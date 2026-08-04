import type { ViewStyle } from 'react-native';
import { ActivityIndicator, View, StyleSheet } from 'react-native';
import { Colors } from '@/theme';

interface SpinnerProps {
  size?: 'small' | 'large';
  color?: string;
  style?: ViewStyle;
  fullScreen?: boolean;
}

export function Spinner({ size = 'large', color = Colors.light.primary, style, fullScreen = false }: SpinnerProps) {
  const containerStyle = fullScreen
    ? [styles.fullScreen, style]
    : [styles.centered, style];

  return (
    <View style={containerStyle}>
      <ActivityIndicator size={size} color={color} />
    </View>
  );
}

const styles = StyleSheet.create({
  centered: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  fullScreen: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.light.background,
  },
});