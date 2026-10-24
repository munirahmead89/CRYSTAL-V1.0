/// Why a relay call failed, and therefore whether retrying can help.
///
/// This is the single classification point for every relay failure. The outbox,
/// the acknowledgement ledger and the deletion service all branch on the
/// [kind] rather than on a message string, because "try again" and "this will
/// never work as written" need opposite handling and a Postgres error message
/// is not a stable thing to parse.
enum RelayFailureKind {
  /// No usable session. Retry after a token refresh.
  unauthenticated,

  /// Authenticated but not permitted. Retrying unchanged will never work.
  unauthorized,

  /// The request itself is invalid. Retrying unchanged will never work.
  invalidRequest,

  /// Server-side rate limit. Back off and retry later.
  rateLimited,

  /// Network, timeout or 5xx. Retry.
  transport,

  /// The server answered, but not with something this build can read.
  malformedResponse,

  /// The function is missing on the server — the migration has not been applied.
  unavailable,

  unknown;

  /// True when the same request has a real chance of succeeding later.
  ///
  /// [unauthorized] is deliberately excluded: a message the user may not send
  /// will still be unsendable in a minute, and retrying it only burns the
  /// rate-limit budget.
  bool get isRetryable =>
      this == RelayFailureKind.transport ||
      this == RelayFailureKind.rateLimited ||
      this == RelayFailureKind.unauthenticated;
}

/// A relay operation that did not succeed.
///
/// Carries a [kind] so the caller can decide between "keep the row and retry"
/// and "surface a permanent failure", without inspecting a message string.
///
/// [message] is guaranteed safe to log and to show: it names the RPC and a
/// SQLSTATE, never the payload. A Postgres error message can quote the offending
/// value, and for a messaging backend that value is frequently the message body.
class RelayException implements Exception {
  const RelayException(this.message, this.kind, {this.cause});

  final String message;
  final RelayFailureKind kind;
  final Object? cause;

  bool get isRetryable => kind.isRetryable;

  @override
  String toString() => 'RelayException($kind): $message';
}
