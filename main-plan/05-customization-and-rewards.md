# 5. Customization and rewards

Status: complete (logic-verified; final art pending)

## Deliverables

30 decor items, 12 accessories, tasks and coins.

## Implementation tasks

- [x] Define data-driven catalog and slots.
- [x] Implement earning, purchase/equip and room display.
- [x] Create daily tasks and non-resetting progress.
- [x] Define three premium bundle identifiers.

## Notes

Shop renders against placeholder `decor.png`/`accessories.png` atlases
(verified grids); final illustrated art still pending per asset-inventory.
Premium IDs: `kin_cottage`, `kin_moonlight`, `kin_blossom` (server-verified,
never granted client-side).

## Acceptance

No negative coins; owned items persist; task rewards only once.

## Dependencies

Final decor/accessory art (see step 2); Play products for premium (see step 9).

## Evidence

world_test shop/task sections PASS 2026-09-07.

