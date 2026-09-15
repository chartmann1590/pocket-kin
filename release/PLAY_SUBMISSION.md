# Pocket Kin — Play submission runbook (0.2.0 / versionCode 2)

Target: full Play Store submission (phone + Wear OS). Accounts: none yet — all external steps listed.

## 1. Artifacts built 2026-09-08 (local, `artifacts/` gitignored)

- `pocket-kin.pck` 33.5 MB (fresh `--export-pack Pack`, final art)
- `android/phone/src/main/assets/pocket-kin.pck` synced copy used by Gradle builds
- `pocket-kin-phone-debug.apk` 217 MB, `pocket-kin-wear-debug.apk` 45 MB (install on your phone + watch now)
- `pocket-kin-phone-release.aab` 96.7 MB, `pocket-kin-wear-release.aab` 24.0 MB (signed with local upload key, upload to Play)
- Godot sim + world PASS, backend `npm test` 4/4 PASS, Firestore + Functions emulator PASS

Upload key: `android/pocket-kin-upload.keystore` (gitignored), alias `pocketkin`,
SHA256 `81:57:C3:D6:E7:58:82:3D:DF:F3:F7:75:7C:D4:00:F7:B8:E1:B5:19:53:45:8F:41:99:64:4F:C8:61:B3:F7:6B`,
SHA1 `9D:85:2B:39:86:0F:03:FD:91:6C:CC:67:C1:24:2D:0A:7F:F9:D7:DE`.

> ROTATE IMMEDIATELY: passwords are placeholder `changeit-SEE-RELEASE-NOTES`.
> `keytool -storepasswd -keystore android/pocket-kin-upload.keystore` + `-keypasswd -alias pocketkin`,
> then set env `KIN_STORE_PASSWORD` / `KIN_KEY_PASSWORD` / `KIN_KEY_ALIAS` (or `gradle.properties`
> `KIN_STORE_PASSWORD=` etc. locally — never commit). Back up keystore + passwords offline.
> Enroll the SHA256 above in Play App Signing; keep upload key separate from app-signing key.

## 2. Create accounts (order matters)

1. Google Play Console ($25): create app `Pocket Kin`, package `com.pocketkin.game`, enroll Play App Signing, upload both AABs to internal → closed track.
2. Firebase Console: project (e.g. `pocket-kin-prod`), enable Auth (Anonymous + Google), Firestore, Functions, Crashlytics, Remote Config. Download `google-services.json` → `android/phone/google-services.json` (gitignored). Set `ANDROID_PACKAGE=com.pocketkin.game`.
3. AdMob: App ID + rewarded + interstitial units + UMP funding-choices. Replace test IDs in `android/phone/build.gradle.kts:15-17` via gradle props `admobAppId`, `rewardedAdUnit`, `interstitialAdUnit`. Rebuild + retest.
4. Play Monetization: managed products `kin_cottage`, `kin_moonlight`, `kin_blossom` (permanent cosmetic bundles), license testers, pending/refund/restore tests.
5. Service account with `Android Publisher` role → JSON to Functions env (`GOOGLE_APPLICATION_CREDENTIALS`); set `ANDROID_PACKAGE`. Deploys `saveGame/loadGame/verifyPurchase/refreshPurchase/deleteAccount`. Configure `play-purchases` Pub/Sub topic → `refreshPurchase`.

## 3. Pre-launch gates (must all be green before production track)

- Device matrix in `DEVICE_MATRIX.md` on your phone + watch (steps, reminders, watch pairing, tile/complication, offline, reboot, revocation).
- Content rating questionnaire, Data Safety (see `DATA_SAFETY.md`), Health permissions declaration (steps-only video + `PRIVACY_POLICY.md` URL), Families self-cert (neutral age screen + parent gate 7×8 already in client), Ads declaration (AdMob + UMP), News? No.
- Closed testing ≥12 testers / 14 days (new accounts). Fix pre-launch report crashes.
- Store listing in `LISTING.md` + feature graphic + 2+ phone + watch screenshots (capture from your hardware, 16:9/9:16 per Play spec).
- Version: bump `versionCode` each upload; keep `versionName 0.2.0` until public. Tag release in git.

## 4. Rebuild commands

```
# Godot PCK (from game/)
../tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-pack "Pack" "../artifacts/pocket-kin.pck"
Copy-Item ..\artifacts\pocket-kin.pck android\phone\src\main\assets\pocket-kin.pck -Force

# Gradle (from android/, needs JDK 17+, SDK 36)
..\tools\gradle-8.13\bin\gradle.bat :phone:assembleDebug :wear:assembleDebug
..\tools\gradle-8.13\bin\gradle.bat :phone:bundleRelease :wear:bundleRelease

# Backend checks (repo root, needs npx firebase-tools)
npm --prefix backend test
npx firebase-tools emulators:exec --only firestore,auth --project demo-pocket-kin "node backend/test/firestore.integration.js"
npx firebase-tools emulators:exec --only firestore,auth,functions --project demo-pocket-kin "node backend/test/functions.integration.js"
```
