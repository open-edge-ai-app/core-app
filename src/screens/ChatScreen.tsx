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
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import AppIcon from '../components/AppIcon';
import ChatBubble from '../components/ChatBubble';
import LoadingDots from '../components/LoadingDots';
import { useI18n } from '../i18n';
import AIEngine, {
  AIChatMessage,
  MultimodalAttachment,
} from '../native/AIEngine';
import { pickAttachment } from '../native/FilePicker';
import {
  applyTodoToolCalls,
  buildTodoToolPromptSection,
  buildTodoToolStateSection,
  shouldUseTodoTool,
} from '../native/todoTools';
import { ensureTodoStoreLoaded } from '../state/todoStore';
import {
  hideGenerationProgress,
  showGenerationProgress,
} from '../native/progressNotification';
import { buildAttachmentOcrContext } from '../native/knowledge';
import { ScaledText as Text } from '../theme/display';
import { appIcons } from '../theme/icons';
import { colors } from '../theme/tokens';

import ChatComposer from './chat/ChatComposer';
import {
  INITIAL_SCROLL_BOTTOM_INSET,
  PENDING_CHAT_TITLE,
  SCROLL_TO_BOTTOM_BUTTON_OFFSET,
  SCROLL_TO_BOTTOM_THRESHOLD,
  THREAD_SCROLL_BOTTOM_INSET,
  chatModeLabelKeys,
  chatModes,
  createConversationHistory,
  createMessage,
  createQueuedChatRequest,
  createRuntimeContextMessage,
  createSystemHistory,
  formatTime,
  getAttachmentKey,
  getAttachmentName,
  isInitialWelcomeMessage,
  quickPrompts,
  shouldIncludeRuntimeContext,
  type ChatMode,
  type ChatMessage,
  type ChatScreenProps,
  type QueuedChatRequest,
} from './chat/chatTypes';
import { styles } from './chat/chatStyles';
export {
  createConversationHistory,
  createInitialChatMessages,
  shouldIncludeRuntimeContext,
} from './chat/chatTypes';
export type { ChatMessage } from './chat/chatTypes';
function ChatScreen({
  commonSystemPrompt = '',
  messages,
  onMessagesChange,
  onSessionTitleChange,
  selectedModelId = 'gemma-4',
  selectedModelLabel = 'Gemma 4',
  sessionId = null,
}: ChatScreenProps) {
  const { locale, t } = useI18n();
  const insets = useSafeAreaInsets();
  const scrollViewRef = useRef<ScrollView>(null);
  const isNearThreadEndRef = useRef(true);
  const generationTokenRef = useRef(0);
  const stopRequestedRef = useRef(false);
  const [draft, setDraft] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [isStoppingGeneration, setIsStoppingGeneration] = useState(false);
  const [isAwaitingFirstChunk, setIsAwaitingFirstChunk] = useState(false);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);
  const [selectedAttachments, setSelectedAttachments] = useState<
    MultimodalAttachment[]
  >([]);
  const [attachmentError, setAttachmentError] = useState<string | null>(null);
  const [selectedMode, setSelectedMode] = useState<ChatMode['id']>('chat');
  const [queuedRequests, setQueuedRequests] = useState<QueuedChatRequest[]>(
    [],
  );
  const [editingQueuedRequestId, setEditingQueuedRequestId] = useState<
    string | null
  >(null);
  const [editingQueuedDraft, setEditingQueuedDraft] = useState('');
  const defaultAttachmentName = t('chat.defaultAttachment');

  const conversationMessages = useMemo(
    () => messages.filter(message => !isInitialWelcomeMessage(message)),
    [messages],
  );
  const systemHistory = useMemo<AIChatMessage[]>(
    () => createSystemHistory(commonSystemPrompt),
    [commonSystemPrompt],
  );
  const hasUserMessages = useMemo(
    () => conversationMessages.some(message => message.role === 'user'),
    [conversationMessages],
  );
  const latestMessageText =
    conversationMessages[conversationMessages.length - 1]?.text ?? '';
  const isGenerationBusy = isGenerating || isStoppingGeneration;
  const canSubmit = draft.trim().length > 0 || selectedAttachments.length > 0;
  const shouldShowStopButton = isGenerationBusy && !canSubmit;

  const bottomSafeAreaInset = Platform.OS === 'ios' ? insets.bottom : 0;
  const composerBottomOffset =
    keyboardHeight > 0 ? keyboardHeight : bottomSafeAreaInset;
  const composerOffsetStyle = useMemo(
    () => ({
      bottom: composerBottomOffset,
      paddingBottom: keyboardHeight > 0 ? 8 : 6,
    }),
    [composerBottomOffset, keyboardHeight],
  );
  const scrollToBottomButtonOffsetStyle = useMemo(
    () => ({
      bottom:
        SCROLL_TO_BOTTOM_BUTTON_OFFSET +
        composerBottomOffset,
    }),
    [composerBottomOffset],
  );
  const scrollContentBottomInsetStyle = useMemo(
    () => ({
      paddingBottom:
        (hasUserMessages
          ? THREAD_SCROLL_BOTTOM_INSET
          : INITIAL_SCROLL_BOTTOM_INSET) + composerBottomOffset,
    }),
    [composerBottomOffset, hasUserMessages],
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
    const handleKeyboardShow = (event: KeyboardEvent) => {
      setKeyboardHeight(event.endCoordinates.height);
    };
    const handleKeyboardHide = () => setKeyboardHeight(0);
    const showSubscription =
      Platform.OS === 'ios'
        ? Keyboard.addListener('keyboardWillChangeFrame', handleKeyboardShow)
        : Keyboard.addListener('keyboardDidShow', handleKeyboardShow);
    const hideSubscription =
      Platform.OS === 'ios'
        ? Keyboard.addListener('keyboardWillHide', handleKeyboardHide)
        : Keyboard.addListener('keyboardDidHide', handleKeyboardHide);

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
    conversationMessages.length,
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

  const handleStopGeneration = useCallback(() => {
    if (!isGenerating || isStoppingGeneration) {
      return;
    }

    stopRequestedRef.current = true;
    generationTokenRef.current += 1;
    setIsStoppingGeneration(true);
    setIsAwaitingFirstChunk(false);
    AIEngine.cancelActiveGeneration()
      .catch(() => undefined)
      .finally(() => {
        setIsGenerating(false);
        setIsStoppingGeneration(false);
      });
  }, [isGenerating, isStoppingGeneration]);

  const runChatRequest = useCallback(async (request: QueuedChatRequest) => {
    const rawPrompt = request.prompt.trim();
    const isSearchSlash = /^\/search(\s|$)/i.test(rawPrompt);
    const searchModeActive = selectedMode === 'search' || isSearchSlash;
    const prompt = isSearchSlash
      ? rawPrompt.replace(/^\/search\s*/i, '').trim()
      : rawPrompt;
    const attachmentsForPrompt = request.attachments;

    const promptForModel = prompt || t('chat.analyzeAttachedFile');
    const userMessageText = prompt || promptForModel;
    const responseModelName = selectedModelLabel;
    const userMessage = createMessage(
      'user',
      userMessageText,
      undefined,
      attachmentsForPrompt,
    );
    const assistantMessage = createMessage('assistant', '', responseModelName);
    const messagesWithUserPrompt = [...conversationMessages, userMessage];
    let baseMessages = messagesWithUserPrompt;
    const nextSessionTitle = !hasUserMessages ? PENDING_CHAT_TITLE : undefined;
    const shouldGenerateSessionTitle = !hasUserMessages;

    if (prompt === '/compact') {
      setIsGenerating(true);
      setIsStoppingGeneration(false);
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
        setIsStoppingGeneration(false);
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
    const generationToken = generationTokenRef.current + 1;
    generationTokenRef.current = generationToken;
    stopRequestedRef.current = false;
    setIsGenerating(true);
    setIsStoppingGeneration(false);
    setIsAwaitingFirstChunk(true);
    showGenerationProgress(
      t('chat.loadingResponse', { model: responseModelName }),
    ).catch(() => undefined);

    let streamedResponse = '';
    try {
      await messagesChange.persisted?.catch(() => undefined);

      if (resolvedSessionId) {
        const compaction = await AIEngine.compactChatSession(
          resolvedSessionId,
          'auto',
        ).catch(() => null);
        if (compaction?.compacted) {
          baseMessages = [
            ...messagesWithUserPrompt,
            createMessage('system', t('chat.contextCompacted')),
          ];
        }
      }

      const todoToolRelevant = shouldUseTodoTool(promptForModel);
      if (todoToolRelevant) {
        await ensureTodoStoreLoaded();
      }
      const todoStateSection = todoToolRelevant
        ? buildTodoToolStateSection()
        : null;
      const todoToolMessages: AIChatMessage[] = todoToolRelevant
        ? [
            { content: buildTodoToolPromptSection(), role: 'system' },
            ...(todoStateSection
              ? [{ content: todoStateSection, role: 'system' } as AIChatMessage]
              : []),
          ]
        : [];

      const ocrContext =
        attachmentsForPrompt.length > 0
          ? await buildAttachmentOcrContext(attachmentsForPrompt)
          : '';
      const ocrMessages: AIChatMessage[] = ocrContext
        ? [{ content: ocrContext, role: 'system' }]
        : [];

      const requestHistory = [
        ...systemHistory,
        ...todoToolMessages,
        ...ocrMessages,
        ...(shouldIncludeRuntimeContext(promptForModel)
          ? [createRuntimeContextMessage()]
          : []),
        ...createConversationHistory(messages),
      ];

      const updateAssistantMessage = (text: string) => {
        if (
          generationTokenRef.current !== generationToken ||
          stopRequestedRef.current
        ) {
          return;
        }

        onMessagesChange(
          [
            ...baseMessages,
            {
              ...assistantMessage,
              reasoning: assistantMessage.reasoning,
              text,
            },
          ],
          nextSessionTitle,
          { persist: false },
        );
      };

      const updateAssistantReasoning = (reasoning: string) => {
        if (
          generationTokenRef.current !== generationToken ||
          stopRequestedRef.current
        ) {
          return;
        }

        assistantMessage.reasoning = reasoning;
        onMessagesChange(
          [
            ...baseMessages,
            {
              ...assistantMessage,
              reasoning,
              text: streamedResponse,
            },
          ],
          nextSessionTitle,
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
            if (
              generationTokenRef.current !== generationToken ||
              stopRequestedRef.current
            ) {
              return;
            }

            streamedResponse += chunk;
            setIsAwaitingFirstChunk(false);
            updateAssistantMessage(streamedResponse);
          },
          onReasoning: updateAssistantReasoning,
        },
        {
          attachments: attachmentsForPrompt,
          chatSessionId: resolvedSessionId ?? undefined,
          forceWebSearch: searchModeActive,
          modelId: selectedModelId,
        },
      );

      if (
        generationTokenRef.current !== generationToken ||
        stopRequestedRef.current
      ) {
        return;
      }

      let finalText = response;
      const responseHasToolBlock =
        /```(?:openedge[_-]tool|openedge_tool_call|todo_tool)/.test(response);
      if (todoToolRelevant || responseHasToolBlock) {
        await ensureTodoStoreLoaded();
        const todoOutcome = applyTodoToolCalls(response);
        if (todoOutcome.results.length > 0) {
          const parts: string[] = [];
          if (todoOutcome.cleanedText) {
            parts.push(todoOutcome.cleanedText);
          }
          if (todoOutcome.listText) {
            parts.push(todoOutcome.listText);
          } else if (todoOutcome.didMutate) {
            parts.push(todoOutcome.results.join('\n'));
          }
          finalText = parts.join('\n\n').trim() || response;
        }
      }

      if (finalText !== streamedResponse) {
        updateAssistantMessage(finalText);
      }

      const finalMessages = [
        ...baseMessages,
        {
          ...assistantMessage,
          reasoning: assistantMessage.reasoning,
          text: finalText,
        },
      ];
      await onMessagesChange(finalMessages, nextSessionTitle).persisted?.catch(
        () => undefined,
      );

      if (shouldGenerateSessionTitle) {
        AIEngine.generateChatTitle(userMessageText || promptForModel, finalText)
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
      if (
        generationTokenRef.current !== generationToken ||
        stopRequestedRef.current
      ) {
        return;
      }

      const message =
        error instanceof Error
          ? error.message
          : t('chat.unknownResponseError');

      onMessagesChange(
        [
          ...baseMessages,
          ...(streamedResponse
            ? [{ ...assistantMessage, text: streamedResponse }]
            : []),
          createMessage('system', t('chat.responseFailed', { message })),
        ],
        nextSessionTitle,
      );
    } finally {
      hideGenerationProgress().catch(() => undefined);
      if (generationTokenRef.current === generationToken) {
        setIsGenerating(false);
        setIsStoppingGeneration(false);
        setIsAwaitingFirstChunk(false);
      }
    }
  }, [
    hasUserMessages,
    conversationMessages,
    messages,
    onMessagesChange,
    onSessionTitleChange,
    selectedMode,
    selectedModelLabel,
    selectedModelId,
    sessionId,
    systemHistory,
    t,
  ]);

  const handleSend = useCallback(() => {
    const prompt = draft.trim();
    const attachmentsForPrompt = [...selectedAttachments];

    if (!prompt && attachmentsForPrompt.length === 0) {
      return;
    }

    const request = createQueuedChatRequest(prompt, attachmentsForPrompt);
    setDraft('');
    setSelectedAttachments([]);
    setAttachmentError(null);

    if (isGenerationBusy) {
      setQueuedRequests(currentRequests => [...currentRequests, request]);
      return;
    }

    runChatRequest(request).catch(() => undefined);
  }, [
    draft,
    isGenerationBusy,
    runChatRequest,
    selectedAttachments,
  ]);

  const handleEditQueuedRequest = useCallback((request: QueuedChatRequest) => {
    setEditingQueuedRequestId(request.id);
    setEditingQueuedDraft(request.prompt);
  }, []);

  const handleCancelQueuedRequestEdit = useCallback(() => {
    setEditingQueuedRequestId(null);
    setEditingQueuedDraft('');
  }, []);

  const handleSaveQueuedRequestEdit = useCallback(
    (requestId: string) => {
      const nextPrompt = editingQueuedDraft.trim();

      setQueuedRequests(currentRequests =>
        currentRequests.flatMap(request => {
          if (request.id !== requestId) {
            return [request];
          }

          if (!nextPrompt && request.attachments.length === 0) {
            return [];
          }

          return [{ ...request, prompt: nextPrompt }];
        }),
      );
      setEditingQueuedRequestId(null);
      setEditingQueuedDraft('');
    },
    [editingQueuedDraft],
  );

  const handleDeleteQueuedRequest = useCallback((requestId: string) => {
    setQueuedRequests(currentRequests =>
      currentRequests.filter(request => request.id !== requestId),
    );
    setEditingQueuedRequestId(currentEditingId =>
      currentEditingId === requestId ? null : currentEditingId,
    );
  }, []);

  useEffect(() => {
    if (
      isGenerationBusy ||
      editingQueuedRequestId ||
      queuedRequests.length === 0
    ) {
      return;
    }

    const [nextRequest] = queuedRequests;
    setQueuedRequests(currentRequests =>
      currentRequests.filter(request => request.id !== nextRequest.id),
    );
    runChatRequest(nextRequest).catch(() => undefined);
  }, [
    editingQueuedRequestId,
    isGenerationBusy,
    queuedRequests,
    runChatRequest,
  ]);

  const handleRetryResponse = useCallback(
    async (assistantMessageId: string) => {
      if (isGenerationBusy) {
        return;
      }

      const assistantIndex = conversationMessages.findIndex(
        message => message.id === assistantMessageId,
      );
      if (assistantIndex < 0) {
        return;
      }

      let userIndex = -1;
      for (let index = assistantIndex - 1; index >= 0; index -= 1) {
        if (conversationMessages[index].role === 'user') {
          userIndex = index;
          break;
        }
      }

      if (userIndex < 0) {
        return;
      }

      const sourceUserMessage = conversationMessages[userIndex];
      const sourceAttachments = sourceUserMessage.attachments ?? [];
      const promptForModel =
        sourceUserMessage.text.trim() ||
        (sourceAttachments.length > 0 ? t('chat.analyzeAttachedFile') : '');
      if (!promptForModel) {
        return;
      }

      const retriedAssistantMessage: ChatMessage = {
        ...conversationMessages[assistantIndex],
        createdAt: new Date(),
        modelName: selectedModelLabel,
        text: t('chat.retrying'),
      };
      const messagesWithPendingRetry = conversationMessages.map(
        (message, index) =>
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
      const generationToken = generationTokenRef.current + 1;
      generationTokenRef.current = generationToken;
      stopRequestedRef.current = false;
      setIsGenerating(true);
      setIsStoppingGeneration(false);
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
          ...(shouldIncludeRuntimeContext(promptForModel)
            ? [createRuntimeContextMessage()]
            : []),
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
              if (
                generationTokenRef.current !== generationToken ||
                stopRequestedRef.current
              ) {
                return;
              }

              streamedResponse += chunk;
              updateRetriedAssistantMessage(streamedResponse);
            },
          },
          {
            attachments: sourceAttachments,
            chatSessionId: sessionId ?? undefined,
            modelId: selectedModelId,
          },
        );

        if (
          generationTokenRef.current !== generationToken ||
          stopRequestedRef.current
        ) {
          return;
        }

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
        if (
          generationTokenRef.current !== generationToken ||
          stopRequestedRef.current
        ) {
          return;
        }

        const message =
          error instanceof Error
            ? error.message
            : t('chat.unknownResponseError');

        updateRetriedAssistantMessage(
          streamedResponse || t('chat.responseFailed', { message }),
        );
      } finally {
        if (generationTokenRef.current === generationToken) {
          setIsGenerating(false);
          setIsStoppingGeneration(false);
          setIsAwaitingFirstChunk(false);
        }
      }
    },
    [
      isGenerationBusy,
      commonSystemPrompt,
      conversationMessages,
      messages,
      onMessagesChange,
      selectedModelLabel,
      selectedModelId,
      sessionId,
      t,
    ],
  );

  const handleAttachFile = useCallback(async () => {
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
          name: getAttachmentName(attachment, defaultAttachmentName),
        },
      ]);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : t('chat.filePickFailed');
      setAttachmentError(t('chat.attachmentFailed', { message }));
    }
  }, [defaultAttachmentName, t]);

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
    <KeyboardAvoidingView style={styles.container}>
      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          !hasUserMessages && styles.scrollContentInitial,
          hasUserMessages && styles.scrollContentThread,
          scrollContentBottomInsetStyle,
        ]}
        keyboardShouldPersistTaps="handled"
        onScroll={handleThreadScroll}
        ref={scrollViewRef}
        scrollEventThrottle={16}
        scrollEnabled={hasUserMessages}
        showsVerticalScrollIndicator={hasUserMessages}
      >
        {!hasUserMessages ? (
          <View style={styles.hero}>
            <Text style={styles.heroTitle}>{t('chat.heroTitle')}</Text>
            <Text style={styles.heroBody}>
              {t('chat.heroBody')}
            </Text>
          </View>
        ) : null}

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
                      {t(chatModeLabelKeys[mode.id])}
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
            <View style={styles.threadList}>
              {conversationMessages.map((message, index) => {
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
                  conversationMessages
                    .slice(0, index)
                    .some(previousMessage => previousMessage.role === 'user');

                return (
                  <ChatBubble
                    assistantName={message.modelName ?? selectedModelLabel}
                    isRetryDisabled={isGenerationBusy}
                    key={message.id}
                    onRetry={
                      canRetryAssistantMessage
                        ? () => handleRetryResponse(message.id)
                        : undefined
                    }
                    reasoning={message.reasoning}
                    role={message.role}
                    text={message.text}
                    attachments={message.attachments}
                    attachmentFallbackName={defaultAttachmentName}
                    timestamp={formatTime(message.createdAt, locale)}
                  />
                );
              })}

              {isGenerating && isAwaitingFirstChunk ? (
                <View style={styles.loadingRow}>
                  <LoadingDots
                    label={t('chat.loadingResponse', {
                      model: selectedModelLabel,
                    })}
                  />
                </View>
              ) : null}
            </View>
          </View>
        ) : null}
      </ScrollView>

      {showScrollToBottom ? (
        <Pressable
          accessibilityLabel={t('chat.scrollToBottom')}
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

      <ChatComposer
        attachmentError={attachmentError}
        canSubmit={canSubmit}
        composerOffsetStyle={composerOffsetStyle}
        defaultAttachmentName={defaultAttachmentName}
        draft={draft}
        editingQueuedDraft={editingQueuedDraft}
        editingQueuedRequestId={editingQueuedRequestId}
        isGenerationBusy={isGenerationBusy}
        isStoppingGeneration={isStoppingGeneration}
        onAttachFile={handleAttachFile}
        onCancelQueuedRequestEdit={handleCancelQueuedRequestEdit}
        onChangeDraft={setDraft}
        onChangeEditingQueuedDraft={setEditingQueuedDraft}
        onDeleteQueuedRequest={handleDeleteQueuedRequest}
        onEditQueuedRequest={handleEditQueuedRequest}
        onRemoveAttachment={handleRemoveAttachment}
        onSaveQueuedRequestEdit={handleSaveQueuedRequestEdit}
        onSend={handleSend}
        onStopGeneration={handleStopGeneration}
        queuedRequests={queuedRequests}
        selectedAttachments={selectedAttachments}
        shouldShowStopButton={shouldShowStopButton}
      />
    </KeyboardAvoidingView>
  );
}


export default ChatScreen;
