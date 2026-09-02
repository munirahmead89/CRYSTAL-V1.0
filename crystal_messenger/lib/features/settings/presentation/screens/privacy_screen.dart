import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../../shared/widgets/setting_row.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy'), backgroundColor: AppColors.surface),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          SettingSwitch(
            icon: Icons.traffic,
            title: 'Read Receipts',
            subtitle: 'Show when you\'ve read messages',
            value: settings.readReceipts,
            onChanged: (v) => ref.read(settingsProvider.notifier).setReadReceipts(v),
          ),
          SettingSwitch(
            icon: Icons.visibility,
            title: 'Online Status',
            subtitle: 'Show when you\'re online',
            value: settings.onlineStatus,
            onChanged: (v) => ref.read(settingsProvider.notifier).setOnlineStatus(v),
          ),
          SettingSwitch(
            icon: Icons.timer,
            title: 'Disappearing Messages',
            subtitle: 'Messages disappear after 24 hours',
            value: settings.disappearingMessages,
            onChanged: (v) => ref.read(settingsProvider.notifier).setDisappearingMessages(v),
          ),
          SettingSwitch(
            icon: Icons.fingerprint,
            title: 'Biometric Lock',
            subtitle: 'Require fingerprint to open app',
            value: settings.biometricLock,
            onChanged: (v) => ref.read(settingsProvider.notifier).setBiometricLock(v),
          ),
          SettingSwitch(
            icon: Icons.pin,
            title: 'PIN Lock',
            subtitle: 'Require PIN to open app',
            value: settings.pinLock,
            onChanged: (v) => ref.read(settingsProvider.notifier).setPinLock(v),
          ),
        ],
      ),
    );
  }
}
