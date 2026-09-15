# 13. Widget, fullscreen, sound and visual polish

Status: implementation complete; device verification in progress.

User additions: home-screen widget, sound, optional fullscreen, beautiful visuals and gameplay, no controls obscured by navigation or system bars.

- [x] Native resizable Android home-screen widget with original pet art, name, last saved needs, Care and Play links.
- [x] Widget refreshes with phone saves and background watch care; opens the correct game page on warm and cold launch.
- [x] Widget pin request in Settings.
- [x] Persisted fullscreen preference with swipe-to-reveal system bars.
- [x] Layout reads system bars, cutouts and keyboard insets; scrolling content reserves app navigation space.
- [x] Mini-games fit inside the available safe rectangle; toast placement follows available height.
- [x] Original ambient music and tap/care/hatch/reward/sleep effects with independent toggles.
- [x] Hatch animation, care reactions, favorite foods and friendship tricks.
- [ ] Verify widget pinning and both links on Pixel 8 Pro.
- [ ] Verify fullscreen, keyboard, games and all navigation screens on Pixel 8 Pro.

Assets: widget reuses the six generated pet atlases recorded in asset-inventory.md; native rounded cream widget background and typography. No extra downloaded artwork. Production sprites and backgrounds use the final generated assets.

Evidence: KinWidget.kt, kin_widget.xml, KinServices.kt, main.gd and minigame.gd. Detailed device results are recorded in 11-testing-and-accessibility.md and 07-watch-companion.md.
