import { NativeModules } from 'react-native';

type ProgressNativeModule = {
  showProgress?: (options: {
    id?: string;
    title?: string;
    text?: string;
  }) => Promise<string>;
  hideProgress?: (id: string) => Promise<boolean>;
};

const nativeModule = NativeModules.ProgressNotification as
  | ProgressNativeModule
  | undefined;

const DEFAULT_ID = 'ai-generation';

export const isProgressNotificationAvailable = (): boolean =>
  Boolean(nativeModule?.showProgress);

// Android analogue of the iOS Dynamic Island / Live Activity generation status.
// No-op when the native module is absent (iOS, web preview, tests).
export async function showGenerationProgress(
  text?: string,
  id: string = DEFAULT_ID,
): Promise<void> {
  if (!isProgressNotificationAvailable()) {
    return;
  }
  try {
    await nativeModule?.showProgress?.({ id, text });
  } catch {
    // best-effort
  }
}

export async function hideGenerationProgress(
  id: string = DEFAULT_ID,
): Promise<void> {
  if (!isProgressNotificationAvailable()) {
    return;
  }
  try {
    await nativeModule?.hideProgress?.(id);
  } catch {
    // best-effort
  }
}
