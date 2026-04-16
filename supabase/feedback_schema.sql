CREATE TABLE feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('bug_report', 'feature_request', 'general', 'card_report')),
  description TEXT CHECK (char_length(description) <= 1000),
  card_id     TEXT,
  app_version TEXT,
  platform    TEXT,
  status      TEXT NOT NULL DEFAULT 'new'
              CHECK (status IN ('new', 'reviewed', 'in_progress', 'resolved', 'closed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- If you've already deployed the earlier schema, run these migrations instead:
-- ALTER TABLE feedback DROP CONSTRAINT feedback_type_check;
-- ALTER TABLE feedback ADD  CONSTRAINT feedback_type_check
--   CHECK (type IN ('bug_report', 'feature_request', 'general', 'card_report'));
-- ALTER TABLE feedback ADD COLUMN IF NOT EXISTS card_id TEXT;

CREATE INDEX idx_feedback_user   ON feedback(user_id);
CREATE INDEX idx_feedback_status ON feedback(status, created_at DESC);

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own feedback"
  ON feedback FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own feedback"
  ON feedback FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
