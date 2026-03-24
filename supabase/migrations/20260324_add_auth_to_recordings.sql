-- Add user_id to recordings table
ALTER TABLE recordings ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- One recording per user per quote per language (only for authenticated uploads)
CREATE UNIQUE INDEX IF NOT EXISTS recordings_user_quote_lang_idx
  ON recordings (user_id, quote_text_hash, language)
  WHERE user_id IS NOT NULL;

-- Enable Row Level Security
ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;

-- Anyone can read recordings
CREATE POLICY "Anyone can read recordings" ON recordings
  FOR SELECT USING (true);

-- Authenticated users can insert their own recordings
CREATE POLICY "Auth users can insert own" ON recordings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Authenticated users can update their own recordings
CREATE POLICY "Auth users can update own" ON recordings
  FOR UPDATE USING (auth.uid() = user_id);

-- Authenticated users can delete their own recordings
CREATE POLICY "Auth users can delete own" ON recordings
  FOR DELETE USING (auth.uid() = user_id);

-- Allow anonymous inserts (user_id IS NULL) for backward compatibility
CREATE POLICY "Anon can insert without user_id" ON recordings
  FOR INSERT WITH CHECK (user_id IS NULL);
