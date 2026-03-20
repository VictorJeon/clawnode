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
  - 실패 시: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.memory-v3-api`
- Atomize Worker:
  - `launchctl print gui/$(id -u)/ai.openclaw.memory-v3-atomize | grep "state = running"`
  - 실패 시: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.memory-v3-atomize`
- LLM Atomize Worker:
  - `~/Library/LaunchAgents/ai.openclaw.memory-v3-llm-atomize.plist` 가 있을 때만 체크
  - 실패 시: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.memory-v3-llm-atomize`

### Ollama

- `curl -sf http://127.0.0.1:11434/api/tags` 확인
- 실패 시: `nohup ollama serve >/tmp/openclaw-ollama.log 2>&1 &`
- 모델 누락 시: `ollama pull bge-m3:latest`

### 필수 LaunchAgent

아래 라벨은 PID 또는 running state가 있어야 한다. 없으면 `launchctl kickstart -k gui/$(id -u)/<label>` 로 복구한다.

- `ai.openclaw.gateway`
- `ai.openclaw.memory-v3-api`
- `ai.openclaw.memory-v3-atomize`
- `ai.openclaw.memory-v3-flush`
- `ai.openclaw.memory-v3-snapshot`
- `ai.openclaw.memory-v3-eviction`
- `ai.openclaw.memory-v3-llm-atomize` (있을 때만)
- `ai.openclaw.memory-v3-backfill-ko` (있을 때만)

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
