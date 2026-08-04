export const CONSTANTS = {
  APP_NAME: 'Crystal Messenger',
  APP_VERSION: '1.0.0',
  BUILD_NUMBER: 1,

  AUTH: {
    TOKEN_REFRESH_THRESHOLD: 5 * 60 * 1000,
    MAX_LOGIN_ATTEMPTS: 5,
    LOCKOUT_DURATION: 15 * 60 * 1000,
    PASSWORD_MIN_LENGTH: 8,
    USERNAME_MIN_LENGTH: 3,
    USERNAME_MAX_LENGTH: 30,
  },

  CHAT: {
    MESSAGE_MAX_LENGTH: 4000,
    MAX_MESSAGES_PER_REQUEST: 50,
    TYPING_INDICATOR_TIMEOUT: 3000,
    RECONNECT_DELAY: 1000,
    MAX_RECONNECT_ATTEMPTS: 10,
    MESSAGE_RETRY_DELAY: 2000,
    MAX_MESSAGE_RETRIES: 3,
  },

  MEDIA: {
    MAX_IMAGE_SIZE: 10 * 1024 * 1024,
    MAX_VIDEO_SIZE: 50 * 1024 * 1024,
    MAX_FILE_SIZE: 100 * 1024 * 1024,
    MAX_AUDIO_DURATION: 5 * 60,
    IMAGE_QUALITY: 0.8,
    THUMBNAIL_SIZE: 200,
    SUPPORTED_IMAGE_TYPES: ['image/jpeg', 'image/png', 'image/webp', 'image/heic'],
    SUPPORTED_VIDEO_TYPES: ['video/mp4', 'video/quicktime', 'video/x-matroska'],
    SUPPORTED_AUDIO_TYPES: ['audio/m4a', 'audio/mp3', 'audio/wav', 'audio/ogg'],
    SUPPORTED_FILE_TYPES: ['application/pdf', 'text/plain', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  },

  NOTIFICATIONS: {
    MAX_PAYLOAD_SIZE: 4096,
    DEFAULT_PRIORITY: 'high' as const,
    CHANNEL_ID: 'crystal-messenger',
    CHANNEL_NAME: 'Crystal Messenger',
    CHANNEL_DESCRIPTION: 'Messages and calls notifications',
  },

  STORAGE: {
    CACHE_EXPIRY: 7 * 24 * 60 * 60 * 1000,
    MAX_CACHE_SIZE: 100 * 1024 * 1024,
    OFFLINE_QUEUE_MAX_SIZE: 1000,
    SYNC_INTERVAL: 30000,
  },

  NETWORK: {
    REQUEST_TIMEOUT: 30000,
    UPLOAD_TIMEOUT: 120000,
    RETRY_DELAYS: [1000, 2000, 5000, 10000, 30000],
    MAX_RETRIES: 5,
  },

  DATABASE: {
    PAGE_SIZE: 20,
    MAX_PAGE_SIZE: 100,
    PRELOAD_THRESHOLD: 5,
  },

  UI: {
    ANIMATION_DURATION: 250,
    DEBOUNCE_DELAY: 300,
    THROTTLE_DELAY: 100,
    TOAST_DURATION: 3000,
    MODAL_ANIMATION_DURATION: 200,
  },

  SECURITY: {
    BIOMETRIC_PROMPT_TITLE: 'Crystal Messenger',
    BIOMETRIC_PROMPT_SUBTITLE: 'Authenticate to access your messages',
    PIN_LENGTH: 6,
    SESSION_TIMEOUT: 30 * 60 * 1000,
    ENCRYPTION_ALGORITHM: 'AES-GCM',
    KEY_DERIVATION_ITERATIONS: 100000,
  },

  REGEX: {
    EMAIL: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    PHONE: /^\+?[1-9]\d{1,14}$/,
    USERNAME: /^[a-zA-Z0-9_]{3,30}$/,
    PASSWORD: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/,
  },

  ERROR_CODES: {
    NETWORK_ERROR: 'NETWORK_ERROR',
    UNAUTHORIZED: 'UNAUTHORIZED',
    FORBIDDEN: 'FORBIDDEN',
    NOT_FOUND: 'NOT_FOUND',
    VALIDATION_ERROR: 'VALIDATION_ERROR',
    CONFLICT: 'CONFLICT',
    RATE_LIMITED: 'RATE_LIMITED',
    INTERNAL_ERROR: 'INTERNAL_ERROR',
    TIMEOUT: 'TIMEOUT',
    OFFLINE: 'OFFLINE',
  },
} as const;

export type Constants = typeof CONSTANTS;