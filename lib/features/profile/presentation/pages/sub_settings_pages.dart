import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/security/app_lock.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/user_settings.dart';
import '../providers/settings_providers.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Account sub-screen  (WhatsApp → Settings → Account)
/// ─────────────────────────────────────────────────────────────────────────────
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(ownProfileProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          SectionHeader('Security'),
          ListTile(
            leading: Icon(Icons.fingerprint, color: theme.colorScheme.primary),
            title: const Text('App lock'),
            subtitle: const Text('Require fingerprint or Face ID to open app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAppLockDialog(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
            title: const Text('Two-step verification'),
            subtitle: const Text('Add a PIN for extra security'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/account/two-step'),
          ),
          const Divider(),
          SectionHeader('Account info'),
          ListTile(
            leading: Icon(
              Icons.person_outline,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Personal info'),
            subtitle: Text(
              '${profile?.displayName ?? "Your name"} · ${profile?.phone ?? "Your phone"}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
          ListTile(
            leading: Icon(
              Icons.email_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Email'),
            subtitle: Text(
              (authUser?.email ?? '').isNotEmpty
                  ? authUser!.email
                  : 'Add email to enable device sync',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEmailDialog(context, ref),
          ),
          ListTile(
            leading: Icon(
              Icons.phone_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Phone number'),
            subtitle: Text(
              (profile?.phone ?? '').isNotEmpty
                  ? profile!.phone
                  : 'Update your phone number',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup'),
          ),
          const Divider(),
          SectionHeader('Devices'),
          ListTile(
            leading: Icon(
              Icons.devices_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Linked devices'),
            subtitle: const Text('Manage where you\'re logged in'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/account/devices'),
          ),
          const Divider(),
          SectionHeader('Danger zone'),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Delete my account',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: const Text(
              'Permanently remove your account and all data',
            ),
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAppLockDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsControllerProvider.notifier);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'App Lock',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                secondary: Icon(
                  Icons.fingerprint,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Require biometric to open'),
                subtitle: const Text('Use fingerprint or Face ID'),
                value: settings.appLockEnabled,
                onChanged: (v) =>
                    notifier.set((s) => s.copyWith(appLockEnabled: v)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.timer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Auto-lock timer'),
                // Reflects the saved choice. This was a const 'Immediately', so
                // the row kept claiming the strictest setting no matter what the
                // user had actually picked two taps above.
                subtitle: Text(_appLockTimerLabel(settings.appLockTimer)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAutoLockTimerDialog(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAutoLockTimerDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsControllerProvider.notifier);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto-lock timer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              for (final option in const [
                ('immediate', 'Immediately', 0),
                ('1min', 'After 1 minute', 60),
                ('5min', 'After 5 minutes', 300),
                ('15min', 'After 15 minutes', 900),
                ('1hour', 'After 1 hour', 3600),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    settings.appLockTimer == option.$1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(option.$2),
                  onTap: () {
                    notifier.set((s) => s.copyWith(appLockTimer: option.$1));
                    // The lock reads this, not the setting above. Without this
                    // bridge the choice was saved and never applied.
                    ref
                        .read(appLockControllerProvider)
                        .setGraceSeconds(option.$3);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailDialog(BuildContext context, WidgetRef ref) {
    final authUser = ref.read(authStateProvider).user;
    final emailController = TextEditingController(text: authUser?.email ?? '');

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Email address'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                try {
                  await ref
                      .read(authRepositoryProvider)
                      .linkGuestAccount(
                        email: email,
                        password:
                            'temp_password_will_be_set', // User will set via reset flow
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update email: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your Crystal Messenger account and all your data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authRepositoryProvider).deleteAccount();
                if (context.mounted) context.go('/welcome');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Privacy sub-screen  (WhatsApp → Settings → Privacy)
/// ─────────────────────────────────────────────────────────────────────────────
class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          const SectionHeader('Who can see my info'),
          _ChoiceTile(
            theme: theme,
            icon: Icons.access_time,
            title: 'Last seen & online',
            value: _visibilityLabel(settings.lastSeenVisibility),
            onTap: () => _pickVisibility(
              context: context,
              title: 'Last seen & online',
              value: settings.lastSeenVisibility,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(lastSeenVisibility: v)),
            ),
          ),
          _ChoiceTile(
            theme: theme,
            icon: Icons.photo_outlined,
            title: 'Profile photo',
            value: _visibilityLabel(settings.profilePhotoVisibility),
            onTap: () => _pickVisibility(
              context: context,
              title: 'Profile photo',
              value: settings.profilePhotoVisibility,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(profilePhotoVisibility: v)),
            ),
          ),
          _ChoiceTile(
            theme: theme,
            icon: Icons.info_outline,
            title: 'About',
            value: _visibilityLabel(settings.profilePhotoVisibility),
            onTap: () => _pickVisibility(
              context: context,
              title: 'About',
              value: settings.profilePhotoVisibility,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(profilePhotoVisibility: v)),
            ),
          ),
          _ChoiceTile(
            theme: theme,
            icon: Icons.circle_outlined,
            title: 'Status',
            value: _visibilityLabel(settings.statusVisibility),
            onTap: () => _pickVisibility(
              context: context,
              title: 'Status',
              value: settings.statusVisibility,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(statusVisibility: v)),
            ),
          ),
          const Divider(),
          const SectionHeader('Messaging'),
          _ChoiceTile(
            theme: theme,
            icon: Icons.group_outlined,
            title: 'Groups',
            value: _groupsPrivacyLabel(settings.groupsPrivacy),
            onTap: () =>
                _pickGroupsPrivacy(context, notifier, settings.groupsPrivacy),
          ),
          _ChoiceTile(
            theme: theme,
            icon: Icons.live_tv_outlined,
            title: 'Channels',
            value: _visibilityLabel(settings.channelsPrivacy),
            onTap: () => _pickVisibility(
              context: context,
              title: 'Channels',
              value: settings.channelsPrivacy,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(channelsPrivacy: v)),
            ),
          ),
          const Divider(),
          const SectionHeader('Disappearing messages'),
          _ChoiceTile(
            theme: theme,
            icon: Icons.timer_outlined,
            title: 'Default message timer',
            value: _disappearingLabel(settings.disappearingMessagesTimer),
            onTap: () => _pickDisappearingTimer(
              context,
              notifier,
              settings.disappearingMessagesTimer,
            ),
          ),
          const Divider(),
          const SectionHeader('Advanced'),
          SwitchListTile(
            secondary: Icon(
              Icons.fingerprint,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Fingerprint lock'),
            subtitle: const Text('Lock Crystal Messenger with fingerprint'),
            value: settings.fingerprintLock,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(fingerprintLock: v)),
          ),
          SwitchListTile(
            secondary: Icon(
              Icons.screen_share_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Incognito keyboard'),
            subtitle: const Text('Keyboard won\'t learn from your messages'),
            value: settings.incognitoKeyboard,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(incognitoKeyboard: v)),
          ),
        ],
      ),
    );
  }
}

String _groupsPrivacyLabel(String value) {
  switch (value) {
    case 'contacts':
      return 'My contacts';
    case 'contacts_except':
      return 'My contacts except…';
    default:
      return 'Everyone';
  }
}

String _disappearingLabel(String value) {
  switch (value) {
    case '24h':
      return '24 hours';
    case '7d':
      return '7 days';
    case '90d':
      return '90 days';
    default:
      return 'Off';
  }
}

Future<void> _pickGroupsPrivacy(
  BuildContext context,
  SettingsController notifier,
  String currentValue,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Who can add me to groups',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            for (final option in const [
              ('everyone', 'Everyone'),
              ('contacts', 'My contacts'),
              ('contacts_except', 'My contacts except…'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  currentValue == option.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                title: Text(option.$2),
                onTap: () {
                  notifier.set((s) => s.copyWith(groupsPrivacy: option.$1));
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickDisappearingTimer(
  BuildContext context,
  SettingsController notifier,
  String currentValue,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default message timer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            for (final option in const [
              ('off', 'Off'),
              ('24h', '24 hours'),
              ('7d', '7 days'),
              ('90d', '90 days'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  currentValue == option.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                title: Text(option.$2),
                onTap: () {
                  notifier.set(
                    (s) => s.copyWith(disappearingMessagesTimer: option.$1),
                  );
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickVisibility({
  required BuildContext context,
  required String title,
  required String value,
  required ValueChanged<String> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            for (final option in const [
              ('everyone', 'Everyone'),
              ('contacts', 'My contacts'),
              ('nobody', 'Nobody'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  value == option.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                title: Text(option.$2),
                onTap: () {
                  onChanged(option.$1);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

String _visibilityLabel(String value) {
  switch (value) {
    case 'contacts':
      return 'My contacts';
    case 'nobody':
      return 'Nobody';
    default:
      return 'Everyone';
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.theme,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });
  final ThemeData theme;
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.outline,
            ),
      onTap: onTap,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Notifications sub-screen (toggles persisted + synced across devices)
/// ─────────────────────────────────────────────────────────────────────────────
class NotificationsSettingsPage extends ConsumerWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          const SectionHeader('Messages'),
          SwitchListTile(
            secondary: const Icon(Icons.message_outlined),
            title: const Text('Message notifications'),
            value: settings.messageNotifications,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(messageNotifications: v)),
          ),
          if (settings.messageNotifications) ...[
            SwitchListTile(
              secondary: const Icon(Icons.preview_outlined),
              title: const Text('Show previews'),
              value: settings.showPreviews,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(showPreviews: v)),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Vibrate'),
              value: settings.vibrate,
              onChanged: (v) => notifier.set((s) => s.copyWith(vibrate: v)),
            ),
          ],
          const Divider(),
          const SectionHeader('Groups'),
          SwitchListTile(
            secondary: const Icon(Icons.group_outlined),
            title: const Text('Group notifications'),
            value: settings.groupNotifications,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(groupNotifications: v)),
          ),
          const Divider(),
          const SectionHeader('Updates'),
          SwitchListTile(
            secondary: const Icon(Icons.update_outlined),
            title: const Text('Status updates'),
            value: settings.updatesNotifications,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(updatesNotifications: v)),
          ),
          const Divider(),
          const SectionHeader('Calls'),
          SwitchListTile(
            secondary: const Icon(Icons.call_outlined),
            title: const Text('Call ringtone'),
            value: settings.callRingtone,
            onChanged: (v) => notifier.set((s) => s.copyWith(callRingtone: v)),
          ),
          const Divider(),
          const SectionHeader('Other'),
          SwitchListTile(
            secondary: const Icon(Icons.light_mode_outlined),
            title: const Text('In-app notification light'),
            value: settings.inAppLight,
            onChanged: (v) => notifier.set((s) => s.copyWith(inAppLight: v)),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Chats sub-screen
/// ─────────────────────────────────────────────────────────────────────────────
class ChatsSettingsPage extends ConsumerStatefulWidget {
  const ChatsSettingsPage({super.key});
  @override
  ConsumerState<ChatsSettingsPage> createState() => _ChatsSettingsPageState();
}

class _ChatsSettingsPageState extends ConsumerState<ChatsSettingsPage> {
  void _pickChatWallpaper(
    BuildContext context,
    SettingsController notifier,
    String current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Chat Wallpaper',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String>(
              title: const Text('Default (Original UI)'),
              value: 'default',
              // ignore: deprecated_member_use
              groupValue: current,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) {
                  notifier.set((s) => s.copyWith(chatWallpaper: v));
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Custom Anime Wallpaper (Gojo)'),
              value: 'gojo',
              // ignore: deprecated_member_use
              groupValue: current,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) {
                  notifier.set((s) => s.copyWith(chatWallpaper: v));
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Pure Black Wallpaper'),
              value: 'black',
              // ignore: deprecated_member_use
              groupValue: current,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) {
                  notifier.set((s) => s.copyWith(chatWallpaper: v));
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final notifier = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView(
        children: [
          const SectionHeader('Display'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              mode == ThemeMode.dark
                  ? 'Dark'
                  : mode == ThemeMode.light
                  ? 'Light'
                  : 'System default',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref, notifier),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Font size'),
            subtitle: Text(_fontSizeLabel(settings.fontSize)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickFontSize(context, notifier, settings.fontSize),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('Chat wallpaper'),
            subtitle: Text(
              settings.chatWallpaper == 'gojo'
                  ? 'Custom Anime Wallpaper (Gojo)'
                  : settings.chatWallpaper == 'black'
                  ? 'Pure Black Wallpaper'
                  : 'Default (Original UI)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _pickChatWallpaper(context, notifier, settings.chatWallpaper),
          ),
          const Divider(),
          const SectionHeader('Behaviour'),
          SwitchListTile(
            secondary: const Icon(Icons.done_all),
            title: const Text('Read receipts'),
            subtitle: const Text(
              'If turned off, you won\'t send or see receipts',
            ),
            value: settings.readReceipts,
            onChanged: (v) => notifier.set((s) => s.copyWith(readReceipts: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.send_outlined),
            title: const Text('Enter to send'),
            value: settings.enterToSend,
            onChanged: (v) => notifier.set((s) => s.copyWith(enterToSend: v)),
          ),
          const Divider(),
          const SectionHeader('Media'),
          SwitchListTile(
            secondary: const Icon(Icons.download_outlined),
            title: const Text('Auto-download media'),
            value: settings.mediaAutoDownload,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(mediaAutoDownload: v)),
          ),
          const Divider(),
          const SectionHeader('Backup'),
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('Chat backup'),
            subtitle: const Text('Back up to Google Drive'),
            value: settings.chatBackup,
            onChanged: (v) => notifier.set((s) => s.copyWith(chatBackup: v)),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Back up now · Coming soon'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _pickTheme(
    BuildContext context,
    WidgetRef ref,
    SettingsController notifier,
  ) {
    final mode = ref.read(themeModeProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) {
                  final next = s.first;
                  // Theme is a synced setting too — other devices follow.
                  notifier.set((set) => set.copyWith(theme: next.name));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fontSizeLabel(String value) {
    switch (value) {
      case 'small':
        return 'Small';
      case 'large':
        return 'Large';
      default:
        return 'Medium';
    }
  }

  void _pickFontSize(
    BuildContext context,
    SettingsController notifier,
    String currentValue,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Font size',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              for (final option in const [
                ('small', 'Small'),
                ('medium', 'Medium'),
                ('large', 'Large'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    currentValue == option.$1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  ),
                  title: Text(option.$2),
                  onTap: () {
                    notifier.set((s) => s.copyWith(fontSize: option.$1));
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Storage & Data sub-screen
/// ─────────────────────────────────────────────────────────────────────────────
class StorageDataSettingsPage extends ConsumerWidget {
  const StorageDataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage and data')),
      body: ListView(
        children: [
          const SectionHeader('On this device'),
          ListTile(
            leading: Icon(
              Icons.cleaning_services_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Manage storage'),
            subtitle: const Text(
              'See what media is cached, and clear cache or chat history',
            ),
            trailing: const Icon(Icons.chevron_right),
            // This route existed and was never pushed from anywhere, so the
            // whole screen - the only place that shows cache size or offers to
            // clear it - was unreachable.
            onTap: () => context.push('/settings/storage/manage'),
          ),
          ListTile(
            leading: Icon(
              Icons.data_usage_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Network usage'),
            subtitle: const Text('View data used by Crystal Messenger'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/storage/network'),
          ),
          const Divider(),
          const SectionHeader('Media auto-download'),
          _MediaTile(
            theme: theme,
            label: 'Using mobile data',
            settings: settings,
            notifier: notifier,
            connectionType: 'mobile',
          ),
          _MediaTile(
            theme: theme,
            label: 'Using Wi-Fi',
            settings: settings,
            notifier: notifier,
            connectionType: 'wifi',
          ),
          _MediaTile(
            theme: theme,
            label: 'When roaming',
            settings: settings,
            notifier: notifier,
            connectionType: 'roaming',
          ),
          const Divider(),
          const SectionHeader('Calls'),
          SwitchListTile(
            secondary: Icon(
              Icons.hd_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Use less data for calls'),
            subtitle: const Text('Reduce call quality to save data'),
            value: settings.useLessDataForCalls,
            onChanged: (v) =>
                notifier.set((s) => s.copyWith(useLessDataForCalls: v)),
          ),
          SwitchListTile(
            secondary: Icon(
              Icons.wifi_calling_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Wi-Fi calling'),
            subtitle: const Text('Make calls over Wi-Fi when available'),
            value: settings.wifiCalling,
            onChanged: (v) => notifier.set((s) => s.copyWith(wifiCalling: v)),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends ConsumerWidget {
  const _MediaTile({
    required this.theme,
    required this.label,
    required this.settings,
    required this.notifier,
    required this.connectionType,
  });

  final ThemeData theme;
  final String label;
  final AppUserSettings settings;
  final SettingsController notifier;
  final String connectionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = connectionType == 'mobile'
        ? 'mobile_data_auto_download'
        : connectionType == 'wifi'
        ? 'wifi_auto_download'
        : 'roaming_auto_download';

    final enabled = key == 'mobile_data_auto_download'
        ? settings.mobileDataAutoDownload
        : key == 'wifi_auto_download'
        ? settings.wifiAutoDownload
        : settings.roamingAutoDownload;

    return ListTile(
      title: Text(label),
      subtitle: Text(
        'Photos, audio, videos, documents',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (v) {
          if (key == 'mobile_data_auto_download') {
            notifier.set((s) => s.copyWith(mobileDataAutoDownload: v));
          } else if (key == 'wifi_auto_download') {
            notifier.set((s) => s.copyWith(wifiAutoDownload: v));
          } else {
            notifier.set((s) => s.copyWith(roamingAutoDownload: v));
          }
        },
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Help sub-screen
/// ─────────────────────────────────────────────────────────────────────────────
class HelpSettingsPage extends StatelessWidget {
  const HelpSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        children: [
          const SectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Centre'),
            subtitle: const Text('FAQs, guides, and troubleshooting'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openUrl('https://crystalmessenger.com/help'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Contact us'),
            subtitle: const Text('Report a problem or send feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openEmail(context),
          ),
          const Divider(),
          const SectionHeader('Legal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            subtitle: const Text('How we collect and use your data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openUrl('https://crystalmessenger.com/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of service'),
            subtitle: const Text('Terms and conditions of use'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openUrl('https://crystalmessenger.com/terms'),
          ),
          const Divider(),
          const SectionHeader('App info'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App info'),
            subtitle: const Text('Crystal Messenger v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Crystal Messenger',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Crystal Messenger',
              );
            },
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:support@crystalmessenger.com');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact: support@crystalmessenger.com')),
      );
    }
  }
}

/// Human-readable form of the stored `appLockTimer` value.
///
/// Unknown or unset values resolve to the strictest setting, which is the safe
/// direction to fail: the user asked for a lock, so an unrecognised value
/// should keep the app locked rather than quietly stop asking.
String _appLockTimerLabel(String value) => switch (value) {
  '1min' => 'After 1 minute',
  '5min' => 'After 5 minutes',
  '15min' => 'After 15 minutes',
  '1hour' => 'After 1 hour',
  _ => 'Immediately',
};
