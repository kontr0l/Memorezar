-- Create flags table for recording moderation
CREATE TABLE IF NOT EXISTS flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    reason TEXT,
    status TEXT DEFAULT 'pending',  -- 'pending', 'reviewed', 'dismissed'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for quick lookup of unreviewed flags
CREATE INDEX IF NOT EXISTS flags_status_idx ON flags (status) WHERE status = 'pending';
-- Index for looking up flags by recording
CREATE INDEX IF NOT EXISTS flags_recording_id_idx ON flags (recording_id);

-- RLS
ALTER TABLE flags ENABLE ROW LEVEL SECURITY;

-- Anyone can create a flag
CREATE POLICY "Anyone can insert flags" ON flags FOR INSERT WITH CHECK (true);
-- Anyone can read flags (admin needs this)
CREATE POLICY "Anyone can read flags" ON flags FOR SELECT USING (true);
-- Only authenticated users can update flags (admin review)
CREATE POLICY "Auth users can update flags" ON flags FOR UPDATE USING (auth.role() = 'authenticated');
-- Only authenticated users can delete flags
CREATE POLICY "Auth users can delete flags" ON flags FOR DELETE USING (auth.role() = 'authenticated');
