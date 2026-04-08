-- Add is_free flag to suggestion_packs.
-- TRUE (default) = available to all users. FALSE = Pro subscribers only.
ALTER TABLE suggestion_packs ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT TRUE;
