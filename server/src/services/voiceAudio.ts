import { spawn } from 'child_process';
import { mkdtemp, rm, writeFile } from 'fs/promises';
import os from 'os';
import path from 'path';
import ffmpegPath from 'ffmpeg-static';

export interface VerifiedVoiceAudio {
  contentType: 'audio/mp4' | 'audio/aac';
  extension: 'm4a' | 'aac';
  durationMs: number;
}

const AAC_SAMPLE_RATES = [
  96000, 88200, 64000, 48000, 44100, 32000, 24000,
  22050, 16000, 12000, 11025, 8000, 7350
];

const DECODE_SAMPLE_RATE = 8000;
const DECODE_BYTES_PER_SAMPLE = 2;
const MAX_CONCURRENT_DECODERS = 2;
const MAX_DECODERS_PER_USER = 1;
const MAX_PROBES_PER_USER_PER_MINUTE = 10;
let activeDecoders = 0;
const activeDecodersByUser = new Map<string, number>();
const probeWindowsByUser = new Map<string, { count: number; resetAt: number }>();

function acceptsProbe(userId?: string): boolean {
  if (!userId) return true;
  const now = Date.now();
  const window = probeWindowsByUser.get(userId);
  if (!window || now >= window.resetAt) {
    probeWindowsByUser.set(userId, { count: 1, resetAt: now + 60000 });
    return true;
  }
  if (window.count >= MAX_PROBES_PER_USER_PER_MINUTE) return false;
  window.count += 1;
  return true;
}

function acquireDecoder(userId?: string): (() => void) | null {
  const userDecoders = userId ? activeDecodersByUser.get(userId) ?? 0 : 0;
  if (
    activeDecoders >= MAX_CONCURRENT_DECODERS ||
    (userId != null && userDecoders >= MAX_DECODERS_PER_USER)
  ) {
    return null;
  }

  activeDecoders += 1;
  if (userId) activeDecodersByUser.set(userId, userDecoders + 1);
  let released = false;
  return () => {
    if (released) return;
    released = true;
    activeDecoders -= 1;
    if (!userId) return;
    const remaining = (activeDecodersByUser.get(userId) ?? 1) - 1;
    if (remaining > 0) activeDecodersByUser.set(userId, remaining);
    else activeDecodersByUser.delete(userId);
  };
}

function boxType(bytes: Buffer, offset: number): string {
  return bytes.toString('ascii', offset + 4, offset + 8);
}

function findBoxes(
  bytes: Buffer,
  start: number,
  end: number,
  wantedType: string
): Array<{ start: number; end: number; dataStart: number }> {
  const matches: Array<{ start: number; end: number; dataStart: number }> = [];
  let offset = start;
  while (offset + 8 <= end) {
    let size = bytes.readUInt32BE(offset);
    let headerSize = 8;
    if (size === 1) {
      if (offset + 16 > end) break;
      const extended = bytes.readBigUInt64BE(offset + 8);
      if (extended > BigInt(Number.MAX_SAFE_INTEGER)) break;
      size = Number(extended);
      headerSize = 16;
    } else if (size === 0) {
      size = end - offset;
    }
    if (size < headerSize || offset + size > end) break;
    if (boxType(bytes, offset) === wantedType) {
      matches.push({ start: offset, end: offset + size, dataStart: offset + headerSize });
    }
    offset += size;
  }
  return matches;
}

function inspectMp4(bytes: Buffer): VerifiedVoiceAudio | null {
  const topLevelEnd = bytes.length;
  if (findBoxes(bytes, 0, topLevelEnd, 'ftyp').length === 0) return null;
  const moov = findBoxes(bytes, 0, topLevelEnd, 'moov')[0];
  const mdat = findBoxes(bytes, 0, topLevelEnd, 'mdat')[0];
  if (!moov || !mdat || mdat.end <= mdat.dataStart) return null;

  const mvhd = findBoxes(bytes, moov.dataStart, moov.end, 'mvhd')[0];
  const tracks = findBoxes(bytes, moov.dataStart, moov.end, 'trak');
  if (!mvhd || tracks.length === 0) return null;

  const hasAudioTrack = tracks.some((track) => {
    const mdia = findBoxes(bytes, track.dataStart, track.end, 'mdia')[0];
    if (!mdia) return false;
    const handler = findBoxes(bytes, mdia.dataStart, mdia.end, 'hdlr')[0];
    return Boolean(
      handler &&
      handler.dataStart + 12 <= handler.end &&
      bytes.toString('ascii', handler.dataStart + 8, handler.dataStart + 12) === 'soun'
    );
  });
  if (!hasAudioTrack) return null;

  const version = bytes[mvhd.dataStart];
  const timescaleOffset = mvhd.dataStart + (version === 1 ? 20 : 12);
  const durationOffset = mvhd.dataStart + (version === 1 ? 24 : 16);
  const durationSize = version === 1 ? 8 : 4;
  if (durationOffset + durationSize > mvhd.end) return null;
  const timescale = bytes.readUInt32BE(timescaleOffset);
  const duration = version === 1
    ? Number(bytes.readBigUInt64BE(durationOffset))
    : bytes.readUInt32BE(durationOffset);
  if (!Number.isSafeInteger(duration) || timescale < 1 || duration < 1) return null;

  return {
    contentType: 'audio/mp4',
    extension: 'm4a',
    durationMs: Math.ceil((duration * 1000) / timescale)
  };
}

function inspectAdtsAac(bytes: Buffer): VerifiedVoiceAudio | null {
  let offset = 0;
  let totalSamples = 0;
  let sampleRate: number | null = null;
  let frameCount = 0;

  while (offset + 7 <= bytes.length) {
    const first = bytes[offset];
    const second = bytes[offset + 1];
    if (first !== 0xff || (second & 0xf6) !== 0xf0) return null;
    const frequencyIndex = (bytes[offset + 2] & 0x3c) >> 2;
    const frameSampleRate = AAC_SAMPLE_RATES[frequencyIndex];
    if (!frameSampleRate || (sampleRate != null && sampleRate !== frameSampleRate)) {
      return null;
    }
    sampleRate = frameSampleRate;
    const frameLength =
      ((bytes[offset + 3] & 0x03) << 11) |
      (bytes[offset + 4] << 3) |
      ((bytes[offset + 5] & 0xe0) >> 5);
    const headerLength = (second & 0x01) === 1 ? 7 : 9;
    if (frameLength < headerLength || offset + frameLength > bytes.length) return null;
    totalSamples += 1024 * ((bytes[offset + 6] & 0x03) + 1);
    frameCount += 1;
    offset += frameLength;
  }

  if (offset !== bytes.length || frameCount === 0 || sampleRate == null) return null;
  return {
    contentType: 'audio/aac',
    extension: 'aac',
    durationMs: Math.ceil((totalSamples * 1000) / sampleRate)
  };
}

function inspectVoiceContainer(bytes: Buffer): VerifiedVoiceAudio | null {
  if (bytes.length < 7) return null;
  return inspectMp4(bytes) ?? inspectAdtsAac(bytes);
}

async function decodesAsAudio(
  bytes: Buffer,
  extension: string,
  maximumDurationMs: number,
  userId?: string
): Promise<number | null> {
  if (!ffmpegPath) return null;
  const releaseDecoder = acquireDecoder(userId);
  if (!releaseDecoder) return null;
  const executablePath = ffmpegPath;
  let temporaryDirectory: string | null = null;
  try {
    temporaryDirectory = await mkdtemp(path.join(os.tmpdir(), 'kiwishare-voice-'));
    const inputPath = path.join(temporaryDirectory, `input.${extension}`);
    await writeFile(inputPath, bytes);
    return await new Promise<number | null>((resolve) => {
      const child = spawn(
        executablePath,
        [
          '-v', 'error',
          '-xerror',
          '-nostdin',
          '-i', inputPath,
          '-map', '0:a:0',
          '-ac', '1',
          '-ar', DECODE_SAMPLE_RATE.toString(),
          '-f', 's16le',
          'pipe:1'
        ],
        { windowsHide: true }
      );
      child.stdin.end();
      const maximumDecodedBytes = Math.floor(
        (maximumDurationMs / 1000) * DECODE_SAMPLE_RATE * DECODE_BYTES_PER_SAMPLE
      );
      let decodedBytes = 0;
      let invalid = false;
      let settled = false;
      const finish = (result: number | null) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        resolve(result);
      };
      const timeout = setTimeout(() => {
        invalid = true;
        child.kill();
        finish(null);
      }, 15000);

      child.stdout.on('data', (chunk: Buffer) => {
        decodedBytes += chunk.length;
        if (decodedBytes > maximumDecodedBytes) {
          invalid = true;
          child.kill();
        }
      });
      // Drain stderr so a malformed input cannot block the child process.
      child.stderr.resume();
      child.once('error', () => finish(null));
      child.once('close', (code) => {
        if (invalid || code !== 0 || decodedBytes < DECODE_BYTES_PER_SAMPLE) {
          finish(null);
          return;
        }
        const decodedSamples = Math.floor(decodedBytes / DECODE_BYTES_PER_SAMPLE);
        finish(Math.ceil((decodedSamples * 1000) / DECODE_SAMPLE_RATE));
      });
    });
  } finally {
    if (temporaryDirectory) {
      await rm(temporaryDirectory, { recursive: true, force: true });
    }
    releaseDecoder();
  }
}

export async function probeVoiceAudio(
  bytes: Buffer,
  maximumDurationMs: number,
  userId?: string
): Promise<VerifiedVoiceAudio | null> {
  if (!acceptsProbe(userId)) return null;
  const container = inspectVoiceContainer(bytes);
  if (
    container == null ||
    container.durationMs < 1 ||
    container.durationMs > maximumDurationMs
  ) {
    return null;
  }
  const decodedDurationMs = await decodesAsAudio(
    bytes,
    container.extension,
    maximumDurationMs,
    userId
  );
  if (decodedDurationMs == null || decodedDurationMs > maximumDurationMs) return null;
  return { ...container, durationMs: decodedDurationMs };
}
