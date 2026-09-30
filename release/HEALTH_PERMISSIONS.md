# Pocket Kin — Health permission declaration (Play Console → App content)

Apps that use Health Connect (or health permissions) must declare usage in Play Console
and pass review. Pocket Kin uses **only** `android.permission.health.READ_STEPS`
(+ legacy `ACTIVITY_RECOGNITION` for the on-device sensor fallback).

## Declare in App content → Health apps

- **Is your app a health/fitness app?** Yes (reads steps).
- **Which permissions?** `READ_STEPS`.
- **Purpose:** "Steps are read only if the player opts into the optional Walk Together
  feature. Today's/yesterday's step totals unlock walking milestones (500/1500/3000 steps)
  that grant in-game rewards (petals, friendship, parcels). No other health data types are
  read, no health data is written, and steps never leave the device except that milestone
  claim IDs sync with the player's own cloud save."
- **Video requirement:** record a screen capture showing the Walk Together opt-in flow →
  permission dialog → steps appearing on the Walk page → a milestone claim. Upload to
  YouTube (unlisted) and paste the link in the declaration form.
- **Privacy policy URL:** https://chartmann1590.github.io/pocket-kin/privacy
- **Prominent disclosure:** the game shows the opt-in copy on the Walk page before the
  permission dialog ("Pocket Kin counts steps for walking milestones. Steps stay on your
  device."), and a dedicated rationale screen (`PrivacyActivity`) is reachable from system
  settings via the `VIEW_PERMISSION_USAGE` intent filter.
- **Is the data shared with third parties?** No. Steps are never shared, sold, or used for
  advertising/analytics.

## Review readiness checklist

- [ ] Opt-in flow recorded and linkable (unlisted YouTube).
- [ ] Privacy policy live at the URL above.
- [ ] `PrivacyActivity` reachable: Settings → Apps → Pocket Kin → Health permission.
- [ ] Revocation verified: denying/clearing permission leaves the game fully playable
      (see DEVICE_MATRIX walk section).
- [ ] Data safety form mirrors this declaration (see DATA_SAFETY.md — Health info: steps,
      collected, not shared, not ads-linked).
