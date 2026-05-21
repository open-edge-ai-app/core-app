import AsyncStorage from '@react-native-async-storage/async-storage';
import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  ActivityIndicator,
  Pressable,
  StatusBar,
  Text as RNText,
  TextInput as RNTextInput,
  View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

import AppIcon from './src/components/AppIcon';
import type { FloatingSelectOption } from './src/components/FloatingSelect';
import PastelBackground from './src/components/PastelBackground';
import AIEngine, { ModelStatus } from './src/native/AIEngine';
import ChatScreen, {
  ChatMessage,
  createInitialChatMessages,
} from './src/screens/ChatScreen';
import Settings, {
  type PersonalCustomizationSettings,
  type SettingsPanelId,
} from './src/screens/Settings';
import TodoListScreen from './src/screens/TodoListScreen';
import {
  ChatSession,
  hydrateMessages,
  loadNativeChatSnapshots,
  mergeSessionLists,
  serializeMessages,
  shouldUseNativeMessages,
  toStoredChatMessages,
} from './src/state/chatStorage';
import { createCommonSystemPrompt } from './src/state/systemPrompt';
import {
  DisplaySettingsProvider,
  ScaledText as Text,
} from './src/theme/display';
import { appIcons } from './src/theme/icons';
import { colors } from './src/theme/tokens';
import { I18nProvider, useI18n } from './src/i18n';
import {
  APP_STATE_STORAGE_KEY,
  DEFAULT_WORK_FOLDER_ICON_ID,
  TITLE_TYPING_INTERVAL_MS,
  createChatSessionId,
  createPersonalSystemPrompt,
  defaultDownloadableModelOption,
  defaultPersonalCustomizationSettings,
  defaultSelectedModelId,
  getModelStatusForId,
  initialRecentSessions,
  isSystemManagedModel,
  modelManageOption,
  modelOptions,
  omitRecordKey,
  parseStoredAppState,
  visibleHeaderModelOptions,
  type ModelOption,
  type ModelStateSnapshot,
  type PersistedAppState,
  type SessionTitleChangeOptions,
  type WorkFolder,
  type WorkFolderIconId,
} from './src/app/appConfig';
import FullScreenMenu from './src/app/AppMenu';
import { styles } from './src/app/appStyles';

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

function AppContent() {
  const { t } = useI18n();
  const activeSessionIdRef = useRef<string | null>(null);
  const pendingWorkFolderIdRef = useRef<string | null>(null);
  const titleAnimationTimerRef = useRef<ReturnType<typeof setInterval> | null>(
    null,
  );
  const pendingTitleAnimationRef = useRef<{
    sessionId: string;
    title: string;
  } | null>(null);
  const [isAppStateHydrated, setIsAppStateHydrated] = useState(false);
  const [sessionTitle, setSessionTitle] = useState('새 채팅');
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [recentSessions, setRecentSessions] = useState<ChatSession[]>(
    initialRecentSessions,
  );
  const [workFolderSessions, setWorkFolderSessions] = useState<ChatSession[]>(
    [],
  );
  const [workFolders, setWorkFolders] = useState<WorkFolder[]>([]);
  const [pendingWorkFolderId, setPendingWorkFolderId] = useState<string | null>(
    null,
  );
  const [chatMessagesBySessionId, setChatMessagesBySessionId] = useState<
    Record<string, ChatMessage[]>
  >({});
  const [draftChatMessages, setDraftChatMessages] = useState<ChatMessage[]>(
    createInitialChatMessages,
  );
  const [personalCustomization, setPersonalCustomization] =
    useState<PersonalCustomizationSettings>(
      defaultPersonalCustomizationSettings,
    );
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isModelMenuOpen, setIsModelMenuOpen] = useState(false);
  const [chatInstanceKey, setChatInstanceKey] = useState(0);
  const [activeScreen, setActiveScreen] = useState<
    'chat' | 'settings' | 'todo'
  >('chat');
  const [settingsPanel, setSettingsPanel] = useState<SettingsPanelId>('root');
  const [selectedModelId, setSelectedModelId] = useState<ModelOption['id']>(
    defaultSelectedModelId,
  );
  const [modelStatus, setModelStatus] = useState<ModelStatus | null>(null);
  const [modelStatuses, setModelStatuses] = useState<ModelStatus[]>([]);
  const [isModelDownloadStarting, setIsModelDownloadStarting] = useState(false);

  const handleModelStateChange = useCallback(
    ({
      modelStatus: nextModelStatus,
      modelStatuses: nextModelStatuses,
    }: ModelStateSnapshot) => {
      setModelStatus(nextModelStatus);
      if (nextModelStatuses) {
        setModelStatuses(nextModelStatuses);
      } else if (nextModelStatus) {
        setModelStatuses(currentStatuses => {
          const nextModelId = nextModelStatus.modelId ?? selectedModelId;
          const remainingStatuses = currentStatuses.filter(
            status => status.modelId !== nextModelId,
          );
          return [...remainingStatuses, nextModelStatus];
        });
      }
    },
    [selectedModelId],
  );

  const refreshModelState = useCallback(async () => {
    const nextModelStatuses = await AIEngine.getModelStatuses();
    const nextModelStatus =
      getModelStatusForId(nextModelStatuses, selectedModelId) ??
      nextModelStatuses[0] ??
      null;
    handleModelStateChange({
      modelStatus: nextModelStatus,
      modelStatuses: nextModelStatuses,
      runtimeStatus: null,
    });
  }, [handleModelStateChange, selectedModelId]);

  const selectedModel = useMemo(
    () =>
      modelOptions.find(
        model => model.id === selectedModelId && model.action !== 'settings',
      ) ?? modelOptions[0],
    [selectedModelId],
  );
  const headerSelectedModelId = selectedModel.id;
  const headerModelLabel = selectedModel.label;
  const isSettingsDetailPanel =
    activeScreen === 'settings' && settingsPanel !== 'root';

  const handleDownloadModelFromMenu = useCallback(
    async (modelId: ModelOption['id']) => {
      const status = getModelStatusForId(modelStatuses, modelId);

      if (
        modelId === 'manage' ||
        modelId === 'auto' ||
        isSystemManagedModel(modelId, status) ||
        isModelDownloadStarting ||
        status?.installed ||
        status?.isDownloading
      ) {
        return;
      }

      setIsModelDownloadStarting(true);

      try {
        const nextModelStatus = await AIEngine.downloadModel(modelId);
        setModelStatus(nextModelStatus);
        setModelStatuses(currentStatuses => {
          const nextModelId = nextModelStatus.modelId ?? modelId;
          const remainingStatuses = currentStatuses.filter(
            currentStatus => currentStatus.modelId !== nextModelId,
          );
          return [...remainingStatuses, nextModelStatus];
        });
      } finally {
        setIsModelDownloadStarting(false);
      }
    },
    [isModelDownloadStarting, modelStatuses],
  );

  const modelSelectOptions = useMemo<
    FloatingSelectOption<ModelOption['id']>[]
  >(() => {
    const visibleModelOptions = [
      ...visibleHeaderModelOptions,
      modelManageOption,
    ];

    return visibleModelOptions.map((model, index) => {
      const status = getModelStatusForId(modelStatuses, model.id);
      const isSystemManaged = isSystemManagedModel(model.id, status);
      const isDownloadableMissingModel =
        !isSystemManaged &&
        model.id === defaultDownloadableModelOption.id &&
        !status?.installed;

      return {
        description: model.detail,
        dividerBefore: index > 0 && model.action === 'settings',
        label: model.label,
        trailingIcon: isDownloadableMissingModel
          ? appIcons.download
          : undefined,
        trailingIconColor: modelStatus?.error
          ? colors.destructive
          : colors.primary,
        value: model.id,
      };
    });
  }, [modelStatus, modelStatuses]);
  const handleModelMenuExpandedChange = useCallback((expanded: boolean) => {
    if (expanded) {
      setIsMenuOpen(false);
    }
    setIsModelMenuOpen(expanded);
  }, []);

  const handleSelectModel = useCallback(
    (modelId: ModelOption['id']) => {
      const nextModel = modelOptions.find(model => model.id === modelId);

      if (!nextModel) {
        return;
      }

      if (nextModel.action === 'settings') {
        setActiveScreen('settings');
        setSettingsPanel('root');
        return;
      }

      setSelectedModelId(modelId);

      const nextStatus = getModelStatusForId(modelStatuses, modelId);
      if (
        !nextStatus?.installed &&
        !isSystemManagedModel(modelId, nextStatus)
      ) {
        handleDownloadModelFromMenu(modelId).catch(() => undefined);
      }
    },
    [handleDownloadModelFromMenu, modelStatuses],
  );

  const handleHeaderModelOptionPress = useCallback(
    (option: FloatingSelectOption<ModelOption['id']>) => {
      if (option.disabled) {
        return;
      }

      const optionStatus = getModelStatusForId(modelStatuses, option.value);
      const isDownloadableMissingModel =
        option.value === defaultDownloadableModelOption.id &&
        !optionStatus?.installed &&
        !isSystemManagedModel(option.value, optionStatus);

      if (isDownloadableMissingModel) {
        if (optionStatus?.isDownloading || isModelDownloadStarting) {
          return;
        }

        setSelectedModelId(option.value);
        handleDownloadModelFromMenu(option.value).catch(() => undefined);
        return;
      }

      handleSelectModel(option.value);
      setIsModelMenuOpen(false);
    },
    [
      handleDownloadModelFromMenu,
      handleSelectModel,
      isModelDownloadStarting,
      modelStatuses,
    ],
  );

  useEffect(() => {
    refreshModelState().catch(() => undefined);
  }, [refreshModelState]);

  useEffect(() => {
    if (isModelMenuOpen) {
      refreshModelState().catch(() => undefined);
    }
  }, [isModelMenuOpen, refreshModelState]);

  useEffect(() => {
    if (!modelStatus?.isDownloading) {
      return;
    }

    const intervalId = setInterval(() => {
      refreshModelState().catch(() => undefined);
    }, 1200);

    return () => clearInterval(intervalId);
  }, [modelStatus?.isDownloading, refreshModelState]);

  useEffect(() => {
    activeSessionIdRef.current = activeSessionId;
  }, [activeSessionId]);

  useEffect(() => {
    let isCancelled = false;

    const hydrateAppState = async () => {
      try {
        const storedState = parseStoredAppState(
          await AsyncStorage.getItem(APP_STATE_STORAGE_KEY),
        );
        const nativeSnapshots = await loadNativeChatSnapshots();

        if (isCancelled) {
          return;
        }

        if (!storedState && nativeSnapshots.length === 0) {
          return;
        }

        const hydratedMessagesBySessionId: Record<string, ChatMessage[]> =
          storedState
            ? Object.fromEntries(
                Object.entries(storedState.chatMessagesBySessionId).map(
                  ([sessionId, messages]) => [
                    sessionId,
                    hydrateMessages(messages),
                  ],
                ),
              )
            : {};

        nativeSnapshots.forEach(({ messages, session }) => {
          if (
            shouldUseNativeMessages(
              hydratedMessagesBySessionId[session.id],
              messages,
            )
          ) {
            hydratedMessagesBySessionId[session.id] = messages;
          }
        });

        const storedRecentSessions =
          storedState?.recentSessions ?? initialRecentSessions;
        const storedWorkFolderSessions = storedState?.workFolderSessions ?? [];
        const storedWorkFolderSessionIds = new Set(
          storedWorkFolderSessions.map(session => session.id),
        );
        const nativeRecentSessions = nativeSnapshots
          .map(snapshot => snapshot.session)
          .filter(session => !storedWorkFolderSessionIds.has(session.id));
        const mergedRecentSessions = mergeSessionLists(
          storedRecentSessions,
          nativeRecentSessions,
        );
        const availableSessionIds = new Set(
          [...mergedRecentSessions, ...storedWorkFolderSessions].map(
            session => session.id,
          ),
        );
        const resolvedActiveSessionId =
          storedState?.activeSessionId &&
          availableSessionIds.has(storedState.activeSessionId)
            ? storedState.activeSessionId
            : nativeSnapshots[0]?.session.id ?? null;
        const resolvedSessionTitle =
          resolvedActiveSessionId == null
            ? storedState?.sessionTitle ?? '새 채팅'
            : [...mergedRecentSessions, ...storedWorkFolderSessions].find(
                session => session.id === resolvedActiveSessionId,
              )?.title ??
              storedState?.sessionTitle ??
              '새 채팅';

        activeSessionIdRef.current = resolvedActiveSessionId;
        setSessionTitle(resolvedSessionTitle);
        setActiveSessionId(resolvedActiveSessionId);
        setRecentSessions(mergedRecentSessions);
        setWorkFolderSessions(storedWorkFolderSessions);
        setWorkFolders(storedState?.workFolders ?? []);
        setSelectedModelId(storedState?.selectedModelId ?? 'gemma-4');
        setPersonalCustomization(
          storedState?.personalCustomization ??
            defaultPersonalCustomizationSettings,
        );
        setChatMessagesBySessionId(hydratedMessagesBySessionId);
        setDraftChatMessages(hydrateMessages(storedState?.draftChatMessages));
      } finally {
        if (!isCancelled) {
          setIsAppStateHydrated(true);
        }
      }
    };

    hydrateAppState();

    return () => {
      isCancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!isAppStateHydrated) {
      return;
    }

    const nextState: PersistedAppState = {
      activeSessionId,
      chatMessagesBySessionId: Object.fromEntries(
        Object.entries(chatMessagesBySessionId).map(([sessionId, messages]) => [
          sessionId,
          serializeMessages(messages),
        ]),
      ),
      draftChatMessages: serializeMessages(draftChatMessages),
      personalCustomization,
      recentSessions,
      selectedModelId,
      sessionTitle,
      version: 1,
      workFolders,
      workFolderSessions,
    };

    AsyncStorage.setItem(
      APP_STATE_STORAGE_KEY,
      JSON.stringify(nextState),
    ).catch(() => undefined);
  }, [
    activeSessionId,
    chatMessagesBySessionId,
    draftChatMessages,
    isAppStateHydrated,
    personalCustomization,
    recentSessions,
    selectedModelId,
    sessionTitle,
    workFolders,
    workFolderSessions,
  ]);

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

  const activeMessages = useMemo(() => {
    if (!activeSessionId) {
      return draftChatMessages;
    }

    return (
      chatMessagesBySessionId[activeSessionId] ?? createInitialChatMessages()
    );
  }, [activeSessionId, chatMessagesBySessionId, draftChatMessages]);

  const activeWorkFolderMemory = useMemo(() => {
    const activeWorkFolderId = activeSessionId
      ? workFolderSessions.find(session => session.id === activeSessionId)
          ?.workFolderId
      : pendingWorkFolderId;

    if (!activeWorkFolderId) {
      return '';
    }

    return (
      workFolders
        .find(folder => folder.id === activeWorkFolderId)
        ?.memory?.trim() ?? ''
    );
  }, [activeSessionId, pendingWorkFolderId, workFolders, workFolderSessions]);

  const activeSystemPrompt = useMemo(
    () =>
      createCommonSystemPrompt(
        createPersonalSystemPrompt(personalCustomization),
        activeWorkFolderMemory,
      ),
    [activeWorkFolderMemory, personalCustomization],
  );

  const stopTitleAnimation = useCallback(() => {
    if (titleAnimationTimerRef.current) {
      clearInterval(titleAnimationTimerRef.current);
      titleAnimationTimerRef.current = null;
    }

    pendingTitleAnimationRef.current = null;
  }, []);

  const applySessionTitle = useCallback(
    (sessionId: string, title: string, options: { persist?: boolean } = {}) => {
      if (activeSessionIdRef.current === sessionId) {
        setSessionTitle(title);
      }

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

      if (options.persist === false) {
        return;
      }

      const currentMessages = chatMessagesBySessionId[sessionId];
      if (currentMessages) {
        AIEngine.saveChatSession(
          sessionId,
          title,
          toStoredChatMessages(currentMessages),
        ).catch(() => undefined);
      }
    },
    [chatMessagesBySessionId],
  );

  const clearTitleAnimation = useCallback(
    (complete = false) => {
      const pendingAnimation = pendingTitleAnimationRef.current;
      stopTitleAnimation();

      if (complete && pendingAnimation) {
        applySessionTitle(pendingAnimation.sessionId, pendingAnimation.title);
      }
    },
    [applySessionTitle, stopTitleAnimation],
  );

  useEffect(() => stopTitleAnimation, [stopTitleAnimation]);

  const handleNewChat = () => {
    clearTitleAnimation(true);
    pendingWorkFolderIdRef.current = null;
    setPendingWorkFolderId(null);
    setActiveScreen('chat');
    setSettingsPanel('root');
    activeSessionIdRef.current = null;
    setActiveSessionId(null);
    setSessionTitle('새 채팅');
    setDraftChatMessages(createInitialChatMessages());
    setChatInstanceKey(current => current + 1);
    setIsMenuOpen(false);
  };

  const handleStartWorkFolderChat = (folderId: string) => {
    const folder = workFolders.find(candidate => candidate.id === folderId);
    if (!folder) {
      return;
    }

    clearTitleAnimation(true);
    pendingWorkFolderIdRef.current = folderId;
    setPendingWorkFolderId(folderId);
    setActiveScreen('chat');
    setSettingsPanel('root');
    activeSessionIdRef.current = null;
    setActiveSessionId(null);
    setSessionTitle('새 채팅');
    setDraftChatMessages(createInitialChatMessages());
    setChatInstanceKey(current => current + 1);
    setIsMenuOpen(false);
  };

  const handleSelectSession = (title: string, id?: string) => {
    clearTitleAnimation(true);
    pendingWorkFolderIdRef.current = null;
    setPendingWorkFolderId(null);
    const isChatSession =
      id != null &&
      (recentSessions.some(session => session.id === id) ||
        workFolderSessions.some(session => session.id === id));

    setActiveScreen('chat');
    setSettingsPanel('root');
    activeSessionIdRef.current = isChatSession ? id : null;
    setActiveSessionId(isChatSession ? id : null);
    if (!isChatSession) {
      setDraftChatMessages(createInitialChatMessages());
    }
    setSessionTitle(title);
    setChatInstanceKey(current => current + 1);
    setIsMenuOpen(false);
  };

  const handleOpenSettings = () => {
    clearTitleAnimation(true);
    pendingWorkFolderIdRef.current = null;
    setPendingWorkFolderId(null);
    setActiveScreen('settings');
    setSettingsPanel('root');
    activeSessionIdRef.current = null;
    setActiveSessionId(null);
    setIsMenuOpen(false);
  };

  const handleOpenTodoList = () => {
    clearTitleAnimation(true);
    pendingWorkFolderIdRef.current = null;
    setPendingWorkFolderId(null);
    setActiveScreen('todo');
    setSettingsPanel('root');
    activeSessionIdRef.current = null;
    setActiveSessionId(null);
    setSessionTitle('Todo List');
    setIsMenuOpen(false);
  };

  const handleChatMessagesChange = useCallback(
    (
      nextMessages: ChatMessage[],
      sessionTitleCandidate?: string,
      options?: { persist?: boolean },
    ) => {
      const currentSessionId = activeSessionIdRef.current;
      const shouldPersist = options?.persist !== false;

      if (currentSessionId) {
        const session = [...recentSessions, ...workFolderSessions].find(
          candidate => candidate.id === currentSessionId,
        );
        const persisted = shouldPersist
          ? AIEngine.saveChatSession(
              currentSessionId,
              sessionTitleCandidate?.trim() ||
                session?.title ||
                sessionTitle ||
                '새 채팅',
              toStoredChatMessages(nextMessages),
            ).catch(() => undefined)
          : undefined;

        setChatMessagesBySessionId(current => ({
          ...current,
          [currentSessionId]: nextMessages,
        }));
        return { persisted, sessionId: currentSessionId };
      }

      if (!nextMessages.some(message => message.role === 'user')) {
        setDraftChatMessages(nextMessages);
        return { sessionId: null };
      }

      const targetWorkFolderId = pendingWorkFolderIdRef.current;
      const nextSessionId = createChatSessionId();
      const nextSessionTitle =
        sessionTitleCandidate?.trim() || sessionTitle || '새 채팅';
      const persisted = shouldPersist
        ? AIEngine.saveChatSession(
            nextSessionId,
            nextSessionTitle,
            toStoredChatMessages(nextMessages),
          ).catch(() => undefined)
        : undefined;

      activeSessionIdRef.current = nextSessionId;
      pendingWorkFolderIdRef.current = null;
      setActiveSessionId(nextSessionId);
      setPendingWorkFolderId(null);
      setSessionTitle(nextSessionTitle);
      if (targetWorkFolderId) {
        setWorkFolderSessions(current => [
          {
            id: nextSessionId,
            title: nextSessionTitle,
            workFolderId: targetWorkFolderId,
          },
          ...current,
        ]);
      } else {
        setRecentSessions(current => [
          {
            id: nextSessionId,
            title: nextSessionTitle,
          },
          ...current,
        ]);
      }
      setChatMessagesBySessionId(current => ({
        ...current,
        [nextSessionId]: nextMessages,
      }));
      setDraftChatMessages(createInitialChatMessages());
      return { persisted, sessionId: nextSessionId };
    },
    [recentSessions, sessionTitle, workFolderSessions],
  );

  const handleActiveSessionTitleChange = useCallback(
    (title: string, options: SessionTitleChangeOptions = {}) => {
      const normalizedTitle = title.trim();
      const targetSessionId = options.sessionId ?? activeSessionIdRef.current;

      if (!normalizedTitle) {
        return;
      }

      if (!targetSessionId) {
        clearTitleAnimation(true);
        setSessionTitle(normalizedTitle);
        return;
      }

      const isActiveSession = targetSessionId === activeSessionIdRef.current;
      if (
        !options.animated ||
        !isActiveSession ||
        normalizedTitle.length <= 1
      ) {
        clearTitleAnimation(true);
        applySessionTitle(targetSessionId, normalizedTitle);
        return;
      }

      clearTitleAnimation(true);

      let characterIndex = 0;
      pendingTitleAnimationRef.current = {
        sessionId: targetSessionId,
        title: normalizedTitle,
      };

      const tickTitle = () => {
        characterIndex += 1;
        const nextTitle = normalizedTitle.slice(0, characterIndex);
        const isComplete = characterIndex >= normalizedTitle.length;

        applySessionTitle(targetSessionId, nextTitle, {
          persist: isComplete,
        });

        if (isComplete) {
          stopTitleAnimation();
        }
      };

      tickTitle();
      titleAnimationTimerRef.current = setInterval(
        tickTitle,
        TITLE_TYPING_INTERVAL_MS,
      );
    },
    [applySessionTitle, clearTitleAnimation, stopTitleAnimation],
  );

  const handleRenameSession = (sessionId: string, title: string) => {
    clearTitleAnimation(true);
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

    const messages = chatMessagesBySessionId[sessionId];
    if (messages) {
      AIEngine.saveChatSession(
        sessionId,
        title,
        toStoredChatMessages(messages),
      ).catch(() => undefined);
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
    setWorkFolderSessions(current =>
      current.map(session =>
        session.id === sessionId
          ? { ...session, pinned: !session.pinned }
          : session,
      ),
    );
  };

  const handleMoveSessionToWorkFolder = (
    sessionId: string,
    workFolderId: string,
  ) => {
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
        return current.map(session =>
          session.id === sessionId ? { ...session, workFolderId } : session,
        );
      }

      return [...current, { ...movedSession, pinned: false, workFolderId }];
    });
  };

  const handleCreateWorkFolder = (
    title: string,
    iconId: WorkFolderIconId = DEFAULT_WORK_FOLDER_ICON_ID,
    memory = '',
  ) => {
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }

    setWorkFolders(current => [
      ...current,
      {
        iconId,
        id: `work-folder-${Date.now()}`,
        memory: memory.trim(),
        title: nextTitle,
      },
    ]);
  };

  const handleUpdateWorkFolder = (
    folderId: string,
    title: string,
    iconId: WorkFolderIconId,
    memory: string,
  ) => {
    const nextTitle = title.trim();
    if (!nextTitle) {
      return;
    }

    setWorkFolders(current =>
      current.map(folder =>
        folder.id === folderId
          ? { ...folder, iconId, memory: memory.trim(), title: nextTitle }
          : folder,
      ),
    );
  };

  const handleDeleteWorkFolder = (folderId: string) => {
    const deletedSessionIds = workFolderSessions
      .filter(session => session.workFolderId === folderId)
      .map(session => session.id);
    const deletedSessionIdSet = new Set(deletedSessionIds);

    setWorkFolders(current => current.filter(folder => folder.id !== folderId));
    setWorkFolderSessions(current =>
      current.filter(session => session.workFolderId !== folderId),
    );
    setChatMessagesBySessionId(current => {
      if (deletedSessionIds.length === 0) {
        return current;
      }

      return Object.fromEntries(
        Object.entries(current).filter(
          ([sessionId]) => !deletedSessionIdSet.has(sessionId),
        ),
      );
    });
    deletedSessionIds.forEach(sessionId => {
      AIEngine.deleteChatSession(sessionId).catch(() => undefined);
    });

    if (pendingWorkFolderIdRef.current === folderId) {
      pendingWorkFolderIdRef.current = null;
      setPendingWorkFolderId(null);
    }

    if (activeSessionId && deletedSessionIdSet.has(activeSessionId)) {
      clearTitleAnimation(false);
      activeSessionIdRef.current = null;
      setActiveSessionId(null);
      setSessionTitle('새 채팅');
      setDraftChatMessages(createInitialChatMessages());
      setChatInstanceKey(current => current + 1);
    }
  };

  const handleRemoveSessionFromWorkFolder = (sessionId: string) => {
    const removedSession = workFolderSessions.find(
      session => session.id === sessionId,
    );
    if (!removedSession) {
      return;
    }

    setWorkFolderSessions(current =>
      current.filter(session => session.id !== sessionId),
    );
    setRecentSessions(current => {
      if (current.some(session => session.id === sessionId)) {
        return current;
      }

      return [
        {
          id: removedSession.id,
          pinned: removedSession.pinned ?? false,
          title: removedSession.title,
        },
        ...current,
      ];
    });
  };

  const handleDeleteSession = (sessionId: string) => {
    setRecentSessions(current =>
      current.filter(session => session.id !== sessionId),
    );
    setWorkFolderSessions(current =>
      current.filter(session => session.id !== sessionId),
    );
    setChatMessagesBySessionId(current => omitRecordKey(current, sessionId));
    AIEngine.deleteChatSession(sessionId).catch(() => undefined);

    if (activeSessionId === sessionId) {
      clearTitleAnimation(false);
      activeSessionIdRef.current = null;
      setActiveSessionId(null);
      setSessionTitle('새 채팅');
      setDraftChatMessages(createInitialChatMessages());
      setChatInstanceKey(current => current + 1);
    }
  };

  return (
    <DisplaySettingsProvider>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      <SafeAreaView edges={['top', 'left', 'right']} style={styles.safeArea}>
        <PastelBackground />

        <View style={styles.header}>
          <View style={styles.headerSide}>
            <Pressable
              accessibilityLabel={
                isSettingsDetailPanel ? '설정 목록으로 돌아가기' : '메뉴 열기'
              }
              accessibilityRole="button"
              onPress={() => {
                if (isSettingsDetailPanel) {
                  setSettingsPanel('root');
                  return;
                }

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
                icon={
                  isSettingsDetailPanel
                    ? appIcons.back
                    : appIcons.navigationMenu
                }
                size={isSettingsDetailPanel ? 18 : 20}
              />
            </Pressable>
          </View>

          <Text numberOfLines={1} style={styles.sessionTitle}>
            {activeScreen === 'settings'
              ? t('settings.title')
              : activeScreen === 'todo'
              ? 'Todo List'
              : sessionTitle}
          </Text>

          <View style={[styles.headerSide, styles.headerSideRight]}>
            {activeScreen !== 'chat' ? null : (
              <Pressable
                accessibilityLabel="모델 선택"
                accessibilityRole="button"
                accessibilityState={{ expanded: isModelMenuOpen }}
                onPress={() => handleModelMenuExpandedChange(!isModelMenuOpen)}
                style={({ pressed }) => [
                  styles.modelSelector,
                  isModelMenuOpen && styles.modelSelectorActive,
                  pressed && styles.menuButtonPressed,
                ]}
              >
                <Text numberOfLines={1} style={styles.modelSelectorText}>
                  {headerModelLabel}
                </Text>
                <AppIcon
                  color={colors.mutedForeground}
                  icon={appIcons.chevronDown}
                  size={9}
                />
              </Pressable>
            )}
          </View>
        </View>

        {isModelMenuOpen ? (
          <Pressable
            accessibilityLabel="모델 메뉴 닫기"
            onPress={() => setIsModelMenuOpen(false)}
            style={styles.modelMenuBackdrop}
          />
        ) : null}

        {isModelMenuOpen ? (
          <View style={styles.modelMenuOverlay}>
            {modelSelectOptions.map(option => {
              const optionStatus = getModelStatusForId(
                modelStatuses,
                option.value,
              );
              const isSelected = option.value === headerSelectedModelId;
              const isDownloadableMissingModel =
                option.value === defaultDownloadableModelOption.id &&
                !optionStatus?.installed &&
                !isSystemManagedModel(option.value, optionStatus);
              const isDownloadInProgress =
                isDownloadableMissingModel &&
                (optionStatus?.isDownloading || isModelDownloadStarting);
              const optionDownloadProgress =
                optionStatus == null || optionStatus.totalBytes <= 0
                  ? 0
                  : Math.min(
                      1,
                      optionStatus.bytesDownloaded / optionStatus.totalBytes,
                    );

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
                  onPress={() => handleHeaderModelOptionPress(option)}
                  style={({ pressed }) => [
                    styles.modelMenuOption,
                    isDownloadableMissingModel &&
                      styles.modelMenuOptionDownloadable,
                    option.dividerBefore && styles.modelMenuOptionDivider,
                    isSelected && styles.modelMenuOptionSelected,
                    option.disabled && styles.modelMenuOptionDisabled,
                    pressed && styles.menuButtonPressed,
                  ]}
                >
                  <View style={styles.modelMenuOptionValue}>
                    <View style={styles.modelMenuOptionCopy}>
                      <Text
                        numberOfLines={1}
                        style={[
                          styles.modelMenuOptionLabel,
                          isDownloadableMissingModel &&
                            styles.modelMenuOptionLabelDownloadable,
                        ]}
                      >
                        {option.label}
                      </Text>
                      {option.description ? (
                        <Text
                          numberOfLines={1}
                          style={styles.modelMenuOptionDescription}
                        >
                          {option.description}
                        </Text>
                      ) : null}
                      {isDownloadInProgress ? (
                        <View style={styles.modelMenuProgressTrack}>
                          <View
                            style={[
                              styles.modelMenuProgressFill,
                              { width: `${optionDownloadProgress * 100}%` },
                            ]}
                          />
                        </View>
                      ) : null}
                    </View>
                  </View>
                  {isDownloadInProgress ? (
                    <View style={styles.modelMenuDownloadPill}>
                      <ActivityIndicator color={colors.primary} size="small" />
                      <Text style={styles.modelMenuDownloadPillText}>
                        받는 중
                      </Text>
                    </View>
                  ) : option.trailingIcon ? (
                    <View style={styles.modelMenuDownloadPill}>
                      <Text style={styles.modelMenuDownloadPillText}>받기</Text>
                      <AppIcon
                        color={option.trailingIconColor ?? colors.primary}
                        icon={option.trailingIcon}
                        size={14}
                      />
                    </View>
                  ) : isSelected ? (
                    <View style={styles.modelMenuTrailingCircle}>
                      <AppIcon
                        color={colors.primary}
                        icon={appIcons.selected}
                        size={14}
                      />
                    </View>
                  ) : null}
                </Pressable>
              );
            })}
          </View>
        ) : null}

        <View style={styles.content}>
          {activeScreen === 'chat' ? (
            <ChatScreen
              commonSystemPrompt={activeSystemPrompt}
              key={`chat-${chatInstanceKey}`}
              messages={activeMessages}
              onMessagesChange={handleChatMessagesChange}
              onSessionTitleChange={handleActiveSessionTitleChange}
              selectedModelId={selectedModel.id}
              selectedModelLabel={selectedModel.label}
              sessionId={activeSessionId}
            />
          ) : activeScreen === 'settings' ? (
            <Settings
              activePanel={settingsPanel}
              onModelStateChange={handleModelStateChange}
              onPanelChange={setSettingsPanel}
              onPersonalCustomizationChange={setPersonalCustomization}
              personalCustomization={personalCustomization}
              selectedModelId={selectedModel.id}
            />
          ) : (
            <TodoListScreen />
          )}
        </View>

        <FullScreenMenu
          chatMessagesBySessionId={chatMessagesBySessionId}
          onCreateWorkFolder={handleCreateWorkFolder}
          onDeleteWorkFolder={handleDeleteWorkFolder}
          onDeleteSession={handleDeleteSession}
          onClose={() => setIsMenuOpen(false)}
          onMoveSessionToWorkFolder={handleMoveSessionToWorkFolder}
          onNewChat={handleNewChat}
          onOpenSettings={handleOpenSettings}
          onOpenTodoList={handleOpenTodoList}
          onRenameSession={handleRenameSession}
          onRemoveSessionFromWorkFolder={handleRemoveSessionFromWorkFolder}
          onSelectSession={handleSelectSession}
          onStartWorkFolderChat={handleStartWorkFolderChat}
          onTogglePinnedSession={handleTogglePinnedSession}
          onUpdateWorkFolder={handleUpdateWorkFolder}
          recentSessions={sortedRecentSessions}
          visible={isMenuOpen}
          workFolders={workFolders}
          workFolderSessions={workFolderSessions}
        />
      </SafeAreaView>
    </DisplaySettingsProvider>
  );
}

function App() {
  return (
    <I18nProvider>
      <SafeAreaProvider>
        <AppContent />
      </SafeAreaProvider>
    </I18nProvider>
  );
}

export default App;
