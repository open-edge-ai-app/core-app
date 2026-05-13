import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Keyboard,
  KeyboardAvoidingView,
  KeyboardEvent,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';

import AppIcon from '../components/AppIcon';
import ChatBubble, { ChatRole } from '../components/ChatBubble';
import LoadingDots from '../components/LoadingDots';
import AIEngine, {
  AIChatMessage,
  MultimodalAttachment,
} from '../native/AIEngine';
import { pickAttachment } from '../native/FilePicker';
import {
  ScaledText as Text,
  ScaledTextInput as TextInput,
} from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors, typography } from '../theme/tokens';

export type ChatMessage = {
  createdAt: Date;
  id: string;
  modelName?: string;
  role: ChatRole;
  text: string;
};

type QuickPrompt = {
  description: string;
  prompt: string;
  title: string;
};

type ChatMode = {
  id: 'chat' | 'search' | 'reason' | 'files';
  label: string;
};

type MessagesChangeResult = {
  persisted?: Promise<void>;
  sessionId: string | null;
};

type MessagesChangeOptions = {
  persist?: boolean;
};

type SessionTitleChangeOptions = {
  animated?: boolean;
  sessionId?: string | null;
};

type ChatScreenProps = {
  commonSystemPrompt?: string;
  messages: ChatMessage[];
  onMessagesChange: (
    nextMessages: ChatMessage[],
    sessionTitleCandidate?: string,
    options?: MessagesChangeOptions,
  ) => MessagesChangeResult;
  onSessionTitleChange?: (
    title: string,
    options?: SessionTitleChangeOptions,
  ) => void;
  selectedModelLabel?: string;
  sessionId?: string | null;
};

export const createInitialChatMessages = (): ChatMessage[] => [
  {
    createdAt: new Date(),
    id: 'welcome',
    role: 'assistant',
    text: '무엇을 만들고 싶은지 남겨주세요. 목표, 대상, 제약을 함께 주면 실행 순서까지 정리합니다.',
  },
];

const quickPrompts: QuickPrompt[] = [
  {
    description: '핵심 흐름과 리스크를 짧게 정리',
    prompt: '오늘 삼성전자 주가 흐름을 요약해줘',
    title: '오늘 삼성전자 주가 흐름을 요약해줘',
  },
  {
    description: '검색 기반으로 최신 흐름 확인',
    prompt: '친환경 소재의 최신 연구 동향을 검색해줘',
    title: '친환경 소재의 최신 연구 동향 검색',
  },
  {
    description: '긴 문서를 읽기 쉬운 요약으로 변환',
    prompt: '업로드한 PDF 내용을 정리해줘',
    title: '업로드한 PDF 내용을 정리해줘',
  },
];

const chatModes: ChatMode[] = [
  { id: 'chat', label: '채팅' },
  { id: 'search', label: '검색' },
  { id: 'reason', label: '분석' },
  { id: 'files', label: '파일' },
];

const INITIAL_SCROLL_BOTTOM_INSET = 170;
const THREAD_SCROLL_BOTTOM_INSET = 210;
const SCROLL_TO_BOTTOM_THRESHOLD = 140;
const SCROLL_TO_BOTTOM_BUTTON_OFFSET = 198;
const PENDING_CHAT_TITLE = '제목 생성 중';

const formatTime = (date: Date) =>
  new Intl.DateTimeFormat('ko-KR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);

const formatLocalDate = (date: Date) => {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');

  return `${year}-${month}-${day}`;
};

const createRuntimeContextMessage = (date = new Date()): AIChatMessage => {
  const localDate = formatLocalDate(date);
  const readableDate = new Intl.DateTimeFormat('ko-KR', {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
    year: 'numeric',
  }).format(date);
  const readableTime = new Intl.DateTimeFormat('ko-KR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
  const timeZone =
    Intl.DateTimeFormat().resolvedOptions().timeZone || 'local time';

  return {
    content: [
      '현재 날짜/시간 컨텍스트입니다.',
      `오늘은 ${readableDate}입니다.`,
      `로컬 날짜: ${localDate}`,
      `현재 로컬 시각: ${readableTime}`,
      `시간대: ${timeZone}`,
      '사용자가 "오늘", "내일", "어제", "이번 주"처럼 상대 날짜를 말하면 이 값을 기준으로 해석하세요.',
    ].join('\n'),
    role: 'system',
  };
};

const createMessage = (
  role: ChatRole,
  text: string,
  modelName?: string,
): ChatMessage => ({
  createdAt: new Date(),
  id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  modelName,
  role,
  text,
});

const getAttachmentKey = (attachment: MultimodalAttachment) =>
  attachment.id ?? attachment.uri;

const getAttachmentName = (attachment: MultimodalAttachment) =>
  attachment.name?.trim() || '첨부 파일';

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

const createAttachmentSummary = (attachments: MultimodalAttachment[]) =>
  attachments.map(getAttachmentName).join(', ');

const createUserMessageText = (
  prompt: string,
  attachments: MultimodalAttachment[],
) => {
  const attachmentSummary = createAttachmentSummary(attachments);

  if (!attachmentSummary) {
    return prompt;
  }

  return [prompt, `첨부 파일: ${attachmentSummary}`]
    .filter(Boolean)
    .join('\n\n');
};

const createSystemHistory = (commonSystemPrompt: string): AIChatMessage[] => [
  ...(commonSystemPrompt.trim()
    ? [
        {
          content: commonSystemPrompt.trim(),
          role: 'system' as const,
        },
      ]
    : []),
];

export const createConversationHistory = (
  messages: ChatMessage[],
): AIChatMessage[] =>
  messages
    .filter(message => message.id !== 'welcome' && message.role !== 'system')
    .map(message => ({
      content: message.text.trim(),
      role: message.role,
    }))
    .filter(message => message.content.length > 0);

function ChatScreen({
  commonSystemPrompt = '',
  messages,
  onMessagesChange,
  onSessionTitleChange,
  selectedModelLabel = 'Gemma 4',
  sessionId = null,
}: ChatScreenProps) {
  const scrollViewRef = useRef<ScrollView>(null);
  const isNearThreadEndRef = useRef(true);
  const [draft, setDraft] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [isAwaitingFirstChunk, setIsAwaitingFirstChunk] = useState(false);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);
  const [selectedAttachments, setSelectedAttachments] = useState<
    MultimodalAttachment[]
  >([]);
  const [attachmentError, setAttachmentError] = useState<string | null>(null);
  const [selectedMode, setSelectedMode] = useState<ChatMode['id']>('chat');

  const hasUserMessages = useMemo(
    () => messages.some(message => message.role === 'user'),
    [messages],
  );
  const latestMessageText = messages[messages.length - 1]?.text ?? '';
  const canSend =
    (draft.trim().length > 0 || selectedAttachments.length > 0) &&
    !isGenerating;

  const systemHistory = useMemo<AIChatMessage[]>(
    () => createSystemHistory(commonSystemPrompt),
    [commonSystemPrompt],
  );

  const composerOffsetStyle = useMemo(
    () => ({
      marginBottom: Platform.OS === 'android' ? keyboardHeight : 0,
    }),
    [keyboardHeight],
  );
  const scrollToBottomButtonOffsetStyle = useMemo(
    () => ({
      bottom:
        SCROLL_TO_BOTTOM_BUTTON_OFFSET +
        (Platform.OS === 'android' ? keyboardHeight : 0),
    }),
    [keyboardHeight],
  );

  const scrollToThreadEnd = useCallback((animated = true) => {
    isNearThreadEndRef.current = true;
    setShowScrollToBottom(false);
    scrollViewRef.current?.scrollToEnd({ animated });
  }, []);

  const handleThreadScroll = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      if (!hasUserMessages) {
        return;
      }

      const { contentOffset, contentSize, layoutMeasurement } =
        event.nativeEvent;
      const distanceFromBottom =
        contentSize.height - layoutMeasurement.height - contentOffset.y;
      const shouldShow =
        distanceFromBottom > SCROLL_TO_BOTTOM_THRESHOLD &&
        contentSize.height > layoutMeasurement.height;

      isNearThreadEndRef.current = !shouldShow;
      setShowScrollToBottom(current =>
        current === shouldShow ? current : shouldShow,
      );
    },
    [hasUserMessages],
  );

  useEffect(() => {
    if (Platform.OS !== 'android') {
      return;
    }

    const handleKeyboardShow = (event: KeyboardEvent) => {
      setKeyboardHeight(event.endCoordinates.height);
    };
    const showSubscription = Keyboard.addListener(
      'keyboardDidShow',
      handleKeyboardShow,
    );
    const hideSubscription = Keyboard.addListener('keyboardDidHide', () => {
      setKeyboardHeight(0);
    });

    return () => {
      showSubscription.remove();
      hideSubscription.remove();
    };
  }, []);

  useEffect(() => {
    if (!hasUserMessages) {
      return;
    }

    if (!isNearThreadEndRef.current) {
      return;
    }

    const timeoutId = setTimeout(() => {
      scrollToThreadEnd(true);
    }, 80);

    return () => clearTimeout(timeoutId);
  }, [
    hasUserMessages,
    isGenerating,
    keyboardHeight,
    latestMessageText,
    messages.length,
    scrollToThreadEnd,
  ]);

  useEffect(() => {
    if (hasUserMessages) {
      return;
    }

    isNearThreadEndRef.current = true;
    setShowScrollToBottom(false);
    scrollViewRef.current?.scrollTo({ animated: false, y: 0 });
  }, [hasUserMessages]);

  const handleSend = useCallback(async () => {
    const prompt = draft.trim();
    const attachmentsForPrompt = selectedAttachments;

    if ((!prompt && attachmentsForPrompt.length === 0) || isGenerating) {
      return;
    }

    const promptForModel = prompt || '첨부한 파일을 분석해줘';
    const userMessageText = createUserMessageText(prompt, attachmentsForPrompt);
    const responseModelName = selectedModelLabel;
    const userMessage = createMessage('user', userMessageText);
    const assistantMessage = createMessage('assistant', '', responseModelName);
    const messagesWithUserPrompt = [...messages, userMessage];
    const nextSessionTitle = !hasUserMessages ? PENDING_CHAT_TITLE : undefined;
    const shouldGenerateSessionTitle = !hasUserMessages;

    if (prompt === '/compact') {
      setDraft('');
      setIsGenerating(true);
      const pendingAssistant = createMessage(
        'assistant',
        'Compacting context...',
        responseModelName,
      );
      onMessagesChange([...messagesWithUserPrompt, pendingAssistant]);

      try {
        if (!sessionId) {
          throw new Error(
            'A saved chat session is required before compacting.',
          );
        }

        const result = await AIEngine.compactChatSession(sessionId, 'manual');
        onMessagesChange([
          ...messagesWithUserPrompt,
          {
            ...pendingAssistant,
            text: result.compacted
              ? `Context compacted. Token estimate ${result.beforeTokenEstimate} -> ${result.afterTokenEstimate}.`
              : result.message,
          },
        ]);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : 'Context compact failed.';
        onMessagesChange([
          ...messagesWithUserPrompt,
          {
            ...pendingAssistant,
            text: `Context compact failed: ${message}`,
          },
        ]);
      } finally {
        setIsGenerating(false);
      }
      return;
    }

    const messagesChange = onMessagesChange(
      [...messagesWithUserPrompt, assistantMessage],
      nextSessionTitle,
    );
    const resolvedSessionId = messagesChange.sessionId ?? sessionId;
    if (!hasUserMessages) {
      onSessionTitleChange?.(PENDING_CHAT_TITLE, {
        sessionId: resolvedSessionId,
      });
    }
    setDraft('');
    setSelectedAttachments([]);
    setAttachmentError(null);
    setIsGenerating(true);
    setIsAwaitingFirstChunk(true);

    let streamedResponse = '';
    try {
      await messagesChange.persisted?.catch(() => undefined);

      if (resolvedSessionId) {
        await AIEngine.compactChatSession(resolvedSessionId, 'auto').catch(
          () => undefined,
        );
      }

      const requestHistory = [
        ...systemHistory,
        createRuntimeContextMessage(),
        ...createConversationHistory(messages),
      ];

      const updateAssistantMessage = (text: string) => {
        onMessagesChange(
          [
            ...messagesWithUserPrompt,
            {
              ...assistantMessage,
              text,
            },
          ],
          nextSessionTitle,
          { persist: false },
        );
      };

      const response = await AIEngine.generateResponseStream(
        promptForModel,
        requestHistory,
        {
          onChunk: chunk => {
            if (!chunk) {
              return;
            }

            streamedResponse += chunk;
            setIsAwaitingFirstChunk(false);
            updateAssistantMessage(streamedResponse);
          },
        },
        {
          attachments: attachmentsForPrompt,
          chatSessionId: resolvedSessionId ?? undefined,
        },
      );

      if (response !== streamedResponse) {
        updateAssistantMessage(response);
      }

      const finalMessages = [
        ...messagesWithUserPrompt,
        {
          ...assistantMessage,
          text: response,
        },
      ];
      await onMessagesChange(finalMessages, nextSessionTitle).persisted?.catch(
        () => undefined,
      );

      if (shouldGenerateSessionTitle) {
        AIEngine.generateChatTitle(userMessageText || promptForModel, response)
          .then(title => {
            const normalizedTitle = title.trim();
            if (normalizedTitle) {
              onSessionTitleChange?.(normalizedTitle, {
                animated: true,
                sessionId: resolvedSessionId,
              });
            }
          })
          .catch(() => undefined);
      }
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : 'AI 응답 처리 중 알 수 없는 문제가 발생했습니다.';

      onMessagesChange(
        [
          ...messagesWithUserPrompt,
          ...(streamedResponse
            ? [{ ...assistantMessage, text: streamedResponse }]
            : []),
          createMessage('system', `응답 실패: ${message}`),
        ],
        nextSessionTitle,
      );
    } finally {
      setIsGenerating(false);
      setIsAwaitingFirstChunk(false);
    }
  }, [
    draft,
    hasUserMessages,
    isGenerating,
    messages,
    onMessagesChange,
    onSessionTitleChange,
    selectedModelLabel,
    selectedAttachments,
    sessionId,
    systemHistory,
  ]);

  const handleRetryResponse = useCallback(
    async (assistantMessageId: string) => {
      if (isGenerating) {
        return;
      }

      const assistantIndex = messages.findIndex(
        message => message.id === assistantMessageId,
      );
      if (assistantIndex < 0) {
        return;
      }

      let userIndex = -1;
      for (let index = assistantIndex - 1; index >= 0; index -= 1) {
        if (messages[index].role === 'user') {
          userIndex = index;
          break;
        }
      }

      if (userIndex < 0) {
        return;
      }

      const sourceUserMessage = messages[userIndex];
      const promptForModel = sourceUserMessage.text.trim();
      if (!promptForModel) {
        return;
      }

      const retriedAssistantMessage: ChatMessage = {
        ...messages[assistantIndex],
        createdAt: new Date(),
        modelName: selectedModelLabel,
        text: '다시 생성 중...',
      };
      const messagesWithPendingRetry = messages.map((message, index) =>
        index === assistantIndex ? retriedAssistantMessage : message,
      );
      const updateRetriedAssistantMessage = (text: string) => {
        onMessagesChange(
          messagesWithPendingRetry.map(message =>
            message.id === retriedAssistantMessage.id
              ? { ...retriedAssistantMessage, text }
              : message,
          ),
          undefined,
          { persist: false },
        );
      };

      const messagesChange = onMessagesChange(messagesWithPendingRetry);
      setAttachmentError(null);
      setIsGenerating(true);
      setIsAwaitingFirstChunk(false);

      let streamedResponse = '';
      try {
        await messagesChange.persisted?.catch(() => undefined);

        if (sessionId) {
          await AIEngine.compactChatSession(sessionId, 'auto').catch(
            () => undefined,
          );
        }

        const requestHistory = [
          ...createSystemHistory(commonSystemPrompt),
          createRuntimeContextMessage(),
          ...createConversationHistory(messages.slice(0, userIndex + 1)),
        ];

        const response = await AIEngine.generateResponseStream(
          promptForModel,
          requestHistory,
          {
            onChunk: chunk => {
              if (!chunk) {
                return;
              }

              streamedResponse += chunk;
              updateRetriedAssistantMessage(streamedResponse);
            },
          },
          {
            chatSessionId: sessionId ?? undefined,
          },
        );

        const finalResponse = response || streamedResponse;
        updateRetriedAssistantMessage(finalResponse);
        await onMessagesChange(
          messagesWithPendingRetry.map(message =>
            message.id === retriedAssistantMessage.id
              ? { ...retriedAssistantMessage, text: finalResponse }
              : message,
          ),
        ).persisted?.catch(() => undefined);
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : 'AI 응답 처리 중 알 수 없는 문제가 발생했습니다.';

        updateRetriedAssistantMessage(
          streamedResponse || `응답 실패: ${message}`,
        );
      } finally {
        setIsGenerating(false);
        setIsAwaitingFirstChunk(false);
      }
    },
    [
      commonSystemPrompt,
      isGenerating,
      messages,
      onMessagesChange,
      selectedModelLabel,
      sessionId,
    ],
  );

  const handleAttachFile = useCallback(async () => {
    if (isGenerating) {
      return;
    }

    setAttachmentError(null);

    try {
      const attachment = await pickAttachment();
      if (!attachment) {
        return;
      }

      setSelectedAttachments(currentAttachments => [
        ...currentAttachments,
        {
          ...attachment,
          id:
            attachment.id ??
            `${Date.now()}-${Math.random().toString(36).slice(2)}`,
          name: getAttachmentName(attachment),
        },
      ]);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : '파일을 선택하지 못했습니다.';
      setAttachmentError(`파일 첨부 실패: ${message}`);
    }
  }, [isGenerating]);

  const handleRemoveAttachment = useCallback(
    (attachment: MultimodalAttachment) => {
      const attachmentKey = getAttachmentKey(attachment);
      setSelectedAttachments(currentAttachments =>
        currentAttachments.filter(
          currentAttachment =>
            getAttachmentKey(currentAttachment) !== attachmentKey,
        ),
      );
    },
    [],
  );

  const handlePromptPress = useCallback((prompt: string) => {
    setDraft(prompt);
  }, []);

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={styles.container}
    >
      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          !hasUserMessages && styles.scrollContentInitial,
          hasUserMessages && styles.scrollContentThread,
        ]}
        keyboardShouldPersistTaps="handled"
        onScroll={handleThreadScroll}
        ref={scrollViewRef}
        scrollEventThrottle={16}
        scrollEnabled={hasUserMessages}
        showsVerticalScrollIndicator={hasUserMessages}
      >
        <View style={[styles.hero, hasUserMessages && styles.heroCompact]}>
          <Text style={styles.heroTitle}>
            {hasUserMessages ? '대화' : '무엇이든 물어보세요'}
          </Text>
          {!hasUserMessages ? (
            <Text style={styles.heroBody}>
              로컬 AI가 빠르고 안전하게 답변해드려요.
            </Text>
          ) : null}
        </View>

        {!hasUserMessages ? (
          <View style={styles.quickSection}>
            <View style={styles.modeRail}>
              {chatModes.map(mode => {
                const isSelected = selectedMode === mode.id;

                return (
                  <Pressable
                    accessibilityRole="button"
                    accessibilityState={{ selected: isSelected }}
                    key={mode.id}
                    onPress={() => setSelectedMode(mode.id)}
                    style={({ pressed }) => [
                      styles.modeItem,
                      isSelected && styles.modeItemSelected,
                      pressed && styles.promptRowPressed,
                    ]}
                  >
                    <Text
                      style={[
                        styles.modeText,
                        isSelected && styles.modeTextSelected,
                      ]}
                    >
                      {mode.label}
                    </Text>
                    {isSelected ? <View style={styles.modeIndicator} /> : null}
                  </Pressable>
                );
              })}
            </View>

            <View style={styles.promptList}>
              {quickPrompts.map(prompt => (
                <Pressable
                  accessibilityRole="button"
                  key={prompt.title}
                  onPress={() => handlePromptPress(prompt.prompt)}
                  style={({ pressed }) => [
                    styles.promptRow,
                    pressed && styles.promptRowPressed,
                  ]}
                >
                  <View style={styles.promptCopy}>
                    <Text style={styles.promptTitle}>{prompt.title}</Text>
                  </View>
                  <AppIcon
                    color={colors.primary}
                    icon={appIcons.openPrompt}
                    size={14}
                  />
                </Pressable>
              ))}
            </View>
          </View>
        ) : null}

        {hasUserMessages ? (
          <View style={styles.threadSection}>
            <View style={styles.cardHeader}>
              <Text style={styles.cardTitle}>대화</Text>
              <Text style={styles.sectionMeta}>{messages.length}개 메시지</Text>
            </View>
            <View style={styles.cardSeparator} />

            <View style={styles.threadList}>
              {messages.map((message, index) => {
                const isPendingAssistant =
                  isGenerating &&
                  isAwaitingFirstChunk &&
                  message.role === 'assistant' &&
                  !message.text.trim();

                if (isPendingAssistant) {
                  return null;
                }

                const canRetryAssistantMessage =
                  message.role === 'assistant' &&
                  messages
                    .slice(0, index)
                    .some(previousMessage => previousMessage.role === 'user');

                return (
                  <ChatBubble
                    assistantName={message.modelName ?? selectedModelLabel}
                    isRetryDisabled={isGenerating}
                    key={message.id}
                    onRetry={
                      canRetryAssistantMessage
                        ? () => handleRetryResponse(message.id)
                        : undefined
                    }
                    role={message.role}
                    text={message.text}
                    timestamp={formatTime(message.createdAt)}
                  />
                );
              })}

              {isGenerating && isAwaitingFirstChunk ? (
                <View style={styles.loadingRow}>
                  <LoadingDots label={`${selectedModelLabel} 응답 준비 중`} />
                </View>
              ) : null}
            </View>
          </View>
        ) : null}
      </ScrollView>

      {showScrollToBottom ? (
        <Pressable
          accessibilityLabel="최신 메시지로 이동"
          accessibilityRole="button"
          onPress={() => scrollToThreadEnd(true)}
          style={({ pressed }) => [
            styles.scrollToBottomButton,
            scrollToBottomButtonOffsetStyle,
            pressed && styles.scrollToBottomButtonPressed,
          ]}
        >
          <AppIcon
            color={colors.foreground}
            icon={appIcons.chevronDown}
            size={14}
          />
        </Pressable>
      ) : null}

      <View style={[styles.composer, composerOffsetStyle]}>
        <View style={styles.inputPanel}>
          {selectedAttachments.length > 0 ? (
            <View style={styles.attachmentList}>
              {selectedAttachments.map(attachment => {
                const attachmentName = getAttachmentName(attachment);
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
                      size={13}
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
                      accessibilityLabel={`${attachmentName} 제거`}
                      accessibilityRole="button"
                      onPress={() => handleRemoveAttachment(attachment)}
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
          ) : null}

          <TextInput
            multiline
            onChangeText={setDraft}
            placeholder="Ask, search, or make anything..."
            placeholderTextColor={colors.mutedForeground}
            style={styles.input}
            value={draft}
          />

          {attachmentError ? (
            <Text style={styles.attachmentError}>{attachmentError}</Text>
          ) : null}

          <View style={styles.inputFooter}>
            <View style={styles.inputTools}>
              <Pressable
                accessibilityLabel="파일 첨부"
                accessibilityRole="button"
                disabled={isGenerating}
                onPress={handleAttachFile}
                style={({ pressed }) => [
                  styles.iconTool,
                  pressed && styles.promptRowPressed,
                  isGenerating && styles.disabledTool,
                ]}
              >
                <AppIcon
                  color={colors.mutedForeground}
                  icon={appIcons.attachment}
                  size={19}
                />
              </Pressable>
            </View>

            <Pressable
              accessibilityLabel="메시지 보내기"
              accessibilityRole="button"
              disabled={!canSend}
              onPress={handleSend}
              style={({ pressed }) => [
                styles.sendButton,
                pressed && styles.sendButtonPressed,
                !canSend && styles.sendButtonDisabled,
              ]}
            >
              <AppIcon color={colors.card} icon={appIcons.send} size={20} />
            </Pressable>
          </View>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    overflow: 'hidden',
    position: 'relative',
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: 24,
  },
  scrollContentInitial: {
    paddingBottom: INITIAL_SCROLL_BOTTOM_INSET,
    paddingTop: 24,
  },
  scrollContentThread: {
    paddingBottom: THREAD_SCROLL_BOTTOM_INSET,
    paddingTop: 24,
  },
  hero: {
    paddingBottom: 28,
  },
  heroCompact: {
    paddingBottom: 20,
  },
  heroTitle: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 30,
    fontWeight: '800',
    letterSpacing: 0,
    lineHeight: 36,
  },
  heroBody: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 21,
    marginTop: 10,
    maxWidth: 320,
  },
  quickSection: {
    marginBottom: 26,
  },
  modeRail: {
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 24,
  },
  modeItem: {
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 8,
    position: 'relative',
  },
  modeItemSelected: {},
  modeText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 14,
    fontWeight: '600',
  },
  modeTextSelected: {
    color: colors.primary,
  },
  modeIndicator: {
    backgroundColor: colors.primary,
    borderRadius: 2,
    bottom: -1,
    height: 3,
    left: 0,
    position: 'absolute',
    right: 0,
  },
  threadSection: {
    marginBottom: 22,
  },
  cardHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  cardTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 17,
  },
  sectionMeta: {
    ...typography.caption,
    color: colors.mutedForeground,
  },
  cardSeparator: {
    backgroundColor: colors.border,
    height: StyleSheet.hairlineWidth,
    marginTop: 12,
  },
  promptList: {
    marginTop: 0,
  },
  promptRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderRadius: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 72,
    paddingHorizontal: 0,
    paddingVertical: 14,
  },
  promptRowPressed: {
    opacity: 0.58,
  },
  promptCopy: {
    flex: 1,
    paddingRight: 16,
  },
  promptTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 16,
    fontWeight: '500',
    lineHeight: 21,
  },
  threadList: {
    paddingTop: 18,
  },
  loadingRow: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    flexDirection: 'row',
    marginBottom: 12,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  scrollToBottomButton: {
    alignItems: 'center',
    alignSelf: 'center',
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
    height: 40,
    justifyContent: 'center',
    position: 'absolute',
    width: 40,
    zIndex: 30,
  },
  scrollToBottomButtonPressed: {
    opacity: 0.68,
  },
  composer: {
    backgroundColor: 'transparent',
    bottom: 0,
    left: 0,
    paddingBottom: 6,
    paddingHorizontal: 12,
    paddingTop: 14,
    position: 'absolute',
    right: 0,
  },
  inputPanel: {
    backgroundColor: colors.card,
    borderColor: 'rgba(21,25,34,0.08)',
    borderRadius: 18,
    borderWidth: 1,
    minHeight: 132,
    paddingBottom: 12,
    paddingHorizontal: 16,
    paddingTop: 14,
    shadowColor: '#000000',
    shadowOffset: { height: 18, width: 0 },
    shadowOpacity: 0.12,
    shadowRadius: 28,
  },
  input: {
    ...typography.body,
    backgroundColor: 'transparent',
    color: colors.foreground,
    fontSize: 16,
    fontWeight: '400',
    lineHeight: 22,
    maxHeight: 82,
    minHeight: 54,
    paddingHorizontal: 4,
    paddingTop: 18,
    textAlignVertical: 'top',
  },
  attachmentList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    paddingBottom: 10,
  },
  attachmentChip: {
    alignItems: 'center',
    backgroundColor: colors.muted,
    borderColor: colors.border,
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 7,
    maxWidth: '100%',
    minHeight: 36,
    paddingLeft: 10,
    paddingRight: 5,
  },
  attachmentCopy: {
    flexShrink: 1,
    minWidth: 0,
  },
  attachmentName: {
    ...typography.caption,
    color: colors.foreground,
    fontSize: 12,
    maxWidth: 190,
  },
  attachmentMeta: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontSize: 10,
    marginTop: 2,
  },
  removeAttachmentButton: {
    alignItems: 'center',
    height: 28,
    justifyContent: 'center',
    width: 28,
  },
  removeAttachmentText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 17,
    lineHeight: 18,
  },
  attachmentError: {
    ...typography.caption,
    color: colors.destructive,
    paddingBottom: 10,
  },
  inputFooter: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  inputTools: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: 14,
    paddingRight: 10,
  },
  iconTool: {
    alignItems: 'center',
    height: 36,
    justifyContent: 'center',
    width: 34,
  },
  disabledTool: {
    opacity: 0.38,
  },
  sendButton: {
    alignItems: 'center',
    backgroundColor: colors.foreground,
    borderRadius: 22,
    height: 44,
    justifyContent: 'center',
    width: 44,
  },
  sendButtonPressed: {
    opacity: 0.76,
  },
  sendButtonDisabled: {
    backgroundColor: colors.foreground,
    opacity: 1,
  },
});

export default ChatScreen;
