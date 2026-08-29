import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../providers/starred_provider.dart';

class StarredMessagesScreen extends ConsumerWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = ref.watch(starredMessagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Starred Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
      ),
      body: starred.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.textSecondary))),
        data: (ids) => ids.isEmpty
            ? const Center(child: Text('No starred messages', style: TextStyle(color: AppColors.textTertiary)))
            : ListView.builder(
                itemCount: ids.length,
                itemBuilder: (context, index) => _StarredItem(messageId: ids.elementAt(index)),
              ),
      ),
    );
  }
}

class _StarredItem extends ConsumerWidget {
  final String messageId;
  const _StarredItem({required this.messageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    return FutureBuilder<Map<String, dynamic>?>(
      future: client.from('messages').select('content, message_type, chat_id').eq('id', messageId).limit(1).then((r) => r.isEmpty ? null : r.first),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final msg = snap.data!;
        final chatId = msg['chat_id'] as String?;
        return ListTile(
          leading: const Icon(Icons.star, color: AppColors.secondary),
          title: Text(msg['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(msg['message_type'] ?? '', style: const TextStyle(color: AppColors.textTertiary)),
          onTap: () {
            if (chatId != null) context.push('/chat/$chatId');
          },
        );
      },
    );
  }
}
