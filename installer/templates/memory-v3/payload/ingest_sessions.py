"""Memory V2 — Session transcript backfill.

Reads JSONL session files, extracts user/assistant messages,
chunks them into conversation segments, embeds and stores.
"""
import json
import hashlib
import os
import sys
import time
from pathlib import Path
from datetime import datetime, timezone

from config import EMBEDDING_BATCH_SIZE
from chunker import estimate_tokens
from embeddings import embed_batch
from db import get_conn, put_conn, upsert_document, insert_chunks

SESSIONS_DIRS = {
    "agent:nova": Path(os.path.expanduser("~/.openclaw/agents/nova/sessions")),
    "agent:bolt": Path(os.path.expanduser("~/.openclaw/agents/bolt/sessions")),
    "agent:sol": Path(os.path.expanduser("~/.openclaw/agents/sol/sessions")),
}

# Skip sessions older than this
MAX_AGE_DAYS = 90
# Max messages per chunk (conversation segment)
MESSAGES_PER_CHUNK = 10
# Max tokens per chunk
MAX_CHUNK_TOKENS = 500


def extract_messages(filepath: Path) -> list[dict]:
    """Extract user/assistant messages from a JSONL session file."""
    messages = []
    session_date = None

    with open(filepath, "r") as f:
        for line in f:
            try:
                entry = json.loads(line.strip())
            except json.JSONDecodeError:
                continue

            etype = entry.get("type", "")

            # Get session start date
            if etype == "session" and not session_date:
                ts = entry.get("timestamp", "")
                if ts:
                    try:
                        session_date = ts[:10]  # YYYY-MM-DD
                    except:
                        pass

            if etype != "message":
                continue

            msg = entry.get("message", {})
            role = msg.get("role", "")
            if role not in ("user", "assistant"):
                continue

            # Extract text from content
            content = msg.get("content", "")
            if isinstance(content, list):
                text_parts = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        text_parts.append(part.get("text", ""))
                    elif isinstance(part, str):
                        text_parts.append(part)
                text = "\n".join(text_parts)
            elif isinstance(content, str):
                text = content
            else:
                continue

            text = text.strip()
            if not text or len(text) < 20:
                continue

            # Skip tool call noise
            if text.startswith("[tool_") or text.startswith("```json\n{\"tool"):
                continue

            ts = entry.get("timestamp", "")

            messages.append({
                "role": role,
                "text": text,
                "timestamp": ts,
            })

    return messages, session_date


def chunk_conversation(messages: list[dict], session_date: str = None) -> list[dict]:
    """Group messages into conversation chunks."""
    chunks = []
    current_texts = []
    current_tokens = 0

    for msg in messages:
        prefix = "User" if msg["role"] == "user" else "Assistant"
        line = f"[{prefix}]: {msg['text']}"
        line_tokens = estimate_tokens(line)

        if (len(current_texts) >= MESSAGES_PER_CHUNK or
                current_tokens + line_tokens > MAX_CHUNK_TOKENS) and current_texts:
            chunks.append({
                "content": "\n\n".join(current_texts),
                "date": session_date,
                "title": f"Session conversation ({session_date})",
            })
            current_texts = []
            current_tokens = 0

        current_texts.append(line)
        current_tokens += line_tokens

    if current_texts:
        chunks.append({
            "content": "\n\n".join(current_texts),
            "date": session_date,
            "title": f"Session conversation ({session_date})",
        })

    return chunks


def ingest_session_file(conn, filepath: Path, namespace: str) -> int:
    """Ingest a single session file."""
    # Read file hash
    raw = filepath.read_bytes()
    source_hash = hashlib.sha256(raw).hexdigest()[:16]

    doc_id, is_new = upsert_document(
        conn, namespace, "session", str(filepath), source_hash,
        filepath.stem, ["session"]
    )

    if not is_new:
        return 0

    messages, session_date = extract_messages(filepath)
    if not messages:
        conn.commit()
        return 0

    chunks = chunk_conversation(messages, session_date)
    if not chunks:
        conn.commit()
        return 0

    # Embed
    all_embeddings = []
    for i in range(0, len(chunks), EMBEDDING_BATCH_SIZE):
        batch = chunks[i:i + EMBEDDING_BATCH_SIZE]
        texts = [c["content"][:2000] for c in batch]  # Truncate long chunks
        embeddings = embed_batch(texts)
        all_embeddings.extend(embeddings)
        if i + EMBEDDING_BATCH_SIZE < len(chunks):
            time.sleep(0.3)

    insert_chunks(conn, doc_id, list(zip(chunks, all_embeddings)))
    conn.commit()
    return len(chunks)


def backfill_all(max_age_days: int = MAX_AGE_DAYS) -> dict:
    """Backfill all session transcripts."""
    conn = get_conn()
    results = {}

    try:
        for namespace, sessions_dir in SESSIONS_DIRS.items():
            if not sessions_dir.exists():
                continue

            stats = {"files": 0, "chunks": 0, "skipped": 0, "errors": 0}
            files = sorted(sessions_dir.glob("*.jsonl"), key=lambda f: f.stat().st_mtime, reverse=True)

            cutoff = time.time() - (max_age_days * 86400)

            for f in files:
                if f.stat().st_mtime < cutoff:
                    continue

                try:
                    n = ingest_session_file(conn, f, namespace)
                    if n:
                        stats["files"] += 1
                        stats["chunks"] += n
                        print(f"  {namespace}/{f.name}: {n} chunks")
                    else:
                        stats["skipped"] += 1
                except Exception as e:
                    stats["errors"] += 1
                    print(f"  ERROR {namespace}/{f.name}: {e}")

            results[namespace] = stats
    finally:
        put_conn(conn)

    return results


if __name__ == "__main__":
    print("=== Session Backfill ===")
    results = backfill_all()
    print("\n=== Results ===")
    total_chunks = 0
    for ns, s in results.items():
        print(f"  {ns}: {s['files']} files, {s['chunks']} chunks, {s['skipped']} skipped, {s['errors']} errors")
        total_chunks += s["chunks"]
    print(f"\nTotal new chunks: {total_chunks}")
