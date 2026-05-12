-- Create table
create table public.trade_conditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listed_card_id text not null,
  wanted_card_id text not null,
  wanted_language text not null default 'ANY',
  created_at timestamptz not null default now(),
  constraint trade_conditions_language_check check (
    wanted_language = any (array['ANY','ENG','JPN','FRA','ITA','DEU','ESP','POR','CHN','KOR'])
  ),
  unique (user_id, listed_card_id, wanted_card_id, wanted_language)
);

  -- Enable RLS
  alter table public.trade_conditions enable row level security;

  -- Anyone authenticated can read trade conditions (needed for trade matching RPCs)
  create policy "Anyone can read trade conditions"
    on public.trade_conditions for select
    using (auth.uid() is not null);

  -- Users can insert their own conditions
  create policy "Users can insert own trade conditions"
    on public.trade_conditions for insert
    with check (auth.uid() = user_id);

  -- Users can delete their own conditions
  create policy "Users can delete own trade conditions"
    on public.trade_conditions for delete
    using (auth.uid() = user_id);

-- Atomic replace of trade conditions for a single listed card.
-- Delete-then-insert from the client can leave the user with no conditions
-- if the insert fails. This RPC does both inside a single transaction,
-- so either the full new set is persisted or nothing changes.
CREATE OR REPLACE FUNCTION set_trade_conditions(
  p_listed_card_id text,
  p_wanted jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
        AND uc.type = 'owned'
    ) THEN
      RAISE EXCEPTION 'Listed card must be owned by the current user';
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
$$;

REVOKE EXECUTE ON FUNCTION set_trade_conditions(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_trade_conditions(text, jsonb) TO authenticated;
