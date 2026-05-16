# Battle Portrait Layout Rollout Plan

## Status

First implementation complete. This plan tracks the design in `docs/superpowers/specs/2026-05-07-battle-portrait-layout-design.md`.

Delivered in the first pass:

- `GameManager` battle layout preference with persisted setup selection.
- `BattleLayoutController` auto/landscape/portrait resolver and portrait card metrics.
- Battle setup selector under the map background section.
- In-battle layout toggle.
- Portrait layout shell with collapsed side/log panels.
- Portrait bench grid using four columns, with metrics sized for future 8-bench support.
- Portrait prize HUD behavior: hidden by default, visible for the selecting player during prize taking.
- Portrait `more` popup for secondary actions and battle log access.
- Focused TDD coverage in `tests/test_battle_portrait_layout.gd`.

Follow-up correction after visual review:

- The first pass still looked wrong on Android because it only rearranged controls inside the original landscape viewport.
- The battle layout mode now needs an orientation/window layer: mobile uses runtime screen orientation requests; desktop preview swaps the battle window between landscape and portrait aspect.
- Portrait layout metrics should apply after the viewport becomes tall, not as a substitute for real device orientation.
- When the platform refuses to provide a tall viewport, use a BattleScene-level 90-degree rotated canvas fallback so forced portrait visibly rotates the whole battle instead of remaining a horizontal board.

## Outcome

Ship an optional mobile portrait battle layout without changing battle rules, card effects, AI behavior, or interaction semantics.

User-facing result:

- Battle setup exposes battle layout under map background: `Auto`, `Landscape`, `Portrait` (`自动`, `横屏`, `竖屏` in UI copy).
- Default is `Auto`.
- Android portrait battles use a phone-friendly layout automatically.
- Portrait mode uses larger cards and touch targets.
- Player bench supports a portrait `2 x 4` grid, ready for future 8-bench effects.
- Prize cards are hidden during normal portrait play and appear only when prize taking is pending.
- Existing landscape battle layout remains unchanged.

## Source Of Truth

Implementation should align these files:

| Area | Source |
|---|---|
| Battle layout state | `scripts/autoload/GameManager.gd` |
| Battle orientation/window shape | `scripts/autoload/GameManager.gd`, `project.godot` |
| Setup entry | `scenes/battle_setup/BattleSetup.tscn`, `scenes/battle_setup/BattleSetup.gd` |
| Runtime layout switching | `scenes/battle/BattleScene.gd` |
| Shared layout math | `scripts/ui/battle/BattleLayoutController.gd` |
| Battle display refresh | `scripts/ui/battle/BattleDisplayController.gd` |
| Prize display/overlay behavior | `scenes/battle/BattleScene.gd`, `scripts/ui/battle/BattleOverlayController.gd` if needed |
| Tests | `tests/test_battle_ui_features.gd` plus focused new tests if cleaner |

Do not make rules-layer changes unless a UI test reveals an existing battle-state bug unrelated to layout.

## Delivery Strategy

Use small, testable steps. Keep landscape behavior stable by preserving the current `_apply_responsive_layout()` body as the landscape implementation before adding portrait logic.

Recommended implementation order:

1. Add tests for mode selection and resolver.
2. Add setup UI and `GameManager` state.
3. Split responsive layout into landscape and portrait routing.
4. Add portrait shell with side panels collapsed.
5. Add portrait-specific card metrics and bench grid.
6. Add prize/log/more drawers.
7. Run regression and manual smoke.

## Phase 0: Baseline And TDD Harness

### Tasks

- Add or extend tests before major UI code changes.
- Capture current landscape expectations so regressions are visible.
- Add helper assertions for layout mode resolution and key node visibility.

### Proposed Tests

Create `tests/test_battle_portrait_layout.gd` if it keeps the suite cleaner.

Minimum test cases:

- `test_layout_resolver_auto_portrait_for_phone_viewport`
- `test_layout_resolver_auto_landscape_for_wide_viewport`
- `test_battle_setup_layout_selector_defaults_to_auto`
- `test_battle_setup_layout_selector_writes_game_manager`
- `test_landscape_layout_keeps_side_panels_visible`
- `test_portrait_layout_collapses_side_panels`
- `test_portrait_metrics_fit_four_bench_columns`
- `test_portrait_hand_cards_are_larger_than_bench_cards`

### Gate

- Existing battle setup and battle UI tests still pass before functional changes.
- New tests fail for the expected missing implementation, not from scene load errors.

## Phase 1: Settings And Mode Resolver

### Files

- `scripts/autoload/GameManager.gd`
- `scripts/ui/battle/BattleLayoutController.gd`
- `scenes/battle_setup/BattleSetup.tscn`
- `scenes/battle_setup/BattleSetup.gd`

### Tasks

- Add constants:
  - `BATTLE_LAYOUT_AUTO := "auto"`
  - `BATTLE_LAYOUT_LANDSCAPE := "landscape"`
  - `BATTLE_LAYOUT_PORTRAIT := "portrait"`
- Add `GameManager.battle_layout_mode := BATTLE_LAYOUT_AUTO`.
- Add `BattleLayoutController.resolve_layout_mode(viewport_size, preferred_mode, is_mobile=false)`.
- Add battle setup selector under `BackgroundGallery`.
- Initialize selector from `GameManager.battle_layout_mode`.
- Persist selected mode into `GameManager` when starting battle.

### UI Placement

Path:

`SafeArea/SetupFrame/FrameMargin/RootVBox/ContentColumns/LeftColumn/LeftMargin/LeftVBox`

Insert after:

`BackgroundGallery`

Add:

- `BattleLayoutLabel`
- `BattleLayoutSegment` with three buttons, or `BattleLayoutOption` if the scene needs less vertical space.

Preferred first version: segmented buttons, matching existing setup controls.

### Gate

- Default selection is `Auto`.
- Switching to `Portrait` reaches `GameManager.battle_layout_mode == "portrait"`.
- Switching to `Landscape` reaches `GameManager.battle_layout_mode == "landscape"`.

## Phase 2: Runtime Layout Routing

### Files

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleLayoutController.gd`

### Tasks

- Rename current `_apply_responsive_layout()` body into `_apply_landscape_layout(viewport_size)`.
- Keep existing landscape code as unchanged as practical.
- Make `_apply_responsive_layout()` only resolve mode and dispatch:
  - portrait -> `_apply_portrait_layout(viewport_size)`
  - landscape -> `_apply_landscape_layout(viewport_size)`
- Add `_is_portrait_battle_layout()` helper for display logic.
- Ensure viewport resize still calls `_apply_responsive_layout()`.

### Portrait Shell First Pass

Implement only shell visibility and broad sizing first:

- Hide/collapse `LeftPanel`.
- Hide/collapse `RightPanel`.
- Hide/collapse `LogPanel`.
- Give `CenterField` full width.
- Keep `TopBar`, `OppField`, `StadiumBar`, `MyField`, and `HandArea` visible.
- Do not change effect dialogs in this phase.

### Gate

- Landscape layout still matches current behavior.
- Portrait mode scene loads and displays central battle field without side panels.
- No pending choice or selected card state is cleared when switching modes.

## Phase 3: Portrait Metrics And 2x4 Bench Grid

### Files

- `scripts/ui/battle/BattleLayoutController.gd`
- `scenes/battle/BattleScene.gd`
- Potentially `scenes/battle/BattleScene.tscn` if adding portrait grid containers is cleaner.

### Tasks

- Add `measure_portrait_card_layout(viewport_size, bench_capacity, card_aspect)`.
- Produce separate sizes:
  - `portrait_active_card_size`
  - `portrait_bench_card_size`
  - `portrait_hand_card_size`
  - `portrait_dialog_card_size`
  - `portrait_detail_card_size`
- Use 4 portrait bench columns.
- Support 2 rows for 8 bench slots.
- Preserve existing slot node instances and callbacks.

### Recommended Metrics

For `390 x 844`:

- Active card height: `150-170`.
- Bench card height: `108-124`.
- Hand card height: `150-180`.
- Main action buttons: minimum `56`, preferably `64`.

Bench formula:

```gdscript
var columns := 4
var usable_width := viewport_size.x - horizontal_padding - float(columns - 1) * gap
var bench_h := minf((usable_width / float(columns)) / CARD_ASPECT, portrait_max_bench_height)
```

### Bench Rehosting Strategy

Use existing bench panel nodes if possible:

- Keep `_my_bench_slots` and `_opp_bench_slots` as node-instance references.
- Rehost nodes into portrait `GridContainer` in original slot order.
- Restore nodes to landscape `HBoxContainer` when switching back.
- Avoid hard-coded parent path assumptions after rehosting.

If rehosting becomes too risky, keep the original `HBoxContainer` for opponent bench in first pass and only implement player `2 x 4`; document the limitation before widening scope.

### Gate

- Player portrait bench lays out as 4 columns.
- Future 8-slot capacity can be represented as 2 rows.
- Hand cards are larger than bench cards.
- Existing field click handlers still work after switching layout.

## Phase 4: Portrait Action Drawers, Prize Overlay, And Log Drawer

### Files

- `scenes/battle/BattleScene.gd`
- `scripts/ui/battle/BattleOverlayController.gd`
- Existing dialog/overlay controllers only if responsive metrics need centralization.

### More Actions Drawer

Portrait top bar should avoid many small buttons.

Keep directly visible:

- Current status text.
- `布局` or `更多`.

Move into `更多` drawer:

- `AI建议`
- `AI探讨`
- `宙斯帮我`
- `攻击特效预览`
- `查看对手手牌`
- `退出游戏`
- Replay controls when replay mode is active

Drawer button minimum height: `64`.

### Prize Overlay

Portrait mode should not show permanent prize cards.

Behavior:

- Hide permanent `LeftPanel`.
- Show only compact prize count if useful.
- When prize taking is pending, open a modal prize-taking overlay.
- Reuse existing prize slot data and selection logic.
- Support multiple prize selection.

### Log Drawer

Behavior:

- Hide permanent `LogPanel`.
- Add `日志` entry in `更多` drawer or center strip.
- Open log in a bottom sheet or side drawer.
- Do not change log generation.

### Gate

- Prize selection is still mandatory when required.
- Prize cards are visible only during prize-taking overlay in portrait.
- Battle log remains accessible in portrait.
- `退出游戏` remains accessible in portrait.

## Phase 5: Regression And Manual Verification

### Automated Tests

Run focused tests:

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_portrait_layout.gd
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_setup_layout.gd
```

If `test_battle_setup_layout.gd` does not exist in the current checkout, add the setup assertions to the closest existing setup UI test instead.

Run broader UI/effect checks when implementation touches overlays:

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_effect_interaction_flow.gd
```

Only run the broad interaction suite after the known runtime issue is understood; if it times out, record that as residual verification risk and use focused overlay tests.

### Manual Smoke

Use both portrait and landscape viewport sizes:

- `390 x 844` portrait.
- `412 x 915` portrait.
- `844 x 390` landscape.
- Desktop default.

Scenarios:

- Opening hand Pokemon selection.
- Normal hand card selection.
- Card detail from field, hand, and discard.
- Nest Ball or Ultra Ball deck search.
- Arven two-step search.
- Raging Bolt ex energy discard selector.
- Prize taking after KO.
- Handover dialog.
- AI discussion.
- Match end review.
- Switch layout mid-game.

## Acceptance Criteria

Functional:

- Battle setup has battle layout selection under map background.
- Default is `Auto`.
- `Auto` uses portrait on phone-shaped portrait viewport.
- `Landscape` preserves existing battle layout.
- `Portrait` can be forced for testing.
- Portrait player bench supports a `2 x 4` layout.
- Portrait hand cards are visibly larger than bench cards.
- Permanent prize card area is hidden in portrait.
- Prize-taking overlay appears when required.
- Battle log and secondary actions remain accessible.

Regression:

- Existing landscape layout remains visually and functionally stable.
- Card effects and AI actions are unchanged.
- No battle-state changes happen when toggling layout.
- No overlay is clipped off-screen on portrait phone viewports.

## Rollback Strategy

Keep the feature easy to disable:

- If portrait layout has a release-blocking bug, keep `GameManager.battle_layout_mode` but hide the setup selector and force resolver to `landscape`.
- Do not remove the landscape path.
- Avoid modifying card effects or engine code, so rollback is limited to UI/layout files.

## Implementation Notes

- Prefer adding layout helpers over embedding more math directly in `BattleScene.gd`.
- Avoid creating a second `BattleScene` unless the single-scene approach becomes unmaintainable.
- Do not reparent nodes during pending animation frames unless necessary.
- Re-apply layout after any drawer/overlay close if viewport changed.
- Keep portrait constants named and centralized so phone tuning is not scattered across files.

## Open Decisions

- Whether the in-battle `布局` switch should be always visible in portrait or live inside `更多`.
- Whether prize count chips should appear in portrait normal view, or whether prize information should also live inside `更多`.
- Whether opponent bench should be forced into a grid in phase 3 or deferred until 8-bench rules ship.
