import { I18nKey } from '../../i18n';
import { AIChatMessage, ModelId, MultimodalAttachment, RUNTIME_CONTEXT_MARKER } from '../../native/AIEngine';
import type { ChatRole } from '../../components/ChatBubble';

export type ChatMessage = {
  attachments?: MultimodalAttachment[];
  createdAt: Date;
  id: string;
  modelName?: string;
  reasoning?: string;
  role: ChatRole;
  text: string;
};

export type QueuedChatRequest = {
  attachments: MultimodalAttachment[];
  createdAt: Date;
  id: string;
  prompt: string;
};

export type QuickPrompt = {
  description: string;
  prompt: string;
  title: string;
};

export type ChatMode = {
  id: 'chat' | 'search' | 'reason' | 'files';
  label: string;
};

export type MessagesChangeResult = {
  persisted?: Promise<void>;
  sessionId: string | null;
};

export type MessagesChangeOptions = {
  persist?: boolean;
};

export type SessionTitleChangeOptions = {
  animated?: boolean;
  sessionId?: string | null;
};

export type ChatScreenProps = {
  commonSystemPrompt?: string;
  messages: ChatMessage[];
  onMessagesChange: (
    nextMessages: ChatMessage[],
    sessionTitleCandidate?: string,
    options?: MessagesChangeOptions,
  ) => MessagesChangeResult;
  onSessionTitleChange?: (
    title: string,
    options?: SessionTitleChangeOptions,
  ) => void;
  selectedModelId?: ModelId | string;
  selectedModelLabel?: string;
  sessionId?: string | null;
};

export const createInitialChatMessages = (): ChatMessage[] => [];

export const isInitialWelcomeMessage = (message: ChatMessage) =>
  message.id === 'welcome';

export const quickPrompts: QuickPrompt[] = [
  {
    description: '핵심 흐름과 리스크를 짧게 정리',
    prompt: '오늘 삼성전자 주가 흐름을 요약해줘',
    title: '오늘 삼성전자 주가 흐름을 요약해줘',
  },
  {
    description: '검색 기반으로 최신 흐름 확인',
    prompt: '친환경 소재의 최신 연구 동향을 검색해줘',
    title: '친환경 소재의 최신 연구 동향 검색',
  },
  {
    description: '긴 문서를 읽기 쉬운 요약으로 변환',
    prompt: '업로드한 PDF 내용을 정리해줘',
    title: '업로드한 PDF 내용을 정리해줘',
  },
];

export const chatModes: ChatMode[] = [
  { id: 'chat', label: '채팅' },
  { id: 'search', label: '검색' },
  { id: 'reason', label: '분석' },
  { id: 'files', label: '파일' },
];

export const chatModeLabelKeys: Record<ChatMode['id'], I18nKey> = {
  chat: 'chat.modeChat',
  files: 'chat.modeFiles',
  reason: 'chat.modeReason',
  search: 'chat.modeSearch',
};

export const INITIAL_SCROLL_BOTTOM_INSET = 170;
export const THREAD_SCROLL_BOTTOM_INSET = 210;
export const SCROLL_TO_BOTTOM_THRESHOLD = 140;
export const SCROLL_TO_BOTTOM_BUTTON_OFFSET = 198;
export const PENDING_CHAT_TITLE = '제목 생성 중';

export const formatTime = (date: Date, locale: string) =>
  new Intl.DateTimeFormat(locale, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);

const formatLocalDate = (date: Date) => {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');

  return `${year}-${month}-${day}`;
};

const RUNTIME_CONTEXT_TRIGGER_PATTERN =
  /(?:오늘|내일|어제|그제|모레|이번\s*(?:주|달|월|해|연도)|다음\s*(?:주|달|월|해|연도)|지난\s*(?:주|달|월|해|연도)|현재|지금|방금|나중|이따|날짜|시각|시간|몇\s*시|며칠|몇\s*일|요일|타임\s*존|시간대|오전|오후|자정|정오|분\s*(?:뒤|후|이따)|시간\s*(?:뒤|후|이따)|리마인드|상기|알림|일정|예약|today|tomorrow|yesterday|tonight|date|time|timezone|time zone|now|current|later|remind|reminder|schedule|this\s+week|next\s+week|last\s+week|this\s+month|next\s+month|last\s+month)/i;

export const shouldIncludeRuntimeContext = (text: string) =>
  RUNTIME_CONTEXT_TRIGGER_PATTERN.test(text);

export const createRuntimeContextMessage = (date = new Date()): AIChatMessage => {
  const localDate = formatLocalDate(date);
  const readableDate = new Intl.DateTimeFormat('ko-KR', {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
    year: 'numeric',
  }).format(date);
  const readableTime = new Intl.DateTimeFormat('ko-KR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
  const timeZone =
    Intl.DateTimeFormat().resolvedOptions().timeZone || 'local time';

  return {
    content: [
      RUNTIME_CONTEXT_MARKER,
      '비공개 런타임 날짜/시간 컨텍스트입니다.',
      `오늘은 ${readableDate}입니다.`,
      `로컬 날짜: ${localDate}`,
      `현재 로컬 시각: ${readableTime}`,
      `시간대: ${timeZone}`,
      '사용자가 날짜, 시각, 시간대 또는 "오늘", "내일", "어제", "이번 주"처럼 상대 날짜를 직접 묻거나 해석해야 할 때만 이 값을 기준으로 사용하세요.',
      '일반 답변에서는 이 날짜/시각/시간대 정보를 먼저 말하거나 그대로 출력하지 마세요.',
    ].join('\n'),
    role: 'system',
  };
};

export const createSystemHistory = (commonSystemPrompt: string): AIChatMessage[] => [
  ...(commonSystemPrompt.trim()
    ? [
        {
          content: commonSystemPrompt.trim(),
          role: 'system' as const,
        },
      ]
    : []),
];

export const createMessage = (
  role: ChatRole,
  text: string,
  modelName?: string,
  attachments?: MultimodalAttachment[],
): ChatMessage => ({
  attachments: attachments?.length ? attachments : undefined,
  createdAt: new Date(),
  id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  modelName,
  role,
  text,
});

export const createQueuedChatRequest = (
  prompt: string,
  attachments: MultimodalAttachment[],
): QueuedChatRequest => ({
  attachments,
  createdAt: new Date(),
  id: `queued-${Date.now()}-${Math.random().toString(36).slice(2)}`,
  prompt,
});


export const getAttachmentKey = (attachment: MultimodalAttachment) =>
  attachment.id ?? attachment.uri;

export const getAttachmentName = (
  attachment: MultimodalAttachment,
  fallbackName: string,
) => attachment.name?.trim() || fallbackName;

export const formatAttachmentSize = (sizeBytes?: number) => {
  if (
    typeof sizeBytes !== 'number' ||
    !Number.isFinite(sizeBytes) ||
    sizeBytes <= 0
  ) {
    return '';
  }

  if (sizeBytes < 1024) {
    return `${Math.round(sizeBytes)} B`;
  }

  if (sizeBytes < 1024 * 1024) {
    return `${(sizeBytes / 1024).toFixed(1)} KB`;
  }

  return `${(sizeBytes / (1024 * 1024)).toFixed(1)} MB`;
};

export const createAttachmentSummary = (
  attachments: MultimodalAttachment[],
  fallbackName: string,
) =>
  attachments
    .map(attachment => getAttachmentName(attachment, fallbackName))
    .join(', ');

export const createConversationHistory = (
  messages: ChatMessage[],
): AIChatMessage[] =>
  messages
    .filter(message => message.id !== 'welcome' && message.role !== 'system')
    .map(message => ({
      content: message.text.trim(),
      role: message.role,
    }))
    .filter(message => message.content.length > 0);
