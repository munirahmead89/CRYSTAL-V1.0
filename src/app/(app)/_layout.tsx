import { Stack } from 'expo-router';

export default function AppLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="profile" />
      <Stack.Screen name="settings" />
      <Stack.Screen name="qr-code" />
      <Stack.Screen name="new-contact" />
      <Stack.Screen name="contacts" />
      <Stack.Screen name="chats/[id]" />
      <Stack.Screen name="contacts/[id]" />
    </Stack>
  );
}
