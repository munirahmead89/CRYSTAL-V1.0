class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';

  factory AppException.network([String? message]) => AppException(
        message: message ?? 'No internet connection',
        code: 'NETWORK_ERROR',
      );

  factory AppException.auth([String? message]) => AppException(
        message: message ?? 'Authentication failed',
        code: 'AUTH_ERROR',
      );

  factory AppException.server([String? message]) => AppException(
        message: message ?? 'Server error occurred',
        code: 'SERVER_ERROR',
      );

  factory AppException.storage([String? message]) => AppException(
        message: message ?? 'Storage operation failed',
        code: 'STORAGE_ERROR',
      );

  factory AppException.permission([String? message]) => AppException(
        message: message ?? 'Permission denied',
        code: 'PERMISSION_ERROR',
      );

  factory AppException.unknown([Object? error]) => AppException(
        message: error?.toString() ?? 'An unexpected error occurred',
        code: 'UNKNOWN',
        originalError: error,
      );
}
