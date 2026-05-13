import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import React, { ReactNode, useCallback, useEffect, useState } from 'react';
import { Image, Pressable, ScrollView, StyleSheet, View } from 'react-native';

import AppIcon from '../components/AppIcon';
import { Badge, Button, Separator } from '../components/ui';
import { brandAssets } from '../config/branding';
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
  const [status, setStatus] = useState<IndexingStatus>(defaultStatus);
  const [modelStatus, setModelStatus] = useState<ModelStatus | null>(null);
  const [runtimeStatus, setRuntimeStatus] = useState<RuntimeStatus | null>(
    null,
  );
  const { selectedTextSize, setTextSize, textSize, textSizes } =
    useDisplaySettings();

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

  const modelSummary = modelStatus?.installed
    ? runtimeStatus?.loaded
      ? '로드됨'
      : '설치됨'
    : modelStatus?.isDownloading
    ? '다운로드 중'
    : '설치 필요';
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

      <SettingsSection title="맞춤 설정">
        <SettingsNavigationRow
          icon={appIcons.personalSettings}
          onPress={() => onPanelChange('appearance')}
          title="모양"
        />
        <SettingsNavigationRow
          icon={appIcons.memory}
          onPress={() => onPanelChange('personalCustomization')}
          title="개인 맞춤 설정"
        />
        <SettingsNavigationRow
          icon={appIcons.appsGrid}
          isLast
          onPress={() => onPanelChange('embedding')}
          title="임베딩 설정"
        />
      </SettingsSection>

      <SettingsSection title="AI">
        <SettingsNavigationRow
          icon={appIcons.modelBalanced}
          isLast
          onPress={() => onPanelChange('model')}
          title="모델"
          value={modelSummary}
        />
      </SettingsSection>
    </>
  );

  const renderPersonalCustomization = () => (
    <>
      {renderDetailHeader(
        '개인 맞춤 설정',
        'AI가 사용자를 이해하고 응답 방식을 맞출 수 있도록 기본 정보를 관리합니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>개인 맞춤 설정</Text>
            <Text style={styles.sectionCaption}>이름, 성격, 지침, 메모리</Text>
          </View>
          <Badge
            variant={personalCustomization.memoryEnabled ? 'success' : 'outline'}
          >
            {personalCustomization.memoryEnabled ? '메모리 켜짐' : '메모리 꺼짐'}
          </Badge>
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>이름</Text>
          <TextInput
            accessibilityLabel="이름"
            onChangeText={userName => updatePersonalCustomization({ userName })}
            placeholder="예: Minjun"
            placeholderTextColor={colors.mutedForeground}
            style={styles.settingsTextInput}
            value={personalCustomization.userName}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>성격</Text>
          <TextInput
            accessibilityLabel="성격"
            multiline
            onChangeText={personality =>
              updatePersonalCustomization({ personality })
            }
            placeholder="예: 차분하고 직접적이며, 필요한 경우 근거를 짧게 설명해줘."
            placeholderTextColor={colors.mutedForeground}
            style={[styles.settingsTextInput, styles.shortTextArea]}
            textAlignVertical="top"
            value={personalCustomization.personality}
          />
        </View>

        <View style={styles.fieldGroup}>
          <Text style={styles.fieldLabel}>맞춤형 지침</Text>
          <TextInput
            accessibilityLabel="맞춤형 지침"
            multiline
            onChangeText={customInstructions =>
              updatePersonalCustomization({ customInstructions })
            }
            placeholder="예: 항상 한국어로 간결하게 답하고, 모호한 요청은 필요한 가정을 먼저 밝혀줘."
            placeholderTextColor={colors.mutedForeground}
            style={[styles.settingsTextInput, styles.longTextArea]}
            textAlignVertical="top"
            value={personalCustomization.customInstructions}
          />
        </View>

        <Separator style={styles.separator} />

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>메모리 활성</Text>
            <Text style={styles.sectionCaption}>
              채팅 기록에서 기억을 생성하고 이후 응답에 반영합니다.
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
          <Text style={styles.fieldLabel}>저장된 메모리 리스트</Text>
          <View style={styles.memoryList}>
            {personalCustomization.savedMemories.length > 0 ? (
              personalCustomization.savedMemories.map((memory, index) => (
                <View key={`${memory}-${index}`} style={styles.memoryListItem}>
                  <Text style={styles.memoryListText}>{memory}</Text>
                </View>
              ))
            ) : (
              <Text style={styles.emptyMemoryText}>
                채팅 기록에서 생성된 메모리가 여기에 표시됩니다.
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
        '모양',
        '앱에서 반복적으로 보는 텍스트의 표시 크기를 설정합니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>모양</Text>
            <Text style={styles.sectionCaption}>텍스트 크기</Text>
          </View>
          <Badge variant="outline">{selectedTextSize.label}</Badge>
        </View>

        <Text style={styles.personalizationDescription}>
          {selectedTextSize.description}
        </Text>

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
                    {option.label}
                  </Text>
                  <Text style={styles.textSizeDescription}>
                    {option.description}
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
        '모델',
        '온디바이스 모델 파일과 런타임 연결 상태를 관리합니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>모델</Text>
            <Text style={styles.sectionCaption}>엔진 연결 상태</Text>
          </View>
          <Badge variant={status.isAvailable ? 'success' : 'secondary'}>
            {status.isAvailable ? '연결됨' : '대기 중'}
          </Badge>
        </View>

        <Separator style={styles.separator} />

        <StatusRow
          label="Native bridge"
          value={status.isAvailable ? '연결됨' : '대기 중'}
        />
        <StatusRow
          label="기본 모델"
          value={modelStatus?.modelName ?? 'gemma-4-E2B-it'}
        />
        <StatusRow
          label="모델 파일"
          value={
            modelStatus?.installed
              ? '설치됨'
              : modelStatus?.isDownloading
              ? '다운로드 중'
              : '필요함'
          }
        />
        <StatusRow
          label="다운로드"
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
            label="모델 다운로드"
            onPress={handleDownloadModel}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            disabled={!modelStatus?.isDownloading}
            label="취소"
            onPress={handleCancelModelDownload}
            style={styles.modelButton}
            variant="ghost"
          />
        </View>
        <StatusRow
          label="런타임"
          value={
            runtimeStatus?.loaded
              ? '로드됨'
              : runtimeStatus?.loading
              ? '로드 중'
              : '꺼짐'
          }
        />
        <View style={styles.actionRow}>
          <Button
            disabled={!modelStatus?.installed || runtimeStatus?.loaded}
            label="모델 켜기"
            onPress={handleLoadModel}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            disabled={!runtimeStatus?.loaded}
            label="모델 끄기"
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
        '임베딩 설정',
        '검색과 개인 메모리에 사용할 소스별 임베딩을 관리합니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>임베딩 설정</Text>
            <Text style={styles.sectionCaption}>소스별 임베딩 생성/삭제</Text>
          </View>
        </View>

        <Separator style={styles.separator} />

        <StatusRow
          label="임베딩 항목"
          value={`${status.indexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="SMS 임베딩"
          value={`${status.smsIndexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="갤러리 임베딩"
          value={`${status.galleryIndexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="문서 임베딩"
          value={`${status.documentIndexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="마지막 임베딩 생성"
          value={status.lastIndexedAt ?? '기록 없음'}
        />

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>SMS</Text>
            <Text style={styles.sectionCaption}>문자 임베딩</Text>
          </View>
          <SettingsToggle
            disabled={status.isIndexing}
            onValueChange={handleSmsToggle}
            value={status.smsEnabled}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>갤러리</Text>
            <Text style={styles.sectionCaption}>사진 임베딩</Text>
          </View>
          <SettingsToggle
            disabled={status.isIndexing}
            onValueChange={handleGalleryToggle}
            value={status.galleryEnabled}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>문서</Text>
            <Text style={styles.sectionCaption}>다운로드/공유 문서 임베딩</Text>
          </View>
          <SettingsToggle
            disabled={status.isIndexing}
            onValueChange={handleDocumentToggle}
            value={status.documentEnabled}
          />
        </View>

        <Text style={styles.description}>
          백그라운드 작업과 권한 상태는 네이티브 엔진 연결에 맞춰 갱신됩니다.
        </Text>

        <Button
          disabled={status.isIndexing}
          label="SMS/갤러리/문서 임베딩 생성"
          textStyle={styles.refreshButtonText}
          onPress={handleStartIndexing}
          style={styles.refreshButton}
          variant="ghost"
        />

        <View style={styles.actionRow}>
          <Button
            label="SMS 임베딩 삭제"
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteSms}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            label="갤러리 임베딩 삭제"
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteGallery}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            label="문서 임베딩 삭제"
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteDocuments}
            style={styles.modelButton}
            variant="ghost"
          />
        </View>

        <Button
          label="상태 새로고침"
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
