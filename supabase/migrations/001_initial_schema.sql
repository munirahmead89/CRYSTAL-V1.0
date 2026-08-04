-- Crystal Messenger - Initial Schema
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New Query)

-- ============================================================
-- 1. PROFILES (extends auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  email TEXT,
  full_name TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT DEFAULT '',
  is_online BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profiles ADD CONSTRAINT profiles_phone_unique UNIQUE (phone);

-- ============================================================
-- 2. CHATS (direct 1-on-1 conversations)
-- ============================================================
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT DEFAULT 'direct' CHECK (type IN ('direct', 'group', 'channel')),
  name TEXT,
  avatar_url TEXT,
  description TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_encrypted BOOLEAN DEFAULT false,
  disappearing_timer INTEGER,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. CHAT PARTICIPANTS
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'admin', 'owner')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  left_at TIMESTAMPTZ,
  is_muted BOOLEAN DEFAULT false,
  mute_until TIMESTAMPTZ,
  last_read_message_id UUID,
  UNIQUE(chat_id, user_id)
);

-- ============================================================
-- 4. MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'file', 'location', 'contact', 'sticker', 'system')),
  reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  forwarded_from_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  metadata JSONB,
  is_edited BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 5. MESSAGE READS (read receipts)
-- ============================================================
CREATE TABLE IF NOT EXISTS message_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(message_id, user_id)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_chat ON chat_participants(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_message ON message_reads(message_id);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reads ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all profiles, update only their own
CREATE POLICY "Profiles: anyone can read"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Profiles: users can update own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Profiles: users can insert own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Chats: only participants can see their chats
CREATE POLICY "Chats: participants can read"
  ON chats FOR SELECT
  USING (
    id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Chats: authenticated can create"
  ON chats FOR INSERT
  WITH CHECK (auth.uid() = created_by);

-- Chat Participants: only participants can see who's in the chat
CREATE POLICY "ChatParticipants: participants can read"
  ON chat_participants FOR SELECT
  USING (
    chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "ChatParticipants: chat creator can add"
  ON chat_participants FOR INSERT
  WITH CHECK (
    chat_id IN (
      SELECT id FROM chats WHERE created_by = auth.uid()
    )
    OR user_id = auth.uid()
  );

-- Messages: only chat participants can see messages
CREATE POLICY "Messages: participants can read"
  ON messages FOR SELECT
  USING (
    chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Messages: participants can insert"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Messages: sender can update own"
  ON messages FOR UPDATE
  USING (auth.uid() = sender_id);

-- Message Reads: participants can read and insert
CREATE POLICY "MessageReads: participants can read"
  ON message_reads FOR SELECT
  USING (
    message_id IN (
      SELECT m.id FROM messages m
      JOIN chat_participants cp ON cp.chat_id = m.chat_id
      WHERE cp.user_id = auth.uid()
    )
  );

CREATE POLICY "MessageReads: users can insert own"
  ON message_reads FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Function: Create a direct chat between two users
CREATE OR REPLACE FUNCTION create_direct_chat(other_user_id UUID)
RETURNS UUID AS $$
DECLARE
  existing_chat_id UUID;
  new_chat_id UUID;
BEGIN
  -- Check if a direct chat already exists between these two users
  SELECT cp1.chat_id INTO existing_chat_id
  FROM chat_participants cp1
  JOIN chat_participants cp2 ON cp1.chat_id = cp2.chat_id
  JOIN chats c ON c.id = cp1.chat_id
  WHERE cp1.user_id = auth.uid()
    AND cp2.user_id = other_user_id
    AND c.type = 'direct'
  LIMIT 1;

  IF existing_chat_id IS NOT NULL THEN
    RETURN existing_chat_id;
  END IF;

  -- Create new chat
  INSERT INTO chats (type, created_by)
  VALUES ('direct', auth.uid())
  RETURNING id INTO new_chat_id;

  -- Add both participants
  INSERT INTO chat_participants (chat_id, user_id, role)
  VALUES
    (new_chat_id, auth.uid(), 'owner'),
    (new_chat_id, other_user_id, 'member');

  RETURN new_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Send a message
CREATE OR REPLACE FUNCTION send_message(
  p_chat_id UUID,
  p_content TEXT,
  p_message_type TEXT DEFAULT 'text',
  p_reply_to_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_message_id UUID;
BEGIN
  INSERT INTO messages (chat_id, sender_id, content, message_type, reply_to_id)
  VALUES (p_chat_id, auth.uid(), p_content, p_message_type, p_reply_to_id)
  RETURNING id INTO new_message_id;

  -- Update chat's updated_at
  UPDATE chats SET updated_at = now() WHERE id = p_chat_id;

  RETURN new_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- REALTIME (enable for messages table)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;

-- ============================================================
-- TRIGGER: Auto-create profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, phone, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- TRANSFORMER MODEL: Messages are relayed, not stored permanently
-- Server acts as a relay. Messages auto-delete after delivery.
-- ============================================================

-- Function: Delete messages after all participants have read them
CREATE OR REPLACE FUNCTION cleanup_delivered_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM messages m
  WHERE m.is_deleted = false
    AND m.created_at < now() - interval '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM chat_participants cp
      WHERE cp.chat_id = m.chat_id
        AND cp.user_id != m.sender_id
        AND (cp.last_read_message_id IS NULL OR cp.last_read_message_id != m.id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Mark messages as read and trigger cleanup
CREATE OR REPLACE FUNCTION mark_messages_read(
  p_chat_id UUID,
  p_message_ids UUID[]
)
RETURNS void AS $$
BEGIN
  INSERT INTO message_reads (message_id, user_id)
  SELECT unnest(p_message_ids), auth.uid()
  ON CONFLICT (message_id, user_id) DO NOTHING;

  -- Update last_read_message_id for this user
  UPDATE chat_participants
  SET last_read_message_id = (
    SELECT id FROM messages
    WHERE chat_id = p_chat_id
      AND id = ANY(p_message_ids)
    ORDER BY created_at DESC
    LIMIT 1
  )
  WHERE chat_id = p_chat_id AND user_id = auth.uid();

  -- Trigger cleanup of delivered messages
  PERFORM cleanup_delivered_messages();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Auto-delete messages older than 7 days (disappearing messages)
CREATE OR REPLACE FUNCTION auto_disappear_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM messages
  WHERE created_at < now() - interval '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule cleanup every hour via pg_cron (if available)
-- SELECT cron.schedule('cleanup-messages', '0 * * * *', 'SELECT cleanup_delivered_messages()');
-- SELECT cron.schedule('disappear-messages', '0 0 * * *', 'SELECT auto_disappear_messages()');

-- Function: Soft-delete a message (for "Delete for Everyone")
CREATE OR REPLACE FUNCTION delete_message_for_everyone(p_message_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE messages
  SET is_deleted = true, content = 'This message was deleted', deleted_at = now()
  WHERE id = p_message_id AND sender_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
