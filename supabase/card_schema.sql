create table cards (
    id         text primary key,
    name       text not null,
    type       text,
    rarity     text,
    pack       text,
    image      text,
    fullart    boolean default false,
    ex         boolean default false,
    updated_at timestamptz default now()
);

ALTER TABLE cards ENABLE ROW LEVEL SECURITY;

/* RLS: Allow authenticated users to read cards */
CREATE POLICY "Authenticated users can read cards"
ON cards FOR SELECT
TO authenticated
USING (true);