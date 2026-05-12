-- Secure migration of app data from an anonymous auth user ID to a newly
-- linked Google auth user ID.
--
-- Why the token exists:
-- After Google sign-in, auth.uid() is the new user ID, so the database cannot
-- prove from auth.uid() alone that the caller previously controlled p_old_id.
-- begin_user_migration() is called while still signed in as the old anonymous
-- user and returns a short-lived random token. migrate_user_data() then requires
-- that token before moving rows.

CREATE TABLE IF NOT EXISTS user_migration_tokens (
  old_user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_migration_tokens ENABLE ROW LEVEL SECURITY;

-- No client role needs direct table access; clients use the RPCs below.
REVOKE ALL ON TABLE user_migration_tokens FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION begin_user_migration()
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

  -- This flow is only for upgrading an anonymous account to a real login.
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE u.id = v_user_id
      AND u.is_anonymous = true
  ) THEN
    RAISE EXCEPTION 'Only anonymous users can start a migration';
  END IF;

  v_token := encode(gen_random_bytes(32), 'hex');

  INSERT INTO user_migration_tokens (old_user_id, token_hash, expires_at)
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

-- Atomic migration of a user's app data from one auth user ID to another.
CREATE OR REPLACE FUNCTION migrate_user_data(
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

  -- Only the current auth user can migrate INTO their own id.
  IF p_new_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to migrate into user %', p_new_id;
  END IF;

  -- The caller must prove they controlled p_old_id immediately before linking.
  DELETE FROM user_migration_tokens t
  WHERE t.old_user_id = p_old_id
    AND t.expires_at > now()
    AND t.token_hash = encode(digest(p_token, 'sha256'), 'hex');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired migration token';
  END IF;

  UPDATE profiles
  SET user_id = p_new_id
  WHERE user_id = p_old_id
    AND NOT EXISTS (SELECT 1 FROM profiles WHERE user_id = p_new_id);
  DELETE FROM profiles WHERE user_id = p_old_id;

  INSERT INTO user_cards (user_id, card_id, type, language, created_at)
  SELECT p_new_id, card_id, type, language, created_at
  FROM user_cards
  WHERE user_id = p_old_id
  ON CONFLICT DO NOTHING;
  DELETE FROM user_cards WHERE user_id = p_old_id;

  FOR v_conversation IN
    SELECT *
    FROM conversations
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

    -- If old and new users had a conversation with each other, it becomes a
    -- self-conversation after migration and should not be kept.
    IF v_new_user_a = v_new_user_b THEN
      DELETE FROM conversations WHERE id = v_conversation.id;
      CONTINUE;
    END IF;

    SELECT id INTO v_existing_id
    FROM conversations
    WHERE user_a = v_new_user_a
      AND user_b = v_new_user_b
      AND id <> v_conversation.id;

    IF v_existing_id IS NOT NULL THEN
      UPDATE messages
      SET conversation_id = v_existing_id
      WHERE conversation_id = v_conversation.id;

      UPDATE conversations c
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

      DELETE FROM conversations WHERE id = v_conversation.id;
    ELSE
      UPDATE conversations
      SET user_a = v_new_user_a,
          user_b = v_new_user_b,
          unread_count_a = v_source_unread_a,
          unread_count_b = v_source_unread_b
      WHERE id = v_conversation.id;
    END IF;
  END LOOP;

  INSERT INTO trade_conditions (
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
  FROM trade_conditions
  WHERE user_id = p_old_id
  ON CONFLICT DO NOTHING;
  DELETE FROM trade_conditions WHERE user_id = p_old_id;
END;
$$;

DROP FUNCTION IF EXISTS migrate_user_data(UUID, UUID);

REVOKE EXECUTE ON FUNCTION begin_user_migration() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION migrate_user_data(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION begin_user_migration() TO authenticated;
GRANT EXECUTE ON FUNCTION migrate_user_data(UUID, UUID, TEXT) TO authenticated;
