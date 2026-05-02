import React, {useState} from 'react';
import {
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import ChatBubble, {ChatBubbleRole} from '../components/ChatBubble';
import LoadingDots from '../components/LoadingDots';
import AIEngine from '../native/AIEngine';

type Message = {
  id: string;
  role: ChatBubbleRole;
  text: string;
};

type ChatScreenProps = {
  onOpenSettings: () => void;
};

const initialMessages: Message[] = [
  {
    id: 'welcome',
    role: 'assistant',
    text: '기억조각 On-Da입니다. Kotlin AIEngine 브릿지가 연결되어 있습니다.',
  },
];

function ChatScreen({onOpenSettings}: ChatScreenProps) {
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const sendMessage = async () => {
    const trimmed = input.trim();
    if (!trimmed || isLoading) {
      return;
    }

    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      text: trimmed,
    };

    setInput('');
    setMessages(current => [...current, userMessage]);
    setIsLoading(true);

    try {
      const reply = await AIEngine.sendMessage(trimmed);
      setMessages(current => [
        ...current,
        {
          id: `assistant-${Date.now()}`,
          role: 'assistant',
          text: reply,
        },
      ]);
    } catch (error) {
      setMessages(current => [
        ...current,
        {
          id: `assistant-error-${Date.now()}`,
          role: 'assistant',
          text:
            error instanceof Error
              ? error.message
              : 'AIEngine 호출 중 오류가 발생했습니다.',
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>On-Da</Text>
          <Text style={styles.subtitle}>React Native UI + Kotlin Core</Text>
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={onOpenSettings}
          style={({pressed}) => [styles.iconButton, pressed && styles.pressed]}>
          <Text style={styles.iconButtonText}>⚙</Text>
        </Pressable>
      </View>

      <FlatList
        data={messages}
        keyExtractor={item => item.id}
        renderItem={({item}) => <ChatBubble role={item.role} text={item.text} />}
        contentContainerStyle={styles.messageList}
        ListFooterComponent={isLoading ? <LoadingDots /> : null}
      />

      <View style={styles.composer}>
        <TextInput
          value={input}
          onChangeText={setInput}
          placeholder="AIEngine.sendMessage 테스트"
          placeholderTextColor="#8c8171"
          style={styles.input}
          returnKeyType="send"
          onSubmitEditing={sendMessage}
        />
        <Pressable
          accessibilityRole="button"
          onPress={sendMessage}
          style={({pressed}) => [
            styles.sendButton,
            (!input.trim() || isLoading) && styles.disabled,
            pressed && styles.pressed,
          ]}>
          <Text style={styles.sendButtonText}>Send</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    minHeight: 72,
    paddingHorizontal: 18,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#d8d0c1',
    backgroundColor: '#f7f3ea',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: {
    color: '#191713',
    fontSize: 24,
    fontWeight: '700',
  },
  subtitle: {
    marginTop: 2,
    color: '#6d6254',
    fontSize: 13,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#e8dfd1',
  },
  iconButtonText: {
    fontSize: 18,
    color: '#24211d',
  },
  messageList: {
    padding: 16,
    paddingBottom: 10,
  },
  composer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#d8d0c1',
    backgroundColor: '#fffaf0',
  },
  input: {
    flex: 1,
    minHeight: 44,
    maxHeight: 110,
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#cfc3b1',
    backgroundColor: '#ffffff',
    paddingHorizontal: 12,
    color: '#201d18',
    fontSize: 15,
  },
  sendButton: {
    minWidth: 64,
    height: 44,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#294f46',
  },
  sendButtonText: {
    color: '#ffffff',
    fontWeight: '700',
  },
  disabled: {
    opacity: 0.45,
  },
  pressed: {
    opacity: 0.75,
  },
});

export default ChatScreen;
