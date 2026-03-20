# OpenClaw Startup Checklist

이 파일은 gateway가 시작될 때마다 읽는 운영 체크리스트다. 아래 순서대로 상태를 점검하고, 복구가 필요하면 최소 범위만 건드린다.

## 1. 컨텍스트 복구

- `PROJECT-STATE.md` 먼저 읽기
- `MEMORY.md` 먼저 읽기
- `memory/` 최신 일일 로그 읽기 (오늘 + 어제)
- 진행 중이던 작업이 있으면 현재 상태를 먼저 파악

## 2. 인프라 점검

### Memory V3

- 포트 계산:
  - `MEMORY_PORT=$(awk -F= '/^MEMORY_PORT=/{gsub(/\047|\"/,"",$2); print $2; exit}' ~/.openclaw/services/memory-v2/.env 2>/dev/null)`
  - `MEMORY_PORT=${MEMORY_PORT:-18790}`
  - `MEMORY_URL="http://127.0.0.1:${MEMORY_PORT}"`
- API 서버:
  - `curl -sf "${MEMORY_URL}/health"` 확인
  - systemd user가 있으면: `systemctl --user restart openclaw-memory-v3-api.service`
  - 없으면: `pgrep -af "server.py" || nohup ~/.openclaw/services/memory-v2/.venv/bin/python ~/.openclaw/services/memory-v2/server.py >/tmp/openclaw-memory-v3-api.log 2>&1 &`
- Atomize Worker:
  - systemd user가 있으면: `systemctl --user status openclaw-memory-v3-atomize.service`
  - 없으면: `pgrep -af "atomize_worker.py"`
- LLM Atomize Worker:
  - `GOOGLE_API_KEY`가 있을 때만 체크
  - systemd user가 있으면: `systemctl --user status openclaw-memory-v3-llm-atomize.service`
  - 없으면: `pgrep -af "llm_atomize_worker.py"`

### Ollama

- `curl -sf http://127.0.0.1:11434/api/tags` 확인
- 실패 시:
  - systemd system이 있으면: `sudo systemctl restart ollama`
  - 없으면: `pgrep -af "ollama serve" || nohup ollama serve >/tmp/openclaw-ollama.log 2>&1 &`
- 모델 누락 시: `ollama pull bge-m3:latest`

### 필수 서비스

아래 서비스는 running 상태여야 한다. 없으면 재시작한다.

- `openclaw-memory-v3-api`
- `openclaw-memory-v3-atomize`
- `openclaw-memory-v3-flush.timer`
- `openclaw-memory-v3-snapshot.timer`
- `openclaw-memory-v3-eviction.timer`
- `openclaw-memory-v3-llm-atomize` (있을 때만)
- `openclaw-memory-v3-backfill-ko.timer` (있을 때만)

## 3. 사용자 보고

- 재시작 또는 복구가 있었으면 짧게 상태 보고
- 포함 항목:
  - 현재 시간
  - Memory V3 / Ollama / Gateway 상태
  - 진행 중이던 작업 요약
- 사용자 메시지를 보냈다면 마지막 응답은 반드시 `NO_REPLY`

## 4. 작업 재개

- Memory V3 검색:
  - `curl -s -X POST "${MEMORY_URL}/v1/memory/search" -H "Content-Type: application/json" -d '{"query":"진행 중 작업 현재 상태","maxResults":5}'`
- 오늘/어제 일일 로그와 검색 결과 기준으로 미완료 작업이 있으면 이어서 진행
- 없으면 상태만 보고하고 대기
