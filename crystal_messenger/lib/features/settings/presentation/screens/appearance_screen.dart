import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/settings_provider.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Appearance'), backgroundColor: AppColors.surface),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Theme',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _themeOption('system', 'System', Icons.brightness_auto, ref, settings.theme),
          _themeOption('light', 'Light', Icons.light_mode, ref, settings.theme),
          _themeOption('dark', 'Dark', Icons.dark_mode, ref, settings.theme),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Wallpaper',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _wallpaperOption('aurora', 'Aurora', ref, settings.wallpaper),
          _wallpaperOption('midnight', 'Midnight', ref, settings.wallpaper),
          _wallpaperOption('graphite', 'Graphite', ref, settings.wallpaper),
          _wallpaperOption('violet', 'Violet', ref, settings.wallpaper),
        ],
      ),
    );
  }

  Widget _themeOption(String value, String label, IconData icon, WidgetRef ref, String current) {
    final isSelected = current == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
      title: Text(label, style: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      )),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: () => ref.read(settingsProvider.notifier).setTheme(value),
    );
  }

  Widget _wallpaperOption(String value, String label, WidgetRef ref, String current) {
    final isSelected = current == value;
    return ListTile(
      title: Text(label, style: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      )),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: () => ref.read(settingsProvider.notifier).setWallpaper(value),
    );
  }
}
