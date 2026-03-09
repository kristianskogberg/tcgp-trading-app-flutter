-- Drop old 2-param signatures before creating new 3-param versions
DROP FUNCTION IF EXISTS get_trade_matches_for_wanted(text, uuid);
DROP FUNCTION IF EXISTS get_trade_matches_for_owned(text, uuid);

-- Finds users who WANT p_card_id, returns their OWNED cards
CREATE OR REPLACE FUNCTION get_trade_matches_for_wanted(p_card_id text, p_user_id uuid, p_languages text[])
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text)
LANGUAGE sql STABLE
AS $$
  SELECT DISTINCT uc_owned.card_id, uc_owned.user_id, p.player_name, p.friend_id, p.icon,
    p.last_active_at, uc_owned.language
  FROM user_cards uc_want
  JOIN user_cards uc_owned ON uc_owned.user_id = uc_want.user_id AND uc_owned.type = 'owned'
  JOIN profiles p ON p.user_id = uc_want.user_id
  WHERE uc_want.card_id = p_card_id
    AND uc_want.type = 'wishlist'
    AND uc_want.user_id != p_user_id
    AND (uc_owned.language = 'ANY' OR uc_owned.language = ANY(p_languages));
$$;

-- Finds users who OWN p_card_id, returns their WISHLIST cards
CREATE OR REPLACE FUNCTION get_trade_matches_for_owned(p_card_id text, p_user_id uuid, p_languages text[])
RETURNS TABLE(card_id text, user_id uuid, player_name text, friend_id text, icon text, last_active_at timestamptz, language text)
LANGUAGE sql STABLE
AS $$
  SELECT DISTINCT uc_wish.card_id, uc_wish.user_id, p.player_name, p.friend_id, p.icon,
    p.last_active_at, uc_wish.language
  FROM user_cards uc_own
  JOIN user_cards uc_wish ON uc_wish.user_id = uc_own.user_id AND uc_wish.type = 'wishlist'
  JOIN profiles p ON p.user_id = uc_own.user_id
  WHERE uc_own.card_id = p_card_id
    AND uc_own.type = 'owned'
    AND uc_own.user_id != p_user_id
    AND (uc_wish.language = 'ANY' OR uc_wish.language = ANY(p_languages));
$$;
