import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

part 'contacts_provider.freezed.dart';

@freezed
class ContactsState with _$ContactsState {
  const factory ContactsState({
    @Default([]) List<Map<String, dynamic>> contacts,
    @Default(false) bool isLoading,
    String? error,
  }) = _ContactsState;
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  final SupabaseClient _supabase;

  ContactsNotifier(this._supabase) : super(const ContactsState()) {
    loadContacts();
  }

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final contacts = await _supabase
          .from('contacts')
          .select('*, profile:profiles!contact_id(id, full_name, avatar_url, phone, is_online, last_seen)')
          .eq('user_id', userId)
          .order('display_name');

      state = state.copyWith(contacts: contacts, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> addContactByPhone(String phone) async {
    try {
      final result = await _supabase.rpc('search_user_by_phone', params: {
        'phone_number': phone,
      });
      if (result != null && result.isNotEmpty) {
        await _supabase.from('contacts').insert({
          'user_id': _supabase.auth.currentUser!.id,
          'contact_id': result['id'],
          'display_name': result['full_name'],
        });
        await loadContacts();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleFavorite(String contactId, bool current) async {
    try {
      await _supabase.from('contacts').update({
        'is_favorite': !current,
      }).eq('id', contactId);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> blockContact(String contactId, bool current) async {
    try {
      await _supabase.from('contacts').update({
        'is_blocked': !current,
      }).eq('id', contactId);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeContact(String contactId) async {
    try {
      await _supabase.from('contacts').delete().eq('id', contactId);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> renameContact(String contactId, String newName) async {
    try {
      await _supabase.from('contacts').update({
        'display_name': newName,
      }).eq('id', contactId);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ContactsNotifier(client);
});
