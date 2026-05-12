import React from 'react';
import { Image, ImageSourcePropType, StyleSheet, View } from 'react-native';

import claudeLogo from '@lobehub/icons-static-png/light/claude-color.png';
import deepseekLogo from '@lobehub/icons-static-png/light/deepseek-color.png';
import geminiLogo from '@lobehub/icons-static-png/light/gemini-color.png';
import gemmaLogo from '@lobehub/icons-static-png/light/gemma-color.png';
import huggingFaceLogo from '@lobehub/icons-static-png/light/huggingface-color.png';
import mistralLogo from '@lobehub/icons-static-png/light/mistral-color.png';
import ollamaLogo from '@lobehub/icons-static-png/light/ollama.png';
import openaiLogo from '@lobehub/icons-static-png/light/openai.png';
import qwenLogo from '@lobehub/icons-static-png/light/qwen-color.png';

import MarkdownText from './MarkdownText';
import { Button } from './ui';
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

type AssistantProfile = {
  backgroundColor: string;
  foregroundColor: string;
  label: string;
  logoSource?: ImageSourcePropType;
};

const modelLogoProfiles: Array<{
  label: string;
  matches: string[];
  source: ImageSourcePropType;
}> = [
  {
    label: 'Gemma',
    matches: ['gemma'],
    source: gemmaLogo,
  },
  {
    label: 'Gemini',
    matches: ['gemini'],
    source: geminiLogo,
  },
  {
    label: 'OpenAI',
    matches: ['openai', 'gpt'],
    source: openaiLogo,
  },
  {
    label: 'Claude',
    matches: ['claude', 'anthropic'],
    source: claudeLogo,
  },
  {
    label: 'DeepSeek',
    matches: ['deepseek'],
    source: deepseekLogo,
  },
  {
    label: 'Mistral',
    matches: ['mistral'],
    source: mistralLogo,
  },
  {
    label: 'Qwen',
    matches: ['qwen'],
    source: qwenLogo,
  },
  {
    label: 'Hugging Face',
    matches: ['hugging face', 'huggingface', 'hf '],
    source: huggingFaceLogo,
  },
  {
    label: 'Ollama',
    matches: ['ollama'],
    source: ollamaLogo,
  },
];

const getAssistantProfile = (assistantName: string): AssistantProfile => {
  const normalizedName = assistantName.toLowerCase();
  const matchedLogo = modelLogoProfiles.find(profile =>
    profile.matches.some(match => normalizedName.includes(match)),
  );

  if (matchedLogo) {
    return {
      backgroundColor: '#FFFFFF',
      foregroundColor: colors.foreground,
      label: matchedLogo.label,
      logoSource: matchedLogo.source,
    };
  }

  return {
    backgroundColor: colors.muted,
    foregroundColor: colors.foreground,
    label: assistantName.trim().slice(0, 2).toUpperCase() || 'AI',
  };
};

function ChatBubble({
  actions = [],
  assistantName = 'Gemma 4',
  role,
  text,
  thumbnail,
  timestamp,
}: ChatBubbleProps) {
  const assistantProfile = getAssistantProfile(assistantName);

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
      <View
        accessibilityLabel={`${assistantName} 모델 프로필`}
        accessibilityRole="image"
        accessible
        style={[
          styles.avatarIcon,
          { backgroundColor: assistantProfile.backgroundColor },
        ]}
      >
        {assistantProfile.logoSource ? (
          <Image
            resizeMode="contain"
            source={assistantProfile.logoSource}
            style={styles.avatarLogo}
          />
        ) : (
          <Text
            style={[
              styles.avatarModelLabel,
              { color: assistantProfile.foregroundColor },
            ]}
          >
            {assistantProfile.label}
          </Text>
        )}
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
    borderColor: colors.border,
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    height: 28,
    justifyContent: 'center',
    overflow: 'hidden',
    width: 28,
  },
  avatarLogo: {
    height: 20,
    width: 20,
  },
  avatarModelLabel: {
    ...typography.caption,
    fontSize: 10,
    fontWeight: '800',
    lineHeight: 12,
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
