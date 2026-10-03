# KiwiShare Product Requirements Document

| Field | Value |
| --- | --- |
| Product | KiwiShare |
| Team | Five Guys — COMPSCI 734, Semester 2, 2026 |
| Document version | 0.1 |
| Status | Draft for team review |
| Prepared on | 15 August 2026 |
| Intended release | University of Auckland pilot MVP |
| Document owner | Five Guys |
| Approval | Required from the project team before this document becomes a baseline |

> **Implementation status note — 30 September 2026:** this v0.1 document records the original pilot-scope baseline and therefore still labels several capabilities as Conditional/Future below. The repository has since implemented a recommendation engine, server-backed search suggestions, AI-assisted listing creation, Stripe-backed payment/refund flows, wallet/saved-card UI, QR handover, the React admin portal, KiwiGold/VIP promotion, event-driven watchlist alerts, and native product deep links with web fallback. The original classifications are retained for traceability; use [`../product-capabilities.md`](../product-capabilities.md) for the current implemented capability map.

## 1. Purpose

This Product Requirements Document (PRD) defines what KiwiShare must deliver for its University of Auckland pilot, how the product will be evaluated, and which proposed capabilities require an explicit scope decision before implementation.

It translates the team's elevator pitch and GitHub project backlog into testable product requirements. It does not define detailed API contracts, database schemas, source-code structure, deployment procedures, or complete business-state rules. Those concerns are governed by the linked engineering documents.

### 1.1 Normative language

The terms **shall**, **should**, and **may** are used deliberately:

- **Shall** identifies a mandatory requirement for the stated release scope.
- **Should** identifies a planned capability that is desirable but is not a release blocker unless promoted by team decision.
- **May** identifies an optional implementation choice or future enhancement.

### 1.2 Scope classification

| Classification | Meaning |
| --- | --- |
| **Must — Baseline MVP** | Required to complete the trusted end-to-end pilot journey. Failure blocks MVP release. |
| **Should — Pilot enhancement** | Planned in the backlog and valuable to the pilot, but the core release can proceed without it if the team records a scope decision. |
| **Conditional — Decision required** | Present in the backlog but inconsistent with, or not fully confirmed by, the approved pitch. It must not become a release commitment until the team resolves the associated open decision. |
| **Future — Outside pilot** | Explicitly reserved for a later growth or ecosystem phase. |

### 1.3 Source hierarchy and change control

This draft is grounded in:

1. the approved KiwiShare Elevator Pitch presentation;
2. the Five Guys GitHub Project backlog visible on 15 August 2026;
3. KiwiShare UI Design Guidelines Version 1.3.

The repository's architecture, API, schema, security, deployment, and GitLab Flow documents are related engineering baselines. Their detailed content shall be checked for consistency with this PRD during team review; this draft does not claim to replace or restate them.

After approval, this PRD becomes the product-scope baseline. A GitHub issue does not silently change product scope. Any material addition, removal, reprioritisation, or change to an acceptance criterion shall update this document through the team's normal pull-request process.

## 2. Product overview

### 2.1 Product vision

**Give every item in Aotearoa a second life by making local second-hand trading smarter, safer, and greener.**

### 2.2 Problem statement

Local second-hand trading is often fragmented across listing, messaging, meeting, payment, handover, and reputation mechanisms. Buyers and sellers may be uncertain about who they are dealing with, where to meet, whether an exchange has been completed, and whether a review reflects a real transaction.

KiwiShare addresses this problem by providing one traceable, privacy-conscious journey from discovery to verified exchange and review.

### 2.3 Value proposition

KiwiShare enables members to:

- discover relevant items in their local area;
- communicate in-app without exposing personal phone numbers;
- arrange a handover at a suitable public meetup location;
- move a listing through a clear trade lifecycle;
- confirm that an exchange took place; and
- build reputation through reviews linked to confirmed exchanges.

The product promise is: **safer trades, stronger communities, and less waste**.

### 2.4 Pilot context

The initial release is a focused University of Auckland pilot. The pilot is intended to reduce marketplace cold-start risk, validate the core trust loop in a bounded community, and generate evidence for future iteration.

KiwiShare does not guarantee a user's identity, honesty, item quality, personal safety, successful payment, or successful exchange. Product language shall not imply that KiwiShare eliminates transaction risk.

## 3. Target users and roles

### 3.1 Primary user groups

- **Students** seeking affordable nearby items or a convenient way to sell items they no longer need.
- **Young families** seeking practical second-hand goods and local exchange options.
- **Renters** who may need temporary, affordable, or easily transferable household items.

The UoA pilot prioritises students while preserving a product model that can later support the other identified groups.

### 3.2 Product roles

| Role | Description | Baseline permissions |
| --- | --- | --- |
| Unauthenticated visitor | A person who has not signed in | Access authentication and onboarding surfaces. Whether public browsing is permitted remains an open decision. |
| Registered member | An authenticated KiwiShare user | Maintain a profile and act as both a buyer and a seller. |
| Buyer | A registered member acting on an item owned by another member | Discover, watch, chat, initiate a trade, arrange a meetup, confirm an exchange, review, and report. |
| Seller | A registered member who owns a listing | Publish and manage listings, respond to buyers, manage trade progression, confirm an exchange, review, and report. |
| Moderator or administrator | An authorised operator | Review reports and take explicitly authorised moderation actions. The administrator portal scope remains conditional. |

## 4. Product goals

### 4.1 Pilot goals

The pilot shall:

1. provide a complete and understandable path from authentication to verified exchange;
2. reduce the need to disclose personal contact information;
3. support local discovery without exposing a user's precise home address;
4. make listing and trade status visible and consistent;
5. restrict verified reviews to participants in confirmed exchanges;
6. provide accessible reporting pathways throughout the trading journey;
7. operate reliably enough for controlled user-acceptance testing; and
8. collect structured feedback to guide iteration after the pilot.

### 4.2 Non-goals and product boundaries

The baseline pilot does not aim to:

- operate as a nationwide marketplace;
- provide delivery or logistics services;
- support rentals or item sharing;
- provide production-grade monetisation;
- guarantee identity, item condition, payment, or personal safety;
- provide emergency assistance;
- provide automated final decisions on reports or disputes;
- replace appropriate law-enforcement, financial, or emergency channels; or
- deliver personalised recommendation systems beyond any separately approved pilot experiment.

Payments are listed in the current backlog but in the pitch's future ecosystem roadmap. They are therefore **Conditional**, not part of the baseline MVP, until Open Decision OD-001 is approved.

## 5. Release scope

### 5.1 Must — Baseline MVP

The baseline MVP contains the minimum capabilities necessary for the trusted exchange loop:

1. authentication and basic profile management;
2. item publishing and owner-controlled listing management;
3. item browsing, conventional search, filtering, sorting, and item details;
4. item-linked in-app text chat;
5. approximate-location discovery and public meetup support;
6. trade-order creation and controlled listing/trade status progression;
7. authenticated handover confirmation, with the precise method subject to OD-002;
8. reviews and reputation derived only from confirmed exchanges;
9. reporting from relevant user, chat, and trade contexts;
10. essential notifications and history required to complete the core flow; and
11. unit, widget, integration, usability, performance, and user-acceptance validation of the core flow.

### 5.2 Should — Pilot enhancements

The following are planned enhancements but are not baseline release blockers unless promoted by team decision:

- Google sign-in in addition to email authentication;
- watchlist management and price-change notifications;
- dark mode;
- photo messages and voice messages in chat;
- AI-assisted listing-description suggestions;
- AI-assisted search;
- report-status history and follow-up email;
- extended profile inventory views; and
- a limited moderator or administrator interface.

Each enhancement shall fail safely and shall not prevent completion of the baseline flow when unavailable.

### 5.3 Conditional — Team decision required

| Capability | Backlog evidence | Pitch position | Required decision |
| --- | --- | --- | --- |
| Integrated payment and refund flow | Payment module #49 and issues #65–#68, #76 | Payments are presented as a later ecosystem capability | OD-001 |
| QR-based exchange completion | Issues #20, #21, #50 and #113–#115 | Presented as a potential confirmation method | OD-002 |
| MongoDB as the product database | Issue #24 | Database was still TBC in the pitch | OD-003 |
| AI search and publishing assistance | Issues #25 and #40 | AI publishing assistance appears in core features; smarter recommendations appear in the later roadmap | OD-004 |
| React administrator portal | Issue #34 | Not defined in the pitch | OD-005 |

### 5.4 Future — Outside the UoA pilot

- expansion through universities, student groups, and verified communities;
- nationwide expansion across Aotearoa;
- delivery integration;
- rentals and item sharing;
- production payments if not separately approved for the pilot; and
- smarter or personalised recommendations beyond approved pilot experiments.

## 6. Core user journey

The baseline happy path is:

1. A member signs up or signs in.
2. The member browses or searches for an item.
3. The member opens the item detail page.
4. The member starts an item-linked in-app conversation with the seller.
5. The buyer and seller agree on a public meetup using a structured meetup flow.
6. The seller accepts the proposed trade and the listing becomes unavailable to competing completion flows according to the domain rules.
7. At handover, the participants complete an authenticated confirmation step.
8. The trade becomes complete and the listing becomes Sold.
9. Each participant may submit one review of the other participant for that confirmed exchange.

If integrated payment is approved, the payment steps shall be inserted without weakening the listing, trade, confirmation, refund, reporting, or audit rules.

The detailed state machine, cancellation paths, concurrency rules, and dispute behaviour shall be defined in `docs/domain-rules.md` before trade implementation is considered complete.

## 7. Functional requirements

### 7.1 Authentication and session management

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-AUTH-001 | The system shall allow a new member to create an account using an email-based authentication flow. | Must | #15, #47, #56 |
| FR-AUTH-002 | The system shall allow a registered member to sign in using the supported email authentication method. | Must | #15, #16, #47, #56 |
| FR-AUTH-003 | The system shall use Firebase Authentication for the pilot unless the architecture baseline is formally changed. | Must | #4, #16; pitch testing and compliance section |
| FR-AUTH-004 | The system should support Google sign-in. | Should | #57 |
| FR-AUTH-005 | The system shall allow an authenticated member to sign out from the profile area. | Must | #89 |
| FR-AUTH-006 | The system shall prevent unauthenticated or unauthorised users from invoking protected profile, listing-management, chat, trade, review, report-history, or payment operations. | Must | Security baseline |
| FR-AUTH-007 | Authentication failures shall present an actionable, non-sensitive error message and shall not reveal whether unrelated accounts exist. | Must | Security and UI baselines |

### 7.2 Member profile

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-PRO-001 | The system shall maintain one product profile for each authenticated member. | Must | #46, #47, #58 |
| FR-PRO-002 | The profile shall display the member's username, avatar or default avatar, and approved account information without exposing private contact details to other members. | Must | #121, #131 |
| FR-PRO-003 | A member shall be able to change their username, subject to validation and moderation rules. | Must | #91 |
| FR-PRO-004 | A member shall be able to select a profile image or retain the default avatar. | Must | #131 |
| FR-PRO-005 | A member shall be able to view their active and previously sold listings. | Must | #111, #112 |
| FR-PRO-006 | The profile shall display the member's reputation summary using the approved reputation model. | Must | #73, #90 |
| FR-PRO-007 | A member shall be able to initiate a report from another member's profile where that context is available. | Must | #93 |
| FR-PRO-008 | The product should allow a member to select light or dark appearance where the platform supports it. | Should | #18, #92 |

### 7.3 Listing publication and management

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-LIST-001 | An authenticated member shall be able to create and publish an item listing using the fields defined by the approved listing schema. | Must | #22, #23, #44, #77–#79 |
| FR-LIST-002 | The publication flow shall support adding item images from the device's supported camera or media workflow. | Must | Pitch core features |
| FR-LIST-003 | The publication flow shall validate required values and display field-level correction guidance before submission. | Must | UI and schema baselines |
| FR-LIST-004 | The system shall associate each listing with exactly one owner. | Must | #43, #108, #109 |
| FR-LIST-005 | Only the listing owner or an explicitly authorised moderator shall be able to edit or remove the listing. | Must | #108, #109 |
| FR-LIST-006 | A seller shall be able to view the current publication and trade status of each owned listing. | Must | #111, trade workflow |
| FR-LIST-007 | Listing deletion shall not silently delete trade, report, review, or audit records that must be retained for an active transaction, dispute, security purpose, or approved retention period. | Must | Privacy, safety, and audit requirements |
| FR-LIST-008 | The product should offer an AI-assisted description suggestion that the seller can review, edit, ignore, or replace before publication. | Should | #25 |
| FR-LIST-009 | AI-generated content shall never be published without an explicit user action and shall not be represented as verified item information. | Should | AI risk control |

### 7.4 Discovery and item details

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-DISC-001 | The system shall provide a browsable list of available items. | Must | #36 |
| FR-DISC-002 | A member shall be able to search, filter, and sort item listings using the conventional controls approved for the pilot. | Must | #37 |
| FR-DISC-003 | The product shall provide category-based discovery using the approved category taxonomy. | Must | #39 |
| FR-DISC-004 | The product shall allow a member to select or change the location context used for discovery. | Must | #38 |
| FR-DISC-005 | With permission, the system shall be able to display nearby items using approximate location data. | Must | #26, #41, #53 |
| FR-DISC-006 | Denying or losing location permission shall not prevent conventional browsing or search. | Must | Graceful-degradation requirement |
| FR-DISC-007 | Selecting an item from a result list shall open its item detail page. | Must | #42 |
| FR-DISC-008 | The item detail page shall display the information required for a buyer to understand the listing, its current status, its seller context, and the actions currently available. | Must | #43, #106, #107 |
| FR-DISC-009 | The product should support AI-assisted search only if an unavailable or inaccurate AI service does not remove conventional search capability. | Should | #40; OD-004 |

### 7.5 Item-linked chat and notifications

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-CHAT-001 | An authenticated member shall be able to start a conversation from an eligible item detail page. | Must | #45, #85 |
| FR-CHAT-002 | Each trade-related conversation shall retain an unambiguous association with the relevant item listing and participants. | Must | Pitch core features |
| FR-CHAT-003 | Members shall be able to send and receive text messages and view conversation history. | Must | #82, #83 |
| FR-CHAT-004 | In-app chat shall not require either participant to expose a personal phone number. | Must | Product value proposition |
| FR-CHAT-005 | The system shall notify a member of a new message through an available in-app or push-notification channel, subject to permission and delivery availability. | Must | #84 |
| FR-CHAT-006 | Notification failure shall not remove the underlying message or conversation history. | Must | Reliability requirement |
| FR-CHAT-007 | The system shall provide a report action from the chat context. | Must | #100 |
| FR-CHAT-008 | User-generated chat input and supported attachments shall be validated and sanitised before processing or display. | Must | #97, #98 |
| FR-CHAT-009 | A member should be able to send an approved image attachment. | Should | #97 |
| FR-CHAT-010 | A member should be able to send an approved voice message. | Should | #96 |
| FR-CHAT-011 | A member should be able to remove a conversation from their own visible conversation list. This action shall not delete the other participant's copy or records subject to an active safety, dispute, or retention requirement. | Should | #95; retention constraint |

### 7.6 Location and meetup support

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-LOC-001 | The product shall request location access only when a location-dependent function is invoked and shall explain the purpose of the request. | Must | Privacy baseline |
| FR-LOC-002 | KiwiShare shall use approximate location for discovery and meetup support and shall not publicly expose a member's precise home address. | Must | Pitch compliance section |
| FR-LOC-003 | The product shall not perform permanent or unnecessary background location tracking. | Must | Pitch compliance section |
| FR-LOC-004 | The meetup flow shall support selecting or proposing a public meetup location through a structured interface. | Must | #53, #63, #64; pitch core journey |
| FR-LOC-005 | Where suitable data is available, the product should suggest public meetup places or designated Safe Zones. | Should | #63; pitch core features |
| FR-LOC-006 | A member who denies location access shall be able to choose an available location manually. | Must | Graceful-degradation requirement |

### 7.7 Trade and handover verification

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-TRD-001 | An authenticated buyer shall be able to initiate an eligible trade from the item detail page. | Must | #48, #116 |
| FR-TRD-002 | A valid trade initiation shall create one traceable trade order linked to the buyer, seller, and listing. | Must | #117 |
| FR-TRD-003 | The system shall prevent a member from buying their own listing. | Must | Core business rule |
| FR-TRD-004 | The trade workflow shall provide explicit states for initiation, seller decision, reservation, cancellation, completion, and any approved dispute or refund path. | Must | Pitch core journey; `domain-rules.md` |
| FR-TRD-005 | When a seller accepts an eligible trade, the listing shall become Reserved according to the approved concurrency rules. | Must | Pitch speaker notes |
| FR-TRD-006 | The system shall prevent multiple trades from simultaneously completing against the same listing. | Must | Integrity requirement |
| FR-TRD-007 | Completion shall require an authenticated handover-confirmation action by the approved participant or participants. | Must | #50; pitch core journey |
| FR-TRD-008 | After valid completion, the trade shall become complete and the listing shall become Sold atomically or through a recoverable consistency mechanism. | Must | #114; pitch core journey |
| FR-TRD-009 | A failed or repeated confirmation request shall not create duplicate completed trades, charges, or reviews. | Must | Integrity and idempotency requirement |
| FR-TRD-010 | If QR confirmation is approved, the code or token shall be transaction-specific, time-bounded or single-use, validated by a privileged service, and unusable after successful completion or cancellation. | Conditional | #20, #21, #113–#115; OD-002 |

### 7.8 Reviews and reputation

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-REV-001 | Only participants in a confirmed exchange shall be eligible to review each other for that exchange. | Must | #52, #70; pitch compliance section |
| FR-REV-002 | Each eligible participant shall be able to submit no more than one review of the other participant for the same trade. | Must | Reputation integrity |
| FR-REV-003 | The system shall reject self-reviews and reviews submitted by users who were not participants in the trade. | Must | Reputation integrity |
| FR-REV-004 | The reputation summary shall be derived from eligible review records using an approved and documented calculation. | Must | #71, #73, #90; OD-006 |
| FR-REV-005 | The product shall distinguish product reputation from a regulated financial credit score and shall not describe it in a misleading way. | Must | Terminology risk; OD-006 |

### 7.9 Reporting and user safety

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-REP-001 | A member shall be able to submit a report from relevant profile, chat, and trade contexts. | Must | #51, #93, #99, #100 |
| FR-REP-002 | The report form shall capture an approved reason, description, relevant object references, and optional supporting evidence subject to validation and privacy controls. | Must | #101, #102 |
| FR-REP-003 | The system shall acknowledge successful report submission without promising a resolution or response time that the team cannot provide. | Must | Safety communication requirement |
| FR-REP-004 | A report shall not be disclosed to the reported user through ordinary product surfaces. | Must | Reporter safety requirement |
| FR-REP-005 | Authorised moderators shall be able to access the information necessary to review a report, subject to least-privilege controls and auditability. | Must | Moderation requirement |
| FR-REP-006 | The product should allow the reporter to view an appropriate report status and history. | Should | #103 |
| FR-REP-007 | The product should send a follow-up email after report submission when a supported email service is configured. | Should | #104 |
| FR-REP-008 | The safety experience shall include report and block controls before public pilot release. The precise block behaviour shall be defined in `docs/domain-rules.md`. | Must | Pitch compliance section |
| FR-REP-009 | The product shall display public-meeting safety guidance at the appropriate point in the meetup flow. | Must | Pitch compliance section |

### 7.10 Watchlist

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-WAT-001 | A member should be able to add an eligible item to a personal watchlist. | Should | #54, #87 |
| FR-WAT-002 | A member should be able to remove an item from their watchlist. | Should | #88 |
| FR-WAT-003 | The watchlist should support list display, search, filtering, sorting, and navigation to item details. | Should | #59–#61 |
| FR-WAT-004 | The system should notify an opted-in watcher when a watched item's price changes, subject to notification availability. | Should | #62, #69, #132 |
| FR-WAT-005 | A watchlist notification shall not imply that an item remains available at the time the notification is opened. | Should | Marketplace consistency requirement |

### 7.11 Integrated payment

All requirements in this section are inactive until OD-001 is approved.

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-PAY-001 | If approved, the pilot shall use the selected payment provider's sandbox or test mode unless the team has completed a separate production-readiness and compliance review. | Conditional | #49, #65, #66 |
| FR-PAY-002 | If approved, the product shall display the amount, item, payer, payee context, and action outcome clearly before and after a payment attempt. | Conditional | #67, #68 |
| FR-PAY-003 | Payment processing shall occur through privileged backend logic; secret keys and privileged operations shall not be exposed in the Flutter client. | Conditional | Security baseline |
| FR-PAY-004 | Payment retries shall be idempotent and shall not create duplicate charges or duplicate trade completion. | Conditional | Integrity requirement |
| FR-PAY-005 | Approved cancellation and refund states shall be defined before the payment flow is accepted. | Conditional | #67; `domain-rules.md` |
| FR-PAY-006 | A payment-provider failure shall result in a recoverable, non-completed state with an actionable user message. | Conditional | Reliability requirement |

### 7.12 Moderator or administrator capability

| ID | Requirement | Priority | Traceability |
| --- | --- | --- | --- |
| FR-ADM-001 | If approved, the administrator interface shall be accessible only to explicitly authorised accounts. | Conditional | #34; OD-005 |
| FR-ADM-002 | Administrator actions shall be limited to the approved moderation and content-management use cases and shall be auditable. | Conditional | #34; security baseline |
| FR-ADM-003 | Whether administrators may create listings shall be decided explicitly; it shall not be assumed from the current task title. | Conditional | #34; OD-005 |

## 8. Non-functional requirements

### 8.1 Security

| ID | Requirement |
| --- | --- |
| NFR-SEC-001 | All application-to-service communication shall use HTTPS/TLS in deployed environments. |
| NFR-SEC-002 | Protected backend operations shall validate authentication and authorisation independently of client-side UI controls. |
| NFR-SEC-003 | Privileged QR, moderation, payment, and security-sensitive trade operations shall execute through trusted backend functions. |
| NFR-SEC-004 | Secrets, private keys, service-account files, and real environment values shall not be committed to the repository or embedded in the client. |
| NFR-SEC-005 | User-generated text and uploaded files shall be validated for supported type, size, structure, and unsafe content before use. |
| NFR-SEC-006 | Security controls shall follow the repository's `docs/security-owasp.md` baseline. |

### 8.2 Privacy

| ID | Requirement |
| --- | --- |
| NFR-PRI-001 | KiwiShare shall collect personal information only when it is necessary for a defined product purpose. |
| NFR-PRI-002 | Exact home addresses and permanent location histories shall not be required for the baseline trading flow. |
| NFR-PRI-003 | Access to chat, trade, report, location, and payment data shall be limited according to role and purpose. |
| NFR-PRI-004 | Personal information shall be deleted or anonymised when it is no longer required for an active account, trade, dispute, safety, legal, or approved operational purpose. |
| NFR-PRI-005 | Exact retention periods for each data category shall be approved before public pilot release and recorded in the security or data-governance documentation. |
| NFR-PRI-006 | Logs, analytics, notifications, and crash reports shall avoid unnecessary message content, precise location, payment details, secrets, or other sensitive personal information. |

These requirements are product controls intended to support privacy-conscious design; they are not a legal-compliance certification.

### 8.3 Accessibility and user experience

| ID | Requirement |
| --- | --- |
| NFR-ACC-001 | The Flutter application shall implement the approved KiwiShare UI Design Guidelines Version 1.3. |
| NFR-ACC-002 | Core flows shall target WCAG 2.2 Level AA principles and applicable success criteria, including contrast, semantic labels, focus visibility, clear error identification, and sufficient target size. |
| NFR-ACC-003 | Meaning shall not be communicated by colour alone. |
| NFR-ACC-004 | Core buyer, seller, authentication, reporting, and confirmation flows shall be usable with supported screen-reader and text-scaling settings. |
| NFR-ACC-005 | Loading, empty, offline, success, and failure states shall provide understandable feedback and recovery actions. |

### 8.4 Reliability and graceful degradation

| ID | Requirement |
| --- | --- |
| NFR-REL-001 | The core listing, chat-history, trade, and report records shall not rely solely on transient device state. |
| NFR-REL-002 | Loss of location, AI, push notification, camera, or optional payment service shall not corrupt product state. |
| NFR-REL-003 | Location or AI failure shall not prevent conventional browsing, search, manual location selection, or manual listing entry. |
| NFR-REL-004 | Recoverable network failures shall provide retry or refresh behaviour without creating duplicate writes. |
| NFR-REL-005 | Backup, restore, and recovery expectations shall be defined in the deployment documentation before pilot release. |

### 8.5 Performance and capacity

| ID | Requirement |
| --- | --- |
| NFR-PERF-001 | The team shall establish measurable response-time and reliability targets for the core flow before executing the performance-test plan. |
| NFR-PERF-002 | The product shall remain responsive for the agreed UoA pilot load and representative listing, chat, and notification volumes. |
| NFR-PERF-003 | Image upload and processing shall provide progress and failure feedback and shall not block unrelated navigation longer than necessary. |
| NFR-PERF-004 | The system shall use pagination or another bounded retrieval strategy for growing item, chat, report, and watchlist collections. |

Numeric targets are intentionally not invented in this draft. They shall be added after the team confirms the pilot environment, dataset, and measurement method.

### 8.6 Observability and operations

| ID | Requirement |
| --- | --- |
| NFR-OBS-001 | The deployed Flutter application should use an approved crash-reporting mechanism such as Firebase Crashlytics. |
| NFR-OBS-002 | Backend services shall produce structured operational and security-relevant logs without unnecessary personal information. |
| NFR-OBS-003 | Critical failures in authentication, publishing, trade creation, confirmation, reporting, and conditional payment shall be diagnosable from approved logs and request identifiers. |
| NFR-OBS-004 | Monitoring and operational data shall follow approved access and retention controls. |

### 8.7 Quality verification

| ID | Requirement |
| --- | --- |
| NFR-TST-001 | New or changed domain and service logic shall have appropriate unit tests. |
| NFR-TST-002 | Core Flutter states and interactions shall have appropriate widget tests. |
| NFR-TST-003 | Authentication, publishing, discovery, chat, trade, confirmation, reporting, and review shall be covered by integration tests appropriate to the implemented architecture. |
| NFR-TST-004 | The end-to-end happy path shall be demonstrated in a pilot-like environment before release. |
| NFR-TST-005 | The team shall conduct usability and user-acceptance testing with representative campus-pilot users. |
| NFR-TST-006 | Release-blocking test scope, commands, environments, and pass criteria shall be defined in `docs/testing-strategy.md`. |

## 9. Data categories and handling constraints

| Data category | Examples | Product purpose | Key constraint |
| --- | --- | --- | --- |
| Account data | Authentication identifier, email, username, avatar | Account access and profile | Do not expose private account details to other members without a defined need. |
| Listing data | Item content, images, price, category, approximate area, status | Marketplace discovery and selling | Owner-controlled; status must remain consistent with active trades. |
| Location data | Approximate discovery area, selected meetup place | Nearby discovery and handover coordination | No unnecessary exact home address or permanent background history. |
| Communication data | Item-linked messages and approved attachments | Buyer–seller coordination and safety | Participant access only, subject to authorised safety review and retention rules. |
| Trade data | Buyer, seller, listing, state changes, confirmation | Traceable exchange lifecycle | Immutable or auditable critical transitions; no duplicate completion. |
| Review data | Rating and approved review content | Reputation after confirmed exchange | Only eligible participants; one review per direction per trade. |
| Report data | Reason, description, evidence, status | Safety and moderation | Restricted access; protect reporter confidentiality. |
| Watchlist data | Watched items and notification preferences | Personal tracking and alerts | Private to the member and authorised services. |
| Payment data | Provider references and transaction state, if enabled | Conditional payment workflow | Do not store sensitive payment credentials in KiwiShare systems. |
| Operational data | Logs, crash reports, request identifiers | Reliability, security, and support | Minimise personal information and apply access and retention controls. |

## 10. Pilot acceptance and release criteria

The baseline MVP is ready for controlled pilot use only when all of the following are true:

1. The team has approved this PRD and resolved all release-blocking open decisions.
2. A new user can complete the core journey from account creation to confirmed exchange and eligible review.
3. Listing, trade, confirmation, review, and report records remain consistent during expected retries and failure cases.
4. Unauthorised users cannot access protected profile, listing-management, chat, trade, report, moderation, or conditional payment operations.
5. Exact home addresses and permanent background location tracking are not required by the baseline flow.
6. Reporting and blocking are available in the approved contexts.
7. Core automated tests and the agreed CI checks pass.
8. No unresolved critical or high-severity defect remains in the core journey unless the team records a justified release decision.
9. Representative usability and UAT sessions confirm that users can understand and complete the core flow.
10. Monitoring, operational ownership, backup expectations, and rollback guidance are documented.
11. Known limitations and conditional features are communicated accurately.

## 11. Assumptions and dependencies

### 11.1 Assumptions

- The first controlled pilot is centred on the University of Auckland community.
- A registered member may act as both a buyer and a seller.
- Internet connectivity is normally required for authenticated marketplace operations.
- Device access to location, camera, and notifications is permission-based and may be denied.
- Optional services shall not be required to preserve the integrity of the core flow.
- The project is an academic implementation and shall not be presented as a production-certified financial, identity, safety, or moderation service.

### 11.2 Technical dependencies requiring alignment

- Flutter mobile client and its CI/CD workflow (#2, #4, #7).
- Firebase Authentication (#16).
- Node.js privileged backend or cloud functions (#3, #19, #21, #23).
- REST API and shared schemas.
- Realtime chat and notification services.
- Selected database and data model; the backlog currently proposes MongoDB (#24), while the pitch recorded the database as TBC.
- Location/map data and permission support (#26, #53).
- Crash reporting, backend logging, backup, and recovery.
- Conditional providers for AI, email, payment, and administrator capabilities.

## 12. Principal risks and required product responses

| Risk | Product response |
| --- | --- |
| Marketplace cold start | Begin with a bounded UoA pilot and prioritise a complete core journey over broad feature volume. |
| Fraud, misrepresentation, or unsafe conduct | Use authenticated accounts, traceable trades, confirmed-exchange reviews, reporting, blocking, and public-meeting guidance without claiming zero risk. |
| Precise-location exposure | Use approximate discovery location, public meetup choices, just-in-time permission requests, and no permanent background tracking. |
| Concurrent buyers or duplicate completion | Define enforceable state transitions, concurrency controls, and idempotent write operations. |
| Harmful user-generated content | Validate and sanitise content, provide reporting, restrict moderation access, and define retention and evidence handling. |
| Unreliable AI output | Keep AI assistance optional, editable, labelled as assistance, and backed by a complete manual path. |
| Payment complexity | Keep payment outside the baseline until scope, provider, refund, security, test-mode, and operational rules are approved. |
| Notification or location failure | Preserve in-app records and manual alternatives; do not depend on transient notification delivery for correctness. |
| Feature overload | Apply Must/Should/Conditional/Future classifications and require a PRD change for scope promotion. |
| Ambiguous reputation language | Use a defined marketplace reputation model and avoid misleading financial-credit terminology. |

## 13. Backlog traceability summary

| Backlog module | Issues observed | PRD coverage | Baseline status |
| --- | --- | --- | --- |
| Happy path and foundational integration | #10, #15–#26 | Sections 6–8, 11 | Mixed Must/Should/Conditional |
| Products page | #36–#42, #81 | FR-DISC | Must, except AI search |
| Product detail | #43, #106–#110 | FR-DISC, FR-LIST | Must |
| Publish item | #44, #77–#80 | FR-LIST | Must |
| Chat | #45, #82–#86, #95–#98 | FR-CHAT | Text and safety Must; media/voice Should |
| Profile | #46, #90–#94, #111, #112, #131 | FR-PRO | Mixed Must/Should |
| Authentication | #47, #56–#58, #89, #120, #121 | FR-AUTH, FR-PRO | Email Must; Google Should |
| Trade | #48, #116–#118 | FR-TRD | Must |
| Payment | #49, #65–#68, #76 | FR-PAY | Conditional |
| Verification order | #50, #113–#115 | FR-TRD | Confirmation Must; QR method Conditional |
| Report abuse | #51, #99–#105 | FR-REP | Core reporting Must; status/email Should |
| User reputation | #52, #70–#73 | FR-REV | Must |
| Location finding | #53, #63, #64, #74 | FR-LOC | Manual/public meetup Must; suggestions Should |
| Watchlist | #54, #59–#62, #69, #75, #87, #88, #132 | FR-WAT | Should |
| Administrator portal | #34 | FR-ADM | Conditional |
| UI design guidelines | #119, #130 | NFR-ACC | Must baseline |
| Development, flow, deployment docs | #124–#126 | Related engineering documents | Must before release |

This matrix demonstrates coverage, not automatic acceptance of every backlog issue into the baseline MVP.

## 14. Open decisions

The team shall record each decision in this table and update all affected issues and specifications.

| ID | Decision required | Why it matters | Current recommendation | Status |
| --- | --- | --- | --- | --- |
| OD-001 | Is integrated Stripe payment included in the UoA pilot? | The backlog treats it as high priority, while the pitch places payments in the later ecosystem phase. It materially expands security, refund, testing, and operational scope. | Keep production payment outside the baseline. If needed for demonstration, use a clearly isolated sandbox prototype that does not block the non-payment exchange flow. | Open |
| OD-002 | What exact action confirms handover, and is QR mandatory? | The pitch described QR as potential, while the backlog implements dual QR verification. State transitions and fraud controls depend on this. | Require authenticated bilateral confirmation; use a single-use transaction QR only if the team can define expiration, replay prevention, fallback, and cancellation behaviour. | Open |
| OD-003 | What are the final database, BaaS, realtime, and Node.js responsibility boundaries? | The pitch recorded these as TBC, while the backlog proposes MongoDB and an 80/20 hybrid model. | Resolve in `architecture.md` before parallel feature implementation creates incompatible data paths. | Open |
| OD-004 | Which AI features are in the pilot, and are they release blockers? | AI publishing assistance appears in the pitch and backlog; AI search is also in the backlog; smarter recommendations are future roadmap. | Treat publishing and search assistance as optional, non-blocking enhancements with complete manual fallbacks. | Open |
| OD-005 | What is the administrator portal's approved role? | Issue #34 mentions posting and managing items, but the product need and permissions are not defined. | Limit the first administrator surface to report/content moderation if it is required at all. Do not allow administrator listing publication without a documented use case. | Open |
| OD-006 | How is marketplace reputation calculated and named? | The backlog uses “credit score,” which could be misunderstood as a financial score. | Use “rating” or “reputation score”; document the formula, eligibility, rounding, and treatment of deleted reviews. | Open |
| OD-007 | What are the exact listing and trade states, cancellation paths, and concurrency rules? | These rules affect every client, API, schema, and test. | Resolve in `domain-rules.md` before trade implementation is accepted. | Open |
| OD-008 | What does “delete chat” mean? | Local hiding, bilateral deletion, and permanent record deletion have different privacy and safety consequences. | Treat it as removal from the requesting user's active list while retaining records only as required by approved retention and safety rules. | Open |
| OD-009 | What are the moderation workflow, report statuses, operator ownership, and response expectations? | The product currently promises report progress without defining who processes reports. | Define a small set of honest statuses and avoid an SLA the student team cannot operate. | Open |
| OD-010 | What are the approved data-retention periods? | Chat, reports, trades, reviews, logs, and deleted accounts have different purposes. | Establish a purpose-based retention schedule before public pilot use. | Open |
| OD-011 | Can unauthenticated visitors browse listings? | It affects privacy, discovery, authentication, and API access rules. | Decide explicitly; require authentication for interaction and protected data in all cases. | Open |
| OD-012 | What are the four pilot categories and supported location areas? | Backlog tasks assume four category tabs and dedicated location choices but do not identify them. | Approve a small pilot taxonomy and location set, then keep values schema-driven. | Open |

## 15. Related documents

- `docs/architecture.md`
- `docs/api-spec.md`
- `docs/deployment.md`
- `docs/design-guidelines/kiwishare-ui-design-guidelines-v1.3.md`
- `docs/domain-rules.md` — planned
- `docs/git-flow.md`
- `docs/schemas/`
- `docs/security-owasp.md`
- `docs/testing-strategy.md` — planned
- `docs/development-standards.md` — planned or represented by the team's development-standard document

## 16. References

### 16.1 Team sources

- Five Guys, *COMPSCI 734 — KiwiShare Elevator Pitch Assignment 1*, 2026.
- Five Guys GitHub Project backlog, issues and modules visible on 15 August 2026.
- Five Guys, *KiwiShare UI Design Guidelines Version 1.3*, 2026.

### 16.2 External standards and official guidance

- New Zealand Office of the Privacy Commissioner, [Privacy Principle 1 — Purpose for collection of personal information](https://www.privacy.org.nz/privacy-principles/1/).
- New Zealand Office of the Privacy Commissioner, [Privacy Principle 9 — Retention of personal information](https://www.privacy.org.nz/privacy-principles/9/).
- W3C, [Web Content Accessibility Guidelines (WCAG) 2.2](https://www.w3.org/TR/WCAG22/).
- Firebase, [Firebase Authentication](https://firebase.google.com/docs/auth/).
- Firebase, [Get started with Crashlytics for Flutter](https://firebase.google.com/docs/crashlytics/flutter/get-started).

## 17. Approval record

| Role or reviewer | Name | Decision | Date | Notes |
| --- | --- | --- | --- | --- |
| Product scope reviewer | TBD | Pending | TBD |  |
| Flutter representative | TBD | Pending | TBD |  |
| Backend representative | TBD | Pending | TBD |  |
| Testing/security reviewer | TBD | Pending | TBD |  |
