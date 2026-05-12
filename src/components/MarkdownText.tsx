import React, { ReactNode } from 'react';
import {
  Linking,
  Platform,
  StyleProp,
  StyleSheet,
  TextStyle,
  View,
} from 'react-native';

import { ScaledText as Text } from '../theme/display';
import { colors, typography } from '../theme/tokens';

type MarkdownTextProps = {
  style?: StyleProp<TextStyle>;
  text: string;
};

type MarkdownBlock =
  | { text: string; type: 'paragraph' }
  | { level: number; text: string; type: 'heading' }
  | { items: string[]; type: 'bulletList' }
  | { items: Array<{ marker: string; text: string }>; type: 'orderedList' }
  | { text: string; type: 'quote' }
  | { language?: string; text: string; type: 'code' };

const blockStartPattern =
  /^(```|#{1,6}\s+|>\s?|[-*]\s+|\d+[.)]\s+)/;
const inlinePattern =
  /(\[[^\]]+\]\([^)]+\)|`[^`\n]+`|\*\*[^*\n]+?\*\*|__[^_\n]+?__|\*[^*\n]+?\*|_[^_\n]+?_)/g;

const isBlockStart = (line: string) => blockStartPattern.test(line.trim());

function parseMarkdown(text: string): MarkdownBlock[] {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const blocks: MarkdownBlock[] = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index];
    const trimmedLine = line.trim();

    if (!trimmedLine) {
      index += 1;
      continue;
    }

    const codeFence = trimmedLine.match(/^```(\w+)?/);
    if (codeFence) {
      const codeLines: string[] = [];
      index += 1;

      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        codeLines.push(lines[index]);
        index += 1;
      }

      blocks.push({
        language: codeFence[1],
        text: codeLines.join('\n'),
        type: 'code',
      });
      index += index < lines.length ? 1 : 0;
      continue;
    }

    const heading = trimmedLine.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      blocks.push({
        level: Math.min(heading[1].length, 3),
        text: heading[2],
        type: 'heading',
      });
      index += 1;
      continue;
    }

    if (/^>\s?/.test(trimmedLine)) {
      const quoteLines: string[] = [];

      while (index < lines.length && /^>\s?/.test(lines[index].trim())) {
        quoteLines.push(lines[index].trim().replace(/^>\s?/, ''));
        index += 1;
      }

      blocks.push({ text: quoteLines.join('\n'), type: 'quote' });
      continue;
    }

    if (/^[-*]\s+/.test(trimmedLine)) {
      const items: string[] = [];

      while (index < lines.length && /^[-*]\s+/.test(lines[index].trim())) {
        items.push(lines[index].trim().replace(/^[-*]\s+/, ''));
        index += 1;
      }

      blocks.push({ items, type: 'bulletList' });
      continue;
    }

    if (/^\d+[.)]\s+/.test(trimmedLine)) {
      const items: Array<{ marker: string; text: string }> = [];

      while (index < lines.length) {
        const match = lines[index].trim().match(/^(\d+[.)])\s+(.+)$/);
        if (!match) {
          break;
        }

        items.push({ marker: match[1], text: match[2] });
        index += 1;
      }

      blocks.push({ items, type: 'orderedList' });
      continue;
    }

    const paragraphLines: string[] = [];

    while (
      index < lines.length &&
      lines[index].trim() &&
      !isBlockStart(lines[index])
    ) {
      paragraphLines.push(lines[index]);
      index += 1;
    }

    blocks.push({
      text: paragraphLines.map(value => value.trim()).join('\n'),
      type: 'paragraph',
    });
  }

  return blocks;
}

function renderInline(text: string, keyPrefix: string, depth = 0): ReactNode[] {
  if (depth > 4) {
    return [text];
  }

  const nodes: ReactNode[] = [];
  const pattern = new RegExp(inlinePattern.source, 'g');
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(text))) {
    const token = match[0];

    if (match.index > lastIndex) {
      nodes.push(text.slice(lastIndex, match.index));
    }

    const key = `${keyPrefix}-${match.index}`;
    const link = token.match(/^\[([^\]]+)\]\(([^)]+)\)$/);

    if (link) {
      nodes.push(
        <Text
          key={key}
          onPress={() => Linking.openURL(link[2]).catch(() => undefined)}
          style={styles.link}
        >
          {link[1]}
        </Text>,
      );
    } else if (token.startsWith('`')) {
      nodes.push(
        <Text key={key} style={styles.inlineCode}>
          {token.slice(1, -1)}
        </Text>,
      );
    } else if (token.startsWith('**') || token.startsWith('__')) {
      nodes.push(
        <Text key={key} style={styles.bold}>
          {renderInline(token.slice(2, -2), key, depth + 1)}
        </Text>,
      );
    } else {
      nodes.push(
        <Text key={key} style={styles.italic}>
          {renderInline(token.slice(1, -1), key, depth + 1)}
        </Text>,
      );
    }

    lastIndex = match.index + token.length;
  }

  if (lastIndex < text.length) {
    nodes.push(text.slice(lastIndex));
  }

  return nodes;
}

function MarkdownText({ style, text }: MarkdownTextProps) {
  const blocks = parseMarkdown(text);

  return (
    <View style={styles.container}>
      {blocks.map((block, index) => {
        if (block.type === 'heading') {
          return (
            <Text
              key={`heading-${index}`}
              style={[
                styles.text,
                style,
                styles.heading,
                block.level === 1 && styles.headingLarge,
              ]}
            >
              {renderInline(block.text, `heading-${index}`)}
            </Text>
          );
        }

        if (block.type === 'code') {
          return (
            <View key={`code-${index}`} style={styles.codeBlock}>
              {block.language ? (
                <Text style={styles.codeLanguage}>{block.language}</Text>
              ) : null}
              <Text selectable style={styles.codeText}>
                {block.text}
              </Text>
            </View>
          );
        }

        if (block.type === 'quote') {
          return (
            <View key={`quote-${index}`} style={styles.quote}>
              <Text style={[styles.text, style, styles.quoteText]}>
                {renderInline(block.text, `quote-${index}`)}
              </Text>
            </View>
          );
        }

        if (block.type === 'bulletList') {
          return (
            <View key={`bullet-${index}`} style={styles.list}>
              {block.items.map((item, itemIndex) => (
                <View key={`${item}-${itemIndex}`} style={styles.listItem}>
                  <Text style={[styles.text, style, styles.listMarker]}>
                    {'\\u2022'}
                  </Text>
                  <Text style={[styles.text, style, styles.listText]}>
                    {renderInline(item, `bullet-${index}-${itemIndex}`)}
                  </Text>
                </View>
              ))}
            </View>
          );
        }

        if (block.type === 'orderedList') {
          return (
            <View key={`ordered-${index}`} style={styles.list}>
              {block.items.map((item, itemIndex) => (
                <View
                  key={`${item.marker}-${item.text}-${itemIndex}`}
                  style={styles.listItem}
                >
                  <Text style={[styles.text, style, styles.orderedMarker]}>
                    {item.marker}
                  </Text>
                  <Text style={[styles.text, style, styles.listText]}>
                    {renderInline(item.text, `ordered-${index}-${itemIndex}`)}
                  </Text>
                </View>
              ))}
            </View>
          );
        }

        return (
          <Text key={`paragraph-${index}`} style={[styles.text, style]}>
            {renderInline(block.text, `paragraph-${index}`)}
          </Text>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 8,
  },
  text: {
    ...typography.body,
    color: colors.cardForeground,
    fontWeight: '400',
    lineHeight: 24,
  },
  heading: {
    color: colors.foreground,
    fontSize: 17,
    fontWeight: '800',
    lineHeight: 24,
    marginTop: 2,
  },
  headingLarge: {
    fontSize: 19,
    lineHeight: 26,
  },
  bold: {
    fontWeight: '800',
  },
  italic: {
    fontStyle: 'italic',
  },
  inlineCode: {
    backgroundColor: colors.muted,
    borderRadius: 4,
    color: colors.foreground,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 14,
    paddingHorizontal: 4,
  },
  link: {
    color: colors.primary,
    textDecorationLine: 'underline',
  },
  list: {
    gap: 6,
  },
  listItem: {
    flexDirection: 'row',
    gap: 8,
  },
  listMarker: {
    color: colors.mutedForeground,
    width: 14,
  },
  orderedMarker: {
    color: colors.mutedForeground,
    minWidth: 22,
  },
  listText: {
    flex: 1,
  },
  quote: {
    borderLeftColor: colors.border,
    borderLeftWidth: 3,
    paddingLeft: 10,
  },
  quoteText: {
    color: colors.mutedForeground,
  },
  codeBlock: {
    backgroundColor: '#111827',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  codeLanguage: {
    ...typography.caption,
    color: '#CBD5E1',
    marginBottom: 6,
  },
  codeText: {
    ...typography.caption,
    color: '#F8FAFC',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 13,
    fontWeight: '500',
    lineHeight: 19,
  },
});

export default MarkdownText;
