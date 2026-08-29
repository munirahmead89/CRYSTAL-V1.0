import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../../shared/widgets/setting_row.dart';

class DataStorageScreen extends ConsumerWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Storage and Data'), backgroundColor: AppColors.surface),
      body: ListView(
        children: [
          const _Header('Auto-download media'),
          ListTile(
            leading: const Icon(Icons.wifi, color: AppColors.textPrimary),
            title: const Text('On Wi-Fi', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(s.autoDownload == 'wifi' ? 'All media' : s.autoDownload, style: const TextStyle(color: AppColors.textTertiary)),
            onTap: () => notifier.setAutoDownload('wifi'),
          ),
          ListTile(
            leading: const Icon(Icons.signal_cellular_alt, color: AppColors.textPrimary),
            title: const Text('On mobile data', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Photos only', style: TextStyle(color: AppColors.textTertiary)),
            onTap: () => notifier.setAutoDownload('mobile'),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: AppColors.textPrimary),
            title: const Text('Never', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => notifier.setAutoDownload('never'),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ListTile(
            leading: const Icon(Icons.data_usage, color: AppColors.textPrimary),
            title: const Text('Low data usage', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Reduce data in calls', style: TextStyle(color: AppColors.textTertiary)),
            trailing: Switch(
              value: s.lowDataUsage,
              activeColor: AppColors.primary,
              onChanged: notifier.setLowDataUsage,
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
