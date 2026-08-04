import type { UserProfile } from './user';

export interface Contact {
  id: string;
  userId: string;
  contactId: string;
  displayName?: string;
  isFavorite: boolean;
  isBlocked: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ContactWithProfile extends Contact {
  profile: UserProfile;
}

export interface AddContactData {
  contactId: string;
  displayName?: string;
}

export interface UpdateContactData {
  displayName?: string;
  isFavorite?: boolean;
  isBlocked?: boolean;
}