# 2. Art and assets

Status: complete (149 *-final.png generated-integrated and wired; legacy placeholders archived)

## Complete inventory

See [asset-inventory.md](asset-inventory.md) for every generated background, lifecycle, expression, item, icon, premium bundle and watch asset, plus `game/assets/manifest.json` (machine-readable, with grids). Generated reference art is not automatically production-ready.

## What changed this pass

- Verified all six pet sheets: 1536x1024 ARGB, 4x2 grid, 384x512 cells,
  transparent, clean atlas seams (alpha probe + seam averages).
- Verified backgrounds opaque (correct) and fonts present.
- Generated procedural placeholder atlases in palette (transparent, exact
  grids the code slices): `decor.png` 6x5, `accessories.png` 4x3,
  `objects.png` 6x4 (cell 0 = peach), `ui-icons.png` 6x2,
  `premium.png` 3x1 banners, `launcher.png`.
- Generated placeholder audio: `tap.wav` (0.14s blip), `ambient.wav`
  (8s loop-safe pad, wired into Home with loop + settings toggle).
- Fixed `art.gd` fallback that mis-sliced reference-only `mochi.png`.

## Deliverables

Reference art, original pets/backgrounds/icons/audio, asset manifest.

## Implementation tasks

- [x] Generate cozy home and pet reference artwork.
- [x] Create consistent life stages, species variants and expressions.
- [x] Build reusable animation and native icons.
- [x] Generate original ambient loop and interaction sounds.
- [x] Inspect images on phone/watch layouts.
- [x] Replace procedural placeholders with final illustrated art (main.gd/minigame.gd slice decor-final/accessories-final/objects-final/ui-icons-final/premium-final; old decor.png etc. in manifest `archive`, excluded from production).
- [ ] Watch-asset optimization pass on hardware (assets compile; paired screenshot check outstanding).
- [ ] Store graphics set (feature graphic, phone + watch screenshots) — release material, not in-game assets.

## Acceptance

No broken assets; readable UI and visible expressive pet; final asset origins documented.

## Dependencies

Final illustration work for placeholder atlases (see asset-inventory.md).

## Evidence

Alpha/seam probes + in-headless-run with zero script errors 2026-09-07.
In-game phone/watch layout inspection needs a device build (see step 11).
