-- Chat feature: conversations + messages tables
-- Run this in the Supabase SQL Editor

-- conversations table
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID NOT NULL REFERENCES auth.users(id),
  user_b UUID NOT NULL REFERENCES auth.users(id),
  last_message_at TIMESTAMPTZ DEFAULT now(),
  last_message_text TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_a, user_b),
  CHECK (user_a < user_b)
);

CREATE INDEX idx_conversations_user_a ON conversations(user_a);
CREATE INDEX idx_conversations_user_b ON conversations(user_b);
CREATE INDEX idx_conversations_last_msg ON conversations(last_message_at DESC);

-- messages table
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at DESC);

-- RLS for conversations
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own conversations" ON conversations FOR SELECT
  USING (auth.uid() = user_a OR auth.uid() = user_b);

CREATE POLICY "Users insert own conversations" ON conversations FOR INSERT
  WITH CHECK ((auth.uid() = user_a OR auth.uid() = user_b) AND user_a < user_b);

CREATE POLICY "Users update own conversations" ON conversations FOR UPDATE
  USING (auth.uid() = user_a OR auth.uid() = user_b);

-- RLS for messages
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see messages in own conversations" ON messages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
  ));

CREATE POLICY "Users insert messages in own conversations" ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
      AND (c.user_a = auth.uid() OR c.user_b = auth.uid())
    )
  );

-- Message content is immutable from clients. Trade proposal responses go
-- through respond_to_trade_message(), which verifies the receiver and format.
DROP POLICY IF EXISTS "Receiver can update trade status" ON messages;

CREATE OR REPLACE FUNCTION respond_to_trade_message(
  p_message_id UUID,
  p_status TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_sender_id UUID;
  v_user_a UUID;
  v_user_b UUID;
  v_content TEXT;
  v_parts TEXT[];
  v_updated_content TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_status NOT IN ('accepted', 'denied') THEN
    RAISE EXCEPTION 'Invalid trade status';
  END IF;

  SELECT m.sender_id, m.content, c.user_a, c.user_b
    INTO v_sender_id, v_content, v_user_a, v_user_b
  FROM messages m
  JOIN conversations c ON c.id = m.conversation_id
  WHERE m.id = p_message_id
  FOR UPDATE OF m;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  IF v_user_id NOT IN (v_user_a, v_user_b) OR v_sender_id = v_user_id THEN
    RAISE EXCEPTION 'Not authorized to respond to this trade';
  END IF;

  v_parts := string_to_array(v_content, ':');
  IF array_length(v_parts, 1) < 6 OR v_parts[1] <> 'TRADE' THEN
    RAISE EXCEPTION 'Message is not a trade proposal';
  END IF;

  IF v_parts[6] <> 'pending' THEN
    RAISE EXCEPTION 'Trade proposal is no longer pending';
  END IF;

  v_parts[6] := p_status;
  v_updated_content := array_to_string(v_parts, ':');

  UPDATE messages
  SET content = v_updated_content
  WHERE id = p_message_id;

  RETURN v_updated_content;
END;
$$;

REVOKE EXECUTE ON FUNCTION respond_to_trade_message(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION respond_to_trade_message(UUID, TEXT) TO authenticated;

-- RPC: get-or-create conversation
-- Handles race conditions and canonical user ordering in a single round-trip
CREATE OR REPLACE FUNCTION get_or_create_conversation(p_other_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_a UUID;
  v_user_b UUID;
  v_id UUID;
BEGIN
  IF auth.uid() < p_other_user_id THEN
    v_user_a := auth.uid();
    v_user_b := p_other_user_id;
  ELSE
    v_user_a := p_other_user_id;
    v_user_b := auth.uid();
  END IF;

  SELECT id INTO v_id
  FROM conversations
  WHERE user_a = v_user_a AND user_b = v_user_b;

  IF v_id IS NULL THEN
    INSERT INTO conversations (user_a, user_b)
    VALUES (v_user_a, v_user_b)
    ON CONFLICT (user_a, user_b) DO UPDATE
      SET user_a = conversations.user_a
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

-- IMPORTANT: After running this SQL, enable Realtime replication
-- on the "messages" table in Supabase Dashboard:
-- Database > Replication > enable "messages"

  -- Add unread count columns to conversations
  ALTER TABLE conversations
    ADD COLUMN IF NOT EXISTS unread_count_a int DEFAULT 0,
    ADD COLUMN IF NOT EXISTS unread_count_b int DEFAULT 0;

  -- Trigger function: auto-increment the OTHER user's unread count on new message
  CREATE OR REPLACE FUNCTION increment_unread_count()
  RETURNS TRIGGER AS $$
  BEGIN
    IF NEW.sender_id = (SELECT user_a FROM conversations WHERE id = NEW.conversation_id) THEN
      UPDATE conversations SET unread_count_b = unread_count_b + 1 WHERE id =
  NEW.conversation_id;
    ELSE
      UPDATE conversations SET unread_count_a = unread_count_a + 1 WHERE id =
  NEW.conversation_id;
    END IF;
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  -- Create trigger on messages table
  DROP TRIGGER IF EXISTS on_new_message_increment_unread ON messages;
  CREATE TRIGGER on_new_message_increment_unread
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION increment_unread_count();
