export const colors = {
  background: '#FBFCFF',
  foreground: '#151922',
  card: '#FFFFFF',
  cardForeground: '#151922',
  muted: '#F5F7FA',
  mutedForeground: '#68707D',
  border: '#E3E7EE',
  input: '#E7EBF1',
  primary: '#007AFF',
  primaryForeground: '#FFFFFF',
  secondary: '#F2F4F7',
  secondaryForeground: '#151922',
  accent: '#EEF6FF',
  accentForeground: '#0068D9',
  ring: '#A5ACB7',
  success: '#34C759',
  warning: '#FF9500',
  destructive: '#FF3B30',
};

export const radii = {
  sm: 10,
  md: 14,
  lg: 18,
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
