import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

class ContactsRepository {
  final SupabaseClient _supabase;

  ContactsRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getContacts(String userId) async {
    final response = await _supabase
        .from('contacts')
        .select('*, profile:profiles!contact_id(id, full_name, avatar_url, phone, is_online, last_seen)')
        .eq('user_id', userId)
        .order('display_name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> searchByPhone(String phone) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('phone', phone)
        .maybeSingle();
    return response;
  }

  Future<void> addContact({
    required String userId,
    required String contactId,
    String? displayName,
  }) async {
    await _supabase.from('contacts').upsert({
      'user_id': userId,
      'contact_id': contactId,
      if (displayName != null) 'display_name': displayName,
    });
  }

  Future<void> toggleFavorite(String contactId, bool isFavorite) async {
    await _supabase.from('contacts').update({
      'is_favorite': !isFavorite,
    }).eq('id', contactId);
  }

  Future<void> toggleBlock(String contactId, bool isBlocked) async {
    await _supabase.from('contacts').update({
      'is_blocked': !isBlocked,
    }).eq('id', contactId);
  }

  Future<void> removeContact(String contactId) async {
    await _supabase.from('contacts').delete().eq('id', contactId);
  }

  Future<void> renameContact(String contactId, String newName) async {
    await _supabase.from('contacts').update({
      'display_name': newName,
    }).eq('id', contactId);
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ContactsRepository(client);
});
