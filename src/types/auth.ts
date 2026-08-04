export interface AuthUser {
  id: string;
  phone: string;
  email?: string;
  fullName: string;
  avatarUrl?: string;
  bio?: string;
  isOnline: boolean;
  lastSeen: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  user: AuthUser;
}

export interface AuthState {
  user: AuthUser | null;
  session: AuthSession | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isOnboarded: boolean;
}

export interface OnboardingData {
  fullName: string;
  phone: string;
  bio?: string;
  avatarUrl?: string;
}