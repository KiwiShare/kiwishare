# Design evolution: from inception to reality

This document contains the final presentation content for issue #256. It is
intended to be incorporated into the team presentation without changing the
scope or content owned by other team members.

Editable slide section: [KiwiShare Final Presentation - Design Evolution (#256)](https://docs.google.com/presentation/d/1XG28XQgGRQvzI67DXpoVuQcF_NpDHD_ampSKu4JAupw/edit)

## Slide 1 - From broad marketplace to focused, testable journey

The trust promise stayed constant; scope and architecture changed to make it
deliverable.

| Date | Stage | What changed |
| --- | --- | --- |
| 23 July | Broad opportunity | KiwiShare began as a second-hand marketplace idea with open scope. The team agreed that user research and feasibility had to shape the product. |
| 28 July | Trust-first concept | Local discovery, in-app chat, a public meetup, confirmation and reputation became the distinctive end-to-end flow. |
| 15 August | UoA pilot MVP | The team prioritised one complete user journey. Payments, delivery, rentals and advanced AI moved outside the core release. |
| 17 September | Working product | Flutter and React clients use a Koa and TypeScript REST API, MongoDB, and bounded services for authentication, push notifications, email and media. |

**Key message:** Local, safe and trusted stayed constant. Every other decision
served that promise.

### Speaker notes (about 55 seconds)

We did not begin with a fixed feature list. On 23 July, the team had a broad
second-hand marketplace opportunity and deliberately kept the solution open
while we validated users and feasibility. By 28 July, the durable idea was
clear: local discovery had to lead into a safer, traceable exchange through
in-app chat, a public meetup, confirmation and reputation. The 15 August
product requirements turned that vision into a UoA pilot and one complete
journey, while payments, delivery, rentals and advanced AI moved out of the
core release. By 17 September, that journey had become a working product
foundation across Flutter and React clients, a Koa and TypeScript REST API,
MongoDB, Firebase Authentication and push notifications, plus bounded email
and media services. The concept evolved, but the promise did not: local, safe
and trusted.

## Slide 2 - Reality replaced assumptions with explicit trade-offs

Each decision reduced delivery risk without weakening the core trust journey.

| Decision | Early direction | Reality and reason |
| --- | --- | --- |
| Scope | A New Zealand-wide marketplace with many possible services. | A UoA pilot with explicit Must, Should, Conditional and Future scope. A focused community reduces cold-start and deadline risk. |
| Trust | Listings and chat supported by broad safety ideas. | Item-bound chat, public meetup proposals, reservation, QR handover, reporting and authenticated state changes make trust observable. |
| Architecture | Backend-as-a-Service, serverless functions and Firestore were explored. | Flutter and React clients use a shared Koa and TypeScript REST API backed by MongoDB. Firebase is bounded to authentication and push notifications, leaving one clear application source of truth. |
| Delivery | Payments, delivery, rentals and advanced AI competed for attention. | The core journey comes first. Optional AI degrades gracefully, while reliability, tests and documentation form part of the Definition of Done. |

**Key message:** The idea became real by protecting the trust promise while
reducing everything else.

### Speaker notes (about 60 seconds)

Reality forced four useful trade-offs. First, scope: a nationwide marketplace
became a focused UoA pilot with explicit Must, Should, Conditional and Future
categories. Second, trust: broad safety ideas became observable state changes,
including item-bound chat, public meetup proposals, reservation, QR handover,
reporting and authenticated confirmation. Third, architecture: the early
Backend-as-a-Service and Firestore direction was replaced by decoupled clients
using a shared Koa REST API and MongoDB; Firebase is now bounded to
authentication and push notifications. Fourth, delivery discipline: payments,
delivery, rentals and advanced AI stopped competing with the core journey.
Optional AI is allowed to fail gracefully, while tests, documentation and
security evidence are part of done. This is how the idea reached reality: we
protected the trust promise and reduced everything else.

## Evidence basis

- Team meeting minutes from 23 and 28 July 2026 document the move from an open
  marketplace concept to a local, trust-first journey.
- [Product requirements](../product-requirements/product-requirements.md)
  record the UoA pilot, prioritised journey and explicit scope categories.
- [Architecture](../architecture.md), [deployment](../deployment.md),
  [API](../api-spec.md) and [testing strategy](../testing-strategy/testing-strategy.md)
  document the implemented system and its delivery constraints.
- The `pre` branch history through 17 September 2026 provides implementation
  evidence for authentication, discovery, publishing, chat, notifications,
  meetups, QR handover, profiles and reporting.

## Accuracy boundaries

- Present early Backend-as-a-Service and Firestore content as an explored
  direction, not as the final architecture.
- Present payments, delivery and rentals as future scope, not implemented MVP
  features.
- Describe AI listing support as optional and recoverable; the core publishing
  flow must remain usable without it.
- Avoid implying guaranteed user safety. KiwiShare provides trust and safety
  mechanisms, but users still follow public-meeting guidance and report unsafe
  behaviour.
