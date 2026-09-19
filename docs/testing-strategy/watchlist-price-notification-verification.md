# Watchlist Price Notification Verification

## Scope

Watchlist price-drop notifications use the existing authenticated device-token
registration, the `watchlistPriceDrop` business preference, and Firebase Cloud
Messaging. The Auckland daily quota applies only to `watchlist_price_drop`; it
does not apply to Chat notifications.

## Safe iOS configuration

The repository contains the push entitlement and the remote-notification
background mode. Secrets and developer-specific signing data must remain
outside source control.

1. Enable **Push Notifications** for the KiwiShare App ID in the Apple Developer
   portal. The App ID and Xcode target must use the same bundle identifier.
2. Create or select an APNs authentication key with push access. Upload the key
   to the matching Firebase project. Never commit the `.p8` file, key ID,
   private key, certificate, provisioning profile, or service-account JSON.
3. In Xcode, select an authorised development team and a provisioning profile
   that includes the push entitlement. Do not commit a personal Apple Team ID.
4. Development/debug signing must use the APNs development environment;
   distribution/profile builds must use the production environment.
5. Configure Firebase Admin credentials on the test backend through the
   deployment secret store, never through a committed `.env` file.

## Physical-iPhone verification

An Apple Developer account, Firebase project access, valid signing and
provisioning, a physical iPhone, and two test accounts are required.

1. Sign in on the iPhone, enable notifications contextually, and verify that the
   device token is registered for the active account.
2. Add another member's active item to the Watchlist and leave **Price alerts**
   enabled.
3. Lower the price from the seller account and verify foreground, background,
   and terminated-state delivery.
4. Tap each notification and verify that KiwiShare opens the current item
   detail without implying that it is still available.
5. Disable **Price alerts**, lower the price again, and verify that neither email
   nor push is sent for that account. Confirm Chat notification behaviour is
   unchanged.
6. Re-enable the preference and verify the Auckland daily limit admits at most
   20 price-drop events for the account without affecting Chat.
7. Log out, verify that the installation token is removed for the old session,
   and confirm that later price changes do not notify that logged-out account.

Automated tests and simulator builds verify application logic and native build
configuration, but they do not prove real APNs delivery. Attach physical-device
screenshots or a recording before marking real iOS delivery complete.

## Durable outbox evaluation (#206)

Price persistence currently succeeds independently of best-effort notification
delivery. A process crash after the price update commits but before the unique
notification event is reserved can therefore lose a notification. This does
not corrupt the Item or Watchlist and does not block the current pilot flow, so
a durable outbox is deliberately deferred.

Re-evaluate an outbox when at-least-once delivery becomes a product requirement,
observable production notification loss occurs, automatic retry of transient
provider failures is required, or cross-process recovery becomes necessary.
Any future design should reuse the existing stable event ID and notification
history rather than introduce a competing notification record.
