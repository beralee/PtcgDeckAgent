# AI prize settlement at the turn action limit

## Incident and owning layer

The local match `match_20261004_233300_334686` stopped on turn 19 after
Dragapult ex's Phantom Dive knocked out the human player's Benched Munkidori.
The engine correctly requested one prize for player 2. The runtime log records
`ai_step_waiting_for_policy ... actions=19` immediately before the last counter
selection, followed by the prize prompt and repeated watchdog rescheduling.

`BattleSceneDialogInteractionReviewRuntime._run_ai_step` counted every
successful selection window as an action, including the six damage-counter
choices. That final choice raised the counter to 20. The unconditional action
cap then returned before dispatching the prize window. Its end-turn fallback
only applied to MAIN with no prompt, leaving Pokemon Check blocked indefinitely.
Rescheduling could not change that condition.

## Repair

The shared live scheduler now counts only successful steps initiated in MAIN,
with no pending prompt and with the current player matching the AI owner.
The 20-action protection applies at that same boundary and logs
`ai_main_action_limit` when it ends the turn. Effect continuations, prizes and
forced replacements execute through their existing current-window owners even
when the main-action budget is exhausted. Human-owned prompts remain blocked
from AI execution. Waiting policy responses do not count as completed actions.

No card effect, strategy package, legal frontier, hidden-information projection,
engine rule, cloud service or exported build was changed.

## Validation

- RED: before the scheduler repair, the new author/classic single-prize and
  two-prize regressions reproduced the engine remaining in turn 19 with prizes
  untouched. The initial effect-window fixture was subsequently corrected to
  supply a typed step array; its initial failure is not claimed as bug evidence.
- GREEN: `AITurnActionLimit` passes 8/8. It checks real engine prize movement,
  turn-20 continuation, multi-prize settlement, human ownership, six substep
  dispatches, real forced replacement, retained MAIN loop protection and budget
  reset on a new turn.
- Related suites pass 139/139: `AIBaseline` 101, `AIWatchdog` 17,
  `LocalAuthorCounterWindows` 18, `AISelfKnockoutPrizeDialog` 3.
- Original-match continuation: private snapshot event 655 was restored into the
  complete packed battle scene using the exact original Dragapult 0.29.0 package
  (`AD8396CA9C9D15058A9507D4D2CA450636E638CE4298B12902D232C515531629`), the real
  development execution gate/owner and asynchronous scene scheduler. Starting
  with the original exhausted count of 20, the AI took exactly one prize:
  prizes 3 → 2, hand 2 → 3; turn 20/player 1 began, the engine had no pending
  choice, and both prize animation and visual input blocking cleared. One
  engine commit, zero rejections; continuation completed in 1.121 seconds.

Commands:

```powershell
python scripts/tools/run_test_matrix.py --suite-script res://tests/test_ai_turn_action_limit.gd --output .tmp/ai-prize-stall-20261004/focused
python scripts/tools/run_test_matrix.py --suite AIBaseline,AIWatchdog,LocalAuthorCounterWindows,AISelfKnockoutPrizeDialog --output .tmp/ai-prize-stall-20261004/integration
```

Local receipts, logs, diagnostic probes and source-before bytes are under
`.tmp/ai-prize-stall-20261004/`. The private snapshot stays there and is neither
a committed fixture nor policy input. `live-replay-result.json` and
`live-engine-green.log` are the complete-scene continuation receipts. An initial
probe had a script-load-order error; that failed diagnostic harness was fixed
before the clean run and is not an application failure.

This proves the scoped Godot scheduler and original-position continuation,
not an exact full-match rerun, official engine parity, strategy strength or
Android/exported-device acceptance. Source-launched clients must restart to
load the change; no EXE/APK or online release was produced.

## Rollback

Revert only the action-limit/counting hunk in
`scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd` and this
task's new test/documentation. Preserve pre-existing edits in that file and the
working tree. Exact pre-edit bytes are retained locally in
`.tmp/ai-prize-stall-20261004/source-before/`; do not replace the entire file if
subsequent work has changed it. Rolling back reintroduces the reproduced stall.
