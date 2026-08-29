-- Crystal Messenger - Status / Updates (WhatsApp-style statuses)
--
-- · statuses        - a user's status update (text, image or video), auto-expires after 24h
-- · status_views    - per-viewer read tracking (drives the "seen" rings)
-- · get_status_feed() RPC - returns statuses visible to the caller (own + contacts),
--                           tagged with viewed/unviewed and view counts
--
-- Reads are scoped to the author and the author's contacts (like WhatsApp).
-- Writes are author-only. Everything is gated by RLS.

/* =====================================================================
   1. TABLES
   ===================================================================== */

CREATE TABLE IF NOT EXISTS public.statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT,
  media_url TEXT,
  media_type TEXT NOT NULL DEFAULT 'text' CHECK (media_type IN ('text', 'image', 'video')),
  background_color TEXT NOT NULL DEFAULT '#1F2C34',
  text_color TEXT NOT NULL DEFAULT '#FFFFFF',
  caption TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.status_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status_id UUID NOT NULL REFERENCES public.statuses(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(status_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS idx_statuses_user
  ON public.statuses(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_statuses_expiry
  ON public.statuses(expires_at);
CREATE INDEX IF NOT EXISTS idx_status_views_status
  ON public.status_views(status_id);
CREATE INDEX IF NOT EXISTS idx_status_views_viewer
  ON public.status_views(viewer_id, viewed_at);

/* =====================================================================
   2. ROW LEVEL SECURITY
   ===================================================================== */

ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_views ENABLE ROW LEVEL SECURITY;

-- Statuses: a user sees their own statuses plus those of their contacts.
DROP POLICY IF EXISTS "Statuses: read own or contacts" ON public.statuses;
CREATE POLICY "Statuses: read own or contacts"
  ON public.statuses FOR SELECT
  USING (
    user_id = auth.uid()
    OR user_id IN (
      SELECT contact_id FROM public.contacts WHERE user_id = auth.uid()
    )
  );

-- Statuses: authors create their own.
DROP POLICY IF EXISTS "Statuses: insert own" ON public.statuses;
CREATE POLICY "Statuses: insert own"
  ON public.statuses FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Statuses: authors update/delete their own (used by auto-expiry cleanup too).
DROP POLICY IF EXISTS "Statuses: update own" ON public.statuses;
CREATE POLICY "Statuses: update own"
  ON public.statuses FOR UPDATE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Statuses: delete own" ON public.statuses;
CREATE POLICY "Statuses: delete own"
  ON public.statuses FOR DELETE
  USING (user_id = auth.uid());

-- Views: only the viewer can see their own view rows.
DROP POLICY IF EXISTS "StatusViews: read own" ON public.status_views;
CREATE POLICY "StatusViews: read own"
  ON public.status_views FOR SELECT
  USING (viewer_id = auth.uid());

DROP POLICY IF EXISTS "StatusViews: insert own" ON public.status_views;
CREATE POLICY "StatusViews: insert own"
  ON public.status_views FOR INSERT
  WITH CHECK (viewer_id = auth.uid());

/* =====================================================================
   3. FUNCTIONS
   ===================================================================== */

-- Status feed for the current user: their own + their contacts' statuses that
-- have not expired yet, with `viewed` (has the caller seen it) and `view_count`.
CREATE OR REPLACE FUNCTION public.get_status_feed()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  author_full_name TEXT,
  author_phone TEXT,
  author_avatar_url TEXT,
  content TEXT,
  media_url TEXT,
  media_type TEXT,
  background_color TEXT,
  text_color TEXT,
  caption TEXT,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  viewed BOOLEAN,
  view_count BIGINT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    s.user_id,
    p.full_name,
    p.phone,
    p.avatar_url,
    s.content,
    s.media_url,
    s.media_type,
    s.background_color,
    s.text_color,
    s.caption,
    s.created_at,
    s.expires_at,
    EXISTS (
      SELECT 1 FROM public.status_views v
      WHERE v.status_id = s.id AND v.viewer_id = auth.uid()
    ) AS viewed,
    (
      SELECT COUNT(*) FROM public.status_views v
      WHERE v.status_id = s.id
    ) AS view_count
  FROM public.statuses s
  JOIN public.profiles p ON p.id = s.user_id
  WHERE s.expires_at > now()
    AND (
      s.user_id = auth.uid()
      OR s.user_id IN (
        SELECT contact_id FROM public.contacts WHERE user_id = auth.uid()
      )
    )
  ORDER BY s.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_status_feed() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_status_feed() TO service_role;

-- A user may only ever view someone else's status. Re-viewing the caller's own
-- status is a no-op (silently ignored) so authors never mark their own status seen.
CREATE OR REPLACE FUNCTION public.record_status_view(p_status_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.status_views (status_id, viewer_id)
  SELECT s.id, auth.uid()
  FROM public.statuses s
  WHERE s.id = p_status_id AND s.user_id <> auth.uid()
  ON CONFLICT (status_id, viewer_id) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_status_view(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_status_view(UUID) TO service_role;

-- Auto-expire old statuses (safe to run on a schedule / app launch / realtime tick).
CREATE OR REPLACE FUNCTION public.expire_statuses()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.statuses WHERE expires_at <= now();
$$;

GRANT EXECUTE ON FUNCTION public.expire_statuses() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_statuses() TO service_role;

/* =====================================================================
   4. REALTIME
   ===================================================================== */

ALTER PUBLICATION supabase_realtime ADD TABLE public.statuses;

-- A status update's effective lifespan is created_at..expires_at, so clients
-- only ever care about non-expired rows.
CREATE INDEX IF NOT EXISTS idx_statuses_realtime
  ON public.statuses(created_at);