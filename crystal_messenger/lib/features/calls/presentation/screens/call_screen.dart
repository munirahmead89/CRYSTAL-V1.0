import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/call_provider.dart';
import '../../../../services/rtc/web_rtc_session.dart';

class CallScreen extends ConsumerWidget {
  final String callId;
  const CallScreen({super.key, required this.callId});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    final renderer = ref.watch(callProvider.notifier).remoteRenderer;

    final statusText = switch (call.status) {
      CallStatus.outgoing => 'Calling...',
      CallStatus.incoming => 'Incoming call',
      CallStatus.connecting => 'Connecting...',
      CallStatus.active => _formatDuration(call.duration),
      CallStatus.failed => 'Call failed',
      CallStatus.missed => 'Missed call',
      CallStatus.ended => 'Call ended',
      _ => '',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.surfaceVariant,
              child: Icon(Icons.person, size: 60, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              call.remoteUserName ?? 'Unknown',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (call.callType == 'video' && call.status == CallStatus.active)
              Expanded(
                child: RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    call.isMuted ? Icons.mic : Icons.mic_off,
                    call.isMuted ? 'Unmute' : 'Mute',
                    () => ref.read(callProvider.notifier).toggleMute(),
                  ),
                  _controlButton(
                    Icons.call_end,
                    'End',
                    () => ref.read(callProvider.notifier).endCall(),
                    color: AppColors.error,
                  ),
                  _controlButton(
                    call.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    call.isSpeakerOn ? 'Speaker' : 'Earpiece',
                    () => ref.read(callProvider.notifier).toggleSpeaker(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (call.callType == 'video')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      call.isCameraOff ? Icons.videocam_off : Icons.videocam,
                      call.isCameraOff ? 'Camera On' : 'Camera Off',
                      () => ref.read(callProvider.notifier).toggleCamera(),
                      small: true,
                    ),
                    _controlButton(
                      Icons.flip_camera_ios,
                      'Switch',
                      () => ref.read(callProvider.notifier).switchCamera(),
                      small: true,
                    ),
                  ],
                ),
              ),
            if (call.status == CallStatus.incoming) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(Icons.call_end, 'Decline',
                      () => ref.read(callProvider.notifier).decline(),
                      color: AppColors.error),
                  _controlButton(Icons.call, 'Accept',
                      () => ref.read(callProvider.notifier).accept(),
                      color: AppColors.success),
                ],
              ),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, String label, VoidCallback onTap,
      {Color? color, bool small = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: small ? 56 : 64,
            height: small ? 56 : 64,
            decoration: BoxDecoration(
              color: color ?? AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: small ? 24 : 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
