import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/setting_row.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final user = client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Account'), backgroundColor: AppColors.surface),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          SettingRow(
            icon: Icons.person,
            title: 'Name',
            subtitle: user?.userMetadata?['full_name'] ?? 'User',
            onTap: () => _editName(context, ref),
          ),
          SettingRow(
            icon: Icons.phone,
            title: 'Phone',
            subtitle: user?.userMetadata?['phone'] ?? 'Not set',
            onTap: () {},
          ),
          SettingRow(
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () {},
          ),
          SettingRow(
            icon: Icons.verified_user,
            title: 'Two-Step Verification',
            onTap: () {},
          ),
          SettingRow(
            icon: Icons.email,
            title: 'Email Address',
            subtitle: user?.email ?? 'Not set',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          SettingRow(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            onTap: () => _deleteAccount(context, ref),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  void _editName(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: ref.read(supabaseClientProvider).auth.currentUser?.userMetadata?['full_name'] ?? '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceBright,
        title: const Text('Edit Name', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Full name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider).from('profiles').update({
                'full_name': controller.text.trim(),
              }).eq('id', ref.read(supabaseClientProvider).auth.currentUser!.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceBright,
        title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
        content: const Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider).rpc('delete_account');
              if (context.mounted) {
                await ref.read(authProvider.notifier).signOut();
                context.go('/onboarding');
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
