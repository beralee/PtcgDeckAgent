class_name TestDeckExpertPlay
extends TestBase

const CATALOG_PATH := "res://scripts/training/expert/ExpertPlayCatalog.gd"
const STORE_PATH := "res://scripts/training/expert/ExpertPlayStore.gd"
const RECORDER_PATH := "res://scripts/training/expert/ExpertPlayRecorder.gd"
const StateFactory := preload("res://scripts/training/DeckTrainingStateFactory.gd")

class TeachingScene:
	extends Control
	var _btn_zeus_help := Button.new()
	var _btn_battle_discuss_ai := Button.new()
	var _pending_choice := ""
	func _init() -> void:
		add_child(_btn_zeus_help)
		add_child(_btn_battle_discuss_ai)
	func _maybe_run_ai() -> void:
		pass


func test_feedback_guide_preserves_existing_notes_and_ignores_an_empty_template() -> String:
	var path := "res://scripts/training/expert/ExpertFeedbackGuide.gd"
	if not ResourceLoader.exists(path):
		return "expert_feedback_guide_missing"
	var guide: Script = load(path)
	return run_checks([
		assert_true(guide.TEMPLATE.contains("目标：") and guide.TEMPLATE.contains("顺序：") and guide.TEMPLATE.contains("取舍：") and guide.TEMPLATE.contains("换打法条件：")),
		assert_eq(guide.insert_template("保留唯一恶能量"), "保留唯一恶能量"),
		assert_eq(guide.normalized_note(guide.TEMPLATE), ""),
		assert_eq(guide.normalized_note("目标：保住下一攻击手"), "目标：保住下一攻击手"),
	])


func test_feedback_draft_recovers_same_attempt_and_remains_unsubmitted() -> String:
	var catalog: Script = load(CATALOG_PATH)
	var store: Script = load(STORE_PATH)
	var recorder: RefCounted = load(RECORDER_PATH).new()
	if not recorder.has_method("pause_for_feedback") or not store.has_method("pending_feedback"):
		return "expert_feedback_recovery_missing"
	var scenario: Dictionary = catalog.load_catalog().scenarios[0]
	var built: Dictionary = StateFactory.build(scenario)
	var id: String = store.new_attempt_id()
	recorder.begin(scenario, built.gsm.game_state, id, false)
	recorder.pause_for_feedback(built.gsm.game_state)
	recorder.draft_feedback("discuss", "resource", "目标：留能量\n顺序：先取牌，再决定贴给谁")
	var saved: bool = store.save(recorder.document())
	var restored: RefCounted = load(RECORDER_PATH).new()
	var loaded := false
	for document: Dictionary in store.pending_feedback():
		if document.attempt_id == id:
			loaded = restored.restore_feedback(document)
	if not loaded:
		return "expert_feedback_draft_not_recoverable"
	var draft: Dictionary = restored.document()
	var integer_types_preserved := typeof(draft.schema_version) == TYPE_INT and typeof(draft.initial_public_state.turn.number) == TYPE_INT
	var malformed := draft.duplicate(true)
	malformed.initial_public_state.turn.number = 1.5
	var rejected_fraction: bool = not restored.restore_feedback(malformed)
	var submitted: Dictionary = restored.finish("discuss", "resource", str(draft.feedback.note), null)
	store.save(restored.document())
	var still_pending := false
	for document: Dictionary in store.pending_feedback():
		still_pending = still_pending or str(document.attempt_id) == id
	return run_checks([
		assert_true(saved), assert_eq(draft.status, "draft"),
		assert_true(integer_types_preserved, "Recovered JSON must retain the closed schema's integer number types"),
		assert_true(rejected_fraction, "Fractional public counters must not be rounded into a valid record"),
		assert_eq(draft.attempt_id, id), assert_eq(draft.feedback.note, "目标：留能量\n顺序：先取牌，再决定贴给谁"),
		assert_false(bool(draft.qualification.bc_eligible)), assert_true(bool(submitted.ok)),
		assert_eq(restored.document().final_public_state, draft.final_public_state),
		assert_false(still_pending),
	])


func test_feedback_keyboard_keeps_submit_footer_outside_the_scroll() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := TeachingScene.new()
	tree.root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog: Script = load(CATALOG_PATH)
	var scenario: Dictionary = catalog.load_catalog().scenarios[0]
	var built: Dictionary = StateFactory.build(scenario)
	var controller: RefCounted = load("res://scripts/training/expert/ExpertPlayController.gd").new()
	controller.setup(scene, built.gsm, scenario, built.snapshot)
	controller._on_intro_confirmed()
	controller._finish_segment()
	await tree.process_frame
	var form := scene.find_child("DeckTrainingResultOverlay", true, false)
	var scroll := form.find_child("ExpertFormScroll", true, false)
	var next := form.find_child("ExpertSubmitNext", true, false) as Button
	var checks: Array[String] = [assert_false(scroll.is_ancestor_of(next), "Save must stay outside the scrolling note content")]
	if not form.has_method("set_keyboard_height"):
		checks.append("expert_feedback_keyboard_layout_missing")
	else:
		var screen_scale := scene.get_viewport().get_screen_transform().get_scale().y
		var keyboard_height := roundi(scene.get_viewport_rect().size.y * screen_scale * 0.35)
		form.set_keyboard_height(keyboard_height)
		controller.apply_layout(scene.get_viewport_rect().size)
		await tree.process_frame
		await tree.process_frame
		checks.append(assert_true(next.get_global_rect().end.y <= scene.get_viewport_rect().size.y - float(keyboard_height) / screen_scale, "Save must fit above the software keyboard"))
		form.set_keyboard_height(0)
	controller.release()
	scene.queue_free()
	await tree.process_frame
	return run_checks(checks)


func test_recovered_feedback_ui_commits_focused_text_and_rejects_duplicate_submission() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var catalog: Script = load(CATALOG_PATH)
	var scenario: Dictionary = catalog.load_catalog().scenarios[0]
	var built: Dictionary = StateFactory.build(scenario)
	var recorder: RefCounted = load(RECORDER_PATH).new()
	recorder.begin(scenario, built.gsm.game_state, load(STORE_PATH).new_attempt_id(), false)
	recorder.pause_for_feedback(built.gsm.game_state)
	recorder.draft_feedback("discuss", "information", "目标：先取牌")
	var scene := TeachingScene.new()
	tree.root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var controller: RefCounted = load("res://scripts/training/expert/ExpertPlayController.gd").new()
	var restored: bool = controller.setup_feedback_recovery(scene, recorder.document())
	await tree.process_frame
	var note := scene.find_child("ExpertNote", true, false) as TextEdit
	var text_restored := note.text == "目标：先取牌"
	note.text = "目标：先取牌\n顺序：担架拿恶能量，再贴给愿增猿"
	note.grab_focus()
	var saved: bool = await controller._prepare_submission()
	var duplicate: bool = await controller._prepare_submission()
	var result: Dictionary = controller.get("_recorder").document()
	var checks := run_checks([
		assert_true(restored and text_restored), assert_true(saved), assert_false(duplicate),
		assert_false(note.has_focus()), assert_eq(result.feedback.note, note.text),
		assert_eq(result.attempt_id, recorder.document().attempt_id),
		assert_eq(result.final_public_state, recorder.document().final_public_state),
		assert_false(bool(result.qualification.bc_eligible)),
	])
	controller.release()
	scene.queue_free()
	await tree.process_frame
	return checks


func test_browser_recovery_modal_captures_note_touches_before_the_question_list() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var browser := (load("res://scenes/deck_training/ExpertPlayBrowser.tscn") as PackedScene).instantiate()
	tree.root.add_child(browser)
	await tree.process_frame
	var background_presses := [0]
	var background := Button.new()
	background.position = Vector2(5, 5)
	background.size = Vector2(70, 70)
	background.pressed.connect(func() -> void: background_presses[0] += 1)
	browser.add_child(background)
	var catalog: Script = load(CATALOG_PATH)
	var scenario: Dictionary = catalog.load_catalog().scenarios[0]
	var built: Dictionary = StateFactory.build(scenario)
	var recorder: RefCounted = load(RECORDER_PATH).new()
	recorder.begin(scenario, built.gsm.game_state, load(STORE_PATH).new_attempt_id(), false)
	recorder.pause_for_feedback(built.gsm.game_state)
	var controller: RefCounted = load("res://scripts/training/expert/ExpertPlayController.gd").new()
	controller.setup_feedback_recovery(browser, recorder.document())
	browser.set("_feedback_controller", controller)
	await tree.process_frame
	await tree.process_frame
	var note := browser.find_child("ExpertNote", true, false) as TextEdit
	var form := browser.find_child("DeckTrainingResultOverlay", true, false)
	var bridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
	var point := note.get_global_rect().get_center()
	var checks: Array[String] = [assert_eq(bridge.native_text_input_at_position(form, point), note), assert_eq(bridge.native_text_input_at_position(browser, point), note)]
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = point
	var old_emulation: Variant = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	browser._input(press)
	checks.append(assert_true(note.has_focus(), "The browser must not route a recovered note tap to the underlying question list"))
	press.position = Vector2(30, 30)
	browser._input(press)
	press.pressed = false
	browser._input(press)
	checks.append(assert_eq(background_presses[0], 0, "A modal must block the underlying browser even outside its panel"))
	press.pressed = true
	GameManager._input(press)
	press.pressed = false
	GameManager._input(press)
	checks.append(assert_eq(background_presses[0], 0, "The global non-battle button fallback must yield to the expert form"))
	form.hide()
	press.pressed = true
	GameManager._input(press)
	press.pressed = false
	GameManager._input(press)
	checks.append(assert_eq(background_presses[0], 1, "Hidden forms must not block ordinary browser input"))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", old_emulation)
	controller.release()
	browser.queue_free()
	await tree.process_frame
	return run_checks(checks)


func test_curriculum_uses_exact_185_deck_and_builds_every_position() -> String:
	if not ResourceLoader.exists(CATALOG_PATH):
		return "expert_play_catalog_missing"
	var catalog_script: Script = load(CATALOG_PATH)
	var catalog: Dictionary = catalog_script.load_catalog()
	var checks: Array[String] = [assert_true(catalog.errors.is_empty(), str(catalog.errors)), assert_eq(catalog.scenarios.size(), 36)]
	var families: Dictionary = {}
	for scenario: Dictionary in catalog.scenarios:
		checks.append(assert_eq(int(scenario.player_deck_id), 675701))
		checks.append(assert_false(scenario.has("validation_operations"), "Open teaching has no answer sequence"))
		families[scenario.family_id] = int(families.get(scenario.family_id, 0)) + 1
		var built: Dictionary = StateFactory.build(scenario)
		checks.append(assert_true(built.errors.is_empty(), "%s: %s" % [scenario.id, str(built.errors)]))
		var gsm: GameStateMachine = built.get("gsm")
		if gsm != null:
			checks.append(assert_eq(gsm.count_player_total_cards(0), 60))
			checks.append(assert_eq(gsm.count_player_total_cards(1), 60))
	for family: String in families:
		checks.append(assert_eq(int(families[family]), 3, family))
	return run_checks(checks)


func test_observation_and_export_never_copy_hidden_zones_or_action_payload() -> String:
	if not ResourceLoader.exists(RECORDER_PATH) or not ResourceLoader.exists(CATALOG_PATH):
		return "expert_play_recorder_missing"
	var catalog: Script = load(CATALOG_PATH)
	var built: Dictionary = StateFactory.build(catalog.load_catalog().scenarios[0])
	if not built.errors.is_empty():
		return str(built.errors)
	var recorder: RefCounted = load(RECORDER_PATH).new()
	var state: GameState = built.gsm.game_state
	recorder.begin(catalog.load_catalog().scenarios[0], state, "test-attempt", false)
	recorder.observe_action(GameAction.create(GameAction.ActionType.DRAW_CARD, 1, {"secret": "HIDDEN_SENTINEL", "card_ids": [999999]}, state.turn_number), state)
	var draft: Dictionary = recorder.document()
	var snapshot: Dictionary = draft.initial_public_state
	return run_checks([
		assert_false(snapshot.opponent.has("hand")),
		assert_false(snapshot.own.has("deck")),
		assert_false(snapshot.own.has("prizes")),
		assert_false(JSON.stringify(draft).contains("HIDDEN_SENTINEL")),
		assert_false(JSON.stringify(draft).contains("999999")),
		assert_false(bool(draft.qualification.bc_eligible)),
		assert_eq(str(draft.qualification.reason), "human_current_window_witness_missing"),
	])


func test_queue_interleaves_families_and_keeps_related_cases_in_one_split_group() -> String:
	if not ResourceLoader.exists(STORE_PATH) or not ResourceLoader.exists(CATALOG_PATH):
		return "expert_play_store_missing"
	var catalog: Script = load(CATALOG_PATH)
	var store: Script = load(STORE_PATH)
	var scenarios: Array = catalog.load_catalog().scenarios
	var queue: Array = store.choose_queue(scenarios, {}, 5)
	var families: Dictionary = {}
	var checks: Array[String] = [assert_eq(queue.size(), 5)]
	for id: String in queue:
		var scenario: Dictionary = catalog.get_scenario(id)
		checks.append(assert_false(families.has(scenario.family_id), "Five questions should vary the theme"))
		checks.append(assert_eq(scenario.split_group, "dragapult185-expert-v1"))
		families[scenario.family_id] = true
	return run_checks(checks)


func test_feedback_rejects_empty_confidence_and_cannot_promote_a_demo_to_bc() -> String:
	if not ResourceLoader.exists(RECORDER_PATH) or not ResourceLoader.exists(CATALOG_PATH):
		return "expert_play_recorder_missing"
	var catalog: Script = load(CATALOG_PATH)
	var scenario: Dictionary = catalog.load_catalog().scenarios[0]
	var built: Dictionary = StateFactory.build(scenario)
	var recorder: RefCounted = load(RECORDER_PATH).new()
	recorder.begin(scenario, built.gsm.game_state, "feedback-test", true)
	var rejected: Dictionary = recorder.finish("", "", "", built.gsm.game_state)
	var accepted: Dictionary = recorder.finish("confident", "resource", "保留唯一夜光给下一攻击手", built.gsm.game_state)
	return run_checks([
		assert_false(bool(rejected.ok)),
		assert_true(bool(accepted.ok)),
		assert_false(bool(recorder.document().qualification.bc_eligible)),
		assert_true(bool(recorder.document().exposure.repeated_position)),
		assert_eq(recorder.document().feedback.note, "保留唯一夜光给下一攻击手"),
	])


func test_draft_replacement_export_and_queue_survive_reload() -> String:
	var catalog: Script = load(CATALOG_PATH)
	var store: Script = load(STORE_PATH)
	var scenario: Dictionary = catalog.load_catalog().scenarios[0]
	var built: Dictionary = StateFactory.build(scenario)
	var recorder: RefCounted = load(RECORDER_PATH).new()
	var id: String = store.new_attempt_id()
	recorder.begin(scenario, built.gsm.game_state, id, false)
	var draft_saved: bool = store.save(recorder.document())
	recorder.finish("discuss", "resource", "这是测试进程内的隔离示范", built.gsm.game_state)
	var submitted_saved: bool = store.save(recorder.document())
	var data: Dictionary = store._read(store.ROOT + "/attempts/" + id + ".json")
	var exported: Dictionary = store.export_public()
	var queue_saved: bool = store.set_queue(["expert-dragapult185-01", "expert-dragapult185-04"])
	var advanced: bool = store.advance("expert-dragapult185-01")
	return run_checks([
		assert_true(draft_saved and submitted_saved, "Atomic replacement must work on Windows"),
		assert_eq(str(data.payload_json).sha256_text(), str(data.payload_sha256)),
		assert_eq(JSON.parse_string(data.payload_json).status, "submitted"),
		assert_true(bool(exported.ok)),
		assert_true(FileAccess.file_exists(str(exported.path))),
		assert_true(queue_saved and advanced),
		assert_eq(store.queue_state().remaining, ["expert-dragapult185-04"]),
	])


func test_engine_attachment_is_recorded_and_feedback_is_required_before_submission() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := TeachingScene.new()
	tree.root.add_child(scene)
	var catalog: Script = load(CATALOG_PATH)
	var scenario: Dictionary = catalog.get_scenario("expert-dragapult185-01")
	var built: Dictionary = StateFactory.build(scenario)
	var controller: RefCounted = load("res://scripts/training/expert/ExpertPlayController.gd").new()
	controller.setup(scene, built.gsm, scenario, built.snapshot)
	controller._on_intro_confirmed()
	built.gsm.action_logged.connect(controller.on_action_logged)
	var own: PlayerState = built.gsm.game_state.players[0]
	var energy: CardInstance
	for card: CardInstance in own.hand:
		if card.card_data.get_uid() == "CSV1C_127":
			energy = card
	var applied: bool = built.gsm.attach_energy(0, energy, own.bench[0])
	controller._finish_segment()
	await tree.process_frame
	var first_submit: bool = controller._submit()
	var confidence := scene.find_child("ExpertConfidence", true, false) as OptionButton
	var note := scene.find_child("ExpertNote", true, false) as TextEdit
	var native_note: bool = note != null and note.virtual_keyboard_enabled and note.virtual_keyboard_show_on_focus and bool(note.get_meta(preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd").NATIVE_TEXT_INPUT_META, false))
	var form := scene.find_child("DeckTrainingResultOverlay", true, false)
	var form_routed: bool = form != null and form.get_script().resource_path == "res://scripts/training/expert/ExpertPlayFormOverlay.gd"
	if confidence != null:
		preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd").emit_button_pressed_once(confidence)
		form_routed = form_routed and confidence.get_popup().visible
		confidence.get_popup().hide()
		confidence.select(1)
	var submitted: bool = controller._submit()
	var record: Dictionary = controller.get("_recorder").document()
	var attachment_seen := false
	for event: Dictionary in record.events:
		if int(event.event_type) == GameAction.ActionType.ATTACH_ENERGY:
			attachment_seen = event.checkpoint_after_event.own.bench[0].energy_count == 1
	var checks := run_checks([
		assert_true(applied),
		assert_true(attachment_seen, "Must witness the actual engine attachment, not a proposed action"),
		assert_false(first_submit),
		assert_true(submitted),
		assert_true(form_routed, "The expert form must use the popup-aware touch router"),
		assert_true(native_note, "Android notes must request the native keyboard on touch focus"),
		assert_false(bool(record.qualification.bc_eligible)),
	])
	controller.release()
	scene.queue_free()
	await tree.process_frame
	return checks


func test_export_can_be_copied_to_a_user_selected_file_without_changing_bytes() -> String:
	var path := "res://scripts/training/expert/ExpertPlayExportAdapter.gd"
	if not ResourceLoader.exists(path):
		return assert_true(false, "Android needs a user-selected file export, not an internal path")
	var adapter: Script = load(path)
	var source := "user://expert-export-source.jsonl"
	var destination := "user://expert-export-selected.jsonl"
	var payload := "{\"format\":\"ptcg_expert_play_export_v1\"}\n多龙专家示范\n"
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(payload)
	file.close()
	var result: Dictionary = adapter.copy_export(source, destination)
	var missing: Dictionary = adapter.copy_export("user://missing-expert-export.jsonl", destination)
	return run_checks([
		assert_true(bool(result.ok)),
		assert_eq(FileAccess.get_file_as_string(destination), payload),
		assert_false(bool(missing.ok)),
		assert_eq(FileAccess.get_sha256(source), FileAccess.get_sha256(destination)),
	])


func test_expert_browser_and_legacy_catalog_coexist() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var browser := (load("res://scenes/deck_training/ExpertPlayBrowser.tscn") as PackedScene).instantiate()
	tree.root.add_child(browser)
	await tree.process_frame
	await tree.process_frame
	var checks := run_checks([
		assert_true(browser.find_child("ExpertStartFive", true, false) != null),
		assert_true(browser.has_method("_set_battle_ready"), "Cold Android launch must keep start disabled until the battle scene is ready"),
		assert_eq(browser.find_children("ExpertPlay_expert-*", "Button", true, false).size(), 36),
		assert_eq(preload("res://scripts/training/DeckTrainingCatalog.gd").list_scenarios().size(), 70),
		assert_eq(preload("res://scripts/training/DeckTrainingCatalog.gd").get_scenario("expert-dragapult185-01").player_deck_id, 675701),
	])
	if browser.has_method("_set_battle_ready"):
		browser._set_battle_ready(false)
		checks += assert_true((browser.find_child("ExpertStartFive", true, false) as Button).disabled)
		browser._set_battle_ready(true)
		checks += assert_false((browser.find_child("ExpertStartFive", true, false) as Button).disabled)
	browser.queue_free()
	await tree.process_frame
	return checks
