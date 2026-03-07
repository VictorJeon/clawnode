"""bge-m3 embedding client via Ollama with fail-fast routing/circuit-breaker."""
import logging
import threading
import time
import requests
from config import (
    OLLAMA_URLS, EMBEDDING_MODEL,
    EMBED_CONNECT_TIMEOUT_SEC, EMBED_READ_TIMEOUT_SEC,
    EMBED_MAX_RETRIES, EMBED_RETRY_BACKOFF_SEC,
    EMBED_ENDPOINT_COOLDOWN_SEC, EMBED_CIRCUIT_OPEN_SEC,
    EMBED_MAX_INFLIGHT, EMBED_QUEUE_WAIT_SEC,
)

_last_good_url: str | None = None
_endpoint_cooldown_until: dict[str, float] = {}
_circuit_open_until: float = 0.0
_embed_slots = threading.BoundedSemaphore(max(1, EMBED_MAX_INFLIGHT))
_log = logging.getLogger("memory-v2-embeddings")


def _candidate_urls() -> list[str]:
    """Pick candidate endpoints, prioritizing the last healthy endpoint."""
    now = time.time()
    ordered = []
    if _last_good_url and _last_good_url in OLLAMA_URLS:
        ordered.append(_last_good_url)
    ordered.extend([u for u in OLLAMA_URLS if u != _last_good_url])
    if not ordered:
        return []

    healthy = [u for u in ordered if now >= _endpoint_cooldown_until.get(u, 0.0)]
    return healthy


def _request_embeddings(input_payload):
    """POST /api/embed with short timeouts and circuit breaker."""
    global _last_good_url, _circuit_open_until

    now = time.time()
    if now < _circuit_open_until:
        remaining = int(_circuit_open_until - now)
        raise RuntimeError(f"Embedding circuit open ({remaining}s remaining)")

    urls = _candidate_urls()
    if not urls:
        if OLLAMA_URLS:
            _log.warning(
                "All embedding endpoints in cooldown; opening circuit for %ss",
                EMBED_CIRCUIT_OPEN_SEC,
            )
            _circuit_open_until = time.time() + EMBED_CIRCUIT_OPEN_SEC
            raise RuntimeError("No healthy Ollama embedding endpoint (cooldown active)")
        raise RuntimeError("No Ollama embedding endpoint configured")

    if not _embed_slots.acquire(timeout=max(0.0, EMBED_QUEUE_WAIT_SEC)):
        _log.warning(
            "Embedding queue busy (max_inflight=%s, wait=%.2fs)",
            EMBED_MAX_INFLIGHT,
            EMBED_QUEUE_WAIT_SEC,
        )
        raise RuntimeError(f"Embedding queue busy (max_inflight={EMBED_MAX_INFLIGHT})")

    attempts = 1 + max(0, EMBED_MAX_RETRIES)
    last_err = None
    failed_all = True
    try:
        for base_url in urls:
            url = f"{base_url}/api/embed"
            for attempt in range(attempts):
                try:
                    resp = requests.post(
                        url,
                        json={"model": EMBEDDING_MODEL, "input": input_payload},
                        timeout=(EMBED_CONNECT_TIMEOUT_SEC, EMBED_READ_TIMEOUT_SEC),
                    )
                    resp.raise_for_status()
                    data = resp.json()
                    embeddings = data.get("embeddings")
                    if not isinstance(embeddings, list):
                        raise RuntimeError("Malformed embeddings response")
                    _last_good_url = base_url
                    _endpoint_cooldown_until.pop(base_url, None)
                    _circuit_open_until = 0.0
                    failed_all = False
                    return embeddings
                except (
                    requests.exceptions.ConnectionError,
                    requests.exceptions.Timeout,
                    requests.exceptions.HTTPError,
                    requests.exceptions.RequestException,
                    ValueError,
                    RuntimeError,
                ) as e:
                    last_err = e
                    if attempt < attempts - 1:
                        time.sleep(EMBED_RETRY_BACKOFF_SEC * (2 ** attempt))
                    else:
                        _endpoint_cooldown_until[base_url] = time.time() + EMBED_ENDPOINT_COOLDOWN_SEC
    finally:
        if failed_all:
            _circuit_open_until = time.time() + EMBED_CIRCUIT_OPEN_SEC
        _embed_slots.release()

    raise RuntimeError(f"Ollama embedding failed across endpoints: {last_err}")


def embed_batch(texts: list[str], task_type: str = "RETRIEVAL_DOCUMENT") -> list[list[float]]:
    """Batch embed texts via Ollama. task_type kept for API compat but unused."""
    return _request_embeddings(texts)


def embed_query(text: str) -> list[float]:
    """Embed a single query text."""
    embeddings = _request_embeddings(text)
    if not embeddings:
        raise RuntimeError("Empty embedding response")
    return embeddings[0]
