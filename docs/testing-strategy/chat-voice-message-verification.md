# Chat voice message verification (#96)

## Scope

Voice messages are part of an authenticated item conversation. A user can start
and cancel a recording, or stop and send it. Recordings are limited to 60
seconds and 5 MB, uploaded to the controlled `audio/chat` R2 folder, and stored
as message metadata rather than binary database content.

The receiver can load the persisted message history and play or pause the voice
message from its chat bubble. Conversation previews use `Voice message`; no
audio content is included in a text preview.

## Automated verification

- Backend: 72/72 tests passed.
- Flutter: 116/116 tests passed.
- Backend ESLint passed.
- Backend TypeScript build passed.
- Flutter analyze passed with no issues.
- Android debug APK build passed.

Coverage added for:

- authenticated voice message creation and history serialization;
- invalid external URLs and recordings over 60 seconds;
- the controlled `audio/chat` R2 upload folder;
- Flutter upload and REST request payloads;
- provider size and duration limits;
- recording, cancellation, sending, and voice bubble rendering.

## Manual mobile verification

Run these checks with two authenticated test accounts:

1. Open an active conversation and tap the microphone button.
2. Allow microphone access and confirm the recording timer appears.
3. Cancel once and confirm no message is sent.
4. Record again, send, and confirm the sender sees a playable voice bubble.
5. Open the same conversation as the receiver and confirm the message persists.
6. Play, pause, replay, and verify the displayed duration.
7. Deny microphone permission and confirm the app shows a safe recovery message.
8. Record for 60 seconds and confirm recording stops without exceeding the
   limit.

Android and iOS screenshots or a short recording should be attached to the PR
after device verification.
