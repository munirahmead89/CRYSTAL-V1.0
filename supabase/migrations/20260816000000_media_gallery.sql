-- Crystal Messenger - Media Gallery, Forward, View Tracking
--
-- · get_chat_media_gallery(p_chat_id, p_cursor, p_limit)
--     Returns all image/video messages in a chat with sender info, paginated.
--     Drives the WhatsApp-style media grid in chat info and the swipe viewer.
--
-- · mark_media_viewed(p_message_id)
--     Records that the caller viewed a media message (blue-tick equivalent for
--     images/videos).  Only the non-sender can mark as viewed.
--
-- · get_media_viewers(p_message_id)
--     Returns the list of users who have viewed a specific media message, with
--     their avatar and name.  Only the sender can call this.
--
-- · forward_media_message(p_message_id, p_target_chat_id)
--     Copies a media message (image/video/audio) to another chat that the
--     caller participates in.  Creates a new message referencing the same
--     storage path so no data is duplicated.

/* =====================================================================
   1. TABLES
   ===================================================================== */

CREATE TABLE IF NOT EXISTS public.media_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id  UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  viewer_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(message_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS idx_media_views_message
  ON public.media_views(message_id);
CREATE INDEX IF NOT EXISTS idx_media_views_viewer
  ON public.media_views(viewer_id, viewed_at);

/* =====================================================================
   2. ROW LEVEL SECURITY
   ===================================================================== */

ALTER TABLE public.media_views ENABLE ROW LEVEL SECURITY;

-- Media views: only chat participants can see view rows.
DROP POLICY IF EXISTS "MediaViews: read participants" ON public.media_views;
CREATE POLICY "MediaViews: read participants"
  ON public.media_views FOR SELECT
  USING (
    message_id IN (
      SELECT m.id FROM public.messages m
      JOIN public.chats c ON c.id = m.chat_id
      WHERE c.user_one = auth.uid() OR c.user_two = auth.uid()
    )
  );

-- Media views: any chat participant can insert (mark as viewed).
DROP POLICY IF EXISTS "MediaViews: insert own" ON public.media_views;
CREATE POLICY "MediaViews: insert own"
  ON public.media_views FOR INSERT
  WITH CHECK (viewer_id = auth.uid());

/* =====================================================================
   3. FUNCTIONS
   ===================================================================== */

-- Paginated media gallery for a chat.  Returns all image/video/audio
-- messages with sender name + avatar.  Use p_cursor (message created_at)
-- for infinite scroll.  Results are ordered newest-first.
CREATE OR REPLACE FUNCTION public.get_chat_media_gallery(
  p_chat_id UUID,
  p_cursor  TIMESTAMPTZ DEFAULT NULL,
  p_limit   INT DEFAULT 30
)
RETURNS TABLE (
  message_id    UUID,
  content       TEXT,
  message_type  TEXT,
  metadata      JSONB,
  sender_id     UUID,
  sender_name   TEXT,
  sender_avatar TEXT,
  created_at    TIMESTAMPTZ,
  viewed_by_me  BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    m.id AS message_id,
    m.content,
    m.message_type,
    m.metadata,
    m.sender_id,
    p.full_name   AS sender_name,
    p.avatar_url  AS sender_avatar,
    m.created_at,
    EXISTS (
      SELECT 1 FROM public.media_views mv
      WHERE mv.message_id = m.id AND mv.viewer_id = auth.uid()
    ) AS viewed_by_me
  FROM public.messages m
  JOIN public.profiles p ON p.id = m.sender_id
  WHERE m.chat_id = p_chat_id
    AND m.message_type IN ('image', 'video', 'audio')
    AND m.is_deleted = false
    AND m.content IS NOT NULL
    AND (p_cursor IS NULL OR m.created_at < p_cursor)
  ORDER BY m.created_at DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_media_gallery(UUID, TIMESTAMPTZ, INT) TO authenticated;

-- Mark a media message as viewed by the caller.  The sender cannot mark
-- their own message as viewed (no-op in that case).
CREATE OR REPLACE FUNCTION public.mark_media_viewed(p_message_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.media_views (message_id, viewer_id)
  SELECT m.id, auth.uid()
  FROM public.messages m
  WHERE m.id = p_message_id
    AND m.sender_id <> auth.uid()
  ON CONFLICT (message_id, viewer_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_media_viewed(UUID) TO authenticated;

-- Returns who has viewed a specific media message.  Only the sender can
-- call this (to see who has viewed their photo/video).
CREATE OR REPLACE FUNCTION public.get_media_viewers(p_message_id UUID)
RETURNS TABLE (
  viewer_id   UUID,
  viewer_name TEXT,
  viewer_avatar TEXT,
  viewed_at   TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    mv.viewer_id,
    p.full_name   AS viewer_name,
    p.avatar_url  AS viewer_avatar,
    mv.viewed_at
  FROM public.media_views mv
  JOIN public.profiles p ON p.id = mv.viewer_id
  WHERE mv.message_id = p_message_id
    AND (
      -- Only the sender can see who viewed their media
      EXISTS (
        SELECT 1 FROM public.messages m
        WHERE m.id = p_message_id AND m.sender_id = auth.uid()
      )
      -- Or the viewer can see their own view record
      OR mv.viewer_id = auth.uid()
    )
  ORDER BY mv.viewed_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_media_viewers(UUID) TO authenticated;

-- Forward a media message (image/video/audio) to another chat.
-- Creates a new message in the target chat referencing the same storage
-- path so no data duplication occurs.
CREATE OR REPLACE FUNCTION public.forward_media_message(
  p_message_id UUID,
  p_target_chat_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_msg RECORD;
  v_new_id UUID;
BEGIN
  -- Verify the caller participates in both the source and target chats.
  SELECT * INTO v_msg FROM public.messages WHERE id = p_message_id;
  IF v_msg IS NULL THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chats
    WHERE id = v_msg.chat_id
      AND (user_one = auth.uid() OR user_two = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Not a participant in source chat';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chats
    WHERE id = p_target_chat_id
      AND (user_one = auth.uid() OR user_two = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Not a participant in target chat';
  END IF;

  -- Create the forwarded message (same content, new sender = caller).
  INSERT INTO public.messages (chat_id, sender_id, content, message_type, metadata)
  VALUES (
    p_target_chat_id,
    auth.uid(),
    v_msg.content,
    v_msg.message_type,
    jsonb_build_object(
      'forwarded', true,
      'originalSenderId', v_msg.sender_id,
      'originalMessageId', v_msg.id
    )
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.forward_media_message(UUID, UUID) TO authenticated;
