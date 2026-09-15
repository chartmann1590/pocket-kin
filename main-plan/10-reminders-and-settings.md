# 10. Reminders and settings

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
