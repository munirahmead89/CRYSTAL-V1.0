import 'package:flutter/material.dart';

/// WhatsApp-style "verified" badge shown next to a display name for accounts
/// backed by Supabase's default email/password sign-in (or a guest that later
/// added an email + password). Hidden for anonymous-only guests.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 12});

  /// Diameter of the circular seal.
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Verified (email-synced account)',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(
          Icons.check_rounded,
          size: size * 0.7,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
