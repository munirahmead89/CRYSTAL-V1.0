import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

import type { AuthUser, AuthSession } from '@/types';

interface AuthState {
  user: AuthUser | null;
  session: AuthSession | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isOnboarded: boolean;
  setUser: (user: AuthUser | null) => void;
  setSession: (session: AuthSession | null) => void;
  setAuthenticated: (authenticated: boolean) => void;
  setLoading: (loading: boolean) => void;
  setOnboarded: (onboarded: boolean) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      session: null,
      isAuthenticated: false,
      isLoading: true,
      isOnboarded: false,
      setUser: (user) => set({ user }),
      setSession: (session) => set({ session }),
      setAuthenticated: (isAuthenticated) => set({ isAuthenticated }),
      setLoading: (isLoading) => set({ isLoading }),
      setOnboarded: (isOnboarded) => set({ isOnboarded }),
      logout: () => set({ user: null, session: null, isAuthenticated: false, isOnboarded: false }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated,
        isOnboarded: state.isOnboarded,
      }),
    }
  )
);

interface UIState {
  theme: 'light' | 'dark' | 'system';
  sidebarOpen: boolean;
  setTheme: (theme: 'light' | 'dark' | 'system') => void;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
}

export const useUIStore = create<UIState>()(
  persist(
    (set) => ({
      theme: 'system',
      sidebarOpen: false,
      setTheme: (theme) => set({ theme }),
      toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
      setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
    }),
    {
      name: 'ui-storage',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);

interface ChatState {
  activeChatId: string | null;
  unreadCounts: Record<string, number>;
  setActiveChat: (chatId: string | null) => void;
  incrementUnread: (chatId: string) => void;
  clearUnread: (chatId: string) => void;
  setUnreadCount: (chatId: string, count: number) => void;
}

export const useChatStore = create<ChatState>((set) => ({
  activeChatId: null,
  unreadCounts: {},
  setActiveChat: (activeChatId) => set({ activeChatId }),
  incrementUnread: (chatId) =>
    set((state) => ({
      unreadCounts: {
        ...state.unreadCounts,
        [chatId]: (state.unreadCounts[chatId] || 0) + 1,
      },
    })),
  clearUnread: (chatId) =>
    set((state) => {
      const newUnreadCounts = { ...state.unreadCounts };
      delete newUnreadCounts[chatId];
      return { unreadCounts: newUnreadCounts };
    }),
  setUnreadCount: (chatId, count) =>
    set((state) => ({
      unreadCounts: {
        ...state.unreadCounts,
        [chatId]: count,
      },
    })),
}));

interface NetworkState {
  isConnected: boolean;
  connectionType: 'wifi' | 'cellular' | 'none' | 'unknown';
  setConnected: (connected: boolean) => void;
  setConnectionType: (type: NetworkState['connectionType']) => void;
}

export const useNetworkStore = create<NetworkState>((set) => ({
  isConnected: true,
  connectionType: 'unknown',
  setConnected: (isConnected) => set({ isConnected }),
  setConnectionType: (connectionType) => set({ connectionType }),
}));

interface NotificationState {
  pushToken: string | null;
  hasPermission: boolean;
  setPushToken: (token: string | null) => void;
  setPermission: (hasPermission: boolean) => void;
}

export const useNotificationStore = create<NotificationState>()(
  persist(
    (set) => ({
      pushToken: null,
      hasPermission: false,
      setPushToken: (pushToken) => set({ pushToken }),
      setPermission: (hasPermission) => set({ hasPermission }),
    }),
    {
      name: 'notification-storage',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);

interface MediaState {
  cache: Map<string, string>;
  addToCache: (key: string, value: string) => void;
  getFromCache: (key: string) => string | undefined;
  clearCache: () => void;
}

export const useMediaStore = create<MediaState>((set, get) => ({
  cache: new Map(),
  addToCache: (key, value) =>
    set((state) => {
      const newCache = new Map(state.cache);
      newCache.set(key, value);
      return { cache: newCache };
    }),
  getFromCache: (key) => get().cache.get(key),
  clearCache: () => set({ cache: new Map() }),
}));
