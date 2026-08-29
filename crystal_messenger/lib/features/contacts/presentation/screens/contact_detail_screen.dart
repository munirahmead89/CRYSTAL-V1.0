import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/contacts_provider.dart';
import '../../../shared/widgets/app_avatar.dart';

class ContactDetailScreen extends ConsumerWidget {
  final String contactId;
  const ContactDetailScreen({super.key, required this.contactId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider).contacts;
    final contact = contacts.where((c) => c['contact_id'] == contactId).firstOrNull;

    if (contact == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Contact not found', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final profile = contact['profile'] as Map<String, dynamic>?;
    final name = contact['display_name'] ?? profile?['full_name'] ?? 'Unknown';
    final phone = profile?['phone'] ?? '';
    final bio = profile?['bio'] ?? '';
    final avatarUrl = profile?['avatar_url'] as String?;
    final isOnline = profile?['is_online'] == true;
    final isFavorite = contact['is_favorite'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.surface,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    AppAvatar(
                      imageUrl: avatarUrl,
                      name: name,
                      size: 100,
                      isOnline: isOnline,
                      showStatus: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isOnline)
                      const Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onlineIndicator,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionButton(Icons.chat, 'Chat', () {
                        context.push('/chat/$contactId');
                      }),
                      _actionButton(Icons.call, 'Call', () {}),
                      _actionButton(Icons.videocam, 'Video', () {}),
                      _actionButton(
                        isFavorite ? Icons.star : Icons.star_border,
                        isFavorite ? 'Unfavorite' : 'Favorite',
                        () {
                          ref.read(contactsProvider.notifier).toggleFavorite(
                                contact['id'],
                                isFavorite,
                              );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Info
                if (phone.isNotEmpty)
                  _infoTile(Icons.phone, 'Phone', phone),
                if (bio.isNotEmpty)
                  _infoTile(Icons.info_outline, 'Bio', bio),

                const SizedBox(height: 16),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 8),

                // Block/Delete
                ListTile(
                  leading: Icon(
                    contact['is_blocked'] == true ? Icons.lock_open : Icons.block,
                    color: AppColors.error,
                  ),
                  title: Text(
                    contact['is_blocked'] == true ? 'Unblock' : 'Block',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    ref.read(contactsProvider.notifier).toggleBlock(
                          contact['id'],
                          contact['is_blocked'] ?? false,
                        );
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text(
                    'Remove contact',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    ref.read(contactsProvider.notifier).removeContact(contact['id']);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
    );
  }
}
