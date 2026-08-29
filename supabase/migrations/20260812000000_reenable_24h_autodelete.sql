-- Crystal Messenger - v1.1.2 re-enable 24h auto-delete (disappearing messages)
-- v1.1.1 deliberately turned the relay-mode purge functions into no-ops so
-- chats persisted forever. We now bring back WhatsApp-style automatic deletion:
-- every message disappears 24 hours after it was sent (or sooner, honoring a
-- chat's `disappearing_timer`). Media files and chats emptied by the purge are
-- cleaned up by the scheduled hourly pg_cron job.
--
-- The admin/suspension work from v1.1.1 is preserved; nothing here touches it.

/* =====================================================================
   1. AUTO-DISAPPEARING MESSAGES (default 24h, honors per-chat timer)
   ===================================================================== */

CREATE OR REPLACE FUNCTION public.auto_disappear_messages()
RETURNS void AS $$
DECLARE
  r RECORD;
  obj_path TEXT;
  lifetime_secs float8;
BEGIN
  -- 1) Remove media objects belonging to expired image/audio messages.
  FOR r IN
    SELECT m.id, m.content,
           COALESCE(c.disappearing_timer, 86400)::float8 AS life
    FROM public.messages m
    JOIN public.chats c ON c.id = m.chat_id
    WHERE m.message_type IN ('image', 'audio')
      AND m.content LIKE '%/object/public/media/%'
      AND COALESCE(c.disappearing_timer, 86400) > 0
      AND m.created_at < now() - make_interval(secs => COALESCE(c.disappearing_timer, 86400)::float8)
  LOOP
    obj_path := regexp_replace(r.content, '^.*/object/public/media/', '');
    obj_path := regexp_replace(obj_path, '\?.*$', '');
    BEGIN
      DELETE FROM storage.objects
      WHERE bucket_id = 'media' AND name = obj_path;
    EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
      NULL; -- never let storage issues block message deletion
    END;
  END LOOP;

  -- 2) Hard-delete expired messages (message_reactions + message_reads
  --    cascade via ON DELETE CASCADE). Default lifetime is 24 hours.
  DELETE FROM public.messages m
  USING public.chats c
  WHERE c.id = m.chat_id
    AND COALESCE(c.disappearing_timer, 86400) > 0
    AND m.created_at < now() - make_interval(secs => COALESCE(c.disappearing_timer, 86400)::float8);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

/* =====================================================================
   2. 24H CHAT/MEDIA PURGE (restores the original relay-mode purge)
   ===================================================================== */

CREATE OR REPLACE FUNCTION public.purge_expired_chats()
RETURNS void AS $$
DECLARE
  r RECORD;
  obj_path TEXT;
BEGIN
  -- 1) Storage: delete media objects for expired image/audio messages.
  FOR r IN
    SELECT id, content FROM public.messages
    WHERE created_at < now() - interval '24 hours'
      AND message_type IN ('image', 'audio')
      AND content LIKE '%/object/public/media/%'
  LOOP
    obj_path := regexp_replace(r.content, '^.*/object/public/media/', '');
    obj_path := regexp_replace(obj_path, '\?.*$', '');
    BEGIN
      DELETE FROM storage.objects
      WHERE bucket_id = 'media' AND name = obj_path;
    EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
      NULL;
    END;
  END LOOP;

  -- 2) Hard-delete messages older than 24h (reads + reactions cascade).
  DELETE FROM public.messages
  WHERE created_at < now() - interval '24 hours';

  -- 3) Delete chats with no messages left that have been inactive > 24h.
  DELETE FROM public.chats c
  WHERE c.updated_at < now() - interval '24 hours'
    AND NOT EXISTS (SELECT 1 FROM public.messages m WHERE m.chat_id = c.id);

  -- 4) Remove orphaned media files older than 24h.
  DELETE FROM storage.objects o
  WHERE o.bucket_id = 'media'
    AND o.created_at < now() - interval '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM public.messages m
      WHERE m.message_type IN ('image', 'audio')
        AND m.content LIKE '%/object/public/media/' || o.name || '%'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

/* =====================================================================
   3. SCHEDULE (hourly, only if pg_cron is enabled)
   ===================================================================== */

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'disappear-messages') THEN
      PERFORM cron.schedule('disappear-messages', '0 * * * *', $$SELECT public.auto_disappear_messages()$$);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-chats-24h') THEN
      PERFORM cron.schedule('purge-chats-24h', '0 * * * *', $$SELECT public.purge_expired_chats()$$);
    END IF;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.auto_disappear_messages() TO authenticated;
GRANT EXECUTE ON FUNCTION public.purge_expired_chats() TO authenticated;