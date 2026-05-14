import {
  hydrateMessages,
  hydrateStoredChatMessages,
  mergeSessionLists,
  serializeMessages,
  shouldUseNativeMessages,
  toStoredChatMessages,
} from '../src/state/chatStorage';
import { ChatMessage } from '../src/screens/ChatScreen';

const messages: ChatMessage[] = [
  {
    createdAt: new Date('2026-05-13T00:00:00.000Z'),
    id: 'user-1',
    role: 'user',
    text: 'hello',
  },
  {
    createdAt: new Date('2026-05-13T00:01:00.000Z'),
    id: 'assistant-1',
    modelName: 'Gemma 4',
    role: 'assistant',
    text: 'hi',
  },
];

test('serializes and hydrates app chat messages', () => {
  const hydrated = hydrateMessages(serializeMessages(messages));

  expect(hydrated).toEqual(messages);
});

test('converts between native stored messages and chat messages', () => {
  const storedMessages = toStoredChatMessages(messages);

  expect(hydrateStoredChatMessages(storedMessages)).toEqual(messages);
});

test('keeps local messages unless native has more complete content', () => {
  expect(shouldUseNativeMessages(messages, messages.slice(0, 1))).toBe(false);
  expect(
    shouldUseNativeMessages(messages.slice(0, 1), [
      ...messages,
      {
        createdAt: new Date('2026-05-13T00:02:00.000Z'),
        id: 'assistant-2',
        role: 'assistant',
        text: 'more context',
      },
    ]),
  ).toBe(true);
});

test('merges sessions without duplicating ids', () => {
  expect(
    mergeSessionLists(
      [
        { id: 'a', title: 'A' },
        { id: 'b', title: 'B' },
      ],
      [
        { id: 'b', title: 'Native B' },
        { id: 'c', title: 'C' },
      ],
    ),
  ).toEqual([
    { id: 'a', title: 'A' },
    { id: 'b', title: 'B' },
    { id: 'c', title: 'C' },
  ]);
});
