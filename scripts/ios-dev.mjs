#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const bundleId = process.env.OPEN_EDGE_AI_BUNDLE_IDENTIFIER ?? 'com.openedgeai';
const scheme = process.env.OPEN_EDGE_AI_IOS_SCHEME ?? 'OpenEdgeAI';
const simulatorName = process.env.OPEN_EDGE_AI_IOS_SIMULATOR;
const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDir, '..');
const iosRoot = resolve(projectRoot, 'ios');
const workspacePath = resolve(iosRoot, 'OpenEdgeAI.xcworkspace');
const derivedDataPath = resolve(iosRoot, 'build');

const command = process.argv[2] ?? 'run';

const run = (
  executable,
  args,
  { allowFailure = false, cwd = projectRoot, stdio = 'inherit' } = {},
) => {
  const result = spawnSync(executable, args, {
    cwd,
    encoding: 'utf8',
    stdio,
  });

  if (!allowFailure && result.status !== 0) {
    const printable = [executable, ...args].join(' ');
    throw new Error(`Command failed: ${printable}`);
  }

  return result;
};

const capture = (executable, args, options = {}) => {
  const result = run(executable, args, {
    ...options,
    stdio: 'pipe',
  });

  return result.stdout?.trim() ?? '';
};

const ensureXcode = () => {
  const developerDir = capture('xcode-select', ['-p']);

  if (!developerDir || developerDir.includes('CommandLineTools')) {
    throw new Error(
      [
        'Xcode is required to build and run the iOS app.',
        `Current developer directory: ${developerDir || 'not configured'}`,
        'Install Xcode, then run:',
        'sudo xcode-select -s /Applications/Xcode.app/Contents/Developer',
      ].join('\n'),
    );
  }

  run('xcrun', ['simctl', 'list', 'devices', 'available'], {
    stdio: 'ignore',
  });
};

const ensurePods = () => {
  const manifestPath = resolve(iosRoot, 'Pods', 'Manifest.lock');

  if (existsSync(manifestPath)) {
    return;
  }

  const bundleCheck = run('bundle', ['check'], {
    allowFailure: true,
    stdio: 'ignore',
  });

  if (bundleCheck.status === 0) {
    run('bundle', ['exec', 'pod', 'install'], { cwd: iosRoot });
    return;
  }

  run('pod', ['install'], { cwd: iosRoot });
};

const bootSimulator = () => {
  const devicesJson = capture('xcrun', [
    'simctl',
    'list',
    'devices',
    'available',
    '-j',
  ]);
  const devices = JSON.parse(devicesJson).devices ?? {};
  const allDevices = Object.values(devices).flat();
  const bootedDevice = allDevices.find(device => device.state === 'Booted');

  if (bootedDevice) {
    return bootedDevice.udid;
  }

  const targetDevice =
    (simulatorName
      ? allDevices.find(device => device.name === simulatorName)
      : undefined) ??
    allDevices.find(device => /^iPhone/.test(device.name)) ??
    allDevices[0];

  if (!targetDevice) {
    throw new Error('No available iOS simulator was found.');
  }

  run('xcrun', ['simctl', 'boot', targetDevice.udid], {
    allowFailure: true,
  });
  run('open', ['-a', 'Simulator'], { allowFailure: true });

  return targetDevice.udid;
};

const runIos = () => {
  const simulatorId = bootSimulator();
  const destination = `platform=iOS Simulator,id=${simulatorId}`;

  run(
    'xcodebuild',
    [
      '-workspace',
      workspacePath,
      '-scheme',
      scheme,
      '-configuration',
      'Debug',
      '-destination',
      destination,
      '-derivedDataPath',
      derivedDataPath,
      'build',
    ],
    { cwd: iosRoot },
  );

  const appPath = resolve(
    derivedDataPath,
    'Build',
    'Products',
    'Debug-iphonesimulator',
    `${scheme}.app`,
  );

  run('xcrun', ['simctl', 'install', simulatorId, appPath]);
  run('xcrun', ['simctl', 'launch', simulatorId, bundleId]);
};

const activate = () => {
  const simulatorId = bootSimulator();
  run('xcrun', ['simctl', 'launch', simulatorId, bundleId]);
};

try {
  ensureXcode();

  if (command === 'pods') {
    ensurePods();
  } else if (command === 'activate') {
    activate();
  } else if (command === 'run') {
    ensurePods();
    runIos();
  } else {
    throw new Error(`Unknown command "${command}". Use run, activate, or pods.`);
  }
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
}
