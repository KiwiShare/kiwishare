import { inspectVoiceAudio } from '../src/services/voiceAudio';

function box(type: string, payload: Buffer): Buffer {
  const result = Buffer.alloc(8 + payload.length);
  result.writeUInt32BE(result.length, 0);
  result.write(type, 4, 4, 'ascii');
  payload.copy(result, 8);
  return result;
}

function mp4Audio(durationMs: number, handler = 'soun'): Buffer {
  const movieHeader = Buffer.alloc(20);
  movieHeader.writeUInt32BE(1000, 12);
  movieHeader.writeUInt32BE(durationMs, 16);
  const handlerBox = Buffer.alloc(12);
  handlerBox.write(handler, 8, 4, 'ascii');
  return Buffer.concat([
    box('ftyp', Buffer.from('M4A \u0000\u0000\u0000\u0000M4A ', 'binary')),
    box(
      'moov',
      Buffer.concat([
        box('mvhd', movieHeader),
        box('trak', box('mdia', box('hdlr', handlerBox)))
      ])
    ),
    box('mdat', Buffer.from([1, 2, 3]))
  ]);
}

describe('voice audio inspection', () => {
  test('derives duration and type from an MP4 audio container', () => {
    expect(inspectVoiceAudio(mp4Audio(12500))).toEqual({
      contentType: 'audio/mp4',
      extension: 'm4a',
      durationMs: 12500
    });
  });

  test('rejects arbitrary bytes and MP4 files without an audio track', () => {
    expect(inspectVoiceAudio(Buffer.from('arbitrary bytes'))).toBeNull();
    expect(inspectVoiceAudio(mp4Audio(1000, 'vide'))).toBeNull();
  });

  test('exposes overlong duration from the media container', () => {
    expect(inspectVoiceAudio(mp4Audio(60001))?.durationMs).toBe(60001);
  });

  test('recognises a structurally valid ADTS AAC frame', () => {
    const frame = Buffer.from([0xff, 0xf1, 0x50, 0x80, 0x01, 0x7f, 0xfc, 0x00, 0x00, 0x00, 0x00]);
    expect(inspectVoiceAudio(frame)).toEqual({
      contentType: 'audio/aac',
      extension: 'aac',
      durationMs: 24
    });
  });
});
