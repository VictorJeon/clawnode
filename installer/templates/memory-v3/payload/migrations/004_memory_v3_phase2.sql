-- Memory V3 Phase 2 migration
-- Run AFTER stopping writer LaunchAgents

BEGIN;

-- Feature 2: Decay columns
ALTER TABLE memories ADD COLUMN IF NOT EXISTS hit_count INT NOT NULL DEFAULT 0;
ALTER TABLE memories ADD COLUMN IF NOT EXISTS last_hit_at TIMESTAMPTZ;

-- Feature 4b: Pending status
ALTER TABLE memories DROP CONSTRAINT IF EXISTS memories_status_check;
ALTER TABLE memories ADD CONSTRAINT memories_status_check
  CHECK (status = ANY(ARRAY['active','pending','superseded','retracted']));

COMMIT;
