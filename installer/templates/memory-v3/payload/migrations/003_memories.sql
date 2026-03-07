-- Memory V3: Atomic Memories + Temporal Versioning
-- Migration 003: memories, memory_relations, pending_atomize, project_snapshots
--
-- Run on Mac Mini:
--   /opt/homebrew/Cellar/postgresql@16/16.12/bin/psql -d memory_v2 -f migrations/003_memories.sql

BEGIN;

-- ── memories ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Content
    fact TEXT NOT NULL,
    context TEXT,
    source_content_hash TEXT,       -- sha256[:16] of chunk content for re-link

    -- Source
    source_chunk_id UUID REFERENCES memory_chunks(id) ON DELETE SET NULL,
    source_path TEXT,                -- denorm: survives chunk deletion

    -- Temporal
    created_at TIMESTAMPTZ DEFAULT now(),
    event_date DATE,
    event_at TIMESTAMPTZ,            -- same-day ordering of corrections
    document_date DATE,

    -- Status
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'superseded', 'retracted')),
    superseded_by UUID REFERENCES memories(id),
    retracted_reason TEXT,

    -- Embedding
    embedding vector(1024) NOT NULL,

    -- Metadata
    entity TEXT,
    category TEXT CHECK (category IN ('factual', 'decision', 'metric', 'lesson', 'state')),
    confidence FLOAT DEFAULT 0.8 CHECK (confidence >= 0 AND confidence <= 1),

    -- Namespace
    namespace TEXT NOT NULL DEFAULT 'global'
);

CREATE INDEX IF NOT EXISTS idx_memories_active
    ON memories (namespace, status, category, event_date DESC)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_memories_embedding
    ON memories USING hnsw (embedding vector_cosine_ops)
    WITH (m=16, ef_construction=64);

CREATE INDEX IF NOT EXISTS idx_memories_entity
    ON memories (entity) WHERE entity IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_memories_event_date
    ON memories (event_date DESC);

CREATE INDEX IF NOT EXISTS idx_memories_superseded_by
    ON memories (superseded_by) WHERE superseded_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_memories_source_chunk
    ON memories (source_chunk_id) WHERE source_chunk_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_memories_namespace
    ON memories (namespace);

CREATE INDEX IF NOT EXISTS idx_memories_source_hash
    ON memories (source_content_hash) WHERE source_content_hash IS NOT NULL;


-- ── memory_relations (audit trail) ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS memory_relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
    relation_type TEXT NOT NULL
        CHECK (relation_type IN ('updates', 'extends', 'derives', 'contradicts')),
    status TEXT NOT NULL DEFAULT 'confirmed'
        CHECK (status IN ('pending', 'confirmed', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (source_id, target_id, relation_type),
    CHECK (source_id != target_id)
);

CREATE INDEX IF NOT EXISTS idx_relations_source ON memory_relations (source_id);
CREATE INDEX IF NOT EXISTS idx_relations_target ON memory_relations (target_id);
CREATE INDEX IF NOT EXISTS idx_relations_pending
    ON memory_relations (status) WHERE status = 'pending';


-- ── pending_atomize (async work queue) ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS pending_atomize (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id UUID NOT NULL REFERENCES memory_chunks(id) ON DELETE CASCADE,
    chunk_content TEXT NOT NULL,
    source_path TEXT,
    source_date DATE,
    namespace TEXT NOT NULL DEFAULT 'global',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'done', 'failed')),
    attempts INT DEFAULT 0,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    processed_at TIMESTAMPTZ,
    UNIQUE (chunk_id)
);

CREATE INDEX IF NOT EXISTS idx_pending_status
    ON pending_atomize (status, created_at) WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_pending_processing
    ON pending_atomize (status) WHERE status = 'processing';


-- ── project_snapshots ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS project_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_name TEXT NOT NULL,
    snapshot_date DATE NOT NULL,
    summary TEXT NOT NULL,
    key_facts JSONB,
    embedding vector(1024) NOT NULL,
    namespace TEXT NOT NULL DEFAULT 'global',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (project_name, snapshot_date, namespace)
);

CREATE INDEX IF NOT EXISTS idx_snapshots_embedding
    ON project_snapshots USING hnsw (embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS idx_snapshots_project
    ON project_snapshots (project_name, snapshot_date DESC);


-- ── Backfill: enqueue all existing chunks ─────────────────────────────────────
-- Inserts all current chunks into pending_atomize (ON CONFLICT DO NOTHING = idempotent).
INSERT INTO pending_atomize (chunk_id, chunk_content, source_path, source_date, namespace)
SELECT
    c.id,
    c.content,
    d.source_path,
    c.source_date,
    d.namespace
FROM memory_chunks c
JOIN memory_documents d ON c.document_id = d.id
ON CONFLICT (chunk_id) DO NOTHING;

COMMIT;

-- Verify
SELECT
    'memories'        AS tbl, count(*) FROM memories
UNION ALL SELECT
    'memory_relations', count(*) FROM memory_relations
UNION ALL SELECT
    'pending_atomize',  count(*) FROM pending_atomize
UNION ALL SELECT
    'project_snapshots', count(*) FROM project_snapshots;
