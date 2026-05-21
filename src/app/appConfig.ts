import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import { Platform } from 'react-native';

import { FloatingSelectOption } from '../components/FloatingSelect';
import {
  defaultPersonalityPresetId,
  resolvePersonalityPrompt,
} from '../config/personalityPresets';
import { ModelId, ModelStatus, RuntimeStatus } from '../native/AIEngine';
import { createInitialChatMessages } from '../screens/ChatScreen';
import type { PersonalCustomizationSettings } from '../screens/Settings';
import {
  ChatSession,
  PersistedChatMessage,
  serializeMessages,
} from '../state/chatStorage';
import { appIcons } from '../theme/icons';

export type MenuRowProps = {
  icon?: IconDefinition;
  iconColor?: string;
  label: string;
  onPress?: () => void;
};

export type ModelOption = {
  action?: 'settings';
  detail: string;
  icon: IconDefinition;
  id: ModelId | 'auto' | 'manage';
  label: string;
};

export type WorkFolderIconId =
  | 'folder'
  | 'ai'
  | 'code'
  | 'document'
  | 'memory'
  | 'chart';

export type WorkFolder = {
  iconId?: WorkFolderIconId;
  id: string;
  memory?: string;
  title: string;
};

export type ModelStateSnapshot = {
  modelStatus: ModelStatus | null;
  modelStatuses?: ModelStatus[];
  runtimeStatus: RuntimeStatus | null;
};

export type MenuSearchResult = {
  iconId?: WorkFolderIconId;
  id: string;
  subtitle?: string;
  title: string;
  type: 'folder' | 'session';
};

export type RecentActionMenuAnchor = {
  x: number;
  y: number;
};

export type RecentActionMenuPosition = {
  left: number;
  top: number;
};

export type RecentActionMenuSize = {
  height: number;
  width: number;
};

export type SessionActionScope = 'recent' | 'workFolder';

export type RecentSessionDialog =
  | { session: ChatSession; type: 'rename' }
  | { session: ChatSession; type: 'move' }
  | { session: ChatSession; type: 'delete' };

export type WorkFolderActionDialog =
  | { folder: WorkFolder; type: 'settings' }
  | { folder: WorkFolder; type: 'delete' };

export type PersistedAppState = {
  activeSessionId: string | null;
  chatMessagesBySessionId: Record<string, PersistedChatMessage[]>;
  draftChatMessages: PersistedChatMessage[];
  personalCustomization: PersonalCustomizationSettings;
  personalSystemPrompt?: string;
  recentSessions: ChatSession[];
  selectedModelId: ModelOption['id'];
  sessionTitle: string;
  version: 1;
  workFolders: WorkFolder[];
  workFolderSessions: ChatSession[];
};

export type SessionTitleChangeOptions = {
  animated?: boolean;
  sessionId?: string | null;
};

export const APP_STATE_STORAGE_KEY = 'open-edge-ai:app-state:v1';
export const MODEL_MENU_GAP = 6;
export const MODEL_MENU_TOP = 32 + MODEL_MENU_GAP;
export const MODEL_MENU_WIDTH = 252;
export const TITLE_TYPING_INTERVAL_MS = 42;
export const WEB_APP_MAX_WIDTH = 430;
export const MENU_HORIZONTAL_PADDING = 24;
export const MENU_HEADER_LOGO_LEFT_OFFSET = -16;
export const MENU_HEADER_ICON_SIZE = 18;
export const OPTION_MENU_ELEVATION = 96;
export const OPTION_MENU_Z_INDEX = 96;
export const RECENT_ACTION_MENU_EDGE_GAP = 16;
export const RECENT_ACTION_MENU_OFFSET = 10;
export const RECENT_ACTION_MENU_WIDTH = 214;
export const RECENT_ACTION_MENU_HEIGHT = 160;
export const WORK_FOLDER_ACTION_MENU_HEIGHT = 84;
export const WORK_FOLDER_SESSION_ACTION_MENU_HEIGHT = 122;

export const defaultPersonalCustomizationSettings: PersonalCustomizationSettings =
  {
    customInstructions: '',
    memoryEnabled: true,
    personality: defaultPersonalityPresetId,
    savedMemories: [],
    userName: '',
  };

export const modelOptions: ModelOption[] = [
  {
    detail: 'Apple 기본 온디바이스 AI',
    icon: appIcons.modelBalanced,
    id: 'apple-foundation',
    label: 'Apple Intelligence',
  },
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

export const modelManageOption = modelOptions.find(
  model => model.id === 'manage',
)!;
export const defaultDownloadableModelOption = modelOptions.find(
  model => model.id === 'gemma-4',
)!;
export const visibleHeaderModelOptions = modelOptions.filter(
  model =>
    model.id === 'gemma-4' ||
    (Platform.OS === 'ios' && model.id === 'apple-foundation'),
);
export const defaultSelectedModelId: ModelId =
  Platform.OS === 'ios' ? 'apple-foundation' : 'gemma-4';

export const getModelStatusForId = (
  statuses: ModelStatus[],
  modelId: ModelOption['id'],
) =>
  statuses.find(status => {
    if (status.modelId === modelId) {
      return true;
    }

    const normalizedName = status.modelName.toLowerCase();
    if (modelId === 'apple-foundation') {
      return (
        normalizedName.includes('apple') ||
        normalizedName.includes('foundation')
      );
    }

    if (modelId === 'gemma-4') {
      return normalizedName.includes('gemma');
    }

    return false;
  }) ?? null;

export const isSystemManagedModel = (
  modelId: ModelOption['id'],
  status?: ModelStatus | null,
) =>
  modelId === 'apple-foundation' ||
  Boolean(status?.systemManaged) ||
  Boolean(status?.modelName.toLowerCase().includes('apple'));

export const normalizeSelectedModelId = (modelId: ModelOption['id']) =>
  Platform.OS === 'ios' || modelId !== 'apple-foundation'
    ? modelId
    : defaultSelectedModelId;

export const DEFAULT_WORK_FOLDER_ICON_ID: WorkFolderIconId = 'folder';

export const workFolderIconOptions: FloatingSelectOption<WorkFolderIconId>[] = [
  {
    icon: appIcons.folder,
    label: '폴더',
    value: 'folder',
  },
  {
    icon: appIcons.chatAssistant,
    label: 'AI',
    value: 'ai',
  },
  {
    icon: appIcons.menuCodex,
    label: '코드',
    value: 'code',
  },
  {
    icon: appIcons.info,
    label: '문서',
    value: 'document',
  },
  {
    icon: appIcons.memory,
    label: '메모리',
    value: 'memory',
  },
  {
    icon: appIcons.workFolderChart,
    label: '분석',
    value: 'chart',
  },
];

export const initialRecentSessions: ChatSession[] = [
  {
    id: 'linkedin-intro',
    title: '링크드인 소개 수정',
  },
];

export const createChatSessionId = () =>
  `chat-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

export const isModelOptionId = (value: string): value is ModelOption['id'] =>
  modelOptions.some(model => model.id === value);

export const isWorkFolderIconId = (
  value: string | undefined,
): value is WorkFolderIconId =>
  workFolderIconOptions.some(option => option.value === value);

export const getWorkFolderIcon = (iconId?: WorkFolderIconId) =>
  workFolderIconOptions.find(option => option.value === iconId)?.icon ??
  appIcons.folder;

export const hydrateWorkFolders = (
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
      iconId: normalizeWorkFolderIconId(folder.iconId),
      memory: typeof folder.memory === 'string' ? folder.memory : '',
    }));
};

const legacyWorkFolderIconMap: Partial<Record<string, WorkFolderIconId>> = {
  book: 'document',
  briefcase: 'folder',
  idea: 'ai',
  palette: 'folder',
};

const normalizeWorkFolderIconId = (
  iconId: string | undefined,
): WorkFolderIconId =>
  isWorkFolderIconId(iconId)
    ? iconId
    : legacyWorkFolderIconMap[iconId ?? ''] ?? DEFAULT_WORK_FOLDER_ICON_ID;

export const hydratePersonalCustomization = (
  settings: unknown,
  legacySystemPrompt: unknown,
): PersonalCustomizationSettings => {
  const parsedSettings =
    settings && typeof settings === 'object'
      ? (settings as Partial<PersonalCustomizationSettings>)
      : {};

  return {
    customInstructions:
      typeof parsedSettings.customInstructions === 'string'
        ? parsedSettings.customInstructions
        : typeof legacySystemPrompt === 'string'
        ? legacySystemPrompt
        : defaultPersonalCustomizationSettings.customInstructions,
    memoryEnabled:
      typeof parsedSettings.memoryEnabled === 'boolean'
        ? parsedSettings.memoryEnabled
        : defaultPersonalCustomizationSettings.memoryEnabled,
    personality:
      typeof parsedSettings.personality === 'string' &&
      parsedSettings.personality.trim()
        ? parsedSettings.personality
        : defaultPersonalCustomizationSettings.personality,
    savedMemories: Array.isArray(parsedSettings.savedMemories)
      ? parsedSettings.savedMemories.filter(
          (memory): memory is string => typeof memory === 'string',
        )
      : defaultPersonalCustomizationSettings.savedMemories,
    userName:
      typeof parsedSettings.userName === 'string'
        ? parsedSettings.userName
        : defaultPersonalCustomizationSettings.userName,
  };
};

export const parseStoredAppState = (
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
      personalCustomization: hydratePersonalCustomization(
        parsed.personalCustomization,
        parsed.personalSystemPrompt,
      ),
      recentSessions: Array.isArray(parsed.recentSessions)
        ? parsed.recentSessions
        : initialRecentSessions,
      selectedModelId:
        typeof parsed.selectedModelId === 'string' &&
        isModelOptionId(parsed.selectedModelId)
          ? normalizeSelectedModelId(parsed.selectedModelId)
          : defaultSelectedModelId,
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

export const omitRecordKey = <Value>(
  record: Record<string, Value>,
  key: string,
): Record<string, Value> => {
  const nextRecord = { ...record };
  delete nextRecord[key];
  return nextRecord;
};

export const createPersonalSystemPrompt = (
  settings: PersonalCustomizationSettings,
) =>
  [
    settings.userName.trim() ? `User name: ${settings.userName.trim()}` : '',
    resolvePersonalityPrompt(settings.personality).trim(),
    settings.customInstructions.trim(),
    settings.memoryEnabled && settings.savedMemories.length > 0
      ? `Saved memories:\n${settings.savedMemories
          .map(memory => memory.trim())
          .filter(Boolean)
          .map(memory => `- ${memory}`)
          .join('\n')}`
      : '',
  ]
    .filter(Boolean)
    .join('\n\n');
