import 'package:crystal_messenger/core/platform/data_usage.dart';
import 'package:crystal_messenger/shared/models/user_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/ui/glass.dart';

import '../../../../core/media/media_providers.dart';
import '../../../../core/media/media_transfer_service.dart';
import '../../../../core/network/supabase_providers.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/conversations/presentation/providers/chat_providers.dart';
import '../providers/settings_providers.dart';
import 'sub_settings_pages.dart' show SectionHeader;

/// Two-step verification settings page
class TwoStepVerificationPage extends ConsumerWidget {
  const TwoStepVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: GlassAppBar(title: 'Two-step verification'),
      body: ListView(
        children: [
          const SectionHeader('Security'),
          ListTile(
            leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
            title: const Text('Two-step verification'),
            subtitle: Text(settings.twoStepEnabled ? 'Enabled' : 'Disabled'),
            trailing: Switch(
              value: settings.twoStepEnabled,
              onChanged: (v) =>
                  notifier.set((s) => s.copyWith(twoStepEnabled: v)),
            ),
          ),
          if (settings.twoStepEnabled) ...[
            ListTile(
              leading: Icon(
                Icons.email_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Recovery email'),
              subtitle: Text(settings.recoveryEmail ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRecoveryEmailDialog(
                context,
                notifier,
                settings.recoveryEmail,
              ),
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: theme.colorScheme.primary),
              title: const Text('Change PIN'),
              subtitle: const Text('Update your 6-digit PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePinDialog(context, notifier),
            ),
          ],
          const Divider(),
          const SectionHeader('About'),
          ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: const Text('What is two-step verification?'),
            subtitle: const Text(
              'Adds an extra layer of security to your account',
            ),
            onTap: () => _showInfoDialog(context),
          ),
        ],
      ),
    );
  }

  void _showRecoveryEmailDialog(
    BuildContext context,
    SettingsController notifier,
    String? currentEmail,
  ) {
    final controller = TextEditingController(text: currentEmail ?? '');
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recovery email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
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
            onPressed: () {
              final email = controller.text.trim();
              if (email.isEmpty || email.contains('@')) {
                notifier.set(
                  (s) =>
                      s.copyWith(recoveryEmail: email.isEmpty ? null : email),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, SettingsController notifier) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New PIN (6 digits)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (newController.text == confirmController.text &&
                  newController.text.length == 6) {
                notifier.set((s) => s.copyWith(twoStepPin: newController.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('PIN changed')));
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About two-step verification'),
        content: const Text(
          'Two-step verification adds an extra layer of security by requiring a 6-digit PIN '
          'when registering your phone number with Crystal Messenger again.\n\n'
          'You\'ll also need to provide a recovery email to reset your PIN if you forget it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Linked devices management page
class LinkedDevicesPage extends ConsumerWidget {
  const LinkedDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devicesAsync = ref.watch(userDevicesProvider);

    return Scaffold(
      appBar: GlassAppBar(title: 'Linked devices'),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading devices: $e')),
        data: (devices) {
          return ListView(
            children: [
              const SectionHeader('Current device'),
              ...devices
                  .where((d) => d.isCurrentDevice)
                  .map(
                    (device) => _DeviceTile(
                      device: device,
                      isCurrent: true,
                      onLogout: () => _logoutDevice(context, ref, device.id),
                    ),
                  ),
              if (devices.where((d) => !d.isCurrentDevice).isNotEmpty) ...[
                const Divider(),
                const SectionHeader('Other devices'),
                ...devices
                    .where((d) => !d.isCurrentDevice)
                    .map(
                      (device) => _DeviceTile(
                        device: device,
                        isCurrent: false,
                        onLogout: () => _logoutDevice(context, ref, device.id),
                      ),
                    ),
              ] else ...[
                const Divider(),
                const SectionHeader('Other devices'),
                const ListTile(
                  leading: Icon(Icons.desktop_windows_outlined),
                  title: Text('No other devices linked'),
                  subtitle: Text(
                    'Link devices by scanning QR code from Settings',
                  ),
                ),
              ],
              const Divider(),
              const SectionHeader('Security'),
              SwitchListTile(
                secondary: Icon(
                  Icons.notifications,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Notify on new login'),
                subtitle: const Text(
                  'Get notified when a new device links to your account',
                ),
                value: true,
                onChanged: (_) {},
              ),
              ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: const Text(
                  'Log out of all devices',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: const Text(
                  'This will log you out everywhere except this device',
                ),
                onTap: () => _confirmLogoutAll(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmLogoutAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out of all devices?'),
        content: const Text(
          'You will be logged out of all other devices. This device will stay logged in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out of all other devices'),
                ),
              );
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutDevice(
    BuildContext context,
    WidgetRef ref,
    String deviceId,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('devices').delete().eq('id', deviceId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device logged out')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to logout device: $e')));
      }
    }
  }
}

/// Manage storage page
class ManageStoragePage extends ConsumerStatefulWidget {
  const ManageStoragePage({super.key});

  @override
  ConsumerState<ManageStoragePage> createState() => _ManageStoragePageState();
}

class _ManageStoragePageState extends ConsumerState<ManageStoragePage> {
  bool _loading = false;
  int _cacheBytes = 0;

  /// Per-conversation media totals, biggest first.
  List<({String conversationId, int bytes, int fileCount})> _perChat = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Human name for a conversation id, from the local cache.
  ///
  /// Falls back to a shortened id rather than an empty row, so an orphaned entry
  /// is still identifiable rather than looking like an empty label.
  String _titleFor(String conversationId) {
    final title = _titles[conversationId];
    if (title != null && title.isNotEmpty) return title;
    return conversationId.length <= 8
        ? conversationId
        : '${conversationId.substring(0, 8)}…';
  }

  Map<String, String> _titles = {};

  /// Clears one conversation's cached media and its cached messages.
  ///
  /// Local only, and explicitly labelled as such: the messages remain on the
  /// server and re-sync if the chat is opened again. Use "Delete messages for
  /// everyone" in the chat menu to remove them server-side.
  Future<void> _clearChatMedia(String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear this chat on this device?'),
        content: const Text(
          'Removes its cached messages and downloaded media. The conversation '
          'stays, and everything comes back if you open it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      // Order matters. The stored manifests are the only link between a file
      // on disk and the chat that downloaded it, so the names have to be read
      // BEFORE the rows go. The previous version deleted the rows and nothing
      // else: every file stayed on disk while the dialog above promised the
      // media would be removed, so the storage figures never went down and the
      // user was told something that did not happen.
      final store = ref.read(localStoreProvider);
      final owned = await store.mediaFilesForConversation(conversationId);

      // A file forwarded into another chat is stored once and referenced twice.
      // Deleting it here would break the surviving chat's playback until it was
      // re-downloaded, so only delete files this conversation solely owns.
      final solelyOwned = owned.fileNames
          .where((name) => (owned.referenceCounts[name] ?? 0) <= 1)
          .toSet();

      var freed = 0;
      try {
        final service = await ref.read(mediaTransferServiceProvider.future);
        freed = await service.deleteLocalFiles(solelyOwned);
      } catch (_) {
        // The rows still get cleared even if the bytes do not: leaving the
        // conversation cached to protect against a failed file delete would be
        // the worse outcome.
      }

      await store.deleteConversationLocally(conversationId);
      await _loadStats();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              freed > 0
                  ? 'Cleared on this device · freed ${_formatBytes(freed)}'
                  : 'Cleared on this device',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not clear: $e')));
    }
  }

  Future<void> _loadStats() async {
    try {
      final service = await ref.read(mediaTransferServiceProvider.future);
      final bytes = await service.localCacheBytes();
      final store = ref.read(localStoreProvider);
      final perChat = await store.mediaBytesByConversation();
      final conversations = await store.cachedConversations();
      if (!mounted) return;
      setState(() {
        _cacheBytes = bytes;
        _perChat = perChat;
        _titles = {for (final c in conversations) c.id: c.title};
      });
    } catch (_) {}
  }

  Future<void> _clearMediaCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear media cache?'),
        content: const Text(
          'This will delete all cached photos, videos, voice notes, and documents from device storage. They can be re-downloaded from chats anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final service = await ref.read(mediaTransferServiceProvider.future);
      await service.clearLocalCache();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media cache cleared successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to clear cache: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAllChatData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all local chat data?'),
        content: const Text(
          'This will delete all local messages, conversations, and outbox entries from device storage, freeing all local space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final store = ref.read(localStoreProvider);
      final chats = await store.cachedConversations();
      for (final chat in chats) {
        await store.deleteConversationLocally(chat.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local chat storage cleared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear chat storage: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GlassAppBar(title: 'Manage storage'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SectionHeader('Storage overview'),
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Media cache used',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _formatBytes(_cacheBytes),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Scaled against the budget that is actually
                        // enforced (`MediaTransferService.localCacheBudgetBytes`,
                        // 512 MiB). This was hardcoded to 1 GiB, so a full cache
                        // rendered as 50% and never looked like a problem.
                        LinearProgressIndicator(
                          value:
                              (_cacheBytes /
                                      MediaTransferService
                                          .localCacheBudgetBytes)
                                  .clamp(0.0, 1.0),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Limit ${_formatBytes(MediaTransferService.localCacheBudgetBytes)} '
                          '· oldest media is removed first',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                if (_perChat.isNotEmpty) ...[
                  const SectionHeader('Media in each chat'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Counted from the attachments in each conversation. '
                      'Clearing one removes its cached media on this device '
                      'only - the messages stay on the server.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final entry in _perChat)
                    ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(_titleFor(entry.conversationId)),
                      subtitle: Text(
                        '${entry.fileCount} file${entry.fileCount == 1 ? '' : 's'}',
                      ),
                      trailing: Text(
                        formatBytes(entry.bytes),
                        style: theme.textTheme.bodyMedium,
                      ),
                      onTap: () => _clearChatMedia(entry.conversationId),
                    ),
                  const Divider(),
                ],
                const SectionHeader('Device storage management'),
                ListTile(
                  leading: Icon(
                    Icons.cleaning_services,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Clear media cache'),
                  subtitle: const Text(
                    'Free device storage by removing cached photos, videos & audio',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearMediaCache,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: const Text('Clear all local chat history'),
                  subtitle: const Text(
                    'Delete all cached messages and conversations locally',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearAllChatData,
                ),
              ],
            ),
    );
  }
}

/// Network usage page
/// Network usage.
///
/// Every number here comes from Android's own per-app counters via
/// [DataUsage]. The previous version of this screen rendered hardcoded strings
/// ("1.8 GB", "200 MB messages") and two switches wired to an empty
/// `onChanged`, so it reported figures that never described the user's device.
///
/// There is no per-category breakdown, because none is available without
/// `PACKAGE_USAGE_STATS`. The screen says so rather than inventing a split.
class NetworkUsagePage extends ConsumerStatefulWidget {
  const NetworkUsagePage({super.key});

  @override
  ConsumerState<NetworkUsagePage> createState() => _NetworkUsagePageState();
}

class _NetworkUsagePageState extends ConsumerState<NetworkUsagePage> {
  DataUsage? _usage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final usage = await DataUsage.read();
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: GlassAppBar(title: 'Data usage'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SectionHeader('Data used by Crystal Messenger'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _usage == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Not available on this device.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            _DataRow(
                              label: 'Downloaded',
                              value: formatBytes(_usage!.rxBytes),
                              icon: Icons.download,
                            ),
                            const Divider(),
                            _DataRow(
                              label: 'Uploaded',
                              value: formatBytes(_usage!.txBytes),
                              icon: Icons.upload,
                            ),
                            const Divider(),
                            _DataRow(
                              label: 'Total',
                              value: formatBytes(_usage!.totalBytes),
                              isTotal: true,
                            ),
                          ],
                        ),
                ),
              ),
            ),
            // The per-purpose breakdown Android does allow, without the
            // PACKAGE_USAGE_STATS permission: what is actually occupying this
            // device's storage, split by conversation. The counters above are
            // lifetime totals and cannot be attributed to anything; these are
            // measured from the real files on disk right now.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: SectionHeader('Stored on this device, by chat'),
            ),
            const _PerChatStorageList(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Counts everything this app has sent and received since it was '
                'installed: messages, photos, videos, voice notes and avatars. '
                'Android does not expose a per-category split without a special '
                'permission this app does not request, so it is not broken down '
                'here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const Divider(height: 28),
            const SectionHeader('Media downloads'),
            _MediaDownloadTile(
              icon: Icons.download,
              title: 'Auto-download photos and videos',
              subtitle:
                  'Received media is fetched as soon as you open the chat',
              read: (s) => s.mediaAutoDownload,
              write: (s, v) => s.copyWith(mediaAutoDownload: v),
            ),
            _MediaDownloadTile(
              icon: Icons.signal_cellular_alt,
              title: 'Also download on mobile data',
              subtitle:
                  'When off, large files wait until you are on Wi-Fi. Tapping '
                  'one still downloads it immediately.',
              read: (s) => s.mobileDataAutoDownload,
              write: (s, v) => s.copyWith(mobileDataAutoDownload: v),
              dependsOn: (s) => s.mediaAutoDownload,
            ),
            const _CompressionQualityTile(),
          ],
        ),
      ),
    );
  }
}

/// Picks how hard outgoing photos are shrunk before they are uploaded.
///
/// A real choice rather than a switch, because the right answer differs: on a
/// metered connection Data Saver is worth visible quality, while someone
/// sending design references genuinely needs the original pixels. The default
/// (Balanced) is the conservative middle.
class _CompressionQualityTile extends ConsumerWidget {
  const _CompressionQualityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ??
        AppUserSettings.defaults;
    final current = settings.mediaCompressionQuality;

    const options = [
      (
        value: 'original',
        title: 'Original',
        subtitle:
            'Send photos exactly as they are. Slowest, but no quality loss.',
      ),
      (
        value: 'balanced',
        title: 'Balanced',
        subtitle: 'Shrink large photos. Recommended.',
      ),
      (
        value: 'dataSaver',
        title: 'Data Saver',
        subtitle: 'Shrink photos harder to use less mobile data.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.compress, color: theme.colorScheme.primary),
          title: const Text('Photo compression'),
          subtitle: Text(
            options
                .firstWhere((o) => o.value == current, orElse: () => options[1])
                .title,
          ),
        ),
        const SizedBox(height: 4),
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) {
            if (v == null) return;
            ref
                .read(settingsControllerProvider.notifier)
                .set((s) => s.copyWith(mediaCompressionQuality: v));
          },
          child: Column(
            children: [
              for (final option in options)
                RadioListTile<String>(
                  value: option.value,
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Photos only. Videos, voice notes and documents are always sent '
            'unchanged - recompressing them costs battery and usually makes them '
            'bigger.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// A switch backed by a real, persisted setting.
///
/// The previous page had `onChanged: (_) {}`, so the switch moved and nothing
/// changed anywhere. These write through [settingsControllerProvider], the same
/// store every other setting uses, so the value survives a restart and reaches
/// the server.
class _MediaDownloadTile extends ConsumerWidget {
  const _MediaDownloadTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.read,
    required this.write,
    this.dependsOn,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool Function(AppUserSettings s) read;
  final AppUserSettings Function(AppUserSettings s, bool v) write;

  /// When supplied, this switch is disabled and visually subordinate unless it
  /// is also on — the two are meaningless without each other.
  final bool Function(AppUserSettings s)? dependsOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final enabled = settings != null && read(settings);
    final parentOn =
        dependsOn == null || (settings != null && dependsOn!(settings));

    return SwitchListTile(
      secondary: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        parentOn ? subtitle : 'Turn on the setting above to change this.',
      ),
      value: enabled,
      onChanged: parentOn
          ? (next) => ref
                .read(settingsControllerProvider.notifier)
                .set((s) => write(s, next))
          : null,
    );
  }
}

/// Live per-chat media footprint, measured from the real files on disk.
///
/// The lifetime counters above cannot be attributed to anything, so this is the
/// honest per-purpose answer: which conversations are occupying this device,
/// and how much. Every value comes from summing the cached manifests, not from
/// an estimate.
class _PerChatStorageList extends ConsumerStatefulWidget {
  const _PerChatStorageList();

  @override
  ConsumerState<_PerChatStorageList> createState() =>
      _PerChatStorageListState();
}

class _PerChatStorageListState extends ConsumerState<_PerChatStorageList> {
  List<({String conversationId, int bytes, int fileCount})> _perChat = const [];
  Map<String, String> _titles = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(localStoreProvider);
      final perChat = await store.mediaBytesByConversation();
      final conversations = await store.cachedConversations();
      if (!mounted) return;
      setState(() {
        _perChat = perChat;
        _titles = {for (final c in conversations) c.id: c.title};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final entries =
        List<({String conversationId, int bytes, int fileCount})>.of(_perChat)
          ..sort((a, b) => b.bytes.compareTo(a.bytes));
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          'No media cached yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < entries.length && i < 8; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_outlined, size: 20),
                title: Text(
                  _titles[entries[i].conversationId] ?? 'Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${entries[i].fileCount} '
                  '${entries[i].fileCount == 1 ? 'file' : 'files'}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Text(formatBytes(entries[i].bytes)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.icon,
    this.isTotal = false,
  });
  final String label;
  final String value;
  final IconData? icon;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
          ] else
            const SizedBox(width: 34),
          Expanded(
            child: Text(
              label,
              style: isTotal
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: isTotal
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Provider to fetch all devices for the current user
final userDevicesProvider = FutureProvider<List<UserDevice>>((ref) async {
  final user = ref.watch(authStateProvider).user;
  if (user == null) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final rows = await supabase
      .from('devices')
      .select()
      .eq('user_id', user.id)
      .order('is_current_device', ascending: false)
      .order('last_seen_at', ascending: false);

  return rows
      .map((r) => UserDevice.fromJson(Map<String, dynamic>.from(r)))
      .toList();
});

/// User device model from the devices table
class UserDevice {
  const UserDevice({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.pushToken,
    required this.status,
    required this.deviceModel,
    required this.deviceOs,
    required this.deviceManufacturer,
    required this.deviceIp,
    required this.deviceLocale,
    required this.appVersion,
    required this.isCurrentDevice,
    required this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      pushToken: json['push_token'] as String?,
      status: json['status'] as String? ?? 'active',
      deviceModel: json['device_model'] as String?,
      deviceOs: json['device_os'] as String?,
      deviceManufacturer: json['device_manufacturer'] as String?,
      deviceIp: json['device_ip'] as String?,
      deviceLocale: json['device_locale'] as String?,
      appVersion: json['app_version'] as String?,
      isCurrentDevice: json['is_current_device'] as bool? ?? false,
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  final String id;
  final String userId;
  final String deviceId;
  final String platform;
  final String deviceName;
  final String? pushToken;
  final String status;
  final String? deviceModel;
  final String? deviceOs;
  final String? deviceManufacturer;
  final String? deviceIp;
  final String? deviceLocale;
  final String? appVersion;
  final bool isCurrentDevice;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final parts = <String>[];
    if (deviceManufacturer != null) parts.add(deviceManufacturer!);
    if (deviceModel != null) parts.add(deviceModel!);
    if (parts.isEmpty) parts.add(deviceName);
    return parts.join(' ');
  }

  String get lastSeenLabel {
    if (lastSeenAt == null) return 'Never';
    final diff = DateTime.now().difference(lastSeenAt!);
    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastSeenAt!.day}/${lastSeenAt!.month}/${lastSeenAt!.year}';
  }
}

/// Device tile widget for linked devices page
class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isCurrent,
    required this.onLogout,
  });

  final UserDevice device;
  final bool isCurrent;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          device.platform.toLowerCase().contains('ios')
              ? Icons.phone_iphone
              : device.platform.toLowerCase().contains('android')
              ? Icons.phone_android
              : device.platform.toLowerCase().contains('windows')
              ? Icons.desktop_windows
              : device.platform.toLowerCase().contains('mac')
              ? Icons.laptop_mac
              : Icons.computer,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(device.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(device.deviceOs ?? 'Unknown OS'),
          Text(
            isCurrent ? 'Active now' : 'Last seen ${device.lastSeenLabel}',
            style: TextStyle(
              fontSize: 12,
              color: isCurrent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Current',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            )
          : IconButton(
              icon: Icon(Icons.logout, color: theme.colorScheme.error),
              onPressed: onLogout,
              tooltip: 'Log out of this device',
            ),
    );
  }
}
