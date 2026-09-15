# Pocket Kin — Privacy Policy (DRAFT — host this URL before submission)

Last updated: 2026-09-08. Contact: [ADD SUPPORT EMAIL].

## What Pocket Kin is
Single-player cozy virtual pet game for all ages. One active pet, no chat/trading, English, portrait phone + Wear OS companion.

## Data we collect
- **Game save (optional cloud backup):** pet state, inventory, room, discoveries, memories, settings, revision, entitlements. Raw step counts and timezone offset are stripped before upload (`World.cloud_snapshot`, `validateSave`). Stored in Firebase Firestore per-account (`users/{uid}`), writes via Cloud Functions only.
- **Account:** Firebase Anonymous ID; optional Google link (parent-managed for children). Deletion via in-game Delete Account → removes Firestore save + receipts + Auth user.
- **Purchases:** Play purchase tokens verified server-side; receipt hashes stored for dedup/restore/refund handling. No card data touched by us.
- **Steps (optional, opt-in only):** today's/yesterday's step totals via Health Connect (preferred) or on-device sensor session. Used only for walking milestones (500/1500/3000 → petals/friendship/parcels). Raw steps stay on device; only milestone claim IDs sync. No GPS, routes, heart rate, or health writes. Deny/revoke anytime; game fully playable without steps.
- **Diagnostics:** Crashlytics technical crash logs (analytics collection disabled in manifest). No health data in crashes/ads/analytics.

## Data we never collect/share
No contacts, location, photos, microphone, precise health beyond step counts, and step-derived attributes never enter ads/analytics.

## Ads & purchases
- Optional rewarded ads (decorating coins / exploration bonus, single-grant after confirmation) + interstitial every 3rd phone mini-game (10-min minimum). Never during onboarding/care/hatching/treatment/milestones/walking/watch. Test units in dev; production AdMob + UMP consent in release.
- Permanent cosmetic bundles only (`kin_cottage`, `kin_moonlight`, `kin_blossom`). Server-verified; no local grants. Core care/recovery/progression never needs ads/purchases.

## Children & families
Neutral age screen + parent gate (7×8) before sign-in/purchases/restore/deletion. Behaviors-compliant ads settings for child users via UMP.

## Permissions used
INTERNET, ACCESS_NETWORK_STATE, VIBRATE, POST_NOTIFICATIONS (reminders, after first care), ACTIVITY_RECOGNITION + `health.READ_STEPS` (walking, opt-in), FOREGROUND_SERVICE_HEALTH (sensor fallback with persistent notification), RECEIVE_BOOT_COMPLETED (restore reminders). Health permission rationale screen included (`PrivacyActivity` / `VIEW_PERMISSION_USAGE`).

## Retention / rights
Local saves versioned + backed up; cloud saves revisioned with explicit conflict choice (never silent merge). Request export/deletion via [SUPPORT EMAIL] or in-game Delete Account.

Host this file publicly and paste the URL into Play Console (app content → Privacy policy) + in-game Settings → Privacy.
