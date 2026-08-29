import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_settings_provider.dart';
import '../../../shared/widgets/app_avatar.dart';

class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatListProvider);
    final archived = chatState.chats.where((c) {
      final my = c['my_participant'] as Map<String, dynamic>?;
      return my?['is_archived'] == true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Archived', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
      ),
      body: archived.isEmpty
          ? const Center(child: Text('No archived chats', style: TextStyle(color: AppColors.textTertiary)))
          : ListView.builder(
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final chat = archived[index];
                final name = _name(chat);
                final avatar = _avatar(chat);
                final chatId = chat['id'] as String;
                return ListTile(
                  leading: AppAvatar(imageUrl: avatar, name: name, size: 52),
                  title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text((chat['last_message']?['content'] ?? '') ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textTertiary)),
                  onTap: () => context.push('/chat/$chatId'),
                  onLongPress: () => ref.read(chatSettingsProvider(chatId).notifier).toggleArchive(),
                );
              },
            ),
    );
  }

  String _name(Map<String, dynamic> c) {
    if (c['type'] == 'group' || c['type'] == 'broadcast') return c['name'] ?? 'Group';
    return (c['other_participant'] as Map?)?['full_name'] ?? 'Unknown';
  }

  String? _avatar(Map<String, dynamic> c) {
    if (c['type'] == 'group' || c['type'] == 'broadcast') return c['avatar_url'];
    return (c['other_participant'] as Map?)?['avatar_url'];
  }
}
