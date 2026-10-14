-- Verifies save_collection_changes (see save_collection_changes.sql, step 3).
--
-- 1. Find a user id. Users who signed in anonymously have no email, so look
--    one up by player name:
--      SELECT user_id, player_name FROM public.profiles
--      WHERE player_name = 'YourPlayerName';
--    or list them all with
--      SELECT id, is_anonymous, created_at FROM auth.users ORDER BY created_at;
-- 2. Replace PUT-YOUR-USER-ID-HERE below with it. Don't commit the id.
-- 3. Run this whole file in the SQL editor. It acts as that user, saves and
--    rejects test edits, checks each result and ROLLS BACK at the end: the
--    user's collection is not changed. Expect one result row reading
--    "save_collection_changes: all checks passed". A failed check shows an
--    error starting "Check failed:" instead.

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
  v_rarity TEXT;
  v_listed TEXT;      -- listed in the checks
  v_same TEXT;        -- same rarity as v_listed
  v_other TEXT;       -- a different rarity
  v_wished TEXT;      -- wishlisted in the checks
  v_rejected BOOLEAN;
  v_count INT;
  v_cases JSONB;
  v_case JSONB;
BEGIN
  IF auth.uid() IS DISTINCT FROM v_user THEN
    RAISE EXCEPTION 'Check failed: not acting as %, put your user id in', v_user;
  END IF;

  SELECT rarity INTO v_rarity
  FROM cards GROUP BY rarity HAVING count(*) >= 3
  ORDER BY count(*) DESC LIMIT 1;
  SELECT id INTO v_listed FROM cards WHERE rarity = v_rarity ORDER BY id LIMIT 1;
  SELECT id INTO v_same FROM cards
  WHERE rarity = v_rarity AND id <> v_listed ORDER BY id LIMIT 1;
  SELECT id INTO v_wished FROM cards
  WHERE rarity = v_rarity AND id NOT IN (v_listed, v_same) ORDER BY id LIMIT 1;
  SELECT id INTO v_other FROM cards WHERE rarity <> v_rarity ORDER BY id LIMIT 1;

  -- A valid multi-card save -------------------------------------------------
  PERFORM save_collection_changes(jsonb_build_array(
    jsonb_build_object('card_id', v_listed, 'wishlist', null,
      'listing', jsonb_build_object(
        'languages', jsonb_build_array('ENG'),
        'trade_conditions', jsonb_build_array(
          jsonb_build_object('card_id', v_same,
                             'languages', jsonb_build_array('ANY'))))),
    jsonb_build_object('card_id', v_wished, 'listing', null,
      'wishlist', jsonb_build_object(
        'languages', jsonb_build_array('JPN', 'KOR'))),
    jsonb_build_object('card_id', v_other, 'wishlist', null, 'listing', null)
  ));

  IF NOT EXISTS (SELECT 1 FROM user_cards WHERE user_id = v_user
      AND card_id = v_listed AND type = 'listing' AND language = 'ENG')
    OR (SELECT count(*) FROM user_cards
        WHERE user_id = v_user AND card_id = v_listed) <> 1 THEN
    RAISE EXCEPTION 'Check failed: listing was not saved as one ENG row';
  END IF;
  IF (SELECT array_agg(language ORDER BY language) FROM user_cards
      WHERE user_id = v_user AND card_id = v_wished AND type = 'wishlist')
     IS DISTINCT FROM ARRAY['JPN', 'KOR'] THEN
    RAISE EXCEPTION 'Check failed: wishlist entry was not saved in JPN and KOR';
  END IF;
  IF EXISTS (SELECT 1 FROM user_cards
             WHERE user_id = v_user AND card_id = v_other) THEN
    RAISE EXCEPTION 'Check failed: removed card still has rows';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM trade_conditions WHERE user_id = v_user
      AND listed_card_id = v_listed AND wanted_card_id = v_same
      AND wanted_language = 'ANY') THEN
    RAISE EXCEPTION 'Check failed: trade condition was not saved';
  END IF;

  -- A language change keeps the trade conditions ----------------------------
  PERFORM save_collection_changes(jsonb_build_array(
    jsonb_build_object('card_id', v_listed, 'wishlist', null,
      'listing', jsonb_build_object(
        'languages', jsonb_build_array('FRA'),
        'trade_conditions', jsonb_build_array(
          jsonb_build_object('card_id', v_same,
                             'languages', jsonb_build_array('ANY')))))));
  IF (SELECT language FROM user_cards WHERE user_id = v_user
      AND card_id = v_listed AND type = 'listing') IS DISTINCT FROM 'FRA'
    OR (SELECT count(*) FROM trade_conditions
        WHERE user_id = v_user AND listed_card_id = v_listed) <> 1 THEN
    RAISE EXCEPTION 'Check failed: language change lost the trade conditions';
  END IF;

  -- Each invalid save is rejected and changes nothing -----------------------
  -- Every case also re-lists v_listed in KOR first, to show that a rejected
  -- save leaves even its valid cards untouched.
  v_cases := jsonb_build_array(
    jsonb_build_object('name', 'both a wishlist entry and a listing',
      'change', jsonb_build_object('card_id', v_wished,
        'wishlist', jsonb_build_object('languages', jsonb_build_array('ENG')),
        'listing', jsonb_build_object('languages', jsonb_build_array('ENG'),
                                      'trade_conditions', '[]'::jsonb))),
    jsonb_build_object('name', 'listing with two languages',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', jsonb_build_array('ENG', 'JPN'),
          'trade_conditions', '[]'::jsonb))),
    jsonb_build_object('name', 'listing in "any language"',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', jsonb_build_array('ANY'),
          'trade_conditions', '[]'::jsonb))),
    jsonb_build_object('name', 'listing without a language',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', '[]'::jsonb, 'trade_conditions', '[]'::jsonb))),
    jsonb_build_object('name', 'wishlist mixing "any" and specific',
      'change', jsonb_build_object('card_id', v_wished, 'listing', null,
        'wishlist', jsonb_build_object(
          'languages', jsonb_build_array('ANY', 'ENG')))),
    jsonb_build_object('name', 'trade condition mixing "any" and specific',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', jsonb_build_array('ENG'),
          'trade_conditions', jsonb_build_array(jsonb_build_object(
            'card_id', v_same,
            'languages', jsonb_build_array('ANY', 'JPN')))))),
    jsonb_build_object('name', 'trade condition repeated to mix languages',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', jsonb_build_array('ENG'),
          'trade_conditions', jsonb_build_array(
            jsonb_build_object('card_id', v_same,
                               'languages', jsonb_build_array('ANY')),
            jsonb_build_object('card_id', v_same,
                               'languages', jsonb_build_array('JPN')))))),
    jsonb_build_object('name', 'trade condition of another rarity',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', jsonb_build_array('ENG'),
          'trade_conditions', jsonb_build_array(jsonb_build_object(
            'card_id', v_other, 'languages', jsonb_build_array('ANY')))))),
    jsonb_build_object('name', 'trade condition on the listing itself',
      'change', jsonb_build_object('card_id', v_wished, 'wishlist', null,
        'listing', jsonb_build_object(
          'languages', jsonb_build_array('ENG'),
          'trade_conditions', jsonb_build_array(jsonb_build_object(
            'card_id', v_wished, 'languages', jsonb_build_array('ANY')))))),
    jsonb_build_object('name', 'the same card twice',
      'change', jsonb_build_object('card_id', v_listed, 'listing', null,
        'wishlist', jsonb_build_object(
          'languages', jsonb_build_array('ANY'))))
  );

  FOR v_case IN SELECT * FROM jsonb_array_elements(v_cases) LOOP
    v_rejected := false;
    BEGIN
      PERFORM save_collection_changes(jsonb_build_array(
        jsonb_build_object('card_id', v_listed, 'wishlist', null,
          'listing', jsonb_build_object(
            'languages', jsonb_build_array('KOR'),
            'trade_conditions', '[]'::jsonb)),
        v_case->'change'));
    EXCEPTION WHEN raise_exception THEN
      v_rejected := true;
    END;

    IF NOT v_rejected THEN
      RAISE EXCEPTION 'Check failed: % was accepted', v_case->>'name';
    END IF;
    IF (SELECT language FROM user_cards WHERE user_id = v_user
        AND card_id = v_listed AND type = 'listing') IS DISTINCT FROM 'FRA'
      OR (SELECT count(*) FROM trade_conditions
          WHERE user_id = v_user AND listed_card_id = v_listed) <> 1
      OR (SELECT count(*) FROM user_cards
          WHERE user_id = v_user AND card_id = v_wished) <> 2 THEN
      RAISE EXCEPTION 'Check failed: rejected save (%) changed rows',
        v_case->>'name';
    END IF;
  END LOOP;

  -- A listing that becomes a wishlist entry loses its trade conditions ------
  PERFORM save_collection_changes(jsonb_build_array(
    jsonb_build_object('card_id', v_listed, 'listing', null,
      'wishlist', jsonb_build_object('languages', jsonb_build_array('FRA')))));
  SELECT count(*) INTO v_count FROM trade_conditions
  WHERE user_id = v_user AND listed_card_id = v_listed;
  IF v_count <> 0 OR NOT EXISTS (SELECT 1 FROM user_cards WHERE user_id = v_user
      AND card_id = v_listed AND type = 'wishlist' AND language = 'FRA') THEN
    RAISE EXCEPTION 'Check failed: listing to wishlist kept trade conditions';
  END IF;

END;
$$;

-- Only reached when every check above passed. The SQL editor shows this row
-- as the result; it does not show notices.
SELECT 'save_collection_changes: all checks passed' AS result;

ROLLBACK;
