-- Support tickets table
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  email TEXT NOT NULL,
  reason TEXT NOT NULL CHECK (reason IN ('feature_request', 'quote_pack_request', 'bug_report', 'awesome', 'other')),
  message TEXT NOT NULL,
  app_version TEXT,
  device_info TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

-- Anyone can insert (anonymous + authenticated)
CREATE POLICY "Anyone can submit a support ticket"
  ON support_tickets FOR INSERT
  WITH CHECK (true);

-- Authenticated users can read their own tickets
CREATE POLICY "Users can read own tickets"
  ON support_tickets FOR SELECT
  USING (auth.uid() = user_id);

-- Authenticated users can read/update/delete all (admin via service role or RLS bypass)
CREATE POLICY "Admins can manage all tickets"
  ON support_tickets FOR ALL
  USING (auth.role() = 'authenticated');
