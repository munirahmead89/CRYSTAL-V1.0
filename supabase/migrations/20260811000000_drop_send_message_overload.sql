-- Two overloads of send_message() existed: (uuid, text, text, uuid) and
-- (uuid, text, text, uuid, jsonb). When the client omitted the optional
-- metadata argument PostgREST refused to pick one (PGRST203 / ambiguous
-- overload), so messages could not be sent.
--
-- This migration removes the shorter 4-arg overload, leaving the canonical
-- 5-arg signature (chat_id, content, message_type, reply_to_id, metadata)
-- with metadata nullable.

drop function if exists public.send_message(uuid, text, text, uuid);
