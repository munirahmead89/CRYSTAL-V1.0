export interface UserProfile {
  id: string;
  email: string;
  phone?: string;
  fullName: string;
  username?: string;
  avatarUrl?: string;
  bio?: string;
  isOnline: boolean;
  lastSeen: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserPresence {
  userId: string;
  status: 'online' | 'offline' | 'away' | 'busy';
  lastSeen: Date;
  deviceType?: string;
}

export interface UpdateProfileData {
  fullName?: string;
  username?: string;
  avatarUrl?: string;
  bio?: string;
}

export interface SearchUserResult {
  id: string;
  fullName: string;
  username?: string;
  avatarUrl?: string;
  isOnline: boolean;
}