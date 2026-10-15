-- Trade matching: get_trade_matches and get_my_pending_proposals (issue #6;
-- "Trade match", "Perfect match", "Partial match" and "Direction" in
-- CONTEXT.md). This file is the definition of record for both functions.
--
-- Hand-run in the Supabase SQL editor.
--
-- Run guide
-- 1. Paste this whole file into the SQL editor and run it. It runs in one
--    transaction, so if anything fails nothing is changed. Running it again
--    is safe.
-- 2. Open supabase/trade_matches_verify.sql, put your own user id in it as
--    the file says, and run it. It builds a few test players and cards'
--    collections, checks every rule below as you, and rolls everything back
--    at the end, so no data is left behind. Expect one result row reading
--    "get_trade_matches: all checks passed". A failed check stops it with an
--    error starting "Check failed:" instead.
-- 3. Ship the app build that calls get_trade_matches. Older builds call
--    get_trade_matches_for_wanted / _for_listing, which this script drops.
--
-- The rule: receiver protection. The other player's side of every trade match
-- is always perfect: they list the card they give, they accept the card they
-- get (a trade condition on that listing if it has any, else a wishlist
-- entry), in compatible card languages. Only the calling user's side may be
-- partial; their own declarations narrow the matches, and the absence of one
-- is permissive:
-- - The card the user receives comes in the other player's listing language.
--   If the user wishlisted it, that language must be one they wishlisted it in
--   (or "any language").
-- - The card the user sends, when they list it, goes in their listing
--   language, which the other player must accept. When that listing has trade
--   conditions, the received card must be one of them.
-- - The card the user sends, when they don't list it, goes in exactly the
--   language the other player accepts, which may be ANY.
-- A trade match is perfect when the user lists the card they send and
-- wishlists the card they receive.

BEGIN;

DROP FUNCTION IF EXISTS public.get_trade_matches_for_wanted(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_listing(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS public.get_trade_matches_for_owned(TEXT, TEXT[], BOOLEAN, INTEGER, INTEGER);

-- ---------------------------------------------------------------------------
-- get_trade_matches
-- ---------------------------------------------------------------------------
-- p_direction: 'receiving' (the user would receive p_card_id) or 'sending'
--   (the user would send it).
-- p_languages: the other card's languages as the other player declared them;
--   empty or NULL means every language. ANY always passes.
-- p_fullart_only: only full-art trainer cards as the other card.
-- p_only_mine: receiving, only matches where the user lists the card they
--   send; sending, only matches where they wishlist the card they receive.
-- One row per other player, other card and other card language. Perfect
-- matches come first.

CREATE OR REPLACE FUNCTION public.get_trade_matches(
  p_card_id TEXT,
  p_direction TEXT,
  p_languages TEXT[],
  p_fullart_only BOOLEAN,
  p_only_mine BOOLEAN,
  p_limit INTEGER,
  p_offset INTEGER
)
RETURNS TABLE(
  send_card_id TEXT,
  send_language TEXT,
  receive_card_id TEXT,
  receive_language TEXT,
  user_id UUID,
  player_name TEXT,
  friend_id TEXT,
  icon TEXT,
  last_active_at TIMESTAMPTZ,
  is_perfect BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
BEGIN
  IF p_direction IS NULL OR p_direction NOT IN ('receiving', 'sending') THEN
    RAISE EXCEPTION 'Direction must be receiving or sending, not %', p_direction;
  END IF;

  RETURN QUERY
  WITH
  -- Every swap another player's collection allows that involves p_card_id:
  -- a listing of theirs and a card they accept for it.
  their_swaps AS (
    -- A listing with trade conditions accepts exactly its conditions.
    SELECT listing.user_id,
           listing.card_id AS listed_card,
           listing.language AS listed_language,
           tc.wanted_card_id AS accepted_card,
           tc.wanted_language AS accepted_language
    FROM user_cards listing
    JOIN trade_conditions tc
      ON tc.user_id = listing.user_id
     AND tc.listed_card_id = listing.card_id
    WHERE listing.type = 'listing'
      AND listing.user_id <> auth.uid()
      AND ((p_direction = 'receiving' AND listing.card_id = p_card_id)
        OR (p_direction = 'sending' AND tc.wanted_card_id = p_card_id))

    UNION ALL

    -- A listing without trade conditions accepts the player's wishlist.
    SELECT listing.user_id,
           listing.card_id,
           listing.language,
           wish.card_id,
           wish.language
    FROM user_cards listing
    JOIN user_cards wish
      ON wish.user_id = listing.user_id
     AND wish.type = 'wishlist'
     AND wish.card_id <> listing.card_id
    WHERE listing.type = 'listing'
      AND listing.user_id <> auth.uid()
      AND ((p_direction = 'receiving' AND listing.card_id = p_card_id)
        OR (p_direction = 'sending' AND wish.card_id = p_card_id))
      AND NOT EXISTS (
        SELECT 1 FROM trade_conditions tc
        WHERE tc.user_id = listing.user_id AND tc.listed_card_id = listing.card_id
      )
  ),
  -- The same swaps from the user's side: they send the accepted card and
  -- receive the listed one. Adds what the user's collection says about both.
  candidates AS (
    SELECT s.user_id,
           s.accepted_card AS send_card,
           s.accepted_language,
           s.listed_card AS receive_card,
           s.listed_language AS receive_language,
           CASE p_direction WHEN 'receiving' THEN s.accepted_card
                            ELSE s.listed_card END AS other_card,
           CASE p_direction WHEN 'receiving' THEN s.accepted_language
                            ELSE s.listed_language END AS other_language,
           my_listing.language AS my_listing_language,
           my_conditions.has_any AS my_listing_has_conditions,
           my_conditions.allows_receive AS my_conditions_allow_receive,
           my_wish.has_any AS wishlists_receive,
           my_wish.in_language AS wishlists_receive_in_language
    FROM their_swaps s
    JOIN cards listed ON listed.id = s.listed_card
    JOIN cards accepted
      ON accepted.id = s.accepted_card
     AND accepted.rarity = listed.rarity
    LEFT JOIN user_cards my_listing
      ON my_listing.user_id = auth.uid()
     AND my_listing.card_id = s.accepted_card
     AND my_listing.type = 'listing'
    CROSS JOIN LATERAL (
      SELECT count(*) > 0 AS has_any,
             COALESCE(bool_or(
               tc.wanted_card_id = s.listed_card
               AND (tc.wanted_language = 'ANY'
                 OR s.listed_language = 'ANY'
                 OR tc.wanted_language = s.listed_language)), false) AS allows_receive
      FROM trade_conditions tc
      WHERE tc.user_id = auth.uid() AND tc.listed_card_id = s.accepted_card
    ) my_conditions
    CROSS JOIN LATERAL (
      SELECT count(*) > 0 AS has_any,
             COALESCE(bool_or(
               w.language = 'ANY'
               OR s.listed_language = 'ANY'
               OR w.language = s.listed_language), false) AS in_language
      FROM user_cards w
      WHERE w.user_id = auth.uid()
        AND w.card_id = s.listed_card
        AND w.type = 'wishlist'
    ) my_wish
  ),
  -- Drop what the user's own declarations rule out.
  allowed AS (
    SELECT c.*,
           COALESCE(c.my_listing_language, c.accepted_language) AS send_language,
           c.my_listing_language IS NOT NULL AS lists_send
    FROM candidates c
    WHERE (NOT c.wishlists_receive OR c.wishlists_receive_in_language)
      AND (c.my_listing_language IS NULL OR (
            (c.my_listing_language = 'ANY'
              OR c.accepted_language = 'ANY'
              OR c.my_listing_language = c.accepted_language)
            AND (NOT c.my_listing_has_conditions OR c.my_conditions_allow_receive)))
  ),
  -- Apply the filters and keep one row per other player, other card and the
  -- other card's language as the trade match shows it. (Sending, an unlisted
  -- card the other player wishlists in several languages would otherwise
  -- repeat each card they list; the first send language is kept.)
  filtered AS (
    SELECT DISTINCT ON (a.user_id, a.send_card, a.receive_card,
                        CASE p_direction WHEN 'receiving' THEN a.send_language
                                         ELSE a.receive_language END)
           a.user_id,
           a.send_card,
           a.send_language,
           a.receive_card,
           a.receive_language,
           a.lists_send AND a.wishlists_receive AS perfect
    FROM allowed a
    JOIN cards other_card ON other_card.id = a.other_card
    WHERE (array_length(p_languages, 1) IS NULL
        OR a.other_language = 'ANY'
        OR a.other_language = ANY(p_languages))
      AND (NOT p_fullart_only
        OR (other_card.fullart = true AND other_card.type = 'Trainer'))
      AND (NOT p_only_mine OR CASE p_direction
            WHEN 'receiving' THEN a.lists_send
            ELSE a.wishlists_receive END)
    ORDER BY a.user_id, a.send_card, a.receive_card,
             CASE p_direction WHEN 'receiving' THEN a.send_language
                              ELSE a.receive_language END,
             a.send_language
  ),
  ranked AS (
    SELECT f.*,
           p.player_name AS p_player_name,
           p.friend_id::text AS p_friend_id,
           p.icon AS p_icon,
           p.last_active_at AS p_last_active_at,
           -- The other player could also make a perfect trade with the user
           -- the opposite way round: receiving, they list another card of
           -- this rarity the user wishlists; sending, they wishlist another
           -- one the user lists. For ordering only.
           EXISTS (
             SELECT 1
             FROM user_cards theirs
             JOIN user_cards mine
               ON mine.user_id = auth.uid()
              AND mine.card_id = theirs.card_id
              AND mine.type = CASE p_direction WHEN 'receiving' THEN 'wishlist'
                                               ELSE 'listing' END
             JOIN cards c ON c.id = theirs.card_id
             JOIN cards viewed ON viewed.id = p_card_id AND viewed.rarity = c.rarity
             WHERE theirs.user_id = f.user_id
               AND theirs.type = CASE p_direction WHEN 'receiving' THEN 'listing'
                                                  ELSE 'wishlist' END
               AND theirs.card_id <> p_card_id
               AND (mine.language = 'ANY'
                 OR theirs.language = 'ANY'
                 OR mine.language = theirs.language)
           ) AS has_mutual_match
    FROM filtered f
    JOIN profiles p ON p.user_id = f.user_id
  )
  SELECT r.send_card,
         r.send_language,
         r.receive_card,
         r.receive_language,
         r.user_id,
         r.p_player_name,
         r.p_friend_id,
         r.p_icon,
         r.p_last_active_at,
         r.perfect
  FROM ranked r
  ORDER BY r.perfect DESC,
           r.has_mutual_match DESC,
           r.p_last_active_at DESC NULLS LAST,
           r.user_id, r.send_card, r.receive_card,
           r.send_language, r.receive_language
  LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_trade_matches(TEXT, TEXT, TEXT[], BOOLEAN, BOOLEAN, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_trade_matches(TEXT, TEXT, TEXT[], BOOLEAN, BOOLEAN, INTEGER, INTEGER) TO authenticated;

-- ---------------------------------------------------------------------------
-- get_my_pending_proposals
-- ---------------------------------------------------------------------------
-- All pending trade proposals the current user sent, parsed from the
-- TRADE:offerCard:offerLang:receiveCard:receiveLang:status message format.

CREATE OR REPLACE FUNCTION public.get_my_pending_proposals()
RETURNS TABLE(other_user_id UUID, offer_card_id TEXT, receive_card_id TEXT)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT
    CASE WHEN c.user_a = auth.uid() THEN c.user_b ELSE c.user_a END AS other_user_id,
    split_part(m.content, ':', 2) AS offer_card_id,
    split_part(m.content, ':', 4) AS receive_card_id
  FROM messages m
  JOIN conversations c ON c.id = m.conversation_id
  WHERE m.sender_id = auth.uid()
    AND m.content LIKE 'TRADE:%'
    AND split_part(m.content, ':', 6) = 'pending';
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_pending_proposals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_pending_proposals() TO authenticated;

COMMIT;
