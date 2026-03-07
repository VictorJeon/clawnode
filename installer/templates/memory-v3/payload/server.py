#!/usr/bin/env python3
"""Memory V2/V3 — FastAPI server. Local sidecar for OpenClaw memory."""
import logging
import threading
import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
from config import HOST, PORT, WORKSPACES
from search_engine import hybrid_search, hybrid_search_v3, start_hit_flush_thread, _flush_hit_buffer
from ingest import ingest_all, ingest_workspace
from db import get_conn, put_conn, get_stats, get_queue_status

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("memory-v2")

# ── Relink job store (in-memory, no persistence) ─────────────────────────────
_relink_jobs: dict[str, dict] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("Memory V2 starting on %s:%d", HOST, PORT)
    start_hit_flush_thread()
    yield
    log.info("Memory V2 shutting down — flushing hit buffer")
    _flush_hit_buffer()


app = FastAPI(title="Memory V2", version="0.1.0", lifespan=lifespan)


# --- Models ---
class SearchRequest(BaseModel):
    query: str
    scopes: list[str] | None = None
    maxResults: int | None = None
    legacy: bool = False   # legacy=True → V2 chunk-only search

class IngestRequest(BaseModel):
    namespace: str | None = None  # None = all

class FlushRequest(BaseModel):
    namespace: str | None = None


# --- Routes ---
@app.get("/health")
def health():
    return {"status": "ok", "service": "memory-v2"}


@app.post("/v1/memory/search")
def search(req: SearchRequest):
    """Hybrid search. V3 memory-first by default; legacy=true for V2 chunk-only."""
    if not req.query.strip():
        raise HTTPException(400, "query required")
    try:
        if req.legacy:
            return hybrid_search(req.query, req.scopes, req.maxResults)
        return hybrid_search_v3(req.query, req.scopes, req.maxResults)
    except (RuntimeError, ConnectionError, TimeoutError, psycopg2.Error) as e:
        # Memory server must fail soft so chat latency doesn't collapse when
        # embedding backend or DB is unhealthy.
        log.error("search failed: %s", e, exc_info=True)
        return {
            "results": [],
            "intent": "unknown",
            "latencyMs": 0,
            "embedMs": 0,
            "vectorHits": 0,
            "lexicalHits": 0,
            "source": "error",
            "memoryHits": 0,
            "chunkFallback": True,
            "degraded": True,
            "error": str(e),
        }


@app.post("/v1/memory/ingest")
def ingest(req: IngestRequest):
    """Trigger ingest for one or all namespaces."""
    if req.namespace:
        ws = WORKSPACES.get(req.namespace)
        if not ws:
            raise HTTPException(400, f"unknown namespace: {req.namespace}")
        stats = ingest_workspace(req.namespace, ws)
        return {"namespace": req.namespace, **stats}
    else:
        results = ingest_all()
        return {"namespaces": results}


@app.post("/v1/memory/flush")
def flush(req: FlushRequest):
    """Alias for ingest (incremental — only changed files re-indexed) + auto-label."""
    result = ingest(IngestRequest(namespace=req.namespace))
    # Run auto-labeling after ingest
    try:
        from auto_label import run_auto_label
        label_stats = run_auto_label()
        result["autoLabel"] = label_stats
    except Exception as e:
        log.error("Auto-label failed: %s", e)
        result["autoLabelError"] = str(e)
    return result


@app.get("/v1/memory/stats")
def stats():
    """Index statistics (V2 chunks + V3 memories/relations if migrated)."""
    conn = get_conn()
    try:
        return get_stats(conn)
    finally:
        put_conn(conn)


@app.get("/v1/memory/queue/status")
def queue_status():
    """Return pending_atomize queue counts by status."""
    conn = get_conn()
    try:
        return get_queue_status(conn)
    except Exception as e:
        raise HTTPException(500, f"Queue status error (V3 migrated?): {e}")
    finally:
        put_conn(conn)


class AtomizeRequest(BaseModel):
    limit: int = 0   # 0 = unlimited


@app.post("/v1/memory/atomize")
def atomize(req: AtomizeRequest):
    """
    Manually trigger atomization of pending queue.
    Runs synchronously — use sparingly; prefer atomize_worker daemon for bulk.
    """
    try:
        from atomize_worker import run_once
        result = run_once(limit=req.limit)
        return result
    except Exception as e:
        raise HTTPException(500, str(e))


@app.post("/v1/memory/snapshots/generate")
def generate_snapshots(entity: str | None = None):
    """Generate project state snapshots (all or specific entity)."""
    try:
        from snapshot_generator import generate_snapshot, generate_all_snapshots
        conn = get_conn()
        try:
            if entity:
                result = generate_snapshot(conn, entity)
                conn.commit()
                return result or {"message": f"No recent memories for {entity}"}
            else:
                results = generate_all_snapshots(conn)
                return {"snapshots": results, "count": len(results)}
        finally:
            put_conn(conn)
    except Exception as e:
        raise HTTPException(500, str(e))


@app.get("/v1/memory/entity/{name}")
def entity_memories(name: str, namespace: str = "global"):
    """Return all active memories for a named entity."""
    conn = get_conn()
    try:
        from db import get_memories_by_entity
        rows = get_memories_by_entity(conn, name, namespace, status="active")
        # Convert date objects for JSON
        for r in rows:
            for k, v in r.items():
                if hasattr(v, 'isoformat'):
                    r[k] = v.isoformat()
        return {"entity": name, "namespace": namespace, "count": len(rows), "memories": rows}
    except Exception as e:
        raise HTTPException(500, str(e))
    finally:
        put_conn(conn)


# ── Async relink endpoints ───────────────────────────────────────────────────

class RelinkRequest(BaseModel):
    dry_run: bool = False


def _run_relink_job(job_id: str, dry_run: bool):
    """Background thread for relink job."""
    _relink_jobs[job_id]["status"] = "running"
    try:
        from atomize_worker import run_link_pass
        stats = run_link_pass(dry_run=dry_run)
        _relink_jobs[job_id]["status"] = "completed"
        _relink_jobs[job_id]["result"] = stats
    except Exception as e:
        _relink_jobs[job_id]["status"] = "failed"
        _relink_jobs[job_id]["error"] = str(e)
        log.error("Relink job %s failed: %s", job_id, e)


@app.post("/v1/memory/relink", status_code=202)
def relink(req: RelinkRequest):
    """Start async relink job. Returns 202 + job_id."""
    job_id = str(uuid.uuid4())[:8]
    _relink_jobs[job_id] = {
        "status": "queued",
        "dry_run": req.dry_run,
        "result": None,
        "error": None,
    }
    t = threading.Thread(
        target=_run_relink_job, args=(job_id, req.dry_run),
        daemon=True, name=f"relink-{job_id}",
    )
    t.start()
    return {"job_id": job_id, "status": "queued"}


@app.get("/v1/memory/relink/{job_id}")
def relink_status(job_id: str):
    """Poll relink job status."""
    job = _relink_jobs.get(job_id)
    if not job:
        raise HTTPException(404, f"job {job_id} not found")
    return {"job_id": job_id, **job}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host=HOST, port=PORT, log_level="info")
