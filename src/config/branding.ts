import type { ImageSourcePropType } from 'react-native';

import logoSource from '../assets/logo.png';

export type BrandingConfig = {
  androidAppName: string;
  appRegistryName: string;
  bundleIdentifier: string;
  displayName: string;
  iosDisplayName: string;
  logo: ImageSourcePropType;
  productName: string;
  webTitle: string;
};

export const branding: BrandingConfig = {
  androidAppName: 'Kepler',
  appRegistryName: 'OpenEdgeAI',
  bundleIdentifier: 'com.openedgeai',
  displayName: 'Kepler',
  iosDisplayName: 'Kepler',
  logo: logoSource,
  productName: 'Kepler',
  webTitle: 'Kepler',
};

export const brandAssets = {
  logo: logoSource,
} as const;
