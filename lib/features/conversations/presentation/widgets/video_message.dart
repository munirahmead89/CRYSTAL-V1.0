import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/media/chunked_uploader.dart';
import '../../../../core/media/transfer_progress.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/ui/media_progress.dart';
import 'media_source_resolver.dart';

/// Playable video bubble.
///
/// Chunked media is reassembled locally before playback, so a multi-gigabyte
/// clip is never handed to the player as a partial stream. While the parts are
/// arriving the bubble shows real progress rather than an indefinite spinner.
class VideoMessage extends ConsumerStatefulWidget {
  const VideoMessage({
    super.key,
    required this.message,
    required this.textColor,
  });

  final ChatMessage message;
  final Color textColor;

  @override
  ConsumerState<VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends ConsumerState<VideoMessage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _initialized = false;
  bool _error = false;
  bool _downloading = false;
  double? _fraction;
  String? _errorMessage;
  String? _downloadDetail;

  /// Smooths download throughput so the ETA is stable across parts.
  final _speed = TransferSpeedEstimator();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final attachment = widget.message.attachment;
    if (attachment == null) {
      if (mounted) setState(() => _error = true);
      return;
    }

    try {
      final attachmentIsChunked = attachment.isChunked;
      if (attachmentIsChunked && mounted) {
        setState(() {
          _downloading = true;
          _fraction = 0;
        });
      }

      // Chunked media resolves to a verified local file; legacy media keeps
      // its URL. Either way the player gets one consistent source.
      final source = await MediaSourceResolver.resolve(
        ref,
        attachment,
        onProgress: attachmentIsChunked
            ? (MediaTransferProgress p) {
                if (!mounted) return;
                final speed = _speed.update(p.bytesTransferred, DateTime.now());
                setState(() {
                  _fraction = p.fraction;
                  _downloadDetail = [
                    'of ${formatBytes(p.totalBytes)}',
                    if (speed > 1) '${formatBytes(speed.round())}/s',
                    if (_etaLabel(p, speed) != null) _etaLabel(p, speed)!,
                  ].join(' • ');
                });
              }
            : null,
      );
      if (!mounted) return;

      if (source.startsWith('http')) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(source),
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(File(source));
      }

      await _videoPlayerController!.initialize();
      if (!mounted) {
        await _videoPlayerController!.dispose();
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        showControlsOnInitialize: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return const Center(child: Icon(Icons.error, color: Colors.white));
        },
      );
      if (mounted) {
        setState(() {
          _initialized = true;
          _downloading = false;
        });
      }
    } on MediaTransferException catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _downloading = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _downloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  /// "3m 12s left", or null when the speed is not yet trustworthy.
  ///
  /// Returning null on the first samples is deliberate: a countdown derived
  /// from one noisy reading is a promise the user watches break.
  String? _etaLabel(MediaTransferProgress p, double speed) {
    if (speed < 1) return null;
    final remaining = p.totalBytes - p.bytesTransferred;
    if (remaining <= 0) return null;
    final seconds = remaining / speed;
    if (seconds.isNaN || seconds.isInfinite || seconds > 86400) return null;
    return '${formatDuration(Duration(milliseconds: (seconds * 1000).round()))} left';
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        width: 260,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.grey),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 220,
            constraints: const BoxConstraints(maxHeight: 300),
            color: Colors.black,
            child: _initialized && _chewieController != null
                ? AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                : SizedBox(
                    width: 220,
                    height: 140,
                    child: Center(
                      child: _downloading
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MediaProgressButton(
                                  state: MediaTransferState.transferring,
                                  progress: _fraction ?? 0.0,
                                  onTap: () {},
                                  size: 48,
                                  showStopGlyph: false,
                                ),
                                if (_downloadDetail != null) ...[
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      _downloadDetail!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
