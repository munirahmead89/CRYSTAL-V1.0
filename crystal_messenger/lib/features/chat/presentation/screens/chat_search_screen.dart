import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../widgets/message_bubble.dart';

class ChatSearchScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatSearchScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;
    try {
      final rows = await client
          .from('messages')
          .select('*, reply_to:messages!reply_to_id(id, content, sender_id, message_type)')
          .eq('chat_id', widget.chatId)
          .ilike('content', '%$q%')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() => _results = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Search in conversation', border: InputBorder.none, hintStyle: TextStyle(color: AppColors.textTertiary)),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final msg = _results[index];
                final isMe = msg['sender_id'] == ref.read(supabaseClientProvider).auth.currentUser?.id;
                return ListTile(
                  title: MessageBubble(message: msg, isMe: isMe),
                  onTap: () => context.pop(),
                );
              },
            ),
    );
  }
}
