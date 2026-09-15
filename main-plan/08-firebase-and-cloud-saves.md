# 8. Firebase and cloud saves

Status: in progress (client + Functions/Rules emulator-verified 2026-09-08; live project outstanding)

## Deliverables

Auth, Firestore rules, Functions, revision conflicts.

## Client implementation (done)

- Versioned snapshots: `World.cloud_snapshot()` carries `revision`; raw step
  counts and tz offset are stripped before upload (health-data privacy).
- `World.apply_cloud_snapshot()`: newer revision applies (local walking kept);
  older/divergent snapshots are stashed to `user://pocket-kin.cloud.json` for
  an explicit player choice - never silently merged. Garbage rejected.
- Conflict UI: Settings shows "Review cloud save conflict" when a stash
  exists; `resolve_cloud_conflict(use_cloud)` applies or dismisses it.
- Regression tests in `game/tests/world_test.gd` cover apply/keep/reject,
  walking preservation, and stash round-trips.

## Implementation tasks

- [x] Versioned snapshot load/CAS save contract on the client.
- [x] Revision conflict preservation with player choice (tested headless).
- [x] Keep raw steps local; entitlements server-owned (client never grants).
- [ ] Firebase project: guest auth + Google linking, Firestore rules, Functions
  (revision-aware saves, purchase verification, reward dedup, deletion).
- [ ] Emulator tests for rules/functions.
- [ ] Live-credential configuration and production verification.

## Backend setup (when accounts exist)

1. Create Firebase project; enable Auth (anonymous + Google), Firestore,
   Functions, Crashlytics, Remote Config with bundled defaults in-client.
2. Firestore rules: per-user isolation (`users/{uid}` owner-only read/write).
3. Functions: CAS save on `revision`, purchase verification before entitlement,
   idempotent reward grants (claim IDs), account deletion cascade.
4. Wire Android bridge (`PocketKin` singleton): `sign_in`, `cloud_save`,
   `cloud_load`, `delete_account` - payload shapes match `platform.gd`.
5. Run emulator suite; record results here before any production claim.

## Acceptance

Rules isolate users; save conflicts preserve both; backend tests pass; live credentials status explicit.

## Dependencies

Firebase project, service credentials, and Play identity/signing are external
dependencies and are not configured (see decisions.md).

## Evidence

Client: `game/scripts/world.gd` snapshot/apply/resolve + world_test cloud
section PASS 2026-09-08. Backend: `domain.test.js` 4/4 PASS; Firestore emulator
rules PASS (`owner read, cross-user denial, server-only writes`); Functions
emulator save/load CAS + privacy stripping PASS 2026-09-08 after lazy-loading
Play publisher (cold-start timeout fix, `timeoutSeconds:60`). Live Firebase
project + `google-services.json` + service-account Play verification outstanding.

## Emulator verification — 2026-09-08

Authenticated Functions save/load, CAS conflict, privacy stripping, cross-account isolation and invalid input rejection PASS using demo-pocket-kin. Conflict responses now carry server revision, and keeping local state advances the expected cloud revision for the next explicit save. Play API loading is deferred until purchase verification to avoid discovery timeouts. Production Firebase configuration is still absent.
