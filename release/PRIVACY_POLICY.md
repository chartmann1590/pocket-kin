# Pocket Kin — Privacy Policy (LIVE)

Canonical public URL: **https://chartmann1590.github.io/pocket-kin/privacy**
(source: `docs/privacy.html`, deployed to GitHub Pages by `.github/workflows/deploy-pages.yml`).

Last updated: 2026-09-29. Contact: support@charleshartmann.com.

## What Pocket Kin is
Single-player cozy virtual pet game for all ages. One active pet, no chat/trading, English, portrait phone + Wear OS companion.

## Data we collect
- **Game save (optional cloud backup):** pet state, inventory, room, discoveries, memories, settings, revision, entitlements. Raw step counts and timezone offset are stripped before upload (`World.cloud_snapshot`, `validateSave`). Stored in Firebase Firestore per-account (`users/{uid}`), writes via Cloud Functions only.
- **Account:** Firebase Anonymous ID; optional Google link (parent-managed for children). Deletion via in-game Delete Account → removes Firestore save + receipts + Auth user.
- **Purchases:** Play purchase tokens verified server-side; receipt hashes stored for dedup/restore/refund handling. No card data touched by us.
- **Steps (optional, opt-in only):** today's/yesterday's step totals via Health Connect (preferred) or on-device sensor session. Used only for walking milestones (500/1500/3000 → petals/friendship/parcels). Raw steps stay on device; only milestone claim IDs sync. No GPS or routes. Deny/revoke anytime; game fully playable without steps.
- **Watch heart rate (optional, opt-in only):** on a paired Wear OS watch, the companion can read the current heart-rate (BPM) from the watch's sensor after you grant the body-sensors permission on the watch. It powers the "Heartbeat Harmony" mood bonus and the live watch/phone dashboard. Readings stay on the watch and phone, are never uploaded to any server, and are never used for advertising or analytics. No health data is ever written back. Skip or revoke the permission and the game stays fully playable.
- **Diagnostics:** Crashlytics technical crash logs (analytics collection disabled in manifest). No health data in crashes/ads/analytics.

## Data we never collect/share
No contacts, location, photos, microphone, and no health data beyond step counts and watch heart-rate readings described above. Health values never enter ads/analytics and are never sold or shared.

## Ads & purchases
- Optional rewarded ads (decorating coins / exploration bonus, single-grant after confirmation) + interstitial every 3rd phone mini-game (10-min minimum). Never during onboarding/care/hatching/treatment/milestones/walking/watch. Test units in dev; production AdMob + UMP consent in release.
- Permanent cosmetic bundles only (`kin_cottage`, `kin_moonlight`, `kin_blossom`). Server-verified; no local grants. Core care/recovery/progression never needs ads/purchases.

## Children & families
Neutral age screen + parent gate (7×8) before sign-in/purchases/restore/deletion. Behaviors-compliant ads settings for child users via UMP.

## Permissions used
INTERNET, ACCESS_NETWORK_STATE, VIBRATE, POST_NOTIFICATIONS (reminders, after first care), ACTIVITY_RECOGNITION + `health.READ_STEPS` (walking, opt-in), BODY_SENSORS (watch heart rate, opt-in on the watch), FOREGROUND_SERVICE_HEALTH (sensor fallback with persistent notification), RECEIVE_BOOT_COMPLETED (restore reminders). Health permission rationale screen included (`PrivacyActivity` / `VIEW_PERMISSION_USAGE`).

## Retention / rights
Local saves versioned + backed up; cloud saves revisioned with explicit conflict choice (never silent merge). Request export/deletion via support@charleshartmann.com or in-game Settings → Delete cloud account.

The GitHub Pages copy (docs/privacy.html) is the authoritative version — update it whenever
this file changes, then redeploy Pages before publishing a new release.
