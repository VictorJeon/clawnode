# Memory V3 Setup Contract — Phase 0

> 목적: 현재 개발자 로컬 환경에 묶여 있는 Memory V3 스택을 고객 환경에 설치 가능한 형태로 정의한다.
> 범위: 아직 setup 스크립트를 구현하지 않는다. 먼저 설치 계약, 배치 경로, 설정 주입 방식, 프로세스 모델을 고정한다.

---

## 1. 목표

Phase 0의 목표는 하나다.

"고객 머신에서 Memory V3를 어떤 파일/경로/프로세스/환경변수로 구성할지"를 구현 가능한 계약으로 고정한다.

이 단계가 끝나야 다음 단계가 가능하다.
- PostgreSQL + pgvector 설치 자동화
- sidecar payload 배포
- Ollama 설치 자동화
- launchd/systemd 등록
- `openclaw.json` patch

---

## 2. 비목표

Phase 0에서 아직 하지 않는 것:
- `services/memory-v2` 전체 리팩터링
- installer에 Docker/Ollama/DB 로직 추가
- launchd/systemd 실제 구현
- migration 실행 자동화
- 고객용 E2E

즉 Phase 0은 “설치 계약 확정” 단계다.

---

## 3. 현재 상태 요약

현재 Memory V3는 두 레이어로 나뉜다.

1. OpenClaw plugin
- 위치: `~/.openclaw/extensions/memory-v3`
- 역할: `memory_search`, auto-recall, post-compaction continuity
- sidecar를 `baseUrl`로 호출

2. Memory sidecar
- 현재 위치: `~/.openclaw/workspace-nova/services/memory-v2`
- 역할: FastAPI search API, ingest, atomize workers, relations, snapshots, eviction

문제는 sidecar가 아직 설치 가능한 패키지 단위가 아니라는 점이다.

현재 코드에는 개발자 환경 하드코딩이 존재한다.
- workspace path 하드코딩
- session path 하드코딩
- local Ollama endpoint 고정 원칙
- cron shell script에 절대경로 사용
- 일부 LLM credential fallback이 `~/.openclaw/openclaw.json`에 의존

---

## 4. 현재 하드코딩 / 이식 리스크

### 4.1 `config.py`

현재 하드코딩:
- `WORKSPACES`
  - `global -> ~/.openclaw/workspace-nova`
  - `agent:bolt -> ~/.openclaw/workspace-bolt`
  - `agent:sol -> ~/.openclaw/workspace-sol`
- `EXTRA_GLOBAL_FILES`
  - `~/projects/polymarket-weather-bot/ANALYSIS-STATE.md`
- `OLLAMA_URL/OLLAMA_URLS` 기본값
  - `http://127.0.0.1:11434`

이건 고객 설치 기본값으로 쓰면 안 된다.
특히 원격 Ollama fallback은 더 이상 허용하지 않는다.

### 4.2 세션 ingest 경로

`ingest_sessions.py`, `session_ingest.py`는 현재 아래 경로를 가정한다.
- `~/.openclaw/agents/nova/sessions`
- `~/.openclaw/agents/bolt/sessions`
- `~/.openclaw/agents/sol/sessions`

즉 agent/session layout도 install-time 계약이 필요하다.

### 4.3 절대경로 shell script

현재 cron/maintenance shell script는 절대경로를 포함한다.
예:
- `backfill-ko-cron.sh`
- `eviction-cron.sh`

이건 payload relocation에 취약하다.

### 4.4 LLM credential fallback

Gemini 관련 모듈 일부는:
- env의 `GOOGLE_API_KEY`
- 또는 `~/.openclaw/openclaw.json`의 `env.vars.GOOGLE_API_KEY`
를 본다.

즉 installer가 credential source를 어디로 둘지 명시해야 한다.

---

## 5. 설치 계약의 권장 방향

### 5.1 sidecar 배치 경로

권장 표준 경로:
- code: `~/.openclaw/services/memory-v2`
- venv: `~/.openclaw/services/memory-v2/.venv`
- env file: `~/.openclaw/services/memory-v2/.env`
- logs: `~/.openclaw/logs/memory-v2/`

이유:
- workspace와 서비스 코드를 분리할 수 있음
- `workspace-nova` 같은 dev naming을 제거할 수 있음
- launchd/systemd 작성이 쉬워짐

### 5.2 workspace 계약

권장 기본 workspace mapping:
- `global -> ~/.openclaw/workspace`
- optional agent workspaces:
  - `agent:bolt -> ~/.openclaw/workspace-bolt`
  - `agent:sol -> ~/.openclaw/workspace-sol`

결정 필요:
- 고객 설치에서 multi-agent workspace를 기본으로 둘지
- 아니면 `global` 단일 workspace만 먼저 지원할지

권장:
- V2 첫 버전은 `global`만 필수
- agent별 workspace는 optional feature로 둔다

### 5.3 session ingest 계약

결정 필요:
- 어떤 agent/session 디렉토리를 감시 대상으로 둘지

권장 최소 계약:
- `agent:nova` 또는 `main`에 해당하는 대표 session source 1개만 우선 지원
- 나머지 agent session은 후속 단계에서 확장

이유:
- 지금 구조를 그대로 다 이식하면 설치 복잡도가 급증함

### 5.4 env 계약

Memory sidecar는 아래 env를 기준으로 동작하게 맞춘다.

필수:
- `DATABASE_URL`
- `OLLAMA_URL` 또는 `OLLAMA_URLS`
- `MEMORY_WORKSPACE_GLOBAL`

선택:
- `MEMORY_WORKSPACE_BOLT`
- `MEMORY_WORKSPACE_SOL`
- `GOOGLE_API_KEY`
- `MEMORY_EXTRA_GLOBAL_FILES`

권장 예시:

```dotenv
DATABASE_URL=postgresql://postgres:<PASSWORD>@127.0.0.1:5433/memory_v2
OLLAMA_URL=http://127.0.0.1:11434
MEMORY_WORKSPACE_GLOBAL=/Users/<user>/.openclaw/workspace
GOOGLE_API_KEY=<optional>
```

### 5.5 OpenClaw core 계약

installer는 `openclaw.json`에 아래를 만족시켜야 한다.
- `plugins.allow`에 `memory-v3`
- `plugins.slots.memory = "memory-v3"`
- `plugins.entries["memory-v3"].enabled = true`
- `plugins.entries["memory-v3"].config.baseUrl = "http://127.0.0.1:18790"`

주의:
- merge 방식이어야 한다
- 기존 plugin/channel 설정을 덮어쓰면 안 된다

---

## 6. 프로세스 모델 계약

Phase 0에서 고정할 권장 프로세스는 아래다.

### 필수 프로세스

1. API server
- command: `python server.py`
- bind: `127.0.0.1:18790`

2. Tier 1 atomize worker
- command: `python atomize_worker.py`

### 선택 프로세스

3. Tier 2 worker
- command: `python llm_atomize_worker.py`
- 조건: `GOOGLE_API_KEY` 있고 고품질 extraction이 필요할 때

### maintenance jobs

필수 후보:
- ingest / flush trigger
- snapshot generation
- eviction

결정 필요:
- 항상 daemon처럼 띄울지
- cron/launchd interval job로 둘지

권장:
- API server + Tier1 worker는 상시 프로세스
- snapshot/eviction/flush는 interval job

---

## 7. DB 계약

### 7.1 DB 이름

표준 DB 이름:
- `memory_v2`

이유:
- 현재 실제 코드 기본값과 일치
- 문서와 실코드 drift를 줄임

### 7.2 배치 방식

권장 기본값:
- mac target에서는 native PostgreSQL + native `pgvector` extension
- `Docker`는 기본 경로가 아니라 fallback 후보
- mac V2 기본 기준 버전은 `Homebrew postgresql@17`

이유:
- OpenClaw 본체가 native process인 만큼 운영 모델을 단순하게 유지할 수 있음
- 맥미니 단일 타깃에서는 Docker Desktop 의존성을 줄이는 편이 제품 메시지와도 맞음
- 고객 입장에서 관찰 가능한 런타임 레이어를 줄일 수 있음

### 7.3 포트

권장:
- listen/bind: `127.0.0.1:5433`

### 7.4 schema source of truth

toy schema 금지.

반드시 실제 migration을 실행해야 한다.

중요:
- 현재 repo에는 `003~006`만 있다
- 그러나 `003_memories.sql`은 `memory_documents`, `memory_chunks`, `vector` extension을 선행 조건으로 가정한다
- 즉 setup V2에는 pre-V3 base schema migration이 추가로 필요하다

기준 문서:
- [MEMORY-V3-BASE-SCHEMA.md](/Users/nova/projects/clawnode/docs/MEMORY-V3-BASE-SCHEMA.md)
- [001_base_schema.sql](/Users/nova/projects/clawnode/installer/templates/memory-v3/001_base_schema.sql)

실행 순서:
- `installer/templates/memory-v3/001_base_schema.sql`
- `003_memories.sql`
- `004_memory_v3_phase2.sql`
- `005_bilingual_facts.sql`
- `006_eviction.sql`

### 7.5 보안 계약

- loopback bind only
- random DB password 생성
- env file permission `600`

---

## 8. Ollama 계약

표준 계약:
- local Ollama 사용
- endpoint: `http://127.0.0.1:11434`
- model: `bge-m3:latest`
- dimensions: `1024`

문서상 `nomic-embed-text`나 `768`은 더 이상 기준이 아니다.

설치 후 검증:

```bash
curl -s http://127.0.0.1:11434/api/tags
```

---

## 9. Gemini 계약

Gemini 2.5 Flash는 hot-path retrieval provider가 아니다.

역할:
- Tier 2 atomization
- contradiction/update judgment
- LLM snapshot generation

설치 계약 관점에서의 권장:
- V2 초기 설치에서는 `GOOGLE_API_KEY` 없더라도 bring-up 가능해야 함
- 이 경우 Tier2/LLM snapshot은 degrade되어도 시스템은 동작해야 함

즉 Gemini는:
- **권장 optional** 이지
- **hard requirement** 는 아니다

---

## 10. payload 배포 방식 결정

결정해야 할 항목:

### Option A: repo subtree export
- 장점: 현재 코드 재사용 쉬움
- 단점: 배포 시점 코드 분리/버전 관리 어려움

### Option B: versioned tarball/artifact
- 장점: installer와 payload 버전 고정 쉬움
- 단점: artifact publish 절차 필요

### Option C: secret gist/raw 스크립트가 sidecar 코드까지 bootstrap
- 장점: 배포 단순
- 단점: 코드량 많아지고 유지보수 어려움

권장:
- **Option B**
- installer version과 payload version을 함께 관리할 수 있기 때문

---

## 11. V2 최소 지원 범위

현실적으로 첫 이식 버전에서 보장할 범위는 아래로 제한하는 것이 맞다.

### V2 minimum viable scope
- mac 우선
- `global` workspace 1개 우선
- native PostgreSQL + pgvector
- local Ollama + `bge-m3:latest`
- API server + Tier1 worker
- plugin 연결
- 초기 ingest + retrieval smoke test

### V2 deferred scope
- multi-agent workspace full parity
- Tier2 always-on 기본화
- 모든 기존 maintenance script 이식
- dev 환경의 extra file ingest parity
- WSL까지 memory full-stack parity

즉 첫 목표는 “기억 시스템을 가져온다”이지 “현재 dev 머신을 완전히 복제한다”가 아니다.

---

## 12. 검증 계약

Phase 0가 끝났다고 보려면 아래가 문서로 확정되어야 한다.

### 설치 후 필수 검증

1. API health
```bash
curl -s http://127.0.0.1:18790/health
```

2. stats
```bash
curl -s http://127.0.0.1:18790/v1/memory/stats
```

3. search
```bash
curl -s -X POST http://127.0.0.1:18790/v1/memory/search \
  -H 'Content-Type: application/json' \
  -d '{"query":"현재 프로젝트 상태","maxResults":5}'
```

4. OpenClaw plugin binding
- `plugins.slots.memory = memory-v3`
- `memory-v3` service probe log 확인

5. ingestion path
- `MEMORY.md` 또는 `memory/*.md`를 넣고 flush 후 검색되는지 확인

### Phase 0 exit criteria

아래가 결정되면 Phase 0 종료다.
- payload source 확정
- install target path 확정
- env contract 확정
- process model 확정
- minimum scope 확정
- validation contract 확정

---

## 13. 권장 결정안

지금 기준으로 바로 채택할 권장안:

1. payload는 versioned artifact로 배포한다
2. sidecar 설치 경로는 `~/.openclaw/services/memory-v2`
3. env file 기반 설정으로 바꾼다
4. DB는 mac 기준 native PostgreSQL + pgvector를 기본 경로로 두고, 현재 baseline은 `postgresql@17`로 맞춘다
5. pre-V3 base schema migration을 별도로 확보한다
6. first release는 `global` workspace만 필수 지원
7. Gemini는 optional feature로 둔다
8. API server + Tier1 worker만 우선 필수 프로세스로 본다
9. setup V2는 full parity가 아니라 minimum viable memory stack 재현을 목표로 한다

이 9개가 Phase 0의 실질적인 결론이다.
