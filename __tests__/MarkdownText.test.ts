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

  it('keeps compact Korean responses readable without breaking urls or times', () => {
    expect(
      normalizeMarkdownText(
        '네,알겠습니다.오늘 10:30에 확인하세요.참고:https://example.com/a.b',
      ),
    ).toBe(
      '네, 알겠습니다. 오늘 10:30에 확인하세요. 참고: https://example.com/a.b',
    );
  });

  it('splits compact ordered lists embedded in paragraphs', () => {
    expect(parseMarkdown('예시:*1.미팅 준비2)자료 확인')).toEqual([
      {
        text: '예시:',
        type: 'paragraph',
      },
      {
        items: [{ marker: '1.', text: '미팅 준비 2) 자료 확인' }],
        type: 'orderedList',
      },
    ]);
    expect(parseMarkdown('예시:*1.미팅 준비.2)자료 확인')).toEqual([
      {
        text: '예시:',
        type: 'paragraph',
      },
      {
        items: [
          { marker: '1.', text: '미팅 준비.' },
          { marker: '2)', text: '자료 확인' },
        ],
        type: 'orderedList',
      },
    ]);
  });

  it('breaks very long single-paragraph answers into readable paragraphs', () => {
    const compact =
      '삼성전자 주가 정보를 확인할 수 있습니다. 현재 시세는 예시이며 실제 가격은 거래소에서 확인해야 합니다. 또한 관련 뉴스와 공시를 함께 보는 것이 좋습니다. 투자 판단에는 실적과 수급을 같이 봐야 합니다.';

    expect(normalizeMarkdownText(compact)).toBe(
      '삼성전자 주가 정보를 확인할 수 있습니다. 현재 시세는 예시이며 실제 가격은 거래소에서 확인해야 합니다.\n\n또한 관련 뉴스와 공시를 함께 보는 것이 좋습니다. 투자 판단에는 실적과 수급을 같이 봐야 합니다.',
    );
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
