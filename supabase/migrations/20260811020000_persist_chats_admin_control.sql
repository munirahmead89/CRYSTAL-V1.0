-- Crystal Messenger - v1.1.1 backend hardening
-- 1) WhatsApp-style persistence: DISABLE the "relay mode" 24h auto-delete that
--    was hard-deleting messages (and even empty chats) so conversations never
--    vanish after a day. Messages now persist like WhatsApp.
-- 2) Full admin control: admin_users table, is_admin()/is_suspended() helpers,
--    and SUSPEND / UN-SUSPEND / PROMOTE / DEMOTE / DELETE-ACCOUNT RPCs callable
--    from the Supabase SQL Editor or any HTTP client with a role key.
-- 3) Suspension enforcement inside the SECURITY DEFINER write functions and the
--    chat/message read policies, so a suspended user can neither send nor read.
-- 4) Realtime publication additions (chats, notifications, reactions, blocked).
--
-- Bootstrapping your first admin (run once in the Supabase SQL Editor):
--   INSERT INTO public.admin_users (user_id) VALUES ('<your-auth-user-uuid>');
-- The SQL Editor runs as the database owner and therefore bypasses RLS, so this
-- plain INSERT works. After that you can use the RPCs below.

/* =====================================================================
   1. PERSISTENCE (kill the relay auto-delete)
   ===================================================================== */

-- Neutralize cleanup_delivered_messages: it was invoked synchronously by
-- mark_messages_read() (called every time the app opens a chat) and deleted
-- every message older than 24h once it had been read.
CREATE OR REPLACE FUNCTION public.cleanup_delivered_messages()
RETURNS void AS $$
BEGIN
  -- Disabled (v1.1.1): conversations persist like WhatsApp. Previously this
  -- hard-deleted read messages older than 24 hours.
  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Neutralize auto_disappear_messages (7-day wipe) — keep everything.
CREATE OR REPLACE FUNCTION public.auto_disappear_messages()
RETURNS void AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Neutralize purge_expired_chats (24h media/message/chat purge). Now a no-op
-- so that even if it is ever scheduled via pg_cron it cannot erase anything.
CREATE OR REPLACE FUNCTION public.purge_expired_chats()
RETURNS void AS $$
BEGIN
  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop any previously scheduled cron jobs referencing the old purge.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname IN ('purge-chats-24h','cleanup-messages','disappear-messages')) THEN
      PERFORM cron.unschedule(jobid) FROM cron.job
        WHERE jobname IN ('purge-chats-24h','cleanup-messages','disappear-messages');
    END IF;
  END IF;
END $$;

-- Recreate mark_messages_read WITHOUT calling the cleanup.
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

/* =====================================================================
   2. ADMIN CONTROL
   ===================================================================== */

-- Suspension state lives on profiles, so the client's profile read already
-- exposes it, but normal users are forbidden from changing those columns.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT;

-- Who is an admin (only readable by admins; written via SQL Editor or RPCs).
-- Created *before* is_admin() so the SQL-language helper resolves the table.
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Helper: is the current user an admin? (SECURITY DEFINER, bypasses RLS.)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid());
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

-- Helper: is the current user suspended? (SECURITY DEFINER, bypasses RLS.)
CREATE OR REPLACE FUNCTION public.is_suspended()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT is_suspended FROM public.profiles WHERE id = auth.uid()), false);
$$;

GRANT EXECUTE ON FUNCTION public.is_suspended() TO anon, authenticated;

-- Readable only by admins.
DROP POLICY IF EXISTS "AdminUsers: admins can read" ON public.admin_users;
CREATE POLICY "AdminUsers: admins can read" ON public.admin_users
  FOR SELECT
  USING (public.is_admin());

-- Hard guard used by every sensitive writer function.
CREATE OR REPLACE FUNCTION public.assert_not_suspended()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_suspended() THEN
    RAISE EXCEPTION 'Your account is suspended. Contact support.';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assert_not_suspended() TO authenticated;

-- Protect the suspension columns: only an admin may change them. Recreated as
-- SECURITY DEFINER so the admin RPCs (also SECURITY DEFINER) can pass.
CREATE OR REPLACE FUNCTION public.protect_profiles_admin_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_suspended IS DISTINCT FROM OLD.is_suspended
     OR NEW.suspended_at IS DISTINCT FROM OLD.suspended_at
     OR NEW.suspended_reason IS DISTINCT FROM OLD.suspended_reason THEN
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Only admins can modify account suspension state';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profiles_admin_columns ON public.profiles;
CREATE TRIGGER protect_profiles_admin_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profiles_admin_columns();

/* ---------------------------------------------------------------------
   ADMIN RPCs  (callable from the Supabase SQL Editor as a user, or via
   supabase.rpc() on an admin client)
   --------------------------------------------------------------------- */

-- Promote a user to admin.
CREATE OR REPLACE FUNCTION public.promote_to_admin(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Insufficient privileges';
  END IF;
  INSERT INTO public.admin_users (user_id, created_by)
  VALUES (p_user_id, auth.uid())
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;

-- Demote an admin.
CREATE OR REPLACE FUNCTION public.demote_from_admin(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() OR p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Insufficient privileges';
  END IF;
  DELETE FROM public.admin_users WHERE user_id = p_user_id;
END;
$$;

-- Suspend a user (blocks sending + reading).
CREATE OR REPLACE FUNCTION public.suspend_user(p_user_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Insufficient privileges';
  END IF;
  UPDATE public.profiles
  SET is_suspended = true,
      suspended_at = now(),
      suspended_reason = p_reason
  WHERE id = p_user_id;
END;
$$;

-- Lift a suspension.
CREATE OR REPLACE FUNCTION public.unsuspend_user(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Insufficient privileges';
  END IF;
  UPDATE public.profiles
  SET is_suspended = false,
      suspended_at = NULL,
      suspended_reason = NULL
  WHERE id = p_user_id;
END;
$$;

-- Admin delete of any account (auth.users cascades to profiles, chats, ...).
CREATE OR REPLACE FUNCTION public.delete_user_by_admin(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Insufficient privileges';
  END IF;
  DELETE FROM public.profiles WHERE id = p_user_id;
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

-- Admin overview: every user with their admin/suspension status.
CREATE OR REPLACE FUNCTION public.list_users_for_admin()
RETURNS TABLE (
  id UUID,
  phone TEXT,
  email TEXT,
  full_name TEXT,
  is_online BOOLEAN,
  is_suspended BOOLEAN,
  suspended_reason TEXT,
  suspended_at TIMESTAMPTZ,
  is_admin BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Insufficient privileges';
  END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.phone,
    p.email,
    p.full_name,
    COALESCE(p.is_online, false),
    COALESCE(p.is_suspended, false),
    p.suspended_reason,
    p.suspended_at,
    EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = p.id),
    p.created_at
  FROM public.profiles p
  ORDER BY p.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.promote_to_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.demote_from_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.suspend_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unsuspend_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_by_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_users_for_admin() TO authenticated;

/* =====================================================================
   3. ENFORCE SUSPENSION IN WRITE FUNCTIONS (participant-check + suspend)
   ===================================================================== */

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
  PERFORM public.assert_not_suspended();

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

CREATE OR REPLACE FUNCTION public.create_direct_chat(other_user_id UUID)
RETURNS UUID AS $$
DECLARE
  existing_chat_id UUID;
  new_chat_id UUID;
  other_exists BOOLEAN;
BEGIN
  PERFORM public.assert_not_suspended();

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

CREATE OR REPLACE FUNCTION public.mark_messages_delivered(
  p_chat_id UUID,
  p_message_ids UUID[]
)
RETURNS void AS $$
BEGIN
  PERFORM public.assert_not_suspended();

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

CREATE OR REPLACE FUNCTION public.log_call(
  p_chat_id UUID,
  p_type TEXT DEFAULT 'audio',
  p_status TEXT DEFAULT 'initiated'
)
RETURNS UUID AS $$
DECLARE
  new_call_id UUID;
BEGIN
  PERFORM public.assert_not_suspended();

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

CREATE OR REPLACE FUNCTION public.delete_message_for_everyone(p_message_id UUID)
RETURNS void AS $$
BEGIN
  PERFORM public.assert_not_suspended();
  UPDATE messages
  SET is_deleted = true, content = 'This message was deleted', deleted_at = now()
  WHERE id = p_message_id AND sender_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.clear_chat(p_chat_id UUID)
RETURNS void AS $$
BEGIN
  PERFORM public.assert_not_suspended();
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

CREATE OR REPLACE FUNCTION public.delete_message_permanently(p_message_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_not_suspended();
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

CREATE OR REPLACE FUNCTION public.delete_all_messages_permanently(p_chat_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_not_suspended();
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_participants cp
    WHERE cp.chat_id = p_chat_id AND cp.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant of this chat';
  END IF;

  DELETE FROM public.messages WHERE chat_id = p_chat_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_push_token(p_token TEXT, p_platform TEXT DEFAULT 'android', p_device_id TEXT DEFAULT NULL)
RETURNS void AS $$
BEGIN
  PERFORM public.assert_not_suspended();
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Refresh grants (current overloads).
GRANT EXECUTE ON FUNCTION public.send_message(UUID, TEXT, TEXT, UUID, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_direct_chat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_call(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_messages_delivered(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_messages_read(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_message_for_everyone(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_chat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_message_permanently(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_all_messages_permanently(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_push_token(TEXT, TEXT, TEXT) TO authenticated;

/* =====================================================================
   4. BLOCK SUSPENDED USERS FROM READING (chat list, messages, members)
   ===================================================================== */

DROP POLICY IF EXISTS "Chats: participants can read" ON public.chats;
CREATE POLICY "Chats: participants can read" ON public.chats
  FOR SELECT
  USING (
    NOT public.is_suspended()
    AND id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

-- Drop the dashboard-generated leftovers so no dual policy lets suspended
-- users through.
DROP POLICY IF EXISTS "chats: select participating" ON public.chats;

DROP POLICY IF EXISTS "Messages: participants can read" ON public.messages;
CREATE POLICY "Messages: participants can read" ON public.messages
  FOR SELECT
  USING (
    NOT public.is_suspended()
    AND chat_id IN (
      SELECT chat_id FROM chat_participants
      WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "messages: select participating" ON public.messages;

DROP POLICY IF EXISTS "ChatParticipants: participants can read" ON public.chat_participants;
CREATE POLICY "ChatParticipants: participants can read" ON public.chat_participants
  FOR SELECT
  USING (
    NOT public.is_suspended()
    AND public.is_chat_participant(chat_id)
  );

DROP POLICY IF EXISTS "chat_participants: select own chats" ON public.chat_participants;

/* =====================================================================
   5. REALTIME PUBLICATION (chats, notifications, reactions, blocked)
   ===================================================================== */

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chats') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'message_reactions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'blocked_users') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.blocked_users;
  END IF;
END $$;