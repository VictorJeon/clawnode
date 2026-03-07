"""Session JSONL incremental ingester for Memory V2.

Indexes active session conversations into pgvector so that
post-compaction memory recall works via V2 search.

Key design:
- Only indexes sessions modified in the last ACTIVE_WINDOW seconds
- Incremental: tracks byte offset per file, only processes new lines
- Only indexes user/assistant message content (skips tool calls, model changes, etc.)
- Groups consecutive messages into conversational chunks for better retrieval
"""
import json
import os
import time
import logging
from pathlib import Path
from config import AGENT_SESSION_DIRS, EMBEDDING_BATCH_SIZE, OFFSET_STATE_FILE
from embeddings import embed_batch
from db import get_conn, put_conn

log = logging.getLogger("memory-v2.session-ingest")

# How recently a file must be modified to be considered "active"
ACTIVE_WINDOW = 3600  # 1 hour

# Track ingested byte offsets: {filepath: last_byte_offset}
_offset_state: dict[str, int] = {}
_offset_loaded = False


def _load_offsets():
    """Load persisted offsets from disk."""
    global _offset_state, _offset_loaded
    if _offset_loaded:
        return
    try:
        OFFSET_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        if OFFSET_STATE_FILE.exists():
            _offset_state = json.loads(OFFSET_STATE_FILE.read_text())
            log.info("Loaded %d session offsets from %s", len(_offset_state), OFFSET_STATE_FILE)
    except Exception as e:
        log.warning("Failed to load session offsets: %s", e)
        _offset_state = {}
    _offset_loaded = True


def _save_offsets():
    """Persist offsets to disk."""
    try:
        OFFSET_STATE_FILE.write_text(json.dumps(_offset_state))
    except Exception as e:
        log.warning("Failed to save session offsets: %s", e)

# Chunk settings
MESSAGES_PER_CHUNK = 6  # Group N messages into one chunk
MAX_CHUNK_CHARS = 2000


def find_active_sessions(sessions_dir: Path, window: int = ACTIVE_WINDOW) -> list[Path]:
    """Find session files modified within the window."""
    if not sessions_dir.exists():
        return []
    cutoff = time.time() - window
    active = []
    for f in sessions_dir.glob("*.jsonl"):
        if f.name.endswith(".deleted") or ".deleted." in f.name:
            continue
        if f.stat().st_mtime > cutoff:
            active.append(f)
    return sorted(active, key=lambda f: f.stat().st_mtime, reverse=True)


def extract_messages(filepath: Path, from_offset: int = 0) -> tuple[list[dict], int]:
    """Read new lines from offset, extract user/assistant messages.
    Returns (messages, new_offset).
    """
    messages = []
    new_offset = from_offset

    with open(filepath, "r", encoding="utf-8") as f:
        f.seek(from_offset)
        for line in f:
            new_offset += len(line.encode("utf-8"))
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if entry.get("type") != "message":
                continue

            msg = entry.get("message", {})
            role = msg.get("role")
            if role not in ("user", "assistant"):
                continue

            content = msg.get("content", "")
            if isinstance(content, list):
                # Extract text parts only
                text_parts = [p.get("text", "") for p in content
                              if isinstance(p, dict) and p.get("type") == "text"]
                text = "\n".join(text_parts)
            else:
                text = str(content)

            if not text.strip():
                continue

            # Skip very long tool results that happen to be in message content
            if len(text) > 10000:
                text = text[:5000] + "\n...[truncated]...\n" + text[-2000:]

            ts = entry.get("timestamp", "")
            messages.append({
                "role": role,
                "text": text,
                "timestamp": ts,
            })

    return messages, new_offset


def messages_to_chunks(messages: list[dict], session_id: str) -> list[dict]:
    """Group messages into conversational chunks for embedding."""
    chunks = []
    buffer = []
    buffer_len = 0

    msg_idx = 0
    for msg in messages:
        prefix = "User" if msg["role"] == "user" else "Assistant"
        line = f"[{prefix}] {msg['text']}"
        line_len = len(line)

        if buffer and (len(buffer) >= MESSAGES_PER_CHUNK or
                       buffer_len + line_len > MAX_CHUNK_CHARS):
            # Flush buffer — use timestamp of first message in this chunk
            chunk_start = msg_idx - len(buffer)
            ts = messages[max(0, chunk_start)].get("timestamp", "")
            chunk_text = "\n\n".join(buffer)
            chunks.append({
                "title": f"Session {session_id}",
                "content": chunk_text,
                "date": ts[:10] if ts else None,
            })
            buffer = []
            buffer_len = 0

        buffer.append(line)
        buffer_len += line_len
        msg_idx += 1

    if buffer:
        chunk_text = "\n\n".join(buffer)
        ts = messages[-1].get("timestamp", "") if messages else ""
        chunks.append({
            "title": f"Session {session_id}",
            "content": chunk_text,
            "date": ts[:10] if ts else None,
        })

    return chunks


def _get_max_ingested_offset(conn, filepath: str, namespace: str) -> int:
    """Check DB for the highest offset already ingested for this file."""
    # source_path format: /path/to/file.jsonl::offset:START-END
    prefix = f"{filepath}::offset:"
    with conn.cursor() as cur:
        cur.execute(
            "SELECT source_path FROM memory_documents WHERE namespace=%s AND source_path LIKE %s ORDER BY source_path DESC LIMIT 1",
            (namespace, prefix + "%")
        )
        row = cur.fetchone()
        if row:
            # Extract END from "...::offset:START-END"
            try:
                return int(row[0].split("-")[-1])
            except (ValueError, IndexError):
                return 0
    return 0


def ingest_session_file(conn, filepath: Path, namespace: str) -> dict:
    """Incrementally ingest a single session file. Returns stats."""
    _load_offsets()
    stats = {"new_messages": 0, "new_chunks": 0, "skipped": False}
    fpath_str = str(filepath)

    # Get previous offset — prefer in-memory, fallback to DB
    prev_offset = _offset_state.get(fpath_str)
    if prev_offset is None:
        prev_offset = _get_max_ingested_offset(conn, fpath_str, namespace)
        if prev_offset > 0:
            _offset_state[fpath_str] = prev_offset
            log.info("Recovered offset %d for %s from DB", prev_offset, filepath.name)

    file_size = filepath.stat().st_size

    if file_size <= prev_offset:
        stats["skipped"] = True
        return stats

    # Extract new messages
    new_messages, new_offset = extract_messages(filepath, prev_offset)
    stats["new_messages"] = len(new_messages)

    if not new_messages:
        _offset_state[fpath_str] = new_offset
        return stats

    # Session ID from filename
    session_id = filepath.stem

    # Build chunks
    chunks = messages_to_chunks(new_messages, session_id)
    if not chunks:
        _offset_state[fpath_str] = new_offset
        return stats

    # Use a unique doc path that includes offset range to avoid conflicts
    doc_source_path = f"{fpath_str}::offset:{prev_offset}-{new_offset}"

    # Embed
    all_embeddings = []
    for i in range(0, len(chunks), EMBEDDING_BATCH_SIZE):
        batch = chunks[i:i + EMBEDDING_BATCH_SIZE]
        texts = [c["content"] for c in batch]
        embeddings = embed_batch(texts)
        all_embeddings.extend(embeddings)
        if i + EMBEDDING_BATCH_SIZE < len(chunks):
            time.sleep(0.1)

    # Store — use direct insert (no dedup since offset-based source_path is unique)
    from uuid import uuid4
    doc_id = str(uuid4())
    with conn.cursor() as cur:
        cur.execute(
            """INSERT INTO memory_documents (id, namespace, source_type, source_path, source_hash, title, tags)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (doc_id, namespace, "session_live", doc_source_path,
             f"offset:{prev_offset}-{new_offset}",
             f"Session {session_id}", ["session", "live"])
        )
        for i, (chunk, embedding) in enumerate(zip(chunks, all_embeddings)):
            token_count = len(chunk["content"].split())
            chunk_date = chunk.get("date")  # YYYY-MM-DD from timestamp
            cur.execute(
                """INSERT INTO memory_chunks (document_id, chunk_index, content, token_count, embedding, source_date)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (doc_id, i, chunk["content"], token_count, str(embedding), chunk_date)
            )
    conn.commit()

    stats["new_chunks"] = len(chunks)
    _offset_state[fpath_str] = new_offset
    _save_offsets()
    log.info("Ingested %d messages (%d chunks) from %s [%d→%d]",
             len(new_messages), len(chunks), filepath.name, prev_offset, new_offset)
    return stats


def ingest_active_sessions() -> dict:
    """Ingest all active sessions across all agents. Called by flush."""
    results = {}
    conn = get_conn()
    try:
        for namespace, sessions_dir in AGENT_SESSION_DIRS.items():
            active_files = find_active_sessions(sessions_dir)
            ns_stats = {"active_files": len(active_files), "new_messages": 0,
                        "new_chunks": 0, "skipped": 0}

            for fpath in active_files[:3]:  # Max 3 active sessions per agent
                try:
                    s = ingest_session_file(conn, fpath, namespace)
                    ns_stats["new_messages"] += s["new_messages"]
                    ns_stats["new_chunks"] += s["new_chunks"]
                    if s["skipped"]:
                        ns_stats["skipped"] += 1
                except Exception as e:
                    log.error("Failed to ingest %s: %s", fpath.name, e)
                    continue

            results[namespace] = ns_stats
    finally:
        put_conn(conn)
    return results
