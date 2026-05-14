import packageJson from '../../package.json';

import { branding } from './branding';

type PackageInfo = {
  dependencies?: Record<string, string>;
  devDependencies?: Record<string, string>;
  version?: string;
};

const packageInfo = packageJson as PackageInfo;
const dependencyVersion = (packageName: string) =>
  packageInfo.dependencies?.[packageName] ??
  packageInfo.devDependencies?.[packageName] ??
  'bundled';

export const repositoryUrl = 'https://github.com/open-edge-ai-app/core-app';

export const appInfo = {
  bundleIdentifier: branding.bundleIdentifier,
  displayName: branding.displayName,
  repositoryName: 'open-edge-ai-app/core-app',
  repositoryUrl,
  version: packageInfo.version ?? '0.0.1',
} as const;

export const openSourcePackages = [
  {
    name: 'React',
    url: 'https://github.com/facebook/react',
    version: dependencyVersion('react'),
  },
  {
    name: 'React Native',
    url: 'https://github.com/facebook/react-native',
    version: dependencyVersion('react-native'),
  },
  {
    name: 'AsyncStorage',
    url: 'https://github.com/react-native-async-storage/async-storage',
    version: dependencyVersion('@react-native-async-storage/async-storage'),
  },
  {
    name: 'Font Awesome',
    url: 'https://github.com/FortAwesome/Font-Awesome',
    version: dependencyVersion('@fortawesome/react-native-fontawesome'),
  },
  {
    name: 'LobeHub Icons',
    url: 'https://github.com/lobehub/lobe-icons',
    version: dependencyVersion('@lobehub/icons-static-png'),
  },
  {
    name: 'React Native SVG',
    url: 'https://github.com/software-mansion/react-native-svg',
    version: dependencyVersion('react-native-svg'),
  },
  {
    name: 'Safe Area Context',
    url: 'https://github.com/AppAndFlow/react-native-safe-area-context',
    version: dependencyVersion('react-native-safe-area-context'),
  },
] as const;

export const contributors = [
  {
    name: 'minjuun05',
    role: 'maintainer',
    url: 'https://github.com/minjuun05',
  },
  {
    name: 'Open Edge AI contributors',
    role: 'community',
    url: `${repositoryUrl}/graphs/contributors`,
  },
] as const;
