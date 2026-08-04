export interface Group {
  id: string;
  chatId: string;
  name: string;
  description?: string;
  avatarUrl?: string;
  inviteLink?: string;
  isPrivate: boolean;
  maxMembers: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface GroupMember {
  id: string;
  groupId: string;
  userId: string;
  role: 'member' | 'admin' | 'owner';
  joinedAt: Date;
  invitedBy?: string;
}

export interface CreateGroupData {
  name: string;
  description?: string;
  participantIds: string[];
  avatarUrl?: string;
  isPrivate?: boolean;
}

export interface UpdateGroupData {
  name?: string;
  description?: string;
  avatarUrl?: string;
  isPrivate?: boolean;
  maxMembers?: number;
}