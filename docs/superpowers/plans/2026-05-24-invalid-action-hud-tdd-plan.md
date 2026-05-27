# Invalid Action HUD TDD Plan

**Date:** 2026-05-24

**Design:** `docs/superpowers/specs/2026-05-24-invalid-action-hud-design.md`

## Objective

Replace generic "cannot use" battle feedback with a HUD popup that explains why a card or action is blocked. The change must be test-driven and must not alter the underlying game rules.

## Delivery Criteria

- Invalid hand-card attempts produce a HUD reason popup.
- Invalid selected-card target attempts produce a HUD reason popup.
- Disabled Pokemon action dialog items expose clear reason text inline and do not open the full-screen invalid HUD.
- The battle log still records a short reason.
- Existing gameplay and dialog selection tests continue to pass.

## 2026-05-24 Refinement: Pokemon Action HUD Disabled Rows

Problem:

- Battle Active ability/attack details are rendered in the Pokemon action HUD.
- Disabled rows already show full text and `不可用：原因`.
- Clicking a disabled row currently confirms the option, closes the action HUD, and opens `InvalidActionOverlay`, which hides the original card/action detail surface.

Plan:

- [x] Document the distinction between hand-card invalid hints and field Pokemon action HUD disabled rows.
- [x] Add RED tests proving disabled action HUD rows do not confirm or create the invalid overlay.
- [x] Add a runtime fallback test proving `pokemon_action` disabled choices do not call `_show_invalid_action_message`.
- [ ] Keep existing hand-card invalid hint tests unchanged.
- [x] Keep existing hand-card invalid hint tests unchanged.
- [x] Update `BattleDialogController` so disabled action HUD rows consume clicks without confirming.
- [x] Update the `pokemon_action` fallback branch to log only, without creating the full-screen overlay.
- [x] Run focused tests for dialog, action-controller, invalid-hint, and battle UI behavior.

## Phase 0: Baseline

- [x] Run focused script-load tests.
- [x] Run existing battle action/dialog tests.
- [x] Record unrelated failures if present.

## Phase 1: RED Tests

Add focused tests before implementation:

- `tests/test_invalid_action_reasons.gd`
  - Supporter used this turn.
  - First player's first-turn Supporter restriction.
  - Energy already attached this turn.
  - Bench full blocks Basic Pokemon.
  - Same Stadium already in play.
  - Tool target already has a Tool.
  - Nest Ball and Buddy-Buddy Poffin Bench full reasons.
  - Ultra Ball discard-cost reason.
  - Rare Candy no-valid-target reason.

- `tests/test_battle_invalid_action_hint_controller.gd`
  - Popup nodes are created.
  - Payload text is rendered.
  - Popup hides cleanly.
  - Showing popup does not mutate dialog state fields on a lightweight host.

- Extend or add `tests/test_battle_action_controller_invalid_hints.gd`
  - Blocked Supporter calls `_show_invalid_action_hint`.
  - Blocked Item calls `_show_invalid_action_hint`.
  - Blocked Stadium calls `_show_invalid_action_hint`.

## Phase 2: Rule Reason Layer

- Add reason-returning APIs to `RuleValidator`.
- Rework existing `can_*` functions to delegate to reason APIs where risk is low.
- Keep `can_*` signatures intact for existing callers.
- Add generic `EffectProcessor.get_card_from_hand_block_reason`.

## Phase 3: Effect-Specific Reasons

- Add optional default methods to `BaseEffect`.
- Implement high-frequency Trainer reasons:
  - `EffectNestBall`
  - `EffectBuddyPoffin`
  - `EffectUltraBall`
  - `EffectRareCandy`
- Add bridge method `EffectProcessor.get_effect_unusable_reason`.

## Phase 4: HUD Controller

- Add `scripts/ui/battle/BattleInvalidActionHintController.gd`.
- Dynamically build the overlay under `BattleScene`.
- Add landscape and portrait metrics.
- Style with the existing HUD theme language.
- Add wrapper methods on battle runtime:
  - `_show_invalid_action_hint(payload_or_reason)`
  - `_hide_invalid_action_hint()`

## Phase 5: UI Wiring

- Wire `BattleActionController` hand-card failure paths.
- Wire selected hand-card target failures in `BattleSceneBoardActionRuntime`.
- Wire disabled action item selection in `BattleSceneDialogInteractionReviewRuntime`.
- Preserve existing `_log()` calls using the short reason.

## Phase 6: Verification

Run focused tests:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_invalid_action_reasons.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_invalid_action_hint_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_action_controller_invalid_hints.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_script_load_regressions.gd
```

Run broader regressions if focused tests pass:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_dialog_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_rule_validator.gd
```

## Verification Notes

- `test_invalid_action_reasons.gd`: 10 passed, 0 failed.
- `test_battle_invalid_action_hint_controller.gd`: 2 passed, 0 failed.
- `test_battle_action_controller_invalid_hints.gd`: 3 passed, 0 failed.
- `test_battle_dialog_controller.gd`: 11 passed, 0 failed.
- `test_battle_ui_features.gd`: 246 passed, 0 failed.
- `test_rule_validator.gd`: 24 passed, 0 failed.
- `test_script_load_regressions.gd`: battle/runtime load checks passed; one unrelated existing AI strategy assertion remains: `DeckStrategy17BombCharizardLLM.gd should extend the shared v17 LLM base`.

## 2026-05-24 Refinement Verification Notes

- RED confirmed:
  - `test_disabled_action_hud_option_does_not_confirm_or_hide_dialog` failed before the controller change because disabled rows still confirmed and closed the action HUD.
  - `test_battle_scene_disabled_pokemon_action_choice_does_not_open_invalid_overlay` failed before the runtime fallback change because `InvalidActionOverlay` was created.
- GREEN:
  - `test_battle_dialog_controller.gd`: 11 passed, 0 failed.
  - `test_battle_ui_features.gd`: 246 passed, 0 failed.
  - `test_battle_action_controller_invalid_hints.gd`: 3 passed, 0 failed.
  - `test_battle_invalid_action_hint_controller.gd`: 2 passed, 0 failed.
  - `test_script_load_regressions.gd`: same unrelated existing failure remains: `DeckStrategy17BombCharizardLLM.gd should extend the shared v17 LLM base`.

## Rollback Strategy

The feature is isolated behind new reason methods and one UI controller. If a late regression appears:

- Disable only `_show_invalid_action_hint` calls and keep the reason APIs.
- Keep the old `_log()` behavior as fallback.
