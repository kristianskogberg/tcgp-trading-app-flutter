-- Drop old signatures before creating new versions
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[]);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[]);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[], boolean);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[], boolean);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[], boolean, integer, integer);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[], boolean, integer, integer);

CREATE OR REPLACE FUNCTION get_trade_matches_for_wanted(p_card_id text, p_user_id uuid, p_languages text[], p_fullart_only boolean, p_limit integer, p_offset integer)
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text, has_mutual_match boolean)
LANGUAGE sql STABLE
AS $$
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
     AND uc_own.type = 'owned'
     AND uc_own.user_id != p_user_id
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
       AND uc_a_wish.user_id = p_user_id
       AND uc_a_wish.type = 'wishlist'
      JOIN cards c2 ON c2.id = uc_b_own.card_id AND c2.rarity = target.rarity
      WHERE uc_b_own.user_id = uc_own.user_id
        AND uc_b_own.type = 'owned'
        AND uc_b_own.card_id != p_card_id
        AND (
             uc_a_wish.language = 'ANY'
          OR uc_b_own.language = 'ANY'
          OR uc_a_wish.language = uc_b_own.language
        )
      LIMIT 1
    ) mutual ON true
    WHERE uc_me.user_id = p_user_id
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

    -- Case 2: Other user HAS trade conditions → only show them if current user owns the condition card
    SELECT DISTINCT tc.wanted_card_id AS card_id,
      uc_own.user_id,
      p.player_name,
      p.friend_id,
      p.icon,
      p.last_active_at,
      tc.wanted_language AS language,
      true AS has_mutual_match  -- current user owns the wanted card by definition
    FROM user_cards uc_me
    JOIN user_cards uc_own
      ON uc_own.card_id = p_card_id
     AND uc_own.type = 'owned'
     AND uc_own.user_id != p_user_id
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
    -- Current user must own the condition card in a compatible language
    JOIN user_cards uc_a_own
      ON uc_a_own.user_id = p_user_id
     AND uc_a_own.card_id = tc.wanted_card_id
     AND uc_a_own.type = 'owned'
     AND (
          tc.wanted_language = 'ANY'
       OR uc_a_own.language = 'ANY'
       OR uc_a_own.language = tc.wanted_language
     )
    WHERE uc_me.user_id = p_user_id
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
$$;

CREATE OR REPLACE FUNCTION get_trade_matches_for_owned(p_card_id text, p_user_id uuid, p_languages text[], p_fullart_only boolean, p_limit integer, p_offset integer)
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text, has_mutual_match boolean)
LANGUAGE sql STABLE
AS $$
  SELECT * FROM (
    -- Case 1: Current user has NO trade conditions for this card → use other users' owned cards (existing behaviour)
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
     AND uc_want.user_id != p_user_id
    JOIN profiles p
      ON p.user_id = uc_want.user_id
    JOIN cards target
      ON target.id = p_card_id
    JOIN user_cards uc_other
      ON uc_other.user_id = uc_want.user_id
     AND uc_other.card_id != p_card_id
     AND uc_other.type = 'owned'
    JOIN cards c
      ON c.id = uc_other.card_id
     AND c.rarity = target.rarity
    LEFT JOIN LATERAL (
      SELECT true AS val
      FROM user_cards uc_b_wish
      JOIN user_cards uc_a_own
        ON uc_a_own.card_id = uc_b_wish.card_id
       AND uc_a_own.user_id = p_user_id
       AND uc_a_own.type = 'owned'
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
    WHERE uc_me.user_id = p_user_id
      AND uc_me.card_id = p_card_id
      AND uc_me.type = 'owned'
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
        WHERE tc.user_id = p_user_id AND tc.listed_card_id = p_card_id
      )

    UNION ALL

    -- Case 2: Current user HAS trade conditions → only show other users who own the condition card
    SELECT DISTINCT uc_other_own.card_id,
      uc_want.user_id,
      p.player_name,
      p.friend_id,
      p.icon,
      p.last_active_at,
      uc_other_own.language,
      true AS has_mutual_match  -- other user owns the wanted card by definition
    FROM user_cards uc_me
    JOIN trade_conditions tc
      ON tc.user_id = p_user_id
     AND tc.listed_card_id = p_card_id
    JOIN user_cards uc_want
      ON uc_want.card_id = p_card_id
     AND uc_want.type = 'wishlist'
     AND uc_want.user_id != p_user_id
    JOIN profiles p
      ON p.user_id = uc_want.user_id
    JOIN cards target
      ON target.id = p_card_id
    JOIN cards c
      ON c.id = tc.wanted_card_id
     AND c.rarity = target.rarity
    -- Other user must own the condition card in a compatible language
    JOIN user_cards uc_other_own
      ON uc_other_own.user_id = uc_want.user_id
     AND uc_other_own.card_id = tc.wanted_card_id
     AND uc_other_own.type = 'owned'
     AND (
          tc.wanted_language = 'ANY'
       OR uc_other_own.language = 'ANY'
       OR uc_other_own.language = tc.wanted_language
     )
    WHERE uc_me.user_id = p_user_id
      AND uc_me.card_id = p_card_id
      AND uc_me.type = 'owned'
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
$$;

-- Returns all pending trade proposals sent by the current user.
-- Parses the TRADE: message format to extract card IDs and the other user.
DROP FUNCTION IF EXISTS get_my_pending_proposals();
CREATE OR REPLACE FUNCTION get_my_pending_proposals()
RETURNS TABLE(other_user_id uuid, offer_card_id text, receive_card_id text)
LANGUAGE sql STABLE SECURITY DEFINER
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
