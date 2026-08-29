import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../presentation/providers/chat_provider.dart';
import '../../presentation/providers/chat_settings_provider.dart';
import '../../../shared/widgets/app_avatar.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _process(List<Map<String, dynamic>> chats) {
    final visible = chats.where((c) {
      final my = c['my_participant'] as Map<String, dynamic>?;
      final archived = my?['is_archived'] == true;
      return !archived;
    }).toList();

    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? visible
        : visible.where((c) {
            final name = _ChatListScreenState._displayName(c).toLowerCase();
            final last = (c['last_message']?['content'] as String? ?? '').toLowerCase();
            return name.contains(q) || last.contains(q);
          }).toList();

    filtered.sort((a, b) {
      final ap = _isPinned(a) ? 0 : 1;
      final bp = _isPinned(b) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      final at = _time(a);
      final bt = _time(b);
      return bt.compareTo(at);
    });
    return filtered;
  }

  bool _isPinned(Map<String, dynamic> c) =>
      (c['my_participant'] as Map<String, dynamic>?)?['is_pinned'] == true;

  DateTime _time(Map<String, dynamic> c) {
    final lm = c['last_message'];
    if (lm == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(lm['created_at'] ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _displayName(Map<String, dynamic> c) {
    if (c['type'] == 'group' || c['type'] == 'broadcast') {
      return c['name'] as String? ?? 'Group';
    }
    final other = c['other_participant'] as Map<String, dynamic>?;
    return other?['full_name'] as String? ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatListProvider);
    final chats = _process(chatState.chats);
    final archivedCount = chatState.chats
        .where((c) =>
            (c['my_participant'] as Map<String, dynamic>?)?['is_archived'] == true)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text(
                'Crystal Messenger',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
        backgroundColor: AppColors.surface,
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _searching = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textSecondary),
              onPressed: () => setState(() => _searching = true),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceBright,
            onSelected: (v) {
              switch (v) {
                case 'new_group':
                  context.push('/new-group');
                  break;
                case 'new_broadcast':
                  context.push('/new-broadcast');
                  break;
                case 'contacts':
                  context.push('/contacts');
                  break;
                case 'starred':
                  context.push('/starred');
                  break;
                case 'settings':
                  context.push('/settings');
                  break;
                case 'profile':
                  context.push('/profile');
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new_group', child: Text('New Group')),
              const PopupMenuItem(value: 'new_broadcast', child: Text('New Broadcast')),
              const PopupMenuItem(value: 'contacts', child: Text('Contacts')),
              const PopupMenuItem(value: 'starred', child: Text('Starred Messages')),
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: chatState.isLoading && chatState.chats.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : (chats.isEmpty && archivedCount == 0)
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: chats.length + (archivedCount > 0 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && archivedCount > 0 && _query.isEmpty) {
                        return _ArchivedTile(count: archivedCount);
                      }
                      final chat = chats[_query.isEmpty ? index - 1 : index];
                      return _ChatTile(chat: chat);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/new-group'),
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: AppColors.textTertiary.withAlpha(80)),
          const SizedBox(height: 16),
          const Text('No chats yet', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Tap the button below to start a conversation',
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ArchivedTile extends StatelessWidget {
  final int count;
  const _ArchivedTile({required this.count});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.surfaceVariant,
        child: Icon(Icons.archive, color: AppColors.textSecondary),
      ),
      title: const Text('Archived', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      trailing: Text('$count', style: const TextStyle(color: AppColors.textTertiary)),
      onTap: () => context.push('/archived'),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final name = _ChatListScreenState._displayName(chat);
    final avatarUrl = chat['type'] == 'group' || chat['type'] == 'broadcast'
        ? chat['avatar_url'] as String?
        : (chat['other_participant'] as Map<String, dynamic>?)?['avatar_url'] as String?;
    final lastMessage = chat['last_message'] as Map<String, dynamic>?;
    final lastContent = lastMessage?['content'] as String?;
    final lastMessageAt = lastMessage?['created_at'] != null
        ? DateTime.tryParse(lastMessage?['created_at'])
        : null;
    final unreadCount = (chat['unread_count'] as num?)?.toInt() ?? 0;
    final chatId = chat['id'] as String;
    final my = chat['my_participant'] as Map<String, dynamic>?;
    final isMuted = my?['is_muted'] == true;
    final isPinned = my?['is_pinned'] == true;
    final isGroup = chat['type'] == 'group' || chat['type'] == 'broadcast';

    return InkWell(
      onTap: () => context.push('/chat/$chatId'),
      onLongPress: () => _showActions(context, chatId, isPinned, isMuted),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AppAvatar(imageUrl: avatarUrl, name: name, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (lastMessageAt != null)
                        Text(
                          _formatTime(lastMessageAt),
                          style: TextStyle(fontSize: 12, color: unreadCount > 0 ? AppColors.primary : AppColors.textTertiary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isPinned) const Icon(Icons.push_pin, size: 14, color: AppColors.textTertiary),
                      if (isPinned) const SizedBox(width: 4),
                      if (isMuted) const Icon(Icons.volume_off, size: 14, color: AppColors.textTertiary),
                      if (isMuted) const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastContent ?? 'No messages yet',
                          style: TextStyle(fontSize: 14, color: unreadCount > 0 ? AppColors.textSecondary : AppColors.textTertiary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text('$unreadCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, String chatId, bool isPinned, bool isMuted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppColors.textPrimary),
              title: Text(isPinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () {
                Navigator.pop(context);
                final notifier = ProviderScope.containerOf(context).read(chatSettingsProvider(chatId).notifier);
                notifier.togglePin();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: AppColors.textPrimary),
              title: const Text('Archive chat'),
              onTap: () {
                Navigator.pop(context);
                ProviderScope.containerOf(context).read(chatSettingsProvider(chatId).notifier).toggleArchive();
              },
            ),
            ListTile(
              leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off, color: AppColors.textPrimary),
              title: Text(isMuted ? 'Unmute' : 'Mute'),
              onTap: () {
                Navigator.pop(context);
                final notifier = ProviderScope.containerOf(context).read(chatSettingsProvider(chatId).notifier);
                if (isMuted) {
                  notifier.setMute(false);
                } else {
                  _showMuteOptions(context, notifier);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMuteOptions(BuildContext context, ChatSettingsNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Mute for', style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(title: const Text('8 hours'), onTap: () { Navigator.pop(context); notifier.setMute(true, duration: const Duration(hours: 8)); }),
            ListTile(title: const Text('1 week'), onTap: () { Navigator.pop(context); notifier.setMute(true, duration: const Duration(days: 7)); }),
            ListTile(title: const Text('Always'), onTap: () { Navigator.pop(context); notifier.setMute(true); }),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    if (messageDate == today) return DateFormat('HH:mm').format(time);
    if (messageDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(time).inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('dd/MM/yy').format(time);
  }
}
