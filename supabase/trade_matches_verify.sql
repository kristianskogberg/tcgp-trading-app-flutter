-- Verifies get_trade_matches (see trade_matches_schema.sql, step 2).
--
-- 1. Find a user id. Users who signed in anonymously have no email, so look
--    one up by player name:
--      SELECT user_id, player_name FROM public.profiles
--      WHERE player_name = 'YourPlayerName';
--    or list them all with
--      SELECT id, is_anonymous, created_at FROM auth.users ORDER BY created_at;
-- 2. Replace PUT-YOUR-USER-ID-HERE below with it. Don't commit the id.
-- 3. Run this whole file in the SQL editor. It creates test players with
--    collections on cards nobody has in their collection yet, gives your
--    user a few test listings and wishlist entries on those cards, checks the
--    trade matches as your user and ROLLS BACK at the end: nothing is kept.
--    Expect one result row reading "get_trade_matches: all checks passed".
--    A failed check shows an error starting "Check failed:" instead.

BEGIN;

SELECT set_config('verify.user_id', 'PUT-YOUR-USER-ID-HERE', true);
SELECT set_config(
  'request.jwt.claims',
  json_build_object('sub', current_setting('verify.user_id'),
                    'role', 'authenticated')::text,
  true);

DO $$
DECLARE
  v_me UUID := current_setting('verify.user_id')::uuid;
  v_rarity TEXT;
  v_cards TEXT[];
  -- Cards, all of one rarity, that no collection holds yet.
  r TEXT; s1 TEXT; s2 TEXT; s3 TEXT; s4 TEXT; s5 TEXT; s6 TEXT;
  t TEXT; y1 TEXT; y2 TEXT; y3 TEXT; y4 TEXT;
  u TEXT; y5 TEXT; y6 TEXT; m TEXT; n TEXT; y7 TEXT; y8 TEXT;
  v_labels TEXT[] := ARRAY['P1', 'P2', 'P3', 'P4', 'P5', 'Q1', 'Q2',
                           'W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8',
                           'K1', 'K2', 'K3', 'K4', 'K5', 'K6'];
  v_players JSONB := '{}'::jsonb;  -- label -> test player id
  v_label TEXT;
  v_got TEXT[];
  v_page TEXT[];
BEGIN
  IF auth.uid() IS DISTINCT FROM v_me THEN
    RAISE EXCEPTION 'Check failed: not acting as %, put your user id in', v_me;
  END IF;
  IF to_regprocedure('public.get_trade_matches_for_wanted(text,text[],boolean,integer,integer)') IS NOT NULL
    OR to_regprocedure('public.get_trade_matches_for_listing(text,text[],boolean,integer,integer)') IS NOT NULL THEN
    RAISE EXCEPTION 'Check failed: an old get_trade_matches_for_* function still exists';
  END IF;

  SELECT c.rarity, array_agg(c.id ORDER BY c.id) INTO v_rarity, v_cards
  FROM cards c
  WHERE NOT EXISTS (SELECT 1 FROM user_cards uc WHERE uc.card_id = c.id)
    AND NOT EXISTS (SELECT 1 FROM trade_conditions tc
                    WHERE c.id IN (tc.listed_card_id, tc.wanted_card_id))
  GROUP BY c.rarity HAVING count(*) >= 19
  ORDER BY count(*) DESC LIMIT 1;
  IF v_rarity IS NULL THEN
    RAISE EXCEPTION 'Check failed: no rarity has 19 cards outside every collection';
  END IF;
  r := v_cards[1];  s1 := v_cards[2];  s2 := v_cards[3];  s3 := v_cards[4];
  s4 := v_cards[5]; s5 := v_cards[6];  s6 := v_cards[7];  t := v_cards[8];
  y1 := v_cards[9]; y2 := v_cards[10]; y3 := v_cards[11]; y4 := v_cards[12];
  u := v_cards[13]; y5 := v_cards[14]; y6 := v_cards[15]; m := v_cards[16];
  n := v_cards[17]; y7 := v_cards[18]; y8 := v_cards[19];

  -- Test players. K5 and K6 were active longest ago, so they sort last.
  FOREACH v_label IN ARRAY v_labels LOOP
    v_players := v_players || jsonb_build_object(v_label, gen_random_uuid());
    INSERT INTO auth.users (id, aud, role)
    VALUES ((v_players->>v_label)::uuid, 'authenticated', 'authenticated');
    INSERT INTO profiles (user_id, player_name, friend_id, last_active_at)
    VALUES ((v_players->>v_label)::uuid, 'verify ' || v_label,
            (random() * 1e15)::bigint,
            CASE WHEN v_label IN ('K5', 'K6') THEN now() - interval '30 days'
                 ELSE now() END);
  END LOOP;

  INSERT INTO user_cards (user_id, card_id, type, language)
  SELECT (v_players->>p)::uuid, card, kind, lang
  FROM (VALUES
    -- Receiving r. The other players accept s1..s5 as in the language table.
    ('P1', r, 'listing', 'JPN'), ('P1', s1, 'wishlist', 'JPN'),
    ('P2', r, 'listing', 'JPN'), ('P2', s2, 'wishlist', 'JPN'),
    ('P3', r, 'listing', 'JPN'), ('P3', s3, 'wishlist', 'JPN'),
    ('P4', r, 'listing', 'JPN'), ('P4', s4, 'wishlist', 'ANY'),
    ('P5', r, 'listing', 'JPN'), ('P5', s5, 'wishlist', 'ANY'),
    -- Q1 lists r in a language the user did not wishlist it in.
    ('Q1', r, 'listing', 'KOR'), ('Q1', s3, 'wishlist', 'JPN'),
    -- Q2's listing of r has a trade condition (below), so their wishlist
    -- doesn't count for it.
    ('Q2', r, 'listing', 'JPN'), ('Q2', s3, 'wishlist', 'JPN'),
    -- Sending t, which the user lists in ENG.
    ('W1', t, 'wishlist', 'JPN'), ('W1', y1, 'listing', 'FRA'),
    ('W2', t, 'wishlist', 'ENG'), ('W2', y2, 'listing', 'KOR'),
    ('W3', t, 'wishlist', 'ANY'), ('W3', y3, 'listing', 'KOR'),
    ('W4', t, 'wishlist', 'ENG'), ('W4', y4, 'listing', 'KOR'),
    -- Sending u, which the user lists in ENG accepting only y5.
    ('W5', u, 'wishlist', 'ENG'), ('W5', y5, 'listing', 'DEU'),
    ('W6', u, 'wishlist', 'ENG'), ('W6', y6, 'listing', 'DEU'),
    -- Sending n, which the user hasn't listed: they send it in whatever the
    -- other player accepts.
    ('W7', n, 'wishlist', 'ENG'), ('W7', n, 'wishlist', 'JPN'),
    ('W7', y7, 'listing', 'FRA'),
    ('W8', n, 'wishlist', 'ANY'), ('W8', y8, 'listing', 'FRA'),
    -- Receiving m, which the user hasn't wishlisted. K1..K4 accept s3, which
    -- the user doesn't list; K5 and K6 accept s2, which they do.
    ('K1', m, 'listing', 'ENG'), ('K1', s3, 'wishlist', 'ANY'),
    ('K2', m, 'listing', 'ENG'), ('K2', s3, 'wishlist', 'ANY'),
    ('K3', m, 'listing', 'ENG'), ('K3', s3, 'wishlist', 'ANY'),
    ('K4', m, 'listing', 'ENG'), ('K4', s3, 'wishlist', 'ANY'),
    ('K5', m, 'listing', 'ENG'), ('K5', s2, 'wishlist', 'ANY'),
    ('K6', m, 'listing', 'ENG'), ('K6', s2, 'wishlist', 'ANY')
  ) AS rows(p, card, kind, lang);

  INSERT INTO trade_conditions (user_id, listed_card_id, wanted_card_id, wanted_language)
  VALUES ((v_players->>'Q2')::uuid, r, s6, 'ANY'),
         -- W3 only gives y3 for y1, not for t.
         ((v_players->>'W3')::uuid, y3, y1, 'ANY'),
         (v_me, u, y5, 'ANY');

  -- The user's side.
  INSERT INTO user_cards (user_id, card_id, type, language) VALUES
    (v_me, r, 'wishlist', 'ENG'), (v_me, r, 'wishlist', 'JPN'),
    (v_me, s1, 'listing', 'ENG'),
    (v_me, s2, 'listing', 'JPN'),
    (v_me, s4, 'listing', 'ENG'),
    (v_me, t, 'listing', 'ENG'),
    (v_me, y2, 'wishlist', 'ANY'),
    (v_me, u, 'listing', 'ENG');

  -- From here on, act as the user, through the API role.
  SET LOCAL ROLE authenticated;

  -- Receiving: the language table, receiver protection and is_perfect -------
  SELECT array_agg(format('%s %s %s %s %s %s', player_name,
           send_card_id, send_language, receive_card_id, receive_language,
           CASE WHEN is_perfect THEN 'perfect' ELSE 'partial' END)
         ORDER BY player_name)
  INTO v_got
  FROM get_trade_matches(r, 'receiving', '{}', false, false, 100, 0)
  WHERE player_name LIKE 'verify %';

  IF v_got IS DISTINCT FROM ARRAY[
    -- P1 accepts s1 in JPN, the user lists it in ENG: hidden.
    format('verify P2 %s JPN %s JPN perfect', s2, r),  -- listed JPN
    format('verify P3 %s JPN %s JPN partial', s3, r),  -- not listed
    format('verify P4 %s ENG %s JPN perfect', s4, r),  -- ANY, listed ENG
    format('verify P5 %s ANY %s JPN partial', s5, r),  -- ANY, not listed
    -- Q1 lists r in KOR, which the user didn't wishlist it in: hidden.
    -- Q2 only accepts its trade condition s6, not its wishlist entry s3.
    format('verify Q2 %s ANY %s JPN partial', s6, r)
  ] THEN
    RAISE EXCEPTION 'Check failed: receiving matches were %', v_got;
  END IF;

  -- Perfect matches come first (in either order: they tie on everything
  -- but the random test player ids).
  SELECT array_agg(player_name) INTO v_got
  FROM get_trade_matches(r, 'receiving', '{}', false, false, 100, 0)
  WHERE player_name LIKE 'verify %';
  IF (SELECT array_agg(x ORDER BY x) FROM unnest(v_got[1:2]) x)
     IS DISTINCT FROM ARRAY['verify P2', 'verify P4'] THEN
    RAISE EXCEPTION 'Check failed: perfect matches not first: %', v_got;
  END IF;

  -- Receiving with p_only_mine: only cards the user lists.
  SELECT array_agg(player_name ORDER BY player_name) INTO v_got
  FROM get_trade_matches(r, 'receiving', '{}', false, true, 100, 0)
  WHERE player_name LIKE 'verify %';
  IF v_got IS DISTINCT FROM ARRAY['verify P2', 'verify P4'] THEN
    RAISE EXCEPTION 'Check failed: receiving only-mine matches were %', v_got;
  END IF;

  -- Sending: receiver protection and is_perfect -----------------------------
  SELECT array_agg(format('%s %s %s %s %s %s', player_name,
           send_card_id, send_language, receive_card_id, receive_language,
           CASE WHEN is_perfect THEN 'perfect' ELSE 'partial' END)
         ORDER BY player_name)
  INTO v_got
  FROM get_trade_matches(t, 'sending', '{}', false, false, 100, 0)
  WHERE player_name LIKE 'verify %';

  IF v_got IS DISTINCT FROM ARRAY[
    -- W1 wishlists t in JPN, the user lists it in ENG: hidden.
    format('verify W2 %s ENG %s KOR perfect', t, y2),
    -- W3's trade condition on y3 doesn't accept t: hidden.
    format('verify W4 %s ENG %s KOR partial', t, y4)
  ] THEN
    RAISE EXCEPTION 'Check failed: sending matches were %', v_got;
  END IF;

  -- Sending with p_only_mine: only cards the user wishlists.
  SELECT array_agg(player_name ORDER BY player_name) INTO v_got
  FROM get_trade_matches(t, 'sending', '{}', false, true, 100, 0)
  WHERE player_name LIKE 'verify %';
  IF v_got IS DISTINCT FROM ARRAY['verify W2'] THEN
    RAISE EXCEPTION 'Check failed: sending only-mine matches were %', v_got;
  END IF;

  -- The user's own trade conditions narrow what they receive for u.
  SELECT array_agg(player_name ORDER BY player_name) INTO v_got
  FROM get_trade_matches(u, 'sending', '{}', false, false, 100, 0)
  WHERE player_name LIKE 'verify %';
  IF v_got IS DISTINCT FROM ARRAY['verify W5'] THEN
    RAISE EXCEPTION 'Check failed: the user''s trade conditions gave %', v_got;
  END IF;

  -- Sending a card the user hasn't listed: partial matches in what the other
  -- player accepts, one per card they list.
  SELECT array_agg(format('%s %s %s %s %s %s', player_name,
           send_card_id, send_language, receive_card_id, receive_language,
           CASE WHEN is_perfect THEN 'perfect' ELSE 'partial' END)
         ORDER BY player_name)
  INTO v_got
  FROM get_trade_matches(n, 'sending', '{}', false, false, 100, 0)
  WHERE player_name LIKE 'verify %';
  IF v_got IS DISTINCT FROM ARRAY[
    format('verify W7 %s ENG %s FRA partial', n, y7),
    format('verify W8 %s ANY %s FRA partial', n, y8)
  ] THEN
    RAISE EXCEPTION 'Check failed: sending unlisted matches were %', v_got;
  END IF;

  -- Paging with p_only_mine returns full pages ------------------------------
  -- K1..K4 sort before K5 and K6 but are filtered out, so filtering after
  -- LIMIT would make the first pages empty.
  v_got := '{}';
  FOR i IN 0..2 LOOP
    SELECT array_agg(player_name) INTO v_page
    FROM get_trade_matches(m, 'receiving', '{}', false, true, 1, i);
    IF i < 2 AND coalesce(array_length(v_page, 1), 0) <> 1 THEN
      RAISE EXCEPTION 'Check failed: only-mine page % had % rows', i, v_page;
    END IF;
    IF i = 2 AND v_page IS NOT NULL THEN
      RAISE EXCEPTION 'Check failed: only-mine page 2 should be empty, was %', v_page;
    END IF;
    v_got := v_got || coalesce(v_page, '{}');
  END LOOP;
  IF v_got IS DISTINCT FROM ARRAY['verify K5', 'verify K6']
    AND v_got IS DISTINCT FROM ARRAY['verify K6', 'verify K5'] THEN
    RAISE EXCEPTION 'Check failed: only-mine pages were %', v_got;
  END IF;

  -- An unknown direction is rejected.
  BEGIN
    PERFORM get_trade_matches(r, 'wanted', '{}', false, false, 1, 0);
    RAISE EXCEPTION 'Check failed: direction "wanted" was accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'Check failed:%' THEN RAISE; END IF;
  END;
END;
$$;

-- Only reached when every check above passed. The SQL editor shows this row
-- as the result; it does not show notices.
SELECT 'get_trade_matches: all checks passed' AS result;

ROLLBACK;
