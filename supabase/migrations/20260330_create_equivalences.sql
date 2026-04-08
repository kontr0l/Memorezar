-- Community word equivalences: crowd-sourced word pairs from user disputes
CREATE TABLE IF NOT EXISTS equivalences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expected_word TEXT NOT NULL,
    spoken_word TEXT NOT NULL,
    report_count INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(expected_word, spoken_word)
);

-- Index for fetching equivalences by expected word
CREATE INDEX IF NOT EXISTS equivalences_expected_word_idx ON equivalences (expected_word);

-- RLS
ALTER TABLE equivalences ENABLE ROW LEVEL SECURITY;

-- Anyone can read equivalences
CREATE POLICY "Anyone can read equivalences" ON equivalences FOR SELECT USING (true);
-- Anyone can insert equivalences (fire-and-forget from app)
CREATE POLICY "Anyone can insert equivalences" ON equivalences FOR INSERT WITH CHECK (true);
-- Authenticated users can update (for report_count increment + admin)
CREATE POLICY "Auth users can update equivalences" ON equivalences FOR UPDATE USING (auth.role() = 'authenticated');
-- Authenticated users can delete (admin cleanup)
CREATE POLICY "Auth users can delete equivalences" ON equivalences FOR DELETE USING (auth.role() = 'authenticated');
