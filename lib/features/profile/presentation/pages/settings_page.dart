import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../native/device_info.dart';
import '../../../../shared/widgets/avatar_editor.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/ui/glass.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../providers/settings_providers.dart';

/// The full WhatsApp-style Settings page opened from the header avatar.
///
/// Covers identity (profile editing), account shortcuts, chat preferences,
/// storage & network usage (with explicit Wi-Fi/SIM permission prompts), a
/// cache control and the About/Help block.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final bool _savingAvatar = false;

  /// Opens the camera / gallery / remove sheet.
  ///
  /// The previous handler was gallery-only and began with an early
  /// if (!online) return;, so tapping the avatar with no connection
  /// produced no upload and no message at all.
  Future<void> _pickAvatar() => editAvatar(context, ref);

  Future<void> _editProfile() async {
    final async = ref.read(ownProfileProvider);
    final profile = async.valueOrNull;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileEditSheet(
        displayName: profile?.displayName ?? '',
        bio: profile?.bio ?? '',
        onSave: (name, bio) => ref
            .read(ownProfileProvider.notifier)
            .save(displayName: name, bio: bio),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).updatePresence('offline');
    } catch (_) {}
    // Route through the notifier so an explicit sign-out also clears any
    // offline-degraded suppression.
    await ref.read(authStateProvider.notifier).signOut();
    if (mounted) context.go('/welcome');
  }

  Future<void> _upgradeAccount() async {
    final online = ref.read(isOnlineProvider).valueOrNull ?? true;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to the internet to save your account.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UpgradeAccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ownProfileProvider);
    final profile = async.valueOrNull;
    final authUser = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: GlassAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(
            profile: profile,
            savingAvatar: _savingAvatar,
            onAvatarTap: _savingAvatar ? null : _pickAvatar,
            onEdit: _editProfile,
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Account'),
          if (authUser?.isGuest ?? false) ...[
            _SettingsTile(
              icon: Icons.enhanced_encryption_outlined,
              title: 'Save your account',
              subtitle: 'Upgrade the guest session with email & password',
              onTap: _upgradeAccount,
            ),
          ],
          const _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
            subtitle: 'Security, two-step verification, delete account',
            route: '/settings/account',
          ),
          const _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Last seen, profile photo, about, status',
            route: '/settings/privacy',
          ),
          const _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Message, group and call tones',
            route: '/settings/notifications',
          ),
          const _SettingsTile(
            icon: Icons.chat_outlined,
            title: 'Chats',
            subtitle: 'Theme, wallpaper, chat backup',
            route: '/settings/chats',
          ),
          const Divider(),
          const _SectionLabel('Quick access'),
          const _SettingsTile(
            icon: Icons.qr_code_2,
            title: 'My QR code & scan',
            subtitle: 'Share your number, scan contacts',
            route: '/qr-hub',
          ),
          const _SettingsTile(
            icon: Icons.person_add_alt,
            title: 'Find people',
            subtitle: 'Search by phone or scan a QR code',
            route: '/people',
          ),
          const _AppearanceSection(),
          const Divider(),
          const _SectionLabel('Storage & network'),
          const _SettingsTile(
            icon: Icons.storage_outlined,
            title: 'Storage and data',
            subtitle: 'Network usage, auto-download, media',
            route: '/settings/storage',
          ),
          const _StorageNetworkSection(),
          const Divider(),
          const _SectionLabel('Help'),
          const _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'Help centre, contact us, privacy policy',
            route: '/settings/help',
          ),
          const _AboutSection(),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.savingAvatar,
    required this.onAvatarTap,
    required this.onEdit,
  });

  final dynamic profile;
  final bool savingAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                children: [
                  // The whole avatar is now tappable, not just the 15px camera
                  // badge in the corner. A 30px hit target is below the
                  // accessible minimum, so the primary action was effectively
                  // unhittable for anyone with a tremor or a large finger.
                  GestureDetector(
                    onTap: onAvatarTap,
                    behavior: HitTestBehavior.opaque,
                    child: UserAvatar(profile: profile, radius: 44),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: onAvatarTap,
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 15,
                        foregroundColor: theme.colorScheme.onSurface,
                        child: savingAvatar
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera, size: 15),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      profile?.displayName?.isNotEmpty == true
                          ? profile!.displayName
                          : 'Your name',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (profile?.isVerified == true) ...[
                    const SizedBox(width: 6),
                    const VerifiedBadge(size: 14),
                  ],
                ],
              ),
              Text(
                profile?.phone ?? '',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (profile?.bio?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  profile!.bio,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              // WhatsApp-style account label: verified accounts sync across
              // all devices/OS; anonymous guests are single-device only.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: profile?.isVerified == true
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      profile?.isVerified == true
                          ? Icons.verified_rounded
                          : Icons.person_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile?.isVerified == true
                          ? 'Verified · syncs on all devices'
                          : 'Guest · add email for device sync',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to edit profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsTile extends ConsumerWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: onTap ?? (route == null ? null : () => context.push(route!)),
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Appearance'),
      subtitle: const Text('Follow system or choose a theme'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance',
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
                  onSelectionChanged: (selection) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setMode(selection.first);
                    // Persist + broadcast the theme as a synced setting so
                    // every device follows the same appearance.
                    ref
                        .read(settingsControllerProvider.notifier)
                        .set((s) => s.copyWith(theme: selection.first.name));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Storage & network: asks for Wi-Fi/SIM permission, then shows live network
/// facts (network name, operator, IP) plus a cache-clear control.
class _StorageNetworkSection extends ConsumerStatefulWidget {
  const _StorageNetworkSection();

  @override
  ConsumerState<_StorageNetworkSection> createState() =>
      _StorageNetworkSectionState();
}

class _StorageNetworkSectionState
    extends ConsumerState<_StorageNetworkSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.data_usage_outlined),
          title: const Text('Data usage'),
          subtitle: const Text('What this app has sent and received'),
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          onTap: () => context.push('/settings/storage/network'),
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(deviceInfoProvider).valueOrNull;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.smartphone_outlined),
          title: const Text('Device'),
          subtitle: Text(info?.fullName ?? 'Unknown device'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('App version'),
          subtitle: Text(
            info == null
                ? 'v1.0.0'
                : 'v${info.appVersion} (${info.buildNumber}) · '
                      '${info.platform} ${info.osVersion}',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Privacy'),
          subtitle: const Text('Phone-based identity — no usernames, ever'),
        ),
      ],
    );
  }
}

/// Editable name + bio used by the profile card. Keeps pushing updates to the
/// server via [ownProfileProvider].
class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet({
    required this.displayName,
    required this.bio,
    required this.onSave,
  });

  final String displayName;
  final String bio;
  final Future<void> Function(String name, String bio) onSave;

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.displayName);
    _bio = TextEditingController(text: widget.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_name.text.trim(), _bio.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that upgrades a guest (anonymous) session into a permanent
/// email/password account. Same user id is kept, so chats and the profile row
/// survive the transition.
class _UpgradeAccountSheet extends ConsumerStatefulWidget {
  const _UpgradeAccountSheet();

  @override
  ConsumerState<_UpgradeAccountSheet> createState() =>
      _UpgradeAccountSheetState();
}

class _UpgradeAccountSheetState extends ConsumerState<_UpgradeAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authStateProvider.notifier)
        .linkGuestAccount(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account saved — sign in on any device any time.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save your account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Keep your chats and number safe by upgrading the guest session '
              'to a permanent account. Sign in anywhere with this email and '
              'password — your history stays put.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty || !v.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'Password must be at least 6 characters.';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save account'),
            ),
          ],
        ),
      ),
    );
  }
}
