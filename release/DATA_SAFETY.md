# Pocket Kin — Data Safety answers (copy into Play Console)

## Collects / shares
- **App activity (game save):** pet/inventory/room/discoveries/memories/settings/revision — collected, stored in Firebase, not shared with third parties. Required for cloud backup; optional (offline play works). [Ephemeral? No.]
- **Personal identifiers (Firebase UID, optional Google account):** collected for auth/cloud save, not shared. Deletion available in-app.
- **Health info (steps):** step counts collected ONLY after opt-in, stored on-device; milestone claim IDs only in cloud. No GPS/HR. Collected, not shared, not used for ads. Include Health permissions declaration + video.
- **Purchases (Play order history / tokens):** collected for verification/restore, via Google Play Billing + Firebase Functions, not shared beyond Google/Firebase processors.
- **Diagnostics (crash logs):** collected via Crashlytics, not shared, not linked to steps.

## Security
Data encrypted in transit (HTTPS/TLS) + at rest (Firestore). Owner-only Firestore reads; all writes via authenticated Functions with CAS revision checks. Receipt-hash dedup; no silent currency merge.

## Families / ads
Target includes children (all ages, Teacher-approved path optional later). Ads: AdMob with Families-compliant + UMP consent; ads only when permitted, never in care/milestone/watch flows. Declare `android.permission.health.READ_STEPS` + ACTIVITY_RECOGNITION with prominent disclosure (in-game Walk Together copy + PrivacyActivity).
