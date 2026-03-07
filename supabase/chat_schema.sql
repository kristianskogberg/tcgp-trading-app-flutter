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

-- RPC: get-or-create conversation
-- Handles race conditions and canonical user ordering in a single round-trip
CREATE OR REPLACE FUNCTION get_or_create_conversation(p_other_user_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
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
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

-- IMPORTANT: After running this SQL, enable Realtime replication
-- on the "messages" table in Supabase Dashboard:
-- Database > Replication > enable "messages"
