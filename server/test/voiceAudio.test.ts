import { spawnSync } from 'child_process';
import { mkdtempSync, readFileSync, rmSync } from 'fs';
import os from 'os';
import path from 'path';
import {
  acquireVoiceProcessingAdmission,
  probeVoiceAudio,
  resolveFfmpegExecutable
} from '../src/services/voiceAudio';

function generatedM4a(durationSeconds: number): Buffer {
  const executable = resolveFfmpegExecutable();
  if (!executable) {
    throw new Error(
      'ffmpeg executable not found in test environment. Please install ffmpeg or set FFMPEG_BIN.'
    );
  }
  const directory = mkdtempSync(path.join(os.tmpdir(), 'kiwishare-audio-test-'));
  const outputPath = path.join(directory, 'voice.m4a');
  try {
    const result = spawnSync(
      executable,
      [
        '-v', 'error',
        '-f', 'lavfi',
        '-i', 'anullsrc=r=44100:cl=mono',
        '-t', durationSeconds.toString(),
        '-c:a', 'aac',
        '-y', outputPath
      ],
      { windowsHide: true }
    );
    if (result.error || result.status !== 0) {
      const errorMsg =
        result.error?.message ||
        result.stderr?.toString() ||
        `Exit code ${result.status}`;
      throw new Error(`Fixture generation failed: ${errorMsg}`);
    }
    return readFileSync(outputPath);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function mp4Box(type: string, payload: Buffer): Buffer {
  const box = Buffer.alloc(8 + payload.length);
  box.writeUInt32BE(box.length, 0);
  box.write(type, 4, 4, 'ascii');
  payload.copy(box, 8);
  return box;
}

function labelledButUndecodableMp4(): Buffer {
  const movieHeader = Buffer.alloc(20);
  movieHeader.writeUInt32BE(1000, 12);
  movieHeader.writeUInt32BE(1000, 16);
  const handler = Buffer.alloc(12);
  handler.write('soun', 8, 4, 'ascii');
  return Buffer.concat([
    mp4Box('ftyp', Buffer.from('M4A \u0000\u0000\u0000\u0000M4A ', 'binary')),
    mp4Box(
      'moov',
      Buffer.concat([
        mp4Box('mvhd', movieHeader),
        mp4Box('trak', mp4Box('mdia', mp4Box('hdlr', handler)))
      ])
    ),
    mp4Box('mdat', Buffer.from([1, 2, 3]))
  ]);
}

function withMovieDuration(bytes: Buffer, duration: number): Buffer {
  const changed = Buffer.from(bytes);
  const typeOffset = changed.indexOf(Buffer.from('mvhd'));
  if (typeOffset < 0) throw new Error('Generated fixture has no mvhd box');
  const dataStart = typeOffset + 4;
  const version = changed[dataStart];
  const durationOffset = dataStart + (version === 1 ? 24 : 16);
  if (version === 1) changed.writeBigUInt64BE(BigInt(duration), durationOffset);
  else changed.writeUInt32BE(duration, durationOffset);
  return changed;
}

describe('voice audio probing', () => {
  let validAudio: Buffer;

  beforeAll(() => {
    validAudio = generatedM4a(0.25);
  });

  test('fully decodes a valid AAC-in-M4A audio track', async () => {
    const result = await probeVoiceAudio(validAudio, 60000);
    expect(result).toEqual(
      expect.objectContaining({
        contentType: 'audio/mp4',
        extension: 'm4a'
      })
    );
    expect(result?.durationMs).toBeGreaterThan(0);
    expect(result?.durationMs).toBeLessThanOrEqual(1000);
  });

  test('rejects arbitrary bytes and a fabricated audio handler', async () => {
    await expect(
      probeVoiceAudio(Buffer.from('arbitrary bytes'), 60000)
    ).resolves.toBeNull();
    await expect(
      probeVoiceAudio(labelledButUndecodableMp4(), 60000)
    ).resolves.toBeNull();
  });

  test('enforces measured container duration before decoding', async () => {
    await expect(probeVoiceAudio(validAudio, 100)).resolves.toBeNull();
  });

  test('uses decoded samples instead of a shortened movie-header duration', async () => {
    const shortenedHeader = withMovieDuration(validAudio, 1);

    await expect(probeVoiceAudio(shortenedHeader, 100)).resolves.toBeNull();
    const result = await probeVoiceAudio(shortenedHeader, 60000);
    expect(result?.durationMs).toBeGreaterThan(100);
  });

  test('rejects concurrent processing admission for the same user', () => {
    const first = acquireVoiceProcessingAdmission('user-a');
    const second = acquireVoiceProcessingAdmission('user-a');

    expect(first).not.toBeNull();
    expect(second).toBeNull();
    first?.release();
  });
});
