import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';

function LoadingDots() {
  const opacities = useRef([
    new Animated.Value(0.3),
    new Animated.Value(0.3),
    new Animated.Value(0.3),
  ]).current;

  useEffect(() => {
    const animations = opacities.map(opacity =>
      Animated.sequence([
        Animated.timing(opacity, {
          duration: 280,
          toValue: 1,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          duration: 280,
          toValue: 0.3,
          useNativeDriver: true,
        }),
      ]),
    );
    const loop = Animated.loop(Animated.stagger(140, animations));

    loop.start();

    return () => loop.stop();
  }, [opacities]);

  return (
    <View accessibilityLabel="AI response loading" style={styles.container}>
      {opacities.map((opacity, index) => (
        <Animated.View key={index} style={[styles.dot, { opacity }]} />
      ))}
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
  dot: {
    backgroundColor: '#007AFF',
    borderRadius: 4,
    height: 8,
    marginHorizontal: 3,
    width: 8,
  },
});

export default LoadingDots;
