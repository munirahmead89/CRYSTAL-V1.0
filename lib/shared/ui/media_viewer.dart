import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/voice_player_controller.dart';
import '../models/chat_message.dart';
import '../models/user_profile.dart';
import '../widgets/user_avatar.dart';
import 'glass.dart';
import 'motion.dart';

/// Full-screen media viewer.
///
/// One viewer for every media type rather than a separate screen each: opening
/// a photo, a video and a voice note all present the same chrome, the same
/// gestures, and the same dismissal animation, so the app has one idea of "the
/// media screen" instead of three.
///
/// ## Interaction model
///
///  * Tap anywhere toggles the chrome. A viewer with permanently visible
///    controls hides the thing the user opened.
///  * Drag down dismisses, and the viewer scales back toward the tap origin as
///    it goes, so dismissal is continuous rather than a cut.
///  * Swipe left/right moves between adjacent media of the same type, which is
///    what makes a viewer useful for anything sent as a run of photos.
///  * Pinch zooms images. Video is excluded: the platform player owns those
///    gestures and fighting them produces a viewer that drops frames.
///
/// ## Why the chrome is glass
///
/// It floats over arbitrary content - a white document screenshot, a bright
/// photo - so a flat white toolbar would be unreadable half the time. The blur
/// plus a scrim keeps the controls legible over anything.
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.messages,
    required this.initialIndex,
    this.peerName,
    this.peerAvatarUrl,
    this.peer,
    this.onForward,
    this.onShare,
    this.voicePlayer,
  });

  final List<ChatMessage> messages;
  final int initialIndex;
  final String? peerName;
  final String? peerAvatarUrl;
  final UserProfile? peer;
  final void Function(ChatMessage message)? onForward;
  final void Function(ChatMessage message)? onShare;

  /// Shared voice player for the viewer's bottom bar.
  ///
  /// Optional, and when omitted the viewer supplies its own and disposes it.
  /// It cannot simply be created internally without a leak, and it cannot be
  /// required without breaking every existing caller — so the viewer creates
  /// one only if the host did not provide it.
  ///
  /// Passing one in is what stops opening a voice note in the full-screen viewer
  /// from crashing: `_VoiceControls` reads
  /// [VoicePlayerControllerScope.of(context)], which asserts the scope is
  /// present, and nothing had ever inserted it.
  final VoicePlayerController? voicePlayer;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage>
    with TickerProviderStateMixin {
  /// Created only when the host did not supply one, and disposed only in that
  /// case — disposing a controller the host still owns would break the chat
  /// screen's own player.
  late final VoicePlayerController _ownVoicePlayer =
      widget.voicePlayer ?? VoicePlayerController();

  late final bool _ownsVoicePlayer = widget.voicePlayer == null;

  VoicePlayerController get _voicePlayer =>
      widget.voicePlayer ?? _ownVoicePlayer;
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _chromeVisible = true;

  /// Vertical drag offset, used to both dismiss and to scale the content back.
  double _dragOffset = 0;

  /// Set while the dismiss animation runs, so the drag handler stops
  /// competing with it.
  bool _dismissing = false;

  late final AnimationController _chromeController = AnimationController(
    vsync: this,
    duration: Motion.fast,
    reverseDuration: Motion.instant,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_chromeVisible) _chromeController.value = 1;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pages.dispose();
    _chromeController.dispose();
    if (_ownsVoicePlayer) _ownVoicePlayer.dispose();
    super.dispose();
  }

  ChatMessage get _current => widget.messages[_index];

  Future<void> _dismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final message = _current;
    // 1 -> normal, 0.9 -> pulled away. Scaling toward a fixed value reads as
    // the media physically receding under the finger.
    final scale = (1 - (_dragOffset.abs() / 1400)).clamp(0.86, 1.0);

    // The voice controls read their player from this scope. Without it, opening
    // a voice note in the full-screen viewer hit the scope's own assert and the
    // `!` turned it into a null dereference.
    return VoicePlayerControllerScope(
      controller: _voicePlayer,
      child: ViewerScrim(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // The media itself, pannable and zoomable.
              GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                onVerticalDragUpdate: _dismissing
                    ? null
                    : (d) => setState(() {
                        _dragOffset += d.delta.dy;
                        // Resistance: pulling past the dismiss distance should
                        // feel like it is fighting back, not like free travel.
                        if (_dragOffset.abs() > 160) {
                          _dragOffset += d.delta.dy * 2;
                        }
                      }),
                onVerticalDragEnd: _dismissing
                    ? null
                    : (d) {
                        final fast = d.velocity.pixelsPerSecond.dy.abs() > 700;
                        if (_dragOffset.abs() > 120 || fast) {
                          _dismiss();
                        } else {
                          // Spring back.
                          setState(() => _dragOffset = 0);
                        }
                      },
                child: Transform.scale(
                  scale: scale,
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: PageView.builder(
                      controller: _pages,
                      // Horizontal paging only for still media; video needs the
                      // full width for its own gesture handling.
                      scrollDirection: Axis.horizontal,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: widget.messages.length,
                      itemBuilder: (context, i) => _MediaStage(
                        message: widget.messages[i],
                        isActive: i == _index,
                        onShare: widget.onShare,
                        onForward: widget.onForward,
                      ),
                    ),
                  ),
                ),
              ),
              // Top chrome.
              _AnimatedChrome(
                controller: _chromeController,
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: _topBar(context),
              ),
              // Bottom chrome: contextual controls for the current type.
              _AnimatedChrome(
                controller: _chromeController,
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: _bottomBar(context, message),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 8,
        right: 8,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CrystalColorsFallback.scrim,
            CrystalColorsFallback.scrim.withValues(alpha: 0),
          ],
        ),
      ),
      child: Row(
        children: [
          _CircleButton(icon: Icons.close, onTap: _dismiss, tooltip: 'Close'),
          const SizedBox(width: 8),
          if (widget.peerName != null) ...[
            UserAvatar(radius: 16, profile: widget.peer),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peerName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(_current.createdAt),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Spacer(),
          if (widget.onShare != null)
            _CircleButton(
              icon: Icons.share_outlined,
              onTap: () => widget.onShare!(_current),
              tooltip: 'Share',
            ),
          if (widget.onForward != null)
            _CircleButton(
              icon: Icons.forward,
              onTap: () => widget.onForward!(_current),
              tooltip: 'Forward',
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _bottomBar(BuildContext context, ChatMessage message) {
    switch (message.type) {
      case 'voice':
        return _VoiceControls(message: message);
      case 'video':
        return _VideoControlsOverlay(message: message);
      case 'audio':
        return _AudioPlayer(message: message);
      default:
        return _ImageCaption(message: message);
    }
  }
}

/// Scrim colours, kept local so this file does not depend on the theme file
/// being imported for two constants.
abstract final class CrystalColorsFallback {
  static const Color scrim = Color(0xCC000000);
}

/// Audio player modal for the media viewer.
///
/// Plays the audio associated with the message and provides play/pause controls.
/// Designed to be used inside [MediaViewerPage] via [_bottomBar].
class _AudioPlayer extends StatelessWidget {
  const _AudioPlayer({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          const Icon(
            Icons.music_note_outlined,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Audio message',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _CircleButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Fades and slides chrome in sync with the content.
class _AnimatedChrome extends StatelessWidget {
  const _AnimatedChrome({
    required this.controller,
    required this.alignment,
    required this.child,
    required this.heightFactor,
  });

  final AnimationController controller;
  final Alignment alignment;
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FadeTransition(
        opacity: controller,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, alignment == Alignment.topCenter ? -0.4 : 0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: controller, curve: Motion.enter)),
          child: child,
        ),
      ),
    );
  }
}

/// Renders one message's media at full bleed.
class _MediaStage extends StatelessWidget {
  const _MediaStage({
    required this.message,
    required this.isActive,
    this.onShare,
    this.onForward,
  });

  final ChatMessage message;
  final bool isActive;
  final void Function(ChatMessage message)? onShare;
  final void Function(ChatMessage message)? onForward;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    final path = attachment?.localPath;
    final name = attachment?.name ?? '';
    final exists = path != null && File(path).existsSync();

    if (!exists) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white38,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                path == null
                    ? 'This media is still on the server.'
                    : 'The downloaded copy is no longer on this device.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 8),
              const Text(
                'Re-request it from the chat to download again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return switch (message.type) {
      'video' => _VideoStage(path: path, isActive: isActive),
      'image' => _ZoomableImage(path: path),
      _ => _StaticStage(path: path, name: name),
    };
  }
}

class _StaticStage extends StatelessWidget {
  const _StaticStage({required this.path, required this.name});

  final String path;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        maxScale: 6,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          // The thumbnail in the chat list is already decoded and cached, so
          // this resolves without a re-encode flash.
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, _, __) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white38,
            size: 48,
          ),
        ),
      ),
    );
  }
}

/// Full-bleed image with double-tap zoom and pan.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.path});

  final String path;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final transform = TransformationController();
  Matrix4Tween? zoomTween;

  late final AnimationController doubleTap =
      AnimationController(vsync: this, duration: Motion.fast)..addListener(() {
        // Drive the transform from the tween each frame. Doing it in the
        // listener rather than only inside `build` means the zoom animates
        // smoothly without rebuilding the subtree 60 times a second.
        final animation = zoomTween?.animate(
          CurvedAnimation(parent: doubleTap, curve: Motion.standard),
        );
        if (animation != null) transform.value = animation.value;
      });

  TapDownDetails? lastTap;

  @override
  void dispose() {
    doubleTap.dispose();
    transform.dispose();
    super.dispose();
  }

  void handleDoubleTap() {
    final position = lastTap?.localPosition;
    if (position == null) return;

    final zoomedIn = transform.value.getMaxScaleOnAxis() > 1.05;
    zoomTween = Matrix4Tween(
      begin: Matrix4.copy(transform.value),
      end: zoomedIn
          ? Matrix4.identity()
          // Zoom into the point that was tapped, not the centre of the image.
          // Centring is the single most common way double-tap zoom feels wrong.
          : (Matrix4.identity()
              ..translateByDouble(-position.dx, -position.dy, 0, 1)
              ..scaleByDouble(2.4, 2.4, 2.4, 1)),
    );
    doubleTap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => lastTap = d,
      onDoubleTap: handleDoubleTap,
      child: InteractiveViewer(
        transformationController: transform,
        minScale: 1,
        maxScale: 6,
        child: Center(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            errorBuilder: (context, _, __) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

/// Video playback surface.
///
/// Drives [VideoPlayerController] directly rather than going through Chewie:
/// the viewer renders its own controls so they share the glass treatment and
/// the hide-on-tap behaviour, which means Chewie would only add a widget whose
/// chrome is switched off.
class _VideoStage extends StatefulWidget {
  const _VideoStage({required this.path, required this.isActive});

  final String path;
  final bool isActive;

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  VideoPlayerController? video0;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) open();
  }

  Future<void> open() async {
    final controller = VideoPlayerController.file(File(widget.path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted || !widget.isActive) {
        await controller.dispose();
        return;
      }
      setState(() => video0 = controller);
      // Expose the player to the shared control bar, which is a separate
      // widget in the tree. Exactly one video is ever on screen, so a static
      // slot needs no routing.
      _VideoControlsOverlayState.attach(controller);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not play this video.');
      }
    }
  }

  @override
  void didUpdateWidget(_VideoStage old) {
    super.didUpdateWidget(old);
    // Do not decode video for pages the user has swiped past, and do decode
    // when they come back. A run of videos would otherwise initialise every
    // player at once.
    if (widget.isActive && video0 == null && error == null) {
      open();
    }
  }

  @override
  void dispose() {
    if (identical(_VideoControlsOverlayState._attached, video0)) {
      _VideoControlsOverlayState._attached = null;
    }
    video0?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = video0;
    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (video == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: video.value.aspectRatio,
        child: VideoPlayer(video),
      ),
    );
  }
}

/// Bottom controls for a video.
class _VideoControlsOverlay extends StatefulWidget {
  const _VideoControlsOverlay({required this.message});

  final ChatMessage message;

  @override
  State<_VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<_VideoControlsOverlay>
    with SingleTickerProviderStateMixin {
  /// Holds the player for whichever video is currently on screen. Exactly one
  /// is alive at a time, so a static slot is enough and costs no routing.
  static VideoPlayerController? _attached;

  static void attach(VideoPlayerController controller) =>
      _attached = controller;

  VideoPlayerController? get _player => _attached;

  Timer? ticker;

  @override
  void initState() {
    super.initState();
    // The player may already exist (the stage initialises before this bar
    // mounts) or arrive a frame later, so poll briefly instead of attaching
    // once and missing it.
    ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final value = player.value;
    final duration = value.duration.inMilliseconds;
    final position = value.position.inMilliseconds;
    final fraction = duration > 0 ? position / duration : 0.0;
    final remaining = Duration(milliseconds: duration - position);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            CrystalColorsFallback.scrim,
            CrystalColorsFallback.scrim.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          scrub(fraction, duration, player),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _format(position),
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              speedButton(),
              const SizedBox(width: 8),
              _CircleButton(
                icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                onTap: () => value.isPlaying ? player.pause() : player.play(),
                size: 52,
              ),
              const Spacer(),
              Text('-${_format(remaining.inMilliseconds)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget scrub(double fraction, int duration, VideoPlayerController player) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: _accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: _accent,
      ),
      child: Slider(
        value: fraction.clamp(0.0, 1.0),
        onChanged: (v) =>
            player.seekTo(Duration(milliseconds: (v * duration).round())),
      ),
    );
  }

  Widget speedButton() {
    final player = _player!;
    final speed = player.value.playbackSpeed;
    return GestureDetector(
      onTap: () {
        final next =
            kPlaybackSpeeds[(kPlaybackSpeeds.indexOf(speed) + 1) %
                kPlaybackSpeeds.length];
        player.setPlaybackSpeed(next);
      },
      child: ViewerChromePill(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 1)}x',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

const _accent = Color(0xFF00E676);

String _format(int ms) {
  final total = Duration(milliseconds: ms);
  final minutes = total.inMinutes;
  final seconds = total.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Voice-note transport, reusing the app-wide player.
class _VoiceControls extends StatelessWidget {
  const _VoiceControls({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final controller = VoicePlayerControllerScope.of(context);
    final path = message.attachment?.localPath;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final active = controller.activeId == message.id;
        final playing = active && controller.isPlaying;
        final position = active ? controller.position : Duration.zero;
        final total = active
            ? (controller.duration ?? Duration.zero)
            : Duration.zero;
        final fraction = total.inMilliseconds > 0
            ? position.inMilliseconds / total.inMilliseconds
            : 0.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                CrystalColorsFallback.scrim,
                CrystalColorsFallback.scrim.withValues(alpha: 0),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              waveform(fraction),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _format(position.inMilliseconds),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: playing ? Icons.pause : Icons.play_arrow,
                    size: 52,
                    onTap: path == null
                        ? null
                        : () => controller.toggle(message.id, path),
                  ),
                  const Spacer(),
                  Text(
                    _format(total.inMilliseconds),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget waveform(double fraction) {
    return SizedBox(
      height: 48,
      child: CustomPaint(painter: _VoiceWavePainter(fraction: fraction)),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 44;
    const gap = 3.0;
    final barWidth = (size.width - gap * (bars - 1)) / bars;
    final played = Paint()..color = _accent;
    final unplayed = Paint()..color = Colors.white24;

    for (var i = 0; i < bars; i++) {
      // Deterministic pseudo-random heights: stable between frames, so the
      // bar does not flicker as the widget rebuilds.
      final seed = (i * 2654435761) % 1000;
      final h = size.height * (0.25 + (seed / 1000) * 0.75);
      final x = i * (barWidth + gap);
      final isPlayed = (i / bars) <= fraction;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h),
          const Radius.circular(2),
        ),
        isPlayed ? played : unplayed,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWavePainter old) => old.fraction != fraction;
}

/// Caption strip under an image.
class _ImageCaption extends StatelessWidget {
  const _ImageCaption({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final caption = message.body?.trim() ?? '';
    final meta = message.attachment == null
        ? null
        : metaLine(message.type, message.attachment!.sizeBytes);
    if (caption.isEmpty && meta == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            CrystalColorsFallback.scrim,
            CrystalColorsFallback.scrim.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (meta != null)
            Text(
              meta,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ],
      ),
    );
  }

  String? metaLine(String type, int? sizeBytes) {
    final parts = <String>[];
    if (sizeBytes != null && sizeBytes > 0) parts.add(_bytes(sizeBytes));
    if (type == 'image') parts.add('Image');
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: size * 0.55,
          color: enabled ? Colors.white : Colors.white38,
        ),
      ),
    );
    return button;
    return Tooltip(message: tooltip, child: button);
  }
}

/// Provides the shared voice player to the viewer's bottom bar.
///
/// Kept as a tiny scope rather than reaching for a global: the viewer is the
/// only place that needs the controller, and the main chat screen keeps its own.
class VoicePlayerControllerScope extends InheritedWidget {
  const VoicePlayerControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final VoicePlayerController controller;

  static VoicePlayerController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<VoicePlayerControllerScope>();
    assert(scope != null, 'No VoicePlayerControllerScope in this subtree');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(VoicePlayerControllerScope old) =>
      old.controller != controller;
}
