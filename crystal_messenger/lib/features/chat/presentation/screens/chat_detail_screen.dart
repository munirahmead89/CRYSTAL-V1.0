import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../providers/message_provider.dart';
import '../providers/chat_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/media_message_bubble.dart';
import '../widgets/voice_recorder_sheet.dart';
import '../providers/message_actions_provider.dart';
import '../../data/repositories/media_repository.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatDetailScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _replyToId;
  String? _replyToContent;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageListProvider(widget.chatId));
    final activeChat = ref.watch(activeChatProvider);
    final isTyping = activeChat.typingUserIds.isNotEmpty;
    final chats = ref.watch(chatListProvider).chats;
    final thisChat = chats.where((c) => c['id'] == widget.chatId).firstOrNull;
    final chatName = _chatName(thisChat ?? const {'type': ''});

    ref.listen<ActiveChatState>(activeChatProvider, (prev, next) {
      if (next.chatId == widget.chatId && next.typingUserIds.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => context.push('/chat/${widget.chatId}/info'),
          child: Row(
            children: [
              const AppAvatar(size: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (isTyping)
                    const Text(
                      'typing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.typingIndicator,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => context.push('/chat/${widget.chatId}/info'),
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () => context.push('/chat/${widget.chatId}/info'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.surfaceBright,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'view', child: Text('View contact')),
              const PopupMenuItem(value: 'media', child: Text('Media, links, and docs')),
              const PopupMenuItem(value: 'search', child: Text('Search')),
              const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
              const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
              const PopupMenuItem(value: 'delete', child: Text('Delete chat')),
            ],
            onSelected: (v) {
              if (v == 'search') context.push('/chat/${widget.chatId}/search');
              if (v == 'view') context.push('/chat/${widget.chatId}/info');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messages.isLoading && messages.messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: messages.messages.length + (messages.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && messages.hasMore) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }

                      final msgIndex = messages.hasMore ? index - 1 : index;
                      if (msgIndex < 0 || msgIndex >= messages.messages.length) {
                        return const SizedBox.shrink();
                      }

                      final message = messages.messages[msgIndex];
                      final isMe = message['sender_id'] ==
                          ref.read(supabaseClientProvider).auth.currentUser?.id;

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        onReply: () => _startReply(
                          message['id'],
                          message['content'] ?? '',
                        ),
                        onDelete: () => _deleteMessage(message['id']),
                        onForward: () => _pickForwardTarget(message['id']),
                        onTapMedia: () {
                          if ((message['message_type'] ?? 'text') == 'video') {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => VideoPlayerSheet(reference: message['content'] ?? ''),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),

          // Reply preview
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Container(width: 3, height: 30, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Replying',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _replyToContent ?? '',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
                    onPressed: () => setState(() {
                      _replyToId = null;
                      _replyToContent = null;
                    }),
                  ),
                ],
              ),
            ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 5,
                        minLines: 1,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty) {
                            ref.read(typingProvider(widget.chatId).notifier).startTyping();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => MediaPickerSheet(
                          chatId: widget.chatId,
                          replyToId: _replyToId,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _messageController.text.isEmpty
                      ? IconButton(
                          icon: const Icon(Icons.mic_none, color: AppColors.textSecondary),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => VoiceRecorderSheet(
                                onRecorded: (path) async {
                                  final repo = ref.read(mediaRepositoryProvider);
                                  final reference = await repo.uploadVoiceNote(File(path));
                                  await ref
                                      .read(messageListProvider(widget.chatId).notifier)
                                      .sendMessage(
                                        content: reference,
                                        messageType: 'audio',
                                        replyToId: _replyToId,
                                        metadata: {'duration': 0},
                                      );
                                },
                              ),
                            );
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primary),
                          onPressed: _sendMessage,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startReply(String messageId, String content) {
    setState(() {
      _replyToId = messageId;
      _replyToContent = content;
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(messageListProvider(widget.chatId).notifier).sendMessage(
          content: text,
          replyToId: _replyToId,
        );

    _messageController.clear();
    setState(() {
      _replyToId = null;
      _replyToContent = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _deleteMessage(String messageId) {
    ref.read(messageListProvider(widget.chatId).notifier).deleteMessage(messageId);
  }

  void _pickForwardTarget(String messageId) {
    final chats = ref.read(chatListProvider).chats;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Forward to', style: TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final name = _chatName(chat);
                  final chatId = chat['id'] as String;
                  return ListTile(
                    leading: const Icon(Icons.chat, color: AppColors.primary),
                    title: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () async {
                      Navigator.pop(context);
                      await forwardMessage(ref, messageId, chatId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Forwarded to $name')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _chatName(Map<String, dynamic> c) {
    if (c['type'] == 'group' || c['type'] == 'broadcast') return c['name'] ?? 'Group';
    return (c['other_participant'] as Map?)?['full_name'] ?? 'Unknown';
  }
}

