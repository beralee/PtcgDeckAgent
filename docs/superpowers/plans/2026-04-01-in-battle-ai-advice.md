# In-Battle AI Advice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a repeatable in-match `AI Advice` flow for local two-player battles that reuses one match-long ZenMux session, sends only the current player's visible information plus both decklists, and shows structured advice in an overlay plus a docked side panel.

**Architecture:** Build the feature as a read-only parallel pipeline next to the existing battle recorder and post-match review pipeline. Reuse the recorder outputs and ZenMux client patterns, then add advice-specific session persistence, payload building, prompt schemas, service orchestration, and `BattleScene` UI state without changing battle rules or action resolution.

**Tech Stack:** GDScript, Godot `HTTPRequest`, existing `BattleScene` / `BattleRecorder` / `ZenMuxClient` patterns, focused Godot suite runner, repository unit test framework

---

## File Structure

### New files

- `D:/ai/code/ptcgtrain/scripts/engine/BattleAdviceSessionStore.gd`
  - Owns `session.json`, `latest_advice.json`, `latest_success.json`, and per-request artifact reads/writes.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleAdvicePromptBuilder.gd`
  - Owns the `battle_advice_v1` request/response contract and prompt payload assembly.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleAdviceContextBuilder.gd`
  - Builds current-position payloads from live battle state plus incremental recorder artifacts.
- `D:/ai/code/ptcgtrain/scripts/engine/BattleAdviceService.gd`
  - Orchestrates async request lifecycle, busy state, persistence, and normalized result handling.
- `D:/ai/code/ptcgtrain/tests/test_battle_advice_session_store.gd`
  - Focused coverage for session initialization, latest-attempt persistence, latest-success persistence, and failed-attempt handling.
- `D:/ai/code/ptcgtrain/tests/test_battle_advice_prompt_builder.gd`
  - Focused coverage for `battle_advice_v1` schema versioning and contract shape.
- `D:/ai/code/ptcgtrain/tests/test_battle_advice_context_builder.gd`
  - Focused coverage for visible-information filtering, decklist inclusion, and incremental delta assembly.
- `D:/ai/code/ptcgtrain/tests/test_battle_advice_service.gd`
  - Focused coverage for busy-state gating, normalized success/failure writes, and request indexing.

### Existing files to modify

- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
  - Wire the new button, busy gating, advice overlay, pinned side panel, service integration, and cache the authoritative match-start deck snapshot for advice requests.
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
  - Add `BtnAiAdvice`, the overlay widgets, and the docked panel widgets.
- `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - Add integration coverage for button placement, busy disable behavior, overlay rendering, rerun handling, and panel pinning.
- `D:/ai/code/ptcgtrain/tests/TestRunner.gd`
  - Register the four new advice test suites.

### Existing files to reference during implementation

- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewArtifactStore.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewPromptBuilder.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewService.gd`
- `D:/ai/code/ptcgtrain/scripts/network/ZenMuxClient.gd`
- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- `D:/ai/code/ptcgtrain/docs/superpowers/specs/2026-04-01-in-battle-ai-advice-design.md`

### Boundaries to preserve

- Reuse `GameManager.get_battle_review_api_config()` for ZenMux endpoint/key/model access. Do not add a second config path in this plan.
- Do not alter battle legality, effect resolution, or turn progression.
- Do not add provider chat-history state outside the match directory artifacts.
- Treat the match-start initial snapshot captured in `BattleScene` as the authoritative source for both players' full 60-card decklists during in-match advice.

---

### Task 1: Add failing persistence tests and implement `BattleAdviceSessionStore`

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_advice_session_store.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleAdviceSessionStore.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for session initialization and latest-success preservation**

```gdscript
func test_create_session_starts_with_next_request_index_one() -> String:
	var store := BattleAdviceSessionStore.new()
	var session := store.create_or_load_session("user://test_battle_advice/session_a", 0)
	return run_checks([
		assert_eq(int(session.get("next_request_index", 0)), 1, "Session should start with request index 1"),
		assert_eq(String(session.get("latest_attempt_status", "")), "idle", "New session should start idle"),
	])


func test_failed_attempt_does_not_overwrite_latest_success() -> String:
	var store := BattleAdviceSessionStore.new()
	var match_dir := "user://test_battle_advice/session_b"
	store.write_latest_success(match_dir, {"status": "completed", "request_index": 1, "advice": {"strategic_thesis": "keep pressure"}})
	store.write_latest_attempt(match_dir, {"status": "failed", "request_index": 2, "errors": [{"message": "timeout"}]})
	var latest_success := store.read_latest_success(match_dir)
	return run_checks([
		assert_eq(int(latest_success.get("request_index", 0)), 1, "Failed attempt must not overwrite latest_success"),
	])
```

- [ ] **Step 2: Register the new suite in `tests/TestRunner.gd`**

```gdscript
const TestBattleAdviceSessionStore = preload("res://tests/test_battle_advice_session_store.gd")
```

and:

```gdscript
	_run_test_suite("BattleAdviceSessionStore", TestBattleAdviceSessionStore.new())
```

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_session_store.gd
```

Expected:

- the suite loads
- tests fail because `BattleAdviceSessionStore.gd` does not exist yet

- [ ] **Step 4: Implement the minimal session store**

```gdscript
class_name BattleAdviceSessionStore
extends RefCounted

func create_or_load_session(match_dir: String, player_view_index: int) -> Dictionary:
	var existing := _read_json(_advice_dir(match_dir).path_join("session.json"))
	if not existing.is_empty():
		return existing
	var session := {
		"session_id": _make_session_id(match_dir),
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),
		"request_count": 0,
		"next_request_index": 1,
		"last_synced_event_index": 0,
		"last_synced_turn_number": 0,
		"last_advice_summary": "",
		"last_player_view_index": player_view_index,
		"latest_attempt_status": "idle",
		"latest_attempt_request_index": 1,
		"latest_success_request_index": 1,
	}
	_write_json(_advice_dir(match_dir).path_join("session.json"), session)
	return session
```

- [ ] **Step 5: Add helpers for `write_latest_attempt`, `write_latest_success`, `read_latest_success`, and per-request debug artifacts**

- [ ] **Step 6: Run the focused suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_session_store.gd
```

Expected:

- PASS for the session-store suite

- [ ] **Step 7: Commit**

```powershell
git add tests/test_battle_advice_session_store.gd tests/TestRunner.gd scripts/engine/BattleAdviceSessionStore.gd
git commit -m "feat: add battle advice session persistence"
```

### Task 2: Add failing prompt-contract tests and implement `BattleAdvicePromptBuilder`

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_advice_prompt_builder.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleAdvicePromptBuilder.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for schema version and payload shape**

```gdscript
func test_build_request_payload_sets_battle_advice_v1() -> String:
	var builder := BattleAdvicePromptBuilder.new()
	var payload := builder.build_request_payload({"session_id": "match_1"}, {"known": ["board"], "unknown": ["opponent_hand"]}, {"current_position": {}}, {"delta_since_last_advice": {}})
	return run_checks([
		assert_eq(String(payload.get("schema_version", "")), "battle_advice_v1", "Prompt payload should use the fixed schema version"),
		assert_true(payload.has("response_format"), "Prompt payload should expose a strict JSON schema"),
		assert_true(payload.has("visibility_rules"), "Prompt payload should include visibility_rules"),
	])


func test_response_schema_defines_step_object_shape() -> String:
	var builder := BattleAdvicePromptBuilder.new()
	var schema: Dictionary = builder.response_schema()
	var current_turn_items := (((schema.get("properties", {}) as Dictionary).get("current_turn_main_line", {}) as Dictionary).get("items", {}) as Dictionary)
	return run_checks([
		assert_true(current_turn_items.has("properties"), "Current-turn main line items should be object-shaped"),
	])
```

- [ ] **Step 2: Register the new suite in `tests/TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_prompt_builder.gd
```

Expected:

- tests fail because `BattleAdvicePromptBuilder.gd` does not exist yet

- [ ] **Step 4: Implement the minimal prompt builder and strict schema**

```gdscript
class_name BattleAdvicePromptBuilder
extends RefCounted

const BATTLE_ADVICE_SCHEMA_VERSION := "battle_advice_v1"

func build_request_payload(session_block: Dictionary, visibility_rules: Dictionary, current_position: Dictionary, delta_block: Dictionary) -> Dictionary:
	return {
		"schema_version": BATTLE_ADVICE_SCHEMA_VERSION,
		"response_format": response_schema(),
		"instructions": instructions(),
		"session": session_block.duplicate(true),
		"visibility_rules": visibility_rules.duplicate(true),
		"current_position": current_position.duplicate(true),
		"delta_since_last_advice": delta_block.duplicate(true),
	}
```

- [ ] **Step 5: Add explicit object schemas for `current_turn_main_line`, `conditional_branches`, `prize_plan`, `risk_watchouts`, plus `why_this_line` and `summary_for_next_request`**

- [ ] **Step 6: Run the focused suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_prompt_builder.gd
```

Expected:

- PASS for the prompt-builder suite

- [ ] **Step 7: Commit**

```powershell
git add tests/test_battle_advice_prompt_builder.gd tests/TestRunner.gd scripts/engine/BattleAdvicePromptBuilder.gd
git commit -m "feat: add battle advice prompt contract"
```

### Task 3: Add failing context-builder tests and implement `BattleAdviceContextBuilder`

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_advice_context_builder.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleAdviceContextBuilder.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing tests for visible-information filtering and decklist inclusion**

```gdscript
func test_build_request_context_hides_opponent_hand_and_shows_decklists() -> String:
	var builder := BattleAdviceContextBuilder.new()
	var context := builder.build_request_context(_sample_live_snapshot(), _sample_initial_snapshot(), _sample_match_dir(), 0, {"session_id": "match_1", "request_index": 1})
	var current_position: Dictionary = context.get("current_position", {})
	var players: Array = (current_position.get("players", []) as Array)
	var opponent := players[1] as Dictionary
	var visibility_rules := context.get("visibility_rules", {}) as Dictionary
	return run_checks([
		assert_false(opponent.has("hand"), "Opponent hand contents should not be present"),
		assert_true(current_position.has("decklists"), "Both decklists should be included"),
		assert_true(visibility_rules.has("known") and visibility_rules.has("unknown"), "Context should include explicit visibility rules"),
		assert_false(current_position.has("prize_identities"), "Prize identities should not be exposed"),
		assert_false(current_position.has("deck_order"), "Deck order should not be exposed"),
	])


func test_build_request_context_only_includes_unsynced_detail_events() -> String:
	var builder := BattleAdviceContextBuilder.new()
	var context := builder.build_request_context(_sample_live_snapshot(), _sample_initial_snapshot(), _sample_match_dir(), 0, {
		"session_id": "match_1",
		"request_index": 2,
		"last_synced_event_index": 3,
	})
	var delta := context.get("delta_since_last_advice", {}) as Dictionary
	return run_checks([
		assert_eq(int(((delta.get("detail_events", []) as Array)[0] as Dictionary).get("event_index", -1)), 4, "Delta should start at the first unsynced event"),
	])
```

- [ ] **Step 2: Register the new suite in `tests/TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_context_builder.gd
```

Expected:

- tests fail because `BattleAdviceContextBuilder.gd` does not exist yet

- [ ] **Step 4: Implement a minimal live-context builder**

```gdscript
class_name BattleAdviceContextBuilder
extends RefCounted

func build_request_context(live_snapshot: Dictionary, initial_snapshot: Dictionary, match_dir: String, view_player: int, session: Dictionary) -> Dictionary:
	return {
		"session": {
			"session_id": str(session.get("session_id", "")),
			"request_index": int(session.get("request_index", 1)),
			"last_advice_summary": str(session.get("last_advice_summary", "")),
			"current_player_index": view_player,
		},
		"visibility_rules": _visibility_rules(),
		"current_position": _current_position(live_snapshot, initial_snapshot, match_dir, view_player),
		"delta_since_last_advice": _build_delta(match_dir, int(session.get("last_synced_event_index", 0))),
	}
```

- [ ] **Step 5: Reuse existing battle snapshot shape and recorder artifacts**
  - include acting player hand contents
  - strip opponent hand contents
  - include both decklists from the authoritative match-start initial snapshot captured in `BattleScene`
  - include summary lines and unsynced `detail.jsonl` events

- [ ] **Step 5a: Add `_sample_initial_snapshot()` fixture data with both full decklists**
  - make the decklist source deterministic in the context-builder suite

- [ ] **Step 6: Run the focused suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_context_builder.gd
```

Expected:

- PASS for the context-builder suite

- [ ] **Step 7: Commit**

```powershell
git add tests/test_battle_advice_context_builder.gd tests/TestRunner.gd scripts/engine/BattleAdviceContextBuilder.gd
git commit -m "feat: add battle advice context builder"
```

### Task 4: Add failing service tests and implement `BattleAdviceService`

**Files:**
- Create: `D:/ai/code/ptcgtrain/tests/test_battle_advice_service.gd`
- Create: `D:/ai/code/ptcgtrain/scripts/engine/BattleAdviceService.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_advice_session_store.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_advice_prompt_builder.gd`
- Test: `D:/ai/code/ptcgtrain/tests/test_battle_advice_context_builder.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Write failing service tests for busy gating, successful writes, and failed writes**

Use deterministic async test doubles instead of real `HTTPRequest` work. The service suite should:

- inject a fake ZenMux client whose `request_json(parent, endpoint, api_key, payload, callback)` immediately calls the bound callback with a canned response and returns `OK`
- inject fake context-builder and prompt-builder dependencies
- wait on the service's `advice_completed` signal before asserting persisted files
- explicitly add the following test-only helpers before asserting on them:
  - `BattleAdviceService.set_busy_for_test(value: bool)`
  - `BattleAdviceService.configure_dependencies(client, context_builder, store, prompt_builder)`
  - `BattleAdviceSessionStore.read_session(match_dir: String)`
  - `BattleAdviceSessionStore.write_raw_session_for_test(match_dir: String, raw_text: String)`
  - `_wait_for_signal(emitter: Object, signal_name: String)` in the test suite

```gdscript
func test_generate_advice_ignores_new_request_while_running() -> String:
	var service := BattleAdviceService.new()
	service.set_busy_for_test(true)
	var result := service.generate_advice(Node.new(), "user://test_battle_advice/service_busy", {}, {"players": []}, {"endpoint": "", "api_key": "", "model": ""}, 0)
	return run_checks([
		assert_eq(String(result.get("status", "")), "ignored", "Busy service should ignore concurrent requests"),
	])


func test_failed_response_writes_latest_attempt_but_preserves_latest_success() -> String:
	var store := BattleAdviceSessionStore.new()
	var service := BattleAdviceService.new()
	service.configure_dependencies(_fake_client_error(), _fake_context_builder(), store, _fake_prompt_builder())
	var completions: Array[Dictionary] = []
	service.advice_completed.connect(func(result: Dictionary) -> void:
		completions.append(result)
	)
	service.generate_advice(Node.new(), "user://test_battle_advice/service_failure", {"turn_number": 5}, {"players": []}, {"endpoint": "", "api_key": "", "model": ""}, 0)
	await _wait_for_signal(service, "advice_completed")
	var latest_success := store.read_latest_success("user://test_battle_advice/service_failure")
	return run_checks([
		assert_eq(completions.size(), 1, "Failure path should emit exactly one completion"),
		assert_true(latest_success.is_empty(), "Failure path should not invent a new latest_success artifact"),
	])


func test_second_request_reuses_session_id_and_increments_request_count() -> String:
	var store := BattleAdviceSessionStore.new()
	var service := BattleAdviceService.new()
	service.configure_dependencies(_fake_client_success(), _fake_context_builder(), store, _fake_prompt_builder())
	var match_dir := "user://test_battle_advice/service_session_reuse"
	service.generate_advice(Node.new(), match_dir, {"turn_number": 5}, {"players": []}, {"endpoint": "", "api_key": "", "model": ""}, 0)
	await _wait_for_signal(service, "advice_completed")
	service.generate_advice(Node.new(), match_dir, {"turn_number": 6}, {"players": []}, {"endpoint": "", "api_key": "", "model": ""}, 0)
	await _wait_for_signal(service, "advice_completed")
	var session := store.read_session(match_dir)
	return run_checks([
		assert_eq(int(session.get("request_count", 0)), 2, "Repeated requests should increment request_count"),
		assert_eq(String(session.get("session_id", "")), String(store.read_session(match_dir).get("session_id", "")), "Repeated requests should reuse the same session_id"),
	])


func test_missing_or_corrupted_session_is_rebuilt_non_fatally() -> String:
	var store := BattleAdviceSessionStore.new()
	var match_dir := "user://test_battle_advice/service_recover_session"
	store.write_raw_session_for_test(match_dir, "{not-json")
	var session := store.create_or_load_session(match_dir, 0)
	return run_checks([
		assert_eq(int(session.get("next_request_index", 0)), 1, "Corrupted session should be rebuilt with default counters"),
		assert_eq(String(session.get("latest_attempt_status", "")), "idle", "Rebuilt session should return to idle"),
	])
```

- [ ] **Step 2: Register the new suite in `tests/TestRunner.gd`**

- [ ] **Step 3: Run the focused suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_service.gd
```

Expected:

- tests fail because `BattleAdviceService.gd` does not exist yet

- [ ] **Step 4: Implement minimal async orchestration**

```gdscript
class_name BattleAdviceService
extends RefCounted

signal status_changed(status: String, context: Dictionary)
signal advice_completed(result: Dictionary)

func configure_dependencies(client: Variant, context_builder: Variant, store: Variant, prompt_builder: Variant) -> void:
	if client != null:
		_client = client
	if context_builder != null:
		_context_builder = context_builder
	if store != null:
		_store = store
	if prompt_builder != null:
		_prompt_builder = prompt_builder

func generate_advice(parent: Node, match_dir: String, live_snapshot: Dictionary, initial_snapshot: Dictionary, api_config: Dictionary, view_player: int) -> Dictionary:
	if _busy:
		return {"status": "ignored"}
	_busy = true
	var session := _store.create_or_load_session(match_dir, view_player)
	var request_index := int(session.get("next_request_index", 1))
	var request_context := _context_builder.build_request_context(live_snapshot, initial_snapshot, match_dir, view_player, session)
	var payload := _prompt_builder.build_request_payload(
		request_context.get("session", {}),
		request_context.get("visibility_rules", {}),
		request_context.get("current_position", {}),
		request_context.get("delta_since_last_advice", {})
	)
	return _start_request(parent, match_dir, payload, session, request_index)
```

The `api_config` passed here should come from `GameManager.get_battle_review_api_config()` in `BattleScene.gd`, not from a new config source.

- [ ] **Step 5: Normalize success/failure persistence**
  - before dispatch:
    - increment `request_count`
    - set `latest_attempt_status = "running"`
    - set `latest_attempt_request_index = request_index`
    - advance `next_request_index = request_index + 1`
    - set `last_player_view_index = view_player`
    - persist the updated session
  - success writes `latest_advice.json`, `latest_success.json`, and `advice_response_<n>.json`
  - failure writes `latest_advice.json` and `advice_response_<n>.json`
  - every request writes `advice_request_<n>.json` before the ZenMux call starts
  - failed attempts persist the normalized failed envelope, including `raw_provider_response` when available
  - both success and failure advance session timestamps
  - success sets `latest_attempt_status = "completed"` and `latest_success_request_index = request_index`
  - failure sets `latest_attempt_status = "failed"`
  - only success advances `last_synced_event_index`, `last_synced_turn_number`, and `last_advice_summary`
  - success also refreshes `last_player_view_index = view_player`
  - on request completion callback:
    - clear the service busy flag
    - emit `status_changed` with the terminal state
    - emit `advice_completed` with the normalized successful or failed envelope
  - if `session.json` is missing or cannot be parsed:
    - rebuild it through `create_or_load_session(...)`
    - continue the request flow without crashing or aborting the match scene

- [ ] **Step 6: Run all four advice-focused suites until they pass**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_session_store.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_prompt_builder.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_context_builder.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_service.gd
```

Expected:

- PASS for all advice backend suites

- [ ] **Step 7: Commit**

```powershell
git add tests/test_battle_advice_service.gd tests/TestRunner.gd scripts/engine/BattleAdviceService.gd scripts/engine/BattleAdviceSessionStore.gd scripts/engine/BattleAdvicePromptBuilder.gd scripts/engine/BattleAdviceContextBuilder.gd
git commit -m "feat: add in-battle AI advice service"
```

### Task 5: Add failing UI tests for button placement and busy-state behavior

**Files:**
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`

- [ ] **Step 1: Add a failing test for top-bar button placement**

```gdscript
func test_battle_scene_includes_ai_advice_button_left_of_zeus_help() -> String:
	var scene := load("res://scenes/battle/BattleScene.tscn").instantiate()
	var actions := scene.find_child("TopBarActions", true, false) as HBoxContainer
	var ai_button := scene.find_child("BtnAiAdvice", true, false)
	var zeus_button := scene.find_child("BtnZeusHelp", true, false)
	return run_checks([
		assert_true(ai_button is Button, "BattleScene should expose BtnAiAdvice"),
		assert_true(actions.get_child(actions.get_children().find(ai_button) + 1) == zeus_button, "BtnAiAdvice should sit immediately left of BtnZeusHelp"),
	])
```

- [ ] **Step 2: Add a failing test for busy disable behavior**

```gdscript
func test_ai_advice_button_disables_while_request_running() -> String:
	var scene := _make_battle_scene_stub()
	scene.set("_btn_ai_advice", Button.new())
	scene.set("_battle_advice_busy", true)
	scene.call("_refresh_ai_advice_controls")
	var button := scene.get("_btn_ai_advice") as Button
	return run_checks([
		assert_true(button.disabled, "AI advice button should disable while request is running"),
	])


func test_ai_advice_overlay_shows_failure_and_retry_action() -> String:
	var scene := _make_battle_scene_stub()
	scene.set("_advice_overlay", Panel.new())
	scene.set("_advice_content", RichTextLabel.new())
	scene.set("_advice_rerun_btn", Button.new())
	scene.call("_show_battle_advice_overlay", {
		"status": "failed",
		"errors": [{"message": "timeout"}],
	})
	var rerun := scene.get("_advice_rerun_btn") as Button
	return run_checks([
		assert_true(rerun.visible, "Failure state should expose rerun"),
		assert_false(rerun.disabled, "Rerun should be enabled after a failed request finishes"),
	])
```

- [ ] **Step 3: Add placeholder `BtnAiAdvice` and advice overlay/panel nodes to `BattleScene.tscn`**

- [ ] **Step 4: Run the focused UI suite and verify failure**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- the suite fails because `BtnAiAdvice` and the new advice UI state are not wired yet

- [ ] **Step 5: Commit**

```powershell
git add tests/test_battle_ui_features.gd scenes/battle/BattleScene.tscn
git commit -m "test: add in-battle AI advice UI coverage"
```

### Task 6: Implement `BattleScene` advice flow and finish integration

**Files:**
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
- Modify: `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.tscn`
- Modify: `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
- Modify: `D:/ai/code/ptcgtrain/tests/TestRunner.gd`

- [ ] **Step 1: Add the new state and node references to `BattleScene.gd`**

```gdscript
const BattleAdviceServiceScript := preload("res://scripts/engine/BattleAdviceService.gd")

var _battle_advice_service: RefCounted = null
var _battle_advice_busy: bool = false
var _battle_advice_last_result: Dictionary = {}
var _battle_advice_panel_pinned: bool = false
var _battle_advice_panel_collapsed: bool = false
var _battle_advice_initial_snapshot: Dictionary = {}

@onready var _btn_ai_advice: Button = %BtnAiAdvice
@onready var _advice_overlay: Panel = %AdviceOverlay
@onready var _advice_title: Label = %AdviceTitle
@onready var _advice_content: RichTextLabel = %AdviceContent
@onready var _advice_rerun_btn: Button = %AdviceRerunBtn
@onready var _advice_pin_btn: Button = %AdvicePinBtn
@onready var _advice_panel: PanelContainer = %AdvicePanel
@onready var _advice_panel_content: RichTextLabel = %AdvicePanelContent
```

- [ ] **Step 2: Wire `_btn_ai_advice` in `_ready()` and add `_ensure_battle_advice_service()`**

- [ ] **Step 3: Implement a small `_build_live_advice_snapshot()` helper by reusing `_build_battle_state_snapshot()`**

```gdscript
func _build_live_advice_snapshot() -> Dictionary:
	return _build_battle_state_snapshot()
```

- [ ] **Step 3a: Cache the authoritative initial snapshot when battle recording starts**

```gdscript
func _ensure_battle_recording_started() -> void:
	# existing guards...
	_battle_advice_initial_snapshot = _build_battle_initial_state()
```

- [ ] **Step 4: Implement `_on_ai_advice_pressed()` and busy gating**
  - return immediately if mode is not `TWO_PLAYER`
  - return immediately if `_battle_advice_busy` is true
  - open overlay
  - show loading text
  - fetch `api_config` with `GameManager.get_battle_review_api_config()`
  - call `generate_advice(self, _battle_review_match_dir, _build_live_advice_snapshot(), _battle_advice_initial_snapshot, api_config, _view_player)`

- [ ] **Step 5: Implement result formatting, panel pinning, and collapse/expand state**

```gdscript
func _format_battle_advice(result: Dictionary) -> String:
	var advice: Dictionary = result.get("advice", {})
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % str(advice.get("strategic_thesis", "")))
	for step_variant: Variant in advice.get("current_turn_main_line", []):
		var step: Dictionary = step_variant if step_variant is Dictionary else {}
		lines.append("%d. %s" % [int(step.get("step", 0)), str(step.get("action", ""))])
	lines.append("")
	lines.append("[b]Conditional Branches[/b]")
	for branch_variant: Variant in advice.get("conditional_branches", []):
		var branch: Dictionary = branch_variant if branch_variant is Dictionary else {}
		lines.append("- IF %s" % str(branch.get("if", "")))
		for then_step: Variant in branch.get("then", []):
			lines.append("  - %s" % str(then_step))
	lines.append("")
	lines.append("[b]Prize Plan[/b]")
	for prize_variant: Variant in advice.get("prize_plan", []):
		var prize_entry: Dictionary = prize_variant if prize_variant is Dictionary else {}
		lines.append("- [%s] %s" % [str(prize_entry.get("horizon", "")), str(prize_entry.get("goal", ""))])
	lines.append("")
	lines.append("[b]Why This Line[/b]")
	for reason_variant: Variant in advice.get("why_this_line", []):
		lines.append("- %s" % str(reason_variant))
	lines.append("")
	lines.append("[b]Risk Watchouts[/b]")
	for risk_variant: Variant in advice.get("risk_watchouts", []):
		var risk_entry: Dictionary = risk_variant if risk_variant is Dictionary else {}
		lines.append("- %s | Mitigation: %s" % [str(risk_entry.get("risk", "")), str(risk_entry.get("mitigation", ""))])
	lines.append("")
	lines.append("[b]Confidence[/b] %s" % str(advice.get("confidence", "")))
	lines.append("")
	lines.append("[b]Summary For Next Request[/b] %s" % str(advice.get("summary_for_next_request", "")))
	return "\n".join(lines)
```

Add a small panel-state helper:

```gdscript
func _set_advice_panel_collapsed(collapsed: bool) -> void:
	_battle_advice_panel_collapsed = collapsed
	_advice_panel_content.visible = not collapsed
```

The final overlay and docked-panel formatter should render all required response sections from the spec:

- `strategic_thesis`
- `current_turn_main_line`
- `conditional_branches`
- `prize_plan`
- `why_this_line`
- `risk_watchouts`
- `confidence`

`summary_for_next_request` must always be persisted back into the session even if the UI chooses to show it in a compact form.

Use the localized labels defined in the spec for the visible UI copy when implementing these sections.

- [ ] **Step 6: Hook service callbacks**
  - `status_changed` updates loading copy and control state
  - `advice_completed` stores latest result, re-enables controls, refreshes overlay, refreshes pinned panel
  - failed completions render the normalized error state and expose retry
  - rerun stays disabled while `_battle_advice_busy` is true

- [ ] **Step 7: Run the focused UI suite until it passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- PASS for the new AI advice UI tests

- [ ] **Step 8: Run all advice-focused suites plus the full runner**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_session_store.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_prompt_builder.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_context_builder.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_advice_service.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain res://tests/TestRunner.tscn
```

Expected:

- PASS for all new advice-focused suites
- PASS for the full test runner, or failures only in unrelated pre-existing suites that must be documented before merge

- [ ] **Step 9: Add one focused UI assertion for panel collapse/expand**

```gdscript
func test_ai_advice_panel_can_collapse_and_expand() -> String:
	var scene := _make_battle_scene_stub()
	scene.set("_advice_panel_content", RichTextLabel.new())
	scene.call("_set_advice_panel_collapsed", true)
	var content := scene.get("_advice_panel_content") as RichTextLabel
	if content.visible:
		return "Advice panel content should hide when collapsed"
	scene.call("_set_advice_panel_collapsed", false)
	return "" if content.visible else "Advice panel content should show again when expanded"
```

- [ ] **Step 10: Re-run the focused UI suite and confirm the new panel-state test passes**

Run:

```powershell
& "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_battle_ui_features.gd
```

Expected:

- PASS for button placement, busy-state, failure/retry, and panel collapse tests

- [ ] **Step 11: Commit**

```powershell
git add scenes/battle/BattleScene.gd scenes/battle/BattleScene.tscn tests/test_battle_ui_features.gd tests/TestRunner.gd
git commit -m "feat: add in-battle AI advice UI flow"
```

## Final Verification

- [ ] Run the focused advice suites again after the final UI commit.
- [ ] Run the full `TestRunner.tscn` suite and record the outcome.
- [ ] Manually verify in local two-player mode that:
  - `BtnAiAdvice` appears immediately left of `BtnZeusHelp`
  - pressing it opens the overlay
  - the button greys out while a request is in flight
  - the pinned panel updates after a successful response
  - a failed response preserves the last successful advice
- [ ] If all checks pass, use `superpowers:finishing-a-development-branch` before merge or handoff.
