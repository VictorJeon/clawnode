#!/usr/bin/env python3
from __future__ import annotations

import json
import logging
from datetime import date

from config import load_google_api_key
from memory_distill_common import (
    DAILY_END,
    DAILY_START,
    call_gemini_json,
    format_search_results,
    memory_dir,
    memory_md_path,
    read_daily_log,
    search_memory,
    upsert_marker_block,
    write_text,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("daily-distill")

SYSTEM_PROMPT = """You summarize one day's project work into operator-facing memory.
Return JSON only: {"summary":"...", "decisions":["..."], "facts":["..."], "lessons":["..."]}.
Requirements:
- Korean by default
- concise
- only include durable information worth keeping
- if evidence is weak, omit it"""


def main() -> int:
    today = date.today()
    if not load_google_api_key():
        log.info("GOOGLE_API_KEY missing — daily distill skipped")
        return 0

    daily_log = read_daily_log(today)
    memory_hits = search_memory(f"{today.isoformat()} 오늘 작업 결정 사실", max_results=20)
    if not daily_log.strip() and not memory_hits.get("results"):
        log.info("No daily log or memory hits for %s — skip", today.isoformat())
        return 0

    user_prompt = f"""Date: {today.isoformat()}

Daily log:
{daily_log[:12000]}

Memory search results:
{format_search_results(memory_hits)[:12000]}

Generate durable daily distill."""
    parsed = call_gemini_json(SYSTEM_PROMPT, user_prompt)

    summary = str(parsed.get("summary", "")).strip()
    decisions = [str(x).strip() for x in parsed.get("decisions", []) if str(x).strip()]
    facts = [str(x).strip() for x in parsed.get("facts", []) if str(x).strip()]
    lessons = [str(x).strip() for x in parsed.get("lessons", []) if str(x).strip()]

    lines = [f"## {today.isoformat()} Daily Distill"]
    if summary:
        lines += ["", summary]
    if decisions:
        lines += ["", "### Decisions"] + [f"- {item}" for item in decisions[:6]]
    if facts:
        lines += ["", "### Facts"] + [f"- {item}" for item in facts[:8]]
    if lessons:
        lines += ["", "### Lessons"] + [f"- {item}" for item in lessons[:5]]

    body = "\n".join(lines).strip()
    upsert_marker_block(memory_md_path(), DAILY_START, DAILY_END, body)
    write_text(memory_dir() / "distill" / f"{today.isoformat()}.md", body + "\n")
    log.info(
        "Daily distill updated: %s",
        json.dumps({"date": today.isoformat(), "decisions": len(decisions), "facts": len(facts), "lessons": len(lessons)}),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
