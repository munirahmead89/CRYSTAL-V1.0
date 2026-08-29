import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/contacts_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

class NewContactScreen extends ConsumerStatefulWidget {
  const NewContactScreen({super.key});

  @override
  ConsumerState<NewContactScreen> createState() => _NewContactScreenState();
}

class _NewContactScreenState extends ConsumerState<NewContactScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _showManualEntry = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Contact'),
        backgroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phone Number',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            AppInput(
              hint: '+1 234 567 8900',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
              controller: _phoneController,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Search',
              icon: Icons.search,
              onPressed: () => _searchContact(),
            ),
            const SizedBox(height: 24),
            if (_showManualEntry) ...[
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),
              const Text(
                'Manual Entry',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              AppInput(
                hint: 'Contact name',
                prefixIcon: Icons.person,
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Save Contact',
                icon: Icons.save,
                onPressed: () => _saveManualContact(),
              ),
            ],
            const Spacer(),
            if (!_showManualEntry)
              TextButton(
                onPressed: () => setState(() => _showManualEntry = true),
                child: const Text('Enter manually instead'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchContact() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    await ref.read(contactsProvider.notifier).searchByPhone(phone);

    if (mounted) {
      final deviceContacts = ref.read(contactsProvider).deviceContacts;
      if (deviceContacts.isNotEmpty) {
        final profile = deviceContacts.first;
        await ref.read(contactsProvider.notifier).addContact(profile['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact added!')),
          );
          context.pop();
        }
      } else {
        setState(() => _showManualEntry = true);
      }
    }
  }

  Future<void> _saveManualContact() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    if (phone.isEmpty) return;

    await ref.read(contactsProvider.notifier).addContactByPhone(phone);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact added!')),
      );
      context.pop();
    }
  }
}
