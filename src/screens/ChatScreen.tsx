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
  faChevronRight,
  faGlobe,
  faPaperclip,
} from '@fortawesome/free-solid-svg-icons';
import {
  Keyboard,
  KeyboardAvoidingView,
  KeyboardEvent,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import AppIcon from '../components/AppIcon';
import ChatBubble, { ChatRole } from '../components/ChatBubble';
import LoadingDots from '../components/LoadingDots';
import { Separator } from '../components/ui';
import AIEngine, { AIChatMessage } from '../native/AIEngine';
import { colors, typography } from '../theme/tokens';

type Message = {
  createdAt: Date;
  id: string;
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
    description: '강점, 병목, 다음 액션을 한 번에 정리',
    prompt: '내 프로젝트를 개선하기 위한 핵심 아이디어를 정리해줘',
    title: '프로젝트 방향성 정리',
  },
  {
    description: '콘텐츠, 커뮤니티, 추천 루프 중심',
    prompt: '광고 없이 사용자를 늘리는 현실적인 방법을 알려줘',
    title: '광고 없는 성장 전략',
  },
  {
    description: '오늘 바로 실행할 수 있는 순서로 변환',
    prompt: '오늘 할 일을 실행 계획으로 정리해줘',
    title: '실행 계획 만들기',
  },
];

const chatModes: ChatMode[] = [
  { id: 'chat', label: '채팅' },
  { id: 'search', label: '검색' },
  { id: 'reason', label: '분석' },
  { id: 'files', label: '파일' },
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
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
        ref={scrollViewRef}
        showsVerticalScrollIndicator={false}
      >
        <View style={[styles.hero, hasUserMessages && styles.heroCompact]}>
          <Text style={styles.heroTitle}>
            {hasUserMessages ? '대화' : '무엇이든 물어보세요'}
          </Text>
          {!hasUserMessages ? (
            <Text style={styles.heroBody}>
              질문, 검색, 자료 분석을 같은 입력창에서 이어서 시작합니다.
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

            <View style={styles.cardHeader}>
              <Text style={styles.cardTitle}>빠른 시작</Text>
              <Text style={styles.sectionMeta}>3개 추천</Text>
            </View>
            <Separator style={styles.cardSeparator} />

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
                    <Text style={styles.promptDescription}>
                      {prompt.description}
                    </Text>
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
            <Separator style={styles.cardSeparator} />

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
                <Text style={styles.textToolLabel}>Auto</Text>
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
  },
  scrollContent: {
    paddingBottom: 176,
    paddingHorizontal: 20,
    paddingTop: 14,
  },
  hero: {
    paddingBottom: 22,
    paddingTop: 18,
  },
  heroCompact: {
    paddingBottom: 12,
  },
  heroTitle: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 31,
    lineHeight: 37,
  },
  heroBody: {
    ...typography.body,
    color: colors.mutedForeground,
    fontWeight: '400',
    lineHeight: 22,
    marginTop: 8,
    maxWidth: 320,
  },
  quickSection: {
    marginBottom: 26,
  },
  modeRail: {
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: 24,
    marginBottom: 24,
  },
  modeItem: {
    minHeight: 40,
    justifyContent: 'center',
    position: 'relative',
  },
  modeText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 16,
  },
  modeTextSelected: {
    color: colors.foreground,
  },
  modeIndicator: {
    backgroundColor: colors.primary,
    borderRadius: 1,
    bottom: -1,
    height: 2,
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
    marginTop: 12,
  },
  promptList: {
    marginTop: 2,
  },
  promptRow: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderRadius: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 64,
    paddingHorizontal: 4,
    paddingVertical: 10,
  },
  promptRowPressed: {
    opacity: 0.58,
  },
  promptCopy: {
    flex: 1,
    paddingRight: 12,
  },
  promptTitle: {
    ...typography.label,
    color: colors.foreground,
    fontSize: 16,
  },
  promptDescription: {
    ...typography.caption,
    color: colors.mutedForeground,
    fontWeight: '500',
    lineHeight: 17,
    marginTop: 5,
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
    backgroundColor: 'rgba(247,247,250,0.96)',
    bottom: 0,
    left: 0,
    paddingBottom: 10,
    paddingHorizontal: 12,
    paddingTop: 8,
    position: 'absolute',
    right: 0,
  },
  inputPanel: {
    backgroundColor: colors.card,
    borderColor: '#DADADD',
    borderRadius: 20,
    borderWidth: 1,
    minHeight: 138,
    paddingBottom: 10,
    paddingHorizontal: 12,
    paddingTop: 10,
  },
  contextPill: {
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderColor: colors.input,
    borderRadius: 13,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 7,
    minHeight: 32,
    paddingHorizontal: 11,
  },
  contextText: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 15,
  },
  input: {
    ...typography.body,
    backgroundColor: 'transparent',
    color: colors.foreground,
    fontSize: 16,
    fontWeight: '400',
    lineHeight: 22,
    maxHeight: 82,
    minHeight: 44,
    paddingHorizontal: 4,
    paddingTop: 16,
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
    gap: 13,
    paddingRight: 10,
  },
  iconTool: {
    alignItems: 'center',
    height: 36,
    justifyContent: 'center',
    width: 34,
  },
  textTool: {
    minHeight: 34,
    justifyContent: 'center',
  },
  textToolLabel: {
    ...typography.label,
    color: colors.mutedForeground,
    fontSize: 15,
  },
  sourceTool: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 8,
    minHeight: 34,
  },
  sendButton: {
    alignItems: 'center',
    backgroundColor: colors.foreground,
    borderRadius: 21,
    height: 42,
    justifyContent: 'center',
    width: 42,
  },
  sendButtonPressed: {
    opacity: 0.76,
  },
  sendButtonDisabled: {
    backgroundColor: '#161616',
    opacity: 1,
  },
});

export default ChatScreen;
