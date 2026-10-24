/// Exception hierarchy used by the data layer.
///
/// These represent failures at the edge (network, storage, database, auth).
/// Use cases map them into [Failure] via `toFailure` in error_handler.dart.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

class TimeoutException extends NetworkException {
  const TimeoutException(super.message, {super.cause});
}

class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode, super.cause});

  final int? statusCode;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message, {super.cause})
    : super(statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException(super.message, {super.cause})
    : super(statusCode: 403);
}

class ValidationException extends ApiException {
  const ValidationException(super.message, {super.cause})
    : super(statusCode: 400);
}

class ServerException extends ApiException {
  const ServerException(super.message, {super.cause}) : super(statusCode: 500);
}

class CacheException extends AppException {
  const CacheException(super.message, {super.cause});
}

/// Chunked media transfer failed (upload or reassembly).
///
/// Declared here rather than next to the transfer engine because
/// [AppException] is `sealed`: a subtype has to live in the same library.
class MediaTransferException extends AppException {
  const MediaTransferException(super.message, {super.cause});
}

/// The free-tier storage budget cannot fit the file.
///
/// Distinct from [MediaTransferException] because this is a *policy* refusal
/// that retrying cannot fix — the caller should surface the quota and the
/// remedy, not a "try again" affordance.
class MediaQuotaException extends MediaTransferException {
  const MediaQuotaException(super.message, {super.cause});
}

class UnknownAppException extends AppException {
  const UnknownAppException(super.message, {super.cause});
}
