"""Shared LLM helper for enrichment workers.

Historical function names are kept for compatibility, but the current policy is:
- OpenRouter only for enrichment/snapshot/contradiction/backfill LLM calls
- no Ollama fallback
- no Gemini fallback
"""
import json
import re
import logging
import requests

# --- OpenRouter (Primary) ---
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = "qwen/qwen3-235b-a22b-2507"
OPENROUTER_API_KEY = None  # Loaded lazily from Keychain

log = logging.getLogger("llm-helper")


def _get_openrouter_key() -> str:
    """Load OpenRouter API key from Keychain (cached)."""
    global OPENROUTER_API_KEY
    if OPENROUTER_API_KEY:
        return OPENROUTER_API_KEY
    import subprocess
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "openrouter-api-key", "-a", "mason", "-w"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            OPENROUTER_API_KEY = result.stdout.strip()
            return OPENROUTER_API_KEY
    except Exception:
        pass
    # Hardcoded fallback (will be replaced by env var in production)
    import os
    return os.environ.get("OPENROUTER_API_KEY", "")


def _call_openrouter(prompt: str, system: str = "", max_retries: int = 2, timeout: int = 120) -> str:
    """Call OpenRouter API. Returns raw text or empty string."""
    key = _get_openrouter_key()
    if not key:
        log.warning("OpenRouter key unavailable")
        return ""

    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    for attempt in range(max_retries + 1):
        try:
            resp = requests.post(
                OPENROUTER_URL,
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": OPENROUTER_MODEL,
                    "messages": messages,
                    "temperature": 0.1,
                    "max_tokens": 16384,
                },
                timeout=timeout,
            )
            resp.raise_for_status()
            data = resp.json()
            text = data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()
            text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()
            return text
        except Exception as e:
            log.warning("OpenRouter call failed attempt %d: %s", attempt + 1, e)
            if attempt < max_retries:
                import time
                time.sleep(3)

    return ""


def call_ollama(prompt: str, system: str = "", max_retries: int = 2, timeout: int = 180) -> str:
    """Compatibility wrapper: current implementation is OpenRouter-only."""
    return _call_openrouter(prompt, system, max_retries=max_retries, timeout=min(timeout, 120))


def call_ollama_json(prompt: str, system: str = "", max_retries: int = 2) -> list | dict | None:
    """Call LLM and parse JSON response with relaxed extraction."""
    text = call_ollama(prompt, system, max_retries)
    if not text:
        return None

    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r'^```\w*\n?', '', text)
        text = re.sub(r'\n?```$', '', text)

    start = text.find("[") if "[" in text else text.find("{")
    end = max(text.rfind("]"), text.rfind("}"))
    if start != -1 and end != -1 and end > start:
        text = text[start:end+1]

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    relaxed = text.replace("\u201c", '"').replace("\u201d", '"').replace("\u2019", "'")
    relaxed = re.sub(r',\s*([\]}])', r'\1', relaxed)
    try:
        return json.loads(relaxed)
    except json.JSONDecodeError:
        return None


def is_ollama_available() -> bool:
    """Compatibility wrapper: current enrichment backend availability means OpenRouter key exists."""
    return bool(_get_openrouter_key())
