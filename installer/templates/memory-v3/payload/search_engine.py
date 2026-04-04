"""Memory V2 — Hybrid search with RRF fusion + recency/status reranking.
V3 adds memory-first search pipeline on top of V2 chunk search.
"""
import logging
import math
import re
import threading
import time
from datetime import date
from config import (
    RRF_K, DEFAULT_MAX_RESULTS, DEFAULT_SCOPES,
    MEMORY_SCORE_THRESHOLD, MEMORY_SCORE_THRESHOLD_DECAYED,
    MEMORY_MIN_RESULTS, MEMORY_HALFLIFE, MEMORY_HALFLIFE_BY_CATEGORY,
    ENTITY_ALIASES,
)
from embeddings import embed_query
from db import (
    get_conn, put_conn, vector_search, lexical_search, vector_search_memories,
    batch_update_hits,
)

_log = logging.getLogger("search-engine")

# ── Query expansion: inject canonical entity names ──────────────────────────
# Korean-English cross-lingual term mappings for common search patterns
_QUERY_EXPANSIONS = {
    "백필": "backfill",
    "개선": "improvement",
    "개선사항": "improvement roadmap enhancement",
    "로드맵": "roadmap plan",
    "교훈": "lesson learned",
    "진입가": "entry price cap",
    "승률": "win rate",
    "손실": "loss",
    "수익": "profit",
    "봇": "bot",
    "전략": "strategy",
    "검색": "search",
    "메모리": "memory",
    "크론": "cron",
    "하트비트": "heartbeat",
    "백테스트": "backtest",
    "포지션": "position",
    "정산": "settlement",
    "구현": "implementation",
    "완료": "completed done",
    "변경": "change update",
    "설정": "config setting",
    "배포": "deployment deploy",
    "오류": "error bug",
    "수정": "fix patch",
    "기능": "feature function",
    "물어봤": "asked question",
    "답한": "answered response",
    "뭐였": "what was",
}


def _expand_query(query: str) -> str:
    """Expand query with entity aliases and cross-lingual terms.
    Appends canonical names so the embedding covers both languages.
    """
    expansions = []
    query_lower = query.lower()

    # Entity alias expansion: if query mentions an alias, append canonical name
    for alias, canonical in ENTITY_ALIASES.items():
        if alias in query_lower and canonical.lower() not in query_lower:
            expansions.append(canonical)

    # Cross-lingual expansion: Korean→English keywords
    for ko, en in _QUERY_EXPANSIONS.items():
        if ko in query and en.lower() not in query_lower:
            expansions.append(en)

    if expansions:
        # Deduplicate
        seen = set()
        unique = []
        for e in expansions:
            if e.lower() not in seen:
                seen.add(e.lower())
                unique.append(e)
        return query + " " + " ".join(unique)
    return query

# --- Rerank weights ---
W_SIM = 0.50      # semantic similarity (RRF-normalized)
W_BM25 = 0.18     # lexical match (RRF-normalized)
W_RECENCY = 0.15  # recency decay
W_STATUS = 0.17   # status prior (strong enough to override cosine for deprecated)

# Half-life (days) for chunk recency decay
HALFLIFE_DEFAULT = 3    # aligned with memory-level default
HALFLIFE_STABLE = 60    # MEMORY.md, AGENTS.md, USER.md, IDENTITY.md, infra.md etc.
STABLE_PATH_PATTERNS = [
    r'MEMORY\.md$', r'AGENTS\.md$', r'USER\.md$', r'SOUL\.md$',
    r'IDENTITY\.md$', r'infra\.md$', r'CREDENTIAL',
]

# Status priors (default intent = current-state)
STATUS_PRIOR = {"active": 1.0, "deprecated": 0.15, "failed": 0.15}
# Inverted for postmortem intent
STATUS_PRIOR_POSTMORTEM = {"active": 0.4, "deprecated": 0.8, "failed": 1.0}

# Intent detection keywords
POSTMORTEM_KEYWORDS = [
    '실패', '왜 망', '교훈', 'postmortem', 'lesson', '장애', '사건',
    'incident', '오판', '착각', 'what went wrong', 'root cause',
    '제거 이유', '왜 제거', '왜 삭제', '왜 폐기', '변경 이유', '롤백',
    '문제점', '장벽', '실수', 'mistake', 'error', '손실',
    '안 되는지', '하면 안', '금지', '위험',
]
CURRENT_STATE_KEYWORDS = [
    '현재', '지금', '현행', 'current', 'active', 'latest', '최신',
    '운영 중', '라이브', 'live', '설정', '구성', '상태',
]

CONVERSATION_RECALL_KEYWORDS = [
    '아까', '방금', '대화', '말했', '얘기', '세션', 'session',
    'jsonl', '지난 대화', '위에서 말', '직전에', 'what did i say',
]

# Keep current-mode precision high by down-weighting chat transcript chunks.
SESSION_SOURCE_TYPES = {'session', 'session_live'}
SOURCE_GATE_DEFAULT = {
    'core_md': 1.0,
    'memory_md': 0.95,
    'daily_log': 0.92,
    'project_md': 0.90,
    'session': 0.60,
    'session_live': 0.65,
}
SOURCE_GATE_CURRENT_NO_CONV = {
    'session': 0.30,
    'session_live': 0.35,
}

MIN_SCORE_CURRENT = 0.60
MIN_SCORE_POSTMORTEM = 0.54
MIN_SCORE_DEGRADED = 0.72        # stricter when lexical-only (no embeddings)

# V3 merge: penalize raw chunk results so they don't outrank memories/snapshots
CHUNK_SCORE_PENALTY = 0.82       # multiplicative; snapshots & memories stay at 1.0


def _detect_intent(query: str) -> str:
    """Detect query intent: 'current' or 'postmortem'."""
    q = query.lower()
    pm_hits = sum(1 for kw in POSTMORTEM_KEYWORDS if kw in q)
    cs_hits = sum(1 for kw in CURRENT_STATE_KEYWORDS if kw in q)
    if pm_hits > cs_hits and pm_hits >= 1:
        return "postmortem"
    return "current"


def _is_conversation_recall_query(query: str) -> bool:
    q = query.lower()
    return any(kw in q for kw in CONVERSATION_RECALL_KEYWORDS)


def _source_gate_for(source_type: str, intent: str, conversation_query: bool,
                     source_date: date | None = None, today: date | None = None) -> float:
    gate = SOURCE_GATE_DEFAULT.get(source_type, 0.85)

    if source_type in SESSION_SOURCE_TYPES:
        # For explicit conversation recall, let transcripts compete normally.
        if conversation_query:
            return 1.0

        if intent == "current" and not conversation_query:
            # Today's transcripts are likely the freshest source of truth
            # (memory/*.md only updates once daily via distill cron).
            # Older transcripts are downweighted since they should already be distilled.
            if source_date and today and source_date >= today:
                gate = 0.85  # near-parity with memory_md
            else:
                gate = SOURCE_GATE_CURRENT_NO_CONV.get(source_type, gate)

    return gate


def _recency_decay(source_date: date | None, path: str, today: date) -> float:
    """Exponential decay based on age. Returns 0.0-1.0."""
    if source_date is None:
        return 0.5  # unknown date → neutral

    age_days = max(0, (today - source_date).days)

    # Determine half-life based on path
    halflife = HALFLIFE_DEFAULT
    for pat in STABLE_PATH_PATTERNS:
        if re.search(pat, path):
            halflife = HALFLIFE_STABLE
            break

    return math.exp(-math.log(2) * age_days / halflife)


def _normalize_rrf_scores(scores: dict[str, float]) -> dict[str, float]:
    """Min-max normalize RRF scores to 0-1."""
    if not scores:
        return {}
    vals = list(scores.values())
    mn, mx = min(vals), max(vals)
    rng = mx - mn if mx != mn else 1.0
    return {k: (v - mn) / rng for k, v in scores.items()}


def hybrid_search(
    query: str,
    scopes: list[str] = None,
    max_results: int = None,
    intent: str = None,
    embedding: list[float] | None = None,
    embed_error: Exception | None = None,
) -> dict:
    """Run hybrid vector + BM25 search with recency/status-aware reranking."""
    scopes = scopes or DEFAULT_SCOPES
    max_results = max_results or DEFAULT_MAX_RESULTS
    t0 = time.time()

    # Detect intent
    detected_intent = intent or _detect_intent(query)
    conversation_query = _is_conversation_recall_query(query)
    status_prior = STATUS_PRIOR_POSTMORTEM if detected_intent == "postmortem" else STATUS_PRIOR

    # Expand query with entity aliases + cross-lingual terms and try embedding.
    # If embedding fails, continue with lexical-only fallback.
    embed_t0 = time.time()
    if embedding is None and embed_error is None:
        expanded_query = _expand_query(query)
        try:
            embedding = embed_query(expanded_query)
        except Exception as e:
            embed_error = e
            _log.warning("embedding failed; using lexical-only fallback: %s", e)
    embed_ms = int((time.time() - embed_t0) * 1000)

    conn = get_conn()
    try:
        v_results = vector_search(conn, embedding, scopes) if embedding is not None else []
        l_results = lexical_search(conn, query, scopes)

        # Fetch status + source_date for all candidate chunks
        all_chunk_ids = set()
        for row in v_results:
            all_chunk_ids.add(str(row[0]))
        for row in l_results:
            all_chunk_ids.add(str(row[0]))

        chunk_meta_db = {}
        if all_chunk_ids:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT c.id, c.status, c.status_confidence, c.source_date, d.source_type
                    FROM memory_chunks c
                    JOIN memory_documents d ON c.document_id = d.id
                    WHERE c.id = ANY(%s::uuid[])
                    """,
                    (list(all_chunk_ids),)
                )
                for row in cur.fetchall():
                    chunk_meta_db[str(row[0])] = {
                        "status": row[1] or "active",
                        "status_confidence": row[2] or 0.5,
                        "source_date": row[3],
                        "source_type": row[4] or "memory_md",
                    }
    finally:
        put_conn(conn)

    # Phase 1: RRF fusion (sim + bm25 separate for rerank)
    sim_scores = {}
    bm25_scores = {}
    meta = {}

    for rank, row in enumerate(v_results):
        cid = str(row[0])
        sim_scores[cid] = 1.0 / (RRF_K + rank + 1)
        meta[cid] = {
            "content": row[1],
            "tokens": row[2],
            "path": row[3],
            "namespace": row[4],
            "chunk_index": row[5],
            "source_type": row[6],
            "cosine": round(float(row[7]), 4),
        }

    for rank, row in enumerate(l_results):
        cid = str(row[0])
        bm25_scores[cid] = 1.0 / (RRF_K + rank + 1)
        if cid not in meta:
            meta[cid] = {
                "content": row[1],
                "tokens": row[2],
                "path": row[3],
                "namespace": row[4],
                "chunk_index": row[5],
                "source_type": row[6],
                "cosine": None,
            }
        meta[cid]["bm25"] = round(float(row[7]), 4)

    # Phase 2: Normalize + rerank
    all_cids = set(sim_scores) | set(bm25_scores)
    sim_norm = _normalize_rrf_scores(sim_scores)
    bm25_norm = _normalize_rrf_scores(bm25_scores)
    today = date.today()

    final_scores = {}
    for cid in all_cids:
        s = sim_norm.get(cid, 0.0)
        b = bm25_norm.get(cid, 0.0)

        db_meta = chunk_meta_db.get(cid, {})
        src_date = db_meta.get("source_date")
        status = db_meta.get("status", "active")
        source_type = db_meta.get("source_type") or meta[cid].get("source_type") or "memory_md"
        path = meta[cid]["path"] or ""

        r = _recency_decay(src_date, path, today)
        st = status_prior.get(status, 0.5)
        source_gate = _source_gate_for(source_type, detected_intent, conversation_query,
                                       source_date=src_date, today=today)

        base = W_SIM * s + W_BM25 * b + W_RECENCY * r + W_STATUS * st
        final_scores[cid] = base * source_gate

    # Threshold: stricter when degraded (lexical-only) to suppress weak matches
    degraded = embedding is None
    if degraded:
        threshold = MIN_SCORE_DEGRADED
    elif detected_intent == "postmortem":
        threshold = MIN_SCORE_POSTMORTEM
    else:
        threshold = MIN_SCORE_CURRENT
    filtered = [(cid, sc) for cid, sc in final_scores.items() if sc >= threshold]

    ranked = sorted(filtered, key=lambda x: x[1], reverse=True)[:max_results]
    if not ranked and not degraded:
        # Graceful fallback if threshold is too strict — but ONLY when embeddings
        # are available. When degraded, returning junk is worse than returning nothing.
        ranked = sorted(final_scores.items(), key=lambda x: x[1], reverse=True)[:max_results]

    total_ms = int((time.time() - t0) * 1000)

    results = []
    for cid, score in ranked:
        m = meta[cid]
        db_m = chunk_meta_db.get(cid, {})
        source_type = db_m.get("source_type") or m.get("source_type") or "memory_md"
        results.append({
            "chunkId": cid,
            "score": round(score, 4),
            "cosine": m.get("cosine"),
            "bm25": m.get("bm25"),
            "recency": round(_recency_decay(db_m.get("source_date"), m["path"] or "", today), 4),
            "status": db_m.get("status", "active"),
            "sourceType": source_type,
            "sourceGate": round(_source_gate_for(source_type, detected_intent, conversation_query,
                                                source_date=db_m.get("source_date"), today=today), 3),
            "path": m["path"],
            "namespace": m["namespace"],
            "chunkIndex": m["chunk_index"],
            "tokens": m["tokens"],
            "text": m["content"],
        })

    return {
        "results": results,
        "intent": detected_intent,
        "latencyMs": total_ms,
        "embedMs": embed_ms,
        "vectorHits": len(v_results),
        "lexicalHits": len(l_results),
        "degraded": embedding is None,
        "embedError": str(embed_error) if embed_error else None,
    }


# ── Hit buffer (flush to DB periodically) ────────────────────────────────────

_hit_buffer: dict[str, int] = {}
_hit_lock = threading.Lock()
_hit_flush_started = False

HIT_FLUSH_INTERVAL = 60  # seconds
HIT_FLUSH_THRESHOLD = 50  # flush when buffer reaches this size


def _record_hits(memory_ids: list[str]):
    """Record memory hits in the in-memory buffer (thread-safe)."""
    with _hit_lock:
        for mid in memory_ids:
            _hit_buffer[mid] = _hit_buffer.get(mid, 0) + 1


def _flush_hit_buffer():
    """Flush accumulated hits to DB. Called periodically by daemon thread."""
    with _hit_lock:
        if not _hit_buffer:
            return
        updates = list(_hit_buffer.items())
        _hit_buffer.clear()

    if not updates:
        return

    conn = get_conn()
    try:
        batch_update_hits(conn, updates)
        conn.commit()
    except Exception as e:
        _log.warning("Hit buffer flush failed: %s", e)
        try:
            conn.rollback()
        except Exception:
            pass
    finally:
        put_conn(conn)


def _hit_flush_loop():
    """Daemon thread loop: flush hit buffer every HIT_FLUSH_INTERVAL seconds."""
    while True:
        time.sleep(HIT_FLUSH_INTERVAL)
        try:
            _flush_hit_buffer()
        except Exception as e:
            _log.warning("Hit flush loop error: %s", e)


def start_hit_flush_thread():
    """Start the hit buffer flush daemon thread (idempotent).
    Should be called once during FastAPI lifespan startup.
    """
    global _hit_flush_started
    if _hit_flush_started:
        return
    _hit_flush_started = True
    t = threading.Thread(target=_hit_flush_loop, daemon=True, name="hit-flush")
    t.start()
    _log.info("Hit buffer flush thread started (interval=%ds)", HIT_FLUSH_INTERVAL)


# ── Category boost ───────────────────────────────────────────────────────────

_CATEGORY_PATTERNS = {
    "state": re.compile(
        r'현재|상태|current|active|설정|구성', re.IGNORECASE
    ),
    "lesson": re.compile(
        r'교훈|lesson|실수|mistake', re.IGNORECASE
    ),
    "decision": re.compile(
        r'결정|decided|채택', re.IGNORECASE
    ),
    "metric": re.compile(
        r'수치|숫자|how much|몇|shares|가격', re.IGNORECASE
    ),
    "transaction": re.compile(
        r'매수|매도|bought|sold|주식|포지션', re.IGNORECASE
    ),
}
CATEGORY_BOOST = 1.2


def _detect_category_boost(query: str) -> dict[str, float]:
    """Detect preferred category from query. Returns {category: boost_factor}."""
    boosts: dict[str, float] = {}
    for cat, pattern in _CATEGORY_PATTERNS.items():
        if pattern.search(query):
            boosts[cat] = CATEGORY_BOOST
    return boosts


# ── V3: Memory-first search ───────────────────────────────────────────────────

def search_memories(query: str, embedding: list[float], scopes: list[str],
                    max_results: int = 8) -> list[dict]:
    """
    Stage 1 of V3 pipeline: vector search on memories table (active only).
    Applies decay scoring and category boost.
    Deduplicates: same source_chunk → keep highest score.
    Returns list of result dicts with V2-compatible + V3-extra fields.
    """
    conn = get_conn()
    try:
        rows = vector_search_memories(conn, embedding, scopes, limit=max_results * 3)
    finally:
        put_conn(conn)

    # rows is now a list of dicts (keys from _MEMORY_COLS in db.py):
    #   id, fact, fact_ko, context, source_path, namespace, entity, category,
    #   event_date, source_chunk_id, status, superseded_by, hit_count, created_at,
    #   document_date, score
    today = date.today()
    category_boosts = _detect_category_boost(query)

    scored_results = []
    seen_chunk_ids: set[str] = set()

    for row in rows:
        mem_id = str(row['id'])
        fact = row['fact']
        context = row['context']
        source_path = row['source_path']
        namespace = row['namespace']
        entity = row['entity']
        category = row['category']
        event_date = row['event_date']
        source_chunk_id = str(row['source_chunk_id']) if row['source_chunk_id'] else None
        status = row['status']
        superseded_by = str(row['superseded_by']) if row['superseded_by'] else None
        cosine = float(row['score'])
        hit_count = int(row['hit_count']) if row['hit_count'] else 0
        created_at = row['created_at']
        document_date = row['document_date']

        # Diversity: one memory per source chunk
        if source_chunk_id:
            if source_chunk_id in seen_chunk_ids:
                continue
            seen_chunk_ids.add(source_chunk_id)

        # Age source: event_date → document_date → created_at (fallback chain)
        age_date = None
        if event_date and hasattr(event_date, 'isoformat'):
            age_date = event_date if hasattr(event_date, 'days') or hasattr(event_date, 'year') else None
        if age_date is None and document_date and hasattr(document_date, 'isoformat'):
            age_date = document_date if hasattr(document_date, 'year') else None
        if age_date is None and created_at:
            age_date = created_at.date() if hasattr(created_at, 'date') else created_at

        # Decay: exp(-ln(2) * age_days / halflife) — category-aware
        halflife = MEMORY_HALFLIFE_BY_CATEGORY.get(category, MEMORY_HALFLIFE)
        if age_date:
            try:
                age_days = max(0, (today - age_date).days)
            except TypeError:
                age_days = 0
            decay = math.exp(-math.log(2) * age_days / halflife)
        else:
            decay = 0.5  # unknown age → neutral

        # Boost: 1.0 + min(hit_count, 20) * 0.01 (capped at 1.2x)
        boost = 1.0 + min(hit_count, 20) * 0.01

        # Final score
        final_score = cosine * decay * boost

        # Category boost (soft, after decay)
        cat_boost = category_boosts.get(category, 1.0) if category else 1.0
        final_score *= cat_boost

        scored_results.append({
            # V2-compatible fields
            "chunkId": source_chunk_id,
            "score": round(final_score, 4),
            "cosine": round(cosine, 4),
            "bm25": None,
            "recency": round(decay, 4),
            "status": status,
            "sourceType": "memory",
            "sourceGate": 1.0,
            "path": source_path or "",
            "namespace": namespace,
            "chunkIndex": None,
            "tokens": len(fact.split()) if fact else 0,
            "text": context or fact,
            # V3 extra fields
            "resultType": "memory",
            "memoryId": mem_id,
            "fact": fact,
            "entity": entity,
            "category": category,
            "eventDate": event_date.isoformat() if hasattr(event_date, 'isoformat') else str(event_date) if event_date else None,
            "supersedes": superseded_by,
            "sourceChunkId": source_chunk_id,
        })

    # Re-sort by final_score (decay may reorder results)
    scored_results.sort(key=lambda x: x["score"], reverse=True)
    results = scored_results[:max_results]

    # Record hits for returned memories (async via buffer)
    hit_ids = [r["memoryId"] for r in results if r.get("memoryId")]
    if hit_ids:
        _record_hits(hit_ids)
        # Flush early if buffer is large
        with _hit_lock:
            buf_size = len(_hit_buffer)
        if buf_size >= HIT_FLUSH_THRESHOLD:
            threading.Thread(target=_flush_hit_buffer, daemon=True).start()

    return results


# ── Snapshot relevance gate ────────────────────────────────────────────────
# Generic status words that inflate cosine similarity for snapshots.
# If a snapshot *only* matches on these and the query doesn't name the
# entity, it's almost certainly irrelevant.
_SNAPSHOT_GENERIC_WORDS = frozenset({
    "current", "status", "progress", "active", "recent", "decision",
    "qa", "state", "update", "plan", "roadmap", "migration",
    "improvement", "fix", "bug", "deploy", "deployment", "test",
    "config", "setting", "feature", "implementation", "change",
    "monitoring", "alert", "infra", "pipeline", "cron",
    # Korean equivalents
    "현재", "상태", "진행", "활성", "최근", "결정", "업데이트",
    "계획", "로드맵", "개선", "수정", "배포", "테스트", "설정",
})

SNAPSHOT_COSINE_THRESHOLD = 0.58     # higher than old 0.5 — require stronger match
SNAPSHOT_ENTITY_MISS_PENALTY = 0.70  # multiplicative penalty when query doesn't name entity


def _query_mentions_entity(query: str, entity: str) -> bool:
    """Check if the query plausibly references the snapshot's entity.
    Checks: exact substring, aliases, and known canonical names.
    """
    q_lower = query.lower()
    e_lower = entity.lower()

    # Direct mention (substring)
    if e_lower in q_lower:
        return True

    # Check both directions of ENTITY_ALIASES
    for alias, canonical in ENTITY_ALIASES.items():
        if canonical.lower() == e_lower and alias in q_lower:
            return True
        if alias == e_lower and canonical.lower() in q_lower:
            return True

    # Hyphen / space / underscore normalization
    e_variants = {e_lower, e_lower.replace("-", " "), e_lower.replace("_", " "),
                  e_lower.replace("-", ""), e_lower.replace("_", "")}
    for v in e_variants:
        if v in q_lower:
            return True

    return False


def _snapshot_has_strong_overlap(query: str, summary: str) -> bool:
    """Return True if query and snapshot share at least one non-generic
    content word (length ≥ 3), indicating topical relevance beyond
    generic status vocabulary."""
    q_words = set(re.findall(r'\w{3,}', query.lower()))
    s_words = set(re.findall(r'\w{3,}', summary.lower()))
    overlap = q_words & s_words - _SNAPSHOT_GENERIC_WORDS
    return len(overlap) >= 1


def _search_snapshots(query: str, embedding: list[float], scopes: list[str],
                      limit: int = 2) -> list[dict]:
    """Search project_snapshots by vector similarity with entity relevance gate.

    Applies:
      1. Higher cosine threshold (0.58) than the old 0.5
      2. Entity-mention gate: penalizes snapshots when the query doesn't name
         the entity AND there's no strong lexical overlap beyond generic words
      3. Per-entity dedup: only the best snapshot per entity survives
    Returns V2-compatible result dicts.
    """
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, project_name, snapshot_date, summary, key_facts,
                       1 - (embedding <=> %s::vector) AS score
                FROM project_snapshots
                WHERE namespace = ANY(%s)
                ORDER BY embedding <=> %s::vector
                LIMIT %s
            """, (str(embedding), scopes, str(embedding), limit * 3))
            rows = cur.fetchall()
    finally:
        put_conn(conn)

    results = []
    seen_entities: set[str] = set()  # per-entity dedup

    for row in rows:
        snap_id, project, snap_date, summary, key_facts, score = row
        score = float(score)
        if score < SNAPSHOT_COSINE_THRESHOLD:
            continue

        entity_lower = (project or "").lower()

        # Per-entity dedup: keep only the highest-scoring snapshot per entity
        if entity_lower in seen_entities:
            continue

        # Entity relevance gate:
        # If the query doesn't mention this entity AND there's no strong
        # lexical overlap beyond generic words → apply penalty.
        mentions_entity = _query_mentions_entity(query, project or "")
        strong_overlap = _snapshot_has_strong_overlap(query, summary or "")

        effective_score = score
        if not mentions_entity and not strong_overlap:
            effective_score *= SNAPSHOT_ENTITY_MISS_PENALTY

        # After penalty, re-check threshold
        if effective_score < SNAPSHOT_COSINE_THRESHOLD:
            continue

        seen_entities.add(entity_lower)

        results.append({
            "chunkId": None,
            "score": round(effective_score, 4),
            "cosine": round(score, 4),
            "bm25": None,
            "recency": 1.0,  # snapshots are always "current"
            "status": "active",
            "sourceType": "snapshot",
            "sourceGate": 1.0,
            "path": f"snapshot:{project}",
            "namespace": "global",
            "chunkIndex": None,
            "tokens": len(summary.split()),
            "text": summary,
            "resultType": "snapshot",
            "memoryId": None,
            "fact": summary,
            "entity": project,
            "category": "state",
            "eventDate": snap_date.isoformat() if snap_date else None,
            "supersedes": None,
            "sourceChunkId": None,
            "snapshotId": str(snap_id),
            "keyFacts": key_facts,
        })

    # Re-sort by effective score and cap at limit
    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:limit]


def hybrid_search_v3(query: str, scopes: list[str] = None,
                     max_results: int = None, intent: str = None) -> dict:
    """
    V3 memory-first hybrid search.

    Pipeline:
      1. Embed query (shared with V2)
      2. Search memories (active only, vector)
      3. If enough high-quality memory hits → return memories
      4. Else: run chunk fallback (V2 hybrid_search logic)
      5. Merge: memory results first, chunk results fill remaining slots

    Response schema: V2-compatible + V3 extra fields (resultType, memoryId, etc.)
    """
    scopes = scopes or DEFAULT_SCOPES
    max_results = max_results or DEFAULT_MAX_RESULTS
    t0 = time.time()

    detected_intent = intent or _detect_intent(query)

    # Expand query with entity aliases + cross-lingual terms
    expanded_query = _expand_query(query)

    # Embed once, reuse. If embed fails, drop to chunk lexical fallback.
    embed_error: Exception | None = None
    embed_t0 = time.time()
    embedding: list[float] | None = None
    try:
        embedding = embed_query(expanded_query)
    except Exception as e:
        embed_error = e
        _log.warning("V3 embedding failed; using chunk lexical fallback: %s", e)
    embed_ms = int((time.time() - embed_t0) * 1000)

    # Stage 0: snapshot search (for "current state" queries)
    snapshot_results = []
    if embedding is not None and detected_intent == "current":
        try:
            snapshot_results = _search_snapshots(query, embedding, scopes, limit=2)
        except Exception:
            pass  # snapshots table may not exist or be empty

    # Stage 1: memory search
    memory_results = []
    if embedding is not None:
        try:
            memory_results = search_memories(query, embedding, scopes, max_results)
        except Exception as e:
            # V3 tables may not exist yet — gracefully fall back to V2
            import logging
            logging.getLogger("memory-v2").warning("memory search failed (V3 tables ready?): %s", e)

    # Stage 2: decide if chunk fallback needed
    # Use lower threshold since decay reduces scores for older memories
    high_quality = [r for r in memory_results if r["score"] > MEMORY_SCORE_THRESHOLD_DECAYED]
    # Snapshots count as high quality hits
    high_quality_total = len(high_quality) + len(snapshot_results)
    needs_fallback = embedding is None or high_quality_total < MEMORY_MIN_RESULTS
    chunk_results: list[dict] = []

    if needs_fallback:
        # Reduce chunk quota: only fill remaining slots, not the full max_results.
        # This prevents low-quality chunks from flooding results when some
        # memories/snapshots already exist.
        existing_count = len(memory_results) + len(snapshot_results)
        chunk_quota = max(max_results - existing_count, 2)

        # Run V2 chunk search. If embedding failed above, reuse that state so we
        # do not trigger a second embedding attempt.
        chunk_response = hybrid_search(
            query,
            scopes,
            chunk_quota,
            intent=detected_intent,
            embedding=embedding,
            embed_error=embed_error,
        )
        # Annotate chunk results with V3 fields + apply score penalty
        for r in chunk_response.get("results", []):
            if "resultType" not in r:
                r["resultType"] = "chunk"
                r["memoryId"] = None
                r["fact"] = None
                r["entity"] = None
                r["category"] = None
                r["eventDate"] = None
                r["supersedes"] = None
                r["sourceChunkId"] = r.get("chunkId")
                r["score"] = round(r["score"] * CHUNK_SCORE_PENALTY, 4)
        chunk_results = chunk_response.get("results", [])

    # Merge all results, then sort by score (highest first)
    # Entity diversity cap: limit snapshots + memories per entity so one
    # project doesn't monopolize results on generic queries.
    ENTITY_CAP = 3  # max results per entity (snapshots + memories combined)
    seen_chunk_ids: set[str] = set()
    entity_counts: dict[str, int] = {}
    all_candidates: list[dict] = []

    def _accept_entity(r: dict) -> bool:
        """Return True if this result's entity hasn't exceeded the cap."""
        ent = (r.get("entity") or "").lower()
        if not ent:
            return True  # no entity → always accept
        return entity_counts.get(ent, 0) < ENTITY_CAP

    def _track_entity(r: dict):
        ent = (r.get("entity") or "").lower()
        if ent:
            entity_counts[ent] = entity_counts.get(ent, 0) + 1

    # Pre-sort each source by score so entity cap keeps highest-scoring ones
    snapshot_results.sort(key=lambda x: x.get("score", 0), reverse=True)
    memory_results.sort(key=lambda x: x.get("score", 0), reverse=True)

    for r in snapshot_results:
        if _accept_entity(r):
            all_candidates.append(r)
            _track_entity(r)

    for r in memory_results:
        if _accept_entity(r):
            all_candidates.append(r)
            _track_entity(r)
            if r.get("chunkId"):
                seen_chunk_ids.add(r["chunkId"])

    for r in chunk_results:
        cid = r.get("chunkId")
        if cid and cid in seen_chunk_ids:
            continue
        all_candidates.append(r)
        if cid:
            seen_chunk_ids.add(cid)

    # Sort by score descending — best results first regardless of type
    all_candidates.sort(key=lambda x: x.get("score", 0), reverse=True)
    merged = all_candidates[:max_results]
    total_ms = int((time.time() - t0) * 1000)

    if embedding is None:
        source = "chunks_lexical_fallback"
    else:
        source = "memories" if not needs_fallback else ("hybrid_v3" if memory_results else "chunks")

    return {
        "results": merged,
        "intent": detected_intent,
        "latencyMs": total_ms,
        "embedMs": embed_ms,
        "vectorHits": len(memory_results),
        "lexicalHits": len(chunk_results),
        "source": source,
        "memoryHits": len(memory_results),
        "chunkFallback": needs_fallback,
        "degraded": embedding is None,
        "embedError": str(embed_error) if embed_error else None,
    }
