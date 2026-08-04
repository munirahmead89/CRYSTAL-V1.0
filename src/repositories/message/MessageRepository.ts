import { BaseRepository } from '../base/BaseRepository';
import { supabase } from '@/database/client';
import type { Message, Profile } from '@/types/database';
import { logger } from '@/utils/logger';

export type MessageWithSender = Message & {
  sender?: Profile;
};

export class MessageRepository extends BaseRepository<Message> {
  constructor() {
    super('messages');
  }

  async getMessages(chatId: string, limit = 50): Promise<MessageWithSender[]> {
    try {
      const { data: messages, error } = await supabase
        .from('messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', { ascending: true })
        .limit(limit);

      if (error) {
        this.handleError(error);
      }

      if (!messages || messages.length === 0) return [];

      const senderIds = [...new Set(messages.map((m) => m.sender_id))];
      const { data: profiles, error: pError } = await supabase
        .from('profiles')
        .select('*')
        .in('id', senderIds);

      const profileMap: Record<string, Profile> = {};
      if (profiles && !pError) {
        profiles.forEach((p) => {
          profileMap[p.id] = p;
        });
      }

      return messages.map((msg) => ({
        ...msg,
        sender: profileMap[msg.sender_id],
      })) as MessageWithSender[];
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  async sendMessage(chatId: string, content: string, messageType = 'text', replyToId?: string): Promise<string> {
    try {
      const { data, error } = await supabase.rpc('send_message', {
        p_chat_id: chatId,
        p_content: content,
        p_message_type: messageType,
        p_reply_to_id: replyToId,
      });

      if (error) {
        this.handleError(error);
      }

      return data as string;
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  subscribeToMessages(
    chatId: string,
    onInsert: (message: MessageWithSender) => void,
    onUpdate: (message: Message) => void
  ): () => void {
    const channel = supabase
      .channel(`messages-${chatId}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'messages', filter: `chat_id=eq.${chatId}` },
        async (payload) => {
          const newMsg = payload.new as Message;
          const { data: profile } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', newMsg.sender_id)
            .single();

          onInsert({
            ...newMsg,
            sender: profile || undefined,
          });
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'messages', filter: `chat_id=eq.${chatId}` },
        (payload) => {
          onUpdate(payload.new as Message);
        }
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }

  subscribeToPresence(
    chatId: string,
    userId: string,
    onPresenceChange: (userId: string, isOnline: boolean, status: any) => void
  ): () => void {
    const presenceChannel = supabase.channel(`presence-${chatId}`);

    presenceChannel
      .on('presence', { event: 'sync' }, () => {
        const state = presenceChannel.presenceState();
        Object.values(state).forEach((presenceItems: any[]) => {
          presenceItems.forEach((item) => {
            if (item.user_id) {
              onPresenceChange(item.user_id, item.is_online ?? true, item);
            }
          });
        });
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await presenceChannel.track({
            user_id: userId,
            is_online: true,
            online_at: new Date().toISOString(),
          });
        }
      });

    return () => {
      void supabase.removeChannel(presenceChannel);
    };
  }

  subscribeToTyping(chatId: string, onTypingChange: (userId: string, isTyping: boolean) => void): () => void {
    const channel = supabase
      .channel(`typing-${chatId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'typing_indicators', filter: `chat_id=eq.${chatId}` },
        (payload) => {
          if (payload.eventType === 'DELETE') {
            const oldRow = payload.old as any;
            if (oldRow && oldRow.user_id) {
              onTypingChange(oldRow.user_id, false);
            }
          } else {
            const row = payload.new as any;
            if (row && row.user_id) {
              onTypingChange(row.user_id, row.is_typing);
            }
          }
        }
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }

  async updateTypingStatus(chatId: string, userId: string, isTyping: boolean): Promise<void> {
    try {
      const { error } = await supabase
        .from('typing_indicators')
        .upsert({
          chat_id: chatId,
          user_id: userId,
          is_typing: isTyping,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'chat_id,user_id',
        });

      if (error) {
        this.handleError(error);
      }
    } catch (error) {
      logger.error('Failed to update typing status', { chatId, userId, isTyping }, error as Error);
    }
  }
}

export const messageRepository = new MessageRepository();
