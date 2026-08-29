import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../providers/chat_settings_provider.dart';
import '../../../calls/presentation/providers/call_provider.dart';

class ChatInfoScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  Map<String, dynamic>? _chat;
  List<Map<String, dynamic>> _participants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final rows = await client.from('chats').select().eq('id', widget.chatId).limit(1);
    _chat = rows.isNotEmpty ? rows.first : null;
    if (_chat?['type'] == 'group' || _chat?['type'] == 'broadcast') {
      final parts = await client
          .from('chat_participants')
          .select('role, profile:profiles(id, full_name, avatar_url, phone)')
          .eq('chat_id', widget.chatId)
          .isFilter('left_at', null);
      _participants = List<Map<String, dynamic>>.from(parts);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startCall(bool video) async {
    if (_chat == null) return;
    final isGroup = _chat?['type'] == 'group' || _chat?['type'] == 'broadcast';
    if (isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group calls are not supported yet')),
      );
      return;
    }
    final other = _chat?['other_participant'] as Map<String, dynamic>?;
    final remoteUserId = other?['id'];
    final remoteUserName = other?['full_name'] ?? 'Unknown';
    if (remoteUserId == null) return;

    if (video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return;
    }
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return;

    await ref.read(callProvider.notifier).startOutgoing(
      chatId: widget.chatId,
      remoteUserId: remoteUserId,
      remoteUserName: remoteUserName,
      callType: video ? 'video' : 'audio',
    );
    final id = ref.read(callProvider).callId;
    if (id != null && mounted) context.push('/call/$id');
  }

  void _confirmDisappearing() {
    final options = [0, 86400, 604800, 1209600];
    final labels = ['Off', '24 hours', '7 days', '14 days'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Disappearing messages', style: TextStyle(fontWeight: FontWeight.bold))),
            ...List.generate(options.length, (i) => ListTile(
              title: Text(labels[i]),
              onTap: () {
                Navigator.pop(context);
                ref.read(chatSettingsProvider(widget.chatId).notifier).setDisappearingTimer(options[i] == 0 ? null : options[i]);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(chatSettingsProvider(widget.chatId));
    final isGroup = _chat?['type'] == 'group' || _chat?['type'] == 'broadcast';
    final name = isGroup
        ? (_chat?['name'] ?? 'Group')
        : ((_chat?['other_participant'] as Map?)?['full_name'] ?? 'Chat');
    final avatar = isGroup
        ? _chat?['avatar_url']
        : (_chat?['other_participant'] as Map?)?['avatar_url'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              children: [
                const SizedBox(height: 16),
                Center(child: AppAvatar(imageUrl: avatar, name: name, size: 96)),
                const SizedBox(height: 12),
                Center(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                if (isGroup)
                  Center(child: Text('${_participants.length} participants', style: const TextStyle(color: AppColors.textTertiary))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Action(icon: Icons.call, label: 'Call', onTap: () => _startCall(false)),
                    _Action(icon: Icons.videocam, label: 'Video', onTap: () => _startCall(true)),
                    _Action(icon: Icons.search, label: 'Search', onTap: () => context.push('/chat/${widget.chatId}/search')),
                    _Action(icon: Icons.notifications, label: 'Mute', onTap: () => ref.read(chatSettingsProvider(widget.chatId).notifier).setMute(!settings.isMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                if (isGroup) ...[
                  _SectionHeader(title: 'Participants'),
                  ..._participants.map((p) {
                    final profile = p['profile'] as Map<String, dynamic>? ?? {};
                    return ListTile(
                      leading: AppAvatar(imageUrl: profile['avatar_url'], name: profile['full_name'] ?? '', size: 44),
                      title: Text(profile['full_name'] ?? '', style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(p['role'] ?? 'member', style: const TextStyle(color: AppColors.textTertiary)),
                    );
                  }),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.add, color: Colors.white)),
                    title: const Text('Add participants', style: TextStyle(color: AppColors.primary)),
                    onTap: () {},
                  ),
                  const Divider(),
                ],
                _SwitchTile(
                  title: 'Muted',
                  value: settings.isMuted,
                  onChanged: (v) => ref.read(chatSettingsProvider(widget.chatId).notifier).setMute(v),
                ),
                ListTile(
                  title: const Text('Disappearing messages', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(_disappearingLabel(settings.disappearingTimer), style: const TextStyle(color: AppColors.textTertiary)),
                  onTap: _confirmDisappearing,
                ),
                ListTile(
                  leading: const Icon(Icons.push_pin, color: AppColors.textPrimary),
                  title: const Text('Pin chat', style: TextStyle(color: AppColors.textPrimary)),
                  trailing: Switch(
                    value: settings.isPinned,
                    activeColor: AppColors.primary,
                    onChanged: (_) => ref.read(chatSettingsProvider(widget.chatId).notifier).togglePin(),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.archive, color: AppColors.textPrimary),
                  title: const Text('Archive chat', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () => ref.read(chatSettingsProvider(widget.chatId).notifier).toggleArchive(),
                ),
                ListTile(
                  leading: const Icon(Icons.star_border, color: AppColors.textPrimary),
                  title: const Text('Starred messages', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () => context.push('/starred'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Clear chat', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    await ref.read(supabaseClientProvider).rpc('clear_chat', params: {'p_chat_id': widget.chatId});
                    if (mounted) Navigator.pop(context);
                  },
                ),
                if (!isGroup)
                  ListTile(
                    leading: const Icon(Icons.block, color: AppColors.error),
                    title: const Text('Block', style: TextStyle(color: AppColors.error)),
                    onTap: () {},
                  ),
                if (isGroup)
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Exit group', style: TextStyle(color: AppColors.error)),
                    onTap: () {},
                  ),
              ],
            ),
    );
  }

  String _disappearingLabel(int? t) {
    if (t == null) return 'Off';
    if (t == 86400) return '24 hours';
    if (t == 604800) return '7 days';
    if (t == 1209600) return '14 days';
    return 'On';
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.surfaceVariant, child: Icon(icon, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.notifications, color: AppColors.textPrimary),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        trailing: Switch(value: value, activeColor: AppColors.primary, onChanged: onChanged),
      );
}
