# VPS 프로비저닝 & OpenClaw 설치 SOP (DELUXE)

> 에이전트(Nova/Sol/Bolt)가 고객 대신 VPS를 구매하고 OpenClaw을 설치하는 표준 절차.
> 예상 소요시간: 30~45분

---

## 사전 확인

### 고객이 직접 해야 하는 것 (대행 불가)

1. **Hetzner 계정 생성** — 결제/본인인증 필요 → 대신 생성 불가
2. **서버 생성** — 가이드를 보내주면 고객이 버튼 클릭
3. **AI 모델 결제** — Claude Pro / ChatGPT Plus 구독 등

> 💡 고객에게 "사전 준비 가이드"를 보내서 위 3가지를 미리 완료하게 한다.
> 가이드에 스크린샷 포함 필수. 비개발자 기준.

### 고객에게 받아야 할 정보

| 항목 | 필수 | 비고 |
|------|:---:|------|
| AI 모델 선택 | ✅ | Claude Pro / ChatGPT Plus / API Key |
| Telegram 봇 토큰 | ✅ | @BotFather에서 발급 (사전 가이드 전달) |
| Telegram Chat ID | ✅ | 봇에 /start 후 자동 감지 |
| 사용자 이름 (봇 호칭) | ✅ | 예: "Mason" |
| API Key (해당 시) | 조건부 | Claude API / ChatGPT API / Gemini 선택 시 |
| **서버 SSH 접속 정보** | ✅ | IP + root 비밀번호 (Hetzner 이메일로 전달됨) |
| VPS 리전 | ❌ | 가이드에서 권장 리전 안내 |

---

## Phase 1: 서버 접속 & 초기 세팅

> ⚠️ 서버는 **고객이 직접 생성**한 상태. 고객에게서 IP + root 비밀번호를 받아서 시작.

### 1.1 고객에게 보낸 사전 가이드 체크

고객이 아래를 완료했는지 확인:
- [ ] Hetzner 계정 생성 + 결제수단 등록
- [ ] 서버 생성 (CX22, Ubuntu 24.04, IPv4 포함)
- [ ] 서버 IP + root 비밀번호 전달받음

```
권장 스펙 (가이드에 명시):
- Type: CX22 (2 vCPU, 4GB RAM, 40GB SSD) — €4.51/월
- OS: Ubuntu 24.04
- Location: Nuremberg (nbg1) 또는 Ashburn
- Networking: IPv4 포함
```

### 1.2 초기 접속 & 기본 하드닝

```bash
# SSH 접속
ssh root@<SERVER_IP>

# 1) 시스템 업데이트
apt update && apt upgrade -y

# 2) 비root 사용자 생성
adduser openclaw
usermod -aG sudo openclaw

# 3) SSH 키 복사
mkdir -p /home/openclaw/.ssh
cp ~/.ssh/authorized_keys /home/openclaw/.ssh/
chown -R openclaw:openclaw /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys

# 4) ⚠️ 키 접속 검증 (하드닝 전 필수!)
# 새 터미널에서 키 인증으로 접속 테스트:
#   ssh openclaw@<SERVER_IP>
# 접속 성공 확인 후에만 아래 하드닝 진행!

# 5) SSH 하드닝 (키 접속 확인 후에만 실행)
if [[ $(wc -l < /home/openclaw/.ssh/authorized_keys) -gt 0 ]]; then
  sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart sshd
  echo "✅ SSH 하드닝 완료"
else
  echo "❌ authorized_keys가 비어있습니다! 하드닝을 건너뜁니다."
  echo "   키를 먼저 등록하세요."
fi

# 5) UFW 방화벽
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# 6) 이후 openclaw 유저로 작업
su - openclaw
```

---

## Phase 2: OpenClaw 설치

### 2.1 스크립트 실행

```bash
# openclaw 유저로 로그인된 상태

# 방법 A: 스크립트 다운로드 & 실행
curl -fsSL https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup-wsl.sh -o /tmp/openclaw-setup.sh
bash /tmp/openclaw-setup.sh

# 방법 B: 직접 설치 (스크립트 없이)
sudo apt update
sudo apt install -y curl git unzip
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g openclaw
```

### 2.2 OpenClaw Onboard

```bash
# 고객 모델에 따라 분기:

# Claude Pro (구독형) — 대화형
openclaw onboard --auth-choice setup-token \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --skip-channels --skip-skills \
  --accept-risk

# Claude API Key — 비대화형
openclaw onboard --non-interactive \
  --auth-choice apiKey \
  --anthropic-api-key "$API_KEY" \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --skip-channels --skip-skills \
  --accept-risk

# ChatGPT Plus (구독형) — 대화형 (브라우저 URL 복사 필요)
# ⚠️ VPS에는 브라우저가 없으므로 URL을 고객에게 전달하여 코드를 받아야 함
openclaw onboard --auth-choice openai-codex \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --skip-channels --skip-skills \
  --accept-risk

# ChatGPT API Key
openclaw onboard --non-interactive \
  --auth-choice openai-api-key \
  --openai-api-key "$API_KEY" \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --skip-channels --skip-skills \
  --accept-risk

# Gemini API Key
openclaw onboard --non-interactive \
  --auth-choice gemini-api-key \
  --gemini-api-key "$API_KEY" \
  --gateway-port 18789 --gateway-bind loopback \
  --install-daemon --daemon-runtime node \
  --skip-channels --skip-skills \
  --accept-risk
```

### 2.3 Telegram 채널 설정

```bash
# openclaw.json에 Telegram 설정 주입
OC_PATH="$HOME/.openclaw/openclaw.json" \
OC_TOKEN="<BOT_TOKEN>" \
OC_CHAT="<CHAT_ID>" \
node -e '
  const fs = require("fs");
  const {OC_PATH, OC_TOKEN, OC_CHAT} = process.env;
  const c = JSON.parse(fs.readFileSync(OC_PATH, "utf8"));
  c.channels = c.channels || {};
  c.channels.telegram = {
    enabled: true,
    botToken: OC_TOKEN,
    dmPolicy: "allowlist",
    allowFrom: [OC_CHAT]
  };
  fs.writeFileSync(OC_PATH, JSON.stringify(c, null, 2));
'
chmod 600 "$HOME/.openclaw/openclaw.json"
```

### 2.4 Workspace 생성

```bash
WORKSPACE="$HOME/.openclaw/workspace"
mkdir -p "$WORKSPACE/memory"

cat > "$WORKSPACE/SOUL.md" << 'EOF'
# SOUL.md — 봇의 성격
## 핵심
- 동료 같은 AI 비서. 딱딱한 말투 금지.
- 결과를 먼저 말하고, 근거는 뒤에.
- 모르면 '찾아볼게요'라고 솔직하게.
## 말투
- 부드러운 해요체 (ex. 알겠습니다, 처리할게요)
- 이모지 적절히 사용
EOF

cat > "$WORKSPACE/AGENTS.md" << EOF
# AGENTS.md — 운영 규칙
## 우선순위
1. **안전**: 데이터 삭제 시 신중하게 (trash 사용)
2. **실행**: 지시하면 즉시 수행
## 메모리
- 사용자의 선호, 결정사항은 MEMORY.md에 기록
- 이름: <고객이름>
EOF

cat > "$WORKSPACE/USER.md" << EOF
# USER.md
- 이름: <고객이름>
- Chat ID: <CHAT_ID>
EOF
```

---

## Phase 3: 검증 & 하드닝

### 3.1 동작 검증

```bash
# Gateway 상태
openclaw gateway status

# systemd 데몬 확인
systemctl --user status openclaw-gateway

# 고객에게 Telegram으로 "안녕" 보내게 요청
# → 봇 응답 확인
```

### 3.2 VPS 보안 하드닝

```bash
# 보안 점검 스크립트 실행
curl -fsSL https://gist.githubusercontent.com/VictorJeon/50f6bc9a3765551edf39a896aaa56c82/raw/security-audit.sh -o /tmp/security-audit.sh
TIER=DELUXE bash /tmp/security-audit.sh > ~/security-report.md

# 자동 보안 업데이트
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# fail2ban (SSH 브루트포스 방지)
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3.3 Tailscale 설치 (권장)

```bash
# 고객이 다른 기기에서도 안전하게 접근 가능
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# → 고객에게 Tailscale 초대 링크 전달
```

---

## Phase 4: 고객 인수

### 4.1 고객에게 전달할 정보

```markdown
## 🦞 OpenClaw 설치 완료!

### 서버 정보
- IP: <SERVER_IP>
- Tailscale IP: <TS_IP> (해당 시)
- 사용자: openclaw
- 인증: SSH 키 (비밀번호 비활성화)

### 봇 사용법
1. Telegram에서 봇에게 메시지를 보내세요
2. "안녕", "오늘 날씨", "할일 정리해줘" 등

### 관리 명령어 (SSH 접속 후)
- 상태 확인: `openclaw gateway status`
- 재시작: `openclaw gateway restart`
- 로그 확인: `journalctl --user -u openclaw-gateway -f`

### 비용
- 서버: €4.51/월 (Hetzner CX22)
- AI 모델: 선택한 구독/API 비용 별도

### 지원
- 문제 발생 시 Telegram으로 연락
- 서버 관리/업데이트는 요청 시 지원
```

### 4.2 완료 체크리스트

- [ ] 봇이 Telegram 메시지에 응답하는지 확인
- [ ] 고객이 직접 메시지 보내서 테스트 완료
- [ ] 서버 정보 전달 완료
- [ ] 보안 리포트 전달 (DELUXE+)
- [ ] Hetzner 로그인 정보 → 고객에게 인계 (또는 고객 계정으로 이전)
- [ ] 작업 완료 보고 (Kmong)

---

## ⚠️ 주의사항

1. **Hetzner 계정은 고객 소유**: 우리가 계정을 대신 만들지 않음. 결제/본인인증은 고객이 직접.
2. **ChatGPT OAuth on VPS**: 브라우저 없음 → 인증 URL을 고객에게 전달, 코드를 받아서 입력
3. **API Key 취급**: 고객에게서 받은 API Key는 작업 완료 후 채팅 기록에서 삭제 권장
4. **서버 비용**: 고객에게 월 서버 비용이 별도 발생함을 사전 안내 (DELUXE 가격과 별개)
5. **root 비밀번호**: 초기 접속 후 SSH 키 전환 → 비밀번호 로그인 비활성화 → 고객에게 비밀번호 변경 안내

---

## 시간 예산

| 단계 | 예상 시간 |
|------|-----------|
| Phase 1: VPS 구매 & 초기 세팅 | 10분 |
| Phase 2: OpenClaw 설치 | 15분 |
| Phase 3: 검증 & 하드닝 | 10분 |
| Phase 4: 고객 인수 | 10분 |
| **합계** | **~45분** |

---

*Last updated: 2026-03-03*
