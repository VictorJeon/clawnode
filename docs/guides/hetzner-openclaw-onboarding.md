# Hetzner 기반 OpenClaw 직원 온보딩 가이드 (1인 1서버)

> 대상: 운영자(Mason/Nova)가 결제/인프라를 관리하고, 직원은 자기 서버만 쓰는 모델

---

## 0) 왜 이 구조가 맞나

- 회사 PC에 직접 설치하면 키/세션/권한 관리가 어렵고 퇴사 시 회수가 번거롭습니다.
- **Hetzner 1인 1서버**면 격리/감사/폐기(삭제)가 명확합니다.
- 문제 발생 시 해당 직원 서버만 정지/삭제하면 끝납니다.

---

## 1) Hetzner 설정법 (결제는 운영자)

### 1-1. 계정/결제
1. Hetzner Cloud 계정 생성
2. 결제수단 등록 (카드/계좌)
3. 프로젝트 생성 (예: `openclaw-team`)

### 1-2. API 토큰 생성
1. Project → Security → API Tokens
2. Read/Write 토큰 발급
3. 운영자 로컬에서만 보관 (`HCLOUD_TOKEN`)

```bash
export HCLOUD_TOKEN="<hetzner_api_token>"
```

### 1-3. 기본 서버 스펙
- 기본 권장: `cax21` (4 vCPU / 8GB)
- 무거운 사용자: `cax31`
- 이미지: `ubuntu-24.04`
- 위치: `nbg1` or `hel1`

---

## 2) 실제 온보딩 순서 (누가 뭘 주는지)

이게 표준 순서입니다.

1. **직원**: 자기 PC에서 SSH 키 생성
   ```bash
   ssh-keygen -t ed25519 -C "openclaw-<employee>" -f ~/.ssh/openclaw-<employee>
   ```

2. **직원 → 운영자**: `~/.ssh/openclaw-<employee>.pub` 내용만 전달
   - private key는 절대 공유하지 않음

3. **운영자**: 받은 `.pub`를 로컬 파일로 저장
   - 예: `~/.ssh/openclaw-minsu.pub`

4. **운영자**: Hetzner 서버 생성 스크립트 실행

5. **운영자 → 직원**: 서버 IP 전달
   - 전달 대상: 서버 IP, 접속 방법, 온보딩 카드 링크

6. **직원**: 자기 private key로 SSH 접속

7. **직원**: OpenClaw 설치/인증/모델 선택 직접 수행

8. **직원 → 운영자**: 완료 보고
   - 선택 모델 + health/audit 결과

---

## 3) SSH 설정 정책

### 3-1. 키 관리 원칙
- 서버에는 **공개키(.pub)**만 등록
- 개인키는 해당 직원만 보유
- 운영자는 직원 개인키를 보지 않음

### 3-2. 접속 정책
- 초기 접속: `root` (bootstrap 전용)
- 운영 단계: `openclaw` 유저 중심
- 비밀번호 로그인 비활성화/키 기반만 허용(권장)

---

## 4) OpenClaw 설치 자동화 (2가지 모드)

경로:
- `/Users/nova/.openclaw/workspace-nova/vibe-coding-lecture/provision-hetzner-openclaw-user.sh`
- `/Users/nova/.openclaw/workspace-nova/vibe-coding-lecture/openclaw-setup-hetzner.sh`
- `/Users/nova/.openclaw/workspace-nova/vibe-coding-lecture/employee-onboarding-card.md` (직원용 1페이지)

### 4-A) 운영자 중앙 bootstrap 모드 (자동화 최대)
운영자가 Telegram Bot/Chat ID까지 넣어서 설치를 대신 끝냄.

```bash
cd /Users/nova/.openclaw/workspace-nova/vibe-coding-lecture

./provision-hetzner-openclaw-user.sh \
  --hcloud-token "$HCLOUD_TOKEN" \
  --employee minsu \
  --ssh-pubkey-file ~/.ssh/openclaw-minsu.pub \
  --telegram-bot-token "<tg_bot_token>" \
  --telegram-chat-id "<employee_chat_id>" \
  --auth-mode skip
```

### 4-B) 직원 자율 bootstrap 모드 (권장: CLI 학습 목적)
운영자는 서버만 만들고, 직원이 자기 정보(텔레그램/인증/모델)를 직접 넣음.

#### 1) 운영자 (서버만 생성)
```bash
./provision-hetzner-openclaw-user.sh \
  --hcloud-token "$HCLOUD_TOKEN" \
  --employee minsu \
  --ssh-pubkey-file ~/.ssh/openclaw-minsu.pub \
  --no-bootstrap
```

#### 2) 운영자 (설치 스크립트 전달, 1회)
```bash
scp ./openclaw-setup-hetzner.sh root@<SERVER_IP>:/root/openclaw-setup-hetzner.sh
```

#### 3) 직원 (SSH 접속 후 자기 정보로 설치)
```bash
bash /root/openclaw-setup-hetzner.sh \
  --user-name "<YOUR_NAME>" \
  --telegram-bot-token "<YOUR_TG_BOT_TOKEN>" \
  --telegram-chat-id "<YOUR_CHAT_ID>" \
  --auth-mode skip
```

> `skip`은 인증을 나중에 본인이 직접 선택하는 모드.

---

## 5) 인증/모델 선택 (직원이 직접)

### 5-1. 인증
```bash
sudo -u openclaw -H openclaw models auth add
# 또는
sudo -u openclaw -H openclaw models auth login --provider <provider-id> --set-default
```

### 5-2. 모델 선택
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

## 6) 운영 체크리스트 (실서비스 기준)

### 필수
- [ ] `openclaw status --json` 정상
- [ ] Telegram 메시지 왕복 확인
- [ ] `openclaw security audit --deep` 실행
- [ ] 직원별 서버/키/토큰 매핑 시트 기록

### 권장
- [ ] 자동 업데이트 창구 정하기 (월 1회)
- [ ] 일일 스냅샷/백업 정책
- [ ] 장애 대응 Runbook (재시작/롤백/폐기)

---

## 7) 오프보딩 절차 (중요)

1. Hetzner 서버 삭제
2. Hetzner SSH key 삭제
3. OpenClaw/채널 토큰 폐기 또는 회전
4. 내부 자산 목록에서 사용자 제거

---

## 8) 지금 질문에 대한 답: "이것만 하면 되나?"

아니요. **설치 3단계 + 운영 4단계**가 있어야 완성입니다.

- 설치: (1) Hetzner (2) SSH (3) OpenClaw bootstrap
- 운영: (4) 보안점검 (5) 모니터링 (6) 백업 (7) 오프보딩

설치만 해두면 다음 분기부터 운영 부채가 폭발합니다.

---

## 9) 다음 자동화 확장 (원하면 바로 추가 가능)

1. 팀 CSV 일괄 온보딩 (`employees.csv` -> 서버 N개 자동 생성)
2. 서버 라벨 기준 비용 집계 스크립트
3. 주간 health-check cron 자동 등록
4. 원클릭 폐기 스크립트 (서버+키+토큰 회전 템플릿)
