# Chat Photo Message Verification

## Scope

This record covers Issue #97: sending an image in an authenticated buyer-seller
conversation. It does not include voice messages or push notifications.

## Implementation boundaries

- The Flutter client lets the member take one photo or choose one image from
  the device gallery.
- The client requests a presigned upload URL and uploads the raw image bytes
  directly to Cloudflare R2 under `images/chat/`. Controlled integration runs
  can use a `test/.../chat` prefix through `R2_UPLOAD_FOLDER`.
- After upload, the client sends only the R2 public CDN URL to the chat API.
- MongoDB stores the message type and CDN URL; image binary data is never
  placed in a message document.
- The API accepts only HTTPS image URLs from the configured KiwiShare R2 public
  origin and continues to derive sender and receiver identities from the
  authenticated conversation.

## Automated coverage

### Koa and MongoDB integration tests

- reject external image URLs and unsupported message types;
- persist an R2 URL as an image message without a text or binary payload;
- return the image URL in authenticated conversation history; and
- update the receiver's unread count and conversation preview.

### Flutter tests

- upload image bytes through the R2 presign boundary and preserve
  authentication failures;
- send only the returned CDN URL to the message API;
- avoid creating a message when the R2 upload fails;
- map image message JSON into the chat domain model;
- open the gallery option from the composer and render the resulting image
  bubble; and
- preserve the existing text, closed-conversation, error, and accessibility
  behaviour.

## Manual Android verification

Verified on 29 August 2026 using the Android emulator connected to the local
backend and the shared MongoDB test database:

1. The buyer selected an image from the gallery and sent it in the test
   conversation.
2. The image appeared immediately in the buyer's conversation.
3. The buyer left and reopened the conversation; the image remained visible.
4. The authenticated seller API view returned the same image message with an
   unread count of one and correctly identified it as an incoming message.
5. The stored message contained only an HTTPS CDN URL under
   `test/pr-97/chat/`; it did not contain an embedded binary or data URL.
6. A direct request to the stored CDN URL returned HTTP 200 with the
   `image/png` content type.

The temporary listing, accounts, MongoDB message, and R2 object are test data
and may be removed after the pull request has been reviewed.
