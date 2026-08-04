import { supabase } from '@/database/client';
import { AuthRepository } from '../AuthRepository';

const fromMock = supabase.from as jest.Mock;

type ProfileFixture = {
  id: string;
  phone: string;
  full_name: string;
  is_online: boolean;
  last_seen: string;
  created_at: string;
  updated_at: string;
};

const profile: ProfileFixture = {
  id: 'user-1',
  phone: '+14155552671',
  full_name: 'John Doe',
  is_online: false,
  last_seen: '2024-01-01T00:00:00.000Z',
  created_at: '2024-01-01T00:00:00.000Z',
  updated_at: '2024-01-01T00:00:00.000Z',
};

interface QueryChain {
  select: jest.Mock;
  insert: jest.Mock;
  update: jest.Mock;
  delete: jest.Mock;
  eq: jest.Mock;
  neq: jest.Mock;
  or: jest.Mock;
  in: jest.Mock;
  ilike: jest.Mock;
  limit: jest.Mock;
  range: jest.Mock;
  order: jest.Mock;
  single: jest.Mock;
  maybeSingle: jest.Mock;
  then: (onfulfilled?: ((value: unknown) => unknown) | null, onrejected?: ((reason: unknown) => unknown) | null) => Promise<unknown>;
}

function createChain(result: unknown): QueryChain {
  const chain = {} as QueryChain;
  const terminal = jest.fn().mockResolvedValue(result);
  (['select', 'insert', 'update', 'delete', 'eq', 'neq', 'or', 'in', 'ilike', 'limit', 'range', 'order'] as const).forEach(
    (method) => {
      chain[method] = jest.fn(() => chain);
    }
  );
  chain.single = jest.fn(() => terminal());
  chain.maybeSingle = jest.fn(() => terminal());
  chain.then = (onfulfilled, onrejected) => terminal().then(onfulfilled, onrejected);
  return chain;
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('AuthRepository', () => {
  it('creates a profile with generated timestamps', async () => {
    const chain = createChain({ data: profile, error: null });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    const result = await repo.createProfile('user-1', {
      phone: '+14155552671',
      full_name: 'John Doe',
      is_online: false,
      last_seen: '2024-01-01T00:00:00.000Z',
    });

    expect(result).toEqual(profile);
    expect(fromMock).toHaveBeenCalledWith('profiles');
    const insertData = chain.insert.mock.calls[0][0];
    expect(insertData.id).toBe('user-1');
    expect(insertData.full_name).toBe('John Doe');
    expect(insertData.created_at).toBeDefined();
    expect(insertData.updated_at).toBeDefined();
  });

  it('returns null when a profile is not found', async () => {
    const chain = createChain({ data: null, error: { code: 'PGRST116', message: 'not found' } });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    await expect(repo.getProfile('missing')).resolves.toBeNull();
  });

  it('updates a profile and refreshes updated_at', async () => {
    const updated = { ...profile, full_name: 'Jane Doe' };
    const chain = createChain({ data: updated, error: null });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    const result = await repo.updateProfile('user-1', { full_name: 'Jane Doe' });

    expect(result.full_name).toBe('Jane Doe');
    expect(chain.update.mock.calls[0][0]).toMatchObject({ full_name: 'Jane Doe' });
    expect(chain.update.mock.calls[0][0].updated_at).toBeDefined();
    expect(chain.eq).toHaveBeenCalledWith('id', 'user-1');
  });

  it('looks up a profile by phone', async () => {
    const chain = createChain({ data: profile, error: null });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    const result = await repo.getProfileByPhone('+14155552671');

    expect(result).toEqual(profile);
    expect(chain.eq).toHaveBeenCalledWith('phone', '+14155552671');
  });

  it('returns null from getProfileByPhone when the phone does not exist', async () => {
    const chain = createChain({ data: null, error: { code: 'PGRST116', message: 'not found' } });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    await expect(repo.getProfileByPhone('+19999999999')).resolves.toBeNull();
  });

  it('searches profiles by name or phone', async () => {
    const chain = createChain({ data: [profile], error: null });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    const result = await repo.searchProfiles('john');

    expect(result).toEqual([profile]);
    expect(chain.or).toHaveBeenCalledWith('full_name.ilike.%john%,phone.ilike.%john%');
    expect(chain.limit).toHaveBeenCalledWith(20);
  });

  it('updates the online status and last seen timestamp', async () => {
    const chain = createChain({ data: profile, error: null });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    await repo.updateOnlineStatus('user-1', true);

    const updateData = chain.update.mock.calls[0][0];
    expect(updateData.is_online).toBe(true);
    expect(updateData.last_seen).toBeDefined();
    expect(chain.eq).toHaveBeenCalledWith('id', 'user-1');
  });

  it('returns an empty array for getOnlineUsers with no ids', async () => {
    const repo = new AuthRepository();
    await expect(repo.getOnlineUsers([])).resolves.toEqual([]);
    expect(fromMock).not.toHaveBeenCalled();
  });

  it('fetches online users by ids', async () => {
    const chain = createChain({ data: [profile], error: null });
    fromMock.mockReturnValue(chain);
    const repo = new AuthRepository();

    const result = await repo.getOnlineUsers(['user-1']);

    expect(result).toEqual([profile]);
    expect(chain.in).toHaveBeenCalledWith('id', ['user-1']);
    expect(chain.eq).toHaveBeenCalledWith('is_online', true);
  });
});
