-- ===========================================================================
-- Crystal Messenger — PREFLIGHT audit (READ ONLY)
--
-- Run this FIRST, before any migration. It changes nothing: every statement is a
-- SELECT or a RAISE NOTICE.
--
-- Why it exists
-- -------------
-- The schema in this repository is spread over several files that were written
-- at different times and applied by hand:
--
--   supabase/migrations/00021_full_schema.sql   the canonical base
--   APPLY_THIS_TO_SUPABASE.sql                  an older full copy
--   APPLY_GAP_FILL.sql, APPLY_RLS_FIX.sql      targeted fixes
--   APPLY_AVATAR_FIX.sql, APPLY_AVATAR_PRIVACY.sql
--   APPLY_DELETE_ACCOUNT_RPC.sql
--
-- They overlap, so "which of these do I already have?" is not answerable by
-- reading the repository. This script answers it against YOUR database, so the
-- migration that follows only has to do the missing work.
--
-- How to read the output
-- ----------------------
--   missing      not present, the migration will create it
--   present      already correct, the migration will skip it
--   MISMATCH     exists but with a different definition/return type than the
--                repository expects — needs attention, flagged explicitly
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------
do $$
declare
  v_expected text[] := array[
    'profiles','devices','conversations','conversation_members','messages',
    'message_receipts','statuses','status_views','message_archive','groups',
    'group_members','communities','community_members','community_announcements',
    'contacts','blocked_users','message_reactions','typing','notifications',
    'admin_users','user_privacy_settings','device_sync_cursors','client_outbox',
    'notification_queue','user_settings','media_uploads','media_chunks',
    'device_link_sessions'
  ];
  t text;
  v_missing int := 0;
begin
  raise notice '=== TABLES ===';
  foreach t in array v_expected loop
    if to_regclass('public.' || t) is null then
      raise notice 'MISSING  table %', t;
      v_missing := v_missing + 1;
    else
      raise notice 'present  table %', t;
    end if;
  end loop;
  raise notice '% of % tables missing', v_missing, array_length(v_expected, 1);
end;
$$;

-- The calls table must be GONE. If it is still present, the app is shipping a
-- screen that reads a table nothing writes any more.
do $$
declare
  v_present boolean := to_regclass('public.calls') is not null;
begin
  if v_present then
    raise notice 'MISMATCH  table public.calls still exists - the calls-removal migration has not been applied';
  else
    raise notice 'present   table public.calls correctly absent';
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 2. The new conversations column
-- ---------------------------------------------------------------------------
do $$
declare
  v_col text;
begin
  raise notice '=== COLUMNS ===';
  select a.attname into v_col
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
   where c.relname = 'conversations'
     and a.attname = 'disappearing_seconds'
     and a.attnum > 0 and not a.attisdropped;
  if v_col is null then
    raise notice 'MISSING  conversations.disappearing_seconds (disappearing messages will not work)';
  else
    raise notice 'present  conversations.disappearing_seconds';
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 3. Functions the app calls
--
-- Every one of these is invoked by name from Dart. A missing function is a
-- runtime error in the app, not a build error, which is why it hides.
-- ---------------------------------------------------------------------------
do $$
declare
  v_expected text[] := array[
    'get_my_chats()',
    'get_messages(uuid,uuid,int)',
    'get_messages_after(uuid,uuid,int)',
    'mark_read(uuid,uuid)',
    'mark_delivered(uuid[])',
    'get_or_create_direct_conversation(uuid)',
    'create_group_conversation(text,uuid[])',
    'set_reaction(uuid,text)',
    'normalize_phone(text)',
    'restore_profile_by_phone(text)',
    'delete_user_account()',
    'register_device(text,text,text,text)',
    'set_presence(text)',
    'get_ban_status()',
    'submit_ban_appeal(text)',
    'media_storage_usage()',
    'purge_stale_media_uploads(interval)',
    'validate_media_upload()',
    'expire_device_link_sessions()',
    'device_link_qr_payload(uuid)',
    'post_status(uuid,text,jsonb,interval)',
    'view_status(uuid[])',
    'status_view_count(uuid[])',
    -- added this round
    'delete_conversation_messages(uuid)',
    'set_disappearing_messages(uuid,integer)',
    'purge_expired_messages(integer,timestamptz)'
  ];
  sig text;
  v_missing int := 0;
begin
  raise notice '=== FUNCTIONS ===';
  foreach sig in array v_expected loop
    -- to_regprocedure needs the bare name; 'uuid'/'timestamptz' are not valid
    -- there, so resolve through pg_proc on name + arg count instead.
    if exists (
      select 1 from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and p.proname = split_part(sig, '(', 1)
    ) then
      raise notice 'present  function %', sig;
    else
      raise notice 'MISSING  function %', sig;
      v_missing := v_missing + 1;
    end if;
  end loop;
  raise notice '% of % functions missing', v_missing, array_length(v_expected, 1);
end;
$$;


-- ---------------------------------------------------------------------------
-- 4. Storage buckets
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  raise notice '=== STORAGE BUCKETS ===';
  for r in select id, name, public from storage.buckets order by name loop
    raise notice 'present  bucket % (public=%)', r.name, r.public;
  end loop;
  if not exists (select 1 from storage.buckets where name = 'attachments') then
    raise notice 'MISSING  bucket attachments - all media transfer fails without it';
  end if;
  if not exists (select 1 from storage.buckets where name = 'avatars') then
    raise notice 'MISSING  bucket avatars - profile photos cannot be uploaded';
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 5. RLS coverage
--
-- A table with RLS enabled and no policies denies everything. That is the safe
-- failure mode, but it looks like "the app is broken" from the user's side, so
-- it is worth surfacing explicitly.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  raise notice '=== RLS COVERAGE ===';
  for r in
    select c.relname as tbl,
           c.relrowsecurity as rls_enabled,
           (select count(*) from pg_policies p where p.schemaname='public' and p.tablename=c.relname) as policies
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
     order by c.relname
  loop
    if r.rls_enabled and r.policies = 0 then
      raise notice 'WARNING  % has RLS on but NO policies - all access denied', r.tbl;
    end if;
  end loop;
  raise notice '(no WARNING lines above means every RLS table has at least one policy)';
end;
$$;


-- ---------------------------------------------------------------------------
-- 6. Realtime publication
-- ---------------------------------------------------------------------------
do $$
declare
  v_count int;
begin
  raise notice '=== REALTIME PUBLICATION ===';
  select count(*) into v_count
    from pg_publication_tables
   where pubname = 'supabase_realtime' and schemaname = 'public';
  raise notice 'supabase_realtime: % public table(s) published', v_count;
  if v_count = 0 then
    raise notice 'MISMATCH  no tables published - realtime delivery of messages will not work';
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 7. Scheduled jobs
--
-- Disappearing messages are enforced by a scheduled call, not by the app. If
-- this is missing, the timer can be set but nothing ever deletes anything.
-- ---------------------------------------------------------------------------
do $$
declare
  v_has_cron boolean := to_regclass('cron.job') is not null;
begin
  raise notice '=== SCHEDULED JOBS ===';
  if not v_has_cron then
    raise notice 'pg_cron is not installed: purge_expired_messages must be run by an external scheduler';
  else
    if exists (select 1 from cron.job where jobname = 'purge-expired-messages') then
      raise notice 'present  cron job purge-expired-messages';
    else
      raise notice 'MISSING  cron job purge-expired-messages - disappearing messages are NOT being enforced';
    end if;
  end if;
end;
$$;
