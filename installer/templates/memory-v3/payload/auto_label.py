#!/usr/bin/env python3
"""Auto-label memory chunks with status (active/deprecated/failed) using weak supervision.

Rules-based approach:
1. Keyword signals in chunk content
2. Supersession detection (newer chunk explicitly replaces older)
3. Confidence scoring

Run periodically or after ingest to keep labels fresh.
"""
import re
import sys
from db import get_conn, put_conn

# --- Signal keywords (Korean + English) ---
DEPRECATED_SIGNALS = [
    r'\b폐기\b', r'\b대체\b', r'\b교체\b', r'\b제거\b', r'\b삭제\b',
    r'\bsuperseded\b', r'\bdeprecated\b', r'\breplaced\b', r'\bremoved\b',
    r'\b더 이상.*사용.*않\b', r'\b중단\b', r'\b비활성\b', r'\bdisabled\b',
    r'\brollback\b', r'\b롤백\b', r'\b이전.*방식\b', r'\b구버전\b',
]

FAILED_SIGNALS = [
    r'\b실패\b', r'\b손실\b', r'\b오판\b', r'\b착각\b',
    r'\bpostmortem\b', r'\b사후\s*분석\b',
    r'\b버그\b', r'\bbug\b', r'\b장애\b', r'\bincident\b',
    r'\bfailed\b', r'\bfailure\b', r'\b오류\b', r'\b사건\b',
]

ACTIVE_SIGNALS = [
    r'\b채택\b', r'\b운영\b', r'\b프로덕션\b', r'\b승격\b', r'\b확정\b',
    r'\b활성\b', r'\bcurrent\b', r'\bactive\b', r'\bproduction\b',
    r'\b라이브\b', r'\blive\b', r'\b현행\b',
]

# Completion markers — these indicate resolved/done items, not failed
COMPLETED_SIGNALS = [
    r'✅', r'\b완료\b', r'\bcompleted\b', r'\bdone\b', r'\bmerged\b',
]


def score_signals(text: str) -> tuple[str, float]:
    """Score chunk text for status. Returns (status, confidence)."""
    text_lower = text.lower()

    dep_score = sum(1 for pat in DEPRECATED_SIGNALS if re.search(pat, text_lower))
    fail_score = sum(1 for pat in FAILED_SIGNALS if re.search(pat, text_lower))
    active_score = sum(1 for pat in ACTIVE_SIGNALS if re.search(pat, text_lower))
    completed_score = sum(1 for pat in COMPLETED_SIGNALS if re.search(pat, text_lower))

    # Completed items are active (they succeeded), not failed
    active_score += completed_score * 0.5

    total = dep_score + fail_score + active_score + 0.01  # avoid div/0

    # Determine status — conservative: prefer active unless strong signal
    # "A를 제거하고 B로 교체" = this is a CURRENT decision, not deprecated
    # Only mark deprecated if the chunk itself IS the deprecated thing
    if dep_score >= 2 and dep_score / total > 0.5 and active_score <= 1:
        return "deprecated", min(0.9, 0.5 + dep_score * 0.1)
    elif fail_score >= 2 and fail_score / total > 0.4 and active_score <= 1:
        return "failed", min(0.85, 0.4 + fail_score * 0.1)
    elif active_score > 0 and active_score / total > 0.3:
        return "active", min(0.9, 0.5 + active_score * 0.1)
    else:
        return "active", 0.5  # default: active with low confidence


def run_auto_label(dry_run: bool = False) -> dict:
    """Label chunks using weak supervision with strict guardrails.

    Guardrails:
    - core_md / memory_md / session* chunks are forced active (avoid AGENTS/MEMORY poisoning)
    - only daily_log / project_md are auto-labeled as deprecated/failed candidates
    """
    conn = get_conn()
    try:
        if not dry_run:
            with conn.cursor() as cur:
                # Reset potentially poisoned labels on core knowledge + transcripts.
                cur.execute("""
                    UPDATE memory_chunks c
                    SET status='active', status_confidence=0.5, decided_at=now()
                    FROM memory_documents d
                    WHERE c.document_id=d.id
                      AND d.source_type IN ('core_md', 'memory_md', 'session', 'session_live')
                      AND c.status != 'active'
                """)
            conn.commit()

        with conn.cursor() as cur:
            cur.execute("""
                SELECT c.id, c.content, d.source_type, d.source_path
                FROM memory_chunks c
                JOIN memory_documents d ON c.document_id = d.id
                WHERE d.source_type IN ('daily_log', 'project_md')
            """)
            rows = cur.fetchall()

        stats = {
            "total": len(rows),
            "active": 0,
            "deprecated": 0,
            "failed": 0,
            "changed": 0,
            "guardrailResets": 0,
        }

        updates = []
        for chunk_id, content, source_type, source_path in rows:
            status, confidence = score_signals(content)
            stats[status] += 1
            updates.append((status, confidence, str(chunk_id)))

        if not dry_run:
            with conn.cursor() as cur:
                # Count guardrail resets for visibility
                cur.execute("""
                    SELECT count(*)
                    FROM memory_chunks c
                    JOIN memory_documents d ON c.document_id=d.id
                    WHERE d.source_type IN ('core_md', 'memory_md', 'session', 'session_live')
                      AND c.status='active' AND c.status_confidence=0.5
                """)
                stats["guardrailResets"] = cur.fetchone()[0]

                for status, confidence, chunk_id in updates:
                    cur.execute(
                        "UPDATE memory_chunks SET status = %s, status_confidence = %s, decided_at = now() "
                        "WHERE id = %s AND (status != %s OR status_confidence != %s)",
                        (status, confidence, chunk_id, status, confidence)
                    )
                    if cur.rowcount > 0:
                        stats["changed"] += 1
            conn.commit()

        return stats
    finally:
        put_conn(conn)


if __name__ == "__main__":
    dry = "--dry-run" in sys.argv
    stats = run_auto_label(dry_run=dry)
    mode = "DRY RUN" if dry else "APPLIED"
    print(f"[{mode}] {stats}")
