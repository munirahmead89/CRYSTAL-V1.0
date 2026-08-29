-- ============================================================
-- Crystal Messenger — WhatsApp parity features
-- Pinned / Archived / Muted chats, Starred messages,
-- Emoji reactions, Disappearing messages, Broadcast lists
-- ============================================================

-- 1. Per-participant chat flags --------------------------------
ALTER TABLE public.chat_participants
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT false;

-- 2. Allow 'broadcast' chat type -------------------------------
ALTER TABLE public.chats DROP CONSTRAINT IF EXISTS chats_type_check;
ALTER TABLE public.chats
  ADD CONSTRAINT chats_type_check
  CHECK (type IN ('direct', 'group', 'channel', 'broadcast'));

-- 3. Starred messages -------------------------------------------
CREATE TABLE IF NOT EXISTS public.starred_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, message_id)
);
CREATE INDEX IF NOT EXISTS idx_starred_user ON public.starred_messages(user_id);
ALTER TABLE public.starred_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Starred: owner manage" ON public.starred_messages;
CREATE POLICY "Starred: owner manage" ON public.starred_messages
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 4. send_message: accept metadata -----------------------------
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
    RAISE EXCEPTION 'Not a participant of this chat';
  END IF;

  INSERT INTO messages (chat_id, sender_id, content, message_type, reply_to_id, metadata)
  VALUES (p_chat_id, auth.uid(), p_content, p_message_type, p_reply_to_id, p_metadata)
  RETURNING id INTO new_message_id;

  UPDATE chats SET updated_at = now() WHERE id = p_chat_id;
  RETURN new_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. chat_with_last_message: include per-user flags -----------
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
    WHERE cp.chat_id = c.id AND cp.user_id <> auth.uid()
    ORDER BY cp.joined_at ASC
    LIMIT 1
  ) AS other_participant,
  (
    SELECT jsonb_build_object(
      'is_pinned', COALESCE(cp.is_pinned, false),
      'is_archived', COALESCE(cp.is_archived, false),
      'is_muted', COALESCE(cp.is_muted, false),
      'mute_until', cp.mute_until
    )
    FROM chat_participants cp
    WHERE cp.chat_id = c.id AND cp.user_id = auth.uid()
    LIMIT 1
  ) AS my_participant,
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

-- 6. Chat setting RPCs ----------------------------------------
CREATE OR REPLACE FUNCTION public.set_chat_pin(p_chat_id UUID, p_pinned BOOLEAN)
RETURNS void AS $$
BEGIN
  UPDATE chat_participants SET is_pinned = p_pinned
  WHERE chat_id = p_chat_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.set_chat_archive(p_chat_id UUID, p_archived BOOLEAN)
RETURNS void AS $$
BEGIN
  UPDATE chat_participants SET is_archived = p_archived
  WHERE chat_id = p_chat_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.set_chat_mute(p_chat_id UUID, p_muted BOOLEAN, p_mute_until TIMESTAMPTZ DEFAULT NULL)
RETURNS void AS $$
BEGIN
  UPDATE chat_participants SET is_muted = p_muted, mute_until = p_mute_until
  WHERE chat_id = p_chat_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.set_disappearing_timer(p_chat_id UUID, p_timer INTEGER)
RETURNS void AS $$
BEGIN
  UPDATE chats SET disappearing_timer = p_timer WHERE id = p_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Reaction toggle ------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_reaction(p_message_id UUID, p_emoji TEXT)
RETURNS void AS $$
DECLARE
  v_chat UUID;
BEGIN
  SELECT chat_id INTO v_chat FROM messages WHERE id = p_message_id;
  IF NOT EXISTS (SELECT 1 FROM chat_participants WHERE chat_id = v_chat AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Not a participant';
  END IF;

  IF EXISTS (SELECT 1 FROM message_reactions WHERE message_id = p_message_id AND user_id = auth.uid() AND emoji = p_emoji) THEN
    DELETE FROM message_reactions WHERE message_id = p_message_id AND user_id = auth.uid() AND emoji = p_emoji;
  ELSE
    INSERT INTO message_reactions (message_id, user_id, emoji)
    VALUES (p_message_id, auth.uid(), p_emoji)
    ON CONFLICT (message_id, user_id, emoji) DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Star toggle ----------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_star(p_message_id UUID)
RETURNS void AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM starred_messages WHERE message_id = p_message_id AND user_id = auth.uid()) THEN
    DELETE FROM starred_messages WHERE message_id = p_message_id AND user_id = auth.uid();
  ELSE
    INSERT INTO starred_messages (user_id, message_id) VALUES (auth.uid(), p_message_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Broadcast list creation ----------------------------------
CREATE OR REPLACE FUNCTION public.create_broadcast(p_name TEXT, p_recipient_ids UUID[])
RETURNS UUID AS $$
DECLARE
  new_chat UUID;
  rid UUID;
BEGIN
  INSERT INTO chats (type, name, created_by) VALUES ('broadcast', p_name, auth.uid())
  RETURNING id INTO new_chat;
  INSERT INTO chat_participants (chat_id, user_id, role)
  VALUES (new_chat, auth.uid(), 'owner');
  FOREACH rid IN ARRAY p_recipient_ids LOOP
    INSERT INTO chat_participants (chat_id, user_id, role)
    VALUES (new_chat, rid, 'member')
    ON CONFLICT (chat_id, user_id) DO NOTHING;
  END LOOP;
  RETURN new_chat;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
