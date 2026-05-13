#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

const repoPath = (...segments) => path.join(rootDir, ...segments);

const readText = filePath => fs.readFileSync(filePath, 'utf8');
const writeText = (filePath, value) => fs.writeFileSync(filePath, value);

const parseEnvFile = filePath => {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  return readText(filePath)
    .split(/\r?\n/)
    .reduce((env, line) => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) {
        return env;
      }

      const separatorIndex = trimmed.indexOf('=');
      if (separatorIndex === -1) {
        return env;
      }

      const key = trimmed.slice(0, separatorIndex).trim();
      const rawValue = trimmed.slice(separatorIndex + 1).trim();
      const value = rawValue.replace(/^['"]|['"]$/g, '');

      return {
        ...env,
        [key]: value,
      };
    }, {});
};

const env = {
  ...parseEnvFile(repoPath('.env')),
  ...process.env,
};

const getEnv = (key, fallback) => {
  const value = env[key];
  return value == null || value.trim() === '' ? fallback : value.trim();
};

const resolveOptionalPath = value => {
  if (!value) {
    return null;
  }

  return path.isAbsolute(value) ? value : repoPath(value);
};

const escapeTsString = value =>
  value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");

const branding = {
  androidAppName: getEnv('OPEN_EDGE_AI_ANDROID_APP_NAME', 'OpenEdgeAI'),
  appRegistryName: getEnv('OPEN_EDGE_AI_APP_NAME', 'OpenEdgeAI'),
  bundleIdentifier: getEnv('OPEN_EDGE_AI_BUNDLE_IDENTIFIER', 'com.openedgeai'),
  displayName: getEnv('OPEN_EDGE_AI_DISPLAY_NAME', 'Open Edge AI'),
  iosDisplayName: getEnv('OPEN_EDGE_AI_IOS_DISPLAY_NAME', 'OpenEdgeAI'),
  productName: getEnv('OPEN_EDGE_AI_PRODUCT_NAME', 'Open Edge AI'),
  webTitle: getEnv('OPEN_EDGE_AI_WEB_TITLE', 'Open Edge AI'),
};

const copyFileIfConfigured = (sourceValue, targetPath) => {
  const sourcePath = resolveOptionalPath(sourceValue);
  if (!sourcePath) {
    return false;
  }

  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Configured branding asset was not found: ${sourcePath}`);
  }

  fs.copyFileSync(sourcePath, targetPath);
  return true;
};

const copyDirectoryIfConfigured = (sourceValue, targetPath) => {
  const sourcePath = resolveOptionalPath(sourceValue);
  if (!sourcePath) {
    return false;
  }

  if (!fs.existsSync(sourcePath) || !fs.statSync(sourcePath).isDirectory()) {
    throw new Error(
      `Configured branding directory was not found: ${sourcePath}`,
    );
  }

  fs.cpSync(sourcePath, targetPath, {
    filter: source => path.basename(source) !== '.DS_Store',
    recursive: true,
  });
  return true;
};

const writeBrandingConfig = () => {
  const configPath = repoPath('src/config/branding.ts');
  const content = `import type { ImageSourcePropType } from 'react-native';

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
  androidAppName: '${escapeTsString(branding.androidAppName)}',
  appRegistryName: '${escapeTsString(branding.appRegistryName)}',
  bundleIdentifier: '${escapeTsString(branding.bundleIdentifier)}',
  displayName: '${escapeTsString(branding.displayName)}',
  iosDisplayName: '${escapeTsString(branding.iosDisplayName)}',
  logo: logoSource,
  productName: '${escapeTsString(branding.productName)}',
  webTitle: '${escapeTsString(branding.webTitle)}',
};

export const brandAssets = {
  logo: logoSource,
} as const;
`;

  writeText(configPath, content);
};

const updateAppJson = () => {
  const appJsonPath = repoPath('app.json');
  const appConfig = JSON.parse(readText(appJsonPath));
  appConfig.name = branding.appRegistryName;
  appConfig.displayName = branding.displayName;
  writeText(appJsonPath, `${JSON.stringify(appConfig, null, 2)}\n`);
};

const updateIndexHtml = () => {
  const indexPath = repoPath('index.html');
  const html = readText(indexPath).replace(
    /<title>.*?<\/title>/,
    `<title>${branding.webTitle}</title>`,
  );
  writeText(indexPath, html);
};

const updateAndroidStrings = () => {
  const stringsPath = repoPath('android/app/src/main/res/values/strings.xml');
  const strings = readText(stringsPath).replace(
    /<string name="app_name">.*?<\/string>/,
    `<string name="app_name">${branding.androidAppName}</string>`,
  );
  writeText(stringsPath, strings);
};

const updateAndroidBuild = () => {
  const buildPath = repoPath('android/app/build.gradle');
  const buildFile = readText(buildPath).replace(
    /applicationId ".*?"/,
    `applicationId "${branding.bundleIdentifier}"`,
  );
  writeText(buildPath, buildFile);
};

const updateAndroidMainActivity = () => {
  const activityPath = repoPath(
    'android/app/src/main/java/com/openedgeai/MainActivity.kt',
  );
  const activity = readText(activityPath).replace(
    /getMainComponentName\(\): String = ".*?"/,
    `getMainComponentName(): String = "${branding.appRegistryName}"`,
  );
  writeText(activityPath, activity);
};

const replacePlistValue = (plist, key, value) => {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(
    `(<key>${escapedKey}<\\/key>\\s*<string>)(.*?)(<\\/string>)`,
    's',
  );
  return plist.replace(pattern, `$1${value}$3`);
};

const updateIosInfo = () => {
  const plistPath = repoPath('ios/OpenEdgeAI/Info.plist');
  const plist = replacePlistValue(
    readText(plistPath),
    'CFBundleDisplayName',
    branding.iosDisplayName,
  );
  writeText(plistPath, plist);
};

const updateIosProject = () => {
  const projectPath = repoPath('ios/OpenEdgeAI.xcodeproj/project.pbxproj');
  const project = readText(projectPath).replace(
    /PRODUCT_BUNDLE_IDENTIFIER = ".*?";/g,
    `PRODUCT_BUNDLE_IDENTIFIER = "${branding.bundleIdentifier}";`,
  );
  writeText(projectPath, project);
};

const updateIosAppDelegate = () => {
  const appDelegatePath = repoPath('ios/OpenEdgeAI/AppDelegate.swift');
  const appDelegate = readText(appDelegatePath).replace(
    /withModuleName: ".*?"/,
    `withModuleName: "${branding.appRegistryName}"`,
  );
  writeText(appDelegatePath, appDelegate);
};

const updateLaunchScreen = () => {
  const launchScreenPath = repoPath('ios/OpenEdgeAI/LaunchScreen.storyboard');
  const storyboard = readText(launchScreenPath).replace(
    /text="[^"]*"/,
    `text="${branding.iosDisplayName}"`,
  );
  writeText(launchScreenPath, storyboard);
};

writeBrandingConfig();
updateAppJson();
updateIndexHtml();
updateAndroidStrings();
updateAndroidBuild();
updateAndroidMainActivity();
updateIosInfo();
updateIosProject();
updateIosAppDelegate();
updateLaunchScreen();

const copiedAssets = [
  copyFileIfConfigured(
    env.OPEN_EDGE_AI_LOGO_SOURCE,
    repoPath('src/assets/logo.png'),
  )
    ? 'src/assets/logo.png'
    : null,
  copyFileIfConfigured(
    env.OPEN_EDGE_AI_README_LOGO_SOURCE,
    repoPath('docs/assets/open-edge-ai-logo.png'),
  )
    ? 'docs/assets/open-edge-ai-logo.png'
    : null,
  copyDirectoryIfConfigured(
    env.OPEN_EDGE_AI_ANDROID_ICON_DIR,
    repoPath('android/app/src/main/res'),
  )
    ? 'android/app/src/main/res'
    : null,
  copyDirectoryIfConfigured(
    env.OPEN_EDGE_AI_IOS_ICON_DIR,
    repoPath('ios/OpenEdgeAI/Images.xcassets/AppIcon.appiconset'),
  )
    ? 'ios/OpenEdgeAI/Images.xcassets/AppIcon.appiconset'
    : null,
].filter(Boolean);

console.log('Branding applied.');
console.log(`- App registry name: ${branding.appRegistryName}`);
console.log(`- Display name: ${branding.displayName}`);
console.log(`- Bundle identifier: ${branding.bundleIdentifier}`);
if (copiedAssets.length > 0) {
  console.log(`- Updated assets: ${copiedAssets.join(', ')}`);
}
