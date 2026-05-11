import {NativeModules, Platform} from 'react-native';

export type AIChatRole = 'assistant' | 'user' | 'system';

export type AIChatMessage = {
  role: AIChatRole;
  content: string;
};

export type IndexingStatus = {
  isAvailable: boolean;
  isIndexing: boolean;
  indexedItems: number;
  lastIndexedAt?: string;
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
  options?: {
    useRag?: boolean;
    stream?: boolean;
  };
};

export type AIResponse = {
  type: 'text' | 'memory' | 'action' | 'error';
  message: string;
  route: 'direct' | 'rag' | 'agent' | 'invalid';
  modalities: MultimodalAttachmentType[];
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
  getIndexingStatus?: () => Promise<NativeIndexingStatus>;
  getStartupState?: () => Promise<StartupState>;
  getModelStatus?: () => Promise<ModelStatus>;
  getRuntimeStatus?: () => Promise<RuntimeStatus>;
  loadModel?: () => Promise<RuntimeStatus>;
  unloadModel?: () => Promise<RuntimeStatus>;
  downloadModel?: () => Promise<ModelStatus>;
  ensureModelDownloaded?: () => Promise<ModelStatus>;
  cancelModelDownload?: () => Promise<ModelStatus>;
  startIndexing?: () => Promise<void>;
};

const nativeModule = NativeModules.AIEngine as AIEngineNativeModule | undefined;

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

async function createDevelopmentResponse(prompt: string) {
  await sleep(450);

  return [
    '아직 Kotlin AIEngineModule이 연결되지 않았습니다.',
    `프론트 입력은 정상 처리됐고, 마지막 메시지는 "${prompt}"입니다.`,
  ].join('\n');
}

export const AIEngine = {
  isAvailable() {
    return isNativeAvailable();
  },

  async generateResponse(prompt: string, history: AIChatMessage[] = []) {
    if (nativeModule?.sendMultimodalMessage) {
      const response = await nativeModule.sendMultimodalMessage({
        text: prompt,
        attachments: [],
      });
      return response.message;
    }

    if (nativeModule?.generateResponse) {
      return nativeModule.generateResponse(prompt, history);
    }

    if (nativeModule?.sendMessage) {
      return nativeModule.sendMessage(prompt);
    }

    return createDevelopmentResponse(prompt);
  },

  async sendMultimodalMessage(message: MultimodalMessage): Promise<AIResponse> {
    if (nativeModule?.sendMultimodalMessage) {
      return nativeModule.sendMultimodalMessage(message);
    }

    const modalities = message.attachments?.map(attachment => attachment.type) ?? [];
    return {
      type: 'text',
      message: await createDevelopmentResponse(message.text ?? ''),
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
        lastIndexedAt: status.lastIndexedAt,
      };
    }

    return {
      indexedItems: 0,
      isAvailable: false,
      isIndexing: false,
      lastIndexedAt: undefined,
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

  async startIndexing() {
    if (nativeModule?.startIndexing) {
      return nativeModule.startIndexing();
    }

    throw new Error(
      `AIEngine native module is not linked on ${Platform.OS}.`,
    );
  },
};

export default AIEngine;
