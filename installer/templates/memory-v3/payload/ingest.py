"""Memory V2 — Ingest engine. Reads workspace files, chunks, embeds, stores."""
import logging
import time
from pathlib import Path
from config import WORKSPACES, EMBEDDING_BATCH_SIZE, EXTRA_GLOBAL_FILES
from chunker import chunk_markdown
from embeddings import embed_batch
from db import get_conn, put_conn, upsert_document, insert_chunks, file_hash, enqueue_chunk

log = logging.getLogger("memory-v2")


def ingest_file(conn, filepath: Path, namespace: str, source_type: str,
                tags: list[str] = None) -> int:
    """Ingest a single markdown file. Returns chunk count (0 if unchanged)."""
    if not filepath.exists():
        return 0

    text = filepath.read_text(encoding="utf-8")
    source_hash = file_hash(text)
    rel_path = str(filepath)

    doc_id, is_new = upsert_document(
        conn, namespace, source_type, rel_path, source_hash,
        filepath.name, tags or []
    )

    if not is_new:
        return 0

    chunks = chunk_markdown(text, rel_path)
    if not chunks:
        return 0

    # Embed in batches
    all_embeddings = []
    for i in range(0, len(chunks), EMBEDDING_BATCH_SIZE):
        batch = chunks[i:i + EMBEDDING_BATCH_SIZE]
        texts = [c["content"] for c in batch]
        embeddings = embed_batch(texts)
        all_embeddings.extend(embeddings)
        if i + EMBEDDING_BATCH_SIZE < len(chunks):
            time.sleep(0.2)

    pairs = list(zip(chunks, all_embeddings))
    insert_chunks(conn, doc_id, pairs)

    # V3: enqueue new chunks for async atomization
    # Skip core_md (MEMORY.md, AGENTS.md, etc.) — already curated, atomizing creates duplicates
    if source_type != "core_md":
        _enqueue_new_chunks(conn, doc_id, chunks, namespace, rel_path)

    conn.commit()
    return len(chunks)


def _enqueue_new_chunks(conn, doc_id: str, chunks: list, namespace: str, source_path: str):
    """Add newly inserted chunks to the pending_atomize queue."""
    try:
        # Fetch chunk IDs we just inserted (by doc_id, ordered by chunk_index)
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, source_date FROM memory_chunks WHERE document_id=%s ORDER BY chunk_index",
                (doc_id,)
            )
            rows = cur.fetchall()
        for (chunk_id, source_date), chunk in zip(rows, chunks):
            enqueue_chunk(
                conn,
                chunk_id=str(chunk_id),
                chunk_content=chunk["content"],
                source_path=source_path,
                source_date=source_date,
                namespace=namespace,
            )
    except Exception as e:
        # Queue enqueue must NOT break ingest — log and continue
        log.warning("pending_atomize enqueue failed (non-fatal): %s", e)


def ingest_workspace(namespace: str, workspace: Path) -> dict:
    """Ingest all memory files from a workspace."""
    conn = get_conn()
    stats = {"files": 0, "chunks": 0, "skipped": 0}

    try:
        # Core MD files (global only)
        if namespace == "global":
            for name in ["MEMORY.md", "AGENTS.md", "USER.md", "IDENTITY.md", "SOUL.md"]:
                fp = workspace / name
                n = ingest_file(conn, fp, namespace, "core_md", ["core", name.lower().replace(".md", "")])
                if n:
                    stats["files"] += 1
                    stats["chunks"] += n
                else:
                    stats["skipped"] += 1

        # memory/ directory
        memory_dir = workspace / "memory"
        if memory_dir.exists():
            for f in sorted(memory_dir.glob("*.md")):
                source_type = "daily_log" if f.name[:4].isdigit() else "memory_md"
                tags = ["daily"] if source_type == "daily_log" else ["core", f.stem]
                n = ingest_file(conn, f, namespace, source_type, tags)
                if n:
                    stats["files"] += 1
                    stats["chunks"] += n
                else:
                    stats["skipped"] += 1
    finally:
        put_conn(conn)

    return stats


def ingest_extra_files() -> dict:
    """Ingest extra global files (outside workspaces)."""
    conn = get_conn()
    stats = {"files": 0, "chunks": 0, "skipped": 0}
    try:
        for fp in EXTRA_GLOBAL_FILES:
            if fp.exists():
                tags = ["project", fp.stem.lower()]
                n = ingest_file(conn, fp, "global", "project_md", tags)
                if n:
                    stats["files"] += 1
                    stats["chunks"] += n
                else:
                    stats["skipped"] += 1
    finally:
        put_conn(conn)
    return stats


def ingest_all() -> dict:
    """Full ingest across all workspaces + extra files + active sessions."""
    results = {}
    for namespace, workspace in WORKSPACES.items():
        if workspace.exists():
            results[namespace] = ingest_workspace(namespace, workspace)
    results["extra_global"] = ingest_extra_files()

    # Incremental session ingest (active sessions only)
    try:
        from session_ingest import ingest_active_sessions
        session_results = ingest_active_sessions()
        for ns, stats in session_results.items():
            key = f"{ns}:sessions"
            results[key] = stats
    except Exception as e:
        import logging
        logging.getLogger("memory-v2").error("Session ingest failed: %s", e)
        results["sessions_error"] = str(e)

    return results
