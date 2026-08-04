import {
  supabase,
  signInAnonymously,
  signOut,
  getCurrentUser,
  getCurrentSession,
  subscribeToAuthChanges,
  initializeAuthListener,
} from '../client';

const auth = supabase.auth as unknown as {
  getUser: jest.Mock;
  getSession: jest.Mock;
  signInAnonymously: jest.Mock;
  signOut: jest.Mock;
  onAuthStateChange: jest.Mock;
  startAutoRefresh: jest.Mock;
  stopAutoRefresh: jest.Mock;
};

const user = { id: 'user-1', phone: '+14155552671' };
const session = {
  access_token: 'access-token',
  refresh_token: 'refresh-token',
  expires_at: 1700000000,
  user,
};

beforeEach(() => {
  jest.clearAllMocks();
  auth.getUser.mockResolvedValue({ data: { user }, error: null });
  auth.getSession.mockResolvedValue({ data: { session }, error: null });
  auth.signInAnonymously.mockResolvedValue({ data: { user, session }, error: null });
  auth.signOut.mockResolvedValue({ error: null });
});

describe('auth client functions', () => {
  it('signs in anonymously', async () => {
    const result = await signInAnonymously();
    expect(auth.signInAnonymously).toHaveBeenCalledTimes(1);
    expect(result.data?.user?.id).toBe('user-1');
  });

  it('signs out', async () => {
    const result = await signOut();
    expect(auth.signOut).toHaveBeenCalledTimes(1);
    expect(result.error).toBeNull();
  });

  it('returns the current user', async () => {
    await expect(getCurrentUser()).resolves.toEqual(user);
  });

  it('returns the current session', async () => {
    await expect(getCurrentSession()).resolves.toEqual(session);
  });

  it('subscribes to auth changes and returns an unsubscribe function', () => {
    const callback = jest.fn();
    const unsubscribe = subscribeToAuthChanges(callback);

    expect(auth.onAuthStateChange).toHaveBeenCalledTimes(1);
    const handler = auth.onAuthStateChange.mock.calls[0][0] as (event: string, session: unknown) => void;
    handler('SIGNED_IN', session);
    expect(callback).toHaveBeenCalledWith('SIGNED_IN', session);

    unsubscribe();
    const result = auth.onAuthStateChange.mock.results[0];
    const subscription = (result as { value: { data: { subscription: { unsubscribe: jest.Mock } } } }).value.data.subscription;
    expect(subscription.unsubscribe).toHaveBeenCalledTimes(1);
  });

  it('registers the AppState listener exactly once', () => {
    const RN = require('react-native') as { AppState: { addEventListener: jest.Mock } };
    const spy = jest.spyOn(RN.AppState, 'addEventListener');
    const unsubscribe = initializeAuthListener();
    initializeAuthListener();
    expect(spy).toHaveBeenCalledTimes(1);
    unsubscribe();
    spy.mockRestore();
  });
});
