-- Migration 005_bilingual_facts.sql
-- Adds bilingual fact storage for Korean query support (Phase 2.1)
--
-- fact_ko   : Korean translation of fact (for Korean embedding)
-- embedding_ko : Korean vector embedding (1024-dim bge-m3)
--
-- NOTE: HNSW index on embedding_ko is intentionally NOT created here.
--       Building HNSW over 47K NULL rows is wasteful.
--       After backfill_fact_ko.py completes, create the index manually:
--
--   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_memories_embedding_ko
--     ON memories USING hnsw (embedding_ko vector_cosine_ops)
--     WITH (m = 16, ef_construction = 64)
--     WHERE embedding_ko IS NOT NULL;

BEGIN;

ALTER TABLE memories ADD COLUMN IF NOT EXISTS fact_ko TEXT;
ALTER TABLE memories ADD COLUMN IF NOT EXISTS embedding_ko vector(1024);

COMMIT;
