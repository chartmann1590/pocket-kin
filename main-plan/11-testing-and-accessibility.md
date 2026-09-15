# 11. Testing and accessibility

Status: in progress (automated headless suites green; hardware checks outstanding)

## Deliverables

Automated tests, build checks, visual inspections, hardware matrix.

## Results 2026-09-08 (this machine, Godot 4.7.2 portable, Windows; SDK 36; firebase-tools 15.29.0)

- [x] Backend `npm test`: 4/4 PASS; Firestore emulator rules PASS; Functions emulator save/load CAS + privacy PASS (lazy-publisher cold-start fix).
- [x] Gradle `:phone:assembleDebug` (7m35s) + `:wear:assembleDebug` (3m09s) + `:phone:bundleRelease` + `:wear:bundleRelease` (4m54s) SUCCESS — `phone-release.aab` 96.7 MB, `wear-release.aab` 24.0 MB, signed with local upload key (SHA256 recorded in release/PLAY_SUBMISSION.md).
- [x] Fresh `--export-pack Pack` 33.5 MB (final art) synced to phone assets before Gradle builds.

## Results 2026-09-07 (this machine, Godot 4.7.2 portable, Windows)

- [x] `tests/simulation_test.gd`: PASS (sleep windows, decay, rollback,
  illness/recovery, cooldowns).
- [x] `tests/world_test.gd` (new): PASS - adoption locks, care/cooldown,
  task-once, bounded rewards + bests, explore locks/range/discovery dedup,
  shop no-negative/equip, sanctuary rules, growth stages, walking
  opt-in/thresholds/dedup/yesterday, cloud privacy/apply/conflict/reject,
  save round-trip.
- [x] `--import`: clean, no errors.
- [x] Headless main-scene run (8s): zero script/parse errors.
- [x] `--export-pack Pack`: `artifacts/pocket-kin.pck` 22,124,228 bytes.
- [x] Asset alpha/seam probes: all pet sheets transparent with clean seams;
  placeholders transparent with exact grids.
- [ ] Touch/mouse game feel, layout readability, animation/audio, loading,
  performance/battery on real phone hardware.
- [ ] Backend/security tests (needs Firebase emulator + live project).
- [ ] Android + Wear APK builds (needs templates/SDK/signing + devices).
- [ ] Accessibility pass with screen reader / font scaling on device.

## Implementation tasks

- [x] Run simulation/time/reward/persistence tests.
- [ ] Run backend/security tests.
- [ ] Build both Android apps.
- [ ] Inspect desktop/mobile screenshot layouts.
- [ ] Record real-device, accessibility and battery checks separately.

## Acceptance

Every completed claim has evidence; unresolved checks remain pending.

## Dependencies

Hardware, OS services, and live backends (see decisions.md).

## Evidence

This document + suite outputs above. Nothing hardware-dependent is claimed.

## Paired Pixel/Wear pass — 2026-09-08

- Godot simulation/world regression tests PASS; all nine desktop screen renders complete without script errors.
- Phone and Wear debug builds, native care unit tests and release bundles build successfully.
- Wear OS 5 emulator paired to Pixel 8 Pro; foreground Feed and background Cuddle acknowledged and persisted exactly once. Zero-hit 20-second rhythm completion gives 5 petals. Offline controls disable and reconnect.
- Fullscreen verified on Pixel; app navigation remains above the system navigation region in normal mode and reachable in fullscreen.
- Widget pinning, pet display, Care and Play links verified on Pixel. Phone screenshots exposed a resume-time texture issue; native callbacks now defer scene work to the game loop, with final retest recorded separately.
- Firebase Functions emulator PASS: authenticated save/load, CAS conflict, privacy stripping, cross-account isolation and invalid input rejection. Lazy-loading the Play API client fixes function discovery startup timeouts.
- Physical-watch battery, tile/complication UI, Health Connect permission/source scenarios, reminders, full accessibility and live billing/ad checks remain open.
