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

- Backend: 98/98 tests passed.
- Flutter: 139/139 tests passed.
- Backend ESLint passed.
- Backend TypeScript build passed.
- Flutter analyze passed with no issues.
- Android debug APK build passed.

Coverage added for:

- authenticated voice message creation and history serialization;
- invalid external URLs and recordings over 60 seconds;
- trusted R2 object-size and audio content-type validation before persistence;
- rejection of native recordings measured beyond the 60-second limit;
- the controlled `audio/chat` R2 upload folder;
- Flutter upload and REST request payloads;
- provider size and duration limits;
- recording, cancellation, sending, and voice bubble rendering.

## Manual mobile verification

Manual verification was completed on 30 August 2026 using the Android emulator
and two authenticated users connected to the local API and `kiwishare_test`
database.

Verified results:

- microphone recording could be started and cancelled without sending a
  message;
- a recording could be completed and sent successfully;
- the other participant received the persisted voice message;
- the voice bubble displayed the recorded duration; and
- playback, pause, and resume worked from the received message bubble.

The following extended edge-case checks remain useful but are not blockers for
the core Issue #96 acceptance path:

1. Deny microphone permission and confirm the app shows a safe recovery message.
2. Record for 60 seconds and confirm recording stops without exceeding the
   limit.
3. Repeat the core flow on iOS.

Android verification evidence was captured after completing the core flow.
