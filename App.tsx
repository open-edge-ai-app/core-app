import React, { useEffect, useMemo, useRef, useState } from 'react';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import {
  Animated,
  Easing,
  Image,
  Modal,
  Platform,
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
import { appIcons } from './src/theme/icons';
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

type ChatSession = {
  id: string;
  pinned?: boolean;
  title: string;
};

type WorkFolder = {
  id: string;
  title: string;
};

type MenuSearchResult = {
  id: string;
  title: string;
  type: 'folder' | 'session';
};

type RecentSessionDialog =
  | { session: ChatSession; type: 'rename' }
  | { session: ChatSession; type: 'move' }
  | { session: ChatSession; type: 'delete' };

const MODEL_MENU_GAP = 6;
const MODEL_MENU_TOP = 32 + MODEL_MENU_GAP;
const MODEL_MENU_WIDTH = 252;
const WEB_APP_MAX_WIDTH = 430;
const MENU_HORIZONTAL_PADDING = 24;
const MENU_HEADER_LOGO_LEFT_OFFSET = -16;
const MENU_HEADER_ICON_SIZE = 18;

const modelOptions: ModelOption[] = [
  {
    detail: '빠르고 균형 잡힌 성능',
    icon: appIcons.modelBalanced,
    id: 'gemma-4',
    label: 'Gemma 4',
  },
  {
    detail: '가볍고 빠른 응답',
    icon: appIcons.modelFast,
    id: 'gemma-lite',
    label: 'Gemma 4 Lite',
  },
  {
    detail: '복잡한 추론에 최적화',
    icon: appIcons.modelDeep,
    id: 'gemma-deep',
    label: 'Gemma 4 Deep',
  },
  {
    detail: '작업에 맞춰 자동 선택',
    icon: appIcons.modelAuto,
    id: 'auto',
    label: 'Auto',
  },
  {
    action: 'settings',
    detail: '다운로드 및 상태 확인',
    icon: appIcons.modelManage,
    id: 'manage',
    label: '모델 관리',
  },
];

const mainMenuRows: MenuIconRow[] = [
  {
    icon: appIcons.menuImage,
    label: '이미지',
  },
  {
    icon: appIcons.menuPulse,
    label: 'Pulse',
  },
  {
    icon: appIcons.menuCodex,
    label: 'Codex',
  },
  {
    icon: appIcons.menuApps,
    label: '앱',
  },
];

const workFolderRows: MenuIconRow[] = [
  {
    icon: appIcons.newFolder,
    label: '새 작업 폴더',
  },
];

const initialRecentSessions: ChatSession[] = [
  {
    id: 'linkedin-intro',
    title: '링크드인 소개 수정',
  },
];

function App() {
  const [sessionTitle, setSessionTitle] = useState('새 채팅');
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [recentSessions, setRecentSessions] = useState<ChatSession[]>(
    initialRecentSessions,
  );
  const [workFolderSessions, setWorkFolderSessions] = useState<ChatSession[]>(
    [],
  );
  const [workFolders, setWorkFolders] = useState<WorkFolder[]>([]);
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

  const sortedRecentSessions = useMemo(
    () =>
      [...recentSessions].sort((first, second) => {
        if (first.pinned === second.pinned) {
          return 0;
        }

        return first.pinned ? -1 : 1;
      }),
    [recentSessions],
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
    setActiveSessionId(null);
    setSessionTitle('새 채팅');
    setChatInstanceKey(current => current + 1);
    setIsMenuOpen(false);
  };

  const handleSelectSession = (title: string, id?: string) => {
    setActiveScreen('chat');
    setActiveSessionId(id ?? null);
    setSessionTitle(title);
    setIsMenuOpen(false);
  };

  const handleOpenSettings = () => {
    setActiveScreen('settings');
    setActiveSessionId(null);
    setIsMenuOpen(false);
  };

  const handleRenameSession = (sessionId: string, title: string) => {
    setRecentSessions(current =>
      current.map(session =>
        session.id === sessionId ? { ...session, title } : session,
      ),
    );
    setWorkFolderSessions(current =>
      current.map(session =>
        session.id === sessionId ? { ...session, title } : session,
      ),
    );

    if (activeSessionId === sessionId) {
      setSessionTitle(title);
    }
  };

  const handleTogglePinnedSession = (sessionId: string) => {
    setRecentSessions(current =>
      current.map(session =>
        session.id === sessionId
          ? { ...session, pinned: !session.pinned }
          : session,
      ),
    );
  };

  const handleMoveSessionToWorkFolder = (sessionId: string) => {
    const movedSession = recentSessions.find(
      session => session.id === sessionId,
    );
    if (!movedSession) {
      return;
    }

    setRecentSessions(current =>
      current.filter(session => session.id !== sessionId),
    );
    setWorkFolderSessions(current => {
      if (current.some(session => session.id === sessionId)) {
        return current;
      }

      return [...current, { ...movedSession, pinned: false }];
    });
  };

  const handleCreateWorkFolder = (title: string) => {
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }

    setWorkFolders(current => [
      ...current,
      {
        id: `work-folder-${Date.now()}`,
        title: nextTitle,
      },
    ]);
  };

  const handleDeleteSession = (sessionId: string) => {
    setRecentSessions(current =>
      current.filter(session => session.id !== sessionId),
    );
    setWorkFolderSessions(current =>
      current.filter(session => session.id !== sessionId),
    );

    if (activeSessionId === sessionId) {
      setActiveSessionId(null);
      setSessionTitle('새 채팅');
      setChatInstanceKey(current => current + 1);
    }
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
                <AppIcon
                  color={colors.foreground}
                  icon={appIcons.navigationMenu}
                  size={20}
                />
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
                  icon={appIcons.chevronDown}
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
                            icon={appIcons.selected}
                            size={16}
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
            onCreateWorkFolder={handleCreateWorkFolder}
            onDeleteSession={handleDeleteSession}
            onClose={() => setIsMenuOpen(false)}
            onMoveSessionToWorkFolder={handleMoveSessionToWorkFolder}
            onNewChat={handleNewChat}
            onOpenSettings={handleOpenSettings}
            onRenameSession={handleRenameSession}
            onSelectSession={handleSelectSession}
            onTogglePinnedSession={handleTogglePinnedSession}
            recentSessions={sortedRecentSessions}
            visible={isMenuOpen}
            workFolders={workFolders}
            workFolderSessions={workFolderSessions}
          />
        </SafeAreaView>
      </SafeAreaProvider>
    </DisplaySettingsProvider>
  );
}

function FullScreenMenu({
  onClose,
  onCreateWorkFolder,
  onDeleteSession,
  onMoveSessionToWorkFolder,
  onNewChat,
  onOpenSettings,
  onRenameSession,
  onSelectSession,
  onTogglePinnedSession,
  recentSessions,
  visible,
  workFolders,
  workFolderSessions,
}: {
  onClose: () => void;
  onCreateWorkFolder: (title: string) => void;
  onDeleteSession: (sessionId: string) => void;
  onMoveSessionToWorkFolder: (sessionId: string) => void;
  onNewChat: () => void;
  onOpenSettings: () => void;
  onRenameSession: (sessionId: string, title: string) => void;
  onSelectSession: (title: string, id?: string) => void;
  onTogglePinnedSession: (sessionId: string) => void;
  recentSessions: ChatSession[];
  visible: boolean;
  workFolders: WorkFolder[];
  workFolderSessions: ChatSession[];
}) {
  const { width } = useWindowDimensions();
  const slideX = useRef(new Animated.Value(-width)).current;
  const [isRendered, setIsRendered] = useState(visible);
  const [actionSheetSession, setActionSheetSession] =
    useState<ChatSession | null>(null);
  const [recentDialog, setRecentDialog] =
    useState<RecentSessionDialog | null>(null);
  const [renameDraft, setRenameDraft] = useState('');
  const [isWorkFolderDialogOpen, setIsWorkFolderDialogOpen] = useState(false);
  const [workFolderDraft, setWorkFolderDraft] = useState('');
  const [isSearchDialogOpen, setIsSearchDialogOpen] = useState(false);
  const [searchDraft, setSearchDraft] = useState('');

  const searchResults = useMemo(() => {
    const query = searchDraft.trim().toLowerCase();
    const candidates: MenuSearchResult[] = [
      ...workFolders.map(folder => ({
        id: folder.id,
        title: folder.title,
        type: 'folder' as const,
      })),
      ...workFolderSessions.map(session => ({
        id: session.id,
        title: session.title,
        type: 'session' as const,
      })),
      ...recentSessions.map(session => ({
        id: session.id,
        title: session.title,
        type: 'session' as const,
      })),
    ];

    if (!query) {
      return candidates;
    }

    return candidates.filter(candidate =>
      candidate.title.toLowerCase().includes(query),
    );
  }, [recentSessions, searchDraft, workFolders, workFolderSessions]);

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

  useEffect(() => {
    if (visible) {
      return;
    }

    setActionSheetSession(null);
    setRecentDialog(null);
    setRenameDraft('');
    setIsWorkFolderDialogOpen(false);
    setWorkFolderDraft('');
    setIsSearchDialogOpen(false);
    setSearchDraft('');
  }, [visible]);

  if (!isRendered) {
    return null;
  }

  const handleOpenSettingsFromMenu = () => {
    onOpenSettings();
    setIsRendered(false);
  };

  const handleOpenRecentDialog = (
    type: RecentSessionDialog['type'],
    session: ChatSession,
  ) => {
    setActionSheetSession(null);
    setRecentDialog({ session, type } as RecentSessionDialog);
    setRenameDraft(session.title);
  };

  const handleCloseRecentDialog = () => {
    setRecentDialog(null);
    setRenameDraft('');
  };

  const handleOpenSearchDialog = () => {
    setActionSheetSession(null);
    setIsSearchDialogOpen(true);
  };

  const handleCloseSearchDialog = () => {
    setIsSearchDialogOpen(false);
    setSearchDraft('');
  };

  const handleSelectSearchResult = (result: MenuSearchResult) => {
    handleCloseSearchDialog();
    onSelectSession(result.title, result.id);
  };

  const handleOpenWorkFolderDialog = () => {
    setActionSheetSession(null);
    setIsWorkFolderDialogOpen(true);
  };

  const handleCloseWorkFolderDialog = () => {
    setIsWorkFolderDialogOpen(false);
    setWorkFolderDraft('');
  };

  const handleSubmitWorkFolder = () => {
    const nextTitle = workFolderDraft.trim();
    if (!nextTitle) {
      return;
    }

    onCreateWorkFolder(nextTitle);
    handleCloseWorkFolderDialog();
  };

  const handleSubmitRename = () => {
    if (recentDialog?.type !== 'rename') {
      return;
    }

    const nextTitle = renameDraft.trim();
    if (!nextTitle) {
      return;
    }

    onRenameSession(recentDialog.session.id, nextTitle);
    handleCloseRecentDialog();
  };

  const handleConfirmMove = () => {
    if (recentDialog?.type !== 'move') {
      return;
    }

    onMoveSessionToWorkFolder(recentDialog.session.id);
    handleCloseRecentDialog();
  };

  const handleConfirmDelete = () => {
    if (recentDialog?.type !== 'delete') {
      return;
    }

    onDeleteSession(recentDialog.session.id);
    handleCloseRecentDialog();
  };

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
          Platform.OS === 'web' && styles.menuWebFrame,
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
                onPress={handleOpenSearchDialog}
                style={({ pressed }) => [
                  styles.menuSearchButton,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <AppIcon
                  color={colors.foreground}
                  icon={appIcons.search}
                  size={MENU_HEADER_ICON_SIZE}
                />
              </Pressable>
              <Pressable
                accessibilityLabel="설정"
                accessibilityRole="button"
                onPress={handleOpenSettingsFromMenu}
                style={({ pressed }) => [
                  styles.menuSettingsButton,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <AppIcon
                  color={colors.foreground}
                  icon={appIcons.settings}
                  size={MENU_HEADER_ICON_SIZE}
                />
              </Pressable>
            </View>
          </View>

          <ScrollView
            contentContainerStyle={styles.menuScrollContent}
            onScrollBeginDrag={() => setActionSheetSession(null)}
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
                      ? handleOpenSettingsFromMenu
                      : () => onSelectSession(row.label)
                  }
                />
              ))}
            </View>

            <View style={styles.menuSectionBlock}>
              <Text style={styles.menuSectionTitle}>작업 폴더</Text>
              <MenuRow
                icon={workFolderRows[0].icon}
                label={workFolderRows[0].label}
                onPress={handleOpenWorkFolderDialog}
              />
              {workFolders.map(folder => (
                <MenuRow
                  icon={appIcons.folder}
                  iconColor={colors.foreground}
                  key={folder.id}
                  label={folder.title}
                  onPress={() => onSelectSession(folder.title, folder.id)}
                />
              ))}
              {workFolderSessions.map(session => (
                <MenuRow
                  icon={appIcons.folder}
                  iconColor={colors.mutedForeground}
                  key={session.id}
                  label={session.title}
                  onPress={() => onSelectSession(session.title, session.id)}
                />
              ))}
              {workFolderRows.slice(1).map(row => (
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
              {recentSessions.map(session => {
                const isActionMenuOpen = actionSheetSession?.id === session.id;

                return (
                  <View key={session.id} style={styles.menuRecentItem}>
                    <Pressable
                      accessibilityRole="button"
                      delayLongPress={360}
                      onLongPress={() => setActionSheetSession(session)}
                      onPress={() => {
                        setActionSheetSession(null);
                        onSelectSession(session.title, session.id);
                      }}
                      style={({ pressed }) => [
                        styles.menuRecentRow,
                        isActionMenuOpen && styles.menuRecentRowActive,
                        pressed && styles.menuRowPressed,
                      ]}
                    >
                      <Text numberOfLines={1} style={styles.menuRecentLabel}>
                        {session.title}
                      </Text>
                      {session.pinned ? (
                        <AppIcon
                          color={colors.primary}
                          icon={appIcons.pin}
                          size={14}
                        />
                      ) : null}
                    </Pressable>

                    {isActionMenuOpen ? (
                      <View style={styles.recentInlineActionMenu}>
                        <RecentActionButton
                          icon={appIcons.rename}
                          label="이름 바꾸기"
                          onPress={() =>
                            handleOpenRecentDialog('rename', session)
                          }
                        />
                        <RecentActionButton
                          icon={appIcons.pin}
                          label={session.pinned ? '채팅 고정 해제' : '채팅 고정'}
                          onPress={() => {
                            onTogglePinnedSession(session.id);
                            setActionSheetSession(null);
                          }}
                        />
                        <RecentActionButton
                          icon={appIcons.moveToFolder}
                          label="작업 폴더로 이동"
                          onPress={() => handleOpenRecentDialog('move', session)}
                        />
                        <RecentActionButton
                          destructive
                          icon={appIcons.delete}
                          label="삭제"
                          onPress={() =>
                            handleOpenRecentDialog('delete', session)
                          }
                        />
                      </View>
                    ) : null}
                  </View>
                );
              })}
            </View>
          </ScrollView>

          {!isWorkFolderDialogOpen && !recentDialog && !isSearchDialogOpen ? (
            <Pressable
              accessibilityLabel="새로운 채팅"
              accessibilityRole="button"
              onPress={onNewChat}
              style={({ pressed }) => [
                styles.newChatFloatingButton,
                pressed && styles.menuButtonPressed,
              ]}
            >
              <AppIcon
                color={colors.primaryForeground}
                icon={appIcons.newChat}
                size={15}
              />
              <Text style={styles.newChatFloatingText}>새로운 채팅</Text>
            </Pressable>
          ) : null}

          {isSearchDialogOpen ? (
            <View style={styles.recentDialogLayer}>
              <Pressable
                accessibilityLabel="검색 닫기"
                onPress={handleCloseSearchDialog}
                style={styles.recentDialogBackdrop}
              />
              <View style={[styles.recentDialogCard, styles.searchDialogCard]}>
                <Text style={styles.recentDialogTitle}>검색</Text>
                <View style={styles.searchInputWrap}>
                  <AppIcon
                    color={colors.mutedForeground}
                    icon={appIcons.search}
                    size={15}
                  />
                  <RNTextInput
                    accessibilityLabel="폴더와 채팅 세션 검색"
                    autoFocus
                    onChangeText={setSearchDraft}
                    placeholder="폴더, 채팅 세션 검색"
                    placeholderTextColor={colors.mutedForeground}
                    returnKeyType="search"
                    style={styles.searchInput}
                    value={searchDraft}
                  />
                </View>
                <ScrollView
                  keyboardShouldPersistTaps="handled"
                  showsVerticalScrollIndicator={false}
                  style={styles.searchResultsList}
                >
                  {searchResults.length > 0 ? (
                    searchResults.map(result => (
                      <Pressable
                        accessibilityRole="button"
                        key={`${result.type}-${result.id}`}
                        onPress={() => handleSelectSearchResult(result)}
                        style={({ pressed }) => [
                          styles.searchResultRow,
                          pressed && styles.menuRowPressed,
                        ]}
                      >
                        <View style={styles.searchResultIcon}>
                          <AppIcon
                            color={colors.foreground}
                            icon={
                              result.type === 'folder'
                                ? appIcons.folder
                                : appIcons.session
                            }
                            size={16}
                          />
                        </View>
                        <View style={styles.searchResultCopy}>
                          <Text
                            numberOfLines={1}
                            style={styles.searchResultTitle}
                          >
                            {result.title}
                          </Text>
                          <Text style={styles.searchResultMeta}>
                            {result.type === 'folder'
                              ? '작업 폴더'
                              : '채팅 세션'}
                          </Text>
                        </View>
                      </Pressable>
                    ))
                  ) : (
                    <Text style={styles.searchEmptyText}>검색 결과 없음</Text>
                  )}
                </ScrollView>
              </View>
            </View>
          ) : null}

          {isWorkFolderDialogOpen ? (
            <View style={styles.recentDialogLayer}>
              <Pressable
                accessibilityLabel="작업 폴더 만들기 닫기"
                onPress={handleCloseWorkFolderDialog}
                style={styles.recentDialogBackdrop}
              />
              <View style={styles.recentDialogCard}>
                <Text style={styles.recentDialogTitle}>새 작업 폴더</Text>
                <RNTextInput
                  accessibilityLabel="작업 폴더 이름"
                  autoFocus
                  onChangeText={setWorkFolderDraft}
                  placeholder="작업 폴더 이름"
                  placeholderTextColor={colors.mutedForeground}
                  returnKeyType="done"
                  style={styles.recentDialogInput}
                  value={workFolderDraft}
                />
                <View style={styles.recentDialogActions}>
                  <Pressable
                    accessibilityRole="button"
                    onPress={handleCloseWorkFolderDialog}
                    style={({ pressed }) => [
                      styles.recentDialogButton,
                      pressed && styles.menuButtonPressed,
                    ]}
                  >
                    <Text style={styles.recentDialogCancelText}>취소</Text>
                  </Pressable>
                  <Pressable
                    accessibilityRole="button"
                    disabled={!workFolderDraft.trim()}
                    onPress={handleSubmitWorkFolder}
                    style={({ pressed }) => [
                      styles.recentDialogButton,
                      styles.recentDialogPrimaryButton,
                      pressed && styles.menuButtonPressed,
                      !workFolderDraft.trim() &&
                        styles.recentDialogButtonDisabled,
                    ]}
                  >
                    <Text style={styles.recentDialogPrimaryText}>만들기</Text>
                  </Pressable>
                </View>
              </View>
            </View>
          ) : null}

          {recentDialog ? (
            <View style={styles.recentDialogLayer}>
              <Pressable
                accessibilityLabel="최근 채팅 작업 닫기"
                onPress={handleCloseRecentDialog}
                style={styles.recentDialogBackdrop}
              />
              <View style={styles.recentDialogCard}>
                <Text style={styles.recentDialogTitle}>
                  {recentDialog.type === 'rename'
                    ? '이름 바꾸기'
                    : recentDialog.type === 'move'
                      ? '작업 폴더로 이동'
                      : '채팅 삭제'}
                </Text>
                {recentDialog.type === 'rename' ? (
                  <RNTextInput
                    accessibilityLabel="채팅 이름"
                    autoFocus
                    onChangeText={setRenameDraft}
                    onSubmitEditing={handleSubmitRename}
                    placeholder="채팅 이름"
                    placeholderTextColor={colors.mutedForeground}
                    returnKeyType="done"
                    style={styles.recentDialogInput}
                    value={renameDraft}
                  />
                ) : (
                  <Text style={styles.recentDialogMessage}>
                    {recentDialog.type === 'move'
                      ? '최근 목록에서 제거하고 작업 폴더에 추가합니다.'
                      : '이 채팅 세션을 삭제할까요? 삭제 후에는 목록에서 사라집니다.'}
                  </Text>
                )}
                {recentDialog.type === 'move' ? (
                  <View style={styles.recentDialogFolderTarget}>
                    <AppIcon
                      color={colors.foreground}
                      icon={appIcons.folder}
                      size={16}
                    />
                    <Text style={styles.recentDialogFolderText}>
                      기본 작업 폴더
                    </Text>
                  </View>
                ) : null}
                <View style={styles.recentDialogActions}>
                  <Pressable
                    accessibilityRole="button"
                    onPress={handleCloseRecentDialog}
                    style={({ pressed }) => [
                      styles.recentDialogButton,
                      pressed && styles.menuButtonPressed,
                    ]}
                  >
                    <Text style={styles.recentDialogCancelText}>취소</Text>
                  </Pressable>
                  <Pressable
                    accessibilityRole="button"
                    disabled={
                      recentDialog.type === 'rename' && !renameDraft.trim()
                    }
                    onPress={
                      recentDialog.type === 'rename'
                        ? handleSubmitRename
                        : recentDialog.type === 'move'
                          ? handleConfirmMove
                          : handleConfirmDelete
                    }
                    style={({ pressed }) => [
                      styles.recentDialogButton,
                      styles.recentDialogPrimaryButton,
                      recentDialog.type === 'delete' &&
                        styles.recentDialogDeleteButton,
                      pressed && styles.menuButtonPressed,
                      recentDialog.type === 'rename' &&
                        !renameDraft.trim() &&
                        styles.recentDialogButtonDisabled,
                    ]}
                  >
                    <Text style={styles.recentDialogPrimaryText}>
                      {recentDialog.type === 'rename'
                        ? '저장'
                        : recentDialog.type === 'move'
                          ? '이동'
                          : '삭제'}
                    </Text>
                  </Pressable>
                </View>
              </View>
            </View>
          ) : null}
        </SafeAreaView>
      </Animated.View>
    </Modal>
  );
}

function RecentActionButton({
  destructive,
  icon,
  label,
  onPress,
}: {
  destructive?: boolean;
  icon: IconDefinition;
  label: string;
  onPress: () => void;
}) {
  const foreground = destructive ? colors.destructive : colors.foreground;

  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.recentActionRow,
        pressed && styles.menuRowPressed,
      ]}
    >
      <View style={styles.recentActionIcon}>
        <AppIcon color={foreground} icon={icon} size={16} />
      </View>
      <Text
        style={[
          styles.recentActionLabel,
          destructive && styles.recentActionDestructiveLabel,
        ]}
      >
        {label}
      </Text>
    </Pressable>
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
        {icon ? <AppIcon color={iconColor} icon={icon} size={20} /> : null}
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
  menuWebFrame: {
    alignSelf: 'center',
    maxWidth: WEB_APP_MAX_WIDTH,
    width: '100%',
  },
  menuSafeArea: {
    backgroundColor: colors.card,
    flex: 1,
    position: 'relative',
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
    minHeight: 78,
    paddingHorizontal: MENU_HORIZONTAL_PADDING,
    paddingTop: 8,
  },
  menuHeaderLogo: {
    flexShrink: 1,
    height: 32,
    marginLeft: MENU_HEADER_LOGO_LEFT_OFFSET,
    marginRight: 16,
    maxWidth: 152,
    width: 152,
  },
  menuHeaderActions: {
    alignItems: 'center',
    backgroundColor: '#F7F7F8',
    borderRadius: 24,
    flexDirection: 'row',
    gap: 8,
    minHeight: 46,
    paddingHorizontal: 10,
  },
  menuSearchButton: {
    alignItems: 'center',
    height: 38,
    justifyContent: 'center',
    width: 34,
  },
  menuSettingsButton: {
    alignItems: 'center',
    height: 38,
    justifyContent: 'center',
    width: 34,
  },
  menuScrollContent: {
    paddingBottom: 104,
    paddingHorizontal: MENU_HORIZONTAL_PADDING,
    paddingTop: 22,
  },
  menuPrimaryList: {
    marginBottom: 34,
  },
  menuSectionBlock: {
    marginTop: 0,
    paddingTop: 0,
  },
  menuRecentSection: {
    marginTop: 34,
  },
  menuSectionTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 17,
    fontWeight: '800',
    lineHeight: 22,
    marginBottom: 8,
  },
  menuRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 52,
    paddingVertical: 8,
  },
  menuRowPressed: {
    opacity: 0.58,
  },
  menuIconSlot: {
    alignItems: 'flex-start',
    justifyContent: 'center',
    width: 46,
  },
  menuRowCopy: {
    flex: 1,
    minWidth: 0,
  },
  menuRowLabel: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 16,
    fontWeight: '500',
    lineHeight: 21,
  },
  menuRecentItem: {
    marginBottom: 2,
  },
  menuRecentRow: {
    alignItems: 'center',
    borderRadius: 10,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 48,
    paddingHorizontal: 8,
  },
  menuRecentRowActive: {
    backgroundColor: colors.muted,
  },
  menuRecentLabel: {
    ...typography.body,
    color: colors.foreground,
    flex: 1,
    fontSize: 16,
    fontWeight: '400',
    lineHeight: 22,
    paddingRight: 12,
  },
  recentInlineActionMenu: {
    alignSelf: 'flex-end',
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    marginBottom: 8,
    marginTop: 2,
    maxWidth: 214,
    minWidth: 188,
    overflow: 'hidden',
    paddingVertical: 4,
  },
  recentActionRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 38,
    paddingHorizontal: 12,
  },
  recentActionIcon: {
    alignItems: 'center',
    height: 24,
    justifyContent: 'center',
    marginRight: 9,
    width: 20,
  },
  recentActionLabel: {
    ...typography.label,
    color: colors.foreground,
    flex: 1,
    fontSize: 14,
    fontWeight: '600',
  },
  recentActionDestructiveLabel: {
    color: colors.destructive,
  },
  newChatFloatingButton: {
    alignItems: 'center',
    backgroundColor: colors.foreground,
    borderRadius: 18,
    bottom: 22,
    elevation: 32,
    flexDirection: 'row',
    minHeight: 44,
    paddingHorizontal: 16,
    position: 'absolute',
    right: 22,
    shadowColor: '#000000',
    shadowOffset: { height: 10, width: 0 },
    shadowOpacity: 0.18,
    shadowRadius: 18,
    zIndex: 35,
  },
  newChatFloatingText: {
    ...typography.label,
    color: colors.primaryForeground,
    fontSize: 14,
    fontWeight: '800',
    marginLeft: 8,
  },
  recentDialogLayer: {
    alignItems: 'center',
    bottom: 0,
    justifyContent: 'center',
    left: 0,
    paddingHorizontal: 22,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 40,
  },
  recentDialogBackdrop: {
    backgroundColor: 'rgba(21,25,34,0.24)',
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  recentDialogCard: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 18,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 18,
    width: '100%',
  },
  searchDialogCard: {
    maxHeight: '72%',
  },
  recentDialogTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 18,
    fontWeight: '800',
    lineHeight: 24,
    marginBottom: 14,
  },
  recentDialogInput: {
    ...typography.body,
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    color: colors.foreground,
    fontSize: 16,
    minHeight: 46,
    paddingHorizontal: 14,
  },
  searchInputWrap: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 46,
    paddingHorizontal: 14,
  },
  searchInput: {
    ...typography.body,
    color: colors.foreground,
    flex: 1,
    fontSize: 16,
    marginLeft: 10,
    minHeight: 44,
    padding: 0,
  },
  searchResultsList: {
    marginTop: 12,
  },
  searchResultRow: {
    alignItems: 'center',
    borderRadius: 12,
    flexDirection: 'row',
    minHeight: 58,
    paddingHorizontal: 10,
  },
  searchResultIcon: {
    alignItems: 'center',
    height: 32,
    justifyContent: 'center',
    marginRight: 12,
    width: 28,
  },
  searchResultCopy: {
    flex: 1,
    minWidth: 0,
  },
  searchResultTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 15,
    fontWeight: '700',
  },
  searchResultMeta: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '600',
    marginTop: 4,
  },
  searchEmptyText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 14,
    fontWeight: '600',
    paddingVertical: 22,
    textAlign: 'center',
  },
  recentDialogMessage: {
    ...typography.body,
    color: colors.mutedForeground,
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 21,
  },
  recentDialogFolderTarget: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: 12,
    flexDirection: 'row',
    marginTop: 14,
    minHeight: 44,
    paddingHorizontal: 14,
  },
  recentDialogFolderText: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 15,
    fontWeight: '700',
    marginLeft: 10,
  },
  recentDialogActions: {
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'flex-end',
    marginTop: 18,
  },
  recentDialogButton: {
    alignItems: 'center',
    borderRadius: 12,
    justifyContent: 'center',
    minHeight: 42,
    minWidth: 74,
    paddingHorizontal: 14,
  },
  recentDialogPrimaryButton: {
    backgroundColor: colors.foreground,
  },
  recentDialogDeleteButton: {
    backgroundColor: colors.destructive,
  },
  recentDialogButtonDisabled: {
    opacity: 0.36,
  },
  recentDialogCancelText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 15,
    fontWeight: '700',
  },
  recentDialogPrimaryText: {
    ...typography.label,
    color: colors.primaryForeground,
    fontSize: 15,
    fontWeight: '800',
  },
});

export default App;
