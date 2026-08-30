import { spawnSync } from 'child_process';
import { mkdtempSync, readFileSync, rmSync } from 'fs';
import os from 'os';
import path from 'path';
import { probeVoiceAudio } from '../src/services/voiceAudio';

const ffmpegPath = require('ffmpeg-static') as string;

function generatedM4a(durationSeconds: number): Buffer {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'kiwishare-audio-test-'));
  const outputPath = path.join(directory, 'voice.m4a');
  try {
    const result = spawnSync(
      ffmpegPath,
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
    if (result.status !== 0) {
      throw new Error(`Fixture generation failed: ${result.stderr.toString()}`);
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
});
