import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../../shared/widgets/setting_row.dart';

class ChatsSettingsScreen extends ConsumerWidget {
  const ChatsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chats'), backgroundColor: AppColors.surface),
      body: ListView(
        children: [
          const _Header('Display'),
          ListTile(
            leading: const Icon(Icons.contrast, color: AppColors.textPrimary),
            title: const Text('Pure black theme', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('True-black backgrounds for OLED', style: TextStyle(color: AppColors.textTertiary)),
            trailing: Switch(
              value: s.pureBlack,
              activeColor: AppColors.primary,
              onChanged: notifier.setPureBlack,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper, color: AppColors.textPrimary),
            title: const Text('Wallpaper', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(s.wallpaper, style: const TextStyle(color: AppColors.textTertiary)),
            onTap: () {},
          ),
          const Divider(color: AppColors.divider, height: 1),
          const _Header('Composing'),
          ListTile(
            leading: const Icon(Icons.keyboard_return, color: AppColors.textPrimary),
            title: const Text('Enter is send', style: TextStyle(color: AppColors.textPrimary)),
            trailing: Switch(
              value: s.enterIsSend,
              activeColor: AppColors.primary,
              onChanged: notifier.setEnterIsSend,
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          const _Header('Privacy in chats'),
          ListTile(
            leading: const Icon(Icons.done_all, color: AppColors.textPrimary),
            title: const Text('Read receipts', style: TextStyle(color: AppColors.textPrimary)),
            trailing: Switch(
              value: s.readReceipts,
              activeColor: AppColors.primary,
              onChanged: notifier.setReadReceipts,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.visibility, color: AppColors.textPrimary),
            title: const Text('Online status', style: TextStyle(color: AppColors.textPrimary)),
            trailing: Switch(
              value: s.onlineStatus,
              activeColor: AppColors.primary,
              onChanged: notifier.setOnlineStatus,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.timer, color: AppColors.textPrimary),
            title: const Text('Disappearing messages', style: TextStyle(color: AppColors.textPrimary)),
            trailing: Switch(
              value: s.disappearingMessages,
              activeColor: AppColors.primary,
              onChanged: notifier.setDisappearingMessages,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
