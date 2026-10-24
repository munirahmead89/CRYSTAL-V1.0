import 'package:flutter/material.dart';
import '../../domain/webrtc_network_config.dart';

/// The Calls tab.
///
/// ## UI only — there is no calling behind this
///
/// Calling was removed from the app (WebRTC audio/video, the call log table and
/// its notifications). This tab exists because the bottom navigation is a fixed
/// three-slot shell, so removing the slot would have left the other two
/// off-centre.
///
/// It is honest about being empty rather than showing a fake call history, and
/// it says what is available instead of a bare "coming soon", because a tab that
/// looks broken is worse than one that looks deliberate.
///
/// Restoring real calling means: a `calls` table with RLS, SDP/ICE signaling
/// over a Realtime broadcast room, and an RTCPeerConnection per call. The
/// signaling pattern is unchanged and lives in
/// `lib/core/p2p/p2p_signaling.dart` as `P2PSignaling`, which already does the
/// offer/answer/ICE exchange for the message data channel.
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.call_outlined,
                size: 42,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No calls',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Local WebRTC calling is prepared with Google STUN discovery. '
              'A TURN relay is still required for some mobile and restricted '
              'networks.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.call_outlined),
              label: Text('${WebRtcNetworkConfig.stunServers.length} STUN servers configured'),
            ),
            const SizedBox(height: 12),
            // Reassure on the thing a messaging user actually cares about,
            // without implying a feature that does not exist.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Messages between you two are never lost',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
