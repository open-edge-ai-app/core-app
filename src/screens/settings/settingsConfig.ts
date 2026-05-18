import { I18nKey } from '../../i18n';
import { IndexingStatus } from '../../native/AIEngine';
import { type PersonalityPresetId } from '../../config/personalityPresets';

export const defaultStatus: IndexingStatus = {
  galleryEnabled: false,
  galleryIndexedItems: 0,
  indexedItems: 0,
  isAvailable: false,
  isIndexing: false,
  documentEnabled: false,
  documentIndexedItems: 0,
  smsEnabled: false,
  smsIndexedItems: 0,
};

export const getErrorMessage = (error: unknown) =>
  error instanceof Error ? error.message : String(error);

export const textSizeLabelKeys: Record<string, I18nKey> = {
  compact: 'settings.textSize.compact.label',
  default: 'settings.textSize.default.label',
  large: 'settings.textSize.large.label',
};

export const textSizeDescriptionKeys: Record<string, I18nKey> = {
  compact: 'settings.textSize.compact.description',
  default: 'settings.textSize.default.description',
  large: 'settings.textSize.large.description',
};

export const personalityLabelKeys: Record<PersonalityPresetId, I18nKey> = {
  analytical: 'settings.personality.analytical.label',
  balanced: 'settings.personality.balanced.label',
  concise: 'settings.personality.concise.label',
  friendly: 'settings.personality.friendly.label',
};

export const personalityDescriptionKeys: Record<PersonalityPresetId, I18nKey> = {
  analytical: 'settings.personality.analytical.description',
  balanced: 'settings.personality.balanced.description',
  concise: 'settings.personality.concise.description',
  friendly: 'settings.personality.friendly.description',
};

export const languageMenuGap = 8;
export const languageMenuMargin = 18;
export const languageMenuMaxHeight = 420;
export const languageMenuMinHeight = 220;
export const languageMenuBottomGap = 10;
export const languageSearchInputHeight = 47;

export const formatBytes = (bytes: number) => {
  if (bytes <= 0) {
    return '0 MB';
  }

  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
};
