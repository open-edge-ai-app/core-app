import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import React, {
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import type { GestureResponderEvent, LayoutChangeEvent } from 'react-native';
import {
  Animated,
  Easing,
  Image,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  TextInput as RNTextInput,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';

import AppIcon from '../components/AppIcon';
import FloatingSelect, {
  FloatingSelectOption,
} from '../components/FloatingSelect';
import { brandAssets } from '../config/branding';
import { ChatSession } from '../state/chatStorage';
import { ScaledText as Text } from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors } from '../theme/tokens';
import {
  DEFAULT_WORK_FOLDER_ICON_ID,
  MENU_HEADER_ICON_SIZE,
  RECENT_ACTION_MENU_EDGE_GAP,
  RECENT_ACTION_MENU_HEIGHT,
  RECENT_ACTION_MENU_OFFSET,
  RECENT_ACTION_MENU_WIDTH,
  WORK_FOLDER_ACTION_MENU_HEIGHT,
  WORK_FOLDER_SESSION_ACTION_MENU_HEIGHT,
  getWorkFolderIcon,
  mainMenuRows,
  omitRecordKey,
  workFolderIconOptions,
  type MenuRowProps,
  type MenuSearchResult,
  type RecentActionMenuAnchor,
  type RecentActionMenuPosition,
  type RecentActionMenuSize,
  type RecentSessionDialog,
  type SessionActionScope,
  type WorkFolder,
  type WorkFolderActionDialog,
  type WorkFolderIconId,
} from './appConfig';
import { styles } from './appStyles';

export default function FullScreenMenu({
  onClose,
  onCreateWorkFolder,
  onDeleteWorkFolder,
  onDeleteSession,
  onMoveSessionToWorkFolder,
  onNewChat,
  onOpenSettings,
  onRenameSession,
  onRemoveSessionFromWorkFolder,
  onSelectSession,
  onTogglePinnedSession,
  onUpdateWorkFolder,
  recentSessions,
  visible,
  workFolders,
  workFolderSessions,
}: {
  onClose: () => void;
  onCreateWorkFolder: (title: string, iconId: WorkFolderIconId) => void;
  onDeleteWorkFolder: (folderId: string) => void;
  onDeleteSession: (sessionId: string) => void;
  onMoveSessionToWorkFolder: (sessionId: string, workFolderId: string) => void;
  onNewChat: () => void;
  onOpenSettings: () => void;
  onRenameSession: (sessionId: string, title: string) => void;
  onRemoveSessionFromWorkFolder: (sessionId: string) => void;
  onSelectSession: (title: string, id?: string) => void;
  onTogglePinnedSession: (sessionId: string) => void;
  onUpdateWorkFolder: (
    folderId: string,
    title: string,
    iconId: WorkFolderIconId,
    memory: string,
  ) => void;
  recentSessions: ChatSession[];
  visible: boolean;
  workFolders: WorkFolder[];
  workFolderSessions: ChatSession[];
}) {
  const { height: windowHeight, width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const hiddenSlideX = -Math.max(width, 1);
  const slideX = useRef(new Animated.Value(hiddenSlideX)).current;
  const menuFrameRef = useRef<React.ElementRef<typeof View>>(null);
  const actionMenuAnchorRef = useRef<RecentActionMenuAnchor | null>(null);
  const workFolderActionMenuAnchorRef = useRef<RecentActionMenuAnchor | null>(
    null,
  );
  const [isRendered, setIsRendered] = useState(visible);
  const [actionSheetSession, setActionSheetSession] =
    useState<ChatSession | null>(null);
  const [actionSheetPosition, setActionSheetPosition] =
    useState<RecentActionMenuPosition | null>(null);
  const [actionSheetScope, setActionSheetScope] =
    useState<SessionActionScope>('recent');
  const [workFolderActionSheetFolder, setWorkFolderActionSheetFolder] =
    useState<WorkFolder | null>(null);
  const [workFolderActionSheetPosition, setWorkFolderActionSheetPosition] =
    useState<RecentActionMenuPosition | null>(null);
  const [menuFrameSize, setMenuFrameSize] = useState<RecentActionMenuSize>({
    height: windowHeight,
    width,
  });
  const [recentDialog, setRecentDialog] = useState<RecentSessionDialog | null>(
    null,
  );
  const [renameDraft, setRenameDraft] = useState('');
  const [isWorkFolderDialogOpen, setIsWorkFolderDialogOpen] = useState(false);
  const [workFolderDraft, setWorkFolderDraft] = useState('');
  const [selectedWorkFolderIconId, setSelectedWorkFolderIconId] =
    useState<WorkFolderIconId>(DEFAULT_WORK_FOLDER_ICON_ID);
  const [isWorkFolderIconMenuOpen, setIsWorkFolderIconMenuOpen] =
    useState(false);
  const [selectedWorkFolderId, setSelectedWorkFolderId] = useState<
    string | null
  >(null);
  const [isWorkFolderSelectOpen, setIsWorkFolderSelectOpen] = useState(false);
  const [isSearchDialogOpen, setIsSearchDialogOpen] = useState(false);
  const [searchDraft, setSearchDraft] = useState('');
  const [collapsedWorkFolderIds, setCollapsedWorkFolderIds] = useState<
    Record<string, boolean>
  >({});
  const [workFolderActionDialog, setWorkFolderActionDialog] =
    useState<WorkFolderActionDialog | null>(null);
  const [workFolderActionTitleDraft, setWorkFolderActionTitleDraft] =
    useState('');
  const [workFolderActionMemoryDraft, setWorkFolderActionMemoryDraft] =
    useState('');
  const [workFolderActionIconId, setWorkFolderActionIconId] =
    useState<WorkFolderIconId>(DEFAULT_WORK_FOLDER_ICON_ID);
  const [isWorkFolderActionIconMenuOpen, setIsWorkFolderActionIconMenuOpen] =
    useState(false);

  const workFolderSelectOptions = useMemo<FloatingSelectOption<string>[]>(
    () =>
      workFolders.map(folder => ({
        icon: getWorkFolderIcon(folder.iconId),
        label: folder.title,
        value: folder.id,
      })),
    [workFolders],
  );
  const workFolderSessionsByFolderId = useMemo(
    () =>
      workFolderSessions.reduce<Record<string, ChatSession[]>>(
        (sessionsByFolderId, session) => {
          if (!session.workFolderId) {
            return sessionsByFolderId;
          }

          return {
            ...sessionsByFolderId,
            [session.workFolderId]: [
              ...(sessionsByFolderId[session.workFolderId] ?? []),
              session,
            ],
          };
        },
        {},
      ),
    [workFolderSessions],
  );

  const searchResults = useMemo(() => {
    const query = searchDraft.trim().toLowerCase();
    const candidates: MenuSearchResult[] = [
      ...workFolders.map(folder => ({
        iconId: folder.iconId ?? DEFAULT_WORK_FOLDER_ICON_ID,
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
    setCollapsedWorkFolderIds(current => {
      const nextCollapsedFolderIds: Record<string, boolean> = {};
      workFolders.forEach(folder => {
        if (current[folder.id]) {
          nextCollapsedFolderIds[folder.id] = true;
        }
      });

      return nextCollapsedFolderIds;
    });
  }, [workFolders]);

  useEffect(() => {
    if (recentDialog?.type !== 'move') {
      return;
    }

    if (workFolders.length === 0) {
      setSelectedWorkFolderId(null);
      setIsWorkFolderSelectOpen(false);
      return;
    }

    setSelectedWorkFolderId(current => {
      if (current && workFolders.some(folder => folder.id === current)) {
        return current;
      }

      return workFolders[0].id;
    });
  }, [recentDialog?.type, workFolders]);

  useEffect(() => {
    if (visible) {
      setIsRendered(true);
      return;
    }

    if (!isRendered) {
      return;
    }

    slideX.stopAnimation();
    Animated.timing(slideX, {
      duration: 210,
      easing: Easing.in(Easing.cubic),
      toValue: hiddenSlideX,
      useNativeDriver: true,
    }).start(({ finished }) => {
      if (finished) {
        setIsRendered(false);
      }
    });
  }, [hiddenSlideX, isRendered, slideX, visible]);

  useEffect(() => {
    if (!visible || !isRendered) {
      return undefined;
    }

    slideX.stopAnimation();
    slideX.setValue(hiddenSlideX);

    const frameId = requestAnimationFrame(() => {
      Animated.timing(slideX, {
        duration: 280,
        easing: Easing.out(Easing.cubic),
        toValue: 0,
        useNativeDriver: true,
      }).start();
    });

    return () => {
      cancelAnimationFrame(frameId);
    };
  }, [hiddenSlideX, isRendered, slideX, visible]);

  useEffect(() => {
    if (visible) {
      return;
    }

    setActionSheetSession(null);
    setActionSheetPosition(null);
    setActionSheetScope('recent');
    actionMenuAnchorRef.current = null;
    setWorkFolderActionSheetFolder(null);
    setWorkFolderActionSheetPosition(null);
    workFolderActionMenuAnchorRef.current = null;
    setRecentDialog(null);
    setRenameDraft('');
    setIsWorkFolderDialogOpen(false);
    setWorkFolderDraft('');
    setSelectedWorkFolderIconId(DEFAULT_WORK_FOLDER_ICON_ID);
    setIsWorkFolderIconMenuOpen(false);
    setSelectedWorkFolderId(null);
    setIsWorkFolderSelectOpen(false);
    setIsSearchDialogOpen(false);
    setSearchDraft('');
    setWorkFolderActionDialog(null);
    setWorkFolderActionTitleDraft('');
    setWorkFolderActionMemoryDraft('');
    setWorkFolderActionIconId(DEFAULT_WORK_FOLDER_ICON_ID);
    setIsWorkFolderActionIconMenuOpen(false);
  }, [visible]);

  if (!isRendered) {
    return null;
  }

  const clamp = (value: number, minimum: number, maximum: number) =>
    Math.min(Math.max(value, minimum), Math.max(minimum, maximum));

  const getBoundedActionMenuPosition = (
    anchor: RecentActionMenuAnchor,
    size: RecentActionMenuSize = {
      height: RECENT_ACTION_MENU_HEIGHT,
      width: RECENT_ACTION_MENU_WIDTH,
    },
  ): RecentActionMenuPosition => {
    const frameWidth = menuFrameSize.width || width;
    const frameHeight = menuFrameSize.height || windowHeight;
    const maxLeft = frameWidth - size.width - RECENT_ACTION_MENU_EDGE_GAP;
    const maxTop = frameHeight - size.height - RECENT_ACTION_MENU_EDGE_GAP;

    let left = anchor.x + RECENT_ACTION_MENU_OFFSET;
    if (left > maxLeft) {
      left = anchor.x - size.width - RECENT_ACTION_MENU_OFFSET;
    }
    if (left < RECENT_ACTION_MENU_EDGE_GAP || left > maxLeft) {
      left = anchor.x - size.width / 2;
    }

    let top = anchor.y + RECENT_ACTION_MENU_OFFSET;
    if (top > maxTop) {
      top = anchor.y - size.height - RECENT_ACTION_MENU_OFFSET;
    }
    if (top < RECENT_ACTION_MENU_EDGE_GAP || top > maxTop) {
      top = anchor.y - size.height / 2;
    }

    return {
      left: clamp(left, RECENT_ACTION_MENU_EDGE_GAP, maxLeft),
      top: clamp(top, RECENT_ACTION_MENU_EDGE_GAP, maxTop),
    };
  };

  const closeRecentActionMenu = () => {
    setActionSheetSession(null);
    setActionSheetPosition(null);
    setActionSheetScope('recent');
    actionMenuAnchorRef.current = null;
  };

  const closeWorkFolderActionMenu = () => {
    setWorkFolderActionSheetFolder(null);
    setWorkFolderActionSheetPosition(null);
    workFolderActionMenuAnchorRef.current = null;
  };

  const closeFloatingActionMenus = () => {
    closeRecentActionMenu();
    closeWorkFolderActionMenu();
  };

  const handleMenuFrameLayout = (event: LayoutChangeEvent) => {
    const { height, width: frameWidth } = event.nativeEvent.layout;
    setMenuFrameSize({ height, width: frameWidth });
  };

  const handleRecentActionMenuLayout = (event: LayoutChangeEvent) => {
    const anchor = actionMenuAnchorRef.current;
    if (!anchor) {
      return;
    }

    const nextPosition = getBoundedActionMenuPosition(anchor, {
      height: event.nativeEvent.layout.height,
      width: event.nativeEvent.layout.width,
    });

    setActionSheetPosition(current => {
      if (
        current &&
        Math.abs(current.left - nextPosition.left) < 1 &&
        Math.abs(current.top - nextPosition.top) < 1
      ) {
        return current;
      }

      return nextPosition;
    });
  };

  const handleWorkFolderActionMenuLayout = (event: LayoutChangeEvent) => {
    const anchor = workFolderActionMenuAnchorRef.current;
    if (!anchor) {
      return;
    }

    const nextPosition = getBoundedActionMenuPosition(anchor, {
      height: event.nativeEvent.layout.height,
      width: event.nativeEvent.layout.width,
    });

    setWorkFolderActionSheetPosition(current => {
      if (
        current &&
        Math.abs(current.left - nextPosition.left) < 1 &&
        Math.abs(current.top - nextPosition.top) < 1
      ) {
        return current;
      }

      return nextPosition;
    });
  };

  const handleOpenRecentActionMenu = (
    event: GestureResponderEvent,
    session: ChatSession,
    scope: SessionActionScope = 'recent',
  ) => {
    const { pageX, pageY } = event.nativeEvent;
    const fallbackAnchor = { x: pageX, y: pageY };

    const openMenu = (anchor: RecentActionMenuAnchor) => {
      closeWorkFolderActionMenu();
      const menuSize =
        scope === 'workFolder'
          ? {
              height: WORK_FOLDER_SESSION_ACTION_MENU_HEIGHT,
              width: RECENT_ACTION_MENU_WIDTH,
            }
          : undefined;
      actionMenuAnchorRef.current = anchor;
      setActionSheetPosition(getBoundedActionMenuPosition(anchor, menuSize));
      setActionSheetScope(scope);
      setActionSheetSession(session);
    };

    if (!menuFrameRef.current?.measureInWindow) {
      openMenu(fallbackAnchor);
      return;
    }

    menuFrameRef.current.measureInWindow((frameX, frameY) => {
      openMenu({
        x: pageX - frameX,
        y: pageY - frameY,
      });
    });
  };

  const handleOpenWorkFolderActionMenu = (
    event: GestureResponderEvent,
    folder: WorkFolder,
  ) => {
    const { pageX, pageY } = event.nativeEvent;
    const fallbackAnchor = { x: pageX, y: pageY };

    const openMenu = (anchor: RecentActionMenuAnchor) => {
      closeRecentActionMenu();
      workFolderActionMenuAnchorRef.current = anchor;
      setWorkFolderActionSheetPosition(
        getBoundedActionMenuPosition(anchor, {
          height: WORK_FOLDER_ACTION_MENU_HEIGHT,
          width: RECENT_ACTION_MENU_WIDTH,
        }),
      );
      setWorkFolderActionSheetFolder(folder);
    };

    if (!menuFrameRef.current?.measureInWindow) {
      openMenu(fallbackAnchor);
      return;
    }

    menuFrameRef.current.measureInWindow((frameX, frameY) => {
      openMenu({
        x: pageX - frameX,
        y: pageY - frameY,
      });
    });
  };

  const handleOpenSettingsFromMenu = () => {
    closeFloatingActionMenus();
    onOpenSettings();
    setIsRendered(false);
  };

  const handleOpenRecentDialog = (
    type: RecentSessionDialog['type'],
    session: ChatSession,
  ) => {
    closeFloatingActionMenus();
    setRecentDialog({ session, type } as RecentSessionDialog);
    setRenameDraft(session.title);
    setIsWorkFolderSelectOpen(false);
    setSelectedWorkFolderId(
      type === 'move' ? workFolders[0]?.id ?? null : null,
    );
  };

  const handleCloseRecentDialog = () => {
    setRecentDialog(null);
    setRenameDraft('');
    setSelectedWorkFolderId(null);
    setIsWorkFolderSelectOpen(false);
  };

  const handleOpenSearchDialog = () => {
    closeFloatingActionMenus();
    setIsSearchDialogOpen(true);
  };

  const handleCloseSearchDialog = () => {
    setIsSearchDialogOpen(false);
    setSearchDraft('');
  };

  const handleSelectSearchResult = (result: MenuSearchResult) => {
    handleCloseSearchDialog();
    if (result.type === 'folder') {
      setCollapsedWorkFolderIds(current => omitRecordKey(current, result.id));
      return;
    }

    onSelectSession(result.title, result.id);
  };

  const handleOpenWorkFolderDialog = () => {
    closeFloatingActionMenus();
    setSelectedWorkFolderIconId(DEFAULT_WORK_FOLDER_ICON_ID);
    setIsWorkFolderIconMenuOpen(false);
    setIsWorkFolderDialogOpen(true);
  };

  const handleCloseWorkFolderDialog = () => {
    setIsWorkFolderDialogOpen(false);
    setWorkFolderDraft('');
    setSelectedWorkFolderIconId(DEFAULT_WORK_FOLDER_ICON_ID);
    setIsWorkFolderIconMenuOpen(false);
  };

  const handleSubmitWorkFolder = () => {
    const nextTitle = workFolderDraft.trim();
    if (!nextTitle) {
      return;
    }

    onCreateWorkFolder(nextTitle, selectedWorkFolderIconId);
    handleCloseWorkFolderDialog();
  };

  const handleToggleWorkFolderCollapsed = (folderId: string) => {
    closeFloatingActionMenus();
    setCollapsedWorkFolderIds(current => ({
      ...current,
      [folderId]: !current[folderId],
    }));
  };

  const handleOpenWorkFolderActionDialog = (
    type: WorkFolderActionDialog['type'],
    folder: WorkFolder,
  ) => {
    closeFloatingActionMenus();
    setWorkFolderActionDialog({ folder, type } as WorkFolderActionDialog);
    setWorkFolderActionTitleDraft(folder.title);
    setWorkFolderActionMemoryDraft(folder.memory ?? '');
    setWorkFolderActionIconId(folder.iconId ?? DEFAULT_WORK_FOLDER_ICON_ID);
    setIsWorkFolderActionIconMenuOpen(false);
  };

  const handleCloseWorkFolderActionDialog = () => {
    setWorkFolderActionDialog(null);
    setWorkFolderActionTitleDraft('');
    setWorkFolderActionMemoryDraft('');
    setWorkFolderActionIconId(DEFAULT_WORK_FOLDER_ICON_ID);
    setIsWorkFolderActionIconMenuOpen(false);
  };

  const handleSubmitWorkFolderSettings = () => {
    if (workFolderActionDialog?.type !== 'settings') {
      return;
    }

    const nextTitle = workFolderActionTitleDraft.trim();
    if (!nextTitle) {
      return;
    }

    onUpdateWorkFolder(
      workFolderActionDialog.folder.id,
      nextTitle,
      workFolderActionIconId,
      workFolderActionMemoryDraft,
    );
    handleCloseWorkFolderActionDialog();
  };

  const handleConfirmWorkFolderDelete = () => {
    if (workFolderActionDialog?.type !== 'delete') {
      return;
    }

    onDeleteWorkFolder(workFolderActionDialog.folder.id);
    setCollapsedWorkFolderIds(current =>
      omitRecordKey(current, workFolderActionDialog.folder.id),
    );
    handleCloseWorkFolderActionDialog();
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
    if (recentDialog?.type !== 'move' || !selectedWorkFolderId) {
      return;
    }

    onMoveSessionToWorkFolder(recentDialog.session.id, selectedWorkFolderId);
    handleCloseRecentDialog();
  };

  const handleConfirmDelete = () => {
    if (recentDialog?.type !== 'delete') {
      return;
    }

    onDeleteSession(recentDialog.session.id);
    handleCloseRecentDialog();
  };

  const isRecentDialogPrimaryDisabled =
    (recentDialog?.type === 'rename' && !renameDraft.trim()) ||
    (recentDialog?.type === 'move' && !selectedWorkFolderId);
  const isWorkFolderActionPrimaryDisabled =
    workFolderActionDialog?.type === 'settings' &&
    !workFolderActionTitleDraft.trim();
  const menuSafeAreaStyle = {
    paddingBottom: Platform.OS === 'ios' ? insets.bottom : 0,
    paddingTop: Platform.OS === 'ios' ? insets.top : 0,
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
        <SafeAreaView
          edges={['left', 'right']}
          style={[styles.menuSafeArea, menuSafeAreaStyle]}
        >
          <View
            onLayout={handleMenuFrameLayout}
            ref={menuFrameRef}
            style={styles.menuFrame}
          >
            <View style={styles.menuBackground} />

            <View style={styles.menuHeader}>
              <Pressable
                accessibilityLabel="새 채팅 시작"
                accessibilityRole="button"
                hitSlop={8}
                onPress={onNewChat}
                style={({ pressed }) => [
                  styles.menuHeaderLogoButton,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <Image
                  accessible={false}
                  accessibilityIgnoresInvertColors
                  resizeMode="contain"
                  source={brandAssets.logo}
                  style={styles.menuHeaderLogo}
                />
              </Pressable>
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
              onScrollBeginDrag={closeFloatingActionMenus}
              showsVerticalScrollIndicator={false}
            >
              <View style={styles.menuPrimaryList}>
                {mainMenuRows.map(row => (
                  <MenuRow
                    icon={row.icon}
                    key={row.label}
                    label={row.label}
                    onPress={() => onSelectSession(row.label)}
                  />
                ))}
              </View>

              <View style={styles.menuSectionBlock}>
                <View style={styles.menuSectionHeader}>
                  <Text
                    style={[
                      styles.menuSectionTitle,
                      styles.menuSectionHeaderTitle,
                    ]}
                  >
                    작업 폴더
                  </Text>
                  <Pressable
                    accessibilityLabel="새 작업 폴더"
                    accessibilityRole="button"
                    onPress={handleOpenWorkFolderDialog}
                    style={({ pressed }) => [
                      styles.menuSectionAddButton,
                      pressed && styles.menuButtonPressed,
                    ]}
                  >
                    <AppIcon
                      color={colors.foreground}
                      icon={appIcons.plus}
                      size={15}
                    />
                  </Pressable>
                </View>
                <View style={styles.workFolderTree}>
                  {workFolders.map(folder => {
                    const folderSessions =
                      workFolderSessionsByFolderId[folder.id] ?? [];
                    const isExpanded = !collapsedWorkFolderIds[folder.id];
                    const isActionMenuOpen =
                      workFolderActionSheetFolder?.id === folder.id;

                    return (
                      <View key={folder.id} style={styles.workFolderTreeItem}>
                        <WorkFolderTreeRow
                          expanded={isExpanded}
                          folder={folder}
                          isActionMenuOpen={isActionMenuOpen}
                          onLongPress={event =>
                            handleOpenWorkFolderActionMenu(event, folder)
                          }
                          onPress={() =>
                            handleToggleWorkFolderCollapsed(folder.id)
                          }
                          sessionCount={folderSessions.length}
                        />
                        {isExpanded && folderSessions.length > 0 ? (
                          <View style={styles.workFolderTreeChildren}>
                            {folderSessions.map(session => (
                              <TreeSessionRow
                                isActionMenuOpen={
                                  actionSheetScope === 'workFolder' &&
                                  actionSheetSession?.id === session.id
                                }
                                key={session.id}
                                label={session.title}
                                onLongPress={event =>
                                  handleOpenRecentActionMenu(
                                    event,
                                    session,
                                    'workFolder',
                                  )
                                }
                                onPress={() => {
                                  closeFloatingActionMenus();
                                  onSelectSession(session.title, session.id);
                                }}
                              />
                            ))}
                          </View>
                        ) : null}
                      </View>
                    );
                  })}
                </View>
                {workFolderSessions
                  .filter(session => !session.workFolderId)
                  .map(session => (
                    <MenuRow
                      icon={appIcons.session}
                      iconColor={colors.mutedForeground}
                      key={session.id}
                      label={session.title}
                      onPress={() => onSelectSession(session.title, session.id)}
                    />
                  ))}
              </View>

              <View style={[styles.menuSectionBlock, styles.menuRecentSection]}>
                <Text style={styles.menuSectionTitle}>최근</Text>
                {recentSessions.map(session => {
                  const isActionMenuOpen =
                    actionSheetScope === 'recent' &&
                    actionSheetSession?.id === session.id;

                  return (
                    <View key={session.id} style={styles.menuRecentItem}>
                      <Pressable
                        accessibilityRole="button"
                        delayLongPress={360}
                        onLongPress={event =>
                          handleOpenRecentActionMenu(event, session)
                        }
                        onPress={() => {
                          closeRecentActionMenu();
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
                    </View>
                  );
                })}
              </View>
            </ScrollView>

            {actionSheetSession && actionSheetPosition ? (
              <View pointerEvents="box-none" style={styles.recentActionLayer}>
                <Pressable
                  accessibilityLabel="채팅 세션 메뉴 닫기"
                  onPress={closeRecentActionMenu}
                  style={styles.recentActionBackdrop}
                />
                <View
                  onLayout={handleRecentActionMenuLayout}
                  style={[
                    styles.recentFloatingActionMenu,
                    {
                      left: actionSheetPosition.left,
                      top: actionSheetPosition.top,
                    },
                  ]}
                >
                  <RecentActionButton
                    icon={appIcons.rename}
                    label="이름 바꾸기"
                    onPress={() =>
                      handleOpenRecentDialog('rename', actionSheetSession)
                    }
                  />
                  {actionSheetScope === 'recent' ? (
                    <RecentActionButton
                      icon={appIcons.pin}
                      label={
                        actionSheetSession.pinned
                          ? '채팅 고정 해제'
                          : '채팅 고정'
                      }
                      onPress={() => {
                        onTogglePinnedSession(actionSheetSession.id);
                        closeRecentActionMenu();
                      }}
                    />
                  ) : null}
                  {actionSheetScope === 'workFolder' ? (
                    <RecentActionButton
                      icon={appIcons.moveToFolder}
                      label="작업 폴더에서 제거"
                      onPress={() => {
                        onRemoveSessionFromWorkFolder(actionSheetSession.id);
                        closeRecentActionMenu();
                      }}
                    />
                  ) : (
                    <RecentActionButton
                      icon={appIcons.moveToFolder}
                      label="작업 폴더로 이동"
                      onPress={() =>
                        handleOpenRecentDialog('move', actionSheetSession)
                      }
                    />
                  )}
                  <RecentActionButton
                    destructive
                    icon={appIcons.delete}
                    label="삭제"
                    onPress={() =>
                      handleOpenRecentDialog('delete', actionSheetSession)
                    }
                  />
                </View>
              </View>
            ) : null}

            {workFolderActionSheetFolder && workFolderActionSheetPosition ? (
              <View pointerEvents="box-none" style={styles.recentActionLayer}>
                <Pressable
                  accessibilityLabel="작업 폴더 메뉴 닫기"
                  onPress={closeWorkFolderActionMenu}
                  style={styles.recentActionBackdrop}
                />
                <View
                  onLayout={handleWorkFolderActionMenuLayout}
                  style={[
                    styles.recentFloatingActionMenu,
                    {
                      left: workFolderActionSheetPosition.left,
                      top: workFolderActionSheetPosition.top,
                    },
                  ]}
                >
                  <RecentActionButton
                    icon={appIcons.settings}
                    label="작업 폴더 설정"
                    onPress={() =>
                      handleOpenWorkFolderActionDialog(
                        'settings',
                        workFolderActionSheetFolder,
                      )
                    }
                  />
                  <RecentActionButton
                    destructive
                    icon={appIcons.delete}
                    label="삭제"
                    onPress={() =>
                      handleOpenWorkFolderActionDialog(
                        'delete',
                        workFolderActionSheetFolder,
                      )
                    }
                  />
                </View>
              </View>
            ) : null}

            {!isWorkFolderDialogOpen &&
            !recentDialog &&
            !isSearchDialogOpen &&
            !workFolderActionDialog ? (
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
                <View
                  style={[styles.recentDialogCard, styles.searchDialogCard]}
                >
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
                                  ? getWorkFolderIcon(result.iconId)
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
                  <FloatingSelect
                    accessibilityLabel="작업 폴더 아이콘 변경"
                    expanded={isWorkFolderIconMenuOpen}
                    onExpandedChange={setIsWorkFolderIconMenuOpen}
                    onValueChange={setSelectedWorkFolderIconId}
                    options={workFolderIconOptions}
                    selectedValue={selectedWorkFolderIconId}
                    triggerIconSize={17}
                    variant="compact"
                  >
                    <RNTextInput
                      accessibilityLabel="작업 폴더 이름"
                      autoFocus
                      onChangeText={setWorkFolderDraft}
                      placeholder="작업 폴더 이름"
                      placeholderTextColor={colors.mutedForeground}
                      returnKeyType="done"
                      style={[
                        styles.recentDialogInput,
                        styles.workFolderNameInput,
                      ]}
                      value={workFolderDraft}
                    />
                  </FloatingSelect>
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

            {workFolderActionDialog ? (
              <View style={styles.recentDialogLayer}>
                <Pressable
                  accessibilityLabel="작업 폴더 작업 닫기"
                  onPress={handleCloseWorkFolderActionDialog}
                  style={styles.recentDialogBackdrop}
                />
                <View style={styles.recentDialogCard}>
                  <Text style={styles.recentDialogTitle}>
                    {workFolderActionDialog.type === 'settings'
                      ? '작업 폴더 설정'
                      : '작업 폴더 삭제'}
                  </Text>
                  {workFolderActionDialog.type === 'settings' ? (
                    <View>
                      <Text style={styles.workFolderSettingsLabel}>
                        이름과 아이콘
                      </Text>
                      <FloatingSelect
                        accessibilityLabel="작업 폴더 아이콘 변경"
                        expanded={isWorkFolderActionIconMenuOpen}
                        onExpandedChange={setIsWorkFolderActionIconMenuOpen}
                        onValueChange={setWorkFolderActionIconId}
                        options={workFolderIconOptions}
                        selectedValue={workFolderActionIconId}
                        triggerIconSize={17}
                        variant="compact"
                      >
                        <RNTextInput
                          accessibilityLabel="작업 폴더 이름"
                          autoFocus
                          onChangeText={setWorkFolderActionTitleDraft}
                          onSubmitEditing={handleSubmitWorkFolderSettings}
                          placeholder="작업 폴더 이름"
                          placeholderTextColor={colors.mutedForeground}
                          returnKeyType="done"
                          style={[
                            styles.recentDialogInput,
                            styles.workFolderNameInput,
                          ]}
                          value={workFolderActionTitleDraft}
                        />
                      </FloatingSelect>
                      <Text style={styles.workFolderSettingsLabel}>
                        시스템 프롬프트(메모리)
                      </Text>
                      <RNTextInput
                        accessibilityLabel="작업 폴더 메모리"
                        multiline
                        onChangeText={setWorkFolderActionMemoryDraft}
                        placeholder="이 작업 폴더의 모든 채팅에 추가로 적용할 시스템 프롬프트"
                        placeholderTextColor={colors.mutedForeground}
                        style={[
                          styles.recentDialogInput,
                          styles.workFolderMemoryInput,
                        ]}
                        textAlignVertical="top"
                        value={workFolderActionMemoryDraft}
                      />
                      <Text style={styles.workFolderSettingsHelp}>
                        개인 시스템 프롬프트가 먼저 적용되고, 이 내용은 그
                        아래에 작업 폴더 지침으로 전달됩니다.
                      </Text>
                    </View>
                  ) : (
                    <Text style={styles.recentDialogMessage}>
                      이 작업 폴더를 삭제할까요? 폴더 안의 채팅은 최근 목록으로
                      이동합니다.
                    </Text>
                  )}
                  <View style={styles.recentDialogActions}>
                    <Pressable
                      accessibilityRole="button"
                      onPress={handleCloseWorkFolderActionDialog}
                      style={({ pressed }) => [
                        styles.recentDialogButton,
                        pressed && styles.menuButtonPressed,
                      ]}
                    >
                      <Text style={styles.recentDialogCancelText}>취소</Text>
                    </Pressable>
                    <Pressable
                      accessibilityRole="button"
                      disabled={isWorkFolderActionPrimaryDisabled}
                      onPress={
                        workFolderActionDialog.type === 'settings'
                          ? handleSubmitWorkFolderSettings
                          : handleConfirmWorkFolderDelete
                      }
                      style={({ pressed }) => [
                        styles.recentDialogButton,
                        styles.recentDialogPrimaryButton,
                        workFolderActionDialog.type === 'delete' &&
                          styles.recentDialogDeleteButton,
                        pressed && styles.menuButtonPressed,
                        isWorkFolderActionPrimaryDisabled &&
                          styles.recentDialogButtonDisabled,
                      ]}
                    >
                      <Text style={styles.recentDialogPrimaryText}>
                        {workFolderActionDialog.type === 'settings'
                          ? '적용'
                          : '삭제'}
                      </Text>
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
                  ) : recentDialog.type === 'move' ? (
                    <View>
                      <Text style={styles.recentDialogMessage}>
                        최근 목록에서 제거하고 선택한 작업 폴더에 추가합니다.
                      </Text>
                      <View style={styles.workFolderSelectBlock}>
                        <Text style={styles.workFolderSelectLabel}>
                          이동할 작업 폴더
                        </Text>
                        <FloatingSelect
                          accessibilityLabel="작업 폴더 선택"
                          disabled={workFolders.length === 0}
                          expanded={isWorkFolderSelectOpen}
                          menuStyle={styles.workFolderSelectMenu}
                          onExpandedChange={setIsWorkFolderSelectOpen}
                          onValueChange={setSelectedWorkFolderId}
                          options={workFolderSelectOptions}
                          placeholder="작업 폴더 없음"
                          placeholderIcon={appIcons.folder}
                          selectedValue={selectedWorkFolderId}
                        />
                        {workFolders.length === 0 ? (
                          <Text style={styles.workFolderSelectHelp}>
                            새 작업 폴더를 먼저 만들어주세요.
                          </Text>
                        ) : null}
                      </View>
                    </View>
                  ) : (
                    <Text style={styles.recentDialogMessage}>
                      이 채팅 세션을 삭제할까요? 삭제 후에는 목록에서
                      사라집니다.
                    </Text>
                  )}
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
                      disabled={isRecentDialogPrimaryDisabled}
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
                        isRecentDialogPrimaryDisabled &&
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
          </View>
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

function WorkFolderTreeRow({
  expanded,
  folder,
  isActionMenuOpen,
  onLongPress,
  onPress,
  sessionCount,
}: {
  expanded: boolean;
  folder: WorkFolder;
  isActionMenuOpen: boolean;
  onLongPress: (event: GestureResponderEvent) => void;
  onPress: () => void;
  sessionCount: number;
}) {
  return (
    <Pressable
      accessibilityLabel={`${folder.title} 작업 폴더`}
      accessibilityRole="button"
      accessibilityState={{ expanded }}
      delayLongPress={360}
      onLongPress={onLongPress}
      onPress={onPress}
      style={({ pressed }) => [
        styles.workFolderTreeRow,
        isActionMenuOpen && styles.menuRecentRowActive,
        pressed && styles.menuRowPressed,
      ]}
    >
      <View style={styles.workFolderTreeIconSlot}>
        <View style={styles.workFolderTreeChevron}>
          <AppIcon
            color={colors.mutedForeground}
            icon={expanded ? appIcons.chevronDown : appIcons.openPrompt}
            size={12}
          />
        </View>
        <View style={styles.workFolderTreeIcon}>
          <AppIcon
            color={colors.foreground}
            icon={getWorkFolderIcon(folder.iconId)}
            size={18}
          />
        </View>
      </View>
      <Text numberOfLines={1} style={styles.workFolderTreeLabel}>
        {folder.title}
      </Text>
      {sessionCount > 0 ? (
        <Text style={styles.workFolderTreeCount}>{sessionCount}</Text>
      ) : null}
    </Pressable>
  );
}

function TreeSessionRow({
  isActionMenuOpen,
  label,
  onLongPress,
  onPress,
}: {
  isActionMenuOpen: boolean;
  label: string;
  onLongPress: (event: GestureResponderEvent) => void;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      delayLongPress={360}
      onLongPress={onLongPress}
      onPress={onPress}
      style={({ pressed }) => [
        styles.workFolderChildRow,
        isActionMenuOpen && styles.menuRecentRowActive,
        pressed && styles.menuRowPressed,
      ]}
    >
      <View style={styles.workFolderChildIcon}>
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.session}
          size={15}
        />
      </View>
      <Text numberOfLines={1} style={styles.workFolderChildLabel}>
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
