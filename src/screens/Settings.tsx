import React, { useCallback, useEffect, useState } from 'react';
import { faCheck } from '@fortawesome/free-solid-svg-icons';
import { Pressable, ScrollView, StyleSheet, Switch, View } from 'react-native';

import AppIcon from '../components/AppIcon';
import { Badge, Button, Separator } from '../components/ui';
import AIEngine, { IndexingStatus } from '../native/AIEngine';
import { ScaledText as Text, useDisplaySettings } from '../theme/display';
import { colors, typography } from '../theme/tokens';

const defaultStatus: IndexingStatus = {
  indexedItems: 0,
  isAvailable: false,
  isIndexing: false,
};

function Settings() {
  const [status, setStatus] = useState<IndexingStatus>(defaultStatus);
  const [galleryIndexingEnabled, setGalleryIndexingEnabled] = useState(false);
  const { selectedTextSize, setTextSize, textSize, textSizes } =
    useDisplaySettings();

  const refreshStatus = useCallback(async () => {
    const nextStatus = await AIEngine.getIndexingStatus();
    setStatus(nextStatus);
  }, []);

  useEffect(() => {
    refreshStatus();
  }, [refreshStatus]);

  return (
    <ScrollView
      contentContainerStyle={styles.container}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.header}>
        <Text style={styles.title}>설정</Text>
        <Text style={styles.description}>
          개인화, 모델, 인덱싱 상태를 한 곳에서 확인합니다.
        </Text>
      </View>

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
                  <AppIcon color={colors.primary} icon={faCheck} size={17} />
                ) : null}
              </Pressable>
            );
          })}
        </View>
      </View>

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
        <StatusRow label="기본 모델" value="Gemma 4" />
        <StatusRow
          label="인덱싱 항목"
          value={`${status.indexedItems.toLocaleString('ko-KR')}개`}
        />
        <StatusRow
          label="마지막 인덱싱"
          value={status.lastIndexedAt ?? '기록 없음'}
        />
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View style={styles.switchCopy}>
            <Text style={styles.sectionTitle}>인덱싱</Text>
            <Text style={styles.sectionCaption}>파일과 일정 인덱싱</Text>
          </View>
          <Switch
            onValueChange={setGalleryIndexingEnabled}
            thumbColor={galleryIndexingEnabled ? colors.card : '#F8FAFC'}
            trackColor={{
              false: colors.border,
              true: colors.primary,
            }}
            value={galleryIndexingEnabled}
          />
        </View>

        <Separator style={styles.separator} />

        <Text style={styles.description}>
          백그라운드 작업과 권한 상태는 네이티브 엔진 연결에 맞춰 갱신됩니다.
        </Text>

        <Button
          label="상태 새로고침"
          textStyle={styles.refreshButtonText}
          onPress={refreshStatus}
          style={styles.refreshButton}
          variant="ghost"
        />
      </View>
    </ScrollView>
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

const styles = StyleSheet.create({
  container: {
    paddingBottom: 42,
    paddingHorizontal: 24,
    paddingTop: 86,
  },
  header: {
    marginBottom: 42,
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
  separator: {
    marginVertical: 14,
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
