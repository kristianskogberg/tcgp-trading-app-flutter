create table public.user_cards (
  user_id uuid not null,
  card_id text not null,
  type text not null,
  language text not null default 'ANY'::text,
  created_at timestamp with time zone not null default now(),
  constraint user_cards_pkey primary key (user_id, card_id, type, language),
  constraint user_cards_user_id_card_id_type_language_key unique (user_id, card_id, type, language),
  constraint user_cards_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint user_cards_type_check check (
    (
      type = any (array['wishlist'::text, 'owned'::text])
    )
  ),
  constraint valid_language check (
    (
      language = any (
        array[
          'ANY'::text,
          'ENG'::text,
          'JPN'::text,
          'FRA'::text,
          'ITA'::text,
          'DEU'::text,
          'ESP'::text,
          'POR'::text,
          'CHN'::text,
          'KOR'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_user_cards_card_type on public.user_cards using btree (card_id, type) TABLESPACE pg_default;

create index IF not exists idx_user_cards_user_type on public.user_cards using btree (user_id, type) TABLESPACE pg_default;