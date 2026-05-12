-- Manual security verification checklist for Supabase SQL Editor.
--
-- Run these scenarios with real test users after applying the schema/hardening
-- scripts. Most checks need separate sessions/JWTs for user A, user B, and a
-- non-participant user C.

-- 1. Conversations and messages
-- - User C cannot select a conversation between users A and B.
-- - User C cannot insert a message into a conversation between users A and B.
-- - User A can insert a TRADE:...:pending message into an A/B conversation.
-- - User A cannot call respond_to_trade_message() on their own proposal.
-- - User B can call respond_to_trade_message(message_id, 'accepted') once.
-- - User B cannot call respond_to_trade_message() again on the same message.
-- - User B cannot call respond_to_trade_message() for normal text, FRIENDID,
--   or TRADERESULT messages.
-- - Direct client UPDATEs against public.messages are rejected.

-- 2. Trade-match RPC identity
-- - get_trade_matches_for_wanted() and get_trade_matches_for_owned() only use
--   auth.uid(); callers cannot pass or spoof another user's id.
-- - Anonymous authenticated users can still call both functions.

-- 3. Anonymous account migration
-- - Migration succeeds when the new Google user id sorts before the other
--   conversation participant.
-- - Migration succeeds when the new Google user id sorts after the other
--   conversation participant.
-- - If the old and new users both have conversations with the same other user,
--   messages are moved into one canonical conversation and unread counts are
--   preserved.

-- 4. Trade conditions
-- - set_trade_conditions() accepts a normal object payload for a card the
--   caller owns as type='owned'.
-- - set_trade_conditions() rejects non-object payloads.
-- - set_trade_conditions() rejects non-array language values.
-- - set_trade_conditions() rejects non-empty conditions for a listed card the
--   caller does not own.
-- - set_trade_conditions(card_id, '{}'::jsonb) clears the caller's own stale
--   conditions for that card.
