import React from 'react';
import {
  Pressable,
  LayoutChangeEvent,
  ScrollView,
  StyleProp,
  View,
  ViewStyle,
} from 'react-native';

import AppIcon from '../../components/AppIcon';
import { useI18n } from '../../i18n';
import { MultimodalAttachment } from '../../native/AIEngine';
import {
  ScaledText as Text,
  ScaledTextInput as TextInput,
} from '../../theme/display';
import { appIcons } from '../../theme/icons';
import { colors } from '../../theme/tokens';
import {
  createAttachmentSummary,
  formatAttachmentSize,
  getAttachmentKey,
  getAttachmentName,
  type QueuedChatRequest,
} from './chatTypes';
import { styles } from './chatStyles';

type ChatComposerProps = {
  attachmentError: string | null;
  canSubmit: boolean;
  composerOffsetStyle: StyleProp<ViewStyle>;
  defaultAttachmentName: string;
  draft: string;
  editingQueuedDraft: string;
  editingQueuedRequestId: string | null;
  isGenerationBusy: boolean;
  isStoppingGeneration: boolean;
  onAttachFile: () => void;
  onCancelQueuedRequestEdit: () => void;
  onChangeDraft: (text: string) => void;
  onChangeEditingQueuedDraft: (text: string) => void;
  onDeleteQueuedRequest: (requestId: string) => void;
  onEditQueuedRequest: (request: QueuedChatRequest) => void;
  onLayout: (event: LayoutChangeEvent) => void;
  onRemoveAttachment: (attachment: MultimodalAttachment) => void;
  onSaveQueuedRequestEdit: (requestId: string) => void;
  onSend: () => void;
  onStopGeneration: () => void;
  queuedRequests: QueuedChatRequest[];
  selectedAttachments: MultimodalAttachment[];
  shouldShowStopButton: boolean;
};

export default function ChatComposer({
  attachmentError,
  canSubmit,
  composerOffsetStyle,
  defaultAttachmentName,
  draft,
  editingQueuedDraft,
  editingQueuedRequestId,
  isGenerationBusy,
  isStoppingGeneration,
  onAttachFile,
  onCancelQueuedRequestEdit,
  onChangeDraft,
  onChangeEditingQueuedDraft,
  onDeleteQueuedRequest,
  onEditQueuedRequest,
  onLayout,
  onRemoveAttachment,
  onSaveQueuedRequestEdit,
  onSend,
  onStopGeneration,
  queuedRequests,
  selectedAttachments,
  shouldShowStopButton,
}: ChatComposerProps) {
  const { locale, t } = useI18n();

  return (
    <View onLayout={onLayout} style={[styles.composer, composerOffsetStyle]}>
      <View style={styles.inputPanel}>
        {selectedAttachments.length > 0 ? (
          <ScrollView
            horizontal
            keyboardShouldPersistTaps="handled"
            showsHorizontalScrollIndicator={false}
            style={styles.attachmentScroller}
          >
            <View style={styles.attachmentList}>
              {selectedAttachments.map(attachment => {
                const attachmentName = getAttachmentName(
                  attachment,
                  defaultAttachmentName,
                );
                const attachmentSize = formatAttachmentSize(
                  attachment.sizeBytes,
                );

                return (
                  <View
                    key={getAttachmentKey(attachment)}
                    style={styles.attachmentChip}
                  >
                    <AppIcon
                      color={colors.mutedForeground}
                      icon={appIcons.attachment}
                      size={11}
                    />
                    <View style={styles.attachmentCopy}>
                      <Text numberOfLines={1} style={styles.attachmentName}>
                        {attachmentName}
                      </Text>
                      {attachmentSize ? (
                        <Text style={styles.attachmentMeta}>
                          {attachmentSize}
                        </Text>
                      ) : null}
                    </View>
                    <Pressable
                      accessibilityLabel={t('chat.removeAttachment', {
                        name: attachmentName,
                      })}
                      accessibilityRole="button"
                      onPress={() => onRemoveAttachment(attachment)}
                      style={({ pressed }) => [
                        styles.removeAttachmentButton,
                        pressed && styles.promptRowPressed,
                      ]}
                    >
                      <Text style={styles.removeAttachmentText}>×</Text>
                    </Pressable>
                  </View>
                );
              })}
            </View>
          </ScrollView>
        ) : null}

        {attachmentError ? (
          <Text style={styles.attachmentError}>{attachmentError}</Text>
        ) : null}

        {queuedRequests.length > 0 ? (
          <View style={styles.queuePanel}>
            <View style={styles.queueHeader}>
              <Text style={styles.queueTitle}>{t('chat.queueTitle')}</Text>
              <Text style={styles.queueCount}>
                {t('chat.queueCount', {
                  count: queuedRequests.length.toLocaleString(locale),
                })}
              </Text>
            </View>

            <ScrollView
              keyboardShouldPersistTaps="handled"
              nestedScrollEnabled
              showsVerticalScrollIndicator={false}
              style={styles.queueList}
            >
              {queuedRequests.map((request, index) => {
                const isEditing = editingQueuedRequestId === request.id;
                const queuedPrompt =
                  request.prompt || t('chat.analyzeAttachedFile');
                const attachmentSummary = createAttachmentSummary(
                  request.attachments,
                  defaultAttachmentName,
                );

                return (
                  <View key={request.id} style={styles.queueItem}>
                    <View style={styles.queueIndexBadge}>
                      <Text style={styles.queueIndexText}>{index + 1}</Text>
                    </View>

                    <View style={styles.queueItemBody}>
                      {isEditing ? (
                        <TextInput
                          multiline
                          onChangeText={onChangeEditingQueuedDraft}
                          placeholder={t('chat.queueEditPlaceholder')}
                          placeholderTextColor={colors.mutedForeground}
                          style={styles.queueEditInput}
                          value={editingQueuedDraft}
                        />
                      ) : (
                        <>
                          <Text numberOfLines={2} style={styles.queueText}>
                            {queuedPrompt}
                          </Text>
                          {attachmentSummary ? (
                            <Text numberOfLines={1} style={styles.queueMeta}>
                              {t('chat.attachmentPrefix', {
                                summary: attachmentSummary,
                              })}
                            </Text>
                          ) : null}
                        </>
                      )}
                    </View>

                    {isEditing ? (
                      <View style={styles.queueTextActions}>
                        <Pressable
                          accessibilityLabel={t('chat.queueSaveAction')}
                          accessibilityRole="button"
                          onPress={() => onSaveQueuedRequestEdit(request.id)}
                          style={({ pressed }) => [
                            styles.queueTextActionButton,
                            pressed && styles.promptRowPressed,
                          ]}
                        >
                          <Text style={styles.queueTextActionLabel}>
                            {t('chat.queueSave')}
                          </Text>
                        </Pressable>
                        <Pressable
                          accessibilityLabel={t('chat.queueEditCancel')}
                          accessibilityRole="button"
                          onPress={onCancelQueuedRequestEdit}
                          style={({ pressed }) => [
                            styles.queueTextActionButton,
                            pressed && styles.promptRowPressed,
                          ]}
                        >
                          <Text style={styles.queueTextActionLabelMuted}>
                            {t('chat.queueCancel')}
                          </Text>
                        </Pressable>
                      </View>
                    ) : (
                      <View style={styles.queueIconActions}>
                        <Pressable
                          accessibilityLabel={t('chat.queueEdit')}
                          accessibilityRole="button"
                          onPress={() => onEditQueuedRequest(request)}
                          style={({ pressed }) => [
                            styles.queueIconButton,
                            pressed && styles.promptRowPressed,
                          ]}
                        >
                          <AppIcon
                            color={colors.mutedForeground}
                            icon={appIcons.rename}
                            size={12}
                          />
                        </Pressable>
                        <Pressable
                          accessibilityLabel={t('chat.queueDelete')}
                          accessibilityRole="button"
                          onPress={() => onDeleteQueuedRequest(request.id)}
                          style={({ pressed }) => [
                            styles.queueIconButton,
                            pressed && styles.promptRowPressed,
                          ]}
                        >
                          <AppIcon
                            color={colors.destructive}
                            icon={appIcons.delete}
                            size={12}
                          />
                        </Pressable>
                      </View>
                    )}
                  </View>
                );
              })}
            </ScrollView>
          </View>
        ) : null}

        <View style={styles.inputRow}>
          <Pressable
            accessibilityLabel={t('chat.attachFile')}
            accessibilityRole="button"
            onPress={onAttachFile}
            style={({ pressed }) => [
              styles.iconTool,
              pressed && styles.promptRowPressed,
            ]}
          >
            <AppIcon color={colors.foreground} icon={appIcons.plus} size={18} />
          </Pressable>

          <TextInput
            multiline
            onChangeText={onChangeDraft}
            placeholder={t('chat.inputPlaceholder')}
            placeholderTextColor={colors.mutedForeground}
            style={styles.input}
            value={draft}
          />

          <Pressable
            accessibilityLabel={
              shouldShowStopButton
                ? t('chat.stopResponse')
                : isGenerationBusy
                ? t('chat.addToQueue')
                : t('chat.sendMessage')
            }
            accessibilityRole="button"
            disabled={shouldShowStopButton ? isStoppingGeneration : !canSubmit}
            onPress={shouldShowStopButton ? onStopGeneration : onSend}
            style={({ pressed }) => [
              styles.sendButton,
              pressed && styles.sendButtonPressed,
              shouldShowStopButton &&
                isStoppingGeneration &&
                styles.stopButtonDisabled,
              !shouldShowStopButton && !canSubmit && styles.sendButtonDisabled,
            ]}
          >
            <AppIcon
              color={
                !shouldShowStopButton && !canSubmit
                  ? colors.mutedForeground
                  : colors.primaryForeground
              }
              icon={shouldShowStopButton ? appIcons.stop : appIcons.send}
              size={shouldShowStopButton ? 14 : 15}
            />
          </Pressable>
        </View>
      </View>
    </View>
  );
}
