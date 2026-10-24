abstract interface class ClientProfileCache {
  /// Implement this using AppPreferences or SecureStorage
  Future<void> upsertFromServer(Map<String, dynamic> profile);
}

/// Client-side profile storage using AppPreferences
class ClientProfileCache implements ClientProfileCache {
  ClientProfileCache({appPreferences}) : _appPreferences = appPreferences ?? AppPreferences();

  final AppPreferences _appPreferences;

  @override
  Future<void> upsertFromServer(Map<String, dynamic> profile) async {
    // Client-side: just upsert locally
    await _appPreferences.saveProfile({
      'id': profile['id'] ?? '',
      'display_name': profile['displayName'] ?? '',
      'phone': profile['phone'] ?? '',
      'avatar_url': profile['avatarUrl'] ?? '',
      'is_anonymous': profile['isAnonymous'] ?? false,
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

/// Client-side profile cache provider
final clientProfileCacheProvider = StateNotifierProvider<ClientProfileNotifier, Map<String, dynamic>>((ref) {
  return ClientProfileNotifier();
});

class ClientProfileNotifier extends StateNotifier<Map<String, dynamic>> {
  ClientProfileNotifier() : super({});

  /// Load profile from local storage
  Future<void> loadProfile() async {
    final preferences = AppPreferences();
    final profileData = preferences.getProfile();
    if (profileData != null) {
      state = profileData;
    }
  }

  /// Save profile to local storage
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final preferences = AppPreferences();
    await preferences.saveProfile(profile);
    state = profile;
  }

  /// Get a specific field from the profile
  dynamic getField(String field) {
    return state[field];
  }

  /// Update a specific field
  Future<void> updateField(String field, dynamic value) async {
    final newMap = Map<String, dynamic>.from(state);
    newMap[field] = value;
    await saveProfile(newMap);
  }

  /// Get display name
  String get displayName => state['displayName'] ?? '';

  /// Get phone
  String get phone => state['phone'] ?? '';

  /// Get avatar URL
  String get avatarUrl => state['avatarUrl'] ?? '';

  /// Get if anonymous
  bool get isAnonymous => state['isAnonymous'] == true;

  /// Get bio
  String get bio => state['bio'] ?? '';

  /// Get presence
  String get presence => state['presence'] ?? 'offline';

  /// Get last seen
  DateTime? get lastSeenAt => state['lastSeenAt'] != null
      ? DateTime.parse(state['lastSeenAt'])
      : null;

  /// Get verification status
  String get verificationStatus => state['verificationStatus'] ?? 'unverified';

  /// Get sync enabled
  bool get syncEnabled => state['syncEnabled'] ?? true;

  /// Get verified at
  DateTime? get verifiedAt => state['verifiedAt'] != null
      ? DateTime.parse(state['verifiedAt'])
      : null;
}