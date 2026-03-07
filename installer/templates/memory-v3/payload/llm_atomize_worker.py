"""Memory V3 — Tier 2 LLM Atomize Worker.

Processes chunks that benefit from LLM extraction:
1. session_live chunks (conversation logs)
2. Chunks where Tier 1 extracted 0 facts
3. Chunks with high metric/transaction density

Runs as a separate daemon (LaunchAgent) with longer polling interval (5 min).
"""
import logging
import sys
import time
from datetime import date

import math

from config import DEDUP_TEMPORAL_GAP_DAYS
from db import get_conn, put_conn, insert_memory, is_duplicate_memory
from embeddings import embed_batch
from llm_atomizer import llm_atomize_batch, MAX_CHUNKS_PER_BATCH
from relation_linker import link_new_memories

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [llm-atomize] %(message)s",
)
log = logging.getLogger("llm-atomize-worker")

POLL_INTERVAL = 300  # 5 minutes
BATCH_SIZE = MAX_CHUNKS_PER_BATCH


def _ensure_tracking_table(conn):
    """Track which chunks were already processed by Tier 2 (even with 0 facts)."""
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS llm_atomize_runs (
            chunk_id UUID PRIMARY KEY,
            processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            facts_added INT NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'ok'
        )
    """)
    conn.commit()


def _mark_batch_processed(conn, chunk_ids: list[str], facts_by_chunk: dict[str, int], status: str = "ok"):
    """Persist processed marker per chunk to prevent infinite reprocessing."""
    if not chunk_ids:
        return
    cur = conn.cursor()
    for cid in chunk_ids:
        cur.execute(
            """
            INSERT INTO llm_atomize_runs (chunk_id, facts_added, status)
            VALUES (%s::uuid, %s, %s)
            ON CONFLICT (chunk_id)
            DO UPDATE SET processed_at = now(), facts_added = EXCLUDED.facts_added, status = EXCLUDED.status
            """,
            (cid, facts_by_chunk.get(cid, 0), status),
        )
    conn.commit()


def _get_tier2_candidates(conn, limit: int = 50) -> list[dict]:
    """Find chunks that need Tier 2 LLM atomization.

    Current scope (cost/quality optimized):
    - session_live chunks only (recent conversation logs)

    Rationale:
    - User pain-point is conversational recall ("어제 몇개 샀지?")
    - session_live is where Tier 1 misses contextual numeric facts most often
    - keeps API cost predictable
    """
    cur = conn.cursor()

    cur.execute("""
        SELECT c.id, c.content, d.source_path, c.source_date::text, d.namespace
        FROM memory_chunks c
        JOIN memory_documents d ON c.document_id = d.id
        LEFT JOIN llm_atomize_runs lar ON lar.chunk_id = c.id
        WHERE lar.chunk_id IS NULL
          AND length(c.content) > 50
        ORDER BY c.created_at DESC
        LIMIT %s
    """, (limit,))

    rows = cur.fetchall()
    return [
        {
            "id": str(row[0]),
            "content": row[1],
            "source_path": row[2],
            "source_date": row[3],
            "namespace": row[4] or "global",
        }
        for row in rows
    ]


def _get_existing_facts(conn, chunk_ids: list[str]) -> dict[str, list[tuple[str, object]]]:
    """Get existing Tier 1 facts for deduplication.

    Returns dict mapping chunk_id → list of (fact_text, effective_date) tuples.
    effective_date is event_date if set, else document_date, else None.
    """
    if not chunk_ids:
        return {}

    cur = conn.cursor()
    placeholders = ",".join(["%s"] * len(chunk_ids))
    cur.execute(f"""
        SELECT source_chunk_id::text, fact, COALESCE(event_date, document_date)
        FROM memories
        WHERE source_chunk_id::text IN ({placeholders})
          AND status = 'active'
    """, chunk_ids)

    result: dict[str, list[tuple[str, object]]] = {cid: [] for cid in chunk_ids}
    for row in cur.fetchall():
        if row[0] in result:
            result[row[0]].append((row[1], row[2]))  # (fact_text, date_or_None)
    return result


def run_once(limit: int = 0) -> dict:
    """Process one batch of Tier 2 candidates. Returns stats."""
    conn = get_conn()
    stats = {"candidates": 0, "processed": 0, "new_facts": 0, "errors": 0}

    try:
        _ensure_tracking_table(conn)

        candidates = _get_tier2_candidates(conn, limit=limit or 50)
        stats["candidates"] = len(candidates)

        if not candidates:
            return stats

        # Process in batches
        for i in range(0, len(candidates), BATCH_SIZE):
            batch = candidates[i:i + BATCH_SIZE]
            chunk_ids = [c["id"] for c in batch]

            # Get existing facts for dedup
            existing = _get_existing_facts(conn, chunk_ids)

            try:
                facts = llm_atomize_batch(batch, existing)
            except Exception as e:
                log.error("LLM batch failed: %s", e)
                stats["errors"] += 1
                _mark_batch_processed(conn, chunk_ids, {}, status="llm_error")
                stats["processed"] += len(batch)
                continue

            if not facts:
                _mark_batch_processed(conn, chunk_ids, {}, status="ok")
                stats["processed"] += len(batch)
                continue

            # Embed new facts (English)
            try:
                fact_texts = [f["fact"] for f in facts]
                embeddings = embed_batch(fact_texts)
            except Exception as e:
                log.error("Embedding failed: %s", e)
                stats["errors"] += 1
                _mark_batch_processed(conn, chunk_ids, {}, status="embed_error")
                stats["processed"] += len(batch)
                continue

            # Embed Korean facts where available (single batched call)
            ko_texts_indexed = [(i, f["fact_ko"]) for i, f in enumerate(facts)
                                if f.get("fact_ko")]
            embeddings_ko: list[list[float] | None] = [None] * len(facts)
            if ko_texts_indexed:
                try:
                    ko_embs = embed_batch([t for _, t in ko_texts_indexed])
                    for (i, _), emb in zip(ko_texts_indexed, ko_embs):
                        embeddings_ko[i] = emb
                except Exception as e:
                    log.warning("Korean embedding failed, proceeding without: %s", e)

            facts_by_chunk: dict[str, int] = {}
            # Intra-batch dedup: track (embedding, effective_date) pairs
            batch_facts_meta: list[tuple[list[float], object]] = []
            memory_rows: list[dict] = []  # for relation linking

            # Insert into memories table — one commit per fact for isolation
            for fact, embedding, emb_ko in zip(facts, embeddings, embeddings_ko):
                curr_date = fact.get("event_date") or fact.get("document_date")

                # Intra-batch cosine dedup with temporal gap protection
                is_intra_dup = False
                for prev_emb, prev_date in batch_facts_meta:
                    dot = sum(x * y for x, y in zip(embedding, prev_emb))
                    na = math.sqrt(sum(x * x for x in embedding))
                    nb = math.sqrt(sum(x * x for x in prev_emb))
                    if not (na > 0 and nb > 0 and dot / (na * nb) >= 0.95):
                        continue
                    # Cosine hit — check temporal gap
                    if (curr_date is not None and prev_date is not None
                            and abs((curr_date - prev_date).days) >= DEDUP_TEMPORAL_GAP_DAYS):
                        continue  # temporally protected — distinct facts
                    is_intra_dup = True
                    break
                if is_intra_dup:
                    log.debug("Skipping intra-batch duplicate: %s", fact["fact"][:60])
                    continue

                insert_conn = get_conn()
                try:
                    # DB dedup check (cosine + temporal)
                    source_chunk_id = fact.get("source_chunk_id")
                    ev = fact.get("event_date")
                    doc_d = fact.get("document_date")
                    if is_duplicate_memory(insert_conn, embedding,
                                          str(source_chunk_id) if source_chunk_id else None,
                                          embedding_ko=emb_ko,
                                          event_date=ev, document_date=doc_d):
                        log.debug("Skipping DB duplicate: %s", fact["fact"][:60])
                        continue

                    status = fact.get("status", "active")
                    mid = insert_memory(
                        insert_conn,
                        fact=fact["fact"],
                        context=fact.get("context"),
                        source_content_hash=fact["source_content_hash"],
                        source_chunk_id=fact["source_chunk_id"],
                        source_path=fact.get("source_path", ""),
                        event_date=fact.get("event_date"),
                        document_date=fact.get("document_date"),
                        entity=fact.get("entity"),
                        category=fact.get("category", "factual"),
                        confidence=fact.get("confidence", 0.75),
                        namespace=fact.get("namespace", "global"),
                        embedding=embedding,
                        status=status,
                        fact_ko=fact.get("fact_ko"),
                        embedding_ko=emb_ko,
                    )
                    insert_conn.commit()
                    stats["new_facts"] += 1
                    batch_facts_meta.append((embedding, curr_date))
                    cid = str(fact.get("source_chunk_id"))
                    facts_by_chunk[cid] = facts_by_chunk.get(cid, 0) + 1

                    memory_rows.append({
                        "id": mid,
                        "fact": fact["fact"],
                        "entity": fact.get("entity"),
                        "event_date": fact.get("event_date"),
                        "embedding": embedding,
                        "namespace": fact.get("namespace", "global"),
                    })
                except Exception as e:
                    log.warning("Insert failed: %s", str(e)[:120])
                    insert_conn.rollback()
                    stats["errors"] += 1
                finally:
                    put_conn(insert_conn)

            # Wire relation linking on newly inserted memories
            if memory_rows:
                link_conn = get_conn()
                try:
                    link_stats = link_new_memories(link_conn, memory_rows)
                    link_conn.commit()
                    if link_stats.get("updates", 0) > 0 or link_stats.get("extends", 0) > 0:
                        log.info("Relation linking: %s", link_stats)
                except Exception as e:
                    log.warning("Relation linking failed: %s", e)
                finally:
                    put_conn(link_conn)

            _mark_batch_processed(conn, chunk_ids, facts_by_chunk, status="ok")
            stats["processed"] += len(batch)

            # Rate limit between batches
            if i + BATCH_SIZE < len(candidates):
                time.sleep(2)

    except Exception as e:
        log.error("Tier 2 worker error: %s", e)
        stats["errors"] += 1
    finally:
        put_conn(conn)

    log.info(
        "Tier 2 done: %d candidates, %d processed, %d new facts, %d errors",
        stats["candidates"], stats["processed"], stats["new_facts"], stats["errors"],
    )
    return stats


def daemon_loop():
    """Run continuously with POLL_INTERVAL sleep."""
    log.info("Tier 2 LLM atomize worker starting (interval=%ds)", POLL_INTERVAL)
    while True:
        try:
            stats = run_once()
            if stats["new_facts"] > 0:
                log.info("Batch result: +%d facts", stats["new_facts"])
        except Exception as e:
            log.error("Worker loop error: %s", e)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        result = run_once(limit=int(sys.argv[2]) if len(sys.argv) > 2 else 0)
        print(result)
    else:
        daemon_loop()
