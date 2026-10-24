import 'package:crystal_messenger/shared/widgets/avatar_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `avatars` bucket was `public = true`, so every avatar on the project was
/// readable by anyone who could obtain a user id. It is now private and the
/// client stores the bare object path, exchanging it for a short-lived signed
/// URL at render time.
///
/// That contract only holds if `avatarObjectPath` is exact, so the cases that
/// actually exist in the database are pinned here.
void main() {
  group('avatarObjectPath', () {
    test('a bare path passes through unchanged', () {
      // What the client writes today.
      expect(
        avatarObjectPath('82cbd43c-bc0f-48f4-a304-80dff1c1e43d.jpg'),
        '82cbd43c-bc0f-48f4-a304-80dff1c1e43d.jpg',
      );
    });

    test('a path with a cache-buster suffix keeps the filename', () {
      // uploadAvatar appends ?v=<ms> so a re-upload repaints immediately.
      expect(avatarObjectPath('abc.jpg?v=1717171717000'), 'abc.jpg');
    });

    test('a legacy public URL is reduced to its object path', () {
      // Rows written before the bucket went private. These must keep working
      // or the account silently loses its picture.
      const legacy =
          'https://npafjhshccbiukyjgfrt.supabase.co/storage/v1/'
          'object/public/avatars/82cbd43c-bc0f-48f4-a304-80dff1c1e43d.jpg';
      expect(
        avatarObjectPath(legacy),
        '82cbd43c-bc0f-48f4-a304-80dff1c1e43d.jpg',
      );
    });

    test('a legacy public URL with a query is also reduced', () {
      const legacy =
          'https://project.supabase.co/storage/v1/object/public/avatars/x.jpg?v=1';
      expect(avatarObjectPath(legacy), 'x.jpg');
    });

    test('an unrelated full URL degrades to its last segment', () {
      // Fails closed: whatever this resolves to will 403 rather than fetch an
      // unexpected object.
      expect(
        avatarObjectPath('https://cdn.example.com/a/b/pic.png'),
        'pic.png',
      );
    });

    test('empty and null inputs yield an empty path', () {
      expect(avatarObjectPath(null), '');
      expect(avatarObjectPath(''), '');
      expect(avatarObjectPath('   '), '');
    });

    test('a bare filename is never confused with a directory', () {
      expect(avatarObjectPath('avatar_x.jpg'), 'avatar_x.jpg');
    });
  });
}
