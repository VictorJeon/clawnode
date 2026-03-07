"""Memory V3 — LLM snapshot summary generator.

Uses Gemini Flash to produce a high-quality narrative summary of an
entity's recent memories. Called from snapshot_generator.generate_snapshot()
when SNAPSHOT_LLM_ENABLED is True.

Design:
- One API call per entity per day (enforced via input hash skip in caller)
- Falls back to rule-based summary on any failure
- Output capped at 500 unicode chars
"""
import json
import logging
import os
import re

import requests

log = logging.getLogger("snapshot.llm")

# ── API setup ─────────────────────────────────────────────────────────────────

def _load_google_api_key() -> str:
    """Resolve GOOGLE_API_KEY from env."""
    return os.environ.get("GOOGLE_API_KEY", "")

_MAX_RETRIES = 1
_SUMMARY_MAX_CHARS = 500

# ── Prompt ────────────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are a project state summarizer. Given a list of recent memories about a project or entity, \
write a concise current-state narrative in Korean (한국어) or mixed Korean/English as appropriate.

Requirements:
- Reflect temporal changes ("X에서 Y로 변경됨", "이전에는 A였으나 현재 B임")
- Include key metrics and numbers when present
- Reflect the most recent decisions
- Omit minor or redundant details
- Write as a single flowing paragraph (no bullet points, no headers)
- Maximum 450 characters (Unicode). Be concise.

Output ONLY a JSON object: {"summary": "..."}
No markdown fencing, no explanation.\
"""


def _format_memories(memories: list[dict]) -> str:
    """Format memory list for the LLM prompt."""
    lines = []
    for m in memories:
        date_str = str(m.get("event_date") or m.get("document_date") or "날짜미상")
        category = m.get("category", "factual")
        fact = m.get("fact", "").strip()
        lines.append(f"[{category}, {date_str}] {fact}")
    return "\n".join(lines)


# ── JSON parser ───────────────────────────────────────────────────────────────

def _parse_json_relaxed(raw: str) -> dict:
    """Parse LLM output with multiple fallback strategies (mirrors llm_atomizer pattern)."""
    # Normalize smart quotes
    raw = raw.replace("\u201c", '"').replace("\u201d", '"').replace("\u2019", "'")
    # Remove trailing commas before } / ]
    raw = re.sub(r',\s*([\]}])', r'\1', raw)

    # 1) Strict parse
    try:
        result = json.loads(raw)
        if isinstance(result, dict):
            return result
    except Exception:
        pass

    # 2) Extract first {...} block
    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end > start:
        try:
            result = json.loads(raw[start:end + 1])
            if isinstance(result, dict):
                return result
        except Exception:
            pass

    # 3) Regex extract summary value directly
    m = re.search(r'"summary"\s*:\s*"((?:[^"\\]|\\.)*)"', raw, re.DOTALL)
    if m:
        return {"summary": m.group(1)}

    raise ValueError(f"Cannot parse LLM output as JSON. First 200 chars: {raw[:200]}")


# ── Main public function ───────────────────────────────────────────────────────

def generate_llm_summary(
    entity: str,
    memories: list[dict],
    model: str,
) -> str | None:
    """Generate an LLM narrative summary for an entity's recent memories.

    Args:
        entity: Entity name (e.g. "memory-v3", "xitadel").
        memories: List of memory dicts with keys: fact, category, event_date, document_date.
        model: Gemini model name from config (e.g. "gemini-2.5-flash").

    Returns:
        Summary string (≤500 chars), or None on failure (caller should fall back).
    """
    api_key = _load_google_api_key()
    if not api_key:
        log.error("GOOGLE_API_KEY not set — LLM snapshot skipped, falling back to rule-based")
        return None

    if not memories:
        return None

    memory_text = _format_memories(memories)
    user_prompt = (
        f"Entity: {entity}\n\n"
        f"Recent memories ({len(memories)} total):\n"
        f"{memory_text}\n\n"
        "Summarize the current state of this entity."
    )

    api_url = (
        f"https://generativelanguage.googleapis.com/v1beta/models"
        f"/{model}:generateContent"
    )
    payload = {
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "systemInstruction": {"parts": [{"text": _SYSTEM_PROMPT}]},
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 512,
            "responseMimeType": "application/json",
        },
    }

    for attempt in range(_MAX_RETRIES + 1):
        try:
            resp = requests.post(
                f"{api_url}?key={api_key}",
                json=payload,
                timeout=45,
            )
            if resp.status_code == 429:
                log.warning("LLM snapshot: rate limited (attempt %d)", attempt + 1)
                import time
                time.sleep(5 * (attempt + 1))
                continue
            resp.raise_for_status()

            data = resp.json()
            candidates_list = data.get("candidates") or []
            if not candidates_list:
                finish_reason = (data.get("promptFeedback") or {}).get("blockReason", "unknown")
                log.warning("LLM snapshot: empty candidates for %s (reason: %s)", entity, finish_reason)
                return None
            text = candidates_list[0]["content"]["parts"][0]["text"].strip()

            # Strip markdown fencing if present
            if text.startswith("```"):
                text = re.sub(r'^```\w*\n?', '', text)
                text = re.sub(r'\n?```$', '', text.strip())

            parsed = _parse_json_relaxed(text)
            summary = str(parsed.get("summary", "")).strip()

            if not summary:
                log.warning("LLM snapshot: empty summary for %s", entity)
                return None

            # Enforce 500-char limit
            if len(summary) > _SUMMARY_MAX_CHARS:
                log.debug(
                    "LLM snapshot: summary truncated %d→%d chars for %s",
                    len(summary), _SUMMARY_MAX_CHARS, entity,
                )
                summary = summary[:_SUMMARY_MAX_CHARS]

            log.info("LLM snapshot generated for %s (%d chars)", entity, len(summary))
            return summary

        except requests.exceptions.HTTPError as e:
            log.error("LLM snapshot call failed for %s (attempt %d): HTTP %s",
                      entity, attempt + 1, e.response.status_code if e.response else "unknown")
        except Exception as e:
            log.error("LLM snapshot call failed for %s (attempt %d): %s",
                      entity, attempt + 1, type(e).__name__)

    return None
