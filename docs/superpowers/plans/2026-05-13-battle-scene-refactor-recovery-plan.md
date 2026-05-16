# BattleScene Refactor Recovery Plan

**Date:** 2026-05-13  
**Updates:** `2026-05-11-battle-scene-full-refactor.md`  
**Related design update:** `docs/superpowers/specs/2026-05-13-battle-scene-refactor-current-state-update.md`  
**Scope:** Recovery plan with current implementation checkpoint.

## Current Status

The original all-phase refactor plan has not been fully completed. The codebase now has useful architecture scaffolding. The immediate line-count recovery has been implemented by making `BattleScene.gd` a thin scene entry and splitting the legacy implementation into `BattleSceneRuntime.gd` plus business-named runtime files under `scenes/battle/runtime/`.

Current local measurements:

- `BattleScene.gd`: 3 lines
- `BattleScene.gd`: 0 functions
- `BattleSceneRuntime.gd`: ~1890 lines
- `scenes/battle/runtime/BattleScene*Runtime.gd`: each business runtime file under 3000 lines
- `scenes/battle/runtime/BattleSceneRuntimeFoundation.gd`: ~543 lines, still owns 99 `@onready` refs
- `scripts/ui/battle` private scene reflection: ~1206 occurrences
- `test_battle_scene_architecture_audit.gd`: passing for the entry shell and architecture files

This means the next work should not proceed as if the refactor is complete. The line-count gate is restored, but the compatibility runtime files must now be reduced domain by domain.

## Operating Rules

1. Do not mix structural refactor work with unrelated gameplay or UI feature work.
2. Do not add new private scene reflection in migrated modules.
3. Every moved behavior must have a focused regression test.
4. Player UI and headless/AI bridge paths must be kept in sync.
5. Each phase must reduce at least one measurable metric:
   - `BattleScene.gd` lines
   - `BattleScene.gd` functions
   - private scene reflection count
   - scene-owned state fields
   - scene-owned node refs
6. If a phase increases one metric temporarily, it must reduce another and include a follow-up cleanup task before the phase is marked complete.

## Phase R0: Recovery Gate

### Goal

Restore the current architecture audit to passing before continuing broad migration.

### Tasks

- Re-run architecture measurement and record current numbers.
- Identify the newest scene-side additions that can be moved into existing helper/coordinator modules.
- Reduce `BattleScene.gd` below the current audit gate.
- Keep the recent Squawkabilly/bench-entry trigger fix covered while avoiding more scene growth.
- Confirm no new private scene reflection was added to architecture files.

### Acceptance

- `test_battle_scene_architecture_audit.gd` passes. **Done for the entry/runtime split.**
- `test_script_load_regressions.gd` passes. **Done for the entry/runtime split.**
- Existing Squawkabilly bench-entry regression tests pass.
- No behavior changes beyond the already intended bug fixes.

### Suggested Tests

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_scene_architecture_audit.gd
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_script_load_regressions.gd
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_setup_flow.gd --test-filter=first_turn_draw
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_headless_match_bridge.gd --test-filter=bench
```

## Phase R1: Re-baseline The Architecture Audit

### Goal

Make the architecture audit reflect staged progress instead of only a single temporary line-count ceiling.

### Tasks

- Extend audit output to report:
  - line count
  - function count
  - `@onready` count
  - private scene reflection count
  - largest controller files
- Keep current hard fail for line/function threshold.
- Add non-failing diagnostic assertions or logs for reflection and file-size counts.
- Define the next target threshold inside the audit after Recovery Gate passes.

### Acceptance

- Architecture audit gives enough information to guide the next migration.
- The audit fails when `BattleScene.gd` grows past the active threshold.
- The audit does not fail solely because legacy controllers still have known old reflection debt.

## Phase R2: Prompt/Dialog Ownership

### Goal

Move prompt routing and large dialog branching out of `BattleScene`.

### Tasks

- Define concrete prompt IDs and payload contracts in `BattlePromptRequest`.
- Make `BattlePromptSelection` represent confirmed user choices.
- Expand `BattlePromptRouter` from skeleton to owner for:
  - setup active
  - setup bench
  - send out
  - retreat
  - Pokemon action popup
  - stadium action
  - prize selection
  - Heavy Baton / Exp Share style prompts
- Reduce scene methods that only switch on `_pending_choice`.
- Move dialog state fields into `BattleDialogState`.

### Acceptance

- `_handle_dialog_choice` is deleted or reduced to a thin router call.
- Prompt tests cover setup, send-out, retreat, prize, and unknown prompt IDs.
- Player UI behavior remains unchanged.
- Headless prompt owner behavior remains unchanged.

### Suggested Tests

- `test_battle_prompt_router.gd`
- `test_battle_dialog_controller.gd`
- `test_setup_flow.gd`
- `test_headless_match_bridge.gd`
- `test_battle_ui_features.gd`

## Phase R3: Interaction And Effect Flow Ownership

### Goal

Move field target selection, assignment, and counter distribution out of scene-owned private fields.

### Tasks

- Move `_field_interaction_*` data into `BattleInteractionState`.
- Make `BattleInteractionCoordinator` own interaction lifecycle.
- Keep `BattleEffectInteractionController` as a surface/helper until it can be reduced.
- Ensure follow-up interaction steps work in both player UI and headless bridge.
- Add tests for partial assignments, cancel paths, and target limits.

### Acceptance

- Scene no longer directly owns most field interaction data.
- Player UI and headless bridge share the same step semantics.
- Munkidori, bench damage, energy assignment, and counter distribution regressions pass.

### Suggested Tests

- `test_battle_interaction_coordinator.gd`
- `test_battle_ui_features.gd`
- `test_headless_match_bridge.gd`
- card/effect suites for cards using multi-step interactions

## Phase R4: Display Refresh Ownership

### Goal

Move card view creation and board/hand/pile refresh ownership out of `BattleScene`.

### Tasks

- Expand `BattleDisplayCoordinator` beyond wrapping.
- Split focused presenters only where they reduce real coupling:
  - hand presenter
  - field presenter
  - pile/prize presenter
  - card detail presenter
- Move BattleCardView creation and refresh logic into display-owned modules.
- Keep recent portrait hand text, draw reveal, stadium HUD, and detail popup behavior covered.

### Acceptance

- `BattleScene._refresh_ui()` is a thin call to display coordinator.
- Hand, field, pile, prize, and detail display tests pass.
- No display presenter calls gameplay actions directly.

## Phase R5: Overlay, Prize, Handover, Match End

### Goal

Make overlay lifecycle independent from the scene's central state blob.

### Tasks

- Move prize selection state to `BattleOverlayState` or a prize-specific state object.
- Consolidate simultaneous prize-taking behavior.
- Move local handover state and match-end overlay behavior into `BattleOverlayCoordinator`.
- Keep match-end quick review orchestration separated from visual overlay state.

### Acceptance

- Prize choice and handover prompts are not scene-owned branches.
- Simultaneous prize-taking regressions pass.
- Portrait overlay tests pass.

## Phase R6: Layout Ownership

### Goal

Finish the layout migration so landscape and portrait layout implementation does not live in `BattleScene`.

### Tasks

- Move remaining landscape and portrait implementation details into layout views/presenters.
- Keep `BattleScene` wrappers only as compatibility calls or remove them.
- Move layout debug reporting entirely into `BattleLayoutDebugReporter`.
- Keep macOS large-window and mobile portrait constraints covered.

### Acceptance

- Layout implementation methods in scene are deleted or 1-3 line wrappers.
- Portrait and landscape layout focused tests pass.
- No feature code performs one-off layout clamps outside layout modules.

## Phase R7: AI, Advice, Replay, Recording

### Goal

Move remaining service wiring and state ownership for AI/advice/replay/recording out of scene internals.

### Tasks

- Make `BattleAiOpponentFactory` the only AI opponent construction path.
- Move advice state fully into `BattleAdviceState`.
- Move recording state fully into `BattleRecordingState`.
- Keep replay loading/restoration as an explicit service boundary.
- Remove scene-owned duplicate state where coordinator state exists.

### Acceptance

- AI, advice, replay, and recording tests pass.
- Scene retains only lifecycle-level wiring.
- No new private scene reflection is introduced.

## Phase R8: Final Wrapper Cleanup

### Goal

Remove compatibility wrappers and lower `BattleScene.gd` toward final target size.

### Tasks

- Delete wrappers that are no longer referenced by tests or controllers.
- Move remaining `@onready` references into `BattleSceneRefs`.
- Delete duplicate state fields after migration.
- Tighten architecture audit thresholds after each successful deletion pass.

### Acceptance

- `BattleScene.gd` approaches 1200-1800 lines.
- Private scene reflection in migrated modules is near zero.
- Major controllers are under their target size or split by domain.
- Full focused battle test suites pass.

## Immediate Next Checklist

Before writing more refactor code:

- [ ] Accept this revised current-state design update.
- [ ] Accept this recovery plan.
- [ ] Decide whether the next implementation task is Recovery Gate only or Recovery Gate plus Prompt/Dialog ownership.
- [ ] Re-run baseline metrics immediately before editing code.
- [ ] Keep all behavior fixes separate from structural migration commits.

## Stop Conditions

Pause and reassess if any of these occur:

- A migration requires changing gameplay rules.
- A phase cannot reduce any architecture metric.
- Player UI and headless/AI behavior diverge.
- `test_battle_ui_features.gd` or `test_battle_portrait_layout.gd` fails for reasons unrelated to the migrated domain.
- A controller grows larger while still relying on private scene reflection.
