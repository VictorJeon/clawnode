# CLAUDE.md

This repository contains ClawNode product code and installer flows.

## Current task focus
- macOS installer / V4 installer flow only
- prioritize non-technical customer UX
- avoid unrelated changes outside installer scripts unless required by the task

## When editing installer scripts
- preserve idempotency and restart safety
- keep prompts simple and explicit
- prefer concrete shell validation over assumptions
- do not regress prior fixes around OpenRouter/Ollama enrichment backend selection
- Gemini API key in V4 is for image generation / media understanding, not enrichment

## Validation
- run shell syntax checks on modified scripts
- prove relevant branches/functions are reachable
- summarize exact files changed and any follow-up for gist publishing
