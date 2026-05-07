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

type AIEngineNativeModule = {
  generateResponse?: (
    prompt: string,
    history?: AIChatMessage[],
  ) => Promise<string>;
  sendMessage?: (message: string) => Promise<string>;
  getIndexingStatus?: () => Promise<NativeIndexingStatus>;
  startIndexing?: () => Promise<void>;
};

type NativeIndexingStatus = Omit<IndexingStatus, 'isAvailable'> & {
  isAvailable?: boolean;
};

const nativeModule = NativeModules.AIEngine as AIEngineNativeModule | undefined;

const isNativeAvailable = () =>
  Boolean(nativeModule?.generateResponse || nativeModule?.sendMessage);

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
    if (nativeModule?.generateResponse) {
      return nativeModule.generateResponse(prompt, history);
    }

    if (nativeModule?.sendMessage) {
      return nativeModule.sendMessage(prompt);
    }

    return createDevelopmentResponse(prompt);
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
