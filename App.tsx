import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  faBars,
  faBolt,
  faBrain,
  faCheck,
  faChevronDown,
  faChevronRight,
  faGear,
  faLayerGroup,
  faPlus,
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

type SessionPreview = {
  detail: string;
  id: string;
  isActive?: boolean;
  title: string;
};

type MenuRowProps = {
  detail?: string;
  isActive?: boolean;
  label: string;
  onPress?: () => void;
  trailing?: 'chevron' | 'current' | 'plus';
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

const savedSessions: SessionPreview[] = [
  {
    detail: '성장 아이디어와 실행 순서',
    id: 'growth',
    title: '광고 없는 성장 전략',
  },
  {
    detail: '오늘 할 일과 우선순위',
    id: 'plan',
    title: '실행 계획 만들기',
  },
  {
    detail: '로컬 모델 연결 체크',
    id: 'runtime',
    title: 'AIEngine 브릿지 점검',
  },
];

const settingsRows = [
  {
    detail: '텍스트 크기와 표시 방식',
    label: '개인화',
  },
  {
    detail: '모델 다운로드와 연결 상태',
    label: '모델 및 런타임',
  },
  {
    detail: '자료, 파일, 일정 동기화',
    label: '인덱싱 상태',
  },
  {
    detail: '사진, 파일, 알림 권한',
    label: '권한 설정',
  },
  {
    detail: '버전 및 앱 정보',
    label: '앱 정보',
  },
];

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

function App() {
  const [sessionTitle, setSessionTitle] = useState('새 채팅');
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isModelMenuOpen, setIsModelMenuOpen] = useState(false);
  const [chatInstanceKey, setChatInstanceKey] = useState(0);
  const [activeScreen, setActiveScreen] = useState<'chat' | 'settings'>('chat');
  const [selectedModelId, setSelectedModelId] =
    useState<ModelOption['id']>('gemma-4');

  const menuSessions = useMemo<SessionPreview[]>(
    () => [
      ...(sessionTitle === '새 채팅'
        ? []
        : [
            {
              detail: '현재 대화',
              id: 'current',
              isActive: true,
              title: sessionTitle,
            },
          ]),
      ...savedSessions.filter(session => session.title !== sessionTitle),
    ],
    [sessionTitle],
  );

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
            sessions={menuSessions}
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
  sessions,
  visible,
}: {
  onClose: () => void;
  onNewChat: () => void;
  onOpenSettings: () => void;
  onSelectSession: (title: string) => void;
  sessions: SessionPreview[];
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
        useNativeDriver: true,
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
      useNativeDriver: true,
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
          <View pointerEvents="none" style={styles.menuBackground} />

          <View style={styles.menuTopBar}>
            <Pressable
              accessibilityLabel="메뉴 닫기"
              accessibilityRole="button"
              onPress={onClose}
              style={({ pressed }) => [
                styles.closeButton,
                pressed && styles.menuButtonPressed,
              ]}
            >
              <Text style={styles.closeText}>완료</Text>
            </Pressable>
          </View>

          <ScrollView
            contentContainerStyle={styles.menuScrollContent}
            showsVerticalScrollIndicator={false}
          >
            <Image
              accessibilityIgnoresInvertColors
              resizeMode="contain"
              source={logoSource}
              style={styles.menuLogo}
            />

            <View style={styles.menuIntro}>
              <Text style={styles.menuTitle}>채팅 세션</Text>
              <Text style={styles.menuDescription}>
                최근 대화와 앱 설정을 한 화면에서 확인합니다.
              </Text>
            </View>

            <View style={styles.menuSection}>
              <MenuRow
                detail="새 대화로 시작"
                label="새 채팅"
                onPress={onNewChat}
                trailing="plus"
              />
              {sessions.map(session => (
                <MenuRow
                  detail={session.detail}
                  isActive={session.isActive}
                  key={session.id}
                  label={session.title}
                  onPress={() => onSelectSession(session.title)}
                  trailing={session.isActive ? 'current' : 'chevron'}
                />
              ))}
            </View>

            <View style={styles.menuSection}>
              <Text style={styles.menuSectionTitle}>설정</Text>
              {settingsRows.map(row => (
                <MenuRow
                  detail={row.detail}
                  key={row.label}
                  label={row.label}
                  onPress={onOpenSettings}
                  trailing="chevron"
                />
              ))}
            </View>
          </ScrollView>
        </SafeAreaView>
      </Animated.View>
    </Modal>
  );
}

function MenuRow({
  detail,
  isActive = false,
  label,
  onPress,
  trailing,
}: MenuRowProps) {
  return (
    <Pressable
      accessibilityRole={onPress ? 'button' : 'text'}
      onPress={onPress}
      style={({ pressed }) => [
        styles.menuRow,
        isActive && styles.menuRowActive,
        pressed && onPress && styles.menuRowPressed,
      ]}
    >
      <View style={styles.menuRowCopy}>
        <Text
          numberOfLines={1}
          style={[styles.menuRowLabel, isActive && styles.menuRowLabelActive]}
        >
          {label}
        </Text>
        {detail ? (
          <Text numberOfLines={1} style={styles.menuRowDetail}>
            {detail}
          </Text>
        ) : null}
      </View>
      {trailing ? (
        trailing === 'current' ? (
          <Text style={[styles.menuRowTrailing, styles.activeTrailing]}>
            현재
          </Text>
        ) : (
          <AppIcon
            color={colors.primary}
            icon={trailing === 'plus' ? faPlus : faChevronRight}
            size={trailing === 'plus' ? 15 : 14}
          />
        )
      ) : null}
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
    position: 'absolute',
    right: 0,
    top: 0,
  },
  menuTopBar: {
    alignItems: 'flex-end',
    minHeight: 52,
    paddingHorizontal: 18,
  },
  closeButton: {
    alignItems: 'center',
    height: 36,
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  closeText: {
    color: colors.primary,
    fontSize: 17,
    fontWeight: '600',
    includeFontPadding: false,
    lineHeight: 22,
  },
  menuScrollContent: {
    paddingBottom: 34,
    paddingHorizontal: 24,
    paddingTop: 2,
  },
  menuLogo: {
    alignSelf: 'flex-start',
    height: 56,
    marginLeft: -6,
    width: 238,
  },
  menuIntro: {
    marginTop: 34,
  },
  menuTitle: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 34,
    lineHeight: 40,
  },
  menuDescription: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 20,
    marginTop: 8,
  },
  menuSection: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 28,
  },
  menuSectionTitle: {
    ...typography.caption,
    color: colors.mutedForeground,
    marginBottom: 2,
    marginTop: 8,
  },
  menuRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 58,
    paddingVertical: 8,
  },
  menuRowActive: {
    paddingLeft: 0,
  },
  menuRowPressed: {
    opacity: 0.58,
  },
  menuRowCopy: {
    flex: 1,
    paddingRight: 18,
  },
  menuRowLabel: {
    ...typography.body,
    color: colors.foreground,
    fontSize: 18,
    fontWeight: '600',
  },
  menuRowLabelActive: {
    color: colors.foreground,
    fontWeight: '700',
  },
  menuRowDetail: {
    ...typography.caption,
    color: colors.mutedForeground,
    marginTop: 4,
  },
  menuRowTrailing: {
    ...typography.label,
    color: colors.primary,
    fontSize: 17,
  },
  activeTrailing: {
    color: colors.primary,
    fontSize: 12,
  },
});

export default App;
