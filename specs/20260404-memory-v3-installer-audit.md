# 2026-04-04 — Memory V3 installer baseline audit

## Goal

Make fresh ClawNode V4 installs ship the current Memory V3 baseline fixes.

Scope is limited to **installer-managed assets**:
- `installer/scripts/openclaw-setup-v4.sh`
- `installer/templates/memory-v3/extension/*`
- `installer/templates/memory-v3/payload/*`

Out of scope:
- Nana-only recovery hacks
- host-local path rewrites
- OpenClaw upgrade to `2026.3.31`

## Installer wiring map

`installer/scripts/openclaw-setup-v4.sh` deploys these assets into the live runtime:

- `installer/templates/memory-v3/extension/` → `~/.openclaw/extensions/memory-v3`
- `installer/templates/memory-v3/payload/` → `~/.openclaw/services/memory-v2`
- it also patches `openclaw.json` to enable `plugins.memory-v3`
- it already enforces `exec-approvals.json` defaults/security

## Baseline comparison targets

Live fixed baselines used for comparison:
- plugin baseline: `~/.openclaw/extensions/memory-v3/index.ts`
- sidecar baseline: `/Users/nova/.openclaw/workspace-nova/services/memory-v2/*`

## Findings by requirement

### 1) Plugin compatibility / direct registration baseline

Target file:
- `installer/templates/memory-v3/extension/index.ts`

Status: **missing / outdated**

Observed in installer template:
- still references `createMemoryGetTool`
- still references `registerMemoryCli`
- missing `registerMemoryPromptSection`
- missing `before_prompt_build`
- missing `selectInjectedMemories`
- missing `isLowValueAtomicMemory`

Observed in live fixed plugin baseline:
- no `createMemoryGetTool`
- no `registerMemoryCli`
- has direct `memory_get` registration
- has `registerMemoryPromptSection`
- uses `before_prompt_build`
- includes injection-quality gating helpers

### 2) Exact get endpoint (`/v1/memory/get`)

Target file:
- `installer/templates/memory-v3/payload/server.py`

Status: **missing**

Observed in installer template:
- no `/v1/memory/get`
- no `get_snapshot_by_id`
- no `get_memory_by_id`
- no `get_chunk_by_id`

Observed in live sidecar baseline:
- `/v1/memory/get` exists
- direct exact-lookup helpers are imported and used

### 3) fact_ko backfill hardening / token-preservation fallback

Target file:
- `installer/templates/memory-v3/payload/backfill_fact_ko.py`

Status: **missing / outdated**

Observed in installer template:
- no token masking / preservation handling
- no fallback wording/signatures found
- no single-row fallback markers found

Observed in live sidecar baseline:
- token preservation logic present
- fallback logic present
- single-row fallback present

### 4) Source-side junk suppression

Target files:
- `installer/templates/memory-v3/payload/atomizer.py`
- `installer/templates/memory-v3/payload/llm_atomizer.py`

Status: **missing / outdated**

Observed in installer template:
- no suppression markers in `atomizer.py`
- `llm_atomizer.py` still has conversational content handling but not the newer suppression logic

Observed in live sidecar baseline:
- suppression logic/signatures present in both files

### 5) Retrieval relevance tightening

Target file:
- `installer/templates/memory-v3/payload/search_engine.py`

Status: **needs sync**

Observed in installer template:
- has degraded/source-gate machinery
- but differs from live sidecar baseline
- still lacks the latest raw-noise / ranking changes from the live baseline

Observed in live sidecar baseline:
- file differs from installer template
- contains newer raw/result shaping behavior

### 6) `exec-approvals.json` behavior

Target file:
- `installer/scripts/openclaw-setup-v4.sh`

Status: **already present; preserve**

Required preserved behavior:
- `defaults.security = "full"`
- `defaults.ask = "off"`
- `defaults.askFallback = "full"`
- preserve existing `socket.path`, `socket.token`, `agents`
- generate missing socket/token when absent

## Nana relevance

Nana inspection confirms `git pull` alone is **not** sufficient for the full Memory V3 stack:

- `~/.openclaw/services/memory-v2` is a git worktree on Nana
- `~/.openclaw/extensions/memory-v3` is **not** a git worktree on Nana
- therefore pulling the memory repo can update sidecar code, but will not update the live plugin extension
- Nana also contains host-local operational state that installer baselines must not blindly encode

## Required implementation outcome

Fresh V4 installs should receive:
- the current plugin compatibility baseline
- exact item lookup route
- hardened KO backfill behavior
- source junk suppression
- tighter retrieval behavior
- unchanged exec-approvals defaults logic

Nana-specific repair steps stay out of the installer baseline.
