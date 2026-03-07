#!/usr/bin/env python3
"""One-shot Tier 2 backfill — process ALL remaining chunks as fast as possible.

Usage: python3 tier2_backfill_all.py

Processes 50 chunks per Gemini call (max batch), 1s sleep between batches.
Estimated: ~2,500 chunks → ~50 batches → ~5-10 minutes.
"""
import logging
import sys
import time

from db import get_conn, put_conn, insert_memory
from embeddings import embed_batch
from llm_atomizer import llm_atomize_batch, MAX_CHUNKS_PER_BATCH

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [tier2-backfill] %(message)s",
)
log = logging.getLogger("tier2-backfill")


def get_all_remaining(conn, batch_size: int = 50):
    """Fetch next batch of unprocessed chunks (any source_type)."""
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
    """, (batch_size,))
    return [
        {
            "id": str(row[0]),
            "content": row[1],
            "source_path": row[2],
            "source_date": row[3],
            "namespace": row[4] or "global",
        }
        for row in cur.fetchall()
    ]


def get_existing_facts(conn, chunk_ids):
    if not chunk_ids:
        return {}
    cur = conn.cursor()
    placeholders = ",".join(["%s"] * len(chunk_ids))
    cur.execute(f"""
        SELECT source_chunk_id::text, fact
        FROM memories WHERE source_chunk_id::text IN ({placeholders}) AND status = 'active'
    """, chunk_ids)
    result = {cid: [] for cid in chunk_ids}
    for row in cur.fetchall():
        if row[0] in result:
            result[row[0]].append(row[1])
    return result


def mark_processed(conn, chunk_ids, facts_by_chunk, status="ok"):
    if not chunk_ids:
        return
    cur = conn.cursor()
    for cid in chunk_ids:
        cur.execute("""
            INSERT INTO llm_atomize_runs (chunk_id, facts_added, status)
            VALUES (%s::uuid, %s, %s)
            ON CONFLICT (chunk_id) DO UPDATE SET processed_at = now(), facts_added = EXCLUDED.facts_added, status = EXCLUDED.status
        """, (cid, facts_by_chunk.get(cid, 0), status))
    conn.commit()


def main():
    total_facts = 0
    total_chunks = 0
    total_errors = 0
    batch_num = 0
    start = time.time()

    while True:
        conn = get_conn()
        try:
            candidates = get_all_remaining(conn, batch_size=MAX_CHUNKS_PER_BATCH)
            if not candidates:
                log.info("No more candidates. Done!")
                put_conn(conn)
                break

            batch_num += 1
            chunk_ids = [c["id"] for c in candidates]
            existing = get_existing_facts(conn, chunk_ids)
            put_conn(conn)

            # LLM call
            try:
                facts = llm_atomize_batch(candidates, existing)
            except Exception as e:
                log.error("Batch %d LLM failed: %s", batch_num, e)
                conn2 = get_conn()
                mark_processed(conn2, chunk_ids, {}, status="llm_error")
                put_conn(conn2)
                total_errors += len(candidates)
                total_chunks += len(candidates)
                time.sleep(2)
                continue

            if not facts:
                conn2 = get_conn()
                mark_processed(conn2, chunk_ids, {}, status="ok")
                put_conn(conn2)
                total_chunks += len(candidates)
                log.info("Batch %d: %d chunks → 0 facts", batch_num, len(candidates))
                time.sleep(0.5)
                continue

            # Embed
            try:
                embeddings = embed_batch([f["fact"] for f in facts])
            except Exception as e:
                log.error("Batch %d embed failed: %s", batch_num, e)
                conn2 = get_conn()
                mark_processed(conn2, chunk_ids, {}, status="embed_error")
                put_conn(conn2)
                total_errors += len(candidates)
                total_chunks += len(candidates)
                time.sleep(2)
                continue

            # Insert facts
            facts_by_chunk = {}
            batch_new = 0
            batch_err = 0
            for fact, emb in zip(facts, embeddings):
                ic = get_conn()
                try:
                    insert_memory(
                        ic,
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
                        embedding=emb,
                    )
                    ic.commit()
                    batch_new += 1
                    cid = str(fact.get("source_chunk_id"))
                    facts_by_chunk[cid] = facts_by_chunk.get(cid, 0) + 1
                except Exception as e:
                    log.warning("Insert err: %s", str(e)[:100])
                    ic.rollback()
                    batch_err += 1
                finally:
                    put_conn(ic)

            conn3 = get_conn()
            mark_processed(conn3, chunk_ids, facts_by_chunk)
            put_conn(conn3)

            total_facts += batch_new
            total_errors += batch_err
            total_chunks += len(candidates)
            elapsed = time.time() - start
            log.info(
                "Batch %d: %d chunks → %d facts (%d err) | Total: %d chunks, %d facts in %.0fs",
                batch_num, len(candidates), batch_new, batch_err,
                total_chunks, total_facts, elapsed,
            )

            # Brief pause to not hammer Gemini
            time.sleep(1)

        except Exception as e:
            log.error("Fatal: %s", e)
            put_conn(conn)
            time.sleep(5)

    elapsed = time.time() - start
    log.info("=" * 60)
    log.info("BACKFILL COMPLETE: %d chunks, %d facts, %d errors in %.0fs (%.1f min)",
             total_chunks, total_facts, total_errors, elapsed, elapsed / 60)
    log.info("=" * 60)


if __name__ == "__main__":
    main()
