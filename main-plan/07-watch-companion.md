# 7. Watch companion

Status: built and paired-device care verified on 2026-09-08. Physical-watch battery/performance and tile/complication interaction checks remain.

## Implemented

- Native Wear OS Compose app with original pet artwork, needs, feed/cuddle/wash/bedtime, walking progress and 20-second rhythm play.
- Data Layer snapshots, ping responses, request IDs, pet IDs, expected revisions and acknowledgements. Duplicate/stale commands are rejected safely.
- Phone applies care while foregrounded or through the native save adapter when backgrounded. Resume reloads external changes.
- Cached offline display; no offline care queue. Five-second heartbeat disables actions when the phone is unreachable.
- Pet tile and mood/steps complication. Tile image resources change with species/stage/sleep. Tiles upgraded to 1.6.2 after reproducing its older API-34 update crash.

## Emulator and pairing

Dedicated AVD: `PocketKin_Wear_API34`, Android 14 / Wear OS 5, round 454x454, serial `emulator-5556`. Physical phone: Pixel 8 Pro `37220DLJG001ML`.

Google companion app reports Connected. Both debug APKs use the same certificate (SHA-256 `2d568dc6b96d982b19320c575924dd94f29f1438c18379b581cf0c5bd193bd53`). The earlier mismatched watch test APK was replaced on this newly created emulator.

Run `tools/start-watch-testing.ps1 -Install`. Pairing uses phone forward `tcp:5601` and emulator reverse `tcp:5601`; Google Play Services falls back to localhost when host-network access times out. ADB restarts clear tunnels. `tools/watch-connection.ps1` restores them for eight hours; recovery can take approximately two minutes while Wear OS retries.

## Verified results

- Foreground watch Feed: phone hunger about 21% -> 49%, revision 1 -> 2, one successful receipt; watch displays 49%.
- Background watch Cuddle: phone happiness about 50% -> 70%, revision 2 -> 3, second successful receipt. Phone reopening preserves changes.
- Watch rhythm runs 20 seconds and adds its bounded reward: phone coins 80 -> 85 in the zero-hit completion test.
- Watch reconnects and displays the same pet; loss of the ADB tunnel disables controls.
- Watch artwork renders on the round emulator; all care buttons are reachable by scrolling.
- Native care unit tests pass, including duplicate IDs, stale revision, different pet and short-game rejection.

Evidence: artifacts/pixel-before-watch.json, pixel-after-watch.json, pixel-background-watch.json, watch-care.png, Data Layer diagnostics and Android build logs.

## Remaining checks

- Add/open tile and complication through system UI and inspect live updates.
- Complete timed-hit rhythm interaction and cancellation checks.
- Physical watch battery, smaller-screen, font-scale and notification tests.

References: [Android pairing guide](https://developer.android.com/training/wearables/get-started/connect-phone), [AndroidX Tiles release notes](https://developer.android.com/jetpack/androidx/releases/wear-tiles).
