"""Backfill fact_ko and embedding_ko for existing memories.

Resumable/idempotent: only processes rows WHERE fact_ko IS NULL.
Translates English facts to Korean via Gemini Flash 2.0, validates,
then embeds and writes back to the memories table.

Usage:
    python3 backfill_fact_ko.py [options]

Options:
    --batch-size N     Memories per LLM call (default: 100)
    --sleep S          Seconds to sleep between batches (default: 1.0)
    --max-batches N    Stop after N batches (default: unlimited)
    --dry-run          Fetch + translate but do not write to DB
    --failures-file F  Path for failure report (default: backfill_failures.json)
"""
import argparse
import logging
import os
import re
import sys
import time

import requests

from atomizer import _validate_fact_ko
from config import EMBEDDING_MODEL, OLLAMA_URL, load_google_api_key
from db import get_conn, put_conn

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [backfill-ko] %(message)s",
)
log = logging.getLogger("backfill-ko")

# ── Gemini config ─────────────────────────────────────────────────────────────

BACKFILL_MODEL = "gemini-2.5-flash"
MAX_RETRIES = 3

# Retry/lease controls for faster, non-thrashing backfill
IN_PROGRESS_LEASE_SECONDS = 600         # prevent duplicate work across workers
RETRY_BASE_SECONDS = 1800              # 30m base backoff for failed rows
RETRY_MAX_SECONDS = 24 * 3600          # cap retry delay at 24h


GOOGLE_API_KEY = load_google_api_key()
API_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{BACKFILL_MODEL}:generateContent"
)

TRANSLATE_SYSTEM = """You are a Korean translation assistant for a memory system.
Translate each English fact to Korean accurately:
- Preserve all numbers, dates, and entity names exactly
- Use natural Korean phrasing
- Do not add or remove information
- If unsure about translation quality, output null for that fact

Return a JSON array with one element per input fact:
[{"id": "<id>", "fact_ko": "<korean translation or null>"}, ...]"""


# ── Translation ───────────────────────────────────────────────────────────────

def _translate_batch(rows: list[dict]) -> dict[str, str | None]:
    """Translate a batch of facts to Korean. Returns {id: fact_ko or None}."""
    if not GOOGLE_API_KEY:
        log.error("GOOGLE_API_KEY not set, cannot translate")
        return {str(r["id"]): None for r in rows}

    # Build input list
    items = [{"id": str(r["id"]), "fact": r["fact"]} for r in rows]
    user_prompt = (
        "Translate each fact to Korean:\n\n"
        + json.dumps(items, ensure_ascii=False)
        + "\n\nReturn ONLY a JSON array. No markdown fencing."
    )

    payload = {
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "systemInstruction": {"parts": [{"text": TRANSLATE_SYSTEM}]},
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 16384,
            "responseMimeType": "application/json",
        },
    }

    for attempt in range(MAX_RETRIES):
        try:
            resp = requests.post(
                f"{API_URL}?key={GOOGLE_API_KEY}",
                json=payload,
                timeout=90,
            )
            if resp.status_code == 429:
                wait = 2 ** (attempt + 2)
                log.warning("Rate limited, waiting %ds (attempt %d/%d)", wait, attempt + 1, MAX_RETRIES)
                time.sleep(wait)
                continue
            resp.raise_for_status()

            data = resp.json()
            text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            if text.startswith("```"):
                text = re.sub(r'^```\w*\n?', '', text)
                text = re.sub(r'\n?```$', '', text)

            try:
                translated = json.loads(text)
            except json.JSONDecodeError:
                # Truncated JSON recovery: try fixing common truncation patterns
                fixed = text.rstrip()
                # Close any open string
                if fixed.count('"') % 2 == 1:
                    fixed += '"}'
                # Try closing with ]
                if not fixed.endswith(']'):
                    # Find last complete object
                    last_brace = fixed.rfind('}')
                    if last_brace > 0:
                        fixed = fixed[:last_brace + 1] + ']'
                try:
                    translated = json.loads(fixed)
                    log.warning("Recovered truncated JSON (%d chars → %d items)", len(text), len(translated) if isinstance(translated, list) else 0)
                except json.JSONDecodeError:
                    raise ValueError(f"Unrecoverable JSON parse error, text length={len(text)}")
            if not isinstance(translated, list):
                raise ValueError("Expected JSON array")

            result = {str(r["id"]): None for r in rows}
            for item in translated:
                mid = str(item.get("id", ""))
                if mid in result:
                    result[mid] = item.get("fact_ko") or None
            return result

        except Exception as e:
            log.error("Translation failed (attempt %d/%d): %s", attempt + 1, MAX_RETRIES, e)
            if attempt == MAX_RETRIES - 1:
                return {str(r["id"]): None for r in rows}
            time.sleep(2 ** (attempt + 1))

    return {str(r["id"]): None for r in rows}


# ── Embedding ─────────────────────────────────────────────────────────────────

EMBED_BATCH_SIZE = 8  # Ollama handles smaller batches better


def _embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed a list of texts via Ollama bge-m3. Returns list of embeddings."""
    url = f"{OLLAMA_URL}/api/embed"
    all_embeddings = []
    for i in range(0, len(texts), EMBED_BATCH_SIZE):
        batch = texts[i:i + EMBED_BATCH_SIZE]
        for attempt in range(3):
            try:
                resp = requests.post(url, json={
                    "model": EMBEDDING_MODEL,
                    "input": batch,
                }, timeout=60)
                resp.raise_for_status()
                all_embeddings.extend(resp.json()["embeddings"])
                break
            except Exception as e:
                if attempt < 2:
                    time.sleep(2 ** (attempt + 1))
                    continue
                raise RuntimeError(f"Embedding failed after 3 retries: {e}")
    return all_embeddings


# ── DB operations ─────────────────────────────────────────────────────────────

def _ensure_backfill_meta_table(conn) -> None:
    """Create retry/lease metadata table (idempotent)."""
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS fact_ko_backfill_meta (
                memory_id UUID PRIMARY KEY,
                attempts INT NOT NULL DEFAULT 0,
                status TEXT NOT NULL DEFAULT 'pending',
                next_retry_at TIMESTAMPTZ,
                last_error TEXT,
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_fact_ko_backfill_meta_retry
            ON fact_ko_backfill_meta (next_retry_at)
        """)
    conn.commit()


def _fetch_batch(conn, batch_size: int, lease_seconds: int = IN_PROGRESS_LEASE_SECONDS) -> list[dict]:
    """Fetch next backfillable rows and lease them to this worker."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT m.id, m.fact
            FROM memories m
            LEFT JOIN fact_ko_backfill_meta b ON b.memory_id = m.id
            WHERE m.fact_ko IS NULL
              AND m.status = 'active'
              AND (b.next_retry_at IS NULL OR b.next_retry_at <= now())
              AND COALESCE(b.status, 'pending') <> 'in_progress'
            ORDER BY m.created_at ASC
            LIMIT %s
            FOR UPDATE OF m SKIP LOCKED
        """, (batch_size,))
        rows = [{"id": str(row[0]), "fact": row[1]} for row in cur.fetchall()]

        if rows:
            lease_secs = max(30, int(lease_seconds))
            for r in rows:
                cur.execute("""
                    INSERT INTO fact_ko_backfill_meta (memory_id, attempts, status, next_retry_at, last_error, updated_at)
                    VALUES (%s::uuid, 0, 'in_progress', now() + make_interval(secs => %s), NULL, now())
                    ON CONFLICT (memory_id)
                    DO UPDATE SET
                        status = 'in_progress',
                        next_retry_at = now() + make_interval(secs => %s),
                        updated_at = now()
                """, (r["id"], lease_secs, lease_secs))

    conn.commit()
    return rows


def _count_remaining(conn) -> int:
    """Count memories still needing backfill."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT count(*) FROM memories WHERE fact_ko IS NULL AND status = 'active'
        """)
        return cur.fetchone()[0]


def _mark_retry(conn, ids: list[str], reason: str, min_retry_seconds: int = RETRY_BASE_SECONDS) -> None:
    """Mark rows for retry with exponential backoff to avoid hot-loop thrash."""
    if not ids:
        return

    with conn.cursor() as cur:
        for mid in ids:
            cur.execute("SELECT attempts FROM fact_ko_backfill_meta WHERE memory_id = %s::uuid", (mid,))
            row = cur.fetchone()
            prev_attempts = int(row[0]) if row else 0
            attempts = prev_attempts + 1
            backoff = min(
                RETRY_MAX_SECONDS,
                max(int(min_retry_seconds), RETRY_BASE_SECONDS * (2 ** max(0, attempts - 1)))
            )
            cur.execute("""
                INSERT INTO fact_ko_backfill_meta (memory_id, attempts, status, next_retry_at, last_error, updated_at)
                VALUES (%s::uuid, %s, 'retry', now() + make_interval(secs => %s), %s, now())
                ON CONFLICT (memory_id)
                DO UPDATE SET
                    attempts = EXCLUDED.attempts,
                    status = EXCLUDED.status,
                    next_retry_at = EXCLUDED.next_retry_at,
                    last_error = EXCLUDED.last_error,
                    updated_at = now()
            """, (mid, attempts, backoff, reason[:500]))
    conn.commit()


def _clear_meta(conn, ids: list[str]) -> None:
    """Clear retry/lease metadata for completed rows."""
    if not ids:
        return
    with conn.cursor() as cur:
        cur.execute("DELETE FROM fact_ko_backfill_meta WHERE memory_id = ANY(%s::uuid[])", (ids,))
    conn.commit()


def _update_batch(conn, updates: list[dict]) -> int:
    """Update fact_ko and embedding_ko for a list of {id, fact_ko, embedding_ko}."""
    updated = 0
    done_ids: list[str] = []
    with conn.cursor() as cur:
        for u in updates:
            emb_str = str(u["embedding_ko"]) if u.get("embedding_ko") else None
            cur.execute("""
                UPDATE memories
                SET fact_ko = %s, embedding_ko = %s
                WHERE id = %s::uuid AND fact_ko IS NULL
            """, (u["fact_ko"], emb_str, u["id"]))
            updated += cur.rowcount
            done_ids.append(u["id"])
    conn.commit()
    _clear_meta(conn, done_ids)
    return updated


# ── Main backfill loop ────────────────────────────────────────────────────────

def run_backfill(batch_size: int = 100, sleep_sec: float = 0.0,
                 max_batches: int = 0, dry_run: bool = False,
                 failures_file: str = "backfill_failures.json") -> dict:
    """
    Main backfill loop. Resumable: only processes rows WHERE fact_ko IS NULL.

    Returns summary stats dict.
    """
    if not GOOGLE_API_KEY:
        log.error("GOOGLE_API_KEY is required. Set env var or OPENCLAW_CONFIG_PATH")
        sys.exit(1)

    conn = get_conn()
    _ensure_backfill_meta_table(conn)
    total_remaining = _count_remaining(conn)
    log.info("Starting backfill: %d memories need fact_ko", total_remaining)

    processed = 0
    updated = 0
    skipped_validation = 0
    failures: list[dict] = []
    batch_num = 0

    try:
        while True:
            if max_batches > 0 and batch_num >= max_batches:
                log.info("Reached max_batches=%d, stopping.", max_batches)
                break

            rows = _fetch_batch(conn, batch_size, lease_seconds=IN_PROGRESS_LEASE_SECONDS)
            if not rows:
                log.info("No more rows to backfill. Done.")
                break

            batch_num += 1
            log.info("Batch %d: %d rows (total processed so far: %d/%d)",
                     batch_num, len(rows), processed, total_remaining)

            # Step 1: Translate via Gemini
            try:
                translations = _translate_batch(rows)
            except Exception as e:
                log.error("Batch %d translation failed: %s", batch_num, e)
                row_ids = [r["id"] for r in rows]
                _mark_retry(conn, row_ids, f"translate_failed: {e}", min_retry_seconds=300)
                for r in rows:
                    failures.append({"id": r["id"], "error": str(e)})
                processed += len(rows)
                if sleep_sec > 0:
                    time.sleep(sleep_sec)
                continue

            # Step 2: Validate translations
            valid_updates: list[dict] = []
            invalid_ids: list[str] = []
            for r in rows:
                mid = r["id"]
                fact_ko_raw = translations.get(mid)
                fact_ko = _validate_fact_ko(r["fact"], fact_ko_raw)
                if fact_ko is None:
                    skipped_validation += 1
                    invalid_ids.append(mid)
                    log.debug("Validation failed for %s: fact=%r ko=%r", mid, r["fact"][:60], fact_ko_raw)
                else:
                    valid_updates.append({"id": mid, "fact_ko": fact_ko, "embedding_ko": None})

            if invalid_ids:
                # Cool down invalid rows to avoid immediate re-hit loops.
                _mark_retry(conn, invalid_ids, "validation_failed", min_retry_seconds=3600)

            # Step 3: Embed valid Korean facts
            if valid_updates:
                ko_texts = [u["fact_ko"] for u in valid_updates]
                try:
                    ko_embeddings = _embed_texts(ko_texts)
                    for u, emb in zip(valid_updates, ko_embeddings):
                        u["embedding_ko"] = emb
                except Exception as e:
                    log.error("Batch %d embedding failed: %s", batch_num, e)
                    row_ids = [r["id"] for r in rows]
                    _mark_retry(conn, row_ids, f"embedding_failed: {e}", min_retry_seconds=300)
                    for u in valid_updates:
                        failures.append({"id": u["id"], "error": f"embed: {e}"})
                    processed += len(rows)
                    if sleep_sec > 0:
                        time.sleep(sleep_sec)
                    continue

            # Step 4: Write to DB
            if not dry_run and valid_updates:
                n = _update_batch(conn, valid_updates)
                updated += n
                log.info("Batch %d: updated %d/%d rows (validated=%d, skip_validation=%d)",
                         batch_num, n, len(rows), len(valid_updates), skipped_validation)
            elif dry_run:
                log.info("[DRY-RUN] Batch %d: would update %d/%d rows",
                         batch_num, len(valid_updates), len(rows))

            processed += len(rows)

            if sleep_sec > 0:
                time.sleep(sleep_sec)

    except KeyboardInterrupt:
        log.info("Interrupted by user after %d batches.", batch_num)
    finally:
        put_conn(conn)

    # Write failure report
    if failures:
        with open(failures_file, "w", encoding="utf-8") as f:
            json.dump(failures, f, ensure_ascii=False, indent=2)
        log.warning("Wrote %d failures to %s", len(failures), failures_file)

    summary = {
        "batches": batch_num,
        "processed": processed,
        "updated": updated,
        "skipped_validation": skipped_validation,
        "failures": len(failures),
        "dry_run": dry_run,
    }
    log.info("Backfill complete: %s", summary)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backfill fact_ko + embedding_ko for memories")
    parser.add_argument("--batch-size", type=int, default=25,
                        help="Memories per LLM translation call (default: 25)")
    parser.add_argument("--sleep", type=float, default=0.0,
                        help="Seconds to sleep between batches (default: 0.0)")
    parser.add_argument("--max-batches", type=int, default=0,
                        help="Max batches to run (0=unlimited)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Translate and embed but do not write to DB")
    parser.add_argument("--failures-file", type=str, default="backfill_failures.json",
                        help="Path for failure report JSON")
    args = parser.parse_args()

    result = run_backfill(
        batch_size=args.batch_size,
        sleep_sec=args.sleep,
        max_batches=args.max_batches,
        dry_run=args.dry_run,
        failures_file=args.failures_file,
    )
    print("\nSummary:")
    for k, v in result.items():
        print(f"  {k}: {v}")
