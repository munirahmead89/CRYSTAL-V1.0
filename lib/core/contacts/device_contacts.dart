import 'package:flutter/services.dart';

class DeviceContact {
  const DeviceContact({required this.displayName, required this.phone});

  final String displayName;
  final String phone;
}

class DeviceContacts {
  static const _channel = MethodChannel('crystal/contacts');

  static Future<List<DeviceContact>> read() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('readContacts');
    return (raw ?? const [])
        .whereType<Map>()
        .map((row) => DeviceContact(
              displayName: '${row['displayName'] ?? ''}',
              phone: '${row['phone'] ?? ''}',
            ))
        .where((contact) => contact.phone.trim().isNotEmpty)
        .toList(growable: false);
  }
}
