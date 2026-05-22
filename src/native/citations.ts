export type CitationKind = 'web' | 'document' | 'memory' | 'other';

export type CitationSource = {
  kind: CitationKind;
  label: string;
  url?: string;
};

export type ParsedCitations = {
  body: string;
  sources: CitationSource[];
};

// Matches the footer the Android QueryRouter appends: "\n\n## 참고한 자료\n- ...".
export const CITATION_HEADER = '참고한 자료';

const HEADER_PATTERN = new RegExp(`\\n*##\\s*${CITATION_HEADER}\\s*\\n`);
const URL_PATTERN = /(https?:\/\/[^\s)]+)/;

function parseLine(content: string): CitationSource {
  const urlMatch = content.match(URL_PATTERN);
  const url = urlMatch?.[1];

  let kind: CitationKind = 'other';
  if (content.startsWith('웹:') || /^web:/i.test(content)) {
    kind = 'web';
  } else if (content.startsWith('문서:') || /^doc(ument)?:/i.test(content)) {
    kind = 'document';
  } else if (content.includes('기억:') || /memory:/i.test(content)) {
    kind = 'memory';
  } else if (url) {
    kind = 'web';
  }

  let label = content;
  if (url) {
    label = label.replace(url, '');
  }
  // Drop the kind prefix ("웹:", "문서:", "SMS 기억:", ...) and trailing separators.
  label = label
    .replace(/^([^:]{0,12}):\s*/, '')
    .replace(/[—–-]\s*$/, '')
    .trim();

  return { kind, label: label || url || content, url };
}

export function parseCitations(text: string): ParsedCitations {
  const match = text.match(HEADER_PATTERN);
  if (!match || match.index === undefined) {
    return { body: text, sources: [] };
  }

  const body = text.slice(0, match.index).trimEnd();
  const footer = text.slice(match.index + match[0].length);
  const sources = footer
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.startsWith('- '))
    .map(line => parseLine(line.slice(2).trim()))
    .filter(source => source.label.length > 0);

  return { body, sources };
}

// Renders inline citation markers ("Source [1]", "Opened URL details [2]", or a
// bare "[3]") as compact, tappable [n] links pointing at the matching footer
// source. The number always indexes the same ordered source list shown to the
// user, mirroring the iOS citation behavior.
export function linkInlineCitationMarkers(
  body: string,
  sources: CitationSource[],
): string {
  if (sources.length === 0) {
    return body;
  }

  return body.replace(
    /\b(?:Source|Opened URL details)\s*\[(\d+)\]|\[(\d+)\]/gi,
    (match, labeledIndex: string | undefined, bareIndex: string | undefined) => {
      const index = labeledIndex ?? bareIndex;
      if (!index) {
        return match;
      }
      const source = sources[Number(index) - 1];
      if (!source?.url) {
        return match;
      }

      return `[${index}](${source.url})`;
    },
  );
}
