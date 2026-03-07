"""Memory eviction worker — archives stale, unused memories.

Eviction criteria:
  status = 'active'
  AND hit_count = 0
  AND created_at < now() - EVICTION_AGE_DAYS

SNAPSHOT_ENTITIES get 2x age protection (EVICTION_AGE_DAYS * 2).

Usage:
    python3 eviction_worker.py --dry-run   # count targets, no changes
    python3 eviction_worker.py             # archive targets
"""
import argparse
import logging
import sys
from collections import Counter

from config import EVICTION_AGE_DAYS, SNAPSHOT_ENTITIES
from db import archive_memories_batch, get_conn, put_conn

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [eviction] %(message)s",
)
log = logging.getLogger("eviction")

# Batch size for archive updates — keeps individual transactions small
_ARCHIVE_BATCH = 500


def _fetch_candidates(conn, age_days: int, entity_filter: str, limit: int = 0) -> list[tuple[str, str | None]]:
    """Fetch (id, entity) for eviction candidates.

    entity_filter: 'standard' → entity NOT IN SNAPSHOT_ENTITIES (or NULL)
                   'protected' → entity IN SNAPSHOT_ENTITIES
    """
    base_sql = """
        SELECT id, entity
        FROM memories
        WHERE status = 'active'
          AND hit_count = 0
          AND created_at < now() - (%s * interval '1 day')
    """
    if entity_filter == "standard":
        base_sql += " AND (entity IS NULL OR entity != ALL(%s))"
        params: tuple = (age_days, SNAPSHOT_ENTITIES)
    else:  # protected
        base_sql += " AND entity = ANY(%s)"
        params = (age_days, SNAPSHOT_ENTITIES)

    if limit:
        base_sql += " LIMIT %s"
        params = (*params, limit)

    with conn.cursor() as cur:
        cur.execute(base_sql, params)
        return cur.fetchall()


def evict_memories(conn, dry_run: bool = False) -> dict:
    """Find and archive eviction candidates.

    Returns stats dict with keys:
      standard_candidates, protected_candidates, archived_total,
      entity_dist, dry_run
    """
    standard_age = EVICTION_AGE_DAYS
    protected_age = EVICTION_AGE_DAYS * 2

    log.info(
        "Scanning eviction candidates (standard >= %dd, protected >= %dd, dry_run=%s)",
        standard_age, protected_age, dry_run,
    )

    standard_rows = _fetch_candidates(conn, standard_age, "standard")
    protected_rows = _fetch_candidates(conn, protected_age, "protected")

    all_rows = standard_rows + protected_rows
    entity_dist = Counter(entity for _, entity in all_rows)

    stats = {
        "dry_run": dry_run,
        "standard_candidates": len(standard_rows),
        "protected_candidates": len(protected_rows),
        "archived_total": 0,
        "entity_dist": dict(entity_dist.most_common(30)),
    }

    _log_summary(stats, standard_age, protected_age)

    if dry_run:
        return stats

    # Archive in batches
    all_ids = [str(row[0]) for row in all_rows]
    archived = 0
    for i in range(0, len(all_ids), _ARCHIVE_BATCH):
        batch = all_ids[i: i + _ARCHIVE_BATCH]
        archived += archive_memories_batch(conn, batch)
        conn.commit()
        log.info("Archived batch %d–%d (%d so far)", i + 1, i + len(batch), archived)

    stats["archived_total"] = archived
    log.info("Eviction complete. Archived %d memories total.", archived)
    return stats


def _log_summary(stats: dict, standard_age: int, protected_age: int) -> None:
    total = stats["standard_candidates"] + stats["protected_candidates"]
    prefix = "[DRY-RUN] Would archive" if stats["dry_run"] else "Archiving"
    log.info("%s %d memories", prefix, total)
    log.info("  Standard  (>= %dd, hit_count=0): %d", standard_age, stats["standard_candidates"])
    log.info("  Protected (>= %dd, hit_count=0): %d", protected_age, stats["protected_candidates"])

    if stats["entity_dist"]:
        log.info("Entity distribution (top 30):")
        for entity, count in stats["entity_dist"].items():
            label = entity if entity is not None else "(null)"
            log.info("  %-40s %d", label, count)
    else:
        log.info("No candidates found.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Memory eviction worker")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count eviction targets without making any changes",
    )
    args = parser.parse_args()

    conn = get_conn()
    try:
        stats = evict_memories(conn, dry_run=args.dry_run)
    except Exception as e:
        log.error("Eviction failed: %s", e)
        try:
            conn.rollback()
        except Exception:
            pass
        sys.exit(1)
    finally:
        put_conn(conn)

    print("\nEviction summary:")
    print(f"  dry_run:              {stats['dry_run']}")
    print(f"  standard_candidates:  {stats['standard_candidates']}")
    print(f"  protected_candidates: {stats['protected_candidates']}")
    print(f"  archived_total:       {stats['archived_total']}")


if __name__ == "__main__":
    main()
