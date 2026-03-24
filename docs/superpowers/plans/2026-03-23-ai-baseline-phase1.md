# AI Baseline Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable baseline AI that can take over player 2 in `VS_AI`, finish setup, make legal in-turn decisions, and provide a first benchmarkable agent for later `AI vs AI` and deck matrix work.

**Architecture:** Keep AI out of the UI click path. `BattleScene` should only schedule AI turns and provide state access; decision-making should live in `scripts/ai/` with separate units for orchestration, legal action enumeration, interaction-step resolution, setup planning, heuristics, and benchmark execution. Reuse the existing `GameStateMachine` and interaction-step protocol rather than inventing AI-only rules.

**Tech Stack:** Godot 4, GDScript, existing `GameStateMachine` / `EffectProcessor` / `BattleScene`, custom headless test runner in `tests/TestRunner.gd`

---

## Scope Check

The spec covers a large long-term AI roadmap, but this plan intentionally only covers the first executable sub-project:

1. `VS_AI` baseline agent
2. setup automation
3. legal action abstraction
4. interaction-step automation
5. baseline heuristics
6. first benchmark harness

Do not expand this plan to self-play training, MCTS, RL, or full deck-matrix generation. Those should get separate plans after this baseline lands.

## File Map

### Create

- `scripts/ai/AIOpponent.gd`
  Orchestrates one AI-controlled player's turn. Owns scheduling-safe state, asks other AI helpers for choices, and calls existing rules interfaces.

- `scripts/ai/AISetupPlanner.gd`
  Handles setup-only choices: active selection, bench filling, and mulligan bonus-draw choices.

- `scripts/ai/AILegalActionBuilder.gd`
  Enumerates legal high-level actions from the current `GameState`.

- `scripts/ai/AIStepResolver.gd`
  Resolves interaction steps without UI, including `PokemonSlot`, `card_assignment`, deck/discard picks, and chooser-routing fields.

- `scripts/ai/AIHeuristics.gd`
  Scores legal actions and step choices for the baseline agent.

- `scripts/ai/AIBenchmarkRunner.gd`
  Runs fixed baseline matchups for A/B comparison of AI versions.

- `tests/test_ai_baseline.gd`
  Unit and integration-style tests for the AI orchestration, setup, action building, and heuristics.

- `tests/test_ai_benchmark.gd`
  Smoke tests for the benchmark runner and deterministic aggregation.

### Modify

- `scenes/battle/BattleScene.gd`
  Add AI scheduling hooks, UI-busy checks, and the minimal glue that hands control to `AIOpponent` in `VS_AI`.

- `scripts/autoload/GameManager.gd`
  Read-only for the plan unless a tiny helper is needed; do not redesign its mode model.

- `scenes/battle_setup/BattleSetup.gd`
  Read-only for the plan unless a tiny difficulty/default helper is needed; the `VS_AI` selector already exists.

- `tests/TestRunner.gd`
  Register the new AI test suites.

### Reuse Without Changing Unless Needed

- `scripts/engine/GameStateMachine.gd`
- `scripts/engine/EffectProcessor.gd`
- `scripts/engine/RuleValidator.gd`
- `tests/test_battle_ui_features.gd`
- `tests/test_game_state_machine.gd`

Prefer adding AI-specific tests in new files over bloating existing large suites.

## Global Testing Command

Use the existing full-suite runner for all verification steps:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected success shape:

```text
All tests passed!
```

When a step says “run the test to see it fail,” still use the full suite and expect the named AI test to fail in the output.

## Task 1: AI Test Harness And Orchestrator Skeleton

**Files:**
- Create: `scripts/ai/AIOpponent.gd`
- Create: `tests/test_ai_baseline.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write the failing orchestrator tests**

Add a new suite skeleton to `tests/test_ai_baseline.gd` and assert the baseline orchestration API exists.

```gdscript
class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")

func test_ai_opponent_instantiates() -> String:
	var ai := AIOpponentScript.new()
	return run_checks([
		assert_true(ai != null, "AIOpponent should instantiate"),
		assert_true(ai.has_method("configure"), "AIOpponent should expose configure"),
		assert_true(ai.has_method("should_control_turn"), "AIOpponent should expose should_control_turn"),
		assert_true(ai.has_method("run_single_step"), "AIOpponent should expose run_single_step"),
	])
```

- [ ] **Step 2: Register the new suite and run tests to verify failure**

Modify `tests/TestRunner.gd`:

```gdscript
const TestAIBaseline = preload("res://tests/test_ai_baseline.gd")
```

and inside `_ready()`:

```gdscript
_run_test_suite("AIBaseline", TestAIBaseline.new())
```

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: FAIL mentioning `TestAIBaseline.test_ai_opponent_instantiates`

- [ ] **Step 3: Write the minimal orchestrator**

Create `scripts/ai/AIOpponent.gd`:

```gdscript
class_name AIOpponent
extends RefCounted

var player_index: int = 1
var difficulty: int = 1

func configure(next_player_index: int, next_difficulty: int) -> void:
	player_index = next_player_index
	difficulty = next_difficulty

func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
	if game_state == null or ui_blocked:
		return false
	return game_state.current_player_index == player_index

func run_single_step(_battle_scene: Control, _gsm: GameStateMachine) -> bool:
	return false
```

- [ ] **Step 4: Run tests to verify the skeleton passes**

Run the full test suite.

Expected: `AIBaseline` passes; no regressions elsewhere.

- [ ] **Step 5: Commit**

```powershell
git add tests/TestRunner.gd tests/test_ai_baseline.gd scripts/ai/AIOpponent.gd
git commit -m "feat: add AI orchestrator skeleton"
```

## Task 2: BattleScene AI Scheduling And Turn Handoff

**Files:**
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing scheduling tests**

Add tests that verify `BattleScene` only schedules AI in `VS_AI`, only on the AI player’s turn, and never while UI is busy.

```gdscript
func test_battle_scene_only_runs_ai_in_vs_ai_when_unblocked() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	return run_checks([
		assert_true(scene._is_ai_turn_ready(), "AI turn should be schedulable"),
	])
```

- [ ] **Step 2: Run tests to verify failure**

Run the full suite.

Expected: FAIL because `_is_ai_turn_ready()` / setup helpers do not exist yet.

- [ ] **Step 3: Implement minimal scheduling glue in `BattleScene.gd`**

Add focused helpers. Keep the logic thin:

```gdscript
var _ai_opponent: AIOpponent = null
var _ai_running: bool = false

func _ensure_ai_opponent() -> void:
	if _ai_opponent == null:
		_ai_opponent = AIOpponent.new()
		_ai_opponent.configure(1, GameManager.ai_difficulty)

func _is_ui_blocking_ai() -> bool:
	return _dialog_overlay.visible \
		or _handover_panel.visible \
		or _pending_prize_animating \
		or (_field_interaction_overlay != null and _field_interaction_overlay.visible)

func _is_ai_turn_ready() -> bool:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if _gsm == null:
		return false
	_ensure_ai_opponent()
	return _ai_opponent.should_control_turn(_gsm.game_state, _is_ui_blocking_ai())

func _maybe_run_ai() -> void:
	if _ai_running or not _is_ai_turn_ready():
		return
	call_deferred("_run_ai_step")
```

Wire `_maybe_run_ai()` from the places that already refresh state after actions, setup, and turn changes.

- [ ] **Step 4: Run tests to verify pass**

Run the full suite.

Expected: `AIBaseline` scheduling tests pass; current UI tests still pass.

- [ ] **Step 5: Commit**

```powershell
git add scenes/battle/BattleScene.gd tests/test_ai_baseline.gd
git commit -m "feat: schedule AI turns in battle scene"
```

## Task 3: Setup Automation

**Files:**
- Create: `scripts/ai/AISetupPlanner.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing setup tests**

Cover the minimum setup choices:

```gdscript
func test_setup_planner_prefers_basic_active_and_fills_bench() -> String:
	var planner := AISetupPlanner.new()
	var player := PlayerState.new()
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	var choice := planner.plan_opening_setup(player)
	return run_checks([
		assert_eq(choice.active_hand_index, 0, "Should choose a Basic for active"),
		assert_eq(choice.bench_hand_indices.size(), 1, "Should place extra Basic to bench"),
	])
```

Also add one test for mulligan extra-draw choice:

```gdscript
func test_setup_planner_always_accepts_mulligan_bonus_draw() -> String:
	var planner := AISetupPlanner.new()
	return run_checks([
		assert_true(planner.choose_mulligan_bonus_draw(), "Baseline AI should always take the draw"),
	])
```

- [ ] **Step 2: Run tests to verify failure**

Run the full suite.

Expected: FAIL because `AISetupPlanner` does not exist.

- [ ] **Step 3: Implement the setup planner and connect it**

Create `scripts/ai/AISetupPlanner.gd`:

```gdscript
class_name AISetupPlanner
extends RefCounted

func plan_opening_setup(player: PlayerState) -> Dictionary:
	var active_index := -1
	var bench_indices: Array[int] = []
	for i: int in player.hand.size():
		var card: CardInstance = player.hand[i]
		if card.card_data.card_type != "Pokemon":
			continue
		if str(card.card_data.stage) != "Basic":
			continue
		if active_index == -1:
			active_index = i
		elif bench_indices.size() < 5:
			bench_indices.append(i)
	return {
		"active_hand_index": active_index,
		"bench_hand_indices": bench_indices,
	}

func choose_mulligan_bonus_draw() -> bool:
	return true
```

Update `AIOpponent.gd` so `run_single_step()` routes setup-phase prompts through `AISetupPlanner`.

- [ ] **Step 4: Run tests to verify pass**

Run the full suite.

Expected: setup planner tests pass; no setup regressions in existing suites.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/AISetupPlanner.gd scripts/ai/AIOpponent.gd tests/test_ai_baseline.gd
git commit -m "feat: automate AI setup choices"
```

## Task 4: Legal Action Enumeration

**Files:**
- Create: `scripts/ai/AILegalActionBuilder.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing legal-action tests**

Add unit tests that build tiny board states and assert the action builder emits legal actions only.

```gdscript
func test_legal_action_builder_emits_attack_when_attack_is_available() -> String:
	var builder := AILegalActionBuilder.new()
	var gsm := _make_attack_ready_gsm()
	var actions := builder.build_actions(gsm, 1)
	return run_checks([
		assert_true(_has_action(actions, "attack"), "Should emit attack"),
		assert_false(_has_illegal_action(actions), "Should not emit illegal actions"),
	])
```

Add one test each for:

1. `attach_energy`
2. `play_basic_to_bench`
3. `evolve`
4. `play_trainer`
5. `play_stadium`
6. `use_ability`
7. `retreat`
8. `attack`
9. `end_turn`

- [ ] **Step 2: Run tests to verify failure**

Run the full suite.

Expected: FAIL because `AILegalActionBuilder` does not exist.

- [ ] **Step 3: Implement the builder**

Create `scripts/ai/AILegalActionBuilder.gd`:

```gdscript
class_name AILegalActionBuilder
extends RefCounted

func build_actions(gsm: GameStateMachine, player_index: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var state := gsm.game_state
	if state == null or state.current_player_index != player_index:
		return actions
	# Append normalized action dictionaries only when the existing validator / GSM rules allow them.
	actions.append({"kind": "end_turn"})
	return actions
```

Then incrementally fill out action kinds using existing `GameStateMachine` checks rather than duplicating rule logic.

Update `AIOpponent.gd` to ask the builder for choices.

- [ ] **Step 4: Run tests to verify pass**

Run the full suite.

Expected: legal-action unit tests pass; no false-positive actions show up.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/AILegalActionBuilder.gd scripts/ai/AIOpponent.gd tests/test_ai_baseline.gd
git commit -m "feat: add AI legal action builder"
```

## Task 5: Interaction-Step Resolution

**Files:**
- Create: `scripts/ai/AIStepResolver.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing step-resolution tests**

Add one test per supported step family:

```gdscript
func test_step_resolver_handles_single_pokemon_slot_choice() -> String:
	var resolver := AIStepResolver.new()
	var step := {"kind": "PokemonSlot", "items": [_slot_ref(0), _slot_ref(1)], "count": 1}
	var ctx := resolver.resolve_step(step, _make_step_state())
	return run_checks([
		assert_eq(ctx["selected_indices"].size(), 1, "Should select one slot"),
	])
```

Add tests for:

1. `PokemonSlot` single-select
2. `PokemonSlot` multi-select
3. `card_assignment`
4. deck single-pick
5. discard single-pick
6. `opponent_chooses`
7. `chooser_player_index`

Use real card effects already common in the repo where possible:

1. `宝可梦交替`
2. `交替推车`
3. `老大的指令`
4. `电气发生器`
5. `顶尖捕捉器`

- [ ] **Step 2: Run tests to verify failure**

Run the full suite.

Expected: FAIL because `AIStepResolver` does not exist.

- [ ] **Step 3: Implement the minimal resolver**

Create `scripts/ai/AIStepResolver.gd`:

```gdscript
class_name AIStepResolver
extends RefCounted

func resolve_step(step: Dictionary, state: GameState, player_index: int, heuristics: AIHeuristics) -> Dictionary:
	var kind := str(step.get("kind", ""))
	match kind:
		"PokemonSlot":
			return {"selected_indices": [0]}
		"card_assignment":
			return {"assignments": []}
		_:
			return {}
```

Then flesh it out so it returns the same shape the current `BattleScene` / effect pipeline expects. Do not create a second protocol.

- [ ] **Step 4: Run tests to verify pass**

Run the full suite.

Expected: step-resolution tests pass; effect-step smoke tests remain green.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/AIStepResolver.gd scripts/ai/AIOpponent.gd tests/test_ai_baseline.gd
git commit -m "feat: add AI interaction step resolver"
```

## Task 6: Baseline Heuristics And Turn Execution

**Files:**
- Create: `scripts/ai/AIHeuristics.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `tests/test_ai_baseline.gd`
- Modify: `scenes/battle/BattleScene.gd`

- [ ] **Step 1: Write the failing heuristic tests**

Add scoring tests for the baseline preferences.

```gdscript
func test_heuristics_prioritize_knockout_attack() -> String:
	var heuristics := AIHeuristics.new()
	var attack_action := {"kind": "attack", "projected_knockout": true}
	var end_turn_action := {"kind": "end_turn"}
	return run_checks([
		assert_true(
			heuristics.score_action(attack_action, {}) > heuristics.score_action(end_turn_action, {}),
			"Knockout attack should outrank ending turn"
		),
	])
```

Also add tests for:

1. attack > end turn
2. benching Basics > dead actions
3. attach for current/next turn attack > random attach
4. no-op trainer < productive attach / attack

- [ ] **Step 2: Run tests to verify failure**

Run the full suite.

Expected: FAIL because `AIHeuristics` does not exist.

- [ ] **Step 3: Implement heuristics and AI loop**

Create `scripts/ai/AIHeuristics.gd`:

```gdscript
class_name AIHeuristics
extends RefCounted

func score_action(action: Dictionary, context: Dictionary) -> float:
	match str(action.get("kind", "")):
		"attack":
			if action.get("projected_knockout", false):
				return 1000.0
			return 500.0
		"attach_energy":
			return 200.0
		"play_basic_to_bench":
			return 150.0
		"end_turn":
			return 0.0
		_:
			return 10.0
```

Update `AIOpponent.gd` so `run_single_step()`:

1. asks `AILegalActionBuilder` for actions
2. scores them through `AIHeuristics`
3. resolves steps through `AIStepResolver` when needed
4. calls the existing `GameStateMachine` / `BattleScene` hooks
5. returns whether it executed one action

Keep a strict per-turn action cap in `BattleScene.gd`, for example:

```gdscript
const AI_MAX_ACTIONS_PER_TURN := 20
```

- [ ] **Step 4: Run tests to verify pass**

Run the full suite.

Expected: heuristic tests pass; AI can take at least one legal action then stop cleanly.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/AIHeuristics.gd scripts/ai/AIOpponent.gd scenes/battle/BattleScene.gd tests/test_ai_baseline.gd
git commit -m "feat: execute baseline AI turns with heuristics"
```

## Task 7: Smoke Match And Benchmark Harness

**Files:**
- Create: `scripts/ai/AIBenchmarkRunner.gd`
- Create: `tests/test_ai_benchmark.gd`
- Modify: `tests/TestRunner.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing benchmark tests**

Add a new benchmark suite:

```gdscript
class_name TestAIBenchmark
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")

func test_benchmark_runner_aggregates_match_results() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var summary := runner.run_fixed_match_set(_make_fixed_agent(), _make_fixed_matchups())
	return run_checks([
		assert_true(summary.has("total_matches"), "Should report total_matches"),
		assert_true(summary.has("win_rate"), "Should report win_rate"),
	])
```

Also add a smoke test that the baseline AI can finish a full match under an action cap.

- [ ] **Step 2: Register the benchmark suite and run tests to verify failure**

Modify `tests/TestRunner.gd`:

```gdscript
const TestAIBenchmark = preload("res://tests/test_ai_benchmark.gd")
```

and:

```gdscript
_run_test_suite("AIBenchmark", TestAIBenchmark.new())
```

Run the full suite.

Expected: FAIL because `AIBenchmarkRunner` does not exist.

- [ ] **Step 3: Implement the minimal benchmark runner**

Create `scripts/ai/AIBenchmarkRunner.gd`:

```gdscript
class_name AIBenchmarkRunner
extends RefCounted

func run_fixed_match_set(agent: AIOpponent, matchups: Array[Dictionary]) -> Dictionary:
	var wins := 0
	for matchup: Dictionary in matchups:
		var result := _run_one_match(agent, matchup)
		if result.get("winner_index", -1) == matchup.get("tracked_player_index", 1):
			wins += 1
	return {
		"total_matches": matchups.size(),
		"wins": wins,
		"win_rate": 0.0 if matchups.is_empty() else float(wins) / float(matchups.size()),
	}
```

Keep the first implementation simple and deterministic. It only needs to support a fixed benchmark set, not arbitrary tournaments yet.

- [ ] **Step 4: Run tests to verify pass**

Run the full suite.

Expected: benchmark tests pass; smoke match completes without deadlock.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/AIBenchmarkRunner.gd tests/test_ai_benchmark.gd tests/TestRunner.gd tests/test_ai_baseline.gd
git commit -m "feat: add AI benchmark harness"
```

## Task 8: Final Integration Sweep

**Files:**
- Review only: `scripts/ai/*.gd`
- Review only: `scenes/battle/BattleScene.gd`
- Review only: `tests/test_ai_baseline.gd`
- Review only: `tests/test_ai_benchmark.gd`

- [ ] **Step 1: Run the full suite**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: PASS across all suites, including `AIBaseline` and `AIBenchmark`.

- [ ] **Step 2: Manual smoke test in game**

Use the project UI:

1. Open battle setup
2. Choose `AI 对战`
3. Start a match
4. Confirm player 2 is automatically controlled
5. Confirm setup completes
6. Confirm AI can take a turn without hanging the scene

Expected:

1. No handover prompt for AI turns
2. No stuck dialog / field-interaction overlays
3. AI ends its turn or attacks within the action cap

- [ ] **Step 3: Document residual known gaps**

Add a short note to the implementation PR / commit summary:

```text
Baseline AI supports setup, legal action enumeration, common interaction steps, and fixed benchmark runs.
Not included: self-play runner, deck matrix generation, search-based AI, learned policies.
```

- [ ] **Step 4: Commit**

```powershell
git add scripts/ai scenes/battle/BattleScene.gd tests/TestRunner.gd tests/test_ai_baseline.gd tests/test_ai_benchmark.gd
git commit -m "feat: land baseline AI phase 1"
```

## Notes For Execution

1. Keep all AI logic deterministic where possible.
2. Reuse the current interaction-step protocol; do not fork a second AI-only path.
3. Prefer small helper methods over inflating `BattleScene.gd` further.
4. If a required step type is missing, log it and fail fast in tests rather than silently guessing.
5. Do not add “smart” card-specific behavior before the generic legal-action and step layers are stable.

## Local Review Summary

Because this session does not currently include an explicit delegation request, this plan was reviewed locally instead of dispatching a plan-review subagent. The plan intentionally stays within the first sub-project boundary defined by the spec.
