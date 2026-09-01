class_name GodotObservationProjector
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const SerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const GameStateScript = preload("res://scripts/data/GameState.gd")
const PlayerStateScript = preload("res://scripts/data/PlayerState.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const CardDataScript = preload("res://scripts/data/CardData.gd")
const PokemonSlotScript = preload("res://scripts/data/PokemonSlot.gd")

const EXPECTED_BUNDLE_HASH := "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
const EXPECTED_CATALOG_HASH := "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
const EXPECTED_FIREWALL_HASH := "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
const EXPECTED_CURSOR_HASH := "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
const EXPECTED_P1_HASH := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const EXPECTED_SOURCE_LOCK_HASH := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_BUNDLE_ID := "ptcgdap-godot-observation-projector-p2-wp5-v1"
const PROFILE_ID := "godot_observation_projector_v1"
const VECTOR_ID := "ptcgdap-godot-observation-projector-conformance-v1"
const BUNDLE_PATH := "res://contracts/ptcgdap/godot_observation_projector_bundle.json"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_ARTIFACTS := {
	"godot_observation_projector_schema_v1": ["res://contracts/ptcgdap/godot_observation_projector.schema.json", "6045AF6A55B10FF43A917D5ED85DB98204CFDFE78AAEABCD6B20051CEAF011DF"],
	"godot_observation_projector_profile_v1": ["res://contracts/ptcgdap/godot_observation_projector_profile.json", "175C4422EDB2DB5ECCF3BF04AC16AC8B9BF74F80E8B4C3F75E634C6772A4BFD1"],
	"godot_observation_projector_conformance_v1": ["res://contracts/ptcgdap/godot_observation_projector_conformance_vectors.json", "D3724188C8ED7569749E8733AF8666107922E83C632ABD0D7D14F977EBF3AF73"],
}
const OPTION_SHAPES := {
	0: ["type", "number"], 1: ["type"], 2: ["type"],
	3: ["type", "area", "index", "playerIndex"],
	4: ["type", "area", "index", "playerIndex", "toolIndex"],
	5: ["type", "area", "index", "playerIndex", "energyIndex"],
	6: ["type", "area", "index", "playerIndex", "energyIndex", "count"],
	7: ["type", "index"],
	8: ["type", "area", "index", "inPlayArea", "inPlayIndex"],
	9: ["type", "area", "index", "inPlayArea", "inPlayIndex"],
	10: ["type", "area", "index"], 11: ["type", "area", "index"],
	12: ["type"], 13: ["type", "attackId"], 14: ["type"],
	15: ["type", "cardId", "serial"], 16: ["type", "specialConditionType"],
}
const ERROR_CODES := {
	"projector_contract_error": true, "invalid_input": true, "invalid_player_index": true,
	"invalid_state": true, "invalid_decision": true, "invalid_select": true,
	"invalid_card_identity": true, "card_catalog_unmapped": true, "card_serial_unbound": true,
	"invalid_attack_identity": true, "hidden_information_requested": true,
	"invalid_public_event": true, "stale_match_generation": true, "limit_exceeded": true,
	"firewall_rejected": true, "engine_capture_unavailable": true, "result_integrity_invalid": true,
}
const MAPPED_CARD_IDS := {7:true,104:true,112:true,646:true,647:true,648:true,1080:true,1097:true,1259:true}
const ATTACK_OWNER_CARD_IDS := {131:104,141:112,934:646,935:646,936:647,937:648}
const ENGINE_SUPPORTED_OPTION_TYPES := {
	0:true,1:true,2:true,3:true,4:true,5:true,6:true,7:true,8:true,
	9:true,10:true,11:true,12:true,13:true,14:true,15:true,16:true,
}
const ENERGY_TYPE_BY_CODE := {"C":0,"G":1,"R":2,"W":3,"L":4,"P":5,"F":6,"D":7,"M":8,"N":9}

var _ok := false
var _error_code := "projector_contract_error"
var _profile := {}
var _artifact_hashes := {}
var _catalog: Variant = null
var _firewall: Variant = null
var _contract_set: Variant = null
var _seal := ""
var _load_stage := "not_started"
var _capture_stage := "not_started"
var _engine_bindings: Array[WeakRef] = []

var ok: bool:
	get: return _ok
var error_code: String:
	get: return _error_code
var contract_hash: String:
	get: return EXPECTED_BUNDLE_HASH if validate_integrity() else ""


class ProjectorResult extends RefCounted:
	var _owner: Variant = null
	var _bound_input: Variant = null
	var _accepted := false
	var _error_code := "invalid_input"
	var _observation: Variant = null
	var _public_observation_hash: Variant = null
	var _audit: Variant = null
	var _firewall_result: Variant = null
	var _snapshot := {}

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var observation: Variant:
		get: return _copy(_observation)
	var public_observation_hash: Variant:
		get: return _public_observation_hash
	var firewall_result: Variant:
		get: return _firewall_result if validate_integrity(_owner) else null

	func initialize(owner: Variant, bound_input: Variant, evaluation: Dictionary) -> ProjectorResult:
		_owner = owner
		_bound_input = _copy(bound_input)
		_accepted = bool(evaluation.get("accepted", false))
		_error_code = str(evaluation.get("error_code", "invalid_input"))
		_observation = _copy(evaluation.get("observation"))
		_public_observation_hash = evaluation.get("public_observation_hash")
		_audit = _copy(evaluation.get("audit"))
		_firewall_result = evaluation.get("firewall_result")
		_snapshot = _serialize_unchecked()
		return self

	func _serialize_unchecked() -> Dictionary:
		return {
			"schema_version": 1,
			"profile_id": PROFILE_ID,
			"projector_bundle_hash": EXPECTED_BUNDLE_HASH,
			"accepted": _accepted,
			"error_code": _error_code,
			"observation": _copy(_observation),
			"public_observation_hash": _public_observation_hash,
			"audit": _copy(_audit),
		}

	func validate_integrity(current_owner: Variant) -> bool:
		if current_owner == null or current_owner != _owner or not current_owner.validate_integrity():
			return false
		if _snapshot != _serialize_unchecked():
			return false
		var replay: Dictionary = current_owner._evaluate_bound(_bound_input)
		replay.erase("firewall_result")
		return replay == {
			"accepted": _accepted, "error_code": _error_code,
			"observation": _copy(_observation),
			"public_observation_hash": _public_observation_hash,
			"audit": _copy(_audit),
		}

	func to_public_dict() -> Dictionary:
		return _snapshot.duplicate(true) if validate_integrity(_owner) else {}

	func to_conformance_summary() -> Dictionary:
		if not validate_integrity(_owner):
			return {}
		if not _accepted:
			return {"accepted":false,"error_code":_error_code,"public_observation_hash":null,"select_type":null,"select_context":null,"option_count":0,"log_count":0,"acting_hand_visible":false,"opponent_hand_hidden":false}
		var select_value: Variant = _observation.get("select")
		var current: Dictionary = _observation.get("current")
		var acting: int = int(current.get("yourIndex"))
		return {
			"accepted":true,"error_code":"","public_observation_hash":_public_observation_hash,
			"select_type":null if select_value == null else select_value.get("type"),
			"select_context":null if select_value == null else select_value.get("context"),
			"option_count":0 if select_value == null else (select_value.get("option", []) as Array).size(),
			"log_count":(_observation.get("logs", []) as Array).size(),
			"acting_hand_visible":current.get("players", [])[acting].get("hand") != null,
			"opponent_hand_hidden":current.get("players", [])[1 - acting].get("hand") == null,
		}

	static func _copy(value: Variant) -> Variant:
		if value is Dictionary or value is Array:
			return value.duplicate(true)
		return value


class EngineCaptureBinding extends RefCounted:
	var game_state: Variant = null
	var serial_registry: Variant = null
	var decision_source: Variant = null
	var public_events: Variant = null
	var source_documents: Variant = null
	var step: Variant = null
	var remaining_overage_time: Variant = null
	var chooser_player_index: Variant = null

	func initialize(
		state_value: Variant,
		registry_value: Variant,
		decision_value: Variant,
		events_value: Variant,
		documents_value: Variant,
		step_value: Variant,
		remaining_value: Variant,
		chooser_value: Variant
	) -> Variant:
		game_state = state_value
		serial_registry = registry_value
		decision_source = ProjectorResult._copy(decision_value)
		public_events = ProjectorResult._copy(events_value)
		source_documents = ProjectorResult._copy(documents_value)
		step = step_value
		remaining_overage_time = remaining_value
		chooser_player_index = chooser_value
		return self


static func load_default() -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
	var value: RefCounted = script.new()
	value._load()
	return value


func _load() -> void:
	_load_stage = "bundle_read"
	var bundle_result := _read_contract(BUNDLE_PATH)
	if not bool(bundle_result.get("ok", false)) or _canonical_hash(bundle_result.get("value")) != EXPECTED_BUNDLE_HASH:
		return
	var bundle: Dictionary = bundle_result.get("value")
	_load_stage = "bundle_header"
	if not _valid_bundle_header(bundle):
		return
	var entries: Variant = bundle.get("artifacts")
	if not entries is Array or (entries as Array).size() != EXPECTED_ARTIFACTS.size():
		return
	var seen := {}
	var documents := {}
	for entry_value: Variant in entries:
		_load_stage = "artifact_entry"
		if not entry_value is Dictionary:
			return
		var entry: Dictionary = entry_value
		if entry.keys().size() != 3:
			return
		var artifact_id: Variant = entry.get("id")
		if typeof(artifact_id) != TYPE_STRING or seen.has(artifact_id) or not EXPECTED_ARTIFACTS.has(artifact_id):
			return
		var expected: Array = EXPECTED_ARTIFACTS[artifact_id]
		if entry.get("path") != str(expected[0]).trim_prefix("res://") or entry.get("canonical_sha256") != expected[1]:
			return
		var document_result := _read_contract(expected[0])
		_load_stage = "artifact_hash:%s" % artifact_id
		if not bool(document_result.get("ok", false)) or _canonical_hash(document_result.get("value")) != expected[1]:
			return
		seen[artifact_id] = true
		documents[artifact_id] = (document_result.get("value") as Dictionary).duplicate(true)
		_artifact_hashes[artifact_id] = expected[1]
	if seen.size() != EXPECTED_ARTIFACTS.size():
		return
	_profile = documents.get("godot_observation_projector_profile_v1", {})
	_load_stage = "profile"
	if not _profile is Dictionary or not _profile_errors_exact():
		return
	_catalog = CatalogScript.load_default()
	_firewall = FirewallScript.load_default()
	_contract_set = CabtContractSetScript.load_default()
	_load_stage = "parents"
	if _catalog == null or not _catalog.ok or _firewall == null or not _firewall.ok or _contract_set == null or not _contract_set.ok:
		return
	if not _verify_catalog_projection_surface():
		return
	_seal = EXPECTED_BUNDLE_HASH
	_ok = true
	_error_code = ""
	_load_stage = "loaded"


func validate_integrity() -> bool:
	if not _ok or _seal != EXPECTED_BUNDLE_HASH or _canonical_hash(_profile) != EXPECTED_ARTIFACTS["godot_observation_projector_profile_v1"][1]:
		return false
	if _catalog == null or not _catalog.validate_integrity() or _catalog.catalog_hash() != EXPECTED_CATALOG_HASH:
		return false
	if _firewall == null or not _firewall.validate_integrity() or _firewall.contract_hash != EXPECTED_FIREWALL_HASH:
		return false
	return _contract_set != null and _contract_set.validate_integrity()


func project_conformance_case(vectors: Variant, case_value: Variant) -> ProjectorResult:
	var materialized: Variant = _materialize_case(vectors, case_value)
	return ProjectorResult.new().initialize(self, materialized, _evaluate(materialized))


func project_conformance_fixture(fixture: Variant) -> ProjectorResult:
	var bound: Variant = fixture.duplicate(true) if fixture is Dictionary else fixture
	return ProjectorResult.new().initialize(self, bound, _evaluate_bound(bound))


func capture_engine(
	game_state: Variant,
	serial_registry: Variant,
	decision_source: Variant,
	public_events: Variant,
	source_documents: Variant,
	step: Variant = null,
	remaining_overage_time: Variant = null,
	chooser_player_index: Variant = null
) -> ProjectorResult:
	var binding: Variant = EngineCaptureBinding.new().initialize(
		game_state,
		serial_registry,
		decision_source,
		public_events,
		source_documents,
		step,
		remaining_overage_time,
		chooser_player_index
	)
	_engine_bindings.append(weakref(binding))
	return ProjectorResult.new().initialize(self, binding, _evaluate_bound(binding))


func accept_projector_result(result: Variant) -> bool:
	return result is ProjectorResult and result.validate_integrity(self)


static func source_document_key(set_code: Variant, card_index: Variant) -> String:
	if typeof(set_code) != TYPE_STRING or str(set_code).is_empty() or str(set_code).contains("/"):
		return ""
	if typeof(card_index) != TYPE_STRING or str(card_index).is_empty() or str(card_index).contains("/"):
		return ""
	return "%s/%s" % [set_code, card_index]


func _evaluate_bound(bound: Variant) -> Dictionary:
	if bound is EngineCaptureBinding:
		if not _owns_engine_binding(bound):
			return _rejected("result_integrity_invalid")
		return _evaluate_engine(bound)
	return _evaluate(ProjectorResult._copy(bound))


func _owns_engine_binding(binding: Variant) -> bool:
	for reference: WeakRef in _engine_bindings:
		if reference.get_ref() == binding:
			return true
	return false


func _evaluate_engine(binding: EngineCaptureBinding) -> Dictionary:
	if not validate_integrity():
		return _rejected("projector_contract_error")
	var captured := _capture_engine_fixture(binding)
	if not bool(captured.get("ok", false)):
		return _rejected(str(captured.get("error_code", "engine_capture_unavailable")))
	var fixture: Dictionary = captured.get("value")
	var validation := _validate_fixture(fixture)
	if not bool(validation.get("ok", false)):
		return _rejected(str(validation.get("error_code", "invalid_input")))
	var raw: Dictionary = validation.get("raw")
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, _contract_set)
	var firewall_result: Variant = _firewall.project(parsed)
	if firewall_result == null or not firewall_result.accepted:
		return _rejected("firewall_rejected")
	return {
		"accepted": true,
		"error_code": "",
		"observation": firewall_result.public_observation,
		"public_observation_hash": firewall_result.public_observation_hash,
		"audit": {
			"authority": "engine_attested_shadow",
			"source_classes": ["engine_public_state", "engine_public_decision", "match_serial_registry", "strict_catalog", "public_event_ledger"],
			"projector_bundle_hash": EXPECTED_BUNDLE_HASH,
			"identity_checks": int(captured.get("identity_checks", 0)) + int(validation.get("identity_checks", 0)),
			"hidden_fields_emitted": 0,
		},
		"firewall_result": firewall_result,
	}


func _capture_engine_fixture(binding: EngineCaptureBinding) -> Dictionary:
	_capture_stage = "binding"
	if not _has_exact_script(binding.game_state, GameStateScript):
		return _failure("engine_capture_unavailable")
	if not _has_exact_script(binding.serial_registry, SerialRegistryScript):
		return _failure("engine_capture_unavailable")
	if not binding.decision_source is Dictionary:
		return _failure("invalid_decision")
	if not binding.public_events is Array:
		return _failure("invalid_public_event")
	if not binding.source_documents is Dictionary:
		return _failure("invalid_card_identity")
	if not binding.serial_registry.is_open():
		return _failure("stale_match_generation")
	var chooser: Variant = binding.chooser_player_index
	if chooser == null:
		chooser = binding.game_state.current_player_index
	if typeof(chooser) != TYPE_INT or int(chooser) not in [0, 1]:
		return _failure("invalid_player_index")
	var generation: Variant = binding.serial_registry.get_match_generation()
	if not _is_positive(generation):
		return _failure("stale_match_generation")
	var context := {"source_cache": {}, "attack_cache": {}}
	_capture_stage = "current"
	var current_result := _capture_engine_current(
		binding.game_state,
		binding.serial_registry,
		int(generation),
		binding.source_documents,
		binding.decision_source,
		context,
		int(chooser)
	)
	if not bool(current_result.get("ok", false)):
		return current_result
	var current: Dictionary = current_result.get("value")
	_capture_stage = "decision"
	var select_result := _capture_engine_decision(
		binding.game_state,
		binding.serial_registry,
		int(generation),
		binding.source_documents,
		binding.decision_source,
		context,
		int(chooser)
	)
	if not bool(select_result.get("ok", false)):
		return select_result
	if binding.public_events.size() > 512:
		return _failure("limit_exceeded")
	var events := []
	_capture_stage = "events"
	var checks := int(current_result.get("identity_checks", 0)) + int(select_result.get("identity_checks", 0))
	for event_value: Variant in binding.public_events:
		var event_result := _capture_engine_event(
			event_value,
			binding.game_state,
			binding.serial_registry,
			int(generation),
			binding.source_documents,
			context
		)
		if not bool(event_result.get("ok", false)):
			return event_result
		events.append(event_result.get("value"))
		checks += int(event_result.get("identity_checks", 0))
	var fixture := {
		"current_source": current,
		"select_source": select_result.get("value"),
		"public_events": events,
	}
	if binding.step != null:
		if not _is_nonnegative(binding.step):
			return _failure("invalid_input")
		fixture["step"] = binding.step
	if binding.remaining_overage_time != null:
		if not _is_nonnegative(binding.remaining_overage_time):
			return _failure("invalid_input")
		fixture["remainingOverageTime"] = binding.remaining_overage_time
	return {"ok": true, "error_code": "", "value": fixture, "identity_checks": checks}


func _capture_engine_current(
	state_value: Variant,
	registry: Variant,
	generation: int,
	source_documents: Dictionary,
	decision_source: Dictionary,
	context: Dictionary,
	chooser_player_index: int
) -> Dictionary:
	var state: GameState = state_value as GameState
	if state.players.size() != 2:
		return _failure("invalid_state")
	if typeof(state.current_player_index) != TYPE_INT or state.current_player_index not in [0, 1]:
		return _failure("invalid_player_index")
	if typeof(state.first_player_index) != TYPE_INT or state.first_player_index not in [0, 1]:
		return _failure("invalid_state")
	if not _is_nonnegative(state.turn_number) or typeof(state.winner_index) != TYPE_INT or state.winner_index not in [-1, 0, 1]:
		return _failure("invalid_state")
	if not _exact_dictionary_keys(decision_source, ["select", "deck_cards", "context_card", "effect_card", "option_card_refs", "turn_action_count"]):
		return _failure("invalid_decision")
	if not _is_nonnegative(decision_source.get("turn_action_count")):
		return _failure("invalid_decision")
	var players := []
	var checks := 0
	for owner: int in range(2):
		var player_result := _capture_engine_player(
			state.players[owner], owner, chooser_player_index,
			state.turn_number, registry, generation, source_documents, context
		)
		if not bool(player_result.get("ok", false)):
			return player_result
		players.append(player_result.get("value"))
		checks += int(player_result.get("identity_checks", 0))
	var stadium: Variant = null
	if state.stadium_card != null:
		if typeof(state.stadium_owner_index) != TYPE_INT or state.stadium_owner_index not in [0, 1]:
			return _failure("invalid_state")
		var stadium_result := _capture_engine_card(
			state.stadium_card, state.stadium_owner_index, false,
			registry, generation, source_documents, context
		)
		if not bool(stadium_result.get("ok", false)):
			return stadium_result
		stadium = stadium_result.get("value")
		checks += 1
	return {
		"ok": true,
		"error_code": "",
		"value": {
			"turn": state.turn_number,
			"turn_action_count": decision_source.get("turn_action_count"),
			"acting_player_index": chooser_player_index,
			"first_player_index": state.first_player_index,
			"supporter_played": state.supporter_used_this_turn,
			"stadium_played": state.stadium_played_this_turn,
			"energy_attached": state.energy_attached_this_turn,
			"retreated": state.retreat_used_this_turn,
			"result": state.winner_index,
			"stadium": stadium,
			"players": players,
		},
		"identity_checks": checks,
	}


func _capture_engine_player(
	player_value: Variant,
	owner: int,
	acting: int,
	turn_number: int,
	registry: Variant,
	generation: int,
	source_documents: Dictionary,
	context: Dictionary
) -> Dictionary:
	if not _has_exact_script(player_value, PlayerStateScript):
		return _failure("invalid_state")
	var player: PlayerState = player_value as PlayerState
	if player.player_index != owner:
		return _failure("invalid_player_index")
	var active := []
	var bench := []
	var discard := []
	var visible_hand: Variant = [] if owner == acting else null
	var checks := 0
	if player.active_pokemon != null:
		var active_result := _capture_engine_pokemon(
			player.active_pokemon, owner, turn_number,
			registry, generation, source_documents, context
		)
		if not bool(active_result.get("ok", false)):
			return active_result
		active.append(active_result.get("value"))
		checks += int(active_result.get("identity_checks", 0))
	for slot_value: Variant in player.bench:
		var bench_result := _capture_engine_pokemon(
			slot_value, owner, turn_number,
			registry, generation, source_documents, context
		)
		if not bool(bench_result.get("ok", false)):
			return bench_result
		bench.append(bench_result.get("value"))
		checks += int(bench_result.get("identity_checks", 0))
	for card_value: Variant in player.discard_pile:
		var discard_result := _capture_engine_card(
			card_value, owner, false, registry, generation, source_documents, context
		)
		if not bool(discard_result.get("ok", false)):
			return discard_result
		discard.append(discard_result.get("value"))
		checks += 1
	if owner == acting:
		for card_value: Variant in player.hand:
			var hand_result := _capture_engine_card(
				card_value, owner, false, registry, generation, source_documents, context
			)
			if not bool(hand_result.get("ok", false)):
				return hand_result
			visible_hand.append(hand_result.get("value"))
			checks += 1
	return {
		"ok": true,
		"error_code": "",
		"value": {
			"active": active,
			"bench": bench,
			"bench_max": 5,
			"deck_count": player.deck.size(),
			"discard": discard,
			"hand": visible_hand,
			"hand_count": player.hand.size(),
			"prize_count": player.prizes.size(),
			"public_prizes": {},
		},
		"identity_checks": checks,
	}


func _capture_engine_pokemon(
	slot_value: Variant,
	owner: int,
	turn_number: int,
	registry: Variant,
	generation: int,
	source_documents: Dictionary,
	context: Dictionary
) -> Dictionary:
	if not _has_exact_script(slot_value, PokemonSlotScript):
		return _failure("invalid_state")
	var slot: PokemonSlot = slot_value as PokemonSlot
	var entity_result: Dictionary = registry.lookup_pokemon_entity(slot, generation, owner)
	if not bool(entity_result.get("ok", false)):
		return _failure(_registry_error(str(entity_result.get("code", "")), false))
	if slot.pokemon_stack.is_empty() or slot.pokemon_stack.size() > 3:
		return _failure("invalid_state")
	var stack := []
	var energies := []
	var checks := 1
	for card_value: Variant in slot.pokemon_stack:
		var card_result := _capture_engine_card(
			card_value, owner, false, registry, generation, source_documents, context
		)
		if not bool(card_result.get("ok", false)):
			return card_result
		stack.append(card_result.get("value"))
		checks += 1
	for card_value: Variant in slot.attached_energy:
		var energy_result := _capture_engine_card(
			card_value, -1, true, registry, generation, source_documents, context
		)
		if not bool(energy_result.get("ok", false)):
			return energy_result
		energies.append(energy_result.get("value"))
		checks += 1
	var tool: Variant = null
	if slot.attached_tool != null:
		var tool_result := _capture_engine_card(
			slot.attached_tool, -1, false, registry, generation, source_documents, context
		)
		if not bool(tool_result.get("ok", false)):
			return tool_result
		tool = tool_result.get("value")
		checks += 1
	var status_keys := ["poisoned", "burned", "asleep", "paralyzed", "confused"]
	if not _exact_dictionary_keys(slot.status_conditions, status_keys):
		return _failure("invalid_state")
	for key: String in status_keys:
		if typeof(slot.status_conditions.get(key)) != TYPE_BOOL:
			return _failure("invalid_state")
	var max_hp: Variant = slot.get_max_hp()
	var hp: Variant = slot.get_remaining_hp()
	if not _is_positive(max_hp) or not _is_nonnegative(hp) or int(hp) > int(max_hp):
		return _failure("invalid_state")
	return {
		"ok": true,
		"error_code": "",
		"value": {
			"stack": stack,
			"attached_energy": energies,
			"tool": tool,
			"hp": hp,
			"max_hp": max_hp,
			"appear_this_turn": slot.turn_played == turn_number or slot.turn_evolved == turn_number,
			"status": slot.status_conditions.duplicate(true),
		},
		"identity_checks": checks,
	}


func _capture_engine_card(
	card_value: Variant,
	expected_owner: int,
	include_energy_type: bool,
	registry: Variant,
	generation: int,
	source_documents: Dictionary,
	context: Dictionary
) -> Dictionary:
	if not _has_exact_script(card_value, CardInstanceScript):
		_capture_stage = "card_reference"
		return _failure("invalid_card_identity")
	var card: CardInstance = card_value as CardInstance
	if not _has_exact_script(card.card_data, CardDataScript):
		_capture_stage = "card_data_reference"
		return _failure("invalid_card_identity")
	if expected_owner >= 0 and card.owner_index != expected_owner:
		_capture_stage = "card_owner"
		return _failure("invalid_card_identity")
	_capture_stage = "card_source"
	var verified := _verified_engine_source(card.card_data, source_documents, context)
	if not bool(verified.get("ok", false)):
		return verified
	var registry_result: Dictionary = registry.lookup_card(card, generation, expected_owner)
	if not bool(registry_result.get("ok", false)):
		_capture_stage = "card_registry:%s" % registry_result.get("code")
		return _failure(_registry_error(str(registry_result.get("code", "")), true))
	var value := {
		"official_card_id": verified.get("official_card_id"),
		"serial": registry_result.get("serial"),
		"player_index": registry_result.get("player_index"),
	}
	if include_energy_type:
		var energy_code: Variant = card.card_data.energy_type
		if energy_code == "":
			energy_code = card.card_data.energy_provides
		if typeof(energy_code) != TYPE_STRING or not ENERGY_TYPE_BY_CODE.has(energy_code):
			_capture_stage = "energy_type"
			return _failure("invalid_card_identity")
		value["energy_type"] = ENERGY_TYPE_BY_CODE[energy_code]
	return {"ok": true, "error_code": "", "value": value}


func _verified_engine_source(card_data: CardData, source_documents: Dictionary, context: Dictionary) -> Dictionary:
	var key := source_document_key(card_data.set_code, card_data.card_index)
	if key.is_empty() or not source_documents.has(key):
		_capture_stage = "source_missing:%s" % key
		return _failure("card_catalog_unmapped")
	var source_bytes: Variant = source_documents.get(key)
	if not source_bytes is PackedByteArray:
		_capture_stage = "source_type:%s" % key
		return _failure("invalid_card_identity")
	var cache: Dictionary = context.get("source_cache")
	var verified: Dictionary = cache.get(key, {})
	if verified.is_empty():
		var source_result: Dictionary = _catalog.validate_local_source(card_data.set_code, card_data.card_index, source_bytes)
		if not bool(source_result.get("ok", false)):
			_capture_stage = "source_hash:%s" % key
			return _failure("card_catalog_unmapped")
		var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(source_bytes)
		var source: Variant = parsed.get("value")
		if not bool(parsed.get("ok", false)) or not source is Dictionary:
			_capture_stage = "source_parse:%s" % key
			return _failure("invalid_card_identity")
		var card_result: Dictionary = _catalog.lookup_official_card_id(card_data.set_code, card_data.card_index)
		if not bool(card_result.get("ok", false)) or not _is_positive(card_result.get("value")):
			_capture_stage = "source_catalog:%s" % key
			return _failure("card_catalog_unmapped")
		verified = {"source": source.duplicate(true), "official_card_id": card_result.get("value")}
		cache[key] = verified
	if not _card_data_matches_source(card_data, verified.get("source")):
		_capture_stage = "source_live_mismatch:%s" % key
		return _failure("invalid_card_identity")
	return {"ok": true, "error_code": "", "official_card_id": verified.get("official_card_id")}


func _card_data_matches_source(card_data: CardData, source: Variant) -> bool:
	if not source is Dictionary:
		return false
	for key: String in ["set_code", "card_index", "set_code_en", "card_index_en", "card_type", "energy_type", "energy_provides", "stage"]:
		if typeof(source.get(key)) != TYPE_STRING or source.get(key) != card_data.get(key):
			return false
	if typeof(source.get("hp")) != TYPE_INT or source.get("hp") != card_data.hp:
		return false
	var attacks: Variant = source.get("attacks")
	return attacks is Array and attacks.size() == card_data.attacks.size()


func _capture_engine_decision(
	state_value: Variant,
	registry: Variant,
	generation: int,
	source_documents: Dictionary,
	decision_source: Dictionary,
	context: Dictionary,
	chooser_player_index: int
) -> Dictionary:
	var select_value: Variant = decision_source.get("select")
	var deck_cards: Variant = decision_source.get("deck_cards")
	var context_card: Variant = decision_source.get("context_card")
	var effect_card: Variant = decision_source.get("effect_card")
	var option_refs: Variant = decision_source.get("option_card_refs")
	if select_value == null:
		if deck_cards != null or context_card != null or effect_card != null or not option_refs is Array or not option_refs.is_empty():
			return _failure("invalid_decision")
		return {"ok": true, "error_code": "", "value": null, "identity_checks": 0}
	if not select_value is Dictionary or not option_refs is Array:
		return _failure("invalid_decision")
	var required := ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck", "contextCard", "effect"]
	if not _exact_dictionary_keys(select_value, required):
		return _failure("invalid_decision")
	if select_value.get("deck") != null or select_value.get("contextCard") != null or select_value.get("effect") != null:
		return _failure("invalid_decision")
	var source_options: Variant = select_value.get("option")
	if not source_options is Array or source_options.size() != option_refs.size() or source_options.size() > 256:
		return _failure("invalid_decision")
	var state: GameState = state_value as GameState
	var acting := chooser_player_index
	var options := []
	var checks := 0
	for index: int in range(source_options.size()):
		var option: Variant = source_options[index]
		var reference: Variant = option_refs[index]
		if not option is Dictionary or typeof(option.get("type")) != TYPE_INT or not ENGINE_SUPPORTED_OPTION_TYPES.has(option.get("type")):
			return _failure("invalid_decision")
		var option_type := int(option.get("type"))
		if option_type == 13:
			if not _exact_dictionary_keys(option, ["type", "local_attack_index"]) or reference != null:
				return _failure("invalid_decision")
			if state.players[acting].active_pokemon == null:
				return _failure("invalid_attack_identity")
			var attack_result := _engine_attack_id(
				state.players[acting].active_pokemon.get_top_card(), option.get("local_attack_index"),
				source_documents, context
			)
			if not bool(attack_result.get("ok", false)):
				return attack_result
			options.append({"type": 13, "attackId": attack_result.get("value")})
			checks += 1
		elif option_type == 15:
			if _exact_dictionary_keys(option, OPTION_SHAPES[15]):
				if reference != null or option.get("cardId") != 0 or option.get("serial") != 0:
					return _failure("invalid_decision")
				# Official SKILL_ORDER uses (0,0) for a real rule sentinel.  It is
				# not a missing entity and must survive the sparse wire unchanged.
				options.append(option.duplicate(true))
			elif _exact_dictionary_keys(option, ["type"]):
				var card_result := _capture_engine_card(
					reference, -1, false, registry, generation, source_documents, context
				)
				if not bool(card_result.get("ok", false)):
					return card_result
				var card: Dictionary = card_result.get("value")
				options.append({"type": 15, "cardId": card.get("official_card_id"), "serial": card.get("serial")})
				checks += 1
			else:
				return _failure("invalid_decision")
		else:
			if reference != null or not OPTION_SHAPES.has(option_type) or not _exact_dictionary_keys(option, OPTION_SHAPES[option_type]):
				return _failure("invalid_decision")
			options.append(option.duplicate(true))
	var deck: Variant = null
	if deck_cards != null:
		if not deck_cards is Array or deck_cards.size() > 120:
			return _failure("invalid_decision")
		deck = []
		for card_value: Variant in deck_cards:
			var deck_result := _capture_engine_card(
				card_value, acting, false, registry, generation, source_documents, context
			)
			if not bool(deck_result.get("ok", false)):
				return deck_result
			deck.append(deck_result.get("value"))
			checks += 1
	var captured_context: Variant = null
	if context_card != null:
		var context_result := _capture_engine_card(
			context_card, -1, false, registry, generation, source_documents, context
		)
		if not bool(context_result.get("ok", false)):
			return context_result
		captured_context = context_result.get("value")
		checks += 1
	var captured_effect: Variant = null
	if effect_card != null:
		var effect_result := _capture_engine_card(
			effect_card, -1, false, registry, generation, source_documents, context
		)
		if not bool(effect_result.get("ok", false)):
			return effect_result
		captured_effect = effect_result.get("value")
		checks += 1
	var output: Dictionary = select_value.duplicate(true)
	output["option"] = options
	output["deck"] = deck
	output["contextCard"] = captured_context
	output["effect"] = captured_effect
	return {"ok": true, "error_code": "", "value": output, "identity_checks": checks}


func _capture_engine_event(
	event_value: Variant,
	state_value: Variant,
	registry: Variant,
	generation: int,
	source_documents: Dictionary,
	context: Dictionary
) -> Dictionary:
	if not event_value is Dictionary or typeof(event_value.get("kind")) != TYPE_STRING:
		return _failure("invalid_public_event")
	var event: Dictionary = event_value
	var kind: String = event.get("kind")
	if kind in ["turn_start", "turn_end", "result"]:
		if not _exact_dictionary_keys(event, ["kind", "player_index"]) or typeof(event.get("player_index")) != TYPE_INT or int(event.get("player_index")) not in [0, 1]:
			return _failure("invalid_public_event")
		if kind == "result" and int(event.get("player_index")) != int((state_value as GameState).winner_index):
			return _failure("invalid_public_event")
		return {"ok": true, "error_code": "", "value": event.duplicate(true), "identity_checks": 0}
	var allowed_keys := {
		"move_card": ["kind", "card_ref", "from_area", "to_area"],
		"play": ["kind", "card_ref"],
		"attach": ["kind", "card_ref", "target_ref"],
		"evolve": ["kind", "card_ref"],
		"attack": ["kind", "card_ref", "local_attack_index"],
		"hp_change": ["kind", "card_ref", "value", "put_damage_counter"],
	}
	if not allowed_keys.has(kind) or not _exact_dictionary_keys(event, allowed_keys[kind]):
		return _failure("invalid_public_event")
	var card_result := _capture_engine_card(
		event.get("card_ref"), -1, false, registry, generation, source_documents, context
	)
	if not bool(card_result.get("ok", false)):
		return card_result
	var output := {"kind": kind, "card": card_result.get("value")}
	var checks := 1
	if kind == "move_card":
		if not _is_nonnegative(event.get("from_area")) or not _is_nonnegative(event.get("to_area")):
			return _failure("invalid_public_event")
		output["from_area"] = event.get("from_area")
		output["to_area"] = event.get("to_area")
	elif kind == "attach":
		var target_result := _capture_engine_card(
			event.get("target_ref"), -1, false, registry, generation, source_documents, context
		)
		if not bool(target_result.get("ok", false)):
			return target_result
		output["target"] = target_result.get("value")
		checks += 1
	elif kind == "attack":
		var attack_result := _engine_attack_id(event.get("card_ref"), event.get("local_attack_index"), source_documents, context)
		if not bool(attack_result.get("ok", false)):
			return attack_result
		output["attack_id"] = attack_result.get("value")
		checks += 1
	elif kind == "hp_change":
		if not _is_safe_integer(event.get("value")) or typeof(event.get("put_damage_counter")) != TYPE_BOOL:
			return _failure("invalid_public_event")
		output["value"] = event.get("value")
		output["put_damage_counter"] = event.get("put_damage_counter")
	return {"ok": true, "error_code": "", "value": output, "identity_checks": checks}


func _engine_attack_id(card_value: Variant, local_attack_index: Variant, source_documents: Dictionary, context: Dictionary) -> Dictionary:
	if not _has_exact_script(card_value, CardInstanceScript) or not _is_nonnegative(local_attack_index):
		return _failure("invalid_attack_identity")
	var card: CardInstance = card_value as CardInstance
	if not _has_exact_script(card.card_data, CardDataScript):
		return _failure("invalid_attack_identity")
	var verified := _verified_engine_source(card.card_data, source_documents, context)
	if not bool(verified.get("ok", false)):
		return verified
	if int(local_attack_index) >= card.card_data.attacks.size():
		return _failure("invalid_attack_identity")
	var key := "%s#%d" % [source_document_key(card.card_data.set_code, card.card_data.card_index), int(local_attack_index)]
	var cache: Dictionary = context.get("attack_cache")
	if cache.has(key):
		return {"ok": true, "error_code": "", "value": cache[key]}
	var attack_result: Dictionary = _catalog.lookup_official_attack_id(card.card_data.set_code, card.card_data.card_index, local_attack_index)
	if not bool(attack_result.get("ok", false)) or not _is_positive(attack_result.get("value")):
		return _failure("invalid_attack_identity")
	var owner_result: Dictionary = _catalog.official_attack_owner(attack_result.get("value"))
	if not bool(owner_result.get("ok", false)) or owner_result.get("value", {}).get("owner_official_card_id") != verified.get("official_card_id"):
		return _failure("invalid_attack_identity")
	cache[key] = attack_result.get("value")
	return {"ok": true, "error_code": "", "value": attack_result.get("value")}


static func _registry_error(code: String, card_domain: bool) -> String:
	if code == "stale_match_generation":
		return "stale_match_generation"
	if code in ["card_owner_mismatch", "pokemon_owner_mismatch", "pokemon_entity_root_changed", "pokemon_entity_root_already_active"]:
		return "invalid_card_identity" if card_domain else "invalid_state"
	return "card_serial_unbound" if card_domain else "invalid_state"


static func _has_exact_script(value: Variant, expected_script: GDScript) -> bool:
	return value is Object and is_instance_valid(value) and value.get_script() == expected_script


func _materialize_case(vectors: Variant, case_value: Variant) -> Variant:
	if not vectors is Dictionary or not case_value is Dictionary:
		return null
	if vectors.get("artifact_id") != VECTOR_ID or vectors.get("profile_id") != PROFILE_ID:
		return null
	var case: Dictionary = case_value
	if case.has("window"):
		var fixtures: Variant = vectors.get("state_fixtures")
		if not fixtures is Dictionary or not fixtures.get(case.get("state_fixture_id")) is Dictionary:
			return null
		return {
			"current_source": fixtures.get(case.get("state_fixture_id")).duplicate(true),
			"select_source": (case.get("select_source") as Dictionary).duplicate(true),
			"public_events": (case.get("public_events") as Array).duplicate(true),
			"step": case.get("step"),
			"remainingOverageTime": case.get("remainingOverageTime"),
		}
	var base: Variant = null
	for candidate: Variant in vectors.get("projection_cases", []):
		if candidate is Dictionary and candidate.get("case_id") == case.get("base_case_id"):
			base = candidate
			break
	var value: Variant = _materialize_case(vectors, base)
	if not value is Dictionary or not case.get("fault") is Dictionary:
		return null
	_apply_fault(value, case.get("fault"))
	return value


func _apply_fault(value: Dictionary, fault: Dictionary) -> void:
	match str(fault.get("kind")):
		"replace_public_events":
			value["public_events"] = ProjectorResult._copy(fault.get("value"))
		"replace_select_options":
			value.get("select_source", {})["option"] = ProjectorResult._copy(fault.get("value"))
		"replace":
			var parts := str(fault.get("pointer")).split("/", false)
			var cursor: Variant = value
			for index: int in range(parts.size() - 1):
				cursor = cursor[int(parts[index])] if cursor is Array else cursor[parts[index]]
			var last: String = parts[-1]
			if cursor is Array:
				cursor[int(last)] = ProjectorResult._copy(fault.get("value"))
			else:
				cursor[last] = ProjectorResult._copy(fault.get("value"))


func _evaluate(fixture: Variant) -> Dictionary:
	if not validate_integrity():
		return _rejected("projector_contract_error")
	var validation := _validate_fixture(fixture)
	if not bool(validation.get("ok", false)):
		return _rejected(str(validation.get("error_code", "invalid_input")))
	var raw: Dictionary = validation.get("raw")
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, _contract_set)
	var firewall_result: Variant = _firewall.project(parsed)
	if firewall_result == null or not firewall_result.accepted:
		return _rejected("firewall_rejected")
	return {
		"accepted": true,
		"error_code": "",
		"observation": firewall_result.public_observation,
		"public_observation_hash": firewall_result.public_observation_hash,
		"audit": {
			"authority": "conformance_fixture_only",
			"source_classes": ["conformance_fixture_only", "strict_catalog"],
			"projector_bundle_hash": EXPECTED_BUNDLE_HASH,
			"identity_checks": validation.get("identity_checks", 0),
			"hidden_fields_emitted": 0,
		},
		"firewall_result": firewall_result,
	}


func _rejected(code: String) -> Dictionary:
	return {"accepted":false,"error_code":code if ERROR_CODES.has(code) else "invalid_input","observation":null,"public_observation_hash":null,"audit":null}


func _validate_fixture(fixture: Variant) -> Dictionary:
	if not fixture is Dictionary:
		return _failure("invalid_input")
	var allowed := ["current_source", "select_source", "public_events", "step", "remainingOverageTime"]
	for key: Variant in fixture.keys():
		if typeof(key) != TYPE_STRING or key not in allowed:
			return _failure("invalid_input")
	for required: String in ["current_source", "select_source", "public_events"]:
		if not fixture.has(required):
			return _failure("invalid_input")
	var current: Variant = fixture.get("current_source")
	if not current is Dictionary:
		return _failure("invalid_state")
	var acting: Variant = current.get("acting_player_index")
	if typeof(acting) != TYPE_INT or int(acting) not in [0, 1]:
		return _failure("invalid_player_index")
	var players: Variant = current.get("players")
	if not players is Array or players.size() != 2:
		return _failure("invalid_state")
	var authority := {}
	var checks := 0
	for player_index: int in range(2):
		var player_validation := _validate_player(players[player_index], player_index, int(acting), authority)
		if not bool(player_validation.get("ok", false)):
			return player_validation
		checks += int(player_validation.get("identity_checks", 0))
	var stadium: Variant = current.get("stadium")
	if stadium != null:
		var stadium_error := _register_card(stadium, -1, authority)
		if not stadium_error.is_empty():
			return _failure(stadium_error)
		checks += 1
	for flag: String in ["supporter_played", "stadium_played", "energy_attached", "retreated"]:
		if typeof(current.get(flag)) != TYPE_BOOL:
			return _failure("invalid_state")
	for key: String in ["turn", "turn_action_count"]:
		if not _is_nonnegative(current.get(key)):
			return _failure("invalid_state")
	if typeof(current.get("first_player_index")) != TYPE_INT or int(current.get("first_player_index")) not in [-1, 0, 1]:
		return _failure("invalid_state")
	if typeof(current.get("result")) != TYPE_INT or int(current.get("result")) not in [-1, 0, 1]:
		return _failure("invalid_state")
	var select_validation := _validate_select(fixture.get("select_source"), current, authority)
	if not bool(select_validation.get("ok", false)):
		return select_validation
	checks += int(select_validation.get("identity_checks", 0))
	var events: Variant = fixture.get("public_events")
	if not events is Array:
		return _failure("invalid_public_event")
	if events.size() > 512:
		return _failure("limit_exceeded")
	for event: Variant in events:
		var event_validation := _validate_event(event, authority, current)
		if not bool(event_validation.get("ok", false)):
			return event_validation
		checks += int(event_validation.get("identity_checks", 0))
	if fixture.has("step") and not _is_nonnegative(fixture.get("step")):
		return _failure("invalid_input")
	if fixture.has("remainingOverageTime") and not _is_nonnegative(fixture.get("remainingOverageTime")):
		return _failure("invalid_input")
	return {"ok":true,"error_code":"","raw":_build_raw(fixture),"identity_checks":checks}


func _validate_player(player: Variant, owner: int, acting: int, authority: Dictionary) -> Dictionary:
	var keys := ["active", "bench", "bench_max", "deck_count", "discard", "hand", "hand_count", "prize_count", "public_prizes"]
	if not _exact_dictionary_keys(player, keys):
		return _failure("invalid_state")
	var active: Array = player.get("active") if player.get("active") is Array else []
	var bench: Array = player.get("bench") if player.get("bench") is Array else []
	if not player.get("active") is Array or active.size() > 1 or not player.get("bench") is Array or bench.size() > 8:
		return _failure("invalid_state")
	if not _is_nonnegative(player.get("bench_max")) or int(player.get("bench_max")) > 8 or not _is_nonnegative(player.get("deck_count")) or int(player.get("deck_count")) > 120:
		return _failure("invalid_state")
	if owner == acting:
		if not player.get("hand") is Array or player.get("hand").size() > 60 or player.get("hand_count") != player.get("hand").size():
			return _failure("invalid_state")
	elif player.get("hand") != null or not _is_nonnegative(player.get("hand_count")) or int(player.get("hand_count")) > 60:
		return _failure("invalid_state")
	if not player.get("discard") is Array or player.get("discard").size() > 120 or not _is_nonnegative(player.get("prize_count")) or int(player.get("prize_count")) > 12:
		return _failure("invalid_state")
	if not player.get("public_prizes") is Dictionary:
		return _failure("invalid_state")
	var checks := 0
	for pokemon: Variant in active + bench:
		var pokemon_validation := _validate_pokemon(pokemon, owner, authority)
		if not bool(pokemon_validation.get("ok", false)):
			return pokemon_validation
		checks += int(pokemon_validation.get("identity_checks", 0))
	var visible_hand: Array = player.get("hand") if owner == acting else []
	for card: Variant in player.get("discard") + visible_hand:
		var card_error := _register_card(card, owner, authority)
		if not card_error.is_empty():
			return _failure(card_error)
		checks += 1
	for index_text: Variant in player.get("public_prizes"):
		if typeof(index_text) != TYPE_STRING or not _canonical_index(str(index_text)) or int(index_text) >= int(player.get("prize_count")):
			return _failure("invalid_state")
		var prize_error := _register_card(player.get("public_prizes")[index_text], owner, authority)
		if not prize_error.is_empty():
			return _failure(prize_error)
		checks += 1
	return {"ok":true,"error_code":"","identity_checks":checks}


func _validate_pokemon(pokemon: Variant, owner: int, authority: Dictionary) -> Dictionary:
	var keys := ["stack", "attached_energy", "tool", "hp", "max_hp", "appear_this_turn", "status"]
	if not _exact_dictionary_keys(pokemon, keys):
		return _failure("invalid_state")
	if not pokemon.get("stack") is Array or pokemon.get("stack").is_empty() or pokemon.get("stack").size() > 3:
		return _failure("invalid_state")
	if not pokemon.get("attached_energy") is Array or pokemon.get("attached_energy").size() > 64:
		return _failure("invalid_state")
	if not _is_nonnegative(pokemon.get("hp")) or not _is_positive(pokemon.get("max_hp")) or int(pokemon.get("hp")) > int(pokemon.get("max_hp")) or typeof(pokemon.get("appear_this_turn")) != TYPE_BOOL:
		return _failure("invalid_state")
	var status: Variant = pokemon.get("status")
	var status_keys := ["poisoned", "burned", "asleep", "paralyzed", "confused"]
	if not _exact_dictionary_keys(status, status_keys):
		return _failure("invalid_state")
	for key: String in status_keys:
		if typeof(status.get(key)) != TYPE_BOOL:
			return _failure("invalid_state")
	var checks := 0
	for card: Variant in pokemon.get("stack"):
		var card_error := _register_card(card, owner, authority)
		if not card_error.is_empty():
			return _failure(card_error)
		checks += 1
	for card: Variant in pokemon.get("attached_energy"):
		if not card is Dictionary or typeof(card.get("energy_type")) != TYPE_INT or int(card.get("energy_type")) < 0 or int(card.get("energy_type")) > 11:
			return _failure("invalid_card_identity")
		var energy_error := _register_card(card, -1, authority)
		if not energy_error.is_empty():
			return _failure(energy_error)
		checks += 1
	if pokemon.get("tool") != null:
		var tool_error := _register_card(pokemon.get("tool"), -1, authority)
		if not tool_error.is_empty():
			return _failure(tool_error)
		checks += 1
	return {"ok":true,"error_code":"","identity_checks":checks}


func _register_card(card: Variant, expected_owner: int, authority: Dictionary) -> String:
	if not card is Dictionary:
		return "invalid_card_identity"
	for key: Variant in card.keys():
		if typeof(key) != TYPE_STRING or key not in ["official_card_id", "serial", "player_index", "energy_type"]:
			return "invalid_card_identity"
	for key: String in ["official_card_id", "serial", "player_index"]:
		if not card.has(key):
			return "invalid_card_identity"
	var card_id: Variant = card.get("official_card_id")
	var serial: Variant = card.get("serial")
	var player: Variant = card.get("player_index")
	if not _is_positive(card_id) or not _is_positive(serial) or typeof(player) != TYPE_INT or int(player) not in [0, 1] or (expected_owner >= 0 and int(player) != expected_owner):
		return "invalid_card_identity"
	if not MAPPED_CARD_IDS.has(card_id):
		return "card_catalog_unmapped"
	if authority.has(serial):
		return "invalid_card_identity"
	authority[serial] = [card_id, player]
	return ""


func _reference_card(value: Variant, authority: Dictionary) -> bool:
	if not _exact_dictionary_keys(value, ["id", "playerIndex", "serial"]):
		return false
	return _is_positive(value.get("serial")) and authority.get(value.get("serial")) == [value.get("id"), value.get("playerIndex")]


func _register_or_match_card(card: Variant, authority: Dictionary) -> bool:
	if not card is Dictionary:
		return false
	for key: Variant in card.keys():
		if typeof(key) != TYPE_STRING or key not in ["official_card_id", "serial", "player_index", "energy_type"]:
			return false
	for required: String in ["official_card_id", "serial", "player_index"]:
		if not card.has(required):
			return false
	var serial: Variant = card.get("serial")
	if not _is_positive(card.get("official_card_id")) or not _is_positive(serial) or typeof(card.get("player_index")) != TYPE_INT or int(card.get("player_index")) not in [0, 1]:
		return false
	if authority.has(serial):
		return authority.get(serial) == [card.get("official_card_id"), card.get("player_index")]
	return _register_card(card, -1, authority).is_empty()


func _validate_select(select_value: Variant, current: Dictionary, authority: Dictionary) -> Dictionary:
	if select_value == null:
		return {"ok":true,"error_code":"","identity_checks":0}
	var keys := ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck", "contextCard", "effect"]
	if not _exact_dictionary_keys(select_value, keys):
		return _failure("invalid_select")
	if typeof(select_value.get("type")) != TYPE_INT or int(select_value.get("type")) < 0 or int(select_value.get("type")) > 10 or not _is_nonnegative(select_value.get("context")):
		return _failure("invalid_select")
	var options: Variant = select_value.get("option")
	if not options is Array or options.size() > 256:
		return _failure("invalid_select")
	for key: String in ["minCount", "maxCount", "remainDamageCounter", "remainEnergyCost"]:
		if not _is_nonnegative(select_value.get(key)):
			return _failure("invalid_select")
	if int(select_value.get("minCount")) > int(select_value.get("maxCount")) or int(select_value.get("maxCount")) > options.size():
		return _failure("invalid_select")
	var deck_authority := {}
	var deck: Variant = select_value.get("deck")
	if deck != null:
		if not deck is Array or deck.size() > 120:
			return _failure("limit_exceeded")
		for card: Variant in deck:
			var deck_error := _register_card(card, int(current.get("acting_player_index")), deck_authority)
			if not deck_error.is_empty():
				return _failure("invalid_select")
	var checks := deck_authority.size()
	for name: String in ["contextCard", "effect"]:
		var card: Variant = select_value.get(name)
		if card != null:
			var wire: Variant = {"id":card.get("official_card_id"),"serial":card.get("serial"),"playerIndex":card.get("player_index")} if card is Dictionary else null
			if wire == null or not _reference_card(wire, authority):
				return _failure("invalid_select")
			checks += 1
	var actor: int = int(current.get("acting_player_index"))
	for option: Variant in options:
		if not option is Dictionary or typeof(option.get("type")) != TYPE_INT or not OPTION_SHAPES.has(option.get("type")) or not _exact_dictionary_keys(option, OPTION_SHAPES[option.get("type")]):
			return _failure("invalid_select")
		var option_type: int = int(option.get("type"))
		if option_type == 7 and (not _is_nonnegative(option.get("index")) or int(option.get("index")) >= current.get("players")[actor].get("hand").size()):
			return _failure("invalid_select")
		if option_type == 13:
			var active: Array = current.get("players")[actor].get("active")
			var owner_id: Variant = null if active.is_empty() else active[-1].get("stack")[-1].get("official_card_id")
			if not _attack_matches(option.get("attackId"), owner_id):
				return _failure("invalid_attack_identity")
			checks += 1
		if option_type == 15:
			var skill_sentinel: bool = option.get("cardId") == 0 and option.get("serial") == 0
			if not skill_sentinel and (not _is_positive(option.get("cardId")) or not _is_positive(option.get("serial")) or authority.get(option.get("serial"), [null, null])[0] != option.get("cardId")):
				return _failure("invalid_select")
			if not skill_sentinel:
				checks += 1
		if option_type == 3 and not _coordinate_exists(option, current, deck):
			return _failure("invalid_select")
	return {"ok":true,"error_code":"","identity_checks":checks}


func _coordinate_exists(option: Dictionary, current: Dictionary, deck: Variant) -> bool:
	for key: String in ["area", "index", "playerIndex"]:
		if typeof(option.get(key)) != TYPE_INT:
			return false
	var area: int = int(option.get("area")); var index: int = int(option.get("index")); var player: int = int(option.get("playerIndex"))
	if player not in [0, 1] or index < 0:
		return false
	var source: Dictionary = current.get("players")[player]
	match area:
		1: return deck is Array and index < deck.size()
		2: return source.get("hand") is Array and index < source.get("hand").size()
		4: return index < source.get("active").size()
		5: return index < source.get("bench").size()
		6: return index < int(source.get("prize_count"))
	return false


func _attack_matches(attack_id: Variant, owner_card_id: Variant) -> bool:
	if not _is_positive(attack_id) or not _is_positive(owner_card_id):
		return false
	return ATTACK_OWNER_CARD_IDS.get(attack_id) == owner_card_id


func _validate_event(event: Variant, authority: Dictionary, _current: Dictionary) -> Dictionary:
	if not event is Dictionary or typeof(event.get("kind")) != TYPE_STRING:
		return _failure("invalid_public_event")
	var kind: String = str(event.get("kind"))
	if kind in ["turn_start", "turn_end", "result"]:
		if not _exact_dictionary_keys(event, ["kind", "player_index"]) or typeof(event.get("player_index")) != TYPE_INT or int(event.get("player_index")) not in [0, 1]:
			return _failure("invalid_public_event")
		return {"ok":true,"error_code":"","identity_checks":0}
	var allowed_keys := {
		"move_card": ["kind", "card", "from_area", "to_area"],
		"play": ["kind", "card"],
		"attach": ["kind", "card", "target"],
		"evolve": ["kind", "card"],
		"attack": ["kind", "card", "attack_id"],
		"hp_change": ["kind", "card", "value", "put_damage_counter"],
	}
	if not allowed_keys.has(kind) or not _exact_dictionary_keys(event, allowed_keys[kind]):
		return _failure("invalid_public_event")
	var card: Variant = event.get("card")
	if not _register_or_match_card(card, authority):
		return _failure("invalid_public_event")
	if kind == "attack" and not _attack_matches(event.get("attack_id"), card.get("official_card_id")):
		return _failure("invalid_attack_identity")
	if kind == "attach":
		var target: Variant = event.get("target")
		if not _register_or_match_card(target, authority):
			return _failure("invalid_public_event")
	if kind == "move_card" and (not _is_nonnegative(event.get("from_area")) or not _is_nonnegative(event.get("to_area"))):
		return _failure("invalid_public_event")
	if kind == "hp_change" and (not _is_safe_integer(event.get("value")) or typeof(event.get("put_damage_counter")) != TYPE_BOOL):
		return _failure("invalid_public_event")
	return {"ok":true,"error_code":"","identity_checks":1}


func _wire_card(card: Dictionary) -> Dictionary:
	return {"id":card.get("official_card_id"),"playerIndex":card.get("player_index"),"serial":card.get("serial")}


func _wire_select(source: Variant) -> Variant:
	if source == null:
		return null
	if not source is Dictionary:
		return null
	var value: Dictionary = source.duplicate(true)
	if value.get("deck") != null:
		var deck := []
		for card: Dictionary in value.get("deck"):
			deck.append(_wire_card(card))
		value["deck"] = deck
	for key: String in ["contextCard", "effect"]:
		if value.get(key) != null:
			value[key] = _wire_card(value.get(key))
	return value


func _wire_pokemon(source: Dictionary) -> Dictionary:
	var stack: Array = source.get("stack")
	var top: Dictionary = stack[-1]
	var energies := []
	var energy_cards := []
	for card: Dictionary in source.get("attached_energy"):
		energies.append(card.get("energy_type"))
		energy_cards.append(_wire_card(card))
	var tools := []
	if source.get("tool") != null:
		tools.append(_wire_card(source.get("tool")))
	var pre_evolution := []
	for index: int in range(stack.size() - 1):
		pre_evolution.append(_wire_card(stack[index]))
	return {
		"appearThisTurn":source.get("appear_this_turn"),"energies":energies,"energyCards":energy_cards,
		"hp":source.get("hp"),"id":top.get("official_card_id"),"maxHp":source.get("max_hp"),
		"playerIndex":top.get("player_index"),"preEvolution":pre_evolution,"serial":top.get("serial"),"tools":tools,
	}


func _wire_player(source: Dictionary, player_index: int, acting: int) -> Dictionary:
	var active: Array = source.get("active")
	var status := {"poisoned":false,"burned":false,"asleep":false,"paralyzed":false,"confused":false}
	if not active.is_empty():
		status = (active[0].get("status") as Dictionary).duplicate(true)
	var prizes := []
	prizes.resize(int(source.get("prize_count")))
	prizes.fill(null)
	for index_text: Variant in source.get("public_prizes"):
		prizes[int(index_text)] = _wire_card(source.get("public_prizes")[index_text])
	var active_wire := []
	for item: Dictionary in active:
		active_wire.append(_wire_pokemon(item))
	var bench_wire := []
	for item: Dictionary in source.get("bench"):
		bench_wire.append(_wire_pokemon(item))
	var discard_wire := []
	for card: Dictionary in source.get("discard"):
		discard_wire.append(_wire_card(card))
	var hand_wire: Variant = null
	if player_index == acting:
		hand_wire = []
		for card: Dictionary in source.get("hand"):
			hand_wire.append(_wire_card(card))
	return {
		"active":active_wire,"asleep":status.get("asleep"),"bench":bench_wire,"benchMax":source.get("bench_max"),
		"burned":status.get("burned"),"confused":status.get("confused"),"deckCount":source.get("deck_count"),
		"discard":discard_wire,"hand":hand_wire,"handCount":source.get("hand_count"),
		"paralyzed":status.get("paralyzed"),"poisoned":status.get("poisoned"),"prize":prizes,
	}


func _wire_log(event: Dictionary) -> Dictionary:
	var kind: String = str(event.get("kind"))
	if kind == "turn_start": return {"playerIndex":event.get("player_index"),"type":2}
	if kind == "turn_end": return {"playerIndex":event.get("player_index"),"type":3}
	if kind == "result": return {"playerIndex":event.get("player_index"),"type":23}
	var card: Dictionary = _wire_card(event.get("card"))
	if kind == "move_card": return {"cardId":card.get("id"),"fromArea":event.get("from_area"),"playerIndex":card.get("playerIndex"),"serial":card.get("serial"),"toArea":event.get("to_area"),"type":6}
	if kind == "play": return {"cardId":card.get("id"),"playerIndex":card.get("playerIndex"),"serial":card.get("serial"),"type":10}
	if kind == "attach":
		var target: Dictionary = _wire_card(event.get("target"))
		return {"cardId":card.get("id"),"cardIdTarget":target.get("id"),"playerIndex":card.get("playerIndex"),"serial":card.get("serial"),"serialTarget":target.get("serial"),"type":11}
	if kind == "evolve": return {"cardId":card.get("id"),"playerIndex":card.get("playerIndex"),"serial":card.get("serial"),"type":12}
	if kind == "attack": return {"attackId":event.get("attack_id"),"cardId":card.get("id"),"playerIndex":card.get("playerIndex"),"serial":card.get("serial"),"type":15}
	return {"cardId":card.get("id"),"playerIndex":card.get("playerIndex"),"putDamageCounter":event.get("put_damage_counter"),"serial":card.get("serial"),"type":16,"value":event.get("value")}


func _build_raw(fixture: Dictionary) -> Dictionary:
	var current: Dictionary = fixture.get("current_source")
	var acting: int = int(current.get("acting_player_index"))
	var players := []
	for index: int in range(2):
		players.append(_wire_player(current.get("players")[index], index, acting))
	var stadium := []
	if current.get("stadium") != null:
		stadium.append(_wire_card(current.get("stadium")))
	var logs := []
	for event: Dictionary in fixture.get("public_events"):
		logs.append(_wire_log(event))
	var raw := {
		"select":_wire_select(fixture.get("select_source")),"logs":logs,
		"current":{
			"energyAttached":current.get("energy_attached"),"firstPlayer":current.get("first_player_index"),"looking":null,
			"players":players,"result":current.get("result"),"retreated":current.get("retreated"),"stadium":stadium,
			"stadiumPlayed":current.get("stadium_played"),"supporterPlayed":current.get("supporter_played"),
			"turn":current.get("turn"),"turnActionCount":current.get("turn_action_count"),"yourIndex":acting,
		},
		"search_begin_input":null,
	}
	if fixture.has("step"): raw["step"] = fixture.get("step")
	if fixture.has("remainingOverageTime"): raw["remainingOverageTime"] = fixture.get("remainingOverageTime")
	return raw


func _valid_bundle_header(bundle: Dictionary) -> bool:
	var keys := ["schema_version", "bundle_id", "source_lock_canonical_sha256", "p1_contract_canonical_sha256", "catalog_bundle_canonical_sha256", "firewall_bundle_canonical_sha256", "parent_cursor_bundle_canonical_sha256", "artifacts"]
	return (
		_exact_dictionary_keys(bundle, keys)
		and bundle.get("schema_version") == 1 and bundle.get("bundle_id") == EXPECTED_BUNDLE_ID
		and bundle.get("source_lock_canonical_sha256") == EXPECTED_SOURCE_LOCK_HASH
		and bundle.get("p1_contract_canonical_sha256") == EXPECTED_P1_HASH
		and bundle.get("catalog_bundle_canonical_sha256") == EXPECTED_CATALOG_HASH
		and bundle.get("firewall_bundle_canonical_sha256") == EXPECTED_FIREWALL_HASH
		and bundle.get("parent_cursor_bundle_canonical_sha256") == EXPECTED_CURSOR_HASH
	)


func _profile_errors_exact() -> bool:
	var errors: Variant = _profile.get("stable_error_codes")
	if not errors is Array or errors.size() != ERROR_CODES.size():
		return false
	var seen := {}
	for code: Variant in errors:
		if typeof(code) != TYPE_STRING or seen.has(code) or not ERROR_CODES.has(code):
			return false
		seen[code] = true
	return seen.size() == ERROR_CODES.size()


func _verify_catalog_projection_surface() -> bool:
	for card_id: Variant in MAPPED_CARD_IDS:
		var card_result: Dictionary = _catalog.lookup_local_printing_for_official_card(card_id)
		if not bool(card_result.get("ok", false)):
			return false
	for attack_id: Variant in ATTACK_OWNER_CARD_IDS:
		var attack_result: Dictionary = _catalog.official_attack_owner(attack_id)
		if not bool(attack_result.get("ok", false)):
			return false
		if attack_result.get("value", {}).get("owner_official_card_id") != ATTACK_OWNER_CARD_IDS[attack_id]:
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok":false,"error_code":code}


static func _is_safe_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and abs(int(value)) <= MAX_SAFE_INTEGER


static func _is_nonnegative(value: Variant) -> bool:
	return _is_safe_integer(value) and int(value) >= 0


static func _is_positive(value: Variant) -> bool:
	return _is_safe_integer(value) and int(value) > 0


static func _canonical_index(value: String) -> bool:
	if value.is_empty():
		return false
	if value.length() > 1 and value.begins_with("0"):
		return false
	for index: int in range(value.length()):
		var code := value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


static func _exact_dictionary_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.keys().size() != expected.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or key not in expected:
			return false
	return true


static func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


static func _read_contract(path: String) -> Dictionary:
	return FirewallScript._parse_contract_json_bytes(_read_bytes(path))


static func _canonical_hash(value: Variant) -> String:
	var result: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
	if not bool(result.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(result.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
