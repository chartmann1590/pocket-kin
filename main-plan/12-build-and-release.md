# 12. Build and release

Status: in progress (PCK + debug APKs + signed release AABs built 2026-09-08; store accounts + device matrix outstanding)

## Deliverables

APKs, bundles, setup docs, release checklist.

## Implementation tasks

- [x] Package phone PCK smoke build (fresh 33.5 MB 2026-09-08, final art).
- [x] Reserve Android package ID + version in project and preset (unified 0.2.0/2).
- [x] Package phone/watch debug builds (templates 4.7.2 + SDK 36 — SUCCESS 2026-09-08).
- [x] Produce signed release bundles (upload keystore local, SHA256 in release/PLAY_SUBMISSION.md).
- [x] Document Firebase/AdMob/Play/signing setup (release/PLAY_SUBMISSION.md + PRIVACY_POLICY + DATA_SAFETY + LISTING + DEVICE_MATRIX).
- [ ] Create Firebase/AdMob/Play accounts + google-services.json + products (none yet — user action).
- [ ] Rotate upload-key passwords + back up keystore offline (placeholder passwords — user action).
- [ ] Run DEVICE_MATRIX on phone + watch hardware, capture store graphics, closed testing, pre-launch report.
- [ ] Update plan and release readiness.

## Release checklist (all open)

- Export templates 4.7.2 + Android SDK + keystore.
- Firebase project, AdMob units + UMP, Play products
  (`kin_cottage`, `kin_moonlight`, `kin_blossom`) and policy declarations.
- Watch build + paired-device test matrix.
- No public publishing authorized (per decisions.md).

## Acceptance

Artifacts exist; no production-ready claim without live/hardware validation.

## Dependencies

External accounts, signing, and hardware (see decisions.md).

## Evidence

`artifacts/pocket-kin.pck` (33.5 MB, 2026-09-08), `pocket-kin-phone-release.aab`
(96.7 MB), `pocket-kin-wear-release.aab` (24.0 MB), debug APKs for sideload.
Gradle + Godot + backend emulator logs 2026-09-08. No public publishing
authorized; production claim requires accounts + device matrix + closed testing.

## Paired test build update — 2026-09-08

Native phone/watch debug APKs and signed release bundles rebuilt after widget, fullscreen and Wear fixes. Google test ad units remain active; Firebase and Play production configuration remain external prerequisites. Production exports now explicitly exclude archived development artwork and test scripts. Root README and tools/start-watch-testing.ps1 document reproducible setup. No public upload performed.
