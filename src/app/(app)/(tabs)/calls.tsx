import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Screen } from '@/components/Screen';
import { Colors, Spacing, Typography, BorderRadius } from '@/theme';

export default function CallsScreen() {
  return (
    <Screen scrollable={false} padding="none" safeArea>
      <View style={styles.emptyState}>
        <Ionicons name="call-outline" size={64} color={Colors.light.textSecondary} />
        <Text style={styles.emptyText}>No calls logged yet.</Text>
      </View>

      <View style={styles.fabContainer}>
        <Pressable style={styles.fab}>
          <Ionicons name="call" size={24} color={Colors.light.background} />
        </Pressable>
      </View>
      
    </Screen>
  );
}

const styles = StyleSheet.create({
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: Spacing.md,
    paddingBottom: 80,
  },
  emptyText: {
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
    borderRadius: BorderRadius.md,
    backgroundColor: '#D4E4F7',
    justifyContent: 'center',
    alignItems: 'center',
  },
});
