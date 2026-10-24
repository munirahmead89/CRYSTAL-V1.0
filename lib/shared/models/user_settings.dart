import 'dart:convert';

/// Immutable snapshot of every user-configurable setting in Crystal Messenger.
///
/// Serialized as a flat snake_case JSON object in the server-side
/// `user_settings` table (`settings` jsonb column) and mirrored into the local
/// Drift cache (`user_settings.settings_json`) so toggles apply instantly,
/// survive offline restarts, and sync across devices via Supabase Realtime.
class AppUserSettings {
  const AppUserSettings({
    this.messageNotifications = true,
    this.groupNotifications = true,
    this.updatesNotifications = true,
    this.callRingtone = true,
    this.vibrate = true,
    this.showPreviews = true,
    this.inAppLight = true,
    this.readReceipts = true,
    this.enterToSend = false,
    this.mediaAutoDownload = true,
    this.chatBackup = true,
    this.theme = 'system',
    this.lastSeenVisibility = 'everyone',
    this.profilePhotoVisibility = 'everyone',
    this.statusVisibility = 'everyone',
    this.appLockEnabled = false,
    this.appLockTimer = 'immediate',
    this.mediaCompressionQuality = 'balanced',
    this.fingerprintLock = false,
    this.incognitoKeyboard = false,
    this.disappearingMessagesTimer = 'off',
    this.groupsPrivacy = 'everyone',
    this.channelsPrivacy = 'everyone',
    this.fontSize = 'medium',
    this.useLessDataForCalls = false,
    this.wifiCalling = true,
    this.mobileDataAutoDownload = true,
    this.wifiAutoDownload = true,
    this.roamingAutoDownload = true,
    this.twoStepEnabled = false,
    this.recoveryEmail,
    this.twoStepPin,
    this.chatWallpaper = 'default',
  });

  static const defaults = AppUserSettings();

  // Notifications
  final bool messageNotifications;
  final bool groupNotifications;
  final bool updatesNotifications;
  final bool callRingtone;
  final bool vibrate;
  final bool showPreviews;
  final bool inAppLight;

  // Chats / behaviour
  final bool readReceipts;
  final bool enterToSend;
  final bool mediaAutoDownload;
  final bool chatBackup;
  final String theme; // 'system' | 'light' | 'dark'
  final String chatWallpaper; // 'gojo' | 'black'

  // Privacy
  final String lastSeenVisibility; // everyone | contacts | nobody
  final String profilePhotoVisibility; // everyone | contacts | nobody
  final String statusVisibility; // everyone | contacts | nobody

  // Security
  final bool appLockEnabled;
  final String appLockTimer; // immediate | 1min | 5min | 15min | 1hour

  /// Profile used to shrink media before upload.
  /// original | balanced | dataSaver
  final String mediaCompressionQuality;

  // Advanced privacy
  final bool fingerprintLock;
  final bool incognitoKeyboard;
  final String disappearingMessagesTimer; // off | 24h | 7d | 90d
  final String groupsPrivacy; // everyone | contacts | contacts_except
  final String channelsPrivacy; // everyone | contacts | nobody

  // Display & data usage
  final String fontSize; // small | medium | large
  final bool useLessDataForCalls;
  final bool wifiCalling;

  // Media auto-download policy
  final bool mobileDataAutoDownload;
  final bool wifiAutoDownload;
  final bool roamingAutoDownload;

  // Two-step verification
  final bool twoStepEnabled;
  final String? recoveryEmail;
  final String? twoStepPin;

  bool get isDarkTheme => theme == 'dark';
  bool get isLightTheme => theme == 'light';

  AppUserSettings copyWith({
    bool? messageNotifications,
    bool? groupNotifications,
    bool? updatesNotifications,
    bool? callRingtone,
    bool? vibrate,
    bool? showPreviews,
    bool? inAppLight,
    bool? readReceipts,
    bool? enterToSend,
    bool? mediaAutoDownload,
    bool? chatBackup,
    String? theme,
    String? lastSeenVisibility,
    String? profilePhotoVisibility,
    String? statusVisibility,
    bool? appLockEnabled,
    String? appLockTimer,
    String? mediaCompressionQuality,
    bool? fingerprintLock,
    bool? incognitoKeyboard,
    String? disappearingMessagesTimer,
    String? groupsPrivacy,
    String? channelsPrivacy,
    String? fontSize,
    bool? useLessDataForCalls,
    bool? wifiCalling,
    bool? mobileDataAutoDownload,
    bool? wifiAutoDownload,
    bool? roamingAutoDownload,
    bool? twoStepEnabled,
    String? recoveryEmail,
    String? twoStepPin,
    String? chatWallpaper,
  }) {
    return AppUserSettings(
      messageNotifications: messageNotifications ?? this.messageNotifications,
      groupNotifications: groupNotifications ?? this.groupNotifications,
      updatesNotifications: updatesNotifications ?? this.updatesNotifications,
      callRingtone: callRingtone ?? this.callRingtone,
      vibrate: vibrate ?? this.vibrate,
      showPreviews: showPreviews ?? this.showPreviews,
      inAppLight: inAppLight ?? this.inAppLight,
      readReceipts: readReceipts ?? this.readReceipts,
      enterToSend: enterToSend ?? this.enterToSend,
      mediaAutoDownload: mediaAutoDownload ?? this.mediaAutoDownload,
      chatBackup: chatBackup ?? this.chatBackup,
      theme: theme ?? this.theme,
      lastSeenVisibility: lastSeenVisibility ?? this.lastSeenVisibility,
      profilePhotoVisibility:
          profilePhotoVisibility ?? this.profilePhotoVisibility,
      statusVisibility: statusVisibility ?? this.statusVisibility,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockTimer: appLockTimer ?? this.appLockTimer,
      mediaCompressionQuality:
          mediaCompressionQuality ?? this.mediaCompressionQuality,
      fingerprintLock: fingerprintLock ?? this.fingerprintLock,
      incognitoKeyboard: incognitoKeyboard ?? this.incognitoKeyboard,
      disappearingMessagesTimer:
          disappearingMessagesTimer ?? this.disappearingMessagesTimer,
      groupsPrivacy: groupsPrivacy ?? this.groupsPrivacy,
      channelsPrivacy: channelsPrivacy ?? this.channelsPrivacy,
      fontSize: fontSize ?? this.fontSize,
      useLessDataForCalls: useLessDataForCalls ?? this.useLessDataForCalls,
      wifiCalling: wifiCalling ?? this.wifiCalling,
      mobileDataAutoDownload:
          mobileDataAutoDownload ?? this.mobileDataAutoDownload,
      wifiAutoDownload: wifiAutoDownload ?? this.wifiAutoDownload,
      roamingAutoDownload: roamingAutoDownload ?? this.roamingAutoDownload,
      twoStepEnabled: twoStepEnabled ?? this.twoStepEnabled,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      twoStepPin: twoStepPin ?? this.twoStepPin,
      chatWallpaper: chatWallpaper ?? this.chatWallpaper,
    );
  }

  Map<String, dynamic> toJson() => {
    'message_notifications': messageNotifications,
    'group_notifications': groupNotifications,
    'updates_notifications': updatesNotifications,
    'call_ringtone': callRingtone,
    'vibrate': vibrate,
    'show_previews': showPreviews,
    'in_app_light': inAppLight,
    'read_receipts': readReceipts,
    'enter_to_send': enterToSend,
    'media_auto_download': mediaAutoDownload,
    'chat_backup': chatBackup,
    'theme': theme,
    'chat_wallpaper': chatWallpaper,
    'last_seen_visibility': lastSeenVisibility,
    'profile_photo_visibility': profilePhotoVisibility,
    'status_visibility': statusVisibility,
    'app_lock_enabled': appLockEnabled,
    'app_lock_timer': appLockTimer,
    'media_compression_quality': mediaCompressionQuality,
    'fingerprint_lock': fingerprintLock,
    'incognito_keyboard': incognitoKeyboard,
    'disappearing_messages_timer': disappearingMessagesTimer,
    'groups_privacy': groupsPrivacy,
    'channels_privacy': channelsPrivacy,
    'font_size': fontSize,
    'use_less_data_for_calls': useLessDataForCalls,
    'wifi_calling': wifiCalling,
    'mobile_data_auto_download': mobileDataAutoDownload,
    'wifi_auto_download': wifiAutoDownload,
    'roaming_auto_download': roamingAutoDownload,
    'two_step_enabled': twoStepEnabled,
    'recovery_email': recoveryEmail,
    // NOTE: `twoStepPin` is deliberately NOT serialised. This map is the
    // payload pushed to the `user_settings.settings` jsonb column, so a
    // plaintext PIN here would be readable by anyone with database access
    // and would sync to every signed-in device. Until a real 2FA backend
    // (hashed secret + challenge/verify RPC) exists, the PIN stays
    // in-memory only. Never add it back.
  };

  String toJsonString() => jsonEncode(toJson());

  factory AppUserSettings.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return AppUserSettings(
      messageNotifications:
          json['message_notifications'] as bool? ??
          defaults.messageNotifications,
      groupNotifications:
          json['group_notifications'] as bool? ?? defaults.groupNotifications,
      updatesNotifications:
          json['updates_notifications'] as bool? ??
          defaults.updatesNotifications,
      callRingtone: json['call_ringtone'] as bool? ?? defaults.callRingtone,
      vibrate: json['vibrate'] as bool? ?? defaults.vibrate,
      showPreviews: json['show_previews'] as bool? ?? defaults.showPreviews,
      inAppLight: json['in_app_light'] as bool? ?? defaults.inAppLight,
      readReceipts: json['read_receipts'] as bool? ?? defaults.readReceipts,
      enterToSend: json['enter_to_send'] as bool? ?? defaults.enterToSend,
      mediaAutoDownload:
          json['media_auto_download'] as bool? ?? defaults.mediaAutoDownload,
      chatBackup: json['chat_backup'] as bool? ?? defaults.chatBackup,
      theme: json['theme'] as String? ?? defaults.theme,
      lastSeenVisibility:
          json['last_seen_visibility'] as String? ??
          defaults.lastSeenVisibility,
      profilePhotoVisibility:
          json['profile_photo_visibility'] as String? ??
          defaults.profilePhotoVisibility,
      statusVisibility:
          json['status_visibility'] as String? ?? defaults.statusVisibility,
      appLockEnabled:
          json['app_lock_enabled'] as bool? ?? defaults.appLockEnabled,
      appLockTimer: json['app_lock_timer'] as String? ?? defaults.appLockTimer,
      mediaCompressionQuality:
          json['media_compression_quality'] as String? ??
          defaults.mediaCompressionQuality,
      fingerprintLock:
          json['fingerprint_lock'] as bool? ?? defaults.fingerprintLock,
      incognitoKeyboard:
          json['incognito_keyboard'] as bool? ?? defaults.incognitoKeyboard,
      disappearingMessagesTimer:
          json['disappearing_messages_timer'] as String? ??
          defaults.disappearingMessagesTimer,
      groupsPrivacy:
          json['groups_privacy'] as String? ?? defaults.groupsPrivacy,
      channelsPrivacy:
          json['channels_privacy'] as String? ?? defaults.channelsPrivacy,
      fontSize: json['font_size'] as String? ?? defaults.fontSize,
      useLessDataForCalls:
          json['use_less_data_for_calls'] as bool? ??
          defaults.useLessDataForCalls,
      wifiCalling: json['wifi_calling'] as bool? ?? defaults.wifiCalling,
      mobileDataAutoDownload:
          json['mobile_data_auto_download'] as bool? ??
          defaults.mobileDataAutoDownload,
      wifiAutoDownload:
          json['wifi_auto_download'] as bool? ?? defaults.wifiAutoDownload,
      roamingAutoDownload:
          json['roaming_auto_download'] as bool? ??
          defaults.roamingAutoDownload,
      twoStepEnabled:
          json['two_step_enabled'] as bool? ?? defaults.twoStepEnabled,
      recoveryEmail:
          json['recovery_email'] as String? ?? defaults.recoveryEmail,
      chatWallpaper:
          json['chat_wallpaper'] as String? ?? defaults.chatWallpaper,
      // twoStepPin is intentionally not restored — it is never persisted.
    );
  }

  factory AppUserSettings.fromJsonString(String raw) {
    try {
      return AppUserSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return defaults;
    }
  }
}
