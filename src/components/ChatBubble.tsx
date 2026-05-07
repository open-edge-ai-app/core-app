import React from 'react';
import { faWandMagicSparkles } from '@fortawesome/free-solid-svg-icons';
import {
  Image,
  ImageSourcePropType,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import AppIcon from './AppIcon';
import { Button } from './ui';
import { colors, typography } from '../theme/tokens';

export type ChatRole = 'assistant' | 'user' | 'system';

export type ChatBubbleAction = {
  label: string;
  onPress: () => void;
};

type ChatBubbleProps = {
  actions?: ChatBubbleAction[];
  role: ChatRole;
  text: string;
  thumbnail?: ImageSourcePropType;
  timestamp?: string;
};

function ChatBubble({
  actions = [],
  role,
  text,
  thumbnail,
  timestamp,
}: ChatBubbleProps) {
  if (role === 'system') {
    return (
      <View style={styles.systemRow}>
        <Text style={styles.systemLabel}>System</Text>
        <Text style={styles.systemText}>{text}</Text>
      </View>
    );
  }

  if (role === 'user') {
    return (
      <View style={styles.userRow}>
        <Text style={styles.userLabel}>You</Text>
        <Text style={styles.userText}>{text}</Text>
      </View>
    );
  }

  return (
    <View style={styles.assistantRow}>
      <View style={styles.avatarIcon}>
        <AppIcon
          color={colors.accentForeground}
          icon={faWandMagicSparkles}
          size={13}
        />
      </View>

      <View style={styles.assistantContent}>
        <View style={styles.assistantHeader}>
          <Text style={styles.botLabel}>Open Edge</Text>
          {timestamp ? <Text style={styles.timestamp}>{timestamp}</Text> : null}
        </View>

        {thumbnail ? (
          <Image source={thumbnail} style={styles.thumbnail} />
        ) : null}

        <Text style={styles.assistantText}>{text}</Text>

        {actions.length > 0 ? (
          <View style={styles.actions}>
            {actions.map(action => (
              <Button
                key={action.label}
                label={action.label}
                onPress={action.onPress}
                size="sm"
                variant="outline"
              />
            ))}
          </View>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  assistantRow: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 20,
  },
  avatarIcon: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: 14,
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
  assistantContent: {
    flex: 1,
  },
  assistantHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  botLabel: {
    ...typography.label,
    color: colors.foreground,
  },
  timestamp: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 11,
  },
  assistantText: {
    ...typography.body,
    color: colors.cardForeground,
    fontWeight: '400',
    lineHeight: 24,
  },
  userRow: {
    alignItems: 'flex-end',
    marginBottom: 20,
    paddingLeft: 42,
  },
  userText: {
    ...typography.body,
    color: colors.primary,
    fontSize: 17,
    fontWeight: '600',
    lineHeight: 24,
    textAlign: 'right',
  },
  userLabel: {
    ...typography.caption,
    color: colors.mutedForeground,
    marginBottom: 6,
    textTransform: 'uppercase',
  },
  systemRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
    marginBottom: 16,
  },
  systemLabel: {
    ...typography.caption,
    color: colors.mutedForeground,
    textTransform: 'uppercase',
  },
  systemText: {
    ...typography.caption,
    color: colors.mutedForeground,
    maxWidth: 230,
  },
  thumbnail: {
    height: 120,
    marginBottom: 10,
    width: 180,
  },
  actions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 12,
  },
});

export default ChatBubble;
