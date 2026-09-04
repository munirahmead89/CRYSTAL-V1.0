import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/setting_row.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final user = client.auth.currentUser;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: AppColors.surface),
      body: ListView(
        children: [
          // Profile header
          ListTile(
            leading: const AppAvatar(name: 'Me', size: 56),
            title: Text(
              user?.userMetadata?['full_name'] ?? 'User',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              user?.userMetadata?['phone'] ?? '',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            onTap: () => context.push('/profile'),
          ),

          const Divider(color: AppColors.divider, height: 1),

          SettingRow(
            icon: Icons.lock,
            title: 'Account',
            subtitle: 'Security, phone number, email',
            onTap: () => context.push('/settings/account'),
          ),
          SettingRow(
            icon: Icons.key,
            title: 'Privacy',
            subtitle: 'Blocked contacts, read receipts',
            onTap: () => context.push('/settings/privacy'),
          ),
          SettingRow(
            icon: Icons.chat,
            title: 'Chats',
            subtitle: 'Theme, wallpaper, chat history',
            onTap: () => context.push('/settings/chats'),
          ),
          SettingRow(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Message, group, call',
            onTap: () => context.push('/settings/notifications'),
          ),
          SettingRow(
            icon: Icons.language,
            title: 'App Language',
            subtitle: settings.language,
            onTap: () {},
          ),
          SettingRow(
            icon: Icons.storage,
            title: 'Storage and Data',
            subtitle: 'Network usage, auto-download',
            onTap: () => context.push('/settings/storage'),
          ),
          SettingRow(
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'Help center, contact us, privacy policy',
            onTap: () {},
          ),

          const Divider(color: AppColors.divider, height: 1),

          SettingRow(
            icon: Icons.qr_code,
            title: 'QR Code',
            onTap: () => context.push('/qr-code'),
          ),
          SettingRow(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'v2.0.0',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
