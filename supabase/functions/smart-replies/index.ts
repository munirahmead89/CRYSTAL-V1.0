// Crystal Messenger - AI Smart Replies Edge Function
//
// Generates contextual reply suggestions based on recent messages.
// Uses a lightweight rule-based approach (no external AI API needed).
// Can be upgraded to use OpenAI/Anthropic for smarter suggestions.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const QUICK_REPLIES: Record<string, string[]> = {
  greeting: ['Hey!', 'Hello!', 'Hi there!', 'What\'s up?'],
  question: ['Yes', 'No', 'Maybe', 'Let me check', 'Sure!', 'Of course'],
  thanks: ['You\'re welcome!', 'No problem!', 'Anytime!', 'My pleasure'],
  agreement: ['I agree', 'Sounds good', 'Perfect', 'Great idea', 'Let\'s do it'],
  decline: ['Sorry, I can\'t', 'Not now', 'Maybe later', 'I\'ll pass'],
  location: ['On my way!', 'I\'m here', 'Be there in 5 min', 'Where are you?'],
  time: ['Now', 'Later today', 'Tomorrow', 'This weekend', 'Next week'],
  food: ['Let\'s eat!', 'I\'m hungry', 'Pizza?', 'Sure, where?', 'Any preferences?'],
  default: ['👍', 'OK', 'Got it', 'Thanks!', 'Sounds good', 'Sure'],
};

function detectContext(message: string): string {
  const lower = message.toLowerCase();

  if (/\b(hi|hello|hey|howdy|greetings|sup|what'?s up)\b/.test(lower)) return 'greeting';
  if (/\?/.test(message) || /\b(do you|can you|would you|are you|will you|could you|should I)\b/.test(lower)) return 'question';
  if (/\b(thank|thanks|thx|ty|appreciate)\b/.test(lower)) return 'thanks';
  if (/\b(yes|yeah|yep|yup|sure|ok|okay|alright|fine)\b/.test(lower)) return 'agreement';
  if (/\b(no|nah|nope|not really|can't|cannot|busy)\b/.test(lower)) return 'decline';
  if (/\b(where|location|address|come|meeting|gym|office|home|restaurant)\b/.test(lower)) return 'location';
  if (/\b(when|time|what time|schedule|tomorrow|today|morning|evening| afternoon)\b/.test(lower)) return 'time';
  if (/\b(food|eat|lunch|dinner|breakfast|hungry|pizza|restaurant|coffee)\b/.test(lower)) return 'food';

  return 'default';
}

function generateSmartReplies(lastMessage: string, chatType: string): string[] {
  const context = detectContext(lastMessage);
  let suggestions = QUICK_REPLIES[context] ?? QUICK_REPLIES.default;

  // Add emoji reactions for short messages
  if (lastMessage.length < 10) {
    suggestions = ['👍', '❤️', '😂', '😮', ...suggestions.slice(0, 2)];
  }

  // For group chats, add group-relevant replies
  if (chatType === 'group') {
    suggestions = [...new Set(['👍', 'Count me in!', 'I\'m in', 'Send location', ...suggestions])].slice(0, 6);
  }

  return [...new Set(suggestions)].slice(0, 6);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { chat_id, message_id } = await req.json();

    if (!chat_id) {
      return new Response(
        JSON.stringify({ error: 'chat_id is required' }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Fetch the last few messages for context
    const { data: messages } = await supabase
      .from('messages')
      .select('content, message_type, sender_id')
      .eq('chat_id', chat_id)
      .eq('is_deleted', false)
      .order('created_at', { ascending: false })
      .limit(5);

    // Get chat type
    const { data: chat } = await supabase
      .from('chats')
      .select('type')
      .eq('id', chat_id)
      .single();

    const chatType = chat?.type ?? 'direct';
    const lastMessage = messages?.[0]?.content ?? '';

    const replies = generateSmartReplies(lastMessage, chatType);

    return new Response(
      JSON.stringify({
        replies,
        context: detectContext(lastMessage),
        last_message_preview: lastMessage.slice(0, 100),
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
