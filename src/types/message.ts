import type { UserProfile } from './user';

export interface Message {
  id: string;
  chatId: string;
  senderId: string;
  content: string;
  messageType: 'text' | 'image' | 'video' | 'audio' | 'file' | 'location' | 'contact' | 'sticker' | 'system';
  replyToId?: string;
  forwardedFromId?: string;
  metadata?: Record<string, any>;
  isEdited: boolean;
  isDeleted: boolean;
  deletedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface MessageWithSender extends Message {
  sender: UserProfile;
  replyTo?: Message;
  attachments: Attachment[];
  reactions: MessageReaction[];
  readBy: MessageRead[];
}

export interface Attachment {
  id: string;
  messageId: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  url: string;
  thumbnailUrl?: string;
  duration?: number;
  width?: number;
  height?: number;
  createdAt: Date;
}

export interface MessageRead {
  id: string;
  messageId: string;
  userId: string;
  readAt: Date;
}

export interface MessageReaction {
  id: string;
  messageId: string;
  userId: string;
  emoji: string;
  createdAt: Date;
}

export interface SendMessageData {
  chatId: string;
  content: string;
  messageType: Message['messageType'];
  replyToId?: string;
  attachments?: AttachmentInput[];
}

export interface AttachmentInput {
  fileName: string;
  fileSize: number;
  mimeType: string;
  url: string;
  thumbnailUrl?: string;
  duration?: number;
  width?: number;
  height?: number;
}

export interface TypingIndicator {
  chatId: string;
  userId: string;
  isTyping: boolean;
}