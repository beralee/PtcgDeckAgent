# Battle Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a homepage `Battle Replay` flow that lists recorded local two-player matches, opens the loser-side key turn or fallback turn in a read-only replay mode inside `BattleScene`, supports previous/next turn navigation, and optionally resumes live play from the loaded turn-start snapshot.

**Architecture:** Reuse the existing match recording artifacts and `BattleScene` UI rather than building a separate replay renderer. Add a replay-browser scene, a small replay data pipeline (`MatchRecordIndex`, `BattleReplayLocator`, `BattleReplaySnapshotLoader`, and a snapshot-to-live state restorer), then gate `BattleScene` behind an explicit replay mode so live battle logic stays isolated.

**Tech Stack:** GDScript, Godot scenes, existing `BattleRecorder` / `BattleReviewService` artifacts, autoload `GameManager`, repository unit test framework, focused Godot suite runner

---

## File Structure

### New files

- `D:/ai/code/ptcgtrain/scenes/replay_browser/ReplayBrowser.tscn`
  - Dedicated replay browser scene opened from the main menu.
- `D:/ai/code/ptcgtrain/scenes/replay_browser/ReplayBrowser.gd`
  - Owns row rendering, browser refresh, replay launch, and back navigation.
- `D:/ai/code/ptcgtrain/scripts/engine/MatchRecordIndex.gd`
  - Scans `user://match_records`, filters local two-player matches, and builds replay list row summaries.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReplayLocator.gd`
  - Chooses the replay entry turn and produces the ordered replayable turn-number list.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReplaySnapshotLoader.gd`
  - Loads target turn-start snapshots from recorded artifacts and produces both raw and view-filtered replay payloads.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReplayStateRestorer.gd`
  - Rebuilds live runtime state objects from a raw replay snapshot for `Continue From Here`.
- `D:/ai/code/ptcgtrain/tests/test_match_record_index.gd`
  - Coverage for replay-browser row summaries and local-two-player filtering.
- `D:/ai/code/ptcgtrain/tests/test_battle_replay_locator.gd`
  - Coverage for loser key-turn selection, fallback selection, and replayable turn list construction.
- `D:/ai/code/ptcgtrain/tests/test_battle_replay_snapshot_loader.gd`
  - Coverage for exact turn-start loads, fallback logic, and acting-player visibility filtering.
- `D:/ai/code/ptcgtrain/tests/test_battle_replay_state_restorer.gd`
  - Coverage for raw snapshot to live `GameState` reconstruction.
- `D:/ai/code/ptcgtrain/tests/test_replay_browser.gd`
  - Scene-level coverage for row rendering and replay launch behavior.

### Existing files to modify

- `D:/ai/code/ptcgtrain/scenes/main_menu/MainMenu.tscn`
  - Add `BtnBattleReplay`.
- `D:/ai/code/ptcgtrain/scenes/main_menu/MainMenu.gd`
  - Wire the new replay browser button.
- `D:/ai/code/ptcgtrain/scripts/autoload/GameManager.gd`
  - Add replay-browser scene constant, replay launch state, and navigation helpers.
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
  - Add replay navigation controls near `BtnZeusHelp`.
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
  - Add replay mode state, replay snapshot loading, navigation, read-only guards, and `Continue From Here`.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
  - Persist replay-summary fields such as `final_prize_counts` and turn-start markers.
- `D:/ai/code/ptcgtrain/tests/TestRunner.gd`
  - Register the new replay test suites.
- `D:/ai/code/ptcgtrain/tests/test_game_manager.gd`
  - Add coverage for replay launch state helpers.
- `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - Add `BattleScene` replay-mode UI and behavior coverage.

### Existing files to reference during implementation

- `D:/ai/code/ptcgtrain/docs/superpowers/specs/2026-04-04-battle-replay-design.md`
- `D:/ai/code/ptcgtrain/docs/superpowers/specs/2026-03-29-battle-recording-design.md`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecorder.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewTurnExtractor.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewArtifactStore.gd`
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
- `D:/ai/code/ptcgtrain/scenes/main_menu/MainMenu.gd`

### Boundaries to preserve

- Do not add replay support for `VS_AI`, self-play, benchmark, tuner, or training modes in this plan.
- Do not implement intra-turn action playback.
- Do not expose hidden opponent information in replay mode.
- Only allow `Continue From Here` from a loaded turn-start snapshot.
- Keep replay behavior isolated from live battle legality and effect-resolution code.

---

### Task 1: Add replay scene routing and launch-state plumbing

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_replay_browser.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/main_menu/MainMenu.tscn`
- Modify: `D:/ai/code/ptcgtrain/scenes/main_menu/MainMenu.gd`
- Modify: `D:/ai/code/ptcgtrain/scripts/autoload/GameManager.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_game_manager.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing main-menu and GameManager tests**

```gdscript
func test_main_menu_includes_battle_replay_button() -> String:
	var scene: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	var replay_button := scene.find_child("BtnBattleReplay", true, false)
	return run_checks([
		assert_true(replay_button is Button, "MainMenu should expose BtnBattleReplay"),
	])


func test_game_manager_persists_replay_launch_request() -> String:
	var manager: Node = load("res://scripts/autoload/GameManager.gd").new()
	manager.call("set_battle_replay_launch", {"match_dir": "user://match_records/match_a", "entry_turn_number": 6})
	var launch: Dictionary = manager.call("consume_battle_replay_launch")
	return run_checks([
		assert_eq(str(launch.get("match_dir", "")), "user://match_records/match_a", "Replay launch should preserve match_dir"),
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay launch should preserve entry turn"),
		assert_true((manager.call("consume_battle_replay_launch") as Dictionary).is_empty(), "Replay launch should be one-shot"),
	])
```

- [ ] **Step 2: Register the new replay-browser suite in `tests/TestRunner.gd`**

```gdscript
const TestReplayBrowser = preload("res://tests/test_replay_browser.gd")
```

and:

```gdscript
	_run_test_suite("ReplayBrowser", TestReplayBrowser.new())
```

- [ ] **Step 3: Run the focused suites and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_game_manager.gd
```

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_replay_browser.gd
```

Expected:

- `BtnBattleReplay` test fails because the button does not exist yet
- replay launch state test fails because `GameManager` has no replay helpers yet

- [ ] **Step 4: Add replay browser routing and one-shot launch state**

Implement in `GameManager.gd`:

```gdscript
const SCENE_REPLAY_BROWSER := "res://scenes/replay_browser/ReplayBrowser.tscn"
var _battle_replay_launch: Dictionary = {}

func goto_replay_browser() -> void:
	goto_scene(SCENE_REPLAY_BROWSER)

func set_battle_replay_launch(launch: Dictionary) -> void:
	_battle_replay_launch = launch.duplicate(true)

func consume_battle_replay_launch() -> Dictionary:
	var launch := _battle_replay_launch.duplicate(true)
	_battle_replay_launch = {}
	return launch
```

- [ ] **Step 5: Add `BtnBattleReplay` and wire it in `MainMenu.gd`**

Wire:

```gdscript
%BtnBattleReplay.pressed.connect(_on_battle_replay)

func _on_battle_replay() -> void:
	GameManager.goto_replay_browser()
```

- [ ] **Step 6: Add a minimal placeholder `ReplayBrowser` scene and script**

The placeholder scene only needs:

- a title
- a back button
- an empty list container

- [ ] **Step 7: Re-run the focused suites until they pass**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_game_manager.gd
```

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_replay_browser.gd
```

Expected:

- both suites PASS

- [ ] **Step 8: Commit**

```powershell
git add scenes/main_menu/MainMenu.tscn scenes/main_menu/MainMenu.gd scripts/autoload/GameManager.gd scenes/replay_browser/ReplayBrowser.tscn scenes/replay_browser/ReplayBrowser.gd tests/test_game_manager.gd tests/test_replay_browser.gd tests/TestRunner.gd
git commit -m "feat: add battle replay entry points"
```

### Task 2: Add failing replay-index tests and implement `MatchRecordIndex`

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/MatchRecordIndex.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_replay_browser.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for local-two-player filtering and summary rows**

```gdscript
func test_match_record_index_lists_only_two_player_rows_newest_first() -> String:
	var index := MatchRecordIndex.new()
	index.set_root("user://test_match_records")
	_write_match_fixture("user://test_match_records/match_old", "two_player", 0, [3, 0], 6)
	_write_match_fixture("user://test_match_records/match_new", "two_player", 1, [0, 2], 9)
	_write_match_fixture("user://test_match_records/match_ai", "vs_ai", 0, [1, 0], 7)
	var rows := index.list_rows()
	return run_checks([
		assert_eq(rows.size(), 2, "Only two-player rows should be listed"),
		assert_eq(str((rows[0] as Dictionary).get("match_id", "")), "match_new", "Rows should sort newest first"),
		assert_eq((rows[0] as Dictionary).get("final_prize_counts", []), [0, 2], "Rows should expose final prize counts"),
	])
```

- [ ] **Step 2: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_replay_browser.gd
```

Expected:

- the new index test fails because `MatchRecordIndex.gd` does not exist

- [ ] **Step 3: Implement minimal row indexing**

Create `MatchRecordIndex.gd` with:

```gdscript
class_name MatchRecordIndex
extends RefCounted

var _root: String = "user://match_records"

func set_root(root_path: String) -> void:
	_root = root_path

func list_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	# scan directories, load match.json, filter mode == "two_player", then sort descending by recorded_at/match_id
	return rows
```

- [ ] **Step 4: Wire `ReplayBrowser.gd` to use `MatchRecordIndex`**

The browser should render row labels from `list_rows()` and keep `Replay` disabled until locator support lands.

- [ ] **Step 5: Re-run the focused suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_replay_browser.gd
```

Expected:

- PASS for replay-browser/index coverage

- [ ] **Step 6: Commit**

```powershell
git add scripts/engine/MatchRecordIndex.gd scenes/replay_browser/ReplayBrowser.gd tests/test_replay_browser.gd
git commit -m "feat: add replay match indexing"
```

### Task 3: Add failing locator tests and implement `BattleReplayLocator`

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReplayLocator.gd`
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_replay_locator.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for loser key-turn preference and fallback**

```gdscript
func test_locator_prefers_loser_key_turn_from_review() -> String:
	var locator := BattleReplayLocator.new()
	var result := locator.locate("res://tests/fixtures/match_review_fixture")
	return run_checks([
		assert_eq(int(result.get("entry_turn_number", 0)), 6, "Locator should choose the loser key turn when review exists"),
		assert_eq(str(result.get("entry_source", "")), "loser_key_turn", "Locator should report loser_key_turn source"),
	])


func test_locator_falls_back_to_loser_last_full_turn_without_review() -> String:
	var locator := BattleReplayLocator.new()
	var result := locator.locate("user://test_battle_replay_locator/no_review_match")
	return run_checks([
		assert_eq(str(result.get("entry_source", "")), "loser_last_full_turn", "Locator should fall back when review is missing"),
		assert_true(int(result.get("entry_turn_number", 0)) > 0, "Fallback entry turn should be usable"),
	])
```

- [ ] **Step 2: Register the new suite in `tests/TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_replay_locator.gd
```

Expected:

- tests fail because `BattleReplayLocator.gd` does not exist

- [ ] **Step 4: Implement minimal replay location logic**

Create `BattleReplayLocator.gd` with:

```gdscript
class_name BattleReplayLocator
extends RefCounted

func locate(match_dir: String) -> Dictionary:
	var review := _read_json(match_dir.path_join("review/review.json"))
	var loser_review_turn: int = _loser_turn_from_review(review)
	var entry := loser_review_turn
	if entry <= 0:
		entry = _loser_last_full_turn(match_dir)
	return {
		"entry_turn_number": entry,
		"entry_source": "loser_key_turn" if loser_review_turn > 0 else "loser_last_full_turn",
		"turn_numbers": _replayable_turn_numbers(match_dir),
	}
```

- [ ] **Step 5: Build `_replayable_turn_numbers()` from turns with usable `turn_start` snapshots**

Do not add navigation gaps silently; only return turns that the loader can actually open.

- [ ] **Step 6: Re-run the focused suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_replay_locator.gd
```

Expected:

- PASS for locator coverage

- [ ] **Step 7: Commit**

```powershell
git add scripts/engine/BattleReplayLocator.gd tests/test_battle_replay_locator.gd tests/TestRunner.gd
git commit -m "feat: add replay turn locator"
```

### Task 4: Add failing snapshot-loader tests and implement `BattleReplaySnapshotLoader`

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReplaySnapshotLoader.gd`
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_replay_snapshot_loader.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for exact turn-start loading and acting-player filtering**

```gdscript
func test_snapshot_loader_reads_turn_start_snapshot() -> String:
	var loader := BattleReplaySnapshotLoader.new()
	var replay := loader.load_turn("res://tests/fixtures/match_review_fixture", 6)
	return run_checks([
		assert_eq(int(replay.get("turn_number", 0)), 6, "Loader should return the requested turn number"),
		assert_eq(str(replay.get("snapshot_reason", "")), "turn_start", "Loader should prefer turn_start snapshots"),
	])


func test_snapshot_loader_hides_opponent_hand_for_view_player() -> String:
	var loader := BattleReplaySnapshotLoader.new()
	var replay := loader.load_turn("user://test_battle_replay_loader/full_snapshot_match", 4)
	var view_snapshot: Dictionary = replay.get("view_snapshot", {})
	var players: Array = ((view_snapshot.get("state", {}) as Dictionary).get("players", []))
	return run_checks([
		assert_true(((players[0] as Dictionary).get("hand", []) as Array).size() > 0, "Acting player's hand should remain visible"),
		assert_true(((players[1] as Dictionary).get("hand", []) as Array).is_empty(), "Opponent hand should be hidden in replay view"),
	])
```

- [ ] **Step 2: Register the new suite in `tests/TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_replay_snapshot_loader.gd
```

Expected:

- tests fail because `BattleReplaySnapshotLoader.gd` does not exist

- [ ] **Step 4: Implement minimal turn-snapshot loading**

Create `BattleReplaySnapshotLoader.gd` with:

```gdscript
class_name BattleReplaySnapshotLoader
extends RefCounted

func load_turn(match_dir: String, turn_number: int) -> Dictionary:
	var raw_event := _find_turn_start_snapshot(match_dir, turn_number)
	var raw_state := (raw_event.get("state", {}) as Dictionary).duplicate(true)
	var current_player_index := int(raw_state.get("current_player_index", -1))
	return {
		"turn_number": turn_number,
		"snapshot_reason": str(raw_event.get("snapshot_reason", "")),
		"raw_snapshot": raw_event.duplicate(true),
		"view_snapshot": _filter_for_view_player(raw_event, current_player_index),
		"view_player_index": current_player_index,
	}
```

- [ ] **Step 5: Implement visibility filtering**

Filtering rules:

- acting player's own hand remains
- opponent hand entries are stripped
- deck identities and order remain hidden in replay view
- public zones remain intact

- [ ] **Step 6: Re-run the focused suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_replay_snapshot_loader.gd
```

Expected:

- PASS for snapshot-loader coverage

- [ ] **Step 7: Commit**

```powershell
git add scripts/engine/BattleReplaySnapshotLoader.gd tests/test_battle_replay_snapshot_loader.gd tests/TestRunner.gd
git commit -m "feat: add replay snapshot loading"
```

### Task 5: Add failing exporter tests and persist replay summary fields

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_recorder.gd`

- [ ] **Step 1: Write failing tests for `final_prize_counts` and turn-start markers**

```gdscript
func test_export_match_persists_final_prize_counts() -> String:
	var exporter := BattleRecordExporter.new()
	var ok := exporter.export_match("user://test_replay_export/match_a", {"mode": "two_player"}, {"players": []}, _sample_events_with_turn_starts(), {"winner_index": 1, "reason": "knockout", "turn_number": 8, "final_prize_counts": [2, 0]})
	var match_payload := _read_json("user://test_replay_export/match_a/match.json")
	return run_checks([
		assert_true(ok, "export_match should succeed"),
		assert_eq((match_payload.get("result", {}) as Dictionary).get("final_prize_counts", []), [2, 0], "match.json should persist final prize counts"),
	])


func test_export_match_marks_turn_start_presence_in_turns_payload() -> String:
	var exporter := BattleRecordExporter.new()
	exporter.export_match("user://test_replay_export/match_b", {"mode": "two_player"}, {"players": []}, _sample_events_with_turn_starts(), {"winner_index": 0})
	var turns_payload := _read_json("user://test_replay_export/match_b/turns.json")
	var turns: Array = turns_payload.get("turns", [])
	return run_checks([
		assert_true(bool((turns[0] as Dictionary).get("has_turn_start_snapshot", false)), "turns.json should mark turn_start availability"),
	])
```

- [ ] **Step 2: Run the focused recorder suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_recorder.gd
```

Expected:

- new assertions fail because exporter does not persist the replay summary fields yet

- [ ] **Step 3: Implement minimal exporter changes**

In `BattleRecordExporter.gd`:

- mirror `final_prize_counts` from `result`
- mark per-turn `has_turn_start_snapshot`
- optionally persist `turn_start_event_index` when available from the event stream

- [ ] **Step 4: Re-run the focused recorder suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_recorder.gd
```

Expected:

- PASS for the new recorder/exporter assertions

- [ ] **Step 5: Commit**

```powershell
git add scripts/engine/BattleRecordExporter.gd tests/test_battle_recorder.gd
git commit -m "feat: persist replay summary fields"
```

### Task 6: Add failing `BattleScene` replay-mode tests and implement read-only replay entry

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write failing tests for replay controls and read-only gating**

```gdscript
func test_battle_scene_includes_replay_navigation_buttons() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var prev_button := scene.find_child("BtnReplayPrevTurn", true, false)
	var next_button := scene.find_child("BtnReplayNextTurn", true, false)
	return run_checks([
		assert_true(prev_button is Button, "BattleScene should expose BtnReplayPrevTurn"),
		assert_true(next_button is Button, "BattleScene should expose BtnReplayNextTurn"),
	])


func test_battle_scene_replay_mode_blocks_live_hand_actions() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_selected_hand_card", CardInstance.create(_make_trainer_cd("Any", "Item", ""), 0))
	var can_act := bool(battle_scene.call("_can_accept_live_action"))
	return run_checks([
		assert_false(can_act, "Replay mode should block live actions"),
	])
```

- [ ] **Step 2: Run the focused UI suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- replay button tests fail because the new nodes and mode helpers do not exist

- [ ] **Step 3: Add replay-mode state and top-bar controls**

Add new nodes to `BattleScene.tscn`:

- `BtnReplayPrevTurn`
- `BtnReplayNextTurn`
- `BtnReplayContinue`
- `BtnReplayBackToList`

Keep them hidden outside replay mode.

- [ ] **Step 4: Add explicit replay-mode helpers in `BattleScene.gd`**

Implement:

```gdscript
var _battle_mode: String = "live"
var _replay_match_dir: String = ""
var _replay_turn_numbers: Array[int] = []
var _replay_current_turn_index: int = -1
var _replay_entry_source: String = ""

func _is_review_mode() -> bool:
	return _battle_mode == "review_readonly"

func _can_accept_live_action() -> bool:
	return not _is_review_mode()
```

- [ ] **Step 5: Load replay launch state in `_ready()`**

At startup:

- consume `GameManager.consume_battle_replay_launch()`
- if launch data exists, enter replay mode
- do not run normal setup or battle-recording start flow

- [ ] **Step 6: Bind a replay snapshot to UI**

Add a single entry point such as:

```gdscript
func _load_replay_turn(turn_number: int) -> void:
	var replay := _battle_replay_snapshot_loader.load_turn(_replay_match_dir, turn_number)
	_view_player = int(replay.get("view_player_index", 0))
	_apply_replay_snapshot(replay)
	_refresh_ui()
```

- [ ] **Step 7: Re-run the focused UI suite until the replay-mode tests pass**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- the new replay tests PASS
- unrelated existing UI tests remain green

- [ ] **Step 8: Commit**

```powershell
git add scenes/battle/BattleScene.tscn scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd
git commit -m "feat: add battle replay mode shell"
```

### Task 7: Add failing turn-navigation tests and implement previous/next replay jumps

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Write failing tests for replay turn navigation and acting-player view switching**

```gdscript
func test_battle_scene_replay_next_turn_loads_adjacent_turn_start() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_replay_match_dir", "res://tests/fixtures/match_review_fixture")
	battle_scene.set("_replay_turn_numbers", [4, 5, 6])
	battle_scene.set("_replay_current_turn_index", 1)
	battle_scene.call("_on_replay_next_turn_pressed")
	return run_checks([
		assert_eq(int(battle_scene.get("_replay_current_turn_index")), 2, "Next Turn should advance the replay turn index"),
		assert_eq(int(battle_scene.get("_view_player")), 1, "Replay should follow the loaded turn's acting player"),
	])
```

- [ ] **Step 2: Run the focused UI suite and verify failure**

- [ ] **Step 3: Implement previous/next handlers**

Implement:

```gdscript
func _on_replay_prev_turn_pressed() -> void:
	if _replay_current_turn_index <= 0:
		return
	_replay_current_turn_index -= 1
	_load_replay_turn(_replay_turn_numbers[_replay_current_turn_index])

func _on_replay_next_turn_pressed() -> void:
	if _replay_current_turn_index < 0 or _replay_current_turn_index >= _replay_turn_numbers.size() - 1:
		return
	_replay_current_turn_index += 1
	_load_replay_turn(_replay_turn_numbers[_replay_current_turn_index])
```

- [ ] **Step 4: Disable buttons at the boundaries and refresh labels accordingly**

- [ ] **Step 5: Re-run the focused UI suite until the navigation tests pass**

- [ ] **Step 6: Commit**

```powershell
git add scenes/battle/BattleScene.gd tests/test_battle_ui_features.gd
git commit -m "feat: add replay turn navigation"
```

### Task 8: Add failing state-restorer tests and implement `Continue From Here`

**Files:**
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleReplayStateRestorer.gd`
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_replay_state_restorer.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing restorer tests for raw snapshot reconstruction**

```gdscript
func test_state_restorer_rebuilds_live_state_from_raw_snapshot() -> String:
	var restorer := BattleReplayStateRestorer.new()
	var raw_snapshot := _sample_raw_replay_snapshot()
	var state: GameState = restorer.restore(raw_snapshot)
	return run_checks([
		assert_eq(state.turn_number, 6, "Restored state should keep turn number"),
		assert_eq(state.current_player_index, 1, "Restored state should keep current actor"),
		assert_eq(state.players[1].hand.size(), 4, "Restored state should rebuild acting-player hand"),
	])
```

- [ ] **Step 2: Add a failing `BattleScene` continue test**

```gdscript
func test_battle_scene_continue_from_here_switches_to_live_mode() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_replay_loaded_raw_snapshot", _sample_raw_replay_snapshot())
	battle_scene.call("_on_replay_continue_pressed")
	return run_checks([
		assert_eq(str(battle_scene.get("_battle_mode")), "live", "Continue From Here should return the scene to live mode"),
		assert_true(battle_scene.call("_can_accept_live_action"), "Continue From Here should re-enable live actions"),
	])
```

- [ ] **Step 3: Run the focused suites and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_replay_state_restorer.gd
```

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- restorer tests fail because the new class does not exist
- continue test fails because `BattleScene` cannot transition from replay to live yet

- [ ] **Step 4: Implement minimal snapshot-to-live-state reconstruction**

Create `BattleReplayStateRestorer.gd` with focused helpers:

- `_restore_player_state()`
- `_restore_slot()`
- `_restore_card_instance()`
- `restore(raw_snapshot: Dictionary) -> GameState`

Rebuild only the runtime state needed for turn-start live play. Do not attempt to restore mid-turn pending interactions.

- [ ] **Step 5: Implement `BattleScene` continue flow**

Implement:

```gdscript
func _on_replay_continue_pressed() -> void:
	var state: GameState = _battle_replay_state_restorer.restore(_replay_loaded_raw_snapshot)
	_gsm.game_state = state
	_clear_replay_ui_state()
	_battle_mode = "live"
	_refresh_ui()
```

`_clear_replay_ui_state()` must reset:

- replay button visibility state
- pending replay launch data
- pending dialog/effect/handover state
- any replay-only cached snapshot fields

- [ ] **Step 6: Re-run the focused suites until they pass**

- [ ] **Step 7: Commit**

```powershell
git add scripts/engine/BattleReplayStateRestorer.gd scenes/battle/BattleScene.gd tests/test_battle_replay_state_restorer.gd tests/test_battle_ui_features.gd tests/TestRunner.gd
git commit -m "feat: allow continuing live play from replay"
```

### Task 9: Run integration verification and clean up plan edge cases

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/replay_browser/ReplayBrowser.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_replay_browser.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`

- [ ] **Step 1: Add one browser-to-battle integration test**

```gdscript
func test_replay_browser_launches_battle_scene_with_locator_output() -> String:
	var browser := ReplayBrowser.new()
	browser.set("_record_index", FakeRecordIndex.new())
	browser.set("_replay_locator", FakeReplayLocator.new({"entry_turn_number": 6, "entry_source": "loser_key_turn", "turn_numbers": [4, 5, 6]}))
	browser.call("_on_replay_pressed", {"match_dir": "user://match_records/match_a"})
	var launch := GameManager.consume_battle_replay_launch()
	return run_checks([
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay button should forward locator output into GameManager launch state"),
	])
```

- [ ] **Step 2: Run the targeted integration suites**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain "res://tests/TestRunner.tscn" -- --suite=ReplayBrowser,BattleUIFeatures,GameManager
```

Expected:

- all three suites PASS

- [ ] **Step 3: Run the broader replay-adjacent verification**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain "res://tests/TestRunner.tscn" -- --suite=BattleRecorder,ReplayBrowser,BattleUIFeatures,GameManager
```

Expected:

- replay-specific suites PASS
- recorder suite PASS after exporter updates
- any unrelated pre-existing failures must be called out explicitly before completion

- [ ] **Step 4: Commit final replay integration changes**

```powershell
git add scenes/replay_browser/ReplayBrowser.gd scenes/battle/BattleScene.gd tests/test_replay_browser.gd tests/test_battle_ui_features.gd
git commit -m "feat: wire battle replay flow end to end"
```

## Notes for Implementation

- Prefer small helpers over embedding replay parsing directly into `BattleScene`.
- Keep replay filtering and replay-to-live reconstruction outside `BattleScene` where possible.
- Reuse `FocusedSuiteRunner.gd` for new isolated suites instead of running the whole test matrix on every step.
- If an old recorded match lacks `final_prize_counts` or `has_turn_start_snapshot`, degrade gracefully in the browser instead of hard-failing.
- Treat replay launch state as one-shot; always clear it after `BattleScene` consumes it.

## Review Constraints

- The usual plan-review subagent loop was not executed here because subagent delegation requires an explicit user request in this session.
- Before implementation starts, do one manual pass against `docs/superpowers/specs/2026-04-04-battle-replay-design.md` and confirm each task still maps cleanly to the approved spec.
