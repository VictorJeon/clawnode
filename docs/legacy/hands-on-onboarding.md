# 바이브코딩 실전 온보딩 가이드

**용도**: 팀원/지인에게 1:1로 바이브코딩 환경 세팅 + 첫 빌드까지
**시간**: 2~3시간
**전제**: Mason이 옆에 있거나 화면 공유 중
**대상**: Mac Mini 있는 사람 (윈도우 PC에서 원격 접속 OK)

---

## 핵심 원칙

- 이론/동기부여 없음. 이미 하고 싶어서 온 사람들.
- 예제 프로젝트 없음. **본인이 만들고 싶은 걸 만듦.**
- **OpenClaw 먼저, Claude Code는 나중에.** 채팅이 터미널보다 쉬움.

---

## 온보딩 스택

```
Layer 1: Mac Mini + OpenClaw + Telegram  ← 여기서 시작 (진입장벽 0)
Layer 2: Tailscale + VS Code SSH         ← 코드 보고 싶을 때
Layer 3: Claude Code Extension (GUI)     ← 직접 수정하고 싶을 때
```

**Layer 1만으로 충분한 것들**: 봇 만들기, 데이터 수집, 자동화, 알림, 리서치
**Layer 2가 필요한 때**: 만든 코드를 직접 보고 싶을 때
**Layer 3이 필요한 때**: 코드를 세밀하게 수정하고 싶을 때

---

## Phase 0: 사전 준비 (만나기 전)

상대에게 보낼 메시지:

```
내일 만나기 전에 이것만 해놔:

1. Mac Mini 준비
   - 인터넷 연결 + 전원 켜놓기
   - macOS 초기 설정 완료 (계정 만들기까지)
   - (윈도우 PC에서 접속할 거면) Mac Mini 모니터 없어도 됨

2. Claude 가입 + Pro 결제 ($20/월)
   → https://claude.ai → 회원가입 → Pro 업그레이드

3. Telegram 설치 + 봇 만들기
   → Telegram에서 @BotFather 검색 → /newbot → 이름 설정
   → 봇 토큰(긴 문자열) 따로 저장해놔
   → 만든 봇에게 아무 메시지 하나 보내기 (/start)

4. 만들고 싶은 거 구체적으로 정리해와.
   "텔레그램 봇" 말고 "텔레그램에서 특정 채널 메시지를
   내 채널로 자동 포워딩하는 봇" 이런 식으로.
```

> **4번이 제일 중요.** 바이브코딩의 80%는 "뭘 만들지" 아는 것.
> 기획이 명확하면 2시간 안에 끝남. 모호하면 5시간도 모자람.

---

## Phase 1: 환경 세팅 (20~30분)

### Step 1-1: Mac Mini SSH 활성화

Mac Mini 앞에서 (또는 화면 공유로):
1. **시스템 설정 → 일반 → 공유 → 원격 로그인** 켜기
2. "다음 사용자에 대한 액세스 허용" → 현재 사용자 확인

터미널에서 확인:
```bash
# SSH 켜졌는지 확인
sudo systemsetup -getremotelogin
# → Remote Login: On 이면 성공
```

### Step 1-2: Tailscale 설치 (Mac Mini + 윈도우 PC)

**왜 Tailscale?**: 같은 와이파이가 아니어도, 집 밖에서도 Mac Mini에 접속 가능. VPN인데 설정이 1분.

**Mac Mini에서:**
```bash
# Homebrew 설치 (없으면)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Tailscale 설치
brew install --cask tailscale

# Tailscale 앱 실행 → 로그인 (Google/GitHub/Apple 아무거나)
open /Applications/Tailscale.app
```

**윈도우 PC에서:**
1. https://tailscale.com/download/windows 에서 설치
2. 로그인 (Mac Mini와 **같은 계정**)
3. 시스템 트레이에서 Tailscale 아이콘 → Connected 확인

**IP 확인:**
```bash
# Mac Mini 터미널에서
tailscale ip -4
# → 100.x.x.x 형태의 IP가 나옴. 이걸 메모.
```

### Step 1-3: SSH 키 설정 (비밀번호 없이 접속)

**윈도우 PowerShell에서:**
```powershell
# SSH 키 생성 (이미 있으면 스킵)
ssh-keygen -t ed25519
# 엔터 3번 (기본 경로, 패스프레이즈 없이)

# Mac Mini에 키 복사
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh 사용자이름@100.x.x.x "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
# → Mac Mini 비밀번호 한 번만 입력

# 테스트 — 비밀번호 없이 접속되면 성공
ssh 사용자이름@100.x.x.x
```

> `사용자이름`은 Mac Mini 계정 이름. `100.x.x.x`는 Tailscale IP.

### Step 1-4: VS Code에서 SSH 연결

**윈도우 PC에서:**

1. VS Code 설치: https://code.visualstudio.com/
2. 확장 프로그램 설치: **Remote - SSH** (Microsoft)
3. `Ctrl+Shift+P` → "Remote-SSH: Add New SSH Host"
4. 입력: `ssh 사용자이름@100.x.x.x`
5. config 파일 선택 → 저장
6. `Ctrl+Shift+P` → "Remote-SSH: Connect to Host" → 방금 추가한 호스트 선택
7. OS 선택: **macOS**
8. 연결되면 좌측 하단에 `SSH: 100.x.x.x` 표시

**SSH config 직접 편집 (선택):**

`C:\Users\{이름}\.ssh\config` 파일:
```
Host macmini
    HostName 100.x.x.x
    User 사용자이름
    IdentityFile ~/.ssh/id_ed25519
```
→ 이후 `ssh macmini`만 치면 접속됨.

### Step 1-5: OpenClaw 설치

Mac Mini 터미널에서 (VS Code SSH 터미널이든, 직접이든):

```bash
# 원클릭 셋업 스크립트 실행
bash <(curl -fsSL https://gist.githubusercontent.com/VictorJeon/5276afd04d974985537a1ceb7e100e9f/raw/openclaw-setup.sh)
```

스크립트가 물어보는 것:
1. Claude 인증 방법 (setup-token 추천 → claude.ai에서 복사)
2. Telegram 봇 토큰 (BotFather에서 받은 거)
3. Telegram Chat ID (자동 감지됨)
4. 봇 이름/성격 설정

**완료 확인**: Telegram에서 봇에게 `안녕?` → 대답하면 성공 🎉

---

## Phase 2: 첫 체험 — "이게 되네?" (15분)

**상대가 텔레그램에서 직접 해봄.** Mason은 옆에서 지켜보기만.

```
봇한테: 오늘 서울 날씨 어때?
봇한테: 비트코인 지금 가격 알려줘
봇한테: 이 기사 요약해줘 [URL 붙여넣기]
```

**이 단계의 목표**: "텔레그램으로 AI한테 일 시킬 수 있구나" 체감.
특별한 건 아닌데, **24시간 Mac Mini에서 돌아간다**는 게 포인트.

---

## Phase 3: 기획 구체화 (10분)

Mason이 질문으로 유도:

```
Mason: "뭐 만들고 싶다고 했지?"
상대: "텔레그램 포워딩 봇이요"

Mason: "어떤 채널에서 어떤 채널로?"
상대: "A 채널 메시지를 B 채널로"

Mason: "모든 메시지? 특정 키워드만?"
상대: "BTC, ETH 들어간 것만"

Mason: "오케이, 그럼 봇한테 시켜보자"
```

---

## Phase 4: 첫 빌드 — 봇한테 시키기 (30~45분)

**상대가 텔레그램에서 직접 봇한테 요청.**

```
텔레그램 봇을 하나 만들어줘.

기능:
- 채널 A의 메시지를 모니터링
- 메시지에 BTC, ETH 키워드가 포함되면
- 내 채널 B로 원본 메시지 그대로 포워딩

채널 A 이름: @crypto_signals
내 채널: @my_channel

Node.js로 만들고, 완성되면 실행까지 해줘.
```

→ OpenClaw이 코드 작성 → 파일 생성 → 실행
→ 상대가 텔레그램에서 확인 → "와 진짜 되네!"

**Mason이 하는 것:**
- 지켜보기. 끼어들지 않기.
- 에러 나면 "봇한테 에러 메시지 그대로 보내봐" 한마디만.

**Mason이 안 하는 것:**
- 코드 설명 ❌
- 대신 타이핑 ❌
- "이건 이래서 이렇게 하는 거야" 설명 ❌

> **"내가 했다"는 자신감이 핵심.**

---

## Phase 5: 기능 추가 + 자유 실험 (30~45분)

```
Mason: "뭐 더 넣고 싶은 거 없어?"
상대: "포워딩할 때 번역도 해주면 좋겠는데"
Mason: "봇한테 말해봐"
```

### 에러가 날 때
```
상대: "에러 났어요"
Mason: "에러 메시지 봇한테 보내봐. '이거 고쳐줘'라고"
```

### VS Code가 필요해지는 순간
```
상대: "봇이 만든 코드를 직접 보고 싶은데..."
Mason: "아까 세팅한 VS Code에서 폴더 열어봐"
```
→ VS Code 좌측 탐색기에서 프로젝트 폴더 열기
→ "아 이렇게 생겼구나" 수준이면 충분

---

## Phase 6: 마무리 (10분)

### 혼자 할 때 기억할 것 3가지

**1. 텔레그램으로 시키면 됨**
```
아무 때나 봇한테: "이거 해줘"
```

**2. 에러는 봇한테**
```
에러 메시지 복붙 → "이거 고쳐줘"
```

**3. 뭘 시킬지 모르겠으면 물어봐**
```
봇한테: "내가 만든 포워딩 봇에 뭘 더 추가하면 좋을까?"
```

---

## 부록 A: OpenClaw 기본 명령어

```bash
# === 상태 확인 ===
openclaw status              # 전체 상태 한눈에
openclaw gateway status      # 게이트웨이 상태
openclaw logs                # 실시간 로그
openclaw logs --follow       # 로그 스트리밍

# === 시작/중지/재시작 ===
openclaw gateway start       # 시작
openclaw gateway stop        # 중지
openclaw gateway restart     # 재시작

# === 설정 ===
openclaw configure           # 대화형 설정
openclaw config get          # 현재 설정 보기

# === 문제 해결 ===
openclaw doctor              # 자동 진단
openclaw doctor --fix        # 자동 진단 + 수정

# === 업데이트 ===
openclaw update              # 최신 버전으로 업데이트
```

## 부록 B: ClawHub — 스킬 설치

ClawHub (https://clawhub.com)은 OpenClaw 스킬 마켓플레이스.
봇에게 새로운 능력을 추가할 수 있음.

```bash
# 스킬 검색
clawhub search weather       # 날씨 관련 스킬 찾기
clawhub search stock         # 주식 관련 스킬 찾기

# 스킬 설치
clawhub install weather      # 날씨 스킬 설치
clawhub install stock-analysis  # 주식 분석 스킬 설치

# 설치된 스킬 목록
clawhub list

# 스킬 업데이트
clawhub update               # 전체 업데이트
clawhub update weather       # 특정 스킬만
```

설치하면 봇이 바로 사용 가능. 재시작 불필요.

## 부록 C: 크론 (자동 반복 작업)

텔레그램에서 봇한테 직접 시킬 수 있음:

```
봇한테: "매일 아침 9시에 비트코인 가격 알려줘"
봇한테: "매주 월요일에 이번 주 일정 정리해줘"
```

또는 터미널에서:
```bash
# 크론 목록 보기
openclaw cron list

# 크론 상태 확인
openclaw cron status
```

## 부록 D: 프로젝트 유형별 요청 템플릿

**텔레그램 포워딩 봇:**
```
텔레그램 봇을 만들어줘.
채널 A의 메시지 중 키워드 X가 포함된 것만 채널 B로 포워딩.
Node.js, grammy 사용. 환경변수로 토큰 관리.
완성되면 바로 실행해줘.
```

**가격 알림 봇:**
```
비트코인이 $100,000 이상이거나 $90,000 이하면
텔레그램으로 알림 보내줘. 5분마다 체크.
CoinGecko 무료 API 사용.
```

**간단한 대시보드:**
```
BTC/ETH/SOL 실시간 가격을 보여주는 웹페이지를 만들어줘.
30초마다 자동 갱신. 깔끔한 다크 테마.
포트 3000에서 실행.
```

**트위터 모니터링:**
```
특정 트위터 계정(@xxx)의 최신 트윗을 1시간마다 체크해서
내 텔레그램으로 알림 보내줘.
```

---

## Mason 치트시트

### 세션 전 체크리스트
- [ ] Mac Mini 준비 (전원, 인터넷, SSH 켜기)
- [ ] Claude Pro 결제 완료
- [ ] BotFather 봇 토큰 준비
- [ ] Tailscale 양쪽 설치 + 같은 계정 로그인
- [ ] 만들고 싶은 거 구체화 완료

### 시간 배분 가이드
| 상대 유형 | 예상 시간 | 주의점 |
|----------|----------|--------|
| IT 기본 이해 있음 | 1.5~2시간 | Phase 2 스킵 가능 |
| 완전 비개발자 | 2~2.5시간 | Phase 2에서 충분히 놀게 하기 |
| 여러 프로젝트 원함 | 3시간+ | 하나 완성 후 다음 것 |

### 긴급 복구
```bash
# 봇이 안 될 때
openclaw gateway restart

# 그래도 안 되면
openclaw doctor --fix

# Tailscale 끊겼을 때
sudo tailscale up

# Mac Mini 재부팅 후 자동 시작 안 될 때
openclaw gateway start
```
