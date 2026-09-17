export const PUBLIC_TRUST_SCORE_CEILING = 200;

export function formatPublicTrustScore(score: number): string {
  return score > PUBLIC_TRUST_SCORE_CEILING
    ? `${PUBLIC_TRUST_SCORE_CEILING}+`
    : String(score);
}

export function parseNonNegativeSafeInteger(input: string): number | null {
  const trimmed = input.trim();
  if (trimmed.length === 0 || !/^[0-9]+$/.test(trimmed)) return null;

  const value = Number(trimmed);
  return Number.isSafeInteger(value) ? value : null;
}
