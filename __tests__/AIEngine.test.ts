import AIEngine, { createPromptWithHistory } from '../src/native/AIEngine';

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
