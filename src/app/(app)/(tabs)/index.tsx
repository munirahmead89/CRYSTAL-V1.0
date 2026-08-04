import { View, Text, FlatList, RefreshControl, Alert, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { useCallback, useState } from 'react';

import { Screen } from '@/components/Screen';
import { Card } from '@/components/Card';
import { Button } from '@/components/Button';
import { Avatar } from '@/components/Avatar';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';
import { useChats, type ChatWithDetails } from '@/hooks/useChats';

function formatTime(dateStr: string | undefined): string {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) {
    return date.toLocaleDateString([], { weekday: 'short' });
  }
  return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
}

export default function ChatsScreen() {
  const router = useRouter();
  const { user, logout } = useAuth();
  const { chats, loading, refetch } = useChats(user?.id);
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await refetch();
    setRefreshing(false);
  }, [refetch]);

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure you want to logout?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Logout', style: 'destructive', onPress: () => { void logout(); } },
    ]);
  };

  const renderChat = ({ item }: { item: ChatWithDetails }) => {
    const displayName = item.otherParticipant?.full_name || item.name || 'Unknown';
    const lastMsg = item.lastMessage?.content || '';
    const lastTime = formatTime(item.lastMessage?.created_at);
    const isOnline = item.otherParticipant?.is_online ?? false;

    return (
      <Card
        style={styles.chatItem}
        onPress={() => router.push(`/chats/${item.id}`)}
        padding="none"
      >
        <View style={styles.chatContent}>
          <View style={styles.avatarContainer}>
            <Avatar
              name={displayName}
              size="lg"
              showBorder
              borderColor={Colors.light.background}
            />
            {isOnline && <View style={styles.onlineDot} />}
          </View>
          <View style={styles.chatInfo}>
            <View style={styles.chatHeader}>
              <Text style={styles.chatName} numberOfLines={1}>{displayName}</Text>
              <Text style={[
                styles.chatTime,
                (item.unreadCount ?? 0) > 0 && styles.chatTimeUnread,
              ]}>{lastTime}</Text>
            </View>
            <View style={styles.chatPreview}>
              <Text style={[
                styles.lastMessage,
                (item.unreadCount ?? 0) > 0 && styles.lastMessageUnread,
              ]} numberOfLines={1}>{lastMsg || 'Start a conversation'}</Text>
              {(item.unreadCount ?? 0) > 0 && (
                <View style={styles.unreadBadge}>
                  <Text style={styles.unreadText}>{item.unreadCount > 99 ? '99+' : item.unreadCount}</Text>
                </View>
              )}
            </View>
          </View>
        </View>
      </Card>
    );
  };

  return (
    <Screen scrollable={false} padding="none" safeArea>
      <View style={styles.header}>
        <View style={styles.headerContent}>
          <Text style={styles.title}>Chats</Text>
          <View style={styles.headerActions}>
            <Button variant="ghost" size="sm" onPress={() => Alert.alert('Search', 'Coming soon')}>
              <Text style={styles.headerIcon}>🔍</Text>
            </Button>
            <Button variant="ghost" size="sm" onPress={handleLogout}>
              <Text style={styles.headerIcon}>⋮</Text>
            </Button>
          </View>
        </View>
      </View>

      <FlatList
        data={chats}
        renderItem={renderChat}
        keyExtractor={(item) => item.id}
        refreshing={refreshing}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[Colors.light.primary]} tintColor={Colors.light.primary} />
        }
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          !loading ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyIcon}>💬</Text>
              <Text style={styles.emptyText}>No chats yet</Text>
              <Text style={styles.emptySubtext}>Start a new conversation</Text>
            </View>
          ) : null
        }
      />

      <View style={styles.fabContainer}>
        <Button
          variant="primary"
          size="lg"
          style={styles.fab}
          onPress={() => router.push('/(app)/contacts' as any)}
        >
          <Text style={styles.fabText}>💬</Text>
        </Button>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderBottomWidth: 0.5,
    borderBottomColor: Colors.light.border,
    backgroundColor: Colors.light.surface,
  },
  headerContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: {
    fontSize: Typography.fontSize.xxl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  headerActions: {
    flexDirection: 'row',
    gap: Spacing.xs,
  },
  headerIcon: {
    fontSize: 18,
  },
  chatItem: {
    marginHorizontal: Spacing.md,
    marginVertical: Spacing.xs,
    backgroundColor: Colors.light.surface,
  },
  chatContent: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    gap: Spacing.md,
  },
  avatarContainer: {
    position: 'relative',
  },
  onlineDot: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: Colors.light.onlineIndicator,
    borderWidth: 2,
    borderColor: Colors.light.surface,
  },
  chatInfo: {
    flex: 1,
    minWidth: 0,
    gap: Spacing.xs,
  },
  chatHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  chatName: {
    flex: 1,
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.text,
  },
  chatTime: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textTertiary,
  },
  chatTimeUnread: {
    color: Colors.light.primary,
  },
  chatPreview: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  lastMessage: {
    flex: 1,
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
  },
  lastMessageUnread: {
    color: Colors.light.text,
    fontWeight: Typography.fontWeight.medium,
  },
  unreadBadge: {
    backgroundColor: Colors.light.primary,
    borderRadius: BorderRadius.round,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    minWidth: 20,
    alignItems: 'center',
    marginLeft: Spacing.sm,
  },
  unreadText: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.inverse,
  },
  listContent: {
    paddingBottom: 100,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
    paddingTop: Spacing.xxl,
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: Spacing.md,
  },
  emptyText: {
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.text,
    marginBottom: Spacing.xs,
  },
  emptySubtext: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
  },
  fabContainer: {
    position: 'absolute',
    bottom: Spacing.xl,
    right: Spacing.lg,
    zIndex: 10,
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    padding: 0,
    justifyContent: 'center',
    alignItems: 'center',
  },
  fabText: {
    fontSize: 24,
    lineHeight: 24,
  },
});
