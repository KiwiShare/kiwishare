# Profile Module — Decisions and Open Questions

**Status:** Working agreement for implementation and team review  
**Related issues:** #46, #90, #91, #92, #93, #94, #111, #112, #131  
**Updated:** 14 August 2026

## Current implementation status (branch `46-me-profile-module`)

Implemented in Flutter:

- Own-account Profile and guest states.
- Trust-score and verification display using server-owned user data.
- Display-name editing with validation and local session refresh after a successful API response.
- System, light, and dark theme selection persisted on the device.
- Read-only Selling and Sold screens with loading, empty, error, and data states.
- Safety & support report form with reasons, details validation, duplicate-tap prevention, and acknowledgement UI.
- Existing remote avatar display plus a safe initial-based default avatar.
- Logout and login entry points.

Verified on 14 August 2026:

- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.

Not yet end-to-end because backend/team contracts are missing:

- `PATCH /api/users/me` must be implemented before display-name edits work against the real repository.
- `GET /api/users/me/listings` must be implemented before Selling/Sold use real data. The mobile request already sends the JWT.
- `POST /api/reports` must be agreed and implemented. The current form intentionally simulates submission so the UX can be reviewed without pretending moderation storage exists.
- Picking/uploading a new avatar requires an agreed storage provider, authentication rules, upload limits, and image moderation policy.
- Trust calculation after completed transaction ratings belongs to trusted backend transaction/rating logic and is not implemented in the Profile client.

## Confirmed product decisions

- The Profile tab is the signed-in user's own account page. A public profile for other users is lower priority and remains out of the MVP unless time permits.
- The trust score is displayed on Profile but is not calculated by Flutter. It is owned by trusted backend logic.
- Trust changes should be based on ratings submitted after a completed transaction.
- A report must be reviewed before it can affect trust or cause another penalty. A report by itself is not proof of wrongdoing.
- The MVP does not need report history or moderation progress on Profile.
- Profile provides a **Safety & support** entry and a general report form. Reporting a specific user, listing, or chat should ultimately start from that object's screen and reuse the same form.
- `displayName` is a public display name, not a unique account handle. The MVP does not enforce uniqueness.
- Theme preference offers **System**, **Light**, and **Dark** and is stored locally on the device.
- Selling includes `active` and `reserved` listings. Sold contains only `sold` listings.
- A missing or failed avatar uses a safe default based on the user's initial.

## MVP Profile structure

1. Profile header: avatar, display name, verified state, trust score, edit action.
2. My marketplace: Selling and Sold.
3. Preferences: Appearance.
4. Safety & support: Report a safety issue.
5. Account: Log out.
6. Guest state: login/register entry plus appearance settings.

The old architecture explanation cards are developer documentation and must not appear in the customer Profile UI.

## Implementation boundaries

- UI talks to Providers; Providers talk to Repository interfaces.
- Profile mutations update the in-memory user and the stored local session only after the repository succeeds.
- Backend-generated fields such as trust score, reporter ID, report status, and timestamps must never be controlled by the mobile client.
- Remote avatar upload is a separate storage integration. Until it is agreed, Profile supports an existing HTTPS avatar URL and the default avatar without pretending a local file has been uploaded.
- Selling and Sold screens are read-only in this module. Listing edit/delete/status actions remain with the listing/transaction owners unless reassigned.

## Proposed APIs requiring team agreement

### Update current user

```http
PATCH /api/users/me
Authorization: Bearer <token>
```

```json
{ "displayName": "Jenny", "avatarUrl": "https://..." }
```

### Current user's listings

```http
GET /api/users/me/listings?status=active,reserved
GET /api/users/me/listings?status=sold
```

### Submit report

```http
POST /api/reports
Authorization: Bearer <token>
```

See `docs/reporting-feature-proposal.md` for the full reporting proposal.

## Trust score questions for the team

1. What is a new user's starting score?
2. Is a post-transaction rating 1–5 stars, tags, or both?
3. Must both parties confirm completion before ratings affect trust?
4. How are repeated ratings, cancelled trades, and no-shows handled?
5. How is manipulation between friends or duplicate accounts detected?
6. What high-level explanation of the score is shown to users?
7. Which reviewed report outcomes can cause a score change, warning, suspension, or ban?

## Other open questions

1. Will avatar upload use Firebase Storage, and which teammate owns Storage rules?
2. Are camera capture and image cropping MVP requirements, or is gallery selection enough?
3. Which listing endpoint/query contract will be shared with the listing owner?
4. Does the Profile owner implement only read-only Selling/Sold screens, or also listing actions?
5. Which screens will add contextual Report entry points before the final release?
6. Is an admin moderation screen required for the demonstration?
7. What report retention and privacy policy should be documented?
8. When will `averageRating`, `reviewCount`, and `completedTrades` be added to the user schema?
9. Is the issue named “username” actually a non-unique display name, or does the team require a unique `@handle` with availability checks?
10. Should users be able to change their display name freely, or is a cooldown/audit history required to reduce impersonation?
11. Which teammate owns the authenticated current-user endpoints and their Node tests?
12. Should the Profile show only one trust score, or also the rating average and number of completed trades so the score is understandable?
13. What happens when a transaction is disputed after both parties have rated each other?
14. Should reserved listings appear under Selling with a visible Reserved badge?
15. Must users be able to edit/delete a listing from the Profile list, or will those actions live in the listing module?
16. Should a guest be allowed to change appearance? Current recommendation: yes, because theme is a device preference rather than account data.

## Suggested acceptance criteria

- Guest and authenticated Profile states are clear and accessible.
- Authenticated Profile displays the real `displayName`, avatar/default avatar, verification state, and backend trust score.
- A valid display-name update survives app restart through the authenticated session.
- Theme selection applies immediately and survives app restart.
- Selling and Sold have loading, data, empty, and error states.
- Safety reporting validates input, prevents repeated taps, preserves text on recoverable errors, and gives a neutral confirmation.
- Flutter tests cover the Profile states and interactions; Node tests cover each API once backend contracts are accepted.
- The layout supports screen readers, 48×48 touch targets, and 200% text scaling.
