import { View, Text, StyleSheet } from 'react-native';
import { Link } from 'expo-router';
import { Colors, Spacing, Typography } from '@/theme';
import { Button } from '@/components/Button';

export default function NotFoundScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>404</Text>
      <Text style={styles.message}>This screen does not exist.</Text>
      <Link href="/splash" asChild>
        <Button variant="primary" fullWidth>
          Go to login
        </Button>
      </Link>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.md,
    padding: Spacing.xl,
    backgroundColor: Colors.light.background,
  },
  title: {
    fontSize: Typography.fontSize.xxxl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
  },
  message: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
  },
});
