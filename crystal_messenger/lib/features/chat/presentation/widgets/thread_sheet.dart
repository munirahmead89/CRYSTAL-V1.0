import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';

class ThreadSheet extends ConsumerStatefulWidget {
  final String threadId;
  final String chatId;
  const ThreadSheet({
    super.key,
    required this.threadId,
    required this.chatId,
  });

  @override
  ConsumerState<ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends ConsumerState<ThreadSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = true;
  Map<String, dynamic>? _threadMessage;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    try {
      final client = ref.read(supabaseClientProvider);

      // Get the original message
      final msgResult = await client
          .from('messages')
          .select('*, sender:profiles!sender_id(full_name)')
          .eq('id', widget.threadId)
          .single();

      // Get thread replies
      final result = await client.rpc('get_thread_messages', params: {
        'p_thread_id': widget.threadId,
      });

      setState(() {
        _threadMessage = msgResult;
        _replies = (result as List?)?.cast<Map<String, dynamic>>() ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('send_thread_reply', params: {
        'p_thread_id': widget.threadId,
        'p_content': text,
        'p_message_type': 'text',
      });

      _controller.clear();
      HapticFeedback.lightImpact();
      await _loadThread();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surfaceBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thread',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_threadMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_threadMessage!['sender'] as Map<String, dynamic>?)?['full_name'] ?? '',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _threadMessage!['content'] ?? '',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _replies.isEmpty
                    ? const Center(
                        child: Text(
                          'No replies yet',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _replies.length,
                        itemBuilder: (context, index) {
                          final reply = _replies[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary.withAlpha(30),
                                  child: Text(
                                    (reply['sender_name'] as String? ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reply['sender_name'] ?? '',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        reply['content'] ?? '',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Reply in thread...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendReply,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
