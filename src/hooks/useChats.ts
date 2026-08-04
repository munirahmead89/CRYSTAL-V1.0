import { useQuery, useQueryClient } from '@tanstack/react-query';
import { chatRepository } from '@/repositories';
import { supabase } from '@/database/client';
import { useEffect } from 'react';
import type { Database } from '@/types/database';

type ChatRow = Database['public']['Tables']['chats']['Row'];
type ProfileRow = Database['public']['Tables']['profiles']['Row'];
type MessageRow = Database['public']['Tables']['messages']['Row'];

export type ChatWithDetails = ChatRow & {
  otherParticipant?: ProfileRow;
  lastMessage?: MessageRow;
  unreadCount: number;
};

export function useChats(userId: string | undefined) {
  const queryClient = useQueryClient();

  const {
    data: chats = [],
    isLoading,
    error,
    refetch,
  } = useQuery<ChatWithDetails[]>({
    queryKey: ['chats', userId],
    queryFn: async () => {
      if (!userId) return [];
      const data = await chatRepository.getChats(userId);
      return data.map((chat) => ({
        ...chat,
        otherParticipant: chat.other_participant,
        lastMessage: chat.last_message,
        unreadCount: chat.unread_count || 0,
      }));
    },
    enabled: !!userId,
  });

  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel('global-chats-list-sync')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'messages' },
        () => {
          void queryClient.invalidateQueries({ queryKey: ['chats', userId] });
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'chat_participants', filter: `user_id=eq.${userId}` },
        () => {
          void queryClient.invalidateQueries({ queryKey: ['chats', userId] });
        }
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [userId, queryClient]);

  return {
    chats,
    loading: isLoading,
    error: error instanceof Error ? error.message : null,
    refetch,
  };
}
