import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/ui/glass.dart';
import '../../../../shared/ui/media_progress.dart';
import 'voice_message.dart';
import 'video_message.dart';
import 'image_message.dart';
import 'forward_picker.dart';
import 'media_actions_sheet.dart';
import 'link_preview_card.dart';

const kQuickReactions = [
  '\u2764\ufe0f',
  '\ud83d\udc4d',
  '\ud83d\ude02',
  '\ud83d\ude10',
  '\ud83d\ude2e',
  '\ud83d\ude4f',
];

/// A single chat bubble rendered with Messenger-style sequence geometry.
///
/// Rows that share a sender and are close in time are grouped into a "run":
///  - interior bubbles hug their siblings (radius 16 on every side),
///  - the last bubble of a run owns the timestamp/status metadata,
///  - reaction chips hang below the bubble and toggle on tap.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.previous,
    this.next,
    this.peer,
    this.myUserId,
    this.onReact,
    this.onRetry,
    this.onReply,
    this.repliedTo,
    this.onEdit,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  final ChatMessage message;
  final ChatMessage? previous;
  final ChatMessage? next;
  final UserProfile? peer;
  final String? myUserId;
  final void Function(String messageId, String? emoji)? onReact;
  final VoidCallback? onRetry;

  /// Rewrites this message's text in place. Offered only for a text message the
  /// current user sent, because editing someone else's message is not a thing
  /// this product does.
  final VoidCallback? onEdit;

  /// Hides the message on this device only. No server contact.
  final VoidCallback? onDeleteForMe;

  /// Removes the message for every participant. Server-authorized and
  /// tombstoned; offered only when the current user sent it, or while the
  /// server's age policy would still allow it.
  final VoidCallback? onDeleteForEveryone;

  /// "Forwarded" marker above a forwarded message's content.
  ///
  /// Present on the receiver's side as well as the sender's: the point of the
  /// label is that someone who did not create the photo can see it is not
  /// original. Without it a forwarded image is indistinguishable from one the
  /// recipient believes was sent to them directly.
  Widget _forwardedLabel(Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forward,
            size: 12,
            color: textColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            'Forwarded',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// True when this bubble is wrapping media rather than text.
  ///
  /// An attachment is identified by being non-null, NOT by having a `url`:
  /// every media this app sends is chunked, and a chunked attachment
  /// deliberately has no public URL (its bytes live in `media_uploads` +
  /// `media_chunks` and are resolved on demand). Testing `url != null` made
  /// every media branch below permanently false, so images, voice notes and
  /// videos rendered as empty bubbles for both sender and receiver.
  bool get _hasAttachment {
    final attachment = message.attachment;
    return attachment != null &&
        (attachment.url?.isNotEmpty ??
            false || attachment.uploadId?.isNotEmpty == true);
  }

  /// The message this one replies to.
  ///
  /// Supplied by the caller because a reply can point at anything in the
  /// thread, not just an adjacent bubble. Null when the target is not loaded
  /// (an old message scrolled out of the local window), which is handled by
  /// rendering the quote from the id alone rather than showing nothing.
  final ChatMessage? repliedTo;

  /// Enters reply mode for this message. Null hides the action.
  final VoidCallback? onReply;

  /// The quoted reply target, rendered above the bubble's own content.
  Widget _quoteOf(BuildContext context, ChatMessage target) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _outgoing
        ? colorScheme.onPrimaryContainer
        : colorScheme.primary;

    final preview = target.body?.trim().isNotEmpty == true
        ? target.body!.trim()
        : switch (target.type) {
            'image' => '📷 Photo',
            'video' => '🎥 Video',
            'voice' => '🎤 Voice note',
            _ => '📎 Attachment',
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: accent,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  static const _runGap = Duration(minutes: 15);

  bool get _outgoing => message.outgoing;
  bool get _isDeleted => message.deleted;
  bool get _isFailed => message.localState == MessageLocalState.failed;

  bool _sameRun(ChatMessage? other) =>
      other != null &&
      other.senderId == message.senderId &&
      message.createdAt.difference(other.createdAt).abs() < _runGap;

  bool get _firstInRun => !_sameRun(previous);
  bool get _lastInRun => !_sameRun(next);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = _outgoing
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: _firstInRun ? 5 : 1,
      ),
      child: Row(
        mainAxisAlignment: _outgoing
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: _outgoing
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 200 && onReply != null) {
                      onReply!();
                    }
                  },
                  onLongPress: () => _showActions(context),
                  child: CrystalBubble(
                    outgoing: _outgoing,
                    isFailed: _isFailed,
                    tail: _lastInRun,
                    hasAttachment: _hasAttachment,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _hasAttachment ? 4 : 14,
                        vertical: _hasAttachment ? 4 : 10,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.forwarded) _forwardedLabel(textColor),
                            if (repliedTo != null)
                              _quoteOf(context, repliedTo!),
                            // Media carries its own transfer ring, overlaid on
                            // the media itself so the user can see what they
                            // sent or are about to receive while it moves.
                            // Works for the sender's upload and the receiver's
                            // download from one widget, because both publish
                            // into the same process-wide tracker.
                            if (_hasAttachment)
                              Stack(
                                children: [
                                  _content(context, textColor, colorScheme),
                                  Positioned.fill(
                                    child: Center(
                                      child: PendingTransferRing(
                                        message: message,
                                        size: 44,
                                        idleIcon: Icons.play_arrow,
                                        onTapIdle: null,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              _content(context, textColor, colorScheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Reaction chips hug the bubble tail.
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _reactionChips(context, colorScheme),
                  ),
                // Metadata is only shown on the last bubble of a run.
                if (_lastInRun)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFailed && onRetry != null)
                          InkWell(
                            onTap: onRetry,
                            child: Text(
                              'Failed - tap to retry',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.error,
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeLabel(message.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  // Keep the timestamp legible on both bubble
                                  // colours: dimmed on-surface for incoming,
                                  // dimmed on-container for outgoing.
                                  color: _outgoing
                                      ? colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.65)
                                      : colorScheme.outline,
                                ),
                              ),
                              // Marks a message the sender rewrote after it was
                              // sent. Rendered from the server's `edited_at`,
                              // so it survives a restart and a resync instead of
                              // being a transient local flag.
                              if (message.editedAt != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '· edited',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _outgoing
                                        ? colorScheme.onPrimaryContainer
                                              .withValues(alpha: 0.65)
                                        : colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(width: 5),
                        if (_outgoing) _statusIndicator(colorScheme),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionChips(BuildContext context, ColorScheme colorScheme) {
    final counts = message.reactionCounts();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: _outgoing ? WrapAlignment.end : WrapAlignment.start,
      children: [
        for (final entry in counts.entries)
          _ReactionChip(
            emoji: entry.key,
            count: entry.value,
            highlighted:
                myUserId != null && message.hasReacted(entry.key, myUserId!),
            colorScheme: colorScheme,
            onTap: () => onReact?.call(message.id, entry.key),
          ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    Color textColor,
    ColorScheme colorScheme,
  ) {
    if (_isDeleted) {
      return const Text(
        'This message was deleted',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    final children = <Widget>[];
    // An attachment is identified by being non-null, NOT by having a `url`.
    // Every media this app sends is chunked, and a chunked attachment
    // deliberately has no public URL (its bytes live in `media_uploads` +
    // `media_chunks` and are resolved on demand). Testing `url != null` made
    // these three branches permanently false, so images, voice notes and
    // videos rendered as an empty bubble for both sender and receiver.
    final attachment = message.attachment;
    final hasAttachment =
        attachment != null &&
        (attachment.url?.isNotEmpty ??
            false || attachment.uploadId?.isNotEmpty == true);

    if (message.type == 'image' && hasAttachment) {
      children.add(ImageMessage(key: ValueKey(message.id), message: message));
      if (message.body?.isNotEmpty == true) {
        children.add(const SizedBox(height: 6));
      }
    } else if (message.type == 'voice' && hasAttachment) {
      children.add(
        VoiceMessage(
          key: ValueKey(message.id),
          message: message,
          textColor: textColor,
        ),
      );
    } else if (message.type == 'video' && hasAttachment) {
      children.add(
        VideoMessage(
          key: ValueKey(message.id),
          message: message,
          textColor: textColor,
        ),
      );
      if (message.body?.isNotEmpty == true) {
        children.add(const SizedBox(height: 6));
      }
    } else if (message.type == 'file' && attachment != null) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 32),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.attachment!.name ?? 'File',
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      if (message.body?.isNotEmpty == true) {
        children.add(const SizedBox(height: 6));
      }
    }
    if (message.body?.isNotEmpty == true) {
      children.add(Text(message.body!, style: TextStyle(color: textColor)));
      final urlMatch = RegExp(
        r'https?://[^\s]+',
        caseSensitive: false,
      ).firstMatch(message.body!);
      if (urlMatch != null) {
        final url = urlMatch.group(0);
        if (url != null) {
          children.add(
            LinkPreviewCard(
              url: url,
              textColor: textColor,
              colorScheme: colorScheme,
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  void _showActions(BuildContext context) {
    final copyable = message.body?.trim().isNotEmpty == true;
    final reactable =
        onReact != null &&
        !_isDeleted &&
        message.localState != MessageLocalState.failed;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reactable)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    for (final emoji in kQuickReactions)
                      _ReactionChip(
                        emoji: emoji,
                        count:
                            myUserId != null &&
                                message.hasReacted(emoji, myUserId!)
                            ? 1
                            : 0,
                        highlighted:
                            myUserId != null &&
                            message.hasReacted(emoji, myUserId!),
                        colorScheme: Theme.of(sheetContext).colorScheme,
                        size: 34,
                        onTap: () {
                          final already =
                              myUserId != null &&
                              message.hasReacted(emoji, myUserId!);
                          Navigator.of(sheetContext).pop();
                          onReact?.call(message.id, already ? null : emoji);
                        },
                      ),
                  ],
                ),
              ),
            if (onReply != null && !_isDeleted)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onReply!();
                },
              ),
            if (copyable)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: message.body!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                },
              ),
            // Media gets save/share/forward, which reassemble the attachment
            // locally first so the whole file is what leaves the device.
            if (message.isMedia && !_isDeleted)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Save, share or forward'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  MediaActionsSheet.show(
                    context,
                    message: message,
                    onForward: (msg, _) {
                      showForwardPicker(context, message: msg);
                    },
                  );
                },
              ),
            // Text can be forwarded too. The picker handles a message with no
            // attachment, but nothing ever routed a text message to it: the
            // forward entry was gated on `isMedia` and the picker itself
            // returned early when the attachment was null, so there was no way
            // to forward a sentence.
            if (copyable && !message.isMedia)
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showForwardPicker(context, message: message);
                },
              ),
            // Editing is offered only for a text message the current user sent,
            // because "edit" on somebody else's message is not a thing this
            // product does, and offering it would just fail server-side.
            if (onEdit != null && copyable && !message.isMedia && !_isDeleted)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit!();
                },
              ),
            if (onDeleteForMe != null && !_isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                subtitle: const Text('Only removes it on this device'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDeleteForMe!();
                },
              ),
            if (onDeleteForEveryone != null && !_isDeleted)
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Delete for everyone',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                subtitle: const Text(
                  'Removes it for both of you. It cannot be recalled from a '
                  'screenshot or a notification already shown.',
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDeleteForEveryone!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Delivery indicator on outgoing messages.
  ///
  /// Four genuinely different states, with four different glyphs rather than
  /// three states in two colours. The previous mapping sent both "sent" and
  /// "delivered" to the same orange dot, which made the indicator incapable of
  /// distinguishing "the server has it" from "a person has it" — exactly the
  /// distinction the product promises and exactly the one that matters when a
  /// user asks whether someone has seen a message.
  ///
  /// | glyph  | meaning                                                        |
  /// |--------|----------------------------------------------------------------|
  /// | clock  | saved on this device, upload not attempted yet                |
  /// | red !  | retry budget spent; tapping the row re-queues it               |
  /// | one ✓  | the server durably accepted it                                 |
  /// | two ✓✓ | a recipient device committed it and acknowledged (delivered)   |
  /// | blue ✓✓ | a person read it (read receipts enabled)                      |
  ///
  /// The label is exposed to screen readers, because a bare coloured glyph is
  /// invisible to a screen reader and unreadable to a red/green colourblind
  /// user.
  Widget _statusIndicator(ColorScheme colorScheme) {
    if (!message.outgoing) return const SizedBox.shrink();

    if (_isFailed) {
      return _statusDotWidget(
        icon: Icons.priority_high,
        color: Colors.red,
        semanticLabel: 'Message failed to send. Tap to retry.',
      );
    }

    if (message.localState == MessageLocalState.queued ||
        message.localState == MessageLocalState.sending ||
        message.localState == MessageLocalState.local) {
      return _statusDotWidget(
        icon: Icons.schedule,
        color: colorScheme.onSurfaceVariant,
        semanticLabel: 'Waiting to send',
      );
    }

    switch (message.remoteStatus) {
      case RemoteStatus.seen:
        return _statusDotWidget(
          icon: Icons.done_all,
          color: const Color(0xFF53BDEB),
          semanticLabel: 'Read',
        );
      case RemoteStatus.delivered:
        return _statusDotWidget(
          icon: Icons.done_all,
          color: colorScheme.onSurfaceVariant,
          semanticLabel: 'Delivered',
        );
      case RemoteStatus.sent:
        return _statusDotWidget(
          icon: Icons.done,
          color: colorScheme.onSurfaceVariant,
          semanticLabel: 'Sent',
        );
    }
  }

  /// One receipt glyph, with its meaning attached for assistive tech.
  Widget _statusDotWidget({
    required IconData icon,
    required Color color,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: Icon(icon, size: 15, color: color)),
    );
  }

  String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (today == day) return '$hh:$mm';
    return '${time.day}/${time.month}/${time.year} $hh:$mm';
  }
}

class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.highlighted,
    required this.colorScheme,
    this.onTap,
    this.size = 26,
  });

  final String emoji;
  final int count;
  final bool highlighted;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final double size;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _pop,
    curve: Curves.easeOutBack,
  );

  @override
  void didUpdateWidget(_ReactionChip old) {
    super.didUpdateWidget(old);
    // Pop the chip when it becomes "mine" so the reaction feels instant.
    if (widget.highlighted && !old.highlighted) {
      _pop.forward(from: 0.55);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.highlighted;
    final colorScheme = widget.colorScheme;
    final background = highlighted
        ? colorScheme.primary.withValues(alpha: 0.28)
        : colorScheme.surfaceContainerHighest;

    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: highlighted
                  ? Border.all(color: colorScheme.primary, width: 0.8)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.emoji,
                  style: TextStyle(fontSize: widget.size * 0.62),
                ),
                if (widget.count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: highlighted
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
