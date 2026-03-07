# E2E 테스트 계획 — openclaw-setup.sh

## 문제

진짜 E2E를 하려면:
- 깨끗한 macOS 환경 (OpenClaw 미설치)
- Telegram 봇 토큰
- AI 모델 API 키 or 구독
이 세 가지가 다 필요함. 매번 Mac을 초기화할 수는 없음.

---

## 테스트 전략: 3단계

### Level 1: Dry-run (스크립트 로직만 검증)

**방법:** `--dry-run` 플래그 추가

스크립트에 `DRY_RUN=1`이면 실제 설치/API 호출을 하지 않고 로직만 통과시킴.

```bash
DRY_RUN=1 bash openclaw-setup.sh
```

**검증 항목:**
- [ ] 입력 수집 흐름 (이름, 봇 토큰, 모델 선택) 정상 동작
- [ ] 모델별 분기 (1-6) 올바른 onboard 플래그 생성
- [ ] .setup-env 저장/로드 (멱등성)
- [ ] Workspace 파일 생성 (SOUL.md, AGENTS.md 등)
- [ ] 이전 실행값 재사용 Y/n 분기

**구현:** 스크립트 상단에 추가
```bash
DRY_RUN="${DRY_RUN:-0}"
dry() {
  if [[ "$DRY_RUN" == "1" ]]; then
    ok "[DRY] $*"
    return 0
  fi
  "$@"
}
# 사용: dry brew install node
#       dry openclaw onboard --non-interactive ...
```

---

### Level 2: Docker/VM 격리 테스트 (설치 흐름 검증)

**문제:** macOS Docker에서는 Homebrew/LaunchAgent 테스트 불가.

**대안:** macOS VM (UTM/Tart) 사용

```bash
# Tart (Apple Silicon macOS VM) — 무료
brew install tart
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest test-openclaw
tart run test-openclaw

# VM 안에서
bash <(curl -fsSL <gist_url>)
```

**장점:**
- 스냅샷 → 초기화 → 재테스트 가능
- 실제 macOS 환경

**단점:**
- VM 이미지 다운로드 시간
- Apple Silicon에서만 가능

**현실적 대안: Mason의 Mac Mini에서 별도 유저로 테스트**
```bash
# 테스트 전용 유저 생성
sudo dscl . -create /Users/testuser
sudo dscl . -create /Users/testuser UserShell /bin/zsh
sudo dscl . -create /Users/testuser UniqueID 550
sudo dscl . -create /Users/testuser PrimaryGroupID 20
sudo dscl . -create /Users/testuser NFSHomeDirectory /Users/testuser
sudo mkdir -p /Users/testuser
sudo chown testuser:staff /Users/testuser

# 테스트 실행
su - testuser -c 'bash <(curl -fsSL <gist_url>)'

# 테스트 후 정리
sudo dscl . -delete /Users/testuser
sudo rm -rf /Users/testuser
```

이게 가장 현실적임. 깨끗한 macOS 유저 = 깨끗한 환경.

---

### Level 3: 실제 E2E (전체 흐름 검증)

**시나리오별 테스트 매트릭스:**

| # | 모델 | OS | 기존 설치 | 예상 결과 |
|---|------|----|-----------|-----------|
| 1 | Claude (setup-token) | macOS (ARM) | 없음 | Full 설치 |
| 2 | Claude (API key) | macOS (ARM) | 없음 | Full 설치 |
| 3 | ChatGPT (OAuth) | macOS (ARM) | 없음 | 브라우저 플로우 |
| 4 | ChatGPT (API key) | macOS (ARM) | 없음 | Full 설치 |
| 5 | Gemini (API key) | macOS (ARM) | 없음 | Full 설치 |
| 6 | Claude (setup-token) | macOS (Intel) | 없음 | Homebrew 경로 차이 |
| 7 | 재실행 (멱등성) | macOS (ARM) | 있음 | 스킵 동작 |
| 8 | 부분 실패 → 재실행 | macOS (ARM) | 일부 | 이어서 진행 |

**Telegram 봇 테스트:**
- 테스트 전용 봇 하나 만들어두기 (@BotFather → /newbot)
- 테스트 후 봇 삭제 or 비활성화

**API 키:**
- Claude: 테스트 전용 setup-token (만료 짧게)
- ChatGPT: Mason 계정 OAuth
- Gemini: 무료 API 키 (테스트 비용 $0)

---

## 권장 테스트 순서

### 최소 테스트 (출시 전 필수)
1. **DRY_RUN** 전체 통과 확인
2. **새 유저**로 Claude setup-token 시나리오 1회 (가장 많은 고객)
3. **Telegram 응답** 확인

### 풀 테스트 (여유 있을 때)
4. ChatGPT OAuth 시나리오
5. Gemini 시나리오
6. 멱등성 (재실행) 시나리오
7. Intel Mac (있으면)

---

## 자동화 가능 영역

| 영역 | 자동화 | 방법 |
|------|:---:|------|
| 입력 수집 로직 | ✅ | DRY_RUN + expect/자동입력 |
| Homebrew/Node 설치 | △ | 새 유저에서만 |
| onboard 호출 | △ | API 키 필요 |
| Telegram 응답 | ✅ | Bot API로 직접 메시지 전송 + 응답 폴링 |
| Workspace 생성 | ✅ | 파일 존재/내용 체크 |
| 보안 점검 | ✅ | 스크립트로 자동 확인 |

**Telegram 자동 검증 스크립트 (테스트용):**
```bash
#!/bin/bash
# 봇에게 메시지 보내고 응답 확인
BOT_TOKEN="..."
CHAT_ID="..."

# 메시지 전송
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" -d text="테스트: 1+1은?"

# 10초 대기 후 최신 메시지 확인
sleep 10
RESPONSE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=1&offset=-1")
echo "$RESPONSE" | python3 -m json.tool

# 응답에 "2"가 포함되면 성공
if echo "$RESPONSE" | grep -q "2"; then
  echo "✅ 봇 응답 확인"
else
  echo "❌ 봇 응답 없음 또는 비정상"
fi
```

---

## 빠른 시작

지금 당장 할 수 있는 최소 테스트:

```bash
# 1. DRY_RUN
DRY_RUN=1 bash openclaw-setup.sh

# 2. Mac Mini에서 새 유저 테스트
# (위의 testuser 생성 → 스크립트 실행 → 정리)

# 3. Telegram 봇 응답 확인
# (봇에게 "안녕" → 응답 확인)
```
