# Chat Swipe Removal Verification

## Scope

This record covers Issue #95 only: allowing a signed-in member to remove a
conversation from their own Chat list with a left swipe. Removal is private to
that member. It does not delete the conversation or its message history for the
other participant, and the conversation becomes visible again when either
participant sends a new message or the buyer reopens the item conversation.

Permanent message deletion, media messages, and push notifications remain
outside this issue.

## Automated verification

| Layer | Coverage | Result |
| --- | --- | --- |
| Flutter conversation list | Left-swipe direction, confirmation, cancellation, successful removal, and right-swipe protection | Passed |
| Flutter provider | Optimistic list removal, cached-history cleanup, and rollback after an API failure | Passed |
| Flutter repository | Authenticated conversation deletion request and safe API-error handling | Passed |
| Node API | Participant-only removal, per-member visibility, message-triggered restoration, and item-entry restoration | Passed |
| Regression | Full Flutter and server test suites | 94/94 Flutter and 59/59 server tests passed |
| Quality checks | Flutter analysis, server build, and repository lint checks | Passed |

The Node integration suite uses an isolated in-memory MongoDB. It does not call
R2, Resend, Render, or the shared Atlas database.

## Android integration verification

The Android emulator ran against the local Koa server connected to the
`kiwishare_test` MongoDB database.

1. Signed in as the PR83 buyer and opened the Chat list.
2. Swiped the PR83 seller conversation from right to left and confirmed the
   compact `Remove` action was displayed.
3. Selected `Cancel` and confirmed the conversation remained visible.
4. Repeated the gesture, selected `Remove`, and confirmed the conversation
   disappeared only from the buyer's list.
5. Sent a new message from the seller account and confirmed the conversation
   returned to the buyer's list with an unread indicator.
6. Opened the restored conversation and confirmed that its earlier message
   history had not been deleted.

## Manual evidence

Android screenshots captured during verification show the compact swipe action,
the confirmation dialog, the restored unread conversation, and the preserved
message history. The screenshots are attached to the pull request rather than
stored in the repository so that device captures do not increase the source
artifact size.
