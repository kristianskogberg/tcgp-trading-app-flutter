-- Verifies preferred_language (see preferred_language.sql, step 4).
--
-- 1. Find a user id. Users who signed in anonymously have no email, so look
--    one up by player name:
--      SELECT user_id, player_name FROM public.profiles
--      WHERE player_name = 'YourPlayerName';
--    or list them all with
--      SELECT id, is_anonymous, created_at FROM auth.users ORDER BY created_at;
-- 2. Replace PUT-YOUR-USER-ID-HERE below with it. Don't commit the id.
-- 3. Run this whole file in the SQL editor. It acts as that user, sets and
--    rejects test values on their profile, checks each result and ROLLS
--    BACK at the end: the profile is not changed. Expect one result row
--    reading "preferred_language: all checks passed". A failed check shows
--    an error starting "Check failed:" instead.

BEGIN;

SELECT set_config('verify.user_id', 'PUT-YOUR-USER-ID-HERE', true);
SELECT set_config(
  'request.jwt.claims',
  json_build_object('sub', current_setting('verify.user_id'),
                    'role', 'authenticated')::text,
  true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_user UUID := current_setting('verify.user_id')::uuid;
  v_value TEXT;
  v_rejected BOOLEAN;
  v_bad TEXT;
  v_count INT;
BEGIN
  IF auth.uid() IS DISTINCT FROM v_user THEN
    RAISE EXCEPTION 'Check failed: not acting as %, put your user id in', v_user;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE user_id = v_user) THEN
    RAISE EXCEPTION 'Check failed: % has no profile row', v_user;
  END IF;

  -- A specific language is stored ---------------------------------------
  UPDATE profiles SET preferred_language = 'JPN' WHERE user_id = v_user;
  SELECT preferred_language INTO v_value FROM profiles WHERE user_id = v_user;
  IF v_value IS DISTINCT FROM 'JPN' THEN
    RAISE EXCEPTION 'Check failed: JPN was not stored (got %)', v_value;
  END IF;

  -- Unset is allowed ----------------------------------------------------
  UPDATE profiles SET preferred_language = NULL WHERE user_id = v_user;
  SELECT preferred_language INTO v_value FROM profiles WHERE user_id = v_user;
  IF v_value IS NOT NULL THEN
    RAISE EXCEPTION 'Check failed: preferred language could not be unset';
  END IF;

  -- "Any language", unknown and lower-case values are rejected ----------
  FOREACH v_bad IN ARRAY ARRAY['ANY', 'XYZ', 'jpn', ''] LOOP
    v_rejected := false;
    BEGIN
      UPDATE profiles SET preferred_language = v_bad WHERE user_id = v_user;
    EXCEPTION WHEN check_violation THEN
      v_rejected := true;
    END;
    IF NOT v_rejected THEN
      RAISE EXCEPTION 'Check failed: % was accepted as a preferred language',
        quote_literal(v_bad);
    END IF;
  END LOOP;

  -- Another user's preferred language can't be changed ------------------
  -- Row security limits the update to the user's own row, so it changes
  -- no other row.
  UPDATE profiles SET preferred_language = 'KOR'
  WHERE user_id IS DISTINCT FROM v_user;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Check failed: changed % other users'' preferred language',
      v_count;
  END IF;
END;
$$;

-- Only reached when every check above passed. The SQL editor shows this row
-- as the result; it does not show notices.
SELECT 'preferred_language: all checks passed' AS result;

ROLLBACK;
