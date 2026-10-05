# Automatic opening mulligan bonus and informational HUD

## Behavior and owning changes

At the user's request, the normal battle scene now accepts the entire opening
mulligan bonus automatically for either seat. It no longer opens a HUD choice
for drawing zero, one, or more cards. The engine resolves the draw immediately
and continues to opening Pokemon placement. A separate input-transparent
notice reports the actual beneficiary and number of cards drawn, has no
buttons, and removes itself after four seconds. It fits the portrait layout
and reports an exhausted deck without claiming nonexistent cards were drawn.

The original engine emitted a bonus decision after every failed hand with a
cumulative maximum of 1, 2, etc. Taking each maximum could award 1 + 2 cards
for two mulligans. `GameStateMachine._check_mulligan` now completes both opening
hands first and emits a single decision with the total unmatched mulligans.
Simultaneous failures still cancel. The bounded setup retry guard now covers
single-player redraw loops as well as simultaneous redraws. The legacy boolean
acceptance wrapper takes the full accumulated entitlement for headless callers.

The engine's exact `resolve_mulligan_draw_count` boundary still accepts legal
zero/intermediate/full counts and rejects invalid or already-consumed windows.
Normal UI play simply submits the full count automatically. This is a local
engine/UI behavior change, not an assertion of full CABT cross-runtime parity.
No external oracle, policy package, private service, or network API was changed.

## Regression evidence

- RED: the new aggregate-bonus engine regression failed because the first
  pending window contained only one redraw; `.tmp/mulligan_count_red.log`.
- RED: both updated human/AI scene tests reproduced the unwanted modal;
  `.tmp/mulligan_ui_red.log`.
- Full `GameStateMachine` plus new `BattleMulliganNotice` functional suites:
  **84/84**, `.tmp/mulligan_engine_integration.log`.
- Focused AI baseline mulligan coverage: **6/6**,
  `.tmp/mulligan_ai_integration.log`.
- Portrait notice layout: **1/1**, `.tmp/mulligan_portrait_green.log`.
- Headless pending-window recovery and bonus resolution: **2/2**,
  `.tmp/mulligan_bridge_integration.log`.
- External decision-port numeric candidate representation: **1/1**,
  `.tmp/mulligan_external_port.log`.

All final runners exit 0. The new notice suite checks actual hand changes for
both beneficiaries and bonuses of 1, 2, and 3; immediate setup continuation;
no interactive buttons or mouse capture; rejection of stale duplicate events;
short/empty decks; and actual timed dismissal in the scene tree without input.
The repeated-redraw engine test uses a deterministic shuffle that preserves
all cards and produces a failed hand followed by a valid one.

Some existing broader suites emit shutdown resource-leak diagnostics; the
results above are functional gates, not resource-lifetime or packaged-device
acceptance. No export or deployment was performed.

## Rollback

Revert only the mulligan hunks in `GameStateMachine.gd`, the scene's automatic
bonus branch and notice preload, the corresponding test changes, and the new
notice implementation/test files. Preserve unrelated working-tree edits,
including the earlier 18.5 bundled-deck work. An already-running source game
must be fully restarted to load these scripts.
