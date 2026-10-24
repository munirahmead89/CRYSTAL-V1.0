import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logger/logger.dart';

import '../logging/logger_service.dart';
import 'app_exceptions.dart';
import 'failure.dart';

final _logger = _buildLogger();

Logger _buildLogger() {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      colors: false,
      printEmojis: false,
      lineLength: 120,
    ),
  );
}

/// Installs global crash hooks so unexpected errors are logged and surfaced.
class ErrorHandler {
  static void initialize() {
    PlatformDispatcher.instance.onError = (error, stack) {
      _logger.e('Uncaught platform error', error: error, stackTrace: stack);
      return true;
    };

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _logger.e(
        'Flutter error',
        error: details.exception,
        stackTrace: details.stack,
      );
    };
  }

  static void recordError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
  }) {
    _logger.e(reason ?? 'Recorded error', error: error, stackTrace: stackTrace);
  }
}

/// Maps any error raised by the application into a domain [Failure].
Failure toFailure(Object error) {
  if (error is DioException) {
    return _fromDioException(error);
  }
  if (error is AppException) {
    return _fromAppException(error);
  }
  return UnknownFailure('Unexpected error: $error', cause: error);
}

Failure _fromDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return NetworkFailure(
        'The request timed out (${error.type.name}).',
        cause: error,
      );
    case DioExceptionType.connectionError:
      return NetworkFailure('Could not reach the server.', cause: error);
    case DioExceptionType.badCertificate:
      return NetworkFailure(
        'The server certificate could not be validated.',
        cause: error,
      );
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return AuthFailure(
          'Authorization failed (HTTP $status).',
          cause: error,
        );
      }
      if (status >= 500) {
        return ServerFailure('Server error (HTTP $status).', cause: error);
      }
      return ValidationFailure(
        'Request rejected (HTTP $status).',
        cause: error,
      );
    case DioExceptionType.cancel:
      return UnknownFailure('The request was cancelled.', cause: error);
    case DioExceptionType.unknown:
      return NetworkFailure('Request failed: ${error.message}', cause: error);
    default:
      return NetworkFailure('Request failed: ${error.message}', cause: error);
  }
}

Failure _fromAppException(AppException error) {
  return switch (error) {
    NetworkException() => NetworkFailure(error.message, cause: error),
    UnauthorizedException() ||
    ForbiddenException() => AuthFailure(error.message, cause: error),
    ValidationException() => ValidationFailure(error.message, cause: error),
    ServerException() => ServerFailure(error.message, cause: error),
    CacheException() => CacheFailure(error.message, cause: error),
    _ => UnknownFailure(error.message, cause: error),
  };
}

/// Runs a synchronous block and converts exceptions into [Failure]s.
Either<Failure, T> guard<T>(T Function() run, {LoggerService? logger}) {
  try {
    return Either.right(run());
  } catch (error, stackTrace) {
    logger?.error('Guard caught an error.', error, stackTrace);
    return Either.left(toFailure(error));
  }
}
