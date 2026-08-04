import { View, Text, SectionList, TextInput, Pressable, RefreshControl, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { useState, useMemo } from 'react';
import { Ionicons } from '@expo/vector-icons';

import { Screen } from '@/components/Screen';
import { Avatar } from '@/components/Avatar';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';
import { useAuth } from '@/hooks/useAuth';
import { useContacts } from '@/hooks/useContacts';
import type { UserContact } from '@/types/database';

export default function ContactsScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const { contacts, loading, refetch } = useContacts(user?.id);
  const [search, setSearch] = useState('');
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = async () => {
    setRefreshing(true);
    await refetch();
    setRefreshing(false);
  };

  // Filter contacts by search query
  const filteredContacts = useMemo(() => {
    return contacts.filter((contact) => {
      const name = contact.display_name || contact.profile?.full_name || '';
      const phone = contact.profile?.phone || '';
      return (
        name.toLowerCase().includes(search.toLowerCase()) ||
        phone.includes(search)
      );
    });
  }, [contacts, search]);

  // Group contacts alphabetically
  const sections = useMemo(() => {
    const groups: Record<string, UserContact[]> = {};
    filteredContacts.forEach((contact) => {
      const name = contact.display_name || contact.profile?.full_name || 'Unknown';
      const firstLetter = name.charAt(0).toUpperCase();
      const key = /[A-Z]/.test(firstLetter) ? firstLetter : '#';
      const group = groups[key] ?? [];
      group.push(contact);
      groups[key] = group;
    });

    return Object.keys(groups)
      .sort((a, b) => {
        if (a === '#') return 1;
        if (b === '#') return -1;
        return a.localeCompare(b);
      })
      .map((key) => {
        const group = groups[key] ?? [];
        return {
          title: key,
          data: group.sort((a, b) => {
            const nameA = a.display_name || a.profile?.full_name || '';
            const nameB = b.display_name || b.profile?.full_name || '';
            return nameA.localeCompare(nameB);
          }),
        };
      });
  }, [filteredContacts]);

  return (
    <Screen scrollable={false} padding="none" safeArea>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Ionicons name="arrow-back" size={24} color={Colors.light.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Select Contact</Text>
        <Pressable onPress={() => router.push('/new-contact')} style={styles.addButton}>
          <Ionicons name="person-add" size={20} color={Colors.light.text} />
        </Pressable>
      </View>

      <View style={styles.searchContainer}>
        <View style={styles.searchBar}>
          <Ionicons name="search" size={20} color={Colors.light.textSecondary} style={styles.searchIcon} />
          <TextInput
            placeholder="Search contacts..."
            placeholderTextColor={Colors.light.textTertiary}
            value={search}
            onChangeText={setSearch}
            style={styles.searchInput}
          />
          {search ? (
            <Pressable onPress={() => setSearch('')}>
              <Ionicons name="close-circle" size={18} color={Colors.light.textSecondary} />
            </Pressable>
          ) : null}
        </View>
      </View>

      <SectionList
        sections={sections}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => {
          const displayName = item.display_name || item.profile?.full_name || 'Unknown';
          const bio = item.profile?.bio || 'No bio status';
          const isOnline = item.profile?.is_online || false;

          return (
            <Pressable
              onPress={() => router.push(`/contacts/${item.contact_id}`)}
              style={({ pressed }) => [styles.contactItem, pressed && styles.pressed]}
            >
              <View style={styles.avatarContainer}>
                <Avatar
                  source={item.profile?.avatar_url ? { uri: item.profile.avatar_url } : undefined}
                  name={displayName}
                  size="md"
                />
                {isOnline && <View style={styles.onlineDot} />}
              </View>
              <View style={styles.contactInfo}>
                <Text style={styles.contactName}>{displayName}</Text>
                <Text style={styles.contactBio} numberOfLines={1}>{bio}</Text>
              </View>
            </Pressable>
          );
        }}
        renderSectionHeader={({ section: { title } }) => (
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>{title}</Text>
          </View>
        )}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[Colors.light.primary]} />
        }
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={
          !loading ? (
            <View style={styles.emptyState}>
              <Ionicons name="people-outline" size={48} color={Colors.light.textTertiary} />
              <Text style={styles.emptyText}>No contacts found</Text>
              <Text style={styles.emptySubtext}>Add contacts to start chatting</Text>
            </View>
          ) : null
        }
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    backgroundColor: Colors.light.surface,
  },
  backButton: {
    padding: Spacing.xs,
  },
  headerTitle: {
    fontSize: Typography.fontSize.lg,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  addButton: {
    padding: Spacing.xs,
  },
  searchContainer: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    backgroundColor: Colors.light.surface,
    borderBottomWidth: 0.5,
    borderBottomColor: Colors.light.border,
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.light.surfaceVariant,
    borderRadius: BorderRadius.round,
    paddingHorizontal: Spacing.sm,
    height: 40,
  },
  searchIcon: {
    marginRight: Spacing.xs,
  },
  searchInput: {
    flex: 1,
    color: Colors.light.text,
    fontSize: Typography.fontSize.sm,
    paddingVertical: 0,
  },
  listContent: {
    paddingBottom: Spacing.xl,
  },
  sectionHeader: {
    backgroundColor: Colors.light.background,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
  },
  sectionTitle: {
    fontSize: Typography.fontSize.xs,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.primary,
  },
  contactItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    backgroundColor: Colors.light.surface,
    borderBottomWidth: 0.5,
    borderBottomColor: Colors.light.borderLight,
  },
  pressed: {
    backgroundColor: Colors.light.surfaceVariant,
  },
  avatarContainer: {
    position: 'relative',
  },
  onlineDot: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: Colors.light.onlineIndicator,
    borderWidth: 1.5,
    borderColor: Colors.light.surface,
  },
  contactInfo: {
    flex: 1,
    marginLeft: Spacing.md,
  },
  contactName: {
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.text,
  },
  contactBio: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
    marginTop: 2,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.xxl,
    gap: Spacing.sm,
  },
  emptyText: {
    fontSize: Typography.fontSize.md,
    fontWeight: Typography.fontWeight.semibold,
    color: Colors.light.text,
  },
  emptySubtext: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
  },
});
