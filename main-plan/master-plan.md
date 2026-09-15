# Pocket Kin — complete Android and Wear OS implementation plan

## 1. Save the entire plan before implementation

The first implementation action is to create `H:\tomogachi-clone\main-plan\` and save this complete plan plus individual implementation documents.

Create README.md, master-plan.md, 01-project-setup.md, 02-art-design-and-assets.md, 03-pet-care-and-growth.md, 04-mini-games-exploration.md, 05-customization-and-rewards.md, 06-step-tracking.md, 07-watch-companion.md, 08-firebase-and-cloud-saves.md, 09-ads-and-purchases.md, 10-reminders-and-settings.md, 11-testing-and-accessibility.md, 12-build-and-release.md, and decisions.md inside main-plan.

- Save this entire plan, including this first step.
- Put an index, implementation order, dependencies, and progress checklist in README.md.
- Expand each numbered document into actionable tasks, interfaces, deliverables, and acceptance checks.
- Record agreed choices, defaults, service dependencies, and subsequent changes in decisions.md.
- Use pending, in progress, blocked, and complete statuses. Record actual validation evidence before marking work complete.
- Keep the master plan and individual documents synchronized throughout implementation.

## 2. Product and technical foundation

Pocket Kin is an original virtual pet game where players hatch a creature and develop a lasting friendship through care, play, exploration, and walking.

Release scope: Android phone game and connected Wear OS companion; cozy illustrated presentation for all ages; six pet species, three phone mini-games, three exploration destinations, decorating, sanctuary, memories, and walking rewards; Firebase cloud saves, AdMob, and cosmetic purchases; all original graphics, animation, interface assets, and audio created during implementation.

Technology: Godot 4 stable and GDScript phone client in portrait; Kotlin Android plugin for Firebase, Health Connect, sensors, notifications, AdMob, Play Billing, and watch communication; Kotlin and Compose for Wear OS; Firebase Authentication, Firestore, Cloud Functions, Crashlytics, and Remote Config. Minimum Android 9 and Wear OS 3. Pin compatible versions during setup.

Separate simulation from rendering and platform integrations. Provide clearly identified development adapters for unavailable services.

## 3. Original visual design and assets

User clarification during implementation: generate every visual asset and background and track every asset, generation prompt, saved output and validation status in asset-inventory.md and game/assets/manifest.json. Watch assets and all lifecycle/expression variants are included.

Use a storybook style: warm cream, peach, and sage; soft lighting; expressive creatures; illustrated rooms; gentle animation.

Create six original creatures with egg, baby, juvenile, and adult appearances; idle, affection, eating, playing, sleeping, dirty, ill, recovery, and growth expressions/animations; home, sanctuary, meadow, woodland, moonlit pond; food, furniture, accessories, discoveries, parcels, icons, branding; mini-game art, celebrations, watch assets, sound effects, and ambient music.

Establish reference sheets, palette, typography, lighting, and dimensions first. Use image generation for illustrated rasters and editable native assets for icons/interface. Animate with reusable rigs and selected frames. Inspect consistency, transparency, clipping, readability, phone/watch suitability. Store final assets, editable sources where available, and generation records. Final screens must use finished artwork.

## 4. Pet care, growth, and companionship

Offer three starter eggs and unlock three species through play. Hatch during onboarding; name the pet. Target juvenile after two days and adult after seven days of adequate care. Poor care slows growth; pets never die or disappear. Adults remain playable indefinitely. Voluntary sanctuary transfer frees the active slot; sanctuary pets retain identity, appearance, memories without ongoing needs.

Track hunger, happiness, cleanliness, energy; balance visits every 3–4 waking hours. Feed, affection, clean, play, sleep. Protected sleep defaults 22:00–07:00, adjustable. Neglect causes treatable illness and slower growth. Basic food and treatment always free. Develop favorites, preferences, personality, tricks, friendship milestones. Album records adoption, growth, discoveries, meaningful interactions.

Use deterministic calculations and injectable clock. Reconcile elapsed time on reopening instead of continuous background simulation. Handle rollback/large jumps without duplicates/corruption.

## 5. Mini-games, exploration, customization

Build fruit catching, matching pairs, rhythm tapping, each with tutorial, difficulty, bests, bounded rewards, scoring separate from presentation. Meadow, woodland, moonlit pond offer short interactive outings and collectibles. Friendship unlocks destinations. Discoveries permanent.

Launch with 30 earned decorations and 12 earned accessories, predefined room slots, three permanent paid bundles. Three rotating daily tasks, pet requests, lasting collection goals. Missing days never erases progress. Core care/recovery/progression needs no ads/purchases.

## 6. Real-world steps

Walk Together shows today's steps, source/status, refresh, next reward, trail. Walking adds happiness, friendship, parcels; regular play supplies equivalent care/rewards. Milestones 500/1500/3000 steps per day, game thresholds not fitness recommendations, no further care obligation. Count from activation. Reconcile today/yesterday for late synchronization; never revoke rewards on corrected counts.

Prefer Health Connect aggregate steps including compatible watch apps, avoid double counting. Refresh opening/resuming walking and manually. Without source offer explicit phone sensor session with persistent background notification. One source per interval, no overlapping sum. Handle denial/revocation/missing hardware/reboot/interruption/timezone/delays; clearly show stale or unavailable tracking.

Only step access on enable, no GPS/routes/heart rate/health write. Step records local; cloud only resulting progress/claim IDs. Exclude steps and walking-derived attributes from ads/analytics. Include health declarations/disclosures.

## 7. Wear OS

Native short-interaction round/rectangular UI: animated pet, mood, four needs, connection; basic feeding, affection, cleaning, bedtime; 20-second rhythm game with phone-authoritative rewards; phone-synced walking/milestones/rewards/last sync; tile with pet, urgent need, progress, care shortcut; configurable mood/walk complication. Reuse optimized art, static ambient, event updates.

Connected companion: adoption/accounts/purchases/full decorating on phone; care/reward play require reachable phone service; disconnected cached status/time, disable mutations, no queued offline care. Compatible watch health apps supply Health Connect data. Data Layer uses matching identity/signing, versioned snapshots, acknowledged commands with unique request ID, pet ID, expected revision. Phone validates/apply-once/responds. Handle duplicates/timeouts/stale/pet replacement/reconnection. Communicate with phone screen closed subject to OS restrictions. Firebase and authority on phone; ads/purchases phone only; avoid duplicate reminders.

## 8. Firebase, persistence, interfaces

Versioned atomic local saves/backups after meaningful changes; offline phone play; elapsed reconciliation; migration preserving pet/purchases. Save active pet, sanctuary, inventory, room, discoveries, memories, settings, simulation timestamps, claims.

Firebase guest auth and optional Google linking with parent-managed child setup; Firestore saves; Functions revision-aware saves, purchase verification, reward deduplication, deletion; Crashlytics technical errors without health data; Remote Config balance/kill switches with bundled defaults. Server-owned entitlements, per-account access. Upload expected revision; preserve divergent snapshots for player choice, no silent currency merge.

Interfaces: auth/deletion; load/upload/conflict; verification/restoration; steps availability/permissions/totals/sessions; ads availability/show/rewards; notifications; watch snapshot/commands/acks.

## 9. Ads and purchases

Optional rewarded decorating coins or exploration bonuses, grant once after confirmation, failures never block. Interstitial eligible every third phone mini-game with ten-minute minimum, rewarded resets cooldown. Exclude onboarding/care/hatching/treatment/milestones/walking/watch. Test units in development.

Permanent bundles through localized Play prices/restoration. Server verify/acknowledge. Handle pending, duplicate, interrupted, restored, refunded; no entitlement before verification. Neutral age screen, parent gates, child ad settings, UMP; ads only when permitted.

## 10. Reminders/settings/accessibility

Permission after first care. Quiet hours and at most three daily reminders; obsolete cancel, reboot restore; inexact scheduling. Mirror phone alerts, no duplicate watch stream. Controls for music/effects/haptics/motion/notifications/sleep/privacy/account/walking. Readable text, large targets, labels, non-color-only status. Text separate from art.

## 11. Testing/acceptance

Verify lifecycle, sanctuary, adoption, care/sleep/illness/free recovery/absence; clock changes/repeated resume/save interruption/corruption/migrations; scoring/rewards/discoveries/inventory; offline/guest linking/cloud recovery/concurrent saves/deletion.

Steps: phone/watch sources, overlap/delay/activation/midnight/timezone/reboot/source switch/revocation/unsupported. No duplicated refresh/cross-device rewards, full game without tracking.

Watch: pairing/background phone/disconnect/reconnect/stale/repeated taps/lost ack/pet switch/rewards/tile/complication/notification duplicates.

Services: notification denial, ad absence/caps/duplicate callbacks, pending/refund/restore. Inspect all screens/assets, controls/text/animation/audio/loading/performance/battery. Physical tests where available; record outstanding hardware checks.

## 12. Sequence and deliverables

1. Save master and individual documents in main-plan.
2. Set up repository, engine, Android, interfaces, tests.
3. Visual system and finished pet lifecycle/local saves.
4. Species, games, exploration, decorating, sanctuary, memories.
5. Walking/reminders.
6. Watch and sync.
7. Firebase, AdMob, purchases.
8. Art/audio/accessibility/performance/failure tests.
9. Phone/watch APKs and Play bundles, installation, configuration, release checklist.
10. Update all plan statuses/evidence.

Defaults: working name Pocket Kin, English, portrait phone, single player, no chat/trading/non-Wear OS. Deployment dependencies: Firebase, AdMob, Play products/declarations, app identity, signing, devices. Use test integrations until live configured. Public publishing separate after review-ready build/listing. No user artwork required.

## References

- https://developer.android.com/health-and-fitness/health-connect/read-data
- https://support.google.com/googleplay/android-developer/answer/12991134
- https://developer.android.com/training/wearables/user-interfaces
- https://developer.android.com/training/wearables/data/overview
- https://developer.android.com/google/play/billing/security
- https://support.google.com/googleplay/android-developer/answer/9893335
- https://developers.google.com/admob/android/privacy

## Added implementation step: widget and visual polish

The plan remains the first saved deliverable. Step [13](13-widget-fullscreen-and-polish.md) individually tracks the user's home-screen widget, fullscreen, sound and unobscured-navigation requirements. The dedicated watch emulator is now paired to the Pixel 8 Pro; results and reconnect instructions are in step 7.
