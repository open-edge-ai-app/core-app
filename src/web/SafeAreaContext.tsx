import React from 'react';
import {StyleSheet, View, ViewProps} from 'react-native';

type SafeAreaProviderProps = {
  children: React.ReactNode;
};

export function SafeAreaProvider({children}: SafeAreaProviderProps) {
  return <>{children}</>;
}

export function SafeAreaView({children, style, ...props}: ViewProps) {
  return (
    <View {...props} style={[styles.safeArea, style]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
  },
});
