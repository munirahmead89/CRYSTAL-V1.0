import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/webrtc_network_config.dart';

enum CallKind { audio, video }

/// WebRTC transport with Supabase Realtime signaling.
///
/// Media stays peer-to-peer when ICE can connect. STUN is free discovery only;
/// callers can inject TURN servers through [turnServers] for difficult NATs.
class WebRtcCallService {
  WebRtcCallService(this.client, {this.turnServers = const []});

  final SupabaseClient client;
  final List<Map<String, dynamic>> turnServers;
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  RealtimeChannel? _channel;
  String? _callId;

  List<Map<String, dynamic>> get iceServers => [
        ...WebRtcNetworkConfig.iceServers,
        ...turnServers,
      ];

  Future<void> start({required String conversationId, required String calleeId, CallKind kind = CallKind.audio}) async {
    final me = client.auth.currentUser?.id;
    if (me == null) throw StateError('Not authenticated');
    final row = await client.from('call_sessions').insert({
      'conversation_id': conversationId,
      'caller_id': me,
      'callee_id': calleeId,
      'call_type': kind.name,
    }).select('id').single();
    _callId = row['id'] as String;
    await _openPeer(conversationId, video: kind == CallKind.video);
    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);
    await _send('offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> accept({required String conversationId, required String callId, required Map<String, dynamic> offer}) async {
    _callId = callId;
    await _openPeer(conversationId, video: offer['callType'] == 'video');
    await _peer!.setRemoteDescription(RTCSessionDescription(offer['sdp'] as String?, offer['type'] as String?));
    final answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);
    await client.from('call_sessions').update({'state': 'accepted', 'answered_at': DateTime.now().toUtc().toIso8601String()}).eq('id', callId);
    await _send('answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> end() async {
    final id = _callId;
    if (id != null) await client.from('call_sessions').update({'state': 'ended', 'ended_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    await _channel?.unsubscribe();
    await _localStream?.dispose();
    await _peer?.close();
    _channel = null;
    _localStream = null;
    _peer = null;
    _callId = null;
  }

  Future<void> _openPeer(String conversationId, {required bool video}) async {
    _peer = await createPeerConnection({'iceServers': iceServers});
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': video});
    for (final track in _localStream!.getTracks()) {
      await _peer!.addTrack(track, _localStream!);
    }
    _channel = client.channel('calls:$conversationId');
    _channel!.onBroadcast(event: 'signal', callback: (payload) async {
      if (payload['callId'] != _callId) return;
      final type = payload['type'];
      if (type == 'answer') {
        await _peer?.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['descriptionType']));
      } else if (type == 'candidate') {
        await _peer?.addCandidate(RTCIceCandidate(payload['candidate'], payload['sdpMid'], payload['sdpMLineIndex']));
      }
    });
    _peer!.onIceCandidate = (candidate) => _send('candidate', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
    _channel!.subscribe();
  }

  Future<void> _send(String type, Map<String, dynamic> data) async {
    await _channel?.sendBroadcastMessage(event: 'signal', payload: {
      ...data,
      'type': type,
      'callId': _callId,
      'descriptionType': data['type'],
    });
  }
}
