import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../../core/storage/chat_overrides.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/widgets/profile_quick_view.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../home/presentation/widgets/filter_labels.dart';
import '../providers/chat_providers.dart';

enum _ChatFilter { all, read, unread }

/// The Chats shell tab (used inside [HomePage]'s WhatsApp-style tab bar).
///
/// The list refreshes itself: realtime reorders live as messages arrive, a
/// foreground poll re-syncs on a cadence, and app resume/connectivity restore
/// re-fetch. No manual pull-to-refresh gesture is needed.
class ChatsTab extends ConsumerStatefulWidget {
  const ChatsTab({super.key, this.query = ''});

  final String query;

  @override
  ConsumerState<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<ChatsTab>
    with WidgetsBindingObserver {
  Timer? _feedDebounce;
  bool _subscribed = false;
  _ChatFilter _filter = _ChatFilter.all;
  final Set<String> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Live reorder as messages arrive anywhere the user is a member.
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeFeed());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider).syncIncremental().ignore();
      ref.read(chatListProvider.notifier).load(silent: true);
    }
  }

  /// Shows the chat-list feed banner, titled with the sender's name.
  ///
  /// Resolved asynchronously from the local profile cache. Falls back to the app
  /// name rather than a generic "New message", so a banner is never ambiguous
  /// about where it came from.
  Future<void> _showFeedNotification({
    required String? conversationId,
    required String? messageId,
    required String senderId,
    required String body,
  }) async {
    var title = 'Crystal Messenger';
    try {
      if (conversationId != null) {
        final profile = await ref
            .read(localStoreProvider)
            .cachedProfile(senderId);
        final name = profile?.displayName.trim();
        if (name != null && name.isNotEmpty) title = name;
      }
    } catch (_) {
      // Best-effort; the app name is an acceptable title.
    }
    if (!mounted) return;
    await ref
        .read(notificationServiceProvider)
        .showForeground(
          title: title,
          body: body,
          data: {
            if (conversationId != null) 'conversation_id': conversationId,
            if (messageId != null) 'message_id': messageId,
          },
          // Inline reply needs a conversation to reply into; without one the
          // banner is tap-only.
          conversationId: conversationId,
        );
  }

  void _subscribeFeed() {
    if (_subscribed || !mounted) return;
    _subscribed = true;
    try {
      ref.read(realtimeServiceProvider).subscribeToMessageFeed((payload) {
        final record = payload.newRecord;
        if (record.isNotEmpty) {
          final myId = ref.read(authStateProvider).user?.id;
          final senderId = record['sender_id'] as String?;
          if (senderId != null && senderId != myId) {
            HapticFeedback.vibrate();
            final conversationId = record['conversation_id'] as String?;
            final body = (record['text'] as String?) ?? 'Sent a message';
            // `client_message_id` is stable across the server round-trip and is
            // what makes this dedupe against the per-chat notification: both
            // call sites resolve to the same notification id, so whichever
            // fires second *replaces* the banner instead of stacking a second
            // copy of the same message. This feed omitted it entirely, which is
            // why an open chat produced two banners for one message.
            final messageId =
                (record['client_message_id'] as String?) ??
                (record['id'] as String?);
            unawaited(
              _showFeedNotification(
                conversationId: conversationId,
                messageId: messageId,
                senderId: senderId,
                body: body,
              ),
            );
          }
        }
        _feedDebounce?.cancel();
        _feedDebounce = Timer(const Duration(milliseconds: 300), () async {
          if (!mounted) return;
          await ref.read(syncServiceProvider).syncIncremental();
          if (!mounted) return;
          ref.read(chatListProvider.notifier).load(silent: true);
        });
      });
    } catch (_) {
      // Realtime is unavailable here (tests, or backend not configured);
      // the scheduled syncs + lifecycle refresh still keep the list fresh.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedDebounce?.cancel();
    try {
      ref.read(realtimeServiceProvider).unsubscribe('messagesFeed');
    } catch (_) {
      // Same guard as above.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatListProvider);
    final isSelectionMode = _selectedChatIds.isNotEmpty;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        // Show selection app bar when in selection mode, otherwise normal app bar
        if (isSelectionMode)
          SliverAppBar(
            automaticallyImplyLeading: false,
            title: Text(
              '${_selectedChatIds.length} selected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: _selectAllChats,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedChatIds.clear()),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelectedChats,
              ),
            ],
            expandedHeight: kToolbarHeight,
            flexibleSpace: Container(color: Theme.of(context).colorScheme.surface),
          ),
        if (!isSelectionMode)
          SliverToBoxAdapter(
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: FilterLabels<_ChatFilter>(
                    options: const [
                      FilterOption(_ChatFilter.all, 'All'),
                      FilterOption(_ChatFilter.read, 'Read'),
                      FilterOption(_ChatFilter.unread, 'Unread'),
                    ],
                    selected: _filter,
                    onChanged: (filter) => setState(() => _filter = filter),
                  ),
                ),
                // Keep the filter row flush with the padded lists.
                const SizedBox(width: 8),
              ],
            ),
          ),
        ...,
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: _ErrorList(
              message: '$e',
              onRetry: () => ref.read(chatListProvider.notifier).load(),
            ),
          ),
          data: (chats) {
            // Deleted (delete-for-me) and blocked conversations are hidden
            // from the list until reversed.
            final overrides = ref.watch(chatOverridesProvider);
            final visible = chats.where((c) {
              if (overrides.isDeleted(c.id)) return false;
              final peerId = c.peer?.id;
              if (peerId != null && overrides.isBlocked(peerId)) return false;
              return true;
            }).toList();
            final searched = _applySearch(visible);
            final filtered = _applyFilter(searched);
            if (filtered.isEmpty) {
              return SliverFillRemaining(
                child: _EmptyChats(
                  searching: widget.query.trim().isNotEmpty,
                  message: _filter == _ChatFilter.all
                      ? null
                      : _filter == _ChatFilter.unread
                      ? 'No unread conversations'
                      : 'No read conversations',
                ),
              );
            }
            // Show selection mode UI if conversations are selected
            final isSelectionMode = _selectedChatIds.isNotEmpty;
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conversation = filtered[index];
                  // Build the manage sheet toggle for selection mode
                  final isSelected = _selectedChatIds.contains(conversation.id);
                  return _ChatTile(
                    conversation: conversation,
                    onTap: isSelectionMode
                        ? _toggleSelection(conversation.id)
                        : () => context.push(
                              '/chat/${filtered[index].id}',
                              extra: filtered[index],
                            ),
                    onLongPress: isSelectionMode
                        ? null
                        : () => _showManageSheet(context, ref),
                    isSelected: isSelected,
                    enableSelectionMode: isSelectionMode,
                    selectedChatIds: _selectedChatIds,
                    onSelectAll: _selectAllChats,
                  );
                },
                childCount: filtered.length,
              ),
            );
          },
          // When entering selection mode, show a different app bar
          // (this requires adjusting the CustomScrollView's slivers)
        ),
      ],
    );
  }

  List<ConversationSummary> _applySearch(List<ConversationSummary> chats) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return chats.where((c) {
      final name = (c.peer?.displayName ?? c.displayName).toLowerCase();
      final phone = (c.peer?.phone ?? '').toLowerCase();
      final preview = (c.lastMessageText ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || preview.contains(q);
    }).toList();
  }

  List<ConversationSummary> _applyFilter(List<ConversationSummary> chats) {
    switch (_filter) {
      case _ChatFilter.unread:
        return chats.where((c) => c.unreadCount > 0).toList();
      case _ChatFilter.read:
        return chats.where((c) => c.unreadCount == 0).toList();
      case _ChatFilter.all:
        return chats;
    }
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({
    required this.conversation,
    required this.onTap,
    required this.enableSelectionMode,
    required this.selectedChatIds,
    required this.onSelectAll,
  }) : isSelected = false;

  final ConversationSummary conversation;
  final VoidCallback onTap;
  final bool enableSelectionMode;
  final Set<String> selectedChatIds;
  final VoidCallback onSelectAll;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final peer = conversation.peer;
    final overrides = ref.watch(chatOverridesProvider);
    final text = _preview(conversation);
    final isUnread = conversation.unreadCount > 0;
    final muted = overrides.isMuted(conversation.id);

    // Selection mode UI: show checkbox when enabled
    final selectionWidget = enableSelectionMode
        ? Container(
            margin: const EdgeInsets.only(right: 12),
            child: Checkbox(
              value: isSelected,
              onChanged: (value) {
                if (value != null && value) {
                  selectedChatIds.add(conversation.id);
                } else {
                  selectedChatIds.remove(conversation.id);
                }
              },
              activeColor: colorScheme.primary,
            ),
          )
        : const SizedBox.shrink();

    return InkWell(
      onTap: () {
        // Reopening a previously deleted chat reverses the delete-for-me.
        if (overrides.isDeleted(conversation.id)) {
          ref
              .read(chatOverridesProvider.notifier)
              .restoreConversation(conversation.id);
        }
        onTap();
      },
      onLongPress: enableSelectionMode ? null : () => _showManageSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            selectionWidget,
            if (peer != null)
              GestureDetector(
                onTap: () => showProfileQuickView(
                  context,
                  ref,
                  profile: peer,
                  conversationId: conversation.id,
                ),
                child: UserAvatar(
                  profile: peer,
                  radius: 28,
                  online: peer.isOnline == true,
                ),
              )
            else
              UserAvatar(profile: peer, radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          // `title` resolves the group name for group chats and
                          // the peer's name for 1:1. Reading `peer?.displayName`
                          // directly rendered every group as "Unknown", because a
                          // group has no single peer - even though the group name
                          // was sitting in the local cache the whole time.
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (peer?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(),
                      ],
                      if (muted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 14,
                          color: colorScheme.outline,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isUnread
                                ? colorScheme.onSurface
                                : colorScheme.outline,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (conversation.lastMessageAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Â· ${_time(conversation.lastMessageAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                        if (_outgoing(conversation)) ...[
                          const SizedBox(width: 5),
                          _PreviewStatusDot(conversation),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isUnread && !muted)
              // WhatsApp-style dark-green unread count badge; hidden when the
              // conversation is muted or the count drops to zero.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                constraints: const BoxConstraints(minWidth: 22),
                decoration: BoxDecoration(
                  color: CrystalColors.greenDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _badgeLabel(conversation.unreadCount),
                  style: const TextStyle(
                    color: CrystalColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const SizedBox(width: 22),
          ],
        ),
      ),
    );
  }

  bool _outgoing(ConversationSummary c) =>
      c.lastMessageSenderId != null && c.lastMessageSenderId != c.peer?.id;

  /// Toggles a conversation between selected/deselected state.
  void _toggleSelection(String conversationId) {
    setState(() {
      if (_selectedChatIds.contains(conversationId)) {
        _selectedChatIds.remove(conversationId);
      } else {
        _selectedChatIds.add(conversationId);
      }
    });
    // If only one is left selected, maybe exit selection mode? WhatsApp stays
    // in selection mode until the user explicitly acts or taps "Done".
  }

  /// Selects/deselects all visible conversations.
  void _selectAllChats() {
    setState(() {
      final allIds = _applyFilter(_applySearch(
        ref.watch(chatListProvider).valueOrList.where((c) {
          final overrides = ref.watch(chatOverridesProvider);
          final peerId = c.peer?.id;
          if (overrides.isDeleted(c.id)) return false;
          if (peerId != null && overrides.isBlocked(peerId)) return false;
          return true;
        }).map((c) => c.id).toSet(),
      ).toSet());
      if (_selectedChatIds.length == allIds.length) {
        _selectedChatIds.clear();
      } else {
        _selectedChatIds.addAll(allIds);
      }
    });
  }

  /// Deletes all selected conversations.
  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;
    final confirmed = await _confirm(
      context,
      title: 'Delete ${_selectedChatIds.length} chats?',
      message:
          'This will hide these conversations from this device. Messages stay on the server.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final notifier = ref.read(chatOverridesProvider.notifier);
    for (final id in _selectedChatIds) {
      await notifier.deleteConversation(id);
      await ref
          .read(localStoreProvider)
          .deleteConversationLocally(id);
    }
    await ref.read(chatListProvider.notifier).load(silent: true);
    setState(() => _selectedChatIds.clear());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chats deleted')),
    );
  }

  /// The trailing management sheet: Delete Chat / Mute / Block (1:1 only).
  Future<void> _showManageSheet(BuildContext context, WidgetRef ref) async {
    final peer = conversation.peer;
    final overrides = ref.read(chatOverridesProvider);
    final muted = overrides.isMuted(conversation.id);
    final blocked = peer != null && overrides.isBlocked(peer.id);
    final notifier = ref.read(chatOverridesProvider.notifier);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: Text(peer?.displayName ?? 'Chat'),
              subtitle: const Text('Manage conversation'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                muted ? 'Unmute notifications' : 'Mute notifications',
              ),
              onTap: () => Navigator.of(sheetContext).pop('mute'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete chat'),
              subtitle: const Text('Removes it from this device only'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete messages for everyone'),
              subtitle: const Text(
                'Erases every message on the server, for both people. '
                'This cannot be undone.',
              ),
              onTap: () => Navigator.of(sheetContext).pop('delete-everyone'),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Disappearing messages'),
              subtitle: const Text('Messages delete themselves after a time'),
              onTap: () => Navigator.of(sheetContext).pop('disappearing'),
            ),
            if (peer != null)
              ListTile(
                leading: Icon(
                  blocked ? Icons.person_add_alt : Icons.block_outlined,
                ),
                title: Text(blocked ? 'Unblock user' : 'Block user'),
                onTap: () => Navigator.of(sheetContext).pop('block'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case 'mute':
        await notifier.toggleMute(conversation.id);
        if (!context.mounted) return;
        _toast(
          context,
          muted ? 'Notifications unmuted' : 'Notifications muted',
        );
      case 'block':
        final peerId = peer!.id;
        if (!blocked) {
          final confirmed = await _confirm(
            context,
            title:
                'Block ${peer.displayName.isEmpty ? 'this user' : peer.displayName}?',
            message: 'Their chats will be hidden. You can unblock later.',
            confirmLabel: 'Block',
          );
          if (!confirmed || !context.mounted) return;
          await notifier.blockPeer(peerId);
          await ref.read(chatListProvider.notifier).load(silent: true);
          if (!context.mounted) return;
          _toast(context, 'User blocked');
        } else {
          await notifier.unblockPeer(peerId);
          await ref.read(chatListProvider.notifier).load(silent: true);
          if (!context.mounted) return;
          _toast(context, 'User unblocked');
        }
      case 'delete':
        final confirmed = await _confirm(
          context,
          title: 'Delete chat?',
          message:
              'The conversation will be hidden on this device. The messages '
              'stay on the server and will come back if you reinstall.',
          confirmLabel: 'Delete',
        );
        if (!confirmed || !context.mounted) return;
        await notifier.deleteConversation(conversation.id);
        await ref
            .read(localStoreProvider)
            .deleteConversationLocally(conversation.id);
        await ref.read(chatListProvider.notifier).load(silent: true);
        if (!context.mounted) return;
        // Undo, WhatsApp-style. Deleting was irreversible before this: the id
        // went into a persisted `deleted` set, the local rows were purged, and
        // the only restore call sat behind a branch inside the tile that is
        // never built for a deleted conversation.
        //
        // Note what delete does and does not touch: it hides THIS conversation
        // and its cached messages. The contact is never removed, so the person
        // is still reachable and Undo brings the thread straight back.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Chat deleted'),
              action: SnackBarAction(
                label: 'Undo',
                // Restores the conversation; the messages themselves re-sync
                // from the server on the next pass.
                onPressed: () async {
                  await notifier.restoreConversation(conversation.id);
                  await ref.read(chatListProvider.notifier).load(silent: true);
                },
              ),
            ),
          );

      case 'delete-everyone':
        // Server-side, and irreversible for BOTH people. Spelled out in the
        // dialog because "delete chat" above is local-only and undoable, so
        // users need to be certain which one they picked.
        final confirmed = await _confirm(
          context,
          title: 'Delete all messages?',
          message:
              'Every message in this chat will be permanently erased from '
              'the server for you and for ${peer == null ? 'everyone in it' : peer.displayName}. '
              'This cannot be undone, and the chat stays open afterwards.',
          confirmLabel: 'Delete for everyone',
        );
        if (!confirmed || !context.mounted) return;

        final messenger = ScaffoldMessenger.of(context);
        final repo = ref.read(conversationsRepositoryProvider);
        int removed = 0;
        String? failure;
        try {
          removed = await repo.deleteConversationMessages(conversation.id);
        } catch (e) {
          failure = '$e';
        }

        // Local cleanup regardless: if the server call failed, hiding the chat
        // locally is still what the user asked for, and the next sync will
        // reveal that the messages survived.
        await notifier.deleteConversation(conversation.id);
        await ref
            .read(localStoreProvider)
            .deleteConversationLocally(conversation.id);
        await ref.read(chatListProvider.notifier).load(silent: true);
        if (!context.mounted) return;

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Text(
                failure != null
                    ? 'Removed here, but the server refused. Messages may '
                          'still exist.'
                    : removed == 0
                    ? 'No messages left to delete.'
                    : 'Deleted $removed message'
                          '${removed == 1 ? '' : 's'} for everyone.',
              ),
            ),
          );

      case 'disappearing':
        if (!context.mounted) return;
        await _showDisappearingPicker(context, ref, conversation.id);
    }
  }

  /// Lets the user choose how long messages in a conversation survive.
  ///
  /// The timer lives on the conversation row on the server, so both devices and
  /// both participants agree on it. `purge_expired_messages` enforces it on a
  /// schedule.
  Future<void> _showDisappearingPicker(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
  ) async {
    final repo = ref.read(conversationsRepositoryProvider);
    var current = 0;
    try {
      current = await repo.getDisappearingSeconds(conversationId);
    } catch (_) {
      // Fall back to "off" rather than blocking the picker.
    }
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final options = <int, String>{
      0: 'Off',
      86400: '24 hours',
      604800: '7 days',
      2592000: '30 days',
    };

    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Disappearing messages',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final entry in options.entries)
              RadioListTile<int>(
                value: entry.key,
                // ignore: deprecated_member_use
                groupValue: current,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.of(sheetContext).pop(v),
                title: Text(entry.value),
                subtitle: entry.key == 0
                    ? const Text('Messages are kept until you delete them')
                    : Text(
                        'Messages in this chat are erased '
                        '${entry.value} after they are sent',
                      ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    try {
      await repo.setDisappearingMessages(conversationId, chosen);
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              chosen == 0
                  ? 'Disappearing messages off'
                  : 'Messages will disappear after '
                        '${options[chosen]!.toLowerCase()}',
            ),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not change that: $e')));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _badgeLabel(int count) => count > 99 ? '99+' : '$count';

  String _preview(ConversationSummary c) {
    final outgoing = _outgoing(c);
    final prefix = outgoing ? 'You: ' : '';
    final label = switch (c.lastMessageType) {
      'image' => _previewPhoto,
      'file' || 'audio' => _previewAttachment,
      'voice' => _previewVoice,
      'video' => _previewVideo,
      _ => null,
    };
    if (label != null) return '$prefix$label';
    final text = (c.lastMessageText ?? '').trim();
    if (text.isEmpty) return '$prefix$_previewMessage';
    return '$prefix${_scrubUrls(text)}';
  }

  static final RegExp _previewUrlPattern = RegExp(r'https?://\S+');

  String _scrubUrls(String text) {
    final scrubbed = text.replaceAll(_previewUrlPattern, '[link]').trim();
    return scrubbed.isEmpty ? _previewMessage : scrubbed;
  }

  static const _previewPhoto = '[Photo]';
  static const _previewAttachment = '[Attachment]';
  static const _previewVoice = '[Voice message]';
  static const _previewVideo = '[Video]';
  static const _previewMessage = '[Message]';

  String _time(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    if (today == day) {
      final hh = time.hour.toString().padLeft(2, '0');
      final mm = time.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${time.day}/${time.month}';
  }
}

/// Single traffic-light dot beside the timestamp in the chat list preview.
/// Colors match the bubble indicator: red = not sent, orange = sent/delivered
/// (unread by peer), green = read.
class _PreviewStatusDot extends StatelessWidget {
  const _PreviewStatusDot(this.conversation);

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final localState = conversation.lastMessageLocalState;
    final remoteStatus = conversation.lastMessageRemoteStatus;
    Color color;
    if (localState != null &&
        (localState == MessageLocalState.queued.name ||
            localState == MessageLocalState.sending.name ||
            localState == MessageLocalState.failed.name ||
            localState == MessageLocalState.local.name)) {
      color = Colors.red;
    } else if (remoteStatus == RemoteStatus.seen.name) {
      color = Colors.green;
    } else {
      color = Colors.orange;
    }
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({this.searching = false}) : message = null;

  final String? message;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.search_off : Icons.forum_outlined,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          if (message == null) ...[
            Text(
              searching ? 'No results' : 'No conversations yet',
              style: theme.textTheme.titleMedium,
            ),
            if (!searching) ...[
              const SizedBox(height: 8),
              Text(
                'Use the Search bar or add a contact via phone number to start chatting.',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ] else
            Text(message!, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
