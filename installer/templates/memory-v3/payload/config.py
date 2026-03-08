"""Memory V2 configuration."""
import os
from pathlib import Path


def _env_path(name: str, default: str = "") -> Path | None:
    raw = os.environ.get(name, default).strip()
    if not raw:
        return None
    return Path(os.path.expanduser(raw))


def _env_paths(name: str) -> list[Path]:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return []
    return [Path(os.path.expanduser(p.strip())) for p in raw.split(os.pathsep) if p.strip()]


def load_google_api_key() -> str:
    key = os.environ.get("GOOGLE_API_KEY", "").strip()
    if key:
        return key

    cfg_path = _env_path("OPENCLAW_CONFIG_PATH", "~/.openclaw/openclaw.json")
    if not cfg_path or not cfg_path.exists():
        return ""

    try:
        import json
        cfg = json.loads(cfg_path.read_text())
        return cfg.get("env", {}).get("vars", {}).get("GOOGLE_API_KEY", "").strip()
    except Exception:
        return ""


# Database
DB_URL = os.environ.get("DATABASE_URL", "dbname=memory_v2")
DB_POOL_MIN = int(os.environ.get("DB_POOL_MIN", "1"))
DB_POOL_MAX = int(os.environ.get("DB_POOL_MAX", "10"))
DB_POOL_WAIT_MS = int(os.environ.get("DB_POOL_WAIT_MS", "5000"))

# Embedding — bge-m3 via Ollama
_ollama_urls_raw = os.environ.get("OLLAMA_URLS") or os.environ.get("OLLAMA_URL") or "http://127.0.0.1:11434"
OLLAMA_URLS = [u.strip().rstrip("/") for u in _ollama_urls_raw.split(",") if u.strip()]
OLLAMA_URL = OLLAMA_URLS[0]
EMBEDDING_MODEL = "bge-m3:latest"
EMBEDDING_DIM = 1024
EMBEDDING_BATCH_SIZE = 8
EMBED_CONNECT_TIMEOUT_SEC = float(os.environ.get("EMBED_CONNECT_TIMEOUT_SEC", "3"))
EMBED_READ_TIMEOUT_SEC = float(os.environ.get("EMBED_READ_TIMEOUT_SEC", "20"))
EMBED_MAX_RETRIES = int(os.environ.get("EMBED_MAX_RETRIES", "2"))
EMBED_RETRY_BACKOFF_SEC = float(os.environ.get("EMBED_RETRY_BACKOFF_SEC", "1.0"))
EMBED_ENDPOINT_COOLDOWN_SEC = int(os.environ.get("EMBED_ENDPOINT_COOLDOWN_SEC", "30"))
EMBED_CIRCUIT_OPEN_SEC = int(os.environ.get("EMBED_CIRCUIT_OPEN_SEC", "10"))
EMBED_MAX_INFLIGHT = int(os.environ.get("EMBED_MAX_INFLIGHT", "8"))
EMBED_QUEUE_WAIT_SEC = float(os.environ.get("EMBED_QUEUE_WAIT_SEC", "0.7"))

# Service paths
SERVICE_ROOT = Path(__file__).resolve().parent
STATE_DIR = _env_path("MEMORY_STATE_DIR", str(SERVICE_ROOT / "state")) or (SERVICE_ROOT / "state")
OFFSET_STATE_FILE = _env_path(
    "MEMORY_SESSION_OFFSET_FILE",
    str(STATE_DIR / "session-offsets.json"),
) or (STATE_DIR / "session-offsets.json")

# Workspaces
WORKSPACES = {}
for namespace, env_name, default in [
    ("global", "MEMORY_WORKSPACE_GLOBAL", "~/.openclaw/workspace"),
    ("agent:bolt", "MEMORY_WORKSPACE_BOLT", ""),
    ("agent:sol", "MEMORY_WORKSPACE_SOL", ""),
]:
    path = _env_path(env_name, default)
    if path:
        WORKSPACES[namespace] = path

AGENT_SESSION_DIRS = {}
for namespace, env_name, default in [
    ("agent:nova", "MEMORY_SESSION_DIR_AGENT_NOVA", "~/.openclaw/agents/nova/sessions"),
    ("agent:bolt", "MEMORY_SESSION_DIR_AGENT_BOLT", ""),
    ("agent:sol", "MEMORY_SESSION_DIR_AGENT_SOL", ""),
]:
    path = _env_path(env_name, default)
    if path:
        AGENT_SESSION_DIRS[namespace] = path

# Chunking
MAX_CHUNK_TOKENS = 400
MIN_CHUNK_TOKENS = 30

# Search
DEFAULT_SCOPES = ["global"]
DEFAULT_MAX_RESULTS = 8
DEFAULT_MIN_SCORE = 0.0
RRF_K = 60

# Extra files to ingest into global namespace
EXTRA_GLOBAL_FILES = _env_paths("MEMORY_EXTRA_GLOBAL_FILES")

# Server
HOST = os.environ.get("MEMORY_HOST", "127.0.0.1")
PORT = int(os.environ.get("MEMORY_PORT", "18790"))

# Atomizer (V3)
ATOMIZER_BATCH_SIZE = 10
ATOMIZER_COMMIT_INTERVAL = 100
ATOMIZER_WORKER_INTERVAL = 60
ATOMIZER_MAX_ATTEMPTS = 3

# Atomizer fact quality gates
FACT_MIN_CHARS = 10
FACT_MAX_CHARS = 200
FACT_DATE_WINDOW_DAYS = 30

# Dedup temporal gap protection
DEDUP_TEMPORAL_GAP_DAYS = 7

# Relation linker thresholds
RELATION_COSINE_THRESHOLD = 0.75
RELATION_JACCARD_THRESHOLD = 0.20

# LLM contradiction detection
CONTRADICTION_LLM_ENABLED = True
CONTRADICTION_LLM_MODEL = "gemini-2.5-flash"
CONTRADICTION_COSINE_THRESHOLD = 0.80
CONTRADICTION_MAX_PAIRS_PER_MEMORY = 3

# V3 search
MEMORY_SCORE_THRESHOLD = 0.70
MEMORY_SCORE_THRESHOLD_DECAYED = 0.50
MEMORY_MIN_RESULTS = 3

# Decay / relevance scoring — category-aware half-lives (days)
MEMORY_HALFLIFE = 3
MEMORY_HALFLIFE_BY_CATEGORY = {
    "state": 3,
    "metric": 3,
    "decision": 14,
    "lesson": 30,
    "factual": 60,
}

# Known entities (for extraction heuristic)
KNOWN_ENTITIES = [
    "polymarket-weather-bot", "weather-bot", "V8", "V7", "V6", "V5",
    "Nova", "Bolt", "Sol", "Mason",
    "memory-v2", "memory-v3", "memory-v1",
    "xitadel", "xitadel-app", "xitadel-keeper",
    "Seoul", "서울", "London", "런던",
    "signal_engine", "signal_engine_v8",
    "Polymarket", "Kalshi",
    "OpenClaw", "openclaw",
    "L1", "L1ForecastEngine",
    "Nova World", "nova-world",
    "Degen Roulette", "solana-roulette",
    "UKMO", "WU", "METAR",
    "Wolsung", "월성비나", "Wolsung VINA",
    "Bella", "Meta Z",
    "Rollup Scanner",
    "claude-realtime", "claude-realtime.sh",
]

# Eviction
EVICTION_AGE_DAYS = 90
SNAPSHOT_ENTITIES = [
    "polymarket-weather-bot", "Nova", "memory-v2", "memory-v3",
    "xitadel", "xitadel-app", "signal_engine", "signal_engine_v8",
    "L1", "nova-world", "Wolsung",
    "V8", "V7", "Seoul", "서울", "Polymarket", "Kalshi",
    "openclaw", "Bolt", "Sol",
]

# Snapshot LLM
SNAPSHOT_LLM_ENABLED = True
SNAPSHOT_LLM_MODEL = "gemini-2.5-flash"

# Entity aliases — map variations to canonical entity name
ENTITY_ALIASES = {
    "fact extraction system": "memory-v3",
    "fact extraction": "memory-v3",
    "atomizer": "memory-v3",
    "atomize": "memory-v3",
    "tier 1": "memory-v3",
    "tier 2": "memory-v3",
    "tier 3": "memory-v3",
    "relation linker": "memory-v3",
    "relation_linker": "memory-v3",
    "decay": "memory-v3",
    "relevance scoring": "memory-v3",
    "query-time reasoning": "memory-v3",
    "active recall": "memory-v3",
    "prefetch plugin": "memory-v3",
    "snapshot generator": "memory-v3",
    "snapshot_generator": "memory-v3",
    "memory server": "memory-v3",
    "l1 forecast": "L1",
    "l1forecastengine": "L1",
    "london l1": "L1",
    "london v8": "V8",
    "seoul v8": "V8",
    "v8.1": "V8",
    "weather bot": "polymarket-weather-bot",
    "weather-bot": "polymarket-weather-bot",
}
