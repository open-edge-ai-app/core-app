import React, { useEffect, useRef, useState } from 'react';
import {
  Image,
  ImageSourcePropType,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';

import MarkdownText from './MarkdownText';
import AppIcon from './AppIcon';
import { Button } from './ui';
import { copyToClipboard } from '../native/Clipboard';
import type { MultimodalAttachment } from '../native/AIEngine';
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
  attachmentFallbackName?: string;
  attachments?: MultimodalAttachment[];
  assistantName?: string;
  isRetryDisabled?: boolean;
  onRetry?: () => void;
  reasoning?: string;
  role: ChatRole;
  text: string;
  thumbnail?: ImageSourcePropType;
  timestamp?: string;
};

const getAttachmentDisplayName = (
  attachment: MultimodalAttachment,
  fallbackName: string,
) => attachment.name?.trim() || fallbackName;

const formatAttachmentSize = (sizeBytes?: number) => {
  if (
    typeof sizeBytes !== 'number' ||
    !Number.isFinite(sizeBytes) ||
    sizeBytes <= 0
  ) {
    return '';
  }

  if (sizeBytes < 1024) {
    return `${Math.round(sizeBytes)} B`;
  }

  if (sizeBytes < 1024 * 1024) {
    return `${(sizeBytes / 1024).toFixed(1)} KB`;
  }

  return `${(sizeBytes / (1024 * 1024)).toFixed(1)} MB`;
};

const getAttachmentMeta = (attachment: MultimodalAttachment) =>
  [attachment.type.toUpperCase(), formatAttachmentSize(attachment.sizeBytes)]
    .filter(Boolean)
    .join(' / ');

function ChatBubble({
  actions = [],
  attachmentFallbackName = 'Attachment',
  attachments = [],
  isRetryDisabled = false,
  onRetry,
  reasoning,
  role,
  text,
  thumbnail,
  timestamp,
}: ChatBubbleProps) {
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
        {attachments.length > 0 ? (
          <View style={styles.userAttachmentList}>
            {attachments.map(attachment => {
              const attachmentName = getAttachmentDisplayName(
                attachment,
                attachmentFallbackName,
              );
              const attachmentMeta = getAttachmentMeta(attachment);

              return (
                <View
                  key={attachment.id ?? attachment.uri}
                  style={styles.userAttachmentCard}
                >
                  <View style={styles.userAttachmentIcon}>
                    <AppIcon
                      color={colors.mutedForeground}
                      icon={appIcons.attachment}
                      size={14}
                    />
                  </View>
                  <View style={styles.userAttachmentCopy}>
                    <Text
                      numberOfLines={1}
                      style={styles.userAttachmentName}
                    >
                      {attachmentName}
                    </Text>
                    {attachmentMeta ? (
                      <Text style={styles.userAttachmentMeta}>
                        {attachmentMeta}
                      </Text>
                    ) : null}
                  </View>
                </View>
              );
            })}
          </View>
        ) : null}
        {text.trim() ? <Text style={styles.userText}>{text}</Text> : null}
      </View>
    );
  }

  return (
    <View style={styles.assistantRow}>
      <View style={styles.assistantContent}>
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

        {canUseAssistantActions || timestamp ? (
          <View style={styles.assistantFooter}>
            <View style={styles.assistantActions}>
              {canUseAssistantActions ? (
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
              ) : null}

              {canUseAssistantActions && onRetry ? (
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

            {timestamp ? (
              <Text style={styles.assistantFooterTimestamp}>{timestamp}</Text>
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
    marginBottom: 22,
  },
  assistantContent: {
    flex: 1,
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
  assistantFooter: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 10,
  },
  assistantActions: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
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
  assistantFooterTimestamp: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 11,
  },
  userRow: {
    alignItems: 'flex-end',
    marginBottom: 22,
    paddingLeft: 42,
  },
  userAttachmentList: {
    alignItems: 'flex-end',
    gap: 8,
    marginBottom: 8,
    maxWidth: 282,
  },
  userAttachmentCard: {
    alignItems: 'center',
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 9,
    maxWidth: 282,
    minHeight: 48,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  userAttachmentIcon: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderRadius: 9,
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  userAttachmentCopy: {
    flexShrink: 1,
    minWidth: 0,
  },
  userAttachmentName: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 13,
    lineHeight: 17,
    maxWidth: 208,
  },
  userAttachmentMeta: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 10,
    marginTop: 3,
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
