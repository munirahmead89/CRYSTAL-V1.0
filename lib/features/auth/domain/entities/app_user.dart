/// Minimal authenticated user representation held by the app.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.isAnonymous = false,
  });

  final String id;
  final String email;

  /// True when the account is a Supabase anonymous (guest) session.
  final bool isAnonymous;

  bool get isEmpty => id.isEmpty;

  /// Guests can be upgraded to permanent accounts without losing data.
  bool get isGuest => isAnonymous;
}
