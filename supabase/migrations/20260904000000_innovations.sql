-- Crystal Messenger - Innovations Migration
-- Adds: Polls, Scheduled Messages, Message Threading, E2EE support

-- ============================================================
-- 1. POLLS - Interactive polls in group chats
-- ============================================================

CREATE TABLE IF NOT EXISTS public.polls (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  is_anonymous BOOLEAN DEFAULT true,
  is_multiple_choice BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.poll_options (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.poll_votes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(poll_id, option_id, user_id)
);

ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can view polls" ON public.polls
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE chat_participants.chat_id = polls.chat_id
      AND chat_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "Participants can create polls" ON public.polls
  FOR INSERT WITH CHECK (
    auth.uid() = creator_id
    AND EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE chat_participants.chat_id = polls.chat_id
      AND chat_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "Participants can view poll options" ON public.poll_options
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.polls p
      JOIN public.chat_participants cp ON cp.chat_id = p.chat_id
      WHERE p.id = poll_options.poll_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Poll creators can add options" ON public.poll_options
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.polls WHERE id = poll_id AND creator_id = auth.uid()
    )
  );

CREATE POLICY "Participants can view poll votes" ON public.poll_votes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.polls p
      JOIN public.chat_participants cp ON cp.chat_id = p.chat_id
      WHERE p.id = poll_votes.poll_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Participants can vote" ON public.poll_votes
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.polls p
      JOIN public.chat_participants cp ON cp.chat_id = p.chat_id
      WHERE p.id = poll_votes.poll_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own votes" ON public.poll_votes
  FOR DELETE USING (auth.uid() = user_id);

-- RPC: Create a poll with options
CREATE OR REPLACE FUNCTION public.create_poll(
  p_chat_id UUID,
  p_question TEXT,
  p_options TEXT[],
  p_is_anonymous BOOLEAN DEFAULT true,
  p_is_multiple_choice BOOLEAN DEFAULT false,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  new_poll UUID;
  opt_text TEXT;
  pos INTEGER := 0;
BEGIN
  PERFORM public.assert_not_suspended();

  IF p_question IS NULL OR btrim(p_question) = '' THEN
    RAISE EXCEPTION 'Poll question is required';
  END IF;

  IF array_length(p_options, 1) < 2 THEN
    RAISE EXCEPTION 'At least 2 options are required';
  END IF;

  INSERT INTO public.polls (chat_id, creator_id, question, is_anonymous, is_multiple_choice, expires_at)
  VALUES (p_chat_id, auth.uid(), btrim(p_question), p_is_anonymous, p_is_multiple_choice, p_expires_at)
  RETURNING id INTO new_poll;

  FOREACH opt_text IN ARRAY p_options LOOP
    INSERT INTO public.poll_options (poll_id, text, position)
    VALUES (new_poll, btrim(opt_text), pos);
    pos := pos + 1;
  END LOOP;

  RETURN jsonb_build_object('poll_id', new_poll);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Vote on a poll
CREATE OR REPLACE FUNCTION public.vote_poll(
  p_poll_id UUID,
  p_option_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_poll RECORD;
BEGIN
  PERFORM public.assert_not_suspended();

  SELECT * INTO v_poll FROM public.polls WHERE id = p_poll_id;

  IF v_poll IS NULL THEN
    RAISE EXCEPTION 'Poll not found';
  END IF;

  IF v_poll.is_multiple_choice = false THEN
    DELETE FROM public.poll_votes WHERE poll_id = p_poll_id AND user_id = auth.uid();
  END IF;

  INSERT INTO public.poll_votes (poll_id, option_id, user_id)
  VALUES (p_poll_id, p_option_id, auth.uid())
  ON CONFLICT (poll_id, option_id, user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Get poll results
CREATE OR REPLACE FUNCTION public.get_poll_results(p_poll_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_poll RECORD;
  v_options JSONB;
BEGIN
  SELECT * INTO v_poll FROM public.polls WHERE id = p_poll_id;

  IF v_poll IS NULL THEN
    RAISE EXCEPTION 'Poll not found';
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', po.id,
    'text', po.text,
    'position', po.position,
    'vote_count', (SELECT COUNT(*) FROM public.poll_votes pv WHERE pv.option_id = po.id),
    'has_voted', EXISTS(SELECT 1 FROM public.poll_votes pv WHERE pv.option_id = po.id AND pv.user_id = auth.uid())
  ) ORDER BY po.position) INTO v_options
  FROM public.poll_options po WHERE po.poll_id = p_poll_id;

  RETURN jsonb_build_object(
    'poll', jsonb_build_object(
      'id', v_poll.id,
      'question', v_poll.question,
      'is_anonymous', v_poll.is_anonymous,
      'is_multiple_choice', v_poll.is_multiple_choice,
      'expires_at', v_poll.expires_at,
      'created_at', v_poll.created_at
    ),
    'options', COALESCE(v_options, '[]'::jsonb),
    'total_votes', (SELECT COUNT(DISTINCT user_id) FROM public.poll_votes WHERE poll_id = p_poll_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.create_poll(UUID, TEXT, TEXT[], BOOLEAN, BOOLEAN, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_poll(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_poll_results(UUID) TO authenticated;

-- ============================================================
-- 2. SCHEDULED MESSAGES - Queue messages for later delivery
-- ============================================================

CREATE TABLE IF NOT EXISTS public.scheduled_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chat_id UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text',
  metadata JSONB,
  scheduled_for TIMESTAMPTZ NOT NULL,
  is_sent BOOLEAN DEFAULT false,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.scheduled_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their scheduled messages" ON public.scheduled_messages
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create scheduled messages" ON public.scheduled_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can cancel their scheduled messages" ON public.scheduled_messages
  FOR DELETE USING (auth.uid() = user_id AND is_sent = false);

-- RPC: Schedule a message
CREATE OR REPLACE FUNCTION public.schedule_message(
  p_chat_id UUID,
  p_content TEXT,
  p_message_type TEXT DEFAULT 'text',
  p_metadata JSONB DEFAULT NULL,
  p_scheduled_for TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
  new_id UUID;
BEGIN
  PERFORM public.assert_not_suspended();

  IF p_content IS NULL OR btrim(p_content) = '' THEN
    RAISE EXCEPTION 'Message content is required';
  END IF;

  IF p_scheduled_for <= now() THEN
    RAISE EXCEPTION 'Schedule time must be in the future';
  END IF;

  INSERT INTO public.scheduled_messages (user_id, chat_id, content, message_type, metadata, scheduled_for)
  VALUES (auth.uid(), p_chat_id, p_content, p_message_type, p_metadata, p_scheduled_for)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('scheduled_message_id', new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Cancel a scheduled message
CREATE OR REPLACE FUNCTION public.cancel_scheduled_message(p_message_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.scheduled_messages
  WHERE id = p_message_id AND user_id = auth.uid() AND is_sent = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Get scheduled messages for a chat
CREATE OR REPLACE FUNCTION public.get_scheduled_messages(p_chat_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(jsonb_build_object(
      'id', sm.id,
      'content', sm.content,
      'message_type', sm.message_type,
      'scheduled_for', sm.scheduled_for,
      'created_at', sm.created_at
    ) ORDER BY sm.scheduled_for)
    FROM public.scheduled_messages sm
    WHERE sm.chat_id = p_chat_id
    AND sm.user_id = auth.uid()
    AND sm.is_sent = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to process due scheduled messages (called by pg_cron)
CREATE OR REPLACE FUNCTION public.process_scheduled_messages()
RETURNS void AS $$
BEGIN
  INSERT INTO public.messages (chat_id, sender_id, content, message_type, metadata)
  SELECT sm.chat_id, sm.user_id, sm.content, sm.message_type, sm.metadata
  FROM public.scheduled_messages sm
  WHERE sm.is_sent = false
  AND sm.scheduled_for <= now();

  UPDATE public.scheduled_messages
  SET is_sent = true, sent_at = now()
  WHERE is_sent = false
  AND scheduled_for <= now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.schedule_message(UUID, TEXT, TEXT, JSONB, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_scheduled_message(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_scheduled_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_scheduled_messages() TO service_role;

-- ============================================================
-- 3. MESSAGE THREADING - Reply threads for organized conversations
-- ============================================================

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS thread_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS thread_reply_count INTEGER DEFAULT 0;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS thread_last_reply_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_messages_thread_id ON public.messages(thread_id);

-- RPC: Get thread messages
CREATE OR REPLACE FUNCTION public.get_thread_messages(p_thread_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(jsonb_build_object(
      'id', m.id,
      'chat_id', m.chat_id,
      'sender_id', m.sender_id,
      'content', m.content,
      'message_type', m.message_type,
      'created_at', m.created_at,
      'sender_name', p.full_name
    ) ORDER BY m.created_at ASC)
    FROM public.messages m
    LEFT JOIN public.profiles p ON p.id = m.sender_id
    WHERE m.thread_id = p_thread_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Send a thread reply
CREATE OR REPLACE FUNCTION public.send_thread_reply(
  p_thread_id UUID,
  p_content TEXT,
  p_message_type TEXT DEFAULT 'text'
)
RETURNS JSONB AS $$
DECLARE
  new_msg UUID;
  chat_id_val UUID;
BEGIN
  PERFORM public.assert_not_suspended();

  SELECT chat_id INTO chat_id_val FROM public.messages WHERE id = p_thread_id;

  IF chat_id_val IS NULL THEN
    RAISE EXCEPTION 'Thread message not found';
  END IF;

  INSERT INTO public.messages (chat_id, sender_id, content, message_type, thread_id)
  VALUES (chat_id_val, auth.uid(), p_content, p_message_type, p_thread_id)
  RETURNING id INTO new_msg;

  UPDATE public.messages
  SET thread_reply_count = thread_reply_count + 1,
      thread_last_reply_at = now()
  WHERE id = p_thread_id;

  RETURN jsonb_build_object('message_id', new_msg);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_thread_messages(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_thread_reply(UUID, TEXT, TEXT) TO authenticated;

-- ============================================================
-- 4. E2EE KEY REGISTRATION - Prekey bundle storage
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_key_bundles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  identity_public_key TEXT NOT NULL,
  signed_prekey_public TEXT NOT NULL,
  signed_prekey_signature TEXT NOT NULL,
  one_time_prekeys TEXT[] DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_key_bundles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view key bundles" ON public.user_key_bundles
  FOR SELECT USING (true);

CREATE POLICY "Users can upsert their own key bundle" ON public.user_key_bundles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own key bundle" ON public.user_key_bundles
  FOR UPDATE USING (auth.uid() = user_id);

-- RPC: Upload key bundle
CREATE OR REPLACE FUNCTION public.upload_key_bundle(
  p_identity_public_key TEXT,
  p_signed_prekey_public TEXT,
  p_signed_prekey_signature TEXT,
  p_one_time_prekeys TEXT[] DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.user_key_bundles (user_id, identity_public_key, signed_prekey_public, signed_prekey_signature, one_time_prekeys)
  VALUES (auth.uid(), p_identity_public_key, p_signed_prekey_public, p_signed_prekey_signature, p_one_time_prekeys)
  ON CONFLICT (user_id) DO UPDATE SET
    identity_public_key = EXCLUDED.identity_public_key,
    signed_prekey_public = EXCLUDED.signed_prekey_public,
    signed_prekey_signature = EXCLUDED.signed_prekey_signature,
    one_time_prekeys = EXCLUDED.one_time_prekeys,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Get a user's key bundle
CREATE OR REPLACE FUNCTION public.get_key_bundle(p_user_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'user_id', user_id,
      'identity_public_key', identity_public_key,
      'signed_prekey_public', signed_prekey_public,
      'signed_prekey_signature', signed_prekey_signature,
      'one_time_prekeys', one_time_prekeys
    )
    FROM public.user_key_bundles
    WHERE user_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Consume a one-time prekey
CREATE OR REPLACE FUNCTION public.consume_one_time_prekey(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_key TEXT;
BEGIN
  SELECT one_time_prekeys[1] INTO v_key
  FROM public.user_key_bundles
  WHERE user_id = p_user_id
  AND array_length(one_time_prekeys, 1) > 0;

  IF v_key IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE public.user_key_bundles
  SET one_time_prekeys = one_time_prekeys[2:]
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object('one_time_prekey', v_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.upload_key_bundle(TEXT, TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_key_bundle(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.consume_one_time_prekey(UUID) TO authenticated;

-- ============================================================
-- 5. ENCRYPTED MESSAGE COLUMNS
-- ============================================================

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_encrypted BOOLEAN DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS encryption_version INTEGER DEFAULT 0;

-- ============================================================
-- 6. MESSAGE REACTIONS UPGRADE - Custom emoji support
-- ============================================================

-- Drop existing reaction policy and recreate with emoji length check
DROP POLICY IF EXISTS "Participants can react" ON public.message_reactions;
CREATE POLICY "Participants can react" ON public.message_reactions
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND length(emoji) <= 8
    AND EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.chat_participants cp ON cp.chat_id = m.chat_id
      WHERE m.id = message_reactions.message_id
      AND cp.user_id = auth.uid()
    )
  );
