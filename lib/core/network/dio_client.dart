import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../logging/logger_service.dart';

/// Builds the shared [Dio] client for the Crystal Messenger backend.
///
/// Reliability/scale defaults:
///  - gzip advertised on every request (the platform HTTP client transparently
///    decompresses, saving bandwidth on chat payloads).
///  - HTTP keep-alive + connection reuse so the realtime-heavy traffic does
///    not re-handshake per RPC call.
///  - a bounded retry layer (exponential backoff + full jitter) that only
///    retries *idempotent* requests (GET/HEAD/OPTIONS/PUT/DELETE) — writes go
///    through the outbox engine which owns their retries.
Dio createDioClient({
  required AppConfig config,
  required LoggerService logger,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      // Non-2xx responses error out so the retry interceptor can decide which
      // transient ones deserve another attempt.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
      // Advertise that we accept compressed responses; the reference-client
      // already does HTTP keep-alive connection reuse by default.
      headers: const {'accept': 'application/json', 'accept-encoding': 'gzip'},
    ),
  );
  dio.interceptors.add(BackoffRetryInterceptor(logger, dio));
  dio.interceptors.add(DioLoggerInterceptor(logger));
  return dio;
}

/// Retries idempotent requests that hit transient failures using exponential
/// backoff with full jitter (Amazon-style: `min(base * 2^attempt, cap) + rand`).
///
/// Never retries POST bodies — optimistic outbox handling owns duplication
/// safety for sends, so retrying them at the transport layer would risk
/// duplicate messages. 401/403 responses are also never retried.
class BackoffRetryInterceptor extends Interceptor {
  BackoffRetryInterceptor(this._logger, this._dio, {this.maxAttempts = 3});

  final LoggerService _logger;
  final Dio _dio;
  final int maxAttempts;

  static const _retryableTimeoutTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.connectionError,
  };

  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  /// Base delay (400 ms) doubles per attempt and is capped at 5 s before the
  /// random jitter is added, keeping total sleep < ~6 s.
  static const _baseDelay = Duration(milliseconds: 400);
  static const _maxDelay = Duration(seconds: 5);

  final Map<String, int> _attempts = {};

  bool _isRetryable(DioException err) {
    final status = err.response?.statusCode;
    if (status == 401 || status == 403) return false;
    if (_retryableTimeoutTypes.contains(err.type)) return true;
    return status != null && (status == 408 || status == 429 || status >= 500);
  }

  Duration _schedule(int attempt) {
    final exp = min(attempt, 10);
    final baseMs = (_baseDelay.inMilliseconds << exp).clamp(
      0,
      _maxDelay.inMilliseconds,
    );
    final jitterMs = Random().nextInt(_baseDelay.inMilliseconds);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _attempts.remove(
      '${response.requestOptions.method} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final tag = '${options.method} ${options.uri}';
    final isIdempotent = _idempotentMethods.contains(
      options.method.toUpperCase(),
    );
    final attempt = _attempts[tag] ?? 0;
    final canRetry =
        attempt < maxAttempts &&
        isIdempotent &&
        options.extra['noRetry'] != true &&
        _isRetryable(err);

    if (!canRetry) {
      _attempts.remove(tag);
      handler.next(err);
      return;
    }

    _attempts[tag] = attempt + 1;
    final delay = _schedule(attempt);
    _logger.debug(
      '[Dio] retry #${attempt + 1} for $tag in ${delay.inMilliseconds}ms',
    );

    try {
      await Future<void>.delayed(delay);
    } catch (_) {
      handler.next(err);
      return;
    }

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (retryErr) {
      handler.next(retryErr as DioException? ?? err);
    }
  }
}

class DioLoggerInterceptor extends Interceptor {
  DioLoggerInterceptor(this._logger);

  final LoggerService _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('[Dio] ${options.method} ${options.uri}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.debug(
      '[Dio] ${response.statusCode} ${response.requestOptions.uri}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warn(
      '[Dio] ${err.requestOptions.method} ${err.requestOptions.uri} -> ${err.type.name}',
    );
    super.onError(err, handler);
  }
}
