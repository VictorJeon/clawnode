# PRD: ClawNode Installer v6

## 개요
ClawNode installer v5의 증분 업데이트. v5에서 이미 잘 동작하는 부분은 건드리지 않고, 2가지 새 기능만 추가.

## 기반
- v5 스크립트: `/Users/nova/projects/clawnode/installer/scripts/openclaw-setup-v5.sh`
- v6 산출물: `/Users/nova/projects/clawnode/installer/scripts/openclaw-setup-v6.sh` (v5 복사 후 수정)

## 변경사항

### 1. GLM-5.1 Coding Plan-Global API 키 옵션 추가
**목적**: 설치 시 사용자가 z.ai Coding Plan-Global API 키를 입력할 수 있게 함

**실제 런타임 스키마** (검증 완료 — analysis-20260417-llvff1):

config patch (올바른 스키마):
```json
{
  "models": {
    "providers": {
      "zai": {
        "baseUrl": "https://api.z.ai/api/coding/paas/v4"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-5.1"
      }
    }
  }
}
```

auth-profiles.json (별도 파일):
```json
{
  "zai:default": {
    "apiKey": "<USER_INPUT>"
  }
}
```

auth.order (provider-keyed):
```json
{
  "auth": {
    "order": {
      "zai": ["zai:default"]
    }
  }
}
```

**구현**:
- onboard 단계에서 새로운 선택지 추가:
  ```
  [3] Z.AI (GLM-5.1) - Coding Plan Global
  ```
- 선택 시 API 키 입력 프롬프트
- `models.providers.zai.baseUrl` 설정
- `auth-profiles.json`에 키 저장
- `auth.order`에 provider-keyed 엔트리 추가
- Keychain 저장: `security add-generic-password -s "openclaw-zai-api" -a "zai" -w "<KEY>"`

**주의** (검증에서 발견된 스키마 불일치):
- ❌ `providers.*` (최상위) → ✅ `models.providers.*`
- ❌ `auth.apiKey` 인라인 → ✅ `auth-profiles.json` 별도 파일
- ❌ `auth.order` 단순 배열 → ✅ `auth.order` provider-keyed 구조

### 2. Sanitizer Preload
**목적**: GLM이 openclow를 차단하는 문제를 우회하기 위한 response sanitizer preload

**소스**: `/Users/nova/.openclaw/scripts/zai_openclaw_sanitize.js`

**구현**:
- 스크립트를 `~/.openclaw/scripts/zai_openclaw_sanitize.js`로 복사
- openclaw LaunchAgent plist에 환경변수 추가:
  ```xml
  <key>NODE_OPTIONS</key>
  <string>--require /Users/$USER/.openclaw/scripts/zai_openclaw_sanitize.js</string>
  ```
- 조건부 적용: z.ai provider가 선택된 경우에만 활성화
- 복사 후 `launchctl bootstrap` + `kickstart` 실행

**주의**:
- Apple Silicon + SIP 환경에서 `DYLD_INSERT_LIBRARIES`는 제한이 있으므로 `NODE_OPTIONS --require` 방식 사용
- 기존 `NODE_OPTIONS`가 있으면 append (덮어쓰지 않음)

## 설치 플로우 (v5 대비 변경점)

v5의 기존 onboard 선택지에 2개를 추가/수정:

```
=== Model & Provider ===
[1] Anthropic (Claude)
[2] OpenAI (GPT)
[3] Z.AI (GLM-5.1) - Coding Plan Global      ← NEW
[4] Skip (configure later)

=== Optional Add-ons ===
Install GLM sanitizer preload? [y/N]           ← NEW (z.ai 선택 시 권장)
```

### 3. Auth 검증 개선 (Anthropic-first 문제 수정)
**목적**: v5의 `core_auth_present()`가 Anthropic setup-token만 기본으로 인식하고, 다른 provider(Codex, z.ai)로 인증했을 때 "auth invalid"로 판단해 코어 재실행(= Anthropic 온보딩)을 강제하는 문제 수정

**원인 분석**:
1. `core_auth_present()`는 curl로 각 provider API를 검증(8초 타임아웃)
2. 네트워크 지연/타임아웃/토큰 만료 → `return 1` → "auth invalid — re-running core setup"
3. 코어 스크립트(`openclaw-setup.sh`)는 Anthropic setup-token을 기본 온보딩으로 제시
4. 결과: Codex로 인증했어도 Anthropic 인증 화면으로 강제 이동

**구현**:

#### 3a. `core_auth_present()`에 z.ai provider 추가
```bash
# 기존 KNOWN_PROVIDERS에 "zai" 추가
KNOWN_PROVIDERS={"anthropic", "openai", "google", "gemini", "openai-codex", "zai"}

# z.ai 검증 케이스 추가 (openai와 동일한 Bearer 헤더)
    zai)
      curl -fsS --max-time 8 -H "Authorization: Bearer ${secret}" "${zai_base_url}/models" -o /dev/null 2>/dev/null && return 0
      ;;
```

#### 3b. Auth 실패 시 코어 재실행 대신 auth-only 패치 경로
```bash
# 기존: auth 실패 → 코어 스크립트 재실행 (Anthropic 온보딩 강제)
# 변경: auth 실패 → provider 선택 프롬프트 → 해당 provider auth만 패치
if ! core_auth_present; then
    warn "auth validation failed — select provider to re-authenticate:"
    echo "  [1] Anthropic (setup-token or API key)"
    echo "  [2] OpenAI / Codex (API key)"
    echo "  [3] Z.AI (GLM-5.1) API key"
    echo "  [4] Skip auth (configure manually later)"
    read -rp "  Choice [1-4]: " AUTH_CHOICE
    case "$AUTH_CHOICE" in
      1) auth_anthropic ;;    # 기존 코어 스크립트의 Anthropic 경로 재사용
      2) auth_openai ;;      # API key를 auth-profiles.json에 직접 기록
      3) auth_zai ;;          # Feature 1의 z.ai auth 경로 재사용
      *) warn "skipping auth — configure manually via openclaw onboard" ;;
    esac
fi
```

#### 3c. 검증 타임아웃 완화
- curl 타임아웃 8초 → 15초 (해외 API 특히 z.ai 중국 엔드포인트 고려)
- 연속 실패 시 재시도 1회 추가

## 변경하지 않는 것
- v5의 모든 기존 기능 (Tailscale, exec-approvals, LaunchAgent, etc.)
- Dreaming / memory-wiki / memory-core (v5에서 이미 정상 동작)
- gbrain, active memory (v7 이후로 연기)
- Hetzner provision (별도 스크립트)
- V3 cleanup 로직

## 검증 기준
1. `openclaw-setup-v6.sh` 실행 후:
   - z.ai 선택 → `openclaw.json`에 `models.providers.zai` + `auth-profiles.json` + `auth.order` 설정 존재
   - sanitizer → `~/.openclaw/scripts/zai_openclaw_sanitize.js` 존재 + LaunchAgent에 NODE_OPTIONS 반영
   - Codex로 인증한 기존 설치 → auth invalid 재현 시 provider 선택 프롬프트 노출 (Anthropic 강제 안 함)
   - z.ai로 인증한 설치 → `core_auth_present()`가 z.ai를 인식하고 통과
2. 기존 v5 기능이 깨지지 않음 (idempotent)
3. `shellcheck` 경고 없음
4. `bash --norc --noprofile` 환경에서도 동작

## 산출물
- `/Users/nova/projects/clawnode/installer/scripts/openclaw-setup-v6.sh`
- v5와의 diff 요약 문서
