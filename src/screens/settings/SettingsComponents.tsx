import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import React, {
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  useWindowDimensions,
  View,
} from 'react-native';

import AppIcon from '../../components/AppIcon';
import { LocaleCode, SupportedLocale } from '../../i18n';
import {
  ScaledText as Text,
  ScaledTextInput as TextInput,
} from '../../theme/display';
import { appIcons } from '../../theme/icons';
import { colors } from '../../theme/tokens';
import {
  languageMenuBottomGap,
  languageMenuGap,
  languageMenuMargin,
  languageMenuMaxHeight,
  languageMenuMinHeight,
  languageSearchInputHeight,
} from './settingsConfig';
import { styles } from './settingsStyles';

type SettingsNavigationRowProps = {
  caption?: string;
  icon: IconDefinition;
  iconColor?: string;
  isLast?: boolean;
  onPress: () => void;
  title: string;
  value?: string;
};

export function SettingsNavigationRow({
  caption,
  icon,
  iconColor = colors.foreground,
  isLast = false,
  onPress,
  title,
  value,
}: SettingsNavigationRowProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.navigationRow,
        !isLast && styles.navigationRowDivider,
        pressed && styles.rowPressed,
      ]}
    >
      <View style={styles.navigationIconSlot}>
        <AppIcon color={iconColor} icon={icon} size={18} />
      </View>
      <View style={styles.navigationCopy}>
        <Text style={styles.navigationTitle}>{title}</Text>
        {caption ? (
          <Text style={styles.navigationCaption}>{caption}</Text>
        ) : null}
      </View>
      <View style={styles.navigationMeta}>
        {value ? (
          <Text numberOfLines={1} style={styles.navigationValue}>
            {value}
          </Text>
        ) : null}
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.openPrompt}
          size={14}
        />
      </View>
    </Pressable>
  );
}
type SearchableLanguageSelectProps = {
  expanded: boolean;
  locale: LocaleCode;
  noResultsLabel: string;
  onExpandedChange: (expanded: boolean) => void;
  onQueryChange: (query: string) => void;
  onSelect: (locale: LocaleCode) => void;
  options: readonly SupportedLocale[];
  query: string;
  searchPlaceholder: string;
  selectedLocale: SupportedLocale;
};

export function SearchableLanguageSelect({
  expanded,
  locale,
  noResultsLabel,
  onExpandedChange,
  onQueryChange,
  onSelect,
  options,
  query,
  searchPlaceholder,
  selectedLocale,
}: SearchableLanguageSelectProps) {
  const triggerRef = useRef<View>(null);
  const overlayRef = useRef<View>(null);
  const windowSize = useWindowDimensions();
  const [overlayFrame, setOverlayFrame] = useState<{
    height: number;
    width: number;
    x: number;
    y: number;
  } | null>(null);
  const [triggerFrame, setTriggerFrame] = useState<{
    height: number;
    width: number;
    x: number;
    y: number;
  } | null>(null);
  const measureOverlay = useCallback(() => {
    overlayRef.current?.measureInWindow((x, y, width, height) => {
      setOverlayFrame({ height, width, x, y });
    });
  }, []);
  const measureTrigger = useCallback(() => {
    triggerRef.current?.measureInWindow((x, y, width, height) => {
      setTriggerFrame({ height, width, x, y });
    });
  }, []);
  const handleToggle = useCallback(() => {
    if (expanded) {
      onExpandedChange(false);
      return;
    }

    measureTrigger();
    onExpandedChange(true);
  }, [expanded, measureTrigger, onExpandedChange]);

  useEffect(() => {
    if (!expanded) {
      return;
    }

    const frame = requestAnimationFrame(() => {
      measureOverlay();
      measureTrigger();
    });
    return () => cancelAnimationFrame(frame);
  }, [
    expanded,
    measureOverlay,
    measureTrigger,
    windowSize.height,
    windowSize.width,
  ]);

  const menuLayout = useMemo(() => {
    if (!triggerFrame || !overlayFrame) {
      return null;
    }

    const viewportTop = overlayFrame.y + languageMenuBottomGap;
    const viewportBottom =
      overlayFrame.y + overlayFrame.height - languageMenuBottomGap;
    const viewportHeight = Math.max(viewportBottom - viewportTop, 0);
    const menuWidth = Math.min(
      triggerFrame.width,
      overlayFrame.width - languageMenuMargin * 2,
    );
    const left = Math.min(
      Math.max(triggerFrame.x - overlayFrame.x, languageMenuMargin),
      overlayFrame.width - menuWidth - languageMenuMargin,
    );
    const spaceBelow = viewportBottom - triggerFrame.y - triggerFrame.height;
    const spaceAbove = triggerFrame.y - viewportTop;
    const openUp = spaceBelow < languageMenuMinHeight && spaceAbove > spaceBelow;
    const availableSpace = Math.max(openUp ? spaceAbove : spaceBelow, 0);
    const height = Math.min(
      viewportHeight,
      Math.max(
        96,
        Math.min(languageMenuMaxHeight, availableSpace - languageMenuGap),
      ),
    );
    const topInWindow = Math.min(
      Math.max(
        openUp
          ? triggerFrame.y - height - languageMenuGap
          : triggerFrame.y + triggerFrame.height + languageMenuGap,
        viewportTop,
      ),
      viewportBottom - height,
    );
    const top = Math.max(languageMenuBottomGap, topInWindow - overlayFrame.y);
    const optionListHeight = Math.max(48, height - languageSearchInputHeight);

    return {
      height,
      left,
      optionListHeight,
      top,
      width: menuWidth,
    };
  }, [overlayFrame, triggerFrame]);

  const handleOverlayLayout = useCallback(() => {
    requestAnimationFrame(measureOverlay);
  }, [measureOverlay]);

  return (
    <View style={styles.languageSelect}>
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ expanded }}
        onPress={handleToggle}
        ref={triggerRef}
        style={({ pressed }) => [
          styles.languageSelectTrigger,
          expanded && styles.languageSelectTriggerActive,
          pressed && styles.rowPressed,
        ]}
      >
        <View style={styles.languageSelectValue}>
          <Text numberOfLines={1} style={styles.languageSelectNative}>
            {selectedLocale.nativeName}
          </Text>
          <Text numberOfLines={1} style={styles.languageSelectEnglish}>
            {selectedLocale.englishName}
          </Text>
        </View>
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.chevronDown}
          size={11}
        />
      </Pressable>

      <Modal
        animationType="none"
        onRequestClose={() => onExpandedChange(false)}
        transparent
        visible={expanded}
      >
        <View
          onLayout={handleOverlayLayout}
          ref={overlayRef}
          style={styles.languageOverlay}
        >
          <Pressable
            accessibilityLabel="Close language menu"
            accessibilityRole="button"
            onPress={() => onExpandedChange(false)}
            style={StyleSheet.absoluteFill}
          />
          {menuLayout ? (
            <View
              style={[
                styles.languageSelectMenu,
                {
                  height: menuLayout.height,
                  left: menuLayout.left,
                  top: menuLayout.top,
                  width: menuLayout.width,
                },
              ]}
            >
              <TextInput
                accessibilityLabel={searchPlaceholder}
                autoCapitalize="none"
                onChangeText={onQueryChange}
                placeholder={searchPlaceholder}
                placeholderTextColor={colors.mutedForeground}
                style={styles.languageSearchInput}
                value={query}
              />
              <ScrollView
                keyboardShouldPersistTaps="handled"
                nestedScrollEnabled
                style={{ height: menuLayout.optionListHeight }}
              >
                {options.length > 0 ? (
                  options.map(option => {
                    const isSelected = option.code === locale;

                    return (
                      <Pressable
                        accessibilityLabel={`${option.nativeName} ${option.englishName}`}
                        accessibilityRole="button"
                        accessibilityState={{ selected: isSelected }}
                        key={option.code}
                        onPress={() => onSelect(option.code)}
                        style={({ pressed }) => [
                          styles.languageOption,
                          isSelected && styles.languageOptionActive,
                          pressed && styles.rowPressed,
                        ]}
                      >
                        <View style={styles.languageOptionCopy}>
                          <Text
                            numberOfLines={1}
                            style={styles.languageOptionNative}
                          >
                            {option.nativeName}
                          </Text>
                          <Text
                            numberOfLines={1}
                            style={styles.languageOptionEnglish}
                          >
                            {option.englishName}
                          </Text>
                        </View>
                        {isSelected ? (
                          <AppIcon
                            color={colors.primary}
                            icon={appIcons.selected}
                            size={16}
                          />
                        ) : null}
                      </Pressable>
                    );
                  })
                ) : (
                  <Text style={styles.languageEmptyText}>{noResultsLabel}</Text>
                )}
              </ScrollView>
            </View>
          ) : null}
        </View>
      </Modal>
    </View>
  );
}

type SettingsSectionProps = {
  children: ReactNode;
  title: string;
};

export function SettingsSection({ children, title }: SettingsSectionProps) {
  return (
    <View style={styles.settingsSection}>
      <Text style={styles.settingsSectionTitle}>{title}</Text>
      <View style={styles.settingsCard}>{children}</View>
    </View>
  );
}

type StatusRowProps = {
  label: string;
  value: string;
};

export function StatusRow({ label, value }: StatusRowProps) {
  return (
    <View style={styles.statusRow}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

type InfoLinkRowProps = {
  label: string;
  onPress: () => void;
  value: string;
};

export function InfoLinkRow({ label, onPress, value }: InfoLinkRowProps) {
  return (
    <Pressable
      accessibilityRole="link"
      onPress={onPress}
      style={({ pressed }) => [
        styles.infoLinkRow,
        pressed && styles.rowPressed,
      ]}
    >
      <Text style={styles.rowLabel}>{label}</Text>
      <View style={styles.infoLinkMeta}>
        <Text numberOfLines={1} style={styles.rowValue}>
          {value}
        </Text>
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.openPrompt}
          size={13}
        />
      </View>
    </Pressable>
  );
}

type SettingsToggleProps = {
  disabled?: boolean;
  onValueChange: (value: boolean) => void;
  value: boolean;
};

export function SettingsToggle({
  disabled = false,
  onValueChange,
  value,
}: SettingsToggleProps) {
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityState={{ checked: value, disabled }}
      disabled={disabled}
      hitSlop={8}
      onPress={() => onValueChange(!value)}
      style={({ pressed }) => [
        styles.settingsToggle,
        value && styles.settingsToggleOn,
        disabled && styles.settingsToggleDisabled,
        pressed && styles.settingsTogglePressed,
      ]}
    >
      <View
        style={[
          styles.settingsToggleThumb,
          value && styles.settingsToggleThumbOn,
        ]}
      />
    </Pressable>
  );
}
