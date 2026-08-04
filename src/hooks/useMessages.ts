import { useState, useEffect, useCallback, useRef } from 'react';
import { messageRepository, chatRepository } from '@/repositories';
import { useNetworkStore } from '@/stores';
import { offlineStorage } from '@/services/offline/offlineStorage';
import type { Message, Profile } from '@/types/database';
import { logger } from '@/utils/logger';

export type MessageWithSender = Message & {
  sender?: Profile;
  status?: 'pending' | 'sending' | 'sent' | 'failed';
};

export function useMessages(chatId: string | undefined, userId: string | undefined) {
  const [messages, setMessages] = useState<MessageWithSender[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isTyping, setIsTyping] = useState(false);
  const [otherParticipantTyping, setOtherParticipantTyping] = useState<Record<string, boolean>>({});
  const [otherParticipantPresence, setOtherParticipantPresence] = useState<Record<string, { isOnline: boolean; lastSeen?: string }>>({});

  const { isConnected } = useNetworkStore();
  const typingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const fetchMessages = useCallback(async () => {
    if (!chatId) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      let dbMessages: MessageWithSender[] = [];
      if (isConnected) {
        dbMessages = await messageRepository.getMessages(chatId);
      }

      const pendingQueue = await offlineStorage.getPendingMessages();
      const pendingForChat = pendingQueue
        .filter((m) => m.chatId === chatId)
        .map((m) => ({
          id: m.localId,
          chat_id: m.chatId,
          sender_id: userId || '',
          content: m.content,
          message_type: m.messageType as any,
          reply_to_id: m.replyToId,
          created_at: new Date(m.timestamp).toISOString(),
          updated_at: new Date(m.timestamp).toISOString(),
          is_edited: false,
          is_deleted: false,
          status: m.status,
        }));

      const combined = [...dbMessages, ...pendingForChat].sort(
        (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
      );

      setMessages(combined);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to fetch messages';
      setError(message);
    } finally {
      setLoading(false);
    }
  }, [chatId, userId, isConnected]);

  useEffect(() => {
    fetchMessages();
  }, [fetchMessages]);

  useEffect(() => {
    if (isConnected) {
      offlineStorage.sync().then(() => {
        void fetchMessages();
      }).catch((err) => {
        logger.error('Failed to sync offline storage on network recovery', {}, err);
      });
    }
  }, [isConnected, fetchMessages]);

  useEffect(() => {
    if (!chatId || !userId || !isConnected) return;

    const unsubscribeMessages = messageRepository.subscribeToMessages(
      chatId,
      (newMsg) => {
        setMessages((prev) => {
          if (prev.some((m) => m.id === newMsg.id)) {
            return prev;
          }
          return [...prev, newMsg];
        });
      },
      (updatedMsg) => {
        setMessages((prev) =>
          prev.map((m) => (m.id === updatedMsg.id ? { ...m, ...updatedMsg } : m))
        );
      }
    );

    const unsubscribeTyping = messageRepository.subscribeToTyping(chatId, (typingUserId, typingState) => {
      if (typingUserId !== userId) {
        setOtherParticipantTyping((prev) => ({
          ...prev,
          [typingUserId]: typingState,
        }));
      }
    });

    const unsubscribePresence = messageRepository.subscribeToPresence(chatId, userId, (presenceUserId, onlineState, presenceItem) => {
      if (presenceUserId !== userId) {
        setOtherParticipantPresence((prev) => ({
          ...prev,
          [presenceUserId]: {
            isOnline: onlineState,
            lastSeen: presenceItem.online_at,
          },
        }));
      }
    });

    return () => {
      unsubscribeMessages();
      unsubscribeTyping();
      unsubscribePresence();
    };
  }, [chatId, userId, isConnected]);

  const sendMessage = useCallback(
    async (content: string, messageType = 'text', replyToId?: string) => {
      if (!chatId || !userId || !content.trim()) return null;

      const trimmedContent = content.trim();

      if (!isConnected) {
        const localId = await offlineStorage.queueMessage({
          chatId,
          content: trimmedContent,
          messageType,
          replyToId,
        });

        const optimisticMessage: MessageWithSender = {
          id: localId,
          chat_id: chatId,
          sender_id: userId,
          content: trimmedContent,
          message_type: messageType as any,
          reply_to_id: replyToId,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          is_edited: false,
          is_deleted: false,
          status: 'pending',
        };

        setMessages((prev) => [...prev, optimisticMessage]);
        return localId;
      }

      try {
        const messageId = await messageRepository.sendMessage(chatId, trimmedContent, messageType, replyToId);
        return messageId;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to send message';
        setError(msg);
        return null;
      }
    },
    [chatId, userId, isConnected]
  );

  const sendTypingStatus = useCallback(
    async (isCurrentlyTyping: boolean) => {
      if (!chatId || !userId || !isConnected) return;

      try {
        await messageRepository.updateTypingStatus(chatId, userId, isCurrentlyTyping);
      } catch (err) {
        logger.error('Failed to broadcast typing status', { chatId, userId }, err as Error);
      }
    },
    [chatId, userId, isConnected]
  );

  const handleKeyPress = useCallback(() => {
    if (!isTyping) {
      setIsTyping(true);
      void sendTypingStatus(true);
    }

    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }

    typingTimeoutRef.current = setTimeout(() => {
      setIsTyping(false);
      void sendTypingStatus(false);
    }, 3000);
  }, [isTyping, sendTypingStatus]);

  const markAsRead = useCallback(
    async (messageIds: string[]) => {
      if (!chatId || !userId || !isConnected || messageIds.length === 0) return;

      try {
        await chatRepository.markAsRead(chatId, messageIds);
      } catch {
        // Silently fail for read receipts
      }
    },
    [chatId, userId, isConnected]
  );

  useEffect(() => {
    return () => {
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
    };
  }, []);

  return {
    messages,
    loading,
    error,
    sendMessage,
    markAsRead,
    handleKeyPress,
    otherParticipantTyping,
    otherParticipantPresence,
    refetch: fetchMessages,
  };
}
