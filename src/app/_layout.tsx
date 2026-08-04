import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { Providers } from '@/providers';
import { useAuth } from '@/hooks/useAuth';
import { Spinner } from '@/components/Spinner';

function RootNavigator() {
  const { isAuthenticated, isLoading, isOnboarded, initialize } = useAuth();

  useEffect(() => {
    initialize();
  }, [initialize]);

  if (isLoading) {
    return <Spinner fullScreen />;
  }

  if (!isAuthenticated) {
    return (
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="splash" />
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="+not-found" />
      </Stack>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      {isOnboarded ? (
        <Stack.Screen name="(app)" />
      ) : (
        <Stack.Screen name="(auth)" />
      )}
      <Stack.Screen name="+not-found" />
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <Providers>
      <RootNavigator />
    </Providers>
  );
}
