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