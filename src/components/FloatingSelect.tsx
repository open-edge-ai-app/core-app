import React, { ReactNode, useMemo } from 'react';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import {
  Pressable,
  StyleProp,
  StyleSheet,
  TextStyle,
  View,
  ViewStyle,
} from 'react-native';

import AppIcon from './AppIcon';
import { ScaledText as Text } from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors, typography } from '../theme/tokens';

export type FloatingSelectOption<Value extends string> = {
  description?: string;
  dividerBefore?: boolean;
  disabled?: boolean;
  icon?: IconDefinition;
  label: string;
  trailingIcon?: IconDefinition;
  trailingIconColor?: string;
  value: Value;
};

type FloatingSelectProps<Value extends string> = {
  accessibilityLabel: string;
  children?: ReactNode;
  disabled?: boolean;
  expanded: boolean;
  menuAlignment?: 'left' | 'right' | 'stretch';
  menuStyle?: StyleProp<ViewStyle>;
  onExpandedChange: (expanded: boolean) => void;
  onValueChange: (value: Value) => void;
  optionIconSize?: number;
  options: FloatingSelectOption<Value>[];
  placeholder?: string;
  placeholderIcon?: IconDefinition;
  selectedValue?: Value | null;
  showTriggerIcon?: boolean;
  triggerIconSize?: number;
  triggerStyle?: StyleProp<ViewStyle>;
  valueTextStyle?: StyleProp<TextStyle>;
  variant?: 'full' | 'compact' | 'header';
};

const OPTION_MENU_ELEVATION = 96;
const OPTION_MENU_Z_INDEX = 96;

function FloatingSelect<Value extends string>({
  accessibilityLabel,
  children,
  disabled = false,
  expanded,
  menuAlignment = 'stretch',
  menuStyle,
  onExpandedChange,
  onValueChange,
  optionIconSize = 14,
  options,
  placeholder,
  placeholderIcon,
  selectedValue,
  showTriggerIcon = true,
  triggerIconSize = 16,
  triggerStyle,
  valueTextStyle,
  variant = 'full',
}: FloatingSelectProps<Value>) {
  const selectedOption = useMemo(
    () => options.find(option => option.value === selectedValue) ?? null,
    [options, selectedValue],
  );
  const isCompact = variant === 'compact';
  const isHeader = variant === 'header';
  const isActiveCompact = isCompact && expanded;
  const isActiveHeader = isHeader && expanded;
  const displayIcon = showTriggerIcon
    ? selectedOption?.icon ?? placeholderIcon
    : undefined;
  const displayLabel = selectedOption?.label ?? placeholder;
  const triggerIconColor = isActiveCompact
    ? colors.primaryForeground
    : selectedOption
    ? colors.foreground
    : colors.mutedForeground;
  const chevronColor = isActiveCompact
    ? colors.primaryForeground
    : colors.mutedForeground;

  const handleSelect = (option: FloatingSelectOption<Value>) => {
    if (option.disabled) {
      return;
    }

    onValueChange(option.value);
    onExpandedChange(false);
  };

  return (
    <View style={[styles.host, expanded && styles.hostRaised]}>
      <View style={[styles.row, children ? styles.rowWithChildren : null]}>
        <Pressable
          accessibilityLabel={accessibilityLabel}
          accessibilityRole="button"
          accessibilityState={{ disabled, expanded }}
          disabled={disabled}
          onPress={() => onExpandedChange(!expanded)}
          style={({ pressed }) => [
            styles.trigger,
            isCompact
              ? styles.compactTrigger
              : isHeader
              ? styles.headerTrigger
              : styles.fullTrigger,
            isActiveCompact && styles.compactTriggerActive,
            isActiveHeader && styles.headerTriggerActive,
            disabled && styles.disabled,
            pressed && styles.pressed,
            triggerStyle,
          ]}
        >
          <View
            style={[
              styles.triggerValue,
              isCompact
                ? styles.compactTriggerValue
                : isHeader
                ? styles.headerTriggerValue
                : styles.fullTriggerValue,
            ]}
          >
            {displayIcon ? (
              <AppIcon
                color={triggerIconColor}
                icon={displayIcon}
                size={triggerIconSize}
              />
            ) : null}
            {!isCompact && displayLabel ? (
              <Text
                numberOfLines={1}
                style={[
                  styles.triggerText,
                  !displayIcon && styles.triggerTextNoIcon,
                  isHeader && styles.headerTriggerText,
                  !selectedOption && styles.placeholderText,
                  valueTextStyle,
                ]}
              >
                {displayLabel}
              </Text>
            ) : null}
          </View>
          <AppIcon
            color={chevronColor}
            icon={appIcons.chevronDown}
            size={isCompact || isHeader ? 9 : 12}
          />
        </Pressable>
        {children}
      </View>

      {expanded && options.length > 0 ? (
        <View
          style={[
            styles.menu,
            menuAlignment === 'stretch'
              ? styles.menuStretch
              : menuAlignment === 'right'
              ? styles.menuRight
              : styles.menuLeft,
            isCompact
              ? styles.compactMenu
              : isHeader
              ? styles.headerMenu
              : styles.fullMenu,
            menuStyle,
          ]}
        >
          {options.map(option => {
            const isSelected = option.value === selectedValue;

            return (
              <Pressable
                accessibilityLabel={`${option.label} 선택`}
                accessibilityRole="button"
                accessibilityState={{
                  disabled: option.disabled,
                  selected: isSelected,
                }}
                disabled={option.disabled}
                key={option.value}
                onPress={() => handleSelect(option)}
                style={({ pressed }) => [
                  styles.optionRow,
                  option.dividerBefore && styles.optionRowDivider,
                  isSelected && styles.optionRowActive,
                  option.disabled && styles.optionRowDisabled,
                  pressed && styles.pressed,
                ]}
              >
                <View style={styles.optionValue}>
                  {option.icon ? (
                    <AppIcon
                      color={isSelected ? colors.primary : colors.foreground}
                      icon={option.icon}
                      size={optionIconSize}
                    />
                  ) : null}
                  <View style={styles.optionCopy}>
                    <Text numberOfLines={1} style={styles.optionLabel}>
                      {option.label}
                    </Text>
                    {option.description ? (
                      <Text numberOfLines={1} style={styles.optionDescription}>
                        {option.description}
                      </Text>
                    ) : null}
                  </View>
                </View>
                {isSelected ? (
                  <AppIcon
                    color={colors.primary}
                    icon={appIcons.selected}
                    size={15}
                  />
                ) : option.trailingIcon ? (
                  <AppIcon
                    color={option.trailingIconColor ?? colors.mutedForeground}
                    icon={option.trailingIcon}
                    size={15}
                  />
                ) : null}
              </Pressable>
            );
          })}
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  host: {
    position: 'relative',
    zIndex: 1,
  },
  hostRaised: {
    elevation: OPTION_MENU_ELEVATION,
    zIndex: OPTION_MENU_Z_INDEX,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
  },
  rowWithChildren: {
    gap: 10,
  },
  trigger: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
  },
  fullTrigger: {
    justifyContent: 'space-between',
    minHeight: 44,
    paddingHorizontal: 14,
    width: '100%',
  },
  headerTrigger: {
    borderRadius: 18,
    justifyContent: 'space-between',
    maxWidth: 106,
    minHeight: 32,
    paddingHorizontal: 11,
  },
  headerTriggerActive: {
    backgroundColor: colors.card,
  },
  compactTrigger: {
    gap: 6,
    height: 46,
    justifyContent: 'center',
    width: 58,
  },
  compactTriggerActive: {
    backgroundColor: colors.foreground,
    borderColor: colors.foreground,
  },
  disabled: {
    opacity: 0.58,
  },
  pressed: {
    opacity: 0.58,
  },
  triggerValue: {
    alignItems: 'center',
    flexDirection: 'row',
    minWidth: 0,
  },
  fullTriggerValue: {
    flex: 1,
    paddingRight: 12,
  },
  headerTriggerValue: {
    flex: 1,
    paddingRight: 5,
  },
  compactTriggerValue: {
    flexShrink: 0,
  },
  triggerText: {
    ...typography.label,
    color: colors.foreground,
    flex: 1,
    fontSize: 15,
    fontWeight: '700',
    marginLeft: 10,
  },
  headerTriggerText: {
    ...typography.caption,
    fontSize: 13,
  },
  triggerTextNoIcon: {
    marginLeft: 0,
  },
  placeholderText: {
    color: colors.mutedForeground,
  },
  menu: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    elevation: OPTION_MENU_ELEVATION,
    overflow: 'hidden',
    position: 'absolute',
    shadowColor: '#000000',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 22,
    zIndex: OPTION_MENU_Z_INDEX,
  },
  menuStretch: {
    left: 0,
    right: 0,
  },
  menuLeft: {
    left: 0,
  },
  menuRight: {
    right: 0,
  },
  fullMenu: {
    top: 46,
  },
  compactMenu: {
    top: 56,
  },
  headerMenu: {
    top: 38,
  },
  optionRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 42,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  optionRowActive: {
    backgroundColor: colors.accent,
  },
  optionRowDisabled: {
    opacity: 0.54,
  },
  optionRowDivider: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 6,
  },
  optionValue: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    minWidth: 0,
    paddingRight: 10,
  },
  optionCopy: {
    flex: 1,
    marginLeft: 10,
    minWidth: 0,
  },
  optionLabel: {
    ...typography.label,
    color: colors.foreground,
    flex: 1,
    fontSize: 14,
    fontWeight: '700',
  },
  optionDescription: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '500',
    marginTop: 3,
  },
});

export default FloatingSelect;
