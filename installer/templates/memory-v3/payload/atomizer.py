"""Memory V3 — Tier 1 rule-based atomizer.

Extracts atomic facts from markdown chunks using pattern matching.
No LLM calls — deterministic extraction only.
"""
import hashlib
import logging
import re
from datetime import date, datetime, timedelta
from typing import Optional

from config import (
    FACT_MIN_CHARS, FACT_MAX_CHARS, FACT_DATE_WINDOW_DAYS, KNOWN_ENTITIES,
    ENTITY_ALIASES,
)

log = logging.getLogger("atomizer")

# ── Date patterns ─────────────────────────────────────────────────────────────

_ISO_DATE = re.compile(r'\b(20\d{2})[-/](0[1-9]|1[0-2])[-/](0[1-9]|[12]\d|3[01])\b')
_KOREAN_DATE = re.compile(
    r'\b(20\d{2})년\s*(1[0-2]|[1-9])월\s*(3[01]|[12]\d|[1-9])일\b'
)
_MONTH_DAY = re.compile(
    r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
    r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|'
    r'Dec(?:ember)?)\s+(\d{1,2})(?:,?\s*(20\d{2}))?\b',
    re.IGNORECASE
)
_SLASH_DATE = re.compile(r'\b(1[0-2]|[1-9])/(3[01]|[12]\d|[1-9])\b')

_MONTH_MAP = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
}


def _extract_date(text: str, source_date: Optional[date] = None) -> Optional[date]:
    """Extract the first plausible date from text."""
    # ISO date: 2026-02-23
    m = _ISO_DATE.search(text)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            pass

    # Korean date: 2026년 2월 23일
    m = _KOREAN_DATE.search(text)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            pass

    # Month Day [Year]: Feb 23 or February 23, 2026
    m = _MONTH_DAY.search(text)
    if m:
        month_str = m.group(1)[:3].lower()
        month = _MONTH_MAP.get(month_str)
        if month:
            day = int(m.group(2))
            year = int(m.group(3)) if m.group(3) else (
                source_date.year if source_date else date.today().year
            )
            try:
                return date(year, month, day)
            except ValueError:
                pass

    # Slash date: 2/23 — only if source_date available
    if source_date:
        m = _SLASH_DATE.search(text)
        if m:
            try:
                return date(source_date.year, int(m.group(1)), int(m.group(2)))
            except ValueError:
                pass

    return None


# ── Entity extraction ─────────────────────────────────────────────────────────

# Build lowercase→canonical lookup
_ENTITY_LC = {e.lower(): e for e in KNOWN_ENTITIES}
# Regex: match any known entity (word-boundary aware)
_ENTITY_PATTERN = re.compile(
    r'\b(' + '|'.join(re.escape(e) for e in KNOWN_ENTITIES) + r')\b',
    re.IGNORECASE
)


def _extract_entity(text: str) -> Optional[str]:
    """Return the most prominent known entity in text, or None.
    Also checks ENTITY_ALIASES for common phrases that map to canonical entities.
    """
    # First check aliases (phrase-level matching, case-insensitive)
    text_lower = text.lower()
    for alias, canonical in ENTITY_ALIASES.items():
        if alias in text_lower:
            return canonical

    # Then check known entities (word-boundary matching)
    counts: dict[str, int] = {}
    for m in _ENTITY_PATTERN.finditer(text):
        canonical = _ENTITY_LC.get(m.group(0).lower(), m.group(0))
        counts[canonical] = counts.get(canonical, 0) + 1
    if not counts:
        return None
    return max(counts, key=counts.__getitem__)


# ── Category detection ────────────────────────────────────────────────────────

_METRIC_PATTERNS = [
    re.compile(p, re.IGNORECASE) for p in [
        r'\d+(\.\d+)?%',         # percentage
        r'승률|win\s*rate|WR',
        r'\$\d+|\d+\s*(달러|USD|SOL|ETH)',
        r'손실|수익|profit|loss',
        r'\d+/\d+',              # ratio like 5/8
    ]
]
_DECISION_PATTERNS = [
    re.compile(p, re.IGNORECASE) for p in [
        r'결정|결론|채택|선택|decided|decision|chosen|선정|폐기',
        r'하기로|않기로|하지 않|변경',
    ]
]
_LESSON_PATTERNS = [
    re.compile(p, re.IGNORECASE) for p in [
        r'교훈|lesson|배웠|learned|깨달|realized|실수|mistake',
        r'postmortem|사후|root cause|원인',
    ]
]
_STATE_PATTERNS = [
    re.compile(p, re.IGNORECASE) for p in [
        r'현재|지금|현행|current|active|running|라이브|live|상태',
        r'구현됨|배포됨|deployed|implemented',
    ]
]
_CORRECTION_PATTERNS = [
    re.compile(p, re.IGNORECASE) for p in [
        r'정정|수정|correction|incorrect|잘못|틀렸|was wrong',
        r'actually|사실은|실제로는|아니라|이 아닌',
    ]
]


def _detect_category(text: str) -> str:
    """Classify fact into one of: metric, decision, lesson, state, factual."""
    if any(p.search(text) for p in _METRIC_PATTERNS):
        return "metric"
    if any(p.search(text) for p in _DECISION_PATTERNS):
        return "decision"
    if any(p.search(text) for p in _LESSON_PATTERNS):
        return "lesson"
    if any(p.search(text) for p in _STATE_PATTERNS):
        return "state"
    return "factual"


def _has_correction(text: str) -> bool:
    """True if text suggests a correction of prior info."""
    return any(p.search(text) for p in _CORRECTION_PATTERNS)


# ── Bilingual helpers ─────────────────────────────────────────────────────────

def _is_korean(text: str) -> bool:
    """Return True if text contains Korean characters."""
    return bool(re.search(r'[가-힣]', text))


def _validate_fact_ko(fact: str, fact_ko: str | None) -> str | None:
    """Validate fact_ko quality. Returns None if validation fails.

    Checks:
    - Non-empty
    - Length ratio 0.1x–5.0x of fact (Korean can be much shorter)
    - All numbers from fact are preserved in fact_ko
    """
    if not fact_ko or not fact_ko.strip():
        return None
    fact_ko = fact_ko.strip()
    ratio = len(fact_ko) / max(len(fact), 1)
    if ratio < 0.1 or ratio > 5.0:
        return None

    # Match integers/decimals without swallowing sentence-ending punctuation
    # e.g. "round 2." -> "2" (not "2.")
    num_pattern = r'(?<!\d)\d+(?:\.\d+)?(?!\d)'
    en_nums = set(re.findall(num_pattern, fact))
    ko_nums = set(re.findall(num_pattern, fact_ko))
    if en_nums and not en_nums.issubset(ko_nums):
        return None
    return fact_ko


# ── Sentence splitting ────────────────────────────────────────────────────────

# Sentence boundary: Korean endings (다/됨/임) + English period
_SENT_SPLIT = re.compile(
    r'(?<=[다됨임함됐었겠음])\.\s+|'   # Korean sentence ending + period
    r'(?<=[다됨임함됐었겠음])\s*\n|'   # Korean ending + newline
    r'(?<=[.!?])\s+(?=[A-Z가-힣])|'   # English sentence boundary
    r'\n{2,}',                         # Blank line = paragraph break
)


# ── Low-value fact suppression ────────────────────────────────────────────────
# Conservative heuristic: reject obvious conversational/meta residue before
# it reaches embedding + insert.  Keep the patterns narrow to avoid nuking
# genuine state snapshots or meaningful factual records.

_JUNK_EXACT: set[str] = {
    # healthcheck / protocol noise
    "ping", "pong", "alive", "no_reply", "NO_REPLY", "ack", "ok", "nop",
    "test", "테스트", "확인", "완료",
}

_JUNK_PATTERNS: list[re.Pattern] = [
    # ping / healthcheck / alive probes
    re.compile(r'^(ping|pong|alive|health\s*check|heartbeat|NO_REPLY)\s*[.!?]?$', re.IGNORECASE),
    # test message chatter
    re.compile(r'^(test\s*message|테스트\s*메시지|this is (a )?test)\b', re.IGNORECASE),
    # feedback / approval / check-request meta chatter
    re.compile(
        r'^(피드백\s*(보냈어?|줬어?|전달했?어?|완료)|확인해\s*줘|확인\s*부탁|리뷰\s*(해줘|부탁)|'
        r'한번\s*봐\s*줘|체크\s*(해줘|부탁)|LGTM|looks good|ship it)\s*[.!?]?$',
        re.IGNORECASE,
    ),
    # system/event wrapper text (bare markers)
    re.compile(
        r'^(session\s*(started|ended|closed)|connection\s*(opened|closed)|'
        r'event:\s*\w+|webhook\s*(received|sent))\s*[.!?]?$',
        re.IGNORECASE,
    ),
    # ultra-short conversational residue (Korean 1-2 word enders)
    re.compile(
        r'^(네|응|ㅇㅇ|ㅋㅋ+|ㅎㅎ+|감사|고마워|알겠|그래|좋아|오키|'
        r'왔을?\s*거예요|보냈어|했어|됐어|할게|가자|보자|하자)\s*[.!?]?$',
    ),
    # bare acknowledgement in English
    re.compile(
        r'^(ok|okay|sure|yes|no|yep|nope|got it|roger|copy|noted|done|'
        r'thanks|thank you|ty|thx)\s*[.!?]?$',
        re.IGNORECASE,
    ),
    # assistant meta-responses
    re.compile(
        r'^(understood|will do|on it|working on it|let me check|'
        r'checking now|one moment)\s*[.!?]?$',
        re.IGNORECASE,
    ),
]


def is_low_value_fact(text: str) -> bool:
    """Return True if *text* is obvious conversational/meta junk.

    Designed to be called from both Tier 1 (validate_memories) and
    Tier 2 (llm_atomize_batch) before embedding + insert.
    Conservative: only rejects clear-cut patterns.
    """
    stripped = text.strip()
    # Exact-match short tokens (after stripping trailing punct)
    canon = re.sub(r'[.!?,;:…]+$', '', stripped).strip()
    if canon.lower() in _JUNK_EXACT or canon in _JUNK_EXACT:
        return True
    # Pattern-match
    for pat in _JUNK_PATTERNS:
        if pat.match(stripped):
            return True
    return False


def _split_sentences(text: str) -> list[str]:
    """Split text into candidate sentences."""
    parts = _SENT_SPLIT.split(text)
    result = []
    for part in parts:
        part = part.strip()
        if part:
            result.append(part)
    return result


# ── Markdown structure parsing ────────────────────────────────────────────────

_BOLD_LINE = re.compile(r'^\*\*(.+?)\*\*[:\s]+(.+)$')
_HEADER = re.compile(r'^#{1,4}\s+(.+)$')
_LIST_ITEM = re.compile(r'^[-*]\s+(.+)$')
_NUMBERED = re.compile(r'^\d+\.\s+(.+)$')


def _parse_structured_facts(text: str) -> list[str]:
    """Extract key-value facts from bold/header/list markdown patterns."""
    facts = []
    for line in text.splitlines():
        line = line.strip()
        # **Key**: value
        m = _BOLD_LINE.match(line)
        if m:
            key, val = m.group(1).strip(), m.group(2).strip()
            if len(val) >= FACT_MIN_CHARS:
                facts.append(f"{key}: {val}")
            continue
        # List items: - some fact
        m = _LIST_ITEM.match(line) or _NUMBERED.match(line)
        if m:
            item = m.group(1).strip()
            if len(item) >= FACT_MIN_CHARS:
                facts.append(item)
    return facts


# ── Main atomize function ─────────────────────────────────────────────────────

def rule_based_atomize(
    chunk_content: str,
    source_path: str,
    source_date: Optional[str],  # YYYY-MM-DD
    chunk_id: str,
    namespace: str,
) -> list[dict]:
    """
    Tier 1 rule-based atomization. No LLM.
    Returns list of fact dicts (not yet stored — caller handles embedding + insert).
    """
    src_date = _parse_date_str(source_date) if source_date else None

    # Collect candidate fact strings from two sources:
    # 1. Structured markdown elements (bold, lists)
    # 2. Sentence-split free text
    candidates: list[str] = []

    structured = _parse_structured_facts(chunk_content)
    candidates.extend(structured)

    # For free text, strip markdown formatting first
    plain = re.sub(r'[*_`#>]', '', chunk_content)
    plain = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', plain)  # links
    sentences = _split_sentences(plain)
    candidates.extend(sentences)

    # Remove duplicates (preserve order)
    seen: set[str] = set()
    unique: list[str] = []
    for c in candidates:
        key = c[:80].lower()
        if key not in seen:
            seen.add(key)
            unique.append(c)

    # Build fact dicts
    facts = []
    source_hash = hashlib.sha256(chunk_content.encode()).hexdigest()[:16]
    for candidate in unique:
        candidate = candidate.strip()
        if len(candidate) < FACT_MIN_CHARS or len(candidate) > FACT_MAX_CHARS:
            continue
        # Skip pure noise: only punctuation, headers, code, etc.
        if re.match(r'^[#\-=_*`\s]+$', candidate):
            continue
        # Skip lines that look like file paths or import statements
        if re.match(r'^(import |from |def |class )', candidate):
            continue

        event_date = _extract_date(candidate, src_date)
        # Fallback: inherit source_date if no date extractable from text
        if event_date is None and src_date is not None:
            event_date = src_date
        entity = _extract_entity(candidate) or _extract_entity(source_path)
        category = _detect_category(candidate)
        confidence = 0.85 if _has_correction(candidate) else 0.80
        status = "pending" if confidence < 0.65 else "active"
        # fact_ko: if source text is Korean, reuse fact directly (no translation needed)
        fact_ko = candidate if _is_korean(candidate) else None

        facts.append({
            "fact": candidate,
            "fact_ko": fact_ko,
            "context": None,
            "source_content_hash": source_hash,
            "source_chunk_id": chunk_id,
            "source_path": source_path,
            "event_date": event_date,
            "document_date": src_date,
            "entity": entity,
            "category": category,
            "confidence": confidence,
            "namespace": namespace,
            "status": status,
        })

    return facts


def _parse_date_str(s: str) -> Optional[date]:
    """Parse YYYY-MM-DD string to date, returns None on failure."""
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return None


# ── Validation pipeline ───────────────────────────────────────────────────────

def validate_memories(facts: list[dict], source_date: Optional[str]) -> list[dict]:
    """
    Quality gate per fact:
    - Length check
    - Date sanity (±30 days of source_date)
    - Dedup by content prefix
    Returns validated subset.
    """
    src_date = _parse_date_str(source_date) if source_date else None
    valid: list[dict] = []
    seen_prefixes: set[str] = set()

    for fact in facts:
        text = fact["fact"]

        # Length
        if len(text) < FACT_MIN_CHARS or len(text) > FACT_MAX_CHARS:
            continue

        # Low-value fact suppression (conversational/meta junk)
        if is_low_value_fact(text):
            continue

        # Date sanity
        ev = fact.get("event_date")
        if ev and src_date:
            if isinstance(ev, str):
                ev = _parse_date_str(ev)
            if ev and abs((ev - src_date).days) > FACT_DATE_WINDOW_DAYS:
                fact["event_date"] = None  # null out suspect date

        # Dedup by first 60 chars
        prefix = text[:60].lower().strip()
        if prefix in seen_prefixes:
            continue
        seen_prefixes.add(prefix)

        valid.append(fact)

    return valid


# ── Coverage report ───────────────────────────────────────────────────────────

def coverage_report(total_chunks: int, total_memories: int,
                    entity_dist: dict, category_dist: dict) -> str:
    """Format a human-readable coverage report."""
    lines = [
        "── Atomizer Coverage Report ──",
        f"  Chunks processed : {total_chunks}",
        f"  Memories created : {total_memories}",
        f"  Facts per chunk  : {total_memories/max(total_chunks,1):.1f}",
        "",
        "  Entity distribution:",
    ]
    for entity, cnt in sorted(entity_dist.items(), key=lambda x: -x[1])[:15]:
        lines.append(f"    {entity or '(none)':30s} {cnt}")
    lines.append("")
    lines.append("  Category distribution:")
    for cat, cnt in sorted(category_dist.items(), key=lambda x: -x[1]):
        lines.append(f"    {cat:12s} {cnt}")
    return "\n".join(lines)
