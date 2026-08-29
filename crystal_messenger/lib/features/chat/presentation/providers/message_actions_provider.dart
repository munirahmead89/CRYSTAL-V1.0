import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';
import 'chat_provider.dart';

/// Forward an existing message into another chat, preserving its
/// content / type / metadata and flagging it as forwarded.
Future<void> forwardMessage(
  WidgetRef ref,
  String messageId,
  String targetChatId,
) async {
  final client = ref.read(supabaseClientProvider);
  final original = await client
      .from('messages')
      .select('content, message_type, metadata')
      .eq('id', messageId)
      .limit(1);
  if (original.isEmpty) return;

  final msg = original.first;
  final metadata = Map<String, dynamic>.from(msg['metadata'] ?? {});
  metadata['forwarded'] = true;

  await client.rpc('send_message', params: {
    'p_chat_id': targetChatId,
    'p_content': msg['content'],
    'p_message_type': msg['message_type'] ?? 'text',
    'p_metadata': metadata,
  });
  ref.invalidate(chatListProvider);
}
