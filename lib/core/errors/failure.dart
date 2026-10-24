import 'package:fpdart/fpdart.dart';

/// Result type used by application/domain use cases.
typedef ApiResult<T> = Either<Failure, T>;

/// The domain-side representation of a failure.
///
/// Failures are safe to surface in the UI and are produced by mapping
/// lower-level exceptions via [error_handler.dart].
sealed class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType(message: $message)';
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.cause});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.cause});
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause});
}
