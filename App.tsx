import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  faBars,
  faCheck,
  faChevronDown,
  faChevronRight,
  faPlus,
} from '@fortawesome/free-solid-svg-icons';
import {
  Animated,
  Easing,
  Image,
  Modal,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

import AppIcon from './src/components/AppIcon';
import PastelBackground from './src/components/PastelBackground';
import ChatScreen from './src/screens/ChatScreen';
import Settings from './src/screens/Settings';
import { colors, typography } from './src/theme/tokens';
import logoSource from './src/assets/logo.png';

const textDefaults = Text as unknown as {
  defaultProps?: { allowFontScaling?: boolean; maxFontSizeMultiplier?: number };
};
const inputDefaults = TextInput as unknown as {
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
  detail: string;
  id: 'gemma-4' | 'auto' | 'rag';
  label: string;
};

const MODEL_MENU_GAP = 6;
const MODEL_MENU_TOP = 30 + MODEL_MENU_GAP;
const MODEL_MENU_WIDTH = 222;

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
    detail: 'Mock engine · Native bridge 연결 전',
    label: '모델 및 런타임',
  },
  {
    detail: '갤러리, 일정 인덱싱 준비 중',
    label: '인덱싱 상태',
  },
  {
    detail: '사진, 파일, 알림 권한',
    label: '권한 설정',
  },
  {
    detail: 'open edge ai · Front-end preview',
    label: '앱 정보',
  },
];

const modelOptions: ModelOption[] = [
  {
    detail: '로컬 기본 모델',
    id: 'gemma-4',
    label: 'Gemma 4',
  },
  {
    detail: '질문에 맞춰 라우팅',
    id: 'auto',
    label: 'Auto',
  },
  {
    detail: '로컬 인덱스 활용',
    id: 'rag',
    label: 'RAG',
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
    <SafeAreaProvider>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
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

                  return (
                    <Pressable
                      accessibilityRole="button"
                      key={model.id}
                      onPress={() => {
                        setSelectedModelId(model.id);
                        setIsModelMenuOpen(false);
                      }}
                      style={({ pressed }) => [
                        styles.modelMenuRow,
                        isSelected && styles.modelMenuRowActive,
                        pressed && styles.menuRowPressed,
                      ]}
                    >
                      <View style={styles.modelMenuCopy}>
                        <Text style={styles.modelMenuLabel}>{model.label}</Text>
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
    backgroundColor: 'rgba(255,255,255,0.88)',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    elevation: 10000,
    flexDirection: 'row',
    minHeight: 44,
    overflow: 'visible',
    paddingHorizontal: 6,
    zIndex: 10000,
  },
  headerSide: {
    alignItems: 'flex-start',
    overflow: 'visible',
    width: 106,
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
    fontSize: 17,
    fontWeight: '600',
    textAlign: 'center',
  },
  modelSelector: {
    alignItems: 'center',
    borderColor: colors.input,
    borderRadius: 15,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 3,
    minHeight: 30,
    maxWidth: 96,
    paddingHorizontal: 9,
  },
  modelSelectorActive: {
    backgroundColor: colors.card,
    borderColor: colors.border,
  },
  modelSelectorText: {
    ...typography.caption,
    color: colors.foreground,
    flexShrink: 1,
    fontSize: 12,
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
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    elevation: 10002,
    overflow: 'hidden',
    position: 'absolute',
    right: 0,
    shadowColor: '#000000',
    shadowOffset: { height: 10, width: 0 },
    shadowOpacity: 0.12,
    shadowRadius: 24,
    top: MODEL_MENU_TOP,
    width: MODEL_MENU_WIDTH,
    zIndex: 10002,
  },
  modelMenuRow: {
    alignItems: 'center',
    borderBottomColor: colors.input,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 58,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  modelMenuRowActive: {
    backgroundColor: colors.accent,
  },
  modelMenuCopy: {
    flex: 1,
    paddingRight: 10,
  },
  modelMenuLabel: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 15,
  },
  modelMenuDetail: {
    ...typography.caption,
    color: colors.mutedForeground,
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
    backgroundColor: colors.background,
    flex: 1,
  },
  menuBackground: {
    backgroundColor: colors.background,
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  menuTopBar: {
    alignItems: 'flex-end',
    minHeight: 44,
    paddingHorizontal: 12,
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
    paddingBottom: 30,
    paddingHorizontal: 20,
    paddingTop: 0,
  },
  menuLogo: {
    alignSelf: 'flex-start',
    height: 64,
    marginLeft: -4,
    width: 250,
  },
  menuIntro: {
    marginTop: 6,
  },
  menuTitle: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 30,
    lineHeight: 35,
  },
  menuDescription: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 20,
    marginTop: 4,
  },
  menuSection: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 14,
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
    minHeight: 44,
    paddingVertical: 5,
  },
  menuRowActive: {
    borderLeftColor: colors.primary,
    borderLeftWidth: 3,
    paddingLeft: 9,
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
    fontSize: 16,
  },
  menuRowLabelActive: {
    color: colors.primary,
    fontWeight: '800',
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
