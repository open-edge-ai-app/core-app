import React, { ReactNode } from 'react';
import {
  Pressable,
  PressableProps,
  StyleProp,
  StyleSheet,
  TextStyle,
  View,
  ViewStyle,
} from 'react-native';

import { ScaledText as Text } from '../../theme/display';
import { colors, radii, shadows, typography } from '../../theme/tokens';

type ButtonVariant = 'default' | 'secondary' | 'outline' | 'ghost';
type ButtonSize = 'sm' | 'md' | 'icon';

type ButtonProps = Omit<PressableProps, 'children' | 'style'> & {
  children?: ReactNode;
  label?: string;
  size?: ButtonSize;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
  variant?: ButtonVariant;
};

const buttonVariantStyles: Record<ButtonVariant, ViewStyle> = {
  default: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  secondary: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  outline: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  ghost: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
};

const buttonTextVariantStyles: Record<ButtonVariant, TextStyle> = {
  default: {
    color: colors.primaryForeground,
  },
  secondary: {
    color: colors.secondaryForeground,
  },
  outline: {
    color: colors.primary,
  },
  ghost: {
    color: colors.primary,
  },
};

const buttonSizeStyles: Record<ButtonSize, ViewStyle> = {
  sm: {
    minHeight: 30,
    paddingHorizontal: 8,
  },
  md: {
    minHeight: 40,
    paddingHorizontal: 14,
  },
  icon: {
    height: 34,
    paddingHorizontal: 0,
    width: 34,
  },
};

const buttonTextSizeStyles: Record<ButtonSize, TextStyle> = {
  sm: {
    fontSize: 15,
  },
  md: {
    fontSize: 16,
  },
  icon: {
    fontSize: 17,
  },
};

export function Button({
  children,
  disabled,
  label,
  size = 'md',
  style,
  textStyle,
  variant = 'default',
  ...pressableProps
}: ButtonProps) {
  const textContent = label ?? (typeof children === 'string' ? children : null);

  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      style={({ pressed }) => [
        styles.button,
        buttonVariantStyles[variant],
        buttonSizeStyles[size],
        pressed && !disabled && styles.pressed,
        disabled && styles.disabled,
        style,
      ]}
      {...pressableProps}
    >
      {textContent ? (
        <Text
          style={[
            styles.buttonText,
            buttonTextVariantStyles[variant],
            buttonTextSizeStyles[size],
            disabled && styles.disabledText,
            textStyle,
          ]}
        >
          {textContent}
        </Text>
      ) : (
        children
      )}
    </Pressable>
  );
}

type CardProps = {
  children: ReactNode;
  padded?: boolean;
  style?: StyleProp<ViewStyle>;
};

export function Card({ children, padded = true, style }: CardProps) {
  return (
    <View style={[styles.card, padded && styles.cardPadded, style]}>
      {children}
    </View>
  );
}

type BadgeVariant = 'default' | 'secondary' | 'outline' | 'success';

type BadgeProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
  variant?: BadgeVariant;
};

const badgeVariantStyles: Record<BadgeVariant, ViewStyle> = {
  default: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  secondary: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  outline: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  success: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
};

const badgeTextVariantStyles: Record<BadgeVariant, TextStyle> = {
  default: {
    color: colors.foreground,
  },
  secondary: {
    color: colors.mutedForeground,
  },
  outline: {
    color: colors.foreground,
  },
  success: {
    color: colors.success,
  },
};

export function Badge({
  children,
  style,
  textStyle,
  variant = 'secondary',
}: BadgeProps) {
  return (
    <View style={[styles.badge, badgeVariantStyles[variant], style]}>
      <Text
        style={[styles.badgeText, badgeTextVariantStyles[variant], textStyle]}
      >
        {children}
      </Text>
    </View>
  );
}

export function Separator({ style }: { style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.separator, style]} />;
}

type TabsProps<T extends string> = {
  items: Array<{ key: T; label: string }>;
  onValueChange: (value: T) => void;
  value: T;
};

export function Tabs<T extends string>({
  items,
  onValueChange,
  value,
}: TabsProps<T>) {
  return (
    <View style={styles.tabs}>
      {items.map(item => {
        const selected = item.key === value;

        return (
          <Pressable
            accessibilityRole="tab"
            accessibilityState={{ selected }}
            key={item.key}
            onPress={() => onValueChange(item.key)}
            style={({ pressed }) => [
              styles.tab,
              selected && styles.tabSelected,
              pressed && styles.pressed,
            ]}
          >
            <Text style={[styles.tabText, selected && styles.tabTextSelected]}>
              {item.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    borderRadius: 999,
    borderWidth: 0,
    flexDirection: 'row',
    justifyContent: 'center',
  },
  buttonText: {
    ...typography.label,
  },
  pressed: {
    opacity: 0.55,
  },
  disabled: {
    opacity: 0.42,
  },
  disabledText: {
    opacity: 0.8,
  },
  card: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: radii.lg,
    borderWidth: StyleSheet.hairlineWidth,
    ...shadows.sm,
  },
  cardPadded: {
    padding: 14,
  },
  badge: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderRadius: 0,
    borderWidth: 0,
    minHeight: 18,
    paddingHorizontal: 0,
    justifyContent: 'center',
  },
  badgeText: {
    ...typography.caption,
  },
  separator: {
    backgroundColor: colors.border,
    height: StyleSheet.hairlineWidth,
    width: '100%',
  },
  tabs: {
    backgroundColor: 'transparent',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
  },
  tab: {
    alignItems: 'center',
    borderBottomColor: 'transparent',
    borderBottomWidth: 2,
    borderRadius: 0,
    flex: 1,
    minHeight: 32,
    justifyContent: 'center',
    paddingHorizontal: 10,
  },
  tabSelected: {
    borderBottomColor: colors.foreground,
  },
  tabText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 12,
  },
  tabTextSelected: {
    color: colors.foreground,
  },
});
