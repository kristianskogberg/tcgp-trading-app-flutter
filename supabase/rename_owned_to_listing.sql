-- Rename the "owned" collection type to "listing" (issue #1, see CONTEXT.md).
--
-- Hand-run in the Supabase SQL editor. Behaviour-neutral: every function keeps
-- its logic, only the type value and the listing RPC name change.
--
-- Run guide
-- 1. Back up first. Either take a backup in Dashboard → Database → Backups, or
--    copy the rows aside by running this on its own. The copy goes in a
--    private schema: a table in `public` would be readable through the API.
--      CREATE SCHEMA IF NOT EXISTS backup;
--      REVOKE ALL ON SCHEMA backup FROM PUBLIC, anon, authenticated;
--      CREATE TABLE backup.user_cards_owned_rename AS TABLE public.user_cards;
--    Note how many rows have type = 'owned':
--      SELECT type, count(*) FROM public.user_cards GROUP BY type;
-- 2. Paste this whole file into the SQL editor and run it. It runs in one
--    transaction, so if anything fails nothing is changed.
-- 3. Run the verification queries at the bottom of this file (they are
--    commented out) one by one and compare with the expected results.
-- 4. Ship the app build that calls get_trade_matches_for_listing. Older builds
--    call get_trade_matches_for_owned, which no longer exists after this script.
-- 5. Once everything works, drop the backup table:
--      DROP TABLE backup.user_cards_owned_rename;

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Type value and check constraint
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_cards DROP CONSTRAINT user_cards_type_check;

UPDATE public.user_cards SET type = 'listing' WHERE type = 'owned';

ALTER TABLE public.user_cards
  ADD CONSTRAINT user_cards_type_check
  CHECK (type = ANY (ARRAY['wishlist'::text, 'listing'::text]));

-- ---------------------------------------------------------------------------
-- 2. get_trade_matches_for_wanted: filter on 'listing'
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_trade_matches_for_wanted(p_card_id text, p_languages text[], p_fullart_only boolean, p_limit integer, p_offset integer)
 RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamp with time zone, language text, has_mutual_match boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM (
    -- Case 1: Other user has NO trade conditions for this card → use their wishlist (existing behaviour)
    SELECT DISTINCT uc_other.card_id,
      uc_own.user_id,
      p.player_name,
      p.friend_id,
      p.icon,
      p.last_active_at,
      uc_other.language,
      COALESCE(mutual.val, false) AS has_mutual_match
    FROM user_cards uc_me
    JOIN user_cards uc_own
      ON uc_own.card_id = p_card_id
     AND uc_own.type = 'listing'
     AND uc_own.user_id != auth.uid()
    JOIN profiles p
      ON p.user_id = uc_own.user_id
    JOIN cards target
      ON target.id = p_card_id
    JOIN user_cards uc_other
      ON uc_other.user_id = uc_own.user_id
     AND uc_other.card_id != p_card_id
     AND uc_other.type = 'wishlist'
    JOIN cards c
      ON c.id = uc_other.card_id
     AND c.rarity = target.rarity
    LEFT JOIN LATERAL (
      SELECT true AS val
      FROM user_cards uc_b_own
      JOIN user_cards uc_a_wish
        ON uc_a_wish.card_id = uc_b_own.card_id
       AND uc_a_wish.user_id = auth.uid()
       AND uc_a_wish.type = 'wishlist'
      JOIN cards c2 ON c2.id = uc_b_own.card_id AND c2.rarity = target.rarity
      WHERE uc_b_own.user_id = uc_own.user_id
        AND uc_b_own.type = 'listing'
        AND uc_b_own.card_id != p_card_id
        AND (
             uc_a_wish.language = 'ANY'
          OR uc_b_own.language = 'ANY'
          OR uc_a_wish.language = uc_b_own.language
        )
      LIMIT 1
    ) mutual ON true
    WHERE uc_me.user_id = auth.uid()
      AND uc_me.card_id = p_card_id
      AND uc_me.type = 'wishlist'
      AND (
           uc_me.language = 'ANY'
        OR uc_own.language = 'ANY'
        OR uc_me.language = uc_own.language
      )
      AND (NOT p_fullart_only OR (c.fullart = true AND c.type = 'Trainer'))
      AND (array_length(p_languages, 1) IS NULL OR uc_other.language = 'ANY' OR uc_other.language = ANY(p_languages))
      -- Exclude users who have trade conditions (handled in Case 2)
      AND NOT EXISTS (
        SELECT 1 FROM trade_conditions tc
        WHERE tc.user_id = uc_own.user_id AND tc.listed_card_id = p_card_id
      )

    UNION ALL

    -- Case 2: Other user HAS trade conditions → only show them if current user lists the condition card
    SELECT DISTINCT tc.wanted_card_id AS card_id,
      uc_own.user_id,
      p.player_name,
      p.friend_id,
      p.icon,
      p.last_active_at,
      tc.wanted_language AS language,
      true AS has_mutual_match  -- current user lists the wanted card by definition
    FROM user_cards uc_me
    JOIN user_cards uc_own
      ON uc_own.card_id = p_card_id
     AND uc_own.type = 'listing'
     AND uc_own.user_id != auth.uid()
    JOIN profiles p
      ON p.user_id = uc_own.user_id
    JOIN cards target
      ON target.id = p_card_id
    JOIN trade_conditions tc
      ON tc.user_id = uc_own.user_id
     AND tc.listed_card_id = p_card_id
    JOIN cards c
      ON c.id = tc.wanted_card_id
     AND c.rarity = target.rarity
    -- Current user must list the condition card in a compatible language
    JOIN user_cards uc_a_own
      ON uc_a_own.user_id = auth.uid()
     AND uc_a_own.card_id = tc.wanted_card_id
     AND uc_a_own.type = 'listing'
     AND (
          tc.wanted_language = 'ANY'
       OR uc_a_own.language = 'ANY'
       OR uc_a_own.language = tc.wanted_language
     )
    WHERE uc_me.user_id = auth.uid()
      AND uc_me.card_id = p_card_id
      AND uc_me.type = 'wishlist'
      AND (
           uc_me.language = 'ANY'
        OR uc_own.language = 'ANY'
        OR uc_me.language = uc_own.language
      )
      AND (NOT p_fullart_only OR (c.fullart = true AND c.type = 'Trainer'))
      AND (array_length(p_languages, 1) IS NULL OR tc.wanted_language = 'ANY' OR tc.wanted_language = ANY(p_languages))
  ) sub
  ORDER BY has_mutual_match DESC, last_active_at DESC NULLS LAST, card_id
  LIMIT p_limit OFFSET p_offset;
$function$;

-- ---------------------------------------------------------------------------
-- 3. set_trade_conditions: the listed card must be a 'listing'
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_trade_conditions(p_listed_card_id text, p_wanted jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_entry jsonb;
  v_wanted_card text;
  v_lang text;
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
      FROM user_cards uc
      WHERE uc.user_id = v_user_id
        AND uc.card_id = p_listed_card_id
        AND uc.type = 'listing'
    ) THEN
      RAISE EXCEPTION 'Listed card must be a listing of the current user';
    END IF;
  END IF;

  DELETE FROM trade_conditions
  WHERE user_id = v_user_id AND listed_card_id = p_listed_card_id;

  IF p_wanted IS NULL OR p_wanted = '{}'::jsonb THEN
    RETURN;
  END IF;

  FOR v_wanted_card, v_entry IN SELECT * FROM jsonb_each(p_wanted) LOOP
    IF jsonb_typeof(v_entry) <> 'array' THEN
      RAISE EXCEPTION 'Wanted languages must be arrays';
    END IF;

    FOR v_lang IN SELECT jsonb_array_elements_text(v_entry) LOOP
      INSERT INTO trade_conditions (user_id, listed_card_id, wanted_card_id, wanted_language)
      VALUES (v_user_id, p_listed_card_id, v_wanted_card, v_lang);
    END LOOP;
  END LOOP;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. get_trade_matches_for_owned → get_trade_matches_for_listing
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.get_trade_matches_for_owned(text, text[], boolean, integer, integer);

CREATE OR REPLACE FUNCTION public.get_trade_matches_for_listing(p_card_id text, p_languages text[], p_fullart_only boolean, p_limit integer, p_offset integer)
 RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamp with time zone, language text, has_mutual_match boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM (
    -- Case 1: Current user has NO trade conditions for this card → use other users' listings (existing behaviour)
    SELECT DISTINCT uc_other.card_id,
      uc_want.user_id,
      p.player_name,
      p.friend_id,
      p.icon,
      p.last_active_at,
      uc_other.language,
      COALESCE(mutual.val, false) AS has_mutual_match
    FROM user_cards uc_me
    JOIN user_cards uc_want
      ON uc_want.card_id = p_card_id
     AND uc_want.type = 'wishlist'
     AND uc_want.user_id != auth.uid()
    JOIN profiles p
      ON p.user_id = uc_want.user_id
    JOIN cards target
      ON target.id = p_card_id
    JOIN user_cards uc_other
      ON uc_other.user_id = uc_want.user_id
     AND uc_other.card_id != p_card_id
     AND uc_other.type = 'listing'
    JOIN cards c
      ON c.id = uc_other.card_id
     AND c.rarity = target.rarity
    LEFT JOIN LATERAL (
      SELECT true AS val
      FROM user_cards uc_b_wish
      JOIN user_cards uc_a_own
        ON uc_a_own.card_id = uc_b_wish.card_id
       AND uc_a_own.user_id = auth.uid()
       AND uc_a_own.type = 'listing'
      JOIN cards c2 ON c2.id = uc_b_wish.card_id AND c2.rarity = target.rarity
      WHERE uc_b_wish.user_id = uc_want.user_id
        AND uc_b_wish.type = 'wishlist'
        AND uc_b_wish.card_id != p_card_id
        AND (
             uc_b_wish.language = 'ANY'
          OR uc_a_own.language = 'ANY'
          OR uc_b_wish.language = uc_a_own.language
        )
      LIMIT 1
    ) mutual ON true
    WHERE uc_me.user_id = auth.uid()
      AND uc_me.card_id = p_card_id
      AND uc_me.type = 'listing'
      AND (
           uc_me.language = 'ANY'
        OR uc_want.language = 'ANY'
        OR uc_me.language = uc_want.language
      )
      AND (NOT p_fullart_only OR (c.fullart = true AND c.type = 'Trainer'))
      AND (array_length(p_languages, 1) IS NULL OR uc_other.language = 'ANY' OR uc_other.language = ANY(p_languages))
      -- Exclude when current user has conditions (handled in Case 2)
      AND NOT EXISTS (
        SELECT 1 FROM trade_conditions tc
        WHERE tc.user_id = auth.uid() AND tc.listed_card_id = p_card_id
      )

    UNION ALL

    -- Case 2: Current user HAS trade conditions → only show other users who list the condition card
    SELECT DISTINCT uc_other_own.card_id,
      uc_want.user_id,
      p.player_name,
      p.friend_id,
      p.icon,
      p.last_active_at,
      uc_other_own.language,
      true AS has_mutual_match  -- other user lists the wanted card by definition
    FROM user_cards uc_me
    JOIN trade_conditions tc
      ON tc.user_id = auth.uid()
     AND tc.listed_card_id = p_card_id
    JOIN user_cards uc_want
      ON uc_want.card_id = p_card_id
     AND uc_want.type = 'wishlist'
     AND uc_want.user_id != auth.uid()
    JOIN profiles p
      ON p.user_id = uc_want.user_id
    JOIN cards target
      ON target.id = p_card_id
    JOIN cards c
      ON c.id = tc.wanted_card_id
     AND c.rarity = target.rarity
    -- Other user must list the condition card in a compatible language
    JOIN user_cards uc_other_own
      ON uc_other_own.user_id = uc_want.user_id
     AND uc_other_own.card_id = tc.wanted_card_id
     AND uc_other_own.type = 'listing'
     AND (
          tc.wanted_language = 'ANY'
       OR uc_other_own.language = 'ANY'
       OR uc_other_own.language = tc.wanted_language
     )
    WHERE uc_me.user_id = auth.uid()
      AND uc_me.card_id = p_card_id
      AND uc_me.type = 'listing'
      AND (
           uc_me.language = 'ANY'
        OR uc_want.language = 'ANY'
        OR uc_me.language = uc_want.language
      )
      AND (NOT p_fullart_only OR (c.fullart = true AND c.type = 'Trainer'))
      AND (array_length(p_languages, 1) IS NULL OR uc_other_own.language = 'ANY' OR uc_other_own.language = ANY(p_languages))
  ) sub
  ORDER BY has_mutual_match DESC, last_active_at DESC NULLS LAST, card_id
  LIMIT p_limit OFFSET p_offset;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Grants and search_path pins (same as rls_hardening.sql /
--    security_hardening_2026_05.sql, under the new name)
-- ---------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.get_trade_matches_for_listing(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_trade_matches_for_listing(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) TO authenticated;
ALTER FUNCTION public.get_trade_matches_for_listing(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.get_trade_matches_for_wanted(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_trade_matches_for_wanted(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.set_trade_conditions(TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_trade_conditions(TEXT, JSONB) TO authenticated;

COMMIT;

-- ---------------------------------------------------------------------------
-- Verification (run one by one after the script)
-- ---------------------------------------------------------------------------

-- a) No 'owned' rows remain; the 'listing' count equals the old 'owned' count.
--    Expected: only 'wishlist' and 'listing' rows.
-- SELECT type, count(*) FROM public.user_cards GROUP BY type;

-- b) The check constraint allows only wishlist and listing.
--    Expected: CHECK ((type = ANY (ARRAY['wishlist'::text, 'listing'::text])))
-- SELECT pg_get_constraintdef(oid) FROM pg_constraint
-- WHERE conrelid = 'public.user_cards'::regclass AND conname = 'user_cards_type_check';

-- c) The constraint rejects 'owned'.
--    Expected: ERROR ... violates check constraint "user_cards_type_check"
--    The check runs before the foreign key, so the random user_id is never
--    looked up, and the rollback means nothing is kept either way.
-- BEGIN;
-- INSERT INTO public.user_cards (user_id, card_id, type, language)
-- VALUES (gen_random_uuid(), 'verify', 'owned', 'ANY');
-- ROLLBACK;

-- d) The listing RPC exists under its new name and the old one is gone.
--    Expected: one row, get_trade_matches_for_listing, search_path pinned.
-- SELECT p.proname, p.proconfig FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public'
--   AND p.proname IN ('get_trade_matches_for_owned', 'get_trade_matches_for_listing');

-- e) Only authenticated (plus postgres/service_role) can execute it.
--    Expected: authenticated, postgres, service_role. No anon, no PUBLIC.
-- SELECT grantee, privilege_type FROM information_schema.routine_privileges
-- WHERE routine_schema = 'public' AND routine_name = 'get_trade_matches_for_listing';

-- f) No function body still filters on 'owned'.
--    Expected: zero rows.
-- SELECT p.proname FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND p.prokind = 'f' AND p.prosrc ILIKE '%''owned''%';
