import type { Message } from './message';
import type { UserProfile } from './user';

export interface Chat {
  id: string;
  type: 'direct' | 'group' | 'channel';
  name?: string;
  avatarUrl?: string;
  description?: string;
  createdBy: string;
  isEncrypted: boolean;
  disappearingTimer?: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface ChatParticipant {
  id: string;
  chatId: string;
  userId: string;
  role: 'member' | 'admin' | 'owner';
  joinedAt: Date;
  leftAt?: Date;
  isMuted: boolean;
  muteUntil?: Date;
  lastReadMessageId?: string;
}

export interface ChatWithLastMessage extends Chat {
  lastMessage?: Message;
  unreadCount: number;
  otherParticipant?: UserProfile;
}

export interface CreateChatData {
  participantIds: string[];
  isGroup: boolean;
  name?: string;
  avatarUrl?: string;
}