import type { ViewStyle} from 'react-native';
import { View, ScrollView, StyleSheet, SafeAreaView } from 'react-native';
import { Colors, Spacing } from '@/theme';

interface ScreenProps {
  children: React.ReactNode;
  style?: ViewStyle;
  scrollable?: boolean;
  padding?: 'none' | 'sm' | 'md' | 'lg' | number;
  backgroundColor?: string;
  safeArea?: boolean;
  keyboardShouldPersistTaps?: 'always' | 'never' | 'handled';
}

const paddingMap = {
  none: 0,
  sm: Spacing.sm,
  md: Spacing.md,
  lg: Spacing.lg,
};

export function Screen({
  children,
  style,
  scrollable = true,
  padding = 'md',
  backgroundColor = Colors.light.background,
  safeArea = true,
  keyboardShouldPersistTaps = 'handled',
}: ScreenProps) {
  const p = typeof padding === 'number' ? padding : paddingMap[padding];
  const containerStyle = [
    styles.container,
    { backgroundColor, padding: p },
    style,
  ];

  const content = (
    <View style={containerStyle}>{children}</View>
  );

  if (scrollable) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps={keyboardShouldPersistTaps}
          showsVerticalScrollIndicator={false}
        >
          {content}
        </ScrollView>
      </SafeAreaView>
    );
  }

  return safeArea ? (
    <SafeAreaView style={styles.safeArea}>
      {content}
    </SafeAreaView>
  ) : (
    content
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: Colors.light.background,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
  },
  container: {
    flex: 1,
  },
});