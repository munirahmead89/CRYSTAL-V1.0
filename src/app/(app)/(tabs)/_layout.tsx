import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Typography } from '@/theme';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: Colors.light.text,
        tabBarInactiveTintColor: Colors.light.textSecondary,
        tabBarLabelStyle: {
          fontSize: Typography.fontSize.xs,
          fontWeight: Typography.fontWeight.semibold,
          textTransform: 'uppercase',
          letterSpacing: 1,
        },
        tabBarStyle: {
          backgroundColor: Colors.light.surface,
          borderTopWidth: 0.5,
          borderTopColor: Colors.light.border,
          height: 60,
          paddingBottom: 8,
          paddingTop: 4,
        },
        lazy: false,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Chats',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="chatbubble-ellipses" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="calls"
        options={{
          title: 'Calls',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="call" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
