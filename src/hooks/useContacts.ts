import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { contactRepository, chatRepository } from '@/repositories';
import { useCallback } from 'react';
import type { UserContact } from '@/types/database';

export function useContacts(userId: string | undefined) {
  const queryClient = useQueryClient();

  const {
    data: contacts = [],
    isLoading,
    error,
    refetch,
  } = useQuery<UserContact[]>({
    queryKey: ['contacts', userId],
    queryFn: async () => {
      if (!userId) return [];
      return contactRepository.getContacts(userId);
    },
    enabled: !!userId,
  });

  const addContactMutation = useMutation({
    mutationFn: async (data: { phone: string; displayName: string }) => {
      if (!userId) throw new Error('Not authenticated');
      return contactRepository.addContact(userId, data.phone, data.displayName);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contacts', userId] });
    },
  });

  const removeContactMutation = useMutation({
    mutationFn: async (contactId: string) => {
      if (!userId) throw new Error('Not authenticated');
      await contactRepository.removeContact(userId, contactId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contacts', userId] });
    },
  });

  const blockContactMutation = useMutation({
    mutationFn: async (contactId: string) => {
      if (!userId) throw new Error('Not authenticated');
      await contactRepository.blockContact(userId, contactId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contacts', userId] });
    },
  });

  const startChat = useCallback(
    async (otherUserId: string): Promise<string | null> => {
      try {
        return await chatRepository.createDirectChat(otherUserId);
      } catch {
        return null;
      }
    },
    []
  );

  return {
    contacts,
    loading: isLoading,
    error: error instanceof Error ? error.message : null,
    refetch,
    startChat,
    addContact: addContactMutation.mutateAsync,
    addContactState: addContactMutation,
    removeContact: removeContactMutation.mutateAsync,
    removeContactState: removeContactMutation,
    blockContact: blockContactMutation.mutateAsync,
    blockContactState: blockContactMutation,
  };
}
