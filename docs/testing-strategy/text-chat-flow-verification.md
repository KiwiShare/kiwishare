# Text Chat Flow Verification

This record covers Issue #83 only: authenticated conversation lists, paginated
text history, text sending, read state, and the related Flutter states. Media,
notifications, deletion, reporting, and product-detail entry points remain in
their own backlog items.

## Automated evidence

| Layer | Check | Result |
|---|---|---|
| Node API | Authentication, participant isolation, idempotent creation, validation, pagination, unread/read state, and closed conversations | 8 tests passed |
| Flutter repository | Authenticated requests, response parsing, pagination, trimmed sends, and safe errors | 4 tests passed |
| Flutter conversation list | Loading, filters, callbacks, signed-out/empty/error states, retry, account-switch privacy, and 200% text scaling | 7 tests passed |
| Flutter conversation view | History, read receipt request, send success/failure, draft retention, closed state, and 200% text scaling | 6 tests passed |
| Mobile regression | Full Flutter test suite | 75 tests passed |
| Static analysis | Flutter analyser | No issues found |

## Local commands

Run from the repository root:

```powershell
pnpm --filter server run lint
pnpm --filter server run build
pnpm --filter server test chat.test.ts --runInBand

cd mobile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
```

The full server suite is intentionally deferred until the R2-isolation change
in PR #176 reaches `pre`. The current `pre` test suite still contains a legacy
upload test that can call the shared Cloudflare R2 bucket when a local `.env`
contains real credentials. The Issue #83 API suite uses an isolated in-memory
MongoDB and does not call R2, Resend, Render, or the shared Atlas database.

## Manual Android acceptance

Before merge, attach screenshots or a short recording to the pull request and
verify the following on Android:

1. Sign in as a buyer or seller and open the Chat tab.
2. Confirm that only that account's conversations are listed.
3. Open a conversation and confirm existing text history is visible.
4. Send a text message and confirm it appears once and survives reopening.
5. Open the same conversation as the other participant and confirm unread state
   clears after the history is viewed.
6. Check loading, empty, recoverable error, and disabled closed-chat states.

Use test accounts and the MongoDB test database. Do not create chat evidence in
production data.
