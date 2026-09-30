# Pocket Kin — Data Safety answers (copy into Play Console)

Privacy policy URL to enter first: https://chartmann1590.github.io/pocket-kin/privacy

## Collects / shares
- **App activity (game save):** pet/inventory/room/discoveries/memories/settings/revision — collected, stored in Firebase, not shared with third parties. Required for cloud backup; optional (offline play works). [Ephemeral? No.]
- **Personal identifiers (Firebase UID, optional Google account):** collected for auth/cloud save, not shared. Deletion available in-app.
- **Health info (steps + watch heart rate):** step counts collected ONLY after opt-in and stored on-device (milestone claim IDs only in cloud). The Wear OS companion additionally reads current heart-rate (BPM, `BODY_SENSORS`) for an in-game mood bonus; readings stay on the watch/phone pair and are never uploaded. No GPS. Collected, not shared, not used for ads. Include Health permissions declaration + video covering both.
- **Purchases (Play order history / tokens):** collected for verification/restore, via Google Play Billing + Firebase Functions, not shared beyond Google/Firebase processors.
- **Diagnostics (crash logs):** collected via Crashlytics, not shared, not linked to steps.

## Security
Data encrypted in transit (HTTPS/TLS) + at rest (Firestore). Owner-only Firestore reads; all writes via authenticated Functions with CAS revision checks. Receipt-hash dedup; no silent currency merge.

## Families / ads
Target includes children (all ages, Teacher-approved path optional later). Ads: AdMob with Families-compliant + UMP consent; ads only when permitted, never in care/milestone/watch flows. Declare `android.permission.health.READ_STEPS` + ACTIVITY_RECOGNITION + watch `BODY_SENSORS` with prominent disclosure (in-game Walk Together copy + PrivacyActivity).

## Wear OS app
- The wear bundle shares this Data Safety form (same package). It reads watch step sensors and
  heart rate (BODY_SENSORS), shows them on the watch, and forwards them to the paired phone via
  the Wearable Data Layer / local network. It does not upload health data anywhere.

## Ads declaration (App content → Advertising ID)
- Does the app use advertising ID? **Yes** (AdMob).
- Purposes: advertising, analytics? **Advertising only**; note that users' ad settings/consent
  (UMP) apply and child users are tagged child-directed.
- Ads declaration: **Yes, contains ads** (banner-less; rewarded + interstitial only).
