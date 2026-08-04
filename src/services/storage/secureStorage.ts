import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const isWeb = Platform.OS === 'web';

const webStorage = {
  getItem: async (key: string): Promise<string | null> => {
    if (isWeb) {
      return localStorage.getItem(key);
    }
    return null;
  },
  setItem: async (key: string, value: string): Promise<void> => {
    if (isWeb) {
      localStorage.setItem(key, value);
    }
  },
  removeItem: async (key: string): Promise<void> => {
    if (isWeb) {
      localStorage.removeItem(key);
    }
  },
};

export const secureStorage = {
  async getItem(key: string): Promise<string | null> {
    try {
      if (isWeb) {
        return webStorage.getItem(key);
      }
      return await SecureStore.getItemAsync(key);
    } catch (error) {
      console.error(`SecureStorage getItem error for key "${key}":`, error);
      return null;
    }
  },

  async setItem(key: string, value: string): Promise<void> {
    try {
      if (isWeb) {
        return webStorage.setItem(key, value);
      }
      return await SecureStore.setItemAsync(key, value);
    } catch (error) {
      console.error(`SecureStorage setItem error for key "${key}":`, error);
      throw error;
    }
  },

  async removeItem(key: string): Promise<void> {
    try {
      if (isWeb) {
        return webStorage.removeItem(key);
      }
      return await SecureStore.deleteItemAsync(key);
    } catch (error) {
      console.error(`SecureStorage removeItem error for key "${key}":`, error);
      throw error;
    }
  },

  async clear(): Promise<void> {
    try {
      if (isWeb) {
        localStorage.clear();
        return;
      }
      const keys = ['auth_token', 'refresh_token', 'user_data', 'push_token', 'encryption_key'];
      await Promise.all(keys.map((key) => SecureStore.deleteItemAsync(key)));
    } catch (error) {
      console.error('SecureStorage clear error:', error);
      throw error;
    }
  },
};

export const storageKeys = {
  authToken: 'auth_token',
  refreshToken: 'refresh_token',
  userData: 'user_data',
  pushToken: 'push_token',
  encryptionKey: 'encryption_key',
  biometricEnabled: 'biometric_enabled',
  pinCode: 'pin_code',
} as const;