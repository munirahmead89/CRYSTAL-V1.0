// Crystal Messenger - Process Scheduled Messages Edge Function
//
// Triggered by pg_cron every minute to send due scheduled messages.
// Can also be triggered manually for testing.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Find all due scheduled messages
    const { data: dueMessages, error: fetchError } = await supabase
      .from('scheduled_messages')
      .select('*')
      .eq('is_sent', false)
      .lte('scheduled_for', new Date().toISOString())
      .order('scheduled_for', { ascending: true })
      .limit(50);

    if (fetchError) throw fetchError;

    if (!dueMessages || dueMessages.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, processed: 0 }),
        { headers: corsHeaders }
      );
    }

    let processed = 0;
    let failed = 0;

    for (const msg of dueMessages) {
      try {
        // Send the message via the send_message RPC
        const { error: sendError } = await supabase.rpc('send_message', {
          p_chat_id: msg.chat_id,
          p_content: msg.content,
          p_message_type: msg.message_type || 'text',
          p_metadata: msg.metadata,
        });

        if (sendError) throw sendError;

        // Mark as sent
        await supabase
          .from('scheduled_messages')
          .update({ is_sent: true, sent_at: new Date().toISOString() })
          .eq('id', msg.id);

        processed++;
      } catch (e) {
        console.error(`Failed to send scheduled message ${msg.id}:`, e);
        failed++;
      }
    }

    return new Response(
      JSON.stringify({ ok: true, processed, failed, total: dueMessages.length }),
      { headers: corsHeaders }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
