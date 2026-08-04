import { BaseRepository } from '../base/BaseRepository';
import { supabase } from '@/database/client';
import type { Profile, ProfileInsert, ProfileUpdate } from '@/types/database';

export class AuthRepository extends BaseRepository<Profile> {
  constructor() {
    super('profiles');
  }

  async createProfile(userId: string, data: Omit<ProfileInsert, 'id'>): Promise<Profile> {
    return this.create({ ...data, id: userId });
  }

  async getProfile(userId: string): Promise<Profile | null> {
    return this.findById(userId);
  }

  async updateProfile(userId: string, updates: ProfileUpdate): Promise<Profile> {
    return this.update(userId, updates);
  }

  async getProfileByPhone(phone: string): Promise<Profile | null> {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('phone', phone)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        this.handleError(error);
      }

      return data as Profile | null;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async searchProfiles(query: string, limit = 20): Promise<Profile[]> {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .or(`full_name.ilike.%${query}%,phone.ilike.%${query}%`)
        .limit(limit);

      if (error) {
        this.handleError(error);
      }

      return (data as Profile[]) || [];
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async updateOnlineStatus(userId: string, isOnline: boolean): Promise<void> {
    await this.update(userId, {
      is_online: isOnline,
      last_seen: new Date().toISOString(),
    });
  }

  async getOnlineUsers(userIds: string[]): Promise<Profile[]> {
    if (userIds.length === 0) return [];

    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .in('id', userIds)
        .eq('is_online', true);

      if (error) {
        this.handleError(error);
      }

      return (data as Profile[]) || [];
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }
}

export const authRepository = new AuthRepository();