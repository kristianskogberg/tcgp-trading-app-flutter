-- Atomic account deletion.
--
-- Previously the client issued 4 separate deletes + a delete_user RPC
-- sequentially. A failure mid-way could leave a zombie partial account
-- (auth user gone, cards still around, or vice versa).
--
-- This RPC wraps everything in a single plpgsql block (implicit transaction).
-- If anything throws, Postgres rolls the whole thing back. The client is
-- responsible for calling `await auth.signOut()` AFTER this returns, to
-- clear the local session.
--
-- SECURITY DEFINER so it can delete from auth.users (the caller normally
-- cannot). We verify the caller is only ever deleting themselves.
CREATE OR REPLACE FUNCTION delete_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- App data. ON DELETE CASCADE on auth.users would handle most of this,
  -- but being explicit keeps the intent clear and avoids relying on
  -- cascade semantics if FKs ever change.
  DELETE FROM device_tokens    WHERE user_id = v_user_id;
  DELETE FROM trade_conditions WHERE user_id = v_user_id;
  DELETE FROM user_cards       WHERE user_id = v_user_id;
  -- messages cascade via conversations.ON DELETE CASCADE
  DELETE FROM conversations
    WHERE user_a = v_user_id OR user_b = v_user_id;
  DELETE FROM profiles         WHERE user_id = v_user_id;

  -- Finally remove the auth user. This also cascades to any remaining
  -- rows with ON DELETE CASCADE FKs to auth.users.
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;
