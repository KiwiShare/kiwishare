# Publish Item Flow Verification

## Scope

This record covers Issue #80 and verifies the integrated publish-item flow delivered by Issues #22, #23, #78, and #79. It focuses on the boundary between the Flutter client, image storage, the authenticated listing API, MongoDB persistence, and subsequent listing discovery.

## Automated coverage

| Behaviour | Verification |
| --- | --- |
| Authenticated photo upload and item creation | Flutter service tests verify presign, byte upload, and authenticated item creation in sequence. |
| Approximate GPS and manual suburb/city payloads | Flutter widget tests and Node API integration tests cover both location paths. |
| Rejected or expired authentication | Flutter service/widget tests and Node API tests verify safe failure and session clearing. |
| Invalid fields | Node API parameterised tests cover missing and malformed listing data. |
| Upload failure | Flutter service tests verify that item creation is not attempted after an upload failure. |
| API failure and retry | Flutter widget tests keep the completed form open, allow a retry, and verify that only one item is created. |
| Duplicate prevention | Flutter widget tests verify that submission and navigation controls are disabled while a publish request is in flight. |
| Discovery after publication | Node integration tests publish into an in-memory MongoDB instance and retrieve the new active listing through the public discovery endpoint. |
| Current user's active listings | Node integration tests retrieve the newly created listing through the authenticated `users/me/usedItems` endpoint. |
| Client refresh after publication | Flutter widget tests verify that listing caches are invalidated after a successful publish. |
| Cloud isolation | Node tests replace R2 with an in-process test double. Automated tests never contact shared R2 or MongoDB environments and contain no credentials. |

## Local verification results

Verified on Windows on 27 August 2026:

| Check | Result |
| --- | --- |
| `pnpm --filter server run build` | Passed |
| `pnpm --filter server run lint` | Passed |
| `pnpm --filter server test` | 45/45 passed |
| `flutter analyze --no-pub` from `mobile` | Passed with no issues |
| `flutter test --no-pub` from `mobile` | 64/64 passed |
| Android release APK with the deployed API URL | Passed; 55.4 MB APK generated |

The Android release command was:

```text
flutter build apk --release --no-pub --dart-define=API_BASE_URL=https://kiwishare.onrender.com
```

## Manual end-to-end evidence

The real-service Android journey was completed during PR #171 before this verification work:

1. Sign in and select a local image.
2. Publish a listing through the deployed API.
3. Confirm the success message.
4. Confirm the new listing appears in both Featured Highlights and Recommended for You on Home.

The screenshot attached to PR #171 shows the listing `PR171 Android publish test`, its uploaded image, the `$1` price, the Auckland location, and the `Your listing is live.` confirmation. The associated test data used the team's designated MongoDB test database and R2 test folder.

iOS layout and publish-screen compatibility were reviewed on a real iPhone by the team's iOS tester during the prerequisite publish-flow work. This Issue #80 change modifies tests only and does not change runtime UI or platform configuration.

## Notes

- GitHub Actions were disabled temporarily by the course staff because of the organisation quota. All checks above were therefore run locally, and this work should be pushed only after the complete local verification pass.
- No secrets, production data, or cloud credentials are stored in this record or in the automated tests.
