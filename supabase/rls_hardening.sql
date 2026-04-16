-- RLS hardening migration
--
-- Context: app uses Supabase anonymous auth. Anonymous users get a JWT with
-- role=authenticated and is_anonymous=true. Targeting {authenticated} therefore
-- still covers anon users; it only blocks requests with NO JWT at all.
--
-- Changes:
--   1. Drop duplicate/redundant policies on `profiles`
--   2. Re-scope all {public} policies to {authenticated}
--   3. Pin search_path on SECURITY DEFINER / trigger functions
--
-- Run in Supabase SQL Editor. Safe to re-run.

-- =============================================================
-- 1. profiles: remove duplicate policies
-- =============================================================
DROP POLICY IF EXISTS "Users can manage own profile" ON profiles;     -- missing WITH CHECK; duplicate of below
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;     -- covered by ALL policy

-- =============================================================
-- 2. Re-scope policies from {public} to {authenticated}
--    (Postgres has no ALTER POLICY ... TO; must drop + recreate.)
-- =============================================================

-- profiles ------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can read profiles" ON profiles;
CREATE POLICY "Authenticated users can read profiles" ON profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can manage their own profile" ON profiles;
CREATE POLICY "Users can manage their own profile" ON profiles
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- user_cards ----------------------------------------------------
DROP POLICY IF EXISTS "Anyone can view user_cards" ON user_cards;
CREATE POLICY "Authenticated users can view user_cards" ON user_cards
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users manage own cards" ON user_cards;
CREATE POLICY "Users insert own cards" ON user_cards
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own cards" ON user_cards;
CREATE POLICY "Users delete own cards" ON user_cards
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- trade_conditions ---------------------------------------------
DROP POLICY IF EXISTS "Anyone can read trade conditions" ON trade_conditions;
CREATE POLICY "Authenticated users can read trade conditions" ON trade_conditions
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Users can insert own trade conditions" ON trade_conditions;
CREATE POLICY "Users can insert own trade conditions" ON trade_conditions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own trade conditions" ON trade_conditions;
CREATE POLICY "Users can delete own trade conditions" ON trade_conditions
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- conversations -------------------------------------------------
DROP POLICY IF EXISTS "Users see own conversations" ON conversations;
CREATE POLICY "Users see own conversations" ON conversations
  FOR SELECT TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "Users insert own conversations" ON conversations;
CREATE POLICY "Users insert own conversations" ON conversations
  FOR INSERT TO authenticated
  WITH CHECK ((auth.uid() = user_a OR auth.uid() = user_b) AND user_a < user_b);

DROP POLICY IF EXISTS "Users update own conversations" ON conversations;
CREATE POLICY "Users update own conversations" ON conversations
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "Users delete own conversations" ON conversations;
CREATE POLICY "Users delete own conversations" ON conversations
  FOR DELETE TO authenticated
  USING (auth.uid() = user_a OR auth.uid() = user_b);

-- messages ------------------------------------------------------
DROP POLICY IF EXISTS "Users see messages in own conversations" ON messages;
CREATE POLICY "Users see messages in own conversations" ON messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
      AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
  ));

DROP POLICY IF EXISTS "Users insert messages in own conversations" ON messages;
CREATE POLICY "Users insert messages in own conversations" ON messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Receiver can update trade status" ON messages;
CREATE POLICY "Receiver can update trade status" ON messages
  FOR UPDATE TO authenticated
  USING (
    sender_id <> auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
    )
  )
  WITH CHECK (
    sender_id <> auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
    )
  );

-- device_tokens -------------------------------------------------
DROP POLICY IF EXISTS "Users can manage their own tokens" ON device_tokens;
CREATE POLICY "Users can manage their own tokens" ON device_tokens
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =============================================================
-- 3. Pin search_path on functions (prevents search_path injection)
-- =============================================================
ALTER FUNCTION public.migrate_user_data              SET search_path = public, pg_temp;
ALTER FUNCTION public.update_cards_timestamp         SET search_path = public, pg_temp;
ALTER FUNCTION public.increment_unread_count         SET search_path = public, pg_temp;
ALTER FUNCTION public.get_or_create_conversation     SET search_path = public, pg_temp;
ALTER FUNCTION public.update_last_active             SET search_path = public, pg_temp;
ALTER FUNCTION public.get_trade_matches_for_wanted   SET search_path = public, pg_temp;
ALTER FUNCTION public.get_trade_matches_for_owned    SET search_path = public, pg_temp;
ALTER FUNCTION public.get_my_pending_proposals       SET search_path = public, pg_temp;
