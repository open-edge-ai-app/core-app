import React, {useEffect, useRef} from 'react';
import {Animated, StyleSheet, View} from 'react-native';

function LoadingDots() {
  const values = useRef([0, 1, 2].map(() => new Animated.Value(0.35))).current;

  useEffect(() => {
    const animations = values.map((value, index) =>
      Animated.loop(
        Animated.sequence([
          Animated.delay(index * 120),
          Animated.timing(value, {
            toValue: 1,
            duration: 260,
            useNativeDriver: true,
          }),
          Animated.timing(value, {
            toValue: 0.35,
            duration: 260,
            useNativeDriver: true,
          }),
        ]),
      ),
    );

    animations.forEach(animation => animation.start());
    return () => animations.forEach(animation => animation.stop());
  }, [values]);

  return (
    <View style={styles.container} accessibilityLabel="AI response loading">
      {values.map((value, index) => (
        <Animated.View key={index} style={[styles.dot, {opacity: value}]} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 2,
    paddingVertical: 3,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: '#6d6254',
  },
});

export default LoadingDots;
