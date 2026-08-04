import * as Linking from 'expo-linking';

export const linking = {
  prefixes: [Linking.createURL('/')],
  config: {
    screens: {
      '(auth)': {
        screens: {
          login: 'login',
          register: 'register',
          'forgot-password': 'forgot-password',
        },
      },
      '(app)': {
        screens: {
          index: 'chats',
          'chats/[id]': 'chat/:id',
          contacts: 'contacts',
          'contacts/[id]': 'contact/:id',
          profile: 'profile',
          settings: 'settings',
        },
      },
    },
  },
};

export function getDeepLink(path: string): string {
  return Linking.createURL(path);
}

export function parseDeepLink(url: string): { path: string; params: Record<string, string> } | null {
  const parsed = Linking.parse(url);
  if (!parsed) return null;

  return {
    path: parsed.path || '/',
    params: parsed.queryParams as Record<string, string>,
  };
}

export function openDeepLink(path: string): Promise<boolean> {
  const url = getDeepLink(path);
  return Linking.openURL(url);
}

export const routes = {
  auth: {
    login: '/(auth)/login',
    register: '/(auth)/register',
    forgotPassword: '/(auth)/forgot-password',
  },
  app: {
    chats: '/(app)',
    chat: (id: string) => `/(app)/chats/${id}`,
    contacts: '/(app)/contacts',
    contact: (id: string) => `/(app)/contacts/${id}`,
    profile: '/(app)/profile',
    settings: '/(app)/settings',
  },
} as const;

export type AppRoutes = typeof routes;