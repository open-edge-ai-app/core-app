import React, { useCallback, useEffect, useState } from 'react';
import { ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { Badge, Button, Separator } from '../components/ui';
import AIEngine, { IndexingStatus } from '../native/AIEngine';
import { colors, typography } from '../theme/tokens';

const defaultStatus: IndexingStatus = {
  indexedItems: 0,
  isAvailable: false,
  isIndexing: false,
};

function Settings() {
  const [status, setStatus] = useState<IndexingStatus>(defaultStatus);
  const [galleryIndexingEnabled, setGalleryIndexingEnabled] = useState(false);

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
          로컬 AI 엔진, 인덱싱, 권한 상태를 한 곳에서 확인합니다.
        </Text>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <View>
            <Text style={styles.sectionTitle}>엔진</Text>
            <Text style={styles.sectionCaption}>네이티브 연결 상태</Text>
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
        <StatusRow label="모델" value="Gemma 준비 중" />
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
            <Text style={styles.sectionCaption}>
              갤러리 및 일정 인덱싱
            </Text>
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
          권한과 백그라운드 워커가 연결되기 전까지는 화면 상태만 관리합니다.
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
    paddingBottom: 34,
    paddingHorizontal: 20,
    paddingTop: 18,
  },
  header: {
    marginBottom: 26,
    paddingTop: 10,
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
    marginBottom: 28,
    paddingTop: 20,
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
