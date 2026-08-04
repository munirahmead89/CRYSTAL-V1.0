import type { ViewStyle } from 'react-native';
import { View, Pressable } from 'react-native';
import { Colors, Spacing, BorderRadius, Shadows } from '@/theme';

interface CardProps {
  children: React.ReactNode;
  style?: ViewStyle;
  variant?: 'default' | 'elevated' | 'outlined';
  padding?: 'none' | 'sm' | 'md' | 'lg';
  onPress?: () => void;
}

const paddingMap = {
  none: 0,
  sm: Spacing.sm,
  md: Spacing.md,
  lg: Spacing.lg,
};

export function Card({
  children,
  style,
  variant = 'default',
  padding = 'md',
  onPress,
}: CardProps) {
  const p = paddingMap[padding];
  const baseStyle: ViewStyle = {
    backgroundColor: Colors.light.surface,
    borderRadius: BorderRadius.lg,
    padding: p,
  };

  if (variant === 'elevated') {
    Object.assign(baseStyle, Shadows.light.md);
  } else if (variant === 'outlined') {
    baseStyle.borderWidth = 1;
    baseStyle.borderColor = Colors.light.border;
  }

  if (onPress) {
    return (
      <Pressable
        style={[{ ...baseStyle }, style]}
        onPress={onPress}
        accessibilityRole="button"
      >
        {children}
      </Pressable>
    );
  }

  return <View style={[{ ...baseStyle }, style]}>{children}</View>;
}