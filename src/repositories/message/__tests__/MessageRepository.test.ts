import { MessageRepository } from '../MessageRepository';

// Variables must be prefixed with `mock` to be accessible inside jest.mock factory
const mockFrom = jest.fn();
const mockRpc = jest.fn();
const mockChannel = jest.fn();
const mockRemoveChannel = jest.fn().mockResolvedValue(undefined);

jest.mock('@/database/client', () => ({
  supabase: {
    from: (...args: any[]) => mockFrom(...args),
    rpc: (...args: any[]) => mockRpc(...args),
    channel: (...args: any[]) => mockChannel(...args),
    removeChannel: (...args: any[]) => mockRemoveChannel(...args),
  },
}));

function createChain(result: { data: any; error: any }) {
  const chain: any = {};
  const identity = () => chain;
  chain.select = jest.fn(identity);
  chain.insert = jest.fn(identity);
  chain.upsert = jest.fn(identity);
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

function createRealtimeChannel() {
  const channel: any = {};
  channel.on = jest.fn(() => channel);
  channel.subscribe = jest.fn(() => channel);
  channel.track = jest.fn(() => Promise.resolve());
  channel.presenceState = jest.fn(() => ({}));
  return channel;
}

describe('MessageRepository', () => {
  let repo: MessageRepository;

  beforeEach(() => {
    jest.clearAllMocks();
    repo = new MessageRepository();
  });

  describe('getMessages', () => {
    it('returns empty array when no messages found', async () => {
      mockFrom.mockImplementation(() => createChain({ data: [], error: null }));

      const result = await repo.getMessages('chat-1');
      expect(result).toEqual([]);
    });

    it('fetches messages and enriches with sender profiles', async () => {
      const messages = [
        {
          id: 'msg-1',
          chat_id: 'chat-1',
          sender_id: 'user-1',
          content: 'Hello',
          message_type: 'text',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
          is_edited: false,
          is_deleted: false,
          reply_to_id: null,
        },
      ];
      const profiles = [
        { id: 'user-1', full_name: 'Alice', avatar_url: null, phone_number: '+1234567890', is_online: true },
      ];

      mockFrom.mockImplementation((table: string) => {
        if (table === 'messages') return createChain({ data: messages, error: null });
        if (table === 'profiles') return createChain({ data: profiles, error: null });
        return createChain({ data: null, error: null });
      });

      const result = await repo.getMessages('chat-1');
      expect(result).toHaveLength(1);
      const [message] = result;
      expect(message?.content).toBe('Hello');
      expect(message?.sender?.id).toBe('user-1');
    });

    it('throws when query fails', async () => {
      mockFrom.mockImplementation(() =>
        createChain({ data: null, error: { message: 'DB error', code: 'POSTGREST_ERROR' } })
      );

      await expect(repo.getMessages('chat-1')).rejects.toThrow();
    });
  });

  describe('sendMessage', () => {
    it('calls rpc send_message and returns message id', async () => {
      mockRpc.mockResolvedValue({ data: 'new-msg-id', error: null });

      const result = await repo.sendMessage('chat-1', 'Hello world');
      expect(result).toBe('new-msg-id');
      expect(mockRpc).toHaveBeenCalledWith('send_message', {
        p_chat_id: 'chat-1',
        p_content: 'Hello world',
        p_message_type: 'text',
        p_reply_to_id: undefined,
      });
    });

    it('throws when rpc returns an error', async () => {
      mockRpc.mockResolvedValue({ data: null, error: { message: 'RPC error', code: 'POSTGREST_ERROR' } });

      await expect(repo.sendMessage('chat-1', 'test')).rejects.toThrow();
    });

    it('passes reply_to_id to the rpc call', async () => {
      mockRpc.mockResolvedValue({ data: 'reply-msg-id', error: null });

      const result = await repo.sendMessage('chat-1', 'Reply msg', 'text', 'original-msg-id');
      expect(result).toBe('reply-msg-id');
      expect(mockRpc).toHaveBeenCalledWith(
        'send_message',
        expect.objectContaining({ p_reply_to_id: 'original-msg-id' })
      );
    });
  });

  describe('subscribeToMessages', () => {
    it('creates a channel and returns an unsubscribe function', () => {
      const fakeChannel = createRealtimeChannel();
      mockChannel.mockReturnValue(fakeChannel);

      const unsubscribe = repo.subscribeToMessages('chat-1', jest.fn(), jest.fn());

      expect(mockChannel).toHaveBeenCalledWith('messages-chat-1');
      expect(typeof unsubscribe).toBe('function');
    });
  });

  describe('subscribeToPresence', () => {
    it('creates a presence channel and returns an unsubscribe function', () => {
      const fakeChannel = createRealtimeChannel();
      mockChannel.mockReturnValue(fakeChannel);

      const unsubscribe = repo.subscribeToPresence('chat-1', 'user-1', jest.fn());

      expect(mockChannel).toHaveBeenCalledWith('presence-chat-1');
      expect(typeof unsubscribe).toBe('function');
    });
  });

  describe('updateTypingStatus', () => {
    it('upserts typing status without throwing', async () => {
      mockFrom.mockImplementation(() => createChain({ data: null, error: null }));

      await expect(repo.updateTypingStatus('chat-1', 'user-1', true)).resolves.not.toThrow();
    });
  });
});
