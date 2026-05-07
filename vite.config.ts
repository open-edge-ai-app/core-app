import react from '@vitejs/plugin-react';
import {defineConfig} from 'vite';

const safeAreaContextWeb = new URL(
  './src/web/SafeAreaContext.tsx',
  import.meta.url,
).pathname;
const reactNativeSvgWeb = new URL(
  './src/web/ReactNativeSvg.tsx',
  import.meta.url,
).pathname;

export default defineConfig({
  define: {
    __DEV__: JSON.stringify(true),
  },
  optimizeDeps: {
    exclude: ['react-native-svg'],
  },
  plugins: [react()],
  resolve: {
    alias: [
      {find: /^react-native$/, replacement: 'react-native-web'},
      {find: /^react-native-svg$/, replacement: reactNativeSvgWeb},
      {
        find: /^react-native-safe-area-context$/,
        replacement: safeAreaContextWeb,
      },
    ],
    extensions: [
      '.web.tsx',
      '.web.ts',
      '.web.jsx',
      '.web.js',
      '.tsx',
      '.ts',
      '.jsx',
      '.js',
      '.json',
    ],
  },
});
