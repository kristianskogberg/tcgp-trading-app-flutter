-- preferred_language: the specific card language a user's new listings
-- start in (issue #5, "Preferred language" in CONTEXT.md).
--
-- Hand-run in the Supabase SQL editor. Adds one nullable column to profiles;
-- existing rows stay unset and the app treats unset as English.
--
-- Run guide
-- 1. Run this BEFORE shipping the app build that reads preferred_language:
--    that build selects the column, and its profile loads fail without it.
--    Older builds don't select it and keep working either way.
-- 2. Paste this whole file into the SQL editor and run it. It runs in one
--    transaction, so if anything fails nothing is changed. Running it again
--    is safe.
-- 3. Check the column and its constraint:
--      SELECT column_name, data_type, is_nullable
--      FROM information_schema.columns
--      WHERE table_schema = 'public' AND table_name = 'profiles'
--        AND column_name = 'preferred_language';
--    Expect one row: preferred_language, text, YES.
--      SELECT pg_get_constraintdef(oid) FROM pg_constraint
--      WHERE conname = 'profiles_preferred_language_check';
--    Expect one row listing the nine specific languages and no 'ANY'.
-- 4. Open supabase/preferred_language_verify.sql, put your own user id in
--    it as the file says, and run it. It sets, clears and rejects preferred
--    languages as you, checks every result, and rolls everything back at the
--    end, so your profile is left exactly as it was. Expect one result row
--    reading "preferred_language: all checks passed". A failed check stops
--    it with an error starting "Check failed:" instead.
-- 5. Ship the app build with the Preferred language setting.
--
-- Users already update their own profile row through the "Users can manage
-- their own profile" policy (rls_hardening.sql), so no policy changes.
-- The allowed values match lib/utils/languages.dart; keep the two in step.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS preferred_language TEXT NULL;

-- "Any language" is never a preferred language: it must be specific.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_preferred_language_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_preferred_language_check
  CHECK (preferred_language IN
    ('ENG', 'JPN', 'FRA', 'ITA', 'DEU', 'ESP', 'POR', 'CHN', 'KOR'));

COMMIT;
