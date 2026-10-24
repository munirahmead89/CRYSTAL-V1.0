/// Network configuration for local WebRTC calling.
///
/// Google's public STUN service is free and useful for discovering a device's
/// public candidate. It is not a TURN relay and cannot guarantee connectivity
/// behind symmetric NAT, carrier NAT, or restrictive enterprise firewalls.
class WebRtcNetworkConfig {
  const WebRtcNetworkConfig._();

  static const stunServers = <String>[
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
  ];

  static const iceServers = <Map<String, dynamic>>[
    {'urls': stunServers},
  ];
}
