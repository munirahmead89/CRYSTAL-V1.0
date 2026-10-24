/// The set of users currently online.
///
/// Kept in its own file because BOTH presence backends produce it: the Redis
/// gateway and the Realtime fallback. Callers depend on this one type, not on
/// which transport is live.
class PresenceSnapshot {
  const PresenceSnapshot({required this.onlineUserIds, required this.syncedAt});

  const PresenceSnapshot.empty() : onlineUserIds = const {}, syncedAt = null;

  final Set<String> onlineUserIds;
  final DateTime? syncedAt;

  bool isOnline(String userId) => onlineUserIds.contains(userId);

  int get count => onlineUserIds.length;

  /// Fraction of the roster that is online, 0.0 - 1.0.
  double ratio(int total) {
    if (total <= 0) return 0;
    return (onlineUserIds.length / total).clamp(0.0, 1.0).toDouble();
  }

  bool get isEmpty => onlineUserIds.isEmpty;
}
