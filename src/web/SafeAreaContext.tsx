import React from 'react';
import {StyleSheet, View, ViewProps} from 'react-native';

type SafeAreaProviderProps = {
  children: React.ReactNode;
};

type Edge = 'top' | 'right' | 'bottom' | 'left';
type SafeAreaViewProps = ViewProps & {
  edges?: Edge[];
};

export function SafeAreaProvider({children}: SafeAreaProviderProps) {
  return <>{children}</>;
}

export function SafeAreaView({children, edges: _edges, style, ...props}: SafeAreaViewProps) {
  return (
    <View {...props} style={[styles.safeArea, style]}>
      {children}
    </View>
  );
}

export function useSafeAreaInsets() {
  return {bottom: 0, left: 0, right: 0, top: 0};
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
  },
});
