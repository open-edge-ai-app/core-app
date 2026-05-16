import AIEngine, {
  RUNTIME_CONTEXT_MARKER,
  createPromptWithHistory,
} from '../src/native/AIEngine';
import {
  createConversationHistory,
  shouldIncludeRuntimeContext,
} from '../src/screens/ChatScreen';

test('builds model prompt with prior chat history', () => {
  const prompt = createPromptWithHistory('내 이름이 뭐라고 했지?', [
    {
      content: '내 이름은 민준이야.',
      role: 'user',
    },
    {
      content: '알겠습니다. 민준이라고 기억할게요.',
      role: 'assistant',
    },
    {
      content: '내 이름이 뭐라고 했지?',
      role: 'user',
    },
  ]);

  expect(prompt).toContain('이전 대화 내용입니다.');
  expect(prompt).toContain('user: 내 이름은 민준이야.');
  expect(prompt).toContain('assistant: 알겠습니다. 민준이라고 기억할게요.');
  expect(prompt).toContain('현재 사용자 요청:\n내 이름이 뭐라고 했지?');
});

test('uses prior chat history in development fallback responses', async () => {
  const response = await AIEngine.generateResponse('내 이름이 뭐라고 했지?', [
    {
      content: '내 이름은 민준이야.',
      role: 'user',
    },
    {
      content: '알겠습니다. 민준이라고 기억할게요.',
      role: 'assistant',
    },
    {
      content: '내 이름이 뭐라고 했지?',
      role: 'user',
    },
  ]);

  expect(response).toContain('이전 대화 2개를 포함해 응답 요청을 구성했습니다.');
  expect(response).toContain('user: 내 이름은 민준이야.');
  expect(response).toContain('현재 사용자 요청:\n내 이름이 뭐라고 했지?');
});

test('only includes runtime date context for date-aware prompts', () => {
  expect(shouldIncludeRuntimeContext('재미있는 앱 이름 추천해줘')).toBe(false);
  expect(shouldIncludeRuntimeContext('오늘 일정 알려줘')).toBe(true);
  expect(shouldIncludeRuntimeContext('5분 뒤에 리마인드해줘')).toBe(true);
});

test('keeps runtime date context separate from visible system instructions', () => {
  const prompt = createPromptWithHistory('재미있는 앱 이름 추천해줘', [
    {
      content: '항상 한국어로 답하세요.',
      role: 'system',
    },
    {
      content: [
        RUNTIME_CONTEXT_MARKER,
        '오늘은 2026년 5월 16일 토요일입니다.',
        '현재 로컬 시각: 오후 04:20',
        '시간대: Asia/Seoul',
      ].join('\n'),
      role: 'system',
    },
  ]);

  expect(prompt).toContain('다음 시스템 지침을 우선 적용하세요.');
  expect(prompt).toContain('항상 한국어로 답하세요.');
  expect(prompt).toContain('비공개 런타임 컨텍스트입니다.');
  expect(prompt).toContain('먼저 언급하지 말고');
  expect(prompt).toContain('오늘은 2026년 5월 16일 토요일입니다.');
  expect(prompt).not.toContain(RUNTIME_CONTEXT_MARKER);
});

test('does not use the first user message as the chat title fallback', async () => {
  await expect(
    AIEngine.generateChatTitle('첫 질문 전체가 제목으로 나오면 안 돼', '응답'),
  ).resolves.toBe('새 채팅');
});

test('converts visible chat messages into model history', () => {
  const history = createConversationHistory([
    {
      createdAt: new Date('2026-05-13T00:00:00+09:00'),
      id: 'welcome',
      role: 'assistant',
      text: '환영 메시지',
    },
    {
      createdAt: new Date('2026-05-13T00:01:00+09:00'),
      id: 'user-1',
      role: 'user',
      text: '내 이름은 민준이야.',
    },
    {
      createdAt: new Date('2026-05-13T00:02:00+09:00'),
      id: 'assistant-1',
      role: 'assistant',
      text: '민준이라고 기억할게요.',
    },
    {
      createdAt: new Date('2026-05-13T00:03:00+09:00'),
      id: 'system-1',
      role: 'system',
      text: '응답 실패: 네트워크 오류',
    },
  ]);

  expect(history).toEqual([
    {
      content: '내 이름은 민준이야.',
      role: 'user',
    },
    {
      content: '민준이라고 기억할게요.',
      role: 'assistant',
    },
  ]);
});
