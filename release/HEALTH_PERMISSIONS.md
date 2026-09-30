# Pocket Kin — Health permission declaration (Play Console → App content)

Apps that use Health Connect (or health permissions) must declare usage in Play Console
and pass review. Pocket Kin uses exactly two health data types:

- **Phone:** `android.permission.health.READ_STEPS` (+ legacy `ACTIVITY_RECOGNITION` for the
  on-device sensor fallback) — optional Walk Together milestones.
- **Wear OS companion:** `android.permission.BODY_SENSORS` — current heart-rate (BPM) from the
  watch's heart-rate sensor, used only for the "Heartbeat Harmony" mood bonus and the live
  dashboard. Requested at runtime the first time the watch dashboard opens; a denied prompt
  simply hides heart-rate rows. Readings stay on the watch/phone pair, are never uploaded to
  any server, never used for ads or analytics, and nothing is written back to Health Connect.

## Declare in App content → Health apps

- **Is your app a health/fitness app?** Yes (reads steps on the phone; reads heart rate on the
  paired Wear OS companion).
- **Which permissions?** `READ_STEPS` (phone) and `BODY_SENSORS` (wear).
- **Purpose:** "Steps are read only if the player opts into the optional Walk Together
  feature. Today's/yesterday's step totals unlock walking milestones (500/1500/3000 steps)
  that grant in-game rewards (petals, friendship, parcels). On the paired Wear OS watch, the
  companion reads the current heart-rate (BPM) for an in-game mood bonus after the player
  grants the body-sensors permission on the watch. No health data is written, nothing is
  uploaded to servers, and health values never leave the device pair except gameplay
  milestone claim IDs, which sync with the player's own cloud save."
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

- [ ] Opt-in flow recorded and linkable (unlisted YouTube) — include a few seconds of the
      watch dashboard showing the heart-rate prompt and the mood bonus.
- [ ] Privacy policy live at the URL above (it names both steps and watch heart rate).
- [ ] `PrivacyActivity` reachable: Settings → Apps → Pocket Kin → Health permission.
- [ ] Revocation verified: denying/clearing permission leaves the game fully playable
      (see DEVICE_MATRIX walk section; watch: deny BODY_SENSORS → no heart-rate row).
- [ ] Data safety form mirrors this declaration (see DATA_SAFETY.md — Health info: steps +
      watch heart rate, collected, not shared, not ads-linked).
