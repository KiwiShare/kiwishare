import {
  MESSAGE_CONTENT_NOT_ALLOWED,
  moderateChatText,
  sanitiseChatText
} from '../src/services/messageModeration';

describe('chat message moderation', () => {
  const originalConfiguredTerms = process.env.CHAT_BLOCKED_TERMS;

  afterEach(() => {
    if (originalConfiguredTerms === undefined) {
      delete process.env.CHAT_BLOCKED_TERMS;
    } else {
      process.env.CHAT_BLOCKED_TERMS = originalConfiguredTerms;
    }
  });

  test('normalises full-width text, whitespace, and line endings', () => {
    expect(sanitiseChatText('  Ｈｅｌｌｏ\t  Kiwi\r\n\r\n\r\n  team  ')).toBe(
      'Hello Kiwi\n\nteam'
    );
  });

  test('removes control, zero-width, and directional characters', () => {
    expect(sanitiseChatText('Safe\u0000 mes\u200bsage\u202e')).toBe('Safe message');
  });

  test('rejects case, full-width, and separator obfuscation consistently', () => {
    expect(moderateChatText('F.U_C K').isAllowed).toBe(false);
    expect(moderateChatText('ＦＵＣＫ').isAllowed).toBe(false);
  });

  test('rejects common inflections and compounds of built-in terms', () => {
    for (const text of ['fucking', 'motherfucker', 'bullshit', 'shithead']) {
      expect(moderateChatText(text).isAllowed).toBe(false);
    }
  });

  test('supports team-configured terms without exposing the matched term', () => {
    process.env.CHAT_BLOCKED_TERMS = 'kiwi-test-term';

    expect(moderateChatText('KIWI_test term').isAllowed).toBe(false);
    expect(MESSAGE_CONTENT_NOT_ALLOWED).not.toContain('kiwi-test-term');
  });

  test('does not reject a blocked character sequence inside a normal word', () => {
    process.env.CHAT_BLOCKED_TERMS = 'ass';

    expect(moderateChatText('This is a classic desk.').isAllowed).toBe(true);
    expect(moderateChatText('Scunthorpe collection').isAllowed).toBe(true);
  });
});
