import 'dart:math';

final _random = Random.secure();

/// Returns a random RFC-4122 v4 UUID string.
String generateUuid() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Short random suffix for file names uploaded to storage.
String randomHex([int length = 8]) {
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    buf.write(_random.nextInt(16).toRadixString(16));
  }
  return buf.toString();
}
