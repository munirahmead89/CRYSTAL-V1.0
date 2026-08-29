import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/contacts_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_input.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? AppInput(
                controller: _searchController,
                hint: 'Search contacts...',
                onChanged: (v) {
                  if (v.isNotEmpty) {
                    ref.read(contactsProvider.notifier).searchByPhone(v);
                  }
                },
              )
            : const Text('Contacts'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.push('/new-contact'),
          ),
        ],
      ),
      body: contactsState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : contactsState.contacts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: contactsState.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contactsState.contacts[index];
                    final profile = contact['profile'] as Map<String, dynamic>?;
                    final name = contact['display_name'] ??
                        profile?['full_name'] ??
                        'Unknown';
                    final avatarUrl = profile?['avatar_url'] as String?;
                    final isOnline = profile?['is_online'] == true;
                    final isFavorite = contact['is_favorite'] == true;
                    final isBlocked = contact['is_blocked'] == true;

                    return ListTile(
                      leading: AppAvatar(
                        imageUrl: avatarUrl,
                        name: name,
                        size: 48,
                        isOnline: isOnline,
                        showStatus: true,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isBlocked
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          fontWeight: isFavorite ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        profile?['phone'] ?? '',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFavorite)
                            const Icon(Icons.star, color: AppColors.warning, size: 18),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.textTertiary.withAlpha(100),
                            size: 18,
                          ),
                        ],
                      ),
                      onTap: () => context.push('/contacts/${contact['contact_id']}'),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_outlined, size: 80, color: AppColors.textTertiary.withAlpha(80)),
          const SizedBox(height: 16),
          const Text(
            'No contacts found',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add contacts by phone number',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
