import { ChatRepository } from '../ChatRepository';

const mockFrom = jest.fn();
const mockRpc = jest.fn();

jest.mock('@/database/client', () => ({
  supabase: {
    from: (...args: any[]) => mockFrom(...args),
    rpc: (...args: any[]) => mockRpc(...args),
  },
}));

function createChain(result: { data: any; error: any; count?: number }) {
  const chain: any = {};
  const identity = () => chain;
  chain.select = jest.fn(identity);
  chain.insert = jest.fn(identity);
  chain.update = jest.fn(identity);
  chain.delete = jest.fn(identity);
  chain.eq = jest.fn(identity);
  chain.neq = jest.fn(identity);
  chain.in = jest.fn(identity);
  chain.order = jest.fn(identity);
  chain.limit = jest.fn(identity);
  chain.single = jest.fn(() => Promise.resolve(result));
  chain.maybeSingle = jest.fn(() => Promise.resolve(result));
  chain.then = (resolve: any, reject: any) => Promise.resolve(result).then(resolve, reject);
  return chain;
}

describe('ChatRepository', () => {
  let repo: ChatRepository;

  beforeEach(() => {
    jest.clearAllMocks();
    repo = new ChatRepository();
  });

  describe('getChats', () => {
    it('returns empty array when user has no chat participants', async () => {
      mockFrom.mockImplementation((table: string) => {
        if (table === 'chat_participants') return createChain({ data: [], error: null });
        return createChain({ data: null, error: null });
      });

      const result = await repo.getChats('user-1');
      expect(result).toEqual([]);
    });

    it('fetches chats from view when available', async () => {
      const chatRow = { id: 'chat-1', name: null, chat_type: 'direct', created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-02T00:00:00Z' };
      let callCount = 0;

      mockFrom.mockImplementation((table: string) => {
        if (table === 'chat_participants') {
          callCount++;
          if (callCount === 1) {
            return createChain({ data: [{ chat_id: 'chat-1' }], error: null });
          }
        }
        if (table === 'chat_with_last_message') {
          return createChain({ data: [chatRow], error: null });
        }
        return createChain({ data: null, error: null });
      });

      const result = await repo.getChats('user-1');
      expect(result).toHaveLength(1);
      const [chat] = result;
      expect(chat?.id).toBe('chat-1');
    });

    it('falls back to manual join when view query fails', async () => {
      const chatRow = { id: 'chat-2', name: 'Group', chat_type: 'group', created_at: '2024-01-01T00:00:00Z', updated_at: '2024-01-02T00:00:00Z' };
      let participantCallCount = 0;

      mockFrom.mockImplementation((table: string) => {
        if (table === 'chat_participants') {
          participantCallCount++;
          if (participantCallCount === 1) {
            return createChain({ data: [{ chat_id: 'chat-2' }], error: null });
          }
          return createChain({ data: [], error: null });
        }
        if (table === 'chat_with_last_message') {
          return createChain({ data: null, error: { message: 'view not found' } });
        }
        if (table === 'chats') {
          return createChain({ data: [chatRow], error: null });
        }
        if (table === 'profiles') {
          return createChain({ data: null, error: null });
        }
        if (table === 'messages') {
          return createChain({ data: null, error: null, count: 0 });
        }
        return createChain({ data: null, error: null });
      });

      const result = await repo.getChats('user-1');
      expect(result).toHaveLength(1);
      const [chat] = result;
      expect(chat?.id).toBe('chat-2');
    });
  });

  describe('createDirectChat', () => {
    it('calls the create_direct_chat rpc and returns the chat id', async () => {
      mockRpc.mockResolvedValue({ data: 'new-chat-id', error: null });

      const result = await repo.createDirectChat('other-user-id');
      expect(result).toBe('new-chat-id');
      expect(mockRpc).toHaveBeenCalledWith('create_direct_chat', { other_user_id: 'other-user-id' });
    });

    it('throws when rpc returns an error', async () => {
      mockRpc.mockResolvedValue({ data: null, error: { message: 'RPC failed', code: 'POSTGREST_ERROR' } });

      await expect(repo.createDirectChat('other-user-id')).rejects.toThrow();
    });
  });

  describe('markAsRead', () => {
    it('calls the mark_messages_read rpc', async () => {
      mockRpc.mockResolvedValue({ data: null, error: null });

      await expect(repo.markAsRead('chat-1', ['msg-1', 'msg-2'])).resolves.not.toThrow();
      expect(mockRpc).toHaveBeenCalledWith('mark_messages_read', {
        p_chat_id: 'chat-1',
        p_message_ids: ['msg-1', 'msg-2'],
      });
    });

    it('throws when rpc returns an error', async () => {
      mockRpc.mockResolvedValue({ data: null, error: { message: 'RPC failed', code: 'POSTGREST_ERROR' } });

      await expect(repo.markAsRead('chat-1', ['msg-1'])).rejects.toThrow();
    });
  });
});
