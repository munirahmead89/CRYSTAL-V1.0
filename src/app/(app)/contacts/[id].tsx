import { View, Text, Alert, ActivityIndicator, StyleSheet } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';

import { Screen } from '@/components/Screen';
import { Card } from '@/components/Card';
import { Button } from '@/components/Button';
import { Avatar } from '@/components/Avatar';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';
import { useContacts } from '@/hooks/useContacts';

export default function ContactDetailScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const contactId = params.id as string;

  const { user } = useAuth();
  const { contacts, loading, blockContact, startChat } = useContacts(user?.id);

  const contact = contacts.find((c) => c.contact_id === contactId);

  if (loading) {
    return (
      <Screen scrollable={false} padding="lg" safeArea={true}>
        <View style={styles.centerContainer}>
          <ActivityIndicator size="large" color={Colors.light.primary} />
        </View>
      </Screen>
    );
  }

  if (!contact) {
    return (
      <Screen scrollable={false} padding="lg" safeArea={true}>
        <View style={styles.centerContainer}>
          <Text style={styles.errorText}>Contact not found</Text>
          <Button variant="outline" onPress={() => router.back()} style={styles.backButton}>
            Go Back
          </Button>
        </View>
      </Screen>
    );
  }

  const displayName = contact.display_name || contact.profile?.full_name || 'Unknown';
  const bio = contact.profile?.bio || '';
  const isOnline = contact.profile?.is_online || false;
  const phone = contact.profile?.phone || '';
  const avatarUrl = contact.profile?.avatar_url;

  const handleMessage = async () => {
    try {
      const chatId = await startChat(contactId);
      if (chatId) {
        router.push(`/chats/${chatId}`);
      } else {
        Alert.alert('Error', 'Failed to start chat session');
      }
    } catch {
      Alert.alert('Error', 'Failed to start chat session');
    }
  };

  const handleVoiceCall = () => {
    Alert.alert('Voice Call', 'Starting voice call...');
  };

  const handleVideoCall = () => {
    Alert.alert('Video Call', 'Starting video call...');
  };

  const handleBlock = () => {
    Alert.alert('Block Contact', 'Are you sure you want to block this contact?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Block',
        style: 'destructive',
        onPress: async () => {
          try {
            await blockContact(contactId);
            Alert.alert('Blocked', 'Contact has been blocked');
            router.back();
          } catch {
            Alert.alert('Error', 'Failed to block contact');
          }
        },
      },
    ]);
  };

  return (
    <Screen scrollable={true} padding="lg" safeArea={true}>
      <View style={styles.container}>
        <View style={styles.profileHeader}>
          <Avatar
            source={avatarUrl ? { uri: avatarUrl } : undefined}
            name={displayName}
            size="xxl"
            showBorder
            borderColor={Colors.light.background}
          />
          <View style={styles.nameContainer}>
            <Text style={styles.fullName}>{displayName}</Text>
            <Text style={styles.username}>{phone}</Text>
          </View>
          <View style={styles.statusContainer}>
            <View style={[styles.statusDot, isOnline && styles.statusOnline]} />
            <Text style={styles.statusText}>
              {isOnline ? 'Online' : 'Offline'}
            </Text>
          </View>
        </View>

        <Card style={styles.actionCard} padding="md" variant="outlined">
          <View style={styles.actionRow}>
            <Button
              variant="primary"
              onPress={handleMessage}
              style={styles.actionButton}
              fullWidth
            >
              Message
            </Button>
            <Button
              variant="outline"
              onPress={handleVoiceCall}
              style={styles.actionButton}
              fullWidth
            >
              Voice Call
            </Button>
            <Button
              variant="outline"
              onPress={handleVideoCall}
              style={styles.actionButton}
              fullWidth
            >
              Video Call
            </Button>
          </View>
        </Card>

        {bio ? (
          <Card style={styles.infoCard} padding="lg" variant="outlined">
            <Text style={styles.sectionTitle}>About</Text>
            <Text style={styles.bioText}>{bio}</Text>
          </Card>
        ) : null}

        <Card style={styles.dangerCard} padding="lg" variant="outlined">
          <Button
            variant="danger"
            fullWidth
            onPress={handleBlock}
          >
            Block Contact
          </Button>
        </Card>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: Spacing.xl,
    alignItems: 'center',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.md,
  },
  errorText: {
    fontSize: Typography.fontSize.lg,
    color: Colors.light.error,
    fontWeight: Typography.fontWeight.semibold,
  },
  backButton: {
    minWidth: 120,
  },
  profileHeader: {
    alignItems: 'center',
    gap: Spacing.md,
    width: '100%',
    paddingTop: Spacing.lg,
  },
  nameContainer: {
    alignItems: 'center',
    gap: Spacing.xs,
  },
  fullName: {
    fontSize: Typography.fontSize.xxl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  username: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.xs,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    backgroundColor: Colors.light.surface,
    borderRadius: BorderRadius.round,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: Colors.light.textTertiary,
  },
  statusOnline: {
    backgroundColor: Colors.light.onlineIndicator,
  },
  statusText: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
  },
  actionCard: {
    width: '100%',
  },
  actionRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
  },
  actionButton: {
    flex: 1,
  },
  infoCard: {
    width: '100%',
    gap: Spacing.md,
  },
  dangerCard: {
    width: '100%',
  },
  sectionTitle: {
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.textSecondary,
    textTransform: 'uppercase',
    marginBottom: Spacing.md,
  },
  bioText: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.text,
    lineHeight: Typography.lineHeight.md,
  },
});