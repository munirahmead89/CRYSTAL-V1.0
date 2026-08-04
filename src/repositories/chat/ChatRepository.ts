import { BaseRepository } from '../base/BaseRepository';
import { supabase } from '@/database/client';
import type { Chat, ChatWithLastMessage } from '@/types/database';

export class ChatRepository extends BaseRepository<Chat> {
  constructor() {
    super('chats');
  }

  async getChats(userId: string): Promise<ChatWithLastMessage[]> {
    try {
      // 1. Get chats where user is a participant
      const { data: participants, error: pError } = await supabase
        .from('chat_participants')
        .select('chat_id')
        .eq('user_id', userId);

      if (pError) this.handleError(pError);
      if (!participants || participants.length === 0) return [];

      const chatIds = participants.map((p) => p.chat_id);

      // 2. Query view or query chats table and manually join details to match production speed
      const { data, error } = await supabase
        .from('chat_with_last_message')
        .select('*')
        .in('id', chatIds)
        .order('updated_at', { ascending: false });

      if (error) {
        // Fallback: If view is not fully supported, fetch manually
        return this.fetchChatsFallback(userId, chatIds);
      }

      return (data || []) as ChatWithLastMessage[];
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }

  private async fetchChatsFallback(userId: string, chatIds: string[]): Promise<ChatWithLastMessage[]> {
    const { data: chatRows, error: chatError } = await supabase
      .from('chats')
      .select('*')
      .in('id', chatIds)
      .order('updated_at', { ascending: false });

    if (chatError) this.handleError(chatError);
    if (!chatRows) return [];

    const enriched: ChatWithLastMessage[] = await Promise.all(
      chatRows.map(async (chat) => {
        // Fetch other participant
        const { data: pData } = await supabase
          .from('chat_participants')
          .select('user_id')
          .eq('chat_id', chat.id)
          .neq('user_id', userId)
          .maybeSingle();

        let otherParticipant: any = undefined;
        if (pData) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', pData.user_id)
            .single();
          otherParticipant = profile;
        }

        // Fetch last message
        const { data: msg } = await supabase
          .from('messages')
          .select('*')
          .eq('chat_id', chat.id)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        // Get unread count
        const { count } = await supabase
          .from('messages')
          .select('*', { count: 'exact', head: true })
          .eq('chat_id', chat.id)
          .neq('sender_id', userId);

        return {
          ...chat,
          other_participant: otherParticipant || undefined,
          last_message: msg || undefined,
          unread_count: count || 0,
        } as ChatWithLastMessage;
      })
    );

    return enriched;
  }

  async createDirectChat(otherUserId: string): Promise<string> {
    try {
      const { data, error } = await supabase.rpc('create_direct_chat', {
        other_user_id: otherUserId,
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

  async markAsRead(chatId: string, messageIds: string[]): Promise<void> {
    try {
      const { error } = await supabase.rpc('mark_messages_read', {
        p_chat_id: chatId,
        p_message_ids: messageIds,
      });

      if (error) {
        this.handleError(error);
      }
    } catch (error) {
      if (error instanceof Error && 'code' in error && (error as any).code === 'POSTGREST_ERROR') {
        throw error;
      }
      throw error;
    }
  }
}

export const chatRepository = new ChatRepository();
