"""Memory V3 — Relation linker.

Detects supersede/update/contradiction relationships between memories using:
  Stage 1: deterministic prefilter (entity + cosine + jaccard + date order)
  Stage 2: rule-based judgment (number change, correction pattern, elaboration)
  Stage 3: LLM contradiction detection — Gemini Flash, opt-in via config
"""
import logging
import math
from typing import Optional

from config import (
    CONTRADICTION_COSINE_THRESHOLD,
    CONTRADICTION_LLM_ENABLED,
    CONTRADICTION_LLM_MODEL,
    CONTRADICTION_MAX_PAIRS_PER_MEMORY,
    RELATION_COSINE_THRESHOLD,
    RELATION_JACCARD_THRESHOLD,
)
from db import (
    get_memories_by_entity, insert_relation, update_memory_status,
)

log = logging.getLogger("relation-linker")


# ── Similarity utilities ──────────────────────────────────────────────────────

def cosine_sim(a: list[float], b: list[float]) -> float:
    """Cosine similarity between two embedding vectors."""
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def jaccard_tokens(text_a: str, text_b: str) -> float:
    """Jaccard similarity of word sets."""
    a = set(text_a.lower().split())
    b = set(text_b.lower().split())
    if not a and not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


# ── Stage 1: Deterministic prefilter ─────────────────────────────────────────

def find_candidates(new_memory: dict, conn) -> list[dict]:
    """
    Find existing active memories that might be superseded by new_memory.

    Uses DB-level HNSW vector search (fast) instead of fetching all entity memories.

    Filters:
      1. Same entity (exact match) — via SQL WHERE
      2. cosine similarity >= threshold — via HNSW index
      3. Exclude self
      4. Date order: new_date >= old_date (or either is None)
      5. Jaccard token overlap >= threshold — Python post-filter

    Returns up to 5 best candidates (by cosine desc).
    """
    entity = new_memory.get("entity")
    if not entity:
        return []

    namespace = new_memory.get("namespace", "global")
    new_emb = new_memory.get("embedding")
    new_date = new_memory.get("event_date")
    new_fact = new_memory.get("fact", "")
    new_id = str(new_memory.get("id", ""))

    if not new_emb:
        return []

    # DB-level vector search with entity + status filter (uses HNSW index)
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, fact, context, source_path, event_date, category,
                   1 - (embedding <=> %s::vector) AS cosine
            FROM memories
            WHERE entity = %s AND namespace = %s AND status = 'active'
              AND id != %s::uuid
            ORDER BY embedding <=> %s::vector
            LIMIT 20
        """, (str(new_emb), entity, namespace, new_id, str(new_emb)))
        cols = [d[0] for d in cur.description]
        db_candidates = [dict(zip(cols, row)) for row in cur.fetchall()]

    filtered = []
    for old in db_candidates:
        cos = float(old.get("cosine", 0))
        if cos < RELATION_COSINE_THRESHOLD:
            continue

        # Date order check
        old_date = old.get("event_date")
        if new_date and old_date:
            nd = new_date if hasattr(new_date, 'isoformat') else None
            od = old_date if hasattr(old_date, 'isoformat') else None
            if not nd:
                try:
                    from datetime import datetime
                    nd = datetime.strptime(str(new_date), "%Y-%m-%d").date()
                except Exception:
                    nd = None
            if not od:
                try:
                    from datetime import datetime
                    od = datetime.strptime(str(old_date), "%Y-%m-%d").date()
                except Exception:
                    od = None
            if nd and od and nd < od:
                continue  # time reversal — skip

        # Jaccard token overlap
        jac = jaccard_tokens(new_fact, old.get("fact", ""))
        if jac < RELATION_JACCARD_THRESHOLD:
            continue

        old["_cosine"] = cos
        old["_jaccard"] = jac
        filtered.append(old)

    # Sort by cosine desc, keep top 5
    filtered.sort(key=lambda x: x.get("_cosine", 0), reverse=True)
    return filtered[:5]


# ── Wider candidates for LLM contradiction stage ─────────────────────────────

def find_wider_candidates(
    new_memory: dict,
    conn,
    exclude_ids: set,
) -> list[dict]:
    """Find semantic candidates for LLM contradiction detection.

    Same DB query as find_candidates() but:
    - Cosine threshold: CONTRADICTION_COSINE_THRESHOLD (stricter, default 0.80)
    - No jaccard gate — catches semantically-opposite facts with different wording
    - Excludes IDs already processed by the rule-based stage

    Returns up to 10 candidates by cosine desc.
    """
    entity = new_memory.get("entity")
    if not entity:
        return []

    namespace = new_memory.get("namespace", "global")
    new_emb = new_memory.get("embedding")
    new_date = new_memory.get("event_date")
    new_id = str(new_memory.get("id", ""))

    if not new_emb:
        return []

    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, fact, context, source_path, event_date, category,
                   1 - (embedding <=> %s::vector) AS cosine
            FROM memories
            WHERE entity = %s AND namespace = %s AND status = 'active'
              AND id != %s::uuid
            ORDER BY embedding <=> %s::vector
            LIMIT 20
        """, (str(new_emb), entity, namespace, new_id, str(new_emb)))
        cols = [d[0] for d in cur.description]
        db_rows = [dict(zip(cols, row)) for row in cur.fetchall()]

    filtered = []
    for old in db_rows:
        if str(old["id"]) in exclude_ids:
            continue

        cos = float(old.get("cosine", 0))
        if cos < CONTRADICTION_COSINE_THRESHOLD:
            continue

        # Date order check (same as find_candidates)
        old_date = old.get("event_date")
        if new_date and old_date:
            nd = new_date if hasattr(new_date, 'isoformat') else None
            od = old_date if hasattr(old_date, 'isoformat') else None
            if not nd:
                try:
                    from datetime import datetime
                    nd = datetime.strptime(str(new_date), "%Y-%m-%d").date()
                except Exception:
                    nd = None
            if not od:
                try:
                    from datetime import datetime
                    od = datetime.strptime(str(old_date), "%Y-%m-%d").date()
                except Exception:
                    od = None
            if nd and od and nd < od:
                continue

        old["_cosine"] = cos
        filtered.append(old)

    filtered.sort(key=lambda x: x.get("_cosine", 0), reverse=True)
    return filtered[:10]


# ── Stage 2: Rule-based relation judgment ─────────────────────────────────────

import re

_NUMBER_PATTERN = re.compile(r'\d+(\.\d+)?%?')
_CORRECTION_PATTERN = re.compile(
    r'정정|수정|correction|incorrect|잘못|틀렸|was wrong|actually|사실은|실제로는|아니라|이 아닌',
    re.IGNORECASE
)
_ELABORATION_PATTERN = re.compile(
    r'구체적|상세|detail|specifically|because|이유|원인|즉|즉,|namely',
    re.IGNORECASE
)
_UPDATE_VERBS = re.compile(
    r'변경|변했|바뀌|업데이트|updated|changed|replaced|대체|supersede',
    re.IGNORECASE
)


def _extract_numbers(text: str) -> list[float]:
    """Extract all numeric values from text."""
    nums = []
    for m in _NUMBER_PATTERN.finditer(text):
        try:
            nums.append(float(m.group(0).rstrip('%')))
        except ValueError:
            pass
    return nums


def judge_relation(new_fact: str, old_fact: str) -> str:
    """
    Rule-based judgment for a new→old pair.
    Returns: 'updates' | 'extends' | 'contradicts' | 'none'
    """
    # Correction pattern in new fact → clearly updates
    if _CORRECTION_PATTERN.search(new_fact):
        return "updates"

    # Explicit update verb in new fact
    if _UPDATE_VERBS.search(new_fact):
        return "updates"

    # Number change: both contain numbers and they differ
    new_nums = _extract_numbers(new_fact)
    old_nums = _extract_numbers(old_fact)
    if new_nums and old_nums:
        new_key = sorted(new_nums)[:3]
        old_key = sorted(old_nums)[:3]
        if new_key != old_key:
            # Different numbers on same topic → updates
            return "updates"

    # Elaboration: new fact adds detail to old (longer + contains old tokens)
    if len(new_fact) > len(old_fact) * 1.3:
        old_tokens = set(old_fact.lower().split())
        new_tokens = set(new_fact.lower().split())
        overlap = len(old_tokens & new_tokens) / max(len(old_tokens), 1)
        if overlap > 0.4 and _ELABORATION_PATTERN.search(new_fact):
            return "extends"

    # Very high token overlap with different content → contradicts
    jac = jaccard_tokens(new_fact, old_fact)
    if jac > 0.6 and new_fact.lower() != old_fact.lower():
        return "contradicts"

    return "none"


# ── Apply relations ───────────────────────────────────────────────────────────

def apply_relations(conn, new_id: str, judgments: list[dict]):
    """
    Apply judgment results:
    - 'updates' → mark old as superseded, insert confirmed relation
    - 'extends' / 'contradicts' → insert relation only (no status change)
    - 'none' → skip
    """
    for j in judgments:
        relation = j["relation"]
        old_id = str(j["old_id"])

        if relation == "none":
            continue

        # Insert relation record (audit trail)
        try:
            insert_relation(conn, new_id, old_id, relation, status="confirmed")
        except Exception as e:
            log.warning("insert_relation failed: %s", e)

        if relation == "updates":
            try:
                update_memory_status(conn, old_id, status="superseded",
                                     superseded_by=new_id)
                log.debug("Superseded %s by %s", old_id, new_id)
            except Exception as e:
                log.warning("update_memory_status failed: %s", e)


# ── Link a batch of new memories ─────────────────────────────────────────────

def link_new_memories(conn, memory_rows: list[dict]):
    """
    For each newly created memory, find candidates and apply relations.
    Called by atomize_worker after embedding.
    memory_rows: list of dicts with id, fact, entity, event_date, embedding, namespace
    """
    stats = {
        "checked": 0, "updates": 0, "extends": 0, "contradicts": 0,
        "llm_calls": 0, "llm_contradicts": 0,
    }

    for memory in memory_rows:
        candidates = find_candidates(memory, conn)
        new_fact = memory.get("fact", "")
        new_id = str(memory["id"])

        # ── Stage 2: rule-based judgment ──────────────────────────────────────
        rule_judgments = []
        rule_none_high_cosine = []   # candidates for LLM stage

        for cand in candidates:
            rel = judge_relation(new_fact, cand.get("fact", ""))
            if rel != "none":
                rule_judgments.append({"old_id": cand["id"], "relation": rel})
                stats[rel] = stats.get(rel, 0) + 1
            elif (
                CONTRADICTION_LLM_ENABLED
                and cand.get("_cosine", 0) >= CONTRADICTION_COSINE_THRESHOLD
            ):
                rule_none_high_cosine.append(cand)

        stats["checked"] += 1
        if rule_judgments:
            apply_relations(conn, new_id, rule_judgments)

        # ── Stage 3: LLM contradiction detection ──────────────────────────────
        if not CONTRADICTION_LLM_ENABLED:
            continue

        # Wider pool: high-cosine candidates that bypassed the jaccard gate
        rule_ids = {str(c["id"]) for c in candidates}
        wider = find_wider_candidates(memory, conn, exclude_ids=rule_ids)

        # Union: rule-based none + wider, deduplicated by id
        seen_ids: set = set()
        llm_pool: list[dict] = []
        for cand in rule_none_high_cosine + wider:
            cid = str(cand["id"])
            if cid not in seen_ids:
                seen_ids.add(cid)
                llm_pool.append(cand)

        # Sort by cosine desc, cap at max pairs
        llm_pool.sort(key=lambda x: x.get("_cosine", 0), reverse=True)
        llm_pool = llm_pool[:CONTRADICTION_MAX_PAIRS_PER_MEMORY]

        if not llm_pool:
            continue

        # Call LLM
        try:
            from llm_contradiction import llm_judge_contradictions
            llm_results = llm_judge_contradictions(
                new_fact, llm_pool, model=CONTRADICTION_LLM_MODEL
            )
            stats["llm_calls"] += 1
        except Exception as e:
            log.error("LLM contradiction stage error: %s", e)
            continue

        llm_judgments = [r for r in llm_results if r["relation"] != "none"]
        if llm_judgments:
            apply_relations(conn, new_id, llm_judgments)
            n_contra = sum(1 for r in llm_judgments if r["relation"] == "contradicts")
            n_update = sum(1 for r in llm_judgments if r["relation"] == "updates")
            stats["llm_contradicts"] += n_contra
            stats["contradicts"] = stats.get("contradicts", 0) + n_contra
            stats["updates"] = stats.get("updates", 0) + n_update
            log.info(
                "LLM contradiction: memory %s — %d contradicts, %d updates detected",
                new_id, n_contra, n_update,
            )

    if stats["llm_calls"] > 0:
        log.info(
            "link_new_memories LLM stats: calls=%d, llm_contradicts=%d",
            stats["llm_calls"], stats["llm_contradicts"],
        )

    return stats


# ── Full pass: link all active memories ──────────────────────────────────────

def link_all_active(conn, dry_run: bool = False) -> dict:
    """
    One-shot: iterate all active memories, run relation detection.
    Uses keyset pagination (NULL-safe) instead of OFFSET.
    Wrapped in pg_advisory_lock(42001) to prevent concurrent runs.

    dry_run: if True, count potential relations without writing.
    Returns stats dict.
    """
    # Try to acquire advisory lock
    with conn.cursor() as cur:
        cur.execute("SELECT pg_try_advisory_lock(42001)")
        acquired = cur.fetchone()[0]
    if not acquired:
        return {"skipped": True, "reason": "another relink running"}

    try:
        # Count first
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM memories WHERE status = 'active'")
            total = cur.fetchone()[0]

        log.info("link_all_active: %d active memories to process (dry_run=%s)",
                 total, dry_run)

        stats = {"checked": 0, "updates": 0, "extends": 0, "contradicts": 0,
                 "total": total, "batches": 0, "dry_run": dry_run}
        if dry_run:
            stats["would_update"] = 0
            stats["would_extend"] = 0
            stats["would_contradict"] = 0

        BATCH = 500
        # Keyset cursor: (COALESCE(event_date, '9999-12-31'), created_at, id)
        last_sort_date = None
        last_created = None
        last_id = None
        processed = 0

        while True:
            with conn.cursor() as cur:
                if last_id is None:
                    # First batch
                    cur.execute("""
                        SELECT id, fact, entity, event_date, embedding, namespace, created_at
                        FROM memories
                        WHERE status = 'active'
                        ORDER BY COALESCE(event_date, DATE '9999-12-31') ASC,
                                 created_at ASC, id ASC
                        LIMIT %s
                    """, (BATCH,))
                else:
                    cur.execute("""
                        SELECT id, fact, entity, event_date, embedding, namespace, created_at
                        FROM memories
                        WHERE status = 'active'
                          AND (COALESCE(event_date, DATE '9999-12-31'), created_at, id)
                              > (%s, %s, %s::uuid)
                        ORDER BY COALESCE(event_date, DATE '9999-12-31') ASC,
                                 created_at ASC, id ASC
                        LIMIT %s
                    """, (last_sort_date, last_created, last_id, BATCH))
                cols = [d[0] for d in cur.description]
                rows = [dict(zip(cols, r)) for r in cur.fetchall()]

            if not rows:
                break

            for memory in rows:
                # Parse embedding from DB (comes as string like "[0.1,0.2,...]")
                emb = memory.get("embedding")
                if isinstance(emb, str):
                    try:
                        emb = [float(x) for x in emb.strip("[]{}").split(",")]
                        memory["embedding"] = emb
                    except Exception:
                        continue

                cands = find_candidates(memory, conn)
                if not cands:
                    continue
                judgments = []
                for cand in cands:
                    rel = judge_relation(memory.get("fact", ""), cand.get("fact", ""))
                    if rel != "none":
                        judgments.append({"old_id": cand["id"], "relation": rel})
                        if dry_run:
                            key = f"would_{rel.rstrip('s') if rel.endswith('s') else rel}"
                            if rel == "updates":
                                stats["would_update"] = stats.get("would_update", 0) + 1
                            elif rel == "extends":
                                stats["would_extend"] = stats.get("would_extend", 0) + 1
                            elif rel == "contradicts":
                                stats["would_contradict"] = stats.get("would_contradict", 0) + 1
                        else:
                            stats[rel] = stats.get(rel, 0) + 1
                stats["checked"] += 1
                if judgments and not dry_run:
                    apply_relations(conn, str(memory["id"]), judgments)

            # Update keyset cursor from last row
            last_row = rows[-1]
            ed = last_row.get("event_date")
            from datetime import date as _date_type
            if ed and hasattr(ed, 'isoformat'):
                last_sort_date = ed
            else:
                last_sort_date = _date_type(9999, 12, 31)
            last_created = last_row["created_at"]
            last_id = str(last_row["id"])

            if not dry_run:
                conn.commit()
            processed += len(rows)
            stats["batches"] += 1

            if processed % 1000 < BATCH:
                log.info("link_all_active: %d/%d processed (checked=%d, updates=%d)",
                         processed, total, stats["checked"],
                         stats.get("would_update", 0) if dry_run else stats["updates"])

        return stats
    finally:
        with conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_unlock(42001)")
        conn.commit()
