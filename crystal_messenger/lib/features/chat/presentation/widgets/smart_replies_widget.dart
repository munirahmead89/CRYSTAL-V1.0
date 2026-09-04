import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';

class SmartRepliesWidget extends ConsumerStatefulWidget {
  final String chatId;
  final Function(String) onReplySelected;
  const SmartRepliesWidget({
    super.key,
    required this.chatId,
    required this.onReplySelected,
  });

  @override
  ConsumerState<SmartRepliesWidget> createState() => _SmartRepliesWidgetState();
}

class _SmartRepliesWidgetState extends ConsumerState<SmartRepliesWidget> {
  List<String> _replies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReplies();
  }

  @override
  void didUpdateWidget(SmartRepliesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      _fetchReplies();
    }
  }

  Future<void> _fetchReplies() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.functions.invoke('smart-replies', body: {
        'chat_id': widget.chatId,
      });

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _replies = (data['replies'] as List?)
                  ?.map((r) => r.toString())
                  .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _replies = ['👍', 'OK', 'Got it', 'Thanks!'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    if (_replies.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final reply = _replies[index];
          final isEmoji = reply.length <= 2 || _isEmojiOnly(reply);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onReplySelected(reply);
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isEmoji ? 12 : 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  reply,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isEmoji ? 18 : 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isEmojiOnly(String text) {
    final emojiRegex = RegExp(
      r'^[\p{Emoji_Presentation}\p{Emoji}\uFE0F\u200D\u20E3]+$',
      unicode: true,
    );
    return emojiRegex.hasMatch(text.trim());
  }
}
