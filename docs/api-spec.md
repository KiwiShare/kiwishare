# KiwiShare RESTful API Specification

This document details the unified RESTful API endpoints exposed by the Koa.js TypeScript backend server inside `server/src/app.ts`.

---

## 1. Authentication Endpoints

### `POST /api/auth/register`
Registers a new user profile with password authentication in MongoDB.
* **Payload**:
  ```json
  {
    "email": "sam@kiwishare.co.nz",
    "password": "securepassword123",
    "displayName": "Sam"
  }
  ```
* **Success Response (201 Created)**:
  ```json
  {
    "status": "success",
    "token": "<JWT>",
    "user": {
      "id": "64e1f77bcf86cd799439011",
      "displayName": "Sam",
      "trustScore": 100,
      "isVerified": false
    }
  }
  ```

### `POST /api/auth/login`
Authenticates an existing user and returns a JSON Web Token.
* **Payload**:
  ```json
  {
    "email": "sam@kiwishare.co.nz",
    "password": "securepassword123"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "token": "<JWT>",
    "user": {
      "id": "64e1f77bcf86cd799439011",
      "displayName": "Sam",
      "trustScore": 100,
      "isVerified": false
    }
  }
  ```

### `POST /api/auth/send-otp`
Sends a 6-digit one-time password code to the given email address.
* **Payload**:
  ```json
  {
    "email": "sam@kiwishare.co.nz"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Verification code sent successfully."
  }
  ```

### `POST /api/auth/verify-otp`
Verifies the OTP code and creates or logs in the user profile.
* **Payload**:
  ```json
  {
    "email": "sam@kiwishare.co.nz",
    "code": "123456",
    "displayName": "Sam"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "token": "<JWT>",
    "user": {
      "id": "64e1f77bcf86cd799439011",
      "email": "sam@kiwishare.co.nz",
      "displayName": "Sam",
      "avatarUrl": null,
      "trustScore": 100,
      "isVerified": false
    }
  }
  ```

### `POST /api/auth/google`
Validates Google OAuth ID tokens and signs in the user.
* **Payload**:
  ```json
  {
    "idToken": "google_id_token_string"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "token": "<JWT>",
    "user": {
      "id": "64e1f77bcf86cd799439011",
      "email": "sam@kiwishare.co.nz",
      "displayName": "Sam",
      "avatarUrl": "https://...",
      "trustScore": 100,
      "isVerified": true
    }
  }
  ```

---

## 2. Used Items Resource (`/api/usedItems`)

### `GET /api/usedItems`
Queries and filters available used items from the marketplace.
* **Query Parameters**:
  - `category` (optional): Exact category value returned by `GET /api/usedItems/discovery-options`.
  - `query` (optional): Search string matched against title, category, description, and location.
  - `location` (optional): Exact city value returned by the discovery-options endpoint.
  - `minPrice` / `maxPrice` (optional): Inclusive NZD price bounds.
  - `sustainable` (optional): Set to `true` to include only sustainability-labelled items.
  - `sort` (optional): `price_asc` or `price_desc`; omit for recommended order.
  - `latitude` / `longitude` (optional, paired): Approximate current location for nearby discovery.
  - `radiusKm` (optional): Nearby radius in kilometres; defaults to 50 when coordinates are supplied.
  - `status` (optional): `active`, `reserved`, `sold`
  - `sellerId` / `ownerId` (optional): Filter items by specific seller ID.
* **Success Response (200 OK)**:
  ```json
  [
    {
      "id": "64e1f77bcf86cd799439012",
      "title": "Retro Armchair",
      "priceNzd": "45",
      "location": "Central, Auckland",
      "imageUrl": "https://images.unsplash.com/photo-1567538096630-e0c55bd6374c",
      "isSustainable": true,
      "category": "Furniture",
      "condition": "good",
      "status": "active",
      "ownerId": "64e1f77bcf86cd799439011",
      "latitude": -36.8485,
      "longitude": 174.7633
    }
  ]
  ```

### `GET /api/usedItems/discovery-options`
Returns the categories, city locations, approximate city centres, item counts,
and available price bounds derived from active MongoDB listings. The mobile
client uses this response instead of maintaining category or location arrays.

* **Success Response (200 OK)**:
  ```json
  {
    "categories": [
      { "value": "Furniture", "count": 8 }
    ],
    "locations": [
      {
        "value": "Auckland",
        "count": 12,
        "latitude": -36.8485,
        "longitude": 174.7633
      }
    ],
    "priceRange": {
      "minimum": 15,
      "maximum": 890
    }
  }
  ```

### `GET /api/usedItems/:id`
Retrieves full details for a single used item by its ID.
* **Path Parameter**:
  - `id`: MongoDB ObjectId or unique item ID.
* **Success Response (200 OK)**:
  ```json
  {
    "id": "64e1f77bcf86cd799439012",
    "title": "Retro Armchair",
    "description": "Comfortable vintage armchair in great shape.",
    "priceNzd": "45",
    "price": 4500,
    "currency": "NZD",
    "location": "Central, Auckland",
    "imageUrl": "https://images.unsplash.com/photo-1567538096630-e0c55bd6374c",
    "isSustainable": true,
    "category": "Furniture",
    "condition": "good",
    "status": "active",
    "ownerId": "64e1f77bcf86cd799439011",
    "createdAt": "2026-08-19T00:00:00.000Z"
  }
  ```
* **Error Response (404 Not Found)**:
  ```json
  {
    "status": "error",
    "message": "Used item not found."
  }
  ```

### `POST /api/usedItems`
Publishes a new used item listing to the marketplace (Requires Authorization Header).
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Payload**:
  ```json
  {
    "title": "Monstera Deliciosa",
    "priceNzd": "15",
    "location": "Te Aro, Wellington",
    "imageUrl": "https://images.unsplash.com/photo-1545241047-6083a3684587",
    "isSustainable": true,
    "category": "Plants",
    "condition": "like_new",
    "description": "Healthy indoor plant in ceramic pot."
  }
  ```
* **Success Response (201 Created)**:
  ```json
  {
    "status": "created",
    "item": {
      "id": "64e1f77bcf86cd799439099",
      "title": "Monstera Deliciosa",
      "priceNzd": "15",
      "location": "Te Aro, Wellington",
      "imageUrl": "https://images.unsplash.com/photo-1545241047-6083a3684587",
      "isSustainable": true,
      "category": "Plants",
      "status": "active",
      "ownerId": "64e1f77bcf86cd799439011"
    }
  }
  ```

### `PATCH /api/usedItems/:id` (or `PUT /api/usedItems/:id`)
Updates an existing used item listing (Requires Auth & Ownership).
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Payload**:
  ```json
  {
    "priceNzd": "12",
    "status": "reserved"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "item": {
      "id": "64e1f77bcf86cd799439099",
      "title": "Monstera Deliciosa",
      "priceNzd": "12",
      "status": "reserved"
    }
  }
  ```

### `DELETE /api/usedItems/:id`
Deletes/soft-deletes a used item listing (Requires Auth & Ownership).
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Used item deleted successfully."
  }
  ```

> **Backwards Compatibility**: `/api/listings` endpoints remain supported as aliases to `/api/usedItems`.

---

### `POST /api/listing-suggestions`
Returns an optional AI-generated draft for the authenticated seller to review.
The endpoint never creates or updates a listing, does not accept photos, and
does not generate or replace the listing location.

* **Authentication**: Bearer token required.
* **Rate limit**: 5 requests per authenticated account per minute.
* **Payload**: At least one of `title`, `description`, `category`, or
  `condition` is required. `location` is optional context.
  ```json
  {
    "title": "Wooden desk",
    "description": "Some scratches on the top",
    "category": "Furniture",
    "condition": "Good",
    "location": "Mount Eden, Auckland"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "suggestion": {
      "title": "Solid wood study desk",
      "description": "A sturdy pre-owned desk with light signs of use.",
      "category": "Furniture",
      "condition": "Good",
      "priceNzd": "120"
    }
  }
  ```
* **Errors**: `400` invalid context, `401` unauthenticated, `429` rate limited,
  `502` invalid provider output, or `503` provider unavailable.

## 3. User Profile Resource (`/api/users`)

### `GET /api/users/me`
Retrieves profile data of the currently authenticated user.
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "user": {
      "id": "64e1f77bcf86cd799439011",
      "email": "sam@kiwishare.co.nz",
      "displayName": "Sam",
      "avatarUrl": "https://...",
      "trustScore": 100,
      "isVerified": true
    }
  }
  ```

### `PATCH /api/users/me`
Updates profile information of the current user.
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Payload**:
  ```json
  {
    "displayName": "Sam Yao",
    "avatarUrl": "https://images.unsplash.com/..."
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "user": {
      "id": "64e1f77bcf86cd799439011",
      "email": "sam@kiwishare.co.nz",
      "displayName": "Sam Yao",
      "avatarUrl": "https://images.unsplash.com/...",
      "trustScore": 100,
      "isVerified": true
    }
  }
  ```

### `GET /api/users/me/usedItems` (or `/api/users/me/listings`)
Retrieves all items listed by the authenticated user.
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Query Parameters**:
  - `status` (optional): `sold` or `active,reserved`
* **Success Response (200 OK)**:
  ```json
  [
    {
      "id": "64e1f77bcf86cd799439099",
      "title": "Monstera Deliciosa",
      "priceNzd": "15",
      "status": "active"
    }
  ]
  ```

---

## 4. Conversation and Message Endpoints (`/api/conversations`)

Every endpoint in this section requires `Authorization: Bearer <JWT_TOKEN>`.
Conversation data is returned only when the authenticated member is the buyer
or seller. Text and photo messages use the same participant-isolated history.
Voice messages are defined by a separate backlog item. Authenticated mobile
devices may register for best-effort new-message push notifications.

### `GET /api/conversations`

Returns the authenticated member's item-linked conversations in most-recent
activity order. Each entry includes the counterparty, item summary, buying or
selling direction, last text, and the caller's unread count.

### `POST /api/conversations`

Creates or returns the buyer's existing conversation for an eligible item.
The operation is idempotent for the same buyer and item.

* **Payload**:
  ```json
  { "itemId": "64e1f77bcf86cd799439012" }
  ```
* **Success Response**: `201 Created` for a new conversation or `200 OK` for
  the existing conversation.
* **Validation**: Rejects invalid or unavailable items and prevents a seller
  from starting a conversation with themselves.

### `GET /api/conversations/:conversationId/messages`

Returns a chronological page of non-deleted messages from a conversation.

* **Query Parameters**:
  - `limit` (optional): Page size from 1 to 100; defaults to 50.
  - `before` (optional): ISO-8601 timestamp cursor for older messages.
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "messages": [
      {
        "id": "64e1f77bcf86cd799439101",
        "conversationId": "64e1f77bcf86cd799439100",
        "senderId": "64e1f77bcf86cd799439011",
        "receiverId": "64e1f77bcf86cd799439013",
        "type": "text",
        "text": "Is this still available?",
        "imageUrl": null,
        "status": "sent",
        "isMine": true,
        "readAt": null,
        "createdAt": "2026-08-27T01:00:00.000Z"
      }
    ],
    "pagination": { "hasMore": false, "nextBefore": null }
  }
  ```

### `POST /api/conversations/:conversationId/messages`

Sends one text or photo message. The server derives the receiver from the
conversation instead of accepting a client-supplied receiver ID.

* **Text payload**:
  ```json
  { "text": "Is this still available?" }
  ```
* **Photo payload**:
  ```json
  {
    "type": "image",
    "imageUrl": "https://assets.kiwishare.online/images/chat/photo.jpg"
  }
  ```
* **Validation**: Text messages apply Unicode NFKC normalisation, remove
  control and invisible direction-changing characters, normalise whitespace,
  permit 1-2000 characters, and check the server-managed sensitive-term list.
  Photo messages accept only URLs produced by the configured KiwiShare R2
  public origin or local image proxy. Image binary data is uploaded directly
  to R2 and is never stored in MongoDB. Both message types require an active
  conversation. Rejected content is not stored and does not update the
  conversation preview.
* **Success Response**: `201 Created` with the created message.
* **Moderation Response (422 Unprocessable Entity)**:
  ```json
  {
    "status": "error",
    "code": "MESSAGE_CONTENT_NOT_ALLOWED",
    "message": "Your message contains language that is not allowed. Please edit it and try again."
  }
  ```

After a message is stored and its unread state is updated, the server attempts
to notify the receiver's registered devices through FCM. The push payload uses
conversation, item, and sender display metadata but excludes message text and
image URLs. Notification failure never rolls back or rejects the stored message.

### `PATCH /api/conversations/:conversationId/read`

Marks the caller's incoming sent or delivered messages as read and resets the
caller's unread counter.

* **Success Response (200 OK)**:
  ```json
  { "status": "success", "readCount": 2 }
  ```

---

## 5. Push Notification Device Endpoints (`/api/notifications`)

Both endpoints require `Authorization: Bearer <JWT_TOKEN>`. Device tokens are
private delivery identifiers and are never returned by the API.

### `POST /api/notifications/devices`

Creates or refreshes the current installation's FCM registration. Registering
the same token under another authenticated account transfers that installation
to the current account, which prevents notifications leaking across account
changes on a shared device.

* **Payload**:
  ```json
  { "token": "<JWT>", "platform": "android" }
  ```
* **Platforms**: `android` or `ios`.
* **Success Response**: `200 OK` with
  `{ "status": "success", "device": { "platform": "android" } }` (or `ios`).

### `DELETE /api/notifications/devices`

Removes the supplied token only when it belongs to the authenticated account.
The Flutter client calls this before clearing a signed-in session.

* **Payload**:
  ```json
  { "token": "<JWT>" }
  ```
* **Success Response**: `200 OK`; the operation is idempotent.

---

## 6. Transaction & QR Handover Endpoints

### `POST /api/transactions/handover/claim`
Executes atomic ownership status transitions during peer-to-peer item handovers.
* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
* **Payload**:
  ```json
  {
    "itemId": "64e1f77bcf86cd799439099",
    "claimCode": "QR_HANDOVER_TOKEN_ABC"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Ownership transaction verified and committed successfully.",
    "newOwnerId": "64e1f77bcf86cd799439011"
  }
  ```

---

## 7. Report Endpoints (`/api/reports`)

Reports are confidential moderation records. Authenticated members can create
reports and review their own report history, but cannot read another member's
reports, choose the reporter identity, or set moderation fields. The stored
document shape is defined in `docs/schemas/report.schema.json`.

### `POST /api/reports`

Creates one report for the authenticated member.

* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
  - `Content-Type: application/json`
* **Payload**:
  ```json
  {
    "targetType": "listing",
    "targetId": "64e1f77bcf86cd799439099",
    "contextType": "listing",
    "contextId": "64e1f77bcf86cd799439099",
    "reason": "misleading_information",
    "details": "The photos and description show different items."
  }
  ```
* **Target types**:
  - `listing`: requires an existing `targetId`, `contextType: listing`, and an
    optional `contextId` equal to the target listing. The stored listing
    context is normalised to the target ID.
  - `user`: requires an existing `targetId`; context must be `profile`, `chat`,
    or `transaction`. Chat and transaction reports require a `contextId` whose
    participants include both the reporter and reported user. A profile context
    is normalised to the reported user ID.
  - `general`: must use `contextType: general` and omit both IDs.
* **Listing reason codes**: `misleading_information`,
  `prohibited_or_unsafe_item`, `counterfeit_item`, `suspected_stolen_item`,
  `duplicate_listing_or_spam`, `other`.
* **User and general reason codes**: `scam_or_fraud`,
  `harassment_or_abusive_behaviour`, `unsafe_meetup_behaviour`,
  `did_not_show_up_repeatedly`, `fake_identity_or_impersonation`,
  `suspicious_payment_request`, `off_platform_communication`, `other`.
* **Details**: required after trimming; 10–1000 characters.
* **Server-owned fields**: `id`, `reporterId`, `status`, and `createdAt`. Any
  same-named values sent by a client are ignored.
* **One report per target**: a member can report a particular user or listing
  only once, regardless of reason, context, or elapsed time. Other members can
  still report the same target. General safety reports are not target-limited.
  The backend uses a database-backed deduplication key to protect concurrent
  requests, while the mobile form also disables submission while one request is
  pending.
* **Email confirmation**: when `RESEND_API_KEY` is configured, the backend sends
  a receipt to the authenticated member's stored email address. The receipt
  includes the reporter name and email, a readable reason, submitted details,
  reference, and submitted time. Listing reports also include the validated
  listing title; user and general reports omit that row. Delivery failure does
  not undo the report or change the response status.
* **Success Response (201 Created)**:
  ```json
  {
    "status": "success",
    "report": {
      "id": "64e1f77bcf86cd799439120",
      "reporterId": "64e1f77bcf86cd799439011",
      "targetType": "listing",
      "targetId": "64e1f77bcf86cd799439099",
      "contextType": "listing",
      "contextId": "64e1f77bcf86cd799439099",
      "reason": "misleading_information",
      "details": "The photos and description show different items.",
      "status": "pending",
      "createdAt": "2026-08-31T03:04:05.000Z"
    }
  }
  ```
* **Error responses**:
  - `400 Bad Request`: invalid target/context/reason/details, or self-report.
  - `401 Unauthorized`: missing/invalid session or deleted reporter account.
  - `403 Forbidden`: the reporter is not a participant in the supplied private
    chat or transaction context.
  - `404 Not Found`: target or related context does not exist.
  - `409 Conflict`: this member has already reported the same user or listing.

### `GET /api/reports`

Returns every report submitted by the authenticated member, ordered by
`createdAt` from newest to oldest. The server always derives ownership from the
JWT and never accepts a reporter ID as a query parameter.

* **Headers**:
  - `Authorization: Bearer <JWT_TOKEN>`
  - `Accept: application/json`
* **Success Response (200 OK)**:
  ```json
  {
    "status": "success",
    "reports": [
      {
        "id": "66e640ee3d3540355741abcd",
        "targetType": "user",
        "contextType": "chat",
        "reason": "harassment_or_abusive_behaviour",
        "details": "The member repeatedly sent threatening messages.",
        "status": "pending",
        "createdAt": "2026-09-14T01:00:00.000Z"
      }
    ]
  }
  ```
* **Statuses**: `pending`, `reviewed`, or `dismissed`. The client presents
  these as high-level progress only and must not imply an enforcement outcome.
* **Privacy**: The response omits `reporterId`, target/context IDs, moderator
  notes, and enforcement details. A member cannot request another account's
  reports.
* **Empty state**: An account with no reports receives `200 OK` with
  `"reports": []`; the client must not fill this state with sample records.
* **Authentication errors**: `401 Unauthorized` for a missing/current-account
  failure and `403 Forbidden` for an invalid or expired JWT.

There is no public or moderator `GET /api/reports` endpoint in the MVP. A future
moderator endpoint requires a separate authorization and privacy review.

---

## 8. Marketplace Discovery, Monetisation & Coordination Endpoints

The product has expanded beyond the original resource list above. The following endpoint groups are particularly relevant to the current product capability map:

### Discovery and recommendation

- `GET /api/usedItems/search-suggestions` — server-backed search-as-you-type suggestions over active marketplace data.
- `GET /api/usedItems/recommended` — weighted recommendation ranking using watchlist affinity, proximity, engagement, freshness, sustainability and condition.
- `GET /api/usedItems/featured` — featured/promoted listing surface.
- `POST /api/usedItems/:id/promote` — owner-only listing promotion using KiwiGold, with VIP promotion rules applied server-side.

### Payment, wallet and membership

- `GET /api/config/fees` — platform fee configuration.
- `POST /api/payments/create-intent` / `POST /api/payments/confirm` — Stripe-backed order payment creation and verification.
- `GET /api/payments/cards`, `POST /api/payments/payment-methods`, `POST /api/payments/cards`, `DELETE /api/payments/cards/:id` — saved-card/payment-method management.
- `POST /api/payments/topup/create-intent` / `POST /api/payments/topup/confirm` — KiwiGold or VIP purchase flow.
- `POST /api/payments/vip/cancel-renewal` / `POST /api/payments/vip/resume-renewal` — VIP renewal controls.

Payment state is authoritative on the backend. Product documentation describes the current hold/release behavior as an **escrow-style application workflow**; these endpoints do not by themselves establish KiwiShare as a regulated escrow provider.

### Notification preferences

- `GET /api/notifications/preferences` — returns notification preferences including watchlist price-change and nearby-category alerts.
- `PATCH /api/notifications/preferences` — updates supported notification preferences.

Marketplace events can be delivered through notification history, native push and email depending on event type, user preference and configured delivery providers.

### Meetup and physical handover

- `POST /api/meetups/propose` — propose or reschedule a meetup.
- `POST /api/meetups/:orderId/accept` / `POST /api/meetups/:orderId/decline` — negotiate meetup status.
- `GET /api/meetups/my` / `GET /api/meetups/:orderId` — retrieve meetup/order coordination state.
- `POST /api/meetups/:orderId/confirm-handover` — bilateral handover confirmation path.
- `POST /api/transactions/handover/claim` — QR-based authenticated handover claim path.

Both clients must use server-derived payment, meetup and handover readiness rather than inventing independent client-side state transitions.
