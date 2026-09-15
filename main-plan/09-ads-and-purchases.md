# 9. Ads and purchases

Status: in progress (client gates done; SDK/products blocked on accounts)

## Client implementation (done)

- Interstitial cadence: eligible every third phone mini-game with a 10-minute
  minimum (`main.gd` start_game + `World.ad` counters). Onboarding, care,
  hatching, treatment, milestones, walking, and watch flows never trigger ads.
- Rewarded ads: single-grant after confirmation, callback deduplication by
  claim ID (`platform.gd` rewarded handler), failures never block play.
- Purchases: client NEVER grants entitlements from a store callback.
  Verified purchases trigger `cloud_load`; unlocks arrive via the verified
  cloud snapshot only (`platform.gd` purchase/restore handlers).
- Parent gate (7x8) in front of sign-in, purchases, restore, and deletion;
  privacy/ad-choices entry point in Settings.

## Implementation tasks

- [x] Every-third-game + 10-minute interstitial limits (client).
- [x] Rewarded callback deduplication (client).
- [x] Verified-only entitlement path, no local grants (client).
- [x] Age/parent gates and privacy entry (client).
- [ ] AdMob + UMP SDK wiring with test units, then production units.
- [ ] Play Billing catalog (`kin_cottage`, `kin_moonlight`, `kin_blossom`),
      pending/purchase/restore/refund handling with server verification.
- [ ] Document Play products and production configuration.

## Acceptance

No ad interrupts care; no unverified grants; real SDK build passes; live checks recorded.

## Dependencies

AdMob account, UMP configuration, Play products/declarations, and app signing
are external dependencies and are not configured (see decisions.md).

## Evidence

Client gates in `game/scripts/main.gd` + `game/scripts/platform.gd`.
SDK/production checks outstanding, not claimed.

