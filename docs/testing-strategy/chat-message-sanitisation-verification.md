# Chat Message Sanitisation Verification

## Scope

This record covers Issue #98 only: authoritative server-side sanitisation and
sensitive-term checking for plain-text chat messages. Photo and voice messages,
push notifications, and third-party moderation services remain outside this
change.

## Behaviour

- normalises Unicode text to NFKC before validation and storage;
- removes control, zero-width, and bidirectional formatting characters;
- normalises line endings and repeated whitespace;
- checks a small built-in sensitive-term list plus optional team-configured
  additions from `CHAT_BLOCKED_TERMS`;
- recognises case, full-width, and punctuation-separated obfuscation; and
- returns a safe `422` response without echoing the matched term.

The server is the single source of truth for moderation. Flutter continues to
display the server's safe error message and retain the unsent draft, without
duplicating the sensitive-term list on the client.

## Data-integrity coverage

Backend integration tests verify that rejected content creates no `Message`
record and does not change the conversation preview or timestamp. Accepted
content is stored and returned only after sanitisation.

The backend test suite uses an isolated in-memory MongoDB instance and does not
read from or write to the shared test or production databases.

## Verification results

| Check | Result |
| --- | --- |
| Message moderation and chat integration tests | 18/18 passed |
| Backend full regression suite | 66/66 passed |
| Flutter full regression suite | 95/95 passed |
| Backend TypeScript build | Passed |
| Backend source lint | Passed |
| Flutter static analysis | No issues found |
