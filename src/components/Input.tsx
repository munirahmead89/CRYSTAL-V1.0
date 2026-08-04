import type { TextInputProps } from 'react-native';
import { TextInput, View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, BorderRadius, Typography } from '@/theme';

interface InputProps extends Omit<TextInputProps, 'style'> {
  label?: string;
  error?: string;
  helperText?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  containerStyle?: any;
  inputStyle?: any;
}

export function Input({
  label,
  error,
  helperText,
  leftIcon,
  rightIcon,
  containerStyle,
  inputStyle,
  secureTextEntry = false,
  ...props
}: InputProps) {
  const hasError = !!error;

  return (
    <View style={[styles.container, containerStyle]}>
      {label && (
        <Text
          style={[
            styles.label,
            { color: hasError ? Colors.light.error : Colors.light.textSecondary },
          ]}
        >
          {label}
        </Text>
      )}
      <View style={styles.inputWrapper}>
        {leftIcon && (
          <View style={styles.iconContainer}>
            {leftIcon}
          </View>
        )}
        <TextInput
          style={[
            styles.input,
            {
              paddingLeft: leftIcon ? 0 : Spacing.md,
              color: Colors.light.text,
            },
            hasError && styles.inputError,
            inputStyle,
          ]}
          secureTextEntry={secureTextEntry}
          selectionColor={Colors.light.primary}
          {...props}
        />
        {rightIcon && (
          <View style={styles.iconContainer}>
            {rightIcon}
          </View>
        )}
      </View>
      {hasError && (
        <Text style={styles.errorText}>{error}</Text>
      )}
      {!hasError && helperText && (
        <Text style={styles.helperText}>{helperText}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: Spacing.xs,
  },
  label: {
    fontSize: Typography.fontSize.sm,
    fontWeight: Typography.fontWeight.medium as '500',
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.light.surface,
    borderWidth: 1,
    borderColor: Colors.light.border,
    borderRadius: BorderRadius.md,
  },
  input: {
    flex: 1,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.md,
    fontSize: Typography.fontSize.md,
    color: Colors.light.text,
  },
  inputError: {
    borderColor: Colors.light.error,
  },
  iconContainer: {
    paddingHorizontal: Spacing.md,
  },
  errorText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.error,
  },
  helperText: {
    fontSize: Typography.fontSize.xs,
    color: Colors.light.textTertiary,
  },
});