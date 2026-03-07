# CLAUDE.md — Memory V3

## Project Overview
Memory V3는 OpenClaw의 장기 기억 시스템이다. PostgreSQL + pgvector 기반으로 fact-level atomic memories, relation graph, entity snapshots를 관리한다.

## Architecture
자세한 아키텍처는 `ARCHITECTURE.md` 참조. 핵심 요약:

- **API Server** (`server.py`): FastAPI, `127.0.0.1:18790`
- **Ingest** (`ingest.py`, `session_ingest.py`): 마크다운/세션 → chunks → pending_atomize 큐
- **Tier 1 Worker** (`atomize_worker.py`, `atomizer.py`): 규칙 기반 fact 추출
- **Tier 2 Worker** (`llm_atomize_worker.py`, `llm_atomizer.py`): Gemini Flash LLM 기반 fact 추출
- **Search** (`search_engine.py`): V3 memory-first → V2 chunk fallback
- **Snapshots** (`snapshot_generator.py`): entity별 현재 상태 요약
- **Relations** (`relation_linker.py`): updates/extends/contradicts 관계 링킹
- **DB** (`db.py`): psycopg2 thread pool, CRUD/search
- **Embeddings** (`embeddings.py`): Ollama bge-m3 1024dim (local)
- **Config** (`config.py`): 모든 설정 상수

## Key Data Flow
1. Source files → chunk → embed → `memory_chunks`
2. Chunk → `pending_atomize` queue → Tier1/Tier2 worker → `memories`
3. Worker: extract facts → embed → dedup (cosine ≥ 0.95) → insert → link relations → supersede old
4. Search: query embed → snapshot search → memory vector search (dual: en/ko) → V2 chunk fallback

## Database
- PostgreSQL with pgvector extension
- Connection: `DATABASE_URL` env or default `dbname=memory_v2`
- Migrations in `migrations/` (순번: 003, 004, 005, 다음은 006)
- Tables: `memory_documents`, `memory_chunks`, `memories`, `memory_relations`, `pending_atomize`, `project_snapshots`

## Key Files
| File | Role |
|------|------|
| `config.py` | All constants (thresholds, models, known entities) |
| `db.py` | Database CRUD, dedup queries, search queries |
| `atomize_worker.py` | Tier 1 extraction worker (polls queue) |
| `atomizer.py` | Tier 1 fact extraction logic |
| `llm_atomize_worker.py` | Tier 2 LLM worker |
| `llm_atomizer.py` | Tier 2 LLM extraction logic |
| `search_engine.py` | Search pipeline (V3 memory-first + V2 fallback) |
| `relation_linker.py` | Relation linking (updates/extends/contradicts) |
| `snapshot_generator.py` | Entity snapshot generation |
| `embeddings.py` | Embedding via Ollama bge-m3 |

## Development
- Python 3.12+, psycopg2, FastAPI, uvicorn
- Embedding: local Ollama `bge-m3:latest` at `http://127.0.0.1:11434`
- Tests: pytest (files matching `test_*.py`)
- Git branches for features: `memory-v3/<feature-name>`
- Commit convention: `feat:`, `fix:`, `refactor:`, `test:`

## Current Stats
- ~49,691 memories (~46,873 active)
- ~11,808 relations
- 25 snapshots
- Dual embeddings (en + ko)
