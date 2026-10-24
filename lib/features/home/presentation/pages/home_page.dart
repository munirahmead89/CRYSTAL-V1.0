import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/runtime.dart';
import '../../../../core/connectivity/connectivity_providers.dart';
import '../../../../core/media/media_providers.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/security/device_identity.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../features/ban/presentation/ban_providers.dart';
import '../../../../native/device_info.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/utils/uuid.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/security/app_lock.dart';
import '../../../calls/presentation/pages/calls_tab.dart';
import '../../../conversations/presentation/pages/chats_page.dart';
import '../../../conversations/presentation/providers/chat_providers.dart';
import '../../../conversations/presentation/widgets/transfer_views.dart';
import 'package:app_links/app_links.dart';
import '../../../updates/presentation/pages/updates_tab.dart';
import '../widgets/main_tab_bar.dart';
import '../../../profile/presentation/providers/settings_providers.dart';

/// The signed-in WhatsApp-style shell.
///
/// Layout (top → bottom):
///   1. [_HomeHeader]  — Crystal Messenger title + QR + avatar
///   2. [_SearchBar]   — pill search field (Chats tab only)
///   3. [MainTabBar]   — Chats / Updates top tab row
///   4. [IndexedStack] — tab content
///   5. [BottomNavigationBar] — WhatsApp-style bottom nav    ← NEW
///
/// Both navigation surfaces share the same [_index] so tapping either one
/// switches the displayed content. No tab is removed — both are additive.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  int _index = 0;
  bool _started = false;
  Timer? _autoRefreshTimer;

  /// How often the shell re-syncs in the foreground, WhatsApp-style.
  ///
  /// Realtime still drives instant updates; this poll is the safety net that
  /// catches anything realtime missed. Every surface refreshes itself — there
  /// is no manual refresh anywhere in the app.
  static const _autoRefreshInterval = Duration(seconds: 30);

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinksSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(authStateProvider, (previous, next) {
      if (next.isSignedIn) _runStartup();
    });
    Future.microtask(() {
      if (ref.read(authStateProvider).isSignedIn) {
        _runStartup();
      }
    });
    _searchController.addListener(() => setState(() {}));
    _initAppLinks();
  }

  void _initAppLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleSharedUri(initialUri);
      _appLinksSub = _appLinks.uriLinkStream.listen((uri) {
        _handleSharedUri(uri);
      });
    } catch (_) {}
  }

  void _handleSharedUri(Uri uri) {
    if (!mounted) return;
    final text =
        uri.queryParameters['text'] ??
        uri.queryParameters['body'] ??
        uri.toString();
    _showShareToChatSheet(text);
  }

  void _showShareToChatSheet(String sharedContent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ShareToChatSheet(content: sharedContent),
    );
  }

  @override
  void dispose() {
    _appLinksSub?.cancel();
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  /// Re-syncs whatever is on screen. Skipped under the test harness so pending
  /// timers do not fail widget tests.
  void _startAutoRefresh() {
    if (isRunningInTest) return;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted) return;
      _refreshVisible();
    });
  }

  /// Pushes fresh data for the active surface without any user gesture.
  void _refreshVisible() {
    if (ref.read(isOnlineProvider).valueOrNull != true) return;
    if (_index == 0) {
      ref.read(syncServiceProvider).syncIncremental().ignore();
      ref.read(chatListProvider.notifier).load(silent: true);
    } else if (_index == 1) {
      ref.invalidate(statusesProvider);
    }
  }

  Future<void> _runStartup() async {
    if (_started) return;
    _started = true;

    // Restore last tab index and conversation
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final savedIndex = prefs.lastTabIndex;
      // Guarded: the page can be disposed while this future is pending (sign
      // out, or a router replacement), and the later `context.push` below is
      // already guarded — this setState was not, so it threw
      // "setState() called after dispose()".
      if (!mounted) return;
      if (savedIndex >= 0 && savedIndex <= 2) {
        setState(() => _index = savedIndex);
      }
      // If last route was a chat, navigate to it after a short delay
      final lastRoute = prefs.lastRoute;
      final lastConversation = prefs.lastConversation;
      if (lastRoute != null &&
          lastRoute.startsWith('/chat/') &&
          lastConversation != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.push('/chat/$lastConversation');
        });
      }
    } catch (_) {}

    final auth = ref.read(authRepositoryProvider);
    final me = ref.read(authStateProvider).user;
    if (me == null) return;

    try {
      final notifications = ref.read(notificationServiceProvider);
      await notifications.ensureInitialized();
      notifications.onNotificationTap = _handleNotificationTap;
      // Replies typed in the shade arrive on a background isolate with no way
      // to send them, so they are queued on disk. Drain whatever piled up while
      // the app was not running.
      unawaited(_flushInlineReplies());
      try {
        final deviceInfo = await ref.read(deviceInfoProvider.future);
        await auth.registerDevice(
          deviceId: await DeviceIdentity.getOrCreate(),
          platform: notifications.platform,
          deviceName: deviceInfo?.label ?? 'default',
          pushToken: await notifications.token(),
          deviceModel: deviceInfo?.model,
          deviceOs: deviceInfo?.osVersion,
          deviceManufacturer: deviceInfo?.manufacturer,
          deviceIp: deviceInfo?.ipAddress,
          deviceLocale: deviceInfo?.locale,
          appVersion: deviceInfo?.appVersion,
        );
      } on DeviceSyncRequiresVerifiedException {
        // Guest (anonymous) account: single-device Realtime chat is fully
        // supported; cloud device registration is a verified-email feature.
      } catch (_) {}
      try {
        await auth.updatePresence('online');
      } catch (_) {}
    } catch (_) {}

    try {
      await ref.read(syncServiceProvider).syncInitial();
      ref
          .read(appPreferencesProvider.future)
          .then((prefs) => prefs.setLastSyncAt(DateTime.now()))
          .ignore();
      _startAutoRefresh();
    } catch (_) {}

    try {
      await ref.read(banStatusProvider.future);
    } catch (_) {}
  }

  /// Sends everything the user typed in the notification shade.
  ///
  /// Android hands those to a background isolate that has no Supabase client and
  /// no auth session, so they are parked on disk until the app is next running.
  /// Sending goes through the normal repository rather than a raw insert, so the
  /// unique-violation recovery applies: a reply that actually committed before the
  /// app died is resolved to the stored row instead of being reported as failed.
  Future<void> _flushInlineReplies() async {
    if (!mounted) return;
    final pending = await NotificationService.takePendingReplies();
    if (pending.isEmpty) return;

    final senderId = ref.read(authStateProvider).user?.id;
    if (senderId == null || senderId.isEmpty) return;
    final repo = ref.read(messagesRepositoryProvider);

    for (final reply in pending) {
      final conversationId = reply.conversationIdFromRoute.trim();
      if (conversationId.isEmpty) continue;
      final text = reply.text.trim();
      if (text.isEmpty) continue;
      try {
        await repo.send(
          ChatMessage(
            id: generateUuid(),
            clientMessageId: generateUuid(),
            conversationId: conversationId,
            senderId: senderId,
            type: 'text',
            body: text,
            createdAt: DateTime.now(),
            outgoing: true,
            localState: MessageLocalState.sent,
          ),
        );
      } catch (error) {
        // Already dequeued, so a failure here means the reply is lost. Surfacing
        // it is better than a silent gap the user will notice in the chat.
        if (!mounted) return;
        debugPrint('[inline-reply] could not send to $conversationId: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not send your reply. Open the chat to retry.',
            ),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => context.push('/chat/$conversationId'),
            ),
          ),
        );
      }
    }
  }

  /// Converts the stored auto-lock timer label into seconds.
  ///
  /// Unknown values become `0`, which means "lock immediately" — the strictest
  /// behaviour. A malformed preference must not be the thing that leaves the app
  /// unlocked.
  int _appLockGraceSeconds(String label) => switch (label) {
    '1min' => 60,
    '5min' => 300,
    '15min' => 900,
    '1hour' => 3600,
    _ => 0,
  };

  void _handleNotificationTap(String route) {
    if (!mounted) return;
    final segments = route.split('/');

    final id = segments.last;
    if (id.length == 36 && id.contains('-')) {
      context.push('/chat/$id');
    } else {
      context.go('/');
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!mounted) return;
    final auth = ref.read(authRepositoryProvider);
    if (state == AppLifecycleState.resumed) {
      try {
        await auth.updatePresence('online');
      } catch (_) {}
      _startAutoRefresh();
      ref.read(syncServiceProvider).syncIncremental().ignore();

      // App Lock. The controller decides whether the grace period has elapsed and
      // latches the router onto the lock screen; it deliberately does not prompt
      // here, because `resumed` also fires when the biometric dialog itself
      // closes, which produced back-to-back prompts.
      final settings = ref.read(settingsControllerProvider).valueOrNull;
      if (settings?.appLockEnabled == true) {
        // Seed the grace period from the user's setting on every resume. The
        // setting lives in `AppUserSettings`; the lock keeps its own copy, and
        // without this they could drift apart (a change made on another device
        // would never reach the controller that enforces it).
        ref
            .read(appLockControllerProvider)
            .setGraceSeconds(
              _appLockGraceSeconds(settings?.appLockTimer ?? 'immediate'),
            );
        await ref
            .read(appLockControllerProvider)
            .evaluate(lockEnabled: true, force: false);
      } else {
        ref.read(appLockControllerProvider).disable();
      }
      // A reply can be typed at any time the shade is visible, which includes
      // long stretches while the app sits in the background.
      unawaited(_flushInlineReplies());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _autoRefreshTimer?.cancel();
      // `inactive` fires for transient interruptions (a notification shade pull,
      // a system dialog) as well as real backgrounding, so it must not latch the
      // lock on its own. `paused` and `detached` mean the app actually left the
      // foreground.
      if (state != AppLifecycleState.inactive) {
        final settings = ref.read(settingsControllerProvider).valueOrNull;
        if (settings?.appLockEnabled == true) {
          // Record the backgrounding without prompting. The lock is evaluated on
          // the way back in, against the user's grace period.
          ref.read(appLockControllerProvider).lock();
        }
      }
      try {
        await auth.updatePresence('offline');
      } catch (_) {}
    }
  }

  void _onTabChanged(int i) {
    setState(() => _index = i);
    _refreshVisible();
    ref
        .read(appPreferencesProvider.future)
        .then((prefs) => prefs.setLastTabIndex(i))
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isOnlineProvider, (previous, next) {
      final wasOnline = previous?.valueOrNull ?? false;
      final nowOnline = next.valueOrNull ?? false;
      if (wasOnline == false && nowOnline) {
        ref.read(syncServiceProvider).syncIncremental().ignore();
      }
    });
    // The network type listener that forcefully signed users out on network changes
    // (WiFi <-> mobile <-> none) has been completely removed.
    // The realtime sync engine (Supabase/SyncService) will gracefully handle
    // network drops and resumes via `isOnlineProvider` without forcing re-auth.

    ref.listen(banStatusProvider, (previous, next) {
      if (next.valueOrNull?.banned == true && mounted) context.go('/banned');
    });

    return Scaffold(
      // ── Bottom navigation bar (WhatsApp-style) ──────────────────────────
      bottomNavigationBar: _CrystalBottomNav(
        index: _index,
        onChanged: _onTabChanged,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top header ─────────────────────────────────────────────
            _HomeHeader(index: _index),

            // ── Upper tabs (Chats / Updates / Calls) ──────────────────
            MainTabBar(index: _index, onChanged: _onTabChanged),

            // ── Search bar (below upper tabs, above filters) ──────────
            _SearchBar(controller: _searchController),

            // ── Tab content ────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  ChatsTab(query: _searchController.text),
                  const UpdatesTab(),
                  const CallsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp-style bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _CrystalBottomNav extends StatelessWidget {
  const _CrystalBottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        // Subtle shadow so the bar lifts off the content.
        boxShadow: [
          BoxShadow(
            color: CrystalColors.black12,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _BottomNavItem(
                index: 0,
                activeIndex: index,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chats',
                onTap: onChanged,
              ),
              _BottomNavItem(
                index: 1,
                activeIndex: index,
                icon: Icons.circle_outlined,
                activeIcon: Icons.circle,
                label: 'Updates',
                onTap: onChanged,
              ),
              _BottomNavItem(
                index: 2,
                activeIndex: index,
                icon: Icons.call_outlined,
                activeIcon: Icons.call,
                label: 'Calls',
                onTap: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.index,
    required this.activeIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int activeIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  bool get _selected => index == activeIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkResponse(
        onTap: () => onTap(index),
        highlightColor: CrystalColors.green24,
        splashColor: CrystalColors.green24,
        radius: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with animated green pill background when active.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: _selected ? CrystalColors.green24 : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _selected ? activeIcon : icon,
                size: 22,
                color: _selected
                    ? CrystalColors.green
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            // Label text.
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: _selected ? FontWeight.bold : FontWeight.w400,
                color: _selected
                    ? CrystalColors.green
                    : scheme.onSurfaceVariant,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

/// Crystal Messenger header: title on the left, QR icon + profile avatar
/// on the right. Tapping the avatar opens Settings / Profile.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(ownProfileProvider);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4, top: 6, bottom: 4),
      child: Row(
        children: [
          // App title — full width, no truncation.
          Expanded(
            child: Text(
              'Crystal Messenger',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Live transfers. Only shown while something is actually moving, so
          // the header stays clean; tapping it opens the full list.
          Consumer(
            builder: (context, ref, _) {
              final tracker = ref.watch(transferTrackerProvider);
              return AnimatedBuilder(
                animation: tracker,
                builder: (context, _) {
                  if (!tracker.hasActive) return const SizedBox.shrink();
                  final count = tracker.activeCount;
                  return IconButton(
                    tooltip:
                        '$count transfer${count == 1 ? '' : 's'} in progress',
                    onPressed: () => TransfersSheet.show(context, tracker),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.swap_vert_circle_outlined),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // QR-hub icon.
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'My code / Scan',
            onPressed: () => context.push('/qr-hub'),
          ),

          // Profile avatar → Settings / Profile page. Presence is shown as a
          // thin green ring around the avatar (no standalone dot).
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: UserAvatar(
                profile: async.valueOrNull,
                radius: 18,
                online: ref.watch(isOnlineProvider).valueOrNull == true,
                avatarUserId: async.valueOrNull?.id,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareToChatSheet extends ConsumerStatefulWidget {
  const _ShareToChatSheet({required this.content});

  final String content;

  @override
  ConsumerState<_ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends ConsumerState<_ShareToChatSheet> {
  final Set<String> _selectedChatIds = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatListProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedChatIds.isEmpty
                      ? 'Share to...'
                      : 'Share to (${_selectedChatIds.length} selected)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedChatIds.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendToSelected,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            chatsAsync.when(
              data: (chats) {
                if (chats.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No active conversations found.'),
                  );
                }
                return SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isSelected = _selectedChatIds.contains(chat.id);
                      return CheckboxListTile(
                        value: isSelected,
                        secondary: UserAvatar(profile: chat.peer, radius: 20),
                        title: Text(chat.peer?.displayName ?? chat.displayName),
                        subtitle: Text(
                          chat.lastMessageText ?? 'Tap to select',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedChatIds.add(chat.id);
                            } else {
                              _selectedChatIds.remove(chat.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Could not load chats.'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToSelected() async {
    if (_selectedChatIds.isEmpty || _sending) return;
    setState(() => _sending = true);
    final myId = ref.read(authStateProvider).user?.id ?? '';
    for (final chatId in _selectedChatIds) {
      try {
        final draft = ChatMessage(
          id: generateUuid(),
          clientMessageId: generateUuid(),
          conversationId: chatId,
          senderId: myId,
          type: 'text',
          body: widget.content,
          createdAt: DateTime.now(),
          outgoing: true,
        );
        await ref.read(localStoreProvider).upsertLocalMessage(draft);
        await ref.read(localStoreProvider).enqueueOutbox(draft);
      } catch (_) {}
    }
    ref.read(syncEngineProvider).flushNow().ignore();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared to ${_selectedChatIds.length} chat(s)')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

/// WhatsApp-style pill search field. Filters whichever tab is active.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
