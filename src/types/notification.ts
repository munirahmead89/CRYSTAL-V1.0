export interface Notification {
  id: string;
  userId: string;
  type: 'message' | 'call' | 'group_invite' | 'mention' | 'reaction' | 'system';
  title: string;
  body: string;
  data?: Record<string, any>;
  isRead: boolean;
  readAt?: Date;
  createdAt: Date;
}

export interface PushToken {
  id: string;
  userId: string;
  token: string;
  platform: 'ios' | 'android' | 'web';
  deviceId?: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface NotificationSettings {
  pushEnabled: boolean;
  soundEnabled: boolean;
  vibrationEnabled: boolean;
  showPreview: boolean;
  groupNotifications: boolean;
}