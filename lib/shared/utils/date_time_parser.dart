/// Parses timestamps coming from Supabase (ISO 8601 with `T` or a space
/// separator, and either a `Z` suffix or a numeric offset).
DateTime? parseSupabaseDate(Object? value) {
  if (value == null || value is! String || value.isEmpty) return null;
  final normalized = value.startsWith(RegExp(r'\d{4}-\d{2}-\d{2} '))
      ? value.replaceFirst(' ', 'T')
      : value;
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null && normalized.endsWith('Z')) {
    return DateTime.tryParse(normalized.replaceFirst(RegExp(r'Z$'), '+00:00'));
  }
  return parsed;
}

DateTime? parseDateOrNow(Object? value) =>
    parseSupabaseDate(value) ?? DateTime.now();
