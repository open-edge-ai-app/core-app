import { NativeModules, Platform } from 'react-native';

type ClipboardNativeModule = {
  copyTextToClipboard?: (text: string) => Promise<boolean>;
};

const nativeModule = NativeModules.AIEngine as ClipboardNativeModule | undefined;

export async function copyToClipboard(text: string) {
  if (Platform.OS === 'web' && globalThis.navigator?.clipboard?.writeText) {
    await globalThis.navigator.clipboard.writeText(text);
    return true;
  }

  if (nativeModule?.copyTextToClipboard) {
    return nativeModule.copyTextToClipboard(text);
  }

  return false;
}
