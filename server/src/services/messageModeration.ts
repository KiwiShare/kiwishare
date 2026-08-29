const DEFAULT_BLOCKED_TERMS = [
  'fuck',
  'fucks',
  'fucked',
  'fucker',
  'fuckers',
  'fucking',
  'motherfuck',
  'motherfucks',
  'motherfucked',
  'motherfucker',
  'motherfuckers',
  'motherfucking',
  'shit',
  'shits',
  'shitty',
  'shitting',
  'bullshit',
  'bullshits',
  'bullshitting',
  'shithead',
  'shitheads',
  'cunt',
  'cunts',
  'cunty',
  '操你妈',
  '傻逼'
] as const;

const MODERATION_SEPARATOR = '[\\p{P}\\p{S}\\s_]*';

export const MESSAGE_CONTENT_NOT_ALLOWED =
  'Your message contains language that is not allowed. Please edit it and try again.';

export interface ModeratedChatText {
  text: string;
  isAllowed: boolean;
}

function escapeRegularExpression(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function configuredBlockedTerms(): string[] {
  const configured = (process.env.CHAT_BLOCKED_TERMS ?? '')
    .split(/[\n,]/u)
    .map((term) => term.trim())
    .filter(Boolean);

  return [...new Set([...DEFAULT_BLOCKED_TERMS, ...configured])];
}

function normaliseForComparison(value: string): string {
  return value.normalize('NFKC').toLocaleLowerCase('en-NZ');
}

function isInvisibleOrDirectional(codePoint: number): boolean {
  return (
    [0x00ad, 0x034f, 0x061c, 0x115f, 0x1160, 0x17b4, 0x17b5, 0x180e,
      0x3164, 0xfeff, 0xffa0].includes(codePoint) ||
    (codePoint >= 0x200b && codePoint <= 0x200f) ||
    (codePoint >= 0x202a && codePoint <= 0x202e) ||
    (codePoint >= 0x2060 && codePoint <= 0x206f)
  );
}

function isDisallowedControl(codePoint: number): boolean {
  return (
    codePoint <= 0x0008 ||
    codePoint === 0x000b ||
    codePoint === 0x000c ||
    (codePoint >= 0x000e && codePoint <= 0x001f) ||
    (codePoint >= 0x007f && codePoint <= 0x009f)
  );
}

function removeUnsafeCharacters(value: string): string {
  return Array.from(value)
    .filter((character) => {
      const codePoint = character.codePointAt(0);
      return (
        codePoint !== undefined &&
        !isInvisibleOrDirectional(codePoint) &&
        !isDisallowedControl(codePoint)
      );
    })
    .join('');
}

function termPattern(term: string): RegExp | null {
  const normalisedTerm = normaliseForComparison(term).replace(
    /[\p{P}\p{S}\s_]+/gu,
    ''
  );
  const characters = Array.from(normalisedTerm);
  if (characters.length < 2) return null;

  const obfuscationTolerantTerm = characters
    .map(escapeRegularExpression)
    .join(MODERATION_SEPARATOR);
  const needsWordBoundary = /^[a-z0-9]+$/u.test(normalisedTerm);
  const source = needsWordBoundary
    ? `(^|[^\\p{L}\\p{N}])${obfuscationTolerantTerm}($|[^\\p{L}\\p{N}])`
    : obfuscationTolerantTerm;

  return new RegExp(source, 'iu');
}

export function sanitiseChatText(input: unknown): string {
  if (typeof input !== 'string') return '';

  return removeUnsafeCharacters(input.normalize('NFKC'))
    .replace(/\r\n?/gu, '\n')
    .split('\n')
    .map((line) => line.replace(/[^\S\n]+/gu, ' ').trim())
    .join('\n')
    .replace(/\n{3,}/gu, '\n\n')
    .trim();
}

export function moderateChatText(input: unknown): ModeratedChatText {
  const text = sanitiseChatText(input);
  const comparisonText = normaliseForComparison(text);
  const containsBlockedTerm = configuredBlockedTerms().some((term) => {
    const pattern = termPattern(term);
    return pattern?.test(comparisonText) ?? false;
  });

  return { text, isAllowed: !containsBlockedTerm };
}
