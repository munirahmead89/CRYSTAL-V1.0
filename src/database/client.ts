import type { SupabaseClient, User, Session, AuthChangeEvent } from '@supabase/supabase-js';
import { createClient } from '@supabase/supabase-js';
import { Platform, AppState } from 'react-native';
import * as SecureStore from 'expo-secure-store';

import { generateId } from '@/utils/id';

export { generateId };

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

class SecureStoreAdapter {
  async getItem(key: string): Promise<string | null> {
    try {
      return await SecureStore.getItemAsync(key);
    } catch {
      return null;
    }
  }

  async setItem(key: string, value: string): Promise<void> {
    try {
      await SecureStore.setItemAsync(key, value);
    } catch (error) {
      console.error('SecureStore setItem error:', error);
    }
  }

  async removeItem(key: string): Promise<void> {
    try {
      await SecureStore.deleteItemAsync(key);
    } catch (error) {
      console.error('SecureStore removeItem error:', error);
    }
  }
}

export const supabase: SupabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: Platform.OS === 'web' ? undefined : new SecureStoreAdapter(),
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: Platform.OS === 'web',
    flowType: 'pkce',
  },
  global: {
    fetch: (url, options) => {
      return fetch(url, {
        ...options,
        headers: {
          ...options?.headers,
          'X-Client-Info': `crystal-messenger/${Platform.OS}`,
        },
      });
    },
  },
});

let appStateSubscription: { remove: () => void } | null = null;
let authListenerStarted = false;

export function subscribeToAuthChanges(
  callback: (event: AuthChangeEvent, session: Session | null) => void
): () => void {
  const { data } = supabase.auth.onAuthStateChange((event, session) => {
    callback(event, session);
  });
  return () => {
    data.subscription.unsubscribe();
  };
}

export function initializeAuthListener(): () => void {
  if (authListenerStarted) {
    return () => {};
  }
  authListenerStarted = true;

  appStateSubscription = AppState.addEventListener('change', (state) => {
    if (state === 'active') {
      supabase.auth.startAutoRefresh();
    } else {
      supabase.auth.stopAutoRefresh();
    }
  });

  return () => {
    appStateSubscription?.remove();
    appStateSubscription = null;
    authListenerStarted = false;
  };
}

export async function getCurrentUser(): Promise<User | null> {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function getCurrentSession(): Promise<Session | null> {
  const { data: { session } } = await supabase.auth.getSession();
  return session;
}

export async function signInAnonymously() {
  const { data, error } = await supabase.auth.signInAnonymously();
  return { data, error };
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  return { error };
}

export async function updateProfile(updates: {
  full_name?: string;
  avatar_url?: string;
  bio?: string;
}) {
  const { data, error } = await supabase.auth.updateUser({
    data: updates,
  });
  return { data, error };
}

export { supabase as default };