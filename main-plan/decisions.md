# Decisions and dependencies

- Approved scope: the complete master plan; no user-supplied graphics.
- Original working brand: Pocket Kin. Portrait, English, all ages, one active pet.
- Frequent care with protected sleep, recoverable illness, no mortality.
- Six species, three games/destinations, sanctuary, 30 decorations, 12 accessories.
- Walking is optional bonus care; Health Connect first and explicit sensor fallback.
- Wear OS is connected-only for actions, with cached read-only status offline.
- Firebase cloud recovery, AdMob rewarded/interstitials, permanent cosmetic purchases.
- Live service credentials, Play identity/signing, policy declarations and physical devices are external dependencies; do not fabricate them.
- No public publishing is authorized by the build request.
- Implementation must record departures and test evidence here and in individual plans.

## Session 2026-09-07 departures and notes

- Engine pinned to portable Godot 4.7.2 (`tools/godot/`); project features 4.5 -> 4.7.
- Legacy `decor.png`, `accessories.png`, `objects.png`, `ui-icons.png`,
  `premium.png`, `launcher.png` are archived development placeholders
  (manifest `archive`, excluded from production exports). Production screens
  slice only `*-final.png` (149 generated-integrated entries). Audio is
  original procedural compositions via `tools/generate_audio.py` (no external
  samples) — acceptable as original; studio re-compose optional, not blocking.
- Bugs fixed: `explore()` out-of-range crash; `art.gd` mis-sliced fallback;
  cloud apply rejected genuine snapshots (local-only fields now normalized).
- Client never grants purchases locally; verified-only via cloud snapshot.
- 2026-09-08 build pass: export templates 4.7.2.stable + Android SDK 36 verified
  present; sim/world + backend unit PASS; versions unified 0.2.0/2. Still blocked
  (external): upload keystore + Play signing, Firebase/AdMob/Play accounts
  (none yet), paired-device/hardware checks (hardware available, not yet run),
  emulator suites (firebase-tools via npx, not yet run).
(End of file - session notes above.)
