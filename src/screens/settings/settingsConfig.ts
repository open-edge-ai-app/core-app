import { I18nKey } from '../../i18n';
import { IndexingStatus, ModelId, ModelStatus } from '../../native/AIEngine';
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

export const personalityDescriptionKeys: Record<PersonalityPresetId, I18nKey> =
  {
    analytical: 'settings.personality.analytical.description',
    balanced: 'settings.personality.balanced.description',
    concise: 'settings.personality.concise.description',
    friendly: 'settings.personality.friendly.description',
  };

export type SettingsModelOption = {
  description: string;
  id: Extract<ModelId, 'apple-foundation' | 'gemma-4'>;
  title: string;
};

export const settingsModelOptions: SettingsModelOption[] = [
  {
    description: 'System-managed on-device model on eligible iOS devices.',
    id: 'apple-foundation',
    title: 'Apple Intelligence',
  },
  {
    description: 'Downloadable local model for on-device inference.',
    id: 'gemma-4',
    title: 'Gemma 4',
  },
];

export const getSettingsModelStatus = (
  statuses: ModelStatus[],
  modelId: ModelId | string,
) =>
  statuses.find(status => {
    if (status.modelId === modelId) {
      return true;
    }

    const normalizedName = status.modelName.toLowerCase();
    if (modelId === 'apple-foundation') {
      return (
        normalizedName.includes('apple') ||
        normalizedName.includes('foundation')
      );
    }

    if (modelId === 'gemma-4') {
      return normalizedName.includes('gemma');
    }

    return false;
  }) ?? null;

export const mergeModelStatuses = (
  currentStatuses: ModelStatus[],
  updatedStatuses: Array<ModelStatus | null | undefined>,
) =>
  updatedStatuses.reduce<ModelStatus[]>((statuses, updatedStatus) => {
    if (!updatedStatus) {
      return statuses;
    }

    const updatedModelId =
      updatedStatus.modelId ??
      (updatedStatus.modelName.toLowerCase().includes('apple')
        ? 'apple-foundation'
        : 'gemma-4');

    return [
      ...statuses.filter(status => {
        const statusModelId =
          status.modelId ??
          (status.modelName.toLowerCase().includes('apple')
            ? 'apple-foundation'
            : 'gemma-4');
        return statusModelId !== updatedModelId;
      }),
      {
        ...updatedStatus,
        modelId: updatedModelId,
      },
    ];
  }, currentStatuses);

export const isSettingsSystemManagedModel = (
  modelId: ModelId | string,
  status?: ModelStatus | null,
) =>
  modelId === 'apple-foundation' ||
  Boolean(status?.systemManaged) ||
  Boolean(status?.modelName.toLowerCase().includes('apple'));

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
