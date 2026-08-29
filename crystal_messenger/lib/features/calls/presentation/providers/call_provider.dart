import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../services/rtc/web_rtc_session.dart';
import '../../../../services/rtc/call_signaling.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/repositories/call_repository.dart';

part 'call_provider.freezed.dart';

enum CallRole { caller, callee }

@freezed
class CallState with _$CallState {
  const factory CallState({
    @Default(CallStatus.idle) CallStatus status,
    @Default(CallRole.caller) CallRole role,
    @Default('audio') String callType,
    String? callId,
    String? chatId,
    String? remoteUserId,
    String? remoteUserName,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool isMuted,
    @Default(false) bool isCameraOff,
    @Default(false) bool isSpeakerOn,
    @Default(false) bool isConnecting,
  }) = _CallState;

  const CallState.idleState()
      : status = CallStatus.idle,
        role = CallRole.caller,
        callType = 'audio',
        callId = null,
        chatId = null,
        remoteUserId = null,
        remoteUserName = null,
        duration = Duration.zero,
        isMuted = false,
        isCameraOff = false,
        isSpeakerOn = false,
        isConnecting = false;
}

enum CallStatus { idle, outgoing, incoming, connecting, active, failed, missed, ended }

class CallNotifier extends StateNotifier<CallState> {
  final SupabaseClient _supabase;
  final CallRepository _repository;
  final CallSignaling _signaling;
  final WebRtcSession _session = WebRtcSession();
  Timer? _ringTimer;

  /// Public accessor for the remote video renderer (used by CallScreen).
  RTCVideoRenderer get remoteRenderer => _session.remoteRenderer;
  Timer? _durationTimer;

  CallNotifier(this._supabase, this._repository, this._signaling)
      : super(const CallState.idleState()) {
    _session.onRemoteStream.listen((_) {});
    _signaling.events.listen(_handleSignal);
  }

  // ─── Outgoing call ──────────────────────────────────
  Future<void> startOutgoing({
    required String chatId,
    required String remoteUserId,
    required String remoteUserName,
    required String callType,
  }) async {
    state = CallState(
      status: CallStatus.outgoing,
      role: CallRole.caller,
      callType: callType,
      chatId: chatId,
      remoteUserId: remoteUserId,
      remoteUserName: remoteUserName,
      isConnecting: true,
    );

    await _session.initialize(video: callType == 'video');
    final offer = await _session.createOffer();

    final call = await _repository.logCall(
      chatId: chatId,
      callerId: _supabase.auth.currentUser!.id,
      callType: callType,
      status: 'ringing',
    );

    state = state.copyWith(callId: call['id'], isConnecting: false);

    _signaling.sendSignal(
      targetUserId: remoteUserId,
      payload: {
        'type': 'offer',
        'sdp': offer,
        'call_id': call['id'],
        'call_type': callType,
        'from_name': _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'User',
      },
    );

    _startRingTimeout();
  }

  // ─── Incoming call ──────────────────────────────────
  void handleIncoming(Map<String, dynamic> payload) {
    if (state.status != CallStatus.idle) return;
    state = CallState(
      status: CallStatus.incoming,
      role: CallRole.callee,
      callType: payload['call_type'] ?? 'audio',
      callId: payload['call_id'],
      chatId: payload['chat_id'],
      remoteUserId: payload['from'],
      remoteUserName: payload['from_name'] ?? 'Unknown',
    );
    _startRingTimeout();
  }

  Future<void> accept() async {
    if (state.status != CallStatus.incoming &&
        state.status != CallStatus.connecting) {
      return;
    }
    await _session.initialize(video: state.callType == 'video');
    // Remote description was set when 'offer' arrived in _handleOffer
    final answer = await _session.createAnswer();
    _signaling.sendSignal(
      targetUserId: state.remoteUserId ?? '',
      payload: {
        'type': 'answer',
        'sdp': answer,
        'call_id': state.callId,
      },
    );
    state = state.copyWith(status: CallStatus.active);
    _startDurationTimer();
  }

  Future<void> decline() async {
    _cancelTimers();
    if (state.callId != null) {
      await _repository.updateCallStatus(callId: state.callId!, status: 'declined');
    }
    _signaling.sendSignal(
      targetUserId: state.remoteUserId ?? '',
      payload: {'type': 'decline', 'call_id': state.callId},
    );
    await _session.dispose();
    state = const CallState.idleState();
  }

  // ─── Signal handling ────────────────────────────────
  void _handleSignal(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'offer':
        _handleOffer(data);
        break;
      case 'answer':
        _handleAnswer(data);
        break;
      case 'candidate':
        _session.addRemoteCandidate(data['candidate']);
        break;
      case 'decline':
        _handleDecline();
        break;
      case 'end':
        _handleRemoteEnd();
        break;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (state.status != CallStatus.incoming) return;
    await _session.initialize(video: state.callType == 'video');
    await _session.setRemoteDescription(data['sdp']);
    state = state.copyWith(
      status: CallStatus.connecting,
      isConnecting: true,
      callId: data['call_id'],
    );
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    await _session.setRemoteDescription(data['sdp']);
    state = state.copyWith(status: CallStatus.active);
    _startDurationTimer();
  }

  void _handleDecline() {
    _cancelTimers();
    state = const CallState.idleState();
  }

  void _handleRemoteEnd() {
    _cancelTimers();
    if (state.callId != null) {
      _repository.updateCallStatus(
        callId: state.callId!,
        status: 'ended',
        duration: state.duration.inSeconds,
      );
    }
    state = const CallState.idleState();
  }

  // ─── Controls ───────────────────────────────────────
  Future<void> toggleMute() async {
    await _session.toggleMute();
    state = state.copyWith(isMuted: _session.isMuted);
  }

  Future<void> toggleCamera() async {
    await _session.toggleCamera();
    state = state.copyWith(isCameraOff: _session.isCameraOff);
  }

  Future<void> switchCamera() async {
    await _session.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
  }

  Future<void> endCall() async {
    _cancelTimers();
    _signaling.sendSignal(
      targetUserId: state.remoteUserId ?? '',
      payload: {'type': 'end', 'call_id': state.callId},
    );
    if (state.callId != null) {
      await _repository.updateCallStatus(
        callId: state.callId!,
        status: 'ended',
        duration: state.duration.inSeconds,
      );
    }
    await _session.dispose();
    state = const CallState.idleState();
  }

  // ─── Timers ─────────────────────────────────────────
  void _startRingTimeout() {
    _ringTimer = Timer(AppConstants.callRingTimeout, () {
      if (state.status == CallStatus.outgoing ||
          state.status == CallStatus.incoming) {
        if (state.callId != null) {
          _repository.updateCallStatus(
            callId: state.callId!,
            status: 'missed',
          );
        }
        _session.dispose();
        state = const CallState.idleState();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(duration: state.duration + const Duration(seconds: 1));
    });
  }

  void _cancelTimers() {
    _ringTimer?.cancel();
    _durationTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    _session.dispose();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final repo = ref.watch(callRepositoryProvider);
  final signaling = ref.watch(callSignalingProvider);
  return CallNotifier(client, repo, signaling);
});

// Call history provider
final callHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(callRepositoryProvider);
  final userId = ref.watch(supabaseClientProvider).auth.currentUser!.id;
  return repo.getCallHistory(userId);
});
