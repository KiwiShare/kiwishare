# Chat Push Notification Verification

## Scope

This record covers Issue #84: notifying the receiving member when a new chat
message is stored. Voice messages and watchlist price alerts remain outside
this change.

## Implementation boundaries

- After sign-in, the Android or iOS client requests notification permission and
  registers its Firebase Cloud Messaging token against the authenticated user.
- Token refresh updates the registration. Logout removes the current token
  before the local session is cleared.
- After MongoDB stores a text or photo message and updates unread state, the
  Koa server sends a best-effort FCM notification to the receiver's registered
  devices only.
- The notification contains the conversation ID and minimal item/sender display
  metadata for navigation. It does not include message text, image URLs, email,
  precise location, authentication data, or other private message content.
- Invalid FCM tokens are removed. Firebase configuration or delivery failure
  does not reject, roll back, or delete the underlying message.
- Android requests the runtime notification permission where required. iOS has
  the push entitlement and remote-notification background mode for Debug,
  Profile, and Release configurations.
- A notification opened from the system tray routes to its conversation. While
  the app is foregrounded, KiwiShare presents an in-app message with an Open
  action because mobile operating systems do not automatically display normal
  FCM notification banners in that state.
- Web remains unconfigured and safely skips FCM initialization.

## Automated coverage

### Koa and MongoDB integration tests

- require authentication and reject invalid device registration payloads;
- register idempotently and transfer a reused token to the currently signed-in
  account;
- prevent one account from unregistering another account's device;
- target only the receiving member and exclude private message content;
- remove invalid tokens returned by the notification gateway; and
- preserve the stored chat message when FCM delivery fails.

### Flutter tests

- ignore malformed or unrelated notification payloads;
- avoid token registration when permission is denied;
- register the initial token, update a refreshed token, and remove it at logout;
- stop registering refreshed tokens after logout; and
- handle foreground, opened, and cold-start chat notification events.

## Local regression result

Verified on 29 August 2026:

- Koa/Jest: 75 of 75 tests passed;
- Flutter: 114 of 114 tests passed;
- TypeScript build and ESLint passed;
- Flutter static analysis reported no issues; and
- the Android debug APK compiled successfully with Firebase Messaging and the
  runtime notification permission included.

These results verify application behaviour and native integration compilation.
They do not claim successful delivery through the shared Firebase project;
that requires the manual two-installation check below.

## Manual device verification

Complete this section before merge using two authenticated team test accounts
on distinct devices or emulators:

1. Configure Firebase Admin credentials on the test backend without committing
   the service-account secret.
2. Sign in as the receiver and allow notifications; sign in as the sender on a
   second installation.
3. With the receiver app backgrounded, send one text message and confirm a
   system notification appears without showing the message content.
4. Open the notification and confirm KiwiShare opens the correct conversation
   and loads the stored message.
5. Keep the receiver app foregrounded, send another message, and confirm the
   in-app notification appears and its Open action works.
6. Deny permission or temporarily remove the Firebase Admin configuration,
   send a message, and confirm the message still persists and appears after the
   receiver refreshes chat history.
7. Log out on the receiver device and confirm that installation is no longer
   registered for the previous account.

Attach Android and iOS screenshots or a short recording to the pull request.
Record any platform that could not be exercised and the responsible follow-up
owner; automated tests do not replace real-device FCM verification.
