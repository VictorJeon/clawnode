"""Memory V3 - Tier 2 LLM Atomizer.

Uses OpenRouter Qwen to extract structured facts from conversation chunks
that rule-based atomization handles poorly (session logs, complex context).

Design:
- Batches chunks for efficiency (up to 10 per API call)
- Extracts facts with date, entity, category, and confidence
- Deduplicates against existing Tier 1 facts
- Costs ~$0.02/day at current volume
"""
import json
import hashlib
import logging
import re
from datetime import date

from config import ENTITY_ALIASES, DEDUP_TEMPORAL_GAP_DAYS
from atomizer import _validate_fact_ko, is_low_value_fact
from ollama_helper import call_ollama_json, is_ollama_available

log = logging.getLogger("memory-v3.llm-atomizer")

# ── Config ────────────────────────────────────────────────────────────────────

class LLMAtomizerBackendError(RuntimeError):
    """Tier 2 LLM backend was unavailable or returned invalid output."""

MAX_CHUNKS_PER_BATCH = 15
MAX_RETRIES = 2

# ── Prompt ────────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are a memory extraction system. Given conversation chunks between a user (Mason) and an AI assistant (Nova), extract every fact worth remembering.

Focus especially on:
- **Transactions**: buy/sell amounts, shares, prices, positions (e.g., "bought 210 shares of L1 YES at $0.60")
- **Decisions**: what was decided and why
- **State changes**: what changed, from what to what
- **Metrics/numbers**: specific quantities, costs, percentages with context
- **Events with dates**: when something happened
- **Lessons learned**: insights from failures or successes

Rules:
1. Each fact must be self-contained - understandable without the original conversation
2. Include specific numbers, entity names, dates whenever present
3. If a date is mentioned or inferrable, include it in ISO format (YYYY-MM-DD)
4. Assign each fact an entity (the main subject: project name, system, person)
   - Use canonical entity names: memory-v3 (not "fact extraction system" or "atomizer"), V8, L1, polymarket-weather-bot, etc.
   - If discussing atomizer/Tier 1/Tier 2/relation linker/decay/active recall → entity is "memory-v3"
   - If discussing weather bot strategies/signals/backtests → entity is "polymarket-weather-bot" or "L1" or "V8"
5. Assign a category: factual, metric, decision, lesson, state, transaction
6. Skip: greetings, filler, questions without answers, tool call details, code snippets, file paths alone (e.g. "The script is located at /path/to/file.py" — unless accompanied by a meaningful fact about what the script does), transient process statuses (e.g. "backfill in progress", "batch N processing")
7. When user asks "how many shares" and assistant answers, the answer IS the fact
8. ALWAYS include a date. If the chunk has a date header, use it. If not, infer from context or use the source_date shown above.

Output JSON array. Each element:
{
  "chunk_number": 1,
  "fact": "concise factual statement in English (canonical)",
  "fact_ko": "동일한 의미의 한국어 버전. fact와 의미가 정확히 같아야 함. 새로운 정보 추가 금지.",
  "date": "YYYY-MM-DD or null",
  "entity": "main entity name",
  "category": "factual|metric|decision|lesson|state|transaction"
}

CRITICAL for fact_ko:
- fact and fact_ko MUST be semantically identical (same numbers, dates, entity names)
- No added or removed information
- If the source chunk is Korean, fact_ko should be natural Korean (not a translation of fact)
- If translation quality is uncertain, set fact_ko to null

`chunk_number` must match the CHUNK index shown in the input (1-based)."""


# ── LLM Call ──────────────────────────────────────────────────────────────────


def _call_llm(chunks: list[dict]) -> list[dict]:
    """Call OpenRouter-backed LLM helper with batched chunks. Returns extracted facts."""
    chunk_texts = []
    for i, chunk in enumerate(chunks):
        source_date = chunk.get("source_date", "unknown")
        source_path = chunk.get("source_path", "unknown")
        content = chunk.get("content", "")
        if len(content) > 3000:
            content = content[:2500] + "\n...[truncated]...\n" + content[-500:]
        chunk_texts.append(
            f"--- CHUNK {i+1} (date: {source_date}, source: {source_path}) ---\n{content}"
        )

    user_prompt = (
        "Extract all memorable facts from these conversation chunks:\n\n"
        + "\n\n".join(chunk_texts)
        + "\n\nReturn ONLY a JSON array of fact objects. No markdown fencing. "
    )

    if not is_ollama_available():
        raise LLMAtomizerBackendError("OpenRouter backend unavailable")

    facts = call_ollama_json(user_prompt, SYSTEM_PROMPT, max_retries=MAX_RETRIES)
    if facts is None:
        raise LLMAtomizerBackendError("OpenRouter returned empty/invalid JSON")
    if not isinstance(facts, list):
        raise LLMAtomizerBackendError("OpenRouter returned non-list JSON")
    return facts


# ── Deduplication ─────────────────────────────────────────────────────────────

def _is_duplicate(fact_text: str, existing_facts: list[str], threshold: float = 0.85,
                  fact_date: date | None = None,
                  existing_dates: list[date | None] | None = None) -> bool:
    """Check if a fact is semantically duplicate of existing facts.
    Uses simple token overlap ratio as a fast heuristic.

    Temporal gap protection: if fact_date and existing_dates are provided,
    a high-overlap pair is NOT considered a duplicate when both dates are set
    and |gap| >= DEDUP_TEMPORAL_GAP_DAYS.
    """
    fact_tokens = set(fact_text.lower().split())
    if not fact_tokens:
        return False

    for i, existing in enumerate(existing_facts):
        existing_tokens = set(existing.lower().split())
        if not existing_tokens:
            continue
        overlap = len(fact_tokens & existing_tokens)
        ratio = overlap / max(len(fact_tokens), len(existing_tokens))
        if ratio > threshold:
            # Temporal gap protection
            if fact_date is not None and existing_dates is not None:
                ex_date = existing_dates[i] if i < len(existing_dates) else None
                if ex_date is not None:
                    if abs((fact_date - ex_date).days) >= DEDUP_TEMPORAL_GAP_DAYS:
                        continue  # temporally protected — not a duplicate
            return True
    return False


# ── Main Atomize Function ────────────────────────────────────────────────────

def llm_atomize_batch(
    chunks: list[dict],
    existing_facts_by_chunk: dict[str, list[tuple[str, object]]],
) -> list[dict]:
    """
    Run LLM atomization on a batch of chunks.

    Args:
        chunks: list of dicts with keys: id, content, source_path, source_date, namespace
        existing_facts_by_chunk: {chunk_id: [(fact_text, effective_date), ...]} from Tier 1

    Returns:
        list of fact dicts ready for embedding + insert
    """
    if not chunks:
        return []

    # Call LLM
    raw_facts = _call_llm(chunks)
    if not raw_facts:
        return []

    # Collect all existing facts + dates for dedup (parallel lists)
    all_existing: list[str] = []
    all_existing_dates: list[date | None] = []
    for facts_list in existing_facts_by_chunk.values():
        for fact_text, fact_date in facts_list:
            all_existing.append(fact_text)
            all_existing_dates.append(fact_date)

    # Process and deduplicate
    results = []
    for raw in raw_facts:
        fact_text = raw.get("fact", "").strip()
        if not fact_text or len(fact_text) < 10:
            continue

        # Low-value fact suppression (shared with Tier 1)
        if is_low_value_fact(fact_text):
            continue

        # Parse date early so we can use it in dedup
        event_date = None
        date_str = raw.get("date")
        if date_str:
            try:
                event_date = date.fromisoformat(date_str)
            except (ValueError, TypeError):
                pass

        # Determine source chunk BEFORE dedup so source_date fallback is available
        chunk_number = raw.get("chunk_number")
        source_chunk = chunks[0]
        if isinstance(chunk_number, int) and 1 <= chunk_number <= len(chunks):
            source_chunk = chunks[chunk_number - 1]

        # Fallback: inherit source_date if LLM didn't extract a date
        if event_date is None and source_chunk.get("source_date"):
            try:
                event_date = date.fromisoformat(source_chunk["source_date"])
            except (ValueError, TypeError):
                pass

        # Skip if duplicate of existing Tier 1 fact (with temporal protection)
        if _is_duplicate(fact_text, all_existing, fact_date=event_date,
                         existing_dates=all_existing_dates):
            continue

        fact_ko = _validate_fact_ko(fact_text, raw.get("fact_ko"))

        entity = raw.get("entity", "").strip() or None
        # Apply entity aliases — normalize LLM-generated entity names
        if entity:
            alias_key = entity.lower()
            if alias_key in ENTITY_ALIASES:
                entity = ENTITY_ALIASES[alias_key]
        category = raw.get("category", "factual").strip()
        if category not in ("factual", "metric", "decision", "lesson", "state", "transaction"):
            category = "factual"

        confidence = 0.75  # slightly lower than Tier 1 (0.80)
        status = "pending" if confidence < 0.65 else "active"

        results.append({
            "fact": fact_text,
            "fact_ko": fact_ko,
            "context": None,
            "source_content_hash": hashlib.sha256(fact_text.encode()).hexdigest()[:16],
            "source_chunk_id": source_chunk["id"],
            "source_path": source_chunk.get("source_path", ""),
            "event_date": event_date,
            "document_date": (
                date.fromisoformat(source_chunk["source_date"])
                if source_chunk.get("source_date")
                else None
            ),
            "entity": entity,
            "category": category,
            "confidence": confidence,
            "namespace": source_chunk.get("namespace", "global"),
            "tier": 2,  # mark as LLM-extracted
            "status": status,
        })

        # Add to existing for intra-batch dedup (track date in parallel)
        all_existing.append(fact_text)
        all_existing_dates.append(event_date)

    log.info("LLM atomizer: %d raw → %d after dedup", len(raw_facts), len(results))
    return results
