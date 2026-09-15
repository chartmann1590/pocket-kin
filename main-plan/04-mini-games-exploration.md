# 4. Mini-games and exploration

Status: complete (logic-verified; on-device input feel outstanding)

## Deliverables

Three playable games and three discoverable destinations.

## Implementation tasks

- [x] Implement fruit catch, matching and rhythm with real input/scoring.
- [x] Add tutorials, score rewards and personal bests.
- [x] Add meadow, woods and pond interaction/collection.
- [x] Keep rewards bounded and persisted.

## Acceptance

Each game can be completed and replayed; destinations unlock and discoveries persist.

## Dependencies

None beyond the Godot client (done).

## Evidence

Rewards/bests/unlocks/discovery-dedup covered in world_test PASS 2026-09-07.
`objects.png` placeholder atlas ships cell 0 = peach for the catch game.
Touch/mouse feel must be checked on device (see step 11).

