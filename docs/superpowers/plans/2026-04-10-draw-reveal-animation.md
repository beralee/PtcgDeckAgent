# Draw Reveal Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add visible deck-to-hand reveal animation for turn-start draw 1 and `Professor's Research` draw 7, with human click-to-continue and AI auto-continue, while keeping rules resolution unchanged.

**Architecture:** Keep draw rules in `GameStateMachine` and add only the minimum draw metadata needed for UI. Implement a dedicated battle-scene draw reveal controller plus a temporary overlay that delays visible hand refresh until the reveal finishes. Reuse `BattleCardView` for temporary face-up cards and integrate reveal blocking into the same battle-scene readiness gates used by other overlays.

**Tech Stack:** Godot 4.6, GDScript, runtime-built battle overlays, focused functional tests in `tests/test_battle_ui_features.gd`

---

## File Structure

- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
  - Add exact drawn-card metadata into `DRAW_CARD` actions for turn-start draw and generic draw paths.
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameAction.gd`
  - Keep action payload conventions documented and compatible with reveal metadata.
- Create: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDrawRevealController.gd`
  - Own reveal queueing, overlay lifecycle, timing, click/auto-continue, and completion callbacks.
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
  - Own controller instance, reveal state flags, overlay references, action-log routing, AI/live-input blocking, and hand-refresh deferral.
- Modify: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDisplayController.gd`
  - Respect reveal-active hand refresh suppression without changing canonical hand rendering.
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - Add functional regression coverage for reveal queueing, blocking, player click wait, and AI auto-continue.
- Optional polish later, not in this plan:
  - `D:/ai/code/ptcgtrain/scenes/battle/BattleCardView.gd`
  - Only if temporary reveal visuals need a tiny helper not achievable from controller code alone.

### Task 1: Draw Action Metadata

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`

- [ ] **Step 1: Write the failing test**

Add targeted tests that prove `DRAW_CARD` actions carry the exact drawn cards:

```gdscript
func test_turn_start_draw_action_includes_drawn_card_names() -> String:
	var gsm := GameStateMachine.new()
	# Build a minimal legal state where _start_turn() draws exactly one known top card.
	# Expect the last DRAW_CARD action to include count=1 and card_names=["Known Top Card"].
	return ""


func test_draw_card_action_includes_all_drawn_cards_for_professors_research_style_draw() -> String:
	var gsm := GameStateMachine.new()
	# Draw 7 from a known deck order through gsm.draw_card(0, 7).
	# Expect action.data.card_names to match the seven drawn cards in order.
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_game_state_machine.gd
```

Expected:
- FAIL because `DRAW_CARD` actions only expose `count` today, not exact drawn card metadata.

- [ ] **Step 3: Write minimal implementation**

Update each `DRAW_CARD` logging site to include drawn-card metadata, for example:

```gdscript
func _draw_action_payload(drawn: Array[CardInstance]) -> Dictionary:
	var names: Array[String] = []
	for card: CardInstance in drawn:
		names.append(card.card_data.name if card != null and card.card_data != null else "")
	return {
		"count": drawn.size(),
		"drawn_cards": drawn.duplicate(),
		"card_names": names,
	}
```

Apply this to:
- `_start_turn()`
- generic `draw_card(player_index, count)`
- mulligan extra draw and any other path already holding the real drawn array before logging

- [ ] **Step 4: Run test to verify it passes**

Run the same focused suite.

Expected:
- PASS on the new tests
- no regressions in existing draw-related tests

- [ ] **Step 5: Commit**

```bash
git add tests/test_game_state_machine.gd scripts/engine/GameStateMachine.gd scripts/engine/GameAction.gd
git commit -m "test: log exact drawn cards for reveal animation"
```

### Task 2: Add Reveal Controller Skeleton and Scene State

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDrawRevealController.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing test**

Add a focused scene test that proves a logged draw action is routed into reveal state instead of immediately exposing the card in hand:

```gdscript
func test_battle_scene_turn_start_draw_starts_reveal_and_defers_hand_refresh() -> String:
	var battle_scene := _make_battle_scene_stub()
	# Seed gsm, hand container, draw reveal controller dependencies, and a DRAW_CARD action with one card.
	# Call _on_action_logged(action).
	# Expect reveal-active state true and pending hand refresh true.
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:
- FAIL because the battle scene currently just logs the action and immediately allows normal hand refresh.

- [ ] **Step 3: Write minimal implementation**

Create `BattleDrawRevealController.gd` with a narrow surface:

```gdscript
class_name BattleDrawRevealController
extends RefCounted

func enqueue_reveal(scene: Object, action: GameAction) -> void:
	# mark reveal active, store payload, build overlay lazily

func is_active(scene: Object) -> bool:
	return bool(scene.get("_draw_reveal_active"))

func flush_if_idle(scene: Object) -> void:
	# no-op skeleton for now
```

Add scene state fields in `BattleScene.gd`:
- `_battle_draw_reveal_controller`
- `_draw_reveal_active`
- `_draw_reveal_waiting_for_confirm`
- `_draw_reveal_pending_hand_refresh`
- `_draw_reveal_overlay`
- `_draw_reveal_queue`

Route relevant `DRAW_CARD` actions in `_on_action_logged()` into the controller.

- [ ] **Step 4: Run test to verify it passes**

Run the same focused UI suite.

Expected:
- the new routing/defer test passes

- [ ] **Step 5: Commit**

```bash
git add scenes/battle/BattleScene.gd scripts/ui/battle/BattleDrawRevealController.gd tests/test_battle_ui_features.gd
git commit -m "feat: scaffold battle draw reveal controller"
```

### Task 3: Turn-Start Draw 1 Animation Flow

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDrawRevealController.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDisplayController.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing test**

Add tests for both human and AI turn-start reveal handling:

```gdscript
func test_battle_scene_turn_start_draw_waits_for_player_click_before_hand_refresh() -> String:
	# enqueue one-card reveal for a human-controlled side
	# expect reveal waits and hand stays visually deferred until confirm
	return ""


func test_battle_scene_turn_start_draw_auto_continues_for_ai_side() -> String:
	# enqueue one-card reveal for an AI-controlled side
	# advance controller timer
	# expect reveal completes without click and hand refresh flushes
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run the focused UI suite again.

Expected:
- FAIL because the controller has no real animation state machine yet.

- [ ] **Step 3: Write minimal implementation**

Implement the single-card reveal path:
- spawn a temporary `BattleCardView`
- set card face-up
- animate deck-origin -> center with scale to about `2x`
- human path sets waiting-for-confirm
- AI path starts an auto-continue timer
- on confirm/auto-continue, animate center -> hand target
- clear reveal state and flush deferred `_refresh_hand()`

Keep actual hand rendering unchanged except for deferral:

```gdscript
func refresh_hand(scene: Object) -> void:
	if bool(scene.get("_draw_reveal_active")):
		scene.set("_draw_reveal_pending_hand_refresh", true)
		return
	# existing hand render path
```

- [ ] **Step 4: Run test to verify it passes**

Run the focused UI suite.

Expected:
- human wait test passes
- AI auto-continue test passes
- existing hand and battle UI tests stay green

- [ ] **Step 5: Commit**

```bash
git add scenes/battle/BattleScene.gd scripts/ui/battle/BattleDisplayController.gd scripts/ui/battle/BattleDrawRevealController.gd tests/test_battle_ui_features.gd
git commit -m "feat: animate turn-start draw reveal"
```

### Task 4: Professor's Research Draw 7 Batch Reveal

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDrawRevealController.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing test**

Add a batch reveal test for `Professor's Research`:

```gdscript
func test_battle_scene_professors_research_reveals_seven_cards_then_waits_once() -> String:
	# use a real Professor's Research card/effect path if practical
	# otherwise inject a DRAW_CARD action with seven known drawn cards
	# expect seven reveal entries are queued, stack remains visible, and only one final confirm is required
	return ""


func test_battle_scene_professors_research_batch_flyin_flushes_hand_after_completion() -> String:
	# after final confirm/auto-continue, expect hand refresh happens once and reveal state fully clears
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run the focused UI suite.

Expected:
- FAIL because only single-card reveal is implemented.

- [ ] **Step 3: Write minimal implementation**

Extend the controller with a batch mode:
- reveal cards sequentially to a centered stack
- store temporary reveal nodes in order
- after the last card lands, enter one shared wait state
- on continue, animate the stack as one grouped exit toward hand
- clear overlay nodes after batch completion

Keep the first implementation simple:
- fixed small stack offsets
- one confirm for the full batch
- one auto-continue timer for AI

- [ ] **Step 4: Run test to verify it passes**

Run the focused UI suite.

Expected:
- new `Professor's Research` tests pass
- single-card draw reveal tests remain green

- [ ] **Step 5: Commit**

```bash
git add scenes/battle/BattleScene.gd scripts/ui/battle/BattleDrawRevealController.gd tests/test_battle_ui_features.gd
git commit -m "feat: add batch reveal for professor draw"
```

### Task 5: Block Live Input and AI Progression During Reveal

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing test**

Add tests that prove reveal-active blocks both player actions and AI continuation:

```gdscript
func test_battle_scene_draw_reveal_blocks_live_actions() -> String:
	# while reveal-active, _can_accept_live_action() should return false
	return ""


func test_battle_scene_draw_reveal_blocks_ai_until_completion() -> String:
	# while reveal-active, _is_ui_blocking_ai() should return true
	return ""
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_battle_ui_features.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_ai_baseline.gd
```

Expected:
- FAIL because reveal state is not yet part of blocking predicates.

- [ ] **Step 3: Write minimal implementation**

Integrate reveal-active into:
- `_can_accept_live_action()`
- `_is_ui_blocking_ai()`
- any queued AI follow-up trigger that should wait until reveal completion

Example:

```gdscript
if bool(_draw_reveal_active):
	return false
```

- [ ] **Step 4: Run test to verify it passes**

Run the same focused suites.

Expected:
- new blocking tests pass
- no regressions in existing AI setup/timing tests

- [ ] **Step 5: Commit**

```bash
git add scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd tests/test_ai_baseline.gd
git commit -m "fix: block actions during draw reveal animation"
```

### Task 6: Final Verification and Cleanup

**Files:**
- Review: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Review: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDrawRevealController.gd`
- Review: `D:/ai/code/ptcgtrain/scripts/ui/battle/BattleDisplayController.gd`
- Review: `D:/ai/code/ptcgtrain/scripts/engine/GameStateMachine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_game_state_machine.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_ai_baseline.gd`
- Test: `D:/ai/code/ptcgtrain/tests/FunctionalTestRunner.gd`

- [ ] **Step 1: Run the focused suites**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_game_state_machine.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_battle_ui_features.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FocusedSuiteRunner.gd' -- --suite-script=res://tests/test_ai_baseline.gd
```

Expected:
- all new reveal tests green

- [ ] **Step 2: Run the full functional suite**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/FunctionalTestRunner.gd'
```

Expected:
- functional suite remains green

- [ ] **Step 3: Final cleanup**

Check:
- no temporary probe scripts
- no unused reveal state fields
- no dead debug logging added only for implementation

- [ ] **Step 4: Commit**

```bash
git add scenes/battle/BattleScene.gd scripts/ui/battle/BattleDrawRevealController.gd scripts/ui/battle/BattleDisplayController.gd scripts/engine/GameStateMachine.gd scripts/engine/GameAction.gd tests/test_battle_ui_features.gd tests/test_game_state_machine.gd tests/test_ai_baseline.gd
git commit -m "feat: add deck-to-hand reveal animation"
```
