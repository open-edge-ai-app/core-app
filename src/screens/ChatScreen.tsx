import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  faArrowUp,
  faAt,
  faBolt,
  faChartSimple,
  faChevronDown,
  faChevronRight,
  faComment,
  faFile,
  faGlobe,
  faMagnifyingGlass,
  faMessage,
  faPaperclip,
} from '@fortawesome/free-solid-svg-icons';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import {
  Keyboard,
  KeyboardAvoidingView,
  KeyboardEvent,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';

import AppIcon from '../components/AppIcon';
import ChatBubble, { ChatRole } from '../components/ChatBubble';
import LoadingDots from '../components/LoadingDots';
import AIEngine, { AIChatMessage } from '../native/AIEngine';
import {
  ScaledText as Text,
  ScaledTextInput as TextInput,
} from '../theme/display';
import { colors, typography } from '../theme/tokens';

type Message = {
  createdAt: Date;
  id: string;
  role: ChatRole;
  text: string;
};

type QuickPrompt = {
  description: string;
  icon: IconDefinition;
  prompt: string;
  title: string;
};

type ChatMode = {
  id: 'chat' | 'search' | 'reason' | 'files';
  icon: IconDefinition;
  label: string;
};

type ChatScreenProps = {
  onSessionTitleChange?: (title: string) => void;
};

const initialMessages: Message[] = [
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
    icon: faComment,
    prompt: '오늘 삼성전자 주가 흐름을 요약해줘',
    title: '오늘 삼성전자 주가 흐름을 요약해줘',
  },
  {
    description: '검색 기반으로 최신 흐름 확인',
    icon: faMagnifyingGlass,
    prompt: '친환경 소재의 최신 연구 동향을 검색해줘',
    title: '친환경 소재의 최신 연구 동향 검색',
  },
  {
    description: '긴 문서를 읽기 쉬운 요약으로 변환',
    icon: faFile,
    prompt: '업로드한 PDF 내용을 정리해줘',
    title: '업로드한 PDF 내용을 정리해줘',
  },
];

const chatModes: ChatMode[] = [
  { icon: faMessage, id: 'chat', label: '채팅' },
  { icon: faMagnifyingGlass, id: 'search', label: '검색' },
  { icon: faChartSimple, id: 'reason', label: '분석' },
  { icon: faFile, id: 'files', label: '파일' },
];

const formatTime = (date: Date) =>
  new Intl.DateTimeFormat('ko-KR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);

const createMessage = (role: ChatRole, text: string): Message => ({
  createdAt: new Date(),
  id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  role,
  text,
});

const createSessionTitle = (prompt: string) => {
  const normalizedPrompt = prompt.replace(/\s+/g, ' ').trim();

  if (normalizedPrompt.length <= 18) {
    return normalizedPrompt;
  }

  return `${normalizedPrompt.slice(0, 18)}...`;
};

function ChatScreen({ onSessionTitleChange }: ChatScreenProps) {
  const scrollViewRef = useRef<ScrollView>(null);
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [draft, setDraft] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const [selectedMode, setSelectedMode] = useState<ChatMode['id']>('chat');

  const hasUserMessages = useMemo(
    () => messages.some(message => message.role === 'user'),
    [messages],
  );

  const history = useMemo<AIChatMessage[]>(
    () =>
      messages
        .filter(message => message.role !== 'system')
        .map(message => ({
          content: message.text,
          role: message.role,
        })),
    [messages],
  );

  const composerOffsetStyle = useMemo(
    () => ({
      marginBottom: Platform.OS === 'android' ? keyboardHeight : 0,
    }),
    [keyboardHeight],
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

    const timeoutId = setTimeout(() => {
      scrollViewRef.current?.scrollToEnd({ animated: true });
    }, 80);

    return () => clearTimeout(timeoutId);
  }, [hasUserMessages, isGenerating, messages.length]);

  useEffect(() => {
    if (hasUserMessages) {
      return;
    }

    scrollViewRef.current?.scrollTo({ animated: false, y: 0 });
  }, [hasUserMessages]);

  const handleSend = useCallback(async () => {
    const prompt = draft.trim();

    if (!prompt || isGenerating) {
      return;
    }

    const userMessage = createMessage('user', prompt);
    setMessages(current => [...current, userMessage]);
    if (!hasUserMessages) {
      onSessionTitleChange?.(createSessionTitle(prompt));
    }
    setDraft('');
    setIsGenerating(true);

    try {
      const response = await AIEngine.generateResponse(prompt, [
        ...history,
        { content: prompt, role: 'user' },
      ]);
      setMessages(current => [
        ...current,
        createMessage('assistant', response),
      ]);
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : 'AI 응답 처리 중 알 수 없는 문제가 발생했습니다.';

      setMessages(current => [
        ...current,
        createMessage('system', `응답 실패: ${message}`),
      ]);
    } finally {
      setIsGenerating(false);
    }
  }, [draft, hasUserMessages, history, isGenerating, onSessionTitleChange]);

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
        ref={scrollViewRef}
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
                    <AppIcon
                      color={
                        isSelected ? colors.primary : colors.mutedForeground
                      }
                      icon={mode.icon}
                      size={16}
                    />
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
                  <View style={styles.promptIcon}>
                    <AppIcon
                      color={colors.foreground}
                      icon={prompt.icon}
                      size={22}
                    />
                  </View>
                  <View style={styles.promptCopy}>
                    <Text style={styles.promptTitle}>{prompt.title}</Text>
                  </View>
                  <AppIcon
                    color={colors.primary}
                    icon={faChevronRight}
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
              {messages.map(message => (
                <ChatBubble
                  key={message.id}
                  role={message.role}
                  text={message.text}
                  timestamp={formatTime(message.createdAt)}
                />
              ))}

              {isGenerating ? (
                <View style={styles.loadingRow}>
                  <LoadingDots />
                  <Text style={styles.loadingText}>응답 준비 중</Text>
                </View>
              ) : null}
            </View>
          </View>
        ) : null}
      </ScrollView>

      <View style={[styles.composer, composerOffsetStyle]}>
        <View style={styles.inputPanel}>
          <Pressable
            accessibilityLabel="컨텍스트 추가"
            accessibilityRole="button"
            style={({ pressed }) => [
              styles.contextPill,
              pressed && styles.promptRowPressed,
            ]}
          >
            <AppIcon color={colors.mutedForeground} icon={faAt} size={18} />
            <Text style={styles.contextText}>Add context</Text>
          </Pressable>

          <TextInput
            multiline
            onChangeText={setDraft}
            placeholder="Ask, search, or make anything..."
            placeholderTextColor={colors.mutedForeground}
            style={styles.input}
            value={draft}
          />

          <View style={styles.inputFooter}>
            <View style={styles.inputTools}>
              <Pressable
                accessibilityLabel="파일 첨부"
                accessibilityRole="button"
                style={({ pressed }) => [
                  styles.iconTool,
                  pressed && styles.promptRowPressed,
                ]}
              >
                <AppIcon
                  color={colors.mutedForeground}
                  icon={faPaperclip}
                  size={21}
                />
              </Pressable>
              <Pressable
                accessibilityLabel="자동 모드"
                accessibilityRole="button"
                style={({ pressed }) => [
                  styles.textTool,
                  pressed && styles.promptRowPressed,
                ]}
              >
                <AppIcon color={colors.foreground} icon={faBolt} size={15} />
                <Text style={styles.textToolLabel}>Auto</Text>
                <AppIcon
                  color={colors.mutedForeground}
                  icon={faChevronDown}
                  size={9}
                />
              </Pressable>
              <Pressable
                accessibilityLabel="전체 소스"
                accessibilityRole="button"
                style={({ pressed }) => [
                  styles.sourceTool,
                  pressed && styles.promptRowPressed,
                ]}
              >
                <AppIcon
                  color={colors.mutedForeground}
                  icon={faGlobe}
                  size={22}
                />
                <Text style={styles.textToolLabel}>All Sources</Text>
                <AppIcon
                  color={colors.mutedForeground}
                  icon={faChevronDown}
                  size={9}
                />
              </Pressable>
            </View>

            <Pressable
              accessibilityLabel="메시지 보내기"
              accessibilityRole="button"
              disabled={!draft.trim() || isGenerating}
              onPress={handleSend}
              style={({ pressed }) => [
                styles.sendButton,
                pressed && styles.sendButtonPressed,
                (!draft.trim() || isGenerating) && styles.sendButtonDisabled,
              ]}
            >
              <AppIcon color={colors.card} icon={faArrowUp} size={22} />
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
    paddingBottom: 170,
    paddingTop: 24,
  },
  scrollContentThread: {
    paddingBottom: 210,
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
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 42,
    paddingHorizontal: 1,
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
  promptIcon: {
    alignItems: 'center',
    height: 34,
    justifyContent: 'center',
    marginRight: 16,
    width: 28,
  },
  promptCopy: {
    flex: 1,
    paddingRight: 12,
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
    gap: 8,
    marginBottom: 12,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  loadingText: {
    ...typography.caption,
    color: colors.mutedForeground,
  },
  composer: {
    backgroundColor: 'transparent',
    bottom: 62,
    left: 0,
    paddingBottom: 12,
    paddingHorizontal: 12,
    paddingTop: 14,
    position: 'absolute',
    right: 0,
  },
  inputPanel: {
    backgroundColor: colors.card,
    borderColor: 'rgba(21,25,34,0.08)',
    borderRadius: 24,
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
  contextPill: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderColor: colors.input,
    borderRadius: 13,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 7,
    minHeight: 31,
    paddingHorizontal: 10,
  },
  contextText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 14,
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
  textTool: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    minHeight: 34,
  },
  textToolLabel: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 14,
  },
  sourceTool: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 7,
    minHeight: 34,
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
