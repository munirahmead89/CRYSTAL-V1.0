/// Phone matching helpers.
library;

/// Crystal treats a phone number as the permanent identity of an account, but
/// the same human types it in different ways across devices:
/// `+92 324 0941091`, `03240941091`, `923240941091` or `00923240941091` should
/// all resolve to the same profile. Matching is therefore done on a canonical
/// digits-only form instead of the raw stored string.

/// Strips everything non-digit from [phone], preserving digits only.
String phoneDigits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

/// Canonical digits form used for matching. Maps a leading local `0`
/// (so `032…` → `92 32…`) and the `00` international prefix onto the default
/// country code `92`; any other input is kept as its plain digits.
String canonicalPhoneDigits(String phone) {
  final digits = phoneDigits(phone);
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('0')) return '92${digits.substring(1)}';
  return digits;
}

/// Every equivalent rendering of [phone] that should resolve to the same
/// profile: the canonical digits, the `+` E.164 form, the local `0` form and
/// the `00` international form. Exhaustive — a stale or hand-typed format on
/// either side is covered as long as at least one variant intersects.
List<String> phoneMatchVariants(String phone) {
  final digits = phoneDigits(phone);
  if (digits.isEmpty) return const [];
  final canonical = canonicalPhoneDigits(phone);

  final variants = <String>{canonical, '+$canonical', digits, '+$digits'};
  if (digits.startsWith('0')) {
    variants.add('+92${digits.substring(1)}');
  } else if (digits.startsWith('92')) {
    variants.add('0${digits.substring(2)}');
  } else if (digits.startsWith('00')) {
    variants.add('+${digits.substring(2)}');
  }

  final list = variants.toList()..sort();
  return list;
}

/// Normalizes a phone number to the canonical storage format (digits only
/// with country code, no `+`, no spaces). Matches the SQL `normalize_phone`
/// function so lookups and storage stay in sync.
String normalizePhoneForStorage(String phone) {
  return canonicalPhoneDigits(phone);
}
