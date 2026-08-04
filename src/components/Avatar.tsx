import type { ViewStyle, ImageSourcePropType } from 'react-native';
import { View, Text, Image, StyleSheet } from 'react-native';
import { Colors, BorderRadius, Typography } from '@/theme';
import { getInitials, getColorForString } from '@/utils/helpers';

type AvatarSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl' | 'xxl';

const sizeMap: Record<AvatarSize, number> = {
  xs: 24,
  sm: 32,
  md: 40,
  lg: 48,
  xl: 64,
  xxl: 80,
};

const fontSizeMap: Record<AvatarSize, number> = {
  xs: 10,
  sm: 12,
  md: 14,
  lg: 18,
  xl: 24,
  xxl: 30,
};

interface AvatarProps {
  source?: ImageSourcePropType;
  name?: string;
  size?: AvatarSize;
  style?: ViewStyle;
  showBorder?: boolean;
  borderColor?: string;
  testID?: string;
}

export function Avatar({
  source,
  name,
  size = 'md',
  style,
  showBorder = false,
  borderColor,
  testID,
}: AvatarProps) {
  const dimension = sizeMap[size];
  const fontSize = fontSizeMap[size];
  const bgColor = name ? getColorForString(name) : Colors.light.primary;

  return (
    <View
      style={[
        styles.container,
        {
          width: dimension,
          height: dimension,
          borderRadius: BorderRadius.round,
          backgroundColor: bgColor,
          borderWidth: showBorder ? 2 : 0,
          borderColor: borderColor || Colors.light.background,
        },
        style,
      ]}
      testID={testID}
    >
      {source ? (
        <Image
          source={source}
          style={[
            styles.image,
            { width: dimension, height: dimension, borderRadius: BorderRadius.round },
          ]}
        />
      ) : name ? (
        <Text
          style={[
            styles.initials,
            { fontSize, color: Colors.light.inverse, fontWeight: Typography.fontWeight.semibold as '600' },
          ]}
        >
          {getInitials(name)}
        </Text>
      ) : (
        <Text
          style={[
            styles.initials,
            { fontSize, color: Colors.light.inverse, fontWeight: Typography.fontWeight.semibold as '600' },
          ]}
        >
          ?
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  image: {
    borderRadius: BorderRadius.round,
  },
  initials: {
    fontWeight: '600',
  },
});