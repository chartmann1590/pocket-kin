# Pocket Kin — Play submission runbook (0.2.0 / versionCode 3)

Target: full Play Store submission (phone + Wear OS). Version code bumped 2 → 3 for the
release-readiness build. All repo-side work is done; remaining items are console actions
on your accounts, listed in the exact order they must happen.

## 0. What ships (built from this branch)

- `artifacts/pocket-kin.pck` — fresh export of the game (parent-gated rewarded ads).
- `android/phone/src/main/assets/pocket-kin.pck` — synced copy used by Gradle.
- `artifacts/pocket-kin-phone-release.aab` — phone bundle, versionCode 3, upload-key signed.
- `artifacts/pocket-kin-wear-release.aab` — Wear OS bundle, versionCode 3.
- `artifacts/play-assets/store-listing/` — icon, feature graphic, phone/tablet/Wear screenshots.
- `artifacts/play-assets/graphic-assets/` — logo, banner, promo variants.
- Website (privacy policy + support) in `docs/`, deployed to GitHub Pages by
  `.github/workflows/deploy-pages.yml` → **https://chartmann1590.github.io/pocket-kin/**
  (enable once under repo Settings → Pages → Source: GitHub Actions).

## 1. Keystore (rotate before any upload)

Upload key: `android/pocket-kin-upload.keystore` (gitignored), alias `pocketkin`,
SHA256 `81:57:C3:D6:E7:58:82:3D:DF:F3:F7:75:7C:D4:00:F7:B8:E1:B5:19:53:45:8F:41:99:64:4F:C8:61:B3:F7:6B`,
SHA1 `9D:85:2B:39:86:0F:03:FD:91:6C:CC:67:C1:24:2D:0A:7F:F9:D7:DE`.

> ROTATE NOW: passwords are still placeholder `changeit-SEE-RELEASE-NOTES`.
> `keytool -storepasswd -keystore android/pocket-kin-upload.keystore` and
> `-keypasswd -alias pocketkin`, then set `KIN_STORE_PASSWORD` / `KIN_KEY_PASSWORD` /
> `KIN_KEY_ALIAS` as environment variables or in `android/gradle.properties`
> (see `android/gradle.properties.example`; never commit). Back up the keystore offline.
> Enroll the SHA256 above in Play App Signing; keep the upload key separate from the app-signing key.

## 2. Accounts, in order

1. **GitHub Pages** — merge this PR to `main`, then repo Settings → Pages →
   Source "GitHub Actions". Verify https://chartmann1590.github.io/pocket-kin/privacy
   loads. (Play Console requires a live privacy-policy URL before app creation.)
2. **Google Play Console** ($25): create app `Pocket Kin`, package `com.pocketkin.game`,
   enroll Play App Signing, upload both AABs to the internal track.
3. **Firebase Console**: project `pocket-kin-prod`; enable Auth (Anonymous + Google),
   Firestore, Functions, Crashlytics, Remote Config. Download `google-services.json` →
   `android/phone/google-services.json` (gitignored). Set `ANDROID_PACKAGE=com.pocketkin.game`.
4. **AdMob**: create the app (package `com.pocketkin.game`), link the Firebase project, then
   create a **rewarded** unit and an **interstitial** unit. Put the three IDs into
   `android/gradle.properties` (`admobAppId`, `rewardedAdUnit`, `interstitialAdUnit`) and
   rebuild. Test units remain the default for debug builds.
   - **Rewarded Ads**: Voluntary user-initiated rewards with G-rated content filter (Free Lucky Mystery Box, Vitality Spa & Feast, and Double Minigame Petals). All rewarded ad prompts are gated behind parent gates for Families compliance.
   - **Interstitial Ads**: Shown only at natural gameplay transition points (minigame completion, returning from exploration) with a family-friendly 120-second cooldown; permanently disabled when `kin_cozy_pass` is active.
5. **Play Monetization**: configure the following managed in-app products in Play Console:
   - **Consumables**:
     - `kin_petals_small`: Pouch of Petals (+250 Petals)
     - `kin_petals_medium`: Basket of Petals (+750 Petals)
     - `kin_petals_large`: Treasury of Petals (+2,000 Petals)
     - `kin_treat_basket`: Fruit Feast (+15 each of berry, peach, melon, starfruit)
   - **Non-Consumables (Permanent)**:
     - `kin_cozy_pass`: Cozy Caretaker Pass (Ad-free care forever, Golden Crown status, boosted daily walking petals, +50% friendship growth rate)
     - `kin_cottage`: Cottage Decor Collection
     - `kin_moonlight`: Moonlight Garden Set
     - `kin_blossom`: Cherry Blossom Wardrobe
   Set up license testers in Play Console. All real-money shop interactions are protected behind parent gates (arithmetic challenges) to strictly comply with Google Play Families Policy. Consumables are immediately consumed via `consumeAsync` so they can be repurchased, and non-consumables are acknowledged via `acknowledgePurchase` to prevent automatic refunds.
6. **Service account** with *Android Publisher* role → JSON for Functions env
   (`GOOGLE_APPLICATION_CREDENTIALS`); set `ANDROID_PACKAGE`. Deploy
   `saveGame/loadGame/verifyPurchase/refreshPurchase/deleteAccount`; configure the
   `play-purchases` Pub/Sub topic → `refreshPurchase`.

## 3. Console paperwork (copy/paste sources)

| Console task | Use |
| --- | --- |
| Store listing | `release/LISTING.md` + `artifacts/play-assets/store-listing/` |
| Privacy policy URL | `https://chartmann1590.github.io/pocket-kin/privacy` |
| Support email | `support@charleshartmann.com` (site: `/support`) |
| Data safety | `release/DATA_SAFETY.md` |
| Content rating | questionnaire answers in `release/CONTENT_RATING.md` |
| Ads declaration | Yes, contains ads (AdMob); UMP consent implemented |
| Health apps declaration | steps (phone) + watch heart rate; demo video + `release/HEALTH_PERMISSIONS.md` |
| Families policy | self-certification checklist in `release/FAMILIES.md` |
| App content → website | `https://chartmann1590.github.io/pocket-kin/` |

## 4. Pre-launch gates (all green before production)

- Device matrix in `DEVICE_MATRIX.md` on your phone + watch (steps, reminders, watch
  pairing, tile/complication, offline, reboot, revocation).
- Closed testing ≥12 testers / 14 days (new personal accounts). Fix pre-launch report crashes.
- Content rating complete, Data safety complete, all declarations above submitted.
- Version: bump `versionCode` for every upload; keep `versionName 0.2.0` until public launch.

## 5. Rebuild commands

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

# Store assets (needs Python + Pillow)
python tools/generate_play_assets.py
python docs/deploy-play-assets.py
```
