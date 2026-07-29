# OpenClaw Installer v7 SOP

Last updated: 2026-07-22

The current production pin is the exact tagged release `openclaw@2026.7.1`. The installer intentionally follows the `v2026.7.1` release tag instead of floating on npm `latest` (`2026.7.1-2` at review time). GPT-5.6 Sol remains the default model. Local isolated compatibility checks and a credential-backed beta-to-stable remote upgrade are current; older beta evidence is retained separately as history.

## Scope

v7 is the current macOS-only OpenClaw installer. Windows/WSL support is intentionally out of scope.

Use this gist for customer installs:

```bash
bash <(curl -fsSL https://gist.githubusercontent.com/VictorJeon/d5a5759cd69f9ed73e087512f7af65d8/raw/openclaw-setup-v7.sh)
```

Public gist:

- `d5a5759cd69f9ed73e087512f7af65d8`
- File: `openclaw-setup-v7.sh`
- Published 2026.7.1 SHA-256: `f80e67e30b1f960029156f56cea0c458258ab4205318ac85e5e94e4e2049922c`

The previous public v6 gist `e3207ff026158cb9e0c4a4e9d1c8cd7f` was deleted after the v7 raw gist install passed.

## Installer Contract

The v7 installer uses current OpenClaw CLI flows rather than patching OpenClaw source:

- Installs or updates the exact stable package `openclaw@2026.7.1` (`OpenClaw 2026.7.1`) instead of floating on `latest` or `beta`.
- Stops an existing OpenClaw Gateway before the npm package swap, then restarts the gateway after onboarding/configuration. This follows the current update guidance and avoids a running gateway loading files while npm is replacing the package.
- Retries the OpenClaw npm install once with optional native dependencies omitted when the first install attempt fails.
- Repairs known legacy JSON before 2026.7.1 plugin setup when a post-upgrade config validation fails: removed `agents.defaults.silentReply*` keys, legacy `plugins.allow`, top-level legacy custom providers without usable auth, and old per-agent custom provider model files that now require a non-secret auth marker. It falls back to `openclaw doctor --fix` only if the conservative JSON repair is not enough.
- Cleans legacy warning-only state as part of the idempotent repair pass: removes obsolete `approvals.exec.enabled=false` forwarding flags and renames legacy Telegram sent-message cache sidecars after preserving them with a timestamped suffix.
- Requires macOS and enforces the exact OpenClaw 2026.7.1 Node engine ranges: Node `22.22.3+` within major 22, `24.15.0+` within major 24, or `25.9.0+`; Node 23 is rejected.
- Uses `openclaw onboard` for workspace, gateway, and LaunchAgent setup.
- Restores the v5-style Tailscale and SSH remote-access step: install the Tailscale cask when absent, open the app, show login/share guidance when no tailnet IP is visible, record the resulting SSH target when connected, enable macOS Remote Login when possible, and add the ClawNode admin public key to `~/.ssh/authorized_keys`. If Tailscale is already installed, v7 prints the detected/connected state instead of silently skipping it.
- Uses `openclaw models auth paste-api-key` for non-interactive API-key E2E.
- Runs the official OpenClaw bundled skills setup during manual interactive installs. For credential-injected/noninteractive E2E, `OPENCLAW_V7_SKIP_SKILLS=auto` still adds `--skip-skills` to keep automated runs deterministic. Override with `OPENCLAW_V7_SKIP_SKILLS=0|1` when intentionally forcing either path.
- Preinstalls compatibility packages before manual official skill setup: `pnpm` for node-kind skill installers, Homebrew core `gogcli` for the `gog` binary, and `steipete/tap/mcporter` for the `mcporter` binary. OpenClaw 2026.6.11 also fixes the bundled `gog` first-run Homebrew install path, so a failed preinstall no longer has to block the official skill setup path. If a previous failed run left `gog` or `mcporter` disabled in `openclaw.json`, v7 re-enables those entries once the matching binaries are present.
- Ensures `MEMORY.md`, `memory/`, `PROJECT-STATE.md`, `BOOT.md`, `SOUL.md`, and `AGENTS.md` exist in the OpenClaw workspace without overwriting existing customer edits.
- `AGENTS.md` and `SOUL.md` use the v5 customer templates with installer-time placeholder rendering.
- Installs and enables QMD by default (`OPENCLAW_V7_ENABLE_QMD=1`) using the current OpenClaw `memory.backend=qmd` contract.
- Enables and initializes the official bundled `memory-wiki` plugin by default (`OPENCLAW_V7_ENABLE_MEMORY_WIKI=1`). The plugin is bundled with current OpenClaw but disabled by default, so v7 configures it, creates `~/.openclaw/wiki/main`, and verifies `openclaw wiki status` plus `openclaw wiki doctor`.
- Enables the premium memory slot path with the official `memory-lancedb` plugin when an embedding-capable provider can be resolved. The default install spec is exact-pinned to `npm:@openclaw/memory-lancedb@2026.7.1`. `OPENCLAW_V7_MEMORY_ENGINE=auto` enables LanceDB for `openai-api-key` or an existing OpenAI API auth profile; `OPENCLAW_V7_MEMORY_ENGINE=lancedb` makes missing embedding credentials a hard failure.
- Grants the trusted official `memory-lancedb` plugin the 2026.7.1 `hooks.allowConversationAccess` permission required by its `agent_end` hook, so optional auto-capture is not silently disabled by the new non-bundled-plugin boundary.
- Retains the npm `legacy-peer-deps` retry for older dependency trees. The 2026.7.1 package aligns `apache-arrow` to `18.1.0` with `@lancedb/lancedb@0.30.0`, removing the npm 11 conflict seen in 2026.6.11.
- Keeps QMD + `memory-core` as the safe default for OAuth-only `openai-codex` browser/device login because OpenAI Codex/ChatGPT OAuth is not an OpenAI Platform embeddings credential.
- Enables the built-in OpenClaw 2026.7.1 Skill Workshop workflow by default (`OPENCLAW_V7_ENABLE_SKILL_WORKSHOP=1`). v7 removes stale `plugins.entries.skill-workshop` config, writes only valid `skills.workshop` settings, and leaves proposal approval in the default pending mode unless `OPENCLAW_V7_SKILL_WORKSHOP_APPROVAL_POLICY=auto` is explicitly set.
- Installs and enables the official Codex harness plugin in `auto` mode by resolving `OPENCLAW_V7_CODEX_INSTALL_SPEC=auto` to `npm:@openclaw/codex@<installed-openclaw-version>`. Stable isolated tests showed that the ClawHub archive reaches install completion but fails runtime registration at OpenClaw's trusted keyed-store boundary; the official npm package loads with an empty diagnostics array. The host and harness remain exact-aligned, and mismatched installs are removed and reinstalled.
- Installs `@openai/codex@0.144.3` under the user prefix and sets `plugins.entries.codex.config.appServer.command` to that exact CLI. This matches the dependency declared by `@openclaw/codex@2026.7.1` and keeps the `gpt-5.6-sol` app-server path deterministic.
- Enables Codex-native plugins and Codex Computer Use only when Codex harness is enabled. On macOS, v7 uses the Codex Desktop bundled marketplace at `/Applications/Codex.app/Contents/Resources/plugins/openai-bundled/.agents/plugins/marketplace.json`; if it is missing, the installer installs/updates `codex-app` with Homebrew.
- Sets the premium agent defaults: model `openai/gpt-5.6-sol`, thinking `xhigh`, reasoning `stream`, per-model fast mode on, message queue mode `steer`, block streaming on, and larger bootstrap limits (`bootstrapMaxChars=200000`, `bootstrapTotalMaxChars=400000`) so v5-style customer knowledge files are not silently truncated.
- When Telegram is configured, defaults its preview streaming to `progress` with tool progress enabled and summarized command status. Telegram block delivery is disabled so it cannot suppress the progress preview. Standard Telegram HTML formatting remains available, while advanced `richMessages` stays off for broad client compatibility. Installations without a Telegram channel are left untouched.
- Enables full tool policy, gateway exec, `security=full`, `ask=off`, elevated default `full`, agent-to-agent tools, tool search, and live web search.
- Configures image generation by default with Google/Gemini auth injection. The current E2E-proven default is `google/gemini-3-pro-image-preview`, with `google/gemini-3.1-flash-image-preview` and `openai/gpt-image-2` as fallbacks.
- Uses `openclaw gateway status --require-rpc`, `openclaw health`, `openclaw doctor`, and `openclaw agent` for verification.
- Prompts for a Gemini API key during interactive installs when no Google/Gemini auth profile, secret file, or `GEMINI_API_KEY`/`GOOGLE_API_KEY` env value is already available.
- Stores the gateway token through the `OPENCLAW_GATEWAY_TOKEN` SecretRef env path. If an interrupted or older install left the gateway token in keychain/file/plaintext form, v7 reads it without printing it, rewrites `gateway.auth.token` to the env SecretRef, persists that env for LaunchAgent and shells, and restarts the gateway.
- Migrates known plaintext secret-bearing config, legacy auth-profile JSON, and current sqlite auth-store fields to file SecretRefs. For `agents/*/agent/models.json`, v7 moves literal provider keys into SecretRef-backed auth profiles, then leaves only OpenClaw's non-secret `secretref-managed` marker in `models.json`. `openclaw secrets audit --json` is the release gate. OAuth legacy residue is allowed because browser/OAuth token stores are not static config plaintext fields.
- Preserves modern provider runtime overrides such as Z.AI `models.providers.zai.baseUrl`/`api`/`models` created by `openclaw onboard --auth-choice zai-api-key`; only stale provider stubs with model rows and no runtime override or real auth are removed.
- Runs prompt-smoke auth preflight only after config repair, SecretRef migration, and gateway restart; it checks both modern `models status` effective auth and legacy auth-profile JSON.
- Treats a synthetic Codex app-server route as runtime availability, not proof of account authentication. Interactive reuse is offered only when the default model provider has direct credentials or the configured Codex CLI reports a successful login; an unrelated provider key cannot skip the OpenAI login step.
- Detects existing 2026.7.1 SQLite auth profiles through `openclaw models status --json` before interactive onboarding, while retaining legacy `auth-profiles.json` detection as a fallback. Rerunning the installer therefore preserves an existing login without reopening the auth menu.
- Retains a narrowly defined repair for migrated hosts that still have a pending local CLI scope upgrade before prompt smoke. It auto-approves only a single pending Darwin `cli`/`operator` request for `operator.write` and `operator.admin` when that exact device is already paired; other devices, roles, platforms, or unknown scopes are never approved automatically.
- Normalizes Telegram DM access: with `OPENCLAW_V7_CHAT_ID`, v7 writes a numeric allowlist. In interactive installs, if a bot token exists but no allowlist is present, v7 asks the user to send a one-time code to the bot, polls both OpenClaw's `credentials/telegram-pairing.json` store and Telegram `getUpdates`, captures the numeric user ID, and writes the allowlist automatically. If that cannot complete, it disables Telegram rather than leaving an open/pairing-only channel that makes `openclaw doctor` fail with warnings.
- Prints only masked secret metadata such as length and short fingerprints.
- When prompt smoke is enabled, stops with a clear login-required message if no auth profile exists after onboarding.

## Operator E2E

Use the private harness from the repo, not the public gist:

```bash
E2E_ALLOW_DESTRUCTIVE=1 \
AUTH_CHOICE=openai-api-key \
AUTH_SECRET_ENV=OPENAI_API_KEY \
GEMINI_SECRET_ENV=GEMINI_API_KEY \
INSTALLER_URL=https://gist.githubusercontent.com/VictorJeon/d5a5759cd69f9ed73e087512f7af65d8/raw/openclaw-setup-v7.sh \
INSTALLER_SHA256=f80e67e30b1f960029156f56cea0c458258ab4205318ac85e5e94e4e2049922c \
RUN_PROMPT_SMOKE=1 \
RUN_IMAGE_SMOKE=1 \
installer/scripts/openclaw-v7-e2e-harness.sh e2e
```

The harness preserves SSH on `yongwon@100.123.92.57` and refuses to reset `~/.ssh`, Remote Login, network settings, or Tailscale.
For URL installs it appends a cache-busting query before download. Set `INSTALLER_SHA256` to make the remote download fail closed if a stale Gist raw revision is returned.

Required automated pass criteria:

- `openclaw --version` contains exact version `2026.7.1`.
- `openclaw gateway status --require-rpc` reports a running loopback gateway with RPC access.
- `openclaw health --json` returns `"ok": true`.
- Active memory slot verification succeeds. For `memory-lancedb`, that means `openclaw plugins inspect memory-lancedb --runtime --json` and `openclaw ltm stats`.
- `openclaw plugins inspect memory-wiki`, `openclaw wiki status --json`, and `openclaw wiki doctor --json` succeed.
- With `AUTH_CHOICE=openai-api-key` and default `OPENCLAW_V7_MEMORY_ENGINE=auto`, `plugins.slots.memory` is `memory-lancedb`, `openclaw plugins inspect memory-lancedb --runtime --json` succeeds, and `openclaw ltm stats` succeeds.
- `openclaw skills workshop --help` and `openclaw skills workshop list` succeed.
- `openclaw config validate` succeeds.
- `openclaw plugins inspect codex --json` succeeds.
- Codex and active `memory-lancedb` plugin versions are exactly `2026.7.1`.
- Codex app-server uses the installer-managed `codex-cli 0.144.3`.
- Codex and active `memory-lancedb` runtime diagnostics are empty; `memory-lancedb` reports `policy.allowConversationAccess=true`.
- `openclaw models list --all --provider openai --json` contains `openai/gpt-5.6-sol`.
- Codex Computer Use config points at the local Codex Desktop marketplace path and prompt smoke does not fail before thread start.
- Workspace docs exist: `MEMORY.md`, `PROJECT-STATE.md`, `BOOT.md`, `SOUL.md`, `AGENTS.md`, and `memory/`.
- The official skill surface is visible through `openclaw skills list`.
- `openclaw secrets audit --json` has no disallowed plaintext findings. `LEGACY_RESIDUE` is allowed for OAuth profiles only.
- `openclaw doctor --lint --json --severity-min warning` returns `{"ok":true,...,"findings":[]}`.
- `openclaw agent --agent main --session-key agent:main:installer-v7-smoke --message ... --json` returns a valid model answer.
- `openclaw infer image generate --model google/gemini-3-pro-image-preview --json ...` returns at least one generated image output.

Stable 2026.7.1 validation status:

- Exact npm package metadata, CLI command surfaces, Node engine ranges, Codex peer/dependency metadata, and isolated npm plugin runtime registration were checked on 2026-07-22.
- Local syntax, contract, full dry-run, generated config-schema, exact Codex CLI, and isolated plugin runtime checks passed on macOS Bash 3.2 with Node `22.22.3`.
- Remote beta-to-stable upgrade passed on `ben@100.70.89.126` (`benui-Macmini.local`, macOS `26.4`, arm64, Node `26.5.0`). Core and Gateway reported exact `2026.7.1`; Codex and `memory-lancedb` were replaced from ClawHub beta installs with npm `2026.7.1`, both loaded with zero diagnostics.
- Gateway RPC, health, QMD/LanceDB, memory-wiki, Skill Workshop, config validation, model catalogs, secrets audit, and doctor lint passed. The default model was `openai/gpt-5.6-sol`.
- A real Codex-harness prompt completed with provider `openai`, model `gpt-5.6-sol`, and response `1+1은 2예요.`. Image smoke was not run in this stable upgrade.
- A clean `nova` run preserved SSH and confirmed the stable Node floor rejects its Node `24.13.0`, but could not download the Node upgrade because that host had no outbound access to npm, GitHub, GHCR, or nodejs.org. This is recorded as an environment gate, not a stable installer pass.

Historical credential-backed 2026.7.1-beta.2 evidence:

- Remote: `ben@100.70.89.126`, host `benui-Macmini.local`, macOS `26.4`, arm64, Node `26.5.0`.
- Installer completed with `Status: OK`; Gateway RPC, health, config, memory, wiki, skills, plugin, model catalog, secrets audit, and doctor lint all passed.
- Gateway and CLI both reported exact `2026.7.1-beta.2`; Telegram was enabled, connected, and running without a channel error.
- Real prompt smoke completed through the Codex harness with provider `openai`, model `gpt-5.6-sol`, and response `1+1은 2입니다.`.
- The initial 2026.7.1 local CLI scope-upgrade request was approved only after matching it to the already-paired local CLI device. The final rerun had no pending scope upgrade.

Historical automated 2026.7.1-beta.2 remote E2E evidence:

- Remote: `nova`, host `Nova`, macOS `26.2`, arm64, Node `24.13.0`.
- Public Gist download SHA-256 verified before execution: `af0e3dd940d82344d7ecabf35fff3eac465415421ba751ca6ad413a2585b6771`.
- Installed OpenClaw: exact `2026.7.1-beta.2`; default model `openai/gpt-5.6-sol` was present in the OpenAI catalog.
- Codex and `memory-lancedb`: exact `2026.7.1-beta.2`; both runtime diagnostics arrays were empty.
- `memory-lancedb`: `policy.allowConversationAccess=true`, active memory slot verified, and `openclaw ltm stats` succeeded.
- Gateway RPC, health, config validation, memory-wiki, Skill Workshop, workspace files, and secrets audit passed.
- Doctor result: `{"ok":true,"checksRun":25,"checksSkipped":21,"findings":[]}`.
- Local evidence: `.omx/ultragoal/evidence/e2e-nova-20260711/install-20260711T011646Z.txt` and `.omx/ultragoal/evidence/e2e-nova-20260711/verify-20260711T011851Z.txt`.
- Prompt and image smoke were intentionally skipped because no test credentials were staged; this run does not claim browser/OAuth or real inference validation.

Latest full v7 E2E evidence before the 2026.6.11 refresh:

- Install/verify log: `/Users/pitt/.openclaw/logs/setup-v7-20260602T034820Z.log`
- Remote: `pitt@100.75.14.87`, host `pittui-Macmini.local`, macOS `26.2`, arm64.
- Installed OpenClaw: `2026.6.8`.
- Codex harness: enabled and verified by `codex-plugin: pass`.
- Prompt smoke: Codex harness `openai-codex` provider, `gpt-5.5`, visible answer `1+1은 2입니다.`
- Image smoke: skipped in this run.
- Security gates: `openclaw doctor --lint --json --severity-min warning` returned `{"ok":true,...,"findings":[]}`; secrets audit had zero disallowed findings.

## Final Manual Login Gate

Automated credential-injection E2E is not a substitute for the customer login UX. Before declaring the release fully complete, reset the test Mac to a clean OpenClaw state, run the public v7 gist interactively, complete the browser/OAuth login by hand, then rerun the same health, doctor, and prompt-smoke checks.

If device/browser authorization is canceled or not completed, the installer must stop before prompt smoke with a clear login-required message.

For the final manual OAuth login gate, the expected premium baseline is QMD + memory-wiki + skill-workshop + Codex harness when the installed OpenClaw supports it + Codex Computer Use marketplace when harness is enabled + full/elevated premium defaults + v5 workspace templates. LanceDB should not be forced unless an embedding-capable provider is also supplied, because OAuth-only OpenAI Codex/ChatGPT auth cannot back OpenAI embeddings.

Operator flow:

```bash
E2E_ALLOW_DESTRUCTIVE=1 installer/scripts/openclaw-v7-e2e-harness.sh reset
installer/scripts/openclaw-v7-e2e-harness.sh manual-login
installer/scripts/openclaw-v7-e2e-harness.sh final-verify
```

`manual-login` opens the real public v7 gist installer and waits for the browser/device login. `final-verify` runs the post-login gateway, health, doctor, and real prompt checks with prompt smoke enabled.

## Official Docs Checked

- `memory-lancedb`: official external memory plugin, installed before selecting `plugins.slots.memory = "memory-lancedb"`; only one plugin owns the active memory slot, while companion plugins such as `memory-wiki` can run beside it.
- `memory-lancedb`: provider-backed embeddings can use configured provider auth, but OpenAI Codex / ChatGPT OAuth is not an OpenAI Platform embeddings credential.
- `skill-workshop`: in OpenClaw 2026.7.1 this is a built-in skills workflow, not an installable plugin. The valid config surface is `skills.workshop`, and pending proposal approval is the recommended starting mode.
- `openclaw update` guidance: manual npm package replacement should stop the managed gateway first; optional native dependency install failures can be retried with optional dependencies omitted.
- OpenClaw 2026.7.1 release notes and package metadata: GPT-5.6 model-family support spans setup, catalog, capability, and runtime selection; Node 23 is rejected and patched Node floors are required for SQLite WAL safety; doctor and plugin diagnostics are stricter.
- `codex-harness`: official Codex app-server harness; new configs use canonical `openai/gpt-*` model refs.
- `codex-computer-use`: Computer Use requires Codex-native plugin support plus an installable local marketplace; on macOS this is the Codex Desktop bundled `openai-bundled` marketplace.
- `tools/image-generation` and `providers/google`: Gemini image generation is supported; current E2E uses `google/gemini-3-pro-image-preview` because it returned real image output with the staged Gemini key.
- `tools/elevated`, `tools/exec-approvals`, `gateway/config-tools`: premium mode intentionally enables full gateway exec, `ask=off`, elevated `full`, and YOLO exec approvals.
- `concepts/messages`: premium message queue default is `steer`.
- `tools/thinking` and `gateway/config-agents`: premium thinking default is `xhigh`, reasoning default is `stream`, and fast mode is configured per `openai/gpt-5.6-sol`.
- `channels/telegram` and `concepts/streaming`: Telegram uses `streaming.mode=progress`, `progress.toolProgress=true`, `progress.commandText=status`, `streaming.block.enabled=false`, and `richMessages=false` by default when the channel exists.
- `plugins/manage-plugins`: install/update/inspect flow and `inspect --runtime` are the verification path for plugin runtime registrations.
- `memory-qmd`: QMD remains the local-first sidecar and fallback memory path.
