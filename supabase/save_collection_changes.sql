-- save_collection_changes: save every collection edit in one atomic,
-- validating call (issue #3, docs/adr/0001-collection-writes-via-atomic-rpc.md).
--
-- Hand-run in the Supabase SQL editor. Only adds a function: no table or row
-- changes, and older app builds keep working on their per-row writes.
--
-- Run guide
-- 1. Paste this whole file into the SQL editor and run it. It runs in one
--    transaction, so if anything fails nothing is changed.
-- 2. Check the function exists and only signed-in users can call it:
--      SELECT p.proname, p.prosecdef,
--             has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_run,
--             has_function_privilege('authenticated', p.oid, 'EXECUTE') AS users_can_run
--      FROM pg_proc p
--      WHERE p.proname = 'save_collection_changes';
--    Expect one row: prosecdef = true, anon_can_run = false,
--    users_can_run = true.
-- 3. Open supabase/save_collection_changes_verify.sql, put your own user id
--    in it as the file says, and run it. It saves and rejects test edits as
--    you, checks every result, and rolls everything back at the end, so your
--    collection is left exactly as it was. Expect one result row reading
--    "save_collection_changes: all checks passed". Any failed check stops it
--    with an error naming the check instead.
-- 4. Ship the app build that saves card-screen edits through this function.
--
-- Payload (p_changes): the desired state of each changed card. A card's
-- stored rows are replaced by that state; cards not in the payload are left
-- alone.
--   [
--     {"card_id": "A1-001", "wishlist": null, "listing": null},
--     {"card_id": "A1-002", "wishlist": {"languages": ["ENG", "JPN"]},
--      "listing": null},
--     {"card_id": "A1-003", "wishlist": null,
--      "listing": {"languages": ["FRA"],
--                  "trade_conditions": [
--                    {"card_id": "A1-010", "languages": ["ANY"]}]}}
--   ]
--
-- The whole save is rejected when any card breaks a collection rule:
-- - a card that is both a wishlist entry and a listing, or appears twice
-- - a listing that doesn't have exactly one specific language
-- - "any language" mixed with specific languages, or no languages at all
-- - the same trade condition card twice on one listing
-- - a trade condition that isn't the same rarity as its listing, or is the
--   listing itself
-- Untradable cards are still only checked in the app.

BEGIN;

CREATE OR REPLACE FUNCTION public.save_collection_changes(p_changes JSONB)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_change JSONB;
  v_card_id TEXT;
  v_wishlist JSONB;
  v_listing JSONB;
  v_languages TEXT[];
  v_listing_language TEXT;
  v_listing_rarity TEXT;
  v_condition JSONB;
  v_condition_card_id TEXT;
  v_condition_languages TEXT[];
  v_condition_rarity TEXT;
  v_seen TEXT[] := '{}';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_changes IS NULL OR jsonb_typeof(p_changes) <> 'array' THEN
    RAISE EXCEPTION 'Changes must be a JSON array';
  END IF;

  FOR v_change IN SELECT * FROM jsonb_array_elements(p_changes) LOOP
    IF jsonb_typeof(v_change) <> 'object' THEN
      RAISE EXCEPTION 'Each change must be a JSON object';
    END IF;

    v_card_id := v_change->>'card_id';
    IF v_card_id IS NULL OR v_card_id = '' THEN
      RAISE EXCEPTION 'Each change needs a card_id';
    END IF;
    IF v_card_id = ANY (v_seen) THEN
      RAISE EXCEPTION 'Card % appears more than once', v_card_id;
    END IF;
    v_seen := v_seen || v_card_id;

    v_wishlist := NULLIF(v_change->'wishlist', 'null'::jsonb);
    v_listing := NULLIF(v_change->'listing', 'null'::jsonb);

    IF v_wishlist IS NOT NULL AND v_listing IS NOT NULL THEN
      RAISE EXCEPTION 'Card % cannot be both a wishlist entry and a listing',
        v_card_id;
    END IF;

    -- Replace whatever is stored for this card.
    DELETE FROM public.user_cards
    WHERE user_id = v_user_id AND card_id = v_card_id;
    DELETE FROM public.trade_conditions
    WHERE user_id = v_user_id AND listed_card_id = v_card_id;

    IF v_wishlist IS NOT NULL THEN
      v_languages := public._collection_languages(
        v_wishlist->'languages', format('Wishlist entry %s', v_card_id));

      INSERT INTO public.user_cards (user_id, card_id, type, language)
      SELECT v_user_id, v_card_id, 'wishlist', l FROM unnest(v_languages) l;
    END IF;

    IF v_listing IS NOT NULL THEN
      v_languages := public._collection_languages(
        v_listing->'languages', format('Listing %s', v_card_id));
      IF cardinality(v_languages) <> 1 OR v_languages[1] = 'ANY' THEN
        RAISE EXCEPTION 'Listing % must have exactly one specific language',
          v_card_id;
      END IF;
      v_listing_language := v_languages[1];

      INSERT INTO public.user_cards (user_id, card_id, type, language)
      VALUES (v_user_id, v_card_id, 'listing', v_listing_language);

      IF v_listing->'trade_conditions' IS NOT NULL
         AND v_listing->'trade_conditions' <> 'null'::jsonb THEN
        IF jsonb_typeof(v_listing->'trade_conditions') <> 'array' THEN
          RAISE EXCEPTION 'Trade conditions of listing % must be an array',
            v_card_id;
        END IF;

        SELECT rarity INTO v_listing_rarity
        FROM public.cards WHERE id = v_card_id;

        FOR v_condition IN
          SELECT * FROM jsonb_array_elements(v_listing->'trade_conditions')
        LOOP
          v_condition_card_id := v_condition->>'card_id';
          IF v_condition_card_id IS NULL OR v_condition_card_id = '' THEN
            RAISE EXCEPTION 'Each trade condition of listing % needs a card_id',
              v_card_id;
          END IF;
          IF v_condition_card_id = v_card_id THEN
            RAISE EXCEPTION 'Listing % cannot be its own trade condition',
              v_card_id;
          END IF;

          SELECT rarity INTO v_condition_rarity
          FROM public.cards WHERE id = v_condition_card_id;
          IF v_listing_rarity IS NULL
             OR v_condition_rarity IS DISTINCT FROM v_listing_rarity THEN
            RAISE EXCEPTION
              'Trade condition % must be the same rarity as listing %',
              v_condition_card_id, v_card_id;
          END IF;

          -- A repeat could mix "any language" with specific languages.
          IF EXISTS (SELECT 1 FROM public.trade_conditions
                     WHERE user_id = v_user_id
                       AND listed_card_id = v_card_id
                       AND wanted_card_id = v_condition_card_id) THEN
            RAISE EXCEPTION
              'Trade condition % appears more than once on listing %',
              v_condition_card_id, v_card_id;
          END IF;

          v_condition_languages := public._collection_languages(
            v_condition->'languages',
            format('Trade condition %s of listing %s',
              v_condition_card_id, v_card_id));

          INSERT INTO public.trade_conditions
            (user_id, listed_card_id, wanted_card_id, wanted_language)
          SELECT v_user_id, v_card_id, v_condition_card_id, l
          FROM unnest(v_condition_languages) l;
        END LOOP;
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- Reads a languages array and rejects one that is empty or mixes "any
-- language" with specific languages. Language codes themselves are checked by
-- the tables' constraints.
CREATE OR REPLACE FUNCTION public._collection_languages(
  p_languages JSONB,
  p_what TEXT
)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_languages TEXT[];
BEGIN
  IF p_languages IS NULL OR jsonb_typeof(p_languages) <> 'array' THEN
    RAISE EXCEPTION '% needs a languages array', p_what;
  END IF;

  SELECT coalesce(array_agg(DISTINCT l), '{}') INTO v_languages
  FROM jsonb_array_elements_text(p_languages) l;

  IF cardinality(v_languages) = 0 THEN
    RAISE EXCEPTION '% needs at least one language', p_what;
  END IF;
  IF 'ANY' = ANY (v_languages) AND cardinality(v_languages) > 1 THEN
    RAISE EXCEPTION '% cannot mix "any language" with specific languages',
      p_what;
  END IF;

  RETURN v_languages;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.save_collection_changes(JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_collection_changes(JSONB)
  TO authenticated;

-- Helper only: callable from save_collection_changes, not through the API.
REVOKE EXECUTE ON FUNCTION public._collection_languages(JSONB, TEXT)
  FROM PUBLIC, anon, authenticated;

COMMIT;
