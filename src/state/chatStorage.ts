import AIEngine, {
  StoredChatMessage,
  StoredChatSession,
} from '../native/AIEngine';
import {
  ChatMessage,
  createInitialChatMessages,
} from '../screens/ChatScreen';

export type ChatSession = {
  id: string;
  pinned?: boolean;
  title: string;
  workFolderId?: string;
};

export type PersistedChatMessage = Omit<ChatMessage, 'createdAt'> & {
  createdAt: string;
};

export type NativeChatSessionSnapshot = {
  messages: ChatMessage[];
  session: ChatSession;
};

export const serializeMessages = (
  messages: ChatMessage[],
): PersistedChatMessage[] =>
  messages.map(message => ({
    ...message,
    createdAt: message.createdAt.toISOString(),
  }));

export const hydrateMessages = (
  messages: PersistedChatMessage[] | undefined,
): ChatMessage[] => {
  if (!Array.isArray(messages) || messages.length === 0) {
    return createInitialChatMessages();
  }

  return messages.map(message => {
    const createdAt = new Date(message.createdAt);

    return {
      ...message,
      createdAt: Number.isNaN(createdAt.getTime()) ? new Date() : createdAt,
    };
  });
};

const isChatMessageRole = (role: string): role is ChatMessage['role'] =>
  role === 'assistant' || role === 'user' || role === 'system';

export const hydrateStoredChatMessages = (
  messages: StoredChatMessage[] | undefined,
): ChatMessage[] => {
  if (!Array.isArray(messages) || messages.length === 0) {
    return createInitialChatMessages();
  }

  return messages.map(message => {
    const createdAt = new Date(message.createdAt);

    return {
      createdAt: Number.isNaN(createdAt.getTime()) ? new Date() : createdAt,
      id: message.id,
      modelName: message.modelName ?? undefined,
      role: isChatMessageRole(message.role) ? message.role : 'user',
      text: message.text,
    };
  });
};

export const toStoredChatMessages = (
  messages: ChatMessage[],
): StoredChatMessage[] =>
  messages.map(message => ({
    createdAt: message.createdAt.getTime(),
    id: message.id,
    modelName: message.modelName,
    role: message.role,
    text: message.text,
  }));

const getConversationContentWeight = (messages: ChatMessage[] | undefined) =>
  messages
    ?.filter(message => message.id !== 'welcome')
    .reduce((total, message) => total + message.text.trim().length, 0) ?? 0;

export const shouldUseNativeMessages = (
  currentMessages: ChatMessage[] | undefined,
  nativeMessages: ChatMessage[],
) => {
  if (!currentMessages) {
    return true;
  }

  return (
    getConversationContentWeight(nativeMessages) >
    getConversationContentWeight(currentMessages)
  );
};

export const loadNativeChatSnapshots = async (): Promise<
  NativeChatSessionSnapshot[]
> => {
  const nativeSessions = await AIEngine.listChatSessions().catch(() => []);
  const loadedSessions = await Promise.all(
    nativeSessions.map(session =>
      AIEngine.loadChatSession(session.id).catch(() => null),
    ),
  );

  return loadedSessions
    .filter((session): session is StoredChatSession => session != null)
    .map(session => ({
      messages: hydrateStoredChatMessages(session.messages),
      session: {
        id: session.chat.id,
        title: session.chat.title,
      },
    }));
};

export const mergeSessionLists = (
  primary: ChatSession[],
  secondary: ChatSession[],
): ChatSession[] => {
  const seenSessionIds = new Set<string>();

  return [...primary, ...secondary].filter(session => {
    if (seenSessionIds.has(session.id)) {
      return false;
    }

    seenSessionIds.add(session.id);
    return true;
  });
};
