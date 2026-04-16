-- Atomic migration of a user's app data from one auth user ID to another.
-- Runs when Supabase creates a fresh user during Google account linking
-- instead of merging into the existing anonymous user.
--
-- Runs inside a single transaction so partial failure leaves no account half-migrated.
-- SECURITY DEFINER so it can rewrite rows the caller would otherwise not own
-- (the old anonymous user_id will no longer match auth.uid() after the link).
CREATE OR REPLACE FUNCTION migrate_user_data(p_old_id UUID, p_new_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF p_old_id IS NULL OR p_new_id IS NULL OR p_old_id = p_new_id THEN
    RETURN;
  END IF;

  -- Only the current auth user can migrate INTO their own id.
  IF p_new_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to migrate into user %', p_new_id;
  END IF;

  UPDATE profiles      SET user_id = p_new_id WHERE user_id = p_old_id;
  UPDATE user_cards    SET user_id = p_new_id WHERE user_id = p_old_id;
  UPDATE conversations SET user_a  = p_new_id WHERE user_a  = p_old_id;
  UPDATE conversations SET user_b  = p_new_id WHERE user_b  = p_old_id;
  -- trade_conditions has a user_id column scoped per-user; migrate it too.
  UPDATE trade_conditions SET user_id = p_new_id WHERE user_id = p_old_id;
END;
$$;
