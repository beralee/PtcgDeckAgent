# Battle Portrait Layout Design

## Status

First implementation complete. This document describes the mobile portrait battle layout only. It does not change battle rules, card effects, AI decisions, or action execution semantics.

Implemented first-pass notes:

- Battle setup now exposes `auto / landscape / portrait`.
- Battle scene can switch layout during a match.
- Portrait mode collapses side panels, uses larger hand cards, and rehosts bench slots into a four-column grid.
- Portrait mode hides permanent prize HUDs and shows the selecting player's prize HUD only during prize taking.
- Portrait mode keeps `layout` and `more` in the top bar; secondary actions and battle log are available through a large HUD popup.

May 7 correction:

- Portrait is not a squeezed landscape canvas. Choosing `portrait` must request a real portrait viewport: Android/iOS use `DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT)`, desktop preview swaps the battle window to a tall size.
- Choosing `landscape` requests `SCREEN_SENSOR_LANDSCAPE` on mobile and restores a wide desktop preview window.
- `auto` keeps mobile orientation sensor-enabled and resolves layout from the actual viewport shape.
- If a platform still reports a landscape viewport after the player forces `portrait`, BattleScene falls back to a rotated portrait canvas: it lays out against a swapped logical viewport and rotates the scene root by 90 degrees.

## Goal

Add a battle-scene layout mode that makes Android portrait play practical without removing existing functionality.

The target experience is:

- Players can switch battle layout between `自动`, `横屏`, and `竖屏`.
- Default is `自动`.
- Portrait mode prioritizes large touch targets and readable cards.
- Portrait mode hides always-on side information that consumes width.
- Prize cards are not shown as a permanent side area; they appear only when a player needs to take prizes.
- The layout is ready for a future stadium or effect that increases bench capacity to 8.

## Non Goals

- Do not change rules around prizes, bench capacity, attacks, abilities, trainers, AI, or interaction resolution.
- Do not create a separate battle engine for mobile.
- Do not duplicate card effect UI logic.
- Do not change battle rules or fork the battle scene. Android/iOS orientation may be requested at runtime, but the same `BattleScene` and effect UI must be reused.

## Current Layout Constraints

The current `BattleScene` is a landscape-first layout:

- `TopBar` contains status and many small action buttons.
- `MainArea` is an `HBoxContainer`.
- `LeftPanel` shows prize information.
- `CenterField` contains opponent field, stadium/status row, player field, and hand area.
- `RightPanel` contains deck/discard information and the end-turn button.
- `LogPanel` is always visible on the right.
- `_apply_responsive_layout()` in `scenes/battle/BattleScene.gd` computes most sizes and delegates card measurement to `scripts/ui/battle/BattleLayoutController.gd`.

This works on landscape screens, but on portrait screens the side panels reduce center width too much. Card size and action buttons become too small.

## Layout Mode Model

Add a small layout preference model:

| Value | Meaning |
|---|---|
| `auto` | Default. Use portrait layout when viewport is taller than wide or width is below a phone threshold. Otherwise use existing landscape layout. |
| `landscape` | Force current desktop/landscape layout. |
| `portrait` | Force mobile portrait layout even if the viewport is wider. Useful for testing and foldable devices. |

Recommended storage:

- `GameManager.battle_layout_mode := "auto"`
- Optional persisted user setting if the project already persists battle setup preferences.
- Runtime resolver: `BattleLayoutController.resolve_layout_mode(viewport_size, GameManager.battle_layout_mode)`.

Recommended auto threshold:

- Portrait if `viewport_size.y > viewport_size.x`.
- Also portrait if `viewport_size.x < 720` and `OS.has_feature("mobile")`.
- Keep landscape for desktop-sized windows even if narrow unless the player explicitly chooses portrait.

## Battle Setup Entry

Add the setting to the battle setup screen, in the left column under the map background selector.

Current relevant path:

- `scenes/battle_setup/BattleSetup.tscn`
- `SafeArea/SetupFrame/FrameMargin/RootVBox/ContentColumns/LeftColumn/LeftMargin/LeftVBox`
- Existing map background section: `BackgroundLabel`, `BackgroundGallery`, `BackgroundGalleryRow`

Add directly after `BackgroundGallery`:

- `BattleLayoutLabel`: text `战斗布局`
- `BattleLayoutSegment` or `BattleLayoutOption`
- Options: `自动`, `横屏`, `竖屏`
- Default selected value: `自动`

Implementation preference:

- Use segmented buttons if consistent with existing setup UI.
- Use `OptionButton` only if vertical space is tight.
- Write selected value to `GameManager.battle_layout_mode` when starting the battle.

## In-Battle Switch

Add an in-battle way to switch layout without restarting the match.

Recommended first version:

- Add a `布局` button to the top action area.
- In landscape, it can be visible as a normal top action button.
- In portrait, top actions should be compact, so `布局` can be inside a `更多` HUD drawer.
- Switching updates only layout mode and calls `_apply_responsive_layout()`.
- Current card selection, pending choice, queued animations, and game state must remain untouched.

## Portrait Layout Structure

Portrait mode should keep the mental order of a real battlefield:

1. Top status/action bar.
2. Opponent battlefield.
3. Center status and action strip.
4. Player battlefield.
5. Player hand.

### Top Bar

Portrait top bar should be compact:

- Show current turn/player/phase in one concise line.
- Keep only critical action buttons visible.
- Move secondary actions into a `更多` drawer:
  - `AI建议`
  - `AI探讨`
  - `宙斯帮我`
  - `攻击特效预览`
  - `查看对手手牌`
  - `退出游戏`
  - Replay-only controls when in replay mode

Touch target minimum:

- Buttons: at least `56px` high.
- Drawer buttons: at least `64px` high.

### Opponent Battlefield

Opponent field remains visible above the center status strip.

Recommended portrait behavior:

- Opponent active Pokemon is visually prominent.
- Opponent bench supports up to 8 slots.
- If the opponent has many bench Pokemon, use a compact 2-row grid or horizontal scroll depending on actual available height.
- Opponent deck/discard/prize counts are shown as small HUD chips, not full side panels.

### Center Status And Action Strip

The center strip replaces the current always-wide stadium/status area.

It should include:

- Stadium name and stadium action when available.
- VSTAR state.
- Lost zone counts.
- Main action button: `结束我的回合`.
- Optional compact chips for deck/discard counts.

`结束我的回合` remains large and easy to hit.

### Player Battlefield

Player field is the highest-priority visible area in portrait.

Required design:

- Active Pokemon is separate from bench and can be larger than bench cards.
- Player bench uses a `2 x 4` grid in portrait mode.
- The grid supports a future maximum of 8 bench slots.
- Empty bench slots should not dominate the screen. Show empty slots only when they are legal/meaningful placement targets; otherwise hide or render as subtle placeholders.

Recommended sizing on a common `390 x 844` phone viewport:

- Player active card height: about `150-170px`.
- Player bench card height: about `108-124px`, constrained by 4 columns.
- Player hand card height: about `150-180px`, because hand uses horizontal scroll and is the main touch area.

Formula guidance:

- `portrait_bench_card_height = min(((viewport_width - horizontal_padding - 3 * gap) / 4) / CARD_ASPECT, portrait_max_bench_height)`.
- `portrait_active_card_height` may be larger than bench cards because active has only one slot.
- `portrait_hand_card_height` should be independent from bench grid width and can be larger.

This deliberately uses different sizes for active, bench, and hand. One shared play-card size is too restrictive for portrait.

### Hand Area

Hand area remains at the bottom.

Requirements:

- Horizontal scroll remains available.
- HUD scrollbar must not overlap card bottoms.
- Hand cards can be larger than bench cards.
- The selected-card visual state should remain unchanged.

### Prize Area

Portrait mode must not show the prize card area permanently.

Instead:

- Normal battle view may show only a small prize count chip if needed.
- When prize-taking is required, open a dedicated prize-taking overlay.
- The overlay should reuse existing prize card data and selection behavior.
- The overlay should be modal enough to prevent accidental field actions while prizes are pending.
- The overlay should support taking multiple prizes after multi-prize KOs.

This preserves rules while removing the permanent left-side prize column from portrait.

### Log Area

The battle log should not be a permanent right panel in portrait.

Recommended behavior:

- Hide `LogPanel` during normal portrait play.
- Add a `日志` drawer button.
- Open log as a bottom sheet or side drawer.
- Keep the current log content source unchanged.

## Future 8 Bench Compatibility

The portrait design must not assume `BENCH_SIZE == 5`.

Implementation requirements:

- Use the actual current bench capacity when available.
- If the engine still exposes only fixed arrays, create UI support that can handle 8 slots before the rules feature ships.
- Bench slot UI should be pooled or generated from capacity.
- Field refresh should iterate slot arrays, not hard-coded node paths.
- Portrait player bench columns should be `4`.
- Portrait player bench rows should be `ceil(bench_capacity / 4)`, currently 2 for an 8-slot future.

Landscape can remain 1-row for now, but should not crash if the future capacity is 8. If 8-slot landscape becomes cramped, handle it separately.

## Implementation Architecture

### Preferred Files

- `scripts/autoload/GameManager.gd`: store `battle_layout_mode`.
- `scenes/battle_setup/BattleSetup.tscn`: add setup selector under map background.
- `scenes/battle_setup/BattleSetup.gd`: read/write layout selector.
- `scripts/ui/battle/BattleLayoutController.gd`: resolve layout mode and measure portrait sizes.
- `scenes/battle/BattleScene.gd`: route `_apply_responsive_layout()` to landscape or portrait application.
- `tests/test_battle_ui_features.gd` or a new focused test file: validate layout mode and portrait metrics.

### Recommended Code Shape

Keep the existing landscape path stable:

```gdscript
func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var mode := _battle_layout_controller.resolve_layout_mode(viewport_size, GameManager.battle_layout_mode)
	if mode == "portrait":
		_apply_portrait_layout(viewport_size)
	else:
		_apply_landscape_layout(viewport_size)
```

Move the current body of `_apply_responsive_layout()` into `_apply_landscape_layout()` with minimal changes.

Add a separate `_apply_portrait_layout()` that:

- Collapses `LeftPanel`, `RightPanel`, and `LogPanel`.
- Lets `CenterField` use full width.
- Applies portrait-specific card sizes.
- Applies portrait-specific top action behavior.
- Rebuilds or rehosts bench slots into grid containers.
- Keeps all existing card/action callbacks intact.

### Bench Grid Strategy

The existing bench nodes are `HBoxContainer` children. A 2x4 portrait bench needs a grid.

Two safe implementation options:

1. Add `PortraitMyBenchGrid` and `PortraitOppBenchGrid` containers, then rehost existing bench panel nodes during layout switches.
2. Replace bench hosts with a wrapper component that can switch between `HBoxContainer` and `GridContainer` behavior.

First version recommendation: rehost existing bench panel nodes, because existing slot references and callbacks can remain the same as long as nodes themselves are not recreated.

Requirements for rehosting:

- Preserve node instances.
- Preserve slot arrays such as `_my_bench_slots` and `_opp_bench_slots`.
- Do not rely on old parent paths after rehosting.
- On switching back to landscape, return nodes to the original HBox containers in the original order.

## Overlay And Dialog Interaction

Portrait mode must reuse the existing overlay controllers where possible:

- Card details overlay.
- Effect interaction dialog.
- Prize selection overlay.
- Discard pile overlay.
- Match end screen.
- Handover dialog.

Portrait-specific adjustment should be done through responsive metrics, not separate card-effect UI implementations.

Key rule:

- Any effect that is already using a shared selector should keep using the same selector; only its size and placement changes.

## Test Plan

Add focused tests before or alongside implementation.

Minimum automated coverage:

- `BattleSetup` contains a battle layout selector under the background selector.
- Default selected layout is `auto`.
- Selecting `portrait` writes `GameManager.battle_layout_mode == "portrait"`.
- `BattleLayoutController.resolve_layout_mode(Vector2(390, 844), "auto") == "portrait"`.
- `BattleLayoutController.resolve_layout_mode(Vector2(844, 390), "auto") == "landscape"`.
- Portrait metrics produce a player bench card size that fits 4 columns within viewport width.
- Portrait metrics produce hand cards larger than bench cards.
- Portrait layout collapses left/right/log panels.
- Landscape layout keeps existing side panels visible.
- Switching layout mode calls responsive layout without clearing pending selections.

Manual smoke scenarios:

- Start battle on `390 x 844` portrait viewport.
- Start battle on `844 x 390` landscape viewport.
- Open card detail from hand, field, and discard.
- Use a deck-search card such as Nest Ball or Ultra Ball.
- Use a multi-step supporter such as Arven.
- Use Raging Bolt ex energy discard selection.
- KO opponent and take prizes from the portrait prize overlay.
- Open and close AI discussion.
- Open and close battle log drawer.
- Switch portrait to landscape mid-game and back.

## Rollout Plan

### Phase 1: Settings And Mode Resolver

- Add `GameManager.battle_layout_mode`.
- Add BattleSetup selector under map background.
- Add resolver and tests.

### Phase 2: Portrait Layout Shell

- Split current responsive layout into landscape and portrait functions.
- Collapse side panels in portrait.
- Keep center field full width.
- Add portrait top action drawer skeleton.
- Add tests for panel visibility and mode switching.

### Phase 3: Card Sizing And Bench Grid

- Add portrait-specific active, bench, hand, dialog, and detail card metrics.
- Implement player bench `2 x 4` grid.
- Prepare opponent bench for future 8-slot support.
- Verify card sizes on common Android viewports.

### Phase 4: Prize And Log Drawers

- Hide permanent prize area in portrait.
- Show prize-taking overlay only when prize selection is required.
- Hide permanent log panel in portrait.
- Add log drawer.

### Phase 5: Full Interaction Regression

- Run battle UI tests.
- Run effect interaction flow tests if runtime is acceptable.
- Manually smoke the high-risk interaction dialogs.

## Risks

| Risk | Mitigation |
|---|---|
| Reparenting bench nodes breaks hard-coded paths | Keep references by node instance, not parent path. Add tests for refresh after switching mode. |
| Portrait card sizes still too small on narrow phones | Use separate active, bench, and hand sizes. Do not force one shared card size. |
| Prize taking becomes hard to discover | Show a mandatory modal overlay only when prizes are pending. Add clear title and selected-count status. |
| Top action drawer hides important actions | Keep `结束我的回合` visible in center strip. Keep `布局` and `更多` accessible. |
| Existing landscape layout regresses | Keep current landscape code path mostly unchanged and test `844 x 390` plus desktop dimensions. |
| Future 8-bench rules need more engine support | UI must support 8 slots now, but rules activation remains separate. |

## Acceptance Criteria

- On a portrait phone viewport, player can clearly see active Pokemon, a 2x4 player bench grid, and larger hand cards.
- Permanent prize card area is hidden in portrait.
- Prize-taking opens a dedicated overlay when required.
- Battle setup exposes `战斗布局: 自动 / 横屏 / 竖屏` under map background.
- Default mode is `自动`.
- Existing landscape layout remains visually and functionally unchanged.
- No card effect, AI action, or game-state rule changes are introduced by the layout work.
