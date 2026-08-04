import { BaseRepository } from '../base/BaseRepository';
import { supabase } from '@/database/client';
import type { Contact, UserContact } from '@/types/database';

export class ContactRepository extends BaseRepository<Contact> {
  constructor() {
    super('contacts');
  }

  async getContacts(userId: string): Promise<UserContact[]> {
    try {
      const { data, error } = await supabase
        .from('contacts')
        .select(`
          *,
          profile:profiles!contacts_contact_id_fkey(*)
        `)
        .eq('user_id', userId)
        .eq('is_blocked', false);

      if (error) {
        this.handleError(error);
      }

      return (data || []) as UserContact[];
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async addContact(userId: string, contactPhone: string, displayName: string): Promise<Contact> {
    try {
      // Find the profile of the contact by phone
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('phone', contactPhone)
        .single();

      if (profileError) {
        if (profileError.code === 'PGRST116') {
          throw new Error('No Crystal user found with this phone number');
        }
        this.handleError(profileError);
      }

      if (profile.id === userId) {
        throw new Error('You cannot add yourself as a contact');
      }

      // Check if contact already exists
      const { data: existing, error: existError } = await supabase
        .from('contacts')
        .select('*')
        .eq('user_id', userId)
        .eq('contact_id', profile.id)
        .maybeSingle();

      if (existError) {
        this.handleError(existError);
      }

      if (existing) {
        throw new Error('Contact already exists');
      }

      // Create contact row
      return this.create({
        id: crypto.randomUUID(),
        user_id: userId,
        contact_id: profile.id,
        display_name: displayName,
        is_favorite: false,
        is_blocked: false,
      });
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async removeContact(userId: string, contactId: string): Promise<void> {
    try {
      const { error } = await supabase
        .from('contacts')
        .delete()
        .eq('user_id', userId)
        .eq('contact_id', contactId);

      if (error) {
        this.handleError(error);
      }
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async blockContact(userId: string, contactId: string): Promise<void> {
    try {
      const { error } = await supabase
        .from('contacts')
        .update({ is_blocked: true, updated_at: new Date().toISOString() })
        .eq('user_id', userId)
        .eq('contact_id', contactId);

      if (error) {
        this.handleError(error);
      }
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async checkContactExists(userId: string, contactPhone: string): Promise<boolean> {
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id')
        .eq('phone', contactPhone)
        .single();

      if (!profile) return false;

      const { data } = await supabase
        .from('contacts')
        .select('id')
        .eq('user_id', userId)
        .eq('contact_id', profile.id)
        .maybeSingle();

      return !!data;
    } catch {
      return false;
    }
  }
}

export const contactRepository = new ContactRepository();
