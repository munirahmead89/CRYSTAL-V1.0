import { View, Text, ScrollView, Pressable, Alert, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

import { Screen } from '@/components/Screen';
import { Avatar } from '@/components/Avatar';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';

type IoniconsName = React.ComponentProps<typeof Ionicons>['name'];

interface SettingsItem {
  icon: IoniconsName;
  title: string;
  subtitle: string;
  onPress: () => void;
}

export default function SettingsScreen() {
  const router = useRouter();
  const { user } = useAuth();

  const settingsItems: SettingsItem[] = [
    {
      icon: 'lock-closed-outline',
      title: 'Account',
      subtitle: 'Security notifications, change number, request account info',
      onPress: () => Alert.alert('Coming Soon'),
    },
    {
      icon: 'shield-checkmark-outline',
      title: 'Privacy',
      subtitle: 'Block contacts, disappearing messages, dynamic profile',
      onPress: () => Alert.alert('Coming Soon'),
    },
    {
      icon: 'chatbubble-ellipses-outline',
      title: 'Chats',
      subtitle: 'Theme, wallpapers, offline cache backup, chat history',
      onPress: () => Alert.alert('Coming Soon'),
    },
    {
      icon: 'notifications-outline',
      title: 'Notifications',
      subtitle: 'Message, group & call alert tones',
      onPress: () => Alert.alert('Coming Soon'),
    },
    {
      icon: 'cloud-outline',
      title: 'Storage and Data',
      subtitle: 'Network usage statistics, media auto-download, low data usage',
      onPress: () => Alert.alert('Coming Soon'),
    },
    {
      icon: 'globe-outline',
      title: 'App Language',
      subtitle: '',
      onPress: () => Alert.alert('Coming Soon'),
    },
  ];

  return (
    <Screen scrollable={false} padding="none" safeArea>
      <View style={styles.container}>
        <View style={styles.header}>
          <Pressable
            onPress={() => router.back()}
            style={styles.backButton}
            accessibilityLabel="Go back"
          >
            <Ionicons name="arrow-back" size={24} color={Colors.light.text} />
          </Pressable>
          <Text style={styles.headerTitle}>Settings</Text>
        </View>

        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          <Pressable
            style={styles.profileSection}
            onPress={() => router.push('/profile')}
            accessibilityRole="button"
          >
            <View style={styles.profileLeft}>
              <View style={styles.avatarContainer}>
                <Avatar
                  source={user?.avatarUrl ? { uri: user.avatarUrl } : undefined}
                  name={user?.fullName}
                  size="xl"
                />
                <View style={styles.crownOverlay}>
                  <Ionicons name="diamond-outline" size={14} color={Colors.light.warning} />
                </View>
              </View>
              <View style={styles.profileInfo}>
                <Text style={styles.profileName}>
                  {user?.fullName || 'MUNIR WAHEED'}
                </Text>
                <Text style={styles.profilePhone}>
                  {user?.phone || '+92 3240941091'}
                </Text>
                <Text style={styles.profileStatus}>
                  Hey there! I am using WhatsApp.
                </Text>
              </View>
            </View>
            <Ionicons
              name="qr-code-outline"
              size={24}
              color={Colors.light.textSecondary}
            />
          </Pressable>

          <View style={styles.listSection}>
            {settingsItems.map((item) => (
              <Pressable
                key={item.title}
                style={({ pressed }) => [
                  styles.listItem,
                  pressed && styles.listItemPressed,
                ]}
                onPress={item.onPress}
                accessibilityRole="button"
              >
                <Ionicons
                  name={item.icon}
                  size={24}
                  color={Colors.light.text}
                  style={styles.listItemIcon}
                />
                <View style={styles.listItemContent}>
                  <Text style={styles.listItemTitle}>{item.title}</Text>
                  {item.subtitle ? (
                    <Text style={styles.listItemSubtitle}>{item.subtitle}</Text>
                  ) : null}
                </View>
              </Pressable>
            ))}
          </View>

          <View style={styles.footer}>
            <Text style={styles.footerFrom}>from</Text>
            <Text style={styles.footerCompany}>CRYSTAL LLC</Text>
          </View>
        </ScrollView>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    backgroundColor: Colors.light.surface,
  },
  backButton: {
    padding: Spacing.xs,
    marginRight: Spacing.sm,
  },
  headerTitle: {
    fontSize: Typography.fontSize.xl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
  },
  profileSection: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.light.surfaceVariant,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.lg,
    borderBottomWidth: 1,
    borderBottomColor: Colors.light.border,
  },
  profileLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    marginRight: Spacing.md,
  },
  avatarContainer: {
    position: 'relative',
    marginRight: Spacing.md,
  },
  crownOverlay: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    backgroundColor: Colors.light.background,
    borderRadius: BorderRadius.round,
    padding: 2,
  },
  profileInfo: {
    flex: 1,
  },
  profileName: {
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  profilePhone: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
    marginTop: 2,
  },
  profileStatus: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textSecondary,
    marginTop: 2,
  },
  listSection: {
    marginTop: Spacing.sm,
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    backgroundColor: Colors.light.background,
  },
  listItemPressed: {
    opacity: 0.7,
  },
  listItemIcon: {
    marginRight: Spacing.md,
  },
  listItemContent: {
    flex: 1,
  },
  listItemTitle: {
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.medium,
    color: Colors.light.text,
  },
  listItemSubtitle: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textSecondary,
    marginTop: 2,
  },
  footer: {
    alignItems: 'center',
    paddingVertical: Spacing.xl,
  },
  footerFrom: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textSecondary,
  },
  footerCompany: {
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
    marginTop: 2,
  },
});
