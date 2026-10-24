import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';

/// The caller's server-side ban state (WhatsApp-style suspension).
class BanStatus {
  const BanStatus({
    this.banned = false,
    this.reason,
    this.bannedAt,
    this.appealable = false,
  });

  factory BanStatus.fromRow(Map<String, dynamic>? row) {
    if (row == null || (row['banned'] ?? false) != true) {
      return const BanStatus();
    }
    return BanStatus(
      banned: true,
      reason: row['reason'] as String?,
      bannedAt: DateTime.tryParse(row['banned_at'] as String? ?? ''),
      appealable: row['appealable'] == true,
    );
  }

  final bool banned;
  final String? reason;
  final DateTime? bannedAt;
  final bool appealable;
}

/// Resolves the current ban state from the server. Degrades to "not banned"
/// whenever the backend is unreachable so the app never soft-locks offline.
final banStatusProvider = FutureProvider.autoDispose<BanStatus>((ref) async {
  try {
    final me = ref.watch(authStateProvider).user?.id ?? '';
    if (me.isEmpty) return const BanStatus();
    final client = ref.watch(supabaseClientProvider);
    final row = await client.rpc('get_ban_status');
    return BanStatus.fromRow(
      row is Map ? Map<String, dynamic>.from(row) : null,
    );
  } catch (_) {
    return const BanStatus();
  }
});

/// Submits a ban appeal (succeeds only when the account is actually banned).
final submitBanAppealProvider = Provider<SubmitAppealFn>(
  (ref) => (reason) async {
    final client = ref.read(supabaseClientProvider);
    await client.rpc('submit_ban_appeal', params: {'p_reason': reason});
    ref.invalidate(banStatusProvider);
  },
);

typedef SubmitAppealFn = Future<void> Function(String reason);
