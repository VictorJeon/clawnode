"""Memory V3 — Project state snapshot generator.

Generates per-entity "current state" summaries from active memories.
Rule-based (no LLM) — assembles recent state/decision/metric memories into a structured snapshot.

Usage:
    python3 snapshot_generator.py [--entity NAME] [--all]
"""
import argparse
import hashlib
import logging
import sys
from collections import defaultdict
from datetime import date, timedelta

from config import KNOWN_ENTITIES, SNAPSHOT_LLM_ENABLED, SNAPSHOT_LLM_MODEL
from db import get_conn, put_conn
from embeddings import embed_batch
from llm_snapshot import generate_llm_summary

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [snapshot] %(message)s",
)
log = logging.getLogger("snapshot")

# Import canonical entity list from config (single source of truth).
# Eviction uses the same list for protection, snapshot uses it for generation.
from config import SNAPSHOT_ENTITIES

# How many days of memories to consider for snapshot
SNAPSHOT_WINDOW_DAYS = 14


def _fetch_recent_memories(conn, entity: str, namespace: str = "global",
                           days: int = SNAPSHOT_WINDOW_DAYS) -> list[dict]:
    """Fetch recent active memories for an entity, prioritizing state/decision/metric."""
    cutoff = date.today() - timedelta(days=days)
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, fact, category, event_date, document_date, confidence
            FROM memories
            WHERE entity = %s AND namespace = %s AND status = 'active'
              AND (document_date >= %s OR event_date >= %s OR document_date IS NULL)
            ORDER BY
                CASE category
                    WHEN 'state' THEN 1
                    WHEN 'decision' THEN 2
                    WHEN 'metric' THEN 3
                    WHEN 'lesson' THEN 4
                    ELSE 5
                END,
                COALESCE(event_date, document_date, '1970-01-01') DESC
            LIMIT 50
        """, (entity, namespace, cutoff, cutoff))
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def _build_summary(entity: str, memories: list[dict]) -> tuple[str, dict]:
    """Build a structured summary from memories. Returns (summary_text, key_facts)."""
    if not memories:
        return f"{entity}: 최근 활동 없음.", {}

    states = [m for m in memories if m["category"] == "state"]
    decisions = [m for m in memories if m["category"] == "decision"]
    metrics = [m for m in memories if m["category"] == "metric"]
    lessons = [m for m in memories if m["category"] == "lesson"]
    factuals = [m for m in memories if m["category"] == "factual"]

    parts = []

    # State lines (top 5)
    if states:
        state_facts = [s["fact"] for s in states[:5]]
        parts.append("현재 상태: " + " / ".join(state_facts))

    # Recent decisions (top 3)
    if decisions:
        dec_facts = [d["fact"] for d in decisions[:3]]
        parts.append("최근 결정: " + " | ".join(dec_facts))

    # Key metrics (top 5)
    if metrics:
        met_facts = [m["fact"] for m in metrics[:5]]
        parts.append("주요 수치: " + " | ".join(met_facts))

    # Lessons (top 2)
    if lessons:
        les_facts = [l["fact"] for l in lessons[:2]]
        parts.append("교훈: " + " | ".join(les_facts))

    if not parts:
        # Fallback to factuals
        fact_texts = [f["fact"] for f in factuals[:5]]
        parts.append(" | ".join(fact_texts))

    summary = f"{entity}: " + " ".join(parts)

    # Key facts JSON
    key_facts = {
        "states": len(states),
        "decisions": len(decisions),
        "metrics": len(metrics),
        "lessons": len(lessons),
        "total_memories": len(memories),
        "latest_date": str(max(
            (m.get("event_date") or m.get("document_date") or date.min for m in memories),
        )),
    }

    return summary, key_facts


def _compute_input_hash(memories: list[dict]) -> str:
    """SHA-256 digest of sorted memory IDs — detects whether inputs changed."""
    ids = sorted(str(m["id"]) for m in memories)
    return hashlib.sha256("|".join(ids).encode()).hexdigest()[:16]


def _fetch_previous_key_facts(conn, entity: str, namespace: str) -> dict | None:
    """Return key_facts JSON from the most recent snapshot for this entity, or None."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT key_facts FROM project_snapshots
            WHERE project_name = %s AND namespace = %s
            ORDER BY snapshot_date DESC
            LIMIT 1
        """, (entity, namespace))
        row = cur.fetchone()
    if not row or not row[0]:
        return None
    kf = row[0]
    # psycopg2 may return the JSONB column as a dict or as a string
    if isinstance(kf, str):
        import json as _json
        try:
            return _json.loads(kf)
        except Exception:
            return None
    return kf


def generate_snapshot(conn, entity: str, namespace: str = "global") -> dict | None:
    """Generate a snapshot for one entity. Returns stats or None if no data."""
    memories = _fetch_recent_memories(conn, entity, namespace)
    if not memories:
        return None

    # ── LLM path ──────────────────────────────────────────────────────────────
    summary_source = "rule"
    if SNAPSHOT_LLM_ENABLED:
        input_hash = _compute_input_hash(memories)
        prev_kf = _fetch_previous_key_facts(conn, entity, namespace)
        if isinstance(prev_kf, dict) and prev_kf.get("input_hash") == input_hash:
            log.info("Snapshot skip (unchanged): %s", entity)
            return None

        llm_summary = generate_llm_summary(entity, memories, SNAPSHOT_LLM_MODEL)
        if llm_summary:
            # Build key_facts counts from memories then inject LLM metadata
            _, key_facts = _build_summary(entity, memories)
            key_facts["input_hash"] = input_hash
            key_facts["summary_source"] = "llm"
            summary = f"{entity}: {llm_summary}"
            summary_source = "llm"
        else:
            log.warning("LLM snapshot failed for %s — using rule-based fallback", entity)
            summary, key_facts = _build_summary(entity, memories)
            key_facts["input_hash"] = input_hash
            key_facts["summary_source"] = "rule"
    else:
        summary, key_facts = _build_summary(entity, memories)

    # Embed the summary
    embeddings = embed_batch([summary])
    embedding = embeddings[0]

    today = date.today()

    # Upsert into project_snapshots
    import json
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO project_snapshots (project_name, snapshot_date, summary, key_facts, embedding, namespace)
            VALUES (%s, %s, %s, %s, %s::vector, %s)
            ON CONFLICT (project_name, snapshot_date, namespace)
            DO UPDATE SET summary = EXCLUDED.summary, key_facts = EXCLUDED.key_facts,
                          embedding = EXCLUDED.embedding, created_at = now()
            RETURNING id
        """, (entity, today, summary, json.dumps(key_facts), str(embedding), namespace))
        snap_id = cur.fetchone()[0]

    return {
        "entity": entity,
        "snapshot_id": str(snap_id),
        "summary_length": len(summary),
        "memories_used": len(memories),
        "summary_source": summary_source,
        "key_facts": key_facts,
    }


def generate_all_snapshots(conn) -> list[dict]:
    """Generate snapshots for all known snapshot-worthy entities."""
    results = []
    for entity in SNAPSHOT_ENTITIES:
        try:
            stats = generate_snapshot(conn, entity)
            if stats:
                results.append(stats)
                log.info(
                    "Snapshot: %s (%d memories, source=%s)",
                    entity, stats["memories_used"], stats.get("summary_source", "rule"),
                )
            else:
                log.debug("Snapshot skip: %s (no recent memories)", entity)
        except Exception as e:
            log.error("Snapshot failed for %s: %s", entity, e)
    conn.commit()
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Memory V3 snapshot generator")
    parser.add_argument("--entity", type=str, help="Generate for specific entity")
    parser.add_argument("--all", action="store_true", help="Generate for all known entities")
    args = parser.parse_args()

    conn = get_conn()
    try:
        if args.entity:
            stats = generate_snapshot(conn, args.entity)
            conn.commit()
            if stats:
                print(f"Snapshot: {stats}")
            else:
                print(f"No recent memories for {args.entity}")
        else:
            results = generate_all_snapshots(conn)
            print(f"\nGenerated {len(results)} snapshots:")
            for r in results:
                print(f"  {r['entity']}: {r['memories_used']} memories, {r['summary_length']} chars")
    finally:
        put_conn(conn)
