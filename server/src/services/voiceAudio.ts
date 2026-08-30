export interface VerifiedVoiceAudio {
  contentType: 'audio/mp4' | 'audio/aac';
  extension: 'm4a' | 'aac';
  durationMs: number;
}

const AAC_SAMPLE_RATES = [
  96000, 88200, 64000, 48000, 44100, 32000, 24000,
  22050, 16000, 12000, 11025, 8000, 7350
];

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

export function inspectVoiceAudio(bytes: Buffer): VerifiedVoiceAudio | null {
  if (bytes.length < 7) return null;
  return inspectMp4(bytes) ?? inspectAdtsAac(bytes);
}
