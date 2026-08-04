import { View as MockView } from 'react-native';
import 'jest-expo';

process.env.EXPO_PUBLIC_SUPABASE_URL = 'https://test-project.supabase.co';
process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY = 'test-anon-key';

jest.mock('@react-native-async-storage/async-storage', () => ({
  getItem: jest.fn(),
  setItem: jest.fn(),
  removeItem: jest.fn(),
  clear: jest.fn(),
  getAllKeys: jest.fn(),
  multiGet: jest.fn(),
  multiSet: jest.fn(),
  multiRemove: jest.fn(),
}));

jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

jest.mock('expo-crypto', () => ({
  randomUUID: jest.fn(() => '00000000-0000-4000-8000-000000000000'),
  getRandomBytes: jest.fn((n: number) => new Uint8Array(n)),
  getRandomBytesAsync: jest.fn(async (n: number) => new Uint8Array(n)),
  getRandomValues: jest.fn(<T extends ArrayBufferView>(array: T): T => array),
}));

jest.mock('@expo/vector-icons', () => {
  const mockIcon = (props: any) => <MockView {...props} />;
  return {
    Ionicons: mockIcon,
    MaterialIcons: mockIcon,
    Feather: mockIcon,
    FontAwesome: mockIcon,
    MaterialCommunityIcons: mockIcon,
    AntDesign: mockIcon,
    Entypo: mockIcon,
    EvilIcons: mockIcon,
    FontAwesome5: mockIcon,
    Foundation: mockIcon,
    Octicons: mockIcon,
    SimpleLineIcons: mockIcon,
    Zocial: mockIcon,
  };
});

jest.mock('expo-router', () => ({
  useRouter: () => ({
    push: jest.fn(),
    replace: jest.fn(),
    back: jest.fn(),
  }),
  useLocalSearchParams: () => ({}),
  useSegments: () => [],
  usePathname: () => '/',
  Link: ({ children, ...props }: any) => <MockView {...props}>{children}</MockView>,
  Stack: ({ children }: any) => <MockView>{children}</MockView>,
  Tabs: ({ children }: any) => <MockView>{children}</MockView>,
  Redirect: (_props: any) => <MockView testID="redirect" />,
}));

jest.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    auth: {
      getUser: jest.fn(),
      getSession: jest.fn(),
      signInAnonymously: jest.fn(),
      signOut: jest.fn(),
      onAuthStateChange: jest.fn(() => ({ data: { subscription: { unsubscribe: jest.fn() } } })),
      startAutoRefresh: jest.fn(),
      stopAutoRefresh: jest.fn(),
      updateUser: jest.fn(),
    },
    from: jest.fn(() => ({
      select: jest.fn().mockReturnThis(),
      insert: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      delete: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      neq: jest.fn().mockReturnThis(),
      gt: jest.fn().mockReturnThis(),
      gte: jest.fn().mockReturnThis(),
      lt: jest.fn().mockReturnThis(),
      lte: jest.fn().mockReturnThis(),
      like: jest.fn().mockReturnThis(),
      ilike: jest.fn().mockReturnThis(),
      is: jest.fn().mockReturnThis(),
      in: jest.fn().mockReturnThis(),
      contains: jest.fn().mockReturnThis(),
      containedBy: jest.fn().mockReturnThis(),
      rangeGt: jest.fn().mockReturnThis(),
      rangeGte: jest.fn().mockReturnThis(),
      rangeLt: jest.fn().mockReturnThis(),
      rangeLte: jest.fn().mockReturnThis(),
      rangeAdjacent: jest.fn().mockReturnThis(),
      overlaps: jest.fn().mockReturnThis(),
      textSearch: jest.fn().mockReturnThis(),
      match: jest.fn().mockReturnThis(),
      not: jest.fn().mockReturnThis(),
      or: jest.fn().mockReturnThis(),
      filter: jest.fn().mockReturnThis(),
      order: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      range: jest.fn().mockReturnThis(),
      single: jest.fn(),
      maybeSingle: jest.fn(),
      count: jest.fn(),
    })),
    rpc: jest.fn(),
    storage: {
      from: jest.fn(() => ({
        upload: jest.fn(),
        download: jest.fn(),
        remove: jest.fn(),
        list: jest.fn(),
        getPublicUrl: jest.fn(),
        createSignedUrl: jest.fn(),
      })),
    },
    realtime: {
      channel: jest.fn(() => ({
        on: jest.fn().mockReturnThis(),
        subscribe: jest.fn().mockReturnThis(),
        unsubscribe: jest.fn(),
      })),
    },
  }),
  PostgrestError: class extends Error {
    constructor(message: string) {
      super(message);
      this.name = 'PostgrestError';
    }
  },
}));

jest.mock('expo-constants', () => ({
  expoConfig: {
    extra: {
      eas: { projectId: 'test' },
    },
  },
}));

jest.mock('expo-device', () => ({
  isDevice: true,
  deviceName: 'Test Device',
  osVersion: '1.0',
  modelName: 'Test Model',
  manufacturer: 'Test',
  brand: 'Test',
  totalMemory: 1000,
  supportedCpuArchitectures: ['arm64'],
}));

jest.mock('expo-application', () => ({
  applicationId: 'com.crystal.messenger',
  applicationName: 'Crystal Messenger',
  buildVersion: '1',
  nativeBuildVersion: '1',
  nativeApplicationVersion: '1.0.0',
}));

jest.mock('expo-linking', () => ({
  createURL: jest.fn((path: string) => `crystal-messenger://${path}`),
  parse: jest.fn(),
  openURL: jest.fn(),
}));

jest.mock('expo-network', () => ({
  getNetworkStateAsync: jest.fn().mockResolvedValue({ isConnected: true, type: 'wifi' }),
  addListener: jest.fn(),
  removeListeners: jest.fn(),
}));

jest.mock('@react-native-community/netinfo', () => ({
  addEventListener: jest.fn(() => jest.fn()),
  fetch: jest.fn().mockResolvedValue({ isConnected: true, type: 'wifi' }),
}));

(globalThis as any).__DEV__ = true;
