-- Security hardening applied after the Supabase MCP audit.
--
-- Main ideas:
--   1. Remove the message webhook trigger that exposed a bearer token.
--   2. Replace unsafe two-argument user migration with a one-time token flow.
--   3. Restrict RPC execution to signed-in users where the app expects auth.
--   4. Apply two safe performance cleanup changes.
--
-- Safe to re-run.

DROP TRIGGER IF EXISTS "push-notification" ON public.messages;
DROP FUNCTION IF EXISTS public.delete_user();

CREATE OR REPLACE FUNCTION public.delete_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.device_tokens    WHERE user_id = v_user_id;
  DELETE FROM public.trade_conditions WHERE user_id = v_user_id;
  DELETE FROM public.user_cards       WHERE user_id = v_user_id;
  DELETE FROM public.conversations
    WHERE user_a = v_user_id OR user_b = v_user_id;
  DELETE FROM public.profiles         WHERE user_id = v_user_id;
  DELETE FROM auth.users              WHERE id = v_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_account() TO authenticated;

CREATE TABLE IF NOT EXISTS public.user_migration_tokens (
  old_user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_migration_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_migration_tokens FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.begin_user_migration()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_token TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = v_user_id
      AND u.is_anonymous = true
  ) THEN
    RAISE EXCEPTION 'Only anonymous users can start a migration';
  END IF;

  v_token := encode(gen_random_bytes(32), 'hex');

  INSERT INTO public.user_migration_tokens (old_user_id, token_hash, expires_at)
  VALUES (
    v_user_id,
    encode(digest(v_token, 'sha256'), 'hex'),
    now() + interval '15 minutes'
  )
  ON CONFLICT (old_user_id) DO UPDATE
    SET token_hash = EXCLUDED.token_hash,
        expires_at = EXCLUDED.expires_at,
        created_at = now();

  RETURN v_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.migrate_user_data(
  p_old_id UUID,
  p_new_id UUID,
  p_token TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_conversation RECORD;
  v_existing_id UUID;
  v_new_user_a UUID;
  v_new_user_b UUID;
  v_source_unread_a INT;
  v_source_unread_b INT;
BEGIN
  IF p_old_id IS NULL OR p_new_id IS NULL OR p_token IS NULL OR p_old_id = p_new_id THEN
    RETURN;
  END IF;

  IF p_new_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to migrate into user %', p_new_id;
  END IF;

  DELETE FROM public.user_migration_tokens t
  WHERE t.old_user_id = p_old_id
    AND t.expires_at > now()
    AND t.token_hash = encode(digest(p_token, 'sha256'), 'hex');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired migration token';
  END IF;

  UPDATE public.profiles
  SET user_id = p_new_id
  WHERE user_id = p_old_id
    AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE user_id = p_new_id);
  DELETE FROM public.profiles WHERE user_id = p_old_id;

  INSERT INTO public.user_cards (user_id, card_id, type, language, created_at)
  SELECT p_new_id, card_id, type, language, created_at
  FROM public.user_cards
  WHERE user_id = p_old_id
  ON CONFLICT DO NOTHING;
  DELETE FROM public.user_cards WHERE user_id = p_old_id;

  FOR v_conversation IN
    SELECT *
    FROM public.conversations
    WHERE user_a = p_old_id OR user_b = p_old_id
    ORDER BY created_at
  LOOP
    IF v_conversation.user_a = p_old_id THEN
      v_new_user_a := LEAST(p_new_id, v_conversation.user_b);
      v_new_user_b := GREATEST(p_new_id, v_conversation.user_b);
      v_source_unread_a := CASE
        WHEN v_new_user_a = p_new_id THEN COALESCE(v_conversation.unread_count_a, 0)
        ELSE COALESCE(v_conversation.unread_count_b, 0)
      END;
      v_source_unread_b := CASE
        WHEN v_new_user_b = p_new_id THEN COALESCE(v_conversation.unread_count_a, 0)
        ELSE COALESCE(v_conversation.unread_count_b, 0)
      END;
    ELSE
      v_new_user_a := LEAST(v_conversation.user_a, p_new_id);
      v_new_user_b := GREATEST(v_conversation.user_a, p_new_id);
      v_source_unread_a := CASE
        WHEN v_new_user_a = p_new_id THEN COALESCE(v_conversation.unread_count_b, 0)
        ELSE COALESCE(v_conversation.unread_count_a, 0)
      END;
      v_source_unread_b := CASE
        WHEN v_new_user_b = p_new_id THEN COALESCE(v_conversation.unread_count_b, 0)
        ELSE COALESCE(v_conversation.unread_count_a, 0)
      END;
    END IF;

    IF v_new_user_a = v_new_user_b THEN
      DELETE FROM public.conversations WHERE id = v_conversation.id;
      CONTINUE;
    END IF;

    SELECT id INTO v_existing_id
    FROM public.conversations
    WHERE user_a = v_new_user_a
      AND user_b = v_new_user_b
      AND id <> v_conversation.id;

    IF v_existing_id IS NOT NULL THEN
      UPDATE public.messages
      SET conversation_id = v_existing_id
      WHERE conversation_id = v_conversation.id;

      UPDATE public.conversations c
      SET
        last_message_at = GREATEST(
          COALESCE(c.last_message_at, '-infinity'::timestamptz),
          COALESCE(v_conversation.last_message_at, '-infinity'::timestamptz)
        ),
        last_message_text = CASE
          WHEN COALESCE(v_conversation.last_message_at, '-infinity'::timestamptz) >=
               COALESCE(c.last_message_at, '-infinity'::timestamptz)
          THEN v_conversation.last_message_text
          ELSE c.last_message_text
        END,
        unread_count_a = COALESCE(c.unread_count_a, 0) + v_source_unread_a,
        unread_count_b = COALESCE(c.unread_count_b, 0) + v_source_unread_b
      WHERE c.id = v_existing_id;

      DELETE FROM public.conversations WHERE id = v_conversation.id;
    ELSE
      UPDATE public.conversations
      SET user_a = v_new_user_a,
          user_b = v_new_user_b,
          unread_count_a = v_source_unread_a,
          unread_count_b = v_source_unread_b
      WHERE id = v_conversation.id;
    END IF;
  END LOOP;

  INSERT INTO public.trade_conditions (
    user_id,
    listed_card_id,
    wanted_card_id,
    wanted_language,
    created_at
  )
  SELECT
    p_new_id,
    listed_card_id,
    wanted_card_id,
    wanted_language,
    created_at
  FROM public.trade_conditions
  WHERE user_id = p_old_id
  ON CONFLICT DO NOTHING;
  DELETE FROM public.trade_conditions WHERE user_id = p_old_id;
END;
$$;

DROP FUNCTION IF EXISTS public.migrate_user_data(UUID, UUID);

REVOKE EXECUTE ON FUNCTION public.begin_user_migration() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.migrate_user_data(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.begin_user_migration() TO authenticated;
GRANT EXECUTE ON FUNCTION public.migrate_user_data(UUID, UUID, TEXT) TO authenticated;

DROP POLICY IF EXISTS "Receiver can update trade status" ON public.messages;

CREATE OR REPLACE FUNCTION public.respond_to_trade_message(
  p_message_id UUID,
  p_status TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sender_id UUID;
  v_user_a UUID;
  v_user_b UUID;
  v_content TEXT;
  v_parts TEXT[];
  v_updated_content TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_status NOT IN ('accepted', 'denied') THEN
    RAISE EXCEPTION 'Invalid trade status';
  END IF;

  SELECT m.sender_id, m.content, c.user_a, c.user_b
    INTO v_sender_id, v_content, v_user_a, v_user_b
  FROM public.messages m
  JOIN public.conversations c ON c.id = m.conversation_id
  WHERE m.id = p_message_id
  FOR UPDATE OF m;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  IF v_user_id NOT IN (v_user_a, v_user_b) OR v_sender_id = v_user_id THEN
    RAISE EXCEPTION 'Not authorized to respond to this trade';
  END IF;

  v_parts := string_to_array(v_content, ':');
  IF array_length(v_parts, 1) < 6 OR v_parts[1] <> 'TRADE' THEN
    RAISE EXCEPTION 'Message is not a trade proposal';
  END IF;

  IF v_parts[6] <> 'pending' THEN
    RAISE EXCEPTION 'Trade proposal is no longer pending';
  END IF;

  v_parts[6] := p_status;
  v_updated_content := array_to_string(v_parts, ':');

  UPDATE public.messages
  SET content = v_updated_content
  WHERE id = p_message_id;

  RETURN v_updated_content;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.respond_to_trade_message(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_trade_message(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_trade_conditions(
  p_listed_card_id TEXT,
  p_wanted JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_entry JSONB;
  v_wanted_card TEXT;
  v_lang TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_wanted IS NOT NULL AND jsonb_typeof(p_wanted) <> 'object' THEN
    RAISE EXCEPTION 'Wanted conditions must be a JSON object';
  END IF;

  IF p_wanted IS NOT NULL AND p_wanted <> '{}'::jsonb THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.user_cards uc
      WHERE uc.user_id = v_user_id
        AND uc.card_id = p_listed_card_id
        AND uc.type = 'owned'
    ) THEN
      RAISE EXCEPTION 'Listed card must be owned by the current user';
    END IF;
  END IF;

  DELETE FROM public.trade_conditions
  WHERE user_id = v_user_id AND listed_card_id = p_listed_card_id;

  IF p_wanted IS NULL OR p_wanted = '{}'::jsonb THEN
    RETURN;
  END IF;

  FOR v_wanted_card, v_entry IN SELECT * FROM jsonb_each(p_wanted) LOOP
    IF jsonb_typeof(v_entry) <> 'array' THEN
      RAISE EXCEPTION 'Wanted languages must be arrays';
    END IF;

    FOR v_lang IN SELECT jsonb_array_elements_text(v_entry) LOOP
      INSERT INTO public.trade_conditions (
        user_id,
        listed_card_id,
        wanted_card_id,
        wanted_language
      )
      VALUES (v_user_id, p_listed_card_id, v_wanted_card, v_lang);
    END LOOP;
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_trade_conditions(TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_trade_conditions(TEXT, JSONB) TO authenticated;

DROP FUNCTION IF EXISTS public.get_trade_matches_for_wanted(TEXT, UUID);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_owned(TEXT, UUID);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_wanted(TEXT, UUID, TEXT[]);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_owned(TEXT, UUID, TEXT[]);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_wanted(TEXT, UUID, TEXT[], BOOLEAN);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_owned(TEXT, UUID, TEXT[], BOOLEAN);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_wanted(TEXT, UUID, TEXT[], BOOLEAN, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_owned(TEXT, UUID, TEXT[], BOOLEAN, INTEGER, INTEGER);

REVOKE EXECUTE ON FUNCTION public.get_my_pending_proposals() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_or_create_conversation(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_trade_matches_for_wanted(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_trade_matches_for_owned(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_last_active() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_my_pending_proposals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trade_matches_for_wanted(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trade_matches_for_owned(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_last_active() TO authenticated;

ALTER FUNCTION public.get_my_pending_proposals() SECURITY INVOKER;
ALTER FUNCTION public.get_or_create_conversation(UUID) SECURITY INVOKER;
ALTER FUNCTION public.respond_to_trade_message(UUID, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.set_trade_conditions(TEXT, JSONB) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_trade_matches_for_wanted(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_trade_matches_for_owned(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) SET search_path = public, pg_temp;

CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
ALTER TABLE public.user_cards
  DROP CONSTRAINT IF EXISTS user_cards_user_id_card_id_type_language_key;
