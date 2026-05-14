export const defaultPersonalityPresetId = 'balanced';

export const personalityPresets = [
  {
    id: 'balanced',
    prompt:
      '차분하고 직접적으로 답하며, 결론을 먼저 제시하고 필요한 근거만 짧게 덧붙입니다.',
  },
  {
    id: 'friendly',
    prompt:
      '친절하고 부드럽게 답하되, 과한 감탄이나 장식적인 표현은 줄이고 다음 행동을 쉽게 정리합니다.',
  },
  {
    id: 'concise',
    prompt:
      '가능한 한 짧고 명확하게 답하며, 핵심 답변과 바로 실행할 수 있는 내용만 우선합니다.',
  },
  {
    id: 'analytical',
    prompt:
      '근거와 선택지를 구조적으로 비교하고, 불확실한 부분과 tradeoff를 명확히 표시합니다.',
  },
] as const;

export type PersonalityPresetId = (typeof personalityPresets)[number]['id'];

export const getPersonalityPreset = (value: string) =>
  personalityPresets.find(
    preset => preset.id === value || preset.prompt === value,
  );

export const resolvePersonalityPrompt = (value: string) =>
  getPersonalityPreset(value.trim())?.prompt ?? value;
