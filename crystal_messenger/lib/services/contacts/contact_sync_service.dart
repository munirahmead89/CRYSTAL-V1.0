import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/supabase_provider.dart';
import '../../core/utils/logger.dart';

class ContactSyncService {
  final SupabaseClient _supabase;

  ContactSyncService(this._supabase);

  Future<List<Map<String, dynamic>>> syncDeviceContacts() async {
    try {
      if (!await FlutterContacts.requestPermission()) {
        return [];
      }

      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      final phoneNumbers = deviceContacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) =>
              c.phones.first.number.replaceAll(RegExp(r'[^\d+]'), ''))
          .where((p) => p.isNotEmpty)
          .toList();

      if (phoneNumbers.isEmpty) return [];

      final matched = await _supabase.rpc('match_contacts', params: {
        'phone_numbers': phoneNumbers,
      });

      return List<Map<String, dynamic>>.from(matched ?? []);
    } catch (e) {
      Logger.error('ContactSync', 'Sync failed', e);
      return [];
    }
  }
}

final contactSyncServiceProvider = Provider<ContactSyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ContactSyncService(client);
});
