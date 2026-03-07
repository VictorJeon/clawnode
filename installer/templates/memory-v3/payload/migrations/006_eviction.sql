-- Migration 006_eviction.sql
-- Adds 'archived' status for evicted memories.
--
-- Eviction: status='active' AND hit_count=0 AND created_at < now() - EVICTION_AGE_DAYS
-- Archived memories are excluded from vector_search_memories() automatically
-- (it filters WHERE status = 'active' by default).
--
-- Run:
--   psql -d memory_v2 -f migrations/006_eviction.sql

BEGIN;

-- Extend status check constraint to include 'archived'
ALTER TABLE memories DROP CONSTRAINT IF EXISTS memories_status_check;
ALTER TABLE memories ADD CONSTRAINT memories_status_check
  CHECK (status = ANY(ARRAY['active','pending','superseded','retracted','archived']));

-- Partial index for efficient eviction candidate scans
-- Covers: WHERE status = 'active' AND hit_count = 0
CREATE INDEX IF NOT EXISTS idx_memories_eviction
  ON memories (created_at)
  WHERE status = 'active' AND hit_count = 0;

COMMIT;

-- Verify constraint
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'memories'::regclass AND conname = 'memories_status_check';
