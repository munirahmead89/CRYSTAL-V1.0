-- ============================================================
-- Crystal Messenger — Supabase schema (PostgreSQL)
-- Paste this into the Supabase SQL Editor (Project > SQL Editor)
-- Run once. Everything rides on RLS + Realtime (Postgres changes).
-- ============================================================

-- ------------------------------------------------------------
-- 1. USERS / PROFILES
--   id = Supabase auth.uid()  (auth created at signup without OTP)
-- ------------------------------------------------------------
create table if not exists public.users (
    id          uuid primary key default auth.uid() references auth.users (id) on delete cascade,
    phone       text unique not null,
    name        text not null,
    about       text default 'Hey there! I am using Crystal Messenger.',
    avatar_url  text,
    wants_status boolean default true,
    status      text default 'offline' check (status in ('online', 'offline')),
    last_seen   timestamptz default now(),
    created_at  timestamptz default now()
);

alter table public.users enable row level security;

create policy "profiles_are_public" on public.users
    for select using (true);

create policy "own_profile_update" on public.users
    for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "own_profile_insert" on public.users
    for insert with check (auth.uid() = id);

-- presence heartbeat helper
create or replace function public.touch_presence(uid uuid, s text)
returns void language sql volatile security definer set search_path = public as $$
    update public.users set status = s, last_seen = now() where id = uid;
$$;

-- ------------------------------------------------------------
-- 2. CONVERSATIONS (single + group)
-- ------------------------------------------------------------
create table if not exists public.conversations (
    id           uuid primary key default gen_random_uuid(),
    ctype        text not null default 'single' check (ctype in ('single','group')),
    name         text,
    description  text,
    avatar_url   text,
    created_by   uuid references public.users (id),
    last_message_text text,
    last_message_at  timestamptz default now(),
    created_at   timestamptz default now()
);

create table if not exists public.conversation_members (
    conversation_id uuid references public.conversations (id) on delete cascade,
    user_id         uuid references public.users (id) on delete cascade,
    nickname        text,
    role            text default 'member',
    joined_at       timestamptz default now(),
    primary key (conversation_id, user_id)
);

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;

-- users only see conversations they belong to
create policy "member_read_conversation" on public.conversations
    for select using (
        exists (select 1 from public.conversation_members m
                where m.conversation_id = conversations.id and m.user_id = auth.uid())
    );

create policy "member_read_membership" on public.conversation_members
    for select using (
        conversation_id in (
            select conversation_id from public.conversation_members
            where user_id = auth.uid()
        )
    );

create policy "member_insert_membership" on public.conversation_members
    for insert with check (
        user_id = auth.uid() or
        auth.uid() in (select created_by from public.conversations where id = conversation_id)
    );

-- secure RPC: idempotent direct/group conversation creation
create or replace function public.find_or_create_conversation(
    p_member_ids uuid[],   -- other participants (not yourself)
    p_name text default null,
    p_type text default 'single'
) returns public.conversations
language plpgsql volatile security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    conv public.conversations;
    existing uuid;
begin
    if me is null then raise exception 'not_authenticated'; end if;

    if p_type = 'single' and array_length(p_member_ids, 1) = 1 then
        select c.id into existing
        from public.conversations c
        join public.conversation_members m on m.conversation_id = c.id
        where c.ctype = 'single'
          and exists (
            select 1 from public.conversation_members m2
            where m2.conversation_id = c.id and m2.user_id = me
          )
          and exists (
            select 1 from public.conversation_members m3
            where m3.conversation_id = c.id and m3.user_id = p_member_ids[1]
          )
        limit 1;
        if existing is not null then
            select * into conv from public.conversations where id = existing;
            return conv;
        end if;
    end if;

    insert into public.conversations (ctype, name, created_by)
    values (p_type, coalesce(p_name, 'Unnamed'), me)
    returning * into conv;

    insert into public.conversation_members (conversation_id, user_id)
    values (conv.id, me);
    insert into public.conversation_members (conversation_id, user_id)
    select conv.id, unnest(p_member_ids)
    where not exists (select 1 from public.conversation_members where conversation_id = conv.id and user_id = auth.uid());

    return conv;
end;
$$;

grant execute on function public.find_or_create_conversation(uuid[], text, text) to authenticated;

-- ------------------------------------------------------------
-- 3. MESSAGES
-- ------------------------------------------------------------
create table if not exists public.messages (
    id            uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references public.conversations (id) on delete cascade,
    sender_id     uuid not null references public.users (id) on delete cascade,
    mtype         text not null default 'text' check (mtype in ('text','image','video','audio','file','location','reply')),
    body          text,
    media_url     text,
    media_thumb   text,
    media_duration double precision,
    media_name    text,
    lat           double precision,
    lng           double precision,
    reply_to_id   uuid references public.messages (id) on delete set null,
    delivered_at  timestamptz,
    read_at       timestamptz,
    created_at    timestamptz default now()
);

create index if not exists idx_messages_conversation on public.messages (conversation_id, created_at desc);

alter table public.messages enable row level security;

-- visibility gated by membership
create policy "member_read_message" on public.messages
    for select using (
        exists (select 1 from public.conversation_members m
                where m.conversation_id = messages.conversation_id and m.user_id = auth.uid())
    );

create policy "member_insert_message" on public.messages
    for insert with check (
        sender_id = auth.uid() and
        exists (select 1 from public.conversation_members m
                where m.conversation_id = messages.conversation_id and m.user_id = auth.uid())
    );

-- receipts update: only set read/delivered, never body/sender
create policy "member_update_message" on public.messages
    for update using (
        auth.uid() in (
            select user_id from public.conversation_members
            where conversation_id = messages.conversation_id
        )
    );

-- keep conversation summary fresh
create or replace function public.touch_conversation() returns trigger as $$
begin
    update public.conversations
    set last_message_text = left(coalesce(new.body, '[' || new.mtype || ']'), 120),
        last_message_at = new.created_at
    where id = new.conversation_id;
    return new;
end; $$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_touch_conversation on public.messages;
create trigger trg_touch_conversation
    after insert on public.messages
    for each row execute function public.touch_conversation();

-- mark all prior messages in a conversation as read when I send a message
create or replace function public.mark_conversation_read(p_conversation uuid)
returns void language sql volatile security definer set search_path = public as $$
    update public.messages
    set read_at = now()
    where conversation_id = p_conversation
      and sender_id <> auth.uid()
      and read_at is null;
$$;

grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.touch_presence(uuid, text) to authenticated;

-- ------------------------------------------------------------
-- 4. TYPING (used instead of raw broadcast — rides RLS)
-- ------------------------------------------------------------
create table if not exists public.typing (
    conversation_id uuid not null references public.conversations (id) on delete cascade,
    user_id         uuid not null references public.users (id) on delete cascade,
    is_typing       boolean not null default false,
    updated_at      timestamptz default now(),
    primary key (conversation_id, user_id)
);

alter table public.typing enable row level security;

create policy "member_read_typing" on public.typing
    for select using (
        exists (select 1 from public.conversation_members m
                where m.conversation_id = typing.conversation_id and m.user_id = auth.uid())
    );

create policy "self_write_typing" on public.typing
    for insert with check (user_id = auth.uid());
create policy "self_update_typing" on public.typing
    for update using (user_id = auth.uid());

-- ------------------------------------------------------------
-- 5. STATUS (WhatsApp-style stories, auto-expire 24h)
-- ------------------------------------------------------------
create table if not exists public.statuses (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references public.users (id) on delete cascade,
    stype      text not null default 'text' check (stype in ('text','image','video')),
    body       text,
    media_url  text,
    media_thumb text,
    created_at timestamptz default now(),
    expires_at timestamptz default now() + interval '24 hours'
);

create index if not exists idx_statuses_expiry on public.statuses (expires_at);
create index if not exists idx_statuses_user on public.statuses (user_id, created_at desc);

alter table public.statuses enable row level security;

create policy "status_read_authenticated" on public.statuses
    for select using (auth.uid() is not null and expires_at > now());

create policy "status_write_self" on public.statuses
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.status_views (
    status_id uuid references public.statuses (id) on delete cascade,
    viewer_id uuid references public.users (id) on delete cascade,
    viewed_at timestamptz default now(),
    primary key (status_id, viewer_id)
);

alter table public.status_views enable row level security;
create policy "status_view_insert" on public.status_views for insert with check (viewer_id = auth.uid());
create policy "status_view_read_owner" on public.status_views
    for select using (
        exists (select 1 from public.statuses s where s.id = status_id and s.user_id = auth.uid())
    );

-- ------------------------------------------------------------
-- 6. CALLS (log + realtime incoming signalling)
-- ------------------------------------------------------------
create table if not exists public.calls (
    id         uuid primary key default gen_random_uuid(),
    conversation_id uuid references public.conversations (id) on delete cascade,
    caller_id  uuid not null references public.users (id),
    callee_id  uuid not null references public.users (id),
    kind       text not null check (kind in ('audio','video')),
    status     text not null default 'ringing' check (status in ('ringing','missed','completed','declined','cancelled')),
    started_at timestamptz default now(),
    answered_at timestamptz,
    ended_at   timestamptz,
    duration   integer default 0
);

create index if not exists idx_calls_callee on public.calls (callee_id, started_at desc);

alter table public.calls enable row level security;

create policy "call_involved_read" on public.calls
    for select using (caller_id = auth.uid() or callee_id = auth.uid());

create policy "call_involved_insert" on public.calls
    for insert with check (caller_id = auth.uid());

create policy "call_involved_update" on public.calls
    for update using (caller_id = auth.uid() or callee_id = auth.uid());

-- ------------------------------------------------------------
-- 7. COMMUNITIES
-- ------------------------------------------------------------
create table if not exists public.communities (
    id          uuid primary key default gen_random_uuid(),
    name        text not null,
    description text,
    cover_url   text,
    created_by  uuid references public.users (id),
    created_at  timestamptz default now()
);

create table if not exists public.community_members (
    community_id uuid references public.communities (id) on delete cascade,
    user_id      uuid references public.users (id) on delete cascade,
    role         text default 'member' check (role in ('member','admin')),
    joined_at    timestamptz default now(),
    primary key (community_id, user_id)
);

create table if not exists public.community_announcements (
    id          uuid primary key default gen_random_uuid(),
    community_id uuid references public.communities (id) on delete cascade,
    user_id     uuid references public.users (id),
    body        text,
    created_at  timestamptz default now()
);

alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.community_announcements enable row level security;

create policy "community_read" on public.communities
    for select using (
        exists (select 1 from public.community_members m where m.community_id = communities.id and m.user_id = auth.uid())
    );
create policy "community_create" on public.communities
    for insert with check (created_by = auth.uid());
create policy "community_membership_read" on public.community_members
    for select using (
        community_id in (select community_id from public.community_members where user_id = auth.uid())
    );
create policy "community_membership_join" on public.community_members
    for insert with check (user_id = auth.uid() or community_id in (
        select community_id from public.community_members where user_id = auth.uid()
    ));
create policy "community_announce_read" on public.community_announcements
    for select using (
        exists (select 1 from public.community_members m
                where m.community_id = community_announcements.community_id and m.user_id = auth.uid())
    );
create policy "community_announce_insert" on public.community_announcements
    for insert with check (user_id = auth.uid());

-- ------------------------------------------------------------
-- 8. REALTIME: publish tables to the Realtime layer
--    The client subscribes to postgres_changes on these.
-- ------------------------------------------------------------
alter publication supabase_realtime add table public.users;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_members;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.typing;
alter publication supabase_realtime add table public.statuses;
alter publication supabase_realtime add table public.calls;
alter publication supabase_realtime add table public.communities;
alter publication supabase_realtime add table public.community_members;
alter publication supabase_realtime add table public.community_announcements;

-- ------------------------------------------------------------
-- 9. STORAGE: media bucket + scoped policies
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 52428800,
        array['image/jpeg','image/png','image/webp','video/mp4','audio/mpeg','audio/mp4','application/pdf'])
on conflict (id) do nothing;

create policy "media_public_read" on storage.objects for select using (bucket_id = 'media');
create policy "media_auth_write" on storage.objects for insert with check (bucket_id = 'media' and auth.uid() is not null);
create policy "media_auth_update" on storage.objects for update using (bucket_id = 'media' and auth.uid() is not null);