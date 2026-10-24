import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../../shared/widgets/profile_quick_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show ownProfileProvider;
import '../providers/chat_providers.dart';

/// Full user details page (the "Info" target of the avatar quick-view sheet).
/// Shows a large avatar with presence ring, contact metadata, verification
/// status and quick actions (Chat / Audio / Video call).
class ContactInfoPage extends ConsumerStatefulWidget {
  const ContactInfoPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<ContactInfoPage> createState() => _ContactInfoPageState();
}

class _ContactInfoPageState extends ConsumerState<ContactInfoPage> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _refresh();
  }

  /// Pulls the freshest presence/bio for the pinned profile.
  Future<void> _refresh() async {
    try {
      final live = await ref
          .read(peopleRepositoryProvider)
          .fetchProfileById(widget.profile.id);
      if (live != null && mounted) setState(() => _profile = live);
    } catch (_) {
      // Offline: keep the pinned snapshot.
    }
  }

  Future<void> _openChat() async {
    final profile = _profile ?? widget.profile;
    final existing = await ref
        .read(localStoreProvider)
        .findDirectConversationWith(profile.id);
    final conversationId =
        existing ??
        await ref
            .read(conversationsRepositoryProvider)
            .getOrCreateDirectConversation(peerId: profile.id);
    if (mounted) context.pushReplacement('/chat/$conversationId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = _profile ?? widget.profile;
    final isOnline = profile.isOnline;
    final isMe = ref.watch(ownProfileProvider).valueOrNull?.id == profile.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact info')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => showProfileQuickView(context, ref, profile: profile),
              child: UserAvatar(
                profile: profile,
                radius: 52,
                online: isOnline,
                avatarUserId: profile.id,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName
                        : profile.phone,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (profile.isVerified) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            // Presence label only â€” the ring on the avatar carries the
            // online/offline indicator (no standalone dot).
            child: Text(
              isOnline ? 'Online' : _lastSeen(profile.lastSeenAt),
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
          ),
          const SizedBox(height: 20),
          if (!isMe) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    onTap: _openChat,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Divider(color: colorScheme.outlineVariant),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Phone'),
            subtitle: Text(profile.phone.isNotEmpty ? profile.phone : 'â€”'),
          ),
          if (profile.bio.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('About'),
              subtitle: Text(profile.bio),
            ),
          const SizedBox(height: 8),
          _InfoSection(
            children: [
              _InfoRow(
                icon: Icons.photo_library_outlined,
                title: 'Media, links and docs',
                subtitle: 'Shared items in this conversation',
                onTap: () => _showComingSoon(context, 'Shared media'),
              ),
              _InfoRow(
                icon: Icons.star_border,
                title: 'Starred messages',
                subtitle: 'Messages you saved',
                onTap: () => _showComingSoon(context, 'Starred messages'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoSection(
            children: [
              _InfoRow(
                icon: Icons.timer_outlined,
                title: 'Disappearing messages',
                subtitle: 'Off',
                onTap: () => _showComingSoon(context, 'Disappearing messages'),
              ),
              _InfoRow(
                icon: Icons.lock_outline,
                title: 'Encryption',
                subtitle: 'Messages are protected in transit',
                onTap: () => _showEncryptionInfo(context),
              ),
            ],
          ),
          if (profile.isVerified)
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Verified account'),
              subtitle: const Text('Uses a confirmed email/phone identity'),
            ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will appear here when available.')),
    );
  }

  void _showEncryptionInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Encryption', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Messages use the app relay over an authenticated Supabase connection. Media is stored privately and access is controlled by conversation membership.'),
            ],
          ),
        ),
      ),
    );
  }

  String _lastSeen(DateTime? at) {
    if (at == null) return 'Offline';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${at.day}/${at.month}/${at.year}';
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
