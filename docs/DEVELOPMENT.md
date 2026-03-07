# ClawNode 설치 시스템 — 개발 문서 v2.0

> CLI 스크립트 기반 (.command + Secret Gist)
> EasyClaw GUI 포크 방식에서 전환 (v1.0 → v2.0)

---

## 목차

1. [아키텍처](#1-아키텍처)
2. [현재 구현 상태](#2-현재-구현-상태)
3. [미구현 항목 (추가 개발 필요)](#3-미구현-항목)
4. [Phase별 구현 가이드](#4-phase별-구현-가이드)
5. [테스트](#5-테스트)
6. [배포](#6-배포)
7. [보안](#7-보안)

---

## 1. 아키텍처

### 왜 CLI인가 (EasyClaw GUI 포크를 버린 이유)

| 비교 | EasyClaw (Electron GUI) | ClawNode (CLI 스크립트) |
|------|------------------------|----------------------|
| 배포 | .dmg 파일 → 복사 유포 위험 | Secret Gist URL → 교체 가능 |
| 업데이트 | 앱 업데이트 배포 필요 | Gist 수정하면 즉시 반영 |
| 유지보수 | Electron + React + IPC | bash 스크립트 1개 |
| 코드서명 | Apple Notarization 필요 | 불필요 |
| 고객 경험 | .dmg 설치 → 앱 실행 → 위자드 | .command 더블클릭 → 터미널에서 진행 |
| 실제 필요 기능 | GUI 로그뷰어, 대시보드 등 | 고객은 설치 후 텔레그램으로만 사용. GUI 불필요 |

**결론**: ClawNode 고객은 설치 후 모니터도 안 연결한다. GUI 앱을 만들 이유가 없다.

### 구성 요소

```
[고객 맥]
  └─ OpenClaw-Install-Mac.command    ← 더블클릭 런처 (10줄)
       └─ curl로 다운로드 & 실행
            └─ openclaw-setup.sh     ← 실제 로직 (Secret Gist)
                 ├── Step 1: 기본 도구 (Brew, Node, Git)
                 ├── Step 2: OpenClaw 설치
                 ├── Step 3: AI 모델 인증 (6가지 분기)
                 ├── Step 4: Telegram 채널 연동
                 ├── Step 5: Workspace 템플릿 생성
                 ├── Step 6: 스킬 + 의존성 설치
                 └── 완료: 리포트 생성 + 원격 접속 터널
```

### 파일 위치

| 파일 | 위치 | 설명 |
|------|------|------|
| `.command` 런처 | `/Users/nova/.openclaw/workspace-nova/vibe-coding-lecture/OpenClaw-Install-Mac.command` | 고객에게 전달하는 파일 |
| 설치 스크립트 | Secret Gist `VictorJeon/5276afd04d974985537a1ceb7e100e9f` | 실제 설치 로직 |
| 이 문서 | `/Users/nova/projects/clawnode/clawnode-app/docs/DEVELOPMENT.md` | 개발 사양서 |

---

## 2. 현재 구현 상태

### ✅ 구현 완료

| # | 항목 | 구현 방식 |
|---|------|----------|
| 1 | Homebrew 자동 설치 | `NONINTERACTIVE=1` 플래그로 무인 설치 |
| 2 | Node.js 설치 (22+) | `brew install node`, 버전 체크 후 스킵/업그레이드 |
| 3 | Git 설치 | `brew install git` |
| 4 | OpenClaw 설치 | `npm install -g openclaw` |
| 5 | 멀티 프로바이더 | Claude(구독/API), GPT(OAuth/API), Gemini(API), 기타 |
| 6 | Claude setup-token | `openclaw onboard --auth-choice setup-token` |
| 7 | OpenAI OAuth | `openclaw onboard --auth-choice openai-codex` (브라우저 로그인) |
| 8 | API Key 입력 | Anthropic / OpenAI / Gemini 각각 분기 |
| 9 | Telegram Chat ID 자동감지 | `getUpdates` API 폴링 (60초 대기) |
| 10 | Telegram config 패치 | `dmPolicy: allowlist`, `allowFrom: [chatId]` |
| 11 | Workspace 템플릿 | SOUL.md, AGENTS.md, USER.md 자동 생성 |
| 12 | 멱등성 | 이미 설치된 것은 스킵, 재실행 안전 |
| 13 | 입력값 재사용 | `.setup-env`에 base64 인코딩 저장, 재실행 시 로드 |
| 14 | gh / ffmpeg 설치 | `brew install` |
| 15 | SSH 활성화 | `sudo systemsetup -setremotelogin on` |
| 16 | 원격 접속 터널 | `localhost.run` (설치 불필요, SSH 리버스 터널) |
| 17 | 설치 리포트 | 시스템 정보 수집 → 클립보드 자동 복사 |
| 18 | 설치 로그 | `~/.openclaw/setup-{timestamp}.log` |
| 19 | DRY_RUN 모드 | `DRY_RUN=1 bash setup.sh`로 실제 설치 없이 플로우 테스트 |
| 20 | 보안 | `.setup-env` 중단 시 자동 삭제, `chmod 600` |

### ❌ 미구현 (추가 개발 필요)

| # | 항목 | 중요도 | 난이도 | Phase |
|---|------|--------|--------|-------|
| 1 | Docker Desktop 설치 | ★★★ | 중 | A |
| 2 | pgvector 컨테이너 (V3 Memory DB) | ★★★ | 상 | A |
| 3 | OpenClaw config에 V3 DB 연결 | ★★★ | 중 | A |
| 4 | Ollama 설치 + 임베딩 모델 | ★★★ | 중 | B |
| 5 | OpenClaw config에 임베딩 연결 | ★★★ | 중 | B |
| 6 | MEMORY.md 초기 생성 | ★★ | 하 | C |
| 7 | 스킬 번들 설치 (clawhub) | ★★ | 중 | C |
| 8 | 크론 작업 등록 (Daily Digest, 증류) | ★★ | 중 | D |
| 9 | Tailscale 설치 | ★★ | 중 | E |
| 10 | localhost.run → Tailscale 전환 | ★ | 하 | E |
| 11 | Windows 지원 (.bat) | ★ | 상 | F |

---

## 3. 미구현 항목 상세

### 왜 이것들이 중요한가

V3 메모리(#1~5)가 **ClawNode의 핵심 차별점**이다. "3개월 전에 지나가듯 말한 것도 기억한다"는 게 이거 없으면 거짓말이 된다.

일반 OpenClaw 설치 = 대화 끊으면 까먹는 AI.
ClawNode = V3 메모리로 영구 기억하는 AI.

이 차이를 만드는 게 Docker + pgvector + Ollama 세팅이다.

---

## 4. Phase별 구현 가이드

### Phase A: Docker + pgvector (V3 Memory)

`openclaw-setup.sh`의 Step 6 이후에 추가.

```bash
# ============================================================================
# Step 7/9: Docker + pgvector (V3 Memory)
# ============================================================================
echo ""
info "Step 7/9: V3 메모리 시스템 구축"

PGVECTOR_CONTAINER="clawnode-pgvector"
PGVECTOR_PORT=5433
PGVECTOR_VOLUME="clawnode-pgdata"

# Docker 설치
if ! command -v docker &>/dev/null; then
  info "Docker Desktop 설치 중..."
  dry brew install --cask docker || fail "Docker 설치 실패"
fi

# Docker Desktop 실행 대기
if ! docker info &>/dev/null 2>&1; then
  info "Docker Desktop 시작 중..."
  open -a Docker
  for i in $(seq 1 60); do
    if docker info &>/dev/null 2>&1; then break; fi
    printf "\r  대기 중... %ds" "$i"
    sleep 2
  done
  echo ""
  if ! docker info &>/dev/null 2>&1; then
    fail "Docker 시작 타임아웃 (120초)"
  fi
fi
ok "Docker 준비 완료"

# pgvector 컨테이너
if docker ps --filter "name=$PGVECTOR_CONTAINER" --format '{{.Status}}' | grep -q "Up"; then
  ok "pgvector 컨테이너 이미 실행 중"
  PG_PASSWORD=$(docker exec $PGVECTOR_CONTAINER printenv POSTGRES_PASSWORD 2>/dev/null)
else
  PG_PASSWORD=$(openssl rand -hex 16)
  info "pgvector 컨테이너 생성 중..."
  dry docker run -d \
    --name "$PGVECTOR_CONTAINER" \
    --restart unless-stopped \
    -e "POSTGRES_PASSWORD=$PG_PASSWORD" \
    -e "POSTGRES_DB=openclaw_memory" \
    -p "${PGVECTOR_PORT}:5432" \
    -v "${PGVECTOR_VOLUME}:/var/lib/postgresql/data" \
    pgvector/pgvector:pg17 || fail "pgvector 컨테이너 생성 실패"

  # PostgreSQL 준비 대기
  for i in $(seq 1 30); do
    if docker exec $PGVECTOR_CONTAINER pg_isready -U postgres &>/dev/null; then break; fi
    sleep 1
  done
fi
ok "pgvector 실행 중 (port $PGVECTOR_PORT)"

# 스키마 생성
info "V3 메모리 스키마 생성 중..."
docker exec -i $PGVECTOR_CONTAINER psql -U postgres -d openclaw_memory <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS memories (
  id SERIAL PRIMARY KEY,
  scope TEXT NOT NULL DEFAULT 'global',
  kind TEXT NOT NULL DEFAULT 'atomic',
  content TEXT NOT NULL,
  embedding vector(768),
  metadata JSONB DEFAULT '{}',
  source_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_memories_scope ON memories (scope);
CREATE INDEX IF NOT EXISTS idx_memories_kind ON memories (kind);
SQL
ok "V3 메모리 스키마 생성 완료"
```

### Phase B: Ollama (로컬 임베딩)

```bash
# ============================================================================
# Step 8/9: Ollama 로컬 임베딩
# ============================================================================
echo ""
info "Step 8/9: 로컬 임베딩 엔진 설치"

if ! command -v ollama &>/dev/null; then
  info "Ollama 설치 중..."
  dry brew install ollama || fail "Ollama 설치 실패"
fi
ok "Ollama 확인됨"

# Ollama 서버 시작
if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
  info "Ollama 서버 시작 중..."
  ollama serve &>/dev/null &
  sleep 3
fi

# 임베딩 모델 다운로드
if ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
  ok "임베딩 모델 이미 다운로드됨"
else
  info "임베딩 모델 다운로드 중 (nomic-embed-text, ~270MB)..."
  dry ollama pull nomic-embed-text || fail "임베딩 모델 다운로드 실패"
fi
ok "임베딩 엔진 준비 완료"

# Ollama 부팅 시 자동 시작
dry brew services start ollama 2>/dev/null
```

### Phase A+B: OpenClaw Config 패치 (V3 연결)

Step 4의 Telegram config 패치와 같은 방식으로:

```bash
# V3 Memory config 패치
OC_PATH="$CONFIG_FILE" OC_PG_PASS="$PG_PASSWORD" OC_PG_PORT="$PGVECTOR_PORT" node -e '
  const fs = require("fs");
  const {OC_PATH, OC_PG_PASS, OC_PG_PORT} = process.env;
  try {
    const c = JSON.parse(fs.readFileSync(OC_PATH, "utf8"));
    c.memory = c.memory || {};
    c.memory.v3 = {
      enabled: true,
      provider: "pgvector",
      connection: {
        host: "127.0.0.1",
        port: parseInt(OC_PG_PORT),
        database: "openclaw_memory",
        user: "postgres",
        password: OC_PG_PASS
      },
      embedding: {
        provider: "ollama",
        model: "nomic-embed-text",
        dimensions: 768
      }
    };
    fs.writeFileSync(OC_PATH, JSON.stringify(c, null, 2));
    console.log("V3 Memory config updated.");
  } catch (e) { console.error(e); process.exit(1); }
'
ok "V3 메모리 config 연결 완료"
```

### Phase C: MEMORY.md + 스킬 번들

MEMORY.md는 기존 Workspace 템플릿 생성(Step 5)에 추가:

```bash
# MEMORY.md (Step 5에 추가)
if [[ ! -f "$WORKSPACE/MEMORY.md" ]]; then
  cat > "$WORKSPACE/MEMORY.md" << 'EOF'
# MEMORY.md — 장기 기억 저장소

> AI 에이전트가 자동으로 업데이트합니다.
> 수동으로 편집해도 됩니다.

## 사용자 프로필
(자동으로 채워집니다)

## 선호/결정사항
(자동으로 채워집니다)
EOF
  ok "MEMORY.md 생성"
fi
```

스킬 번들:

```bash
# 스킬 번들 설치
CORE_SKILLS=(weather summarize github peekaboo video-frames)
info "핵심 스킬 ${#CORE_SKILLS[@]}개 설치 중..."
for skill in "${CORE_SKILLS[@]}"; do
  if clawhub install "$skill" 2>/dev/null; then
    ok "  $skill"
  else
    warn "  $skill 설치 실패 (스킵)"
  fi
done
```

### Phase D: 크론 작업 등록

Gateway가 시작된 후 API 호출:

```bash
# 크론 작업 등록 (Gateway 시작 후)
info "크론 작업 등록 중..."

# Gateway 준비 대기
for i in $(seq 1 15); do
  if curl -s http://127.0.0.1:18789/health &>/dev/null; then break; fi
  sleep 2
done

# Daily Digest
curl -s -X POST http://127.0.0.1:18789/v1/cron/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "📰 Daily Digest",
    "schedule": {"kind":"cron","expr":"0 8 * * *","tz":"Asia/Seoul"},
    "payload": {"kind":"agentTurn","message":"오늘의 주요 업데이트를 요약해서 보고해주세요.","timeoutSeconds":3600},
    "sessionTarget": "isolated"
  }' &>/dev/null && ok "  📰 Daily Digest" || warn "  📰 Daily Digest 등록 실패"

# Memory Distillation
curl -s -X POST http://127.0.0.1:18789/v1/cron/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "name": "🧠 Memory Distillation",
    "schedule": {"kind":"cron","expr":"0 3 * * *","tz":"Asia/Seoul"},
    "payload": {"kind":"agentTurn","message":"오늘 대화를 분석하고 핵심 기억을 MEMORY.md에 증류하세요.","timeoutSeconds":1800},
    "sessionTarget": "isolated"
  }' &>/dev/null && ok "  🧠 Memory Distillation" || warn "  🧠 Memory Distillation 등록 실패"
```

### Phase E: Tailscale

현재 `localhost.run` 리버스 터널을 사용 중. Tailscale로 전환하면 더 안정적이고 보안적:

```bash
# Tailscale 설치
if ! command -v tailscale &>/dev/null; then
  info "Tailscale 설치 중..."
  dry brew install --cask tailscale || warn "Tailscale 설치 실패"
fi

echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │  Tailscale 설정 안내                      │"
echo "  │                                           │"
echo "  │  1. Dock에서 Tailscale 앱을 실행하세요    │"
echo "  │  2. 'Log in' 버튼을 눌러 로그인하세요     │"
echo "  │  3. 담당자가 원격으로 연결할 수 있게 됩니다│"
echo "  └─────────────────────────────────────────┘"
```

**localhost.run은 Tailscale 설치 전 임시 터널로 유지.** 설치 당일 원격 최적화 작업에 사용.

### Phase F: Windows 지원 (미래)

Basic Remote 패키지에서 Windows 고객이 올 때 추가.
- `.bat` 또는 PowerShell 스크립트
- WSL2 자동 설치 → WSL 내부에서 Linux 스크립트 실행
- 현재 우선순위 낮음 (올인원 = Mac Mini)

---

## 5. 테스트

### E2E 테스트 전략

**1회차: 풀 E2E (깡통 맥)**
- 초기화된 맥에서 `.command` 더블클릭
- Homebrew → Node → OpenClaw → 전체 플로우
- 텔레그램 봇 응답까지 검증

**2회차 이후: OpenClaw만 롤백**
```bash
# 롤백 (brew/node는 남겨둠)
openclaw gateway stop
npm uninstall -g openclaw
rm -rf ~/.openclaw

# Docker 리셋 (V3 테스트 시)
docker rm -f clawnode-pgvector
docker volume rm clawnode-pgdata
```
→ 스크립트 다시 실행. 멱등성 덕분에 brew/node는 스킵하고 OpenClaw부터 진행.

**brew/node까지 재테스트 필요한 경우:**
- brew 설치 로직 자체를 수정했을 때
- Node 버전 분기 로직을 수정했을 때
- 이 외에는 매번 밀 필요 없음

### DRY_RUN 테스트
```bash
DRY_RUN=1 bash openclaw-setup.sh
```
실제 설치 없이 전체 플로우를 검증. 입력 프롬프트만 동작하고 설치 명령은 `[DRY]`로 스킵.

### 테스트 체크리스트

```
[ ] .command 더블클릭으로 터미널 열림
[ ] Homebrew 미설치 상태에서 자동 설치
[ ] Node.js 22+ 설치 또는 기존 버전 감지
[ ] 모델 선택 메뉴 (1~6) 정상 동작
[ ] Claude setup-token 플로우
[ ] Claude API Key 플로우
[ ] ChatGPT OAuth 플로우
[ ] ChatGPT API Key 플로우
[ ] Gemini API Key 플로우
[ ] Telegram Chat ID 자동 감지
[ ] Telegram config 패치 (allowlist)
[ ] Workspace 템플릿 생성 (SOUL/AGENTS/USER.md)
[ ] gh, ffmpeg 설치
[ ] Gateway 시작 + 텔레그램 봇 응답
[ ] Docker Desktop 설치 + 실행 (Phase A)
[ ] pgvector 컨테이너 생성 + 스키마 (Phase A)
[ ] Ollama 설치 + 모델 pull (Phase B)
[ ] V3 config 패치 (Phase A+B)
[ ] 스킬 번들 설치 (Phase C)
[ ] 크론 작업 등록 (Phase D)
[ ] 설치 리포트 생성 + 클립보드 복사
[ ] 원격 접속 터널 (localhost.run)
[ ] 재실행 시 멱등성 (이미 설치된 것 스킵)
[ ] 중단 후 재실행 (입력값 재사용)
```

---

## 6. 배포

### 스크립트 업데이트
1. Gist 수정 (`VictorJeon/5276afd04d974985537a1ceb7e100e9f`)
2. 즉시 반영 — 다음 `.command` 실행부터 최신 버전

### 고객 전달
- 올인원 패키지: USB에 `.command` 파일 담아서 현장 전달
- Basic Remote: 텔레그램/카카오로 `.command` 파일 전송
- 크몽: 결제 후 `.command` 파일 + 사용법 안내 전송

### 버전 관리
- Gist revision history로 버전 추적
- 주요 변경 시 스크립트 상단 버전 번호 업데이트 (`# OpenClaw Quick Setup v2.x`)

---

## 7. 보안

### 크리덴셜 관리
- API Key, 봇 토큰: 입력 → OpenClaw config에만 저장 → `.setup-env` 즉시 삭제
- pgvector 비밀번호: `openssl rand -hex 16`으로 생성 → config에만 저장
- `.setup-env`는 base64 인코딩 (평문 아님), 설치 완료 시 삭제, 중단 시 trap으로 삭제

### 네트워크
- `dmPolicy: allowlist` — 등록된 Chat ID만 봇 접근 가능
- localhost.run 터널은 설치 당일 원격 작업용. 창 닫으면 끊김.
- Tailscale은 Mesh VPN — 중앙 서버 경유 없이 P2P 암호화

### 스크립트 유포 방지
- Secret Gist: URL 아는 사람만 접근 (검색 불가)
- URL 유출 시 Gist URL 교체로 무력화
- 스크립트 자체는 오픈소스 도구 설치일 뿐 — 진짜 가치는 V3 세팅 노하우와 에이전트 설계

---

## 개발 우선순위

| 순서 | Phase | 항목 | 이유 |
|------|-------|------|------|
| 1 | — | **E2E 테스트 (현재 버전)** | 기존 기능부터 검증 |
| 2 | A | Docker + pgvector | 핵심 차별점. 이거 없으면 "기억하는 AI" 주장 불가 |
| 3 | B | Ollama + 임베딩 | Phase A와 세트 |
| 4 | C | MEMORY.md + 스킬 번들 | 간단, 즉시 가치 |
| 5 | D | 크론 작업 | Gateway API 호출 |
| 6 | E | Tailscale | 독립적, 언제든 추가 |
| 7 | F | Windows 지원 | 수요 발생 시 |

---

_작성: Sol ☀️ | v2.0 2026-03-06_
_v1.0 (EasyClaw 포크 기반) → v2.0 (CLI 스크립트 기반) 전환_
