# v5 → v6 Planned Change Summary

> **Status**: Forward-looking / planned diff — `openclaw-setup-v6.sh` does not yet exist.
>
> **Sources**:
> - Baseline: `installer/scripts/openclaw-setup-v5.sh` (1 118 lines, current HEAD)
> - Specification: `PRDs/v6-installer.md`
> - Asset (already committed): `installer/assets/zai_openclaw_sanitize.js`
>
> **Date**: 2026-04-18

---

## Feature 1: Z.AI (GLM-5.1) Coding Plan-Global API Key Support

### Purpose

Enable users to select z.ai as their primary model provider during installation, with proper config schema, auth storage, and Keychain entry.

### Files & Functions — Existing (v5)

| File | Function / Area | Lines | Planned Change |
|------|----------------|-------|----------------|
| `openclaw-setup-v5.sh` | `main()` | L1071-1117 | **Modify** — insert provider selection menu call before `run_core_setup` |
| `openclaw-setup-v5.sh` | `run_core_setup()` | L458-486 | **Modify** — route z.ai selection to `auth_zai()` instead of delegating to core script |
| `openclaw-setup-v5.sh` | `patch_openclaw_config()` (node inline) | L652-735 | **Modify** — conditionally add `models.providers.zai.baseUrl` and `agents.defaults.model.primary` |
| `openclaw-setup-v5.sh` | `configure_optional_google_api_key()` | L900-945 | **Reference only** — pattern template for the new `auth_zai()` prompt flow |

### Files & Functions — New (v6)

| Item | Type | Description |
|------|------|-------------|
| `select_provider()` | New function | Presents `[1] Anthropic  [2] OpenAI  [3] Z.AI  [4] Skip` menu; sets `SELECTED_PROVIDER` variable |
| `auth_zai()` | New function | Prompts for z.ai API key, writes Keychain entry, writes `auth-profiles.json` and `auth.order` |
| `${CONFIG_DIR}/auth-profiles.json` | New config artifact | `{ "zai:default": { "apiKey": "<USER_INPUT>" } }` — provider-keyed auth profile |
| `auth.order` in `openclaw.json` | New config section | `{ "auth": { "order": { "zai": ["zai:default"] } } }` |
| Keychain entry | New system artifact | `security add-generic-password -s "openclaw-zai-api" -a "zai" -w "<KEY>"` |

### Line-Level Change Summary

**Additions** (~80-120 lines estimated):
- `select_provider()` function body (~25 lines): menu display, `read` prompt, case dispatch
- `auth_zai()` function body (~40 lines): API key prompt, Keychain write, `auth-profiles.json` creation, `auth.order` patching
- `main()` call site (~5 lines): call `select_provider` before `run_core_setup`
- `patch_openclaw_config()` node block extension (~15 lines): conditional `models.providers.zai` + `agents.defaults.model.primary` + `auth.order` patching
- New global variables (~5 lines): `SELECTED_PROVIDER`, `ZAI_BASE_URL`, `ZAI_API_KEY`

**Modifications** (~10 lines):
- `run_core_setup()` L470-478: condition on `SELECTED_PROVIDER` to skip core script delegation when z.ai is selected
- `print_hero()` L74-88: update banner text from "V5" to "V6"
- `LOG_FILE` L42: rename `setup-v5-*` → `setup-v6-*`
- `INSTALLER_V5_URL` L46: rename to `INSTALLER_V6_URL`, update gist URL
- `write_clawnode_version_stamp()` L1053-1065: `CHANNEL=v5` → `CHANNEL=v6`
- `render_final_summary()` L193-208: update "V5" references to "V6"

**Deletions**: None.

---

## Feature 2: Sanitizer Preload (Response Rewriting)

### Purpose

Work around z.ai rate limiting that triggers on request bodies containing the literal string "OpenClaw". A Node.js preload script rewrites `"OpenClaw"` → `"Claude Code"` in all outbound z.ai traffic.

### Files & Functions — Existing (v5)

| File | Function / Area | Lines | Planned Change |
|------|----------------|-------|----------------|
| `openclaw-setup-v5.sh` | `restart_openclaw_gateway()` | L796-831 | **Modify** — after plist install, conditionally patch `EnvironmentVariables` dict to add `NODE_OPTIONS` |
| `openclaw-setup-v5.sh` | `patch_gateway_throttle_interval()` | L833-847 | **Reference only** — demonstrates the `PlistBuddy` pattern for gateway plist patching |
| `openclaw-setup-v5.sh` | `LAUNCH_AGENTS_DIR` variable | L41 | Used as-is to locate `ai.openclaw.gateway.plist` |

### Files & Functions — New (v6)

| Item | Type | Description |
|------|------|-------------|
| `install_sanitizer_preload()` | New function | Copies sanitizer JS to `~/.openclaw/scripts/`, patches LaunchAgent plist, restarts gateway |
| `installer/assets/zai_openclaw_sanitize.js` | Existing asset | Source file (152 lines, already committed at `edf7613`). Copied to `${CONFIG_DIR}/scripts/` at install time. |
| `${CONFIG_DIR}/scripts/zai_openclaw_sanitize.js` | New runtime artifact | Deployed copy of the sanitizer preload |
| `ai.openclaw.gateway.plist` `EnvironmentVariables.NODE_OPTIONS` | New plist key | `--require /Users/$USER/.openclaw/scripts/zai_openclaw_sanitize.js` |

### Line-Level Change Summary

**Additions** (~35-50 lines estimated):
- `install_sanitizer_preload()` function body (~30 lines):
  - `mkdir -p "${CONFIG_DIR}/scripts"`
  - `cp` from `installer/assets/` or download from gist
  - `PlistBuddy` commands to add/append `NODE_OPTIONS` in plist `EnvironmentVariables`
  - Conditional activation check: only if `SELECTED_PROVIDER == "zai"`
  - User confirmation prompt: `Install GLM sanitizer preload? [y/N]`
- `main()` call site (~3 lines): call `install_sanitizer_preload` in Post-Wizard stage (after L1098)
- Guard variable (~2 lines): `SANITIZER_INSTALLED=0`

**Modifications** (~5 lines):
- `restart_openclaw_gateway()` L812-815: after `gateway install`, the plist must exist before sanitizer patching — order dependency documented
- `prepare_installer_assets()` L443-452: optionally download sanitizer JS if not found locally (gist fallback)

**Deletions**: None.

---

## Feature 3: Auth Validation Improvement (Provider-Agnostic Auth Flow)

### Purpose

Fix v5's Anthropic-first auth validation bug: when `core_auth_present()` fails (timeout, wrong provider), v5 forces a full core script re-run which presents the Anthropic onboarding screen — even if the user authenticated with Codex or z.ai.

### Files & Functions — Existing (v5)

| File | Function / Area | Lines | Planned Change |
|------|----------------|-------|----------------|
| `openclaw-setup-v5.sh` | `core_auth_present()` — Python block | L338-361 | **Modify** — add `"zai"` to `KNOWN_PROVIDERS` set at L340 |
| `openclaw-setup-v5.sh` | `core_auth_present()` — bash `case` | L367-379 | **Modify** — add `zai)` case with Bearer token validation |
| `openclaw-setup-v5.sh` | `core_auth_present()` — curl timeouts | L370, L373, L376 | **Modify** — `--max-time 8` → `--max-time 15` (all 3 provider cases) |
| `openclaw-setup-v5.sh` | `core_auth_present()` — failure path | L380-381 | **Modify** — wrap validation in 1-retry loop before returning failure |
| `openclaw-setup-v5.sh` | `run_core_setup()` | L470-478 | **Modify** — replace "re-running core setup" with provider selection menu |

### Files & Functions — New (v6)

| Item | Type | Description |
|------|------|-------------|
| `reauth_provider_menu()` | New function | Displayed on auth failure: `[1] Anthropic  [2] OpenAI/Codex  [3] Z.AI  [4] Skip`. Calls provider-specific auth function. Does NOT re-run core script. |

### Line-Level Change Summary

**Additions** (~30-40 lines estimated):
- `reauth_provider_menu()` function body (~20 lines): menu display, case dispatch to `auth_anthropic` / `auth_openai` / `auth_zai` / skip
- `zai)` case in `core_auth_present()` bash block (~3 lines): `curl -fsS --max-time 15 -H "Authorization: Bearer ${secret}" "${zai_base_url}/models"`
- Retry wrapper (~8 lines): loop around the provider `case` block with 1 retry on consecutive failure

**Modifications** (~10 lines):
- `core_auth_present()` L340: `KNOWN_PROVIDERS` set — add `"zai"` to the Python set literal
- `core_auth_present()` L370: `--max-time 8` → `--max-time 15` (anthropic case)
- `core_auth_present()` L373: `--max-time 8` → `--max-time 15` (openai case)
- `core_auth_present()` L376: `--max-time 8` → `--max-time 15` (google/gemini case)
- `run_core_setup()` L476-477: replace `warn "existing core found but auth invalid — re-running core setup."` + fall-through with call to `reauth_provider_menu()`

**Deletions** (~2 lines):
- `run_core_setup()` L476-477: the unconditional fall-through to core re-run is removed (replaced by `reauth_provider_menu()` call)

---

## Categorized Change Summary

### Existing in v5 (unchanged)

These v5 components are not affected by v6:

- Tailscale integration (`tailscale_ip()`)
- QMD installation & `--glob` compat patch (`install_qmd()`, `patch_qmd_glob_compat()`)
- Workspace bootstrap (`bootstrap_workspace_memory()`, `ensure_boot_md()`)
- Memory-core / dreaming / wiki config sections within `patch_openclaw_config()`
- Bundled hooks (`enable_bundled_hooks()`)
- Wiki vault init (`init_wiki_vault()`)
- Exec-approvals security (`ensure_exec_approvals_security()`)
- V3 service cleanup (`cleanup_v3_services()`)
- Gateway health check (`health_check_memory()`)
- Utility functions: `dry()`, `resolve_openclaw_bin()`, `gateway_health_ok()`, `wait_for_gateway_health()`, `start_gateway_manual_fallback()`, `config_json_value()`, `download_to_file()`, `load_existing_identity()`
- DRY_RUN / SKIP_CORE_SETUP / FORCE_CORE_SETUP / MEMORY_ONLY control flow

### New in v6

| Item | Type |
|------|------|
| `select_provider()` function | Shell function |
| `auth_zai()` function | Shell function |
| `reauth_provider_menu()` function | Shell function |
| `install_sanitizer_preload()` function | Shell function |
| `SELECTED_PROVIDER` / `ZAI_BASE_URL` / `ZAI_API_KEY` global variables | Variables |
| `${CONFIG_DIR}/auth-profiles.json` (z.ai entry) | Config file |
| `auth.order` provider-keyed section in `openclaw.json` | Config section |
| `${CONFIG_DIR}/scripts/zai_openclaw_sanitize.js` | Runtime asset |
| `ai.openclaw.gateway.plist` `EnvironmentVariables.NODE_OPTIONS` | Plist key |
| Keychain entry `openclaw-zai-api` | System credential |
| `installer/assets/zai_openclaw_sanitize.js` | Repo asset (already committed) |

### Behavior Changes

| Behavior | v5 | v6 |
|----------|----|----|
| Provider selection at install time | Delegated entirely to core script (`openclaw-setup.sh`) | Explicit `[1-4]` menu in v6 script before core setup |
| Auth failure recovery | Full core script re-run → Anthropic onboarding forced | Provider selection menu → auth-only patch (no core re-run) |
| Auth validation providers | `anthropic`, `openai`, `google`, `gemini`, `openai-codex` | + `zai` |
| Auth validation timeout | 8 seconds per provider | 15 seconds per provider |
| Auth validation retry | None (single attempt) | 1 retry on consecutive failure |
| Sanitizer preload | N/A | Conditional `NODE_OPTIONS --require` in LaunchAgent plist |
| Version channel stamp | `CHANNEL=v5` | `CHANNEL=v6` |

### Open Implementation Assumptions

1. **Provider menu placement**: The plan assumes `select_provider()` runs before `run_core_setup()` in `main()`. If z.ai is selected, `run_core_setup()` should skip the core script delegation and use `auth_zai()` directly. The exact skip mechanism (env var vs. return code) needs to be decided during implementation.

2. **`auth-profiles.json` coexistence**: v5's `core_auth_present()` reads from `${CONFIG_DIR}/agents/*/main/agent/auth-profiles.json` (L332). The v6 z.ai entry targets `${CONFIG_DIR}/auth-profiles.json` (top-level). It is unclear whether `core_auth_present()` should also search the top-level path, or whether the z.ai entry should be written to the agent-scoped path instead.

3. **Sanitizer auto-enable vs. opt-in**: The PRD shows `Install GLM sanitizer preload? [y/N]` as opt-in. An alternative is auto-enabling when z.ai is selected with an opt-out. The current plan follows the PRD (opt-in with recommendation).

4. **`NODE_OPTIONS` append behavior**: If the user already has `NODE_OPTIONS` set in the plist (e.g., custom `--require` or `--max-old-space-size`), the sanitizer `--require` must be appended, not overwrite. The exact PlistBuddy read-modify-write sequence needs testing.

5. **Existing Anthropic/OpenAI auth functions**: The PRD references `auth_anthropic()` and `auth_openai()` in `reauth_provider_menu()`, but these do not exist as standalone functions in v5. They would need to be extracted from the core script or implemented fresh in v6.

---

## Follow-up Items for Gist Publishing

1. **Revalidate after v6 script creation**: Once `openclaw-setup-v6.sh` is implemented, regenerate this document as an actual `diff` (not planned). Run `diff -u openclaw-setup-v5.sh openclaw-setup-v6.sh` and update line references to match the final file.

2. **Gist file manifest**: The published gist should include:
   - `openclaw-setup-v6.sh` (the installer script)
   - `zai_openclaw_sanitize.js` (the sanitizer preload asset)
   - `v6-diff-summary.md` (this document, updated with final line numbers)

3. **Gist URL update**: After publishing, update `GIST_BASE_URL` in the v6 script header (currently points to the v5 gist at `5276afd04d974985537a1ceb7e100e9f`). A new gist or gist revision is needed.

4. **`INSTALLER_V6_URL` variable**: The v6 script should reference its own gist URL for self-update scenarios. This variable replaces `INSTALLER_V5_URL` (v5 L46).

5. **ShellCheck validation**: Run `shellcheck openclaw-setup-v6.sh` before gist publish. The v5 script should already pass; confirm v6 additions do not introduce warnings.

6. **Resolve open assumptions**: Items in the "Open Implementation Assumptions" section above must be resolved during v6 implementation and the final version of this document updated accordingly.
