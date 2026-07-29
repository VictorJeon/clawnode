# OpenClaw Telegram Agent 추가 SOP

## 목적

`openclaw-setup-v7.sh`로 설치된 OpenClaw 2026.7.1 Gateway에 별도 Telegram bot과 격리된 agent를 추가한다. 한 번 실행할 때 agent 하나를 추가하며, 같은 명령을 반복해 원하는 수만큼 만들 수 있다.

## 요구사항

- macOS
- OpenClaw 2026.7.1
- 정상 동작 중인 기본 `main` agent와 Gateway
- 정상 연결된 기존 기본 Telegram account
- v7 설치기가 만든 JSON file SecretRef provider
- BotFather에서 발급한 아직 다른 Gateway가 사용하지 않는 Telegram bot token

## 실행

공개 Gist에서 바로 실행:

```bash
bash <(curl -fsSL https://gist.githubusercontent.com/VictorJeon/d5a5759cd69f9ed73e087512f7af65d8/raw/openclaw-add-agent.sh)
```

저장소 체크아웃에서는 다음과 같이 실행할 수 있다.

```bash
bash installer/scripts/openclaw-add-agent.sh
```

스크립트는 다음 세 단계만 요구한다.

1. bot 표시 이름 입력
2. Telegram bot token 입력. 화면과 로그에 표시되지 않는다.
3. 출력된 `clawnode-link-xxxxxxxx` 문자열을 새 bot의 개인 대화에 그대로 전송

Telegram `getMe`에서 확인한 bot username으로 agent/account ID를 자동 생성한다. 예를 들어 `@ClawNode_Sales_Bot`은 `clawnode-sales-bot`이 된다.

## 생성 결과

- agent: `<telegram-username을 정규화한 id>`
- workspace: `~/.openclaw/workspace-<agent-id>`
- Telegram account: `channels.telegram.accounts.<agent-id>`
- binding: `telegram:<agent-id>`에서 같은 ID의 agent로만 연결
- model: 기본 `main` agent의 현재 모델
- auth: 별도 `agentDir`을 사용하며 OpenClaw 2026.7.1의 `main` auth fallback 사용
- token: v7 JSON file SecretRef에 저장
- DM policy: 감지한 숫자 Telegram user ID 한 명만 허용

기존 Telegram 설정이 단일-account 형식이면 OpenClaw 2026.7.1의 `channels add`가 이를 `accounts.default`로 공식 승격한다. 기존 default account ID와 bot ID를 실행 전에 저장하고, 재시작 뒤 기존 bot과 새 bot이 모두 같은 ID로 `running`, `connected`, `probe ok`인지 확인한다.

`AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `BOOT.md`, workspace-local `skills/`는 기본 workspace에서 초기 복제한다. `MEMORY.md`, `memory/`, 세션, secret, `.git`은 복제하지 않는다. 전역 `~/.openclaw/skills`와 plugin/tool 기본 설정은 Gateway 차원에서 계속 공유한다.

## OpenClaw 2026.7.1 메모리 호환성

2026.7.1의 `memory-lancedb`는 agent owner 분리 없이 하나의 DB를 사용하며, `memory-wiki`도 agent별 vault scope를 제공하지 않는다. 새 agent가 기존 사용자의 plugin memory를 읽지 않도록 스크립트는 다음 보호를 적용한다.

- `memory-lancedb`가 active slot이면 전역 `autoRecall`과 `autoCapture`를 `false`로 변경
- 새 secondary agent에서 `memory_recall`, `memory_store`, `memory_forget` 차단
- 새 secondary agent에서 `wiki_status`, `wiki_lint`, `wiki_apply`, `wiki_search`, `wiki_get` 차단
- workspace 파일 기억과 agent별 QMD 인덱스는 계속 사용
- `main` agent의 기존 plugin memory tool 접근은 유지

OpenClaw/plugin이 agent-owned memory storage를 공식 지원하면 이 보호 정책을 재검토한다.

## 검증과 복구

성공 전 다음 검증을 모두 실행한다.

- `openclaw config validate --json`
- agent model/workspace 확인
- 정확한 Telegram account binding 확인
- 기존 default와 새 account 모두 `openclaw channels status --channel telegram --probe --json` 확인
- 새 agent의 model/auth status 확인
- `openclaw secrets audit --json`
- 새 agent 실제 prompt smoke

로그와 검증 결과는 `~/.openclaw/setup-v7/add-agent-runs/<timestamp>-<agent-id>/`에 저장된다.

설정 변경 후 실패하면 새 binding, account, agent, workspace, agent state, token secret만 제거한다. Gateway RPC 삭제가 실패해도 새 agent의 workspace가 이번 실행 경로와 정확히 일치할 때만 local config fallback을 적용한다. LanceDB hook을 이번 실행에서 변경했다면 이전 값으로 복구하며, 기존 agent와 Telegram account는 삭제하지 않는다.

## 자동화 입력

대화형 입력 대신 환경 변수를 사용할 수 있다.

```bash
OPENCLAW_AGENT_NAME='Sales Bot' \
OPENCLAW_TELEGRAM_BOT_TOKEN='123456789:token' \
bash installer/scripts/openclaw-add-agent.sh
```

이미 확인한 숫자 owner ID가 있을 때만 자체 Telegram 메시지 감지를 생략할 수 있다.

```bash
OPENCLAW_TELEGRAM_OWNER_ID='7484970138' \
OPENCLAW_AGENT_NAME='Sales Bot' \
OPENCLAW_TELEGRAM_BOT_TOKEN='123456789:token' \
bash installer/scripts/openclaw-add-agent.sh
```

`OPENCLAW_ADD_AGENT_PROMPT_SMOKE=0`은 provider 호출이 불가능한 점검 환경에서만 사용한다.
