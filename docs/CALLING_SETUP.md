# Local WebRTC Calling

The client now includes a WebRTC transport in `lib/features/calls/data/webrtc_call_service.dart` and a call-session section in `supabase/migrations/00033_crystal_consolidated_hardening.sql`. It uses Supabase Realtime for authenticated offer/answer/ICE signaling and Google's public STUN servers:

- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`
- `stun:stun2.l.google.com:19302`

STUN only discovers public candidates. It does not relay media. TURN servers can be injected into `WebRtcCallService.turnServers` for networks where peer-to-peer connectivity fails.

The UI intentionally does not claim calls are working until those pieces are implemented and tested on physical Android/iOS devices.
