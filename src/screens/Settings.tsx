import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import React, {
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Image,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  useWindowDimensions,
  View,
} from 'react-native';

import AppIcon from '../components/AppIcon';
import { Badge, Button, Separator } from '../components/ui';
import { brandAssets } from '../config/branding';
import {
  I18nKey,
  LocaleCode,
  SupportedLocale,
  useI18n,
} from '../i18n';
import AIEngine, {
  IndexingStatus,
  ModelStatus,
  RuntimeStatus,
} from '../native/AIEngine';
import {
  ScaledText as Text,
  ScaledTextInput as TextInput,
  useDisplaySettings,
} from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors, typography } from '../theme/tokens';

const defaultStatus: IndexingStatus = {
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

const textSizeLabelKeys: Record<string, I18nKey> = {
  compact: 'settings.textSize.compact.label',
  default: 'settings.textSize.default.label',
  large: 'settings.textSize.large.label',
};

const textSizeDescriptionKeys: Record<string, I18nKey> = {
  compact: 'settings.textSize.compact.description',
  default: 'settings.textSize.default.description',
  large: 'settings.textSize.large.description',
};
const languageMenuGap = 8;
const languageMenuMargin = 18;
const languageMenuMaxHeight = 420;
const languageMenuMinHeight = 220;
const languageMenuBottomGap = 10;
const languageSearchInputHeight = 47;

const formatBytes = (bytes: number) => {
  if (bytes <= 0) {
    return '0 MB';
  }

  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
};

type SettingsProps = {
  activePanel: SettingsPanelId;
  onModelStateChange?: (state: {
    modelStatus: ModelStatus | null;
    runtimeStatus: RuntimeStatus | null;
  }) => void;
  onPanelChange: (panel: SettingsPanelId) => void;
  onPersonalCustomizationChange: (
    settings: PersonalCustomizationSettings,
  ) => void;
  personalCustomization: PersonalCustomizationSettings;
};

export type SettingsPanelId =
  | 'root'
  | 'personalCustomization'
  | 'appearance'
  | 'model'
  | 'embedding';

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
}: SettingsProps) {
  const {
    locale,
    selectedLocale,
    setLocale,
    supportedLocales,
    t,
  } = useI18n();
  const [status, setStatus] = useState<IndexingStatus>(defaultStatus);
  const [modelStatus, setModelStatus] = useState<ModelStatus | null>(null);
  const [runtimeStatus, setRuntimeStatus] = useState<RuntimeStatus | null>(
    null,
  );
  const [isLanguageSelectOpen, setIsLanguageSelectOpen] = useState(false);
  const [languageQuery, setLanguageQuery] = useState('');
  const { selectedTextSize, setTextSize, textSize, textSizes } =
    useDisplaySettings();

  const selectedTextSizeLabel =
    t(textSizeLabelKeys[selectedTextSize.id] ?? 'settings.textSize.default.label');
  const selectedTextSizeDescription = t(
    textSizeDescriptionKeys[selectedTextSize.id] ??
      'settings.textSize.default.description',
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

  const refreshStatus = useCallback(async () => {
    const [nextStatus, nextModelStatus, nextRuntimeStatus] = await Promise.all([
      AIEngine.getIndexingStatus(),
      AIEngine.getModelStatus(),
      AIEngine.getRuntimeStatus(),
    ]);
    setStatus(nextStatus);
    setModelStatus(nextModelStatus);
    setRuntimeStatus(nextRuntimeStatus);
    onModelStateChange?.({
      modelStatus: nextModelStatus,
      runtimeStatus: nextRuntimeStatus,
    });
  }, [onModelStateChange]);

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
    const nextStatus = await AIEngine.ensureModelDownloaded();
    setModelStatus(nextStatus);
    onModelStateChange?.({
      modelStatus: nextStatus,
      runtimeStatus,
    });
  }, [onModelStateChange, runtimeStatus]);

  const handleCancelModelDownload = useCallback(async () => {
    const nextStatus = await AIEngine.cancelModelDownload();
    setModelStatus(nextStatus);
    onModelStateChange?.({
      modelStatus: nextStatus,
      runtimeStatus,
    });
  }, [onModelStateChange, runtimeStatus]);

  const handleLoadModel = useCallback(async () => {
    const nextStatus = await AIEngine.loadModel();
    setRuntimeStatus(nextStatus);
    onModelStateChange?.({
      modelStatus,
      runtimeStatus: nextStatus,
    });
  }, [modelStatus, onModelStateChange]);

  const handleUnloadModel = useCallback(async () => {
    const nextStatus = await AIEngine.unloadModel();
    setRuntimeStatus(nextStatus);
    onModelStateChange?.({
      modelStatus,
      runtimeStatus: nextStatus,
    });
  }, [modelStatus, onModelStateChange]);

  const handleStartIndexing = useCallback(async () => {
    const result = await AIEngine.startIndexing();
    setStatus(result.status);
  }, []);

  const handleSmsToggle = useCallback(async (enabled: boolean) => {
    const result = await AIEngine.setIndexingSourceEnabled('sms', enabled);
    setStatus(result.status);
  }, []);

  const handleGalleryToggle = useCallback(async (enabled: boolean) => {
    const result = await AIEngine.setIndexingSourceEnabled('gallery', enabled);
    setStatus(result.status);
  }, []);

  const handleDocumentToggle = useCallback(async (enabled: boolean) => {
    const result = await AIEngine.setIndexingSourceEnabled('document', enabled);
    setStatus(result.status);
  }, []);

  const handleDeleteSms = useCallback(async () => {
    const result = await AIEngine.deleteIndexingSource('sms');
    setStatus(result.status);
  }, []);

  const handleDeleteGallery = useCallback(async () => {
    const result = await AIEngine.deleteIndexingSource('gallery');
    setStatus(result.status);
  }, []);

  const handleDeleteDocuments = useCallback(async () => {
    const result = await AIEngine.deleteIndexingSource('document');
    setStatus(result.status);
  }, []);

  const updatePersonalCustomization = useCallback(
    (patch: Partial<PersonalCustomizationSettings>) => {
      onPersonalCustomizationChange({
        ...personalCustomization,
        ...patch,
      });
    },
    [onPersonalCustomizationChange, personalCustomization],
  );
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

  const modelSummary = modelStatus?.installed
    ? runtimeStatus?.loaded
      ? t('settings.loaded')
      : t('settings.installed')
    : modelStatus?.isDownloading
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
          accessibilityLabel="Open Edge AI"
          resizeMode="contain"
          source={brandAssets.logo}
          style={styles.profileLogo}
        />
      </View>

      <SettingsSection title={t('settings.customizationSection')}>
        <SettingsNavigationRow
          icon={appIcons.personalSettings}
          onPress={() => onPanelChange('appearance')}
          title={t('settings.appearance')}
        />
        <SettingsNavigationRow
          icon={appIcons.memory}
          onPress={() => onPanelChange('personalCustomization')}
          title={t('settings.personalCustomization')}
        />
        <SettingsNavigationRow
          icon={appIcons.appsGrid}
          isLast
          onPress={() => onPanelChange('embedding')}
          title={t('settings.embeddingSettings')}
        />
      </SettingsSection>

      <SettingsSection title={t('settings.aiSection')}>
        <SettingsNavigationRow
          icon={appIcons.modelBalanced}
          isLast
          onPress={() => onPanelChange('model')}
          title={t('settings.model')}
          value={modelSummary}
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
          <Badge
            variant={personalCustomization.memoryEnabled ? 'success' : 'outline'}
          >
            {personalCustomization.memoryEnabled
              ? t('settings.memoryOn')
              : t('settings.memoryOff')}
          </Badge>
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
          <TextInput
            accessibilityLabel={t('settings.personality')}
            multiline
            onChangeText={personality =>
              updatePersonalCustomization({ personality })
            }
            placeholder={t('settings.personalityPlaceholder')}
            placeholderTextColor={colors.mutedForeground}
            style={[styles.settingsTextInput, styles.shortTextArea]}
            textAlignVertical="top"
            value={personalCustomization.personality}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>
            {t('settings.customInstructions')}
          </Text>
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

        <Separator style={styles.separator} />

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>{t('settings.memoryEnabled')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.memoryEnabledDescription')}
            </Text>
          </View>
          <SettingsToggle
            onValueChange={memoryEnabled =>
              updatePersonalCustomization({ memoryEnabled })
            }
            value={personalCustomization.memoryEnabled}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>
            {t('settings.savedMemoryList')}
          </Text>
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
          {textSizes.map(option => {
            const isSelected = option.id === textSize;

            return (
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ selected: isSelected }}
                key={option.id}
                onPress={() => setTextSize(option.id)}
                style={({ pressed }) => [
                  styles.textSizeRow,
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

  const renderModel = () => (
    <>
      {renderDetailHeader(
        t('settings.model'),
        t('settings.modelDescription'),
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>{t('settings.model')}</Text>
            <Text style={styles.sectionCaption}>
              {t('settings.engineStatus')}
            </Text>
          </View>
          <Badge variant={status.isAvailable ? 'success' : 'secondary'}>
            {status.isAvailable
              ? t('settings.connected')
              : t('settings.waiting')}
          </Badge>
        </View>

        <Separator style={styles.separator} />

        <StatusRow
          label={t('settings.nativeBridge')}
          value={
            status.isAvailable
              ? t('settings.connected')
              : t('settings.waiting')
          }
        />
        <StatusRow
          label={t('settings.defaultModel')}
          value={modelStatus?.modelName ?? 'gemma-4-E2B-it'}
        />
        <StatusRow
          label={t('settings.modelFile')}
          value={
            modelStatus?.installed
              ? t('settings.installed')
              : modelStatus?.isDownloading
              ? t('settings.downloading')
              : t('settings.required')
          }
        />
        <StatusRow
          label={t('settings.download')}
          value={`${formatBytes(
            modelStatus?.bytesDownloaded ?? 0,
          )} / ${formatBytes(modelStatus?.totalBytes ?? 2588147712)}`}
        />
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${downloadProgress * 100}%` },
            ]}
          />
        </View>
        {modelStatus?.error ? (
          <Text style={styles.errorText}>{modelStatus.error}</Text>
        ) : null}
        <View style={styles.actionRow}>
          <Button
            disabled={modelStatus?.installed || modelStatus?.isDownloading}
            label={t('settings.downloadModel')}
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
            disabled={!modelStatus?.installed || runtimeStatus?.loaded}
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

        <Text style={styles.description}>
          {t('settings.embeddingHelp')}
        </Text>

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
      case 'root':
      default:
        return renderRoot();
    }
  };

  return (
    <ScrollView
      key={activePanel}
      contentContainerStyle={styles.container}
      style={styles.scroll}
      showsVerticalScrollIndicator={false}
    >
      {renderActivePanel()}
    </ScrollView>
  );
}

type SettingsNavigationRowProps = {
  caption?: string;
  icon: IconDefinition;
  iconColor?: string;
  isLast?: boolean;
  onPress: () => void;
  title: string;
  value?: string;
};

function SettingsNavigationRow({
  caption,
  icon,
  iconColor = colors.foreground,
  isLast = false,
  onPress,
  title,
  value,
}: SettingsNavigationRowProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.navigationRow,
        !isLast && styles.navigationRowDivider,
        pressed && styles.rowPressed,
      ]}
    >
      <View style={styles.navigationIconSlot}>
        <AppIcon color={iconColor} icon={icon} size={18} />
      </View>
      <View style={styles.navigationCopy}>
        <Text style={styles.navigationTitle}>{title}</Text>
        {caption ? (
          <Text style={styles.navigationCaption}>{caption}</Text>
        ) : null}
      </View>
      <View style={styles.navigationMeta}>
        {value ? (
          <Text numberOfLines={1} style={styles.navigationValue}>
            {value}
          </Text>
        ) : null}
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.openPrompt}
          size={14}
        />
      </View>
    </Pressable>
  );
}

type SearchableLanguageSelectProps = {
  expanded: boolean;
  locale: LocaleCode;
  noResultsLabel: string;
  onExpandedChange: (expanded: boolean) => void;
  onQueryChange: (query: string) => void;
  onSelect: (locale: LocaleCode) => void;
  options: readonly SupportedLocale[];
  query: string;
  searchPlaceholder: string;
  selectedLocale: SupportedLocale;
};

function SearchableLanguageSelect({
  expanded,
  locale,
  noResultsLabel,
  onExpandedChange,
  onQueryChange,
  onSelect,
  options,
  query,
  searchPlaceholder,
  selectedLocale,
}: SearchableLanguageSelectProps) {
  const triggerRef = useRef<View>(null);
  const windowSize = useWindowDimensions();
  const [triggerFrame, setTriggerFrame] = useState<{
    height: number;
    width: number;
    x: number;
    y: number;
  } | null>(null);
  const measureTrigger = useCallback(() => {
    triggerRef.current?.measureInWindow((x, y, width, height) => {
      setTriggerFrame({ height, width, x, y });
    });
  }, []);
  const handleToggle = useCallback(() => {
    if (expanded) {
      onExpandedChange(false);
      return;
    }

    measureTrigger();
    onExpandedChange(true);
  }, [expanded, measureTrigger, onExpandedChange]);

  useEffect(() => {
    if (!expanded) {
      return;
    }

    const frame = requestAnimationFrame(measureTrigger);
    return () => cancelAnimationFrame(frame);
  }, [expanded, measureTrigger, windowSize.height, windowSize.width]);

  const menuLayout = useMemo(() => {
    if (!triggerFrame) {
      return null;
    }

    const menuWidth = Math.min(
      triggerFrame.width,
      windowSize.width - languageMenuMargin * 2,
    );
    const left = Math.min(
      Math.max(triggerFrame.x, languageMenuMargin),
      windowSize.width - menuWidth - languageMenuMargin,
    );
    const spaceBelow =
      windowSize.height -
      triggerFrame.y -
      triggerFrame.height -
      languageMenuBottomGap;
    const spaceAbove = triggerFrame.y - languageMenuMargin;
    const openUp = spaceBelow < languageMenuMinHeight && spaceAbove > spaceBelow;
    const availableSpace = Math.max(openUp ? spaceAbove : spaceBelow, 0);
    const height = Math.max(
      160,
      Math.min(languageMenuMaxHeight, availableSpace - languageMenuGap),
    );
    const top = openUp
      ? Math.max(
          languageMenuMargin,
          triggerFrame.y - height - languageMenuGap,
        )
      : Math.min(
          triggerFrame.y + triggerFrame.height + languageMenuGap,
          windowSize.height - height - languageMenuBottomGap,
        );

    return {
      height,
      left,
      optionListHeight: Math.max(110, height - languageSearchInputHeight),
      top,
      width: menuWidth,
    };
  }, [triggerFrame, windowSize.height, windowSize.width]);

  return (
    <View style={styles.languageSelect}>
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ expanded }}
        onPress={handleToggle}
        ref={triggerRef}
        style={({ pressed }) => [
          styles.languageSelectTrigger,
          expanded && styles.languageSelectTriggerActive,
          pressed && styles.rowPressed,
        ]}
      >
        <View style={styles.languageSelectValue}>
          <Text numberOfLines={1} style={styles.languageSelectNative}>
            {selectedLocale.nativeName}
          </Text>
          <Text numberOfLines={1} style={styles.languageSelectEnglish}>
            {selectedLocale.englishName}
          </Text>
        </View>
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.chevronDown}
          size={11}
        />
      </Pressable>

      <Modal
        animationType="none"
        onRequestClose={() => onExpandedChange(false)}
        transparent
        visible={expanded}
      >
        <View style={styles.languageOverlay}>
          <Pressable
            accessibilityLabel="Close language menu"
            accessibilityRole="button"
            onPress={() => onExpandedChange(false)}
            style={StyleSheet.absoluteFill}
          />
          {menuLayout ? (
            <View
              style={[
                styles.languageSelectMenu,
                {
                  height: menuLayout.height,
                  left: menuLayout.left,
                  top: menuLayout.top,
                  width: menuLayout.width,
                },
              ]}
            >
              <TextInput
                accessibilityLabel={searchPlaceholder}
                autoCapitalize="none"
                onChangeText={onQueryChange}
                placeholder={searchPlaceholder}
                placeholderTextColor={colors.mutedForeground}
                style={styles.languageSearchInput}
                value={query}
              />
              <ScrollView
                keyboardShouldPersistTaps="handled"
                nestedScrollEnabled
                style={[
                  styles.languageOptionList,
                  { height: menuLayout.optionListHeight },
                ]}
              >
                {options.length > 0 ? (
                  options.map(option => {
                    const isSelected = option.code === locale;

                    return (
                      <Pressable
                        accessibilityLabel={`${option.nativeName} ${option.englishName}`}
                        accessibilityRole="button"
                        accessibilityState={{ selected: isSelected }}
                        key={option.code}
                        onPress={() => onSelect(option.code)}
                        style={({ pressed }) => [
                          styles.languageOption,
                          isSelected && styles.languageOptionActive,
                          pressed && styles.rowPressed,
                        ]}
                      >
                        <View style={styles.languageOptionCopy}>
                          <Text
                            numberOfLines={1}
                            style={styles.languageOptionNative}
                          >
                            {option.nativeName}
                          </Text>
                          <Text
                            numberOfLines={1}
                            style={styles.languageOptionEnglish}
                          >
                            {option.englishName}
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
                  })
                ) : (
                  <Text style={styles.languageEmptyText}>{noResultsLabel}</Text>
                )}
              </ScrollView>
            </View>
          ) : null}
        </View>
      </Modal>
    </View>
  );
}

type SettingsSectionProps = {
  children: ReactNode;
  title: string;
};

function SettingsSection({ children, title }: SettingsSectionProps) {
  return (
    <View style={styles.settingsSection}>
      <Text style={styles.settingsSectionTitle}>{title}</Text>
      <View style={styles.settingsCard}>{children}</View>
    </View>
  );
}

type StatusRowProps = {
  label: string;
  value: string;
};

function StatusRow({ label, value }: StatusRowProps) {
  return (
    <View style={styles.statusRow}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

type SettingsToggleProps = {
  disabled?: boolean;
  onValueChange: (value: boolean) => void;
  value: boolean;
};

function SettingsToggle({
  disabled = false,
  onValueChange,
  value,
}: SettingsToggleProps) {
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityState={{ checked: value, disabled }}
      disabled={disabled}
      hitSlop={8}
      onPress={() => onValueChange(!value)}
      style={({ pressed }) => [
        styles.settingsToggle,
        value && styles.settingsToggleOn,
        disabled && styles.settingsToggleDisabled,
        pressed && styles.settingsTogglePressed,
      ]}
    >
      <View
        style={[
          styles.settingsToggleThumb,
          value && styles.settingsToggleThumbOn,
        ]}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: '#F4F5F8',
  },
  container: {
    paddingBottom: 38,
    paddingHorizontal: 18,
    paddingTop: 20,
  },
  profileHeader: {
    alignItems: 'center',
    marginBottom: 22,
    paddingTop: 2,
  },
  profileLogo: {
    height: 34,
    opacity: 0.54,
    width: 152,
  },
  header: {
    marginBottom: 24,
  },
  title: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 28,
    lineHeight: 34,
  },
  description: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 22,
    marginTop: 10,
  },
  settingsSection: {
    marginBottom: 24,
  },
  settingsSectionTitle: {
    ...typography.label,
    color: '#93969D',
    fontSize: 17,
    fontWeight: '600',
    marginBottom: 8,
    paddingHorizontal: 16,
  },
  settingsCard: {
    backgroundColor: colors.card,
    borderColor: 'rgba(21,25,34,0.04)',
    borderRadius: 18,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
  },
  navigationRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 54,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  navigationRowDivider: {
    borderBottomColor: '#E7E7EA',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  navigationIconSlot: {
    alignItems: 'center',
    height: 28,
    justifyContent: 'center',
    marginRight: 10,
    width: 28,
  },
  navigationCopy: {
    flex: 1,
    paddingRight: 12,
  },
  navigationTitle: {
    ...typography.body,
    color: colors.foreground,
    fontSize: 16,
    fontWeight: '600',
  },
  navigationCaption: {
    ...typography.caption,
    color: colors.mutedForeground,
    lineHeight: 16,
    marginTop: 5,
  },
  navigationMeta: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 9,
    maxWidth: '52%',
  },
  navigationValue: {
    ...typography.body,
    color: '#8D9097',
    flexShrink: 1,
    fontSize: 15,
    fontWeight: '500',
  },
  section: {
    backgroundColor: colors.card,
    borderColor: 'rgba(21,25,34,0.05)',
    borderRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
    marginBottom: 28,
    padding: 16,
  },
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 17,
  },
  sectionCaption: {
    ...typography.caption,
    color: colors.mutedForeground,
    marginTop: 5,
  },
  personalizationDescription: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 21,
    marginTop: 12,
  },
  sectionContent: {
    marginTop: 16,
  },
  textSizeList: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 18,
  },
  textSizeRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 62,
    paddingVertical: 10,
  },
  rowPressed: {
    opacity: 0.58,
  },
  textSizeCopy: {
    flex: 1,
    paddingRight: 16,
  },
  textSizeLabel: {
    ...typography.body,
    color: colors.foreground,
    fontWeight: '500',
  },
  textSizeLabelSelected: {
    color: colors.primary,
    fontWeight: '700',
  },
  textSizeDescription: {
    ...typography.caption,
    color: colors.mutedForeground,
    lineHeight: 16,
    marginTop: 4,
  },
  fieldGroup: {
    marginTop: 16,
  },
  fieldLabel: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 15,
    marginBottom: 8,
  },
  settingsTextInput: {
    ...typography.body,
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    color: colors.foreground,
    fontSize: 15,
    lineHeight: 21,
    minHeight: 46,
    paddingHorizontal: 14,
    paddingVertical: 11,
  },
  shortTextArea: {
    minHeight: 82,
    paddingTop: 12,
  },
  longTextArea: {
    minHeight: 132,
    paddingTop: 12,
  },
  memoryList: {
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
  },
  memoryListItem: {
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  memoryListText: {
    ...typography.body,
    color: colors.foreground,
    fontSize: 15,
    fontWeight: '400',
    lineHeight: 21,
  },
  emptyMemoryText: {
    ...typography.body,
    color: colors.mutedForeground,
    fontSize: 15,
    fontWeight: '400',
    lineHeight: 21,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  languageSelect: {
    alignSelf: 'stretch',
  },
  languageOverlay: {
    flex: 1,
  },
  languageSelectTrigger: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 52,
    paddingHorizontal: 14,
  },
  languageSelectTriggerActive: {
    backgroundColor: colors.card,
    borderColor: colors.primary,
  },
  languageSelectValue: {
    flex: 1,
    minWidth: 0,
    paddingRight: 12,
  },
  languageSelectNative: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 15,
    fontWeight: '700',
  },
  languageSelectEnglish: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '500',
    marginTop: 3,
  },
  languageSelectMenu: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: StyleSheet.hairlineWidth,
    elevation: 96,
    overflow: 'hidden',
    position: 'absolute',
    shadowColor: '#000000',
    shadowOffset: { height: 12, width: 0 },
    shadowOpacity: 0.12,
    shadowRadius: 22,
    zIndex: 96,
  },
  languageSearchInput: {
    ...typography.body,
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    color: colors.foreground,
    fontSize: 15,
    minHeight: 46,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  languageOptionList: {
    maxHeight: 280,
  },
  languageOption: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 48,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  languageOptionActive: {
    backgroundColor: 'rgba(0,122,255,0.08)',
  },
  languageOptionCopy: {
    flex: 1,
    minWidth: 0,
    paddingRight: 12,
  },
  languageOptionNative: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 15,
    fontWeight: '700',
  },
  languageOptionEnglish: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 12,
    fontWeight: '500',
    marginTop: 3,
  },
  languageEmptyText: {
    ...typography.body,
    color: colors.mutedForeground,
    fontSize: 15,
    lineHeight: 21,
    paddingHorizontal: 14,
    paddingVertical: 14,
  },
  separator: {
    marginVertical: 14,
  },
  progressTrack: {
    backgroundColor: colors.border,
    borderRadius: 4,
    height: 8,
    marginBottom: 8,
    marginTop: 4,
    overflow: 'hidden',
  },
  progressFill: {
    backgroundColor: colors.primary,
    borderRadius: 4,
    height: 8,
  },
  errorText: {
    ...typography.caption,
    color: '#B42318',
    lineHeight: 16,
    marginBottom: 8,
  },
  actionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginBottom: 8,
    marginTop: 4,
  },
  modelButton: {
    paddingHorizontal: 0,
  },
  statusRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 48,
  },
  rowLabel: {
    ...typography.body,
    color: colors.foreground,
    flex: 1,
    fontWeight: '400',
  },
  rowValue: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    textAlign: 'right',
  },
  switchCopy: {
    flex: 1,
    paddingRight: 16,
  },
  toggleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 54,
  },
  settingsToggle: {
    backgroundColor: colors.input,
    borderColor: colors.border,
    borderRadius: 15,
    borderWidth: StyleSheet.hairlineWidth,
    height: 30,
    justifyContent: 'center',
    paddingHorizontal: 3,
    width: 50,
  },
  settingsToggleOn: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  settingsTogglePressed: {
    opacity: 0.72,
  },
  settingsToggleDisabled: {
    opacity: 0.54,
  },
  settingsToggleThumb: {
    backgroundColor: colors.card,
    borderRadius: 12,
    height: 24,
    shadowColor: '#000000',
    shadowOffset: { height: 1, width: 0 },
    shadowOpacity: 0.16,
    shadowRadius: 2,
    transform: [{ translateX: 0 }],
    width: 24,
  },
  settingsToggleThumbOn: {
    transform: [{ translateX: 20 }],
  },
  refreshButton: {
    alignSelf: 'flex-start',
    marginTop: 16,
    paddingHorizontal: 0,
  },
  refreshButtonText: {
    fontSize: 16,
  },
});

export default Settings;
