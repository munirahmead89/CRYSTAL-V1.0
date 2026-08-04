import { supabase } from '@/database/client';
import { ContactRepository } from '../ContactRepository';

const fromMock = supabase.from as jest.Mock;

type ContactFixture = {
  id: string;
  user_id: string;
  contact_id: string;
  display_name: string;
  is_favorite: boolean;
  is_blocked: boolean;
  created_at: string;
  updated_at: string;
};

type ProfileFixture = {
  id: string;
  phone: string;
  full_name: string;
  is_online: boolean;
  last_seen: string;
};

const contact: ContactFixture = {
  id: 'c-1',
  user_id: 'user-1',
  contact_id: 'user-2',
  display_name: 'Alice',
  is_favorite: false,
  is_blocked: false,
  created_at: '2024-01-01T00:00:00.000Z',
  updated_at: '2024-01-01T00:00:00.000Z',
};

const profile: ProfileFixture = {
  id: 'user-2',
  phone: '+14155552672',
  full_name: 'Alice Johnson',
  is_online: true,
  last_seen: '2024-01-01T00:00:00.000Z',
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

describe('ContactRepository', () => {
  it('gets contacts and maps profiles', async () => {
    const enrichedContact = { ...contact, profile };
    const chain = createChain({ data: [enrichedContact], error: null });
    fromMock.mockReturnValue(chain);

    const repo = new ContactRepository();
    const result = await repo.getContacts('user-1');

    expect(result).toEqual([enrichedContact]);
    expect(fromMock).toHaveBeenCalledWith('contacts');
    expect(chain.select).toHaveBeenCalledWith(`
          *,
          profile:profiles!contacts_contact_id_fkey(*)
        `);
    expect(chain.eq).toHaveBeenCalledWith('user_id', 'user-1');
  });

  it('adds contact successfully', async () => {
    const chainProfile = createChain({ data: profile, error: null });
    const chainExist = createChain({ data: null, error: null });
    const chainInsert = createChain({ data: contact, error: null });

    // Mock sequence of from() queries
    let contactsCallCount = 0;
    fromMock.mockImplementation((table: string) => {
      if (table === 'profiles') return chainProfile;
      if (table === 'contacts') {
        contactsCallCount++;
        if (contactsCallCount === 1) {
          return chainExist;
        }
        return chainInsert;
      }
      return createChain({ data: null, error: null });
    });

    const repo = new ContactRepository();
    const result = await repo.addContact('user-1', '+14155552672', 'Alice');

    expect(result).toEqual(contact);
    expect(fromMock).toHaveBeenCalledWith('profiles');
    expect(chainProfile.eq).toHaveBeenCalledWith('phone', '+14155552672');
  });

  it('fails to add contact when phone does not exist', async () => {
    const chainProfile = createChain({ data: null, error: { code: 'PGRST116', message: 'not found' } });
    fromMock.mockReturnValue(chainProfile);

    const repo = new ContactRepository();
    await expect(repo.addContact('user-1', '+19999999999', 'Bob')).rejects.toThrow(
      'No Crystal user found with this phone number'
    );
  });

  it('fails to add self as contact', async () => {
    const selfProfile = { ...profile, id: 'user-1' };
    const chainProfile = createChain({ data: selfProfile, error: null });
    fromMock.mockReturnValue(chainProfile);

    const repo = new ContactRepository();
    await expect(repo.addContact('user-1', '+14155552672', 'Self')).rejects.toThrow(
      'You cannot add yourself as a contact'
    );
  });

  it('removes contact successfully', async () => {
    const chain = createChain({ data: null, error: null });
    fromMock.mockReturnValue(chain);

    const repo = new ContactRepository();
    await repo.removeContact('user-1', 'user-2');

    expect(fromMock).toHaveBeenCalledWith('contacts');
    expect(chain.delete).toHaveBeenCalled();
    expect(chain.eq).toHaveBeenCalledWith('user_id', 'user-1');
  });

  it('blocks contact successfully', async () => {
    const chain = createChain({ data: null, error: null });
    fromMock.mockReturnValue(chain);

    const repo = new ContactRepository();
    await repo.blockContact('user-1', 'user-2');

    expect(fromMock).toHaveBeenCalledWith('contacts');
    expect(chain.update).toHaveBeenCalledWith(expect.objectContaining({ is_blocked: true }));
  });
});
