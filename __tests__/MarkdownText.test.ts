import {
  normalizeMarkdownText,
  parseMarkdown,
} from '../src/components/MarkdownText';

describe('MarkdownText parser', () => {
  it('parses compact headings commonly returned by local models', () => {
    expect(normalizeMarkdownText('-#💡아이디어 선택지')).toBe(
      '# 💡아이디어 선택지',
    );
    expect(parseMarkdown('-#💡아이디어 선택지')).toEqual([
      {
        level: 1,
        text: '💡아이디어 선택지',
        type: 'heading',
      },
    ]);
  });

  it('parses ordered lists even when the model omits marker spacing', () => {
    expect(parseMarkdown('1.첫째\n2)둘째')).toEqual([
      {
        items: [
          { marker: '1.', text: '첫째' },
          { marker: '2)', text: '둘째' },
        ],
        type: 'orderedList',
      },
    ]);
  });

  it('does not normalize fenced code content', () => {
    const source = '```tsx\n#Not heading\n1.value\n```\n#제목';

    expect(normalizeMarkdownText(source)).toBe(
      '```tsx\n#Not heading\n1.value\n```\n# 제목',
    );
    expect(parseMarkdown(source)).toMatchObject([
      {
        language: 'tsx',
        text: '#Not heading\n1.value',
        type: 'code',
      },
      {
        text: '제목',
        type: 'heading',
      },
    ]);
  });
});
