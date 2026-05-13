import AsyncStorage from '@react-native-async-storage/async-storage';
import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import type { GestureResponderEvent, LayoutChangeEvent } from 'react-native';
import {
  ActivityIndicator,
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
import FloatingSelect, {
  FloatingSelectOption,
} from './src/components/FloatingSelect';
import PastelBackground from './src/components/PastelBackground';
import AIEngine, {
  ModelStatus,
  RuntimeStatus,
  StoredChatMessage,
} from './src/native/AIEngine';
import ChatScreen, {
  ChatMessage,
  createInitialChatMessages,
} from './src/screens/ChatScreen';
import Settings, { type SettingsPanelId } from './src/screens/Settings';
import {
  DisplaySettingsProvider,
  ScaledText as Text,
} from './src/theme/display';
import { appIcons } from './src/theme/icons';
import { colors, typography } from './src/theme/tokens';
import { brandAssets } from './src/config/branding';

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
  workFolderId?: string;
};

type WorkFolderIconId =
  | 'folder'
  | 'briefcase'
  | 'idea'
  | 'code'
  | 'chart'
  | 'book'
  | 'palette';

type WorkFolder = {
  iconId?: WorkFolderIconId;
  id: string;
  memory?: string;
  title: string;
};

type ModelStateSnapshot = {
  modelStatus: ModelStatus | null;
  runtimeStatus: RuntimeStatus | null;
};

type MenuSearchResult = {
  iconId?: WorkFolderIconId;
  id: string;
  title: string;
  type: 'folder' | 'session';
};

type RecentActionMenuAnchor = {
  x: number;
  y: number;
};

type RecentActionMenuPosition = {
  left: number;
  top: number;
};

type RecentActionMenuSize = {
  height: number;
  width: number;
};

type SessionActionScope = 'recent' | 'workFolder';

type RecentSessionDialog =
  | { session: ChatSession; type: 'rename' }
  | { session: ChatSession; type: 'move' }
  | { session: ChatSession; type: 'delete' };

type WorkFolderActionDialog =
  | { folder: WorkFolder; type: 'settings' }
  | { folder: WorkFolder; type: 'delete' };

type PersistedChatMessage = Omit<ChatMessage, 'createdAt'> & {
  createdAt: string;
};

type PersistedAppState = {
  activeSessionId: string | null;
  chatMessagesBySessionId: Record<string, PersistedChatMessage[]>;
  draftChatMessages: PersistedChatMessage[];
  personalSystemPrompt: string;
  recentSessions: ChatSession[];
  selectedModelId: ModelOption['id'];
  sessionTitle: string;
  version: 1;
  workFolders: WorkFolder[];
  workFolderSessions: ChatSession[];
};

const APP_STATE_STORAGE_KEY = 'open-edge-ai:app-state:v1';
const MODEL_MENU_GAP = 6;
const MODEL_MENU_TOP = 52 + MODEL_MENU_GAP;
const MODEL_MENU_WIDTH = 220;
const WEB_APP_MAX_WIDTH = 430;
const MENU_HORIZONTAL_PADDING = 24;
const MENU_HEADER_LOGO_LEFT_OFFSET = -16;
const MENU_HEADER_ICON_SIZE = 18;
const OPTION_MENU_ELEVATION = 96;
const OPTION_MENU_Z_INDEX = 96;
const RECENT_ACTION_MENU_EDGE_GAP = 16;
const RECENT_ACTION_MENU_OFFSET = 10;
const RECENT_ACTION_MENU_WIDTH = 214;
const RECENT_ACTION_MENU_HEIGHT = 160;
const WORK_FOLDER_ACTION_MENU_HEIGHT = 84;
const WORK_FOLDER_SESSION_ACTION_MENU_HEIGHT = 122;

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

const modelManageOption = modelOptions.find(model => model.id === 'manage')!;
const defaultDownloadableModelOption = modelOptions.find(
  model => model.id === 'gemma-4',
)!;

const getActiveModelOption = (
  modelStatus: ModelStatus | null,
) => {
  if (!modelStatus?.installed) {
    return null;
  }

  const normalizedModelName = modelStatus.modelName.toLowerCase();

  if (normalizedModelName.includes('lite')) {
    return modelOptions.find(model => model.id === 'gemma-lite') ?? null;
  }

  if (normalizedModelName.includes('deep')) {
    return modelOptions.find(model => model.id === 'gemma-deep') ?? null;
  }

  if (normalizedModelName.includes('gemma')) {
    return modelOptions.find(model => model.id === 'gemma-4') ?? null;
  }

  return null;
};

const mainMenuRows: MenuIconRow[] = [
  {
    icon: appIcons.menuDocumentImage,
    label: '문서 및 이미지',
  },
  {
    icon: appIcons.menuScheduling,
    label: '스케줄링',
  },
  {
    icon: appIcons.menuCodex,
    label: '코드 작성',
  },
];

const DEFAULT_WORK_FOLDER_ICON_ID: WorkFolderIconId = 'folder';

const workFolderIconOptions: FloatingSelectOption<WorkFolderIconId>[] = [
  {
    icon: appIcons.folder,
    label: '기본',
    value: 'folder',
  },
  {
    icon: appIcons.workFolderBriefcase,
    label: '업무',
    value: 'briefcase',
  },
  {
    icon: appIcons.workFolderIdea,
    label: '아이디어',
    value: 'idea',
  },
  {
    icon: appIcons.workFolderCode,
    label: '개발',
    value: 'code',
  },
  {
    icon: appIcons.workFolderChart,
    label: '분석',
    value: 'chart',
  },
  {
    icon: appIcons.workFolderBook,
    label: '문서',
    value: 'book',
  },
  {
    icon: appIcons.workFolderPalette,
    label: '디자인',
    value: 'palette',
  },
];

const initialRecentSessions: ChatSession[] = [
  {
    id: 'linkedin-intro',
    title: '링크드인 소개 수정',
  },
];

const createChatSessionId = () =>
  `chat-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const serializeMessages = (messages: ChatMessage[]): PersistedChatMessage[] =>
  messages.map(message => ({
    ...message,
    createdAt: message.createdAt.toISOString(),
  }));

const hydrateMessages = (
  messages: PersistedChatMessage[] | undefined,
): ChatMessage[] => {
  if (!Array.isArray(messages) || messages.length === 0) {
    return createInitialChatMessages();
  }

  return messages.map(message => {
    const createdAt = new Date(message.createdAt);

    return {
      ...message,
      createdAt: Number.isNaN(createdAt.getTime()) ? new Date() : createdAt,
    };
  });
};

const toStoredChatMessages = (messages: ChatMessage[]): StoredChatMessage[] =>
  messages.map(message => ({
    createdAt: message.createdAt.getTime(),
    id: message.id,
    modelName: message.modelName,
    role: message.role,
    text: message.text,
  }));

const isModelOptionId = (value: string): value is ModelOption['id'] =>
  modelOptions.some(model => model.id === value);

const isWorkFolderIconId = (
  value: string | undefined,
): value is WorkFolderIconId =>
  workFolderIconOptions.some(option => option.value === value);

const getWorkFolderIcon = (iconId?: WorkFolderIconId) =>
  workFolderIconOptions.find(option => option.value === iconId)?.icon ??
  appIcons.folder;

const hydrateWorkFolders = (
  folders: WorkFolder[] | undefined,
): WorkFolder[] => {
  if (!Array.isArray(folders)) {
    return [];
  }

  return folders
    .filter(
      folder =>
        folder &&
        typeof folder.id === 'string' &&
        typeof folder.title === 'string',
    )
    .map(folder => ({
      ...folder,
      iconId: isWorkFolderIconId(folder.iconId)
        ? folder.iconId
        : DEFAULT_WORK_FOLDER_ICON_ID,
      memory: typeof folder.memory === 'string' ? folder.memory : '',
    }));
};

const parseStoredAppState = (
  value: string | null,
): PersistedAppState | null => {
  if (!value) {
    return null;
  }

  try {
    const parsed = JSON.parse(value) as Partial<PersistedAppState>;

    if (parsed.version !== 1) {
      return null;
    }

    return {
      activeSessionId:
        typeof parsed.activeSessionId === 'string'
          ? parsed.activeSessionId
          : null,
      chatMessagesBySessionId:
        parsed.chatMessagesBySessionId &&
        typeof parsed.chatMessagesBySessionId === 'object'
          ? parsed.chatMessagesBySessionId
          : {},
      draftChatMessages: Array.isArray(parsed.draftChatMessages)
        ? parsed.draftChatMessages
        : serializeMessages(createInitialChatMessages()),
      personalSystemPrompt:
        typeof parsed.personalSystemPrompt === 'string'
          ? parsed.personalSystemPrompt
          : '',
      recentSessions: Array.isArray(parsed.recentSessions)
        ? parsed.recentSessions
        : initialRecentSessions,
      selectedModelId:
        typeof parsed.selectedModelId === 'string' &&
        isModelOptionId(parsed.selectedModelId)
          ? parsed.selectedModelId
          : 'gemma-4',
      sessionTitle:
        typeof parsed.sessionTitle === 'string'
          ? parsed.sessionTitle
          : '새 채팅',
      version: 1,
      workFolders: hydrateWorkFolders(parsed.workFolders),
      workFolderSessions: Array.isArray(parsed.workFolderSessions)
        ? parsed.workFolderSessions
        : [],
    };
  } catch {
    return null;
  }
};

const omitRecordKey = <Value,>(
  record: Record<string, Value>,
  key: string,
): Record<string, Value> => {
  const nextRecord = { ...record };
  delete nextRecord[key];
  return nextRecord;
};

const createCommonSystemPrompt = (
  personalSystemPrompt: string,
  workFolderMemory: string,
) =>
  [
    personalSystemPrompt.trim()
      ? `개인 시스템 프롬프트:\n${personalSystemPrompt.trim()}`
      : '',
    workFolderMemory.trim()
      ? `작업 폴더 시스템 프롬프트(메모리):\n${workFolderMemory.trim()}`
      : '',
  ]
    .filter(Boolean)
    .join('\n\n');

function App() {
  const activeSessionIdRef = useRef<string | null>(null);
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
  const [chatMessagesBySessionId, setChatMessagesBySessionId] = useState<
    Record<string, ChatMessage[]>
  >({});
  const [draftChatMessages, setDraftChatMessages] = useState<ChatMessage[]>(
    createInitialChatMessages,
  );
  const [personalSystemPrompt, setPersonalSystemPrompt] = useState('');
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isModelMenuOpen, setIsModelMenuOpen] = useState(false);
  const [chatInstanceKey, setChatInstanceKey] = useState(0);
  const [activeScreen, setActiveScreen] = useState<'chat' | 'settings'>('chat');
  const [settingsPanel, setSettingsPanel] =
    useState<SettingsPanelId>('root');
  const [selectedModelId, setSelectedModelId] =
    useState<ModelOption['id']>('gemma-4');
  const [modelStatus, setModelStatus] = useState<ModelStatus | null>(null);
  const [isModelDownloadStarting, setIsModelDownloadStarting] =
    useState(false);

  const handleModelStateChange = useCallback(
    ({
      modelStatus: nextModelStatus,
    }: ModelStateSnapshot) => {
      setModelStatus(nextModelStatus);
    },
    [],
  );

  const refreshModelState = useCallback(async () => {
    const nextModelStatus = await AIEngine.getModelStatus();
    handleModelStateChange({
      modelStatus: nextModelStatus,
      runtimeStatus: null,
    });
  }, [handleModelStateChange]);

  const activeModelOption = useMemo(
    () => getActiveModelOption(modelStatus),
    [modelStatus],
  );

  const selectedModel = useMemo(
    () =>
      activeModelOption ??
      modelOptions.find(
        model => model.id === selectedModelId && model.action !== 'settings',
      ) ??
      modelOptions[0],
    [activeModelOption, selectedModelId],
  );
  const headerSelectedModelId = activeModelOption?.id ?? null;
  const isSettingsDetailPanel =
    activeScreen === 'settings' && settingsPanel !== 'root';

  const handleDownloadModelFromMenu = useCallback(async () => {
    if (
      isModelDownloadStarting ||
      modelStatus?.installed ||
      modelStatus?.isDownloading
    ) {
      return;
    }

    setIsModelDownloadStarting(true);

    try {
      const nextModelStatus = await AIEngine.downloadModel();
      setModelStatus(nextModelStatus);
    } finally {
      setIsModelDownloadStarting(false);
    }
  }, [
    isModelDownloadStarting,
    modelStatus?.installed,
    modelStatus?.isDownloading,
  ]);

  const modelSelectOptions = useMemo<
    FloatingSelectOption<ModelOption['id']>[]
  >(() => {
    const visibleModelOptions = activeModelOption
      ? [activeModelOption, modelManageOption]
      : [defaultDownloadableModelOption, modelManageOption];

    return visibleModelOptions.map((model, index) => {
      const isDownloadableMissingModel =
        !activeModelOption && model.id === defaultDownloadableModelOption.id;

      return {
        description: isDownloadableMissingModel ? undefined : model.detail,
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
  }, [
    activeModelOption,
    modelStatus,
  ]);
  const headerSelectedModelOption =
    modelSelectOptions.find(option => option.value === headerSelectedModelId) ??
    modelManageOption;

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

      if (!modelStatus?.installed) {
        handleDownloadModelFromMenu().catch(() => undefined);
      }
    },
    [handleDownloadModelFromMenu, modelStatus?.installed],
  );

  const handleHeaderModelOptionPress = useCallback(
    (option: FloatingSelectOption<ModelOption['id']>) => {
      if (option.disabled) {
        return;
      }

      const isDownloadableMissingModel =
        !activeModelOption &&
        option.value === defaultDownloadableModelOption.id;

      if (isDownloadableMissingModel) {
        if (modelStatus?.isDownloading || isModelDownloadStarting) {
          return;
        }

        setSelectedModelId(option.value);
        handleDownloadModelFromMenu().catch(() => undefined);
        return;
      }

      handleSelectModel(option.value);
      setIsModelMenuOpen(false);
    },
    [
      activeModelOption,
      handleDownloadModelFromMenu,
      handleSelectModel,
      isModelDownloadStarting,
      modelStatus?.isDownloading,
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

        if (!storedState || isCancelled) {
          return;
        }

        const hydratedMessagesBySessionId = Object.fromEntries(
          Object.entries(storedState.chatMessagesBySessionId).map(
            ([sessionId, messages]) => [sessionId, hydrateMessages(messages)],
          ),
        );

        activeSessionIdRef.current = storedState.activeSessionId;
        setSessionTitle(storedState.sessionTitle);
        setActiveSessionId(storedState.activeSessionId);
        setRecentSessions(storedState.recentSessions);
        setWorkFolderSessions(storedState.workFolderSessions);
        setWorkFolders(storedState.workFolders);
        setSelectedModelId(storedState.selectedModelId);
        setPersonalSystemPrompt(storedState.personalSystemPrompt);
        setChatMessagesBySessionId(hydratedMessagesBySessionId);
        setDraftChatMessages(hydrateMessages(storedState.draftChatMessages));
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
      personalSystemPrompt,
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

    Object.entries(chatMessagesBySessionId).forEach(([sessionId, messages]) => {
      const session = [...recentSessions, ...workFolderSessions].find(
        candidate => candidate.id === sessionId,
      );
      AIEngine.saveChatSession(
        sessionId,
        session?.title ?? sessionTitle,
        toStoredChatMessages(messages),
      ).catch(() => undefined);
    });
  }, [
    activeSessionId,
    chatMessagesBySessionId,
    draftChatMessages,
    isAppStateHydrated,
    personalSystemPrompt,
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
    if (!activeSessionId) {
      return '';
    }

    const activeWorkFolderId = workFolderSessions.find(
      session => session.id === activeSessionId,
    )?.workFolderId;

    if (!activeWorkFolderId) {
      return '';
    }

    return (
      workFolders
        .find(folder => folder.id === activeWorkFolderId)
        ?.memory?.trim() ?? ''
    );
  }, [activeSessionId, workFolders, workFolderSessions]);

  const activeSystemPrompt = useMemo(
    () =>
      createCommonSystemPrompt(personalSystemPrompt, activeWorkFolderMemory),
    [activeWorkFolderMemory, personalSystemPrompt],
  );

  const handleNewChat = () => {
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
    setActiveScreen('settings');
    setSettingsPanel('root');
    setActiveSessionId(null);
    setIsMenuOpen(false);
  };

  const handleChatMessagesChange = useCallback(
    (nextMessages: ChatMessage[], sessionTitleCandidate?: string) => {
      const currentSessionId = activeSessionIdRef.current;

      if (currentSessionId) {
        const session = [...recentSessions, ...workFolderSessions].find(
          candidate => candidate.id === currentSessionId,
        );
        const persisted = AIEngine.saveChatSession(
          currentSessionId,
          sessionTitleCandidate?.trim() ||
            session?.title ||
            sessionTitle ||
            'New chat',
          toStoredChatMessages(nextMessages),
        ).catch(() => undefined);

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

      const nextSessionId = createChatSessionId();
      const nextSessionTitle =
        sessionTitleCandidate?.trim() || sessionTitle || '새 채팅';
      const persisted = AIEngine.saveChatSession(
        nextSessionId,
        nextSessionTitle,
        toStoredChatMessages(nextMessages),
      ).catch(() => undefined);

      activeSessionIdRef.current = nextSessionId;
      setActiveSessionId(nextSessionId);
      setSessionTitle(nextSessionTitle);
      setRecentSessions(current => [
        {
          id: nextSessionId,
          title: nextSessionTitle,
        },
        ...current,
      ]);
      setChatMessagesBySessionId(current => ({
        ...current,
        [nextSessionId]: nextMessages,
      }));
      setDraftChatMessages(createInitialChatMessages());
      return { persisted, sessionId: nextSessionId };
    },
    [recentSessions, sessionTitle, workFolderSessions],
  );

  const handleActiveSessionTitleChange = useCallback((title: string) => {
    const normalizedTitle = title.trim();
    const currentSessionId = activeSessionIdRef.current;

    if (!normalizedTitle) {
      return;
    }

    setSessionTitle(normalizedTitle);

    if (!currentSessionId) {
      return;
    }

    setRecentSessions(current =>
      current.map(session =>
        session.id === currentSessionId
          ? { ...session, title: normalizedTitle }
          : session,
      ),
    );
    setWorkFolderSessions(current =>
      current.map(session =>
        session.id === currentSessionId
          ? { ...session, title: normalizedTitle }
          : session,
      ),
    );
  }, []);

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
        memory: '',
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
    const restoredSessions = workFolderSessions
      .filter(session => session.workFolderId === folderId)
      .map(session => ({
        id: session.id,
        pinned: false,
        title: session.title,
      }));

    setWorkFolders(current => current.filter(folder => folder.id !== folderId));
    setWorkFolderSessions(current =>
      current.filter(session => session.workFolderId !== folderId),
    );
    setRecentSessions(current => {
      const existingSessionIds = new Set(current.map(session => session.id));
      const nextRestoredSessions = restoredSessions.filter(
        session => !existingSessionIds.has(session.id),
      );

      return [...nextRestoredSessions, ...current];
    });
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
      activeSessionIdRef.current = null;
      setActiveSessionId(null);
      setSessionTitle('새 채팅');
      setDraftChatMessages(createInitialChatMessages());
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
              {activeScreen === 'settings' ? '설정' : sessionTitle}
            </Text>

            <View style={[styles.headerSide, styles.headerSideRight]}>
              {activeScreen === 'settings' ? null : (
                <Pressable
                  accessibilityLabel="모델 선택"
                  accessibilityRole="button"
                  accessibilityState={{ expanded: isModelMenuOpen }}
                  onPress={() =>
                    handleModelMenuExpandedChange(!isModelMenuOpen)
                  }
                  style={({ pressed }) => [
                    styles.modelSelector,
                    isModelMenuOpen && styles.modelSelectorActive,
                    pressed && styles.menuButtonPressed,
                  ]}
                >
                  <Text numberOfLines={1} style={styles.modelSelectorText}>
                    {headerSelectedModelOption.label}
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
                const isSelected = option.value === headerSelectedModelId;
                const isDownloadableMissingModel =
                  !activeModelOption &&
                  option.value === defaultDownloadableModelOption.id;
                const isDownloadInProgress =
                  isDownloadableMissingModel &&
                  (modelStatus?.isDownloading || isModelDownloadStarting);

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
                          style={styles.modelMenuOptionLabel}
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
                      </View>
                    </View>
                    {isSelected ? (
                      <AppIcon
                        color={colors.primary}
                        icon={appIcons.selected}
                        size={15}
                      />
                    ) : isDownloadInProgress ? (
                      <ActivityIndicator color={colors.primary} size="small" />
                    ) : option.trailingIcon ? (
                      <AppIcon
                        color={option.trailingIconColor ?? colors.primary}
                        icon={option.trailingIcon}
                        size={15}
                      />
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
                selectedModelLabel={selectedModel.label}
                sessionId={activeSessionId}
              />
            ) : (
              <Settings
                activePanel={settingsPanel}
                onModelStateChange={handleModelStateChange}
                onPanelChange={setSettingsPanel}
                onPersonalSystemPromptChange={setPersonalSystemPrompt}
                personalSystemPrompt={personalSystemPrompt}
              />
            )}
          </View>

          <FullScreenMenu
            onCreateWorkFolder={handleCreateWorkFolder}
            onDeleteWorkFolder={handleDeleteWorkFolder}
            onDeleteSession={handleDeleteSession}
            onClose={() => setIsMenuOpen(false)}
            onMoveSessionToWorkFolder={handleMoveSessionToWorkFolder}
            onNewChat={handleNewChat}
            onOpenSettings={handleOpenSettings}
            onRenameSession={handleRenameSession}
            onRemoveSessionFromWorkFolder={handleRemoveSessionFromWorkFolder}
            onSelectSession={handleSelectSession}
            onTogglePinnedSession={handleTogglePinnedSession}
            onUpdateWorkFolder={handleUpdateWorkFolder}
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
  const slideX = useRef(new Animated.Value(-width)).current;
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
    justifyContent: 'space-between',
    maxWidth: 92,
    minHeight: 32,
    paddingHorizontal: 10,
  },
  modelSelectorActive: {
    backgroundColor: colors.card,
  },
  modelSelectorText: {
    ...typography.caption,
    color: colors.foreground,
    flex: 1,
    flexShrink: 1,
    fontSize: 12,
    fontWeight: '700',
    marginRight: 4,
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
  modelMenuOverlay: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    elevation: 10002,
    overflow: 'hidden',
    position: 'absolute',
    right: 12,
    shadowColor: '#000000',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 22,
    top: MODEL_MENU_TOP,
    width: MODEL_MENU_WIDTH,
    zIndex: 10002,
  },
  modelMenuOption: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 48,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  modelMenuOptionSelected: {
    backgroundColor: 'rgba(0,122,255,0.08)',
  },
  modelMenuOptionDisabled: {
    opacity: 0.54,
  },
  modelMenuOptionDivider: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 6,
  },
  modelMenuOptionValue: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    minWidth: 0,
    paddingRight: 8,
  },
  modelMenuOptionCopy: {
    flex: 1,
    minWidth: 0,
  },
  modelMenuOptionLabel: {
    ...typography.label,
    color: colors.foreground,
    flex: 1,
    fontSize: 14,
    fontWeight: '700',
  },
  modelMenuOptionDescription: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '500',
    marginTop: 3,
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
  menuFrame: {
    flex: 1,
    overflow: 'visible',
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
  menuHeaderLogoButton: {
    alignItems: 'flex-start',
    flexShrink: 1,
    height: 44,
    justifyContent: 'center',
    marginLeft: MENU_HEADER_LOGO_LEFT_OFFSET,
    marginRight: 16,
    maxWidth: 152,
    width: 152,
  },
  menuHeaderLogo: {
    height: 32,
    width: '100%',
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
    fontSize: 16,
    fontWeight: '700',
    lineHeight: 21,
    marginBottom: 8,
  },
  menuSectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  menuSectionHeaderTitle: {
    marginBottom: 0,
  },
  menuSectionAddButton: {
    alignItems: 'center',
    height: 32,
    justifyContent: 'center',
    width: 32,
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
  workFolderTree: {
    marginTop: 2,
  },
  workFolderTreeItem: {
    marginBottom: 2,
  },
  workFolderTreeRow: {
    alignItems: 'center',
    borderRadius: 8,
    flexDirection: 'row',
    minHeight: 44,
  },
  workFolderTreeIconSlot: {
    height: 32,
    justifyContent: 'center',
    position: 'relative',
    width: 46,
  },
  workFolderTreeIcon: {
    alignItems: 'center',
    height: 30,
    justifyContent: 'center',
    marginLeft: 18,
    width: 24,
  },
  workFolderTreeChevron: {
    alignItems: 'center',
    height: 26,
    justifyContent: 'center',
    position: 'absolute',
    left: 0,
    top: 3,
    width: 16,
  },
  workFolderTreeLabel: {
    ...typography.label,
    color: colors.foreground,
    flex: 1,
    fontSize: 15,
    fontWeight: '500',
    lineHeight: 20,
    minWidth: 0,
  },
  workFolderTreeCount: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '700',
    paddingLeft: 10,
  },
  workFolderTreeChildren: {
    marginLeft: 30,
    paddingVertical: 1,
  },
  workFolderChildRow: {
    alignItems: 'center',
    borderRadius: 8,
    flexDirection: 'row',
    minHeight: 38,
    paddingHorizontal: 2,
  },
  workFolderChildIcon: {
    alignItems: 'center',
    height: 24,
    justifyContent: 'center',
    marginRight: 8,
    width: 20,
  },
  workFolderChildLabel: {
    ...typography.body,
    color: colors.foreground,
    flex: 1,
    fontSize: 15,
    fontWeight: '400',
    lineHeight: 20,
    minWidth: 0,
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
  recentActionLayer: {
    bottom: 0,
    elevation: OPTION_MENU_ELEVATION,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: OPTION_MENU_Z_INDEX,
  },
  recentActionBackdrop: {
    bottom: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  recentFloatingActionMenu: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    elevation: OPTION_MENU_ELEVATION,
    minWidth: RECENT_ACTION_MENU_WIDTH,
    overflow: 'hidden',
    paddingVertical: 4,
    position: 'absolute',
    shadowColor: '#000000',
    shadowOffset: { height: 10, width: 0 },
    shadowOpacity: 0.14,
    shadowRadius: 18,
    zIndex: OPTION_MENU_Z_INDEX + 1,
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
    elevation: 80,
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
    elevation: 0,
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
    zIndex: 0,
  },
  recentDialogCard: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 18,
    borderWidth: StyleSheet.hairlineWidth,
    elevation: 82,
    overflow: 'visible',
    padding: 18,
    position: 'relative',
    shadowColor: '#000000',
    shadowOffset: { height: 16, width: 0 },
    shadowOpacity: 0.14,
    shadowRadius: 28,
    width: '100%',
    zIndex: 1,
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
  workFolderNameInput: {
    flex: 1,
  },
  workFolderSettingsLabel: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 8,
    marginTop: 14,
  },
  workFolderMemoryInput: {
    minHeight: 112,
    paddingTop: 12,
  },
  workFolderSettingsHelp: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 8,
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
  workFolderSelectBlock: {
    marginTop: 14,
    position: 'relative',
    zIndex: 1,
  },
  workFolderSelectLabel: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 8,
  },
  workFolderSelectMenu: {
    backgroundColor: colors.card,
    borderColor: '#D9DEE8',
    borderWidth: 1,
    left: 0,
    position: 'absolute',
    right: 0,
    shadowOpacity: 0.18,
    top: 46,
  },
  workFolderSelectHelp: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '600',
    marginTop: 8,
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
