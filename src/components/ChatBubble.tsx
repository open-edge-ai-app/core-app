import React, { useEffect, useRef, useState } from 'react';
import {
  Image,
  ImageSourcePropType,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';

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
import AppIcon from './AppIcon';
import { Button } from './ui';
import { copyToClipboard } from '../native/Clipboard';
import { ScaledText as Text } from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors, typography } from '../theme/tokens';

export type ChatRole = 'assistant' | 'user' | 'system';

export type ChatBubbleAction = {
  label: string;
  onPress: () => void;
};

type ChatBubbleProps = {
  actions?: ChatBubbleAction[];
  assistantName?: string;
  isRetryDisabled?: boolean;
  onAddToPrompt?: () => void;
  onRetry?: () => void;
  reasoning?: string;
  role: ChatRole;
  text: string;
  thumbnail?: ImageSourcePropType;
  timestamp?: string;
};

type AssistantProfile = {
  backgroundColor: string;
  foregroundColor: string;
  logoSource?: ImageSourcePropType;
};

const modelLogoProfiles: Array<{
  matches: string[];
  source: ImageSourcePropType;
}> = [
  {
    matches: ['gemma'],
    source: gemmaLogo,
  },
  {
    matches: ['gemini'],
    source: geminiLogo,
  },
  {
    matches: ['openai', 'gpt'],
    source: openaiLogo,
  },
  {
    matches: ['claude', 'anthropic'],
    source: claudeLogo,
  },
  {
    matches: ['deepseek'],
    source: deepseekLogo,
  },
  {
    matches: ['mistral'],
    source: mistralLogo,
  },
  {
    matches: ['qwen'],
    source: qwenLogo,
  },
  {
    matches: ['hugging face', 'huggingface', 'hf '],
    source: huggingFaceLogo,
  },
  {
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
      logoSource: matchedLogo.source,
    };
  }

  return {
    backgroundColor: colors.muted,
    foregroundColor: colors.foreground,
  };
};

function ChatBubble({
  actions = [],
  assistantName = 'Gemma 4',
  isRetryDisabled = false,
  onAddToPrompt,
  onRetry,
  reasoning,
  role,
  text,
  thumbnail,
  timestamp,
}: ChatBubbleProps) {
  const assistantProfile = getAssistantProfile(assistantName);
  const [isCopied, setIsCopied] = useState(false);
  const [isReasoningExpanded, setIsReasoningExpanded] = useState(false);
  const copiedTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const canUseAssistantActions = role === 'assistant' && text.trim().length > 0;

  useEffect(
    () => () => {
      if (copiedTimeoutRef.current) {
        clearTimeout(copiedTimeoutRef.current);
      }
    },
    [],
  );

  const handleCopyResponse = async () => {
    const didCopy = await copyToClipboard(text);
    if (!didCopy) {
      return;
    }

    setIsCopied(true);
    if (copiedTimeoutRef.current) {
      clearTimeout(copiedTimeoutRef.current);
    }
    copiedTimeoutRef.current = setTimeout(() => {
      setIsCopied(false);
    }, 1400);
  };

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
          <AppIcon
            color={assistantProfile.foregroundColor}
            icon={appIcons.chatAssistant}
            size={14}
          />
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

        {reasoning?.trim() ? (
          <View style={styles.reasoningBox}>
            <Pressable
              accessibilityRole="button"
              onPress={() => setIsReasoningExpanded(current => !current)}
              style={styles.reasoningHeader}
            >
              <Text style={styles.reasoningTitle}>생각하는 과정 표시</Text>
              <Text style={styles.reasoningChevron}>
                {isReasoningExpanded ? '⌃' : '⌄'}
              </Text>
            </Pressable>
            {isReasoningExpanded ? (
              <Text selectable style={styles.reasoningText}>
                {reasoning.trim()}
              </Text>
            ) : null}
          </View>
        ) : null}

        <MarkdownText selectable style={styles.assistantText} text={text} />

        {canUseAssistantActions ? (
          <View style={styles.assistantActions}>
            <Pressable
              accessibilityLabel="AI 응답 전체 복사"
              accessibilityRole="button"
              hitSlop={6}
              onPress={handleCopyResponse}
              style={({ pressed }) => [
                styles.assistantActionButton,
                pressed && styles.assistantActionButtonPressed,
              ]}
            >
              <AppIcon
                color={isCopied ? colors.success : colors.mutedForeground}
                icon={appIcons.copy}
                size={13}
              />
              {isCopied ? (
                <Text style={styles.assistantActionFeedback}>복사됨</Text>
              ) : null}
            </Pressable>

            {onAddToPrompt ? (
              <Pressable
                accessibilityLabel="AI 응답을 채팅에 추가"
                accessibilityRole="button"
                hitSlop={6}
                onPress={onAddToPrompt}
                style={({ pressed }) => [
                  styles.assistantActionButton,
                  styles.assistantActionButtonWide,
                  pressed && styles.assistantActionButtonPressed,
                ]}
              >
                <AppIcon
                  color={colors.mutedForeground}
                  icon={appIcons.plus}
                  size={12}
                />
                <Text style={styles.assistantActionLabel}>채팅에 추가</Text>
              </Pressable>
            ) : null}

            {onRetry ? (
              <Pressable
                accessibilityLabel="AI 응답 다시 시도"
                accessibilityRole="button"
                disabled={isRetryDisabled}
                hitSlop={6}
                onPress={onRetry}
                style={({ pressed }) => [
                  styles.assistantActionButton,
                  pressed && styles.assistantActionButtonPressed,
                  isRetryDisabled && styles.assistantActionButtonDisabled,
                ]}
              >
                <AppIcon
                  color={colors.mutedForeground}
                  icon={appIcons.retry}
                  size={13}
                />
              </Pressable>
            ) : null}
          </View>
        ) : null}

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
  reasoningBox: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    marginBottom: 10,
    overflow: 'hidden',
  },
  reasoningHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 36,
    paddingHorizontal: 10,
  },
  reasoningTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 13,
  },
  reasoningChevron: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 17,
    lineHeight: 18,
  },
  reasoningText: {
    ...typography.caption,
    borderTopColor: colors.border,
    borderTopWidth: StyleSheet.hairlineWidth,
    color: colors.mutedForeground,
    lineHeight: 18,
    paddingHorizontal: 10,
    paddingVertical: 9,
  },
  assistantActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
    marginTop: 10,
  },
  assistantActionButton: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 5,
    height: 30,
    justifyContent: 'center',
    minWidth: 30,
    paddingHorizontal: 8,
  },
  assistantActionButtonWide: {
    minWidth: 92,
  },
  assistantActionButtonDisabled: {
    opacity: 0.42,
  },
  assistantActionButtonPressed: {
    backgroundColor: colors.muted,
  },
  assistantActionFeedback: {
    ...typography.caption,
    color: colors.success,
    fontSize: 11,
    fontWeight: '700',
  },
  assistantActionLabel: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 11,
    fontWeight: '700',
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
