class_name MarniePackageDevelopmentAIOpponent
extends "res://tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd"

const DevelopmentPolicyScript = preload("res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd")
const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const DEV_PROFILE_ID := "ptcgdap-marnie-package-development-frame-v1"
const DEV_STRATEGY_ID := "ptcgdap.marnie.18.0.package-local-v1"
const DEV_PACKAGE_ID := "ptcgdap.marnie.windows-local"
const DEV_PACKAGE_VERSION := "0.1.0"
const DEV_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"

var _package_policy: Variant = null
var _package_pins: Dictionary = {}
var _package_bound := false


func bind_package_match(next_gsm: GameStateMachine, handle: Variant) -> Dictionary:
	if OS.get_name() != "Windows":
		return {"ok": false, "error_code": "development_platform_not_authorized"}
	if _package_bound or handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return {"ok": false, "error_code": "package_integrity_invalid"}
	var pins: Dictionary = handle.to_public_dict()
	var pin_error := _candidate_pin_error(pins)
	if not pin_error.is_empty():
		return {"ok": false, "error_code": pin_error}
	if next_gsm == null or next_gsm.game_state == null or player_index not in [0, 1]:
		return {"ok": false, "error_code": "invalid_bind"}
	var inventory_error := _deck_inventory_error(
		next_gsm.game_state.players[player_index],
		handle.local_deck_snapshot()
	)
	if not inventory_error.is_empty():
		return {"ok": false, "error_code": inventory_error}
	var base_bind: Dictionary = bind_public_match(next_gsm, "gdscript-package-local")
	if not bool(base_bind.get("ok", false)):
		return base_bind
	var match_id := "marnie.dev.%d.%d" % [int(base_bind.get("match_generation", -1)), player_index]
	var created: Dictionary = DevelopmentPolicyScript.create(handle, match_id)
	if not bool(created.get("ok", false)):
		close_public_match()
		return {"ok": false, "error_code": str(created.get("error_code", "package_policy_unsupported"))}
	_package_policy = created.get("policy")
	_package_pins = pins.duplicate(true)
	_package_bound = true
	return {
		"ok": true,
		"error_code": "",
		"match_generation": base_bind.get("match_generation"),
		"card_inventory": base_bind.get("card_inventory", {}).duplicate(true),
		"package_id": pins.get("package_id"),
		"package_version": pins.get("package_version"),
		"archive_sha256": pins.get("archive_sha256"),
		"development_execution_only": true,
	}


func close_package_match() -> void:
	close_public_match()
	_package_policy = null
	_package_pins.clear()
	_package_bound = false


func get_package_execution_audit() -> Dictionary:
	var base: Dictionary = get_public_strategy_audit()
	var policy_audit: Dictionary = _package_policy.audit_snapshot() if _package_policy != null else {}
	return {
		"schema_version": 1,
		"profile_id": DEV_PROFILE_ID,
		"strategy_id": DEV_STRATEGY_ID,
		"package_id": _package_pins.get("package_id"),
		"package_version": _package_pins.get("package_version"),
		"archive_sha256": _package_pins.get("archive_sha256"),
		"policy_ir_sha256": _package_pins.get("policy_ir_sha256"),
		"adapter_sha256": _package_pins.get("adapter_sha256"),
		"config_sha256": _package_pins.get("config_sha256"),
		"weights_sha256": _package_pins.get("weights_sha256"),
		"card_id_domain": _package_pins.get("deck_card_id_domain"),
		"policy_calls": base.get("python_calls", 0),
		"policy_successes": base.get("python_successes", 0),
		"policy_errors": base.get("python_errors", 0),
		"invalid_outputs": base.get("invalid_outputs", 0),
		"fallbacks": base.get("fallbacks", 0),
		"setup_calls": base.get("setup_calls", 0),
		"interaction_calls": base.get("interaction_calls", 0),
		"send_out_calls": base.get("send_out_calls", 0),
		"rule_baseline_comparisons": base.get("rule_baseline_comparisons", 0),
		"rule_baseline_unavailable": base.get("rule_baseline_unavailable", 0),
		"first_rule_divergence": base.get("first_rule_divergence", {}).duplicate(true),
		"prompt_counts": base.get("prompt_counts", {}).duplicate(true),
		"serial_registry": base.get("serial_registry", {}).duplicate(true),
		"last_error_code": base.get("last_error_code", ""),
		"external_process_attempts": 0,
		"exact_builtin_sha_gate": _candidate_pin_error(_package_pins).is_empty(),
		"cabt_exportable": false,
		"execution_trusted": false,
		"development_execution_only": true,
		"player_runtime_authority": false,
		"classic_fallback_used": int(base.get("fallbacks", 0)) > 0,
		"policy_package_id": policy_audit.get("policy_package_id"),
		"policy_package_version": policy_audit.get("policy_package_version"),
		"policy_package_manifest_canonical_sha256": policy_audit.get("policy_package_manifest_canonical_sha256"),
		"execution_location": policy_audit.get("execution_location"),
		"learned_model": policy_audit.get("learned_model"),
		"model_backend": policy_audit.get("model_backend"),
		"learned_model_invoked": policy_audit.get("learned_model_invoked", false),
		"ir_execution_calls": policy_audit.get("successful_selections", 0),
		"matched_rule_counts": policy_audit.get("matched_rule_counts", {}).duplicate(true),
		"matched_rule_evaluations": policy_audit.get("matched_rule_evaluations", 0),
		"macro_preferred_selections": policy_audit.get("macro_preferred_selections", 0),
	}


func _build_frame(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int
) -> Dictionary:
	var frame: Dictionary = super(prompt_kind, options, minimum, maximum)
	frame["profile_id"] = DEV_PROFILE_ID
	frame["strategy_id"] = DEV_STRATEGY_ID
	var raw_semantics := _select_raw_semantics(prompt_kind)
	var semantics: Dictionary = frame.get("select_semantics")
	semantics["select_type_raw"] = raw_semantics.get("type")
	semantics["select_context_raw"] = raw_semantics.get("context")
	var source: Dictionary = frame.get("source")
	var window: Dictionary = TreeHashScript.public_observation_hash({
		"public_observation_hash": source.get("public_observation_hash"),
		"select_semantics": semantics,
		"options": options,
	})
	source["window_id"] = window.get("sha256", "")
	return frame


func _build_option(index: int, item: Variant, forced_kind: String) -> Dictionary:
	var option: Dictionary = super(index, item, forced_kind)
	var kind := str(option.get("kind", ""))
	option["option_type_raw"] = _option_type_raw(kind)
	option["option_card_uid"] = option.get("target_uid") if kind == "evolve" else option.get("card_uid")
	option["option_player_index"] = player_index
	return option


func _invoke_python(frame: Dictionary) -> Dictionary:
	_python_calls += 1
	if not _package_bound or _package_policy == null:
		return _python_failure("package_policy_not_bound")
	var started := Time.get_ticks_msec()
	var response: Dictionary = _package_policy.select(frame)
	_ipc_elapsed_msec += Time.get_ticks_msec() - started
	if not bool(response.get("ok", false)):
		return _python_failure(str(response.get("error_code", "package_policy_error")))
	_python_successes += 1
	_last_error_code = ""
	return response


func _select_raw_semantics(prompt_kind: String) -> Dictionary:
	match prompt_kind:
		"main":
			return {"type": 0, "context": 0}
		"setup_active":
			return {"type": 1, "context": 1}
		"setup_bench":
			return {"type": 1, "context": 2}
		"attach":
			return {"type": 1, "context": 22}
		_:
			return {"type": 1, "context": 0}


func _option_type_raw(kind: String) -> int:
	match kind:
		"play_trainer", "play_stadium":
			return 7
		"use_ability", "use_stadium_effect":
			return 12
		"attack", "granted_attack":
			return 13
		"end_turn":
			return 14
		"retreat":
			return 15
		_:
			return 3


func _deck_inventory_error(player: PlayerState, expected_rows: Array) -> String:
	if player == null:
		return "missing_player"
	var expected := {}
	for row_value: Variant in expected_rows:
		if not row_value is Dictionary:
			return "package_deck_unmapped"
		var uid := str(row_value.get("local_card_uid", ""))
		var count := int(row_value.get("count", 0))
		if uid.is_empty() or count <= 0 or expected.has(uid):
			return "package_deck_unmapped"
		expected[uid] = count
	var cards: Array[CardInstance] = []
	cards.append_array(player.deck)
	cards.append_array(player.hand)
	cards.append_array(player.prizes)
	cards.append_array(player.discard_pile)
	cards.append_array(player.lost_zone)
	if player.active_pokemon != null:
		cards.append_array(player.active_pokemon.collect_all_cards())
	for slot: PokemonSlot in player.bench:
		cards.append_array(slot.collect_all_cards())
	if cards.size() != 60:
		return "package_deck_inventory_mismatch"
	var actual := {}
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			return "package_deck_inventory_mismatch"
		var uid := card.card_data.get_uid()
		actual[uid] = int(actual.get(uid, 0)) + 1
	return "" if actual == expected else "package_deck_inventory_mismatch"


func _candidate_pin_error(pins: Dictionary) -> String:
	if (
		pins.get("package_id") != DEV_PACKAGE_ID
		or pins.get("package_version") != DEV_PACKAGE_VERSION
		or pins.get("archive_sha256") != DEV_ARCHIVE_SHA256
		or pins.get("deck_card_id_domain") != "godot_local_card_uid_v1"
		or pins.get("deck_platform_scope") != ["windows"]
		or pins.get("local_deck_card_count") != 60
		or pins.get("local_deck_unique_printing_count") != 28
		or pins.get("cabt_exportable") != false
		or pins.get("signature_status") != "test_fixture_trusted"
		or pins.get("development_shadow_ready") != true
		or pins.get("execution_trusted") != false
		or pins.get("live_authority") != false
	):
		return "development_candidate_not_authorized"
	return ""
