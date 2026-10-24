import 'package:crystal_messenger/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseAuthRepository.friendlyMessage', () {
    test('parses a JSON GoTrue envelope and maps the anonymous failure', () {
      const raw =
          '{"code":"unexpected_failure",'
          '"message":"Database error creating anonymous user"}';
      expect(
        SupabaseAuthRepository.friendlyMessage(raw),
        'Could not create a guest session. Please try again.',
      );
    });

    test('maps raw Postgres not-null violations to generic copy', () {
      const raw =
          'null value in column "phone" of relation "profiles" '
          'violates not-null constraint';
      expect(
        SupabaseAuthRepository.friendlyMessage(raw),
        'Something went wrong on our side. Please try again.',
      );
    });

    test('never leaks unexpected raw backend text', () {
      expect(
        SupabaseAuthRepository.friendlyMessage(
          'JWT expired. updateUserToken failed.',
        ),
        'Something went wrong. Please try again.',
      );
    });

    test('keeps known friendly mappings', () {
      expect(
        SupabaseAuthRepository.friendlyMessage('Invalid login credentials'),
        'Wrong email or password.',
      );
      expect(
        SupabaseAuthRepository.friendlyMessage('User already registered'),
        'That email is already registered. Try signing in instead.',
      );
      expect(
        SupabaseAuthRepository.friendlyMessage(
          'Password should be at least 6 characters',
        ),
        'Password must be at least 6 characters long.',
      );
      expect(
        SupabaseAuthRepository.friendlyMessage('Too many requests. Rate limit'),
        'Too many attempts. Wait a moment and try again.',
      );
    });

    test('maps plain anonymous database failure', () {
      expect(
        SupabaseAuthRepository.friendlyMessage(
          'Database error creating new user',
        ),
        'Could not create a guest session. Please try again.',
      );
    });
  });
}
