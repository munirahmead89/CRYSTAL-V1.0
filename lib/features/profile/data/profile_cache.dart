abstract interface class ProfileCache {
  /// Implement this in your Drift DAO as an upsert keyed by `id`.
  Future<void> upsertFromServer(Map<String, dynamic> profile);
}

/// Client-side profile cache using AppPreferences
/// ALL DATA IS STORED LOCALLY - NO SERVER CALLS
class ClientProfileCache implements ProfileCache {
  ClientProfileCache({appPreferences}) : _appPreferences = appPreferences ?? AppPreferences();

  final AppPreferences _appPreferences;

  @override
  Future<void> upsertFromServer(Map<String, dynamic> profile) async {
    // Client-side: store ALL data locally, NO server calls
    await _appPreferences.saveProfile({
      'id': profile['id'] ?? '',
      'display_name': profile['displayName'] ?? '',
      'phone': profile['phone'] ?? '',
      'avatar_url': profile['avatarUrl'] ?? '',
      'is_anonymous': profile['isAnonymous'] ?? true, // Anonymous by default
      'bio': profile['bio'] ?? '',
      'presence': profile['presence'] ?? 'offline',
      'last_seen_at': profile['lastSeenAt'] ?? DateTime.now().toIso8601String(),
      'verification_status': profile['verificationStatus'] ?? 'unverified',
      'sync_enabled': profile['syncEnabled'] ?? true,
      'verified_at': profile['verifiedAt'] ?? '',
      'device_model': profile['deviceModel'] ?? '',
      'device_os': profile['deviceOs'] ?? '',
      'device_manufacturer': profile['deviceManufacturer'] ?? '',
      'device_ip': profile['deviceIp'] ?? '',
      'device_locale': profile['deviceLocale'] ?? '',
      'app_version': profile['appVersion'] ?? '',
    });
  }
}

/// Client profile model for local storage
class ClientProfileModel {
  final String id;
  final String displayName;
  final String phone;
  final String avatarUrl;
  final bool isAnonymous;
  final String bio;
  final String presence;
  final DateTime lastSeenAt;
  final String verificationStatus;
  final bool syncEnabled;
  final DateTime? verifiedAt;
  final String deviceModel;
  final String deviceOs;
  final String deviceManufacturer;
  final String deviceIp;
  final String deviceLocale;
  final String appVersion;

  ClientProfileModel({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.avatarUrl,
    required this.isAnonymous,
    required this.bio,
    required this.presence,
    required this.lastSeenAt,
    required this.verificationStatus,
    required this.syncEnabled,
    required this.verifiedAt,
    required this.deviceModel,
    required this.deviceOs,
    required this.deviceManufacturer,
    required this.deviceIp,
    required this.deviceLocale,
    required this.appVersion,
  });

  /// Convert from map
  factory ClientProfileModel.fromMap(Map<String, dynamic> map) {
    return ClientProfileModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      isAnonymous: map['is_anonymous'] == true,
      bio: map['bio'] ?? '',
      presence: map['presence'] ?? 'offline',
      lastSeenAt: map['last_seen_at'] != null 
          ? DateTime.parse(map['last_seen_at'])
          : DateTime.now(),
      verificationStatus: map['verificationStatus'] ?? 'unverified',
      syncEnabled: map['sync_enabled'] ?? true,
      verifiedAt: map['verified_at'] != null 
          ? DateTime.parse(map['verified_at'])
          : null,
      deviceModel: map['deviceModel'] ?? '',
      deviceOs: map['deviceOs'] ?? '',
      deviceManufacturer: map['deviceManufacturer'] ?? '',
      deviceIp: map['deviceIp'] ?? '',
      deviceLocale: map['deviceLocale'] ?? '',
      appVersion: map['appVersion'] ?? '',
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'isAnonymous': isAnonymous,
      'bio': bio,
      'presence': presence,
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'verificationStatus': verificationStatus,
      'syncEnabled': syncEnabled,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'deviceModel': deviceModel,
      'deviceOs': deviceOs,
      'deviceManufacturer': deviceManufacturer,
      'deviceIp': deviceIp,
      'deviceLocale': deviceLocale,
      'appVersion': appVersion,
    };
  }
}