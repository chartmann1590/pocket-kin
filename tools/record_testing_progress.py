"""Record the September 8 paired-device implementation and verification pass."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
plan=root/'main-plan'
def write(name,text): (plan/name).write_text(text.strip()+'\n',encoding='utf-8')
def append(name,text):
    p=plan/name
    p.write_text(p.read_text(encoding='utf-8').rstrip()+'\n\n'+text.strip()+'\n',encoding='utf-8')
write('07-watch-companion.md','''# 7. Watch companion

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
''')
write('10-reminders-and-settings.md','''# 10. Reminders and settings

Status: implemented; fullscreen and widget device checks passed, notification timing/denial checks outstanding.

- Music, effects, haptics, reduced motion, fullscreen and reminders persisted locally.
- Quiet hours default 21:00-08:00; sleep hours default 22:00-07:00.
- Native CareScheduler schedules at most three inexact reminders outside quiet hours, cancels obsolete alarms and restores after reboot.
- Phone notifications mirror to Wear OS; no separate duplicate watch notification stream.
- Fullscreen hides system bars and permits transient swipe reveal. Pixel 8 Pro verified; layout retains cutout clearance and reserved app navigation space.
- Home-screen widget added successfully on Pixel; Care opens the food chooser and Play opens mini-games. Native widget reuses generated pet atlases.
- Insets include keyboard, system bars and display cutouts. Native results are deferred to the game loop before changing scenes.
- Original ambient music and tap/care/hatch/reward/sleep effects integrated.

See [widget/fullscreen/polish step](13-widget-fullscreen-and-polish.md) for additional checks. Notification permission denial, quiet-hours delivery and reboot timing remain device-test items. The Android bridge is built; earlier tooling blockers no longer apply.
''')
append('master-plan.md','''## Added implementation step: widget and visual polish

The plan remains the first saved deliverable. Step [13](13-widget-fullscreen-and-polish.md) individually tracks the user's home-screen widget, fullscreen, sound and unobscured-navigation requirements. The dedicated watch emulator is now paired to the Pixel 8 Pro; results and reconnect instructions are in step 7.''')
append('11-testing-and-accessibility.md','''## Paired Pixel/Wear pass — 2026-09-08

- Godot simulation/world regression tests PASS; all nine desktop screen renders complete without script errors.
- Phone and Wear debug builds, native care unit tests and release bundles build successfully.
- Wear OS 5 emulator paired to Pixel 8 Pro; foreground Feed and background Cuddle acknowledged and persisted exactly once. Zero-hit 20-second rhythm completion gives 5 petals. Offline controls disable and reconnect.
- Fullscreen verified on Pixel; app navigation remains above the system navigation region in normal mode and reachable in fullscreen.
- Widget pinning, pet display, Care and Play links verified on Pixel. Phone screenshots exposed a resume-time texture issue; native callbacks now defer scene work to the game loop, with final retest recorded separately.
- Firebase Functions emulator PASS: authenticated save/load, CAS conflict, privacy stripping, cross-account isolation and invalid input rejection. Lazy-loading the Play API client fixes function discovery startup timeouts.
- Physical-watch battery, tile/complication UI, Health Connect permission/source scenarios, reminders, full accessibility and live billing/ad checks remain open.''')
append('08-firebase-and-cloud-saves.md','''## Emulator verification — 2026-09-08

Authenticated Functions save/load, CAS conflict, privacy stripping, cross-account isolation and invalid input rejection PASS using demo-pocket-kin. Conflict responses now carry server revision, and keeping local state advances the expected cloud revision for the next explicit save. Play API loading is deferred until purchase verification to avoid discovery timeouts. Production Firebase configuration is still absent.''')
append('12-build-and-release.md','''## Paired test build update — 2026-09-08

Native phone/watch debug APKs and signed release bundles rebuilt after widget, fullscreen and Wear fixes. Google test ad units remain active; Firebase and Play production configuration remain external prerequisites. Production exports now explicitly exclude archived development artwork and test scripts. Root README and tools/start-watch-testing.ps1 document reproducible setup. No public upload performed.''')
p=plan/'README.md'
t=p.read_text(encoding='utf-8').replace('149 *-final.png generated-integrated','135 individually indexed generated assets').replace('paired-device verification outstanding','paired Pixel/emulator care verified; remaining device matrix tracked').replace('emulator + live project outstanding','Functions emulator PASS; live project outstanding')
t+='\n- [ ] [Widget, fullscreen and visual polish](13-widget-fullscreen-and-polish.md) — implemented; final rendering/gameplay checks in progress.\n'
p.write_text(t,encoding='utf-8')
print('Recorded paired-device results and updated individual plan steps.')
