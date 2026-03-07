# OpenClaw 직원 온보딩 카드 (SSH/CLI 직접 설정)

> 목표: 서버 생성 후, 직원이 SSH로 직접 OpenClaw 인증/모델 설정까지 완료한다.

---

## 0) 사전 확인 (역할 분담)

### 운영자(관리자)가 해줘야 할 것
- Hetzner 서버 생성
- 직원 공개키(`.pub`) 등록
- 서버 IP 전달

### 직원이 준비해야 할 것
- 본인 SSH private key (`~/.ssh/openclaw-<name>`)  
  - 이 키는 본인만 보관 (절대 공유 금지)
- Telegram Bot Token
- 본인 Telegram Chat ID

> private key가 없으면 접속 불가. 운영자에게 서버 재생성 요청 전에 먼저 확인하세요.

### (중요) SSH 키가 아직 없으면 먼저 생성 + 공개키 전달
직원 로컬 PC에서 실행:
```bash
ssh-keygen -t ed25519 -C "openclaw-<name>" -f ~/.ssh/openclaw-<name>
chmod 600 ~/.ssh/openclaw-<name>
chmod 644 ~/.ssh/openclaw-<name>.pub
```

운영자에게 보내야 하는 건 **공개키(.pub)만**:
```bash
cat ~/.ssh/openclaw-<name>.pub
```

- 전달 항목: `openclaw-<name>.pub` 내용 전체 1줄
- 절대 전달 금지: `~/.ssh/openclaw-<name>` (private key)

---

## 1) 서버 접속
```bash
ssh -i ~/.ssh/openclaw-<name> root@<SERVER_IP>
```

(키 경로가 기본이면 `-i` 생략 가능)

---

## 2) 설치 스크립트 확인
먼저 파일이 있는지 확인:
```bash
ls -l /root/openclaw-setup-hetzner.sh
```

- 있으면 → 3번으로 이동
- 없으면 아래 중 하나 실행

```bash
# 방법 A) 운영자에게 업로드 요청 (권장)
# scp ./openclaw-setup-hetzner.sh root@<SERVER_IP>:/root/openclaw-setup-hetzner.sh

# 방법 B) 서버에서 직접 다운로드
curl -fsSL https://gist.githubusercontent.com/VictorJeon/6e8dc0e2a3a0b31d22c75281d9e0d14a/raw/d0dd0101de742c1ce03d6247cf331fc997d4a039/openclaw-setup-hetzner.sh -o /root/openclaw-setup-hetzner.sh
chmod +x /root/openclaw-setup-hetzner.sh
```

---

## 3) OpenClaw 설치 실행 (직원 본인 정보 입력)
```bash
bash /root/openclaw-setup-hetzner.sh \
  --user-name "<YOUR_NAME>" \
  --telegram-bot-token "<YOUR_TG_BOT_TOKEN>" \
  --telegram-chat-id "<YOUR_CHAT_ID>" \
  --auth-mode skip
```

> `skip`은 인증을 나중에 본인이 직접 선택하는 모드.

---

## 4) LLM 인증 (직접)
### 권장(대화형)
```bash
sudo -u openclaw -H openclaw models auth add
```

### provider 지정형
```bash
sudo -u openclaw -H openclaw models auth login --provider <provider-id> --set-default
```

예시 provider-id: `anthropic`, `openai-codex`, `google` (환경에 따라 다름)

---

## 5) 모델 선택 (직접)
```bash
sudo -u openclaw -H openclaw models list
sudo -u openclaw -H openclaw models set <provider/model>
sudo -u openclaw -H openclaw models status
```

Telegram에서도 가능:
- `/model`
- `/model list`
- `/model <번호>`
- `/model status`

---

## 6) 헬스체크 (필수)
```bash
sudo -u openclaw -H openclaw gateway status
sudo -u openclaw -H openclaw status --json | head
sudo -u openclaw -H openclaw security audit --deep
```

---

## 7) 운영 기본 명령
```bash
# 로그
sudo -u openclaw -H openclaw logs

# 게이트웨이 재시작
sudo -u openclaw -H openclaw gateway restart

# 모델 상태
sudo -u openclaw -H openclaw models status
```

---

## 8) 완료 기준
- [ ] Telegram에서 메시지 보내면 답이 온다
- [ ] `/model status` 정상 출력
- [ ] `security audit --deep` 결과 공유

완료 후 운영자에게: **"온보딩 완료 + 선택 모델 + audit 결과"** 전달.
