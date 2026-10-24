import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/chunked_uploader.dart'
    show MediaTransferProgress;
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/ui/media_progress.dart';
import '../../../../shared/ui/media_viewer.dart';
import 'media_source_resolver.dart';

/// Playable image bubble.
///
/// Every image this app sends is chunked, and a chunked attachment has NO
/// public URL — its bytes live in `media_uploads` + `media_chunks`. This widget
/// therefore resolves through [MediaSourceResolver], which downloads the parts,
/// reassembles them, and verifies the whole-file digest before handing the
/// player a local file. Using `Image.network(attachment.url)` here showed an
/// empty bubble, because that URL is always null for real media.
class ImageMessage extends ConsumerStatefulWidget {
  const ImageMessage({super.key, required this.message});

  final ChatMessage message;

  @override
  ConsumerState<ImageMessage> createState() => _ImageMessageState();
}

class _ImageMessageState extends ConsumerState<ImageMessage> {
  static const _width = 260.0;
  static const _height = 210.0;

  File? _file;
  bool _downloading = false;
  double _fraction = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  /// The list is virtualised and a bubble can be recycled onto a different
  /// message, so a changed id has to re-resolve. Without this the bubble would
  /// keep showing the previous image.
  @override
  void didUpdateWidget(covariant ImageMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _file = null;
      _failed = false;
      _fraction = 0;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final attachment = widget.message.attachment;
    if (attachment == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (attachment.isChunked && mounted) {
      setState(() => _downloading = true);
    }

    try {
      final source = await MediaSourceResolver.resolve(
        ref,
        attachment,
        onProgress: attachment.isChunked
            ? (MediaTransferProgress p) {
                if (!mounted) return;
                // `fraction` is nullable because progress can be reported before
                // a total is known; a null there must not overwrite a real value.
                final value = p.fraction;
                if (value == null) return;
                setState(() => _fraction = value);
              }
            : null,
      );
      if (!mounted) return;

      // A remote URL renders directly; a chunked attachment resolved to a local
      // file, which is what the checksum was verified against.
      if (source.startsWith('http')) {
        if (!mounted) return;
        setState(() {
          _file = null;
          _downloading = false;
        });
        return;
      }
      setState(() {
        _file = File(source);
        _downloading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attachment = widget.message.attachment;
    final remoteUrl = attachment?.url;

    if (_failed) {
      return SizedBox(
        width: _width,
        height: _height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _failed = false;
                    _fraction = 0;
                  });
                  _resolve();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_downloading) {
      return SizedBox(
        width: _width,
        height: _height,
        child: Container(
          color: Colors.black26,
          child: Center(
            child: MediaProgressButton(
              state: MediaTransferState.transferring,
              progress: _fraction,
              onTap: () {},
              size: 48,
              showStopGlyph: false,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      // Tap opens the full-screen viewer. Before this the thumbnail was
      // inert: there was no way to see a photo at full size short of saving
      // it and opening a gallery app.
      child: GestureDetector(
        onTap: _file == null ? null : () => _openViewer(context),
        child: _file != null
            ? Image.file(
                _file!,
                width: _width,
                height: _height,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _Broken(),
              )
            : Image.network(
                remoteUrl!,
                width: _width,
                height: _height,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        width: _width,
                        height: _height,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (_, _, _) => const _Broken(),
              ),
      ),
    );
  }

  /// Opens the full-screen viewer, scoped to just this photo.
  ///
  /// A single-item viewer rather than the whole thread: swiping between images
  /// needs the neighbouring messages, which this widget does not have. The chat
  /// page owns that and opens a run of media instead.
  void _openViewer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MediaViewerPage(messages: [widget.message], initialIndex: 0),
      ),
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 210,
      child: Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
