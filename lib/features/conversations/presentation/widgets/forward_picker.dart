import 'dart:async';

import 'package:crystal_messenger/features/conversations/application/forward_media_service.dart';
import 'package:crystal_messenger/features/conversations/presentation/providers/chat_providers.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:crystal_messenger/shared/models/conversation.dart';
import 'package:crystal_messenger/shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_provider/image_provider.dart' as img;

/// "Forward to…" — pick one or more conversations for [message].
///
/// Reached from the message action sheet.
///
/// Supports forwarding text as well as media. The old version returned early
/// when `attachment == null`, and the bubble's long-press menu only offered
/// the action for media, so a text message simply could not be forwarded.
///
/// Several chats can be selected at once, which is the common case: forwarding
/// the same thing to a group and two people is one action, not three.
Future<void> showForwardPicker(
  BuildContext context, {
  required ChatMessage message,
}) async {
  final attachment = message.attachment;
  final text = message.body?.trim() ?? '';
  // Nothing to forward: a message with neither media nor text would produce an
  // empty bubble in the destination.
  if (attachment == null && text.isEmpty) return;

  final sourceId = message.conversationId;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  // No WidgetRef here: the call site is a StatefulWidget. Reading the provider
  // through the scope container is the supported way to reach it from a plain
  // BuildContext.
  final container = ProviderScope.containerOf(context);
  final service = container.read(forwardMediaServiceProvider);

  final targets = await showModalBottomSheet<List<ConversationSummary>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ForwardTargetList(
      excludeConversationId: sourceId,
      title: attachment?.name ?? (text.isEmpty ? 'message' : text),
    ),
  );

  if (targets == null || targets.isEmpty) return;

  try {
    final result = await service.forwardToMany(
      targetConversationIds: targets.map((t) => t.id).toList(),
      sourceConversationId: sourceId,
      attachment: attachment,
      body: attachment != null && text.isNotEmpty ? text : null,
    );

    final names = result.queued
        .map((id) => targets.firstWhere((t) => t.id == id).title)
        .join(', ');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.allSucceeded
                ? (result.queued.length == 1
                      ? 'Forwarded to $names'
                      : 'Forwarded to ${result.queued.length} chats')
                : 'Forwarded to ${result.queued.length} of '
                      '${result.queued.length + result.failures.length} chats',
          ),
        ),
      );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Could not forward: $e')));
  }

  // Leave the media sheet, which is still open underneath.
  if (navigator.canPop()) navigator.pop();
}

/// Multi-select list of conversations.
///
/// Tapping toggles a selection; the sheet closes from the Send button. Closing
/// on tap - the previous behaviour - makes forwarding to more than one chat
/// impossible without re-opening the picker for each.
class _ForwardTargetList extends ConsumerStatefulWidget {
  const _ForwardTargetList({
    required this.excludeConversationId,
    required this.title,
  });

  final String excludeConversationId;
  final String title;

  @override
  ConsumerState<_ForwardTargetList> createState() => _ForwardTargetListState();
}

class _ForwardTargetListState extends ConsumerState<_ForwardTargetList> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chats = ref.watch(chatListProvider).valueOrNull ?? const [];

    final targets = chats
        .where((c) => c.id != widget.excludeConversationId)
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Forward',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 24,
                ),
                child: Text(
                  'No other chats yet. Start a conversation first, then forward '
                  'to it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (context, i) {
                    final chat = targets[i];
                    final peer = chat.peer;
                    final selected = _selected.contains(chat.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => setState(() {
                        if (selected) {
                          _selected.remove(chat.id);
                        } else {
                          _selected.add(chat.id);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: UserAvatar(profile: peer, radius: 22),
                      title: Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Select one or more chats'
                          : '${_selected.length} selected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final ids = _selected.toSet();
                            final picked = targets
                                .where((t) => ids.contains(t.id))
                                .toList();
                            Navigator.of(context).pop(picked);
                          },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
