class_name TestPublicReplayVerticalSlice
extends TestBase

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const CaptureScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd")
const PresentationScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayPresentation.gd")
const StoreScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayStore.gd")
const ServiceContractScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd"
)
const ViewerScene = preload("res://scenes/ptcgdap_public_replay/PublicReplayViewer.tscn")
const FixtureFactoryScript = preload(
	"res://tests/ptcgdap/godot/support/PublicReplayFixtureFactory.gd"
)

const SHA_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const SHA_B := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
const SHA_C := "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
const SHA_D := "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"


func _contract_owner() -> Variant:
	var loaded := ContractScript.load_default()
	return loaded.get("owner") if bool(loaded.get("accepted", false)) else null


func _envelope(match_id: String = "csp-wp1-unit-match") -> Dictionary:
	return {
		"document_type": "match_envelope_v1",
		"schema_version": 1,
		"match_id": match_id,
		"lane": "developer_local",
		"evaluator_id": "ptcgdap-csp-wp1-local-capture",
		"participants": [
			{
				"participant_kind": "strategy_release",
				"strategy_id": "ptcgdap.marnie.18.0.package-local-v1",
				"release_version": "0.1.0",
				"package_id": "ptcgdap.marnie.windows-local",
				"archive_sha256": "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E",
				"manifest_canonical_sha256": SHA_A,
				"deck_identity": {
					"domain": "godot_local_card_uid_v1",
					"deck_id": "800018501",
					"deck_sha256": SHA_B,
				},
				"policy_package_sha256": SHA_C,
			},
			{
				"participant_kind": "platform_baseline",
				"baseline_id": "rules-only-575720",
				"baseline_version": "1.0.0",
				"baseline_sha256": SHA_D,
			},
		],
		"engine_sha256": SHA_A,
		"rules_sha256": SHA_B,
		"card_catalog_sha256": SHA_C,
		"host_contract_sha256": SHA_D,
		"runtime_manifest_sha256": SHA_A,
		"evaluation_profile_id": "csp-wp1-marnie-development-v1",
		"evaluation_profile_sha256": SHA_B,
		"seat_assignment": [1, 0],
		"seed_commitment": {
			"capability": "deterministic_seed_v1",
			"commitment_sha256": SHA_C,
			"disclosure": "withheld",
		},
		"replay_visibility_profile": "public_at_event_time_v1",
		"started_at_utc": "2026-08-18T00:00:00Z",
	}


func _source(match_id: String, turn_number: int, phase: String = "setup") -> Dictionary:
	var board: Array[Dictionary] = []
	var public_cards: Array[Dictionary] = []
	if phase == "main":
		board = [
			{
				"seat": 0, "zone": "active", "slot": 0, "card_uid": "CSV8C_094",
				"card_serial": 101, "damage": 30, "status": ["poisoned"],
			},
			{
				"seat": 0, "zone": "bench", "slot": 0, "card_uid": "CSV9.5C_043",
				"card_serial": 102, "damage": 0, "status": [],
			},
			{
				"seat": 1, "zone": "active", "slot": 0, "card_uid": "CSV7C_059",
				"card_serial": 201, "damage": 20, "status": ["asleep"],
			},
			{
				"seat": 1, "zone": "stadium", "slot": 0, "card_uid": "CSV10C_216",
				"card_serial": 202, "damage": 0, "status": [],
			},
		]
		public_cards = [
			{"seat": 0, "zone": "discard", "card_uid": "SVP_105", "card_serial": 103},
			{"seat": 1, "zone": "lost_zone", "card_uid": "CSV8C_094", "card_serial": 203},
		]
	return {
		"source_authority": "ptcgdap_author_public_owner_v1",
		"match_id": match_id,
		"turn_number": turn_number,
		"phase": phase,
		"acting_seat": 1,
		"public_state": {
			"zone_counts": [
				{"seat": 0, "hand_count": 7, "deck_count": 47, "prize_count": 6},
				{"seat": 1, "hand_count": 7, "deck_count": 47, "prize_count": 6},
			],
			"board": board,
			"public_cards": public_cards,
		},
	}


func _completed_replay(match_id: String = "csp-wp1-unit-match") -> Dictionary:
	var owner: Variant = _contract_owner()
	if owner == null:
		return {}
	var created: Dictionary = CaptureScript.create(
		owner, _envelope(match_id), "csp-wp1-unit-replay", SHA_B, SHA_C
	)
	if not bool(created.get("accepted", false)):
		created["envelope_validation"] = owner.validate_document(_envelope(match_id))
		return created
	var capture: Variant = created.get("capture")
	var first: Dictionary = capture.append_public_source(_source(match_id, 0), "match_started")
	if not bool(first.get("accepted", false)):
		return first
	var second: Dictionary = capture.append_public_source(_source(match_id, 1, "main"), "state_progressed")
	if not bool(second.get("accepted", false)):
		return second
	return capture.finish(_source(match_id, 1, "terminal"))


func _completed_replay_with_main_source(match_id: String, main_source: Dictionary) -> Dictionary:
	var owner: Variant = _contract_owner()
	var created: Dictionary = CaptureScript.create(
		owner, _envelope(match_id), "replay-%s" % match_id, SHA_B, SHA_C
	)
	if not bool(created.get("accepted", false)):
		return created
	var capture: Variant = created.get("capture")
	var started: Dictionary = capture.append_public_source(_source(match_id, 0), "match_started")
	if not bool(started.get("accepted", false)):
		return started
	var progressed: Dictionary = capture.append_public_source(main_source, "state_progressed")
	if not bool(progressed.get("accepted", false)):
		return progressed
	return capture.finish(_source(match_id, 1, "terminal"))


func test_capture_builds_valid_public_chain_and_read_only_presentation() -> String:
	var completed := _completed_replay()
	if not bool(completed.get("accepted", false)):
		return "capture failed: %s" % completed
	var artifact: Dictionary = completed.get("artifact", {})
	var owner: Variant = _contract_owner()
	var replay_check: Dictionary = owner.validate_replay(artifact.manifest, artifact.frames)
	var opened: Dictionary = PresentationScript.create(owner, artifact.manifest, artifact.frames)
	if not bool(opened.get("accepted", false)):
		return "presentation rejected valid replay: %s" % opened
	var presentation: Variant = opened.get("presentation")
	var first: Dictionary = presentation.current_view()
	presentation.last()
	var last: Dictionary = presentation.current_view()
	var audit: Dictionary = presentation.audit_snapshot()
	return run_checks([
		assert_true(bool(replay_check.get("accepted", false))),
		assert_eq(artifact.frames.size(), 3),
		assert_eq(first.get("event_kind"), "match_started"),
		assert_eq(last.get("event_kind"), "match_finished"),
		assert_eq(last.get("ordinal"), 2),
		assert_false(bool(audit.get("authoritative", true))),
		assert_eq(audit.get("grants"), []),
		assert_eq(audit.get("engine_invocations"), 0),
		assert_eq(audit.get("ticket_invocations"), 0),
		assert_eq(audit.get("callback_invocations"), 0),
	])


func test_private_search_hidden_and_unattested_sources_fail_closed() -> String:
	var owner: Variant = _contract_owner()
	var forbidden := ["hand", "deck", "prizes", "search_begin_input", "private_rng_state", "engine_object"]
	var checks: Array[String] = []
	for key: String in forbidden:
		var match_id := "csp-wp1-private-%s" % key.replace("_", "-")
		var created: Dictionary = CaptureScript.create(owner, _envelope(match_id), "replay-%s" % match_id, SHA_B, SHA_C)
		var source := _source(match_id, 0)
		source.public_state[key] = ["PRIVATE_SENTINEL"]
		var result: Dictionary = created.get("capture").append_public_source(source, "match_started")
		checks.append(assert_eq(result.get("error_code"), "private_field_forbidden", key))
		checks.append(assert_false(JSON.stringify(result).contains("PRIVATE_SENTINEL"), key))
	var unattested_created: Dictionary = CaptureScript.create(owner, _envelope("csp-wp1-unattested"), "replay-unattested", SHA_B, SHA_C)
	var unattested := _source("csp-wp1-unattested", 0)
	unattested.source_authority = "private_snapshot_sanitizer"
	checks.append(assert_eq(
		unattested_created.get("capture").append_public_source(unattested, "match_started").get("error_code"),
		"public_source_unattested"
	))
	return run_checks(checks)


func test_capture_rejects_duplicate_start_nonterminal_finish_and_path_unsafe_store() -> String:
	var owner: Variant = _contract_owner()
	var match_id := "csp-wp1-sequence-match"
	var created: Dictionary = CaptureScript.create(
		owner, _envelope(match_id), "csp-wp1-sequence-replay", SHA_B, SHA_C
	)
	var capture: Variant = created.get("capture")
	var first: Dictionary = capture.append_public_source(_source(match_id, 0), "match_started")
	var duplicate_start: Dictionary = capture.append_public_source(_source(match_id, 0), "match_started")
	var nonterminal_finish: Dictionary = capture.finish(_source(match_id, 0, "main"))
	return run_checks([
		assert_true(bool(first.get("accepted", false))),
		assert_eq(duplicate_start.get("error_code"), "replay_event_sequence_invalid"),
		assert_eq(nonterminal_finish.get("error_code"), "replay_event_sequence_invalid"),
		assert_eq(StoreScript.create(owner, "../private-records").get("error_code"), "storage_namespace_invalid"),
	])


func test_tamper_missing_reorder_jump_turn_and_old_schema_fail_closed() -> String:
	var completed := _completed_replay("csp-wp1-negative-match")
	if not bool(completed.get("accepted", false)):
		return "fixture failed: %s" % completed
	var artifact: Dictionary = completed.artifact
	var owner: Variant = _contract_owner()
	var tampered: Array = artifact.frames.duplicate(true)
	tampered[1].public_state.zone_counts[0].hand_count = 99
	var missing: Array = artifact.frames.duplicate(true)
	missing.remove_at(1)
	var reordered: Array = artifact.frames.duplicate(true)
	var swap: Variant = reordered[1]
	reordered[1] = reordered[2]
	reordered[2] = swap
	var jumped: Array = artifact.frames.duplicate(true)
	jumped[1].turn_number = 3
	jumped[1].previous_frame_sha256 = ContractScript.frame_hash(jumped[0])
	jumped[2].previous_frame_sha256 = ContractScript.frame_hash(jumped[1])
	var jump_manifest: Dictionary = artifact.manifest.duplicate(true)
	jump_manifest.first_frame_sha256 = ContractScript.frame_hash(jumped[0])
	jump_manifest.frame_chain_root_sha256 = ContractScript.frame_hash(jumped[2])
	var old_schema: Array = artifact.frames.duplicate(true)
	old_schema[0].schema_version = 0
	return run_checks([
		assert_false(bool(PresentationScript.create(owner, artifact.manifest, tampered).get("accepted", false))),
		assert_false(bool(PresentationScript.create(owner, artifact.manifest, missing).get("accepted", false))),
		assert_false(bool(PresentationScript.create(owner, artifact.manifest, reordered).get("accepted", false))),
		assert_eq(PresentationScript.create(owner, jump_manifest, jumped).get("error_code"), "replay_turn_transition_invalid"),
		assert_eq(PresentationScript.create(owner, artifact.manifest, old_schema).get("error_code"), "schema_unsupported"),
	])


func test_visual_projection_rejects_duplicate_or_noncanonical_battle_slots() -> String:
	var duplicate_source := _source("csp-wp1-duplicate-slot", 1, "main")
	var duplicate_entry: Dictionary = duplicate_source.public_state.board[0].duplicate(true)
	duplicate_entry.card_serial = 999
	duplicate_entry.card_uid = "CSV10C_148"
	duplicate_source.public_state.board.append(duplicate_entry)
	var duplicate_replay := _completed_replay_with_main_source(
		"csp-wp1-duplicate-slot", duplicate_source
	)
	if not bool(duplicate_replay.get("accepted", false)):
		return "duplicate replay fixture failed before presentation: %s" % duplicate_replay
	var invalid_slot_source := _source("csp-wp1-invalid-active-slot", 1, "main")
	invalid_slot_source.public_state.board[0].slot = 1
	var invalid_slot_replay := _completed_replay_with_main_source(
		"csp-wp1-invalid-active-slot", invalid_slot_source
	)
	if not bool(invalid_slot_replay.get("accepted", false)):
		return "invalid-slot replay fixture failed before presentation: %s" % invalid_slot_replay
	var owner: Variant = _contract_owner()
	return run_checks([
		assert_eq(
			PresentationScript.create(
				owner, duplicate_replay.artifact.manifest, duplicate_replay.artifact.frames
			).get("error_code"),
			"replay_visual_projection_invalid"
		),
		assert_eq(
			PresentationScript.create(
				owner, invalid_slot_replay.artifact.manifest, invalid_slot_replay.artifact.frames
			).get("error_code"),
			"replay_visual_projection_invalid"
		),
	])


func test_store_index_load_and_isolated_viewer_consume_only_validated_frames() -> String:
	var completed := _completed_replay("csp-wp1-store-match")
	if not bool(completed.get("accepted", false)):
		return "fixture failed: %s" % completed
	var owner: Variant = _contract_owner()
	var storage_namespace := "focused-%d" % Time.get_ticks_usec()
	var store_created: Dictionary = StoreScript.create(owner, storage_namespace)
	if not bool(store_created.get("accepted", false)):
		return "store create failed: %s" % store_created
	var store: Variant = store_created.get("store")
	var saved: Dictionary = store.save_completed(completed.artifact)
	var loaded: Dictionary = store.load_replay(completed.artifact.manifest.replay_id)
	var index: Dictionary = store.list_index()
	var viewer: Control = ViewerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewer)
	await tree.process_frame
	var shown: Dictionary = viewer.load_public_replay(owner, loaded.artifact.manifest, loaded.artifact.frames)
	var before: Dictionary = viewer.current_view()
	viewer.show_next()
	var after: Dictionary = viewer.current_view()
	var visual: Dictionary = viewer.visual_snapshot()
	var rendered_position := str(viewer.get_node("TopBar/TopBarRow/TopBarCenter/LblTurn").text)
	var rendered_event := str(viewer.get_node("TopBar/TopBarRow/TopBarLeft/LblPhase").text)
	var battle_scene_visual_source := str(viewer.get_meta("battle_scene_visual_source", ""))
	var has_opponent_field := viewer.has_node("MainArea/CenterField/FieldArea/OppField")
	var has_player_field := viewer.has_node("MainArea/CenterField/FieldArea/MyField")
	var occupied_bench_panel := viewer.find_child("MyBench0", true, false) as PanelContainer
	var empty_bench_panel := viewer.find_child("MyBench1", true, false) as PanelContainer
	var occupied_bench := (
		occupied_bench_panel.find_children("*", "BattleCardView", true, false).front() as Control
		if occupied_bench_panel != null
		and not occupied_bench_panel.find_children("*", "BattleCardView", true, false).is_empty()
		else null
	)
	var empty_bench := (
		empty_bench_panel.find_children("*", "BattleCardView", true, false).front() as Control
		if empty_bench_panel != null
		and not empty_bench_panel.find_children("*", "BattleCardView", true, false).is_empty()
		else null
	)
	var occupied_bench_alpha := occupied_bench.self_modulate.a if occupied_bench != null else -1.0
	var empty_bench_alpha := empty_bench.self_modulate.a if empty_bench != null else -1.0
	var battle_backdrop := viewer.find_child("BattleBackdrop", true, false) as TextureRect
	var replay_backdrop := viewer.find_child("PublicReplayBattleBackdrop", true, false)
	var hand_scroll := viewer.find_child("HandScroll", true, false) as ScrollContainer
	var has_battle_backdrop := battle_backdrop != null
	var has_replay_backdrop := replay_backdrop != null
	var hand_scroll_visible := hand_scroll != null and hand_scroll.visible
	var hand_container := viewer.find_child("HandContainer", true, false) as HBoxContainer
	var battle_ui_mode := str(viewer.get_meta("battle_ui_mode", ""))
	var public_hand_cards := 0
	if hand_container != null:
		for child: Node in hand_container.get_children():
			if child is BattleCardView:
				public_hand_cards += 1
	var visible_buttons: Array[String] = []
	for child: Node in viewer.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.is_visible_in_tree():
			visible_buttons.append(button.name)
	visible_buttons.sort()
	tree.root.remove_child(viewer)
	viewer.free()
	return run_checks([
		assert_true(bool(saved.get("accepted", false))),
		assert_eq(store.save_completed(completed.artifact).get("error_code"), "replay_exists"),
		assert_true(bool(loaded.get("accepted", false))),
		assert_eq(index.get("entries", []).size(), 1),
		assert_true(bool(shown.get("accepted", false))),
		assert_eq(before.get("ordinal"), 0),
		assert_eq(after.get("event_kind"), "state_progressed"),
		assert_eq(after.get("ordinal"), 1),
		assert_false(bool(after.get("execution_authority", true))),
		assert_true(rendered_position.contains("2 / 3"), rendered_position),
		assert_true(rendered_event.contains("state_progressed"), rendered_event),
		assert_eq(battle_scene_visual_source, "res://scenes/battle/BattleScene.tscn"),
		assert_true(has_opponent_field),
		assert_true(has_player_field),
		assert_eq(occupied_bench_alpha, 1.0),
		assert_true(empty_bench_alpha > 0.0 and empty_bench_alpha < 0.5),
		assert_eq(visible_buttons, [
			"BtnBack", "BtnReplayNextTurn", "BtnReplayPlayPause",
			"BtnReplayPrevTurn", "OptReplaySpeed",
		]),
		assert_true(has_battle_backdrop, "shared BattleBackdrop must be installed"),
		assert_false(has_replay_backdrop, "replay must not install an alternate battle backdrop"),
		assert_true(hand_scroll_visible, "shared battle hand rail must remain visible"),
		assert_eq(public_hand_cards, 7, "public hand counts use the normal battle hand rail"),
		assert_eq(battle_ui_mode, "battle_scene_read_only_timeline"),
		assert_eq(visual.get("slots", {}).get("my_active", {}).get("card_uid"), "CSV8C_094"),
		assert_eq(visual.get("slots", {}).get("my_active", {}).get("damage"), 30),
		assert_eq(visual.get("slots", {}).get("opp_active", {}).get("status"), ["asleep"]),
		assert_eq(visual.get("stadium_card_uid"), "CSV10C_216"),
		assert_eq(visual.get("discard_counts"), {0: 1, 1: 0}),
		assert_eq(visual.get("lost_zone_counts"), {0: 0, 1: 1}),
	])


func test_battle_scene_public_player_autoplays_at_selected_speed_and_never_gains_engine_authority() -> String:
	var completed := _completed_replay("csp-wp1-battle-player")
	if not bool(completed.get("accepted", false)):
		return "fixture failed: %s" % completed
	var viewer: Control = ViewerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewer)
	await tree.process_frame
	var opened: Dictionary = viewer.load_public_replay(
		_contract_owner(), completed.artifact.manifest, completed.artifact.frames
	)
	var at_first: Dictionary = viewer.player_snapshot()
	var speed_control := viewer.get_node("TopBar/TopBarRow/TopBarRight/TopBarActions/OptReplaySpeed") as OptionButton
	var initial_speed_index := speed_control.selected if speed_control != null else -1
	var speed_result: Dictionary = viewer.set_playback_speed(4.0)
	(viewer.get_node("TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPlayPause") as Button).pressed.emit()
	var while_playing: Dictionary = viewer.player_snapshot()
	viewer.advance_playback(float(while_playing.get("frame_interval_seconds", 0.5)) / 4.0 + 0.001)
	var at_second: Dictionary = viewer.player_snapshot()
	viewer.pause()
	viewer.advance_playback(10.0)
	var while_paused: Dictionary = viewer.player_snapshot()
	(viewer.get_node("TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPrevTurn") as Button).pressed.emit()
	var back_at_first: Dictionary = viewer.player_snapshot()
	viewer.play()
	viewer.advance_playback(100.0)
	var at_end: Dictionary = viewer.player_snapshot()
	var finished_play_text := (viewer.get_node("TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPlayPause") as Button).text
	var audit: Dictionary = viewer.presentation_audit()
	var forbidden_runtime_names := [
		"GameStateMachine", "BtnReplayContinue", "BtnEndTurn", "HudEndTurnBtn",
		"BtnStadiumAction", "DialogConfirm", "DialogCancel",
	]
	var forbidden_visible: Array[String] = []
	for node_name: String in forbidden_runtime_names:
		var node := viewer.find_child(node_name, true, false) as CanvasItem
		if node != null and node.is_visible_in_tree():
			forbidden_visible.append(node_name)
	tree.root.remove_child(viewer)
	viewer.free()
	return run_checks([
		assert_true(bool(opened.get("accepted", false))),
		assert_eq(at_first.get("ordinal"), 0),
		assert_eq(at_first.get("playback_speed"), 2.0),
		assert_eq(initial_speed_index, 2),
		assert_true(bool(at_first.get("previous_disabled", false))),
		assert_false(bool(at_first.get("next_disabled", true))),
		assert_true(bool(speed_result.get("accepted", false))),
		assert_eq(while_playing.get("playback_speed"), 4.0),
		assert_true(bool(while_playing.get("is_playing", false))),
		assert_eq(at_second.get("ordinal"), 1),
		assert_eq(while_paused.get("ordinal"), 1),
		assert_false(bool(while_paused.get("is_playing", true))),
		assert_eq(back_at_first.get("ordinal"), 0),
		assert_eq(at_end.get("ordinal"), 2),
		assert_true(bool(at_end.get("next_disabled", false))),
		assert_false(bool(at_end.get("is_playing", true))),
		assert_eq(finished_play_text, "↻ 重头播放"),
		assert_eq(at_end.get("speed_options"), [0.5, 1.0, 2.0, 4.0]),
		assert_eq(forbidden_visible, []),
		assert_eq(audit.get("navigation_policy"), "timeline_autoplay_manual_step"),
		assert_false(bool(audit.get("authoritative", true))),
		assert_eq(audit.get("engine_invocations"), 0),
		assert_eq(audit.get("ticket_invocations"), 0),
		assert_eq(audit.get("callback_invocations"), 0),
		assert_eq(audit.get("grants"), []),
	])


func test_real_156_frame_replay_uses_strategy_seat_and_responsive_battle_layout() -> String:
	var source_path := "res://artifacts/ptcgdap/csp_wp1/marnie_public_replay_acceptance.json"
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not decoded is Dictionary or not decoded.get("artifact") is Dictionary:
		return "real public replay fixture could not be decoded"
	var artifact: Dictionary = ServiceContractScript.coerce_integral_numbers(decoded.artifact)
	var source_before := JSON.stringify(artifact)
	var viewer: Control = ViewerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewer)
	await tree.process_frame
	var opened: Dictionary = viewer.load_public_replay(
		_contract_owner(), artifact.manifest, artifact.frames, artifact.match_envelope
	)
	viewer.show_next()
	viewer.show_next()
	var view: Dictionary = viewer.current_view()
	var visual: Dictionary = viewer.visual_snapshot()
	var audit: Dictionary = viewer.presentation_audit()
	viewer.size = Vector2(540, 900)
	viewer.call("_apply_replay_layout_for_size", Vector2(540, 900))
	await tree.process_frame
	var compact_mode := str(viewer.get_meta("public_replay_layout_mode", ""))
	var compact_log_visible := (viewer.find_child("LogPanel", true, false) as CanvasItem).visible
	var portrait_controls_inside := true
	var portrait_control_geometry: Dictionary = {}
	for control_name: String in [
		"BtnReplayPrevTurn", "BtnReplayPlayPause", "BtnReplayNextTurn",
		"OptReplaySpeed", "BtnBack",
	]:
		var control := viewer.find_child(control_name, true, false) as Control
		portrait_control_geometry[control_name] = (
			control.get_global_rect() if control != null else Rect2()
		)
		portrait_controls_inside = (
			portrait_controls_inside
			and control != null
			and control.visible
			and control.get_global_rect().end.x <= 541.0
			and control.get_global_rect().position.x >= -1.0
		)
	viewer.size = Vector2(1280, 720)
	viewer.call("_apply_replay_layout_for_size", Vector2(1280, 720))
	await tree.process_frame
	var full_mode := str(viewer.get_meta("public_replay_layout_mode", ""))
	var full_log_visible := (viewer.find_child("LogPanel", true, false) as CanvasItem).visible
	var source_after := JSON.stringify(artifact)
	tree.root.remove_child(viewer)
	viewer.free()
	return run_checks([
		assert_true(bool(opened.get("accepted", false))),
		assert_eq(view.get("frame_count"), 156),
		assert_eq(view.get("ordinal"), 2),
		assert_eq(audit.get("view_seat"), 1),
		assert_eq(visual.get("view_seat"), 1),
		assert_eq(visual.get("slots", {}).get("my_active", {}).get("card_uid"), "CSV10C_007"),
		assert_eq(visual.get("slots", {}).get("opp_active", {}).get("card_uid"), "CS6.5C_020"),
		assert_eq(compact_mode, "portrait"),
		assert_false(compact_log_visible),
		assert_true(
			portrait_controls_inside,
			"all replay controls must fit the portrait safe width: %s" % portrait_control_geometry
		),
		assert_eq(full_mode, "landscape"),
		assert_true(full_log_visible),
		assert_eq(source_after, source_before, "viewer must not mutate validated public frames"),
		assert_eq(audit.get("engine_invocations"), 0),
	])


func test_tracked_marnie_replay_steps_every_frame_without_engine_authority() -> String:
	var artifact: Dictionary = FixtureFactoryScript.load_developer_artifact()
	if artifact.is_empty():
		return "tracked Marnie public replay fixture could not be decoded"
	var viewer: Control = ViewerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewer)
	await tree.process_frame
	var opened: Dictionary = viewer.load_public_replay(
		_contract_owner(), artifact.manifest, artifact.frames, artifact.match_envelope
	)
	if not bool(opened.get("accepted", false)):
		tree.root.remove_child(viewer)
		viewer.free()
		return "tracked Marnie public replay rejected: %s" % opened
	viewer.set_playback_speed(4.0)
	viewer.play()
	viewer.advance_playback(1000.0)
	var final_view: Dictionary = viewer.current_view()
	var final_visual: Dictionary = viewer.visual_snapshot()
	var audit: Dictionary = viewer.presentation_audit()
	var player: Dictionary = viewer.player_snapshot()
	tree.root.remove_child(viewer)
	viewer.free()
	return run_checks([
		assert_eq(player.get("autoplay_advance_count"), 155),
		assert_eq(final_view.get("frame_count"), 156),
		assert_eq(final_view.get("ordinal"), 155),
		assert_eq(final_view.get("event_kind"), "match_finished"),
		assert_eq(final_visual.get("view_seat"), 1),
		assert_eq(final_visual.get("slots", {}).get("my_active", {}).get("card_uid"), "CSV10C_148"),
		assert_true(final_visual.get("slots", {}).get("opp_active", {}).is_empty()),
		assert_eq(final_visual.get("stadium_card_uid"), "CSV10C_216"),
		assert_true(bool(player.get("next_disabled", false))),
		assert_false(bool(player.get("previous_disabled", true))),
		assert_eq(audit.get("engine_invocations"), 0),
		assert_eq(audit.get("ticket_invocations"), 0),
		assert_eq(audit.get("callback_invocations"), 0),
		assert_eq(audit.get("grants"), []),
	])


func test_store_load_and_index_fail_closed_after_artifact_tamper() -> String:
	var completed := _completed_replay("csp-wp1-store-tamper-match")
	if not bool(completed.get("accepted", false)):
		return "fixture failed: %s" % completed
	var owner: Variant = _contract_owner()
	var storage_namespace := "tamper-%d" % Time.get_ticks_usec()
	var store_created: Dictionary = StoreScript.create(owner, storage_namespace)
	var store: Variant = store_created.get("store")
	var saved: Dictionary = store.save_completed(completed.artifact)
	if not bool(saved.get("accepted", false)):
		return "save failed: %s" % saved
	var tampered: Dictionary = completed.artifact.duplicate(true)
	tampered.frames[1].public_state.zone_counts[0].hand_count = 999
	var replay_id := str(completed.artifact.manifest.replay_id)
	var path := "user://ptcgdap/public_replays/%s/artifacts/%s.json" % [
		storage_namespace, replay_id,
	]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "unable to open isolated tamper fixture"
	file.store_string(JSON.stringify(tampered))
	file.close()
	return run_checks([
		assert_false(bool(store.load_replay(replay_id).get("accepted", false))),
		assert_eq(store.list_index().get("error_code"), "replay_index_invalid"),
	])
