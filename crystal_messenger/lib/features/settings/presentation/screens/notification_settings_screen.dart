import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../../shared/widgets/setting_row.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          SettingSwitch(
            icon: Icons.notifications,
            title: 'Enable Notifications',
            value: settings.notificationsEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
          ),
          SettingSwitch(
            icon: Icons.message,
            title: 'Message Preview',
            subtitle: 'Show message content in notification',
            value: settings.messagePreview,
            onChanged: (v) => ref.read(settingsProvider.notifier).setMessagePreview(v),
          ),
          SettingSwitch(
            icon: Icons.volume_up,
            title: 'Sound',
            value: settings.soundEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier).setSoundEnabled(v),
          ),
          SettingSwitch(
            icon: Icons.vibration,
            title: 'Vibration',
            value: settings.vibrationEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier).setVibrationEnabled(v),
          ),
        ],
      ),
    );
  }
}
