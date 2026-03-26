# AI Phase 3 Heuristics Iteration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add decision tracing, richer scoring context, and benchmark-gated heuristic improvements so the shared AI plays Miraidon, Gardevoir, and Charizard ex more rationally without changing the single-agent architecture.

**Architecture:** Build a small observability layer around the existing `AIOpponent -> AILegalActionBuilder -> AIHeuristics -> AIBenchmarkRunner` pipeline before changing behavior. Then refactor scoring to consume structured features, add light deck-specific bias inside the shared heuristic policy, and finish with fixed-seed A/B benchmark regression gates using the Phase 2 runner and result schema.

**Tech Stack:** Godot 4.6, GDScript, existing headless benchmark runner, current `TestRunner.tscn` suite.

---

## File Map

### Create

- `scripts/ai/AIDecisionTrace.gd`
  - Structured trace object for one AI decision step.
- `scripts/ai/AIFeatureExtractor.gd`
  - Extracts reusable scoring context from `GameState` and candidate actions.
- `tests/test_ai_decision_trace.gd`
  - Unit tests for trace storage and serialization shape.
- `tests/test_ai_feature_extractor.gd`
  - Unit tests for extracted scoring features.
- `tests/test_ai_phase3_regression.gd`
  - Focused fixed-seed regression checks for `baseline-v1` vs candidate heuristics.

### Modify

- `scripts/ai/AIOpponent.gd`
  - Capture legal actions, scoring details, and chosen actions; expose last trace.
- `scripts/ai/AIHeuristics.gd`
  - Accept feature-rich scoring context; add new shared-heuristic rules and light deck bias hooks.
- `scripts/ai/AIBenchmarkRunner.gd`
  - Accept agent version tags / trace hooks for A/B comparison.
- `scripts/ai/BenchmarkEvaluator.gd`
  - Add Phase 3 comparison summary fields if needed, while preserving Phase 2 schema compatibility.
- `tests/test_ai_baseline.gd`
  - Add behavior tests for better action choice ordering and “do not early-pass” cases.
- `tests/test_ai_phase2_benchmark.gd`
  - Preserve schema compatibility and regression expectations while adding version comparison coverage.
- `tests/TestRunner.gd`
  - Register any new test files.

### Reference

- `docs/superpowers/specs/2026-03-25-ai-phase3-heuristics-design.md`
- `docs/superpowers/specs/2026-03-25-ai-phase2-benchmark-design.md`
- `docs/superpowers/plans/2026-03-25-ai-phase2-benchmark.md`

## Task 1: Add Decision Trace Infrastructure

**Status:** Completed on 2026-03-26

**Files:**
- Create: `scripts/ai/AIDecisionTrace.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Test: `tests/test_ai_decision_trace.gd`
- Test: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing trace unit tests**

Add tests for:
- a new trace object stores `turn_number`, `player_index`, `legal_actions`, `scored_actions`, `chosen_action`, and `reason_tags`
- `AIOpponent` exposes the last completed trace for a single AI step

Suggested assertions:

```gdscript
func test_ai_decision_trace_stores_structured_fields() -> String:
	var trace := AIDecisionTrace.new()
	trace.turn_number = 3
	trace.player_index = 1
	trace.legal_actions = [{"kind": "attach_energy"}]
	trace.scored_actions = [{"kind": "attach_energy", "score": 240.0}]
	trace.chosen_action = {"kind": "attach_energy"}
	trace.reason_tags = ["active_attach"]
	return run_checks([
		assert_eq(trace.turn_number, 3, "Trace should preserve turn number"),
		assert_eq(trace.reason_tags.size(), 1, "Trace should preserve reason tags"),
	])
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- new tests fail because `AIDecisionTrace` does not exist and `AIOpponent` has no trace API

- [ ] **Step 3: Implement the minimal trace object**

Create `scripts/ai/AIDecisionTrace.gd` with plain fields and helper methods only if tests require them.

Recommended minimal shape:

```gdscript
class_name AIDecisionTrace
extends RefCounted

var turn_number: int = -1
var player_index: int = -1
var legal_actions: Array[Dictionary] = []
var scored_actions: Array[Dictionary] = []
var chosen_action: Dictionary = {}
var reason_tags: Array[String] = []
```

- [ ] **Step 4: Thread trace capture through `AIOpponent`**

Record:
- legal actions produced by `_choose_best_action()`
- each candidate score
- final chosen action

Expose a narrow accessor, for example:

```gdscript
func get_last_decision_trace() -> AIDecisionTrace:
	return _last_decision_trace
```

- [ ] **Step 5: Run the trace tests again**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- new trace tests pass
- no regression in existing AI baseline tests caused by passive trace capture

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AIDecisionTrace.gd scripts/ai/AIOpponent.gd tests/test_ai_decision_trace.gd tests/test_ai_baseline.gd tests/TestRunner.gd
git commit -m "feat: add AI decision tracing"
```

## Task 2: Add Feature Extraction For Scoring

**Status:** Completed on 2026-03-26

**Files:**
- Create: `scripts/ai/AIFeatureExtractor.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `scripts/ai/AIHeuristics.gd`
- Test: `tests/test_ai_feature_extractor.gd`
- Test: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write failing feature extractor tests**

Cover at least:
- active vs bench attach target
- action increases bench development
- action enables immediate attack
- Nest Ball with no remaining Basic targets is not marked productive

Suggested pattern:

```gdscript
func test_feature_extractor_marks_active_attach_and_attack_progress() -> String:
	var features := extractor.build_context(gsm, 1, {"kind": "attach_energy", "target_slot": active})
	return run_checks([
		assert_true(bool(features.get("is_active_target", false)), "Attach feature should mark active targets"),
		assert_true(features.has("improves_attack_readiness"), "Feature set should expose readiness fields"),
	])
```

- [ ] **Step 2: Run tests to verify failure**

Run the full suite once so registration and parser errors surface early.

Expected:
- missing extractor class or missing feature fields

- [ ] **Step 3: Implement `AIFeatureExtractor.gd`**

Add a focused extractor that takes:
- `gsm`
- `player_index`
- `action`

Return a `Dictionary` with stable scalar/boolean features only.

Do not encode deck-specific logic here.

- [ ] **Step 4: Wire `AIOpponent` to use extracted features when scoring**

Refactor scoring call sites so `AIHeuristics.score_action()` receives a context that includes extracted features rather than only raw action dictionaries.

- [ ] **Step 5: Keep legacy behavior green**

Any pre-existing `AIHeuristics` tests that rely on old fields like `is_active_target` should still pass, either by preserving those fields in features or by updating tests to the new contract without changing behavior yet.

- [ ] **Step 6: Run targeted and full tests**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- new extractor tests pass
- no behavior changes yet beyond observability plumbing

- [ ] **Step 7: Commit**

```bash
git add scripts/ai/AIFeatureExtractor.gd scripts/ai/AIOpponent.gd scripts/ai/AIHeuristics.gd tests/test_ai_feature_extractor.gd tests/test_ai_baseline.gd tests/TestRunner.gd
git commit -m "feat: add AI scoring feature extraction"
```

## Task 3: Strengthen Shared Heuristic Scoring

**Files:**
- Modify: `scripts/ai/AIHeuristics.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Test: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write failing behavior tests for bad baseline choices**

Add small, deterministic tests for:
- do not end the turn when a productive Nest Ball line is still legal
- prefer bench development over low-value dead trainer actions
- prefer evolution support when it directly advances a key Stage 2 line
- prefer attack setup over purely cosmetic actions

Suggested example:

```gdscript
func test_ai_prefers_nest_ball_followup_over_ending_turn_when_basic_target_exists() -> String:
	# Build a Charizard state with Fire Energy + Nest Ball + remaining Basic in deck.
	# Assert that the second AI step starts trainer interaction instead of ending turn.
```

- [ ] **Step 2: Run tests to confirm failure**

Expected:
- baseline heuristic chooses the lower-quality action in at least one case

- [ ] **Step 3: Implement minimal scoring improvements**

Add rules for:
- productive bench development
- direct evolution progression
- immediate or next-turn attack readiness
- de-prioritizing legal-but-empty trainer lines

Keep all rules inside the shared heuristic policy.

- [ ] **Step 4: Record reason tags in the trace**

When a rule contributes to a score bump, add stable tags such as:
- `bench_development`
- `stage2_progress`
- `attack_readiness`
- `dead_trainer_penalty`

Do not log free-form prose in scoring logic.

- [ ] **Step 5: Run tests**

Run the full suite and inspect new AI behavior tests first.

Expected:
- new behavior tests pass
- existing AI baseline tests stay green

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AIHeuristics.gd scripts/ai/AIOpponent.gd tests/test_ai_baseline.gd
git commit -m "feat: improve shared AI heuristic scoring"
```

## Task 4: Add Light Deck Bias Inside Shared Policy

**Files:**
- Modify: `scripts/ai/AIHeuristics.gd`
- Modify: `scripts/ai/AIFeatureExtractor.gd`
- Test: `tests/test_ai_baseline.gd`
- Test: `tests/test_deck_identity_tracker.gd`

- [ ] **Step 1: Write failing tests for pinned deck identity preferences**

Cover one narrow preference per deck:
- Miraidon: productive `Electric Generator` and Basic Electric benching
- Gardevoir: evolution progress and `Psychic Embrace`
- Charizard: Rare Candy / evolution support / Stage 2 readiness

Use minimal state fixtures, not full games.

- [ ] **Step 2: Run tests and verify failure**

Expected:
- current shared heuristics do not distinguish these deck-specific priorities enough

- [ ] **Step 3: Implement light deck bias**

Use deck keys or stable deck-family signals already present in Phase 2 benchmarking.  
Examples:
- `miraidon`
- `gardevoir`
- `charizard_ex`

Rules must stay as small score adjustments layered on the same shared scoring function.

- [ ] **Step 4: Re-run behavior and identity-adjacent tests**

Expected:
- tests pass
- no need to modify `DeckIdentityTracker` behavior itself unless a test fixture needs updating

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/AIHeuristics.gd scripts/ai/AIFeatureExtractor.gd tests/test_ai_baseline.gd tests/test_deck_identity_tracker.gd
git commit -m "feat: add light deck bias to shared AI policy"
```

## Task 5: Extend Benchmark Runner For Versioned A/B Comparison

**Files:**
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `scripts/ai/BenchmarkEvaluator.gd`
- Modify: `scripts/ai/DeckBenchmarkCase.gd`
- Test: `tests/test_ai_phase2_benchmark.gd`
- Test: `tests/test_benchmark_evaluator.gd`

- [ ] **Step 1: Write failing tests for version comparison support**

Cover:
- `agent_id + version_tag` still flow through benchmark cases
- raw match results preserve version metadata
- pairing summaries can compare `baseline-v1` vs `candidate-v*`

- [ ] **Step 2: Run tests and verify failure**

Expected:
- either missing fields in raw result schema or no evaluator support for version summaries

- [ ] **Step 3: Implement version metadata plumbing**

Preserve Phase 2 field names and JSON schema compatibility.  
Add new fields only where the spec requires them.

- [ ] **Step 4: Keep summary output human-readable**

Ensure text summaries clearly show:
- pairing
- version A vs version B
- total matches
- win rate
- stall / cap rates
- relevant identity deltas

- [ ] **Step 5: Run benchmark-related tests**

Run the full suite so schema regressions surface.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AIBenchmarkRunner.gd scripts/ai/BenchmarkEvaluator.gd scripts/ai/DeckBenchmarkCase.gd tests/test_ai_phase2_benchmark.gd tests/test_benchmark_evaluator.gd
git commit -m "feat: support versioned AI benchmark comparison"
```

## Task 6: Add Phase 3 Regression Gates

**Files:**
- Create: `tests/test_ai_phase3_regression.gd`
- Modify: `tests/TestRunner.gd`
- Modify: `scripts/ai/BenchmarkEvaluator.gd`

- [ ] **Step 1: Write failing regression tests**

Use fixed seeds and narrow expectations:
- candidate heuristic must not increase stall rate
- candidate heuristic must not increase cap termination rate
- at least one target pairing must improve or stay equal on win rate
- critical identity events must not collapse

Do not hardcode exact large win-rate percentages; compare relative benchmark outputs.

- [ ] **Step 2: Run tests to verify failure**

Expected:
- no Phase 3 regression helper exists yet

- [ ] **Step 3: Implement the minimal regression gate helpers**

Add helper logic in evaluation code or tests that:
- compare two benchmark summaries
- return pass/fail with readable reasons

- [ ] **Step 4: Run the full test suite**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- new regression tests pass
- no schema regressions in Phase 2 benchmark tests

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/BenchmarkEvaluator.gd tests/test_ai_phase3_regression.gd tests/TestRunner.gd
git commit -m "test: add Phase 3 AI regression gates"
```

## Task 7: Manual Smoke And Benchmark Review

**Files:**
- Modify: none unless bugs are found
- Test: benchmark and manual smoke outputs

- [ ] **Step 1: Run the full automated suite**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected:
- entire suite passes except for any documented unrelated pre-existing failures, which must be explicitly noted

- [ ] **Step 2: Run focused AI benchmark checks**

Use the existing benchmark runner entry points created in Phase 2.  
Capture:
- `baseline-v1`
- candidate heuristic version
- fixed seed summaries for the three pinned pairings

Expected:
- readable JSON and text summaries
- no stalled or unsupported-prompt spikes

- [ ] **Step 3: Manual `VS_AI` smoke**

Play at least one short game for each pinned deck family:
- Miraidon
- Gardevoir
- Charizard ex

Look for:
- obvious “attach and pass” regressions
- broken interaction ownership
- bad early-turn expansion misses

- [ ] **Step 4: If smoke finds issues, write targeted failing tests before any fix**

Do not patch directly from observation.  
Follow TDD for each issue.

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "feat: complete Phase 3 heuristic iteration"
```

## Execution Notes

- Keep the shared-agent architecture intact.
- Do not add search, rollouts, or learning systems in this phase.
- Prefer additive feature extraction and scoring over invasive rewrites.
- Preserve Phase 2 benchmark schema compatibility unless the spec explicitly allows additive fields.
- Every behavioral fix must start with a failing test.

## Suggested Commit Sequence

1. `feat: add AI decision tracing`
2. `feat: add AI scoring feature extraction`
3. `feat: improve shared AI heuristic scoring`
4. `feat: add light deck bias to shared AI policy`
5. `feat: support versioned AI benchmark comparison`
6. `test: add Phase 3 AI regression gates`
7. `feat: complete Phase 3 heuristic iteration`
