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
      <View style={styles.dots}>
        {ellipsisFrames.map((_, index) => {
          const isActive = index === frameIndex;

          return (
            <View
              key={index}
              style={[
                styles.dot,
                isActive ? styles.dotActive : styles.dotIdle,
              ]}
            />
          );
        })}
      </View>
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
    gap: 7,
    height: 22,
    paddingHorizontal: 2,
  },
  dots: {
    alignItems: 'center',
    flexDirection: 'row',
  },
  dot: {
    backgroundColor: colors.primary,
    borderRadius: 4,
    height: 8,
    marginHorizontal: 3,
    width: 8,
  },
  dotActive: {
    opacity: 1,
    transform: [{ scale: 1.18 }, { translateY: -3 }],
  },
  dotIdle: {
    opacity: 0.34,
    transform: [{ scale: 0.76 }, { translateY: 1 }],
  },
  label: {
    ...typography.caption,
    color: colors.mutedForeground,
    minWidth: 118,
  },
});

export default LoadingDots;
