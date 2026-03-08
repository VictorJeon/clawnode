# ClawNode 설치 시스템 — 개발 문서 v2.3

> CLI 설치 스크립트 기반
> 현재 기준: OpenClaw 코어 설치는 구현됨, Memory V3 V2 install path는 구현됨, 격리된 E2E 검증은 계속 필요함
> 목적: 기존 `installer/scripts/openclaw-setup.sh`를 웹사이트 약속과 맞는 V2로 어떻게 확장할지 정의한다

---

## 목차

1. 아키텍처
2. 현재 구현 상태
3. 현실 기준 갭 분석
4. Setup Script V2 구현 단계
5. 테스트
6. 배포
7. 보안

---

## 1. 아키텍처

### 이 문서의 역할

이 문서는 새 설치기를 따로 설계하는 문서가 아니다.

목표는 기존 `installer/scripts/openclaw-setup.sh`를 기준으로 아래를 정리하는 것이다.

1. 현재 setup 스크립트가 어디까지 구현되어 있는지
2. Memory V3를 붙이려면 어떤 Step을 추가해야 하는지
3. 웹사이트에서 약속한 범위와 실제 설치 범위를 어떻게 맞출지

즉 문서의 중심 질문은 항상 이것이다.

"기존 setup.sh를 어떻게 업데이트해서 고객 설치 경험을 V2로 끌어올릴 것인가?"

### 왜 CLI인가

| 비교 | GUI 앱 | CLI 스크립트 |
|------|--------|-------------|
| 배포 | 앱 패키징/업데이트 필요 | Gist/스크립트 교체로 즉시 반영 |
| 유지보수 | GUI/IPC/서명까지 관리 | 설치 로직 중심 |
| 고객 경험 | 앱 설치 후 위자드 | `.command` / `.bat` 실행 |
| 실제 필요 기능 | 대시보드 포함 과설계 | 설치 후 Telegram 사용이 핵심 |

결론: 고객 설치 경험은 GUI보다 설치 자동화가 중요하다.

### 현재 시스템 구성

```text
[고객 맥/WSL]
  ├─ OpenClaw installer
  │   ├─ 기본 도구 설치
  │   ├─ OpenClaw 설치 + onboarding
  │   ├─ Telegram 연결
  │   └─ workspace 템플릿 생성
  │
  └─ (V2 목표) Memory V3 stack
      ├─ OpenClaw plugin: memory-v3
      ├─ Memory sidecar: services/memory-v2
      ├─ PostgreSQL + pgvector
      ├─ Ollama (bge-m3:latest)
      ├─ Tier1 worker
      ├─ Tier2 worker (선택)
      └─ maintenance jobs (flush/snapshot 등)
```

### 가장 중요한 현실

`memory-v3`는 메모리 엔진 본체가 아니다.

실제 구조는 아래처럼 나뉜다.

1. `~/.openclaw/extensions/memory-v3`
   - OpenClaw memory plugin
   - `memory_search` 툴 제공
   - `before_agent_start`, `after_compaction` 훅 사용
   - `baseUrl`로 memory sidecar 호출

2. `~/.openclaw/workspace-nova/services/memory-v2`
   - 실제 memory server / ingest / worker / snapshot / search 구현
   - FastAPI + PostgreSQL + pgvector + Ollama 기반

즉 setup V2는 기존 `setup.sh`에 단순 옵션 하나를 더하는 수준이 아니다.
기존 설치 Step 뒤에 memory 전용 Step들을 체계적으로 붙여야 한다.

### 파일 위치

| 항목 | 현재 위치 | 비고 |
|------|-----------|------|
| mac 설치 스크립트 | `installer/scripts/openclaw-setup.sh` | E2E 검증됨 |
| WSL 설치 스크립트 | `installer/scripts/openclaw-setup-wsl.sh` | 정적 검토 + dry-run 통과 |
| Windows 런처 | `installer/OpenClaw-Install-Windows.bat` | WSL 부트스트랩 보강 완료 |
| Memory V3 plugin | `~/.openclaw/extensions/memory-v3` | 외부 사용자 환경 의존 |
| Memory sidecar | `~/.openclaw/workspace-nova/services/memory-v2` | 현재 dev 경로 |
| 개발 문서 | `docs/DEVELOPMENT.md` | 이 문서 |

---

## 2. 현재 구현 상태

### ✅ 구현 완료

| # | 항목 | 상태 |
|---|------|------|
| 1 | mac용 OpenClaw 설치 스크립트 | 구현 완료 |
| 2 | mac용 OpenClaw V2 래퍼 (`openclaw-setup-v2.sh`) | 구현 완료 |
| 3 | WSL용 OpenClaw 설치 스크립트 | 구현 완료 |
| 4 | Windows `.bat` → WSL 부트스트랩 | 구현 완료 |
| 5 | mac용 V2 `.command` 런처 | 구현 완료 |
| 6 | Node/OpenClaw/onboarding/Telegram/workspace 기본 설치 | 구현 완료 |
| 7 | Tailscale 기반 원격 접속 플로우 | 구현 완료 |
| 8 | 입력값 재사용 / 로그 / DRY_RUN | 구현 완료 |
| 9 | WSL script dry-run | 통과 |
| 10 | WSL/Windows bootstrap 호환성 수정 | 반영 완료 |
| 11 | V2 memory payload staging / launchd / health check scaffold | 구현 완료 |

### ❌ 아직 미구현

| # | 항목 | 중요도 | 비고 |
|---|------|--------|------|
| 1 | Memory sidecar payload 배포 방식 확정 | 높음 | launcher/gist 배포 버전 고정 필요 |
| 2 | 격리된 E2E 검증 환경 정착 | 높음 | active `~/.openclaw` 대상으로 검증하면 안 됨 |
| 3 | PostgreSQL + pgvector 프로비저닝 | 완료 | mac baseline `postgresql@17`, WSL native PostgreSQL |
| 4 | Ollama + `bge-m3:latest` 설치 | 완료 | install / serve / model pull / tags check 포함 |
| 5 | Memory service daemon/worker 등록 | 완료 | API / atomize / flush / snapshot / eviction 등록 |
| 6 | `openclaw.json`에 memory-v3 plugin 연결 | 높음 | 실제 plugin config 방식으로 패치해야 함 |
| 7 | MEMORY.md + memory 디렉토리 bootstrap | 중간 | 설치 후 즉시 ingest 가능해야 함 |
| 8 | 초기 ingest / stats / search 검증 | 완료 | `/health` + `/stats` + `/search` smoke test |
| 9 | maintenance schedule (flush/snapshot) | 완료 | flush / snapshot / eviction / ko backfill 등록 |
| 10 | gateway cron 기반 distillation jobs | 중간 | memory infra와는 별도 레이어 |

### V2 구현 현황

현재 repo 기준으로는 아래까지 구현되어 있다.

1. 별도 V2 wrapper script
   - `installer/scripts/openclaw-setup-v2.sh`
2. memory payload template
   - `installer/templates/memory-v3/payload`
   - `installer/templates/memory-v3/001_base_schema.sql`
3. native PostgreSQL bring-up
4. Python 3.11~3.13 선택 + venv 구성
5. real migration 실행 + migration tracking
6. `openclaw.json` memory plugin merge patch
7. launchd/systemd plist-wrapper 및 timer 생성
8. Ollama install / serve / `bge-m3:latest` pull
9. `/health`, `/v1/memory/stats`, `/v1/memory/search`, gateway plugin load smoke check
10. snapshot / eviction / ko backfill maintenance job 등록

즉 V2는 더 이상 빈 초안은 아니다.

다만 아직 고객 배포 가능 상태라고 보지는 않는다.

이유:
1. launcher에서 받을 gist/raw 배포본이 아직 고정되지 않았다
2. active 사용자 프로필을 대상으로 한 실검증은 금지해야 한다
3. 다음 E2E는 반드시 격리된 `HOME`, 별도 DB, 별도 LaunchAgents namespace에서 돌아야 한다

---

## 3. 현실 기준 갭 분석

### 문서와 실제 코드가 달랐던 부분

1. **DB 이름**
   - 예전 문서: `openclaw_memory`
   - 실제 sidecar 기본값: `memory_v2`
   - 기준: `DATABASE_URL` env 또는 기본 `dbname=memory_v2`

2. **임베딩 모델 / 차원**
   - 예전 문서: `nomic-embed-text`, `768`
   - 실제 코드: `bge-m3:latest`, `1024`

3. **OpenClaw 연결 방식**
   - 예전 문서: `c.memory.v3 = { ... }`
   - 실제 방식: `plugins.allow`, `plugins.slots.memory`, `plugins.entries["memory-v3"].config`

4. **Memory V3의 정체**
   - 예전 문서: 설치 스크립트에서 DB만 띄우면 되는 것처럼 서술
   - 실제 구조: plugin + Python sidecar + DB + Ollama + workers + jobs

5. **서비스 경로 일반화 부족**
   - 현재 sidecar는 개발자 환경 기준 workspace path를 하드코딩하고 있음
   - fresh machine용 설치 전에 이 부분을 일반화하거나 install-time patch를 해야 함

### Setup Script V2의 진짜 목표

V2는 “OpenClaw를 설치한다”가 아니라 아래를 완성해야 한다.

1. OpenClaw core 설치
2. memory-v3 plugin 활성화
3. memory sidecar 배치
4. PostgreSQL + pgvector 준비
5. Ollama + `bge-m3:latest` 준비
6. API/worker/jobs 상시 실행
7. 초기 ingest + search 검증

이 중 하나라도 빠지면 “기억하는 OpenClaw”는 성립하지 않는다.

### 이번 검증에서 실제로 드러난 문제

실환경 bring-up 리허설에서 아래 문제가 확인되었다.

1. Python 3.14 호환성 문제
   - `watchfiles==1.0.4` wheel/build가 실패했다
   - 대응: V2가 Python 3.11~3.13만 자동 선택하도록 수정

2. 재실행 시 payload staging이 runtime 자산을 덮어쓸 수 있었다
   - `.env`, `.venv`, `state/`, `logs/`를 보존하지 않았다
   - 대응: staging exclude 추가

3. migration 재실행 안전성이 없었다
   - `003_memories.sql`의 backfill insert가 다시 실행될 수 있었다
   - 대응: `installer_schema_migrations` 추적 및 schema signature 기반 skip 추가

4. 실환경 검증 자체가 잘못된 방식이었다
   - active `~/.openclaw`와 live `memory_v2`를 직접 건드리면 안 된다
   - 이후 검증 원칙: 격리된 `HOME`/DB/launchd label namespace 필수

---

## 4. Setup Script V2 구현 단계

### Phase 0: 메모리 서비스 설치 계약 정리

이 단계 없이 바로 setup V2를 구현하면 안 된다.

기준 문서:
- [MEMORY-V3-SETUP-CONTRACT.md](/Users/nova/projects/clawnode/docs/MEMORY-V3-SETUP-CONTRACT.md)

필수 정리 항목:
- sidecar payload를 어디서 가져올지 확정
  - 예: versioned tarball / repo export / 별도 artifact
- 설치 대상 경로 확정
  - 예: `~/.openclaw/services/memory-v2`
- `config.py`의 하드코딩 제거 또는 install-time patch 전략 확정
  - workspace mapping
  - Ollama URL
  - optional extra files
- Tier2 worker를 기본 활성화할지 옵션화할지 결정

권장 방향:
- sidecar 설정은 가능한 env file로 분리
- 고객별 값은 코드 수정이 아니라 env/templating으로 주입
- 첫 릴리스 목표는 dev 환경의 1:1 복제가 아니라, 고객 환경에서 운영 가능한 최소 메모리 스택을 재현하는 것이다
- 설치 전략은 "새 설치기 작성"이 아니라 "기존 `openclaw-setup.sh`에 memory Step을 증설"하는 방식으로 간다

### Phase A: Native PostgreSQL + pgvector

목표: memory sidecar가 실제로 붙을 DB를 준비한다.

권장 구현 방식:
- mac mini 타깃에서는 native PostgreSQL을 우선 기준으로 삼는다
- `Docker`는 기본 경로가 아니라, native bring-up이 불안정할 때만 fallback 후보로 본다
- OpenClaw 본체는 계속 native process로 유지한다
- loopback bind만 허용
- DB 이름은 실제 코드 기준 `memory_v2`
- 현재 mac V2 baseline은 `Homebrew postgresql@17`이다

현재까지 확인된 사실:
- `pgvector` extension file/link 보정이 필요할 수 있다
- `vector` extension은 설치되어 있고, `gen_random_uuid()`는 `pg_catalog`에 있으므로 최소 bring-up에 `pgcrypto` extension은 필수가 아니다
- 반면 `memory-v2` repo에는 `003` 이전 base migration이 없다

즉 Phase A의 실제 핵심은 두 가지다.

1. native PostgreSQL을 올린다
2. `003~006` 이전에 필요한 base schema를 먼저 준비한다

기준 문서:
- [MEMORY-V3-SETUP-CONTRACT.md](/Users/nova/projects/clawnode/docs/MEMORY-V3-SETUP-CONTRACT.md)
- [MEMORY-V3-BASE-SCHEMA.md](/Users/nova/projects/clawnode/docs/MEMORY-V3-BASE-SCHEMA.md)

현재 installer 기준 base migration 파일:
- [001_base_schema.sql](/Users/nova/projects/clawnode/installer/templates/memory-v3/001_base_schema.sql)

기존 `setup.sh` 반영 방식:
- 현재 Step 6 이후에 DB bring-up Step 추가
- `brew`, `launchctl`, `psql`, migration 실행까지 한 흐름으로 묶기
- 설치 산출물은 `DATABASE_URL`로 다음 Step에 넘기기

예시 방향:

```bash
PG_PORT=5433
PG_DB="memory_v2"
PG_PASSWORD="$(openssl rand -hex 16)"

brew install postgresql@17 pgvector
brew services start postgresql@17
createdb "$PG_DB" || true
```

중요:
- toy schema를 직접 만들면 안 된다.
- `003_memories.sql`은 단독 시작점이 아니다.
- `memory_documents`, `memory_chunks`, `vector` extension이 먼저 준비되어 있어야 한다.
- 반드시 실제 sidecar migration을 실행해야 한다.
- native extension 설치/로딩 방식은 실제 mac 환경 기준으로 검증해야 한다.

선행 필요 항목:
- base schema for `memory_documents`
- base schema for `memory_chunks`
- `CREATE EXTENSION IF NOT EXISTS vector`

실행 대상:
- `installer/templates/memory-v3/001_base_schema.sql`
- `migrations/003_memories.sql`
- `migrations/004_memory_v3_phase2.sql`
- `migrations/005_bilingual_facts.sql`
- `migrations/006_eviction.sql`

설치 산출물:
- service env file에 `DATABASE_URL` 저장
- 권한 `600`

### Phase B: Memory sidecar payload 설치

목표: `services/memory-v2`를 fresh machine에서도 실행 가능하게 배치한다.

기존 `setup.sh` 반영 방식:
- DB Step 다음에 payload unpack / copy Step 추가
- 여기서 `~/.openclaw/services/memory-v2`를 만들고 `.env`까지 생성
- 즉 Step 추가이지 별도 설치기 분리가 아니다

필수 작업:
- sidecar 코드 복사 또는 다운로드
- Python virtualenv 생성
- `requirements.txt` 설치
- service env file 생성
- 실행 경로 고정

예시 env:

```bash
DATABASE_URL=postgresql://postgres:<PASSWORD>@127.0.0.1:5433/memory_v2
OLLAMA_URL=http://127.0.0.1:11434
```

주의:
- 현재 코드의 `WORKSPACES` 하드코딩은 설치 전에 해결해야 한다.
- 최소한 고객 설치용 경로에 맞게 patch가 필요하다.

### Phase C: Ollama + embeddings

목표: sidecar가 로컬 임베딩을 안정적으로 수행하도록 한다.

기존 `setup.sh` 반영 방식:
- sidecar payload 설치 직후 로컬 embedding runtime Step 추가
- 이미 Ollama가 있으면 스킵, 없으면 설치
- `bge-m3:latest` pull 이후 다음 Step으로 진행

실제 기준:
- 모델: `bge-m3:latest`
- 차원: `1024`
- endpoint: local Ollama

예시:

```bash
brew install ollama
brew services start ollama
ollama pull bge-m3:latest
```

검증:

```bash
curl -s http://127.0.0.1:11434/api/tags
```

중요:
- 문서상의 `nomic-embed-text` 기준은 폐기
- remote Ollama fallback을 설치 기본값으로 쓰면 안 됨

### Phase D: OpenClaw plugin 연결

목표: OpenClaw가 기본 memory slot으로 `memory-v3`를 사용하게 만든다.

기존 `setup.sh` 반영 방식:
- 현재 Telegram patch와 같은 방식으로 `openclaw.json` merge patch Step 추가
- onboarding이 끝난 뒤, gateway 시작 전 적용하는 편이 안전하다

`openclaw.json` patch 기준:

```json
{
  "plugins": {
    "allow": ["memory-v3", "telegram", "slack"],
    "slots": {
      "memory": "memory-v3"
    },
    "entries": {
      "memory-v3": {
        "enabled": true,
        "config": {
          "baseUrl": "http://127.0.0.1:18790",
          "autoRecall": true,
          "maxResults": 8,
          "minScore": 0.3
        }
      }
    }
  }
}
```

주의:
- 기존 사용자 plugin 설정을 덮어쓰지 말고 merge해야 한다.
- `memory.v3` 같은 별도 top-level 블록을 만들면 안 된다.

### Phase E: Workspace memory bootstrap

목표: 설치 직후 ingest 가능한 기본 메모리 구조를 만든다.

기존 `setup.sh` 반영 방식:
- 현재 workspace template 생성 로직을 확장
- `SOUL.md`, `AGENTS.md`, `USER.md` 옆에 `MEMORY.md`와 `memory/`를 생성
- 즉 기존 workspace Step을 갈아엎는 게 아니라 확장한다

필수 항목:
- `WORKSPACE/MEMORY.md`
- `WORKSPACE/memory/`
- 최소한 daily log 또는 system note 디렉토리

예시:

```text
workspace/
├── MEMORY.md
└── memory/
    ├── logs/
    └── system/
```

설치 직후 할 일:
- 초기 파일 생성
- sidecar ingest 또는 flush 1회 실행

### Phase F: Service supervision

목표: 재부팅 후에도 메모리 시스템이 다시 올라오게 한다.

기존 `setup.sh` 반영 방식:
- 마지막 단계에서 launchd plist를 써서 등록
- 기존 OpenClaw daemon과 memory sidecar daemon을 분리 관리

필요 프로세스:
- memory API server
- Tier1 worker
- Tier2 worker (선택)
- periodic flush / snapshot / eviction jobs
- Korean backfill job (optional, `GOOGLE_API_KEY` 있을 때만)

mac 기준 권장:
- `launchd` plist 여러 개로 분리

권장 분리:
- `com.openclaw.memory-v3-api`
- `com.openclaw.memory-v3-atomize`
- `com.openclaw.memory-v3-llm-atomize` (optional)
- `com.openclaw.memory-v3-maintenance`

### Phase G: Gateway cron jobs

이 단계는 memory infra 자체와는 별개다.

기존 `setup.sh` 반영 방식:
- memory search와 sidecar health가 확인된 이후 선택적으로 cron을 등록
- 즉 Phase G는 bring-up 이후의 부가 Step이다

예시 작업:
- Daily Digest
- MEMORY.md distillation

이건 OpenClaw gateway API에 job 등록하는 레이어다.

중요:
- memory sidecar maintenance와 gateway cron을 혼동하지 말 것
- memory search가 살아있지 않으면 distillation job만 등록해도 가치가 적다

---

## 5. 테스트

### 기본 설치 테스트

- mac installer E2E
- mac installer V2 launcher smoke test
- WSL installer dry-run
- Windows `.bat` → WSL bootstrap 흐름 점검

### Memory V2 전용 테스트

설치 성공과 memory 기능 성공은 별도 검증한다.

#### 1. 인프라 검증

```bash
curl -s http://127.0.0.1:18790/health
curl -s http://127.0.0.1:18790/v1/memory/stats
```

#### 2. 임베딩 검증

```bash
curl -s http://127.0.0.1:11434/api/tags | rg 'bge-m3'
```

#### 3. DB/마이그레이션 검증

확인 대상:
- `memories`
- `memory_relations`
- `pending_atomize`
- `project_snapshots`
- `embedding_ko`

#### 4. ingest 검증

```bash
curl -s -X POST http://127.0.0.1:18790/v1/memory/flush \
  -H 'Content-Type: application/json' \
  -d '{"namespace":"global"}'
```

#### 5. retrieval 검증

```bash
curl -s -X POST http://127.0.0.1:18790/v1/memory/search \
  -H 'Content-Type: application/json' \
  -d '{"query":"사용자 선호와 최근 프로젝트 상태","maxResults":5}'
```

#### 6. OpenClaw integration 검증

확인 항목:
- plugin slot이 `memory-v3`로 설정됨
- gateway 시작 후 memory-v3 연결 로그 출력
- 실제 agent turn에서 auto-recall 동작

### DRY_RUN 원칙

기본 OpenClaw 설치 스크립트는 `DRY_RUN` 지원 가능.

하지만 memory-v3 전체 스택은 아래 때문에 dry-run만으로 충분하지 않다.
- DB migration
- Ollama model pull
- sidecar daemon
- search endpoint behavior

즉 setup V2는 `DRY_RUN + 실제 smoke test` 둘 다 필요하다.

### 실환경 리허설 결과

리허설 기준:
- `SKIP_CORE_SETUP=1 bash installer/scripts/openclaw-setup-v2.sh`
- macOS 로컬 PostgreSQL/launchd/OpenClaw gateway 기준

확인된 점:
1. payload staging
2. native PostgreSQL 확인
3. Python runtime 선택
4. migration 적용
5. plugin patch
6. launchd bring-up
7. `/health`, `/v1/memory/stats` 응답

문제:
- active 사용자 환경에 직접 적용하면 운영 중 profile과 DB를 건드리게 된다

따라서 이 검증은 "기능 경로 확인"으로만 기록하고, 다음 검증부터는 아래로 제한한다.

필수 격리 원칙:
1. `HOME`을 임시 디렉터리로 분리
2. `openclaw.json`은 테스트 전용 복사본 사용
3. PostgreSQL은 별도 테스트 DB 사용
4. launchd label도 test namespace 사용
5. 운영 중 gateway/profile에는 절대 적용하지 않음

---

## 6. 배포

### 현재 배포 단위

- installer script
- launcher (`.command`, `.bat`)

### V2에서 추가될 배포 단위

- memory-v3 plugin payload
- memory sidecar payload
- launchd/systemd templates
- migration bundle

권장:
- installer script와 memory payload를 같은 버전으로 묶어 배포
- Gist만 업데이트하고 payload 버전이 안 맞는 상태를 만들지 말 것
- V2 launcher도 V2 script raw URL만 가리키게 유지할 것

### 웹사이트와의 정합성

웹사이트 기준 메시지는 아래에 맞춰야 한다.

1. OpenClaw는 고객 기기에서 native로 실행된다
2. Memory V3는 plugin + sidecar + local DB + local embedding stack으로 구성된다
3. 맥미니 기본 방향은 native install이며, Docker는 핵심 가치가 아니다
4. setup V2는 기존 `setup.sh`를 확장해서 이 구성을 자동화하는 작업이다

### 문서/코드 버전 관리 원칙

- installer version
- memory payload version
- migration version

이 세 개를 같이 기록해야 설치 실패 원인 추적이 가능하다.

---

## 7. 보안

### 필수 원칙

1. DB는 loopback만 bind
   - `127.0.0.1:5433:5432`

2. service env file은 `600`
   - `DATABASE_URL`
   - optional provider credentials

3. 설치 기본값으로 외부 Ollama endpoint를 쓰지 말 것
   - 고객 머신은 local Ollama 기준으로 설치해야 함

4. `openclaw.json`도 `600`

5. memory DB 비밀번호는 랜덤 생성

6. plugin config merge 시 기존 설정 보존

### 민감 정보 저장 위치

- `openclaw.json`: OpenClaw plugin/channel config
- memory service env file: DB/Ollama/service config
- `.setup-env`: 설치 중 임시 입력값, 완료 후 삭제

---

## 개발 우선순위

| 순서 | 항목 | 이유 |
|------|------|------|
| 1 | Phase 0: sidecar 설치 계약 정리 | 지금 가장 큰 blocker |
| 2 | Phase A: PostgreSQL + real migrations | toy schema 금지 |
| 3 | Phase B: sidecar payload + venv + env | 실제 실행 단위 확보 |
| 4 | Phase C: Ollama + bge-m3 | retrieval 품질 핵심 |
| 5 | Phase D: OpenClaw plugin patch | core 연결 |
| 6 | Phase E/F: ingest + daemon + maintenance | 운영 가능 상태 |
| 7 | Phase G: distillation cron | 부가 기능 |

---

_작성 기준: 2026-03-07_
_이 문서는 실제 `memory-v3` plugin + `services/memory-v2` 런타임 기준으로 정리함._
