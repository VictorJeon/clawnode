"""Markdown chunker with heading-based splitting and date metadata."""
import re
from pathlib import Path
from config import MAX_CHUNK_TOKENS, MIN_CHUNK_TOKENS


def extract_date_from_path(path: str) -> str | None:
    """Extract YYYY-MM-DD from file path if present."""
    m = re.search(r'(\d{4}-\d{2}-\d{2})', path)
    return m.group(1) if m else None


def estimate_tokens(text: str) -> int:
    """Rough token estimate (words * 1.3 for mixed Korean/English)."""
    return int(len(text.split()) * 1.3)


def chunk_markdown(text: str, source_path: str = "") -> list[dict]:
    """Split markdown by ## headings. Returns list of {title, content, date}."""
    chunks = []
    date = extract_date_from_path(source_path)

    # Split by ## headings
    sections = re.split(r'^(#{1,3}\s+.+)$', text, flags=re.MULTILINE)

    current_title = None
    current_content = ""

    for part in sections:
        if re.match(r'^#{1,3}\s+', part):
            if current_content.strip():
                chunks.append({
                    "title": current_title,
                    "content": current_content.strip(),
                    "date": date,
                })
            current_title = part.strip()
            current_content = part + "\n"
        else:
            current_content += part

    if current_content.strip():
        chunks.append({
            "title": current_title,
            "content": current_content.strip(),
            "date": date,
        })

    # Split oversized, merge undersized
    result = []
    for chunk in chunks:
        tok = estimate_tokens(chunk["content"])
        if tok > MAX_CHUNK_TOKENS:
            paragraphs = chunk["content"].split("\n\n")
            sub = ""
            for para in paragraphs:
                candidate = (sub + "\n\n" + para) if sub else para
                if estimate_tokens(candidate) > MAX_CHUNK_TOKENS and sub.strip():
                    result.append({"title": chunk["title"], "content": sub.strip(), "date": date})
                    sub = para
                else:
                    sub = candidate
            if sub.strip():
                result.append({"title": chunk["title"], "content": sub.strip(), "date": date})
        elif tok >= MIN_CHUNK_TOKENS:
            result.append(chunk)
        else:
            if result:
                result[-1]["content"] += "\n\n" + chunk["content"]
            else:
                result.append(chunk)

    return result
