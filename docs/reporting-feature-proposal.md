# KiwiShare Reporting Feature Proposal

**Status:** Proposal for team discussion  
**Related issue:** #93 — User can report in the profile page  
**Parent issue:** #46 — Me/Profile Module  
**Prepared:** 14 August 2026

> Implementation note: the reusable Profile report form UI is present on branch
> `46-me-profile-module`, but persistence is deliberately not claimed as complete.
> The backend contract and moderation ownership below still require team approval.

## 1. Decision needed

Issue #93 does not currently define what can be reported, where reporting starts, or what the Profile page should show afterward. The team should agree on these points before the mobile and backend implementations are finalised.

The central design question is:

> Should reporting be a general form inside the user's own Profile, or should it start from the specific user, listing, chat, or transaction being reported?

## 2. Recommended product design

Reporting should normally start from the object or interaction that caused the concern:

| Entry point | Report target | Context captured automatically |
|---|---|---|
| Another user's profile | User | Reported user ID |
| Listing details | Listing | Listing ID and seller ID |
| Chat or transaction | Buyer/seller behaviour | Chat or transaction ID and participants |
| Current user's Profile | Safety and support | General safety issue only |

This approach reduces user effort and reporting mistakes because the app already knows who or what is being reported. It also gives moderators useful context without asking the reporter to copy IDs manually.

The current user's Profile should contain a **Safety & support** section with a **Report a safety issue** entry. This is suitable for general concerns or for cases where the relevant listing or chat is no longer available. It should not be the only reporting route.

## 3. Proposed reporting flow

1. User selects **Report** from a user profile, listing, chat, transaction, or Safety & support.
2. App explains that reports are confidential and should be accurate.
3. User selects a reason appropriate to the target.
4. User adds optional supporting details. A short description may be required for **Other**.
5. App shows the selected target and asks for confirmation.
6. Submission is sent once; the submit action is disabled while the request is in progress.
7. App confirms: **“Thanks for helping keep KiwiShare safe. We’ll review your report.”**

The confirmation must not promise that the reported account or listing will be removed.

## 4. Suggested report reasons

### User or chat

- Scam or fraud
- Harassment or abusive behaviour
- Unsafe meetup behaviour
- Did not show up repeatedly
- Fake identity or impersonation
- Suspicious payment request
- Asked to move communication off-platform
- Other

### Listing

- Misleading information
- Prohibited or unsafe item
- Counterfeit item
- Suspected stolen item
- Duplicate listing or spam
- Other

The app should store stable reason codes such as `scam_or_fraud` and present friendly labels in the UI.

## 5. MVP recommendation

For the course MVP, implement:

- A reusable report form that accepts a target type and optional target/context IDs.
- A **Safety & support** entry on the Profile page.
- Entry points that other feature owners can later add to listing, chat, and public-profile screens.
- Reason selection, supporting details, validation, loading, success, and failure states.
- Authenticated `POST /api/reports` submission.
- Backend storage with an initial `submitted` status.
- Flutter and Node tests for validation, authentication, successful submission, and server failure.

Do not require the MVP to include:

- A full report-history screen.
- Live moderation progress.
- Appeals or two-way messages with moderators.
- Automated suspension or banning.
- Evidence uploads unless the team explicitly prioritises them.

## 6. Report history and outcome visibility

The Profile page does not need to show report history for the initial MVP. Supporting it would require a moderation workflow, a report-query API, privacy rules, and careful decisions about which outcomes may be disclosed.

If the team later adds history, show only limited information, for example:

- Report type
- Submitted date
- High-level status: `submitted`, `reviewing`, or `closed`

Do not expose moderator notes, enforcement details, or unnecessary information about the reported person. A closed report should not imply that a particular punishment occurred.

## 7. Proposed data contract

```json
{
  "id": "report_uuid",
  "reporterId": "current_user_id",
  "targetType": "user",
  "targetId": "reported_user_id",
  "contextType": "chat",
  "contextId": "chat_id",
  "reason": "scam_or_fraud",
  "details": "The seller requested payment before the meetup.",
  "status": "submitted",
  "createdAt": "timestamp"
}
```

Suggested target types are `user`, `listing`, and `general`. Suggested context types are `profile`, `listing`, `chat`, `transaction`, and `general`.

The backend, not the client, should generate `id`, obtain `reporterId` from the authenticated user, set the initial status, and set `createdAt`.

## 8. Proposed API

```http
POST /api/reports
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

Example request:

```json
{
  "targetType": "user",
  "targetId": "reported_user_id",
  "contextType": "chat",
  "contextId": "chat_id",
  "reason": "scam_or_fraud",
  "details": "The seller requested payment before the meetup."
}
```

The API should validate allowed enum values and text length, require authentication, reject self-reporting where inappropriate, and rate-limit repeated reports against the same target.

## 9. Safety, privacy, and moderation considerations

- Keep the reporter's identity confidential from the reported user.
- Collect only information needed to assess the report.
- Do not let the mobile client choose the reporter ID or moderation status.
- Protect report data with stricter access rules than normal marketplace content.
- Prevent rapid duplicate submissions.
- Preserve enough context for review without exposing private chat content unnecessarily.
- AI may help prioritise reports, but should not automatically ban or penalise users.
- For immediate danger, physical safety, theft, or serious fraud, advise users to contact New Zealand Police or emergency services; KiwiShare reporting is not an emergency service.

## 10. Accessibility and content requirements

- Minimum touch target: 48 × 48 px.
- Support 200% text scaling and screen readers.
- Use labels as well as icons and colours.
- Preserve entered text after a recoverable submission error.
- Explain why information is requested.
- Use clear NZ English and avoid technical moderation terms.

## 11. Questions for the next team meeting

1. Does Issue #93 cover only a Profile safety entry, or the reusable reporting flow for the whole app?
2. Which report targets are required for the MVP: users, listings, chats, or all three?
3. Which team member owns report entry points outside the Profile module?
4. Is a report-history screen required before final submission?
5. Who will review reports during the course demo, and is an admin view needed?
6. Should `did_not_show_up` be a report reason, a transaction rating, or both?
7. What text-length limits and duplicate-report rules should the backend enforce?
8. Does the team want optional evidence uploads, or should they remain out of scope?
9. What retention period and Firestore access rules will apply to report data?
10. Should the current #93 title be rewritten with explicit acceptance criteria after the meeting?

## 12. Proposed acceptance criteria for Issue #93

- An authenticated user can open reporting from **Safety & support** in Profile.
- The report form receives any supplied target and context automatically.
- The user must choose a valid reason and can provide supporting details.
- The UI prevents duplicate submission while loading.
- A successful submission displays a neutral acknowledgement.
- A failed submission preserves the user's input and offers retry.
- Reports are stored through an authenticated backend endpoint.
- The reporter cannot set the reporter ID, status, or creation time.
- Flutter and Node tests cover validation, success, authentication failure, and server failure.
