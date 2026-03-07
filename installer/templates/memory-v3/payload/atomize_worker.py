"""Memory V3 — Async atomize worker.

Runs as a standalone daemon, consuming pending_atomize queue.
Completely independent from server.py and flush pipeline.

Usage:
    python3 atomize_worker.py [--once] [--limit N]

    --once    process current queue then exit (for bulk backfill)
    --limit N  max chunks per run (default: unlimited in --once mode)
"""
import argparse
import logging
import sys
import time
from collections import defaultdict

import math

from atomizer import rule_based_atomize, validate_memories, coverage_report
from config import (
    ATOMIZER_BATCH_SIZE, ATOMIZER_COMMIT_INTERVAL, ATOMIZER_WORKER_INTERVAL,
    DEDUP_TEMPORAL_GAP_DAYS,
)
from db import (
    fetch_pending_chunks, get_conn, get_queue_status, insert_memory,
    mark_queue_done, mark_queue_failed, put_conn,
    is_duplicate_memory, confirm_pending_memories,
)
from embeddings import embed_batch
from relation_linker import link_new_memories

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [atomize-worker] %(message)s",
)
log = logging.getLogger("atomize-worker")


def _cosine_sim_local(a: list[float], b: list[float]) -> float:
    """Fast cosine similarity for intra-batch dedup."""
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def _embed_and_store(conn, facts: list[dict]) -> tuple[list[str], list[dict]]:
    """Embed facts, dedup, insert into memories, and link relations.
    Returns (list of inserted UUIDs, list of inserted memory row dicts).
    """
    if not facts:
        return [], []

    texts = [f["fact"] for f in facts]
    try:
        embeddings = embed_batch(texts)
    except Exception as e:
        log.error("Embedding failed for batch of %d facts: %s", len(facts), e)
        raise

    # Embed Korean facts in a single batched call where available
    ko_texts_indexed = [(i, f["fact_ko"]) for i, f in enumerate(facts)
                        if f.get("fact_ko")]
    embeddings_ko: list[list[float] | None] = [None] * len(facts)
    if ko_texts_indexed:
        try:
            ko_embs = embed_batch([t for _, t in ko_texts_indexed])
            for (i, _), emb in zip(ko_texts_indexed, ko_embs):
                embeddings_ko[i] = emb
        except Exception as e:
            log.warning("Korean embedding failed, proceeding without fact_ko: %s", e)

    memory_ids = []
    memory_rows = []
    # Intra-batch dedup: track (embedding, effective_date) pairs
    batch_facts_meta: list[tuple[list[float], object]] = []

    for fact, emb, emb_ko in zip(facts, embeddings, embeddings_ko):
        curr_date = fact.get("event_date") or fact.get("document_date")

        # Intra-batch dedup: check against already-inserted embeddings
        is_intra_dup = False
        for prev_emb, prev_date in batch_facts_meta:
            if _cosine_sim_local(emb, prev_emb) < 0.95:
                continue
            # Cosine hit — apply temporal gap protection
            if (curr_date is not None and prev_date is not None
                    and abs((curr_date - prev_date).days) >= DEDUP_TEMPORAL_GAP_DAYS):
                continue  # temporally protected — distinct facts
            is_intra_dup = True
            break
        if is_intra_dup:
            log.debug("Skipping intra-batch duplicate: %s", fact["fact"][:60])
            continue

        # DB dedup: check against existing memories (cosine + temporal)
        source_chunk_id = fact.get("source_chunk_id")
        ev = fact.get("event_date")
        doc_d = fact.get("document_date")
        if is_duplicate_memory(conn, emb, source_chunk_id, embedding_ko=emb_ko,
                               event_date=ev, document_date=doc_d):
            log.debug("Skipping DB duplicate: %s", fact["fact"][:60])
            continue
        status = fact.get("status", "active")
        mid = insert_memory(
            conn=conn,
            fact=fact["fact"],
            context=fact.get("context"),
            source_content_hash=fact.get("source_content_hash"),
            source_chunk_id=source_chunk_id,
            source_path=fact.get("source_path"),
            event_date=ev,
            document_date=doc_d,
            embedding=emb,
            entity=fact.get("entity"),
            category=fact.get("category"),
            confidence=fact.get("confidence", 0.8),
            namespace=fact.get("namespace", "global"),
            status=status,
            fact_ko=fact.get("fact_ko"),
            embedding_ko=emb_ko,
        )
        memory_ids.append(mid)
        batch_facts_meta.append((emb, curr_date))

        # Collect row dict for relation linking
        memory_rows.append({
            "id": mid,
            "fact": fact["fact"],
            "entity": fact.get("entity"),
            "event_date": ev,
            "embedding": emb,
            "namespace": fact.get("namespace", "global"),
        })

    # Wire relation linking on newly inserted memories
    if memory_rows:
        try:
            link_stats = link_new_memories(conn, memory_rows)
            if link_stats.get("updates", 0) > 0 or link_stats.get("extends", 0) > 0:
                log.info("Relation linking: %s", link_stats)
        except Exception as e:
            log.warning("Relation linking failed: %s", e)

    return memory_ids, memory_rows


def process_one(conn, item: dict) -> int:
    """
    Process a single queue item. Returns number of memories created.
    Raises on unrecoverable error.
    """
    source_date = item["source_date"]
    source_date_str = source_date.isoformat() if source_date else None

    facts_raw = rule_based_atomize(
        chunk_content=item["chunk_content"],
        source_path=item["source_path"] or "",
        source_date=source_date_str,
        chunk_id=str(item["chunk_id"]),
        namespace=item["namespace"],
    )

    facts = validate_memories(facts_raw, source_date_str)

    if not facts:
        log.debug("chunk %s: 0 facts extracted (empty or filtered)", item["chunk_id"])
        return 0

    memory_ids, _ = _embed_and_store(conn, facts)
    return len(memory_ids)


def run_batch(conn, batch_size: int) -> tuple[int, int, int]:
    """
    Process one batch. Returns (processed, memories_created, failed).
    Commits every ATOMIZER_COMMIT_INTERVAL memories.
    """
    items = fetch_pending_chunks(conn, batch_size)
    conn.commit()  # commit the status=processing update

    if not items:
        return 0, 0, 0

    processed = 0
    memories_created = 0
    failed = 0
    pending_commit = 0

    for item in items:
        queue_id = str(item["id"])
        try:
            n = process_one(conn, item)
            mark_queue_done(conn, queue_id)
            processed += 1
            memories_created += n
            pending_commit += n

            # Commit every N memories to avoid huge transactions
            if pending_commit >= ATOMIZER_COMMIT_INTERVAL:
                conn.commit()
                pending_commit = 0
                log.info("Committed %d memories so far", memories_created)

        except Exception as e:
            log.warning("Failed chunk %s (attempt %d): %s",
                        item["chunk_id"], item["attempts"] + 1, e)
            mark_queue_failed(conn, queue_id, str(e)[:500], increment_attempts=True)
            failed += 1

    conn.commit()
    return processed, memories_created, failed


def run_once(limit: int = 0) -> dict:
    """
    Process the full queue until empty (or up to limit chunks).
    Used for bulk backfill. Returns summary stats.
    """
    conn = get_conn()
    total_processed = 0
    total_memories = 0
    total_failed = 0
    entity_dist: dict[str, int] = defaultdict(int)
    category_dist: dict[str, int] = defaultdict(int)

    try:
        while True:
            batch_size = ATOMIZER_BATCH_SIZE
            if limit > 0:
                remaining = limit - total_processed
                if remaining <= 0:
                    break
                batch_size = min(batch_size, remaining)

            p, m, f = run_batch(conn, batch_size)
            total_processed += p
            total_memories += m
            total_failed += f

            if p == 0:
                log.info("Queue empty. Done.")
                break

            log.info("Batch done: %d processed, %d memories, %d failed (total: %d)",
                     p, m, f, total_processed)

        # Gather distribution stats
        with conn.cursor() as cur:
            cur.execute("""
                SELECT entity, count(*) FROM memories GROUP BY entity ORDER BY count(*) DESC
            """)
            for row in cur.fetchall():
                entity_dist[str(row[0])] = int(row[1])

            cur.execute("""
                SELECT category, count(*) FROM memories GROUP BY category ORDER BY count(*) DESC
            """)
            for row in cur.fetchall():
                category_dist[str(row[0])] = int(row[1])

            cur.execute("SELECT count(*) FROM memories")
            total_rows = cur.fetchone()[0]

    finally:
        put_conn(conn)

    report = coverage_report(total_processed, total_memories, entity_dist, category_dist)
    log.info("\n%s", report)

    return {
        "processed": total_processed,
        "memories": total_memories,
        "failed": total_failed,
        "total_memories_in_db": total_rows,
        "entity_dist": dict(entity_dist),
        "category_dist": dict(category_dist),
    }


CONFIRM_INTERVAL = 300  # 5 minutes between auto-confirm checks


def run_worker(interval: int = ATOMIZER_WORKER_INTERVAL):
    """
    Main daemon loop. Runs forever, polling queue every `interval` seconds.
    Also runs auto-confirm for pending memories every CONFIRM_INTERVAL seconds.
    Call with: python3 atomize_worker.py
    """
    log.info("Atomize worker starting (poll interval: %ds)", interval)
    last_confirm = time.time()

    while True:
        conn = None
        try:
            conn = get_conn()
            p, m, f = run_batch(conn, ATOMIZER_BATCH_SIZE)
            if p > 0:
                log.info("Batch: processed=%d memories=%d failed=%d", p, m, f)

            # Auto-confirm pending memories every CONFIRM_INTERVAL
            if time.time() - last_confirm >= CONFIRM_INTERVAL:
                try:
                    confirmed = confirm_pending_memories(conn, older_than_hours=24)
                    conn.commit()
                    if confirmed > 0:
                        log.info("Auto-confirmed %d pending memories", confirmed)
                except Exception as e:
                    log.warning("Auto-confirm failed: %s", e)
                last_confirm = time.time()

        except Exception as e:
            log.error("Worker error: %s", e)
        finally:
            if conn:
                try:
                    put_conn(conn)
                except Exception:
                    pass

        time.sleep(interval)


def run_link_pass(dry_run: bool = False):
    """
    One-shot: run relation linker over all active memories.
    Useful after bulk backfill to establish supersede chains.
    """
    from relation_linker import link_all_active
    conn = get_conn()
    try:
        stats = link_all_active(conn, dry_run=dry_run)
        if not dry_run:
            conn.commit()
        log.info("Relation link pass: %s", stats)
        return stats
    finally:
        put_conn(conn)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Memory V3 atomize worker")
    parser.add_argument("--once", action="store_true",
                        help="Process full queue then exit")
    parser.add_argument("--limit", type=int, default=0,
                        help="Max chunks in --once mode (0=unlimited)")
    parser.add_argument("--link", action="store_true",
                        help="Run relation linker pass after atomize (--once only)")
    parser.add_argument("--relink", action="store_true",
                        help="Run relation linker over all active memories then exit")
    parser.add_argument("--dry-run", action="store_true",
                        help="With --relink: count potential relations without writing")
    parser.add_argument("--interval", type=int, default=ATOMIZER_WORKER_INTERVAL,
                        help="Poll interval seconds (daemon mode)")
    args = parser.parse_args()

    if args.relink:
        log.info("Relink mode (dry_run=%s)", args.dry_run)
        stats = run_link_pass(dry_run=args.dry_run)
        print("\nRelink stats:")
        for k, v in stats.items():
            print(f"  {k}: {v}")
        sys.exit(0)
    elif args.once:
        log.info("One-shot mode%s", f" (limit={args.limit})" if args.limit else "")
        stats = run_once(limit=args.limit)
        print("\nSummary:")
        for k, v in stats.items():
            if not isinstance(v, dict):
                print(f"  {k}: {v}")
        if args.link:
            log.info("Running relation linker pass…")
            link_stats = run_link_pass()
            print("\nRelation stats:")
            for k, v in link_stats.items():
                print(f"  {k}: {v}")
        sys.exit(0)
    else:
        run_worker(interval=args.interval)
