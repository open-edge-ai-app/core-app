import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

export type AIChatRole = 'assistant' | 'user' | 'system';

export type AIChatMessage = {
  role: AIChatRole;
  content: string;
};

export type StoredChatMessage = {
  id: string;
  role: AIChatRole;
  text: string;
  createdAt: number;
  modelName?: string | null;
};

export type StoredChatHistoryEvent = {
  id: number;
  chatId: string;
  eventType: string;
  payload: string;
  createdAt: number;
};

export type StoredChatSession = {
  chat: {
    id: string;
    title: string;
    createdAt: number;
    updatedAt: number;
  };
  messages: StoredChatMessage[];
  history: StoredChatHistoryEvent[];
};

export type ChatCompactionResult = {
  chatId: string;
  compacted: boolean;
  trigger: 'manual' | 'auto' | string;
  message: string;
  beforeTokenEstimate: number;
  afterTokenEstimate: number;
  compactedUntilMessageId?: string | null;
  snapshotId: number;
};

export type IndexingStatus = {
  isAvailable: boolean;
  isIndexing: boolean;
  indexedItems: number;
  lastIndexedAt?: string;
  lastError?: string | null;
  smsEnabled: boolean;
  galleryEnabled: boolean;
  documentEnabled: boolean;
  smsIndexedItems: number;
  galleryIndexedItems: number;
  documentIndexedItems: number;
};

export type IndexingSource = 'sms' | 'gallery' | 'image' | 'document';

export type IndexingResult = {
  smsIndexed: number;
  galleryIndexed: number;
  documentIndexed: number;
  deleted: number;
  skipped: number;
  status: IndexingStatus;
};

export type ModelStatus = {
  modelName: string;
  installed: boolean;
  isDownloading: boolean;
  bytesDownloaded: number;
  totalBytes: number;
  localPath: string;
  downloadUrl: string;
  error?: string | null;
  started?: boolean;
};

export type StartupState = {
  ready: boolean;
  nextAction: 'continue' | 'show_model_download' | 'show_download_progress';
  message: string;
  modelStatus: ModelStatus;
};

export type RuntimeStatus = {
  modelInstalled: boolean;
  loaded: boolean;
  loading: boolean;
  canGenerate: boolean;
  localPath: string;
  error?: string | null;
};

export type MultimodalAttachmentType = 'image' | 'audio' | 'video' | 'file';

export type MultimodalAttachment = {
  id?: string;
  type: MultimodalAttachmentType;
  uri: string;
  mimeType?: string;
  name?: string;
  sizeBytes?: number;
  width?: number;
  height?: number;
};

export type MultimodalMessage = {
  text?: string;
  attachments?: MultimodalAttachment[];
  history?: AIChatMessage[];
  options?: {
    chatSessionId?: string;
    useRag?: boolean;
    stream?: boolean;
  };
};

export type AIResponseStreamCallbacks = {
  onChunk: (chunk: string) => void;
  onReasoning?: (reasoning: string) => void;
};

export type AIResponseStreamOptions = {
  attachments?: MultimodalAttachment[];
  chatSessionId?: string;
};

export type AIResponse = {
  type: 'text' | 'memory' | 'action' | 'error';
  message: string;
  reasoning?: string | null;
  route: 'direct' | 'rag' | 'agent' | 'invalid';
  modalities: MultimodalAttachmentType[];
};

type NativeStreamEvent = {
  chunk?: string;
  done?: boolean;
  error?: string;
  message?: string;
  reasoning?: string;
  requestId?: string;
};

type NativeIndexingStatus = Omit<IndexingStatus, 'isAvailable'> & {
  isAvailable?: boolean;
};

type AIEngineNativeModule = {
  generateResponse?: (
    prompt: string,
    history?: AIChatMessage[],
  ) => Promise<string>;
  sendMessage?: (message: string) => Promise<string>;
  sendMultimodalMessage?: (message: MultimodalMessage) => Promise<AIResponse>;
  sendMultimodalMessageStream?: (
    requestId: string,
    message: MultimodalMessage,
  ) => Promise<{ started: boolean }>;
  getIndexingStatus?: () => Promise<NativeIndexingStatus>;
  getStartupState?: () => Promise<StartupState>;
  getModelStatus?: () => Promise<ModelStatus>;
  getRuntimeStatus?: () => Promise<RuntimeStatus>;
  loadModel?: () => Promise<RuntimeStatus>;
  unloadModel?: () => Promise<RuntimeStatus>;
  downloadModel?: () => Promise<ModelStatus>;
  ensureModelDownloaded?: () => Promise<ModelStatus>;
  cancelModelDownload?: () => Promise<ModelStatus>;
  startIndexing?: () => Promise<IndexingResult>;
  startIndexingSource?: (source: IndexingSource) => Promise<IndexingResult>;
  setIndexingSourceEnabled?: (
    source: IndexingSource,
    enabled: boolean,
  ) => Promise<IndexingResult>;
  deleteIndexingSource?: (source: IndexingSource) => Promise<IndexingResult>;
  saveChatSession?: (
    sessionId: string,
    title: string,
    messages: StoredChatMessage[],
  ) => Promise<void>;
  loadChatSession?: (sessionId: string) => Promise<StoredChatSession | null>;
  listChatSessions?: () => Promise<StoredChatSession['chat'][]>;
  deleteChatSession?: (sessionId: string) => Promise<number>;
  compactChatSession?: (
    sessionId: string,
    trigger: 'manual' | 'auto' | string,
  ) => Promise<ChatCompactionResult>;
  generateChatTitle?: (
    userMessage: string,
    assistantMessage: string,
  ) => Promise<string>;
  addListener: (eventName: string) => void;
  removeListeners: (count: number) => void;
};

type NativePermissionsAndroidModule = {
  requestMultiplePermissions?: (
    permissions: string[],
  ) => Promise<Record<string, string>>;
};

const nativeModule = NativeModules.AIEngine as AIEngineNativeModule | undefined;
const nativePermissionsAndroid = NativeModules.PermissionsAndroid as
  | NativePermissionsAndroidModule
  | undefined;
const AI_ENGINE_STREAM_EVENT = 'AIEngineStreamChunk';

const androidPermissions = {
  READ_EXTERNAL_STORAGE: 'android.permission.READ_EXTERNAL_STORAGE',
  READ_MEDIA_IMAGES: 'android.permission.READ_MEDIA_IMAGES',
  READ_SMS: 'android.permission.READ_SMS',
} as const;

const androidPermissionResults = {
  GRANTED: 'granted',
} as const;

const modelDownloadUrl =
  'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true';

const fallbackModelStatus: ModelStatus = {
  modelName: 'gemma-4-E2B-it',
  installed: false,
  isDownloading: false,
  bytesDownloaded: 0,
  totalBytes: 2588147712,
  localPath: '',
  downloadUrl: modelDownloadUrl,
};

const fallbackRuntimeStatus: RuntimeStatus = {
  modelInstalled: false,
  loaded: false,
  loading: false,
  canGenerate: false,
  localPath: '',
};

const isNativeAvailable = () =>
  Boolean(
    nativeModule?.sendMultimodalMessage ||
      nativeModule?.generateResponse ||
      nativeModule?.sendMessage,
  );

const sleep = (durationMs: number) =>
  new Promise<void>(resolve => setTimeout(() => resolve(), durationMs));

async function ensureRuntimeReadyForGeneration() {
  if (!nativeModule?.sendMultimodalMessage) {
    return null;
  }

  const modelStatus = await (nativeModule.getModelStatus?.() ??
    Promise.resolve(fallbackModelStatus));

  if (!modelStatus.installed) {
    if (modelStatus.isDownloading) {
      const percent =
        modelStatus.totalBytes > 0
          ? Math.floor(
              (modelStatus.bytesDownloaded / modelStatus.totalBytes) * 100,
            )
          : 0;
      return `모델을 다운로드하는 중입니다. 현재 ${percent}% 완료됐습니다. 다운로드가 끝난 뒤 다시 시도해주세요.`;
    }

    return `Gemma 4 모델이 아직 설치되지 않았습니다. 설정 화면에서 모델을 다운로드한 뒤 다시 시도해주세요.\n${modelStatus.downloadUrl}`;
  }

  const runtimeStatus = await (nativeModule.getRuntimeStatus?.() ??
    Promise.resolve(fallbackRuntimeStatus));

  if (runtimeStatus.canGenerate) {
    return null;
  }

  const loadedStatus = await (nativeModule.loadModel?.() ??
    Promise.resolve(fallbackRuntimeStatus));

  if (loadedStatus.canGenerate) {
    return null;
  }

  return loadedStatus.error
    ? `모델 런타임을 켜지 못했습니다: ${loadedStatus.error}`
    : '모델 런타임을 켜지 못했습니다. 설정 화면에서 모델 상태를 확인해주세요.';
}

async function createDevelopmentResponse(
  prompt: string,
  history: AIChatMessage[] = [],
) {
  await sleep(450);

  const promptWithHistory = createPromptWithHistory(prompt, history);
  const priorConversation = getPriorConversationMessages(prompt, history);

  return [
    '아직 Kotlin AIEngineModule이 연결되지 않았습니다.',
    priorConversation.length > 0
      ? `이전 대화 ${priorConversation.length}개를 포함해 응답 요청을 구성했습니다.`
      : '이전 대화 없이 현재 메시지만 응답 요청에 사용했습니다.',
    `모델에 전달될 프롬프트:\n${promptWithHistory}`,
  ].join('\n');
}

const createFallbackChatTitle = (text: string) => {
  const normalized = text.replace(/\s+/g, ' ').trim();

  if (!normalized) {
    return 'New chat';
  }

  return normalized.length <= 40 ? normalized : `${normalized.slice(0, 40)}...`;
};

const createStreamRequestId = () =>
  `stream-${Date.now()}-${Math.random().toString(36).slice(2)}`;

const splitResponseForStreaming = (text: string) => {
  const chunks = text.match(/\S+\s*|\s+/g) ?? [];

  if (chunks.length > 0) {
    return chunks.flatMap(chunk => {
      if (chunk.length <= 16) {
        return [chunk];
      }

      const splitChunks: string[] = [];
      for (let index = 0; index < chunk.length; index += 8) {
        splitChunks.push(chunk.slice(index, index + 8));
      }
      return splitChunks;
    });
  }

  return text ? [text] : [];
};

const streamCompletedText = async (
  text: string,
  { onChunk }: AIResponseStreamCallbacks,
) => {
  const chunks = splitResponseForStreaming(text);

  for (const chunk of chunks) {
    onChunk(chunk);
    await sleep(18);
  }

  return text;
};

const createNativeStreamEmitter = () => {
  if (!nativeModule?.sendMultimodalMessageStream) {
    return null;
  }

  try {
    return new NativeEventEmitter(nativeModule);
  } catch {
    return null;
  }
};

const getSystemInstructions = (history: AIChatMessage[]) =>
  history
    .filter(message => message.role === 'system')
    .map(message => message.content.trim())
    .filter(Boolean)
    .join('\n\n');

const normalizePromptText = (text: string) => text.replace(/\s+/g, ' ').trim();

const getPriorConversationMessages = (
  prompt: string,
  history: AIChatMessage[],
) => {
  const conversationMessages = history
    .filter(message => message.role !== 'system')
    .map(message => ({
      ...message,
      content: message.content.trim(),
    }))
    .filter(message => message.content.length > 0);

  const lastMessage = conversationMessages[conversationMessages.length - 1];
  if (
    lastMessage?.role === 'user' &&
    normalizePromptText(lastMessage.content) === normalizePromptText(prompt)
  ) {
    return conversationMessages.slice(0, -1);
  }

  return conversationMessages;
};

const formatConversationHistory = (messages: AIChatMessage[]) =>
  messages
    .map(message => {
      const roleLabel =
        message.role === 'assistant'
          ? 'assistant'
          : message.role === 'user'
          ? 'user'
          : 'system';
      return `${roleLabel}: ${message.content}`;
    })
    .join('\n');

export const createPromptWithHistory = (
  prompt: string,
  history: AIChatMessage[],
) => {
  const systemInstructions = getSystemInstructions(history);
  const priorConversation = getPriorConversationMessages(prompt, history);
  const sections: string[] = [];

  if (systemInstructions) {
    sections.push(
      [
        '다음 시스템 지침을 우선 적용하세요.',
        systemInstructions,
      ].join('\n'),
    );
  }

  if (priorConversation.length > 0) {
    sections.push(
      [
        '이전 대화 내용입니다. 사용자가 이전 내용, 방금 말한 것, 위 내용, 이어서 등의 표현을 쓰면 이 대화 맥락을 기준으로 답하세요.',
        formatConversationHistory(priorConversation),
      ].join('\n'),
    );
  }

  sections.push(['현재 사용자 요청:', prompt].join('\n'));

  if (
    sections.length === 1 &&
    !systemInstructions &&
    priorConversation.length === 0
  ) {
    return prompt;
  }

  return sections.join('\n\n');
};

export const AIEngine = {
  isAvailable() {
    return isNativeAvailable();
  },

  async generateResponse(
    prompt: string,
    history: AIChatMessage[] = [],
    options: { chatSessionId?: string } = {},
  ) {
    if (nativeModule?.sendMultimodalMessage) {
      const blockedReason = await ensureRuntimeReadyForGeneration();
      if (blockedReason) {
        return blockedReason;
      }

      const response = await nativeModule.sendMultimodalMessage({
        attachments: [],
        history,
        options: {
          chatSessionId: options.chatSessionId,
        },
        text: prompt,
      });
      return response.message;
    }

    if (nativeModule?.generateResponse) {
      return nativeModule.generateResponse(prompt, history);
    }

    if (nativeModule?.sendMessage) {
      return nativeModule.sendMessage(createPromptWithHistory(prompt, history));
    }

    return createDevelopmentResponse(prompt, history);
  },

  async generateResponseStream(
    prompt: string,
    history: AIChatMessage[] = [],
    callbacks: AIResponseStreamCallbacks,
    options: AIResponseStreamOptions = {},
  ) {
    const attachments = options.attachments ?? [];

    if (nativeModule?.sendMultimodalMessageStream) {
      const sendMultimodalMessageStream =
        nativeModule.sendMultimodalMessageStream.bind(nativeModule);
      const blockedReason = await ensureRuntimeReadyForGeneration();
      if (blockedReason) {
        return streamCompletedText(blockedReason, callbacks);
      }

      const emitter = createNativeStreamEmitter();
      if (emitter) {
        const requestId = createStreamRequestId();

        return new Promise<string>((resolve, reject) => {
          let response = '';
          let settled = false;
          let subscription: { remove: () => void } | null = null;

          const cleanup = () => {
            subscription?.remove();
          };

          const complete = (text: string) => {
            if (settled) {
              return;
            }

            settled = true;
            cleanup();
            resolve(text);
          };

          const fail = (error: Error) => {
            if (settled) {
              return;
            }

            settled = true;
            cleanup();
            reject(error);
          };

          subscription = emitter.addListener(
            AI_ENGINE_STREAM_EVENT,
            (event: NativeStreamEvent) => {
              if (event.requestId !== requestId) {
                return;
              }

              if (event.error) {
                fail(new Error(event.error));
                return;
              }

              if (event.chunk) {
                response += event.chunk;
                callbacks.onChunk(event.chunk);
              }

              if (event.done) {
                if (event.reasoning) {
                  callbacks.onReasoning?.(event.reasoning);
                }
                complete(event.message ?? response);
              }
            },
          );

          sendMultimodalMessageStream(requestId, {
            attachments,
            history,
            options: {
              chatSessionId: options.chatSessionId,
              stream: true,
            },
            text: prompt,
          }).catch(error => {
            fail(
              error instanceof Error
                ? error
                : new Error('AI 응답 스트리밍을 시작하지 못했습니다.'),
            );
          });
        });
      }
    }

    if (attachments.length > 0 && nativeModule?.sendMultimodalMessage) {
      const response = await this.sendMultimodalMessage({
        attachments,
        history,
        options: {
          chatSessionId: options.chatSessionId,
        },
        text: prompt,
      });
      return streamCompletedText(response.message, callbacks);
    }

    const response = await this.generateResponse(prompt, history, options);
    return streamCompletedText(response, callbacks);
  },

  async sendMultimodalMessage(message: MultimodalMessage): Promise<AIResponse> {
    if (nativeModule?.sendMultimodalMessage) {
      const blockedReason = await ensureRuntimeReadyForGeneration();
      if (blockedReason) {
        return {
          type: 'error',
          message: blockedReason,
          route: 'invalid',
          modalities:
            message.attachments?.map(attachment => attachment.type) ?? [],
        };
      }

      return nativeModule.sendMultimodalMessage(message);
    }

    const modalities =
      message.attachments?.map(attachment => attachment.type) ?? [];
    return {
      type: 'text',
      message: await createDevelopmentResponse(
        message.text ?? '',
        message.history ?? [],
      ),
      route: 'direct',
      modalities,
    };
  },

  async getIndexingStatus(): Promise<IndexingStatus> {
    if (nativeModule?.getIndexingStatus) {
      const status = await nativeModule.getIndexingStatus();

      return {
        indexedItems: status.indexedItems,
        isAvailable: status.isAvailable ?? isNativeAvailable(),
        isIndexing: status.isIndexing,
        lastError: status.lastError,
        lastIndexedAt: status.lastIndexedAt,
        smsEnabled: status.smsEnabled ?? false,
        galleryEnabled: status.galleryEnabled ?? false,
        documentEnabled: status.documentEnabled ?? false,
        smsIndexedItems: status.smsIndexedItems ?? 0,
        galleryIndexedItems: status.galleryIndexedItems ?? 0,
        documentIndexedItems: status.documentIndexedItems ?? 0,
      };
    }

    return {
      indexedItems: 0,
      isAvailable: false,
      isIndexing: false,
      lastError: undefined,
      lastIndexedAt: undefined,
      smsEnabled: false,
      galleryEnabled: false,
      documentEnabled: false,
      smsIndexedItems: 0,
      galleryIndexedItems: 0,
      documentIndexedItems: 0,
    };
  },

  async getStartupState(): Promise<StartupState> {
    if (nativeModule?.getStartupState) {
      return nativeModule.getStartupState();
    }

    const modelStatus = await this.getModelStatus();
    return {
      ready: modelStatus.installed,
      nextAction: modelStatus.installed
        ? 'continue'
        : modelStatus.isDownloading
        ? 'show_download_progress'
        : 'show_model_download',
      message: modelStatus.installed
        ? 'Model is installed. On-device inference is ready.'
        : 'Model is required before local inference can start.',
      modelStatus,
    };
  },

  async getModelStatus(): Promise<ModelStatus> {
    return nativeModule?.getModelStatus?.() ?? fallbackModelStatus;
  },

  async getRuntimeStatus(): Promise<RuntimeStatus> {
    return nativeModule?.getRuntimeStatus?.() ?? fallbackRuntimeStatus;
  },

  async loadModel(): Promise<RuntimeStatus> {
    return nativeModule?.loadModel?.() ?? fallbackRuntimeStatus;
  },

  async unloadModel(): Promise<RuntimeStatus> {
    return nativeModule?.unloadModel?.() ?? fallbackRuntimeStatus;
  },

  async downloadModel(): Promise<ModelStatus> {
    return nativeModule?.downloadModel?.() ?? fallbackModelStatus;
  },

  async ensureModelDownloaded(): Promise<ModelStatus> {
    return nativeModule?.ensureModelDownloaded?.() ?? fallbackModelStatus;
  },

  async cancelModelDownload(): Promise<ModelStatus> {
    return nativeModule?.cancelModelDownload?.() ?? fallbackModelStatus;
  },

  async startIndexing(): Promise<IndexingResult> {
    await this.requestIndexingPermissions();

    if (nativeModule?.startIndexing) {
      return nativeModule.startIndexing();
    }

    throw new Error(`AIEngine native module is not linked on ${Platform.OS}.`);
  },

  async startIndexingSource(source: IndexingSource): Promise<IndexingResult> {
    await this.requestIndexingPermissions(source);

    if (nativeModule?.startIndexingSource) {
      return nativeModule.startIndexingSource(source);
    }

    throw new Error(`AIEngine native module is not linked on ${Platform.OS}.`);
  },

  async setIndexingSourceEnabled(
    source: IndexingSource,
    enabled: boolean,
  ): Promise<IndexingResult> {
    if (enabled) {
      await this.requestIndexingPermissions(source);
    }

    if (nativeModule?.setIndexingSourceEnabled) {
      return nativeModule.setIndexingSourceEnabled(source, enabled);
    }

    throw new Error(`AIEngine native module is not linked on ${Platform.OS}.`);
  },

  async deleteIndexingSource(source: IndexingSource): Promise<IndexingResult> {
    if (nativeModule?.deleteIndexingSource) {
      return nativeModule.deleteIndexingSource(source);
    }

    throw new Error(`AIEngine native module is not linked on ${Platform.OS}.`);
  },

  async requestIndexingPermissions(source?: IndexingSource) {
    if (Platform.OS !== 'android') {
      return true;
    }

    const mediaPermission =
      Number(Platform.Version) >= 33
        ? 'android.permission.READ_MEDIA_IMAGES'
        : androidPermissions.READ_EXTERNAL_STORAGE;
    const permissions =
      source === 'sms'
        ? [androidPermissions.READ_SMS]
        : source === 'gallery' || source === 'image'
        ? [mediaPermission]
        : source === 'document'
        ? Number(Platform.Version) >= 33
          ? []
          : [androidPermissions.READ_EXTERNAL_STORAGE]
        : [androidPermissions.READ_SMS, mediaPermission];

    if (permissions.length === 0) {
      return true;
    }

    if (!nativePermissionsAndroid?.requestMultiplePermissions) {
      throw new Error('Android permission module is not available.');
    }

    const results = await nativePermissionsAndroid.requestMultiplePermissions(
      permissions,
    );

    return permissions.every(
      permission => results[permission] === androidPermissionResults.GRANTED,
    );
  },

  async saveChatSession(
    sessionId: string,
    title: string,
    messages: StoredChatMessage[],
  ) {
    return nativeModule?.saveChatSession?.(sessionId, title, messages);
  },

  async loadChatSession(sessionId: string): Promise<StoredChatSession | null> {
    return nativeModule?.loadChatSession?.(sessionId) ?? null;
  },

  async listChatSessions(): Promise<StoredChatSession['chat'][]> {
    return nativeModule?.listChatSessions?.() ?? [];
  },

  async deleteChatSession(sessionId: string): Promise<number> {
    return nativeModule?.deleteChatSession?.(sessionId) ?? 0;
  },

  async compactChatSession(
    sessionId: string,
    trigger: 'manual' | 'auto' | string = 'manual',
  ): Promise<ChatCompactionResult> {
    if (!nativeModule?.compactChatSession) {
      return {
        afterTokenEstimate: 0,
        beforeTokenEstimate: 0,
        chatId: sessionId,
        compacted: false,
        message: 'AIEngine native module is not linked.',
        snapshotId: 0,
        trigger,
      };
    }

    const blockedReason = await ensureRuntimeReadyForGeneration();
    if (blockedReason) {
      return {
        afterTokenEstimate: 0,
        beforeTokenEstimate: 0,
        chatId: sessionId,
        compacted: false,
        message: blockedReason,
        snapshotId: 0,
        trigger,
      };
    }

    return nativeModule.compactChatSession(sessionId, trigger);
  },

  async generateChatTitle(
    userMessage: string,
    assistantMessage: string,
  ): Promise<string> {
    const fallbackTitle = createFallbackChatTitle(userMessage);

    if (!nativeModule?.generateChatTitle) {
      return fallbackTitle;
    }

    const blockedReason = await ensureRuntimeReadyForGeneration();
    if (blockedReason) {
      return fallbackTitle;
    }

    const title = await nativeModule.generateChatTitle(
      userMessage,
      assistantMessage,
    );
    return createFallbackChatTitle(title || fallbackTitle);
  },
};

export default AIEngine;
