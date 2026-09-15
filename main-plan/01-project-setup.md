# 1. Project setup

Status: complete (desktop/PCK verified; Android binary blocked on templates)

## Deliverables

Godot project, pinned engine, Android export, Kotlin bridge, reproducible scripts.

## Implementation tasks

- [x] Install portable Godot and export templates.
- [x] Configure portrait 720x1280 responsive viewport and Android package.
- [x] Create independent simulation tests and native build modules.
- [x] Produce desktop and Android smoke builds.

## Notes / departures

- Engine pinned: portable Godot 4.7.2 in `tools/godot/` (project features
  4.5 -> 4.7). Export templates 4.7.2.stable ARE installed
  (`%APPDATA%/Godot/export_templates/4.7.2.stable` verified 2026-09-08)
  and full Android SDK 36 present (`C:/Users/Charles/AppData/Local/Android/Sdk`),
  so template builds are now reproducible. Version unified 0.2.0 / code 2
  across `game/project.godot`, `export_presets.cfg`, `android/phone` + `wear`.
- `game/export_presets.cfg` defines Pack (verified), Windows Desktop and
  Android (declared; release AAB + signing in progress).
- Android package reserved in project + preset: `com.pocketkin.game`.
- Repro commands (from `game/`):
  `../tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`
  `--script res://tests/simulation_test.gd` / `res://tests/world_test.gd`
  `--export-pack "Pack" "../artifacts/pocket-kin.pck"`
- 2026-09-08: `--import` clean; simulation + world PASS; backend `npm test` 4/4 PASS.

## Acceptance

Engine imports without errors; Android debug build installs or installation limitation is recorded.

## Dependencies

Android templates/SDK/signing and Kotlin bridge build are external and
unconfigured (see decisions.md).

## Evidence

Clean `--import`; `pocket-kin.pck` (22,124,228 bytes, with placeholder
atlases + audio) exported 2026-09-07; simulation + world suites PASS
(see step 11).

