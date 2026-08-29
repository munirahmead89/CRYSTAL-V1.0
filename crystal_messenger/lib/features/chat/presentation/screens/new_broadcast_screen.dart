import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../contacts/presentation/providers/contacts_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../data/repositories/chat_repository.dart';

class NewBroadcastScreen extends ConsumerStatefulWidget {
  const NewBroadcastScreen({super.key});

  @override
  ConsumerState<NewBroadcastScreen> createState() => _NewBroadcastScreenState();
}

class _NewBroadcastScreenState extends ConsumerState<NewBroadcastScreen> {
  final Set<String> _selected = {};
  final TextEditingController _name = TextEditingController(text: 'My broadcast');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selected.isEmpty) return;
    final repo = ref.read(chatRepositoryProvider);
    final chatId = await repo.createBroadcast(_name.text.trim(), _selected.toList());
    if (mounted) context.go('/chat/$chatId');
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('New Broadcast', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: AppColors.primary), onPressed: _create),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _name,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Broadcast name', labelStyle: TextStyle(color: AppColors.textTertiary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Select recipients', style: TextStyle(color: AppColors.textSecondary)),
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
            child: contactsState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    itemCount: contactsState.contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contactsState.contacts[index];
                      final profile = contact['profile'] as Map<String, dynamic>? ?? {};
                      final id = profile['id'] as String? ?? contact['contact_id'];
                      final name = contact['display_name'] as String? ?? profile['full_name'] ?? 'Unknown';
                      final selected = id != null && _selected.contains(id);
                      return CheckboxListTile(
                        secondary: AppAvatar(imageUrl: profile['avatar_url'], name: name, size: 44),
                        title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                        value: selected,
                        onChanged: id == null ? null : (v) => setState(() => v! ? _selected.add(id) : _selected.remove(id)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
