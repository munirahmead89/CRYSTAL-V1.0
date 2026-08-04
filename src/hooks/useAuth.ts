import { useCallback, useEffect, useRef } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';

import {
  signInAnonymously,
  signOut,
  getCurrentUser,
  getCurrentSession,
  subscribeToAuthChanges,
  initializeAuthListener,
  updateProfile as updateSupabaseProfile,
} from '@/database/client';
import { useAuthStore } from '@/stores';
import { authRepository, storageRepository } from '@/repositories';
import type { ProfileUpdate } from '@/types/database';
import type { AuthUser, AuthSession } from '@/types';
import { AppError } from '@/utils/errors';
import { logger } from '@/utils/logger';

function buildUser(user: { id: string; phone?: string; email?: string | null }, profile: { full_name: string; phone: string; avatar_url?: string; bio?: string; is_online: boolean; last_seen: string; created_at: string; updated_at: string } | null): AuthUser {
  return {
    id: user.id,
    phone: user.phone || profile?.phone || '',
    email: user.email ?? undefined,
    fullName: profile?.full_name || '',
    avatarUrl: profile?.avatar_url || undefined,
    bio: profile?.bio || undefined,
    isOnline: profile?.is_online ?? false,
    lastSeen: profile?.last_seen ? new Date(profile.last_seen) : new Date(),
    createdAt: profile?.created_at ? new Date(profile.created_at) : new Date(),
    updatedAt: profile?.updated_at ? new Date(profile.updated_at) : new Date(),
  };
}

export function useAuth() {
  const {
    user,
    session,
    isAuthenticated,
    isLoading,
    isOnboarded,
    setUser,
    setSession,
    setAuthenticated,
    setLoading,
    setOnboarded,
    logout: clearAuth,
  } = useAuthStore();
  const queryClient = useQueryClient();
  const initializedRef = useRef(false);

  const applyAuth = useCallback(
    (userData: { id: string; phone?: string; email?: string | null }, sessionData: { access_token: string; refresh_token: string; expires_at?: number | null }) => {
      return authRepository.getProfile(userData.id).then((profile) => {
        const authUser = buildUser(userData, profile);
        const authSession: AuthSession = {
          accessToken: sessionData.access_token,
          refreshToken: sessionData.refresh_token,
          expiresAt: (sessionData.expires_at ?? 0) * 1000,
          user: authUser,
        };
        return { authUser, authSession };
      });
    },
    []
  );

  const initialize = useCallback(async () => {
    if (initializedRef.current) return;
    initializedRef.current = true;
    try {
      setLoading(true);
      initializeAuthListener();
      const [userData, sessionData] = await Promise.all([getCurrentUser(), getCurrentSession()]);

      if (userData && sessionData) {
        const { authUser, authSession } = await applyAuth(userData, sessionData);
        setUser(authUser);
        setSession(authSession);
        setAuthenticated(true);
        const profile = await authRepository.getProfile(userData.id);
        setOnboarded(!!profile);
      } else {
        setUser(null);
        setSession(null);
        setAuthenticated(false);
        setOnboarded(false);
      }
    } catch (error) {
      logger.error('Auth initialization failed', {}, error as Error);
      setAuthenticated(false);
    } finally {
      setLoading(false);
    }
  }, [setUser, setSession, setAuthenticated, setLoading, setOnboarded, applyAuth]);

  useEffect(() => {
    const unsubscribe = subscribeToAuthChanges((event, session) => {
      if (event === 'SIGNED_IN' && session?.user) {
        applyAuth(session.user, session)
          .then(({ authUser, authSession }) => {
            setUser(authUser);
            setSession(authSession);
            setAuthenticated(true);
          })
          .catch((error) => {
            logger.error('Auth state sync failed', {}, error as Error);
          });
      } else if (event === 'SIGNED_OUT') {
        clearAuth();
        queryClient.clear();
      }
    });
    return unsubscribe;
  }, [applyAuth, setUser, setSession, setAuthenticated, clearAuth, queryClient]);

  const anonymousSignInMutation = useMutation({
    mutationFn: async () => {
      const { data, error } = await signInAnonymously();
      if (error) throw error;
      return data;
    },
    onSuccess: async (data) => {
      if (data.user) {
        const sessionPayload = { access_token: data.session?.access_token ?? '', refresh_token: data.session?.refresh_token ?? '', expires_at: data.session?.expires_at ?? null };
        const { authUser, authSession } = await applyAuth(data.user, sessionPayload);
        setUser(authUser);
        setSession(authSession);
        setAuthenticated(true);
      }
    },
    onError: (error) => {
      logger.error('Anonymous sign-in failed', {}, error as Error);
    },
  });

  const logoutMutation = useMutation({
    mutationFn: async () => {
      const { error } = await signOut();
      if (error) throw error;
    },
    onSuccess: () => {
      clearAuth();
      queryClient.clear();
      logger.info('User logged out');
    },
    onError: (error) => {
      logger.error('Logout failed', {}, error as Error);
    },
  });

  const completeOnboardingMutation = useMutation({
    mutationFn: async (data: { fullName: string; phone: string; bio?: string; avatarUrl?: string }) => {
      const currentUser = useAuthStore.getState().user;
      if (!currentUser) {
        throw AppError.unauthorized('You must be signed in to complete onboarding');
      }
      await authRepository.createProfile(currentUser.id, {
        phone: data.phone,
        full_name: data.fullName,
        bio: data.bio,
        avatar_url: data.avatarUrl,
        is_online: false,
        last_seen: new Date().toISOString(),
      });
      await updateSupabaseProfile({ full_name: data.fullName, avatar_url: data.avatarUrl, bio: data.bio });
      const updatedProfile = await authRepository.getProfile(currentUser.id);
      return updatedProfile;
    },
    onSuccess: async (profile) => {
      const currentUser = useAuthStore.getState().user;
      if (profile && currentUser) {
        const authUser = buildUser({ ...currentUser, phone: profile.phone }, profile);
        setUser(authUser);
        setOnboarded(true);
        queryClient.invalidateQueries({ queryKey: ['user'] });
      }
    },
  });

  const updateProfileMutation = useMutation({
    mutationFn: async (data: { fullName?: string; bio?: string; avatarUrl?: string }) => {
      const currentUser = useAuthStore.getState().user;
      if (!currentUser) {
        throw AppError.unauthorized('You must be signed in to update your profile');
      }
      const updates: ProfileUpdate = {};
      if (data.fullName !== undefined) updates.full_name = data.fullName;
      if (data.bio !== undefined) updates.bio = data.bio;
      if (data.avatarUrl !== undefined) updates.avatar_url = data.avatarUrl;
      await authRepository.updateProfile(currentUser.id, updates);
      await updateSupabaseProfile({ full_name: data.fullName, avatar_url: data.avatarUrl, bio: data.bio });
      const updatedProfile = await authRepository.getProfile(currentUser.id);
      return updatedProfile;
    },
    onSuccess: async (profile) => {
      const currentUser = useAuthStore.getState().user;
      if (profile && currentUser) {
        const authUser = buildUser({ ...currentUser, phone: profile.phone }, profile);
        setUser(authUser);
        queryClient.invalidateQueries({ queryKey: ['user'] });
      }
    },
  });

  const uploadAvatarMutation = useMutation({
    mutationFn: async (fileUri: string) => {
      const currentUser = useAuthStore.getState().user;
      if (!currentUser) {
        throw AppError.unauthorized('You must be signed in to upload an avatar');
      }
      const publicUrl = await storageRepository.uploadAvatar(currentUser.id, fileUri);
      await authRepository.updateProfile(currentUser.id, { avatar_url: publicUrl });
      await updateSupabaseProfile({ avatar_url: publicUrl });
      const updatedProfile = await authRepository.getProfile(currentUser.id);
      return updatedProfile;
    },
    onSuccess: async (profile) => {
      const currentUser = useAuthStore.getState().user;
      if (profile && currentUser) {
        const authUser = buildUser({ ...currentUser, phone: profile.phone }, profile);
        setUser(authUser);
        queryClient.invalidateQueries({ queryKey: ['user'] });
      }
    },
    onError: (error) => {
      logger.error('Avatar upload failed', {}, error as Error);
    },
  });

  const signInAnon = useCallback(
    async () => {
      return anonymousSignInMutation.mutateAsync();
    },
    [anonymousSignInMutation]
  );

  const completeOnboarding = useCallback(
    async (data: { fullName: string; phone: string; bio?: string; avatarUrl?: string }) => {
      return completeOnboardingMutation.mutateAsync(data);
    },
    [completeOnboardingMutation]
  );

  const updateProfileFn = useCallback(
    async (data: { fullName?: string; bio?: string; avatarUrl?: string }) => {
      return updateProfileMutation.mutateAsync(data);
    },
    [updateProfileMutation]
  );

  const uploadAvatarFn = useCallback(
    async (fileUri: string) => {
      return uploadAvatarMutation.mutateAsync(fileUri);
    },
    [uploadAvatarMutation]
  );

  return {
    user,
    session,
    isAuthenticated,
    isLoading,
    isOnboarded,
    initialize,
    signInAnon,
    signInAnonState: anonymousSignInMutation,
    completeOnboarding,
    completeOnboardingState: completeOnboardingMutation,
    logout: logoutMutation.mutateAsync,
    logoutState: logoutMutation,
    updateProfile: updateProfileFn,
    updateProfileState: updateProfileMutation,
    uploadAvatar: uploadAvatarFn,
    uploadAvatarState: uploadAvatarMutation,
  };
}
