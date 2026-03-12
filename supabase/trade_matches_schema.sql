-- Drop old signatures before creating new versions
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[]);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[]);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[], boolean);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[], boolean);

CREATE OR REPLACE FUNCTION get_trade_matches_for_wanted(p_card_id text, p_user_id uuid, p_languages text[], p_fullart_only boolean DEFAULT false)
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text, has_mutual_match boolean)
LANGUAGE sql STABLE
AS $$
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
  -- Check if User A wishlists any card that the other user also owns (mutual trade opportunity)
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
    -- Language compatibility between current user's wishlist entry and other user's owned entry for the same card:
    AND (
         uc_me.language = 'ANY'
      OR uc_own.language = 'ANY'
      OR uc_me.language = uc_own.language
    )
    AND (NOT p_fullart_only OR (c.fullart = true AND c.type = 'Trainer'))
    AND (array_length(p_languages, 1) IS NULL OR uc_other.language = 'ANY' OR uc_other.language = ANY(p_languages));
$$;

CREATE OR REPLACE FUNCTION get_trade_matches_for_owned(p_card_id text, p_user_id uuid, p_languages text[], p_fullart_only boolean DEFAULT false)
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text, has_mutual_match boolean)
LANGUAGE sql STABLE
AS $$
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
  -- Check if User A owns any card that the other user wishlists (mutual trade opportunity)
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
    -- Language compatibility between current user's owned entry and other user's wishlist entry for the same card:
    AND (
         uc_me.language = 'ANY'
      OR uc_want.language = 'ANY'
      OR uc_me.language = uc_want.language
    )
    AND (NOT p_fullart_only OR (c.fullart = true AND c.type = 'Trainer'))
    AND (array_length(p_languages, 1) IS NULL OR uc_other.language = 'ANY' OR uc_other.language = ANY(p_languages));
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
