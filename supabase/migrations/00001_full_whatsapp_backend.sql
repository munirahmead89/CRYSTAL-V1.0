-- Crystal Messenger / CCLINT consolidated WhatsApp-like backend
-- Apply this single file to a fresh or existing Supabase project.
-- Ordered source: 00031 -> 00032 -> 00033 -> 00034 -> 00035.
-- This file is generated from the repository migrations; do not apply source files separately.

-- ============================================================================
-- 00031_full_whatsapp_relay.sql — Combined WhatsApp-Like Relay Migration
-- ============================================================================
-- Run PREFLIGHT.sql FIRST (READ ONLY - checks database state, changes nothing).
-- Then run this single migration.
-- ============================================================================

SET search_path = public;

-- ============================================================================
-- 1. BASE TABLES & CORE IDENTITIES (from 00030_MASTER_SCHEMA.sql)
-- ============================================================================

-- 1.1 Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT UNIQUE,
  display_name TEXT,
  avatar_url TEXT,
  about TEXT DEFAULT 'Hey there! I am using Crystal Messenger.',
  last_seen TIMESTAMPTZ DEFAULT now(),
  is_online BOOLEAN DEFAULT false,
  verified BOOLEAN DEFAULT false,
  role TEXT DEFAULT 'user',
  is_banned BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1.2 Devices Table (For Multi-device sync & QR linking)
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  device_name TEXT NOT NULL,
  push_token TEXT,
  device_model TEXT,
  device_os TEXT,
  device_manufacturer TEXT,
  device_locale TEXT,
  app_version TEXT,
  is_current_device BOOLEAN NOT NULL DEFAULT false,
  last_active_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS devices_one_current_uidx
  ON public.devices (user_id)
  WHERE is_current_device = true;

-- 1.3 Device Link Sessions (QR Code Web/Desktop Linking)
CREATE TABLE IF NOT EXISTS public.device_link_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_token TEXT UNIQUE NOT NULL,
  primary_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  device_name TEXT NOT NULL,
  public_key TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, authorized, rejected, expired
  authorized_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '5 minutes'),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1.4 Conversations Table
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'direct', -- direct, group, channel
  title TEXT,
  avatar_url TEXT,
  description TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_message_id UUID,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  disappearing_duration_seconds INT DEFAULT 0, -- 0 = off
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1.5 Conversation Members
CREATE TABLE IF NOT EXISTS public.conversation_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- admin, member
  muted_until TIMESTAMPTZ,
  unread_count INT DEFAULT 0,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- 1.6 Messages Table (Ephemeral Relay Enabled)
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'text', -- text, image, video, audio, document, location, contact
  content TEXT,
  attachment JSONB,
  reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  forwarded BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'sent', -- sent, delivered, read, failed
  delivered_to_all BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  ephemeral_cleaned BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON public.messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_forwarded
  ON public.messages (conversation_id, created_at DESC)
  WHERE forwarded = true;

-- 1.7 Message Receipts
CREATE TABLE IF NOT EXISTS public.message_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'delivered', -- delivered, read
  timestamp TIMESTAMPTZ DEFAULT now(),
  UNIQUE(message_id, user_id, status)
);

-- 1.8 Message Reactions
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(message_id, user_id)
);

-- Per-device delivery/read acknowledgements and message tombstones.
-- These tables are created before the read-receipt functions and grants below.
CREATE TABLE IF NOT EXISTS public.message_device_acks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL,
  ack_kind TEXT NOT NULL CHECK (ack_kind IN ('delivered', 'read', 'played')),
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ack_version BIGINT NOT NULL DEFAULT 1,
  UNIQUE(message_id, device_id, ack_kind)
);

CREATE INDEX IF NOT EXISTS idx_message_device_acks_message
  ON public.message_device_acks(message_id, ack_kind);

CREATE TABLE IF NOT EXISTS public.message_tombstones (
  message_id UUID PRIMARY KEY REFERENCES public.messages(id) ON DELETE CASCADE,
  deleted_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reason TEXT
);

ALTER TABLE public.message_device_acks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_tombstones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Message acks own read" ON public.message_device_acks;
CREATE POLICY "Message acks own read" ON public.message_device_acks
  FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Message tombstones own read" ON public.message_tombstones;
CREATE POLICY "Message tombstones own read" ON public.message_tombstones
  FOR SELECT TO authenticated USING (deleted_by = auth.uid());

-- ############################################################################
-- 2. CHUNKED MEDIA PIPELINE (Zero Buffer Memory Leaks)
-- ############################################################################

DO $$
BEGIN
  -- The parent upload table must exist before media_chunks can reference it.
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = 'media_uploads'
  ) THEN
    CREATE TABLE public.media_uploads (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      uploader_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      file_name TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      total_bytes BIGINT NOT NULL,
      chunk_size_bytes INT NOT NULL,
      total_chunks INT NOT NULL,
      file_sha256 TEXT NOT NULL,
      completed BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMPTZ DEFAULT now(),
      updated_at TIMESTAMPTZ DEFAULT now()
    );
  END IF;

  -- Safe: create media_chunks if it doesn't exist; if it does exist but is
  -- missing chunk_index, add it (as NULL first, then populate, then NOT NULL).
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = 'media_chunks'
  ) THEN
    CREATE TABLE public.media_chunks (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      upload_id UUID NOT NULL REFERENCES public.media_uploads(id) ON DELETE CASCADE,
      chunk_index INT NOT NULL,
      chunk_bytes BYTEA NOT NULL,
      chunk_sha256 TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now(),
      UNIQUE(upload_id, chunk_index)
    );
  ELSE
    -- Table exists; ensure chunk_index column exists.
    IF NOT EXISTS (
      SELECT 1 FROM pg_attribute WHERE attrelid = 'media_chunks'::regclass AND attname = 'chunk_index'
    ) THEN
      -- Add nullable first, populate, then make NOT NULL.
      ALTER TABLE public.media_chunks ADD COLUMN chunk_index INT;
      UPDATE public.media_chunks SET chunk_index = 1 WHERE chunk_index IS NULL;
      ALTER TABLE public.media_chunks ALTER COLUMN chunk_index SET NOT NULL;
    END IF;
  END IF;
END
$$;

DO $$
BEGIN
  -- Ensure media_uploads has the expected columns (idempotent).
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = 'media_uploads'
  ) THEN
    CREATE TABLE public.media_uploads (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      uploader_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      file_name TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      total_bytes BIGINT NOT NULL,
      chunk_size_bytes INT NOT NULL,
      total_chunks INT NOT NULL,
      file_sha256 TEXT NOT NULL,
      completed BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMPTZ DEFAULT now(),
      updated_at TIMESTAMPTZ DEFAULT now()
    );
  ELSE
    -- Table exists; add any missing columns gently.
    IF NOT EXISTS (
      SELECT 1 FROM pg_attribute WHERE attrelid = 'media_uploads'::regclass AND attname = 'total_chunks'
    ) THEN
      ALTER TABLE public.media_uploads ADD COLUMN total_chunks INT NOT NULL DEFAULT 1;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_attribute WHERE attrelid = 'media_uploads'::regclass AND attname = 'chunk_size_bytes'
    ) THEN
      ALTER TABLE public.media_uploads ADD COLUMN chunk_size_bytes INT NOT NULL DEFAULT 1;
    END IF;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_media_chunks_upload
  ON public.media_chunks(upload_id, chunk_index);

-- ############################################################################
-- 3. STATUSES (WhatsApp Stories)
-- ############################################################################

CREATE TABLE IF NOT EXISTS public.statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_url TEXT,
  caption TEXT,
  type TEXT NOT NULL DEFAULT 'text',
  background_color TEXT,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.status_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id UUID NOT NULL REFERENCES public.statuses(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(status_id, viewer_id)
);

-- ############################################################################
-- 3. RELAY CONFIGURATION TABLE
-- ############################################################################

-- Relay config table with immediate cleanup settings
CREATE TABLE IF NOT EXISTS public.relay_config (
  id boolean PRIMARY KEY DEFAULT true,
  cleanup_grace_seconds integer NOT NULL DEFAULT 900,
  require_all_devices boolean NOT NULL DEFAULT true,
  delete_window_seconds integer NOT NULL DEFAULT 60,
  max_message_bytes integer NOT NULL DEFAULT 16384,
  max_media_bytes integer NOT NULL DEFAULT 262144,
  tombstone_retention_days integer NOT NULL DEFAULT 30,
  per_user_messages_per_minute integer NOT NULL DEFAULT 120,
  per_device_messages_per_minute integer NOT NULL DEFAULT 60,
  per_user_acks_per_minute integer NOT NULL DEFAULT 600,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT relay_config_singleton CHECK (id),
  CONSTRAINT relay_config_grace_positive CHECK (cleanup_grace_seconds >= 0),
  CONSTRAINT relay_config_batch_bounded CHECK (per_user_messages_per_minute BETWEEN 1 AND 10000)
);

-- Initialize with immediate cleanup settings (WhatsApp-like behavior):
--   - cleanup_grace_seconds = 0: immediate payload cleanup (no grace period)
--   - require_all_devices = false: cleanup can happen even if some devices
--     haven't acknowledged, allowing C2 to send/receive even if C3 also sends
--   - delete_window_seconds = 60: 1-minute window for delete-for-everyone
INSERT INTO public.relay_config (id, cleanup_grace_seconds, require_all_devices, delete_window_seconds)
VALUES (true, 0, false, 60)
ON CONFLICT (id) DO UPDATE SET
  cleanup_grace_seconds = 0,
  require_all_devices = false,
  delete_window_seconds = 60;

-- ############################################################################
-- 4. EPHEMERAL RELAY PURGE LOGIC & IMMEDIATE CLEANUP
-- ############################################################################

-- IMMEDIATE payload cleanup trigger (fires after every INSERT on messages)
-- Purges media immediately (grace=0), mimicking WhatsApp behavior where
-- server-side payloads are short-lived. Only affects direct messages
-- (those with a recipient_id).
DROP FUNCTION IF EXISTS public.immediate_payload_cleanup;
CREATE FUNCTION public.immediate_payload_cleanup()
RETURNS TRIGGER AS $$
BEGIN
  -- Only clean up messages that have a recipient (direct messages,
  -- not group messages without a specific recipient)
  IF NEW.recipient_id IS NOT NULL THEN
    -- Immediately purge media (grace = 0 means clean up right away)
    PERFORM public.purge_relay_payloads(
      p_limit => 1,
      p_grace_seconds => 0
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER immediate_payload_cleanup_trigger
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.immediate_payload_cleanup();

-- Media cleanup when message is marked delivered
DROP FUNCTION IF EXISTS public.cleanup_ephemeral_media_on_delivery;
CREATE FUNCTION public.cleanup_ephemeral_media_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_upload_id text;
  v_local_path text;
BEGIN
  IF (NEW.delivered_to_all = TRUE OR (TG_OP = 'UPDATE' AND NEW.read_at IS NOT NULL AND OLD.read_at IS NULL))
     AND NEW.ephemeral_cleaned IS NOT TRUE THEN
    
    IF NEW.attachment IS NOT NULL THEN
      v_upload_id := NEW.attachment->>'uploadId';
      IF v_upload_id IS NOT NULL AND v_upload_id != '' THEN
        DELETE FROM public.media_chunks WHERE upload_id = v_upload_id::uuid;
        DELETE FROM public.media_uploads WHERE id = v_upload_id::uuid;
      END IF;

      v_local_path := NEW.attachment->>'remotePath';
      IF v_local_path IS NOT NULL AND v_local_path != '' THEN
        DELETE FROM storage.objects
        WHERE bucket_id = 'chat_media' AND name = v_local_path;
      END IF;
    END IF;

    NEW.ephemeral_cleaned := TRUE;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_cleanup_ephemeral_media ON public.messages;
CREATE TRIGGER trg_cleanup_ephemeral_media
BEFORE UPDATE ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.cleanup_ephemeral_media_on_delivery();

-- ============================================================================
-- 5. CORE HELPER FUNCTIONS & RPCS
-- ============================================================================

-- is_conversation_member function (from 00030)
DROP FUNCTION IF EXISTS public.is_conversation_member(uuid);
CREATE FUNCTION public.is_conversation_member(p_conv_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members 
    WHERE conversation_id = p_conv_id AND user_id = auth.uid()
  );
$$;

-- Mark Media Received (Triggers Server Ephemeral Cleanup)
DROP FUNCTION IF EXISTS public.ack_media_received(uuid);
CREATE FUNCTION public.ack_media_received(p_message_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.messages
  SET delivered_to_all = TRUE,
      read_at = COALESCE(read_at, now())
  WHERE id = p_message_id
    AND (sender_id = auth.uid() OR conversation_id IN (
      SELECT conversation_id FROM public.conversation_members WHERE user_id = auth.uid()
    ));
END;
$$;

-- Fetch Messages
DROP FUNCTION IF EXISTS public.get_messages(uuid, timestamptz, int);
CREATE FUNCTION public.get_messages(
  p_conversation uuid,
  p_before timestamptz,
  p_limit int DEFAULT 50
)
RETURNS SETOF public.messages
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.*
  FROM public.messages m
  WHERE m.conversation_id = p_conversation
    AND public.is_conversation_member(p_conversation)
    AND (p_before IS NULL OR m.created_at < p_before)
    AND m.deleted_at IS NULL
  ORDER BY m.created_at ASC
  LIMIT greatest(1, least(p_limit, 200));
$$;

-- Fetch My Chats
DROP FUNCTION IF EXISTS public.get_my_chats();
CREATE FUNCTION public.get_my_chats()
RETURNS TABLE (
  conversation_id UUID,
  type TEXT,
  title TEXT,
  avatar_url TEXT,
  last_message_id UUID,
  last_message_content TEXT,
  last_message_type TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count INT,
  peer_user_id UUID,
  peer_display_name TEXT,
  peer_avatar_url TEXT,
  peer_phone TEXT,
  peer_is_online BOOLEAN,
  peer_last_seen TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS conversation_id,
    c.type,
    c.title,
    c.avatar_url,
    m.id AS last_message_id,
    m.content AS last_message_content,
    m.type AS last_message_type,
    c.last_message_at,
    COALESCE(cm.unread_count, 0) AS unread_count,
    peer.id AS peer_user_id,
    peer.display_name AS peer_display_name,
    peer.avatar_url AS peer_avatar_url,
    peer.phone AS peer_phone,
    peer.is_online AS peer_is_online,
    peer.last_seen AS peer_last_seen
  FROM public.conversations c
  JOIN public.conversation_members cm 
    ON cm.conversation_id = c.id AND cm.user_id = auth.uid()
  LEFT JOIN public.messages m 
    ON m.id = c.last_message_id
  LEFT JOIN public.conversation_members peer_cm 
    ON peer_cm.conversation_id = c.id AND peer_cm.user_id != auth.uid() AND c.type = 'direct'
  LEFT JOIN public.profiles peer 
    ON peer.id = peer_cm.user_id
  ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$;

-- Register Device (With Complete Hardware Attributes)
DROP FUNCTION IF EXISTS public.register_device(
  uuid, text, text, text, text, text, text, text, text
);
CREATE FUNCTION public.register_device(
  p_device_id uuid,
  p_platform text,
  p_device_name text,
  p_push_token text,
  p_device_model text,
  p_device_os text,
  p_device_manufacturer text,
  p_device_locale text,
  p_app_version text
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.devices (
    id, user_id, platform, device_name, push_token,
    device_model, device_os, device_manufacturer, device_locale,
    app_version, is_current_device, last_active_at
  ) VALUES (
    COALESCE(p_device_id, gen_random_uuid()),
    auth.uid(),
    p_platform,
    p_device_name,
    p_push_token,
    p_device_model,
    p_device_os,
    p_device_manufacturer,
    p_device_locale,
    p_app_version,
    true,
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    push_token = COALESCE(EXCLUDED.push_token, devices.push_token),
    device_name = EXCLUDED.device_name,
    device_model = EXCLUDED.device_model,
    device_os = EXCLUDED.device_os,
    app_version = EXCLUDED.app_version,
    is_current_device = true,
    last_active_at = now()
  RETURNING id INTO v_id;

  -- Ensure only one active device marked as current
  UPDATE public.devices
  SET is_current_device = false
  WHERE user_id = auth.uid() AND id != v_id;

  RETURN v_id;
END;
$$;

-- Set User Presence
DROP FUNCTION IF EXISTS public.set_presence(boolean);
CREATE FUNCTION public.set_presence(p_is_online boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.profiles
  SET is_online = p_is_online,
      last_seen = now()
  WHERE id = auth.uid();
END;
$$;

-- QR Device Link Session Handshake
DROP FUNCTION IF EXISTS public.device_link_qr_payload(
  text, text, text
);
CREATE FUNCTION public.device_link_qr_payload(
  p_session_token text,
  p_platform text,
  p_device_name text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session_id uuid;
BEGIN
  INSERT INTO public.device_link_sessions (
    session_token, platform, device_name
  ) VALUES (
    p_session_token, p_platform, p_device_name
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'session_id', v_session_id,
    'session_token', p_session_token,
    'expires_in_seconds', 300
  );
END;
$$;

-- Authorize QR Device Linking
DROP FUNCTION IF EXISTS public.authorize_device_link(
  text
);
CREATE FUNCTION public.authorize_device_link(
  p_session_token text
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.device_link_sessions
  SET primary_user_id = auth.uid(),
      status = 'authorized',
      authorized_at = now()
  WHERE session_token = p_session_token
    AND expires_at > now()
    AND status = 'pending';

  RETURN FOUND;
END;
$$;

-- Delete For Everyone (Messages)
DROP FUNCTION IF EXISTS public.delete_conversation_messages(uuid);
CREATE FUNCTION public.delete_conversation_messages(p_conversation_id uuid)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_deleted bigint;
BEGIN
  IF NOT public.is_conversation_member(p_conversation_id) THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;

  DELETE FROM public.messages WHERE conversation_id = p_conversation_id;
  GET DIAGNOSTICS v_deleted = row_count;

  UPDATE public.conversations
  SET last_message_id = NULL,
      last_message_at = now()
  WHERE id = p_conversation_id;

  RETURN v_deleted;
END;
$$;

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_link_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_views ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone can read, only owner can update
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;
CREATE POLICY "Profiles read" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Profiles update" ON public.profiles;
CREATE POLICY "Profiles update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Messages: Only members can read/insert
DROP POLICY IF EXISTS "Messages select" ON public.messages;
CREATE POLICY "Messages select" ON public.messages FOR SELECT USING (public.is_conversation_member(conversation_id));

DROP POLICY IF EXISTS "Messages insert" ON public.messages;
CREATE POLICY "Messages insert" ON public.messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND public.is_conversation_member(conversation_id)
);

DROP POLICY IF EXISTS "Messages update" ON public.messages;
CREATE POLICY "Messages update" ON public.messages FOR UPDATE USING (
  public.is_conversation_member(conversation_id)
);

-- Media Chunks RLS
DROP POLICY IF EXISTS "Media chunks access" ON public.media_chunks;
CREATE POLICY "Media chunks access" ON public.media_chunks FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.media_uploads u WHERE u.id = upload_id AND (u.uploader_id = auth.uid() OR true)
  )
);

-- Statuses RLS
DROP POLICY IF EXISTS "Statuses select" ON public.statuses;
CREATE POLICY "Statuses select" ON public.statuses FOR SELECT USING (true);

DROP POLICY IF EXISTS "Statuses insert" ON public.statuses;
CREATE POLICY "Statuses insert" ON public.statuses FOR INSERT WITH CHECK (
  auth.uid() = user_id
);

-- Status Views RLS
DROP POLICY IF EXISTS "Status views select" ON public.status_views;
CREATE POLICY "Status views select" ON public.status_views FOR SELECT USING (true);

-- ============================================================================
-- 7. SUPABASE REALTIME CONFIGURATION
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'statuses'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.statuses;
  END IF;
END $$;


-- ============================================================================
-- 00032_feature_contract.sql — make the client/schema contracts line up
-- ============================================================================
--
-- Purpose
--   00031 fixed the message-relay path. This file fixes the remaining places
--   where the Dart client and the SQL schema disagree, which is why several
--   shipped features silently never work: every access raises `42703` /
--   `PGRST200` / `42P01`, the calling code swallows it, and the UI falls back
--   to an empty state.
--
--   * user_settings table missing      -> every settings write/read fails,
--                                          so nothing syncs across devices
--   * profiles column names differ    -> people search, restore, and QR link
--                                          all fail to load a profile
--   * statuses.author_id / kind        -> the Updates tab always errors
--   * devices.last_seen_at             -> linked-device list always errors
--   * device_link_sessions shape       -> device linking cannot start
--   * get_ban_status response keys     -> /banned is never shown
--   * submit_ban_appeal stored nothing -> appeals were discarded
--
-- Contract
--   * Strictly additive, exactly like 00031: no DROP TABLE, no DELETE, no
--     column removal, no data loss. Existing rows are backfilled in place.
--   * Fully re-runnable.
--   * Wrapped in a single transaction.
--
-- Apply AFTER 00031_message_relay.sql.
-- ============================================================================

BEGIN;

SET LOCAL search_path = public;

-- ############################################################################
-- 1. user_settings
-- ############################################################################
-- Referenced by lib/features/profile/data/settings_repository.dart as
-- `.from('user_settings')` with `user_id` and `settings jsonb`, including a
-- realtime `stream(primaryKey: ['user_id'])`. It was never created.
CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Reads are hot: the settings cache is consulted on every chat open.
CREATE INDEX IF NOT EXISTS idx_user_settings_updated
  ON public.user_settings (updated_at DESC);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "User settings read own" ON public.user_settings;
CREATE POLICY "User settings read own" ON public.user_settings
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "User settings write own" ON public.user_settings;
CREATE POLICY "User settings write own" ON public.user_settings
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_settings TO authenticated;
REVOKE ALL ON public.user_settings FROM anon;

-- ############################################################################
-- 2. profiles — the columns the client actually reads and writes
-- ############################################################################
-- 00030 defined `about`, `is_online`, `last_seen`, `verified`. The Dart profile
-- select (supabase_chat_repositories.dart profileSelect/identitySelect) and
-- supabase_auth_repository read `bio`, `presence`, `last_seen_at`,
-- `verification_status`, `sync_enabled`, `verified_at`, `is_anonymous` and
-- `email` instead, so every profile load 404s into its error path.
--
-- Both spellings are kept and the new ones are backfilled from the old, so a
-- database that has real profile data keeps it and a client that still reads
-- `about` still works.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS presence text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verification_status text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified_at timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sync_enabled boolean;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_anonymous boolean;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- Ban metadata the ban screen renders.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ban_reason text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ban_appealable boolean;

UPDATE public.profiles SET bio               = about       WHERE bio IS NULL AND about IS NOT NULL;
UPDATE public.profiles SET presence          = 'offline'   WHERE presence IS NULL;
UPDATE public.profiles SET last_seen_at      = last_seen   WHERE last_seen_at IS NULL;
UPDATE public.profiles SET verification_status = 'none'    WHERE verification_status IS NULL;
UPDATE public.profiles SET sync_enabled      = false       WHERE sync_enabled IS NULL;
UPDATE public.profiles SET is_anonymous      = false       WHERE is_anonymous IS NULL;
UPDATE public.profiles SET ban_appealable    = false       WHERE ban_appealable IS NULL;
UPDATE public.profiles
   SET verified_at = last_seen_at
 WHERE verified = true AND verified_at IS NULL;

-- Keep `presence` in step with `is_online`, which is what set_presence writes.
CREATE OR REPLACE FUNCTION public.sync_profile_presence_columns()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.is_online IS DISTINCT FROM OLD.is_online THEN
    NEW.presence := CASE WHEN NEW.is_online THEN 'online' ELSE 'offline' END;
  ELSIF NEW.presence IS DISTINCT FROM OLD.presence THEN
    NEW.is_online := NEW.presence = 'online';
  END IF;

  IF NEW.about IS DISTINCT FROM OLD.about AND NEW.bio IS NOT DISTINCT FROM OLD.bio THEN
    NEW.bio := NEW.about;
  END IF;

  IF NEW.last_seen IS DISTINCT FROM OLD.last_seen AND NEW.last_seen_at IS NOT DISTINCT FROM OLD.last_seen_at THEN
    NEW.last_seen_at := NEW.last_seen;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_presence ON public.profiles;
CREATE TRIGGER trg_sync_profile_presence
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_presence_columns();

-- ############################################################################
-- 3. statuses — the Updates tab's column names
-- ############################################################################
-- updates_tab.dart selects `author_id` and `kind` and embeds
-- `author:profiles!author_id(...)`. The table has `user_id` and `type`, so the
-- embedded author FK does not exist and the whole tab errors out.
ALTER TABLE public.statuses ADD COLUMN IF NOT EXISTS author_id uuid;
ALTER TABLE public.statuses ADD COLUMN IF NOT EXISTS kind text;
ALTER TABLE public.statuses ADD COLUMN IF NOT EXISTS background_color text;
ALTER TABLE public.statuses ADD COLUMN IF NOT EXISTS view_count integer;

UPDATE public.statuses SET author_id = user_id WHERE author_id IS NULL;
UPDATE public.statuses SET kind     = type   WHERE kind IS NULL;
UPDATE public.statuses SET view_count = 0    WHERE view_count IS NULL;

-- The embed `profiles!author_id` needs a real FK to resolve. Guarded, because
-- adding one to a populated table can fail if any row is already orphaned.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'statuses_author_id_fkey'
      AND conrelid = 'public.statuses'::regclass
  ) THEN
    ALTER TABLE public.statuses
      ADD CONSTRAINT statuses_author_id_fkey
      FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Keep both spellings consistent for the composer and any legacy reader.
CREATE OR REPLACE FUNCTION public.sync_status_columns()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id AND NEW.author_id IS NOT DISTINCT FROM OLD.author_id THEN
    NEW.author_id := NEW.user_id;
  END IF;
  IF NEW.type IS DISTINCT FROM OLD.type AND NEW.kind IS NOT DISTINCT FROM OLD.kind THEN
    NEW.kind := NEW.type;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_status_columns ON public.statuses;
CREATE TRIGGER trg_sync_status_columns
BEFORE UPDATE ON public.statuses
FOR EACH ROW EXECUTE FUNCTION public.sync_status_columns();

CREATE INDEX IF NOT EXISTS idx_statuses_author
  ON public.statuses (author_id, created_at DESC);

-- RLS: the Updates tab needs to read live statuses, and insert its own.
DROP POLICY IF EXISTS "Statuses read" ON public.statuses;
CREATE POLICY "Statuses read" ON public.statuses
  FOR SELECT TO authenticated
  USING (expires_at > now());

DROP POLICY IF EXISTS "Statuses write own" ON public.statuses;
CREATE POLICY "Statuses write own" ON public.statuses
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND author_id = auth.uid());

DROP POLICY IF EXISTS "Status views read" ON public.status_views;
CREATE POLICY "Status views read" ON public.status_views
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Status views write own" ON public.status_views;
CREATE POLICY "Status views write own" ON public.status_views
  FOR ALL TO authenticated
  USING (viewer_id = auth.uid())
  WITH CHECK (viewer_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.status_views TO authenticated;

-- ############################################################################
-- 4. devices — the column the linked-device list orders by
-- ############################################################################
-- settings_sub_pages_extra.dart orders by and reads `last_seen_at`. Adding the
-- alias is cheaper than changing the client, and keeps both spellings true.
ALTER TABLE public.devices ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

UPDATE public.devices SET last_seen_at = last_active_at WHERE last_seen_at IS NULL;

CREATE OR REPLACE FUNCTION public.sync_device_last_seen()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.last_active_at IS DISTINCT FROM OLD.last_active_at
     AND NEW.last_seen_at IS NOT DISTINCT FROM OLD.last_seen_at THEN
    NEW.last_seen_at := NEW.last_active_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_device_last_seen ON public.devices;
CREATE TRIGGER trg_sync_device_last_seen
BEFORE UPDATE ON public.devices
FOR EACH ROW EXECUTE FUNCTION public.sync_device_last_seen();

-- The devices page reads `device_id` and `device_ip`, which are deliberately
-- not stored: a client-supplied IP is not proof of anything and is personal
-- data with no product use. The client degrades to null for both.
CREATE INDEX IF NOT EXISTS idx_devices_user_recent
  ON public.devices (user_id, last_active_at DESC);

-- ############################################################################
-- 5. device_link_sessions — reshape to what the client writes
-- ############################################################################
-- device_link_service.dart inserts a 32-character text code as `id`, sets
-- `user_id`, reads and writes `state` (`pending|approved|consumed|expired`),
-- stores the handed-over session in a `session` jsonb column, and filters by
-- `user_id`. 00030's table has a uuid `id` and a NOT NULL `session_token`, so
-- the insert cannot succeed and linking is completely dead.
--
-- The client's own column set becomes the source of truth. `session_token`,
-- `platform` and `device_name` are made nullable rather than dropped, so a
-- database built from 00030 keeps its rows and nothing that reads them breaks.

ALTER TABLE public.device_link_sessions
  ALTER COLUMN session_token DROP NOT NULL;
ALTER TABLE public.device_link_sessions
  ALTER COLUMN platform DROP NOT NULL;
ALTER TABLE public.device_link_sessions
  ALTER COLUMN device_name DROP NOT NULL;

ALTER TABLE public.device_link_sessions ADD COLUMN IF NOT EXISTS user_id uuid;
ALTER TABLE public.device_link_sessions ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE public.device_link_sessions ADD COLUMN IF NOT EXISTS session jsonb;
ALTER TABLE public.device_link_sessions ADD COLUMN IF NOT EXISTS approved_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'device_link_sessions_user_id_fkey'
      AND conrelid = 'public.device_link_sessions'::regclass
  ) THEN
    ALTER TABLE public.device_link_sessions
      ADD CONSTRAINT device_link_sessions_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

UPDATE public.device_link_sessions
   SET user_id = primary_user_id
 WHERE user_id IS NULL AND primary_user_id IS NOT NULL;

UPDATE public.device_link_sessions
   SET state = status
 WHERE state IS NULL AND status IS NOT NULL;

-- `id` must accept the client's text code as well as 00030's uuid, because the
-- column is the primary key and a text code is what a QR flow produces.
ALTER TABLE public.device_link_sessions
  ALTER COLUMN id TYPE text USING id::text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'device_link_sessions_state_check'
      AND conrelid = 'public.device_link_sessions'::regclass
  ) THEN
    ALTER TABLE public.device_link_sessions
      ADD CONSTRAINT device_link_sessions_state_check
      CHECK (state IS NULL OR state IN ('pending', 'approved', 'consumed', 'expired', 'rejected', 'authorized'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_device_link_sessions_user
  ON public.device_link_sessions (user_id, state);

-- The requesting device is signed in but has no `primary_user_id` yet, so the
-- existing policy (which filters on `primary_user_id`) denies it. It needs to
-- read its own row by `user_id`, and nobody else's.
DROP POLICY IF EXISTS "Device link sessions own" ON public.device_link_sessions;
CREATE POLICY "Device link sessions own" ON public.device_link_sessions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR primary_user_id = auth.uid());

DROP POLICY IF EXISTS "Device link sessions insert own" ON public.device_link_sessions;
CREATE POLICY "Device link sessions insert own" ON public.device_link_sessions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Device link sessions update own" ON public.device_link_sessions;
CREATE POLICY "Device link sessions update own" ON public.device_link_sessions
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Device link sessions delete own" ON public.device_link_sessions;
CREATE POLICY "Device link sessions delete own" ON public.device_link_sessions
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR primary_user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_link_sessions TO authenticated;
REVOKE ALL ON public.device_link_sessions FROM anon;

-- A linking row carries a handed-over session, so it must not sit around after
-- it stops being useful.
CREATE OR REPLACE FUNCTION public.purge_expired_device_link_sessions(
  p_limit integer DEFAULT 200
)
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_removed integer := 0;
BEGIN
  WITH stale AS (
    SELECT id
    FROM public.device_link_sessions
    WHERE expires_at < now() - interval '1 hour'
       OR (approved_at IS NOT NULL AND approved_at < now() - interval '15 minutes')
       OR state = 'consumed'
    ORDER BY expires_at ASC
    LIMIT greatest(1, least(coalesce(p_limit, 200), 5000))
    FOR UPDATE SKIP LOCKED
  ), gone AS (
    DELETE FROM public.device_link_sessions s
    USING stale WHERE s.id::text = stale.id
    RETURNING s.id
  )
  SELECT count(*) INTO v_removed FROM gone;

  RETURN v_removed;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_device_link_sessions(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_expired_device_link_sessions(integer) TO service_role;

-- ############################################################################
-- 6. Ban status — response keys and durable appeals
-- ############################################################################
-- BanStatus.fromRow reads `banned`, `reason`, `banned_at` and `appealable`. The
-- 00031 function returned `is_banned`, `role` and `banned_at`, so
-- `(row['banned'] ?? false) != true` was always true and /banned was
-- unreachable no matter what the server said.
DROP FUNCTION IF EXISTS public.get_ban_status();
CREATE OR REPLACE FUNCTION public.get_ban_status()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public AS $$
  SELECT jsonb_build_object(
    'banned', coalesce(p.is_banned, false),
    -- Both spellings, so a client on either contract reads correctly.
    'is_banned', coalesce(p.is_banned, false),
    'reason', p.ban_reason,
    'banned_at', CASE WHEN p.is_banned THEN p.updated_at ELSE NULL END,
    'appealable', coalesce(p.ban_appealable, false) AND coalesce(p.is_banned, false),
    'role', coalesce(p.role, 'user')
  )
  FROM public.profiles p
  WHERE p.id = auth.uid();
$$;

-- Appeals were returned as `{accepted: true}` and stored nowhere, so a user
-- could submit one and lose it.
CREATE TABLE IF NOT EXISTS public.ban_appeals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CONSTRAINT ban_appeals_status_check
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  CONSTRAINT ban_appeals_reason_length CHECK (length(reason) BETWEEN 10 AND 2000),
  -- One open appeal per account, so a user cannot spam the moderation queue.
  CONSTRAINT ban_appeals_one_pending UNIQUE (user_id, status)
);

ALTER TABLE public.ban_appeals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ban appeals read own" ON public.ban_appeals;
CREATE POLICY "Ban appeals read own" ON public.ban_appeals
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Ban appeals insert own" ON public.ban_appeals;
CREATE POLICY "Ban appeals insert own" ON public.ban_appeals
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT ON public.ban_appeals TO authenticated;
REVOKE ALL ON public.ban_appeals FROM anon;

DROP FUNCTION IF EXISTS public.submit_ban_appeal(text);
CREATE OR REPLACE FUNCTION public.submit_ban_appeal(p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING errcode = '28000';
  END IF;

  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'Please describe what happened in at least 10 characters'
      USING errcode = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_uid AND is_banned
  ) THEN
    RAISE EXCEPTION 'No appeal is open for this account' USING errcode = '22023';
  END IF;

  INSERT INTO public.ban_appeals (user_id, reason)
  VALUES (v_uid, trim(p_reason))
  ON CONFLICT (user_id, status) WHERE status = 'pending' DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN jsonb_build_object('accepted', false, 'detail', 'An appeal is already open.');
  END IF;

  RETURN jsonb_build_object('accepted', true, 'appeal_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.get_ban_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_ban_appeal(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_ban_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_ban_appeal(text) TO authenticated;

-- ############################################################################
-- 7. Notification preferences honoured by the relay
-- ############################################################################
-- Two settings the client already stores but the relay never reads, and which
-- therefore have no effect at all:
--
--   * read receipts — a sender who turned them off is still reported as having
--     their messages read, which is a privacy failure rather than a cosmetic
--     one;
--   * presence visibility.
--
-- Stored on `profiles` because that is where the rest of the per-account
-- settings live, and because a default of "receipts on" preserves today's
-- behaviour for accounts that never chose.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS read_receipts_enabled boolean;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS typing_enabled boolean;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS presence_visibility text;

UPDATE public.profiles SET read_receipts_enabled = true  WHERE read_receipts_enabled IS NULL;
UPDATE public.profiles SET typing_enabled       = true  WHERE typing_enabled IS NULL;
UPDATE public.profiles SET presence_visibility  = 'everyone' WHERE presence_visibility IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_presence_visibility_check'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_presence_visibility_check
      CHECK (presence_visibility IS NULL
             OR presence_visibility IN ('everyone', 'contacts', 'nobody'));
  END IF;
END $$;

-- `mark_read` writes a read row for the RECIPIENT. Suppressing the row when the
-- SENDER has receipts disabled is what makes the setting real: without it the
-- sender learns their messages were read whether or not they consented.
CREATE OR REPLACE FUNCTION public.sender_allows_read_receipts(p_sender uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public AS $$
  SELECT coalesce(
    (SELECT p.read_receipts_enabled FROM public.profiles p WHERE p.id = p_sender),
    true
  );
$$;

REVOKE ALL ON FUNCTION public.sender_allows_read_receipts(uuid) FROM PUBLIC;

DROP FUNCTION IF EXISTS public.mark_read(uuid, uuid, uuid);
CREATE FUNCTION public.mark_read(
  p_conversation uuid,
  p_up_to_message_id uuid DEFAULT NULL,
  p_device_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_marked integer := 0;
  v_suppressed integer := 0;
  v_allowed boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING errcode = '28000';
  END IF;

  IF NOT public.relay_is_conversation_member(p_conversation) THEN
    RAISE EXCEPTION 'Not a member of this conversation' USING errcode = '42501';
  END IF;

  IF p_device_id IS NULL THEN
    SELECT id INTO p_device_id
    FROM public.devices
    WHERE user_id = v_uid AND status = 'active' AND revoked_at IS NULL
    ORDER BY is_current_device DESC, last_active_at DESC
    LIMIT 1;
  END IF;

  IF p_device_id IS NULL OR NOT public.relay_authorize_device(p_device_id) THEN
    RAISE EXCEPTION 'Unknown or revoked device' USING errcode = '42501';
  END IF;

  -- Split the window by the sender's preference. A message from someone who
  -- disabled receipts still counts as delivered, and still clears the unread
  -- badge; it just does not produce a read receipt.
  SELECT bool_and(public.sender_allows_read_receipts(m.sender_id))
    INTO v_allowed
  FROM public.messages m
  WHERE m.conversation_id = p_conversation
    AND m.sender_id <> v_uid
    AND m.deleted_at IS NULL
    AND (
      p_up_to_message_id IS NULL
      OR m.created_at <= (
          SELECT created_at FROM public.messages WHERE id = p_up_to_message_id
        )
    );

  v_allowed := coalesce(v_allowed, true);

  WITH target AS (
    SELECT m.id
    FROM public.messages m
    WHERE m.conversation_id = p_conversation
      AND m.sender_id <> v_uid
      AND m.deleted_at IS NULL
      AND (
        p_up_to_message_id IS NULL
        OR m.created_at <= (
            SELECT created_at FROM public.messages WHERE id = p_up_to_message_id
          )
      )
    ORDER BY m.created_at ASC
    LIMIT 500
  ), inserted AS (
    INSERT INTO public.message_device_acks (
      message_id, user_id, device_id, ack_kind, acknowledged_at, ack_version
    )
    SELECT id, v_uid, p_device_id, 'read', now(), 1
    FROM target
    WHERE v_allowed
    ON CONFLICT (message_id, device_id, ack_kind) DO NOTHING
    RETURNING message_id
  )
  SELECT count(*) INTO v_marked FROM inserted;

  v_suppressed := 0;
  IF NOT v_allowed THEN
    SELECT count(*) INTO v_suppressed
    FROM public.messages m
    WHERE m.conversation_id = p_conversation
      AND m.sender_id <> v_uid
      AND m.deleted_at IS NULL
      AND (
        p_up_to_message_id IS NULL
        OR m.created_at <= (
            SELECT created_at FROM public.messages WHERE id = p_up_to_message_id
          )
      );
  END IF;

  -- Unread is cleared either way. Suppressing a read receipt must not leave the
  -- conversation permanently marked unread for its recipient.
  UPDATE public.conversation_members
  SET unread_count = 0
  WHERE conversation_id = p_conversation AND user_id = v_uid;

  RETURN jsonb_build_object(
    'marked', v_marked,
    -- Non-zero means "read locally, but the sender is not told", which is the
    -- honest response for a client that wants to render the suppressed state.
    'suppressed', v_suppressed,
    'device_id', p_device_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_read(uuid, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_read(uuid, uuid, uuid) TO authenticated;

-- ############################################################################
-- 8. Missing CRUD the client calls but no function or policy provided
-- ############################################################################

-- post_status / view_status / status_view_count back the Updates tab. They were
-- referenced only in PREFLIGHT.sql and did not exist.
CREATE OR REPLACE FUNCTION public.post_status(
  p_caption text,
  p_media_url text DEFAULT NULL,
  p_type text DEFAULT 'text',
  p_background_color text DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING errcode = '28000';
  END IF;

  IF coalesce(p_type, 'text') NOT IN ('text', 'image', 'video') THEN
    RAISE EXCEPTION 'Unsupported status type' USING errcode = '22023';
  END IF;

  IF length(coalesce(p_caption, '')) > 700 THEN
    RAISE EXCEPTION 'Caption too long' USING errcode = '22023';
  END IF;

  IF coalesce(p_type, 'text') <> 'text'
     AND (p_media_url IS NULL OR p_media_url !~* '^https://') THEN
    RAISE EXCEPTION 'A media status needs an https URL' USING errcode = '22023';
  END IF;

  INSERT INTO public.statuses (
    user_id, author_id, type, kind, media_url, caption,
    background_color, expires_at
  )
  VALUES (
    v_uid, v_uid, coalesce(p_type, 'text'), coalesce(p_type, 'text'),
    p_media_url, nullif(trim(coalesce(p_caption, '')), ''),
    p_background_color,
    coalesce(p_expires_at, now() + interval '24 hours')
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.view_status(p_status_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING errcode = '28000';
  END IF;

  INSERT INTO public.status_views (status_id, viewer_id, viewed_at)
  SELECT s.id, v_uid, now()
  FROM public.statuses s
  WHERE s.id = ANY(coalesce(p_status_ids, ARRAY[]::uuid[]))
    AND s.user_id <> v_uid
    AND s.expires_at > now()
  ON CONFLICT (status_id, viewer_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('recorded', v_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.status_view_count(p_status_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public AS $$
  SELECT count(*)::integer FROM public.status_views WHERE status_id = p_status_id;
$$;

REVOKE ALL ON FUNCTION public.post_status(text, text, text, text, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.view_status(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.status_view_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.post_status(text, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.view_status(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.status_view_count(uuid) TO authenticated;

-- media_uploads / media_chunks writes are done directly by the uploader through
-- PostgREST, so the tables need table grants in addition to the policies 00031
-- added. Without these the chunked pipeline fails on insert even though the
-- policy allows it.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.media_uploads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.media_chunks TO authenticated;
GRANT SELECT ON public.message_device_acks TO authenticated;
GRANT SELECT ON public.message_tombstones TO authenticated;
GRANT SELECT ON public.message_reactions TO authenticated;
GRANT SELECT, UPDATE, DELETE ON public.devices TO authenticated;
GRANT SELECT ON public.conversations TO authenticated;
GRANT SELECT ON public.conversation_members TO authenticated;
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.statuses TO authenticated;

REVOKE ALL ON public.messages FROM anon;
REVOKE ALL ON public.profiles FROM anon;

-- ############################################################################
-- 9. Realtime membership for the newly reachable tables
-- ############################################################################
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_settings'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.user_settings';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'status_views'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.status_views';
  END IF;

  -- `device_link_sessions` is deliberately NOT published: it carries a
  -- handed-over session token, and it must never appear in a Realtime fan-out.
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN insufficient_privilege THEN NULL;
END $$;

COMMIT;

-- ============================================================================
-- After applying, schedule the link-session sweeper:
--
--   select cron.schedule('purge-device-link-sessions', '*/15 * * * *',
--                        $$select public.purge_expired_device_link_sessions();$$);
-- ============================================================================


-- Crystal Messenger consolidated hardening migration.
-- Applies the additive changes previously split across 00033-00038.
-- Safe intent: no user rows are deleted and no existing tables are dropped.
-- Apply after the repository's existing baseline/feature-contract migrations.
BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Private media chunk access
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.media_chunks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Media chunks access" ON public.media_chunks;
DROP POLICY IF EXISTS "Media chunks owner select" ON public.media_chunks;
DROP POLICY IF EXISTS "Media chunks owner insert" ON public.media_chunks;
DROP POLICY IF EXISTS "Media chunks owner update" ON public.media_chunks;
DROP POLICY IF EXISTS "Media chunks owner delete" ON public.media_chunks;
CREATE POLICY "Media chunks owner select" ON public.media_chunks FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.media_uploads u WHERE u.id = upload_id AND u.uploader_id = auth.uid())
);
CREATE POLICY "Media chunks owner insert" ON public.media_chunks FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.media_uploads u WHERE u.id = upload_id AND u.uploader_id = auth.uid())
);
CREATE POLICY "Media chunks owner update" ON public.media_chunks FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.media_uploads u WHERE u.id = upload_id AND u.uploader_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.media_uploads u WHERE u.id = upload_id AND u.uploader_id = auth.uid()));
CREATE POLICY "Media chunks owner delete" ON public.media_chunks FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.media_uploads u WHERE u.id = upload_id AND u.uploader_id = auth.uid())
);

-- ---------------------------------------------------------------------------
-- 2. Profile and conversation/message authorization
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Profiles read" ON public.profiles;
DROP POLICY IF EXISTS "Profiles authenticated read" ON public.profiles;
CREATE POLICY "Profiles authenticated read" ON public.profiles
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Profiles update" ON public.profiles;
CREATE POLICY "Profiles update" ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

ALTER TABLE IF EXISTS public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.message_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Conversations member select" ON public.conversations;
CREATE POLICY "Conversations member select" ON public.conversations
  FOR SELECT TO authenticated USING (public.is_conversation_member(id));
DROP POLICY IF EXISTS "Conversation members member select" ON public.conversation_members;
CREATE POLICY "Conversation members member select" ON public.conversation_members
  FOR SELECT TO authenticated USING (public.is_conversation_member(conversation_id));
DROP POLICY IF EXISTS "Conversation members client insert" ON public.conversation_members;
DROP POLICY IF EXISTS "Conversation members client delete" ON public.conversation_members;

DROP POLICY IF EXISTS "Messages update" ON public.messages;
CREATE POLICY "Messages update" ON public.messages FOR UPDATE TO authenticated
  USING (sender_id = auth.uid()) WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "Message receipts member select" ON public.message_receipts;
CREATE POLICY "Message receipts member select" ON public.message_receipts FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.messages m WHERE m.id = message_id AND public.is_conversation_member(m.conversation_id)));
DROP POLICY IF EXISTS "Message receipts own insert" ON public.message_receipts;
CREATE POLICY "Message receipts own insert" ON public.message_receipts FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.messages m WHERE m.id = message_id AND public.is_conversation_member(m.conversation_id)));
DROP POLICY IF EXISTS "Message receipts own update" ON public.message_receipts;
CREATE POLICY "Message receipts own update" ON public.message_receipts FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Message receipts own delete" ON public.message_receipts;
CREATE POLICY "Message receipts own delete" ON public.message_receipts FOR DELETE TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Message reactions member select" ON public.message_reactions;
CREATE POLICY "Message reactions member select" ON public.message_reactions FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.messages m WHERE m.id = message_id AND public.is_conversation_member(m.conversation_id)));
DROP POLICY IF EXISTS "Message reactions own write" ON public.message_reactions;
CREATE POLICY "Message reactions own write" ON public.message_reactions FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.messages m WHERE m.id = message_id AND public.is_conversation_member(m.conversation_id)));

-- ---------------------------------------------------------------------------
-- 3. Blocks and atomic direct conversations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_blocks (
  blocker_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT user_blocks_no_self CHECK (blocker_id <> blocked_id)
);
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "User blocks owner select" ON public.user_blocks;
CREATE POLICY "User blocks owner select" ON public.user_blocks FOR SELECT TO authenticated USING (blocker_id = auth.uid());
DROP POLICY IF EXISTS "User blocks owner insert" ON public.user_blocks;
CREATE POLICY "User blocks owner insert" ON public.user_blocks FOR INSERT TO authenticated
  WITH CHECK (blocker_id = auth.uid() AND blocker_id <> blocked_id);
DROP POLICY IF EXISTS "User blocks owner delete" ON public.user_blocks;
CREATE POLICY "User blocks owner delete" ON public.user_blocks FOR DELETE TO authenticated USING (blocker_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.user_blocks TO authenticated;

-- PostgreSQL cannot change a function's return type with CREATE OR REPLACE.
-- The exact signature is dropped first so existing deployments with a legacy
-- return type can be upgraded deterministically.
DROP FUNCTION IF EXISTS public.get_or_create_direct_conversation(uuid);
CREATE FUNCTION public.get_or_create_direct_conversation(p_peer_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me uuid := auth.uid(); v_conversation uuid; v_low uuid; v_high uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Authentication required' USING errcode = '28000'; END IF;
  IF p_peer_id IS NULL OR p_peer_id = v_me THEN RAISE EXCEPTION 'Invalid conversation participant' USING errcode = '22023'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_peer_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Recipient not found' USING errcode = 'P0002';
  END IF;
  IF EXISTS (SELECT 1 FROM public.user_blocks WHERE (blocker_id = v_me AND blocked_id = p_peer_id) OR (blocker_id = p_peer_id AND blocked_id = v_me)) THEN
    RAISE EXCEPTION 'Conversation not permitted' USING errcode = '42501';
  END IF;
  v_low := LEAST(v_me, p_peer_id); v_high := GREATEST(v_me, p_peer_id);
  PERFORM pg_advisory_xact_lock(hashtextextended(v_low::text || ':' || v_high::text, 0));
  SELECT c.id INTO v_conversation
  FROM public.conversations c
  JOIN public.conversation_members a ON a.conversation_id = c.id AND a.user_id = v_low
  JOIN public.conversation_members b ON b.conversation_id = c.id AND b.user_id = v_high
  WHERE c.type = 'direct'
    AND (SELECT count(*) FROM public.conversation_members x WHERE x.conversation_id = c.id) = 2
  ORDER BY c.created_at LIMIT 1;
  IF v_conversation IS NULL THEN
    INSERT INTO public.conversations (type, created_by) VALUES ('direct', v_me) RETURNING id INTO v_conversation;
    INSERT INTO public.conversation_members (conversation_id, user_id) VALUES (v_conversation, v_me), (v_conversation, p_peer_id);
  END IF;
  RETURN v_conversation;
END;
$$;
REVOKE ALL ON FUNCTION public.get_or_create_direct_conversation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_or_create_direct_conversation(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. 14-day inactivity retention contract
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.profiles ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;
-- Some deployed schemas use only last_seen_at (without the legacy last_seen
-- column), so do not reference the optional legacy column directly.
UPDATE public.profiles SET last_seen_at = COALESCE(last_seen_at, created_at, now()) WHERE last_seen_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_inactive_cleanup ON public.profiles (last_seen_at) WHERE deleted_at IS NULL;
CREATE OR REPLACE FUNCTION public.list_inactive_account_ids(p_inactive_for interval DEFAULT interval '14 days', p_limit integer DEFAULT 500)
RETURNS TABLE (user_id uuid) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.profiles WHERE deleted_at IS NULL
    AND COALESCE(last_seen_at, created_at) < now() - p_inactive_for
  ORDER BY COALESCE(last_seen_at, created_at), id LIMIT greatest(1, least(p_limit, 500));
$$;
REVOKE ALL ON FUNCTION public.list_inactive_account_ids(interval, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_inactive_account_ids(interval, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- 5. Call sessions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.call_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  caller_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  callee_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  call_type text NOT NULL CHECK (call_type IN ('audio', 'video')),
  state text NOT NULL DEFAULT 'ringing' CHECK (state IN ('ringing', 'accepted', 'rejected', 'ended', 'missed')),
  created_at timestamptz NOT NULL DEFAULT now(), answered_at timestamptz, ended_at timestamptz,
  CHECK (caller_id <> callee_id)
);
CREATE INDEX IF NOT EXISTS idx_call_sessions_participant ON public.call_sessions (caller_id, callee_id, created_at DESC);
ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Call participants read" ON public.call_sessions;
CREATE POLICY "Call participants read" ON public.call_sessions FOR SELECT TO authenticated USING (caller_id = auth.uid() OR callee_id = auth.uid());
DROP POLICY IF EXISTS "Call caller create" ON public.call_sessions;
CREATE POLICY "Call caller create" ON public.call_sessions FOR INSERT TO authenticated WITH CHECK (
  caller_id = auth.uid() AND public.is_conversation_member(conversation_id)
  AND EXISTS (SELECT 1 FROM public.conversation_members WHERE conversation_id = call_sessions.conversation_id AND user_id = callee_id)
);
DROP POLICY IF EXISTS "Call participants update" ON public.call_sessions;
CREATE POLICY "Call participants update" ON public.call_sessions FOR UPDATE TO authenticated
  USING (caller_id = auth.uid() OR callee_id = auth.uid())
  WITH CHECK (caller_id = auth.uid() OR callee_id = auth.uid());
GRANT SELECT, INSERT, UPDATE ON public.call_sessions TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Future Pro entitlement model
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.account_entitlements (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'canceled')),
  provider text, provider_customer_id text, provider_subscription_id text,
  current_period_end timestamptz, updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.account_entitlements (user_id) SELECT id FROM public.profiles ON CONFLICT (user_id) DO NOTHING;
ALTER TABLE public.account_entitlements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Entitlements owner read" ON public.account_entitlements;
CREATE POLICY "Entitlements owner read" ON public.account_entitlements FOR SELECT TO authenticated USING (user_id = auth.uid());
REVOKE ALL ON public.account_entitlements FROM anon;
GRANT SELECT ON public.account_entitlements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.account_entitlements TO service_role;
CREATE OR REPLACE FUNCTION public.ensure_account_entitlement()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN INSERT INTO public.account_entitlements (user_id) VALUES (NEW.id) ON CONFLICT (user_id) DO NOTHING; RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS trg_profiles_entitlement ON public.profiles;
CREATE TRIGGER trg_profiles_entitlement AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.ensure_account_entitlement();

-- Publish only call sessions when the project permits publication changes.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'call_sessions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.call_sessions;
  END IF;
EXCEPTION WHEN undefined_object OR insufficient_privilege THEN NULL;
END $$;

COMMIT;



-- WhatsApp-style server-authoritative CRUD and disappearing-message cleanup.
-- Apply after 00033_crystal_consolidated_hardening.sql.

SET search_path = public;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS client_message_id text;

CREATE UNIQUE INDEX IF NOT EXISTS messages_sender_client_key
  ON public.messages (sender_id, client_message_id)
  WHERE client_message_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.create_group_conversation(
  p_title text,
  p_member_ids uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid(); v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated' USING errcode = '28000'; END IF;
  IF length(trim(coalesce(p_title, ''))) NOT BETWEEN 1 AND 100
    THEN RAISE EXCEPTION 'Invalid group title' USING errcode = '22023'; END IF;
  INSERT INTO conversations(type, title, created_by)
    VALUES ('group', trim(p_title), v_uid) RETURNING id INTO v_id;
  INSERT INTO conversation_members(conversation_id, user_id, role)
    SELECT v_id, x, CASE WHEN x = v_uid THEN 'admin' ELSE 'member' END
    FROM (SELECT DISTINCT unnest(array_append(coalesce(p_member_ids, ARRAY[]::uuid[]), v_uid)) x) q
    WHERE EXISTS (SELECT 1 FROM profiles p WHERE p.id = x AND p.deleted_at IS NULL);
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.set_conversation_disappearing(
  p_conversation_id uuid, p_seconds integer
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_conversation_member(p_conversation_id) THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
  IF p_seconds NOT IN (0, 86400, 604800, 2592000) THEN
    RAISE EXCEPTION 'Unsupported disappearing-message duration' USING errcode = '22023';
  END IF;
  UPDATE conversations SET disappearing_duration_seconds = p_seconds, updated_at = now()
    WHERE id = p_conversation_id;
END; $$;

CREATE OR REPLACE FUNCTION public.clear_conversation_for_everyone(p_conversation_id uuid)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT is_conversation_member(p_conversation_id) THEN
    RAISE EXCEPTION 'Not authorized' USING errcode = '42501';
  END IF;
  UPDATE messages SET content = NULL, attachment = NULL, deleted_at = coalesce(deleted_at, now())
    WHERE conversation_id = p_conversation_id AND deleted_at IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  UPDATE conversations SET last_message_id = NULL, last_message_at = now(), updated_at = now()
    WHERE id = p_conversation_id;
  RETURN v_count;
END; $$;

CREATE OR REPLACE FUNCTION public.purge_expired_disappearing_messages(p_limit integer DEFAULT 500)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count bigint;
BEGIN
  WITH expired AS (
    SELECT m.id FROM messages m JOIN conversations c ON c.id = m.conversation_id
    WHERE c.disappearing_duration_seconds > 0 AND m.deleted_at IS NULL
      AND m.created_at + make_interval(secs => c.disappearing_duration_seconds) <= now()
    ORDER BY m.created_at LIMIT greatest(1, least(p_limit, 5000))
  )
  UPDATE messages m SET content = NULL, attachment = NULL, deleted_at = now()
    FROM expired e WHERE m.id = e.id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

REVOKE ALL ON FUNCTION public.create_group_conversation(text, uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_conversation_disappearing(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.clear_conversation_for_everyone(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_group_conversation(text, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_conversation_disappearing(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_conversation_for_everyone(uuid) TO authenticated;

-- Schedule with pg_cron when available:
-- select cron.schedule('purge-disappearing-messages', '* * * * *',
--   $$select public.purge_expired_disappearing_messages();$$);



-- Anonymous identity hardening.
-- Apply after 00034_whatsapp_crud_and_retention.sql.
-- Idempotent and non-destructive: existing profiles are preserved.

SET search_path = public;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS bio text,
  ADD COLUMN IF NOT EXISTS is_anonymous boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS sync_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS profiles_phone_lookup_idx
  ON public.profiles (phone) WHERE phone IS NOT NULL AND phone <> '';

CREATE OR REPLACE FUNCTION public.ensure_anonymous_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, is_anonymous, verification_status, sync_enabled)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'display_name', ''), 'New user'),
    COALESCE((NEW.is_anonymous), true),
    CASE WHEN NEW.is_anonymous THEN 'unverified' ELSE 'verified' END,
    true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.ensure_anonymous_profile();

-- Backfill users created before this migration.
INSERT INTO public.profiles (id, display_name, is_anonymous, verification_status, sync_enabled)
SELECT
  u.id,
  COALESCE(NULLIF(u.raw_user_meta_data->>'display_name', ''), 'New user'),
  COALESCE(u.is_anonymous, true),
  CASE WHEN COALESCE(u.is_anonymous, true) THEN 'unverified' ELSE 'verified' END,
  true
FROM auth.users u
ON CONFLICT (id) DO NOTHING;

-- Prevent malformed identities from entering the relay.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_display_name_length'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_display_name_length
      CHECK (display_name IS NULL OR length(display_name) <= 120);
  END IF;
END
$$;

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;



