import type { ReactNode } from 'react';
import { Pressable, Text, StyleSheet, ActivityIndicator, View } from 'react-native';
import { Colors, Spacing, BorderRadius, Typography } from '@/theme';

type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps {
  children: ReactNode;
  onPress?: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  disabled?: boolean;
  loading?: boolean;
  fullWidth?: boolean;
  style?: any;
  testID?: string;
}

const variantStyles: Record<ButtonVariant, { backgroundColor: string; borderColor: string; textColor: string }> = {
  primary: {
    backgroundColor: Colors.light.primary,
    borderColor: Colors.light.primary,
    textColor: Colors.light.inverse,
  },
  secondary: {
    backgroundColor: Colors.light.secondary,
    borderColor: Colors.light.secondary,
    textColor: Colors.light.inverse,
  },
  outline: {
    backgroundColor: 'transparent',
    borderColor: Colors.light.primary,
    textColor: Colors.light.primary,
  },
  ghost: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
    textColor: Colors.light.primary,
  },
  danger: {
    backgroundColor: Colors.light.error,
    borderColor: Colors.light.error,
    textColor: Colors.light.inverse,
  },
};

const sizeStyles: Record<ButtonSize, { paddingVertical: number; paddingHorizontal: number; fontSize: number; borderRadius: number }> = {
  sm: {
    paddingVertical: Spacing.xs,
    paddingHorizontal: Spacing.md,
    fontSize: Typography.fontSize.sm,
    borderRadius: BorderRadius.sm,
  },
  md: {
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    fontSize: Typography.fontSize.md,
    borderRadius: BorderRadius.md,
  },
  lg: {
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.xl,
    fontSize: Typography.fontSize.lg,
    borderRadius: BorderRadius.lg,
  },
};

export function Button({
  children,
  onPress,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  fullWidth = false,
  style,
  testID,
}: ButtonProps) {
  const v = variantStyles[variant];
  const s = sizeStyles[size];

  const isDisabled = disabled || loading;

  return (
    <Pressable
      onPress={isDisabled ? undefined : onPress}
      disabled={isDisabled}
      style={[
        styles.container,
        fullWidth && styles.fullWidth,
        {
          backgroundColor: isDisabled ? Colors.light.border : v.backgroundColor,
          borderColor: isDisabled ? Colors.light.border : v.borderColor,
          paddingVertical: s.paddingVertical,
          paddingHorizontal: s.paddingHorizontal,
          borderRadius: s.borderRadius,
        },
        style,
      ]}
      testID={testID}
      accessibilityRole="button"
      accessibilityState={{ disabled: isDisabled }}
    >
      <View style={styles.content}>
        {loading ? (
          <ActivityIndicator size="small" color={v.textColor} />
        ) : (
          <Text
            style={[
              styles.text,
              {
                color: isDisabled ? Colors.light.textTertiary : v.textColor,
                fontSize: s.fontSize,
                fontWeight: Typography.fontWeight.semibold as '600',
              },
            ]}
          >
            {children}
          </Text>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    minHeight: 44,
  },
  fullWidth: {
    width: '100%',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    textAlign: 'center',
  },
});