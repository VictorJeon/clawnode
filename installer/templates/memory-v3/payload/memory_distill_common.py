#!/usr/bin/env python3
"""Shared helpers for Memory V3 daily/weekly distill jobs."""
from __future__ import annotations

import json
import logging
import os
import re
from datetime import date, timedelta
from pathlib import Path

import requests

from config import HOST, PORT, WORKSPACES, load_google_api_key

log = logging.getLogger("memory-distill")

DAILY_START = "<!-- OPENCLAW_DAILY_DISTILL_START -->"
DAILY_END = "<!-- OPENCLAW_DAILY_DISTILL_END -->"
WEEKLY_START = "<!-- OPENCLAW_WEEKLY_PATTERN_START -->"
WEEKLY_END = "<!-- OPENCLAW_WEEKLY_PATTERN_END -->"
DEFAULT_MODEL = "gemini-2.5-flash"


def workspace_root() -> Path:
    path = WORKSPACES.get("global")
    if not path:
        return Path(os.path.expanduser("~/.openclaw/workspace"))
    return Path(path)


def memory_md_path() -> Path:
    return workspace_root() / "MEMORY.md"


def memory_dir() -> Path:
    return workspace_root() / "memory"


def memory_api_url() -> str:
    return f"http://{HOST}:{PORT}"


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def read_daily_log(target: date) -> str:
    return read_text(memory_dir() / f"{target.isoformat()}.md")


def read_recent_daily_logs(days: int) -> list[tuple[date, str]]:
    items: list[tuple[date, str]] = []
    today = date.today()
    for offset in range(days):
        current = today - timedelta(days=offset)
        text = read_daily_log(current)
        if text.strip():
            items.append((current, text))
    return items


def search_memory(query: str, max_results: int = 20) -> dict:
    resp = requests.post(
        f"{memory_api_url()}/v1/memory/search",
        json={"query": query, "maxResults": max_results},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def _parse_json_relaxed(raw: str) -> dict:
    raw = raw.replace("\u201c", '"').replace("\u201d", '"').replace("\u2019", "'")
    raw = re.sub(r",\s*([\]}])", r"\1", raw)
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return parsed
    except Exception:
        pass
    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end > start:
        parsed = json.loads(raw[start:end + 1])
        if isinstance(parsed, dict):
            return parsed
    raise ValueError(f"Cannot parse Gemini JSON: {raw[:200]}")


def call_gemini_json(system_prompt: str, user_prompt: str, model: str = DEFAULT_MODEL) -> dict:
    api_key = load_google_api_key()
    if not api_key:
        raise RuntimeError("GOOGLE_API_KEY not configured")

    resp = requests.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}",
        json={
            "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "generationConfig": {
                "temperature": 0.2,
                "maxOutputTokens": 700,
                "responseMimeType": "application/json",
            },
        },
        timeout=45,
    )
    resp.raise_for_status()
    data = resp.json()
    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini returned no candidates")
    text = candidates[0]["content"]["parts"][0]["text"].strip()
    if text.startswith("```"):
        text = re.sub(r"^```\w*\n?", "", text)
        text = re.sub(r"\n?```$", "", text.strip())
    return _parse_json_relaxed(text)


def format_search_results(payload: dict) -> str:
    lines: list[str] = []
    for idx, item in enumerate(payload.get("results", []), start=1):
        fact = item.get("fact") or item.get("content") or ""
        entity = item.get("entity") or "-"
        category = item.get("category") or item.get("resultType") or "-"
        score = item.get("score")
        path = item.get("path") or "-"
        lines.append(
            f"[{idx}] entity={entity} category={category} score={score} path={path}\n{fact}".strip()
        )
    return "\n\n".join(lines)


def upsert_marker_block(path: Path, start_marker: str, end_marker: str, body: str) -> None:
    existing = read_text(path)
    block = f"{start_marker}\n{body.rstrip()}\n{end_marker}\n"
    if start_marker in existing and end_marker in existing:
        updated = re.sub(
            re.escape(start_marker) + r".*?" + re.escape(end_marker) + r"\n?",
            block,
            existing,
            flags=re.DOTALL,
        )
    else:
        if existing and not existing.endswith("\n"):
            existing += "\n"
        updated = existing + ("\n" if existing else "") + block
    write_text(path, updated)
