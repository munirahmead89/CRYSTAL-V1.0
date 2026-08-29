class AppConstants {
  AppConstants._();

  static const appName = 'Crystal Messenger';
  static const maxFileSize = 100 * 1024 * 1024; // 100MB
  static const maxImageSize = 16 * 1024 * 1024; // 16MB
  static const maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const maxAudioSize = 16 * 1024 * 1024; // 16MB
  static const maxAvatarSize = 5 * 1024 * 1024; // 5MB

  static const disappearingMessageDuration = Duration(hours: 24);
  static const statusDuration = Duration(hours: 24);
  static const typingTimeout = Duration(seconds: 5);
  static const heartbeatInterval = Duration(seconds: 30);
  static const presenceHeartbeat = Duration(seconds: 25);
  static const reconnectBaseDelay = Duration(seconds: 1);
  static const reconnectMaxDelay = Duration(seconds: 30);
  static const callRingTimeout = Duration(seconds: 45);
  static const messagePageSize = 50;
  static const chatPageSize = 30;

  static const phoneRegex = r'^\+?[1-9]\d{1,14}$';
  static const emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';

  static const avatarBucket = 'avatars';
  static const mediaBucket = 'media';

  static const wsFrameLimit = 256 * 1024; // 256KB
  static const wsRateLimit = 120; // events per 10s
}
