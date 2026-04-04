"""Database operations for Memory V2."""
import hashlib
import logging
import time
import threading
from uuid import uuid4
import psycopg2
import psycopg2.pool
from config import DB_URL, DB_POOL_MIN, DB_POOL_MAX, DB_POOL_WAIT_MS

_pool = None
_pool_lock = threading.Lock()
_log = logging.getLogger("memory-v2-db")

def get_pool():
    global _pool
    if _pool is None:
        with _pool_lock:
            if _pool is None:
                min_conn = max(1, DB_POOL_MIN)
                max_conn = max(min_conn, DB_POOL_MAX)
                _pool = psycopg2.pool.ThreadedConnectionPool(min_conn, max_conn, DB_URL)
    return _pool

def get_conn():
    pool = get_pool()
    deadline = time.monotonic() + max(0, DB_POOL_WAIT_MS) / 1000.0
    retry_count = 0
    while True:
        try:
            return pool.getconn()
        except psycopg2.pool.PoolError as e:
            # ThreadedConnectionPool raises PoolError("connection pool exhausted")
            # when max connections are checked out.
            exhausted = "exhausted" in str(e).lower()
            if not exhausted:
                raise
            if time.monotonic() >= deadline:
                raise RuntimeError(
                    f"DB connection pool exhausted (max={DB_POOL_MAX}, waited={DB_POOL_WAIT_MS}ms)"
                ) from e
            backoff = min(0.05 * (2 ** retry_count), 0.5)
            remaining = max(0.0, deadline - time.monotonic())
            time.sleep(min(backoff, remaining))
            retry_count += 1

def put_conn(conn):
    if conn is None:
        return
    try:
        get_pool().putconn(conn)
    except Exception as e:
        _log.warning("put_conn failed: %s", e)

def file_hash(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:16]

def upsert_document(conn, namespace: str, source_type: str, source_path: str,
                    source_hash: str, title: str, tags: list[str]) -> tuple[str, bool]:
    """Insert or skip-if-unchanged. Returns (doc_id, is_new)."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM memory_documents WHERE namespace=%s AND source_path=%s AND source_hash=%s",
            (namespace, source_path, source_hash)
        )
        row = cur.fetchone()
        if row:
            return row[0], False

        # Remove old version
        cur.execute(
            "DELETE FROM memory_documents WHERE namespace=%s AND source_path=%s",
            (namespace, source_path)
        )

        doc_id = str(uuid4())
        cur.execute(
            """INSERT INTO memory_documents (id, namespace, source_type, source_path, source_hash, title, tags)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (doc_id, namespace, source_type, source_path, source_hash, title, tags)
        )
        return doc_id, True

def insert_chunks(conn, doc_id: str, chunks_with_embeddings: list):
    """Insert chunks for a document. Chunks may contain 'date' key for source_date."""
    with conn.cursor() as cur:
        for i, (chunk, embedding) in enumerate(chunks_with_embeddings):
            token_count = len(chunk["content"].split())
            source_date = chunk.get("date")  # YYYY-MM-DD string or None
            cur.execute(
                """INSERT INTO memory_chunks (document_id, chunk_index, content, token_count, embedding, source_date)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (doc_id, i, chunk["content"], token_count, str(embedding), source_date)
            )

def vector_search(conn, embedding: list[float], scopes: list[str], limit: int = 20):
    """Vector cosine similarity search."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT c.id, c.content, c.token_count, d.source_path, d.namespace,
                   c.chunk_index, d.source_type,
                   1 - (c.embedding <=> %s::vector) as score
            FROM memory_chunks c
            JOIN memory_documents d ON c.document_id = d.id
            WHERE d.namespace = ANY(%s)
            ORDER BY c.embedding <=> %s::vector
            LIMIT %s
        """, (str(embedding), scopes, str(embedding), limit))
        return cur.fetchall()

def _sanitize_tsquery_word(w: str) -> str:
    """Strip characters that break to_tsquery('simple', ...) parsing."""
    import re
    # Keep only word characters (letters, digits, underscore) and hyphens
    cleaned = re.sub(r'[^\w\-]', '', w)
    return cleaned

def lexical_search(conn, query: str, scopes: list[str], limit: int = 20):
    """BM25 full-text search."""
    # Build tsquery: split words, sanitize, join with |, handle Korean
    words = [_sanitize_tsquery_word(w) for w in query.split()]
    words = [w for w in words if len(w) > 1][:10]
    if not words:
        return []
    tsquery = " | ".join(words)  # OR for better Korean recall

    with conn.cursor() as cur:
        cur.execute("""
            SELECT c.id, c.content, c.token_count, d.source_path, d.namespace,
                   c.chunk_index, d.source_type,
                   ts_rank_cd(c.content_tsv, to_tsquery('simple', %s)) as score
            FROM memory_chunks c
            JOIN memory_documents d ON c.document_id = d.id
            WHERE c.content_tsv @@ to_tsquery('simple', %s) AND d.namespace = ANY(%s)
            ORDER BY score DESC
            LIMIT %s
        """, (tsquery, tsquery, scopes, limit))
        return cur.fetchall()

def get_stats(conn) -> dict:
    """Get basic stats (V2 + V3 memories/relations if tables exist)."""
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM memory_documents")
        doc_count = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM memory_chunks")
        chunk_count = cur.fetchone()[0]
        cur.execute("SELECT namespace, count(*) FROM memory_documents GROUP BY namespace ORDER BY namespace")
        namespaces = {row[0]: row[1] for row in cur.fetchall()}

    stats = {"documents": doc_count, "chunks": chunk_count, "namespaces": namespaces}

    # V3 stats (optional — skip if tables don't exist yet)
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM memories WHERE status='active'")
            stats["memories_active"] = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM memories")
            stats["memories_total"] = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM memories WHERE status='superseded'")
            stats["memories_superseded"] = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM memory_relations")
            stats["relations_total"] = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM pending_atomize WHERE status='pending'")
            stats["atomize_queue_pending"] = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM pending_atomize WHERE status='done'")
            stats["atomize_queue_done"] = cur.fetchone()[0]
            cur.execute("SELECT count(*) FROM pending_atomize WHERE status='failed'")
            stats["atomize_queue_failed"] = cur.fetchone()[0]
    except Exception:
        pass  # V3 tables not migrated yet

    return stats


# ── V3: Memory CRUD ───────────────────────────────────────────────────────────

def insert_memory(conn, fact: str, context: str | None, source_content_hash: str | None,
                  source_chunk_id: str | None, source_path: str | None,
                  event_date, document_date, embedding: list[float],
                  entity: str | None, category: str | None, confidence: float,
                  namespace: str, status: str = 'active',
                  fact_ko: str | None = None,
                  embedding_ko: list[float] | None = None) -> str:
    """Insert a single atomic memory. Returns the new memory UUID.
    fact_ko and embedding_ko are optional for backward compatibility.
    """
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO memories
                (fact, fact_ko, context, source_content_hash, source_chunk_id, source_path,
                 event_date, document_date, embedding, embedding_ko, entity, category,
                 confidence, namespace, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::vector, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (fact, fact_ko, context, source_content_hash, source_chunk_id, source_path,
              event_date, document_date, str(embedding),
              str(embedding_ko) if embedding_ko is not None else None,
              entity, category, confidence, namespace, status))
        return str(cur.fetchone()[0])


def update_memory_status(conn, memory_id: str, status: str,
                         superseded_by: str | None = None,
                         retracted_reason: str | None = None):
    """Update memory status (superseded / retracted)."""
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE memories
            SET status = %s, superseded_by = %s, retracted_reason = %s
            WHERE id = %s
        """, (status, superseded_by, retracted_reason, memory_id))


def insert_relation(conn, source_id: str, target_id: str, relation_type: str,
                    status: str = "confirmed"):
    """Insert a memory relation (audit trail). Ignores duplicate."""
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO memory_relations (source_id, target_id, relation_type, status)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (source_id, target_id, relation_type) DO NOTHING
        """, (source_id, target_id, relation_type, status))


# Column order for the memory SELECT used by vector_search_memories.
# score is always appended last by the query.
_MEMORY_COLS = [
    'id', 'fact', 'fact_ko', 'context', 'source_path', 'namespace',
    'entity', 'category', 'event_date', 'source_chunk_id',
    'status', 'superseded_by', 'hit_count', 'created_at', 'document_date',
    'score',
]


def _row_to_memory_dict(row) -> dict:
    return dict(zip(_MEMORY_COLS, row))


def vector_search_memories(conn, embedding: list[float], scopes: list[str],
                           limit: int = 20, status: str = "active") -> list[dict]:
    """Dual-index vector search on memories table.

    Runs two independent HNSW passes (English + Korean embeddings),
    then merges by max(score_en, score_ko) per memory id.
    Returns list of dicts (keys: _MEMORY_COLS) sorted by score descending.
    """
    candidate_limit = limit * 3  # over-fetch to allow merge headroom

    with conn.cursor() as cur:
        # Pass 1: English embedding (uses idx_memories_embedding HNSW)
        cur.execute("""
            SELECT
                m.id, m.fact, m.fact_ko, m.context, m.source_path, m.namespace,
                m.entity, m.category, m.event_date, m.source_chunk_id,
                m.status, m.superseded_by, m.hit_count, m.created_at, m.document_date,
                1 - (m.embedding <=> %s::vector) AS score
            FROM memories m
            WHERE m.namespace = ANY(%s) AND m.status = %s
            ORDER BY m.embedding <=> %s::vector
            LIMIT %s
        """, (str(embedding), scopes, status, str(embedding), candidate_limit))
        en_rows = cur.fetchall()

        # Pass 2: Korean embedding (uses idx_memories_embedding_ko HNSW once built)
        # Only runs on rows that have a Korean embedding stored.
        cur.execute("""
            SELECT
                m.id, m.fact, m.fact_ko, m.context, m.source_path, m.namespace,
                m.entity, m.category, m.event_date, m.source_chunk_id,
                m.status, m.superseded_by, m.hit_count, m.created_at, m.document_date,
                1 - (m.embedding_ko <=> %s::vector) AS score
            FROM memories m
            WHERE m.namespace = ANY(%s) AND m.status = %s
              AND m.embedding_ko IS NOT NULL
            ORDER BY m.embedding_ko <=> %s::vector
            LIMIT %s
        """, (str(embedding), scopes, status, str(embedding), candidate_limit))
        ko_rows = cur.fetchall()

    # Merge: keep max(score_en, score_ko) per memory id
    merged: dict[str, dict] = {}
    for row in en_rows:
        mid = str(row[0])
        merged[mid] = _row_to_memory_dict(row)
    for row in ko_rows:
        mid = str(row[0])
        score = float(row[-1])
        if mid in merged:
            merged[mid]['score'] = max(merged[mid]['score'], score)
        else:
            merged[mid] = _row_to_memory_dict(row)

    results = sorted(merged.values(), key=lambda x: x['score'], reverse=True)
    return results[:limit]


def get_snapshot_by_id(conn, snapshot_id: str) -> dict | None:
    """Fetch a single project_snapshot by UUID. Returns dict or None."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, project_name, snapshot_date, summary, key_facts,
                   namespace, created_at
            FROM project_snapshots WHERE id = %s::uuid
        """, (snapshot_id,))
        row = cur.fetchone()
        if not row:
            return None
        cols = [d[0] for d in cur.description]
        return dict(zip(cols, row))


def get_memory_by_id(conn, memory_id: str) -> dict | None:
    """Fetch a single memory by UUID. Returns dict or None."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, fact, context, source_path, event_date, category,
                   entity, status, source_chunk_id, namespace, created_at
            FROM memories WHERE id = %s::uuid
        """, (memory_id,))
        row = cur.fetchone()
        if not row:
            return None
        cols = [d[0] for d in cur.description]
        return dict(zip(cols, row))


def get_chunk_by_id(conn, chunk_id: str) -> dict | None:
    """Fetch a single chunk by UUID, joined with its document for path/namespace."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT c.id, c.content, c.token_count, c.source_date,
                   c.status, c.created_at,
                   d.source_path, d.namespace
            FROM memory_chunks c
            JOIN memory_documents d ON c.document_id = d.id
            WHERE c.id = %s::uuid
        """, (chunk_id,))
        row = cur.fetchone()
        if not row:
            return None
        cols = [d[0] for d in cur.description]
        return dict(zip(cols, row))


def get_memories_by_entity(conn, entity: str, namespace: str,
                           status: str = "active") -> list[dict]:
    """Fetch all memories for a given entity."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, fact, context, source_path, event_date, category,
                   embedding, status, superseded_by, source_chunk_id
            FROM memories
            WHERE entity = %s AND namespace = %s AND status = %s
            ORDER BY event_date DESC NULLS LAST
        """, (entity, namespace, status))
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


# ── V3: Queue CRUD ────────────────────────────────────────────────────────────

def enqueue_chunk(conn, chunk_id: str, chunk_content: str, source_path: str | None,
                  source_date, namespace: str):
    """Add a chunk to the pending_atomize queue. Idempotent."""
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO pending_atomize
                (chunk_id, chunk_content, source_path, source_date, namespace)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (chunk_id) DO NOTHING
        """, (chunk_id, chunk_content, source_path, source_date, namespace))


def fetch_pending_chunks(conn, limit: int = 10) -> list[dict]:
    """Fetch pending queue items (claim-style: mark as processing)."""
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE pending_atomize
            SET status = 'processing'
            WHERE id IN (
                SELECT id FROM pending_atomize
                WHERE status = 'pending'
                ORDER BY created_at
                LIMIT %s
                FOR UPDATE SKIP LOCKED
            )
            RETURNING id, chunk_id, chunk_content, source_path, source_date,
                      namespace, attempts
        """, (limit,))
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def mark_queue_done(conn, queue_id: str):
    """Mark a queue item as done."""
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE pending_atomize
            SET status = 'done', processed_at = now()
            WHERE id = %s
        """, (queue_id,))


def mark_queue_failed(conn, queue_id: str, error: str, increment_attempts: bool = True):
    """Mark a queue item as failed (or re-pending if attempts < max)."""
    with conn.cursor() as cur:
        if increment_attempts:
            cur.execute("""
                UPDATE pending_atomize
                SET attempts = attempts + 1, error = %s,
                    status = CASE WHEN attempts + 1 >= 3 THEN 'failed' ELSE 'pending' END,
                    processed_at = CASE WHEN attempts + 1 >= 3 THEN now() ELSE NULL END
                WHERE id = %s
            """, (error, queue_id))
        else:
            cur.execute("""
                UPDATE pending_atomize
                SET status = 'pending', error = %s WHERE id = %s
            """, (error, queue_id))


def get_queue_status(conn) -> dict:
    """Return counts per queue status."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT status, count(*) FROM pending_atomize GROUP BY status ORDER BY status
        """)
        return {row[0]: row[1] for row in cur.fetchall()}


# ── V3 Phase 2 ───────────────────────────────────────────────────────────────

def is_duplicate_memory(conn, embedding: list[float],
                        source_chunk_id: str | None = None,
                        threshold: float = 0.95,
                        embedding_ko: list[float] | None = None,
                        event_date=None,
                        document_date=None) -> bool:
    """Check if a semantically similar memory already exists.

    Returns True if English OR Korean embedding exceeds the cosine threshold
    AND the temporal gap check does not protect the match.

    Temporal gap protection (DEDUP_TEMPORAL_GAP_DAYS):
    - If the new fact has no date → cosine-only (old behaviour).
    - If an existing memory has no date → counts as duplicate (conservative).
    - If both have dates and |gap| >= DEDUP_TEMPORAL_GAP_DAYS → NOT a duplicate.

    If source_chunk_id given, only check within same chunk. Otherwise globally.
    """
    from config import DEDUP_TEMPORAL_GAP_DAYS

    # Resolve the effective date for the new fact (event_date takes priority)
    new_date = event_date or document_date

    # Build the temporal filter clause.
    # When new_date is None the clause is always TRUE (cosine-only fallback).
    # When new_date is set, only existing memories within the gap window match.
    temporal_clause = """
        AND (
            %s::date IS NULL
            OR COALESCE(event_date, document_date) IS NULL
            OR ABS(COALESCE(event_date, document_date) - %s::date) < %s
        )
    """
    # Each query needs 3 extra params for the temporal clause
    t_params = (new_date, new_date, DEDUP_TEMPORAL_GAP_DAYS)

    with conn.cursor() as cur:
        # English embedding check
        if source_chunk_id:
            cur.execute(f"""
                SELECT 1 FROM memories
                WHERE status = 'active'
                  AND source_chunk_id = %s::uuid
                  AND 1 - (embedding <=> %s::vector) >= %s
                  {temporal_clause}
                LIMIT 1
            """, (source_chunk_id, str(embedding), threshold) + t_params)
        else:
            cur.execute(f"""
                SELECT 1 FROM memories
                WHERE status = 'active'
                  AND 1 - (embedding <=> %s::vector) >= %s
                  {temporal_clause}
                LIMIT 1
            """, (str(embedding), threshold) + t_params)
        if cur.fetchone() is not None:
            return True

        # Korean embedding check (only if provided)
        if embedding_ko is not None:
            if source_chunk_id:
                cur.execute(f"""
                    SELECT 1 FROM memories
                    WHERE status = 'active'
                      AND embedding_ko IS NOT NULL
                      AND source_chunk_id = %s::uuid
                      AND 1 - (embedding_ko <=> %s::vector) >= %s
                      {temporal_clause}
                    LIMIT 1
                """, (source_chunk_id, str(embedding_ko), threshold) + t_params)
            else:
                cur.execute(f"""
                    SELECT 1 FROM memories
                    WHERE status = 'active'
                      AND embedding_ko IS NOT NULL
                      AND 1 - (embedding_ko <=> %s::vector) >= %s
                      {temporal_clause}
                    LIMIT 1
                """, (str(embedding_ko), threshold) + t_params)
            if cur.fetchone() is not None:
                return True

        return False


def batch_update_hits(conn, updates: list[tuple[str, int]]):
    """Batch update hit_count and last_hit_at for memories.
    updates: list of (memory_id, hit_increment) tuples.
    """
    if not updates:
        return
    with conn.cursor() as cur:
        for memory_id, increment in updates:
            cur.execute("""
                UPDATE memories SET hit_count = hit_count + %s, last_hit_at = now()
                WHERE id = %s::uuid
            """, (increment, memory_id))


def archive_memories_batch(conn, memory_ids: list[str]) -> int:
    """Batch-archive memories by setting status='archived'.

    Uses a single UPDATE WHERE id = ANY(...) for efficiency.
    Only touches rows that are still 'active' (safe to call multiple times).
    Returns the actual number of rows updated.
    """
    if not memory_ids:
        return 0
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE memories SET status = 'archived'
            WHERE id = ANY(%s::uuid[]) AND status = 'active'
              AND hit_count = 0
        """, (memory_ids,))
        return cur.rowcount


def confirm_pending_memories(conn, older_than_hours: int = 24) -> int:
    """Auto-confirm pending memories older than threshold. Returns count."""
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE memories SET status = 'active'
            WHERE status = 'pending'
              AND created_at < now() - (%s * interval '1 hour')
        """, (older_than_hours,))
        return cur.rowcount
