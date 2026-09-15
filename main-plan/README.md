# Pocket Kin implementation tracker

The complete agreed scope is in [master-plan.md](master-plan.md). This directory was created before implementation.

The complete generated-art checklist is in [asset-inventory.md](asset-inventory.md).

## Status (updated 2026-09-08 — build pass, target: full Play submission)

- [x] Save master plan and individual implementation documents.
- [x] [Project setup](01-project-setup.md) — complete (PCK + simulation/world PASS 2026-09-08; templates 4.7.2.stable installed; SDK 36 present; versions unified 0.2.0/2)
- [x] [Art and assets](02-art-design-and-assets.md) — complete (135 individually indexed generated assets and wired in main.gd/minigame.gd; old decor.png etc. archived, not shipped)
- [x] [Pet care and growth](03-pet-care-and-growth.md) — complete (headless-verified)
- [x] [Mini-games and exploration](04-mini-games-exploration.md) — complete (logic-verified)
- [x] [Customization and rewards](05-customization-and-rewards.md) — complete (logic-verified)
- [ ] [Step tracking](06-step-tracking.md) — in progress (ledger tested; native Health Connect + sensor code present, device matrix outstanding)
- [ ] [Watch companion](07-watch-companion.md) — in progress (protocol + native phone/wear code present, paired Pixel/emulator care verified; remaining device matrix tracked)
- [ ] [Firebase and cloud saves](08-firebase-and-cloud-saves.md) — in progress (client + Functions/Rules code done + unit PASS; Functions emulator PASS; live project outstanding — no accounts yet)
- [ ] [Ads and purchases](09-ads-and-purchases.md) — in progress (client gates done; AdMob/Play products outstanding — no accounts yet)
- [ ] [Reminders and settings](10-reminders-and-settings.md) — in progress (client + CareScheduler code present; device verification outstanding)
- [ ] [Testing and accessibility](11-testing-and-accessibility.md) — in progress (suites green 2026-09-08; hardware/a11y outstanding)
- [ ] [Build and release](12-build-and-release.md) — in progress (PCK + existing APK/Windows ZIP present; release AAB + signing + store pack in progress)

## Execution order

Foundation → visual system and pet lifecycle → games/customization → walking/reminders → Wear OS → Firebase/monetization → validation/release. Work can progress on local adapters while external service configuration is unavailable.

Statuses: pending, in progress, blocked, complete. Completion requires evidence; hardware and production checks are tracked separately.

- [ ] [Widget, fullscreen and visual polish](13-widget-fullscreen-and-polish.md) — implemented; final rendering/gameplay checks in progress.
