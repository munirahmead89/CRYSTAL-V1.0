-- Crystal Messenger / CCLINT private storage setup
-- Run after 00001_full_whatsapp_backend.sql.
-- Required object path format: <authenticated-user-id>/<filename>

SET search_path = public, storage;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', false, 10485760,
    ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]),
  ('attachments', 'attachments', false, 52428800, NULL),
  ('media', 'media', false, 524288000, NULL),
  ('voice-notes', 'voice-notes', false, 52428800,
    ARRAY['audio/aac', 'audio/m4a', 'audio/mp4', 'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/webm']::text[])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- All buckets are private. Access is controlled by object ownership and paths.
DROP POLICY IF EXISTS "Private storage read own folder" ON storage.objects;
CREATE POLICY "Private storage read own folder"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id IN ('avatars', 'attachments', 'media', 'voice-notes')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Private storage upload own folder" ON storage.objects;
CREATE POLICY "Private storage upload own folder"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('avatars', 'attachments', 'media', 'voice-notes')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Private storage update own folder" ON storage.objects;
CREATE POLICY "Private storage update own folder"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('avatars', 'attachments', 'media', 'voice-notes')
    AND owner_id = auth.uid()::text
  )
  WITH CHECK (
    bucket_id IN ('avatars', 'attachments', 'media', 'voice-notes')
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Private storage delete own folder" ON storage.objects;
CREATE POLICY "Private storage delete own folder"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id IN ('avatars', 'attachments', 'media', 'voice-notes')
    AND owner_id = auth.uid()::text
  );

-- Cleanup only temporary/unreferenced non-avatar files. Avatar objects are
-- intentionally excluded so a user's profile photo is never purged by age.
CREATE OR REPLACE FUNCTION public.purge_unreferenced_storage_objects(
  p_age interval DEFAULT interval '7 days',
  p_limit integer DEFAULT 500
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  v_deleted integer := 0;
BEGIN
  WITH candidates AS (
    SELECT o.id
    FROM storage.objects o
    WHERE o.bucket_id IN ('attachments', 'media', 'voice-notes')
      AND o.created_at < now() - p_age
      AND NOT EXISTS (
        SELECT 1
        FROM public.media_uploads u
        WHERE u.id::text = split_part(o.name, '/', 2)
           OR u.file_name = o.name
           OR coalesce(u.file_sha256, '') = split_part(o.name, '/', 2)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.attachment::text LIKE '%' || o.name || '%'
      )
    ORDER BY o.created_at
    LIMIT greatest(1, least(p_limit, 5000))
  )
  DELETE FROM storage.objects o
  USING candidates c
  WHERE o.id = c.id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_unreferenced_storage_objects(interval, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_unreferenced_storage_objects(interval, integer) TO service_role;

-- Schedule only if pg_cron is enabled in the project:
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule(
--   'purge-unreferenced-media',
--   '17 * * * *',
--   $$SELECT public.purge_unreferenced_storage_objects(interval '7 days', 500);$$
-- );
