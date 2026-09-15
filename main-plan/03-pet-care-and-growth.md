# 3. Pet care and growth

Status: complete (headless-verified; device play-through outstanding)

## Deliverables

Deterministic simulation, onboarding, sanctuary, favorites, album.

## Implementation tasks

- [x] Implement egg choice, naming, hatch and persistent active pet.
- [x] Implement needs, protected sleep, illness and free recovery.
- [x] Add growth, bond, personality and memories.
- [x] Add voluntary sanctuary and subsequent adoption.
- [x] Test elapsed time and save recovery.

## Notes

- Fixed during this pass: `explore()` crashed on out-of-range destinations;
  now returns the locked message. `art.gd` fallback mis-sliced reference-only
  `mochi.png` as 3x1; now falls back to the verified Mochi atlas.
- Saves self-heal: older files gain new settings keys; tz offset refreshes on
  every launch (travel/DST safe). Godot unix<->date helpers speak UTC, so the
  stored bias converts to local days (documented in `world.gd`).

## Acceptance

Seven-day simulated growth, neglect recovery, sleep protection and restart persistence pass.

## Dependencies

None beyond the Godot client (done).

## Evidence

`game/tests/simulation_test.gd` + `game/tests/world_test.gd` (growth stages,
rollback, illness/recovery, sanctuary, save round-trip) PASS 2026-09-07.
On-device play-through still outstanding (see step 11).

