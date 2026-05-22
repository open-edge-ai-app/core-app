import {
  linkInlineCitationMarkers,
  parseCitations,
} from '../src/native/citations';

describe('parseCitations', () => {
  it('returns the text unchanged when there is no citation footer', () => {
    const text = 'Just a normal answer with no sources.';
    const result = parseCitations(text);
    expect(result.body).toBe(text);
    expect(result.sources).toHaveLength(0);
  });

  it('splits the body from the citation footer and parses web sources', () => {
    const text = [
      'Here is the answer.',
      '',
      '## 참고한 자료',
      '- 웹: Example Title — https://example.com/page',
      '- 웹: Another — https://news.site/article',
    ].join('\n');

    const { body, sources } = parseCitations(text);
    expect(body).toBe('Here is the answer.');
    expect(sources).toHaveLength(2);
    expect(sources[0]).toEqual({
      kind: 'web',
      label: 'Example Title',
      url: 'https://example.com/page',
    });
    expect(sources[1].url).toBe('https://news.site/article');
  });

  it('parses document and memory sources without urls', () => {
    const text = [
      'Answer.',
      '## 참고한 자료',
      '- 문서: report.pdf — /docs/report.pdf',
      '- SMS 기억: thread-12',
    ].join('\n');

    const { sources } = parseCitations(text);
    expect(sources[0].kind).toBe('document');
    expect(sources[0].url).toBeUndefined();
    expect(sources[1].kind).toBe('memory');
  });

  it('links inline source markers to parsed footer urls', () => {
    const text = [
      '요약입니다. (Source [1]) 세부 내용입니다. (Opened URL details [2]) 참고하세요.',
      '',
      '## 참고한 자료',
      '- 웹: First — https://example.com/first',
      '- 웹: Second — https://example.com/second',
    ].join('\n');
    const { body, sources } = parseCitations(text);

    expect(linkInlineCitationMarkers(body, sources)).toBe(
      '요약입니다. ([1](https://example.com/first)) 세부 내용입니다. ([2](https://example.com/second)) 참고하세요.',
    );
  });
});
