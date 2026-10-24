import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Privacy invariant of Crystal Messenger: identity is phone-based and there is
/// **deliberately no username** anywhere in the app. This test statically
/// scans `lib/` to make sure no functional `username`/`peerUsername` identifier
/// (column, field, argument, variable) sneaks back in.
void main() {
  const target = 'lib';

  final files =
      Directory(target)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('there is no functional username identifier in lib/', () {
    final offenders = <String>[];

    // Only a doc-comment/UI mention or an intentional migration DROP is legal.
    // ("usernames" plural in UI copy does not match the \b-boundary pattern.)
    final usernamePattern = RegExp(
      r'\b(peerUsername|peer_username|username)\b',
    );

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();

        // Skip comments and the schema-migration DROP statements (legacy).
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('///') ||
            trimmed.startsWith('/*') ||
            line.contains('DROP COLUMN') ||
            // The WebRTC ICE server map uses `username` as a *protocol*
            // credential attribute (RFC 8489 TURN auth), never as an app
            // identity identifier — allow that one field explicitly.
            // (Lived in call_config.dart until calls were removed; the ICE
            // server list is still needed for the P2P message DataChannel.)
            (file.path.endsWith('ice_config.dart') &&
                line.contains("'username':"))) {
          continue;
        }

        if (usernamePattern.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: $trimmed');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Privacy violation: username identifiers found in lib/:\n'
          '${offenders.join('\n')}',
    );
  });

  test(
    'profile discovery and chat listing are keyed by phone, not username',
    () {
      final repos = files.where(
        (f) => f.path.contains('/repositories/') && f.path.endsWith('.dart'),
      );
      final content = repos
          .map((f) => f.readAsStringSync())
          .join('\n')
          .toLowerCase();

      expect(
        content.contains('username'),
        isFalse,
        reason: 'repositories must never reference a username column',
      );
    },
  );
}
