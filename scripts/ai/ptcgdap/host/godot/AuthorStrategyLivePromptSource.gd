class_name AuthorStrategyLivePromptSource
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const ProjectorScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
const ShadowPromptScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd")
const SourceDocumentsScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategySourceDocuments.gd")
const CommandScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyLiveCommand.gd")
const GameStateMachineScript = preload("res://scripts/engine/GameStateMachine.gd")
const GameStateScript = preload("res://scripts/data/GameState.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const SerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const MAX_OPTIONS := 32
const MAX_EVENTS := 512
const HASH_PREFIX_HEX := "5054434744415000415554484F525F4C4956455F50524F4D50545F534F555243455F563100"
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _gsm: Variant = null
var _registry: Variant = null
var _source_documents: Variant = null
var _chooser_player_index := -1
var _decision_generation := 0
var _match_generation := 0
var _candidate_refs: Array = []
var _candidate_hand_indexes: Array = []
var _candidate_serials: Array = []
var _public_events: Array = []
var _port_source: Dictionary = {}
var _projector_source: Dictionary = {}
var _projector: Variant = null
var _projector_result: Variant = null
var _projection_snapshot_hash := ""
var _contracts: Variant = null
var _window: Variant = null
var _context: Variant = null
var _host_prompt: Variant = null
var _commands: Array = []
var _private_refs: Array = []
var _callback_binding_hash := ""
var _factory_token: Variant = null


static func create_setup_active(
	gsm: Variant,
	registry: Variant,
	source_documents: Variant,
	chooser_player_index: Variant,
	candidates: Variant,
	decision_generation: Variant,
	public_events: Variant = [],
	include_local_uid_public_context: bool = false
) -> Dictionary:
	if not _exact_script(gsm, GameStateMachineScript) or not _exact_script(registry, SerialRegistryScript):
		return _error("invalid_live_owner")
	if not _exact_script(source_documents, SourceDocumentsScript) or not source_documents.validate_integrity():
		return _error("invalid_live_owner")
	if typeof(chooser_player_index) != TYPE_INT or int(chooser_player_index) not in [0, 1]:
		return _error("invalid_engine_prompt")
	if typeof(decision_generation) != TYPE_INT or int(decision_generation) < 1:
		return _error("invalid_engine_prompt")
	if not candidates is Array or candidates.is_empty() or candidates.size() > MAX_OPTIONS:
		return _error("resource_limit_exceeded" if candidates is Array else "invalid_engine_prompt")
	if not public_events is Array or public_events.size() > MAX_EVENTS:
		return _error("resource_limit_exceeded")
	var state: Variant = gsm.game_state
	if not _exact_script(state, GameStateScript) or state.players.size() != 2:
		return _error("invalid_engine_prompt")
	var chooser := int(chooser_player_index)
	var player: Variant = state.players[chooser]
	if player == null or player.active_pokemon != null:
		return _error("invalid_engine_prompt")
	var current_basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if not _same_object_array(candidates, current_basics):
		return _error("invalid_engine_prompt")
	var hand_indexes := []
	var serials := []
	var port_options := []
	var projector_options := []
	var commands := []
	var private_refs := []
	var generation: int = registry.get_match_generation()
	for candidate: Variant in candidates:
		if not _exact_script(candidate, CardInstanceScript) or candidate.card_data == null or not candidate.card_data.is_basic_pokemon():
			return _error("invalid_engine_prompt")
		var hand_index: int = player.hand.find(candidate)
		var registry_result: Dictionary = registry.lookup_card(candidate, generation, chooser)
		if hand_index < 0 or not bool(registry_result.get("ok", false)):
			return _error("invalid_engine_prompt")
		var command_result: Dictionary = CommandScript.create_setup_active(gsm, registry, chooser, candidate, hand_index)
		if not bool(command_result.get("ok", false)):
			return _error("invalid_engine_prompt")
		hand_indexes.append(hand_index)
		serials.append(int(registry_result.get("serial")))
		port_options.append({"type": 3})
		projector_options.append({"type": 3, "area": 2, "index": hand_index, "playerIndex": chooser})
		commands.append(command_result.get("command"))
		private_refs.append([candidate])
	var select_common := {
		"type": 1, "context": 1, "minCount": 1, "maxCount": 1,
		"remainDamageCounter": 0, "remainEnergyCost": 0,
		"deck": null, "contextCard": null, "effect": null,
	}
	var port_select: Dictionary = select_common.duplicate(true)
	port_select["option"] = port_options
	var projector_select: Dictionary = select_common.duplicate(true)
	projector_select["option"] = projector_options
	var port_source := _decision_source(port_select, candidates.size())
	var projector_source := _decision_source(projector_select, candidates.size())
	var projector: Variant = ProjectorScript.load_default()
	if projector == null or not projector.validate_integrity():
		return _error("projector_rejected")
	var projection: Variant = projector.capture_engine(
		state, registry, projector_source, public_events, source_documents.documents(),
		null, null, chooser
	)
	if projection == null or not projection.accepted:
		return _error("projector_rejected")
	var firewall_result: Variant = projection.firewall_result
	if firewall_result == null or not bool(firewall_result.get("accepted")):
		return _error("projector_rejected")
	var public_observation: Dictionary = projection.observation
	var contracts: Variant = CabtContractSetScript.load_default()
	var built: Variant = CabtSelectionWindowScript.build(
		{
			"public_observation_hash": projection.public_observation_hash,
			"public_hash_authority": "firewall_accepted",
			"chooser_player_index": chooser,
			"select": public_observation.get("select"),
		},
		contracts
	)
	var window: Variant = built.get("window") if built != null else null
	if window == null or built.get("decision_state") == "reject" or not window.validate_integrity():
		return _error("window_rejected")
	var context_result: Variant = StrategicContextScript.build_context(firewall_result, window)
	var context: Variant = context_result.context if context_result != null and context_result.accepted else null
	if context == null or not StrategicContextScript.validate_context(context):
		return _error("window_rejected")
	var callback_hash := _hash({
		"match_generation": generation,
		"decision_generation": int(decision_generation),
		"chooser_player_index": chooser,
		"candidate_hand_indexes": hand_indexes,
		"candidate_serials": serials,
		"window_id": window.window_id,
		"public_observation_hash": window.public_observation_hash,
	})
	if callback_hash.is_empty():
		return _error("invalid_engine_prompt")
	var tiers := []
	for index: int in range(window.option_count):
		tiers.append({"index": index, "tier": [0]})
	var local_context: Variant = null
	if include_local_uid_public_context:
		var context_public: Dictionary = StrategicContextScript.context_public_dict(context)
		var local_options: Array = []
		for index: int in range(candidates.size()):
			var option_uid := _local_card_uid(candidates[index])
			if option_uid.is_empty():
				return _error("invalid_engine_prompt")
			local_options.append({"index": index, "local_card_uid": option_uid})
		var local_hand: Array = []
		for card: CardInstance in player.hand:
			var lookup: Dictionary = registry.lookup_card(card, generation, chooser)
			var hand_uid := _local_card_uid(card)
			if not bool(lookup.get("ok", false)) or hand_uid.is_empty():
				return _error("invalid_engine_prompt")
			local_hand.append({"serial": int(lookup.get("serial")), "local_card_uid": hand_uid})
		local_context = {
			"schema_version": 1,
			"card_id_domain": "godot_local_card_uid_v1",
			"source": {
				"context_hash": context_public.get("context_hash"),
				"window_id": context_public.get("source", {}).get("window_id"),
			},
			"options": local_options,
			"acting_hand": local_hand,
			"acting_active": [],
		}
	var prompt_result: Dictionary = ShadowPromptScript.create(
		context, window, "w1.setup_active.%d" % int(decision_generation),
		int(decision_generation), [], [], tiers, [], local_context
	)
	if not bool(prompt_result.get("ok", false)):
		return _error("host_rejected")
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd")
	var owner: Variant = script.new(_FACTORY_TOKEN)
	owner._gsm = gsm
	owner._registry = registry
	owner._source_documents = source_documents
	owner._chooser_player_index = chooser
	owner._decision_generation = int(decision_generation)
	owner._match_generation = generation
	owner._candidate_refs = candidates.duplicate()
	owner._candidate_hand_indexes = hand_indexes.duplicate()
	owner._candidate_serials = serials.duplicate()
	owner._public_events = public_events.duplicate(true)
	owner._port_source = port_source
	owner._projector_source = projector_source
	owner._projector = projector
	owner._projector_result = projection
	owner._projection_snapshot_hash = _hash(projection.get("_snapshot"))
	owner._contracts = contracts
	owner._window = window
	owner._context = context
	owner._host_prompt = prompt_result.get("prompt")
	owner._commands = commands
	owner._private_refs = private_refs
	owner._callback_binding_hash = callback_hash
	if not owner.validate_integrity():
		return _error("invalid_engine_prompt")
	return {"ok": true, "error_code": "", "source": owner}


func _init(token: Variant = null) -> void:
	if token == _FACTORY_TOKEN:
		_factory_token = token


func validate_integrity() -> bool:
	if _factory_token != _FACTORY_TOKEN or not validate_current():
		return false
	if (
		_projector == null or not _exact_script(_projector, ProjectorScript)
		or _projector.contract_hash != ProjectorScript.EXPECTED_BUNDLE_HASH
		or _projector_result == null or not bool(_projector_result.get("accepted"))
		or _projection_snapshot_hash.is_empty()
		or _hash(_projector_result.get("_snapshot")) != _projection_snapshot_hash
	):
		return false
	if _window == null or not _window.validate_integrity() or not StrategicContextScript.validate_context(_context):
		return false
	if _context.get("_window_binding") != _window or _host_prompt == null or not _host_prompt.validate_integrity():
		return false
	if _commands.size() != _candidate_refs.size() or _private_refs.size() != _candidate_refs.size():
		return false
	for index: int in range(_commands.size()):
		if not _exact_script(_commands[index], CommandScript) or not _commands[index].validate_current():
			return false
		if not _private_refs[index] is Array or _private_refs[index].size() != 1 or _private_refs[index][0] != _candidate_refs[index]:
			return false
	return not _callback_binding_hash.is_empty()


func revalidate_public_window() -> bool:
	if not validate_integrity() or not _projector_result.validate_integrity(_projector):
		return false
	return (
		_projector_result.public_observation_hash == _window.public_observation_hash
		and _projector_result.observation.get("select") == _window.select_payload
	)


func validate_current() -> bool:
	if not _exact_script(_gsm, GameStateMachineScript) or not _exact_script(_registry, SerialRegistryScript):
		return false
	if not _exact_script(_source_documents, SourceDocumentsScript) or not _source_documents.validate_integrity():
		return false
	if not _registry.is_open() or _registry.get_match_generation() != _match_generation:
		return false
	var state: Variant = _gsm.game_state
	if not _exact_script(state, GameStateScript) or state.players.size() != 2:
		return false
	if state.phase not in [GameState.GamePhase.SETUP, GameState.GamePhase.SETUP_PLACE]:
		return false
	var player: Variant = state.players[_chooser_player_index]
	if player == null or player.active_pokemon != null:
		return false
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if not _same_object_array(_candidate_refs, basics):
		return false
	for index: int in range(_candidate_refs.size()):
		if player.hand.find(_candidate_refs[index]) != _candidate_hand_indexes[index]:
			return false
		var lookup: Dictionary = _registry.lookup_card(_candidate_refs[index], _match_generation, _chooser_player_index)
		if not bool(lookup.get("ok", false)) or int(lookup.get("serial", 0)) != _candidate_serials[index]:
			return false
	return true


func port_source() -> Dictionary:
	return _port_source.duplicate(true) if validate_integrity() else {}


func window_owner() -> Variant:
	return _window if validate_integrity() else null


func host_prompt_owner() -> Variant:
	return _host_prompt if validate_integrity() else null


func private_commands() -> Array:
	return _commands.duplicate() if validate_integrity() else []


func private_object_refs() -> Array:
	return _private_refs.duplicate(true) if validate_integrity() else []


func callback_binding_hash() -> String:
	return _callback_binding_hash if validate_integrity() else ""


func decision_generation() -> int:
	return _decision_generation


func match_generation() -> int:
	return _match_generation


func chooser_player_index() -> int:
	return _chooser_player_index


func source_documents_owner() -> Variant:
	return _source_documents if _factory_token == _FACTORY_TOKEN else null


func projector_owner() -> Variant:
	return _projector if _factory_token == _FACTORY_TOKEN else null


func game_state_machine_owner() -> Variant:
	return _gsm if _factory_token == _FACTORY_TOKEN else null


func registry_owner() -> Variant:
	return _registry if _factory_token == _FACTORY_TOKEN else null


func public_events() -> Array:
	return _public_events.duplicate(true) if _factory_token == _FACTORY_TOKEN else []


func setup_bench_reobserve_sources() -> Dictionary:
	if _factory_token != _FACTORY_TOKEN or not _exact_script(_gsm, GameStateMachineScript):
		return {}
	var state: Variant = _gsm.game_state
	if not _exact_script(state, GameStateScript) or state.players.size() != 2:
		return {}
	var player: Variant = state.players[_chooser_player_index]
	if player == null or player.active_pokemon == null:
		return {}
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.size() > MAX_OPTIONS:
		return {}
	var port_options := []
	var projector_options := []
	for candidate: CardInstance in basics:
		var hand_index: int = player.hand.find(candidate)
		if hand_index < 0:
			return {}
		port_options.append({"type": 3})
		projector_options.append({
			"type": 3, "area": 2, "index": hand_index,
			"playerIndex": _chooser_player_index,
		})
	var select_common := {
		"type": 1, "context": 2, "minCount": 0, "maxCount": basics.size(),
		"remainDamageCounter": 0, "remainEnergyCost": 0,
		"deck": null, "contextCard": null, "effect": null,
	}
	var port_select: Dictionary = select_common.duplicate(true)
	port_select["option"] = port_options
	var projector_select: Dictionary = select_common.duplicate(true)
	projector_select["option"] = projector_options
	return {
		"port_source": _decision_source(port_select, basics.size()),
		"projector_source": _decision_source(projector_select, basics.size()),
	}


static func null_decision_source(turn_action_count: int) -> Dictionary:
	return {
		"select": null, "deck_cards": null, "context_card": null,
		"effect_card": null, "option_card_refs": [],
		"turn_action_count": maxi(0, turn_action_count),
	}


static func _decision_source(select_value: Dictionary, option_count: int) -> Dictionary:
	var refs := []
	refs.resize(option_count)
	refs.fill(null)
	return {
		"select": select_value, "deck_cards": null, "context_card": null,
		"effect_card": null, "option_card_refs": refs, "turn_action_count": 0,
	}


static func _same_object_array(left: Variant, right: Variant) -> bool:
	if not left is Array or not right is Array or left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


static func _local_card_uid(card: Variant) -> String:
	if not _exact_script(card, CardInstanceScript) or card.card_data == null:
		return ""
	return "%s_%s" % [str(card.card_data.set_code), str(card.card_data.card_index)]


static func _hash(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_hex_bytes(HASH_PREFIX_HEX))
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _hex_bytes(value: String) -> PackedByteArray:
	var result := PackedByteArray()
	for index: int in range(0, value.length(), 2):
		result.append(str("0x" + value.substr(index, 2)).hex_to_int())
	return result


static func _exact_script(value: Variant, expected: GDScript) -> bool:
	return value != null and typeof(value) == TYPE_OBJECT and value.get_script() == expected


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "source": null}
