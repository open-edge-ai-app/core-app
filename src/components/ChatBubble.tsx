import React from 'react';
import {StyleSheet, Text, View} from 'react-native';

export type ChatBubbleRole = 'user' | 'assistant';

type ChatBubbleProps = {
  role: ChatBubbleRole;
  text: string;
};

function ChatBubble({role, text}: ChatBubbleProps) {
  const isUser = role === 'user';

  return (
    <View style={[styles.row, isUser && styles.userRow]}>
      <View style={[styles.bubble, isUser ? styles.userBubble : styles.aiBubble]}>
        <Text style={[styles.message, isUser && styles.userMessage]}>{text}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    width: '100%',
    marginVertical: 5,
    alignItems: 'flex-start',
  },
  userRow: {
    alignItems: 'flex-end',
  },
  bubble: {
    maxWidth: '82%',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  aiBubble: {
    backgroundColor: '#ffffff',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#d9d1c3',
  },
  userBubble: {
    backgroundColor: '#294f46',
  },
  message: {
    color: '#25211b',
    fontSize: 15,
    lineHeight: 22,
  },
  userMessage: {
    color: '#ffffff',
  },
});

export default ChatBubble;
