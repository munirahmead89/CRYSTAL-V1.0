export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: Profile;
        Insert: ProfileInsert;
        Update: ProfileUpdate;
      };
      contacts: {
        Row: Contact;
        Insert: ContactInsert;
        Update: ContactUpdate;
      };
      chats: {
        Row: Chat;
        Insert: ChatInsert;
        Update: ChatUpdate;
      };
      chat_participants: {
        Row: ChatParticipant;
        Insert: ChatParticipantInsert;
        Update: ChatParticipantUpdate;
      };
      messages: {
        Row: Message;
        Insert: MessageInsert;
        Update: MessageUpdate;
      };
      message_reads: {
        Row: MessageRead;
        Insert: MessageReadInsert;
        Update: MessageReadUpdate;
      };
      message_reactions: {
        Row: MessageReaction;
        Insert: MessageReactionInsert;
        Update: MessageReactionUpdate;
      };
      attachments: {
        Row: Attachment;
        Insert: AttachmentInsert;
        Update: AttachmentUpdate;
      };
      groups: {
        Row: Group;
        Insert: GroupInsert;
        Update: GroupUpdate;
      };
      group_members: {
        Row: GroupMember;
        Insert: GroupMemberInsert;
        Update: GroupMemberUpdate;
      };
      calls: {
        Row: Call;
        Insert: CallInsert;
        Update: CallUpdate;
      };
      call_participants: {
        Row: CallParticipant;
        Insert: CallParticipantInsert;
        Update: CallParticipantUpdate;
      };
      notifications: {
        Row: Notification;
        Insert: NotificationInsert;
        Update: NotificationUpdate;
      };
      push_tokens: {
        Row: PushToken;
        Insert: PushTokenInsert;
        Update: PushTokenUpdate;
      };
      blocked_users: {
        Row: BlockedUser;
        Insert: BlockedUserInsert;
        Update: BlockedUserUpdate;
      };
      user_presence: {
        Row: UserPresence;
        Insert: UserPresenceInsert;
        Update: UserPresenceUpdate;
      };
      typing_indicators: {
        Row: TypingIndicator;
        Insert: TypingIndicatorInsert;
        Update: TypingIndicatorUpdate;
      };
    };
    Views: {
      chat_with_last_message: {
        Row: ChatWithLastMessage;
      };
      user_contacts: {
        Row: UserContact;
      };
    };
    Functions: {
      create_chat: {
        Args: { participant_ids: string[]; is_group: boolean; name?: string; avatar_url?: string };
        Returns: string;
      };
      send_message: {
        Args: { chat_id: string; content: string; message_type: string; reply_to_id?: string; metadata?: Record<string, any> };
        Returns: string;
      };
      mark_messages_read: {
        Args: { chat_id: string; user_id: string; message_ids: string[] };
        Returns: void;
      };
      get_unread_count: {
        Args: { user_id: string };
        Returns: number;
      };
      search_messages: {
        Args: { user_id: string; query: string; limit?: number; offset?: number };
        Returns: Message[];
      };
    };
    Enums: {
      message_type: 'text' | 'image' | 'video' | 'audio' | 'file' | 'location' | 'contact' | 'sticker' | 'system';
      chat_type: 'direct' | 'group' | 'channel';
      call_type: 'audio' | 'video';
      call_status: 'initiated' | 'ringing' | 'answered' | 'ended' | 'missed' | 'declined' | 'busy';
      participant_role: 'member' | 'admin' | 'owner';
      notification_type: 'message' | 'call' | 'group_invite' | 'mention' | 'reaction' | 'system';
      presence_status: 'online' | 'offline' | 'away' | 'busy';
    };
  };
}

export type Profile = {
  id: string;
  phone: string;
  email?: string;
  full_name: string;
  avatar_url?: string;
  bio?: string;
  is_online: boolean;
  last_seen: string;
  created_at: string;
  updated_at: string;
};

export type ProfileInsert = Omit<Profile, 'id' | 'created_at' | 'updated_at'> & { id: string };
export type ProfileUpdate = Partial<Omit<Profile, 'id' | 'created_at'>>;

export type Contact = {
  id: string;
  user_id: string;
  contact_id: string;
  display_name?: string;
  is_favorite: boolean;
  is_blocked: boolean;
  created_at: string;
  updated_at: string;
};

export type ContactInsert = Omit<Contact, 'id' | 'created_at' | 'updated_at'>;
export type ContactUpdate = Partial<Omit<Contact, 'id' | 'user_id' | 'contact_id' | 'created_at'>>;

export type Chat = {
  id: string;
  type: 'direct' | 'group' | 'channel';
  name?: string;
  avatar_url?: string;
  description?: string;
  created_by: string;
  is_encrypted: boolean;
  disappearing_timer?: number;
  created_at: string;
  updated_at: string;
};

export type ChatInsert = Omit<Chat, 'id' | 'created_at' | 'updated_at'>;
export type ChatUpdate = Partial<Omit<Chat, 'id' | 'created_at'>>;

export type ChatParticipant = {
  id: string;
  chat_id: string;
  user_id: string;
  role: 'member' | 'admin' | 'owner';
  joined_at: string;
  left_at?: string;
  is_muted: boolean;
  mute_until?: string;
  last_read_message_id?: string;
};

export type ChatParticipantInsert = Omit<ChatParticipant, 'id' | 'joined_at'>;
export type ChatParticipantUpdate = Partial<Omit<ChatParticipant, 'id' | 'chat_id' | 'user_id' | 'joined_at'>>;

export type Message = {
  id: string;
  chat_id: string;
  sender_id: string;
  content: string;
  message_type: 'text' | 'image' | 'video' | 'audio' | 'file' | 'location' | 'contact' | 'sticker' | 'system';
  reply_to_id?: string;
  forwarded_from_id?: string;
  metadata?: Record<string, any>;
  is_edited: boolean;
  is_deleted: boolean;
  deleted_at?: string;
  created_at: string;
  updated_at: string;
};

export type MessageInsert = Omit<Message, 'id' | 'created_at' | 'updated_at'>;
export type MessageUpdate = Partial<Omit<Message, 'id' | 'chat_id' | 'sender_id' | 'created_at'>>;

export type MessageRead = {
  id: string;
  message_id: string;
  user_id: string;
  read_at: string;
};

export type MessageReadInsert = Omit<MessageRead, 'id' | 'read_at'>;
export type MessageReadUpdate = Partial<Omit<MessageRead, 'id' | 'message_id' | 'user_id'>>;

export type MessageReaction = {
  id: string;
  message_id: string;
  user_id: string;
  emoji: string;
  created_at: string;
};

export type MessageReactionInsert = Omit<MessageReaction, 'id' | 'created_at'>;
export type MessageReactionUpdate = Partial<Omit<MessageReaction, 'id' | 'message_id' | 'user_id'>>;

export type Attachment = {
  id: string;
  message_id: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  url: string;
  thumbnail_url?: string;
  duration?: number;
  width?: number;
  height?: number;
  created_at: string;
};

export type AttachmentInsert = Omit<Attachment, 'id' | 'created_at'>;
export type AttachmentUpdate = Partial<Omit<Attachment, 'id' | 'message_id' | 'created_at'>>;

export type Group = {
  id: string;
  chat_id: string;
  name: string;
  description?: string;
  avatar_url?: string;
  invite_link?: string;
  is_private: boolean;
  max_members: number;
  created_at: string;
  updated_at: string;
};

export type GroupInsert = Omit<Group, 'id' | 'created_at' | 'updated_at'>;
export type GroupUpdate = Partial<Omit<Group, 'id' | 'chat_id' | 'created_at'>>;

export type GroupMember = {
  id: string;
  group_id: string;
  user_id: string;
  role: 'member' | 'admin' | 'owner';
  joined_at: string;
  invited_by?: string;
};

export type GroupMemberInsert = Omit<GroupMember, 'id' | 'joined_at'>;
export type GroupMemberUpdate = Partial<Omit<GroupMember, 'id' | 'group_id' | 'user_id' | 'joined_at'>>;

export type Call = {
  id: string;
  chat_id: string;
  caller_id: string;
  type: 'audio' | 'video';
  status: 'initiated' | 'ringing' | 'answered' | 'ended' | 'missed' | 'declined' | 'busy';
  started_at: string;
  ended_at?: string;
  duration?: number;
  metadata?: Record<string, any>;
};

export type CallInsert = Omit<Call, 'id' | 'started_at'>;
export type CallUpdate = Partial<Omit<Call, 'id' | 'chat_id' | 'caller_id' | 'started_at'>>;

export type CallParticipant = {
  id: string;
  call_id: string;
  user_id: string;
  joined_at?: string;
  left_at?: string;
  status: 'invited' | 'ringing' | 'joined' | 'left' | 'declined';
};

export type CallParticipantInsert = Omit<CallParticipant, 'id'>;
export type CallParticipantUpdate = Partial<Omit<CallParticipant, 'id' | 'call_id' | 'user_id'>>;

export type Notification = {
  id: string;
  user_id: string;
  type: 'message' | 'call' | 'group_invite' | 'mention' | 'reaction' | 'system';
  title: string;
  body: string;
  data?: Record<string, any>;
  is_read: boolean;
  read_at?: string;
  created_at: string;
};

export type NotificationInsert = Omit<Notification, 'id' | 'created_at' | 'read_at'>;
export type NotificationUpdate = Partial<Omit<Notification, 'id' | 'user_id' | 'created_at'>>;

export type PushToken = {
  id: string;
  user_id: string;
  token: string;
  platform: 'ios' | 'android' | 'web';
  device_id?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type PushTokenInsert = Omit<PushToken, 'id' | 'created_at' | 'updated_at'>;
export type PushTokenUpdate = Partial<Omit<PushToken, 'id' | 'user_id' | 'created_at'>>;

export type BlockedUser = {
  id: string;
  user_id: string;
  blocked_user_id: string;
  created_at: string;
};

export type BlockedUserInsert = Omit<BlockedUser, 'id' | 'created_at'>;
export type BlockedUserUpdate = Partial<Omit<BlockedUser, 'id' | 'user_id' | 'blocked_user_id'>>;

export type UserPresence = {
  user_id: string;
  status: 'online' | 'offline' | 'away' | 'busy';
  last_seen: string;
  device_type?: string;
};

export type UserPresenceInsert = Omit<UserPresence, 'last_seen'>;
export type UserPresenceUpdate = Partial<Omit<UserPresence, 'user_id'>>;

export type TypingIndicator = {
  id: string;
  chat_id: string;
  user_id: string;
  is_typing: boolean;
  updated_at: string;
};

export type TypingIndicatorInsert = Omit<TypingIndicator, 'id' | 'updated_at'>;
export type TypingIndicatorUpdate = Partial<Omit<TypingIndicator, 'id' | 'chat_id' | 'user_id'>>;

export type ChatWithLastMessage = Chat & {
  last_message?: Message;
  unread_count: number;
  other_participant?: Profile;
};

export type UserContact = Contact & {
  profile: Profile;
};