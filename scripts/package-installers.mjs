#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
} from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDir, '..');
const androidRoot = resolve(projectRoot, 'android');
const iosRoot = resolve(projectRoot, 'ios');
const packageJson = JSON.parse(
  readFileSync(resolve(projectRoot, 'package.json'), 'utf8'),
);
const appSlug = packageJson.name ?? 'open-edge-ai';
const appVersion = packageJson.version ?? '0.0.0';
const artifactRoot = resolve(projectRoot, 'dist', 'installers');
const target = process.argv[2] ?? 'all';
const shouldSkipBuild = process.env.OPEN_EDGE_SKIP_BUILD === '1';
const gradleWrapper = process.platform === 'win32' ? 'gradlew.bat' : './gradlew';
const iosScheme = process.env.OPEN_EDGE_AI_IOS_SCHEME ?? 'OpenEdgeAI';
const iosWorkspacePath = resolve(iosRoot, 'OpenEdgeAI.xcworkspace');
const iosDerivedDataPath = resolve(iosRoot, 'build');

function run(executable, args, options = {}) {
  const result = spawnSync(executable, args, {
    cwd: options.cwd ?? projectRoot,
    encoding: 'utf8',
    stdio: options.stdio ?? 'inherit',
  });

  if (result.status !== 0) {
    throw new Error(`Command failed: ${[executable, ...args].join(' ')}`);
  }

  return result;
}

function capture(executable, args, options = {}) {
  const result = run(executable, args, { ...options, stdio: 'pipe' });
  return result.stdout?.trim() ?? '';
}

function ensureArtifactRoot() {
  mkdirSync(artifactRoot, { recursive: true });
}

function cleanTargetArtifacts(prefix) {
  ensureArtifactRoot();
  for (const entry of readdirSync(artifactRoot)) {
    if (entry.startsWith(prefix)) {
      rmSync(resolve(artifactRoot, entry), { force: true, recursive: true });
    }
  }
}

function collectFiles(directory, predicate) {
  if (!existsSync(directory)) {
    return [];
  }

  const entries = readdirSync(directory)
    .map(entry => resolve(directory, entry))
    .sort();
  const files = [];

  for (const entry of entries) {
    const stats = statSync(entry);
    if (stats.isDirectory()) {
      files.push(...collectFiles(entry, predicate));
    } else if (predicate(entry)) {
      files.push(entry);
    }
  }

  return files;
}

function packageAndroidApks() {
  const prefix = `${appSlug}-android-`;
  cleanTargetArtifacts(prefix);

  if (!shouldSkipBuild) {
    run(gradleWrapper, [':app:assembleDebug', '--console=plain'], {
      cwd: androidRoot,
    });
  }

  const apkRoot = resolve(androidRoot, 'app', 'build', 'outputs', 'apk', 'debug');
  const apkPaths = collectFiles(apkRoot, filePath => filePath.endsWith('.apk'));
  if (apkPaths.length === 0) {
    throw new Error(`No Android APK files were found under ${apkRoot}`);
  }

  return apkPaths.map(apkPath => {
    const variant = basename(apkPath)
      .replace(/^app-/, '')
      .replace(/-debug\.apk$/, '')
      .replace(/\.apk$/, '');
    const artifactName = `${appSlug}-android-debug-${variant}-${appVersion}.apk`;
    const artifactPath = resolve(artifactRoot, artifactName);
    copyFileSync(apkPath, artifactPath);
    return artifactPath;
  });
}

function ensureXcode() {
  const developerDir = capture('xcode-select', ['-p']);
  if (!developerDir || developerDir.includes('CommandLineTools')) {
    throw new Error(
      [
        'Xcode is required to build the iOS simulator app.',
        `Current developer directory: ${developerDir || 'not configured'}`,
        'Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer',
      ].join('\n'),
    );
  }
}

function packageIosSimulatorApp() {
  const prefix = `${appSlug}-ios-simulator-`;
  cleanTargetArtifacts(prefix);
  ensureXcode();

  if (!shouldSkipBuild) {
    run(
      'xcodebuild',
      [
        '-workspace',
        iosWorkspacePath,
        '-scheme',
        iosScheme,
        '-configuration',
        'Debug',
        '-sdk',
        'iphonesimulator',
        '-derivedDataPath',
        iosDerivedDataPath,
        'build',
      ],
      { cwd: iosRoot },
    );
  }

  const appPath = resolve(
    iosDerivedDataPath,
    'Build',
    'Products',
    'Debug-iphonesimulator',
    `${iosScheme}.app`,
  );
  if (!existsSync(appPath)) {
    throw new Error(`No iOS simulator app was found at ${appPath}`);
  }

  const artifactPath = resolve(
    artifactRoot,
    `${appSlug}-ios-simulator-${appVersion}.app.zip`,
  );
  run('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', appPath, artifactPath]);
  return [artifactPath];
}

function printArtifacts(artifacts) {
  console.log('\nCreated installable artifacts:');
  for (const artifact of artifacts) {
    console.log(`- ${artifact}`);
  }
}

try {
  if (!['all', 'android', 'ios'].includes(target)) {
    throw new Error('Usage: node scripts/package-installers.mjs [all|android|ios]');
  }

  ensureArtifactRoot();
  const artifacts = [];
  if (target === 'all' || target === 'android') {
    artifacts.push(...packageAndroidApks());
  }
  if (target === 'all' || target === 'ios') {
    artifacts.push(...packageIosSimulatorApp());
  }

  printArtifacts(artifacts);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
}
