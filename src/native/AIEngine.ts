import {NativeModules} from 'react-native';

export type IndexingStatus = {
  indexedItems: number;
  isIndexing: boolean;
  lastIndexedAt?: string;
};

type AIEngineModule = {
  sendMessage(message: string): Promise<string>;
  getIndexingStatus(): Promise<IndexingStatus>;
};

const fallbackEngine: AIEngineModule = {
  async sendMessage(message: string) {
    return `Native AIEngine is not linked yet. Received: ${message}`;
  },
  async getIndexingStatus() {
    return {
      indexedItems: 0,
      isIndexing: false,
    };
  },
};

const AIEngine: AIEngineModule =
  NativeModules.AIEngine == null
    ? fallbackEngine
    : (NativeModules.AIEngine as AIEngineModule);

export default AIEngine;
