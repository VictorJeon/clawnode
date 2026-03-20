#!/usr/bin/env python3
from __future__ import annotations

import json
import logging
from datetime import date

from config import load_google_api_key
from memory_distill_common import (
    WEEKLY_END,
    WEEKLY_START,
    call_gemini_json,
    format_search_results,
    memory_dir,
    memory_md_path,
    read_recent_daily_logs,
    search_memory,
    upsert_marker_block,
    write_text,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("weekly-pattern")

SYSTEM_PROMPT = """You summarize one week's repeated patterns for an operator.
Return JSON only:
{"summary":"...", "patterns":["..."], "risks":["..."], "next_focus":["..."]}.
Requirements:
- Korean by default
- emphasize repetition, bottlenecks, and recurring wins
- only include patterns supported by the provided evidence"""


def main() -> int:
    today = date.today()
    if not load_google_api_key():
        log.info("GOOGLE_API_KEY missing — weekly pattern skipped")
        return 0

    logs = read_recent_daily_logs(7)
    memory_hits = search_memory("최근 7일 반복 패턴 결정 병목 리스크", max_results=24)
    if not logs and not memory_hits.get("results"):
        log.info("No weekly evidence found — skip")
        return 0

    rendered_logs = "\n\n".join(
        f"[{d.isoformat()}]\n{text[:3000]}" for d, text in logs
    )
    user_prompt = f"""Week ending: {today.isoformat()}

Recent daily logs:
{rendered_logs[:16000]}

Memory search results:
{format_search_results(memory_hits)[:14000]}

Generate weekly recurring patterns."""
    parsed = call_gemini_json(SYSTEM_PROMPT, user_prompt)

    summary = str(parsed.get("summary", "")).strip()
    patterns = [str(x).strip() for x in parsed.get("patterns", []) if str(x).strip()]
    risks = [str(x).strip() for x in parsed.get("risks", []) if str(x).strip()]
    next_focus = [str(x).strip() for x in parsed.get("next_focus", []) if str(x).strip()]

    lines = [f"## Week Ending {today.isoformat()}"]
    if summary:
        lines += ["", summary]
    if patterns:
        lines += ["", "### Repeating Patterns"] + [f"- {item}" for item in patterns[:6]]
    if risks:
        lines += ["", "### Risks"] + [f"- {item}" for item in risks[:5]]
    if next_focus:
        lines += ["", "### Next Focus"] + [f"- {item}" for item in next_focus[:5]]

    body = "\n".join(lines).strip()
    upsert_marker_block(memory_md_path(), WEEKLY_START, WEEKLY_END, body)
    write_text(memory_dir() / f"weekly-{today.isoformat()}.md", body + "\n")
    log.info(
        "Weekly pattern updated: %s",
        json.dumps({"date": today.isoformat(), "patterns": len(patterns), "risks": len(risks), "next_focus": len(next_focus)}),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
