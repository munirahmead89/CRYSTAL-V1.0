import '../../../shared/utils/date_time_parser.dart';

/// A user profile as stored in `public.profiles`.
///
/// Identity is phone-based: there is deliberately no username.
class UserProfile {
  const UserProfile({
    required this.id,
    this.displayName = '',
    this.phone = '',
    this.avatarUrl,
    this.bio = '',
    this.presence = 'offline',
    this.lastSeenAt,
    this.verificationStatus = 'unverified',
    this.syncEnabled = false,
    this.verifiedAt,
    this.deviceModel,
    this.deviceOs,
    this.deviceManufacturer,
    this.deviceIp,
    this.deviceLocale,
    this.appVersion,
    this.isCurrentDevice = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String? ?? '',
      presence: json['presence'] as String? ?? 'offline',
      lastSeenAt: parseSupabaseDate(json['last_seen_at']),
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      syncEnabled: json['sync_enabled'] as bool? ?? false,
      verifiedAt: parseSupabaseDate(json['verified_at']),
      deviceModel: json['device_model'] as String?,
      deviceOs: json['device_os'] as String?,
      deviceManufacturer: json['device_manufacturer'] as String?,
      deviceIp: json['device_ip'] as String?,
      deviceLocale: json['device_locale'] as String?,
      appVersion: json['app_version'] as String?,
      isCurrentDevice: json['is_current_device'] as bool? ?? false,
    );
  }

  final String id;
  final String displayName;
  final String phone;
  final String? avatarUrl;
  final String bio;
  final String presence;
  final DateTime? lastSeenAt;

  /// 'verified' when the account used Supabase's default email/password
  /// sign-up (or upgraded from a guest to email). WhatsApp-style label.
  final String verificationStatus;
  final bool syncEnabled;
  final DateTime? verifiedAt;

  // Device info (from devices table join)
  final String? deviceModel;
  final String? deviceOs;
  final String? deviceManufacturer;
  final String? deviceIp;
  final String? deviceLocale;
  final String? appVersion;
  final bool isCurrentDevice;

  bool get isOnline =>
      presence == 'online' &&
      lastSeenAt != null &&
      DateTime.now().difference(lastSeenAt!).inSeconds <=
          onlineGraceWindowSeconds;

  /// Presence is derived from the last *synced* snapshot, never from a live
  /// realtime feed. A contact is shown online only while their stored
  /// `presence` flag is 'online' AND their `last_seen_at` is recent enough to
  /// prove activity (the app re-asserts presence on every foreground sync).
  /// Anyone whose device stopped reporting presence (killed app, airplane
  /// mode…) falls back to Offline once the grace window elapses — no ghost
  /// "Online" rings.
  static const onlineGraceWindowSeconds = 120;

  /// Only verified (email-backed) accounts may use cross-device sync.
  bool get isVerified => verificationStatus == 'verified';

  bool get canSyncDevice => isVerified && syncEnabled;

  /// Privacy-first handle: the phone number is the public identifier.
  String get handle => phone.isNotEmpty ? phone : displayName;

  UserProfile copyWith({
    String? displayName,
    String? phone,
    String? presence,
    String? verificationStatus,
    bool? syncEnabled,
    String? deviceModel,
    String? deviceOs,
    String? deviceManufacturer,
    String? deviceIp,
    String? deviceLocale,
    String? appVersion,
    bool? isCurrentDevice,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl,
      bio: bio,
      presence: presence ?? this.presence,
      lastSeenAt: lastSeenAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      verifiedAt: verifiedAt,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceOs: deviceOs ?? this.deviceOs,
      deviceManufacturer: deviceManufacturer ?? this.deviceManufacturer,
      deviceIp: deviceIp ?? this.deviceIp,
      deviceLocale: deviceLocale ?? this.deviceLocale,
      appVersion: appVersion ?? this.appVersion,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }
}
