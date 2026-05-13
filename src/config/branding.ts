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
  androidAppName: 'OpenEdgeAI',
  appRegistryName: 'OpenEdgeAI',
  bundleIdentifier: 'com.openedgeai',
  displayName: 'Open Edge AI',
  iosDisplayName: 'OpenEdgeAI',
  logo: logoSource,
  productName: 'Open Edge AI',
  webTitle: 'Open Edge AI',
};

export const brandAssets = {
  logo: logoSource,
} as const;
