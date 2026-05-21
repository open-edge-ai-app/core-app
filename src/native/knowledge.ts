import { NativeModules } from 'react-native';

import type { MultimodalAttachment } from './AIEngine';

export type LocationContext = {
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: number;
};

type KnowledgeNativeModule = {
  recognizeText?: (uri: string) => Promise<string>;
  getLocation?: () => Promise<LocationContext>;
};

const nativeModule = NativeModules.Knowledge as
  | KnowledgeNativeModule
  | undefined;

export const isOcrAvailable = (): boolean =>
  Boolean(nativeModule?.recognizeText);

export const isLocationAvailable = (): boolean =>
  Boolean(nativeModule?.getLocation);

// Mirrors iOS Vision OCR: extracts text from an image so it can feed the prompt.
export async function recognizeImageText(uri: string): Promise<string> {
  if (!nativeModule?.recognizeText) {
    return '';
  }
  try {
    const text = await nativeModule.recognizeText(uri);
    return text.trim();
  } catch {
    return '';
  }
}

// Mirrors iOS CoreLocation device context.
export async function getLocationContext(): Promise<LocationContext | null> {
  if (!nativeModule?.getLocation) {
    return null;
  }
  try {
    return await nativeModule.getLocation();
  } catch {
    return null;
  }
}

// Builds an OCR prompt snippet from image attachments (no-op without the module).
export async function buildAttachmentOcrContext(
  attachments: MultimodalAttachment[],
): Promise<string> {
  if (!isOcrAvailable()) {
    return '';
  }
  const images = attachments.filter(
    attachment => attachment.type === 'image' && Boolean(attachment.uri),
  );
  if (images.length === 0) {
    return '';
  }

  const parts: string[] = [];
  for (const image of images) {
    const text = await recognizeImageText(image.uri);
    if (text) {
      parts.push(`${image.name ?? 'image'}:\n${text}`);
    }
  }

  if (parts.length === 0) {
    return '';
  }
  return `첨부 이미지에서 인식한 텍스트(OCR):\n${parts.join('\n\n')}`;
}
