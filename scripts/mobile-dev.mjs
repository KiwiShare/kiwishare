#!/usr/bin/env node

import { execFileSync, spawnSync } from 'node:child_process';
import os from 'node:os';
import process from 'node:process';

const target = process.argv[2] ?? 'chrome';
const backend = process.argv[3] ?? 'local';
const requestedDeviceId = process.argv[4];

const REMOTE_API =
  process.env.REMOTE_API_URL ?? 'https://kiwishare.onrender.com';

const validTargets = ['chrome', 'android', 'ios-sim', 'ios-device'];
const validBackends = ['local', 'remote'];

function fail(message) {
  console.error(`\n❌ ${message}\n`);
  process.exit(1);
}

if (!validTargets.includes(target)) {
  fail(
    `Unknown target "${target}".\n` +
      `Targets: ${validTargets.join(', ')}`
  );
}

if (!validBackends.includes(backend)) {
  fail(
    `Unknown backend "${backend}".\n` +
      `Backends: ${validBackends.join(', ')}`
  );
}

function getFlutterDevices() {
  try {
    const output = execFileSync(
      'flutter',
      ['devices', '--machine'],
      {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
      }
    );

    return JSON.parse(output);
  } catch (error) {
    fail(
      'Unable to read Flutter devices.\n' +
        'Run "flutter devices" manually to check your Flutter setup.'
    );
  }
}

function getLanIp() {
  // Explicit override is best for unusual environments such as WSL.
  if (process.env.LOCAL_API_HOST) {
    return process.env.LOCAL_API_HOST;
  }

  const interfaces = os.networkInterfaces();
  const candidates = [];

  for (const addresses of Object.values(interfaces)) {
    if (!addresses) continue;

    for (const address of addresses) {
      if (
        address.family === 'IPv4' &&
        !address.internal
      ) {
        candidates.push(address.address);
      }
    }
  }

  // Prefer normal private LAN ranges.
  const preferred = candidates.find(
    (ip) =>
      ip.startsWith('192.168.') ||
      ip.startsWith('10.')
  );

  return preferred ?? candidates[0];
}

function printDevices(devices) {
  console.error('Available matching devices:');

  for (const device of devices) {
    console.error(
      `  ${device.name ?? 'Unknown'} | ${device.id} | ` +
        `${device.targetPlatform ?? 'unknown'} | ` +
        `${device.emulator ? 'emulator' : 'physical'}`
    );
  }
}

function chooseDevice(devices) {
  if (requestedDeviceId) {
    const exact = devices.find(
      (device) => device.id === requestedDeviceId
    );

    if (!exact) {
      printDevices(devices);
      fail(`Device "${requestedDeviceId}" was not found.`);
    }

    return exact;
  }

  if (devices.length === 0) {
    fail(`No ${target} device found.`);
  }

  if (devices.length === 1) {
    return devices[0];
  }

  // For Android, prefer a running emulator if there is exactly one.
  if (target === 'android') {
    const emulators = devices.filter(
      (device) => device.emulator === true
    );

    if (emulators.length === 1) {
      return emulators[0];
    }
  }

  printDevices(devices);

  fail(
    'More than one matching device found.\n' +
      `Specify one explicitly:\n` +
      `pnpm mobile ${target} ${backend} <device-id>`
  );
}

const allDevices = getFlutterDevices();

let matchingDevices;

switch (target) {
  case 'chrome':
    matchingDevices = allDevices.filter(
      (device) => device.id === 'chrome'
    );
    break;

  case 'android':
    matchingDevices = allDevices.filter((device) =>
      String(device.targetPlatform ?? '').startsWith('android')
    );
    break;

  case 'ios-sim':
    if (process.platform !== 'darwin') {
      fail('iOS Simulator requires macOS + Xcode.');
    }

    matchingDevices = allDevices.filter(
      (device) =>
        String(device.targetPlatform ?? '').startsWith('ios') &&
        device.emulator === true
    );
    break;

  case 'ios-device':
    if (process.platform !== 'darwin') {
      fail('Physical iOS development requires macOS + Xcode.');
    }

    matchingDevices = allDevices.filter(
      (device) =>
        String(device.targetPlatform ?? '').startsWith('ios') &&
        device.emulator === false
    );
    break;
}

const device = chooseDevice(matchingDevices);

let apiBaseUrl;

if (backend === 'remote') {
  apiBaseUrl = REMOTE_API;
} else {
  const isPhysicalMobile =
    (target === 'ios-device') ||
    (target === 'android' && device.emulator === false);

  if (isPhysicalMobile) {
    const lanIp = getLanIp();

    if (!lanIp) {
      fail(
        'Could not determine the computer LAN IP.\n' +
          'Set it manually, for example:\n' +
          'LOCAL_API_HOST=192.168.1.10 pnpm dev:ios'
      );
    }

    apiBaseUrl = `http://${lanIp}:3000`;
  } else {
    // ApiConfig handles:
    // Chrome       -> localhost:3000
    // Android emu  -> 10.0.2.2:3000
    // iOS Simulator-> localhost:3000
    apiBaseUrl = 'local';
  }
}

console.log('');
console.log('🚀 KiwiShare Flutter');
console.log(`   Target : ${target}`);
console.log(`   Device : ${device.name} (${device.id})`);
console.log(`   Backend: ${backend}`);
console.log(`   API    : ${apiBaseUrl}`);
console.log('');

const result = spawnSync(
  'flutter',
  [
    'run',
    '-d',
    device.id,
    `--dart-define=API_BASE_URL=${apiBaseUrl}`,
  ],
  {
    cwd: new URL('../mobile/', import.meta.url),
    stdio: 'inherit',
    shell: false,
  }
);

if (result.error) {
  fail(result.error.message);
}

process.exit(result.status ?? 1);