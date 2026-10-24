import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/conversations/presentation/providers/chat_providers.dart';
import '../models/user_profile.dart';
import 'user_avatar.dart';

/// WhatsApp-style profile quick-view bottom sheet, opened by tapping an avatar
/// in the chat list (and the chat header).
///
/// Layout: enlarged avatar, name + presence label, then a row of quick actions:
///   Chat              Ã¢â€ â€™ opens the 1:1 thread,
///   Audio call        Ã¢â€ â€™ starts a P2P voice call,
///   Video call        Ã¢â€ â€™ starts a P2P video call,
///   Info              Ã¢â€ â€™ full user details page.
Future<void> showProfileQuickView(
  BuildContext context,
  WidgetRef ref, {
  required UserProfile profile,
  String? conversationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    builder: (_) =>
        _ProfileQuickView(profile: profile, conversationId: conversationId),
  );
}

class _ProfileQuickView extends ConsumerWidget {
  const _ProfileQuickView({required this.profile, this.conversationId});

  final UserProfile profile;
  final String? conversationId;

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    var chatId = conversationId;
    if (chatId == null) {
      final store = ref.read(localStoreProvider);
      final repo = ref.read(conversationsRepositoryProvider);
      chatId =
          await store.findDirectConversationWith(profile.id) ??
          await repo.getOrCreateDirectConversation(peerId: profile.id);
    }
    if (context.mounted) {
      context.push('/chat/$chatId');
    }
  }

  void _info(BuildContext context) {
    Navigator.of(context).pop();
    context.push('/contact', extra: profile);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = profile.isOnline;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              profile: profile,
              radius: 44,
              online: isOnline,
              avatarUserId: profile.id,
            ),
            const SizedBox(height: 12),
            Text(
              profile.displayName.isNotEmpty
                  ? profile.displayName
                  : profile.phone,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            // Presence label only Ã¢â‚¬â€ the ring on the avatar carries the
            // online/offline indicator (no standalone dot).
            Text(
              isOnline
                  ? 'Online'
                  : (profile.phone.isNotEmpty ? profile.phone : 'Offline'),
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                profile.bio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () => _openChat(context, ref),
                ),
                _QuickAction(
                  icon: Icons.info_outline,
                  label: 'Info',
                  onTap: () => _info(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
