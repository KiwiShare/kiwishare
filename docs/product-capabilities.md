# KiwiShare Product Capabilities

> **Product thesis:** KiwiShare closes the marketplace loop from **discovery → trust → communication → payment → physical handover → reputation** instead of treating second-hand trading as a listing board plus chat.

This document is the concise product-capability map for presentations, demos, README references, and architecture discussions. It describes capabilities that are implemented in the current repository; implementation details and caveats remain documented in the architecture, API, security, and testing documents.

---

## 1. PPT-ready product highlights

| Capability | What is distinctive about it |
| --- | --- |
| **Smart search suggestions** | Full-screen marketplace search provides server-backed search-as-you-type suggestions across active listings, categories, descriptions, and location context. |
| **Personalised recommendation engine** | Recommendations are scored from watchlist/category affinity, title-keyword affinity, geographic proximity, favourites, views, freshness, sustainability, and condition rather than using a static “popular items” list. |
| **Native deep links + smart web handoff** | Shared short links use kiwishare.online/s/:itemId. Mobile visitors are handed to kiwishare:///items/:itemId when the app is installed; otherwise they see a branded install landing page with App Store / Android options and **Continue on web**. |
| **AI listing copilot** | Google Gemini can turn seller context and listing images into editable listing suggestions, reducing the work needed to publish a useful item description. |
| **Google Maps + location-aware marketplace** | Native Google Maps, device geolocation and geocoding connect nearby discovery, listing location, meetup context, and directions. |
| **Unified cross-platform transaction engine** | Mobile and web render the same backend-owned order/payment/meetup/handover state. Payment and meetup can happen in either order, while handover remains locked until both prerequisites are satisfied. |
| **Event-driven watchlist alerts** | Watchlist price drops can fan out to push + email with notification history/rate limiting; price increases and nearby same-category listings use preference-aware push alerts. |
| **Membership + listing promotion economy** | KiwiGold credits fund listing boosts; VIP membership supports monthly access, expiry and auto-renew controls, including unlimited promotion behavior for eligible members. |
| **Safe Pay, saved cards, refunds and seller release** | Stripe PaymentIntents, saved payment methods, refund handling and seller-release state are integrated into the order lifecycle. KiwiShare tracks an escrow-style application state instead of trusting client-reported payment completion. |
| **QR-verified physical handover** | A seller can present a single-use handover QR and the authenticated buyer can scan it to complete a real-world exchange. The authoritative QR claim path atomically consumes the credential, completes the order and transfers ownership. |
| **Trust, reputation + student verification** | Profiles combine transaction-derived Trust Score, verified-exchange reviews, student verification, verification benefits and marketplace safety/reporting signals. |
| **Meetup negotiation + offline coordination** | Buyers and sellers can propose, confirm, reschedule or decline meetups while seeing the related order, location/map, calendar context, transaction step and handover readiness. |
| **Rich marketplace chat** | Item-linked conversations support text, image and voice messages, unread/read state and transaction/meetup status cards without forcing users to exchange private phone numbers. |
| **Governance, reports + marketplace operations** | Reporting, user moderation, listing moderation/reassignment, category controls and an admin dashboard with transaction/GMV/platform-fee visibility provide an operational layer beyond the consumer UI. |
| **Cloud media pipeline** | Listing/chat media use direct Cloudflare R2 presigned uploads; voice messages combine native recording/playback with backend validation/transcoding instead of routing every binary through a monolithic API path. |

---

## 2. The marketplace loop

### Discovery
- Conventional search, filters, sorting, categories and location-aware browsing.
- Server-backed **search-as-you-type** suggestions.
- Recommendation scoring that combines explicit interest and marketplace signals.
- Featured/promoted inventory integrates monetisation into discovery without replacing organic recommendations.
- Public short links make products shareable outside KiwiShare and preserve a path back into the app.

### Trust
- Student email verification and visible verification state.
- Trust Score updated from eligible completed transactions.
- Reviews tied to completed marketplace exchanges.
- Reporting and moderation flows for users, listings and transaction contexts.
- Admin controls for bans, trust adjustments, listing reassignment and category operations.

### Communication
- Item-linked text chat.
- Photo messaging backed by object storage.
- Native voice recording and playback with backend audio processing.
- Read/unread state and notification delivery.
- Transaction and meetup context can be surfaced inside chat rather than forcing users to reconstruct state from separate screens.

### Payment and transaction state
- Stripe-backed payment creation/verification.
- Saved payment methods and wallet UI.
- Refund paths and idempotent payment records.
- Backend-owned order state machine shared by mobile and web.
- Seller-release/completion state is tied to verified handover rather than a client-only button.

### Physical handover
- Structured meetup proposal, confirmation, rescheduling and cancellation.
- Map/location context for the offline meeting.
- QR handover gating after required transaction conditions are satisfied.
- Buyer/seller bilateral confirmation is also supported as a separate completion path.
- Completed handover feeds ownership, order history, Trust Score and review eligibility.

### Retention and monetisation
- Watchlists are not just bookmarks: they become inputs to recommendations and notification events.
- Price-change and nearby/category alerts can return users to relevant inventory.
- KiwiGold provides a promotion currency.
- VIP membership supports recurring membership state and promotion benefits.
- Promoted inventory participates in featured/search surfaces while remaining identifiable as promoted.

---

## 3. Additional differentiators worth mentioning in a presentation

These are easy to overlook because they sit underneath the visible marketplace flow:

1. **Rich-media communication stack** — photo + voice messaging is a substantially stronger product story than “we have chat.”
2. **Admin / governance system** — the platform has operational controls, reporting and live marketplace analytics rather than only buyer/seller screens.
3. **Refund and dispute-aware lifecycle** — payment is connected to cancellation/refund/dispute states instead of stopping at “Payment succeeded.”
4. **Direct-to-object-storage media architecture** — presigned R2 uploads reduce API bandwidth/memory pressure and demonstrate production-oriented system design.
5. **Cross-platform source of truth** — the strongest architectural point is not merely “Flutter + React”; it is that both clients consume the same server-derived transaction state and rules.
6. **Physical/digital bridge** — meetup + maps + QR + ownership transfer makes an offline handover a verifiable state transition inside the digital system.
7. **Marketplace feedback loop** — watchlist behavior influences recommendations; transaction outcomes influence reputation; promotion influences discovery; notification events bring users back into inventory.
8. **Feature flags / remote configuration** — Firebase Remote Config gives the mobile product an operational control plane for selected behavior without a full app-store release.

---

## 4. Important wording for presentations

Use **“smart search suggestions”** for the current autocomplete path. The current endpoint is deterministic/server-backed; an AI/semantic-search experiment is feature-flagged but should not be presented as the active model-generated search path.

Use **“Stripe-backed Safe Pay with escrow-style application state and seller release”** rather than claiming KiwiShare itself is a regulated escrow institution.

Use **“recommendation engine”** rather than “AI recommendations” unless the specific ranking path uses a model. The current recommendation endpoint is a transparent weighted scoring system based on watchlist similarity, proximity, engagement, freshness, sustainability and condition.

Use **“AI-assisted listing creation”** rather than “AI-generated listings.” The seller remains responsible for reviewing and publishing the final content.

Use **“native deep link with smart web fallback”** for the current kiwishare:// + /s/:id flow. This is different from an HTTPS Universal Link / Android App Link association, which can be added later if the product needs OS-level verified-domain routing.

---

## 5. Supporting technical evidence

- Recommendation logic: server/src/routes/usedItems.ts
- AI listing assistance: server AI/listing suggestion routes and mobile publish flow
- Short-link/deep-link handoff: mobile/lib/services/share_service.dart, iOS/Android platform manifests, web/src/pages/ShareLinkLandingPage.tsx
- Transaction state: order/payment/meetup routes plus server/src/services/orderFlowState.ts
- Payment lifecycle: server/src/routes/payments.ts, server/src/models/Payment.ts
- Meetup/handover: server/src/routes/meetups.ts, transaction/QR routes, mobile meetup screens
- Notifications/watchlist: server/src/routes/notifications.ts, server/src/routes/watchlist.ts, watchlist alert services
- Membership/promotions: payment plans and promotion routes in server/src/routes/payments.ts and server/src/routes/usedItems.ts
- Trust/reviews/moderation: user, review, report and admin routes
- Rich chat/media: chat/message routes, R2 upload services and mobile chat screens
- Architecture overview: [architecture.md](architecture.md)
- Demo flow: [demo-guide.md](demo-guide.md)
