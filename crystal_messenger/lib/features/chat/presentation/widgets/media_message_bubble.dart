import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/media/media_url_resolver.dart';

class MediaMessageBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onTap;

  const MediaMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(mediaUrlResolverProvider);
    final reference = message['content'] as String? ?? '';
    final type = message['message_type'] as String? ?? 'image';

    return FutureBuilder<String>(
      future: resolver.resolve(reference),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 220,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          );
        }
        final url = snapshot.data!;
        if (type == 'video') {
          return _VideoThumb(url: url, onTap: onTap);
        }
        return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 220,
                height: 220,
                color: AppColors.surfaceVariant,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 220,
                height: 220,
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.broken_image, color: AppColors.textTertiary),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;
  const _VideoThumb({required this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 240,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 240, height: 200, color: AppColors.surfaceVariant,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerSheet extends ConsumerStatefulWidget {
  final String reference;
  const VideoPlayerSheet({super.key, required this.reference});

  @override
  ConsumerState<VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends ConsumerState<VideoPlayerSheet> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final resolver = ref.read(mediaUrlResolverProvider);
    final url = await resolver.resolve(widget.reference);
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    _chewie = ChewieController(
      videoPlayerController: _controller!,
      autoPlay: true,
      looping: false,
    );
    setState(() {});
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: const BackButton(color: Colors.white)),
      body: Center(
        child: _chewie != null
            ? Chewie(controller: _chewie!)
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
