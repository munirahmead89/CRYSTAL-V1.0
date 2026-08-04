import type { TextInputProps } from 'react-native';
import { Controller, type Control, type FieldValues, type Path } from 'react-hook-form';

import { Input } from '@/components/Input';

type FormInputProps<T extends FieldValues> = {
  name: Path<T>;
  control: Control<T>;
  label?: string;
  rules?: object;
  helperText?: string;
} & Omit<TextInputProps, 'style'>;

export function FormInput<T extends FieldValues>({
  name,
  control,
  label,
  rules,
  helperText,
  ...inputProps
}: FormInputProps<T>) {
  return (
    <Controller
      control={control}
      name={name}
      rules={rules}
      render={({ field: { onChange, onBlur, value }, fieldState: { error } }) => (
        <Input
          label={label}
          error={error?.message}
          helperText={helperText}
          onBlur={onBlur}
          onChangeText={onChange}
          value={value}
          {...inputProps}
        />
      )}
    />
  );
}
