#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const appId = 'com.openedgeai';
const activity = `${appId}/.MainActivity`;
const defaultMetroPort = process.env.OPEN_EDGE_METRO_PORT ?? '8082';
const deviceMetroPort = '8081';
const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDir, '..');
const androidRoot = resolve(projectRoot, 'android');
const gradleWrapper = process.platform === 'win32' ? 'gradlew.bat' : './gradlew';

const command = process.argv[2] ?? 'install';

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

  return result.stdout ?? '';
};

const getDeviceSerial = () => {
  const output = capture('adb', ['devices']);
  const deviceLine = output
    .split('\n')
    .map(line => line.trim())
    .find(line => line.endsWith('\tdevice'));

  if (!deviceLine) {
    throw new Error('No Android device or emulator is connected.');
  }

  return deviceLine.split(/\s+/)[0];
};

const ensureReverse = serial => {
  run('adb', ['-s', serial, 'reverse', '--remove', `tcp:${deviceMetroPort}`], {
    allowFailure: true,
    stdio: 'ignore',
  });
  run('adb', [
    '-s',
    serial,
    'reverse',
    `tcp:${deviceMetroPort}`,
    `tcp:${defaultMetroPort}`,
  ]);
};

const startActivity = serial => {
  run('adb', ['-s', serial, 'shell', 'am', 'force-stop', appId]);
  run('adb', ['-s', serial, 'shell', 'am', 'start', '-n', activity]);
};

const installDebug = () => {
  run(gradleWrapper, [':app:installDebug', '--console=plain'], {
    cwd: androidRoot,
  });
};

try {
  const serial = getDeviceSerial();

  if (command === 'reverse') {
    ensureReverse(serial);
  } else if (command === 'activate') {
    ensureReverse(serial);
    startActivity(serial);
  } else if (command === 'install') {
    installDebug();
    ensureReverse(serial);
    startActivity(serial);
  } else {
    throw new Error(
      `Unknown command "${command}". Use install, activate, or reverse.`,
    );
  }
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
}
