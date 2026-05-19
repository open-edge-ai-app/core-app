import { StyleSheet, View } from 'react-native';

import { ScaledText as Text } from '../theme/display';
import { colors, typography } from '../theme/tokens';

export default function TodoListScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Todo List</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 24,
  },
  title: {
    ...typography.title,
    color: colors.foreground,
    fontSize: 28,
    fontWeight: '800',
    lineHeight: 34,
  },
});
