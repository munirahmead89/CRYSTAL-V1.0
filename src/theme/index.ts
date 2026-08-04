export const Colors = {
  light: {
    primary: '#00A884',
    primaryLight: '#00A88422',
    primaryDark: '#008069',
    secondary: '#53BDEB',
    success: '#25D366',
    warning: '#F7B928',
    error: '#EA4335',
    background: '#000000',
    surface: '#111B21',
    surfaceVariant: '#1F2C33',
    onBackground: '#FFFFFF',
    onSurface: '#E9EDEF',
    onSurfaceVariant: '#8696A0',
    border: '#222D34',
    borderLight: '#1F2C33',
    text: '#FFFFFF',
    textSecondary: '#8696A0',
    textTertiary: '#667781',
    inverse: '#000000',
    shadow: '#000000',
    overlay: 'rgba(0, 0, 0, 0.7)',
    chatBubbleOutgoing: '#005C4B',
    chatBubbleIncoming: '#1F2C33',
    chatTextOutgoing: '#E9EDEF',
    chatTextIncoming: '#E9EDEF',
    onlineIndicator: '#25D366',
    typingIndicator: '#8696A0',
  },
  dark: {
    primary: '#00A884',
    primaryLight: '#00A88422',
    primaryDark: '#008069',
    secondary: '#53BDEB',
    success: '#25D366',
    warning: '#F7B928',
    error: '#EA4335',
    background: '#000000',
    surface: '#111B21',
    surfaceVariant: '#1F2C33',
    onBackground: '#FFFFFF',
    onSurface: '#E9EDEF',
    onSurfaceVariant: '#8696A0',
    border: '#222D34',
    borderLight: '#1F2C33',
    text: '#FFFFFF',
    textSecondary: '#8696A0',
    textTertiary: '#667781',
    inverse: '#000000',
    shadow: '#000000',
    overlay: 'rgba(0, 0, 0, 0.7)',
    chatBubbleOutgoing: '#005C4B',
    chatBubbleIncoming: '#1F2C33',
    chatTextOutgoing: '#E9EDEF',
    chatTextIncoming: '#E9EDEF',
    onlineIndicator: '#25D366',
    typingIndicator: '#8696A0',
  },
};

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const BorderRadius = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  round: 9999,
};

export const Typography = {
  fontFamily: {
    regular: 'System',
    medium: 'System',
    bold: 'System',
  },
  fontSize: {
    xs: 12,
    sm: 14,
    md: 16,
    lg: 18,
    xl: 20,
    xxl: 24,
    xxxl: 32,
  },
  lineHeight: {
    xs: 16,
    sm: 20,
    md: 24,
    lg: 28,
    xl: 32,
    xxl: 36,
  },
  fontWeight: {
    regular: '400' as const,
    medium: '500' as const,
    semibold: '600' as const,
    bold: '700' as const,
  },
};

export const Shadows = {
  light: {
    sm: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.05,
      shadowRadius: 2,
      elevation: 1,
    },
    md: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
      elevation: 3,
    },
    lg: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.15,
      shadowRadius: 8,
      elevation: 5,
    },
  },
  dark: {
    sm: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.2,
      shadowRadius: 2,
      elevation: 1,
    },
    md: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.3,
      shadowRadius: 4,
      elevation: 3,
    },
    lg: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.4,
      shadowRadius: 8,
      elevation: 5,
    },
  },
};

export const Breakpoints = {
  sm: 640,
  md: 768,
  lg: 1024,
  xl: 1280,
};

export const ZIndex = {
  base: 0,
  dropdown: 100,
  modal: 200,
  tooltip: 300,
  toast: 400,
};

export const Animation = {
  duration: {
    fast: 150,
    normal: 250,
    slow: 350,
  },
  easing: {
    easeInOut: 'cubic-bezier(0.4, 0, 0.2, 1)',
    easeOut: 'cubic-bezier(0, 0, 0.2, 1)',
    easeIn: 'cubic-bezier(0.4, 0, 1, 1)',
  },
};

export const Theme = {
  Colors,
  Spacing,
  BorderRadius,
  Typography,
  Shadows,
  Breakpoints,
  ZIndex,
  Animation,
};

export type ThemeColors = typeof Colors.light;
export type ThemeSpacing = typeof Spacing;
export type ThemeBorderRadius = typeof BorderRadius;
export type ThemeTypography = typeof Typography;
export type ThemeShadows = typeof Shadows.light;