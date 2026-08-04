import type { ViewStyle } from 'react-native';
import { View, StyleSheet } from 'react-native';
import { Colors, Spacing } from '@/theme';

interface DividerProps {
  style?: ViewStyle;
  vertical?: boolean;
  inset?: boolean;
}

export function Divider({ style, vertical = false, inset = false }: DividerProps) {
  return (
    <View
      style={[
        vertical ? styles.vertical : styles.horizontal,
        inset && styles.inset,
        style,
      ]}
    />
  );
}

const styles = StyleSheet.create({
  horizontal: {
    height: 1,
    backgroundColor: Colors.light.border,
    marginVertical: Spacing.sm,
  },
  vertical: {
    width: 1,
    backgroundColor: Colors.light.border,
    marginHorizontal: Spacing.sm,
  },
  inset: {
    marginLeft: Spacing.lg,
  },
});