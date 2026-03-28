# AI 训练闭环与可体验版本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a versioned AI training/publishing flow so benchmark-approved training outputs can be selected and experienced directly in `VS_AI`.

**Architecture:** Add a small version registry layer on top of existing `agent` and `value_net` files, thread AI selection through `GameManager`, expose version picking in `BattleSetup`, and make `BattleScene` assemble the correct AI instance at runtime. Extend the headless training flow with benchmark gating and registry publication instead of treating raw files as directly playable.

**Tech Stack:** Godot 4.6 / GDScript, existing headless AI benchmark infrastructure, shell automation in `scripts/training/train_loop.sh`, project test runner `res://tests/TestRunner.tscn`

**Spec:** `docs/superpowers/specs/2026-03-28-ai-training-versioning-design.md`

**Test command:** `& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn'`

---

## File Map

### Create

| File | Responsibility |
|------|----------------|
| `scripts/ai/AIVersionRegistry.gd` | Persist AI version records, list playable versions, resolve latest playable version |
| `scripts/ai/TrainingRunRegistry.gd` | Persist training run metadata and map runs to output directories / published versions |
| `scenes/tuner/BenchmarkRunner.gd` | Headless fixed-benchmark entry point for challenger vs current-best |
| `scenes/tuner/BenchmarkRunner.tscn` | Scene wrapper for benchmark runner |
| `tests/test_ai_version_registry.gd` | Unit tests for version registry behavior |
| `tests/test_training_run_registry.gd` | Unit tests for training run metadata behavior |
| `tests/test_battle_setup_ai_versions.gd` | Scene-level tests for AI source/version selector UI |

### Modify

| File | Change |
|------|--------|
| `scripts/autoload/GameManager.gd` | Add persisted `ai_selection` state and helper methods |
| `scenes/battle_setup/BattleSetup.gd` | Populate AI source/version UI, write selected version into `GameManager` |
| `scenes/battle_setup/BattleSetup.tscn` | Add AI source/version widgets and labels |
| `scenes/battle/BattleScene.gd` | Resolve selected AI version, configure `AIOpponent`, show loaded version in logs/UI, add fallback behavior |
| `scripts/training/train_loop.sh` | Create run directories, call benchmark runner, publish only benchmark-approved versions |
| `tests/TestRunner.gd` | Register new test suites |
| `tests/test_ai_baseline.gd` | Add focused BattleScene AI-version integration assertions |
| `tests/test_battle_ui_features.gd` | Add focused BattleSetup UI assertions for new controls |

### Existing References

- `scripts/ai/AgentVersionStore.gd` — current low-level agent config persistence
- `scripts/ai/AIBenchmarkRunner.gd` — reusable fixed benchmark execution
- `scripts/ai/AIOpponent.gd` — runtime AI assembly point
- `scripts/autoload/GameManager.gd` — cross-scene game setup state
- `scenes/battle_setup/BattleSetup.gd` / `.tscn` — existing pre-battle configuration screen
- `scenes/battle/BattleScene.gd` — current `VS_AI` assembly path

---

### Task 1: Add AI Version Registry

**Files:**
- Create: `scripts/ai/AIVersionRegistry.gd`
- Create: `tests/test_ai_version_registry.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_ai_version_registry.gd`:

```gdscript
class_name TestAIVersionRegistry
extends TestBase

const RegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")


func _cleanup() -> void:
	var dir_path := ProjectSettings.globalize_path("user://ai_versions_test")
	if DirAccess.dir_exists_absolute(dir_path):
		DirAccess.remove_absolute(dir_path.path_join("index.json"))
		DirAccess.remove_absolute(dir_path)


func test_save_and_load_version_roundtrip() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	var record := {
		"version_id": "AI-20260328-01",
		"display_name": "v015 + value1",
		"status": "playable",
		"agent_config_path": "user://ai_agents/agent_v015.json",
		"value_net_path": "user://ai_models/value_net_v1.json",
		"benchmark_summary": {"win_rate_vs_current_best": 0.57}
	}
	var ok: bool = registry.save_version(record)
	var loaded: Dictionary = registry.get_version("AI-20260328-01")
	_cleanup()
	return run_checks([
		assert_true(ok, "save_version 应成功"),
		assert_eq(loaded.get("display_name", ""), "v015 + value1", "应保留 display_name"),
		assert_eq(loaded.get("status", ""), "playable", "应保留 status"),
	])


func test_list_playable_versions_filters_trainable() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	registry.save_version({"version_id": "AI-1", "display_name": "one", "status": "trainable"})
	registry.save_version({"version_id": "AI-2", "display_name": "two", "status": "playable"})
	var versions: Array[Dictionary] = registry.list_playable_versions()
	_cleanup()
	return run_checks([
		assert_eq(versions.size(), 1, "只应返回 playable 版本"),
		assert_eq(versions[0].get("version_id", ""), "AI-2", "应返回 playable 版本"),
	])


func test_get_latest_playable_version_ignores_non_playable() -> String:
	_cleanup()
	var registry := RegistryScript.new()
	registry.base_dir = "user://ai_versions_test"
	registry.save_version({"version_id": "AI-1", "display_name": "one", "status": "playable", "created_at": "2026-03-28T10:00:00"})
	registry.save_version({"version_id": "AI-2", "display_name": "two", "status": "trainable", "created_at": "2026-03-28T11:00:00"})
	registry.save_version({"version_id": "AI-3", "display_name": "three", "status": "playable", "created_at": "2026-03-28T12:00:00"})
	var latest: Dictionary = registry.get_latest_playable_version()
	_cleanup()
	return run_checks([
		assert_eq(latest.get("version_id", ""), "AI-3", "latest playable 应忽略 trainable 记录"),
	])
```

- [ ] **Step 2: Register the test**

Add to `tests/TestRunner.gd`:

```gdscript
const TestAIVersionRegistry = preload("res://tests/test_ai_version_registry.gd")
```

and:

```gdscript
_run_test_suite("AIVersionRegistry", TestAIVersionRegistry.new())
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: `AIVersionRegistry` compile/load failure because the script does not exist yet.

- [ ] **Step 4: Implement the registry**

Create `scripts/ai/AIVersionRegistry.gd` with an index-backed API:

```gdscript
class_name AIVersionRegistry
extends RefCounted

var base_dir: String = "user://ai_versions"
const INDEX_FILE := "index.json"


func save_version(record: Dictionary) -> bool:
	var index := _load_index()
	index[str(record.get("version_id", ""))] = record.duplicate(true)
	return _save_index(index)


func get_version(version_id: String) -> Dictionary:
	return (_load_index().get(version_id, {}) as Dictionary).duplicate(true)


func list_playable_versions() -> Array[Dictionary]:
	var versions: Array[Dictionary] = []
	for value: Variant in _load_index().values():
		if value is Dictionary and str((value as Dictionary).get("status", "")) == "playable":
			versions.append((value as Dictionary).duplicate(true))
	versions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("created_at", "")) < str(b.get("created_at", ""))
	)
	return versions


func get_latest_playable_version() -> Dictionary:
	var versions := list_playable_versions()
	return {} if versions.is_empty() else versions.back().duplicate(true)
```

Implement `_load_index()`, `_save_index()`, `_ensure_dir_exists()` in the same file. Keep the format as a single JSON object keyed by `version_id`.

- [ ] **Step 5: Run tests and verify they pass**

Run the full test runner again.

Expected: `AIVersionRegistry` tests pass; no unrelated regressions.

- [ ] **Step 6: Commit**

```powershell
git add tests/TestRunner.gd tests/test_ai_version_registry.gd scripts/ai/AIVersionRegistry.gd
git commit -m "feat: add AI version registry for playable training builds"
```

---

### Task 2: Add Training Run Registry

**Files:**
- Create: `scripts/ai/TrainingRunRegistry.gd`
- Create: `tests/test_training_run_registry.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_training_run_registry.gd`:

```gdscript
class_name TestTrainingRunRegistry
extends TestBase

const RegistryScript = preload("res://scripts/ai/TrainingRunRegistry.gd")


func test_start_run_creates_metadata_with_run_id() -> String:
	var registry := RegistryScript.new()
	registry.base_dir = "user://training_runs_test"
	var run: Dictionary = registry.start_run("fixed_three_deck_training")
	return run_checks([
		assert_true(str(run.get("run_id", "")).begins_with("run_"), "run_id 应自动生成"),
		assert_eq(run.get("status", ""), "running", "新 run 应为 running"),
	])


func test_mark_run_completed_persists_published_version() -> String:
	var registry := RegistryScript.new()
	registry.base_dir = "user://training_runs_test"
	var run: Dictionary = registry.start_run("fixed_three_deck_training")
	var completed := registry.complete_run(str(run.get("run_id", "")), {
		"published_version_id": "AI-20260328-01",
		"status": "published",
	})
	return run_checks([
		assert_eq(completed.get("published_version_id", ""), "AI-20260328-01", "应记录发布版本号"),
		assert_eq(completed.get("status", ""), "published", "应更新为 published"),
	])
```

- [ ] **Step 2: Register the test**

Add to `tests/TestRunner.gd`:

```gdscript
const TestTrainingRunRegistry = preload("res://tests/test_training_run_registry.gd")
_run_test_suite("TrainingRunRegistry", TestTrainingRunRegistry.new())
```

- [ ] **Step 3: Run test to verify it fails**

Run the headless test runner.

Expected: `TrainingRunRegistry` missing.

- [ ] **Step 4: Implement the registry**

Create `scripts/ai/TrainingRunRegistry.gd`:

```gdscript
class_name TrainingRunRegistry
extends RefCounted

var base_dir: String = "user://training_runs"


func start_run(pipeline_name: String) -> Dictionary:
	var run_id := "run_%s" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var record := {
		"run_id": run_id,
		"pipeline_name": pipeline_name,
		"status": "running",
		"created_at": Time.get_datetime_string_from_system(),
	}
	_save_run_record(run_id, record)
	return record


func complete_run(run_id: String, patch: Dictionary) -> Dictionary:
	var record := get_run(run_id)
	for key: Variant in patch.keys():
		record[key] = patch[key]
	record["completed_at"] = Time.get_datetime_string_from_system()
	_save_run_record(run_id, record)
	return record
```

Implement `get_run()` and `_save_run_record()` in the same file, with one JSON file per run under `user://training_runs/<run_id>/run.json`.

- [ ] **Step 5: Run tests and verify they pass**

Run the headless test runner again.

- [ ] **Step 6: Commit**

```powershell
git add tests/TestRunner.gd tests/test_training_run_registry.gd scripts/ai/TrainingRunRegistry.gd
git commit -m "feat: add training run registry for AI publishing flow"
```

---

### Task 3: Thread AI Selection Through GameManager

**Files:**
- Modify: `scripts/autoload/GameManager.gd`
- Modify: `tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write the failing test**

Add focused assertions to `tests/test_battle_ui_features.gd`:

```gdscript
func test_game_manager_ai_selection_defaults_to_default_source() -> String:
	return run_checks([
		assert_eq(str(GameManager.ai_selection.get("source", "")), "default", "默认 AI 来源应为 default"),
		assert_eq(str(GameManager.ai_selection.get("version_id", "")), "", "默认不应绑定版本号"),
	])
```

- [ ] **Step 2: Run the test to verify it fails**

Run the headless test runner.

Expected: property lookup failure because `GameManager.ai_selection` does not exist.

- [ ] **Step 3: Implement the minimal state**

Add to `scripts/autoload/GameManager.gd`:

```gdscript
var ai_selection := {
	"source": "default",
	"version_id": "",
	"agent_config_path": "",
	"value_net_path": "",
	"display_name": "",
}


func reset_ai_selection() -> void:
	ai_selection = {
		"source": "default",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"display_name": "",
	}
```

Do not remove `ai_difficulty` yet; keep it as fallback for the default built-in AI path.

- [ ] **Step 4: Run tests and verify they pass**

Run the headless test runner again.

- [ ] **Step 5: Commit**

```powershell
git add scripts/autoload/GameManager.gd tests/test_battle_ui_features.gd
git commit -m "feat: add global AI selection state for versioned VS_AI"
```

---

### Task 4: Add AI Source and Version Picker to Battle Setup

**Files:**
- Modify: `scenes/battle_setup/BattleSetup.tscn`
- Modify: `scenes/battle_setup/BattleSetup.gd`
- Create: `tests/test_battle_setup_ai_versions.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_battle_setup_ai_versions.gd`:

```gdscript
class_name TestBattleSetupAIVersions
extends TestBase


func test_battle_setup_scene_includes_ai_source_option() -> String:
	var scene := load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	var ai_source := scene.get_node_or_null("%AISourceOption")
	return run_checks([
		assert_true(ai_source != null, "BattleSetup 应包含 AISourceOption"),
	])


func test_battle_setup_scene_includes_ai_version_option() -> String:
	var scene := load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	var ai_version := scene.get_node_or_null("%AIVersionOption")
	return run_checks([
		assert_true(ai_version != null, "BattleSetup 应包含 AIVersionOption"),
	])
```

- [ ] **Step 2: Register the test**

Add to `tests/TestRunner.gd`:

```gdscript
const TestBattleSetupAIVersions = preload("res://tests/test_battle_setup_ai_versions.gd")
_run_test_suite("BattleSetupAIVersions", TestBattleSetupAIVersions.new())
```

- [ ] **Step 3: Run test to verify it fails**

Run the headless test runner.

Expected: scene lookup failure because the new nodes do not exist.

- [ ] **Step 4: Add the UI controls**

Modify `scenes/battle_setup/BattleSetup.tscn` to insert after `ModeOption`:

```tscn
[node name="AISourceLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "AI 来源:"

[node name="AISourceOption" type="OptionButton" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(300, 35)

[node name="AIVersionLabel" type="Label" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "AI 版本:"

[node name="AIVersionOption" type="OptionButton" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(300, 35)
```

- [ ] **Step 5: Wire the logic in `BattleSetup.gd`**

Add:

```gdscript
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
var _ai_version_registry := AIVersionRegistryScript.new()
var _playable_ai_versions: Array[Dictionary] = []
```

Implement:

```gdscript
func _setup_ai_source_options() -> void:
	%AISourceOption.clear()
	%AISourceOption.add_item("默认 AI", 0)
	%AISourceOption.add_item("最新训练版 AI", 1)
	%AISourceOption.add_item("指定训练版本 AI", 2)
	%AISourceOption.item_selected.connect(_on_ai_source_changed)


func _refresh_ai_version_options() -> void:
	_playable_ai_versions = _ai_version_registry.list_playable_versions()
	%AIVersionOption.clear()
	for version: Dictionary in _playable_ai_versions:
		%AIVersionOption.add_item("%s | %s" % [version.get("version_id", ""), version.get("display_name", "")])
```

Update `_ready()` to call `_setup_ai_source_options()` and `_refresh_ai_version_options()`.

Expose a tiny injection hook for tests:

```gdscript
func set_ai_version_registry_for_test(registry: RefCounted) -> void:
	_ai_version_registry = registry
```

Update `_apply_setup_selection()` to write `GameManager.ai_selection`.

- [ ] **Step 6: Run tests and verify they pass**

Run the headless test runner.

- [ ] **Step 7: Commit**

```powershell
git add scenes/battle_setup/BattleSetup.tscn scenes/battle_setup/BattleSetup.gd tests/TestRunner.gd tests/test_battle_setup_ai_versions.gd
git commit -m "feat: add AI source and version picker to battle setup"
```

---

### Task 5: Load Selected AI Version in Battle Scene

**Files:**
- Modify: `scenes/battle/BattleScene.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write the failing test**

Add focused assertions to `tests/test_ai_baseline.gd`:

```gdscript
func test_battle_scene_uses_default_ai_selection_when_no_version_is_set() -> String:
	GameManager.reset_ai_selection()
	var scene := load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.call("_ensure_ai_opponent")
	var ai = scene.get("_ai_opponent")
	return run_checks([
		assert_true(ai != null, "BattleScene 应创建默认 AI"),
		assert_eq(str(GameManager.ai_selection.get("source", "")), "default", "默认来源应保留为 default"),
	])
```

Then add a second test for version-backed assembly using a fake version record written into `user://ai_versions_test` and a temporary `GameManager.ai_selection`.

- [ ] **Step 2: Run the test to verify it fails**

Run the headless test runner.

Expected: test fails once it tries to exercise selection-aware behavior that does not exist yet.

- [ ] **Step 3: Refactor `_ensure_ai_opponent()`**

In `scenes/battle/BattleScene.gd`, replace the hard-coded setup:

```gdscript
_ai_opponent.configure(1, GameManager.ai_difficulty)
_ai_opponent.use_mcts = true
_ai_opponent.mcts_config = { ... }
```

with a helper split:

```gdscript
func _build_default_ai_opponent() -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(1, GameManager.ai_difficulty)
	ai.use_mcts = true
	ai.mcts_config = {
		"branch_factor": 2,
		"rollouts_per_sequence": 6,
		"rollout_max_steps": 50,
		"time_budget_ms": 1200,
	}
	return ai


func _build_selected_ai_opponent() -> AIOpponent:
	var selection: Dictionary = GameManager.ai_selection
	if str(selection.get("source", "default")) == "default":
		return _build_default_ai_opponent()
```

Add a versioned branch that:

1. Resolves latest playable if `source == "latest_trained"`
2. Resolves explicit record if `source == "specific_version"`
3. Applies `heuristic_weights`, `mcts_config`, and `value_net_path` from the selected agent config
4. Falls back to default AI if the version cannot be resolved or files are missing

Add an injectable registry field so the tests can point `BattleScene` at a disposable version index:

```gdscript
const AIVersionRegistryScript = preload("res://scripts/ai/AIVersionRegistry.gd")
var _ai_version_registry: RefCounted = AIVersionRegistryScript.new()
```

- [ ] **Step 4: Add version display**

In `BattleScene.gd`, add a small helper that writes a runtime log entry after AI assembly:

```gdscript
_runtime_log("ai_loaded", "source=%s version=%s display=%s" % [source, version_id, display_name])
```

Optionally surface the display name in an existing label if the UI has room; do not add a new HUD block in this task.

- [ ] **Step 5: Run tests and verify they pass**

Run the headless test runner again.

- [ ] **Step 6: Commit**

```powershell
git add scenes/battle/BattleScene.gd tests/test_ai_baseline.gd
git commit -m "feat: load selected training AI version in battle scene"
```

---

### Task 6: Add Headless Benchmark Publication Flow

**Files:**
- Create: `scenes/tuner/BenchmarkRunner.gd`
- Create: `scenes/tuner/BenchmarkRunner.tscn`
- Modify: `scripts/training/train_loop.sh`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `scripts/ai/AIVersionRegistry.gd`
- Modify: `scripts/ai/TrainingRunRegistry.gd`

- [ ] **Step 1: Write the failing smoke-check**

Document a manual command that will fail before implementation:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://scenes/tuner/BenchmarkRunner.tscn' -- --agent-a-config=user://a.json --agent-b-config=user://b.json
```

Expected: scene does not exist yet.

- [ ] **Step 2: Create the benchmark runner**

Create `scenes/tuner/BenchmarkRunner.gd` that:

1. Reads CLI args for:
   - `--agent-a-config=...`
   - `--agent-b-config=...`
   - `--value-net-a=...`
   - `--value-net-b=...`
   - `--summary-output=...`
2. Builds three fixed benchmark cases for:
   - `密勒顿 vs 沙奈朵`
   - `密勒顿 vs 喷火龙ex`
   - `沙奈朵 vs 喷火龙ex`
3. Uses `AIBenchmarkRunner.run_and_summarize_case()` to produce summaries
4. Writes a summary JSON containing total win rate, timeouts, failures, and per-pairing results
5. Exits non-zero when the benchmark gate is not met

Minimal skeleton:

```gdscript
extends Control

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckBenchmarkCaseScript = preload("res://scripts/ai/DeckBenchmarkCase.gd")


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var summary := _run_fixed_three_deck_benchmark(args)
	_write_summary(args.get("summary_output", "user://benchmark_summary.json"), summary)
	get_tree().quit(0 if bool(summary.get("gate_passed", false)) else 1)
```

- [ ] **Step 3: Extend `train_loop.sh`**

Modify `scripts/training/train_loop.sh` to:

1. Start a training run with a unique `run_id`
2. Write outputs under a run-scoped directory
3. After each trained model, call `BenchmarkRunner.tscn`
4. Only publish a playable AI version if benchmark exits `0`
5. Save:
   - run metadata
   - benchmark summary
   - published version record

The shell flow should look like:

```bash
RUN_ID="run_$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$DATA_DIR/$RUN_ID"
SUMMARY_FILE="$RUN_DIR/benchmark/summary.json"

"$GODOT" --headless --path "$PROJECT_DIR" res://scenes/tuner/BenchmarkRunner.tscn -- \
  --agent-a-config="$BEST_AGENT" \
  --agent-b-config="$CURRENT_AGENT" \
  --value-net-a="$WEIGHTS_FILE" \
  --summary-output="$SUMMARY_FILE"
```

If the benchmark command returns non-zero, keep the run as trainable only and skip publication.

- [ ] **Step 4: Publish playable versions through the registry**

Add a helper to `AIVersionRegistry.gd`:

```gdscript
func publish_playable_version(record: Dictionary) -> bool:
	record["status"] = "playable"
	return save_version(record)
```

Use the same record format from the spec; `version_id` should be user-facing, for example `AI-20260328-01`.

- [ ] **Step 5: Run validation commands**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn'
```

Then run a 1-iteration smoke loop in shell/Git Bash to confirm:

1. run metadata is written
2. benchmark summary is written
3. playable version is published only on passing benchmark

- [ ] **Step 6: Commit**

```powershell
git add scenes/tuner/BenchmarkRunner.gd scenes/tuner/BenchmarkRunner.tscn scripts/training/train_loop.sh scripts/ai/AIBenchmarkRunner.gd scripts/ai/AIVersionRegistry.gd scripts/ai/TrainingRunRegistry.gd
git commit -m "feat: publish benchmark-approved AI versions from training loop"
```

---

### Task 7: Final Regression and Handoff

**Files:**
- Review: `docs/superpowers/specs/2026-03-28-ai-training-versioning-design.md`
- Review: `docs/superpowers/plans/2026-03-28-ai-training-versioning.md`

- [ ] **Step 1: Run the full test suite**

Run:

```powershell
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:/ai/code/ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: all newly added tests pass; pre-existing failures remain unchanged if any.

- [ ] **Step 2: Manual UI verification**

Verify in-app:

1. `BattleSetup` shows `AI 来源`
2. Choosing `指定训练版本 AI` enables version selection
3. Starting a battle with a versioned AI logs the loaded version
4. Missing version files fall back cleanly to default AI

- [ ] **Step 3: Manual training publication verification**

Run a one-iteration training smoke path and confirm:

1. run metadata exists
2. benchmark summary exists
3. one playable version record is visible in the registry if benchmark passes
4. `BattleSetup` can see that version immediately

- [ ] **Step 4: Commit any final cleanup**

```powershell
git add -A
git commit -m "test: verify AI versioned training flow end to end"
```

---

## Review Notes

- This plan intentionally keeps `AgentVersionStore.gd` as the low-level agent-config store and adds a separate user-facing version registry instead of overloading one file format with both meanings.
- This plan does **not** rewrite the current AI difficulty system; default AI remains available as a stable fallback while versioned AI is layered on top.
- Because this session does not have explicit user approval for delegation, the plan review step should be performed as a local self-review unless the user later requests subagent-based execution.
