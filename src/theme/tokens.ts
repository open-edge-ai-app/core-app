const defaultColors = {
  background: '#FFFFFF',
  foreground: '#000000',
  card: '#FFFFFF',
  cardForeground: '#000000',
  muted: '#F5F5F5',
  mutedForeground: '#666666',
  border: '#E5E5E5',
  input: '#EAEAEA',
  primary: '#000000',
  primaryForeground: '#FFFFFF',
  secondary: '#F5F5F5',
  secondaryForeground: '#000000',
  accent: '#F2F2F2',
  accentForeground: '#000000',
  ring: '#A3A3A3',
  success: '#000000',
  warning: '#000000',
  destructive: '#000000',
};

export const colors = defaultColors;

export const radii = {
  sm: 8,
  md: 10,
  lg: 14,
};

export const shadows = {
  sm: {
    elevation: 1,
    shadowColor: '#000000',
    shadowOffset: { height: 1, width: 0 },
    shadowOpacity: 0.04,
    shadowRadius: 2,
  },
  md: {
    elevation: 10,
    shadowColor: '#000000',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.11,
    shadowRadius: 30,
  },
};

export const typography = {
  caption: {
    fontSize: 12,
    fontWeight: '600' as const,
    includeFontPadding: false,
  },
  body: {
    fontSize: 16,
    fontWeight: '400' as const,
    includeFontPadding: false,
  },
  label: {
    fontSize: 15,
    fontWeight: '600' as const,
    includeFontPadding: false,
  },
  title: {
    fontSize: 32,
    fontWeight: '800' as const,
    includeFontPadding: false,
    lineHeight: 38,
  },
};
