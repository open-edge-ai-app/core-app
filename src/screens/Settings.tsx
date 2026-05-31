import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Image,
  Linking,
  Platform,
  Pressable,
  ScrollView,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import AppIcon from '../components/AppIcon';
import { Badge, Button, Separator } from '../components/ui';
import {
  appInfo,
  contributionLinks,
  openSourcePackages,
  repositoryUrl,
} from '../config/appInfo';
import { brandAssets } from '../config/branding';
import {
  defaultPersonalityPresetId,
  getPersonalityPreset,
  personalityPresets,
} from '../config/personalityPresets';
import { LocaleCode, useI18n } from '../i18n';
import AIEngine, {
  IndexingResult,
  IndexingStatus,
  ModelId,
  ModelStatus,
  RuntimeStatus,
} from '../native/AIEngine';
import {
  ScaledText as Text,
  ScaledTextInput as TextInput,
  useDisplaySettings,
} from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors } from '../theme/tokens';
import {
  InfoLinkRow,
  SearchableLanguageSelect,
  SettingsNavigationRow,
  SettingsSection,
  SettingsToggle,
  StatusRow,
} from './settings/SettingsComponents';
import {
  SETTINGS_CONTENT_BOTTOM_PADDING,
  styles,
} from './settings/settingsStyles';
import {
  defaultStatus,
  formatBytes,
  getErrorMessage,
  getSettingsModelStatus,
  isSettingsSystemManagedModel,
  mergeModelStatuses,
  personalityDescriptionKeys,
  personalityLabelKeys,
  settingsModelOptions,
  textSizeDescriptionKeys,
  textSizeLabelKeys,
} from './settings/settingsConfig';

type SettingsProps = {
  activePanel: SettingsPanelId;
  onModelStateChange?: (state: {
    modelStatus: ModelStatus | null;
    modelStatuses?: ModelStatus[];
    runtimeStatus: RuntimeStatus | null;
  }) => void;
  onPanelChange: (panel: SettingsPanelId) => void;
  onPersonalCustomizationChange: (
    settings: PersonalCustomizationSettings,
  ) => void;
  personalCustomization: PersonalCustomizationSettings;
  selectedModelId?: ModelId | string;
};

export type SettingsPanelId =
  | 'root'
  | 'personalCustomization'
  | 'appearance'
  | 'model'
  | 'embedding'
  | 'about';

export type PersonalCustomizationSettings = {
  customInstructions: string;
  memoryEnabled: boolean;
  personality: string;
  savedMemories: string[];
  userName: string;
};

function Settings({
  activePanel,
  onModelStateChange,
  onPanelChange,
  onPersonalCustomizationChange,
  personalCustomization,
  selectedModelId = 'gemma-4',
}: SettingsProps) {
  const { locale, selectedLocale, setLocale, supportedLocales, t } = useI18n();
  const insets = useSafeAreaInsets();
  const [status, setStatus] = useState<IndexingStatus>(defaultStatus);
  const [modelPanelModelId, setModelPanelModelId] = useState<ModelId | string>(
    selectedModelId,
  );
  const [modelStatus, setModelStatus] = useState<ModelStatus | null>(null);
  const [modelStatuses, setModelStatuses] = useState<ModelStatus[]>([]);
  const [runtimeStatus, setRuntimeStatus] = useState<RuntimeStatus | null>(
    null,
  );
  const [isLanguageSelectOpen, setIsLanguageSelectOpen] = useState(false);
  const [languageQuery, setLanguageQuery] = useState('');
  const { selectedTextSize, setTextSize, textSize, textSizes } =
    useDisplaySettings();

  const selectedTextSizeLabel = t(
    textSizeLabelKeys[selectedTextSize.id] ?? 'settings.textSize.default.label',
  );
  const selectedTextSizeDescription = t(
    textSizeDescriptionKeys[selectedTextSize.id] ??
      'settings.textSize.default.description',
  );
  const selectedPersonalityPreset = getPersonalityPreset(
    personalCustomization.personality,
  );
  const visibleSettingsModelOptions = useMemo(
    () =>
      settingsModelOptions.filter(
        option => Platform.OS === 'ios' || option.id !== 'apple-foundation',
      ),
    [],
  );
  const defaultVisibleModelId = visibleSettingsModelOptions[0]?.id ?? 'gemma-4';
  const visibleSelectedModelId = visibleSettingsModelOptions.some(
    option => option.id === selectedModelId,
  )
    ? selectedModelId
    : defaultVisibleModelId;
  const activeModelId = visibleSettingsModelOptions.some(
    option => option.id === modelPanelModelId,
  )
    ? modelPanelModelId
    : visibleSelectedModelId;
  const getVisibleModelStatuses = useCallback(
    (statuses: ModelStatus[]) =>
      statuses.filter(candidateStatus =>
        visibleSettingsModelOptions.some(option =>
          Boolean(getSettingsModelStatus([candidateStatus], option.id)),
        ),
      ),
    [visibleSettingsModelOptions],
  );
  const visibleLocales = useMemo(() => {
    const normalizedQuery = languageQuery.trim().toLowerCase();

    if (!normalizedQuery) {
      return supportedLocales;
    }

    return supportedLocales.filter(language =>
      [
        language.code,
        language.englishName,
        language.nativeName,
        ...language.searchTags,
      ]
        .join(' ')
        .toLowerCase()
        .includes(normalizedQuery),
    );
  }, [languageQuery, supportedLocales]);

  useEffect(() => {
    setModelPanelModelId(visibleSelectedModelId);
  }, [visibleSelectedModelId]);

  const refreshStatus = useCallback(async () => {
    const [nextStatus, nextModelStatuses, nextModelStatus, nextRuntimeStatus] =
      await Promise.all([
        AIEngine.getIndexingStatus(),
        AIEngine.getModelStatuses(),
        AIEngine.getModelStatusForModel(activeModelId),
        AIEngine.getRuntimeStatus(activeModelId),
      ]);
    const nextMergedModelStatuses = mergeModelStatuses(nextModelStatuses, [
      nextModelStatus,
    ]);
    const nextVisibleModelStatuses = getVisibleModelStatuses(
      nextMergedModelStatuses,
    );
    const nextSelectedModelStatus =
      getSettingsModelStatus(
        nextVisibleModelStatuses,
        visibleSelectedModelId,
      ) ?? nextModelStatus;
    setStatus(nextStatus);
    setModelStatuses(nextVisibleModelStatuses);
    setModelStatus(nextModelStatus);
    setRuntimeStatus(nextRuntimeStatus);
    onModelStateChange?.({
      modelStatus: nextSelectedModelStatus,
      modelStatuses: nextVisibleModelStatuses,
      runtimeStatus:
        activeModelId === visibleSelectedModelId ? nextRuntimeStatus : null,
    });
  }, [
    activeModelId,
    getVisibleModelStatuses,
    onModelStateChange,
    visibleSelectedModelId,
  ]);

  useEffect(() => {
    refreshStatus();
  }, [refreshStatus]);

  useEffect(() => {
    if (!modelStatus?.isDownloading) {
      return;
    }

    const interval = setInterval(refreshStatus, 1500);
    return () => clearInterval(interval);
  }, [modelStatus?.isDownloading, refreshStatus]);

  const downloadProgress =
    modelStatus == null || modelStatus.totalBytes <= 0
      ? 0
      : Math.min(1, modelStatus.bytesDownloaded / modelStatus.totalBytes);

  const handleDownloadModel = useCallback(async () => {
    const nextStatus = await AIEngine.ensureModelDownloaded(activeModelId);
    const nextModelStatuses = getVisibleModelStatuses(
      mergeModelStatuses(modelStatuses, [nextStatus]),
    );
    const nextSelectedModelStatus =
      getSettingsModelStatus(nextModelStatuses, visibleSelectedModelId) ??
      nextStatus;
    setModelStatuses(nextModelStatuses);
    setModelStatus(nextStatus);
    onModelStateChange?.({
      modelStatus: nextSelectedModelStatus,
      modelStatuses: nextModelStatuses,
      runtimeStatus:
        activeModelId === visibleSelectedModelId ? runtimeStatus : null,
    });
  }, [
    activeModelId,
    getVisibleModelStatuses,
    modelStatuses,
    onModelStateChange,
    runtimeStatus,
    visibleSelectedModelId,
  ]);

  const handleCancelModelDownload = useCallback(async () => {
    const nextStatus = await AIEngine.cancelModelDownload(activeModelId);
    const nextModelStatuses = getVisibleModelStatuses(
      mergeModelStatuses(modelStatuses, [nextStatus]),
    );
    const nextSelectedModelStatus =
      getSettingsModelStatus(nextModelStatuses, visibleSelectedModelId) ??
      nextStatus;
    setModelStatuses(nextModelStatuses);
    setModelStatus(nextStatus);
    onModelStateChange?.({
      modelStatus: nextSelectedModelStatus,
      modelStatuses: nextModelStatuses,
      runtimeStatus:
        activeModelId === visibleSelectedModelId ? runtimeStatus : null,
    });
  }, [
    activeModelId,
    getVisibleModelStatuses,
    modelStatuses,
    onModelStateChange,
    runtimeStatus,
    visibleSelectedModelId,
  ]);

  const handleLoadModel = useCallback(async () => {
    const loadingStatus: RuntimeStatus = {
      canGenerate: false,
      error: null,
      loaded: false,
      loading: true,
      localPath: modelStatus?.localPath ?? runtimeStatus?.localPath ?? '',
      modelInstalled: Boolean(modelStatus?.installed),
    };
    setRuntimeStatus(loadingStatus);
    onModelStateChange?.({
      modelStatus,
      modelStatuses,
      runtimeStatus:
        activeModelId === visibleSelectedModelId ? loadingStatus : null,
    });

    try {
      const nextStatus = await AIEngine.loadModel(activeModelId);
      setRuntimeStatus(nextStatus);
      onModelStateChange?.({
        modelStatus,
        modelStatuses,
        runtimeStatus:
          activeModelId === visibleSelectedModelId ? nextStatus : null,
      });
    } catch (error) {
      const errorStatus: RuntimeStatus = {
        ...loadingStatus,
        error:
          error instanceof Error
            ? error.message
            : '모델 런타임을 켜지 못했습니다.',
        loading: false,
      };
      setRuntimeStatus(errorStatus);
      onModelStateChange?.({
        modelStatus,
        modelStatuses,
        runtimeStatus:
          activeModelId === visibleSelectedModelId ? errorStatus : null,
      });
    }
  }, [
    activeModelId,
    modelStatus,
    modelStatuses,
    onModelStateChange,
    runtimeStatus?.localPath,
    visibleSelectedModelId,
  ]);

  const handleUnloadModel = useCallback(async () => {
    const nextStatus = await AIEngine.unloadModel();
    setRuntimeStatus(nextStatus);
    onModelStateChange?.({
      modelStatus,
      modelStatuses,
      runtimeStatus:
        activeModelId === visibleSelectedModelId ? nextStatus : null,
    });
  }, [
    activeModelId,
    modelStatus,
    modelStatuses,
    onModelStateChange,
    visibleSelectedModelId,
  ]);

  const runIndexingAction = useCallback(
    async (action: () => Promise<IndexingResult>) => {
      try {
        const result = await action();
        setStatus(result.status);
      } catch (error) {
        setStatus(previousStatus => ({
          ...previousStatus,
          isIndexing: false,
          lastError: getErrorMessage(error),
        }));
      }
    },
    [],
  );

  const handleStartIndexing = useCallback(async () => {
    await runIndexingAction(() => AIEngine.startIndexing());
  }, [runIndexingAction]);

  const handleSmsToggle = useCallback(
    async (enabled: boolean) => {
      await runIndexingAction(() =>
        AIEngine.setIndexingSourceEnabled('sms', enabled),
      );
    },
    [runIndexingAction],
  );

  const handleGalleryToggle = useCallback(
    async (enabled: boolean) => {
      await runIndexingAction(() =>
        AIEngine.setIndexingSourceEnabled('gallery', enabled),
      );
    },
    [runIndexingAction],
  );

  const handleDocumentToggle = useCallback(
    async (enabled: boolean) => {
      await runIndexingAction(() =>
        AIEngine.setIndexingSourceEnabled('document', enabled),
      );
    },
    [runIndexingAction],
  );

  const handleAddDocumentFolder = useCallback(async () => {
    await runIndexingAction(() => AIEngine.addDocumentFolder());
  }, [runIndexingAction]);

  const handleDeleteSms = useCallback(async () => {
    await runIndexingAction(() => AIEngine.deleteIndexingSource('sms'));
  }, [runIndexingAction]);

  const handleDeleteGallery = useCallback(async () => {
    await runIndexingAction(() => AIEngine.deleteIndexingSource('gallery'));
  }, [runIndexingAction]);

  const handleDeleteDocuments = useCallback(async () => {
    await runIndexingAction(() => AIEngine.deleteIndexingSource('document'));
  }, [runIndexingAction]);

  const updatePersonalCustomization = useCallback(
    (patch: Partial<PersonalCustomizationSettings>) => {
      onPersonalCustomizationChange({
        ...personalCustomization,
        ...patch,
      });
    },
    [onPersonalCustomizationChange, personalCustomization],
  );

  useEffect(() => {
    if (personalCustomization.personality.trim()) {
      return;
    }

    updatePersonalCustomization({ personality: defaultPersonalityPresetId });
  }, [personalCustomization.personality, updatePersonalCustomization]);

  const handleLanguageExpandedChange = useCallback((expanded: boolean) => {
    setIsLanguageSelectOpen(expanded);

    if (!expanded) {
      setLanguageQuery('');
    }
  }, []);
  const handleSelectLanguage = useCallback(
    (nextLocale: LocaleCode) => {
      setLocale(nextLocale);
      handleLanguageExpandedChange(false);
    },
    [handleLanguageExpandedChange, setLocale],
  );
  const openExternalUrl = useCallback((url: string) => {
    Linking.openURL(url).catch(() => undefined);
  }, []);
  const handleReportIssue = useCallback(() => {
    const body = [
      '## 문제 설명',
      '',
      '## 재현 방법',
      '1. ',
      '',
      '## 기대 동작',
      '',
      '## 환경',
      `- App version: ${appInfo.version}`,
      `- Platform: ${Platform.OS}`,
    ].join('\n');
    const issueUrl = `${repositoryUrl}/issues/new?title=${encodeURIComponent(
      '[Bug]: ',
    )}&body=${encodeURIComponent(body)}`;

    openExternalUrl(issueUrl);
  }, [openExternalUrl]);

  const selectedModelStatus =
    getSettingsModelStatus(modelStatuses, visibleSelectedModelId) ??
    (activeModelId === visibleSelectedModelId ? modelStatus : null);
  const isSelectedSystemManagedModel = isSettingsSystemManagedModel(
    visibleSelectedModelId,
    selectedModelStatus,
  );
  const isActiveSystemManagedModel = isSettingsSystemManagedModel(
    activeModelId,
    modelStatus,
  );
  const modelSummary = isSelectedSystemManagedModel
    ? t('settings.systemManagedModel')
    : selectedModelStatus?.installed
    ? activeModelId === visibleSelectedModelId && runtimeStatus?.loaded
      ? t('settings.loaded')
      : t('settings.installed')
    : selectedModelStatus?.isDownloading
    ? t('settings.downloading')
    : t('settings.installNeeded');
  const renderDetailHeader = (title: string, description: string) => (
    <View style={styles.header}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>
    </View>
  );

  const renderRoot = () => (
    <>
      <View style={styles.profileHeader}>
        <Image
          accessibilityLabel="Kepler"
          resizeMode="contain"
          source={brandAssets.logo}
          style={styles.profileLogo}
        />
      </View>

      <SettingsSection title={t('settings.aiSection')}>
        <SettingsNavigationRow
          icon={appIcons.modelManage}
          isLast
          onPress={() => onPanelChange('model')}
          title={t('settings.model')}
          value={modelSummary}
        />
      </SettingsSection>

      <SettingsSection title={t('settings.customizationSection')}>
        <SettingsNavigationRow
          icon={appIcons.memory}
          onPress={() => onPanelChange('personalCustomization')}
          title={t('settings.personalCustomization')}
        />
        <SettingsNavigationRow
          icon={appIcons.personalSettings}
          onPress={() => onPanelChange('appearance')}
          title={t('settings.appearance')}
        />
        <SettingsNavigationRow
          icon={appIcons.appsGrid}
          isLast
          onPress={() => onPanelChange('embedding')}
          title={t('settings.embeddingSettings')}
        />
      </SettingsSection>

      <SettingsSection title={t('settings.supportSection')}>
        <SettingsNavigationRow
          caption={t('settings.reportIssueCaption')}
          icon={appIcons.reportIssue}
          onPress={handleReportIssue}
          title={t('settings.reportIssue')}
        />
        <SettingsNavigationRow
          caption={t('settings.aboutCaption')}
          icon={appIcons.info}
          isLast
          onPress={() => onPanelChange('about')}
          title={t('settings.about')}
        />
      </SettingsSection>
    </>
  );

  const renderPersonalCustomization = () => (
    <>
      {renderDetailHeader(
        t('settings.personalCustomization'),
        t('settings.personalCustomizationDescription'),
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>
              {t('settings.personalCustomization')}
            </Text>
            <Text style={styles.sectionCaption}>
              {t('settings.personalCustomizationCaption')}
            </Text>
          </View>
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>{t('settings.name')}</Text>
          <TextInput
            accessibilityLabel={t('settings.name')}
            onChangeText={userName => updatePersonalCustomization({ userName })}
            placeholder={t('settings.namePlaceholder')}
            placeholderTextColor={colors.mutedForeground}
            style={styles.settingsTextInput}
            value={personalCustomization.userName}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>{t('settings.personality')}</Text>
          <Text style={styles.fieldCaption}>
            {t('settings.personalityCaption')}
          </Text>
          <View style={styles.personalityList}>
            {personalityPresets.map((preset, index) => {
              const isSelected = selectedPersonalityPreset?.id === preset.id;
              const isLast = index === personalityPresets.length - 1;

              return (
                <Pressable
                  accessibilityRole="button"
                  accessibilityState={{ selected: isSelected }}
                  key={preset.id}
                  onPress={() =>
                    updatePersonalCustomization({ personality: preset.id })
                  }
                  style={({ pressed }) => [
                    styles.personalityRow,
                    isSelected && styles.personalityRowSelected,
                    isLast && styles.personalityRowLast,
                    pressed && styles.rowPressed,
                  ]}
                >
                  <View style={styles.personalityCopy}>
                    <Text
                      style={[
                        styles.personalityLabel,
                        isSelected && styles.personalityLabelSelected,
                      ]}
                    >
                      {t(personalityLabelKeys[preset.id])}
                    </Text>
                    <Text style={styles.personalityDescription}>
                      {t(personalityDescriptionKeys[preset.id])}
                    </Text>
                  </View>
                  {isSelected ? (
                    <AppIcon
                      color={colors.primary}
                      icon={appIcons.selected}
                      size={16}
                    />
                  ) : null}
                </Pressable>
              );
            })}
          </View>
        </View>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>
              {t('settings.memoryEnabled')}
            </Text>
            <Text style={styles.sectionCaption}>
              {t('settings.memoryEnabledDescription')}
            </Text>
          </View>
          <Badge
            variant={
              personalCustomization.memoryEnabled ? 'success' : 'outline'
            }
          >
            {personalCustomization.memoryEnabled
              ? t('settings.memoryOn')
              : t('settings.memoryOff')}
          </Badge>
        </View>
        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>{t('settings.memoryEnabled')}</Text>
          </View>
          <SettingsToggle
            onValueChange={memoryEnabled =>
              updatePersonalCustomization({ memoryEnabled })
            }
            value={personalCustomization.memoryEnabled}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>{t('settings.savedMemoryList')}</Text>
          <View style={styles.memoryList}>
            {personalCustomization.savedMemories.length > 0 ? (
              personalCustomization.savedMemories.map((memory, index) => (
                <View key={`${memory}-${index}`} style={styles.memoryListItem}>
                  <Text style={styles.memoryListText}>{memory}</Text>
                </View>
              ))
            ) : (
              <Text style={styles.emptyMemoryText}>
                {t('settings.savedMemoryEmpty')}
              </Text>
            )}
          </View>
        </View>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>
              {t('settings.customInstructions')}
            </Text>
          </View>
        </View>

        <View style={styles.fieldGroup}>
          <TextInput
            accessibilityLabel={t('settings.customInstructions')}
            multiline
            onChangeText={customInstructions =>
              updatePersonalCustomization({ customInstructions })
            }
            placeholder={t('settings.customInstructionsPlaceholder')}
            placeholderTextColor={colors.mutedForeground}
            style={[styles.settingsTextInput, styles.longTextArea]}
            textAlignVertical="top"
            value={personalCustomization.customInstructions}
          />
        </View>
      </View>
    </>
  );

  const renderAppearance = () => (
    <>
      {renderDetailHeader(
        t('settings.appearance'),
        t('settings.appearanceDescription'),
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>{t('settings.language')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.languageCaption')}
            </Text>
          </View>
        </View>

        <View style={styles.sectionContent}>
          <SearchableLanguageSelect
            expanded={isLanguageSelectOpen}
            locale={locale}
            noResultsLabel={t('settings.languageNoResults')}
            onExpandedChange={handleLanguageExpandedChange}
            onQueryChange={setLanguageQuery}
            onSelect={handleSelectLanguage}
            options={visibleLocales}
            query={languageQuery}
            searchPlaceholder={t('settings.languageSearchPlaceholder')}
            selectedLocale={selectedLocale}
          />
        </View>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>{t('settings.textSize')}</Text>
            <Text style={styles.sectionCaption}>
              {selectedTextSizeDescription}
            </Text>
          </View>
          <Badge variant="outline">{selectedTextSizeLabel}</Badge>
        </View>

        <View style={styles.textSizeList}>
          {textSizes.map((option, index) => {
            const isSelected = option.id === textSize;
            const isLast = index === textSizes.length - 1;

            return (
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ selected: isSelected }}
                key={option.id}
                onPress={() => setTextSize(option.id)}
                style={({ pressed }) => [
                  styles.textSizeRow,
                  isSelected && styles.textSizeRowSelected,
                  isLast && styles.textSizeRowLast,
                  pressed && styles.rowPressed,
                ]}
              >
                <View style={styles.textSizeCopy}>
                  <Text
                    style={[
                      styles.textSizeLabel,
                      isSelected && styles.textSizeLabelSelected,
                    ]}
                  >
                    {t(
                      textSizeLabelKeys[option.id] ??
                        'settings.textSize.default.label',
                    )}
                  </Text>
                  <Text style={styles.textSizeDescription}>
                    {t(
                      textSizeDescriptionKeys[option.id] ??
                        'settings.textSize.default.description',
                    )}
                  </Text>
                </View>
                {isSelected ? (
                  <AppIcon
                    color={colors.primary}
                    icon={appIcons.selected}
                    size={16}
                  />
                ) : null}
              </Pressable>
            );
          })}
        </View>
      </View>
    </>
  );

  const getModelStateLabel = (
    modelId: ModelId | string,
    statusForModel: ModelStatus | null,
  ) => {
    const isFocused = modelId === activeModelId;

    if (isSettingsSystemManagedModel(modelId, statusForModel)) {
      if (statusForModel?.error && !statusForModel.runnable) {
        return statusForModel.error;
      }

      return t('settings.systemManagedModel');
    }

    if (isFocused && runtimeStatus?.loaded) {
      return t('settings.loaded');
    }

    if (statusForModel?.isDownloading) {
      return t('settings.downloading');
    }

    if (statusForModel?.installed) {
      return t('settings.installed');
    }

    return t('settings.installNeeded');
  };

  const renderModel = () => (
    <>
      {renderDetailHeader(t('settings.model'), t('settings.modelDescription'))}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>{t('settings.model')}</Text>
            <Text style={styles.sectionCaption}>
              {modelStatus?.modelName ?? 'Gemma 4'}
            </Text>
          </View>
          <Badge variant={status.isAvailable ? 'success' : 'secondary'}>
            {status.isAvailable
              ? t('settings.connected')
              : t('settings.waiting')}
          </Badge>
        </View>

        <View style={styles.modelOptionList}>
          {visibleSettingsModelOptions.map((option, index) => {
            const optionStatus = getSettingsModelStatus(
              modelStatuses,
              option.id,
            );
            const isFocused = option.id === activeModelId;
            const isCurrent = option.id === visibleSelectedModelId;
            const isLast = index === visibleSettingsModelOptions.length - 1;

            return (
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ selected: isFocused }}
                key={option.id}
                onPress={() => setModelPanelModelId(option.id)}
                style={({ pressed }) => [
                  styles.modelOptionRow,
                  isFocused && styles.modelOptionRowSelected,
                  isLast && styles.modelOptionRowLast,
                  pressed && styles.rowPressed,
                ]}
              >
                <View style={styles.modelOptionCopy}>
                  <Text
                    style={[
                      styles.modelOptionTitle,
                      isFocused && styles.modelOptionTitleSelected,
                    ]}
                  >
                    {optionStatus?.modelName ?? option.title}
                  </Text>
                  <Text style={styles.modelOptionDescription}>
                    {option.description}
                  </Text>
                  <Text style={styles.modelOptionStatus}>
                    {getModelStateLabel(option.id, optionStatus)}
                  </Text>
                </View>
                {isCurrent ? (
                  <AppIcon
                    color={colors.primary}
                    icon={appIcons.selected}
                    size={16}
                  />
                ) : null}
              </Pressable>
            );
          })}
        </View>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>
              {t('settings.engineStatus')}
            </Text>
            <Text style={styles.sectionCaption}>
              {getModelStateLabel(activeModelId, modelStatus)}
            </Text>
          </View>
        </View>

        <Separator style={styles.separator} />

        <StatusRow
          label={t('settings.nativeBridge')}
          value={
            status.isAvailable ? t('settings.connected') : t('settings.waiting')
          }
        />
        <StatusRow
          label={t('settings.defaultModel')}
          value={modelStatus?.modelName ?? 'gemma-4-E2B-it'}
        />
        <StatusRow
          label={t('settings.modelFile')}
          value={
            isActiveSystemManagedModel
              ? t('settings.systemManagedModel')
              : modelStatus?.installed
              ? t('settings.installed')
              : modelStatus?.isDownloading
              ? t('settings.downloading')
              : t('settings.required')
          }
        />
        <StatusRow
          label={t('settings.download')}
          value={
            isActiveSystemManagedModel
              ? t('settings.systemManagedModel')
              : `${formatBytes(
                  modelStatus?.bytesDownloaded ?? 0,
                )} / ${formatBytes(modelStatus?.totalBytes ?? 2588147712)}`
          }
        />
        {isActiveSystemManagedModel ? null : (
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                { width: `${downloadProgress * 100}%` },
              ]}
            />
          </View>
        )}
        {modelStatus?.error ? (
          <Text style={styles.errorText}>{modelStatus.error}</Text>
        ) : null}
        <View style={styles.actionRow}>
          <Button
            disabled={
              isActiveSystemManagedModel ||
              modelStatus?.installed ||
              modelStatus?.isDownloading
            }
            label={
              isActiveSystemManagedModel
                ? t('settings.systemManagedModel')
                : t('settings.downloadModel')
            }
            onPress={handleDownloadModel}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            disabled={!modelStatus?.isDownloading}
            label={t('settings.cancel')}
            onPress={handleCancelModelDownload}
            style={styles.modelButton}
            variant="ghost"
          />
        </View>
        <StatusRow
          label={t('settings.runtime')}
          value={
            runtimeStatus?.loaded
              ? t('settings.loaded')
              : runtimeStatus?.loading
              ? t('settings.loading')
              : t('settings.off')
          }
        />
        <View style={styles.actionRow}>
          <Button
            disabled={
              isActiveSystemManagedModel ||
              !modelStatus?.installed ||
              runtimeStatus?.loaded
            }
            label={t('settings.loadModel')}
            onPress={handleLoadModel}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            disabled={!runtimeStatus?.loaded}
            label={t('settings.unloadModel')}
            onPress={handleUnloadModel}
            style={styles.modelButton}
            variant="ghost"
          />
        </View>
      </View>
    </>
  );

  const renderEmbedding = () => (
    <>
      {renderDetailHeader(
        t('settings.embeddingSettings'),
        t('settings.embeddingDescription'),
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>
              {t('settings.embeddingSettings')}
            </Text>
            <Text style={styles.sectionCaption}>
              {t('settings.embeddingCaption')}
            </Text>
          </View>
        </View>

        <Separator style={styles.separator} />

        <StatusRow
          label={t('settings.embeddingItems')}
          value={t('settings.itemCount', {
            count: status.indexedItems.toLocaleString(locale),
          })}
        />
        <StatusRow
          label={t('settings.smsEmbedding')}
          value={t('settings.itemCount', {
            count: status.smsIndexedItems.toLocaleString(locale),
          })}
        />
        <StatusRow
          label={t('settings.galleryEmbedding')}
          value={t('settings.itemCount', {
            count: status.galleryIndexedItems.toLocaleString(locale),
          })}
        />
        <StatusRow
          label={t('settings.documentEmbedding')}
          value={t('settings.itemCount', {
            count: status.documentIndexedItems.toLocaleString(locale),
          })}
        />
        <StatusRow
          label={t('settings.lastEmbedding')}
          value={status.lastIndexedAt ?? t('settings.noRecord')}
        />
        {status.lastError ? (
          <Text style={styles.errorText}>{status.lastError}</Text>
        ) : null}

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>{t('settings.sms')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.smsEmbeddingCaption')}
            </Text>
          </View>
          <SettingsToggle
            disabled={status.isIndexing}
            onValueChange={handleSmsToggle}
            value={status.smsEnabled}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>{t('settings.gallery')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.galleryEmbeddingCaption')}
            </Text>
          </View>
          <SettingsToggle
            disabled={status.isIndexing}
            onValueChange={handleGalleryToggle}
            value={status.galleryEnabled}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>{t('settings.documents')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.documentEmbeddingCaption')}
            </Text>
          </View>
          <SettingsToggle
            disabled={status.isIndexing}
            onValueChange={handleDocumentToggle}
            value={status.documentEnabled}
          />
        </View>

        <Text style={styles.description}>{t('settings.embeddingHelp')}</Text>

        <Button
          disabled={status.isIndexing}
          label={t('settings.addDocumentFolder')}
          textStyle={styles.refreshButtonText}
          onPress={handleAddDocumentFolder}
          style={styles.refreshButton}
          variant="ghost"
        />

        <Button
          disabled={status.isIndexing}
          label={t('settings.startEmbedding')}
          textStyle={styles.refreshButtonText}
          onPress={handleStartIndexing}
          style={styles.refreshButton}
          variant="ghost"
        />

        <View style={styles.actionRow}>
          <Button
            label={t('settings.deleteSmsEmbedding')}
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteSms}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            label={t('settings.deleteGalleryEmbedding')}
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteGallery}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            label={t('settings.deleteDocumentEmbedding')}
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteDocuments}
            style={styles.modelButton}
            variant="ghost"
          />
        </View>

        <Button
          label={t('settings.refreshStatus')}
          textStyle={styles.refreshButtonText}
          onPress={refreshStatus}
          style={styles.refreshButton}
          variant="ghost"
        />
      </View>
    </>
  );

  const renderAbout = () => (
    <>
      {renderDetailHeader(t('settings.about'), t('settings.aboutDescription'))}

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>
              {t('settings.appInformation')}
            </Text>
            <Text style={styles.sectionCaption}>{appInfo.displayName}</Text>
          </View>
        </View>

        <Separator style={styles.separator} />

        <StatusRow label={t('settings.appName')} value={appInfo.displayName} />
        <StatusRow label={t('settings.appVersion')} value={appInfo.version} />
        <StatusRow
          label={t('settings.bundleIdentifier')}
          value={appInfo.bundleIdentifier}
        />
        <InfoLinkRow
          label={t('settings.repository')}
          onPress={() => openExternalUrl(appInfo.repositoryUrl)}
          value={appInfo.repositoryName}
        />
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>{t('settings.openSource')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.openSourceDescription')}
            </Text>
          </View>
        </View>

        <View style={styles.infoList}>
          {openSourcePackages.map(item => (
            <InfoLinkRow
              key={item.name}
              label={item.name}
              onPress={() => openExternalUrl(item.url)}
              value={item.version}
            />
          ))}
        </View>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>{t('settings.contribute')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.contributeDescription')}
            </Text>
          </View>
        </View>

        <View style={styles.infoList}>
          {contributionLinks.map(link => (
            <InfoLinkRow
              key={link.url}
              label={link.label}
              onPress={() => openExternalUrl(link.url)}
              value={t('settings.open')}
            />
          ))}
        </View>
      </View>
    </>
  );

  const renderActivePanel = () => {
    switch (activePanel) {
      case 'personalCustomization':
        return renderPersonalCustomization();
      case 'appearance':
        return renderAppearance();
      case 'model':
        return renderModel();
      case 'embedding':
        return renderEmbedding();
      case 'about':
        return renderAbout();
      case 'root':
      default:
        return renderRoot();
    }
  };

  return (
    <ScrollView
      key={activePanel}
      contentContainerStyle={[
        styles.container,
        { paddingBottom: SETTINGS_CONTENT_BOTTOM_PADDING + insets.bottom },
      ]}
      style={styles.scroll}
      showsVerticalScrollIndicator={false}
    >
      {renderActivePanel()}
    </ScrollView>
  );
}

export default Settings;
