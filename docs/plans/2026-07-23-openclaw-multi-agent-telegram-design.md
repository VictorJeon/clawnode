# OpenClaw Multi-Agent Telegram Provisioner

## Goal

Add an isolated OpenClaw agent to an existing ClawNode/OpenClaw 2026.7.1 installation with only two user inputs: a display name and a Telegram bot token. The script can be run repeatedly to add any number of agents to the same Gateway.

## Decisions

- Ship a separate script rather than extend `openclaw-setup-v7.sh`.
- Keep each agent's workspace, `agentDir`, sessions, and memory isolated.
- Reuse the default agent's effective model and OpenClaw 2026.7.1 main-agent auth fallback. Never share or symlink `agentDir`.
- Share globally installed skills and global plugin/tool configuration. Seed persona and operating files from the default workspace, but do not copy `MEMORY.md`, `memory/`, session data, secrets, or repository metadata.
- Create one Telegram account and one exact `telegram:<accountId>` binding per agent.
- Store bot tokens in the existing v7 file SecretRef store rather than plaintext config or shell arguments.
- Authenticate the owner with the installer's proven one-time-message detection flow instead of OpenClaw's pairing-code CLI. The script asks the user to send a generated code to the new bot, reads that account's Telegram updates, extracts the numeric sender ID, and switches the account to a one-person allowlist.

## Provisioning Flow

1. Verify macOS, OpenClaw 2026.7.1, a valid config, a healthy default agent, and a usable Gateway.
2. Read the display name and token from an interactive TTY. Never echo the token.
3. Call Telegram `getMe`, derive a stable lowercase account/agent ID from the bot username, and reject duplicate IDs or tokens.
4. Resolve the default agent's effective model and workspace.
5. Create a separate workspace and seed only approved setup files.
6. Add the agent through `openclaw agents add`, then set its display identity.
7. Add the Telegram account through supported config operations, backed by the existing v7 SecretRef provider and file.
8. Bind only that Telegram account to the new agent and safely restart the Gateway.
9. Generate a one-time verification string and poll Telegram updates for that exact account until the user sends it.
10. Write the detected sender ID to the account's `allowFrom`, set `dmPolicy=allowlist`, reload/restart, and run final probes.

## Safety And Recovery

- Acquire a per-state-directory lock so two provisioning runs cannot edit config concurrently.
- Back up `openclaw.json` and the SecretRef file before mutation.
- Track completed steps. On failure, remove only the newly created binding, Telegram account, agent, workspace, and secret entry, then restore validated configuration where necessary.
- Refuse to overwrite an existing agent/account/workspace.
- Keep temporary token files mode `0600` and remove them with a trap.
- Redact tokens from logs and command output.

## Verification

Contract tests use a fake `openclaw` executable and a local Telegram API fixture to prove ID derivation, workspace seeding exclusions, SecretRef layout, exact binding, owner detection, idempotency, and rollback. Static gates run `bash -n` and ShellCheck when available. A remote E2E run on OpenClaw 2026.7.1 verifies config validation, agent/account/binding visibility, Gateway/channel health, auth/model inheritance, and a real prompt after a disposable Telegram bot token is available.
