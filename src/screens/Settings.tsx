import React, { useCallback, useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import AppIcon from '../components/AppIcon';
import { Badge, Button, Separator } from '../components/ui';
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
  onPersonalSystemPromptChange: (prompt: string) => void;
  personalSystemPrompt: string;
};

export type SettingsPanelId =
  | 'root'
  | 'systemPrompt'
  | 'personalization'
  | 'model'
  | 'indexing';

function Settings({
  activePanel,
  onModelStateChange,
  onPanelChange,
  onPersonalSystemPromptChange,
  personalSystemPrompt,
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
      runtimeStatus: loadingStatus,
    });

    try {
      const nextStatus = await AIEngine.loadModel();
      setRuntimeStatus(nextStatus);
      onModelStateChange?.({
        modelStatus,
        runtimeStatus: nextStatus,
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
        runtimeStatus: errorStatus,
      });
    }
  }, [modelStatus, onModelStateChange, runtimeStatus?.localPath]);

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

  const handleDeleteSms = useCallback(async () => {
    const result = await AIEngine.deleteIndexingSource('sms');
    setStatus(result.status);
  }, []);

  const handleDeleteGallery = useCallback(async () => {
    const result = await AIEngine.deleteIndexingSource('gallery');
    setStatus(result.status);
  }, []);

  const modelSummary = modelStatus?.installed
    ? runtimeStatus?.loaded
      ? '로드됨'
      : '설치됨'
    : modelStatus?.isDownloading
    ? '다운로드 중'
    : '설치 필요';
  const indexingSummary = status.isIndexing
    ? '인덱싱 중'
    : `${status.indexedItems.toLocaleString('ko-KR')}개`;
  const renderDetailHeader = (title: string, description: string) => (
    <View style={styles.header}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.description}>{description}</Text>
    </View>
  );

  const renderRoot = () => (
    <>
      <View style={styles.header}>
        <Text style={styles.title}>설정</Text>
        <Text style={styles.description}>
          필요한 항목을 선택해서 상세 설정으로 들어갑니다.
        </Text>
      </View>

      <View style={styles.settingsList}>
        <SettingsNavigationRow
          caption="개인 기본 지침과 작업 폴더 메모리 적용 순서"
          onPress={() => onPanelChange('systemPrompt')}
          title="시스템 프롬프트"
          value={personalSystemPrompt.trim() ? '적용 중' : '비어 있음'}
          valueVariant={personalSystemPrompt.trim() ? 'success' : 'outline'}
        />
        <SettingsNavigationRow
          caption="앱 전체 텍스트 크기"
          onPress={() => onPanelChange('personalization')}
          title="개인화"
          value={selectedTextSize.label}
          valueVariant="outline"
        />
        <SettingsNavigationRow
          caption="모델 다운로드, 런타임 로드, 엔진 연결 상태"
          onPress={() => onPanelChange('model')}
          title="모델"
          value={modelSummary}
          valueVariant={runtimeStatus?.loaded ? 'success' : 'secondary'}
        />
        <SettingsNavigationRow
          caption="SMS/Gallery 임베딩 생성과 삭제"
          onPress={() => onPanelChange('indexing')}
          title="인덱싱"
          value={indexingSummary}
          valueVariant={status.isIndexing ? 'success' : 'outline'}
        />
      </View>
    </>
  );

  const renderSystemPrompt = () => (
    <>
      {renderDetailHeader(
        '시스템 프롬프트',
        '개인 기본 지침을 관리합니다. 작업 폴더의 시스템 프롬프트(메모리)는 이 지침 아래에 추가됩니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>시스템 프롬프트</Text>
            <Text style={styles.sectionCaption}>개인 기본 지침</Text>
          </View>
          <Badge variant={personalSystemPrompt.trim() ? 'success' : 'outline'}>
            {personalSystemPrompt.trim() ? '적용 중' : '비어 있음'}
          </Badge>
        </View>

        <Text style={styles.personalizationDescription}>
          모든 채팅에 먼저 적용됩니다. 작업 폴더의 시스템 프롬프트(메모리)는 이
          지침 아래에 추가됩니다.
        </Text>

        <TextInput
          accessibilityLabel="개인 시스템 프롬프트"
          multiline
          onChangeText={onPersonalSystemPromptChange}
          placeholder="예: 항상 한국어로 간결하게 답하고, 모호한 요청은 필요한 가정을 먼저 밝혀줘."
          placeholderTextColor={colors.mutedForeground}
          style={styles.systemPromptInput}
          textAlignVertical="top"
          value={personalSystemPrompt}
        />
      </View>
    </>
  );

  const renderPersonalization = () => (
    <>
      {renderDetailHeader(
        '개인화',
        '앱에서 반복적으로 보는 텍스트의 표시 크기를 설정합니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>개인화</Text>
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

  const renderIndexing = () => (
    <>
      {renderDetailHeader(
        '인덱싱',
        '검색과 개인 메모리에 사용할 소스별 임베딩을 관리합니다.',
      )}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>인덱싱</Text>
            <Text style={styles.sectionCaption}>소스별 임베딩 생성/삭제</Text>
          </View>
        </View>

        <Separator style={styles.separator} />

        <StatusRow
          label="인덱싱 항목"
          value={`${status.indexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="SMS embeddings"
          value={`${status.smsIndexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="Gallery embeddings"
          value={`${status.galleryIndexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="마지막 인덱싱"
          value={status.lastIndexedAt ?? '기록 없음'}
        />

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>SMS</Text>
            <Text style={styles.sectionCaption}>문자 임베딩</Text>
          </View>
          <SettingsToggle
            onValueChange={handleSmsToggle}
            value={status.smsEnabled}
          />
        </View>

        <View style={styles.toggleRow}>
          <View style={styles.switchCopy}>
            <Text style={styles.rowLabel}>Gallery</Text>
            <Text style={styles.sectionCaption}>사진 임베딩</Text>
          </View>
          <SettingsToggle
            onValueChange={handleGalleryToggle}
            value={status.galleryEnabled}
          />
        </View>

        <Text style={styles.description}>
          백그라운드 작업과 권한 상태는 네이티브 엔진 연결에 맞춰 갱신됩니다.
        </Text>

        <Button
          disabled={status.isIndexing}
          label="SMS/Gallery indexing"
          textStyle={styles.refreshButtonText}
          onPress={handleStartIndexing}
          style={styles.refreshButton}
          variant="ghost"
        />

        <View style={styles.actionRow}>
          <Button
            label="Delete SMS embeddings"
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteSms}
            style={styles.modelButton}
            variant="ghost"
          />
          <Button
            label="Delete gallery embeddings"
            textStyle={styles.refreshButtonText}
            onPress={handleDeleteGallery}
            style={styles.modelButton}
            variant="ghost"
          />
        </View>

        <Button
          label="Refresh status"
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
      case 'systemPrompt':
        return renderSystemPrompt();
      case 'personalization':
        return renderPersonalization();
      case 'model':
        return renderModel();
      case 'indexing':
        return renderIndexing();
      case 'root':
      default:
        return renderRoot();
    }
  };

  return (
    <ScrollView
      key={activePanel}
      contentContainerStyle={styles.container}
      showsVerticalScrollIndicator={false}
    >
      {renderActivePanel()}
    </ScrollView>
  );
}

type SettingsNavigationRowProps = {
  caption: string;
  onPress: () => void;
  title: string;
  value: string;
  valueVariant?: 'default' | 'secondary' | 'outline' | 'success';
};

function SettingsNavigationRow({
  caption,
  onPress,
  title,
  value,
  valueVariant = 'secondary',
}: SettingsNavigationRowProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.navigationRow,
        pressed && styles.rowPressed,
      ]}
    >
      <View style={styles.navigationCopy}>
        <Text style={styles.navigationTitle}>{title}</Text>
        <Text style={styles.navigationCaption}>{caption}</Text>
      </View>
      <View style={styles.navigationMeta}>
        <Badge variant={valueVariant}>{value}</Badge>
        <AppIcon
          color={colors.mutedForeground}
          icon={appIcons.openPrompt}
          size={14}
        />
      </View>
    </Pressable>
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
  onValueChange: (value: boolean) => void;
  value: boolean;
};

function SettingsToggle({ onValueChange, value }: SettingsToggleProps) {
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityState={{ checked: value }}
      hitSlop={8}
      onPress={() => onValueChange(!value)}
      style={({ pressed }) => [
        styles.settingsToggle,
        value && styles.settingsToggleOn,
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
  container: {
    paddingBottom: 42,
    paddingHorizontal: 24,
    paddingTop: 26,
  },
  header: {
    marginBottom: 28,
  },
  title: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 34,
    lineHeight: 40,
  },
  description: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 22,
    marginTop: 10,
  },
  settingsList: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  navigationRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    minHeight: 78,
    paddingVertical: 14,
  },
  navigationCopy: {
    flex: 1,
    paddingRight: 16,
  },
  navigationTitle: {
    ...typography.body,
    color: colors.foreground,
    fontSize: 17,
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
    gap: 10,
  },
  section: {
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginBottom: 34,
    paddingTop: 18,
  },
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 18,
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
  systemPromptInput: {
    ...typography.body,
    backgroundColor: colors.muted,
    borderColor: colors.input,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    color: colors.foreground,
    fontSize: 15,
    lineHeight: 21,
    marginTop: 16,
    minHeight: 132,
    paddingHorizontal: 14,
    paddingTop: 12,
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
