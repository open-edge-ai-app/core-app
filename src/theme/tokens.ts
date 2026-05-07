export const colors = {
  background: '#F7F7FA',
  foreground: '#1C1C1E',
  card: '#FFFFFF',
  cardForeground: '#1C1C1E',
  muted: '#F2F2F7',
  mutedForeground: '#6E6E73',
  border: '#D1D1D6',
  input: '#E5E5EA',
  primary: '#007AFF',
  primaryForeground: '#FFFFFF',
  secondary: '#E9E9EF',
  secondaryForeground: '#1C1C1E',
  accent: '#EAF3FF',
  accentForeground: '#0057B8',
  ring: '#8E8E93',
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
    elevation: 2,
    shadowColor: '#000000',
    shadowOffset: { height: 8, width: 0 },
    shadowOpacity: 0.06,
    shadowRadius: 18,
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
    fontWeight: '500' as const,
    includeFontPadding: false,
  },
  label: {
    fontSize: 15,
    fontWeight: '600' as const,
    includeFontPadding: false,
  },
  title: {
    fontSize: 32,
    fontWeight: '700' as const,
    includeFontPadding: false,
    lineHeight: 38,
  },
};
