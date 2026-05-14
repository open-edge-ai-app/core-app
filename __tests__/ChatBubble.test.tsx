import React from 'react';
import ReactTestRenderer from 'react-test-renderer';

import ChatBubble from '../src/components/ChatBubble';

type RenderNode =
  | string
  | {
      children?: RenderNode[] | null;
    }
  | RenderNode[]
  | null;

const collectText = (node: RenderNode): string[] => {
  if (typeof node === 'string') {
    return [node];
  }

  if (Array.isArray(node)) {
    return node.flatMap(collectText);
  }

  if (!node?.children) {
    return [];
  }

  return node.children.flatMap(collectText);
};

describe('ChatBubble', () => {
  it('renders user attachments as separate file cards', async () => {
    let renderer: ReactTestRenderer.ReactTestRenderer | undefined;

    await ReactTestRenderer.act(async () => {
      renderer = ReactTestRenderer.create(
        <ChatBubble
          attachmentFallbackName="첨부 파일"
          attachments={[
            {
              id: 'attachment-1',
              name: 'roadmap.pdf',
              sizeBytes: 153600,
              type: 'file',
              uri: 'file:///tmp/roadmap.pdf',
            },
          ]}
          role="user"
          text="이 문서 요약해줘"
        />,
      );
    });

    const renderedTree = renderer ? renderer.toJSON() : null;
    const visibleText = collectText(renderedTree).join('\n');

    expect(visibleText).toContain('roadmap.pdf');
    expect(visibleText).toContain('FILE / 150.0 KB');
    expect(visibleText).toContain('이 문서 요약해줘');
    expect(visibleText).not.toContain('첨부:');
  });
});
