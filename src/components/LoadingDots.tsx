import React, { useEffect, useRef, useState } from 'react';
import { Animated, StyleSheet, View } from 'react-native';

import { ScaledText as Text } from '../theme/display';
import { colors, typography } from '../theme/tokens';

type LoadingDotsProps = {
  label?: string;
};

const ellipsisFrames = ['.', '..', '...'];

function LoadingDots({ label }: LoadingDotsProps) {
  const [ellipsisIndex, setEllipsisIndex] = useState(0);
  const dotValues = useRef([
    new Animated.Value(0.3),
    new Animated.Value(0.3),
    new Animated.Value(0.3),
  ]).current;

  useEffect(() => {
    if (!label) {
      return undefined;
    }

    const intervalId = setInterval(() => {
      setEllipsisIndex(currentIndex =>
        currentIndex >= ellipsisFrames.length - 1 ? 0 : currentIndex + 1,
      );
    }, 360);

    return () => clearInterval(intervalId);
  }, [label]);

  useEffect(() => {
    const animations = dotValues.map(value =>
      Animated.sequence([
        Animated.timing(value, {
          duration: 280,
          toValue: 1,
          useNativeDriver: true,
        }),
        Animated.timing(value, {
          duration: 280,
          toValue: 0.3,
          useNativeDriver: true,
        }),
      ]),
    );
    const loop = Animated.loop(Animated.stagger(140, animations));

    loop.start();

    return () => loop.stop();
  }, [dotValues]);

  return (
    <View accessibilityLabel="AI response loading" style={styles.container}>
      <View style={styles.dots}>
        {dotValues.map((value, index) => (
          <Animated.View
            key={index}
            style={[
              styles.dot,
              {
                opacity: value,
                transform: [
                  {
                    scale: value.interpolate({
                      inputRange: [0.3, 1],
                      outputRange: [0.76, 1],
                    }),
                  },
                  {
                    translateY: value.interpolate({
                      inputRange: [0.3, 1],
                      outputRange: [1.5, -2],
                    }),
                  },
                ],
              },
            ]}
          />
        ))}
      </View>
      {label ? (
        <Text style={styles.label}>
          {label}
          {ellipsisFrames[ellipsisIndex]}
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
  label: {
    ...typography.caption,
    color: colors.mutedForeground,
    minWidth: 118,
  },
});

export default LoadingDots;
