# OpenClaw Multi-Agent Telegram Provisioner

## Goal

Add an isolated OpenClaw agent to an existing ClawNode/OpenClaw 2026.7.1 installation with only two user inputs: a display name and a Telegram bot token. The script can be run repeatedly to add any number of agents to the same Gateway.

## Decisions

- Ship a separate script rather than extend `openclaw-setup-v7.sh`.
- Keep each agent's workspace, `agentDir`, sessions, and memory isolated.
- Reuse the default agent's effective model and OpenClaw 2026.7.1 main-agent auth fallback. Never share or symlink `agentDir`.
- Share globally installed skills and global plugin/tool configuration. Seed persona and operating files from the default workspace, but do not copy `MEMORY.md`, `memory/`, session data, secrets, or repository metadata.
- OpenClaw 2026.7.1's `memory-lancedb` and `memory-wiki` stores are global rather than agent-owned. To preserve the selected memory-isolation contract, disable LanceDB auto-recall/auto-capture hooks when present and deny the secondary agent's LanceDB/Wiki tools. The secondary agent continues to use its isolated workspace memory and per-agent QMD index. Main keeps explicit access to its existing plugin memory tools.
- Create one Telegram account and one exact `telegram:<accountId>` binding per agent.
- Store bot tokens in the existing v7 file SecretRef store rather than plaintext config or shell arguments.
- Authenticate the owner with the installer's proven one-time-message detection flow instead of OpenClaw's pairing-code CLI. The script asks the user to send a generated code to the new bot, reads that account's Telegram updates, extracts the numeric sender ID, and switches the account to a one-person allowlist.

## Provisioning Flow

1. Verify macOS, OpenClaw 2026.7.1, a valid config, a healthy default agent, and a usable Gateway.
2. Read the display name and token from an interactive TTY. Never echo the token.
3. Call Telegram `getMe`, derive a stable lowercase account/agent ID from the bot username, and reject duplicate IDs or tokens.
4. Resolve the default agent's effective model, workspace, and SecretRef provider.
5. Generate a one-time verification string and poll Telegram updates until the user sends it in a private message to the new bot. Do not mutate OpenClaw before this succeeds.
6. Back up the active config and SecretRef file.
7. Add the agent through `openclaw agents add`, seed only approved setup files, and set its display identity.
8. Apply the 2026.7.1 secondary-agent memory isolation policy.
9. Add the named Telegram account through OpenClaw 2026.7.1 `channels add` using a mode-0600 temporary token file so any legacy single-account config is officially promoted to `accounts.default`; immediately replace the temporary token-file setting with the v7 SecretRef and apply the detected sender allowlist.
10. Bind only that Telegram account to the new agent and safely restart the Gateway.
11. Run config, model/auth, secrets, binding, and real-prompt probes, and require both the pre-existing default Telegram bot and the new bot to remain connected with matching probed bot IDs.

## Safety And Recovery

- Acquire a per-state-directory lock so two provisioning runs cannot edit config concurrently.
- Back up `openclaw.json` and the SecretRef file before mutation.
- Track a resource as rollback-owned only after its create command succeeds. On failure, remove only the newly created binding, Telegram account, agent, workspace/state, and secret entry, then restore validated configuration where necessary.
- If Gateway-backed delete commands are unavailable, use an exact local fallback only for entries whose agent ID, Telegram account ID, binding, and workspace match the resources owned by this run.
- Refuse to overwrite an existing agent/account/workspace.
- Keep temporary token files mode `0600` and remove them with a trap.
- Redact tokens from logs and command output.

## Verification

Contract tests use a fake `openclaw` executable and a local Telegram API fixture to prove ID derivation, workspace seeding exclusions, SecretRef layout, exact binding, owner detection, idempotency, and rollback. Static gates run `bash -n` and ShellCheck when available. A remote E2E run on OpenClaw 2026.7.1 verifies config validation, agent/account/binding visibility, Gateway/channel health, auth/model inheritance, and a real prompt after a disposable Telegram bot token is available.
