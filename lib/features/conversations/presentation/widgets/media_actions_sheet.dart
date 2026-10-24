import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/media/chunked_uploader.dart';
import '../../../../core/media/media_actions.dart';
import '../../../../core/media/media_providers.dart';
import '../../../../shared/models/chat_message.dart';

/// Actions offered when a media bubble is long-pressed.
///
/// Every action resolves the attachment to a complete local file first, so
/// "Save" and "Share" always operate on the whole file, never on a partial
/// download.
class MediaActionsSheet extends ConsumerStatefulWidget {
  const MediaActionsSheet({super.key, required this.message, this.onForward});

  final ChatMessage message;

  /// Optional hook so the host can start a "Forward to…" picker.
  final void Function(ChatMessage message, String localPath)? onForward;

  static Future<void> show(
    BuildContext context, {
    required ChatMessage message,
    void Function(ChatMessage message, String localPath)? onForward,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MediaActionsSheet(message: message, onForward: onForward),
    );
  }

  @override
  ConsumerState<MediaActionsSheet> createState() => _MediaActionsSheetState();
}

class _MediaActionsSheetState extends ConsumerState<MediaActionsSheet> {
  bool _busy = false;
  double? _fraction;
  String? _status;

  Attachment? get _attachment => widget.message.attachment;

  @override
  Widget build(BuildContext context) {
    final attachment = _attachment;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                attachment?.name ?? 'Attachment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _humanSize(attachment?.sizeBytes ?? 0),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (_busy) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _fraction, minHeight: 4),
                    const SizedBox(height: 4),
                    Text(
                      _status ?? 'Preparing…',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Save to Downloads'),
                onTap: () => _run(_save),
              ),
            if (!_busy)
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Share'),
                onTap: () => _run(_share),
              ),
            if (!_busy && widget.onForward != null)
              ListTile(
                leading: const Icon(Icons.forward_to_inbox_outlined),
                title: const Text('Forward'),
                onTap: () => _run(_forward),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(
    Future<void> Function(Attachment a, String path) action,
  ) async {
    final attachment = _attachment;
    if (attachment == null || _busy) return;

    setState(() {
      _busy = true;
      _fraction = 0;
      _status = 'Downloading…';
    });

    try {
      // Resolve once; every action reuses the same verified local file.
      final service = await ref.read(mediaTransferServiceProvider.future);
      final resolved = await service.resolve(
        attachment,
        onProgress: (MediaTransferProgress p) {
          if (mounted) setState(() => _fraction = p.fraction);
        },
      );
      if (!mounted) return;
      if (mounted) setState(() => _status = 'Ready');
      await action(attachment, resolved.path);
    } on MediaQuotaException catch (e) {
      if (mounted) _toast(context, e.message);
    } on MediaTransferException catch (e) {
      if (mounted) _toast(context, e.message);
    } catch (e) {
      if (mounted) _toast(context, 'That did not work. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _fraction = null;
          _status = null;
        });
      }
    }
  }

  Future<void> _save(Attachment attachment, String path) async {
    final name = MediaActions.downloadName(
      name: attachment.name ?? 'file',
      uploadId: attachment.uploadId ?? 'media',
    );
    final uri = await MediaActions.saveToDownloads(
      File(path),
      displayName: name,
      mimeType: attachment.mimeType,
    );
    if (mounted) {
      _toast(context, 'Saved $name');
      // ignore: avoid_print
      debugPrint('Saved to $uri');
    }
  }

  Future<void> _share(Attachment attachment, String path) async {
    await MediaActions.share(
      File(path),
      text: widget.message.body ?? '',
      mimeType: attachment.mimeType,
      subject: attachment.name,
    );
  }

  Future<void> _forward(Attachment attachment, String path) async {
    final handler = widget.onForward;
    if (handler == null) return;
    handler(widget.message, path);
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _humanSize(int bytes) {
    if (bytes <= 0) return 'Size unknown';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value < 10 && unit > 0 ? 1 : 0)} ${units[unit]}';
  }
}
