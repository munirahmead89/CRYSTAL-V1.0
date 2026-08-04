import {
  useAuthStore,
  useUIStore,
  useChatStore,
  useNetworkStore,
  useNotificationStore,
  useMediaStore,
} from '../index';

describe('useAuthStore', () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: null,
      session: null,
      isAuthenticated: false,
      isLoading: true,
    });
  });

  it('starts logged out', () => {
    const state = useAuthStore.getState();
    expect(state.user).toBeNull();
    expect(state.isAuthenticated).toBe(false);
    expect(state.isLoading).toBe(true);
  });

  it('setUser updates the user', () => {
    const user = { id: 'u1', fullName: 'John Doe', email: 'john@example.com' } as const;
    useAuthStore.getState().setUser(user as never);
    expect(useAuthStore.getState().user).toEqual(user);
  });

  it('setSession updates the session', () => {
    const session = { accessToken: 'abc', refreshToken: 'def' } as const;
    useAuthStore.getState().setSession(session as never);
    expect(useAuthStore.getState().session).toEqual(session);
  });

  it('setAuthenticated updates authentication state', () => {
    useAuthStore.getState().setAuthenticated(true);
    expect(useAuthStore.getState().isAuthenticated).toBe(true);
  });

  it('setLoading updates loading state', () => {
    useAuthStore.getState().setLoading(false);
    expect(useAuthStore.getState().isLoading).toBe(false);
  });

  it('logout clears user, session, and auth state', () => {
    useAuthStore.setState({
      user: { id: 'u1' } as never,
      session: { accessToken: 'abc' } as never,
      isAuthenticated: true,
    });
    useAuthStore.getState().logout();
    const state = useAuthStore.getState();
    expect(state.user).toBeNull();
    expect(state.session).toBeNull();
    expect(state.isAuthenticated).toBe(false);
  });
});

describe('useUIStore', () => {
  beforeEach(() => {
    useUIStore.setState({ theme: 'system', sidebarOpen: false });
  });

  it('defaults to system theme with closed sidebar', () => {
    const state = useUIStore.getState();
    expect(state.theme).toBe('system');
    expect(state.sidebarOpen).toBe(false);
  });

  it('setTheme updates the theme', () => {
    useUIStore.getState().setTheme('dark');
    expect(useUIStore.getState().theme).toBe('dark');
  });

  it('toggleSidebar flips the sidebar state', () => {
    useUIStore.getState().toggleSidebar();
    expect(useUIStore.getState().sidebarOpen).toBe(true);
    useUIStore.getState().toggleSidebar();
    expect(useUIStore.getState().sidebarOpen).toBe(false);
  });

  it('setSidebarOpen sets an explicit value', () => {
    useUIStore.getState().setSidebarOpen(true);
    expect(useUIStore.getState().sidebarOpen).toBe(true);
  });
});

describe('useChatStore', () => {
  beforeEach(() => {
    useChatStore.setState({ activeChatId: null, unreadCounts: {} });
  });

  it('starts with no active chat', () => {
    expect(useChatStore.getState().activeChatId).toBeNull();
  });

  it('setActiveChat updates the active chat', () => {
    useChatStore.getState().setActiveChat('chat-1');
    expect(useChatStore.getState().activeChatId).toBe('chat-1');
  });

  it('incrementUnread increments existing counts', () => {
    useChatStore.getState().setUnreadCount('chat-1', 2);
    useChatStore.getState().incrementUnread('chat-1');
    expect(useChatStore.getState().unreadCounts['chat-1']).toBe(3);
  });

  it('incrementUnread starts from zero for a new chat', () => {
    useChatStore.getState().incrementUnread('chat-2');
    expect(useChatStore.getState().unreadCounts['chat-2']).toBe(1);
  });

  it('clearUnread removes the chat key', () => {
    useChatStore.getState().setUnreadCount('chat-1', 5);
    useChatStore.getState().clearUnread('chat-1');
    expect(useChatStore.getState().unreadCounts['chat-1']).toBeUndefined();
  });

  it('setUnreadCount sets a specific count', () => {
    useChatStore.getState().setUnreadCount('chat-1', 9);
    expect(useChatStore.getState().unreadCounts['chat-1']).toBe(9);
  });
});

describe('useNetworkStore', () => {
  beforeEach(() => {
    useNetworkStore.setState({ isConnected: true, connectionType: 'unknown' });
  });

  it('starts connected', () => {
    expect(useNetworkStore.getState().isConnected).toBe(true);
  });

  it('setConnected updates connectivity', () => {
    useNetworkStore.getState().setConnected(false);
    expect(useNetworkStore.getState().isConnected).toBe(false);
  });

  it('setConnectionType updates the connection type', () => {
    useNetworkStore.getState().setConnectionType('cellular');
    expect(useNetworkStore.getState().connectionType).toBe('cellular');
  });
});

describe('useNotificationStore', () => {
  beforeEach(() => {
    useNotificationStore.setState({ pushToken: null, hasPermission: false });
  });

  it('starts with no token and no permission', () => {
    const state = useNotificationStore.getState();
    expect(state.pushToken).toBeNull();
    expect(state.hasPermission).toBe(false);
  });

  it('setPushToken updates the token', () => {
    useNotificationStore.getState().setPushToken('token-1');
    expect(useNotificationStore.getState().pushToken).toBe('token-1');
  });

  it('setPermission updates the permission', () => {
    useNotificationStore.getState().setPermission(true);
    expect(useNotificationStore.getState().hasPermission).toBe(true);
  });
});

describe('useMediaStore', () => {
  beforeEach(() => {
    useMediaStore.setState({ cache: new Map() });
  });

  it('returns undefined for a missing key', () => {
    expect(useMediaStore.getState().getFromCache('missing')).toBeUndefined();
  });

  it('addToCache then getFromCache round-trips', () => {
    useMediaStore.getState().addToCache('key', 'value');
    expect(useMediaStore.getState().getFromCache('key')).toBe('value');
  });

  it('clearCache empties the cache', () => {
    useMediaStore.getState().addToCache('key', 'value');
    useMediaStore.getState().clearCache();
    expect(useMediaStore.getState().getFromCache('key')).toBeUndefined();
  });
});
