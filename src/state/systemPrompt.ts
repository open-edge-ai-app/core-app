const trimPrompt = (value: string) => value.trim();

export const createCommonSystemPrompt = (
  personalSystemPrompt: string,
  workFolderMemory: string,
) =>
  [
    trimPrompt(personalSystemPrompt)
      ? `개인 시스템 프롬프트:\n${trimPrompt(personalSystemPrompt)}`
      : '',
    trimPrompt(workFolderMemory)
      ? `작업 폴더 시스템 프롬프트(메모리):\n${trimPrompt(
          workFolderMemory,
        )}`
      : '',
  ]
    .filter(Boolean)
    .join('\n\n');
