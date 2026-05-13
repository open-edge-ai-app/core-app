import { createCommonSystemPrompt } from '../src/state/systemPrompt';

test('combines personal prompt before work folder memory', () => {
  expect(
    createCommonSystemPrompt('  Be concise.  ', '  Use repo memory.  '),
  ).toBe(
    [
      '개인 시스템 프롬프트:\nBe concise.',
      '작업 폴더 시스템 프롬프트(메모리):\nUse repo memory.',
    ].join('\n\n'),
  );
});

test('omits empty system prompt sections', () => {
  expect(createCommonSystemPrompt('', '  Folder only.  ')).toBe(
    '작업 폴더 시스템 프롬프트(메모리):\nFolder only.',
  );
  expect(createCommonSystemPrompt('  Personal only.  ', '')).toBe(
    '개인 시스템 프롬프트:\nPersonal only.',
  );
  expect(createCommonSystemPrompt('', '')).toBe('');
});
