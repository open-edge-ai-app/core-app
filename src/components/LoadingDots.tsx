import React, { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import { ScaledText as Text } from '../theme/display';
import { colors, typography } from '../theme/tokens';

type LoadingDotsProps = {
  label?: string;
};

const ellipsisFrames = ['.', '..', '...'];

function LoadingDots({ label }: LoadingDotsProps) {
  const [frameIndex, setFrameIndex] = useState(0);

  useEffect(() => {
    const intervalId = setInterval(() => {
      setFrameIndex(currentIndex =>
        currentIndex >= ellipsisFrames.length - 1 ? 0 : currentIndex + 1,
      );
    }, 260);

    return () => clearInterval(intervalId);
  }, []);

  return (
    <View accessibilityLabel="AI response loading" style={styles.container}>
      {label ? (
        <Text style={styles.label}>
          {label}
          {ellipsisFrames[frameIndex]}
        </Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    flexDirection: 'row',
    height: 22,
    paddingHorizontal: 2,
  },
  label: {
    ...typography.caption,
    color: colors.mutedForeground,
    minWidth: 118,
  },
});

export default LoadingDots;
