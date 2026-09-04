import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/widgets/message_status_light.dart';
import '../providers/reactions_provider.dart';
import '../providers/starred_provider.dart';
import 'media_message_bubble.dart';
import 'voice_note_bubble.dart';

class MessageBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;
  final VoidCallback? onTapMedia;
  final VoidCallback? onThread;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onDelete,
    this.onForward,
    this.onTapMedia,
    this.onThread,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = message['message_type'] as String? ?? 'text';
    final content = message['content'] as String?;
    final createdAt = message['created_at'] != null ? DateTime.tryParse(message['created_at']) : null;
    final isDeleted = message['is_deleted'] == true;
    final replyTo = message['reply_to'] as Map<String, dynamic>?;
    final hasRead = message['read_at'] != null;
    final hasDelivered = message['delivered_at'] != null;

    final trafficLight = isMe
        ? (hasRead
            ? MessageTrafficLight.viewed
            : hasDelivered
                ? MessageTrafficLight.delivered
                : MessageTrafficLight.sent)
        : null;
    final messageId = message['id'] as String;
    final reactions = ref.watch(reactionsProvider(messageId));
    final starred = ref.watch(messageStarredProvider(messageId));

    final bubbleColor = isMe ? AppColors.chatBubbleOutgoing : AppColors.chatBubbleIncoming;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context, ref, messageId, starred),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMe ? 12 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyTo != null && replyTo['content'] != null) _ReplyPreview(replyTo: replyTo, isMe: isMe),
                    if (isDeleted)
                      const Text('This message was deleted', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))
                    else if (type == 'image' || type == 'video')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: MediaMessageBubble(message: message, isMe: isMe, onTap: onTapMedia),
                      )
                    else if (type == 'audio')
                      VoiceNoteBubble(message: message, isMe: isMe)
                    else if (type == 'file')
                      _FileBubble(message: message, reference: content ?? '')
                    else if (content != null)
                      Text(content, style: TextStyle(color: isMe ? AppColors.chatTextOutgoing : AppColors.chatTextIncoming, fontSize: 16)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (createdAt != null)
                          Text(DateFormat('HH:mm').format(createdAt), style: TextStyle(fontSize: 11, color: isMe ? Colors.white54 : AppColors.textTertiary)),
                        if (trafficLight != null) ...[
                          const SizedBox(width: 4),
                          MessageStatusLight(status: trafficLight),
                        ],
                        if (starred) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 12, color: Colors.white54),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (reactions.groups.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final mine = reactions.groups.where((g) => g.reactedByMe);
                    if (mine.isNotEmpty) {
                      ref.read(reactionsProvider(messageId).notifier).toggle(mine.first.emoji);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBright,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions.groups
                          .map((g) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text('${g.emoji} ${g.count}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, String messageId, bool starred) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(reactionsProvider(messageId).notifier).toggle(emojis[i]);
                  },
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(emojis[i], style: const TextStyle(fontSize: 26))),
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemCount: emojis.length,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.textPrimary),
              title: const Text('Reply'),
              onTap: () { Navigator.pop(context); onReply?.call(); },
            ),
            ListTile(
              leading: Icon(starred ? Icons.star : Icons.star_border, color: AppColors.textPrimary),
              title: Text(starred ? 'Unstar' : 'Star'),
              onTap: () { Navigator.pop(context); toggleStar(ref, messageId); },
            ),
            ListTile(
              leading: const Icon(Icons.forward, color: AppColors.textPrimary),
              title: const Text('Forward'),
              onTap: () { Navigator.pop(context); onForward?.call(); },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textPrimary),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                final text = message['content'] ?? '';
                if (text.isNotEmpty) FlutterClipboard.copy(text);
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete for everyone', style: TextStyle(color: AppColors.error)),
                onTap: () { Navigator.pop(context); onDelete?.call(); },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final bool isMe;
  const _ReplyPreview({required this.replyTo, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replyTo['sender_id'] == null ? 'You' : 'They', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(replyTo['content'] ?? '', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _FileBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final String reference;
  const _FileBubble({required this.message, required this.reference});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = message['metadata'] as Map<String, dynamic>? ?? {};
    final fileName = metadata['file_name'] ?? 'File';
    final size = metadata['file_size'] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 36),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text(_formatSize(size), style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
