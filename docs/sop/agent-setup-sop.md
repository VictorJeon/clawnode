# Agent Setup SOP — SSH 원격 세팅 가이드

> 고객이 스크립트(`openclaw-setup.sh`)를 실행한 뒤,
> 에이전트(Nova/Sol)가 SSH로 접속하여 마무리하는 표준 절차.

---

## 0. 접속 전 확인사항

고객이 설치 완료 후 클립보드에 복사된 **설치 결과**를 보내줌:

```
🦞 OpenClaw 설치 결과
상태: ✅ 성공
이름: Mason
호스트: Masons-MacBook.local
OS: macOS 15.3 (arm64)
OpenClaw: 2026.3.1
공인IP: 123.45.67.89
유저: mason
원격접속: ssh mason@abc123.localhost.run    ← 이 주소로 접속
ChatID: 819845604
모델: 1
```

추가로 Mason이 확인할 것:
- [ ] 고객이 원하는 커스텀 요구사항 (자동화, 특수 스킬 등)
- [ ] 고객 터미널 창이 열려있는지 (닫으면 터널 끊김)

---

## 1. 접속 및 기본 상태 확인

```bash
# SSH 접속
ssh <user>@<ip>

# OpenClaw 설치 확인
openclaw --version
openclaw gateway status
openclaw health

# Config 존재 및 기본 구조 확인 (⚠️ cat 금지 — 토큰 노출 방지)
node -e '
  const c = JSON.parse(require("fs").readFileSync(process.env.HOME+"/.openclaw/openclaw.json","utf8"));
  const safe = {...c};
  // 민감 필드 마스킹
  const mask = (obj) => {
    for (const [k,v] of Object.entries(obj||{})) {
      if (/key|token|secret|password/i.test(k) && typeof v === "string")
        obj[k] = v.slice(0,8) + "...";
      else if (typeof v === "object" && v !== null) mask(v);
    }
  };
  mask(safe);
  console.log(JSON.stringify(safe, null, 2).split("\n").slice(0,50).join("\n"));
'

# Workspace 확인
ls -la ~/.openclaw/workspace/
```

### 체크리스트
- [ ] `openclaw --version` 정상 출력
- [ ] `openclaw gateway status` → running
- [ ] `openclaw health` → 에러 없음
- [ ] `~/.openclaw/openclaw.json` 존재
- [ ] `~/.openclaw/workspace/` 에 SOUL.md, AGENTS.md 존재

---

## 2. 인증 확인

```bash
# auth profiles 존재 확인 (⚠️ 절대 cat으로 원문 출력 금지)
ls ~/.openclaw/agents/*/agent/auth-profiles.json 2>/dev/null

# 키 존재만 확인 (마스킹)
node -e '
  const fs = require("fs");
  const glob = require("path");
  try {
    const p = fs.readdirSync(process.env.HOME + "/.openclaw/agents/").map(a =>
      process.env.HOME + "/.openclaw/agents/" + a + "/agent/auth-profiles.json"
    ).filter(f => fs.existsSync(f));
    p.forEach(f => {
      const d = JSON.parse(fs.readFileSync(f, "utf8"));
      Object.keys(d).forEach(k => console.log("  profile:", k, "— keys:", Object.keys(d[k]).join(",")));
    });
  } catch(e) { console.log("확인 실패:", e.message); }
'

# OAuth 크리덴셜 존재 확인
ls ~/.openclaw/credentials/ 2>/dev/null

# 모델 동작 테스트
openclaw health
```

### 체크리스트
- [ ] auth-profiles.json 존재하고 비어있지 않음
- [ ] 설정된 모델로 실제 응답 가능

---

## 3. Telegram 연동 확인

```bash
# config에서 telegram 설정 확인
node -e '
  const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const tg = c.channels?.telegram;
  console.log("enabled:", tg?.enabled);
  console.log("botToken:", tg?.botToken?.slice(0,10) + "...");
  console.log("allowFrom:", tg?.allowFrom);
' ~/.openclaw/openclaw.json
```

### 테스트
1. 고객 텔레그램에서 봇에게 "안녕" 전송
2. 응답이 오는지 확인
3. 안 오면 → `openclaw logs --tail 20` 으로 에러 확인

### 체크리스트
- [ ] botToken 설정됨
- [ ] allowFrom에 고객 Chat ID 포함
- [ ] 실제 메시지 송수신 테스트 통과

---

## 4. Daemon 확인

```bash
# macOS LaunchAgent 확인
ls ~/Library/LaunchAgents/ | grep -i openclaw
launchctl list | grep -i openclaw

# 자동 시작 테스트 (데몬이 등록되어 있으면)
launchctl kickstart -k gui/$(id -u)/com.openclaw.gateway 2>/dev/null

# systemd (Linux/WSL)
systemctl --user status openclaw-gateway 2>/dev/null
```

### 체크리스트
- [ ] LaunchAgent 또는 systemd unit 등록됨
- [ ] 재부팅 후에도 자동 시작되는지 확인 (가능하면)

---

## 5. SOUL.md / AGENTS.md 커스텀

고객 요구사항에 맞게 수정:

```bash
# 편집
nano ~/.openclaw/workspace/SOUL.md
nano ~/.openclaw/workspace/AGENTS.md
```

### 커스텀 포인트
- **말투**: 존댓말/반말, 이모지 빈도
- **역할**: "비서", "동료", "코치" 등
- **전문 분야**: 마케팅, 개발, 학술 등
- **금지사항**: 고객이 원하지 않는 행동
- **자동화**: 반복 업무 정의

### 체크리스트
- [ ] 고객 이름이 USER.md에 반영
- [ ] SOUL.md에 고객 성향 반영
- [ ] AGENTS.md에 업무 규칙 반영

---

## 6. 보안 점검

```bash
# 1) API 키가 config에 평문으로 노출되어 있는지 (⚠️ 마스킹 출력)
node -e '
  const c = JSON.parse(require("fs").readFileSync(process.env.HOME+"/.openclaw/openclaw.json","utf8"));
  const mask = (s) => typeof s === "string" ? s.slice(0,8) + "..." : s;
  const scan = (obj, path="") => {
    for (const [k,v] of Object.entries(obj||{})) {
      if (/key|token|secret|password/i.test(k) && typeof v === "string")
        console.log("  ⚠️", path+k+":", mask(v));
      else if (typeof v === "object") scan(v, path+k+".");
    }
  };
  scan(c);
'

# 2) 파일 퍼미션
ls -la ~/.openclaw/openclaw.json      # 반드시 600
ls -la ~/.openclaw/credentials/       # 700
ls -la ~/.openclaw/.setup-env         # 삭제되었는지 확인

# 3) Gateway 바인드 확인 (loopback이어야 안전)
node -e '
  const c = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  console.log("bind:", c.gateway?.bind);
  console.log("auth:", c.gateway?.auth);
' ~/.openclaw/openclaw.json

# 4) 방화벽 (macOS)
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# 5) .setup-env 삭제 확인 (API 키 포함 가능)
test -f ~/.openclaw/.setup-env && echo "⚠️ .setup-env 잔존! 삭제 필요" || echo "✅ .setup-env 삭제됨"
```

### 보안 체크리스트
- [ ] Gateway bind = loopback (외부 노출 없음)
- [ ] Gateway auth = token (인증 필수)
- [ ] .setup-env 삭제됨
- [ ] Config 파일 퍼미션 = 600 (필수)
- [ ] 방화벽 활성화 상태

### 보안 강화 (선택)
```bash
# Config 파일 퍼미션 잠금
chmod 600 ~/.openclaw/openclaw.json
chmod -R 700 ~/.openclaw/credentials/ 2>/dev/null

# .setup-env 삭제 (혹시 남아있으면)
rm -f ~/.openclaw/.setup-env
```

---

## 7. 스킬 동작 확인

텔레그램에서 각 스킬 테스트:
```
"오늘 서울 날씨 알려줘"          → weather 스킬
"https://example.com 요약해줘"   → summarize 스킬
"내일 오후 3시에 알림 줘"        → cron/리마인더
```

### 체크리스트
- [ ] 날씨 응답 정상
- [ ] URL 요약 정상
- [ ] 리마인더 설정 정상

---

## 8. 완료 보고

Mason에게 전달할 내용:
```
✅ 설치 완료 보고
- OpenClaw 버전: X.X.X
- 모델: Claude/ChatGPT/Gemini
- 채널: Telegram (ChatID: XXXXX)
- Daemon: LaunchAgent 등록 ✅
- 보안: loopback + token auth ✅
- 테스트: 메시지 송수신 ✅ / 날씨 ✅ / 요약 ✅
- 커스텀: SOUL.md/AGENTS.md 고객 맞춤 완료
- 특이사항: (있으면 기록)
```

---

## 9. 정리 (작업 완료 후 필수)

> ⚠️ 이 단계를 빼먹으면 고객 컴퓨터에 보안 구멍이 남는다.

### 정리 방식: 에이전트가 정리 스크립트를 만들고 → Mason이 고객에게 실행 요청

에이전트는 SSH로 접속 중이라 `sudo` 권한이 없을 수 있다.
SSH 비활성화(`sudo systemsetup -setremotelogin off`)는 sudo가 필요하므로,
**에이전트가 정리 스크립트를 작성** → **고객이 직접 실행**하는 구조.

### 9.1 에이전트: 정리 스크립트 생성 (SSH 세션에서)

```bash
cat > /tmp/openclaw-cleanup.sh << 'CLEANUP'
#!/bin/bash
echo ""
echo "🧹 OpenClaw 설치 정리 중..."
echo ""

# 1) SSH 터널 종료
pkill -f "localhost.run" 2>/dev/null && echo "  ✅ 원격 접속 터널 종료" || echo "  ✅ 터널 이미 종료됨"

# 2) SSH 비활성화
if [[ "$(uname)" == "Darwin" ]]; then
  sudo systemsetup -setremotelogin off 2>/dev/null && echo "  ✅ SSH 비활성화 (macOS)"
else
  sudo systemctl stop sshd 2>/dev/null || sudo service ssh stop 2>/dev/null
  echo "  ✅ SSH 비활성화 (Linux)"
fi

# 3) 임시 파일 삭제
rm -f /tmp/openclaw-setup.sh /tmp/openclaw-setup-wsl.sh
rm -f /tmp/openclaw-tunnel.log
rm -f /tmp/openclaw-cleanup.sh  # 자기 자신도 삭제
rm -f ~/.openclaw/.setup-env
echo "  ✅ 임시 파일 삭제"

echo ""
echo "  🎉 정리 완료! 이 창을 닫으셔도 됩니다."
echo ""
CLEANUP
chmod +x /tmp/openclaw-cleanup.sh
echo "✅ 정리 스크립트 생성 완료: /tmp/openclaw-cleanup.sh"
```

### 9.2 에이전트: Mason에게 완료 보고

> SSH 세션에서 Mason에게 Telegram으로 보고:
> "작업 완료. 고객에게 아래 명령어 실행 요청해주세요."

### 9.3 Mason → 고객에게 안내

고객에게 전달할 메시지:
```
설정이 모두 끝났습니다! 🎉

마지막으로, 보안을 위해 아래 한 줄만 실행해주세요:
(터미널에 복사+붙여넣기 하시면 됩니다)

bash /tmp/openclaw-cleanup.sh

실행하면 원격 접속이 해제되고 임시 파일이 정리됩니다.
그 후 터미널을 닫으셔도 됩니다.
```

### 실행 순서 요약

```
에이전트 SSH 접속 중:
  1~7  세팅 작업
  8    Mason에게 보고
  9.1  정리 스크립트 생성 (/tmp/openclaw-cleanup.sh)
  9.2  Mason에게 "고객한테 정리 스크립트 실행시켜주세요" 전달

에이전트 SSH 종료 (수동 exit 또는 고객이 정리 스크립트 실행하면 터널 끊겨서 자동 종료)

고객이 실행:
  bash /tmp/openclaw-cleanup.sh
  → 터널 종료 + SSH 비활성화 + 임시 파일 삭제
  → "창을 닫으셔도 됩니다"
```

> 💡 왜 이 구조인가:
> - 에이전트는 SSH 접속이라 `sudo` 불가능할 수 있음
> - 고객 터미널에서 실행하면 `sudo` 프롬프트가 뜨고, 고객이 비밀번호 입력 가능
> - 터널 kill 시 에이전트 세션이 끊기므로, 에이전트가 직접 실행하면 이후 명령 불가
> - 스크립트가 자기 자신도 삭제 (`rm -f /tmp/openclaw-cleanup.sh`)

---

_마지막 업데이트: 2026-03-03_
