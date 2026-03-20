# ClawNode Installer V2.1 — 설치기 + 업데이터 통합 스펙

> 작성: Sol | 2026-03-20
> 정리: Codex
> 기준 코드: `installer/scripts/openclaw-setup-v2.sh`

---

## 개요

V2.1의 목표는 2가지다.

1. `openclaw-setup-v2.sh` 하나로 신규 설치와 기존 고객 업데이트를 모두 처리한다.
2. V2 설치 고객에게 `BOOT.md`, 4개 bundled hook, auto-update, memory distill/weekly 기능을 안전하게 추가한다.

핵심 결정:
- 별도 `clawnode-patch.sh`는 만들지 않는다.
- 기존 `openclaw-setup-v2.sh`를 멱등적인 installer + updater로 확장한다.
- 기존 고객 커스터마이징 파일은 보존하되, 인프라 자산과 installer-managed 섹션만 업데이트한다.
- macOS를 1차 범위로 본다. (`LaunchAgent` 기준)

---

## V2.1 핵심 변경점

### 1. 설치기와 패처를 통합

기존 고객도 신규 고객도 같은 엔트리포인트를 사용한다.

```bash
bash <(curl -fsSL https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-v2.sh)
```

실행 시 스크립트는 자동으로 현재 상태를 판별한다.

- OpenClaw 미설치: 신규 설치 모드
- OpenClaw 설치됨 + `~/.openclaw` 존재: 업데이트 모드
- `MEMORY_ONLY=1`: 기존 OpenClaw에 Memory V3만 붙이는 모드 유지

`FORCE_CORE_SETUP=1`이 아닌 이상, 기존 고객 업데이트에서는 onboard를 다시 태우지 않는다.

### 2. hook 4개를 기본 활성화

V2.1부터는 onboarding wizard에 맡기지 않고 installer가 post-onboard 단계에서 bundled hook 4개를 모두 활성화한다.

대상 hook:
- `boot-md`
- `bootstrap-extra-files`
- `command-logger`
- `session-memory`

정책:
- 신규 설치: core setup 직후 활성화
- 기존 고객 업데이트: idempotent enable
- hook이 이미 켜져 있으면 스킵

가능하면 CLI를 우선 사용한다.

```bash
openclaw hooks enable boot-md
openclaw hooks enable bootstrap-extra-files
openclaw hooks enable command-logger
openclaw hooks enable session-memory
```

CLI 실패 시에만 `openclaw.json`의 hook 관련 섹션을 좁은 범위로 patch한다.

### 3. `BOOTSTRAP.md`와 `BOOT.md`를 명확히 분리

둘은 같은 역할이 아니다.

- `BOOTSTRAP.md`
  - brand-new workspace의 1회성 bootstrap ritual
  - onboarding 완료 후 사라지는 파일
- `BOOT.md`
  - gateway 시작 시마다 실행되는 startup checklist
  - `boot-md` hook이 읽는 파일

V2.1이 관리하는 것은 `BOOT.md`다.
`BOOTSTRAP.md`는 신규 workspace의 OpenClaw 기본 bootstrap 흐름에 맡기며, V2.1이 생성/수정 대상으로 삼지 않는다.

---

## 보호 정책

### 절대 덮어쓰지 않는 파일

아래 파일은 기존 고객 업데이트 시 통째로 덮어쓰지 않는다.

- `~/.openclaw/workspace/AGENTS.md`
- `~/.openclaw/workspace/SOUL.md`
- `~/.openclaw/workspace/USER.md`
- `~/.openclaw/workspace/IDENTITY.md`
- `~/.openclaw/workspace/TOOLS.md`
- `~/.openclaw/workspace/HEARTBEAT.md`
- `~/.openclaw/workspace/MEMORY.md`
- `~/.openclaw/workspace/memory/*.md`

### `openclaw.json` 정책

`openclaw.json`은 파일 전체를 보호 대상으로 보지 않는다.
대신 아래 원칙으로 "좁은 범위 patch"만 허용한다.

허용:
- hook enable 관련 섹션
- `memory-v3` plugin wiring 관련 섹션
- installer가 소유하는 최소 인프라 설정

금지:
- 모델/credential/channel/user agent preference 덮어쓰기
- 전체 파일 재생성
- 사용자 수동 설정 제거

### `MEMORY.md` 정책

`MEMORY.md`는 고객 커스터마이징 파일로 취급한다.
단, V2.1의 daily/weekly 기능은 전체 파일을 재작성하지 않고 installer-managed block만 갱신한다.

사용하는 marker:

```md
<!-- OPENCLAW_DAILY_DISTILL_START -->
<!-- OPENCLAW_DAILY_DISTILL_END -->

<!-- OPENCLAW_WEEKLY_PATTERN_START -->
<!-- OPENCLAW_WEEKLY_PATTERN_END -->
```

규칙:
- marker 외부 텍스트는 절대 수정하지 않음
- marker가 없으면 파일 말미에 새로 추가
- marker 내부만 교체

이렇게 해야 `MEMORY.md 보호`와 `자동 증류 기능`을 동시에 만족할 수 있다.

---

## 실제 경로 기준

V2.1은 현재 V2 런타임 배치를 그대로 따른다.

- Memory service root: `~/.openclaw/services/memory-v2`
- Memory plugin root: `~/.openclaw/extensions/memory-v3`
- Workspace: `~/.openclaw/workspace`
- Config: `~/.openclaw/openclaw.json`
- LaunchAgents: `~/Library/LaunchAgents`

중요:
- wrapper script, distill script, auto-update script는 `extensions/memory-v3/services`가 아니라
  `~/.openclaw/services/memory-v2` 아래에 둔다.
- patch/update도 live runtime 경로를 직접 갱신해야 한다.

---

## 추가 기능 1: BOOT.md

### 목적

Gateway 시작 시 다음을 자동 점검한다.

- Memory V3 API / worker 상태 확인
- Ollama 상태 확인
- 필수 LaunchAgent PID 확인
- 필요 시 kickstart
- 최근 작업 컨텍스트 복구
- 사용자에게 상태 보고

### 설치 위치

- `~/.openclaw/workspace/BOOT.md`

### 설치 규칙

- 파일이 없을 때만 생성
- 이미 있으면 건드리지 않음
- 업데이트 모드에서도 동일

### 중요한 구현 조건

#### 1. 포트 하드코딩 금지

`18790` 고정 금지.
Linux/WSL에서는 이미 포트 충돌 시 `18791+`로 이동할 수 있다.

따라서 `BOOT.md` 안의 예시는 아래 원칙으로 작성한다.

- `~/.openclaw/services/memory-v2/.env`에서 `MEMORY_PORT` 읽기
- 없으면 `18790` fallback

예시:

```bash
MEMORY_PORT=$(awk -F= '/^MEMORY_PORT=/{gsub(/\047|\"/,"",$2); print $2; exit}' ~/.openclaw/services/memory-v2/.env 2>/dev/null)
MEMORY_PORT=${MEMORY_PORT:-18790}
MEMORY_URL="http://127.0.0.1:${MEMORY_PORT}"
curl -sf "${MEMORY_URL}/health"
```

#### 2. `boot-md` hook 전제

`BOOT.md`가 실행되려면 `boot-md` hook이 활성화돼 있어야 한다.
V2.1 installer/updater는 이 hook을 자동 enable한다.

#### 3. `BOOTSTRAP.md`와 혼동 금지

`BOOT.md`는 startup hook용이며, `BOOTSTRAP.md` 대체물이 아니다.

### 고객용 BOOT.md 내용 방향

BOOT.md는 짧고 실행 가능한 checklist로 유지한다.

포함 항목:
- `SESSION-STATE.md` 읽기
- 오늘/어제 daily log 확인
- Memory API health check
- Ollama tags check
- 필수 LaunchAgent `kickstart`
- 상태 보고 후 `NO_REPLY`

비포함 항목:
- 장문의 설명
- onboarding ritual
- 최초 자기소개 유도

### 템플릿 파일

신규 파일:
- `installer/templates/BOOT-customer.md`

---

## 추가 기능 2: bundled hook 4개 자동 활성화

### 대상

- `boot-md`
- `bootstrap-extra-files`
- `command-logger`
- `session-memory`

### 설치 시점

- 신규 설치: core setup 완료 직후
- 기존 고객 업데이트: infra sync 직후
- `MEMORY_ONLY=1` 모드에서도 enable 시도

### 역할 요약

- `boot-md`
  - gateway startup 시 `BOOT.md` 실행
- `bootstrap-extra-files`
  - 추가 bootstrap 파일 injection
- `command-logger`
  - command audit log 기록
- `session-memory`
  - `/new`, `/reset` 시 세션 markdown archive 생성

### `session-memory`와 Memory V3 관계

둘은 중복이 아니라 계층이 다르다.

- `session-memory`: markdown archive / 회상 원문 보존
- `memory-v3`: vector + atomic memory + snapshot retrieval

따라서 V2.1에서는 둘 다 켠다.

---

## 추가 기능 3: Auto-update

### 목적

매일 1회 OpenClaw core와 관련 인프라를 최신 상태로 동기화한다.

### LaunchAgent

- 라벨: `ai.openclaw.auto-update`
- 스케줄: 매일 04:00
- `RunAtLoad: false`
- `StartCalendarInterval: { Hour: 4, Minute: 0 }`
- `ThrottleInterval: 3600`

### Wrapper 위치

- `~/.openclaw/services/memory-v2/run-auto-update.sh`

### 동작 원칙

#### 1. 설치 경로 추상화

`npm update -g openclaw`를 하드코딩하지 않는다.
현재 installer가 이미 가지고 있는 OpenClaw binary resolver를 재사용한다.

즉, 아래 경우를 모두 처리해야 한다.
- npm global install
- pnpm install 위치 (`~/.local/share/pnpm/openclaw` 등)
- PATH에 있는 `openclaw`

#### 2. update 후 즉시 종료가 아니라 검증까지 포함

자동 업데이트는 아래 순서로 동작한다.

1. OpenClaw binary update
2. bundled hook enable 재확인
3. memory-v3 plugin / wrapper / plist sync
4. gateway restart
5. health check
   - gateway running
   - memory API health
   - Ollama tags
   - plugin load log

검증 실패 시:
- 로그 남김
- 사용자에게 보고 가능하면 보고
- 무한 재시작 루프는 피함

#### 3. auto-update 대상 범위

포함:
- OpenClaw core binary
- installer-owned wrapper/plist/BOOT template sync

제외:
- 고객 workspace 문서 전체 덮어쓰기
- MEMORY.md 외부 섹션
- AGENTS/SOUL/USER 재생성
- remote server provisioning

---

## 추가 기능 4: 메모리 증류

### 목표

기존 메모리와 일일 로그를 요약해 사람이 읽기 쉬운 상위 기억을 유지한다.

V2.1에서는 2개 작업을 추가한다.

1. daily distill
2. weekly pattern

### 공통 원칙

- 실제 service root는 `~/.openclaw/services/memory-v2`
- Memory API base URL은 `.env`의 `MEMORY_PORT`를 기준으로 계산
- Gemini는 optional
- `GOOGLE_API_KEY`가 없으면 distill/weekly는 skip하고 로그만 남김
- API 요청 body는 현재 V3 계약에 맞게 `maxResults`를 사용

### 4-A. Daily Distill

#### LaunchAgent
- 라벨: `ai.openclaw.memory-v3-distill`
- 스케줄: 매일 23:50
- `RunAtLoad: false`
- `StartCalendarInterval: { Hour: 23, Minute: 50 }`

#### Wrapper 위치
- `~/.openclaw/services/memory-v2/run-distill.sh`

#### Python 위치
- `~/.openclaw/services/memory-v2/daily_distill.py`

#### 로직
1. 오늘 날짜 계산 (`YYYY-MM-DD`)
2. `workspace/memory/{today}.md` 읽기
3. Memory API 검색
4. Gemini로 핵심 결정/사실/교훈 요약 생성
5. `MEMORY.md`의 `OPENCLAW_DAILY_DISTILL` marker block만 갱신
6. 원문 보존용으로 `memory/distill/{today}.md`도 저장 가능

#### 검색 요청 예시

```json
{
  "query": "2026-03-20 오늘 작업 결정 사실",
  "maxResults": 20
}
```

### 4-B. Weekly Pattern

#### LaunchAgent
- 라벨: `ai.openclaw.memory-v3-weekly`
- 스케줄: 매주 일요일 23:50
- `RunAtLoad: false`
- `StartCalendarInterval: { Weekday: 0, Hour: 23, Minute: 50 }`

#### Wrapper 위치
- `~/.openclaw/services/memory-v2/run-weekly.sh`

#### Python 위치
- `~/.openclaw/services/memory-v2/weekly_pattern.py`

#### 로직
1. 최근 7일 로그 파일 읽기
2. Memory API 검색 / entity frequency 참고
3. Gemini로 반복 패턴 요약
4. `MEMORY.md`의 `OPENCLAW_WEEKLY_PATTERN` marker block만 갱신
5. 히스토리 파일 `memory/weekly-{date}.md` 저장

### 환경변수

- `GOOGLE_API_KEY`
- `OLLAMA_URL`
- `MEMORY_PORT`
- `MEMORY_HOST`

`GEMINI_API_KEY`, `MEMORY_V3_URL` 같은 별도 이름은 도입하지 않는다.
현재 런타임 계약을 그대로 따른다.

---

## 기존 고객 업데이트 전략

### separate patch script를 만들지 않는 이유

별도 patch script를 만들면 아래 문제가 생긴다.

- 설치 로직과 업데이트 로직 drift
- payload/plist/wrapper 변경 시 2군데 유지보수
- gist 배포선 2개 관리
- 신규 설치는 되는데 patch는 깨지는 분기 증가

따라서 V2.1은 `openclaw-setup-v2.sh` 자체를 updater로 만든다.

### 업데이트 모드에서 하는 일

기존 OpenClaw 설치 감지 시 아래만 수행한다.

1. core reinstall 스킵
2. bundled hook 4개 enable
3. memory-v3 plugin / payload / wrapper sync
4. 새 plist 설치 또는 기존 plist reload
5. `BOOT.md` 없으면 생성
6. auto-update / distill / weekly job 설치
7. gateway restart
8. health check 및 리포트

### 업데이트 모드에서 하지 않는 일

- onboarding 재실행
- 이름/토큰/모델 재질문
- AGENTS/SOUL/USER/MEMORY/IDENTITY 덮어쓰기
- `memory/*.md` 삭제/재생성
- 고객 설정 전체 초기화

### 버전 파일

유지:
- `~/.openclaw/.clawnode-version`

용도:
- 마지막 installer-managed infra 버전 기록
- summary/report에 표시
- update mode에서 drift 판단 보조

---

## 파일 구조

```text
installer/
├── scripts/
│   └── openclaw-setup-v2.sh          # installer + updater 통합
├── templates/
│   ├── BOOT-customer.md              # 신규
│   └── memory-v3/
│       └── payload/
│           ├── daily_distill.py      # 신규
│           ├── weekly_pattern.py     # 신규
│           ├── run-auto-update.sh    # 신규 템플릿 또는 wrapper 생성 로직 추가
│           ├── run-distill.sh        # 신규 템플릿 또는 wrapper 생성 로직 추가
│           ├── run-weekly.sh         # 신규 템플릿 또는 wrapper 생성 로직 추가
│           ├── snapshot_generator.py # 기존
│           ├── llm_snapshot.py       # 기존
│           ├── flush-cron.sh         # 기존
│           ├── eviction-cron.sh      # 기존
│           └── backfill-ko-cron.sh   # 기존
```

실제 배치 경로:
- wrapper / Python runtime: `~/.openclaw/services/memory-v2`
- plugin files: `~/.openclaw/extensions/memory-v3`

---

## 신규 LaunchAgent 요약

| 라벨 | 스케줄 | 실제 실행 파일 |
|------|--------|----------------|
| `ai.openclaw.auto-update` | 매일 04:00 | `run-auto-update.sh` |
| `ai.openclaw.memory-v3-distill` | 매일 23:50 | `run-distill.sh` |
| `ai.openclaw.memory-v3-weekly` | 일요일 23:50 | `run-weekly.sh` |

기존 유지:
- `ai.openclaw.memory-v3-api`
- `ai.openclaw.memory-v3-atomize`
- `ai.openclaw.memory-v3-flush`
- `ai.openclaw.memory-v3-snapshot`
- `ai.openclaw.memory-v3-eviction`
- `ai.openclaw.memory-v3-llm-atomize`
- `ai.openclaw.memory-v3-backfill-ko`

---

## Gateway / LaunchAgent 주의사항

### ThrottleInterval

V2.1에서는 gateway LaunchAgent의 `ThrottleInterval`을 최소 `45`로 맞춘다.

정책:
- 기존 값이 `30` 미만이면 `45`로 올림
- 이미 `45` 이상이면 유지
- update mode에서도 멱등 적용

### Kickstart 기준

`BOOT.md`와 updater health check는 아래 라벨을 기준으로 상태를 본다.

- `ai.openclaw.gateway`
- `ai.openclaw.memory-v3-api`
- `ai.openclaw.memory-v3-atomize`
- `ai.openclaw.memory-v3-llm-atomize`
- `ai.openclaw.memory-v3-flush`
- `ai.openclaw.memory-v3-snapshot`
- `ai.openclaw.memory-v3-eviction`
- `ai.openclaw.memory-v3-backfill-ko`
- `ai.openclaw.auto-update`
- `ai.openclaw.memory-v3-distill`
- `ai.openclaw.memory-v3-weekly`

---

## 테스트 체크리스트

### 신규 설치
- [ ] V2 신규 설치에서 hook 4개 자동 enable 확인
- [ ] `BOOT.md` 자동 생성 확인 (없을 때만)
- [ ] auto-update/distill/weekly LaunchAgent 생성 확인
- [ ] gateway / memory / Ollama health 확인

### 기존 고객 업데이트
- [ ] 기존 설치에서 onboard 재실행 안 함
- [ ] AGENTS/SOUL/USER/MEMORY/IDENTITY 미변경 확인
- [ ] `BOOT.md` 없으면 생성, 있으면 미변경 확인
- [ ] hook 4개 enable 확인
- [ ] wrapper/plist payload 갱신 확인
- [ ] update mode 2회 실행해도 동일 결과 확인

### distill / weekly
- [ ] `GOOGLE_API_KEY` 없을 때 skip + log 확인
- [ ] `GOOGLE_API_KEY` 있을 때 marker block만 갱신 확인
- [ ] `MEMORY.md` marker 외부 내용 불변 확인
- [ ] `memory/weekly-*.md` 히스토리 생성 확인

### auto-update
- [ ] OpenClaw 설치 경로가 npm/pnpm 각각일 때 update 동작 확인
- [ ] update 후 hook 재활성화 / infra sync 확인
- [ ] gateway restart 후 health check 통과 확인

---

## 구현 우선순위

1. `openclaw-setup-v2.sh`를 updater로 재구성
2. hook 4개 자동 enable 추가
3. `BOOT-customer.md` + `BOOT.md` 생성 로직 추가
4. auto-update LaunchAgent 추가
5. distill / weekly Python + wrapper + LaunchAgent 추가
6. `MEMORY.md` managed block 정책 구현

