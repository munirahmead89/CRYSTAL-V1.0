import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _cameraGranted = false;
  bool _micGranted = false;
  bool _contactsGranted = false;
  bool _notificationsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _cameraGranted = false;
      _micGranted = false;
      _contactsGranted = false;
      _notificationsGranted = false;
    });
  }

  Future<void> _requestAll() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    final contacts = await Permission.contacts.request();
    final notifications = await Permission.notification.request();

    setState(() {
      _cameraGranted = camera.isGranted;
      _micGranted = mic.isGranted;
      _contactsGranted = contacts.isGranted;
      _notificationsGranted = notifications.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.shield_outlined, color: AppColors.primary, size: 56),
              const SizedBox(height: 24),
              const Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We need a few permissions to provide the best experience.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              _permissionTile(Icons.camera_alt, 'Camera', 'For video calls and photos', _cameraGranted),
              _permissionTile(Icons.mic, 'Microphone', 'For voice notes and calls', _micGranted),
              _permissionTile(Icons.contacts, 'Contacts', 'To find your friends', _contactsGranted),
              _permissionTile(Icons.notifications, 'Notifications', 'To notify you of messages', _notificationsGranted),
              const Spacer(),
              AppButton(
                label: 'Allow All',
                icon: Icons.check_circle_outline,
                onPressed: () => _requestAll().then((_) {
                  _finish();
                }),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Skip for now',
                type: AppButtonType.ghost,
                onPressed: _finish,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile(IconData icon, String title, String subtitle, bool granted) {
    return ListTile(
      leading: Icon(icon, color: granted ? AppColors.primary : AppColors.textTertiary, size: 24),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      trailing: Icon(
        granted ? Icons.check_circle : Icons.arrow_forward_ios,
        color: granted ? AppColors.success : AppColors.textTertiary,
        size: granted ? 24 : 16,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  void _finish() {
    context.go('/');
  }
}
