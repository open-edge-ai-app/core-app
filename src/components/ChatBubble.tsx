import React from 'react';
import { Image, ImageSourcePropType, StyleSheet, View } from 'react-native';

import MarkdownText from './MarkdownText';
import { Button } from './ui';
import assistantLogo from '../assets/assistant-logo.png';
import { ScaledText as Text } from '../theme/display';
import { colors, typography } from '../theme/tokens';

export type ChatRole = 'assistant' | 'user' | 'system';

export type ChatBubbleAction = {
  label: string;
  onPress: () => void;
};

type ChatBubbleProps = {
  actions?: ChatBubbleAction[];
  assistantName?: string;
  role: ChatRole;
  text: string;
  thumbnail?: ImageSourcePropType;
  timestamp?: string;
};

function ChatBubble({
  actions = [],
  assistantName = 'Gemma 4',
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
        <Text style={styles.userText}>{text}</Text>
      </View>
    );
  }

  return (
    <View style={styles.assistantRow}>
      <View style={styles.avatarIcon}>
        <Image
          accessibilityIgnoresInvertColors
          source={assistantLogo}
          style={styles.avatarLogo}
        />
      </View>

      <View style={styles.assistantContent}>
        <View style={styles.assistantHeader}>
          <Text style={styles.botLabel}>{assistantName}</Text>
          {timestamp ? <Text style={styles.timestamp}>{timestamp}</Text> : null}
        </View>

        {thumbnail ? (
          <Image source={thumbnail} style={styles.thumbnail} />
        ) : null}

        <MarkdownText style={styles.assistantText} text={text} />

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
    gap: 11,
    marginBottom: 22,
  },
  avatarIcon: {
    alignItems: 'center',
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    height: 28,
    justifyContent: 'center',
    overflow: 'hidden',
    width: 28,
  },
  avatarLogo: {
    height: 24,
    width: 24,
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
    fontSize: 14,
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
    marginBottom: 22,
    paddingLeft: 42,
  },
  userText: {
    ...typography.body,
    backgroundColor: colors.primary,
    borderRadius: 14,
    color: colors.primaryForeground,
    fontSize: 16,
    fontWeight: '500',
    lineHeight: 22,
    maxWidth: 282,
    overflow: 'hidden',
    paddingHorizontal: 14,
    paddingVertical: 10,
    textAlign: 'right',
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
