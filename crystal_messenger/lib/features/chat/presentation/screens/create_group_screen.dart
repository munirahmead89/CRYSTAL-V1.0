import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../contacts/presentation/providers/contacts_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../data/repositories/chat_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a group name and at least one member')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final result = await chatRepo.createGroup(
        name: _nameController.text.trim(),
        memberIds: _selected.toList(),
      );
      if (mounted) {
        final chatId = result['chat_id'] as String? ?? result['id'];
        if (chatId != null) context.go('/chat/$chatId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('New Group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          _creating
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                )
              : IconButton(icon: const Icon(Icons.check, color: AppColors.primary), onPressed: _create),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const AppAvatar(size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Group name',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Add members', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text('${_selected.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: contactsAsync.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : contactsAsync.error != null
                    ? Center(child: Text('Error: ${contactsAsync.error}', style: const TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        itemCount: contactsAsync.contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contactsAsync.contacts[index];
                          final profile = contact['profile'] as Map<String, dynamic>? ?? {};
                          final id = profile['id'] as String? ?? contact['contact_id'];
                          final name = contact['display_name'] as String? ??
                              profile['full_name'] as String? ?? 'Unknown';
                          final avatar = profile['avatar_url'] as String?;
                          final selected = id != null && _selected.contains(id);
                          return ListTile(
                            leading: Stack(
                              children: [
                                AppAvatar(imageUrl: avatar, name: name, size: 48),
                                if (selected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                            onTap: id == null
                                ? null
                                : () => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
