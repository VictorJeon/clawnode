-- Memory V3 base schema
-- Run BEFORE 003_memories.sql
--
-- Purpose:
--   Provision the pre-V3 chunk search schema that 003+ migrations assume.
--
-- Validated against:
--   Homebrew postgresql@16
--   Database: memory_v2

BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

-- ── memory_documents ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS memory_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    namespace TEXT NOT NULL,
    source_type TEXT NOT NULL,
    source_path TEXT,
    source_hash TEXT NOT NULL,
    title TEXT,
    tags TEXT[] DEFAULT '{}'::text[],
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (namespace, source_path, source_hash)
);

CREATE INDEX IF NOT EXISTS idx_docs_namespace
    ON memory_documents (namespace);

-- ── memory_chunks ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS memory_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES memory_documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    token_count INTEGER NOT NULL,
    embedding VECTOR(1024) NOT NULL,
    content_tsv TSVECTOR GENERATED ALWAYS AS (to_tsvector('simple', content)) STORED,
    created_at TIMESTAMPTZ DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'active',
    status_confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    decided_at TIMESTAMPTZ,
    source_date DATE,
    UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_chunks_document
    ON memory_chunks (document_id);

-- Standardize on a single HNSW index. The live dev DB currently has a duplicate
-- embedding index; setup V2 should not recreate both.
CREATE INDEX IF NOT EXISTS idx_chunks_embedding
    ON memory_chunks USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_chunks_source_date
    ON memory_chunks (source_date);

CREATE INDEX IF NOT EXISTS idx_chunks_status
    ON memory_chunks (status);

CREATE INDEX IF NOT EXISTS idx_chunks_tsv
    ON memory_chunks USING gin (content_tsv);

COMMIT;
