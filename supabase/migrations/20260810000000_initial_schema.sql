-- Crystal Messenger - v1.1 FULL consolidated schema (single migration)
-- Combines all historical migrations (001-018), the storage/realtime helper
-- scripts, schema-drift reconciliation tables and user-management RPCs.
-- Fully idempotent: safe to run on a fresh database OR an already-migrated one.
--
-- Apply via Supabase CLI:  supabase db push
--   or in the Dashboard:   SQL Editor > New Query > paste > Run
-- Generated: 2026-08-10

/* ===================== 001_initial_schema.sql ===================== */

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

-- Real phone numbers must be unique, but the auto-profile trigger seeds placeholder
-- rows with an empty phone for anonymous sign-ins, so enforce uniqueness only on
-- rows that actually carry a phone number (allows many pre-onboarding placeholders).
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_phone_unique;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_unique ON profiles (phone) WHERE phone <> '';


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
DROP POLICY IF EXISTS "Profiles: anyone can read" ON profiles;
CREATE POLICY "Profiles: anyone can read"
  ON profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Profiles: users can update own" ON profiles;
CREATE POLICY "Profiles: users can update own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles: users can insert own" ON profiles;
CREATE POLICY "Profiles: users can insert own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Chats: only participants can see their chats
DROP POLICY IF EXISTS "Chats: participants can read" ON chats;
CREATE POLICY "Chats: participants can read"
  ON chats FOR SELECT
  USING (
    id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Chats: authenticated can create" ON chats;
CREATE POLICY "Chats: authenticated can create"
  ON chats FOR INSERT
  WITH CHECK (auth.uid() = created_by);

-- Chat Participants: only participants can see who's in the chat
DROP POLICY IF EXISTS "ChatParticipants: participants can read" ON chat_participants;
CREATE POLICY "ChatParticipants: participants can read"
  ON chat_participants FOR SELECT
  USING (
    chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "ChatParticipants: chat creator can add" ON chat_participants;
CREATE POLICY "ChatParticipants: chat creator can add"
  ON chat_participants FOR INSERT
  WITH CHECK (
    chat_id IN (
      SELECT id FROM chats WHERE created_by = auth.uid()
    )
    OR user_id = auth.uid()
  );

-- Messages: only chat participants can see messages
DROP POLICY IF EXISTS "Messages: participants can read" ON messages;
CREATE POLICY "Messages: participants can read"
  ON messages FOR SELECT
  USING (
    chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Messages: participants can insert" ON messages;
CREATE POLICY "Messages: participants can insert"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Messages: sender can update own" ON messages;
CREATE POLICY "Messages: sender can update own"
  ON messages FOR UPDATE
  USING (auth.uid() = sender_id);

-- Message Reads: participants can read and insert
DROP POLICY IF EXISTS "MessageReads: participants can read" ON message_reads;
CREATE POLICY "MessageReads: participants can read"
  ON message_reads FOR SELECT
  USING (
    message_id IN (
      SELECT m.id FROM messages m
      JOIN chat_participants cp ON cp.chat_id = m.chat_id
      WHERE cp.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "MessageReads: users can insert own" ON message_reads;
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
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_participants') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'profiles') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;

-- ============================================================
-- TRIGGER: Auto-create profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

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

/* ===================== 002_contacts_realtime.sql ===================== */

-- Crystal Messenger - Migration 002
-- Adds the missing contacts + typing_indicators tables, the chat_with_last_message/user_contacts
-- views, and the auto-contact (WhatsApp-style) bidirectional logic so that when user A messages
-- or calls user B, user B instantly sees user A as a contact with no request/acceptance step.

-- ============================================================
-- 6. CONTACTS
-- ============================================================
CREATE TABLE IF NOT EXISTS contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  display_name TEXT,
  is_favorite BOOLEAN DEFAULT false,
  is_blocked BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_contacts_user ON contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_contact ON contacts(contact_id);

ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Contacts: users can read own" ON contacts;
CREATE POLICY "Contacts: users can read own"
  ON contacts FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Contacts: users can insert own" ON contacts;
CREATE POLICY "Contacts: users can insert own"
  ON contacts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Contacts: users can update own" ON contacts;
CREATE POLICY "Contacts: users can update own"
  ON contacts FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Contacts: users can delete own" ON contacts;
CREATE POLICY "Contacts: users can delete own"
  ON contacts FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 7. TYPING INDICATORS
-- ============================================================
CREATE TABLE IF NOT EXISTS typing_indicators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_typing BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(chat_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_typing_indicators_chat ON typing_indicators(chat_id);

ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Typing: participants can read" ON typing_indicators;
CREATE POLICY "Typing: participants can read"
  ON typing_indicators FOR SELECT
  USING (
    chat_id IN (
      SELECT chat_id FROM chat_participants WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Typing: users can manage own" ON typing_indicators;
CREATE POLICY "Typing: users can manage own"
  ON typing_indicators FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Typing: users can update own" ON typing_indicators;
CREATE POLICY "Typing: users can update own"
  ON typing_indicators FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Typing: users can delete own" ON typing_indicators;
CREATE POLICY "Typing: users can delete own"
  ON typing_indicators FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- VIEWS
-- ============================================================
-- user_contacts joins contacts with the target profile (used for read models)
CREATE OR REPLACE VIEW user_contacts AS
SELECT
  c.id,
  c.user_id,
  c.contact_id,
  c.display_name,
  c.is_favorite,
  c.is_blocked,
  c.created_at,
  c.updated_at,
  p AS profile
FROM contacts c
JOIN profiles p ON p.id = c.contact_id;

-- chat_with_last_message: a read-optimized view for the chat list.
-- NOTE: the app uses the manual fallback when unread_count must be per-user;
-- this view provides the base chat rows plus the latest message.
CREATE OR REPLACE VIEW chat_with_last_message AS
SELECT
  c.id,
  c.type,
  c.name,
  c.avatar_url,
  c.description,
  c.created_by,
  c.is_encrypted,
  c.disappearing_timer,
  c.created_at,
  c.updated_at,
  (
    SELECT to_jsonb(msg)
    FROM messages msg
    WHERE msg.chat_id = c.id
    ORDER BY msg.created_at DESC
    LIMIT 1
  ) AS last_message,
  0::bigint AS unread_count,
  NULL::jsonb AS other_participant
FROM chats c;

-- ============================================================
-- AUTO-CONTACT (WhatsApp-style) LOGIC
-- ============================================================

-- Ensure a single directed contact row exists (idempotent).
CREATE OR REPLACE FUNCTION ensure_contact_for(p_user_id UUID, p_contact_id UUID, p_display_name TEXT DEFAULT NULL)
RETURNS void AS $$
BEGIN
  IF p_user_id IS NULL OR p_contact_id IS NULL OR p_user_id = p_contact_id THEN
    RETURN;
  END IF;

  INSERT INTO contacts (user_id, contact_id, display_name)
  VALUES (p_user_id, p_contact_id, p_display_name)
  ON CONFLICT (user_id, contact_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure reciprocal contacts between two users.
CREATE OR REPLACE FUNCTION ensure_contacts_between(p_user_a UUID, p_user_b UUID)
RETURNS void AS $$
BEGIN
  PERFORM ensure_contact_for(p_user_a, p_user_b, NULL);
  PERFORM ensure_contact_for(p_user_b, p_user_a, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: when a participant is added to a DIRECT chat, instantly add reciprocal contacts
-- with every other participant. This is what makes "user B instantly sees user A as a contact".
CREATE OR REPLACE FUNCTION handle_direct_chat_participant_contacts()
RETURNS TRIGGER AS $$
DECLARE
  other_id UUID;
  is_direct BOOLEAN;
BEGIN
  SELECT (type = 'direct') INTO is_direct
  FROM chats WHERE id = NEW.chat_id;

  IF is_direct THEN
    FOR other_id IN
      SELECT user_id FROM chat_participants
      WHERE chat_id = NEW.chat_id AND user_id <> NEW.user_id
    LOOP
      PERFORM ensure_contact_for(NEW.user_id, other_id, NULL);
      PERFORM ensure_contact_for(other_id, NEW.user_id, NULL);
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_chat_participant_added ON chat_participants;
CREATE TRIGGER on_chat_participant_added
  AFTER INSERT ON chat_participants
  FOR EACH ROW EXECUTE FUNCTION handle_direct_chat_participant_contacts();

-- Belt-and-suspenders: sending a message in a direct chat also ensures contacts,
-- covering any chat that was created outside create_direct_chat.
CREATE OR REPLACE FUNCTION handle_message_contact_sync()
RETURNS TRIGGER AS $$
DECLARE
  is_direct BOOLEAN;
  other_id UUID;
BEGIN
  SELECT (type = 'direct') INTO is_direct
  FROM chats WHERE id = NEW.chat_id;

  IF is_direct THEN
    FOR other_id IN
      SELECT user_id FROM chat_participants
      WHERE chat_id = NEW.chat_id AND user_id <> NEW.sender_id
    LOOP
      PERFORM ensure_contact_for(NEW.sender_id, other_id, NULL);
      PERFORM ensure_contact_for(other_id, NEW.sender_id, NULL);
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_sync_contacts ON messages;
CREATE TRIGGER on_message_sync_contacts
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION handle_message_contact_sync();

-- ============================================================
-- create_direct_chat: also guarantee reciprocal contacts so both users
-- instantly see each other the moment a direct chat is created.
-- ============================================================
CREATE OR REPLACE FUNCTION create_direct_chat(other_user_id UUID)
RETURNS UUID AS $$
DECLARE
  existing_chat_id UUID;
  new_chat_id UUID;
BEGIN
  SELECT cp1.chat_id INTO existing_chat_id
  FROM chat_participants cp1
  JOIN chat_participants cp2 ON cp1.chat_id = cp2.chat_id
  JOIN chats c ON c.id = cp1.chat_id
  WHERE cp1.user_id = auth.uid()
    AND cp2.user_id = other_user_id
    AND c.type = 'direct'
  LIMIT 1;

  IF existing_chat_id IS NOT NULL THEN
    PERFORM ensure_contacts_between(auth.uid(), other_user_id);
    RETURN existing_chat_id;
  END IF;

  INSERT INTO chats (type, created_by)
  VALUES ('direct', auth.uid())
  RETURNING id INTO new_chat_id;

  INSERT INTO chat_participants (chat_id, user_id, role)
  VALUES
    (new_chat_id, auth.uid(), 'owner'),
    (new_chat_id, other_user_id, 'member');

  PERFORM ensure_contacts_between(auth.uid(), other_user_id);

  RETURN new_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- REALTIME (add contacts + typing_indicators)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'contacts') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.contacts;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'typing_indicators') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_indicators;
  END IF;
END $$;

/* ===================== 003_push_tokens.sql ===================== */

-- Crystal Messenger - Migration 003
-- Adds the push_tokens table used to deliver WhatsApp-style push notifications
-- through Expo's free push service (https://exp.host/--/api/v2/push/send).
-- Tokens are registered by each client and consumed by the send-message-push Edge Function.

CREATE TABLE IF NOT EXISTS push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'android',
  device_id TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON push_tokens(is_active);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "PushTokens: users can read own" ON push_tokens;
CREATE POLICY "PushTokens: users can read own"
  ON push_tokens FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "PushTokens: users can insert own" ON push_tokens;
CREATE POLICY "PushTokens: users can insert own"
  ON push_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "PushTokens: users can update own" ON push_tokens;
CREATE POLICY "PushTokens: users can update own"
  ON push_tokens FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "PushTokens: users can delete own" ON push_tokens;
CREATE POLICY "PushTokens: users can delete own"
  ON push_tokens FOR DELETE
  USING (auth.uid() = user_id);

-- Client helper to upsert a push token for the signed-in user.
CREATE OR REPLACE FUNCTION upsert_push_token(p_token TEXT, p_platform TEXT DEFAULT 'android', p_device_id TEXT DEFAULT NULL)
RETURNS void AS $$
BEGIN
  INSERT INTO push_tokens (user_id, token, platform, device_id, is_active)
  VALUES (auth.uid(), p_token, p_platform, p_device_id, true)
  ON CONFLICT (token)
  DO UPDATE SET
    user_id = EXCLUDED.user_id,
    platform = EXCLUDED.platform,
    device_id = EXCLUDED.device_id,
    is_active = true,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/* ===================== 004_calls.sql ===================== */

-- Crystal Messenger - Migration 004
-- Adds call logging tables so the Calls tab shows real-time history, and makes an
-- initiated call also auto-add contacts (WhatsApp-style) just like messages do.

CREATE TABLE IF NOT EXISTS calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  caller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'audio' CHECK (type IN ('audio', 'video')),
  status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'answered', 'ended', 'missed', 'declined', 'busy')),
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  duration INTEGER,
  metadata JSONB
);

CREATE TABLE IF NOT EXISTS call_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  left_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'ringing', 'joined', 'left', 'declined')),
  UNIQUE(call_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_calls_chat ON calls(chat_id);
CREATE INDEX IF NOT EXISTS idx_calls_caller ON calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_user ON call_participants(user_id);

ALTER TABLE calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Calls: participants can read" ON calls;
CREATE POLICY "Calls: participants can read"
  ON calls FOR SELECT
  USING (
    chat_id IN (SELECT chat_id FROM chat_participants WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Calls: caller can create" ON calls;
CREATE POLICY "Calls: caller can create"
  ON calls FOR INSERT
  WITH CHECK (auth.uid() = caller_id);

DROP POLICY IF EXISTS "Calls: participants can update" ON calls;
CREATE POLICY "Calls: participants can update"
  ON calls FOR UPDATE
  USING (
    chat_id IN (SELECT chat_id FROM chat_participants WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "CallParticipants: participants can read" ON call_participants;
CREATE POLICY "CallParticipants: participants can read"
  ON call_participants FOR SELECT
  USING (
    call_id IN (
      SELECT c.id FROM calls c
      JOIN chat_participants cp ON cp.chat_id = c.chat_id
      WHERE cp.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "CallParticipants: caller can add" ON call_participants;
CREATE POLICY "CallParticipants: caller can add"
  ON call_participants FOR INSERT
  WITH CHECK (
    call_id IN (SELECT id FROM calls WHERE caller_id = auth.uid())
  );

DROP POLICY IF EXISTS "CallParticipants: participants can update own" ON call_participants;
CREATE POLICY "CallParticipants: participants can update own"
  ON call_participants FOR UPDATE
  USING (user_id = auth.uid());

-- Helper: log a call for the signed-in user and add them as a participant.
CREATE OR REPLACE FUNCTION log_call(p_chat_id UUID, p_type TEXT DEFAULT 'audio', p_status TEXT DEFAULT 'initiated')
RETURNS UUID AS $$
DECLARE
  new_call_id UUID;
BEGIN
  INSERT INTO calls (chat_id, caller_id, type, status)
  VALUES (p_chat_id, auth.uid(), p_type, p_status)
  RETURNING id INTO new_call_id;

  INSERT INTO call_participants (call_id, user_id, status)
  VALUES (new_call_id, auth.uid(), 'joined');

  RETURN new_call_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-contact on a call: whoever is called instantly shows the caller as a contact.
CREATE OR REPLACE FUNCTION handle_call_contact_sync()
RETURNS TRIGGER AS $$
DECLARE
  other_id UUID;
BEGIN
  FOR other_id IN
    SELECT user_id FROM chat_participants
    WHERE chat_id = NEW.chat_id AND user_id <> NEW.caller_id
  LOOP
    PERFORM ensure_contact_for(NEW.caller_id, other_id, NULL);
    PERFORM ensure_contact_for(other_id, NEW.caller_id, NULL);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_call_sync_contacts ON calls;
CREATE TRIGGER on_call_sync_contacts
  AFTER INSERT ON calls
  FOR EACH ROW EXECUTE FUNCTION handle_call_contact_sync();

-- ============================================================
-- REALTIME (calls)
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'calls') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'call_participants') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.call_participants;
  END IF;
END $$;

/* ===================== 005_enable_anonymous_auth.sql ===================== */

-- Crystal Messenger - Migration 005
-- Enables Anonymous Sign-Ins. The app signs every new user in anonymously first
-- (before they complete their profile) so they can chat/call instantly.
--
-- For a hosted Supabase project you can also toggle this in the dashboard:
--   Authentication -> Sign In / Providers -> Anonymous Sign-Ins -> Enable
--
-- This statement is idempotent and safe to re-run in the SQL Editor.
-- The auth.config table is only present on newer Supabase platforms. Guard it so
-- this migration never fails on older hosts; if the table is missing readers must
-- enable Anonymous Sign-Ins from the dashboard instead.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'config') THEN
    UPDATE auth.config SET enable_anonymous_sign_ins = TRUE;
    RAISE NOTICE 'Anonymous sign-ins enabled via auth.config';
  ELSE
    RAISE NOTICE 'auth.config table not found; enable Anonymous Sign-Ins in Dashboard > Authentication > Sign In / Providers > Anonymous Sign-Ins';
  END IF;
END $$;

/* ===================== 006_fix_auth_trigger_search_path.sql ===================== */

-- Crystal Messenger - Migration 006
-- Fix handle_new_user so it always resolves public.profiles.
--
-- GoTrue (the Auth service) creates anonymous/regular users in auth.users and fires
-- our AFTER INSERT trigger. GoTrue runs with a restricted search_path that does NOT
-- include `public`, so the unqualified `profiles` reference inside the trigger failed
-- with `relation "profiles" does not exist`, making /auth/v1/signup return HTTP 500
-- ("Database error saving new user").
--
-- The fix: pin an empty search_path on the SECURITY DEFINER function and fully
-- qualify the table as public.profiles. Safe to re-run (CREATE OR REPLACE).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

/* ===================== 007_fixes.sql ===================== */

-- Crystal Messenger - Migration 007
-- 1) Rebuild chat_with_last_message as an RLS-respecting, per-user view.
--    The old view returned NULL other_participant / 0 unread_count (so the Chats
--    tab rendered every direct chat as "Unknown" with no badges) and ran without
--    security_invoker, bypassing RLS (any authenticated user could enumerate every
--    chat + last message). security_invoker + auth.uid() fix both.
-- 2) Add authorization checks to the SECURITY DEFINER writer functions so a user
--    can only send/mark-read/log-calls inside chats they participate in, and only
--    create direct chats with a real, non-self user.
-- 3) Create the public `avatars` storage bucket (the app uploads avatars to it,
--    but no migration ever created it, so every avatar upload failed).

-- ============================================================
-- 1. PER-USER CHAT LIST VIEW (RLS-safe)
-- ============================================================
DROP VIEW IF EXISTS public.chat_with_last_message;
CREATE VIEW public.chat_with_last_message
WITH (security_invoker = on)
AS
SELECT
  c.id,
  c.type,
  c.name,
  c.avatar_url,
  c.description,
  c.created_by,
  c.is_encrypted,
  c.disappearing_timer,
  c.created_at,
  c.updated_at,
  (
    SELECT to_jsonb(p)
    FROM profiles p
    JOIN chat_participants cp ON cp.user_id = p.id
    WHERE cp.chat_id = c.id
      AND cp.user_id <> auth.uid()
    ORDER BY cp.joined_at ASC
    LIMIT 1
  ) AS other_participant,
  (
    SELECT to_jsonb(m)
    FROM messages m
    WHERE m.chat_id = c.id
    ORDER BY m.created_at DESC
    LIMIT 1
  ) AS last_message,
  (
    SELECT count(*)::bigint
    FROM messages m
    WHERE m.chat_id = c.id
      AND m.sender_id <> auth.uid()
      AND m.is_deleted = false
      AND NOT EXISTS (
        SELECT 1 FROM message_reads mr
        WHERE mr.message_id = m.id AND mr.user_id = auth.uid()
      )
  ) AS unread_count
FROM chats c;

-- ============================================================
-- 2. AUTHORIZATION HARDENING
-- ============================================================

-- Send message: only a participant may send.
CREATE OR REPLACE FUNCTION public.send_message(
  p_chat_id UUID,
  p_content TEXT,
  p_message_type TEXT DEFAULT 'text',
  p_reply_to_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_message_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  INSERT INTO messages (chat_id, sender_id, content, message_type, reply_to_id)
  VALUES (p_chat_id, auth.uid(), p_content, p_message_type, p_reply_to_id)
  RETURNING id INTO new_message_id;

  UPDATE chats SET updated_at = now() WHERE id = p_chat_id;

  RETURN new_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Mark messages read: only a participant may mark reads.
CREATE OR REPLACE FUNCTION public.mark_messages_read(
  p_chat_id UUID,
  p_message_ids UUID[]
)
RETURNS void AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  INSERT INTO message_reads (message_id, user_id)
  SELECT unnest(p_message_ids), auth.uid()
  ON CONFLICT (message_id, user_id) DO NOTHING;

  UPDATE chat_participants
  SET last_read_message_id = (
    SELECT id FROM messages
    WHERE chat_id = p_chat_id
      AND id = ANY(p_message_ids)
    ORDER BY created_at DESC
    LIMIT 1
  )
  WHERE chat_id = p_chat_id AND user_id = auth.uid();

  PERFORM cleanup_delivered_messages();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Log a call: only a participant may start a call.
CREATE OR REPLACE FUNCTION public.log_call(
  p_chat_id UUID,
  p_type TEXT DEFAULT 'audio',
  p_status TEXT DEFAULT 'initiated'
)
RETURNS UUID AS $$
DECLARE
  new_call_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  INSERT INTO calls (chat_id, caller_id, type, status)
  VALUES (p_chat_id, auth.uid(), p_type, p_status)
  RETURNING id INTO new_call_id;

  INSERT INTO call_participants (call_id, user_id, status)
  VALUES (new_call_id, auth.uid(), 'joined');

  RETURN new_call_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Create a direct chat: participant must be a real, non-self user.
CREATE OR REPLACE FUNCTION public.create_direct_chat(other_user_id UUID)
RETURNS UUID AS $$
DECLARE
  existing_chat_id UUID;
  new_chat_id UUID;
  other_exists BOOLEAN;
BEGIN
  IF other_user_id IS NULL OR other_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot start a chat with yourself';
  END IF;

  SELECT EXISTS(SELECT 1 FROM profiles p WHERE p.id = other_user_id) INTO other_exists;
  IF NOT other_exists THEN
    RAISE EXCEPTION 'Crystal user not found';
  END IF;

  SELECT cp1.chat_id INTO existing_chat_id
  FROM chat_participants cp1
  JOIN chat_participants cp2 ON cp1.chat_id = cp2.chat_id
  JOIN chats c ON c.id = cp1.chat_id
  WHERE cp1.user_id = auth.uid()
    AND cp2.user_id = other_user_id
    AND c.type = 'direct'
  LIMIT 1;

  IF existing_chat_id IS NOT NULL THEN
    PERFORM ensure_contacts_between(auth.uid(), other_user_id);
    RETURN existing_chat_id;
  END IF;

  INSERT INTO chats (type, created_by)
  VALUES ('direct', auth.uid())
  RETURNING id INTO new_chat_id;

  INSERT INTO chat_participants (chat_id, user_id, role)
  VALUES
    (new_chat_id, auth.uid(), 'owner'),
    (new_chat_id, other_user_id, 'member');

  PERFORM ensure_contacts_between(auth.uid(), other_user_id);

  RETURN new_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 3. AVATARS STORAGE BUCKET + POLICIES
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Avatars: public read" ON storage.objects;
CREATE POLICY "Avatars: public read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Avatars: authenticated upload" ON storage.objects;
CREATE POLICY "Avatars: authenticated upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatars: users can update own" ON storage.objects;
CREATE POLICY "Avatars: users can update own" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatars: users can delete own" ON storage.objects;
CREATE POLICY "Avatars: users can delete own" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

/* ===================== 008_fix_chat_participants_rls.sql ===================== */

-- Crystal Messenger - Migration 008
-- Fix "infinite recursion detected in policy for relation chat_participants".
--
-- The read policy on chat_participants selected from chat_participants inside its
-- own USING clause, which Postgres rejects with SQLSTATE 42P17 (and it also broke
-- the security_invoker chat list view and every direct query on the table).
-- The standard fix is a SECURITY DEFINER membership helper: it queries the table
-- as the owner (bypassing RLS), so the policy no longer self-references.
CREATE OR REPLACE FUNCTION public.is_chat_participant(p_chat_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_chat_participant(uuid) TO anon, authenticated;

DROP POLICY IF EXISTS "ChatParticipants: participants can read" ON chat_participants;
CREATE POLICY "ChatParticipants: participants can read"
  ON chat_participants FOR SELECT
  USING (public.is_chat_participant(chat_id));

/* ===================== 009_drop_recursive_policies.sql ===================== */

-- Crystal Messenger - Migration 009
-- Drop the dashboard-generated, self-referencing RLS policies on chat_participants.
--
-- These were created outside the migrations (Supabase Table Editor auto-generates
-- `<table>: <verb> own ...` policies when RLS is toggled in the dashboard). The four
-- on chat_participants selected from chat_participants inside their own USING clause,
-- which PostgreSQL rejects with SQLSTATE 42P17 ("infinite recursion detected"), and
-- which broke the chat list view and every read of the table.
--
-- The migration-created policies remain and fully cover access:
--   * "ChatParticipants: participants can read" (uses the SECURITY DEFINER helper
--     public.is_chat_participant(chat_id), so it is recursion-free)
--   * "ChatParticipants: chat creator can add"
-- These DROP statements are no-ops on a fresh database (the policies do not exist).
DROP POLICY IF EXISTS "chat_participants: select own chats" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants: update own chats" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants: delete own chats" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants: insert own chats" ON chat_participants;

/* ===================== 010_live_features.sql ===================== */

-- Crystal Messenger - Migration 010
-- Live-data features (all work in Expo Go over Supabase Realtime):
-- 1) messages.delivered_at  -> drives "✓✓ delivered" on the sender side.
-- 2) message_reads.chat_id  -> lets clients subscribe to read receipts scoped to
--    one chat, and puts message_reads into the realtime publication so "seen"
--    ticks propagate live to the sender.
-- 3) mark_messages_delivered RPC -> the receiving client marks peer messages as
--    delivered when they arrive / the chat is opened.
-- 4) `media` storage bucket -> hosts voice notes (uploaded by sender under their
--    own user folder, publicly readable so the recipient can play them).

-- ============================================================
-- 1. DELIVERED TIMESTAMP ON MESSAGES
-- ============================================================
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- ============================================================
-- 2. READ RECEIPTS: chat-scoped + realtime
-- ============================================================
ALTER TABLE public.message_reads
  ADD COLUMN IF NOT EXISTS chat_id UUID REFERENCES public.chats(id) ON DELETE CASCADE;

-- Backfill chat_id from the parent message so existing rows become filterable.
DO $$
BEGIN
  UPDATE public.message_reads mr
  SET chat_id = m.chat_id
  FROM public.messages m
  WHERE mr.message_id = m.id
    AND mr.chat_id IS NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_message_reads_chat
  ON public.message_reads(chat_id, read_at);

-- Publish read receipts so "seen" changes stream to the sender in real time.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'message_reads'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reads;
  END IF;
END $$;

-- ============================================================
-- 3. MARK MESSAGES DELIVERED (receiving client calls this)
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_messages_delivered(
  p_chat_id UUID,
  p_message_ids UUID[]
)
RETURNS void AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  UPDATE public.messages
  SET delivered_at = now()
  WHERE chat_id = p_chat_id
    AND sender_id <> auth.uid()
    AND id = ANY(p_message_ids)
    AND delivered_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Extend send_message to carry JSON metadata (voice-note duration, media size…).
CREATE OR REPLACE FUNCTION public.send_message(
  p_chat_id UUID,
  p_content TEXT,
  p_message_type TEXT DEFAULT 'text',
  p_reply_to_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_message_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  INSERT INTO messages (chat_id, sender_id, content, message_type, reply_to_id, metadata)
  VALUES (p_chat_id, auth.uid(), p_content, p_message_type, p_reply_to_id, p_metadata)
  RETURNING id INTO new_message_id;

  UPDATE chats SET updated_at = now() WHERE id = p_chat_id;

  RETURN new_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 4. MEDIA STORAGE BUCKET (voice notes etc.)
--    Public read; authenticated users may upload into their own
--    user folder (mirrors the avatars bucket pattern).
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Media: public read" ON storage.objects;
CREATE POLICY "Media: public read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'media');

DROP POLICY IF EXISTS "Media: authenticated upload" ON storage.objects;
CREATE POLICY "Media: authenticated upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Media: users can update own" ON storage.objects;
CREATE POLICY "Media: users can update own" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Media: users can delete own" ON storage.objects;
CREATE POLICY "Media: users can delete own" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

/* ===================== 011_clear_chat.sql ===================== */

-- Crystal Messenger - Migration 011
-- Chat management actions:
-- 1) clear_chat -> soft-deletes every message in a chat (participants only),
--    used by the chat 3-dot menu "Clear chat".
-- 2) Enable REPLICA IDENTITY FULL on messages so Realtime UPDATE/DELETE events
--    always carry the full row (is_deleted, content, deleted_at). Without this
--    Postgres only ships the primary key on UPDATE events, so the other
--    participant could not see soft-deletions in real time.

-- ============================================================
-- CLEAR CHAT
-- ============================================================
CREATE OR REPLACE FUNCTION public.clear_chat(p_chat_id UUID)
RETURNS void AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  UPDATE public.messages
  SET is_deleted = true,
      content = 'This message was deleted',
      deleted_at = now()
  WHERE chat_id = p_chat_id
    AND is_deleted = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- REALTIME RELIABILITY
-- ============================================================
ALTER TABLE public.messages REPLICA IDENTITY FULL;

/* ===================== 012_fix_read_receipt_chat.sql ===================== */

-- Crystal Messenger - Migration 012
-- Fix read receipts reaching the sender in real time.
--
-- The sender subscribes to realtime INSERTs on `message_reads` filtered by
-- `chat_id=eq.<chat>`. But `mark_messages_read` inserted rows WITHOUT chat_id,
-- so those INSERT events never matched the filter and the sender never learned
-- a message was read (the traffic light stayed red / unsent).
-- This version records chat_id so the realtime filter fires.

CREATE OR REPLACE FUNCTION public.mark_messages_read(
  p_chat_id UUID,
  p_message_ids UUID[]
)
RETURNS void AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  INSERT INTO message_reads (message_id, user_id, chat_id)
  SELECT unnest(p_message_ids), auth.uid(), p_chat_id
  ON CONFLICT (message_id, user_id) DO NOTHING;

  UPDATE chat_participants
  SET last_read_message_id = (
    SELECT id FROM messages
    WHERE chat_id = p_chat_id
      AND id = ANY(p_message_ids)
    ORDER BY created_at DESC
    LIMIT 1
  )
  WHERE chat_id = p_chat_id AND user_id = auth.uid();

  PERFORM cleanup_delivered_messages();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

/* ===================== 013_auto_delete_24h.sql ===================== */

-- Crystal Messenger - Migration 013
-- 1) Guarantee storage buckets exist (media + avatars) with the right policies.
-- 2) Auto-delete ALL chat messages + their media after 24 hours so nothing
--    accumulates on Supabase (saves storage). Runs hourly via pg_cron.
--
-- NOTE: This makes the server a pure relay: conversations older than 24 hours
-- are hard-deleted. Run this AFTER migrations 001-012.

-- ============================================================
-- 1. STORAGE BUCKETS (idempotent)
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Public read for both buckets.
DROP POLICY IF EXISTS "Media: public read" ON storage.objects;
CREATE POLICY "Media: public read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'media');

DROP POLICY IF EXISTS "Avatars: public read" ON storage.objects;
CREATE POLICY "Avatars: public read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'avatars');

-- Authenticated users may upload into their own user folder (both buckets).
DROP POLICY IF EXISTS "Media: authenticated upload" ON storage.objects;
CREATE POLICY "Media: authenticated upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatars: authenticated upload" ON storage.objects;
CREATE POLICY "Avatars: authenticated upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can update/delete their own files in both buckets.
DROP POLICY IF EXISTS "Media: users can update own" ON storage.objects;
CREATE POLICY "Media: users can update own" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Media: users can delete own" ON storage.objects;
CREATE POLICY "Media: users can delete own" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatars: users can update own" ON storage.objects;
CREATE POLICY "Avatars: users can update own" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Avatars: users can delete own" ON storage.objects;
CREATE POLICY "Avatars: users can delete own" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================
-- 2. 24-HOUR AUTO-DELETE (relay mode, storage savings)
-- ============================================================

-- Purge function: removes expired messages, their media files, and any chats
-- that have no messages left and have been inactive for over 24 hours.
CREATE OR REPLACE FUNCTION public.purge_expired_chats()
RETURNS void AS $$
DECLARE
  r RECORD;
  obj_path TEXT;
BEGIN
  -- 1) Delete media files from storage for expired image/audio messages.
  FOR r IN
    SELECT id, content FROM public.messages
    WHERE created_at < now() - interval '24 hours'
      AND message_type IN ('image', 'audio')
      AND content LIKE '%/object/public/media/%'
  LOOP
    obj_path := regexp_replace(r.content, '^.*/object/public/media/', '');
    obj_path := regexp_replace(obj_path, '\?.*$', '');
    DELETE FROM storage.objects
    WHERE bucket_id = 'media' AND name = obj_path;
  END LOOP;

  -- 2) Hard-delete expired messages (message_reads cascade via FK).
  DELETE FROM public.messages
  WHERE created_at < now() - interval '24 hours';

  -- 3) Delete chats with no messages left and inactive > 24h.
  DELETE FROM public.chats c
  WHERE c.updated_at < now() - interval '24 hours'
    AND NOT EXISTS (SELECT 1 FROM public.messages m WHERE m.chat_id = c.id);

  -- 4) Delete orphaned media files (no message references them).
  DELETE FROM storage.objects o
  WHERE o.bucket_id = 'media'
    AND o.created_at < now() - interval '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM public.messages m
      WHERE m.message_type IN ('image', 'audio')
        AND m.content LIKE '%/object/public/media/' || o.name || '%'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule hourly purge via pg_cron if the extension is enabled.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'purge-chats-24h',
      '0 * * * *',
      $$SELECT public.purge_expired_chats()$$
    );
  END IF;
END $$;

/* ===================== 014_ensure_storage_buckets.sql ===================== */

-- Crystal Messenger - Migration 014
-- Runtime self-healing for storage buckets.
--
-- Even after 010/013 are applied, if the `media`/`avatars` buckets are ever
-- deleted (or a project was set up without running those migrations first),
-- uploads fail with "bucket not found". This migration exposes a SECURITY
-- DEFINER RPC that any authenticated client can call before uploading. It
-- re-creates the buckets (if missing) and re-applies the storage policies.
-- The app calls it lazily once per session, so sending photos/videos/voice
-- notes works even when the bucket is missing.

CREATE OR REPLACE FUNCTION public.ensure_storage_buckets()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
BEGIN
  -- 1) Create buckets if missing (idempotent).
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('media', 'media', true), ('avatars', 'avatars', true)
  ON CONFLICT (id) DO NOTHING;

  -- 2) Public read for both buckets.
  DROP POLICY IF EXISTS "Media: public read" ON storage.objects;
  CREATE POLICY "Media: public read" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'media');

  DROP POLICY IF EXISTS "Avatars: public read" ON storage.objects;
  CREATE POLICY "Avatars: public read" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'avatars');

  -- 3) Authenticated users may upload into their own user folder (both buckets).
  DROP POLICY IF EXISTS "Media: authenticated upload" ON storage.objects;
  CREATE POLICY "Media: authenticated upload" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'media'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );

  DROP POLICY IF EXISTS "Avatars: authenticated upload" ON storage.objects;
  CREATE POLICY "Avatars: authenticated upload" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );

  -- 4) Users can update/delete their own files in both buckets.
  DROP POLICY IF EXISTS "Media: users can update own" ON storage.objects;
  CREATE POLICY "Media: users can update own" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
      bucket_id = 'media'
      AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
      bucket_id = 'media'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );

  DROP POLICY IF EXISTS "Media: users can delete own" ON storage.objects;
  CREATE POLICY "Media: users can delete own" ON storage.objects
    FOR DELETE TO authenticated
    USING (
      bucket_id = 'media'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );

  DROP POLICY IF EXISTS "Avatars: users can update own" ON storage.objects;
  CREATE POLICY "Avatars: users can update own" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );

  DROP POLICY IF EXISTS "Avatars: users can delete own" ON storage.objects;
  CREATE POLICY "Avatars: users can delete own" ON storage.objects
    FOR DELETE TO authenticated
    USING (
      bucket_id = 'avatars'
      AND (storage.foldername(name))[1] = auth.uid()::text
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_storage_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_storage_buckets() TO anon;

/* ===================== 015_hard_delete_message.sql ===================== */

-- Crystal Messenger - Migration 015
-- Permanent message deletion ("no remains").
-- delete_message_permanently hard-DELETEs a message row so nothing remains for
-- anyone. Any chat participant may permanently remove any message in a chat
-- they belong to (including messages already soft-deleted). message_reads rows
-- cascade via FK; replies that pointed at this message are unlinked
-- (reply_to_id is ON DELETE SET NULL). The client also receives the Realtime
-- DELETE event (REPLICA IDENTITY FULL) and drops its local copy immediately.

CREATE OR REPLACE FUNCTION public.delete_message_permanently(p_message_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.messages m
    JOIN public.chat_participants cp ON cp.chat_id = m.chat_id
    WHERE m.id = p_message_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  DELETE FROM public.messages WHERE id = p_message_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_message_permanently(UUID) TO authenticated;

/* ===================== 016_scale_indexes.sql ===================== */

-- Crystal Messenger - Migration 016
-- Performance indexes for the per-user chat list view (chat_with_last_message)
-- and for high-traffic chat repositories once the app grows.
-- All indexes are idempotent (CREATE INDEX IF NOT EXISTS).

-- 1. Fast lookup of a user's chat list (first step of getChats).
CREATE INDEX IF NOT EXISTS idx_chat_participants_user_chat
  ON public.chat_participants (user_id, chat_id);

-- 2. Composite covering index for the view's other_participant subquery
--    (WHERE chat_id AND user_id <> auth.uid() ORDER BY joined_at LIMIT 1).
CREATE INDEX IF NOT EXISTS idx_chat_participants_chat_user_joined
  ON public.chat_participants (chat_id, user_id, joined_at);

-- 3. Covering index for the view's unread_count subquery
--    (WHERE chat_id AND sender_id <> auth.uid() AND is_deleted = false).
CREATE INDEX IF NOT EXISTS idx_messages_chat_unread
  ON public.messages (chat_id, is_deleted, sender_id, created_at DESC);

-- 4. Left/anti-join on message_reads inside unread_count
--    (NOT EXISTS message_reads WHERE message_id AND user_id).
CREATE INDEX IF NOT EXISTS idx_message_reads_message_user
  ON public.message_reads (message_id, user_id);

/* ===================== 017_delete_all_messages.sql ===================== */

-- Crystal Messenger - Migration 017
-- Permanently deletes EVERY message in a chat ("Delete all messages", no remains).
-- Runs as SECURITY DEFINER with a participant check. message_reads rows cascade
-- (FK ON DELETE CASCADE) and replies unlink (reply_to_id ON DELETE SET NULL),
-- so a plain DELETE is safe and complete.

CREATE OR REPLACE FUNCTION public.delete_all_messages_permanently(p_chat_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  DELETE FROM public.messages WHERE chat_id = p_chat_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_all_messages_permanently(UUID) TO authenticated;

-- ============================================================
-- REALTIME EXTRAS
-- ============================================================
-- Read receipts carry the full row so the sender's device can react to
-- UPSERT/DELETE events without a manual refresh.
ALTER TABLE public.message_reads REPLICA IDENTITY FULL;

-- ============================================================
-- RPC ACCESS (idempotent grants for the mobile app)
-- ============================================================
GRANT EXECUTE ON FUNCTION public.send_message(UUID, TEXT, TEXT, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_direct_chat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_call(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_messages_delivered(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_messages_read(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_message_for_everyone(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_chat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_message_permanently(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_all_messages_permanently(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_storage_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_storage_buckets() TO anon;
GRANT EXECUTE ON FUNCTION public.is_chat_participant(UUID) TO anon, authenticated;



/* ===================== 018_reclaim_phone.sql ===================== */

-- Crystal Messenger - Migration 018
-- Self-healing phone reclaim for anonymous re-onboarding.
--
-- Problem: anonymous sign-in creates a fresh auth user each time. If a user
-- logs out (or the app is reinstalled / process killed before logout cleanup)
-- and then creates a profile again with the SAME phone number, the old
-- anonymous profile row still holds that phone, so the new user's upsert
-- violates the partial unique index `profiles_phone_unique`.
--
-- Fix: a SECURITY DEFINER RPC that moves the phone to the CURRENT user by
-- first releasing it from any other profile row. The app calls this right
-- before upserting the profile, making re-onboarding idempotent in every case.

-- Release the current user's own phone (clean logout cleanup).
CREATE OR REPLACE FUNCTION public.release_my_phone()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles SET phone = '' WHERE id = auth.uid() AND phone <> '';
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_my_phone() TO authenticated;

-- Reassign a phone to the current user: free it from any other profile first.
CREATE OR REPLACE FUNCTION public.claim_phone(p_phone text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles SET phone = '' WHERE phone = p_phone AND id <> auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_phone(text) TO authenticated;
/* ===================== 019_reconciliation_and_user_management.sql ===================== */

-- v1.1 reconciliation + user management.
-- Creates the tables declared in the app type layer (schema drift fix) and adds
-- self-service account management RPCs. Fully idempotent: safe on fresh and
-- existing databases.

-- ---------------------------------------------------------------------------
-- MESSAGE REACTIONS (WhatsApp-style emoji reactions)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT message_reactions_unique UNIQUE (message_id, user_id, emoji)
);

CREATE INDEX IF NOT EXISTS idx_message_reactions_message ON public.message_reactions(message_id);
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "MessageReactions: participants can read" ON public.message_reactions;
CREATE POLICY "MessageReactions: participants can read" ON public.message_reactions
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = message_id AND public.is_chat_participant(m.chat_id)
  ));

DROP POLICY IF EXISTS "MessageReactions: participants can insert" ON public.message_reactions;
CREATE POLICY "MessageReactions: participants can insert" ON public.message_reactions
  FOR INSERT
  WITH CHECK (user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = message_id AND public.is_chat_participant(m.chat_id)
  ));

DROP POLICY IF EXISTS "MessageReactions: users can delete own" ON public.message_reactions;
CREATE POLICY "MessageReactions: users can delete own" ON public.message_reactions
  FOR DELETE
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- ATTACHMENTS (rich media metadata on messages)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_size BIGINT DEFAULT 0,
  mime_type TEXT DEFAULT 'application/octet-stream',
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  duration DOUBLE PRECISION,
  width INTEGER,
  height INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attachments_message ON public.attachments(message_id);
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Attachments: participants can read" ON public.attachments;
CREATE POLICY "Attachments: participants can read" ON public.attachments
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = message_id AND public.is_chat_participant(m.chat_id)
  ));

DROP POLICY IF EXISTS "Attachments: participants can insert" ON public.attachments;
CREATE POLICY "Attachments: participants can insert" ON public.attachments
  FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = message_id AND public.is_chat_participant(m.chat_id)
  ));

-- ---------------------------------------------------------------------------
-- BLOCKED USERS (explicit block registry)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.blocked_users (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, blocked_user_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "BlockedUsers: users can read own" ON public.blocked_users;
CREATE POLICY "BlockedUsers: users can read own" ON public.blocked_users
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "BlockedUsers: users can insert own" ON public.blocked_users;
CREATE POLICY "BlockedUsers: users can insert own" ON public.blocked_users
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "BlockedUsers: users can delete own" ON public.blocked_users;
CREATE POLICY "BlockedUsers: users can delete own" ON public.blocked_users
  FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- GROUPS & GROUP MEMBERS (multi-party conversations)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  invite_link TEXT,
  is_private BOOLEAN DEFAULT false,
  max_members INTEGER DEFAULT 512,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin', 'owner')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  invited_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  CONSTRAINT group_members_unique UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_groups_chat ON public.groups(chat_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group ON public.group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON public.group_members(user_id);
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Groups: chat participants can read" ON public.groups;
CREATE POLICY "Groups: chat participants can read" ON public.groups
  FOR SELECT USING (public.is_chat_participant(chat_id));

DROP POLICY IF EXISTS "Groups: chat participants can insert" ON public.groups;
CREATE POLICY "Groups: chat participants can insert" ON public.groups
  FOR INSERT WITH CHECK (public.is_chat_participant(chat_id));

DROP POLICY IF EXISTS "GroupMembers: group chat participants can read" ON public.group_members;
CREATE POLICY "GroupMembers: group chat participants can read" ON public.group_members
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.groups g WHERE g.id = group_id AND public.is_chat_participant(g.chat_id)
  ));

DROP POLICY IF EXISTS "GroupMembers: users can insert own" ON public.group_members;
CREATE POLICY "GroupMembers: users can insert own" ON public.group_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "GroupMembers: users can update own" ON public.group_members;
CREATE POLICY "GroupMembers: users can update own" ON public.group_members
  FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "GroupMembers: users can delete own" ON public.group_members;
CREATE POLICY "GroupMembers: users can delete own" ON public.group_members
  FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- IN-APP NOTIFICATIONS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'system' CHECK (type IN ('message', 'call', 'group_invite', 'mention', 'reaction', 'system')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, created_at DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notifications: users can read own" ON public.notifications;
CREATE POLICY "Notifications: users can read own" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Notifications: users can insert own" ON public.notifications;
CREATE POLICY "Notifications: users can insert own" ON public.notifications
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Notifications: users can update own" ON public.notifications;
CREATE POLICY "Notifications: users can update own" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Notifications: users can delete own" ON public.notifications;
CREATE POLICY "Notifications: users can delete own" ON public.notifications
  FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- USER MANAGEMENT RPCs
-- ---------------------------------------------------------------------------

-- Change your phone number: free it from any other profile, then claim it.
CREATE OR REPLACE FUNCTION public.change_phone_number(p_new_phone text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_new_phone IS NULL OR trim(p_new_phone) = '' THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;
  UPDATE public.profiles SET phone = '' WHERE phone = p_new_phone AND id <> auth.uid();
  UPDATE public.profiles SET phone = p_new_phone WHERE id = auth.uid();
END;
$$;

-- Permanently delete the account and ALL associated data. Deleting the
-- auth.users row cascades to profiles and (via FK ON DELETE CASCADE) every
-- chat, message, contact, call, push token and reaction the user owns.
CREATE OR REPLACE FUNCTION public.delete_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  DELETE FROM public.profiles WHERE id = auth.uid();
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.change_phone_number(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_phone(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_my_phone() TO authenticated;

-- ---------------------------------------------------------------------------
-- REALTIME (idempotent publication for the new tables)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'message_reactions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'blocked_users') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.blocked_users;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;

