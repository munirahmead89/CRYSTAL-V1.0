// Crystal Messenger - send-message-push Edge Function
//
// Sends WhatsApp-style push notifications using Expo's FREE push service.
// Trigger it from a Supabase Database Webhook:
//   - Event  : INSERT on public.messages
//   - Method : POST
//   - URL    : https://<project-ref>.functions.supabase.co/send-message-push
//   - Headers: Authorization: Bearer <anon key>  (or leave unset; this function
//     reads push_tokens with the SERVICE_ROLE_KEY server-side)
//
// Requires env secrets (free tiers suffice):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   EXPO_ACCESS_TOKEN  (optional; not required for free Expo push volume)

import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const EXPO_PUSH_API = 'https://exp.host/--/api/v2/push/send';
const EXPO_ACCESS_TOKEN = Deno.env.get('EXPO_ACCESS_TOKEN') ?? '';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const record = body?.record;

    if (!record || !record.chat_id || !record.sender_id) {
      return new Response(JSON.stringify({ error: 'Missing message record' }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const { chat_id, sender_id, content, message_type } = record;

    const { data: participants, error: pErr } = await supabase
      .from('chat_participants')
      .select('user_id')
      .eq('chat_id', chat_id)
      .neq('user_id', sender_id);

    if (pErr || !participants || participants.length === 0) {
      return new Response(JSON.stringify({ ok: true }), { headers: corsHeaders });
    }

    const recipientIds = participants.map((p: { user_id: string }) => p.user_id);

    const { data: tokens, error: tErr } = await supabase
      .from('push_tokens')
      .select('token')
      .in('user_id', recipientIds)
      .eq('is_active', true);

    if (tErr || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ ok: true }), { headers: corsHeaders });
    }

    const { data: sender } = await supabase
      .from('profiles')
      .select('full_name')
      .eq('id', sender_id)
      .single();

    const senderName = sender?.full_name || 'Crystal';

    const preview =
      message_type === 'text'
        ? String(content ?? '').slice(0, 120)
        : `Sent you a ${message_type ?? 'message'}`;

    const notifications = tokens.map((t: { token: string }) => ({
      to: t.token,
      sound: 'default',
      title: senderName,
      body: preview || 'New message',
      data: { chatId: chat_id, senderId: sender_id },
    }));

    const pushRes = await fetch(EXPO_PUSH_API, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(EXPO_ACCESS_TOKEN
          ? { Authorization: `Bearer ${EXPO_ACCESS_TOKEN}` }
          : {}),
      },
      body: JSON.stringify(notifications),
    });

    const pushBody = await pushRes.json();
    return new Response(JSON.stringify(pushBody), { headers: corsHeaders });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
