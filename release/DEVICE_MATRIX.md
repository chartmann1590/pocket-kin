# Pocket Kin — Device test matrix (run on YOUR phone + watch, record dates/results)

Builds: `artifacts/pocket-kin-phone-debug.apk` + `pocket-kin-wear-debug.apk` (debug keys). Enable Stay-awake, disable battery optimization for test.

## Phone (Android 9+; record model/OS/Health Connect version)
- [ ] Install, onboarding: 3 starter eggs → hatch → name → home renders, pet expressive, no script errors (`adb logcat | grep godot`).
- [ ] Care loop: feed/affection/clean/sleep, cooldowns, protected sleep 22-07 + custom window, illness → free recovery.
- [ ] Growth fast-forward (device clock ±2d/7d, rollback, large jump): stages correct, no dup claims/corruption.
- [ ] Games: catch/match/rhythm completable, tutorial, bests persist, rewards bounded; interstitial only every 3rd game + 10-min gap.
- [ ] Explore: meadow/woodland/pond unlock by friendship, discoveries dedup + persist.
- [ ] Shop: 30 decor / 12 accessories buy/equip, no negative coins, task rewards once, sanctuary transfer + re-adopt.
- [ ] Walk Together: opt-in disclosure → Health Connect grant → today's steps → 500/1500/3000 each pay once → kill/reopen (no double-pay) → yesterday late-sync claims → revoke permission (clear stale UI, game playable) → sensor fallback session with persistent notification → reboot (session + reminders restored) → timezone change.
- [ ] Reminders: allow after first care only; ≤3/day; quiet hours 21-08 respected; obsolete cancelled; reboot restore; denial doesn't block.
- [ ] Cloud (after Firebase live): guest → backup → reinstall → restore; link Google → conflict (two devices) → explicit choice, no silent merge; delete account cascades.
- [ ] Billing (after products live): each bundle pending/buy/restore/refund — entitlement only after server verify; airplane-mode purchase recovers.
- [ ] Ads (after AdMob live): rewarded single-grant + dedup; failures never block; UMP consent (EEA VPN) + child settings.
- [ ] A11y/perf: TalkBack labels, font-scale 1.3x, 66px targets, reduced-motion disables bobbing, 8s headless zero-error, battery (Settings → Battery) sane, loading <3s on Wi-Fi.

## Watch (Wear OS 3+; record model/OS, round + rectangular if possible)
- [ ] Install `wear-debug.apk`, pair, open phone app first: watch shows pet/mood/needs/connection + last-sync.
- [ ] Feed/affection/clean/bedtime each apply once (tap twice fast → single ack, revision increments once).
- [ ] Airplane-mode watch: cached status visible, mutations disabled, no queued care; reconnect syncs.
- [ ] 20-sec rhythm: completes, reward phone-authoritative only.
- [ ] Tile: pet + urgent need + progress renders, tap opens care. Complication: mood/walk renders on watchface.
- [ ] Phone screen closed: Data Layer still delivers (subject to Doze); lost-ack retry safe.
- [ ] No duplicate phone+watch notifications.

## Evidence to paste back
`adb devices`, APK install logs, screenshots (home/room/walk/watch/tile), `visual.log`, emulator PASS lines, Play pre-launch report. Update `main-plan/11-testing-and-accessibility.md` + `12-build-and-release.md` with dates.
