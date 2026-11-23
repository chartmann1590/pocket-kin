# Pocket Kin — Play compliance review & fixes (2026-11-23)

Scope: re-review for Google Play submission from Internal testing. App: Pocket Kin,
package `com.pocketkin.game`. Version for submission: **0.2.1 — phone versionCode 10007,
wear versionCode 20007** (was 0.2.0 / 10006 / 20006). Nothing was submitted to Play
Console in this pass; this document is the record of what was found and fixed in the repo.

## 1. Health claims / sensors — FIXED (framing + a real data-integrity bug)

Evidence in the old code/text:
- `README.md` advertised "health tracking" (also the GitHub repo description — see
  "Owner action" below), "health monitoring", "Pet Heartbeat Harmony: Monitors heart
  rate (BPM)", "Wear Health & Harmony".
- Manifests: phone declares `android.permission.health.READ_STEPS` +
  `ACTIVITY_RECOGNITION` (`android/phone/src/main/AndroidManifest.xml`); wear declares
  `BODY_SENSORS` + `ACTIVITY_RECOGNITION` (`android/wear/src/main/AndroidManifest.xml`).
  Phone reads steps via Health Connect (`StepsBridge.kt`); watch reads
  `Sensor.TYPE_HEART_RATE` / step sensors (`WatchHealthManager.kt`). No Health Connect
  heart-rate access. The data is real and functional, so no code was removed.
- **Data-integrity bug:** the watch *fabricated* heart rate — default display 74 BPM and a
  "Pulse" button (`measureHeartRatePulse()`) generating a random 65–88 BPM, synced to the
  phone as if it were a sensor reading. Presenting invented values as health data is a
  deceptive-behavior / health-apps risk. **Removed:** only `TYPE_HEART_RATE` sensor events
  can set a value; before the first reading the watch shows "— BPM / Waiting for a real
  heart-rate reading…"; the Pulse button now only re-registers the sensor listeners.
- Derived "active min / kcal" on the watch are now labelled a game estimate from steps.
- "Daily Hydration" on the watch is the *pet's* drink in the game; relabelled
  "Pet's Daily Sips / sips for your pet" in UI, README, listing and privacy text.
- README, `release/LISTING.md`, `docs/index.html` and the privacy policy now frame steps
  and heart rate strictly as game inputs and state the app is not a health, fitness or
  medical app and gives no health advice. Health Apps declaration answers:
  `release/HEALTH_PERMISSIONS.md` (access = Yes for steps + heart rate; health/fitness/
  medical app = No; purpose = game features only; shared = No; demo video still required).

## 2. Wear OS Tile mention — VERIFIED & STRENGTHENED

The Tile exists (`android/wear/.../KinTileService.kt`, `BIND_TILE_PROVIDER` in the wear
manifest) and `release/LISTING.md` already mentioned "tile + complication" in one clause —
the exact kind of buried mention that got another of our apps rejected. The listing now
carries a dedicated bullet, reproduced verbatim in the Console inputs:

> Wear OS Tile: Pocket Kin includes a Wear OS Tile. Swipe on your watch face to the
> Pocket Kin Tile to see your pet's mood, hunger and happiness and today's in-game
> walking progress at a glance; tap the Tile to open the watch app and use quick care
> (Feed, Cuddle, Wash, Bed). A watch-face complication can also show your pet's mood or
> steps. (Tile and complication need a connected phone.)

The website (`docs/index.html`) now describes the Tile the same way.

## 3. Firebase, accounts, Data Safety — VERIFIED & DOCUMENTED

- Firebase is real: `firebase-auth`, `firebase-firestore`, `firebase-functions`,
  `firebase-config`, `firebase-crashlytics` (`android/phone/build.gradle.kts`);
  `CloudBridge.kt` signs in anonymously, optionally links Google, saves/loads via the
  `saveGame`/`loadGame` Functions, verifies purchases, and **deletes the account**
  (`deleteAccount` Function + sign-out). Analytics collection is disabled in the manifest;
  Crashlytics collection is disabled by default in the manifest.
- Because the app creates accounts, Play requires an in-app deletion path **and** a web
  deletion URL. In-app existed; the web page did not. Added `docs/delete-account.html` →
  **https://chartmann1590.github.io/pocket-kin/delete-account.html** (live after the Pages
  deploy on merge to main). Exact Data Safety answers: `release/DATA_SAFETY.md`.

## 4. Local HTTP fallback server (PhoneSyncServer, port 8765, /kin/*) — FIXED

Old behaviour (`android/phone/.../PhoneSyncServer.kt`): `ServerSocket(8765)` binds all
interfaces, **no authentication**, `Access-Control-Allow-Origin: *`. Any device on the
same Wi-Fi could `GET /kin/state` (pet snapshot), `POST /kin/action` (care actions that
rewrite the save file) or `POST /kin/sync_health` (inject step/heart-rate values).
LAN sync *is* required (the watch is a separate device; candidates include the phone's
LAN IP — `SyncManager.kt`), so binding to localhost would break the feature. Fix:
**pairing-token authentication** —
- Phone generates a 192-bit token once, stored in the never-backed-up `kin_private`
  prefs (`PhoneSyncServer.pairingToken`).
- The phone shares it with the watch only inside the `/kin/ping` reply on the paired
  Wearable (Bluetooth) message channel (`PhoneWatchService`) — never in any HTTP response.
- The watch stores it and sends `X-Kin-Pairing-Token` on every HTTP fallback request
  (`SyncManager.addAuth`); the server compares in constant time and returns **401**
  otherwise. CORS wildcard removed.
- Residual risk, disclosed in `docs/privacy.html` and `release/DATA_SAFETY.md`: the LAN
  channel is still cleartext HTTP (token + game data visible to a passive sniffer on the
  user's own Wi-Fi). No health data is uploaded anywhere; HR/steps stay on the device pair.

## 5. PR #2 billing P1 — PR already merged; its fix had a residual hole — FIXED

PR #2 is **closed/merged** (2026-10-01), not open. Its P1 ("persist the grant before
consuming") was answered in commit 20c278e and the thread is resolved — but the merged
code still cleared `pending_grant_<token>` in the `consumeAsync` success callback
(`BillingBridge.kt`), i.e. before Godot confirmed it had saved the grant, so the exact
app-killed-at-the-wrong-moment loss the P1 described could still happen. Fixed: the
record is now cleared **only** by `confirmGrant()` after the game durably saves
(`world.gd` records `purchase:<token>` in `data.claims` before confirming, so a replay
from `restore()` is idempotent). The P2 findings in PR #2 (Cozy Pass bonus idempotency,
toy re-equip rewards) were verified present in current `world.gd`.

## 6. Extra finding — randomized mystery crates (loot-box disclosure) — FIXED

`world.gd open_mystery_box`: two randomized crates are sold for Petals — a currency that
is earnable **and sold for real money** — with no odds disclosed anywhere, the Royal
Trunk was described as "Guaranteed 200-350 Petals" although the code pays an item 50%
of the time, and `release/CONTENT_RATING.md` / `release/FAMILIES.md` wrongly certified
"no loot boxes / no consumables". Fixes: exact odds are now shown in the shop on the
crate card before opening (`game/scripts/main.gd`), the Royal description is corrected,
and the rating/families documents now disclose the randomized items (expect the IARC
element "In-Game Purchases (Includes Random Items)"). **The Godot PCK must be
re-exported before upload** or the in-game text will not ship (see PLAY_SUBMISSION.md).

## Owner action (cannot be done from the repo)

- GitHub repo description still says "health tracking": change it to
  "Pocket Kin — a cozy storybook virtual-pet game for Android with a Wear OS companion,
  walking-powered game rewards, and a home-screen widget" (repo Settings; no API tool
  in this pass could edit it).
- Record the Health Apps declaration demo video (steps opt-in flow + watch heart-rate
  prompt) and paste the unlisted link in Console — see HEALTH_PERMISSIONS.md checklist.
- Re-export the Godot PCK and rebuild both AABs at 0.2.1 / 10007 / 20007 before upload.
