import { View, Text, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';

import { Screen } from '@/components/Screen';
import { Button } from '@/components/Button';
import { Colors, Spacing, Typography } from '@/theme';

export default function SplashScreen() {
  const router = useRouter();

  const handleAgree = () => {
    router.replace('/(auth)/onboarding');
  };

  return (
    <Screen style={styles.container}>
      <View style={styles.content}>
        <View style={styles.logoContainer}>
          <Text style={styles.logoText}>CM</Text>
        </View>
        <Text style={styles.title}>Crystal Messenger</Text>
        <Text style={styles.subtitle}>Secure. Fast. Simple.</Text>
      </View>

      <View style={styles.footer}>
        <Text style={styles.terms}>
          By continuing, you agree to our{' '}
          <Text style={styles.link}>Terms of Service</Text> and{' '}
          <Text style={styles.link}>Privacy Policy</Text>
        </Text>
        <Button variant="primary" size="lg" fullWidth onPress={handleAgree}>
          Agree and Continue
        </Button>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'space-between',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xl,
  },
  logoContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: Colors.light.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Spacing.xl,
  },
  logoText: {
    fontSize: 36,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.background,
  },
  title: {
    fontSize: Typography.fontSize.xxl,
    fontWeight: Typography.fontWeight.bold,
    color: Colors.light.text,
    marginBottom: Spacing.sm,
  },
  subtitle: {
    fontSize: Typography.fontSize.md,
    color: Colors.light.textSecondary,
  },
  footer: {
    paddingHorizontal: Spacing.xl,
    paddingBottom: Spacing.xl,
    gap: Spacing.md,
  },
  terms: {
    fontSize: Typography.fontSize.sm,
    color: Colors.light.textSecondary,
    textAlign: 'center',
  },
  link: {
    color: Colors.light.primary,
    fontWeight: Typography.fontWeight.medium,
  },
});
