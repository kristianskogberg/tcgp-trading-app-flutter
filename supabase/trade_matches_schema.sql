-- Drop old signatures before creating new versions
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[]);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[]);
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid, text[], boolean);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid, text[], boolean);

CREATE OR REPLACE FUNCTION get_trade_matches_for_wanted(p_card_id text, p_user_id uuid, p_languages text[], p_fullart_only boolean DEFAULT false)
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text)
LANGUAGE sql STABLE
AS $$
  SELECT DISTINCT uc_other.card_id,
    uc_own.user_id,
    p.player_name,
    p.friend_id,
    p.icon,
    p.last_active_at,
    uc_other.language
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
  JOIN cards c
    ON c.id = uc_other.card_id
   AND c.rarity = target.rarity
  WHERE uc_me.user_id = p_user_id
    AND uc_me.card_id = p_card_id
    AND uc_me.type = 'wishlist'
    -- Language compatibility between current user's wishlist entry and other user's owned entry for the same card:
    AND (
         uc_me.language = 'ANY'
      OR uc_own.language = 'ANY'
      OR uc_me.language = uc_own.language
    )
    AND (NOT p_fullart_only OR c.fullart = true);
$$;

CREATE OR REPLACE FUNCTION get_trade_matches_for_owned(p_card_id text, p_user_id uuid, p_languages text[], p_fullart_only boolean DEFAULT false)
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text)
LANGUAGE sql STABLE
AS $$
  SELECT DISTINCT uc_other.card_id,
    uc_want.user_id,
    p.player_name,
    p.friend_id,
    p.icon,
    p.last_active_at,
    uc_other.language
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
  JOIN cards c
    ON c.id = uc_other.card_id
   AND c.rarity = target.rarity
  WHERE uc_me.user_id = p_user_id
    AND uc_me.card_id = p_card_id
    AND uc_me.type = 'owned'
    -- Language compatibility between current user's owned entry and other user's wishlist entry for the same card:
    AND (
         uc_me.language = 'ANY'
      OR uc_want.language = 'ANY'
      OR uc_me.language = uc_want.language
    )
    AND (NOT p_fullart_only OR c.fullart = true);
$$;
