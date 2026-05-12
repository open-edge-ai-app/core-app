import { NativeModules, Platform } from 'react-native';

import type {
  MultimodalAttachment,
  MultimodalAttachmentType,
} from './AIEngine';

type FilePickerNativeModule = {
  pickAttachment?: () => Promise<MultimodalAttachment | null>;
};

const nativeModule = NativeModules.AIEngine as
  | FilePickerNativeModule
  | undefined;

const acceptedMimeTypes = [
  'image/*',
  'audio/*',
  'video/*',
  'application/pdf',
  'text/*',
  'application/json',
].join(',');

const createAttachmentId = () =>
  `attachment-${Date.now()}-${Math.random().toString(36).slice(2)}`;

const inferAttachmentType = (
  mimeType?: string,
  name = '',
): MultimodalAttachmentType => {
  if (mimeType?.startsWith('image/')) {
    return 'image';
  }

  if (mimeType?.startsWith('audio/')) {
    return 'audio';
  }

  if (mimeType?.startsWith('video/')) {
    return 'video';
  }

  const normalizedName = name.toLowerCase();
  if (/\.(png|jpe?g|webp|gif|heic)$/.test(normalizedName)) {
    return 'image';
  }

  if (/\.(mp3|wav|m4a|aac|ogg|flac)$/.test(normalizedName)) {
    return 'audio';
  }

  if (/\.(mp4|mov|m4v|webm|mkv)$/.test(normalizedName)) {
    return 'video';
  }

  return 'file';
};

const pickWebAttachment = () =>
  new Promise<MultimodalAttachment | null>(resolve => {
    if (typeof document === 'undefined') {
      resolve(null);
      return;
    }

    const input = document.createElement('input');
    input.accept = acceptedMimeTypes;
    input.style.display = 'none';
    input.type = 'file';

    let settled = false;
    let focusTimeoutId: ReturnType<typeof setTimeout> | null = null;

    function handleWindowFocus() {
      focusTimeoutId = setTimeout(() => {
        if (!input.files?.length) {
          finish(null);
        }
      }, 350);
    }

    function cleanup() {
      if (focusTimeoutId) {
        clearTimeout(focusTimeoutId);
      }
      window.removeEventListener('focus', handleWindowFocus);
      input.remove();
    }

    function finish(attachment: MultimodalAttachment | null) {
      if (settled) {
        return;
      }

      settled = true;
      cleanup();
      resolve(attachment);
    }

    input.addEventListener(
      'change',
      () => {
        const file = input.files?.[0] ?? null;

        if (!file) {
          finish(null);
          return;
        }

        finish({
          id: createAttachmentId(),
          mimeType: file.type || undefined,
          name: file.name,
          sizeBytes: file.size,
          type: inferAttachmentType(file.type, file.name),
          uri: URL.createObjectURL(file),
        });
      },
      { once: true },
    );

    document.body.appendChild(input);
    setTimeout(() => {
      window.addEventListener('focus', handleWindowFocus, { once: true });
    }, 0);
    input.click();
  });

export async function pickAttachment(): Promise<MultimodalAttachment | null> {
  if (Platform.OS === 'web') {
    return pickWebAttachment();
  }

  if (nativeModule?.pickAttachment) {
    return nativeModule.pickAttachment();
  }

  return null;
}
