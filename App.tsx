import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  faBars,
  faBolt,
  faBrain,
  faCheck,
  faChevronDown,
  faCalendarDays,
  faFolderPlus,
  faGear,
  faGrip,
  faImages,
  faLayerGroup,
  faMagnifyingGlass,
  faPodcast,
  faTerminal,
  faWandMagicSparkles,
} from '@fortawesome/free-solid-svg-icons';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import {
  Animated,
  Easing,
  Image,
  Modal,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text as RNText,
  TextInput as RNTextInput,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

import AppIcon from './src/components/AppIcon';
import PastelBackground from './src/components/PastelBackground';
import ChatScreen from './src/screens/ChatScreen';
import Settings from './src/screens/Settings';
import {
  DisplaySettingsProvider,
  ScaledText as Text,
} from './src/theme/display';
import { colors, typography } from './src/theme/tokens';
import logoSource from './src/assets/logo.png';

const textDefaults = RNText as unknown as {
  defaultProps?: { allowFontScaling?: boolean; maxFontSizeMultiplier?: number };
};
const inputDefaults = RNTextInput as unknown as {
  defaultProps?: { allowFontScaling?: boolean; maxFontSizeMultiplier?: number };
};

textDefaults.defaultProps = {
  ...textDefaults.defaultProps,
  allowFontScaling: false,
  maxFontSizeMultiplier: 1,
};
inputDefaults.defaultProps = {
  ...inputDefaults.defaultProps,
  allowFontScaling: false,
  maxFontSizeMultiplier: 1,
};

type MenuRowProps = {
  icon?: IconDefinition;
  iconColor?: string;
  label: string;
  onPress?: () => void;
};

type MenuIconRow = {
  icon: IconDefinition;
  iconColor?: string;
  label: string;
};

type ModelOption = {
  action?: 'settings';
  detail: string;
  icon: IconDefinition;
  id: 'gemma-4' | 'gemma-lite' | 'gemma-deep' | 'auto' | 'manage';
  label: string;
};

const MODEL_MENU_GAP = 6;
const MODEL_MENU_TOP = 32 + MODEL_MENU_GAP;
const MODEL_MENU_WIDTH = 252;

const modelOptions: ModelOption[] = [
  {
    detail: '빠르고 균형 잡힌 성능',
    icon: faWandMagicSparkles,
    id: 'gemma-4',
    label: 'Gemma 4',
  },
  {
    detail: '가볍고 빠른 응답',
    icon: faBolt,
    id: 'gemma-lite',
    label: 'Gemma 4 Lite',
  },
  {
    detail: '복잡한 추론에 최적화',
    icon: faBrain,
    id: 'gemma-deep',
    label: 'Gemma 4 Deep',
  },
  {
    detail: '작업에 맞춰 자동 선택',
    icon: faLayerGroup,
    id: 'auto',
    label: 'Auto',
  },
  {
    action: 'settings',
    detail: '다운로드 및 상태 확인',
    icon: faGear,
    id: 'manage',
    label: '모델 관리',
  },
];

const mainMenuRows: MenuIconRow[] = [
  {
    icon: faImages,
    label: '이미지',
  },
  {
    icon: faPodcast,
    label: 'Pulse',
  },
  {
    icon: faTerminal,
    label: 'Codex',
  },
  {
    icon: faGrip,
    label: '앱',
  },
];

const projectRows: MenuIconRow[] = [
  {
    icon: faFolderPlus,
    label: '새 프로젝트',
  },
  {
    icon: faTerminal,
    label: 'Gatepex',
  },
  {
    icon: faCalendarDays,
    iconColor: '#F97316',
    label: 'Phison 미팅',
  },
];

const recentRows: { label: string }[] = [
  {
    label: '링크드인 소개 수정',
  },
];

function App() {
  const [sessionTitle, setSessionTitle] = useState('새 채팅');
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isModelMenuOpen, setIsModelMenuOpen] = useState(false);
  const [chatInstanceKey, setChatInstanceKey] = useState(0);
  const [activeScreen, setActiveScreen] = useState<'chat' | 'settings'>('chat');
  const [selectedModelId, setSelectedModelId] =
    useState<ModelOption['id']>('gemma-4');

  const selectedModel = useMemo(
    () =>
      modelOptions.find(model => model.id === selectedModelId) ??
      modelOptions[0],
    [selectedModelId],
  );

  const handleToggleModelMenu = () => {
    if (isModelMenuOpen) {
      setIsModelMenuOpen(false);
      return;
    }

    setIsMenuOpen(false);
    setIsModelMenuOpen(true);
  };

  const handleNewChat = () => {
    setActiveScreen('chat');
    setSessionTitle('새 채팅');
    setChatInstanceKey(current => current + 1);
    setIsMenuOpen(false);
  };

  const handleSelectSession = (title: string) => {
    setActiveScreen('chat');
    setSessionTitle(title);
    setIsMenuOpen(false);
  };

  const handleOpenSettings = () => {
    setActiveScreen('settings');
    setIsMenuOpen(false);
  };

  return (
    <DisplaySettingsProvider>
      <SafeAreaProvider>
        <StatusBar
          barStyle="dark-content"
          backgroundColor={colors.background}
        />
        <SafeAreaView style={styles.safeArea}>
          <PastelBackground />

          <View style={styles.header}>
            <View style={styles.headerSide}>
              <Pressable
                accessibilityLabel="메뉴 열기"
                accessibilityRole="button"
                onPress={() => {
                  setIsModelMenuOpen(false);
                  setIsMenuOpen(true);
                }}
                style={({ pressed }) => [
                  styles.menuButton,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <AppIcon color={colors.foreground} icon={faBars} size={22} />
              </Pressable>
            </View>

            <Text numberOfLines={1} style={styles.sessionTitle}>
              {activeScreen === 'settings' ? '설정' : sessionTitle}
            </Text>

            <View style={[styles.headerSide, styles.headerSideRight]}>
              <Pressable
                accessibilityLabel="모델 선택"
                accessibilityRole="button"
                onPress={handleToggleModelMenu}
                style={({ pressed }) => [
                  styles.modelSelector,
                  isModelMenuOpen && styles.modelSelectorActive,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <Text numberOfLines={1} style={styles.modelSelectorText}>
                  {selectedModel.label}
                </Text>
                <AppIcon
                  color={colors.mutedForeground}
                  icon={faChevronDown}
                  size={10}
                />
              </Pressable>
              {isModelMenuOpen ? (
                <View style={styles.modelMenu}>
                  {modelOptions.map(model => {
                    const isSelected = model.id === selectedModel.id;
                    const isManageAction = model.action === 'settings';

                    return (
                      <Pressable
                        accessibilityRole="button"
                        key={model.id}
                        onPress={() => {
                          if (isManageAction) {
                            setActiveScreen('settings');
                          } else {
                            setSelectedModelId(model.id);
                          }
                          setIsModelMenuOpen(false);
                        }}
                        style={({ pressed }) => [
                          styles.modelMenuRow,
                          isManageAction && styles.modelMenuManageRow,
                          isSelected && styles.modelMenuRowActive,
                          pressed && styles.menuRowPressed,
                        ]}
                      >
                        <View style={styles.modelMenuIcon}>
                          <AppIcon
                            color={
                              isSelected ? colors.primary : colors.foreground
                            }
                            icon={model.icon}
                            size={16}
                          />
                        </View>
                        <View style={styles.modelMenuCopy}>
                          <Text style={styles.modelMenuLabel}>
                            {model.label}
                          </Text>
                          <Text style={styles.modelMenuDetail}>
                            {model.detail}
                          </Text>
                        </View>
                        {isSelected ? (
                          <AppIcon
                            color={colors.primary}
                            icon={faCheck}
                            size={18}
                          />
                        ) : null}
                      </Pressable>
                    );
                  })}
                </View>
              ) : null}
            </View>
          </View>

          {isModelMenuOpen ? (
            <Pressable
              accessibilityLabel="모델 메뉴 닫기"
              onPress={() => setIsModelMenuOpen(false)}
              style={styles.modelMenuBackdrop}
            />
          ) : null}

          <View style={styles.content}>
            {activeScreen === 'chat' ? (
              <ChatScreen
                key={chatInstanceKey}
                onSessionTitleChange={setSessionTitle}
                selectedModelLabel={selectedModel.label}
              />
            ) : (
              <Settings />
            )}
          </View>

          <FullScreenMenu
            onClose={() => setIsMenuOpen(false)}
            onNewChat={handleNewChat}
            onOpenSettings={handleOpenSettings}
            onSelectSession={handleSelectSession}
            visible={isMenuOpen}
          />
        </SafeAreaView>
      </SafeAreaProvider>
    </DisplaySettingsProvider>
  );
}

function FullScreenMenu({
  onClose,
  onNewChat,
  onOpenSettings,
  onSelectSession,
  visible,
}: {
  onClose: () => void;
  onNewChat: () => void;
  onOpenSettings: () => void;
  onSelectSession: (title: string) => void;
  visible: boolean;
}) {
  const { width } = useWindowDimensions();
  const slideX = useRef(new Animated.Value(-width)).current;
  const [isRendered, setIsRendered] = useState(visible);

  useEffect(() => {
    if (visible) {
      setIsRendered(true);
      slideX.setValue(-width);
      Animated.timing(slideX, {
        duration: 260,
        easing: Easing.out(Easing.cubic),
        toValue: 0,
        useNativeDriver: false,
      }).start();
      return;
    }

    if (!isRendered) {
      return;
    }

    Animated.timing(slideX, {
      duration: 210,
      easing: Easing.in(Easing.cubic),
      toValue: -width,
      useNativeDriver: false,
    }).start(({ finished }) => {
      if (finished) {
        setIsRendered(false);
      }
    });
  }, [isRendered, slideX, visible, width]);

  if (!isRendered) {
    return null;
  }

  return (
    <Modal
      animationType="none"
      onRequestClose={onClose}
      presentationStyle="overFullScreen"
      transparent
      visible={isRendered}
    >
      <Animated.View
        style={[
          styles.menuSlidePanel,
          {
            transform: [{ translateX: slideX }],
          },
        ]}
      >
        <SafeAreaView style={styles.menuSafeArea}>
          <View style={styles.menuBackground} />

          <View style={styles.menuHeader}>
            <Image
              accessibilityIgnoresInvertColors
              resizeMode="contain"
              source={logoSource}
              style={styles.menuHeaderLogo}
            />
            <View style={styles.menuHeaderActions}>
              <Pressable
                accessibilityLabel="검색"
                accessibilityRole="button"
                style={({ pressed }) => [
                  styles.menuSearchButton,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <AppIcon
                  color={colors.foreground}
                  icon={faMagnifyingGlass}
                  size={30}
                />
              </Pressable>
              <Pressable
                accessibilityLabel="프로필"
                accessibilityRole="button"
                onPress={onClose}
                style={({ pressed }) => [
                  styles.menuProfileButton,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <Text style={styles.menuProfileText}>ML</Text>
              </Pressable>
            </View>
          </View>

          <ScrollView
            contentContainerStyle={styles.menuScrollContent}
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.menuPrimaryList}>
              {mainMenuRows.map(row => (
                <MenuRow
                  icon={row.icon}
                  key={row.label}
                  label={row.label}
                  onPress={
                    row.label === '앱'
                      ? onOpenSettings
                      : () => onSelectSession(row.label)
                  }
                />
              ))}
            </View>

            <View style={styles.menuSectionBlock}>
              <Text style={styles.menuSectionTitle}>프로젝트</Text>
              <MenuRow
                icon={projectRows[0].icon}
                label={projectRows[0].label}
                onPress={onNewChat}
              />
              {projectRows.slice(1).map(row => (
                <MenuRow
                  icon={row.icon}
                  iconColor={row.iconColor}
                  key={row.label}
                  label={row.label}
                  onPress={() => onSelectSession(row.label)}
                />
              ))}
            </View>

            <View style={[styles.menuSectionBlock, styles.menuRecentSection]}>
              <Text style={styles.menuSectionTitle}>최근</Text>
              {recentRows.map(row => (
                <Pressable
                  accessibilityRole="button"
                  key={row.label}
                  onPress={() => onSelectSession(row.label)}
                  style={({ pressed }) => [
                    styles.menuRecentRow,
                    pressed && styles.menuRowPressed,
                  ]}
                >
                  <Text numberOfLines={1} style={styles.menuRecentLabel}>
                    {row.label}
                  </Text>
                </Pressable>
              ))}
            </View>
          </ScrollView>
        </SafeAreaView>
      </Animated.View>
    </Modal>
  );
}

function MenuRow({
  icon,
  iconColor = colors.foreground,
  label,
  onPress,
}: MenuRowProps) {
  return (
    <Pressable
      accessibilityRole={onPress ? 'button' : 'text'}
      onPress={onPress}
      style={({ pressed }) => [
        styles.menuRow,
        pressed && onPress && styles.menuRowPressed,
      ]}
    >
      <View style={styles.menuIconSlot}>
        {icon ? <AppIcon color={iconColor} icon={icon} size={31} /> : null}
      </View>
      <View style={styles.menuRowCopy}>
        <Text numberOfLines={1} style={styles.menuRowLabel}>
          {label}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: colors.background,
    flex: 1,
  },
  header: {
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.94)',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    elevation: 10000,
    flexDirection: 'row',
    minHeight: 52,
    overflow: 'visible',
    paddingHorizontal: 12,
    zIndex: 10000,
  },
  headerSide: {
    alignItems: 'flex-start',
    flexShrink: 0,
    overflow: 'visible',
    width: 112,
  },
  headerSideRight: {
    alignItems: 'flex-end',
    elevation: 10001,
    position: 'relative',
    zIndex: 10001,
  },
  menuButton: {
    alignItems: 'center',
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  menuButtonPressed: {
    opacity: 0.55,
  },
  sessionTitle: {
    ...typography.label,
    color: colors.foreground,
    flex: 1,
    flexShrink: 1,
    fontSize: 16,
    fontWeight: '700',
    minWidth: 0,
    textAlign: 'center',
  },
  modelSelector: {
    alignItems: 'center',
    borderColor: colors.input,
    borderRadius: 18,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 5,
    minHeight: 32,
    maxWidth: 106,
    paddingHorizontal: 11,
  },
  modelSelectorActive: {
    backgroundColor: colors.card,
    borderColor: colors.input,
  },
  modelSelectorText: {
    ...typography.caption,
    color: colors.foreground,
    flexShrink: 1,
    fontSize: 13,
    fontWeight: '700',
  },
  modelMenuBackdrop: {
    bottom: 0,
    elevation: 9000,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 9000,
  },
  modelMenu: {
    backgroundColor: colors.card,
    borderColor: 'rgba(21,25,34,0.06)',
    borderRadius: 24,
    borderWidth: 1,
    elevation: 10002,
    overflow: 'hidden',
    position: 'absolute',
    right: 0,
    shadowColor: '#000000',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.14,
    shadowRadius: 34,
    top: MODEL_MENU_TOP,
    width: MODEL_MENU_WIDTH,
    zIndex: 10002,
  },
  modelMenuRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 64,
    paddingHorizontal: 18,
    paddingVertical: 10,
  },
  modelMenuRowActive: {
    backgroundColor: 'rgba(0,122,255,0.08)',
  },
  modelMenuManageRow: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 7,
  },
  modelMenuIcon: {
    alignItems: 'center',
    height: 28,
    justifyContent: 'center',
    marginRight: 12,
    width: 22,
  },
  modelMenuCopy: {
    flex: 1,
    paddingRight: 10,
  },
  modelMenuLabel: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 16,
    fontWeight: '700',
  },
  modelMenuDetail: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 13,
    fontWeight: '500',
    marginTop: 4,
  },
  content: {
    flex: 1,
  },
  menuSlidePanel: {
    flex: 1,
  },
  menuSafeArea: {
    backgroundColor: colors.card,
    flex: 1,
  },
  menuBackground: {
    backgroundColor: colors.card,
    bottom: 0,
    left: 0,
    pointerEvents: 'none',
    position: 'absolute',
    right: 0,
    top: 0,
  },
  menuHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 116,
    paddingHorizontal: 27,
    paddingTop: 14,
  },
  menuHeaderLogo: {
    flexShrink: 1,
    height: 41,
    marginRight: 18,
    maxWidth: 196,
    width: 196,
  },
  menuHeaderActions: {
    alignItems: 'center',
    backgroundColor: '#F7F7F8',
    borderRadius: 36,
    flexDirection: 'row',
    gap: 16,
    minHeight: 64,
    paddingLeft: 24,
    paddingRight: 9,
    shadowColor: '#000000',
    shadowOffset: { height: 16, width: 0 },
    shadowOpacity: 0.08,
    shadowRadius: 28,
  },
  menuSearchButton: {
    alignItems: 'center',
    height: 48,
    justifyContent: 'center',
    width: 36,
  },
  menuProfileButton: {
    alignItems: 'center',
    backgroundColor: '#9B4BC1',
    borderRadius: 25,
    height: 50,
    justifyContent: 'center',
    width: 50,
  },
  menuProfileText: {
    color: colors.primaryForeground,
    fontSize: 17,
    fontWeight: '600',
    includeFontPadding: false,
    lineHeight: 22,
  },
  menuScrollContent: {
    paddingBottom: 38,
    paddingTop: 42,
  },
  menuPrimaryList: {
    marginBottom: 58,
  },
  menuSectionBlock: {
    marginTop: 0,
    paddingTop: 0,
  },
  menuRecentSection: {
    marginTop: 58,
  },
  menuSectionTitle: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 28,
    fontWeight: '800',
    lineHeight: 34,
    marginBottom: 24,
    paddingHorizontal: 28,
  },
  menuRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 74,
    paddingHorizontal: 27,
    paddingVertical: 9,
  },
  menuRowPressed: {
    opacity: 0.58,
  },
  menuIconSlot: {
    alignItems: 'flex-start',
    justifyContent: 'center',
    width: 75,
  },
  menuRowCopy: {
    flex: 1,
    minWidth: 0,
  },
  menuRowLabel: {
    ...typography.body,
    color: colors.foreground,
    fontSize: 28,
    fontWeight: '500',
    lineHeight: 35,
  },
  menuRecentRow: {
    justifyContent: 'center',
    minHeight: 66,
    paddingHorizontal: 28,
  },
  menuRecentLabel: {
    ...typography.body,
    color: colors.foreground,
    fontSize: 26,
    fontWeight: '400',
    lineHeight: 34,
  },
});

export default App;
