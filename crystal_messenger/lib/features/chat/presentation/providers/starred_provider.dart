import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

/// All message ids the current user has starred.
final starredMessagesProvider = FutureProvider<Set<String>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser!.id;
  final rows = await client
      .from('starred_messages')
      .select('message_id')
      .eq('user_id', userId);
  return rows.map((r) => r['message_id'] as String).toSet();
});

/// Whether a specific message is starred by the current user.
final messageStarredProvider =
    Provider.family<bool, String>((ref, messageId) {
  final starred = ref.watch(starredMessagesProvider).valueOrNull;
  return starred?.contains(messageId) ?? false;
});

/// Toggle the starred state of a message (call from UI, then it invalidates cache).
Future<void> toggleStar(WidgetRef ref, String messageId) async {
  final client = ref.read(supabaseClientProvider);
  await client.rpc('toggle_star', params: {'p_message_id': messageId});
  ref.invalidate(starredMessagesProvider);
}
