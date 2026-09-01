class_name PtcgDAPAuthorDevelopmentBattleOwner
extends RefCounted

const ExecutionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const DevelopmentPolicyScript = preload("res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd")
const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const GodotSerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const StepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const EngineActionExecutorScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd")
const BenchLimitScript = preload("res://scripts/engine/BenchLimitHelper.gd")
const UcisCompilerScript = preload("res://scripts/engine/ucis/UcisInteractionCompiler.gd")
const ModelActorScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd")
const PolicyWorkerScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyPolicyWorker.gd"
)

const PROFILE_ID := "ptcgdap-marnie-package-development-frame-v1"
const STRATEGY_ID := "ptcgdap.marnie.18.0.package-local-v1"
const CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const PLATFORM_NPC_AUTHORITY_MODE := "platform_npc_public_v1"
const STEP_PROGRESSED := "progressed"
const STEP_WAITING_POLICY := "waiting_policy"
const STEP_NO_PROGRESS := "no_progress"
const POLICY_EXECUTION_MAIN_THREAD := "main_thread_v1"
const POLICY_EXECUTION_WORKER := "worker_v1"


class PublicInteractionAdapter extends RefCounted:
	var owner: Variant = null

	func _init(next_owner: Variant) -> void:
		owner = next_owner

	func get_strategy_id() -> String:
		return STRATEGY_ID

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		return owner._pick_interaction_items(items, step, _context) if owner != null else []

	func should_preserve_empty_interaction_selection(step: Dictionary, context: Dictionary = {}) -> bool:
		return owner._should_preserve_empty_interaction_selection(step, context) if owner != null else false

	func has_pending_external_decision() -> bool:
		return owner.has_pending_external_decision() if owner != null else false

	func uses_external_decision_port() -> bool:
		return owner.uses_external_decision_port() if owner != null else false

	func pick_interaction_target_index(
		items: Array,
		excluded_targets: Array,
		step: Dictionary,
		context: Dictionary = {}
	) -> int:
		return owner._pick_interaction_target_index(items, excluded_targets, step, context) \
			if owner != null else -1


class LegalityOnlyActionBuilder extends AILegalActionBuilder:
	func _init() -> void:
		# The package owns every preference. Keep the inherited builder as a legal
		# action/window enumerator and suppress its legacy automatic deck detector.
		_deck_strategy = null
		_deck_strategy_detected = true

	func _can_headless_auto_resolve_steps(
		steps: Array[Dictionary],
		_allow_side_effectful_headless_resolution: bool
	) -> bool:
		# Public interaction suffixes belong to a fresh author-policy window.
		# The legality builder may certify an action, but it must never choose
		# discard/search/assignment targets on the package's behalf.
		return steps.is_empty()


var player_index := -1
var _gsm: GameStateMachine = null
var _policy: Variant = null
var _external_decision_port: Variant = null
var _pins: Dictionary = {}
var _serial_registry: Variant = null
var _match_generation := -1
var _match_id := ""
var _legal_action_builder: RefCounted = null
var _step_resolver: RefCounted = null
var _engine_executor: RefCounted = null
var _interaction_adapter: RefCounted = null
var _sequence := 0
var _bound := false
var _closed := false
var _planned_setup_bench_serials: Array[int] = []
var _setup_bench_plan_ready := false
var _policy_calls := 0
var _policy_successes := 0
var _policy_errors := 0
var _invalid_outputs := 0
var _same_window_fallbacks := 0
var _engine_commits := 0
var _engine_rejections := 0
var _prompt_counts: Dictionary = {}
var _last_error_code := ""
var _decision_elapsed_usec: Array[int] = []
var _authority_mode := ExecutionGateScript.DEVELOPMENT_MODE
var _developer_trace_enabled := false
var _developer_decision_records: Array[Dictionary] = []
var _developer_trace_dropped_records := 0
var _confirmed_effect_activation_keys: Dictionary = {}
var _tracked_public_entity_slots: Array[Dictionary] = []
var _model_actor: Variant = null
var _model_decision_windows := 0
var _model_inference_successes := 0
var _model_fallbacks := 0
var _model_changed_selections := 0
var _model_elapsed_usec: Array[int] = []
var _model_diagnostic_counts: Dictionary = {}
var _policy_execution_profile := POLICY_EXECUTION_MAIN_THREAD
var _policy_worker: Variant = null
var _pending_policy_context: Dictionary = {}
var _cached_policy_audit: Dictionary = {}
var _policy_worker_schedules := 0
var _policy_worker_start_failures := 0
var _policy_worker_stale_results := 0


static func create(
	handle: Variant,
	gsm: GameStateMachine,
	seat: int,
	match_id: String,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if not _competition_host_authorized():
		return _error("development_platform_not_authorized")
	if (
		handle == null
		or not handle.has_method("validate_integrity")
		or not handle.validate_integrity()
		or gsm == null
		or gsm.game_state == null
		or gsm.game_state.players.size() != 2
		or seat not in [0, 1]
		or match_id.strip_edges().is_empty()
	):
		return _error("invalid_bind")
	var pin_error := ExecutionGateScript.validate_handle_pins(
		handle.to_public_dict(), authority_mode
	)
	if not pin_error.is_empty():
		return _error(pin_error)
	var owner := new()
	var bound := owner._bind(handle, gsm, seat, match_id.strip_edges(), authority_mode)
	if not bool(bound.get("ok", false)):
		return _error(str(bound.get("error_code", "invalid_bind")))
	var model_bound: Dictionary = owner._bind_model(handle)
	if not bool(model_bound.get("ok", false)):
		owner.close_match()
		return _error(str(model_bound.get("error_code", "package_model_relation_invalid")))
	return {"ok": true, "error_code": "", "owner": owner}


static func create_external(
	gsm: GameStateMachine,
	seat: int,
	match_id: String,
	decision_port: Variant
) -> Dictionary:
	if OS.get_name() != "Windows":
		return _error("development_platform_not_authorized")
	if (
		gsm == null
		or gsm.game_state == null
		or gsm.game_state.players.size() != 2
		or seat not in [0, 1]
		or match_id.strip_edges().is_empty()
		or decision_port == null
		or not decision_port.has_method("validate_integrity")
		or not decision_port.validate_integrity()
		or not decision_port.has_method("select")
		or not decision_port.has_method("acknowledge_selection")
	):
		return _error("invalid_external_bind")
	var owner := new()
	var bound := owner._bind_external(
		gsm,
		seat,
		match_id.strip_edges(),
		decision_port,
		"a3_private_oracle_research",
		{}
	)
	if not bool(bound.get("ok", false)):
		return _error(str(bound.get("error_code", "invalid_external_bind")))
	return {"ok": true, "error_code": "", "owner": owner}


static func create_platform_npc(
	gsm: GameStateMachine,
	seat: int,
	match_id: String,
	decision_port: Variant,
	pins: Dictionary
) -> Dictionary:
	if not _competition_host_authorized():
		return _error("development_platform_not_authorized")
	if (
		gsm == null
		or gsm.game_state == null
		or gsm.game_state.players.size() != 2
		or seat not in [0, 1]
		or match_id.strip_edges().is_empty()
		or decision_port == null
		or not decision_port.has_method("validate_integrity")
		or not decision_port.validate_integrity()
		or not decision_port.has_method("select")
		or not decision_port.has_method("acknowledge_selection")
		or str(pins.get("owner_kind", "")) != "platform_npc"
		or str(pins.get("owner_id", "")).is_empty()
		or str(pins.get("competition_conflict_group", "")) \
			!= "platform_npc:%s" % str(pins.get("owner_id", ""))
	):
		return _error("invalid_platform_npc_bind")
	var owner := new()
	var bound := owner._bind_external(
		gsm,
		seat,
		match_id.strip_edges(),
		decision_port,
		PLATFORM_NPC_AUTHORITY_MODE,
		pins
	)
	if not bool(bound.get("ok", false)):
		return _error(str(bound.get("error_code", "invalid_platform_npc_bind")))
	return {"ok": true, "error_code": "", "owner": owner}


func bind_development_competition_identity(pins: Dictionary) -> Dictionary:
	if (
		not _competition_host_authorized()
		or not _bound
		or _authority_mode not in [
			ExecutionGateScript.DEVELOPMENT_MODE,
		]
		or str(pins.get("owner_kind", "")) != "developer"
		or str(pins.get("owner_id", "")) != str(pins.get("developer_id", ""))
		or str(pins.get("competition_conflict_group", "")) \
			!= "developer:%s" % str(pins.get("developer_id", ""))
		or str(pins.get("release_source_kind", "")) != "developer_ptcgai"
		or str(pins.get("runtime_kind", "")) != "godot_restricted_ptcgai_v1"
		or str(pins.get("release_id", "")).is_empty()
		or str(pins.get("archive_sha256", "")).to_upper() \
			!= str(_pins.get("archive_sha256", "")).to_upper()
		or str(pins.get("signing_key_id", "")) \
			!= str(_pins.get("signature_key_id", ""))
		or str(pins.get("admission_sha256", "")).length() != 64
	):
		return _error("invalid_development_competition_identity")
	for field: String in [
		"developer_id", "owner_kind", "owner_id", "competition_conflict_group",
		"release_source_kind", "runtime_kind", "release_id", "admission_sha256",
		"signing_key_id",
	]:
		_pins[field] = pins.get(field)
	return {"ok": true, "error_code": ""}


static func _competition_host_authorized() -> bool:
	return OS.get_name() == "Windows" or (
		OS.get_name() == "Linux"
		and OS.has_feature("dedicated_server")
		and OS.get_environment("PTCGDAP_GODOT_V18_SERVER_COMPETITION") == "enabled"
		and OS.get_environment("PTCGDAP_COMPETITION_NETWORK") == "disabled"
	)


func _bind(
	handle: Variant,
	next_gsm: GameStateMachine,
	seat: int,
	match_id: String,
	authority_mode: String
) -> Dictionary:
	player_index = seat
	_gsm = next_gsm
	_match_id = match_id
	_authority_mode = authority_mode
	_pins = handle.to_public_dict().duplicate(true)
	var inventory_error := _deck_inventory_error(
		_gsm.game_state.players[player_index], handle.local_deck_snapshot()
	)
	if not inventory_error.is_empty():
		return _error(inventory_error)
	_serial_registry = GodotSerialRegistryScript.new()
	_match_generation = int(_serial_registry.get_match_generation())
	for inventory_seat: int in 2:
		var registered := _register_player_inventory(_gsm.game_state.players[inventory_seat])
		if not bool(registered.get("ok", false)):
			return registered
	var sealed: Dictionary = _serial_registry.seal_card_inventory([60, 60])
	if not bool(sealed.get("ok", false)):
		return _error(str(sealed.get("code", "card_inventory_error")))
	var created: Dictionary = DevelopmentPolicyScript.create(
		handle, match_id, _authority_mode
	)
	if not bool(created.get("ok", false)):
		return _error(str(created.get("error_code", "package_policy_unsupported")))
	_policy = created.get("policy")
	_cached_policy_audit = _read_policy_audit_now()
	_legal_action_builder = LegalityOnlyActionBuilder.new()
	# No built-in deck strategy is installed here. The package is the only
	# preference owner; the shared builder contributes legality only.
	_interaction_adapter = PublicInteractionAdapter.new(self)
	_step_resolver = StepResolverScript.new()
	_step_resolver.call("set_deck_strategy", _interaction_adapter)
	_engine_executor = EngineActionExecutorScript.new()
	_bound = true
	return {"ok": true, "error_code": ""}


func _bind_external(
	next_gsm: GameStateMachine,
	seat: int,
	match_id: String,
	decision_port: Variant,
	authority_mode: String,
	pins: Dictionary
) -> Dictionary:
	player_index = seat
	_gsm = next_gsm
	_match_id = match_id
	_authority_mode = authority_mode
	_pins = pins.duplicate(true)
	_external_decision_port = decision_port
	_serial_registry = GodotSerialRegistryScript.new()
	_match_generation = int(_serial_registry.get_match_generation())
	for inventory_seat: int in 2:
		var registered := _register_player_inventory(_gsm.game_state.players[inventory_seat])
		if not bool(registered.get("ok", false)):
			return registered
	var sealed: Dictionary = _serial_registry.seal_card_inventory([60, 60])
	if not bool(sealed.get("ok", false)):
		return _error(str(sealed.get("code", "card_inventory_error")))
	_legal_action_builder = LegalityOnlyActionBuilder.new()
	_interaction_adapter = PublicInteractionAdapter.new(self)
	_step_resolver = StepResolverScript.new()
	_step_resolver.call("set_deck_strategy", _interaction_adapter)
	_engine_executor = EngineActionExecutorScript.new()
	_bound = true
	return {"ok": true, "error_code": ""}


func _bind_model(handle: Variant) -> Dictionary:
	var created: Dictionary = ModelActorScript.create(handle)
	if not bool(created.get("ok", false)) or created.get("owner") == null:
		return _error(str(created.get("error_code", "package_model_relation_invalid")))
	_model_actor = created.get("owner")
	return {"ok": true, "error_code": ""}


func validate_integrity() -> bool:
	return (
		_bound
		and not _closed
		and player_index in [0, 1]
		and _gsm != null
		and _gsm.game_state != null
		and (_policy != null or _external_decision_port != null)
		and _serial_registry != null
		and _legal_action_builder != null
		and _step_resolver != null
		and _engine_executor != null
		and (
			_external_decision_port != null
			or ExecutionGateScript.validate_handle_pins(_pins, _authority_mode).is_empty()
		)
	)


func is_ready() -> bool:
	return validate_integrity()


func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
	return validate_integrity() and not ui_blocked and game_state == _gsm.game_state \
		and game_state.current_player_index == player_index


func run_single_step_result(battle_scene: Control, gsm: GameStateMachine) -> Dictionary:
	var progressed := run_single_step(battle_scene, gsm)
	var waiting := not progressed and (
		has_pending_policy_decision() or has_pending_external_decision()
	)
	return {
		"status": STEP_PROGRESSED if progressed else (
			STEP_WAITING_POLICY if waiting else STEP_NO_PROGRESS
		),
		"progressed": progressed,
	}


func configure_policy_execution_profile(requested_profile: String) -> bool:
	if _policy_calls > 0 or not _pending_policy_context.is_empty():
		return false
	var normalized := requested_profile.strip_edges().to_lower()
	if normalized not in [POLICY_EXECUTION_MAIN_THREAD, POLICY_EXECUTION_WORKER]:
		return false
	if normalized == POLICY_EXECUTION_WORKER and _external_decision_port != null:
		return false
	_policy_execution_profile = normalized
	if normalized == POLICY_EXECUTION_WORKER and _policy_worker == null:
		_policy_worker = PolicyWorkerScript.new()
	return true


func has_pending_policy_decision() -> bool:
	return not _pending_policy_context.is_empty()


func is_policy_decision_ready() -> bool:
	return (
		has_pending_policy_decision()
		and _policy_worker != null
		and bool(_policy_worker.call("is_ready"))
	)


func enable_developer_decision_trace(enabled: bool = true) -> void:
	_developer_trace_enabled = enabled
	if _policy != null and _policy.has_method("enable_turn_program_shadow"):
		_policy.enable_turn_program_shadow(enabled)
	if enabled:
		_developer_decision_records.clear()


func drain_developer_decision_records() -> Array:
	var records: Array = []
	for record: Dictionary in _developer_decision_records:
		records.append(record.duplicate(true))
	_developer_decision_records.clear()
	return records


func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
	if not validate_integrity() or battle_scene == null or gsm != _gsm:
		return false
	var pending_choice := str(battle_scene.get("_pending_choice"))
	if pending_choice == "starting_player_choice":
		return _run_starting_player_step(battle_scene)
	if pending_choice == "mulligan_extra_draw":
		return _run_mulligan_step(battle_scene)
	if pending_choice.begins_with("setup_active_"):
		return _run_setup_active_step(battle_scene, pending_choice)
	if pending_choice.begins_with("setup_bench_"):
		return _run_setup_bench_step(battle_scene, pending_choice)
	if pending_choice == "take_prize":
		return _run_take_prize_step(battle_scene)
	if pending_choice == "send_out":
		return _run_send_out_step(battle_scene)
	if pending_choice == "heavy_baton_target":
		return _run_handoff_step(battle_scene, true)
	if pending_choice == "exp_share_target":
		return _run_handoff_step(battle_scene, false)
	if pending_choice == "retreat_energy":
		return _run_retreat_energy_step(battle_scene)
	if pending_choice == "retreat_bench":
		return _run_retreat_bench_step(battle_scene)
	if pending_choice == "effect_interaction":
		var activation_result: Variant = _run_evolve_trigger_activation_step(battle_scene)
		if activation_result != null:
			return bool(activation_result)
		var state_features: Array[float] = []
		return bool(_step_resolver.call(
			"resolve_pending_step", battle_scene, _gsm, player_index, state_features
		))
	if _gsm.game_state.phase != GameState.GamePhase.MAIN \
		or _gsm.game_state.current_player_index != player_index:
		return false
	return _run_main_step(battle_scene)


func _run_evolve_trigger_activation_step(battle_scene: Control) -> Variant:
	if str(battle_scene.get("_pending_effect_kind")) != "ability":
		return null
	if int(battle_scene.get("_pending_effect_step_index")) != 0:
		return null
	var slot: PokemonSlot = battle_scene.get("_pending_effect_slot") as PokemonSlot
	var card: CardInstance = battle_scene.get("_pending_effect_card") as CardInstance
	var ability_index := int(battle_scene.get("_pending_effect_ability_index"))
	if slot == null or card == null or ability_index < 0:
		return null
	if slot.turn_evolved != int(_gsm.game_state.turn_number):
		return null
	var effect: Variant = _gsm.effect_processor.get_ability_effect(
		slot, ability_index, _gsm.game_state
	)
	if (
		effect == null
		or not effect.has_method("is_evolve_triggered_ability")
		or not bool(effect.call("is_evolve_triggered_ability"))
	):
		return null
	var steps: Array = battle_scene.get("_pending_effect_steps")
	if steps.is_empty() or not (steps[0] is Dictionary):
		return null
	var first_step: Dictionary = steps[0]
	var activation_key := "%d:%d:%d:%d:%s" % [
		battle_scene.get_instance_id(),
		_serial_for_card(card),
		slot.get_instance_id(),
		int(_gsm.game_state.turn_number),
		str(first_step.get("id", "")),
	]
	if bool(_confirmed_effect_activation_keys.get(activation_key, false)):
		return null
	var options: Array = [
		_make_option(0, {"kind": "yes"}, "yes"),
		_make_option(1, {"kind": "no"}, "no"),
	]
	var selected := _select_items(
		"activate", options, 1, 1, {"type": 9, "context": 43}
	)
	if selected.size() != 1 or int(selected[0]) not in [0, 1]:
		return false
	if int(selected[0]) == 0:
		_confirmed_effect_activation_keys[activation_key] = true
		return true
	# Declining a triggered ability consumes only the activation window.  The
	# effect interaction must be cleared without calling use_ability(), so no
	# card effect or hidden-zone mutation is executed.
	battle_scene.call("_reset_effect_interaction")
	return true


func _run_starting_player_step(battle_scene: Control) -> bool:
	var data: Dictionary = battle_scene.get("_dialog_data")
	var chooser := int(data.get("chooser", -1))
	if chooser != player_index:
		return false
	var options: Array = [
		_make_option(0, {"kind": "yes"}, "yes"),
		_make_option(1, {"kind": "no"}, "no"),
	]
	var selected := _select_items(
		"starting_player_choice", options, 1, 1, {"type": 9, "context": 41}
	)
	if selected.size() != 1 or int(selected[0]) not in [0, 1]:
		return false
	var selected_index := int(selected[0])
	_clear_consumed_prompt(battle_scene)
	# Source-locked CABT context IS_FIRST asks the chooser whether they want to
	# go first. The native YES option is index 0/type 1; NO is index 1/type 2.
	if not bool(_gsm.call("resolve_starting_player_choice", chooser, selected_index == 0)):
		_restore_prompt_if_unclaimed(battle_scene, "starting_player_choice", data)
		_engine_rejections += 1
		return false
	_engine_commits += 1
	return true


func _run_mulligan_step(battle_scene: Control) -> bool:
	var data: Dictionary = battle_scene.get("_dialog_data")
	var beneficiary := int(data.get("beneficiary", -1))
	if beneficiary != player_index:
		return false
	var maximum_draw := maxi(0, int(data.get("mulligan_count", 0)))
	var options: Array = []
	for count: int in maximum_draw + 1:
		options.append(_make_option(count, {"number": count}, "mulligan_draw_count"))
	var selected := _select_items(
		"mulligan_draw_count", options, 1, 1, {"type": 8, "context": 38}
	)
	if selected.is_empty():
		return false
	var draw_count := int(selected[0])
	if draw_count < 0 or draw_count > maximum_draw:
		return false
	_clear_consumed_prompt(battle_scene)
	if _gsm.has_method("resolve_mulligan_draw_count"):
		if not bool(_gsm.call("resolve_mulligan_draw_count", beneficiary, draw_count)):
			return false
	else:
		_gsm.resolve_mulligan_choice(beneficiary, draw_count > 0)
	_engine_commits += 1
	return true


func _run_setup_active_step(battle_scene: Control, pending_choice: String) -> bool:
	var seat := int(pending_choice.split("_")[-1])
	if seat != player_index:
		return false
	var player: PlayerState = _gsm.game_state.players[player_index]
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.is_empty():
		return false
	var options := _options_for_items(basics, "setup_active")
	var selected := _select_items("setup_active", options, 1, 1)
	if selected.is_empty():
		return false
	var selected_index := int(selected[0])
	if selected_index < 0 or selected_index >= basics.size():
		return false
	var active := basics[selected_index]
	_planned_setup_bench_serials.clear()
	_setup_bench_plan_ready = false
	_clear_consumed_prompt(battle_scene)
	if not _gsm.setup_place_active_pokemon(player_index, active):
		_engine_rejections += 1
		return false
	_engine_commits += 1
	if battle_scene.has_method("_after_setup_active"):
		battle_scene.call("_after_setup_active", player_index)
	return true


func _run_setup_bench_step(battle_scene: Control, pending_choice: String) -> bool:
	var seat := int(pending_choice.split("_")[-1])
	if seat != player_index:
		return false
	var player: PlayerState = _gsm.game_state.players[player_index]
	var data: Dictionary = battle_scene.get("_dialog_data")
	var available: Array[CardInstance] = []
	for value: Variant in data.get("cards", []):
		if value is CardInstance:
			available.append(value)
	if not _setup_bench_plan_ready:
		# Active placement is an information checkpoint.  Build the optional
		# bench window only from this fresh prompt; never cache its old indexes.
		_planned_setup_bench_serials.clear()
		var capacity := mini(
			available.size(),
			maxi(0, BenchLimitScript.get_bench_limit_for_player(
				_gsm.game_state, player, _gsm.effect_processor
			) - player.bench.size())
		)
		var bench_indexes := _select_items(
			"setup_bench", _options_for_items(available, "setup_bench"), 0, capacity,
			{"type": 1, "context": 2}
		)
		if has_pending_external_decision():
			return false
		for raw_index: Variant in bench_indexes:
			var planned_index := int(raw_index)
			if planned_index >= 0 and planned_index < available.size():
				_planned_setup_bench_serials.append(_serial_for_card(available[planned_index]))
		_setup_bench_plan_ready = true
	var next_card: CardInstance = null
	for planned_serial: int in _planned_setup_bench_serials:
		for card: CardInstance in available:
			if _serial_for_card(card) == planned_serial:
				next_card = card
				break
		if next_card != null:
			break
	if next_card == null:
		_setup_bench_plan_ready = false
		_clear_consumed_prompt(battle_scene)
		if battle_scene.has_method("_after_setup_bench"):
			battle_scene.call("_after_setup_bench", player_index)
		return true
	_clear_consumed_prompt(battle_scene)
	if not _gsm.setup_place_bench_pokemon(player_index, next_card):
		_engine_rejections += 1
		return false
	_planned_setup_bench_serials.erase(_serial_for_card(next_card))
	_planned_setup_bench_serials.erase(_serial_for_card(next_card))
	_engine_commits += 1
	if battle_scene.has_method("_refresh_ui"):
		battle_scene.call("_refresh_ui")
	if battle_scene.has_method("_show_setup_bench_dialog"):
		battle_scene.call("_show_setup_bench_dialog", player_index)
	return true


func _run_take_prize_step(battle_scene: Control) -> bool:
	var has_live_prize_ui := battle_scene.has_method("_try_take_prize_from_slot")
	var prompt_player := int(battle_scene.get("_pending_prize_player_index")) if has_live_prize_ui \
		else int((battle_scene.get("_dialog_data") as Dictionary).get("player", -1))
	if prompt_player != player_index:
		return false
	if has_live_prize_ui and int(battle_scene.get("_pending_prize_remaining")) <= 0:
		_clear_consumed_prompt(battle_scene)
		battle_scene.set("_pending_prize_player_index", -1)
		battle_scene.set("_pending_prize_remaining", 0)
		battle_scene.set("_pending_prize_animating", false)
		if battle_scene.has_method("_refresh_ui") and (not has_live_prize_ui or battle_scene.is_inside_tree()):
			battle_scene.call("_refresh_ui")
		return true
	var player: PlayerState = _gsm.game_state.players[player_index]
	var slots: Array[int] = []
	for slot_index: int in player.get_prize_layout().size():
		if player.get_prize_at_slot(slot_index) != null:
			slots.append(slot_index)
	if slots.is_empty():
		return false
	# Face-down prize positions are intentionally indistinguishable to a
	# public-only data package. Competitive v2 cannot encode a CARD option
	# without inventing a card identity, so Base owns the deterministic current
	# frontier choice. The separate A3 research port retains its reviewed public
	# position projection and may choose the exact slot.
	var selected := _base_owned_hidden_prize_selection(slots) \
		if _uses_competitive_policy_v2() and _external_decision_port == null \
		else _select_items(
			"take_prize",
			_options_for_items(
				slots,
				"take_prize",
				{
					"cabt_select_type_raw": 1,
					"cabt_select_context_raw": 7,
					"option_area_raw": 6,
				}
			),
			1,
			1,
			{"type": 1, "context": 7}
		)
	if selected.is_empty():
		return false
	var selected_index := int(selected[0])
	if selected_index < 0 or selected_index >= slots.size():
		return false
	var selected_slot := slots[selected_index]
	var prizes_before := player.prizes.size()
	if has_live_prize_ui:
		battle_scene.call("_try_take_prize_from_slot", player_index, selected_slot)
		if bool(battle_scene.get("_pending_prize_animating")) or player.prizes.size() < prizes_before:
			_engine_commits += 1
			return true
	_clear_consumed_prompt(battle_scene)
	if not _gsm.resolve_take_prize(player_index, selected_slot):
		_engine_rejections += 1
		return false
	if has_live_prize_ui:
		var pending: Dictionary = _gsm.get_pending_decision_snapshot()
		if str(pending.get("kind", "")) == "take_prize" \
			and int(pending.get("owner_player_index", -1)) == player_index:
			battle_scene.set("_pending_choice", "take_prize")
			battle_scene.set("_pending_prize_player_index", player_index)
			battle_scene.set("_pending_prize_remaining", int(pending.get("count", 0)))
		else:
			battle_scene.set("_pending_prize_player_index", -1)
			battle_scene.set("_pending_prize_remaining", 0)
		battle_scene.set("_pending_prize_animating", false)
		if battle_scene.has_method("_refresh_ui") and battle_scene.is_inside_tree():
			battle_scene.call("_refresh_ui")
	_engine_commits += 1
	return true


static func _base_owned_hidden_prize_selection(slots: Array[int]) -> Array[int]:
	var selected: Array[int] = []
	if not slots.is_empty():
		selected.append(0)
	return selected


func _run_send_out_step(battle_scene: Control) -> bool:
	var data: Dictionary = battle_scene.get("_dialog_data")
	if int(data.get("player", -1)) != player_index:
		return false
	var player_bench: Array[PokemonSlot] = _gsm.game_state.players[player_index].bench
	var bench: Array[PokemonSlot] = []
	for value: Variant in data.get("bench", []):
		if value is PokemonSlot and value in player_bench:
			bench.append(value)
	if bench.is_empty():
		bench = player_bench.duplicate()
	bench = _legal_send_out_slots(bench, _gsm.effect_processor, _gsm.game_state)
	if bench.is_empty():
		return false
	var selected := _select_items("send_out", _options_for_items(bench, "send_out"), 1, 1)
	if selected.is_empty():
		return false
	var index := int(selected[0])
	if index < 0 or index >= bench.size():
		_engine_rejections += 1
		return false
	# Engine signals are synchronous. Retire the consumed prompt before the
	# action is logged or the next phase/turn is published, otherwise observers
	# can schedule the author owner again against a stale send_out window.
	var consumed_data := data.duplicate(true)
	_clear_prompt_if_same(battle_scene, "send_out", player_index)
	if not _gsm.send_out_pokemon(player_index, bench[index]):
		_restore_prompt_if_unclaimed(battle_scene, "send_out", consumed_data)
		_engine_rejections += 1
		return false
	_engine_commits += 1
	if battle_scene.has_method("_refresh_ui_after_successful_action"):
		battle_scene.call("_refresh_ui_after_successful_action", true, player_index)
	return true


static func _legal_send_out_slots(
	bench_slots: Array[PokemonSlot],
	effect_processor: EffectProcessor,
	state: GameState
) -> Array[PokemonSlot]:
	var legal: Array[PokemonSlot] = []
	for slot: PokemonSlot in bench_slots:
		if slot == null or slot.get_top_card() == null:
			continue
		if effect_processor != null:
			if effect_processor.get_effective_max_hp(slot, state) <= 0:
				continue
			if effect_processor.is_effectively_knocked_out(slot, state):
				continue
		elif slot.get_max_hp() <= 0 or slot.is_knocked_out():
			continue
		legal.append(slot)
	return legal


func _run_handoff_step(battle_scene: Control, heavy_baton: bool) -> bool:
	var data: Dictionary = battle_scene.get("_dialog_data")
	if int(data.get("player", -1)) != player_index:
		return false
	var bench: Array[PokemonSlot] = []
	for value: Variant in data.get("bench", []):
		if value is PokemonSlot:
			bench.append(value)
	if bench.is_empty():
		return false
	var selected := _select_items(
		"heavy_baton_target" if heavy_baton else "exp_share_target",
		_options_for_items(bench, "effect_target"), 1, 1
	)
	if selected.is_empty():
		return false
	var index := int(selected[0])
	if index < 0 or index >= bench.size():
		return false
	var energies: Array = data.get("source_energy", [])
	var ok := _gsm.resolve_heavy_baton_choice_with_energy(player_index, bench[index], energies) \
		if heavy_baton else _gsm.resolve_exp_share_choice(player_index, bench[index], energies[0] if not energies.is_empty() else null)
	if not ok:
		_engine_rejections += 1
		return false
	_clear_prompt_if_same(battle_scene, "heavy_baton_target" if heavy_baton else "exp_share_target", player_index)
	_engine_commits += 1
	return true


func _run_retreat_energy_step(battle_scene: Control) -> bool:
	var data: Dictionary = battle_scene.get("_dialog_data")
	if int(data.get("player", -1)) != player_index:
		return false
	var active := _gsm.game_state.players[player_index].active_pokemon
	if active == null:
		return false
	var energies: Array[CardInstance] = []
	for value: Variant in data.get("energy_options", []):
		if value is CardInstance and value in active.attached_energy:
			energies.append(value)
	if energies.is_empty():
		return false
	var retreat_cost := int(data.get("retreat_cost", 0))
	var legal_subsets := _minimal_retreat_energy_subsets(active, energies, retreat_cost)
	if legal_subsets.is_empty():
		return false
	var subset_options: Array = []
	for index: int in legal_subsets.size():
		var subset: Array[CardInstance] = legal_subsets[index]
		subset_options.append(_make_option(
			index,
			{
				"kind": "energy_payment",
				"source": subset[0] if not subset.is_empty() else null,
				"energy_count": subset.size(),
				"requires_interaction": true,
			},
			"energy_payment",
			{
				"cabt_select_type_raw": 2,
				"cabt_select_context_raw": 26,
				"cabt_option_type_raw": 5,
			}
		))
	var selected := _select_items(
		"energy_payment",
		subset_options,
		1,
		1,
		{"type": 2, "context": 26}
	)
	if selected.is_empty():
		return false
	var subset_index := int(selected[0])
	if subset_index < 0 or subset_index >= legal_subsets.size():
		return false
	var chosen: Array[CardInstance] = legal_subsets[subset_index].duplicate()
	if not _gsm.rule_validator.has_enough_energy_to_retreat(
		active, chosen, retreat_cost, _gsm.effect_processor, _gsm.game_state
	):
		_engine_rejections += 1
		return false
	if battle_scene.has_method("_retreat_selection_is_valid") and not bool(
		battle_scene.call("_retreat_selection_is_valid", active, chosen, retreat_cost)
	):
		_engine_rejections += 1
		return false
	if not battle_scene.has_method("_show_retreat_bench_choice"):
		return false
	battle_scene.call("_show_retreat_bench_choice", player_index, chosen)
	_engine_commits += 1
	return true


func _minimal_retreat_energy_subsets(
	active: PokemonSlot,
	energies: Array[CardInstance],
	retreat_cost: int
) -> Array[Array]:
	var result: Array[Array] = []
	if active == null or energies.is_empty() or retreat_cost <= 0:
		return result
	var subset_limit := 1 << mini(energies.size(), 12)
	for mask: int in range(1, subset_limit):
		var chosen: Array[CardInstance] = []
		for index: int in mini(energies.size(), 12):
			if mask & (1 << index):
				chosen.append(energies[index])
		if not _gsm.rule_validator.has_enough_energy_to_retreat(
			active, chosen, retreat_cost, _gsm.effect_processor, _gsm.game_state
		):
			continue
		var minimal := true
		for remove_index: int in chosen.size():
			var reduced: Array[CardInstance] = chosen.duplicate()
			reduced.remove_at(remove_index)
			if _gsm.rule_validator.has_enough_energy_to_retreat(
				active, reduced, retreat_cost, _gsm.effect_processor, _gsm.game_state
			):
				minimal = false
				break
		if minimal:
			result.append(chosen)
	if not result.is_empty() or energies.size() <= 12:
		return result
	# A pathological attachment count stays bounded: deterministically remove
	# every redundant energy from the full public attachment set.
	var reduced: Array[CardInstance] = energies.duplicate()
	var changed := true
	while changed:
		changed = false
		for index: int in reduced.size():
			var candidate: Array[CardInstance] = reduced.duplicate()
			candidate.remove_at(index)
			if _gsm.rule_validator.has_enough_energy_to_retreat(
				active, candidate, retreat_cost, _gsm.effect_processor, _gsm.game_state
			):
				reduced = candidate
				changed = true
				break
	if _gsm.rule_validator.has_enough_energy_to_retreat(
		active, reduced, retreat_cost, _gsm.effect_processor, _gsm.game_state
	):
		result.append(reduced)
	return result


func _run_retreat_bench_step(battle_scene: Control) -> bool:
	var data: Dictionary = battle_scene.get("_dialog_data")
	if int(data.get("player", -1)) != player_index:
		return false
	var player := _gsm.game_state.players[player_index]
	var bench: Array[PokemonSlot] = []
	for value: Variant in data.get("bench", []):
		if value is PokemonSlot and value in player.bench and not value.is_knocked_out():
			bench.append(value)
	if bench.is_empty():
		return false
	var selected := _select_items(
		"self_switch",
		_options_for_items(
			bench,
			"send_out",
			{
				"cabt_select_type_raw": 1,
				"cabt_select_context_raw": 3,
				"cabt_option_type_raw": 3,
			}
		),
		1,
		1,
		{"type": 1, "context": 3}
	)
	if selected.is_empty():
		return false
	var index := int(selected[0])
	if index < 0 or index >= bench.size():
		return false
	var energy_discard: Array[CardInstance] = []
	for value: Variant in data.get("energy_discard", []):
		if value is CardInstance:
			energy_discard.append(value)
	var consumed_data := data.duplicate(true)
	_clear_prompt_if_same(battle_scene, "retreat_bench", player_index)
	if not _gsm.retreat(player_index, energy_discard, bench[index]):
		_restore_prompt_if_unclaimed(battle_scene, "retreat_bench", consumed_data)
		_engine_rejections += 1
		return false
	_engine_commits += 1
	if battle_scene.has_method("_refresh_ui_after_successful_action"):
		battle_scene.call("_refresh_ui_after_successful_action", false, player_index)
	return true


func _run_main_step(battle_scene: Control) -> bool:
	if _start_missing_evolve_trigger_interaction(battle_scene):
		return true
	var actions: Array[Dictionary] = _legal_action_builder.call("build_actions", _gsm, player_index)
	if actions.is_empty():
		return false
	actions = _cabt_order_main_action_tail(actions)
	var options := _options_for_items(actions, "")
	var selected := _select_items("main", options, 1, 1)
	if selected.is_empty():
		return false
	var index := int(selected[0])
	if index < 0 or index >= actions.size():
		_invalid_outputs += 1
		return false
	var committed := bool(_engine_executor.call("execute", player_index, battle_scene, _gsm, actions[index]))
	if committed:
		_engine_commits += 1
	else:
		_engine_rejections += 1
	return committed


func _start_missing_evolve_trigger_interaction(battle_scene: Control) -> bool:
	if (
		battle_scene == null
		or not battle_scene.has_method("_try_start_evolve_trigger_ability_interaction")
		or str(battle_scene.get("_pending_choice")) != ""
	):
		return false
	var state: GameState = _gsm.game_state
	var player: PlayerState = state.players[player_index]
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.turn_evolved != int(state.turn_number):
			continue
		var steps: Array[Dictionary] = _gsm.get_evolve_ability_interaction_steps(slot)
		if steps.is_empty():
			continue
		battle_scene.call("_try_start_evolve_trigger_ability_interaction", player_index, slot)
		return str(battle_scene.get("_pending_choice")) == "effect_interaction"
	return false


func _cabt_order_main_action_tail(actions: Array[Dictionary]) -> Array[Dictionary]:
	# The official MAIN frontier emits attacks before retreat, with END last.
	# Preserve the builder's order within every group and leave all hand/ability
	# actions untouched; only the engine-owned terminal action tail is aligned.
	var prefix: Array[Dictionary] = []
	var attacks: Array[Dictionary] = []
	var retreats: Array[Dictionary] = []
	var ends: Array[Dictionary] = []
	for action: Dictionary in actions:
		match str(action.get("kind", "")):
			"attack", "granted_attack": attacks.append(action)
			"retreat": retreats.append(action)
			"end_turn": ends.append(action)
			_: prefix.append(action)
	var ordered: Array[Dictionary] = []
	ordered.append_array(prefix)
	ordered.append_array(attacks)
	ordered.append_array(retreats)
	ordered.append_array(ends)
	return ordered


func _pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
	if not validate_integrity() or items.is_empty():
		return []
	var minimum := clampi(int(step.get("min_select", 1)), 0, items.size())
	var maximum := clampi(int(step.get("max_select", maxi(1, minimum))), minimum, items.size())
	var prompt_kind := _prompt_kind_for_step(step)
	var option_context := _context.duplicate(true)
	var raw_semantics := _select_raw_semantics_for_step(step, prompt_kind, false)
	option_context["cabt_select_type_raw"] = raw_semantics.get("type")
	option_context["cabt_select_context_raw"] = raw_semantics.get("context")
	var ucis_option_type := _ucis_option_type_for_step(step, false)
	# YES_NO owns option type per current candidate (YES=1, NO=2). A
	# step-level default must not collapse both choices to one wire type.
	if ucis_option_type >= 0 and int(raw_semantics.get("type", -1)) != 9:
		option_context["cabt_option_type_raw"] = ucis_option_type
	elif prompt_kind == "discard":
		option_context["cabt_option_type_raw"] = 3
	if not option_context.get("source_card") is CardInstance:
		var pending_card: Variant = option_context.get("pending_effect_card")
		if pending_card is CardInstance:
			option_context["source_card"] = pending_card
		else:
			var pending_slot: Variant = option_context.get("pending_effect_slot")
			if pending_slot is PokemonSlot and pending_slot.get_top_card() != null:
				option_context["source_card"] = pending_slot.get_top_card()
	var selected := _select_items(
		prompt_kind,
		_options_for_items(items, _option_kind_for_prompt(prompt_kind), option_context),
		minimum,
		maximum,
		raw_semantics
	)
	var result: Array = []
	for raw_index: Variant in selected:
		var index := int(raw_index)
		if index >= 0 and index < items.size() and items[index] not in result:
			result.append(items[index])
	return result


func _should_preserve_empty_interaction_selection(step: Dictionary, _context: Dictionary = {}) -> bool:
	return (
		_uses_competitive_policy_v2()
		and int(step.get("min_select", 1)) == 0
		and not has_pending_external_decision()
	)


func has_pending_external_decision() -> bool:
	return _last_error_code == "decision_pending" and (
		_external_decision_port != null or has_pending_policy_decision()
	)


func uses_external_decision_port() -> bool:
	return _external_decision_port != null


func external_decision_failure_code() -> String:
	if _external_decision_port == null or _last_error_code in ["", "decision_pending"]:
		return ""
	return _last_error_code


func external_decision_failure_detail() -> Dictionary:
	if _external_decision_port == null or not _external_decision_port.has_method("audit_snapshot"):
		return {}
	var audit: Dictionary = _external_decision_port.call("audit_snapshot")
	var detail: Variant = audit.get("fault_detail", {})
	return (detail as Dictionary).duplicate(true) if detail is Dictionary else {}


func _pick_interaction_target_index(
	items: Array,
	excluded_targets: Array,
	step: Dictionary,
	context: Dictionary = {}
) -> int:
	if not _uses_competitive_policy_v2() or not validate_integrity() or items.is_empty():
		return -1
	var legal_items: Array = []
	var source_indexes: Array[int] = []
	for index: int in items.size():
		if index in excluded_targets:
			continue
		legal_items.append(items[index])
		source_indexes.append(index)
	if legal_items.is_empty():
		return -1
	var options: Array = []
	var option_context := context.duplicate(true)
	var target_semantics := _select_raw_semantics_for_step(step, "assignment_target", true)
	option_context["cabt_select_type_raw"] = target_semantics.get("type")
	option_context["cabt_select_context_raw"] = target_semantics.get("context")
	var ucis_target_option_type := _ucis_option_type_for_step(step, true)
	if ucis_target_option_type >= 0:
		option_context["cabt_option_type_raw"] = ucis_target_option_type
	for index: int in legal_items.size():
		options.append(_make_option(index, legal_items[index], "assignment_target", option_context))
	var selected := _select_items(
		"assignment_target",
		options,
		1,
		1,
		target_semantics
	)
	if selected.size() != 1:
		return -1
	var local_index := int(selected[0])
	return source_indexes[local_index] if local_index >= 0 and local_index < source_indexes.size() else -1


func _select_items(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int,
	raw_semantics_override: Dictionary = {}
) -> Array[int]:
	if options.is_empty() or not validate_integrity():
		return []
	if _uses_competitive_policy_v2():
		var entity_error := _sync_public_pokemon_entities()
		if not entity_error.is_empty():
			_policy_errors += 1
			_last_error_code = entity_error
			return []
	var selector: Variant = _external_decision_port if _external_decision_port != null else _policy
	var started_usec := Time.get_ticks_usec()
	var frame: Dictionary = {}
	var response: Dictionary = {}
	var worker_model_decision: Variant = null
	var call_index := 0
	if _policy_execution_profile == POLICY_EXECUTION_WORKER and _external_decision_port == null:
		var worker_outcome := _poll_or_schedule_policy_worker(
			prompt_kind, options, minimum, maximum, raw_semantics_override
		)
		if not bool(worker_outcome.get("ready", false)):
			_last_error_code = "decision_pending"
			return []
		frame = worker_outcome.get("frame", {}).duplicate(true)
		response = worker_outcome.get("response", {}).duplicate(true)
		worker_model_decision = worker_outcome.get("model_decision")
		started_usec = int(worker_outcome.get("started_usec", started_usec))
		call_index = int(worker_outcome.get("call_index", 0))
	else:
		frame = _build_frame(prompt_kind, options, minimum, maximum, raw_semantics_override)
		_policy_calls += 1
		call_index = _policy_calls
		var decision_started_usec := Time.get_ticks_usec()
		_write_competition_agent_timing_event("decision_started", call_index, 0)
		response = selector.select(frame)
		var decision_elapsed_usec := maxi(0, Time.get_ticks_usec() - decision_started_usec)
		_decision_elapsed_usec.append(decision_elapsed_usec)
		_write_competition_agent_timing_event(
			"decision_completed", call_index, decision_elapsed_usec
		)
	if _external_decision_port != null and bool(response.get("decision_pending", false)):
		_last_error_code = "decision_pending"
		return []
	var response_error := str(response.get("error_code", "package_policy_error"))
	if bool(response.get("ok", false)):
		var source: Dictionary = frame.get("source", {})
		var expected_source := str(selector.call("expected_selection_source")) \
			if selector.has_method("expected_selection_source") else "restricted_ir_same_window"
		if (
			response.get("public_observation_hash") != source.get("public_observation_hash")
			or response.get("window_id") != source.get("window_id")
			or response.get("selection_source") != expected_source
		):
			response_error = "stale_policy_response"
		else:
			var validated_result: Variant = _validated_indexes(
				response.get("selected_indexes", []), options.size(), minimum, maximum
			)
			if validated_result != null:
				var validated: Array[int] = validated_result
				if (
					_external_decision_port != null
					and not bool(_external_decision_port.call("acknowledge_selection", frame, validated))
				):
					response_error = "external_commit_ack_mismatch"
					_invalid_outputs += 1
				else:
					var final_indexes: Array[int] = validated
					if (
						_external_decision_port == null
						and _model_actor != null
						and _pins.get("policy_mode") == "rules_with_model"
					):
						_model_decision_windows += 1
						var model_frontier := _model_frontier_from_response(
							response, validated, options.size()
						)
						var model_decision: Dictionary = {}
						if _policy_execution_profile == POLICY_EXECUTION_WORKER:
							model_decision = (worker_model_decision as Dictionary).duplicate(true) \
								if worker_model_decision is Dictionary else {
									"selected_indexes": validated.duplicate(),
									"model_used": false,
									"diagnostic_code": "model_worker_result_missing",
									"elapsed_us": 0,
								}
						else:
							model_decision = _model_actor.decide_development_frame(
								frame, validated, model_frontier
							)
						var model_code := str(model_decision.get("diagnostic_code", ""))
						if bool(model_decision.get("model_used", false)):
							var model_validated: Variant = _validated_indexes(
								model_decision.get("selected_indexes", []),
								options.size(), minimum, maximum
							)
							if model_validated != null:
								final_indexes = model_validated
								_model_inference_successes += 1
								_model_elapsed_usec.append(int(model_decision.get("elapsed_us", 0)))
								if final_indexes != validated:
									_model_changed_selections += 1
							else:
								model_code = "model_output_shape_invalid"
						if not model_code.is_empty():
							_model_diagnostic_counts[model_code] = int(
								_model_diagnostic_counts.get(model_code, 0)
							) + 1
							if not model_code.begins_with("model_bypassed_"):
								_model_fallbacks += 1
						var decision_audit: Dictionary = response.get("decision_audit", {}).duplicate(true) \
							if response.get("decision_audit") is Dictionary else {}
						decision_audit["model"] = {
							"invoked": bool(model_decision.get("model_used", false)),
							"diagnostic_code": model_code,
							"fallback_indexes": validated.duplicate(),
							"selected_indexes": final_indexes.duplicate(),
							"elapsed_us": int(model_decision.get("elapsed_us", 0)),
							"model_manifest_sha256": model_decision.get("model_manifest_sha256"),
							"model_artifact_sha256": model_decision.get("model_artifact_sha256"),
						}
						response["decision_audit"] = decision_audit
					_policy_successes += 1
					_last_error_code = ""
					var elapsed := maxi(0, Time.get_ticks_usec() - started_usec)
					_queue_developer_decision(frame, response, final_indexes, "accepted", false, "", elapsed)
					return final_indexes
			else:
				response_error = "invalid_policy_output"
				_invalid_outputs += 1
	_policy_errors += 1
	_last_error_code = response_error
	var elapsed := maxi(0, Time.get_ticks_usec() - started_usec)
	if _external_decision_port != null:
		# A differential decision port must fail at this immutable window. A
		# fallback would silently execute an action after a contract failure.
		_queue_developer_decision(frame, response, [], "rejected", false, response_error, elapsed)
		return []
	_same_window_fallbacks += 1
	var fallback := _same_window_fallback(options, minimum, maximum, prompt_kind)
	_queue_developer_decision(frame, response, fallback, "same_window_fallback", true, response_error, elapsed)
	return fallback


func _poll_or_schedule_policy_worker(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int,
	raw_semantics_override: Dictionary
) -> Dictionary:
	if _policy_worker == null:
		_policy_worker = PolicyWorkerScript.new()
	if not _pending_policy_context.is_empty():
		if not bool(_policy_worker.call("is_ready")):
			return {"ready": false}
		var completed: Dictionary = _policy_worker.call("take_result")
		if not bool(completed.get("ready", false)):
			return {"ready": false}
		var context := _pending_policy_context.duplicate(true)
		_pending_policy_context.clear()
		var decision_elapsed_usec := maxi(
			0, Time.get_ticks_usec() - int(context.get("decision_started_usec", 0))
		)
		_decision_elapsed_usec.append(decision_elapsed_usec)
		_write_competition_agent_timing_event(
			"decision_completed", int(context.get("call_index", 0)), decision_elapsed_usec
		)
		_cached_policy_audit = _read_policy_audit_now()
		var current_fingerprint := _current_selection_request_fingerprint(
			prompt_kind, options, minimum, maximum, raw_semantics_override
		)
		if current_fingerprint != str(context.get("request_fingerprint", "")):
			_policy_worker_stale_results += 1
			return {
				"ready": true,
				"frame": _build_frame(
					prompt_kind, options, minimum, maximum, raw_semantics_override
				),
				"response": {"ok": false, "error_code": "stale_policy_response"},
				"started_usec": context.get("started_usec", Time.get_ticks_usec()),
				"call_index": context.get("call_index", 0),
			}
		var ready_outcome := {
			"ready": true,
			"frame": context.get("frame", {}).duplicate(true),
			"response": completed.get("response", {}).duplicate(true),
			"started_usec": context.get("started_usec", Time.get_ticks_usec()),
			"call_index": context.get("call_index", 0),
		}
		if completed.get("model_decision") is Dictionary:
			ready_outcome["model_decision"] = completed.get("model_decision", {}).duplicate(true)
		return ready_outcome

	var started_usec := Time.get_ticks_usec()
	var frame := _build_frame(prompt_kind, options, minimum, maximum, raw_semantics_override)
	_policy_calls += 1
	var call_index := _policy_calls
	var decision_started_usec := Time.get_ticks_usec()
	_write_competition_agent_timing_event("decision_started", call_index, 0)
	var scheduled: Dictionary = _policy_worker.call(
		"start",
		_policy,
		frame,
		_model_actor,
		_model_actor != null and _pins.get("policy_mode") == "rules_with_model"
	)
	if not bool(scheduled.get("ok", false)):
		_policy_worker_start_failures += 1
		_write_competition_agent_timing_event("decision_completed", call_index, 0)
		return {
			"ready": true,
			"frame": frame,
			"response": {
				"ok": false,
				"error_code": str(scheduled.get("error_code", "policy_worker_start_failed")),
			},
			"started_usec": started_usec,
			"call_index": call_index,
		}
	_policy_worker_schedules += 1
	_pending_policy_context = {
		"frame": frame.duplicate(true),
		"request_fingerprint": _selection_request_fingerprint_from_frame(frame),
		"started_usec": started_usec,
		"decision_started_usec": decision_started_usec,
		"call_index": call_index,
	}
	return {"ready": false}


func _selection_request_fingerprint_from_frame(frame: Dictionary) -> String:
	var hashed: Dictionary = TreeHashScript.public_observation_hash({
		"seat": frame.get("seat"),
		"prompt_kind": frame.get("prompt_kind"),
		"public_state": frame.get("public_state", {}),
		"select_semantics": frame.get("select_semantics", {}),
		"options": frame.get("options", []),
	})
	return str(hashed.get("sha256", ""))


func _current_selection_request_fingerprint(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int,
	raw_semantics_override: Dictionary
) -> String:
	var hashed: Dictionary = TreeHashScript.public_observation_hash({
		"seat": player_index,
		"prompt_kind": prompt_kind,
		"public_state": _build_public_state(),
		"select_semantics": _selection_semantics(
			prompt_kind, minimum, maximum, raw_semantics_override
		),
		"options": options,
	})
	return str(hashed.get("sha256", ""))


func _write_competition_agent_timing_event(
	event_kind: String, call_index: int, elapsed_usec: int
) -> void:
	var timing_dir := OS.get_environment("PTCGDAP_COMPETITION_AGENT_TIMING_DIR")
	if (
		timing_dir.is_empty()
		or player_index not in [0, 1]
		or call_index < 1
		or event_kind not in ["decision_started", "decision_completed"]
	):
		return
	var suffix := "started" if event_kind == "decision_started" else "completed"
	var final_path := "%s/seat-%d-call-%06d-%s.json" % [
		timing_dir, player_index, call_index, suffix,
	]
	var temporary_path := final_path + ".tmp"
	var event := {
		"document_type": "godot_v18_agent_timing_event_v1",
		"event_kind": event_kind,
		"seat": player_index,
		"call_index": call_index,
		"observed_at_epoch_milliseconds": int(
			Time.get_unix_time_from_system() * 1000.0
		),
		"elapsed_usec": maxi(0, elapsed_usec),
	}
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(event))
	file.flush()
	file.close()
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	if DirAccess.rename_absolute(temporary_path, final_path) != OK:
		DirAccess.remove_absolute(temporary_path)


func _uses_competitive_policy_v2() -> bool:
	return (
		_external_decision_port != null
		or (
			_policy != null
			and _policy.has_method("requires_competitive_frame_v2")
			and bool(_policy.call("requires_competitive_frame_v2"))
		)
	)


func _queue_developer_decision(
	frame: Dictionary,
	response: Dictionary,
	accepted_indexes: Array,
	host_status: String,
	fallback_used: bool,
	error_code: String,
	elapsed_usec: int,
) -> void:
	if not _developer_trace_enabled:
		return
	if _developer_decision_records.size() >= 2048:
		_developer_trace_dropped_records += 1
		return
	var traced_frame := frame.duplicate(true)
	var source: Dictionary = traced_frame.get("source", {})
	var traced_options: Array = []
	var fingerprints_by_index: Dictionary = {}
	for option_value: Variant in traced_frame.get("options", []):
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value.duplicate(true)
		var fingerprint: Dictionary = TreeHashScript.public_observation_hash({
			"profile_id": "ptcgdap-scoped-option-fingerprint-v1",
			"public_observation_hash": source.get("public_observation_hash"),
			"window_id": source.get("window_id"),
			"index": option.get("index"),
			"option": option.duplicate(true),
		})
		option["option_fingerprint"] = fingerprint.get("sha256")
		traced_options.append(option)
		fingerprints_by_index[int(option.get("index", -1))] = fingerprint.get("sha256")
	traced_frame["options"] = traced_options
	var decision_audit: Dictionary = response.get("decision_audit", {}).duplicate(true) \
		if response.get("decision_audit") is Dictionary else {}
	var reported_indexes: Array = []
	if response.get("selected_indexes") is Array:
		for value: Variant in response.get("selected_indexes"):
			if typeof(value) == TYPE_INT:
				reported_indexes.append(int(value))
	var matched_rule_ids: Array = []
	for value: Variant in response.get("matched_rule_ids", []):
		if typeof(value) == TYPE_STRING:
			matched_rule_ids.append(str(value))
	var base_result: Dictionary = decision_audit.get("base_result", {}).duplicate(true) \
		if decision_audit.get("base_result") is Dictionary else {}
	var accepted_fingerprints: Array = []
	for value: Variant in accepted_indexes:
		var index := int(value)
		if fingerprints_by_index.has(index):
			accepted_fingerprints.append(fingerprints_by_index[index])
	_developer_decision_records.append({
		"document_type": "decision_window_record_v1",
		"schema_version": 1,
		"decision_id": "%s.window.%d" % [_match_id, int(frame.get("sequence", 0))],
		"policy_match_id": _match_id,
		"frame": traced_frame,
		"policy": {
			"ok": bool(response.get("ok", false)),
			"error_code": str(response.get("error_code", "")),
			"reported_output_type": type_string(typeof(response.get("selected_indexes"))),
			"reported_indexes": reported_indexes,
			"selection_source": str(response.get("selection_source", "")),
			"reported_public_observation_hash": str(response.get("public_observation_hash", "")),
			"reported_window_id": str(response.get("window_id", "")),
			"matched_rule_ids": matched_rule_ids,
			"macro_proposal_indexes": decision_audit.get("macro_proposal_indexes", []).duplicate(true) \
				if decision_audit.get("macro_proposal_indexes") is Array else [],
			"base_result": base_result,
		},
		"host": {
			"status": host_status,
			"accepted_indexes": accepted_indexes.duplicate(true),
			"accepted_option_fingerprints": accepted_fingerprints,
			"fallback_used": fallback_used,
			"error_code": error_code,
			"latency_usec": elapsed_usec,
		},
	})


func _build_frame(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int,
	raw_semantics_override: Dictionary = {}
) -> Dictionary:
	_sequence += 1
	_prompt_counts[prompt_kind] = int(_prompt_counts.get(prompt_kind, 0)) + 1
	var state := _build_public_state()
	var competitive := _uses_competitive_policy_v2()
	var observation_source := {
		"schema_version": 2 if competitive else 1,
		"sequence": _sequence,
		"seat": player_index,
		"prompt_kind": prompt_kind,
		"public_state": state,
	}
	var observation: Dictionary = TreeHashScript.public_observation_hash(observation_source)
	var semantics := _selection_semantics(
		prompt_kind, minimum, maximum, raw_semantics_override
	)
	var window: Dictionary = TreeHashScript.public_observation_hash({
		"public_observation_hash": observation.get("sha256"),
		"select_semantics": semantics,
		"options": options,
	})
	var frame := {
		"schema_version": 2 if competitive else 1,
		"profile_id": "ptcgdap-competitive-public-frame-v2" if competitive else PROFILE_ID,
		"sequence": _sequence,
		"seat": player_index,
		"prompt_kind": prompt_kind,
		"source": {
			"public_observation_hash": observation.get("sha256"),
			"window_id": window.get("sha256"),
		},
		"public_state": state,
		"select_semantics": semantics,
		"options": options,
	}
	if not competitive:
		frame["strategy_id"] = STRATEGY_ID
		frame["card_id_domain"] = CARD_ID_DOMAIN
	return frame


func _selection_semantics(
	prompt_kind: String,
	minimum: int,
	maximum: int,
	raw_semantics_override: Dictionary = {}
) -> Dictionary:
	var competitive := _uses_competitive_policy_v2()
	var raw_semantics := raw_semantics_override \
		if competitive and not raw_semantics_override.is_empty() \
		else _select_raw_semantics(prompt_kind)
	var semantics := {
		"min_count": minimum,
		"max_count": maximum,
		"select_type_raw": raw_semantics.get("type"),
		"select_context_raw": raw_semantics.get("context"),
	}
	# Competitive v2 is a frozen, closed-key author-policy contract. The CABT
	# selection window and UCIS runtime retain their remain-* facts in their own
	# typed owners; they must not leak into this older public projection.
	if _authority_mode == "a3_private_oracle_research":
		semantics["remain_damage_counter"] = maxi(
			0, int(raw_semantics.get("remainDamageCounter", 0))
		)
		semantics["remain_energy_cost"] = maxi(
			0, int(raw_semantics.get("remainEnergyCost", 0))
		)
	return semantics


func _build_public_state() -> Dictionary:
	var state := _gsm.game_state
	var own: PlayerState = state.players[player_index]
	var opponent: PlayerState = state.players[1 - player_index]
	return {
		"turn_number": maxi(0, int(state.turn_number)),
		"phase": _phase_name(state),
		"self": {
			"hand": _public_cards(own.hand),
			"active": _public_slot_list(own.active_pokemon),
			"bench": _public_slots(own.bench),
			"bench_capacity": BenchLimitScript.get_bench_limit_for_player(
				state, own, _gsm.effect_processor
			),
			"discard": _public_cards(own.discard_pile),
			"deck_count": own.deck.size(),
			"prizes_remaining": own.prizes.size(),
			"turn": {
				"supporter_available": not bool(state.supporter_used_this_turn),
				"manual_attachment_available": not bool(state.energy_attached_this_turn),
				"retreat_available": not bool(state.retreat_used_this_turn),
			},
		},
		"opponent": {
			"hand_count": opponent.hand.size(),
			"active": _public_slot_list(opponent.active_pokemon),
			"bench": _public_slots(opponent.bench),
			"discard": _public_cards(opponent.discard_pile),
			"deck_count": opponent.deck.size(),
			"prizes_remaining": opponent.prizes.size(),
		},
	}


func _options_for_items(
	items: Array,
	forced_kind: String,
	interaction_context: Dictionary = {}
) -> Array:
	var options: Array = []
	for index: int in items.size():
		var item_kind := forced_kind
		if int(interaction_context.get("cabt_select_type_raw", -1)) == 9:
			var item: Variant = items[index]
			if typeof(item) == TYPE_BOOL:
				item_kind = "yes" if bool(item) else "no"
			elif item is Dictionary and str((item as Dictionary).get("kind", "")) in ["yes", "no"]:
				item_kind = str((item as Dictionary).get("kind"))
		options.append(_make_option(index, items[index], item_kind, interaction_context))
	return options


func _make_option(
	index: int,
	item: Variant,
	forced_kind: String,
	interaction_context: Dictionary = {}
) -> Dictionary:
	var action: Dictionary = item if item is Dictionary else {}
	var kind := forced_kind if not forced_kind.is_empty() else str(action.get("kind", "effect_target"))
	var card: CardInstance = action.get("card") as CardInstance
	var source_slot: PokemonSlot = action.get("source_slot") as PokemonSlot
	if card == null and action.get("source") is CardInstance:
		card = action.get("source") as CardInstance
	if source_slot == null and action.get("source") is PokemonSlot:
		source_slot = action.get("source") as PokemonSlot
	var target_slot: PokemonSlot = action.get("target_slot") as PokemonSlot
	if target_slot == null:
		target_slot = action.get("bench_target") as PokemonSlot
	if not item is Dictionary:
		if item is CardInstance:
			card = item
		elif item is PokemonSlot:
			target_slot = item
	# An attached-card source option represents both the movable card and its
	# current public owner.  Keep the effect program in source_uid/source_serial,
	# while reusing the frozen target profile fields for the current attachment
	# binding.  Hand/deck candidates intentionally have no owner profile.
	if target_slot == null and kind == "assignment_source" and card != null:
		target_slot = _find_attached_card_owner_slot(card)
	var granted_attack_identity: Dictionary = {}
	if kind == "granted_attack":
		granted_attack_identity = _resolve_granted_attack_identity(action, source_slot)
	var card_uid: Variant = _uid_for_card(card) if card != null else null
	if card_uid == null and item is CardData:
		card_uid = (item as CardData).get_uid()
	var source_uid: Variant = _uid_for_slot(source_slot) if source_slot != null else null
	var granted_source_card: CardInstance = granted_attack_identity.get("card") as CardInstance
	if granted_source_card != null:
		source_uid = _uid_for_card(granted_source_card)
	elif kind == "use_stadium_effect" and card != null:
		source_uid = _uid_for_card(card)
	var target_uid: Variant = _uid_for_slot(target_slot) if target_slot != null else null
	if source_uid == null and kind in ["attack", "granted_attack"]:
		source_uid = _uid_for_slot(_gsm.game_state.players[player_index].active_pokemon)
	var source_card: CardInstance = interaction_context.get("source_card") as CardInstance
	# Keep the originating public effect identity stable across a multi-window
	# assignment. `source_card` becomes the already selected movable unit in an
	# assignment_target window; it must not replace the Trainer/Ability that
	# owns the interaction program.
	var effect_source_card: CardInstance = interaction_context.get("pending_effect_card") as CardInstance
	if effect_source_card == null:
		var effect_source_slot: PokemonSlot = interaction_context.get("pending_effect_slot") as PokemonSlot
		if effect_source_slot != null:
			effect_source_card = effect_source_slot.get_top_card()
	if card == null and source_card != null:
		card = source_card
		card_uid = _uid_for_card(source_card)
	var identity_source_card: CardInstance = effect_source_card \
		if effect_source_card != null else source_card
	if source_uid == null and identity_source_card != null:
		source_uid = _uid_for_card(identity_source_card)
	var raw_attack_index := int(
		granted_attack_identity.get("attack_index", action.get("attack_index", -1))
	)
	var attack_index_value: Variant = raw_attack_index if raw_attack_index >= 0 else null
	var option_number: Variant = action.get("number") \
		if typeof(action.get("number")) == TYPE_INT else null
	var raw_option_type := _resolved_option_type_raw(
		kind, action, card, source_slot, interaction_context
	)
	var energy_type_raw: Variant = action.get("energy_type_raw") \
		if typeof(action.get("energy_type_raw")) == TYPE_INT else null
	if energy_type_raw == null and raw_option_type == 6:
		energy_type_raw = _energy_type_raw_from_action(action, source_slot)
	var energy_count: Variant = action.get("energy_count") \
		if typeof(action.get("energy_count")) == TYPE_INT else null
	if energy_count == null and raw_option_type == 6:
		energy_count = int(action.get("count", 1))
	var special_condition_type: Variant = action.get("special_condition_type") \
		if typeof(action.get("special_condition_type")) == TYPE_INT else null
	var option_area_raw: Variant = interaction_context.get("option_area_raw") \
		if typeof(interaction_context.get("option_area_raw")) == TYPE_INT else null
	var option_area_index: Variant = item \
		if kind == "take_prize" and typeof(item) == TYPE_INT else null
	var option_card_uid: Variant = card_uid
	var option_card_serial: Variant = _serial_for_card(card) if card != null else null
	# OptionType.CARD names the candidate represented by this option.  During a
	# source-to-target assignment the interaction context also carries the
	# already selected source card; that source must never replace the target
	# Pokemon identity in the fresh ATTACH_FROM window.
	if raw_option_type == 3 and target_slot != null:
		option_card_uid = target_uid
		option_card_serial = _serial_for_card(target_slot.get_top_card())
	var tags: Array = []
	if kind in ["attack", "granted_attack"]:
		tags.append("attack")
	if bool(action.get("projected_knockout", false)):
		tags.append("projected_knockout")
	if not _uses_competitive_policy_v2():
		return {
			"index": index,
			"kind": kind,
			"card_uid": option_card_uid,
			"card_serial": option_card_serial,
			"source_uid": source_uid,
			"target_uid": target_uid,
			"target_remaining_hp": maxi(0, target_slot.get_remaining_hp()) if target_slot != null else null,
			"target_prize_value": target_slot.get_prize_count() if target_slot != null else null,
			"attached_energy_count": target_slot.attached_energy.size() if target_slot != null else null,
			"attack_index": attack_index_value,
			"option_number": option_number,
			"tags": tags,
			"option_type_raw": raw_option_type,
			"option_card_uid": target_uid if kind == "evolve" else option_card_uid,
			"option_player_index": player_index,
			"energy_type_raw": energy_type_raw,
			"energy_count": energy_count,
			"special_condition_type": special_condition_type,
		}
	var target_profile := _slot_attack_profile(target_slot, interaction_context) \
		if target_slot != null else {}
	var source_serial: Variant = null
	if granted_source_card != null:
		source_serial = _serial_for_card(granted_source_card)
	elif source_slot != null:
		source_serial = _serial_for_card(source_slot.get_top_card())
	elif kind == "use_stadium_effect" and card != null:
		source_serial = _serial_for_card(card)
	elif identity_source_card != null:
		source_serial = _serial_for_card(identity_source_card)
	var target_serial: Variant = _serial_for_card(target_slot.get_top_card()) \
		if target_slot != null else null
	var raw_projected_damage: Variant = action.get("projected_damage")
	var projected_damage: Variant = raw_projected_damage \
		if typeof(raw_projected_damage) == TYPE_INT and raw_projected_damage >= 0 else null
	var raw_ability_index := int(action.get("ability_index", -1))
	var ability_index_value: Variant = raw_ability_index if raw_ability_index >= 0 else null
	var competitive_option := {
		"index": index,
		"kind": kind,
		"card_uid": option_card_uid,
		"card_serial": option_card_serial,
		"source_uid": source_uid,
		"source_serial": source_serial,
		"source_entity_serial": _entity_serial_for_slot(source_slot),
		"target_uid": target_uid,
		"target_serial": target_serial,
		"target_entity_serial": _entity_serial_for_slot(target_slot),
		"target_remaining_hp": maxi(0, target_slot.get_remaining_hp()) if target_slot != null else null,
		"target_prize_value": clampi(target_slot.get_prize_count(), 1, 3) if target_slot != null else null,
		"target_attached_energy_count": target_profile.get("attached_energy_count") if target_slot != null else null,
		"target_attached_energy_uids": target_profile.get("attached_energy_uids", []).duplicate() \
			if target_slot != null else null,
		"target_minimum_attack_energy_count": target_profile.get("minimum_attack_energy_count") if target_slot != null else null,
		"target_attack_ready": target_profile.get("attack_ready") if target_slot != null else null,
		"target_energy_debt": target_profile.get("energy_debt") if target_slot != null else null,
		"projected_damage": projected_damage,
		"projected_knockout": bool(action.get("projected_knockout", false)),
		"requires_interaction": bool(action.get("requires_interaction", false)),
		"attack_index": attack_index_value,
		"option_number": option_number,
		"ability_index": ability_index_value,
		"energy_type_raw": energy_type_raw,
		"energy_count": energy_count,
		"special_condition_type": special_condition_type,
		"pending_assignment_count": int(target_profile.get("pending_assignment_count", 0)),
		"tags": tags,
		"option_type_raw": raw_option_type,
		"option_player_index": player_index,
	}
	# The private A3 research port has a separate, explicitly reviewed position
	# shape. Frozen data-only Competitive v2 packages do not receive these keys.
	if _authority_mode == "a3_private_oracle_research":
		competitive_option["option_area_raw"] = option_area_raw
		competitive_option["option_area_index"] = option_area_index
	return competitive_option


func _resolve_granted_attack_identity(action: Dictionary, source_slot: PokemonSlot) -> Dictionary:
	if source_slot == null:
		return {}
	var granted: Variant = action.get("granted_attack_data")
	if not granted is Dictionary:
		return {}
	var granted_attack: Dictionary = granted
	var original_instance_id := int(granted_attack.get("original_card_instance_id", -1))
	var original_attack_index := int(granted_attack.get("original_attack_index", -1))
	if original_instance_id > 0 and original_attack_index >= 0:
		for stack_card: CardInstance in source_slot.pokemon_stack:
			if stack_card != null and int(stack_card.instance_id) == original_instance_id:
				return {"card": stack_card, "attack_index": original_attack_index}
	if str(granted_attack.get("source", "")) == "tool" and source_slot.attached_tool != null:
		# Technical Machines expose one printed granted attack. Bind its public
		# attack identity to the attached Tool printing, not to the attacker.
		return {"card": source_slot.attached_tool, "attack_index": 0}
	return {}


func _slot_attack_profile(slot: PokemonSlot, interaction_context: Dictionary) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {}
	var attached: Array[CardInstance] = slot.attached_energy.duplicate()
	var pending_count := 0
	for assignment_value: Variant in interaction_context.get("pending_assignments", []):
		if not assignment_value is Dictionary or assignment_value.get("target") != slot:
			continue
		var pending_card: CardInstance = assignment_value.get("source") as CardInstance
		if pending_card != null:
			attached.append(pending_card)
			pending_count += 1
	var attached_uids: Array = []
	for energy: CardInstance in attached:
		var uid: Variant = _uid_for_card(energy)
		if uid != null:
			attached_uids.append(uid)
	var minimum_cost := 0
	var minimum_debt := 0
	var has_attack := false
	for attack_value: Variant in slot.get_card_data().attacks:
		if not attack_value is Dictionary:
			continue
		var cost := CardData.normalize_attack_cost(str(attack_value.get("cost", "")))
		var count := cost.length()
		var debt := _missing_energy_units(attached, cost)
		if not has_attack or debt < minimum_debt or (debt == minimum_debt and count < minimum_cost):
			minimum_cost = count
			minimum_debt = debt
		has_attack = true
	var evaluation_slot := slot
	var simulated: PokemonSlot = null
	if pending_count > 0:
		simulated = PokemonSlot.new()
		simulated.pokemon_stack = slot.pokemon_stack.duplicate()
		simulated.attached_energy = attached
		simulated.attached_tool = slot.attached_tool
		simulated.damage_counters = slot.damage_counters
		simulated.status_conditions = slot.status_conditions.duplicate(true)
		simulated.effects = slot.effects.duplicate(true)
		evaluation_slot = simulated
	var ready := false
	if has_attack and _gsm != null and _gsm.rule_validator != null:
		for attack_value: Variant in slot.get_card_data().attacks:
			if not attack_value is Dictionary:
				continue
			var cost := CardData.normalize_attack_cost(str(attack_value.get("cost", "")))
			if _gsm.rule_validator.has_enough_energy(
				evaluation_slot, cost, _gsm.effect_processor, _gsm.game_state
			):
				ready = true
				break
	return {
		"attached_energy_count": attached.size(),
		"attached_energy_uids": attached_uids,
		"minimum_attack_energy_count": minimum_cost,
		"attack_ready": ready,
		"energy_debt": minimum_debt if has_attack else 0,
		"pending_assignment_count": pending_count,
	}


func _missing_energy_units(attached: Array[CardInstance], raw_cost: String) -> int:
	var cost := CardData.normalize_attack_cost(raw_cost)
	if cost.is_empty():
		return 0
	var required := {}
	for symbol: String in cost:
		required[symbol] = int(required.get(symbol, 0)) + 1
	var available := {}
	var colorless_pool := 0
	var any_pool := 0
	var flexible_pools: Array[Dictionary] = []
	for energy: CardInstance in attached:
		if energy == null or energy.card_data == null:
			continue
		var energy_type := energy.card_data.energy_provides
		var energy_count := 1
		if _gsm != null and _gsm.effect_processor != null:
			energy_type = _gsm.effect_processor.get_energy_type(energy, _gsm.game_state)
			energy_count = _gsm.effect_processor.get_energy_colorless_count(energy, _gsm.game_state)
			var energy_types := _gsm.effect_processor.get_energy_types(energy, _gsm.game_state)
			if energy_types.size() > 1:
				flexible_pools.append({"types": energy_types, "remaining": energy_count})
				continue
		if energy_type.is_empty():
			energy_type = "C"
		if energy_type == "ANY":
			any_pool += energy_count
		elif energy_type == "C":
			colorless_pool += energy_count
		else:
			available[energy_type] = int(available.get(energy_type, 0)) + energy_count
	var debt := 0
	var remaining_energy := colorless_pool
	for raw_symbol: Variant in required.keys():
		var symbol := str(raw_symbol)
		if symbol == "C":
			continue
		var needed := int(required.get(symbol, 0))
		var owned := int(available.get(symbol, 0))
		var missing := maxi(0, needed - owned)
		for pool: Dictionary in flexible_pools:
			if missing <= 0:
				break
			var types: PackedStringArray = pool.get("types", PackedStringArray())
			var pool_remaining := int(pool.get("remaining", 0))
			if symbol not in types or pool_remaining <= 0:
				continue
			var used := mini(missing, pool_remaining)
			missing -= used
			pool["remaining"] = pool_remaining - used
		var any_used := mini(missing, any_pool)
		missing -= any_used
		any_pool -= any_used
		debt += missing
		remaining_energy += maxi(0, owned - needed)
	for pool: Dictionary in flexible_pools:
		remaining_energy += int(pool.get("remaining", 0))
	for raw_symbol: Variant in available.keys():
		if not required.has(raw_symbol):
			remaining_energy += int(available.get(raw_symbol, 0))
	remaining_energy += any_pool
	debt += maxi(0, int(required.get("C", 0)) - remaining_energy)
	return mini(16, debt)


func _read_policy_audit_now() -> Dictionary:
	if _policy == null or not _policy.has_method("audit_snapshot"):
		return {}
	var raw_audit: Variant = _policy.call("audit_snapshot")
	return (raw_audit as Dictionary).duplicate(true) if raw_audit is Dictionary else {}


func _policy_audit_snapshot() -> Dictionary:
	if has_pending_policy_decision():
		return _cached_policy_audit.duplicate(true)
	_cached_policy_audit = _read_policy_audit_now()
	return _cached_policy_audit.duplicate(true)


func audit_snapshot() -> Dictionary:
	var policy_audit: Dictionary = (
		_external_decision_port.audit_snapshot()
		if _external_decision_port != null and _external_decision_port.has_method("audit_snapshot")
		else _policy_audit_snapshot()
	)
	var match_id := _resolved_match_id(policy_audit)
	var authority_audit := (
		{"development_execution_only": true, "device_canary_authority": false}
		if _authority_mode in [
			ExecutionGateScript.DEVELOPMENT_MODE,
			"a3_private_oracle_research",
			PLATFORM_NPC_AUTHORITY_MODE,
		]
		else {
			"development_execution_only": false,
			"device_canary_authority": _authority_mode == ExecutionGateScript.DEVICE_CANARY_MODE,
		}
	)
	return {
		"schema_version": 1,
		"profile_id": str(_pins.get("owner_id", PROFILE_ID)),
		"match_id": match_id,
		"strategy_id": policy_audit.get("strategy_id", STRATEGY_ID),
		"package_id": _pins.get("package_id"),
		"package_version": _pins.get("package_version"),
		"archive_sha256": _pins.get("archive_sha256"),
		"signature_key_id": _pins.get("signature_key_id"),
		"signature_scope": _pins.get("signature_scope"),
		"authority_mode": _authority_mode,
		"card_id_domain": CARD_ID_DOMAIN,
		"seat": player_index,
		"sequence": _sequence,
		"policy_calls": _policy_calls,
		"policy_successes": _policy_successes,
		"decision_elapsed_usec": _decision_elapsed_usec.duplicate(),
		"policy_errors": _policy_errors,
		"invalid_outputs": _invalid_outputs,
		"same_window_fallbacks": _same_window_fallbacks,
		"classic_fallbacks": 0,
		"legacy_deck_strategy_preferences": false,
		"engine_commits": _engine_commits,
		"engine_rejections": _engine_rejections,
		"prompt_counts": _prompt_counts.duplicate(true),
		"last_error_code": _last_error_code,
		"policy_execution_profile": _policy_execution_profile,
		"policy_worker_pending": has_pending_policy_decision(),
		"policy_worker_schedules": _policy_worker_schedules,
		"policy_worker_start_failures": _policy_worker_start_failures,
		"policy_worker_stale_results": _policy_worker_stale_results,
		"external_process_attempts": 0,
		"external_decision_port": _external_decision_port != null,
		"research_private_oracle_only": _authority_mode == "a3_private_oracle_research",
		"platform_npc_public_owner": _authority_mode == PLATFORM_NPC_AUTHORITY_MODE,
		"owner_kind": _pins.get("owner_kind"),
		"owner_id": _pins.get("owner_id"),
		"competition_conflict_group": _pins.get("competition_conflict_group"),
		"release_id": _pins.get("release_id"),
		"policy_package_id": policy_audit.get("policy_package_id"),
		"policy_package_version": policy_audit.get("policy_package_version"),
		"policy_package_manifest_canonical_sha256": policy_audit.get("policy_package_manifest_canonical_sha256"),
		"execution_location": policy_audit.get("execution_location"),
		"learned_model": policy_audit.get("learned_model"),
		"model_backend": policy_audit.get("model_backend"),
		"learned_model_invoked": policy_audit.get("learned_model_invoked", false),
		"model_policy_mode": _pins.get("policy_mode", "rules_only"),
		"model_manifest_sha256": _pins.get("model_manifest_sha256"),
		"model_artifact_sha256": _pins.get("model_artifact_sha256"),
		"model_decision_windows": _model_decision_windows,
		"model_inference_successes": _model_inference_successes,
		"model_fallbacks": _model_fallbacks,
		"model_changed_selections": _model_changed_selections,
		"model_elapsed_usec": _model_elapsed_usec.duplicate(),
		"model_diagnostic_counts": _model_diagnostic_counts.duplicate(true),
		"model_execution_provider": "CPUExecutionProvider" \
			if _pins.get("policy_mode") == "rules_with_model" else "none",
		"remote_inference": false,
		"matched_rule_counts": policy_audit.get("matched_rule_counts", {}).duplicate(true),
		"macro_preferred_selections": policy_audit.get("macro_preferred_selections", 0),
		"development_player_authority": validate_integrity() and _authority_mode == ExecutionGateScript.DEVELOPMENT_MODE,
		"control_distributed_player_authority": validate_integrity() and _authority_mode == ExecutionGateScript.CONTROL_DISTRIBUTED_MODE,
		"device_canary_authority": validate_integrity() and bool(authority_audit["device_canary_authority"]),
		"development_execution_only": bool(authority_audit["development_execution_only"]),
		"production_ready": false,
		"execution_trusted": bool(_pins.get("execution_trusted", false)),
		"cabt_exportable": false,
		"android_ready": false,
		"developer_trace_enabled": _developer_trace_enabled,
		"developer_trace_pending_records": _developer_decision_records.size(),
		"developer_trace_dropped_records": _developer_trace_dropped_records,
	}


func public_replay_identity() -> Dictionary:
	if not validate_integrity():
		return _error("public_replay_owner_not_ready")
	var policy_audit: Dictionary = (
		_external_decision_port.audit_snapshot()
		if _external_decision_port != null and _external_decision_port.has_method("audit_snapshot")
		else _policy_audit_snapshot()
	)
	if _authority_mode == PLATFORM_NPC_AUTHORITY_MODE:
		return {
			"ok": true,
			"error_code": "",
			"match_id": _resolved_match_id(policy_audit),
			"source_authority": PLATFORM_NPC_AUTHORITY_MODE,
			"strategy_participant": {
				"participant_kind": "platform_npc",
				"strategy_id": policy_audit.get("strategy_id"),
				"release_id": _pins.get("release_id"),
				"archive_sha256": _pins.get("archive_sha256"),
				"manifest_canonical_sha256": _pins.get("manifest_canonical_sha256"),
				"competition_conflict_group": _pins.get("competition_conflict_group"),
				"deck_identity": {
					"domain": CARD_ID_DOMAIN,
					"deck_id": _pins.get("owner_id"),
					"deck_sha256": _pins.get("deck_manifest_sha256"),
				},
				"policy_package_sha256": policy_audit.get("manifest_sha256"),
			},
			"card_catalog_sha256": _pins.get("card_catalog_sha256"),
		}
	var participant := {
		"participant_kind": "strategy_release",
		"strategy_id": STRATEGY_ID,
		"release_version": str(_pins.get("package_version", "")),
		"package_id": str(_pins.get("package_id", "")),
		"archive_sha256": _pins.get("archive_sha256"),
		"manifest_canonical_sha256": _pins.get("manifest_canonical_sha256"),
		"deck_identity": {
			"domain": CARD_ID_DOMAIN,
			"deck_id": "%s@%s" % [
				str(_pins.get("package_id", "")),
				str(_pins.get("package_version", "")),
			],
			"deck_sha256": _pins.get("deck_manifest_sha256"),
		},
		"policy_package_sha256": policy_audit.get(
			"policy_package_manifest_canonical_sha256"
		),
	}
	return {
		"ok": true,
		"error_code": "",
		"match_id": _resolved_match_id(policy_audit),
		"source_authority": "ptcgdap_author_public_owner_v1",
		"strategy_participant": participant,
		"card_catalog_sha256": _pins.get("card_catalog_sha256"),
	}


func public_replay_source_snapshot() -> Dictionary:
	if not validate_integrity():
		return _error("public_replay_owner_not_ready")
	var state: GameState = _gsm.game_state
	var public_state := {
		"zone_counts": [],
		"board": [],
		"public_cards": [],
	}
	for seat: int in 2:
		var player: PlayerState = state.players[seat]
		public_state.zone_counts.append({
			"seat": seat,
			"hand_count": player.hand.size(),
			"deck_count": player.deck.size(),
			"prize_count": player.prizes.size(),
		})
		if player.active_pokemon != null and player.active_pokemon.get_top_card() != null:
			var active_entry := _public_replay_board_entry(
				player.active_pokemon, seat, "active", 0
			)
			if active_entry.is_empty():
				return _error("public_replay_identity_unavailable")
			public_state.board.append(active_entry)
		for slot_index: int in player.bench.size():
			var slot: PokemonSlot = player.bench[slot_index]
			if slot == null or slot.get_top_card() == null:
				continue
			var bench_entry := _public_replay_board_entry(slot, seat, "bench", slot_index)
			if bench_entry.is_empty():
				return _error("public_replay_identity_unavailable")
			public_state.board.append(bench_entry)
		for card: CardInstance in player.discard_pile:
			var discard_entry := _public_replay_card_entry(card, seat, "discard")
			if discard_entry.is_empty():
				return _error("public_replay_identity_unavailable")
			public_state.public_cards.append(discard_entry)
		for card: CardInstance in player.lost_zone:
			var lost_entry := _public_replay_card_entry(card, seat, "lost_zone")
			if lost_entry.is_empty():
				return _error("public_replay_identity_unavailable")
			public_state.public_cards.append(lost_entry)
	if state.stadium_card != null:
		var stadium_seat := int(state.stadium_owner_index)
		if stadium_seat not in [0, 1]:
			return _error("public_replay_identity_unavailable")
		var stadium_serial := _serial_for_card(state.stadium_card)
		var stadium_uid: Variant = _uid_for_card(state.stadium_card)
		if stadium_serial <= 0 or stadium_uid == null:
			return _error("public_replay_identity_unavailable")
		public_state.board.append({
			"seat": stadium_seat,
			"zone": "stadium",
			"slot": 0,
			"card_uid": stadium_uid,
			"card_serial": stadium_serial,
			"damage": 0,
			"status": [],
		})
	return {
		"ok": true,
		"error_code": "",
		"source": {
			"source_authority": "ptcgdap_author_public_owner_v1",
			"match_id": _resolved_match_id(),
			"turn_number": maxi(0, int(state.turn_number)),
			"phase": "terminal" if state.is_game_over() else _phase_name(state).to_lower(),
			"acting_seat": int(state.current_player_index) if state.current_player_index in [0, 1] else -1,
			"public_state": public_state,
		},
	}


func _resolved_match_id(policy_audit: Dictionary = {}) -> String:
	if not _match_id.is_empty():
		return _match_id
	var audit := policy_audit
	if audit.is_empty() and _policy != null and _policy.has_method("audit_snapshot"):
		audit = _policy_audit_snapshot()
	return str(audit.get("match_id", ""))


func _public_replay_board_entry(
	slot: PokemonSlot,
	seat: int,
	zone: String,
	slot_index: int
) -> Dictionary:
	var top: CardInstance = slot.get_top_card() if slot != null else null
	var serial := _serial_for_card(top)
	var uid: Variant = _uid_for_card(top)
	if serial <= 0 or uid == null:
		return {}
	var statuses: Array[String] = []
	for key: Variant in slot.status_conditions:
		if typeof(key) == TYPE_STRING and slot.status_conditions.get(key) == true:
			statuses.append(str(key))
	statuses.sort()
	return {
		"seat": seat,
		"zone": zone,
		"slot": slot_index,
		"card_uid": uid,
		"card_serial": serial,
		"damage": maxi(0, int(slot.damage_counters)),
		"status": statuses,
	}


func _public_replay_card_entry(card: CardInstance, seat: int, zone: String) -> Dictionary:
	var serial := _serial_for_card(card)
	var uid: Variant = _uid_for_card(card)
	if serial <= 0 or uid == null:
		return {}
	return {
		"seat": seat,
		"zone": zone,
		"card_uid": uid,
		"card_serial": serial,
	}


func close_match() -> void:
	if _policy_worker != null and _policy_worker.has_method("close"):
		_policy_worker.close()
	_policy_worker = null
	_pending_policy_context.clear()
	if _policy != null and _policy.has_method("close"):
		_policy.close()
	if _serial_registry != null:
		_serial_registry.close_match()
	_closed = true
	_bound = false
	_match_id = ""
	_gsm = null
	_policy = null
	_model_actor = null
	_cached_policy_audit.clear()
	if _external_decision_port != null and _external_decision_port.has_method("close"):
		_external_decision_port.close()
	_external_decision_port = null
	_developer_trace_enabled = false
	_developer_decision_records.clear()
	_confirmed_effect_activation_keys.clear()
	_tracked_public_entity_slots.clear()


func _register_player_inventory(player: PlayerState) -> Dictionary:
	if player == null:
		return _error("missing_player")
	var cards := _collect_player_cards(player)
	if cards.size() != 60:
		return _error("unexpected_card_inventory_count")
	for card: CardInstance in cards:
		var result: Dictionary = _serial_registry.register_card(card, player.player_index)
		if not bool(result.get("ok", false)):
			return _error(str(result.get("code", "serial_registry_error")))
	return {"ok": true, "error_code": ""}


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
	var cards := _collect_player_cards(player)
	if cards.size() != 60:
		return "package_deck_inventory_mismatch"
	var actual := {}
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			return "package_deck_inventory_mismatch"
		var uid := card.card_data.get_uid()
		actual[uid] = int(actual.get(uid, 0)) + 1
	return "" if actual == expected else "package_deck_inventory_mismatch"


static func _collect_player_cards(player: PlayerState) -> Array[CardInstance]:
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
	return cards


func _find_attached_card_owner_slot(card: CardInstance) -> PokemonSlot:
	if card == null or _gsm == null or _gsm.game_state == null:
		return null
	for player: PlayerState in _gsm.game_state.players:
		if player == null:
			continue
		var slots: Array[PokemonSlot] = player.get_all_pokemon()
		for slot: PokemonSlot in slots:
			if slot == null:
				continue
			if card in slot.attached_energy or slot.attached_tool == card:
				return slot
	return null


func _public_cards(cards: Array[CardInstance]) -> Array:
	var rows: Array = []
	for card: CardInstance in cards:
		rows.append({"serial": _serial_for_card(card), "local_card_uid": _uid_for_card(card)})
	return rows


func _public_slots(slots: Array[PokemonSlot]) -> Array:
	var rows: Array = []
	for slot: PokemonSlot in slots:
		if slot != null and slot.get_top_card() != null:
			rows.append(_public_slot(slot))
	return rows


func _public_slot_list(slot: PokemonSlot) -> Array:
	return [] if slot == null or slot.get_top_card() == null else [_public_slot(slot)]


func _public_slot(slot: PokemonSlot) -> Dictionary:
	var row := {
		"serial": _serial_for_card(slot.get_top_card()),
		"local_card_uid": _uid_for_slot(slot),
		"remaining_hp": maxi(0, slot.get_remaining_hp()),
		"attached_energy_count": slot.attached_energy.size(),
	}
	if not _uses_competitive_policy_v2():
		return row
	var attack_profile := _slot_attack_profile(slot, {})
	row["entity_serial"] = _entity_serial_for_slot(slot)
	row["max_hp"] = maxi(0, int(_gsm.effect_processor.get_effective_max_hp(
		slot, _gsm.game_state
	))) if _gsm != null and _gsm.effect_processor != null else maxi(0, slot.get_max_hp())
	row["damage_counters"] = maxi(0, int(slot.damage_counters))
	row["appeared_this_turn"] = (
		int(slot.turn_played) == int(_gsm.game_state.turn_number)
		or int(slot.turn_evolved) == int(_gsm.game_state.turn_number)
	)
	row["attached_tool_uid"] = _uid_for_card(slot.attached_tool) if slot.attached_tool != null else null
	var pokemon_stack_uids: Array = []
	for stack_card: CardInstance in slot.pokemon_stack:
		var stack_uid: Variant = _uid_for_card(stack_card)
		if stack_uid != null:
			pokemon_stack_uids.append(stack_uid)
	row["pokemon_stack_uids"] = pokemon_stack_uids
	row["prize_value"] = clampi(slot.get_prize_count(), 1, 3)
	row["attached_energy_uids"] = attack_profile.get("attached_energy_uids", []).duplicate()
	row["minimum_attack_energy_count"] = attack_profile.get("minimum_attack_energy_count", 0)
	row["attack_ready"] = attack_profile.get("attack_ready", false)
	row["energy_debt"] = attack_profile.get("energy_debt", 0)
	return row


func _entity_serial_for_slot(slot: PokemonSlot) -> Variant:
	if slot == null or slot.get_top_card() == null or _serial_registry == null:
		return null
	var owner := int(slot.get_top_card().owner_index)
	var result: Dictionary = _serial_registry.lookup_pokemon_entity(
		slot, _match_generation, owner
	)
	if not bool(result.get("ok", false)) and result.get("code") == "pokemon_entity_not_registered":
		result = _serial_registry.begin_pokemon_entity(slot, owner)
	elif not bool(result.get("ok", false)) and result.get("code") == "pokemon_entity_root_changed":
		var retired: Dictionary = _serial_registry.retire_pokemon_entity(
			slot, _match_generation, owner
		)
		result = _serial_registry.begin_pokemon_entity(slot, owner) \
			if bool(retired.get("ok", false)) else retired
	return int(result.get("serial")) if bool(result.get("ok", false)) else null


func _sync_public_pokemon_entities() -> String:
	if _serial_registry == null or _gsm == null or _gsm.game_state == null:
		return "pokemon_entity_registry_unavailable"
	var current: Array[Dictionary] = []
	for seat: int in 2:
		var player: PlayerState = _gsm.game_state.players[seat]
		if player.active_pokemon != null and player.active_pokemon.get_top_card() != null:
			current.append({"slot": player.active_pokemon, "seat": seat})
		for slot: PokemonSlot in player.bench:
			if slot != null and slot.get_top_card() != null:
				current.append({"slot": slot, "seat": seat})
	for index: int in range(_tracked_public_entity_slots.size() - 1, -1, -1):
		var tracked: Dictionary = _tracked_public_entity_slots[index]
		var weak: Variant = tracked.get("slot_ref")
		var tracked_slot: Variant = weak.get_ref() if weak is WeakRef else null
		var still_present := false
		for row: Dictionary in current:
			if row.get("slot") == tracked_slot:
				still_present = true
				break
		if still_present:
			continue
		if tracked_slot is PokemonSlot:
			var retired: Dictionary = _serial_registry.retire_pokemon_entity(
				tracked_slot, _match_generation, int(tracked.get("seat", -1))
			)
			if not bool(retired.get("ok", false)) and retired.get("code") != "pokemon_entity_retired":
				return str(retired.get("code", "pokemon_entity_retire_failed"))
		_tracked_public_entity_slots.remove_at(index)
	for row: Dictionary in current:
		var slot: PokemonSlot = row.get("slot") as PokemonSlot
		var found := false
		for tracked: Dictionary in _tracked_public_entity_slots:
			var weak: Variant = tracked.get("slot_ref")
			if weak is WeakRef and weak.get_ref() == slot:
				found = true
				break
		var serial: Variant = _entity_serial_for_slot(slot)
		if serial == null:
			return "pokemon_entity_projection_failed"
		if not found:
			_tracked_public_entity_slots.append({"slot_ref": weakref(slot), "seat": row.get("seat")})
	return ""


func _serial_for_card(card: CardInstance) -> int:
	if card == null or _serial_registry == null:
		return -1
	var result: Dictionary = _serial_registry.lookup_card(card, _match_generation, card.owner_index)
	return int(result.get("serial", -1)) if bool(result.get("ok", false)) else -1


static func _uid_for_card(card: CardInstance) -> Variant:
	return card.card_data.get_uid() if card != null and card.card_data != null else null


static func _uid_for_slot(slot: PokemonSlot) -> Variant:
	return slot.get_card_data().get_uid() if slot != null and slot.get_card_data() != null else null


static func _validated_indexes(raw: Variant, count: int, minimum: int, maximum: int) -> Variant:
	if not raw is Array or raw.size() < minimum or raw.size() > maximum:
		return null
	var result: Array[int] = []
	for value: Variant in raw:
		if typeof(value) != TYPE_INT:
			return null
		var index := int(value)
		if index < 0 or index >= count or index in result:
			return null
		result.append(index)
	return result


static func _model_frontier_from_response(
	response: Dictionary,
	fallback_indexes: Array,
	option_count: int,
) -> Array[int]:
	var decision_audit: Variant = response.get("decision_audit")
	if not decision_audit is Dictionary:
		return _typed_indexes(fallback_indexes)
	var base_result: Variant = decision_audit.get("base_result")
	if not base_result is Dictionary or not base_result.get("node_audit") is Array:
		return _typed_indexes(fallback_indexes)
	var raw_frontier: Variant = null
	for node_value: Variant in base_result.get("node_audit"):
		if node_value is Dictionary and node_value.get("operator") == "base_veto":
			raw_frontier = node_value.get("output_indexes")
	if not raw_frontier is Array or raw_frontier.is_empty():
		return _typed_indexes(fallback_indexes)
	var result: Array[int] = []
	for value: Variant in raw_frontier:
		if typeof(value) != TYPE_INT:
			return _typed_indexes(fallback_indexes)
		var index := int(value)
		if index < 0 or index >= option_count or index in result:
			return _typed_indexes(fallback_indexes)
		result.append(index)
	return result


static func _typed_indexes(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		if typeof(value) == TYPE_INT:
			result.append(int(value))
	return result


static func _same_window_fallback(
	options: Array,
	minimum: int,
	maximum: int,
	prompt_kind: String
) -> Array[int]:
	if prompt_kind == "main":
		for index: int in options.size():
			if str(options[index].get("kind", "")) == "end_turn":
				return [index]
	var result: Array[int] = []
	for index: int in mini(mini(maximum, maxi(0, minimum)), options.size()):
		result.append(index)
	return result


static func _clear_consumed_prompt(battle_scene: Control) -> void:
	battle_scene.set("_pending_choice", "")
	battle_scene.set("_dialog_data", {})


static func _clear_prompt_if_same(battle_scene: Control, kind: String, seat: int) -> void:
	var data: Dictionary = battle_scene.get("_dialog_data")
	if str(battle_scene.get("_pending_choice")) == kind and int(data.get("player", -1)) == seat:
		_clear_consumed_prompt(battle_scene)


static func _restore_prompt_if_unclaimed(battle_scene: Control, kind: String, data: Dictionary) -> void:
	var current_data: Dictionary = battle_scene.get("_dialog_data")
	if str(battle_scene.get("_pending_choice")) == "" and current_data.is_empty():
		battle_scene.set("_pending_choice", kind)
		battle_scene.set("_dialog_data", data.duplicate(true))


static func _select_raw_semantics(prompt_kind: String) -> Dictionary:
	match prompt_kind:
		"main": return {"type": 0, "context": 0}
		"starting_player_choice": return {"type": 9, "context": 41}
		"setup_active": return {"type": 1, "context": 1}
		"setup_bench": return {"type": 1, "context": 2}
		"mulligan_draw_count": return {"type": 8, "context": 38}
		"activate": return {"type": 9, "context": 43}
		"take_prize": return {"type": 1, "context": 7}
		"search": return {"type": 1, "context": 24}
		"discard": return {"type": 1, "context": 8}
		"assignment_source", "assignment_target", "effect_target", "attack_target": return {"type": 1, "context": 25}
		"self_switch", "opponent_switch": return {"type": 1, "context": 3}
		"send_out": return {"type": 1, "context": 4}
		"evolve": return {"type": 7, "context": 37}
		"attach": return {"type": 1, "context": 22}
		_: return {"type": 1, "context": 25}


static func _select_raw_semantics_for_step(
	step: Dictionary,
	prompt_kind: String,
	for_target: bool
) -> Dictionary:
	var metadata := UcisCompilerScript.metadata_for_step(step)
	if not metadata.is_empty():
		var ucis_semantics: Variant = metadata.get("target_semantics") if for_target else metadata
		if ucis_semantics is Dictionary:
			var result := {
				"type": int(ucis_semantics.get("select_type_raw", -1)),
				"context": int(ucis_semantics.get("context_raw", -1)),
			}
			if result.type >= 0 and result.context >= 0:
				if typeof(metadata.get("remain_damage_counter")) == TYPE_INT:
					result["remainDamageCounter"] = int(metadata.remain_damage_counter)
				if typeof(metadata.get("remain_energy_cost")) == TYPE_INT:
					result["remainEnergyCost"] = int(metadata.remain_energy_cost)
				return result
	var prefix := "cabt_target_" if for_target else "cabt_"
	var ucis_type_key := "ucis_target_select_type_raw" if for_target else "ucis_select_type_raw"
	var ucis_context_key := "ucis_target_context_raw" if for_target else "ucis_context_raw"
	var type_value: Variant = step.get(ucis_type_key, step.get(prefix + "select_type_raw"))
	var context_value: Variant = step.get(ucis_context_key, step.get(prefix + "select_context_raw"))
	if (
		typeof(type_value) == TYPE_INT
		and int(type_value) >= 0
		and typeof(context_value) == TYPE_INT
		and int(context_value) >= 0
	):
		var result := {"type": int(type_value), "context": int(context_value)}
		var remain_damage: Variant = step.get("cabt_remain_damage_counter")
		var remain_energy: Variant = step.get("cabt_remain_energy_cost")
		if typeof(remain_damage) == TYPE_INT and int(remain_damage) >= 0:
			result["remainDamageCounter"] = int(remain_damage)
		if typeof(remain_energy) == TYPE_INT and int(remain_energy) >= 0:
			result["remainEnergyCost"] = int(remain_energy)
		return result
	return _select_raw_semantics(prompt_kind)


static func _ucis_option_type_for_step(step: Dictionary, for_target: bool) -> int:
	var metadata := UcisCompilerScript.metadata_for_step(step)
	if not metadata.is_empty():
		var semantics: Variant = metadata.get("target_semantics") if for_target else metadata
		if semantics is Dictionary:
			return int(semantics.get("option_type_raw", -1))
	var key := "cabt_target_option_type_raw" if for_target else "cabt_option_type_raw"
	var ucis_key := "ucis_target_option_type_raw" if for_target else "ucis_option_type_raw"
	var value: Variant = step.get(ucis_key, step.get(key))
	return int(value) if typeof(value) == TYPE_INT else -1


static func _option_type_raw(kind: String) -> int:
	match kind:
		"mulligan_draw_count": return 0
		"yes": return 1
		"no": return 2
		"play_basic_to_bench", "play_trainer", "play_stadium": return 7
		"attach", "attach_energy", "attach_tool": return 8
		"evolve": return 9
		"use_ability", "use_stadium_effect": return 10
		"discard": return 11
		"retreat": return 12
		"attack", "granted_attack": return 13
		"end_turn": return 14
		"skill_order": return 15
		"special_condition": return 16
		_: return 3


static func _resolved_option_type_raw(
	kind: String,
	action: Dictionary,
	card: CardInstance,
	source_slot: PokemonSlot,
	interaction_context: Dictionary
) -> int:
	var explicit: Variant = action.get("cabt_option_type_raw")
	if typeof(explicit) != TYPE_INT:
		explicit = interaction_context.get("cabt_option_type_raw")
	if typeof(explicit) == TYPE_INT and int(explicit) >= 0 and int(explicit) <= 16:
		return int(explicit)
	var select_type := int(interaction_context.get("cabt_select_type_raw", -1))
	var select_context := int(interaction_context.get("cabt_select_context_raw", -1))
	if select_type == 1:
		return 3
	if select_type == 2:
		if select_context == 27:
			return 4
		if select_context in [26, 28]:
			return 5
		return _attached_card_option_type(card)
	if select_type == 3:
		var attached_type := _attached_card_option_type(card)
		return attached_type if attached_type in [4, 5] else 3
	if select_type == 4:
		# ENERGY options refer to an in-play Pokemon plus an energy type/count,
		# not a physical Energy card. Missing source/value fields remain visible
		# as an invalid frame and therefore fail closed in the policy/projector.
		return 6
	if select_type == 5:
		return 15
	if select_type == 6:
		return 13
	if select_type == 7:
		return 9
	if select_type == 8:
		return 0
	if select_type == 9:
		return 2 if kind == "no" else 1
	if select_type == 10:
		return 16
	return _option_type_raw(kind)


static func _attached_card_option_type(card: CardInstance) -> int:
	if card == null or card.card_data == null:
		return 3
	if card.card_data.card_type in ["Pokemon Tool", "Tool"]:
		return 4
	if card.card_data.card_type in ["Basic Energy", "Special Energy", "Energy"]:
		return 5
	return 3


static func _energy_type_raw_from_action(action: Dictionary, source_slot: PokemonSlot) -> Variant:
	var energy_type := str(action.get("energy_type", ""))
	if energy_type.is_empty() and action.get("energy") is CardInstance:
		var energy_card: CardInstance = action.get("energy") as CardInstance
		if energy_card.card_data != null:
			energy_type = energy_card.card_data.energy_provides
	if energy_type.is_empty() and source_slot != null and not source_slot.attached_energy.is_empty():
		var first_energy: CardInstance = source_slot.attached_energy[0]
		if first_energy != null and first_energy.card_data != null:
			energy_type = first_energy.card_data.energy_provides
	match energy_type.to_upper():
		"C", "COLORLESS": return 0
		"G", "GRASS": return 1
		"R", "FIRE": return 2
		"W", "WATER": return 3
		"L", "LIGHTNING": return 4
		"P", "PSYCHIC": return 5
		"F", "FIGHTING": return 6
		"D", "DARKNESS": return 7
		"M", "METAL": return 8
		"N", "DRAGON": return 9
		"ANY", "RAINBOW": return 10
		"TEAM_ROCKET": return 11
		_: return null


static func _prompt_kind_for_step(step: Dictionary) -> String:
	var metadata := UcisCompilerScript.metadata_for_step(step)
	if not metadata.is_empty():
		var primitive := str(metadata.get("primitive", ""))
		var context_raw := int(metadata.get("context_raw", -1))
		match primitive:
			"SearchAndMove": return "search"
			"AssignOrDistribute": return "assignment_source"
			"PayCost": return "discard"
			"ChooseEvolution": return "evolve"
			"ChooseEnergyUnits", "ChooseAttachedCardSet": return "assignment_source"
			"RetreatOrSwitch": return "opponent_switch" if context_raw == 23 else "self_switch"
			"AttackAndTarget": return "attack_target"
			"ResolveKnockout": return "take_prize" if context_raw == 7 else "effect_target"
			_: return "effect_target"
	var signature := (
		str(step.get("id", "")) + " " + str(step.get("type", "")) + " "
		+ str(step.get("ui_mode", "")) + " " + str(step.get("title", ""))
	).to_lower()
	if str(step.get("ui_mode", "")).to_lower() == "card_assignment" \
		or step.has("source_items") or step.has("source_card_indices"):
		return "assignment_source"
	# BaseEffect.build_full_library_search_step deliberately exposes a stable,
	# public structural signature.  Prefer that contract over localized titles
	# or deck-specific step ids so every full-library search reaches the author
	# policy as the same semantic prompt.
	if step.has("visible_scope") and step.has("card_items") and step.has("card_indices"):
		return "search"
	# Attached-card resource windows are source-subset selections.  In
	# particular, attacks such as Bellowing Thunder choose public attached
	# Energy to discard; treating the word "Energy" as an attachment prompt
	# prevents the author policy from expressing the exact legal subset.
	if "discard" in signature and step.has("card_items") and step.has("card_groups"):
		return "assignment_source"
	if "search" in signature or "find" in signature or "deck" in signature:
		return "search"
	if "discard" in signature or "弃" in signature:
		return "discard"
	if "evol" in signature:
		return "evolve"
	if "opponent_switch" in signature or "opponent_bench_target" in signature \
			or "gust_target" in signature:
		return "opponent_switch"
	if "self_switch" in signature or "own_bench_target" in signature \
			or "switch_target" in signature or "pivot_target" in signature:
		return "self_switch"
	if "attach" in signature or "energy" in signature:
		return "attach"
	if "attack" in signature or "damage" in signature or "counter" in signature:
		return "attack_target"
	return "effect_target"


static func _option_kind_for_prompt(prompt_kind: String) -> String:
	match prompt_kind:
		"search": return "search"
		"discard": return "discard"
		"assignment_source": return "assignment_source"
		"evolve": return "evolve"
		"attach": return "attach_energy"
		"self_switch": return "send_out"
		"opponent_switch": return "attack_target"
		"attack_target": return "attack_target"
		_: return "effect_target"


static func _phase_name(state: GameState) -> String:
	match state.phase:
		GameState.GamePhase.SETUP: return "SETUP"
		GameState.GamePhase.MULLIGAN: return "MULLIGAN"
		GameState.GamePhase.SETUP_PLACE: return "SETUP_PLACE"
		GameState.GamePhase.DRAW: return "DRAW"
		GameState.GamePhase.MAIN: return "MAIN"
		GameState.GamePhase.ATTACK: return "ATTACK"
		_: return "UNKNOWN"


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "owner": null}
