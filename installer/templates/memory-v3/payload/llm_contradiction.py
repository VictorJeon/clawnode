"""Memory V3 — LLM contradiction detector.

Uses Gemini Flash to judge whether a new fact contradicts or updates existing
facts that rule-based relation linking missed (typically: same topic, different
wording, semantic conflict without numerical change).

Called from relation_linker.link_new_memories() when
CONTRADICTION_LLM_ENABLED is True.
"""
import json
import logging
import re

import requests
from config import load_google_api_key

log = logging.getLogger("relation-linker.llm-contradiction")


# ── API setup ─────────────────────────────────────────────────────────────────

_GOOGLE_API_KEY = load_google_api_key()

_SYSTEM_PROMPT = """\
You are a memory consistency checker. Given a NEW fact and a list of OLD facts,
judge whether each old fact is contradicted or updated by the new fact.

Rules:
- "contradicts": the two facts assert incompatible things about the same subject
  (e.g., one says A is true, the other says A is false, without a change over time).
- "updates": the new fact replaces the old because the situation changed over time
  (e.g., a status changed, a decision was revised, a number was updated).
- "none": no meaningful conflict (different topics, additive info, same assertion).

Respond with a JSON array — one entry per old fact — in this exact schema:
[{"index": 1, "relation": "contradicts"|"updates"|"none"}, ...]

CRITICAL:
- Output ONLY the JSON array, no markdown, no explanation.
- Every old fact must have exactly one entry.
- "index" is 1-based and matches the OLD FACT numbering below.\
"""

_MAX_RETRIES = 1


def _call_gemini(model: str, new_fact: str, old_facts: list[str]) -> list[dict]:
    """Call Gemini Flash with one new fact and a list of old facts.

    Returns a list of {index (1-based), relation} dicts, or [] on failure.
    """
    if not _GOOGLE_API_KEY:
        log.error("GOOGLE_API_KEY not set — LLM contradiction skipped")
        return []

    # Sanitize facts: truncate to 500 chars to limit prompt injection surface
    _MAX_FACT_LEN = 500
    safe_new = new_fact[:_MAX_FACT_LEN]
    safe_old = [f[:_MAX_FACT_LEN] for f in old_facts]

    numbered = "\n".join(f"{i+1}. {f}" for i, f in enumerate(safe_old))
    user_prompt = (
        f"<new_fact>\n{safe_new}\n</new_fact>\n\n"
        f"<old_facts>\n{numbered}\n</old_facts>\n\n"
        "Return a JSON array judging each old fact."
    )

    payload = {
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "systemInstruction": {"parts": [{"text": _SYSTEM_PROMPT}]},
        "generationConfig": {
            "temperature": 0.0,
            "maxOutputTokens": 512,
            "responseMimeType": "application/json",
        },
    }
    api_url = (
        f"https://generativelanguage.googleapis.com/v1beta/models"
        f"/{model}:generateContent"
    )

    for attempt in range(_MAX_RETRIES + 1):
        try:
            resp = requests.post(
                f"{api_url}?key={_GOOGLE_API_KEY}",
                json=payload,
                timeout=30,
            )
            if resp.status_code == 429:
                log.warning("LLM contradiction: rate limited (attempt %d)", attempt + 1)
                import time
                time.sleep(3 * (attempt + 1))
                continue
            resp.raise_for_status()

            data = resp.json()
            candidates_list = data.get("candidates") or []
            if not candidates_list:
                finish_reason = (data.get("promptFeedback") or {}).get("blockReason", "unknown")
                log.warning("LLM contradiction: empty candidates (reason: %s)", finish_reason)
                return []
            text = candidates_list[0]["content"]["parts"][0]["text"].strip()

            # Strip markdown fencing if present
            if text.startswith("```"):
                text = re.sub(r'^```\w*\n?', '', text)
                text = re.sub(r'\n?```$', '', text.strip())

            parsed = json.loads(text)
            if not isinstance(parsed, list):
                parsed = [parsed]
            return parsed

        except requests.exceptions.HTTPError as e:
            log.error("LLM contradiction call failed (attempt %d): HTTP %s",
                      attempt + 1, e.response.status_code if e.response else "unknown")
        except Exception as e:
            log.error("LLM contradiction call failed (attempt %d): %s",
                      attempt + 1, type(e).__name__)

    return []


# ── Public API ────────────────────────────────────────────────────────────────

def llm_judge_contradictions(
    new_fact: str,
    candidates: list[dict],
    model: str = "gemini-2.5-flash",
) -> list[dict]:
    """Judge whether candidates contradict or update new_fact via Gemini Flash.

    Args:
        new_fact: the newly-inserted fact text.
        candidates: list of dicts with keys 'id' and 'fact'.
        model: Gemini model name (from config).

    Returns:
        list of {old_id: str, relation: str} where relation ∈
        {'contradicts', 'updates', 'none'}. Empty list on LLM failure.
    """
    if not candidates:
        return []

    old_facts = [c["fact"] for c in candidates]
    raw = _call_gemini(model, new_fact, old_facts)
    if not raw:
        return []

    # Map 1-based index → candidate id; validate relation values
    # First-wins per index to prevent duplicate relations for same pair
    valid_relations = {"contradicts", "updates", "none"}
    seen_indices: dict[int, dict] = {}
    for entry in raw:
        try:
            idx = int(entry.get("index", 0))
            relation = str(entry.get("relation", "none")).lower().strip()
            if relation not in valid_relations:
                relation = "none"
            if 1 <= idx <= len(candidates) and idx not in seen_indices:
                seen_indices[idx] = {
                    "old_id": str(candidates[idx - 1]["id"]),
                    "relation": relation,
                }
        except Exception as e:
            log.warning("LLM contradiction: malformed entry %s — %s", entry, e)

    return list(seen_indices.values())
