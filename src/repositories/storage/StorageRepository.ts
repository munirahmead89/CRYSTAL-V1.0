import { supabase } from '@/database/client';
import { logger } from '@/utils/logger';

export class StorageRepository {
  async uploadAvatar(userId: string, fileUri: string): Promise<string> {
    try {
      logger.info('Uploading avatar for user', { userId, fileUri });

      // Fetch the file URI to convert it to a Blob for upload in React Native
      const response = await fetch(fileUri);
      const blob = await response.blob();

      const path = `${userId}/avatar.jpg`;
      
      const { error } = await supabase.storage
        .from('avatars')
        .upload(path, blob, {
          contentType: 'image/jpeg',
          upsert: true,
        });

      if (error) {
        throw error;
      }

      const { data: { publicUrl } } = supabase.storage
        .from('avatars')
        .getPublicUrl(path);

      // Append a cache-buster timestamp so changes render immediately
      const publicUrlWithCacheBuster = `${publicUrl}?t=${Date.now()}`;

      logger.info('Avatar uploaded successfully', { userId, publicUrl: publicUrlWithCacheBuster });
      return publicUrlWithCacheBuster;
    } catch (error) {
      logger.error('Failed to upload avatar', { userId }, error as Error);
      throw error;
    }
  }
}

export const storageRepository = new StorageRepository();
