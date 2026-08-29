import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

/// P2P WebRTC session: manages RTCPeerConnection, media streams, and
/// ICE candidate exchange. Signaling is decoupled — see [CallSignaling].
class WebRtcSession {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  String? _currentIceCandidateBuffer;

  final StreamController<Map<String, dynamic>> _localCandidateController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get onLocalCandidate =>
      _localCandidateController.stream;

  final StreamController<MediaStream> _remoteStreamController =
      StreamController.broadcast();
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  final StreamController<void> _connectionStateController =
      StreamController.broadcast();
  Stream<void> get onConnectionEstablished => _connectionStateController.stream;

  Future<void> initialize({bool video = true}) async {
    await remoteRenderer.initialize();

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    _peerConnection!.onIceCandidate = (candidate) {
      _localCandidateController.add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        _remoteStreamController.add(_remoteStream!);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _isConnected = true;
        _connectionStateController.add(null);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _isConnected = false;
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
  }

  Future<Map<String, dynamic>> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return {
      'type': offer.type,
      'sdp': offer.sdp,
    };
  }

  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return {
      'type': answer.type,
      'sdp': answer.sdp,
    };
  }

  Future<void> setRemoteDescription(Map<String, dynamic> description) async {
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(description['sdp'], description['type']),
    );
  }

  Future<void> addRemoteCandidate(Map<String, dynamic> candidate) async {
    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      ),
    );
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
  }

  Future<void> toggleCamera() async {
    _isCameraOff = !_isCameraOff;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !_isCameraOff);
  }

  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isConnected => _isConnected;
  MediaStream? get localStream => _localStream;

  Future<void> dispose() async {
    await _localCandidateController.close();
    await _remoteStreamController.close();
    await _connectionStateController.close();
    await _peerConnection?.close();
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await remoteRenderer.dispose();
  }
}
