import React, {useEffect, useState} from 'react';
import {Pressable, StyleSheet, Text, View} from 'react-native';

import AIEngine, {IndexingStatus} from '../native/AIEngine';

type SettingsProps = {
  onBack: () => void;
};

function Settings({onBack}: SettingsProps) {
  const [status, setStatus] = useState<IndexingStatus | null>(null);

  useEffect(() => {
    AIEngine.getIndexingStatus().then(setStatus);
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="button"
          onPress={onBack}
          style={({pressed}) => [styles.backButton, pressed && styles.pressed]}>
          <Text style={styles.backButtonText}>‹</Text>
        </Pressable>
        <Text style={styles.title}>Settings</Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.label}>Indexing Status</Text>
        <Text style={styles.value}>
          {status?.isIndexing ? 'Indexing' : 'Idle'}
        </Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.label}>Indexed Items</Text>
        <Text style={styles.value}>{status?.indexedItems ?? 0}</Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.label}>Last Indexed At</Text>
        <Text style={styles.value}>{status?.lastIndexedAt ?? 'Not indexed'}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f7f3ea',
  },
  header: {
    minHeight: 72,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#d8d0c1',
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#e8dfd1',
    marginRight: 12,
  },
  backButtonText: {
    color: '#24211d',
    fontSize: 30,
    lineHeight: 32,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#191713',
  },
  section: {
    paddingHorizontal: 18,
    paddingVertical: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#ded6c8',
  },
  label: {
    color: '#6d6254',
    fontSize: 13,
    marginBottom: 6,
  },
  value: {
    color: '#201d18',
    fontSize: 17,
    fontWeight: '600',
  },
  pressed: {
    opacity: 0.75,
  },
});

export default Settings;
