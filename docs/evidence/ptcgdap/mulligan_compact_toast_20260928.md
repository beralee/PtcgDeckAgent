# Compact opening mulligan notice

The opening bonus remains automatic. Only `BattleMulliganNotice.gd` owns this
presentation change; the engine, setup decisions and policy contracts are unchanged.

The old wrapping Label could establish a very large minimum height before its
width settled. Real in-tree layout reproduced heights of 6,475 and 10,087 logical
pixels with long participant names. The old notice also kept its initial rectangle
when the portrait safe frame changed.

The replacement is a small top-centered toast: a draw-count badge, a result line,
and a quieter reason. Explicit content geometry and single-line labels keep its
height at 76 display pixels on the checked phone/desktop canvases. Names are
abbreviated to fit while retaining the count and reason. The toast follows the
safe frame and viewport stretch, fades in, and fades out automatically after
3.4 seconds plus a 0.2-second fade. Every element ignores pointer input. Repeated
notices replace the previous one. Short and empty decks still report the actual
draw, and the notice does not delay setup.

## Local validation

- Original-owner RED: two layout regressions failed (oversized notice and stale
  portrait rectangle), `.tmp/mulligan-toast/red/report.json`.
- Final `BattleMulliganNotice`: 6/6 pass,
  `.tmp/mulligan-toast/verified-notice/report.json`. Includes real engine bonus
  resolution for both seats, duplicate events, empty/short decks, timed dismissal,
  long names, 320/390/1600-wide layouts, changing safe frames, and a 900-unit phone
  canvas displayed at 390 pixels then resized back to desktop.
- Existing portrait-scene integration: 1/1 pass,
  `.tmp/mulligan-toast/verified-portrait/report.json`.
- Windows OpenGL rendering of the actual Arena battle scene was inspected at
  1600×900 and 390×844. Captures: `.tmp/mulligan-toast/1600x900.png` and
  `.tmp/mulligan-toast/390x844.png`; the injected notification is a presentation
  fixture, not evidence of a naturally occurring mulligan.

This is local presentation and functional validation. No Android/iOS device,
exported build, CABT alignment promotion, or release is claimed.

## Rollback

Restore only the toast presentation and its affected tests. The preceding
automatic-draw behavior and all unrelated worktree edits must be preserved.
The pre-change toast and portrait-test copies are in `.tmp/mulligan-toast/`
as `BattleMulliganNotice.before.gd` and `test_battle_portrait_layout.before.gd`.
No engine rollback is needed. Restart the running source game to load the change.
