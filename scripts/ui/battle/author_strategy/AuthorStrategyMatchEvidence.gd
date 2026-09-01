class_name AuthorStrategyMatchEvidence
extends RefCounted

const DEFAULT_ROOT := "user://ptcgdap/author_match_audits"
const MAX_PUBLIC_ACTIONS := 512
const MAX_REVIEW_TURNS := 3
const BATCH_MAX_RECORDS := 16
const BATCH_MAX_BYTES := 262144

var _file: FileAccess = null
var _path := ""
var _match_id := ""
var _identity: Dictionary = {}
var _public_actions: Array[Dictionary] = []
var _owner_audit: Dictionary = {}
var _ordinal := 0
var _dropped_actions := 0
var _started := false
var _finished := false
var _io_failed := false
var _pending_record_count := 0
var _pending_byte_count := 0
var _batch_flush_count := 0


func start(owner: Variant, output_root: String = "") -> Dictionary:
	if _started or owner == null or not owner.has_method("public_replay_identity"):
		return _error("author_evidence_owner_invalid")
	var raw_identity: Variant = owner.call("public_replay_identity")
	if not raw_identity is Dictionary or not bool((raw_identity as Dictionary).get("ok", false)):
		return _error("author_evidence_identity_invalid")
	var identity := raw_identity as Dictionary
	var match_id := str(identity.get("match_id", ""))
	if not _is_safe_segment(match_id):
		return _error("author_evidence_match_id_invalid")
	var root := output_root.strip_edges() if output_root.strip_edges() != "" else DEFAULT_ROOT
	var absolute_root := ProjectSettings.globalize_path(root)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	if directory_error not in [OK, ERR_ALREADY_EXISTS]:
		return _error("author_evidence_storage_unavailable")
	var capture_stamp := int(Time.get_unix_time_from_system() * 1000000.0)
	var path := root.path_join("%s_%d.jsonl" % [match_id, capture_stamp])
	var collision := 0
	while FileAccess.file_exists(path) and collision < 100:
		collision += 1
		path = root.path_join("%s_%d_%d.jsonl" % [match_id, capture_stamp, collision])
	if FileAccess.file_exists(path):
		return _error("author_evidence_exists")
	var opened := FileAccess.open(path, FileAccess.WRITE)
	if opened == null:
		return _error("author_evidence_storage_unavailable")
	_file = opened
	_path = path
	_match_id = match_id
	_identity = _public_identity(identity)
	_started = true
	_append_record("match_started", {"identity": _identity.duplicate(true)})
	if not _flush_pending():
		_close_file()
		return _error("author_evidence_storage_unavailable")
	return {"ok": true, "error_code": "", "path": _path}


func record_action(action: GameAction) -> void:
	if not _is_open() or action == null:
		return
	var public_action := _public_action(action)
	if public_action.is_empty():
		return
	if _public_actions.size() >= MAX_PUBLIC_ACTIONS:
		_dropped_actions += 1
		return
	_public_actions.append(public_action.duplicate(true))
	_append_record("public_action", public_action)


func record_owner_step(owner: Variant, status: String) -> void:
	if not _is_open() or owner == null or not owner.has_method("audit_snapshot"):
		return
	var raw_audit: Variant = owner.call("audit_snapshot")
	if not raw_audit is Dictionary:
		return
	_owner_audit = _owner_audit_summary(raw_audit as Dictionary)
	_append_record("owner_step", {
		"status": status.left(40),
		"audit": _owner_audit.duplicate(true),
	})
	_flush_pending()


func finish(owner: Variant, winner_index: int, reason: String, turn_number: int) -> Dictionary:
	if not _is_open():
		return _error("author_evidence_not_open")
	if owner != null and owner.has_method("audit_snapshot"):
		var raw_audit: Variant = owner.call("audit_snapshot")
		if raw_audit is Dictionary:
			_owner_audit = _owner_audit_summary(raw_audit as Dictionary)
	_append_record("match_finished", {
		"winner_index": winner_index,
		"reason": reason.left(120),
		"turn_number": maxi(0, turn_number),
		"public_action_count": _public_actions.size(),
		"dropped_action_count": _dropped_actions,
		"owner_audit": _owner_audit.duplicate(true),
	})
	_flush_pending()
	_finished = true
	_close_file()
	return audit_snapshot()


func close_incomplete(reason: String = "scene_closed") -> void:
	if not _is_open():
		return
	_append_record("match_incomplete", {
		"reason": reason.left(80),
		"public_action_count": _public_actions.size(),
		"dropped_action_count": _dropped_actions,
	})
	_flush_pending()
	_close_file()


func quick_review_context() -> Dictionary:
	if not _started:
		return {}
	var turns := _review_turns()
	var context := {
		"evidence": {
			"source": "author_strategy_match_evidence_v1",
			"visibility": "public_allow_list_v1",
			"incremental": true,
			"complete": _finished,
			"exact_action_names_only": true,
			"hidden_information_included": false,
			"limitations": [
				"Only explicitly logged public actions may be named.",
				"No hidden hand, deck order, face-down Prize identity, or private RNG is available.",
			],
		},
		"key_moments": _key_moments(),
		"critical_sequences": _critical_sequences(turns),
		"recent_turns": turns,
		"owner_audit": _owner_audit.duplicate(true),
	}
	if not turns.is_empty():
		context["last_turn"] = turns[-1].duplicate(true)
	return context


func audit_snapshot() -> Dictionary:
	return {
		"ok": _started and not _io_failed,
		"error_code": "author_evidence_write_failed" if _io_failed else "",
		"document_type": "author_strategy_match_evidence_audit_v1",
		"schema_version": 1,
		"match_id": _match_id,
		"path": _path,
		"complete": _finished,
		"event_count": _ordinal,
		"public_action_count": _public_actions.size(),
		"dropped_action_count": _dropped_actions,
		"pending_record_count": _pending_record_count,
		"pending_byte_count": _pending_byte_count,
		"batch_flush_count": _batch_flush_count,
		"write_mode": "owner_step_batch_v1",
		"visibility": "public_allow_list_v1",
		"private_replay_used": false,
		"authoritative": false,
		"production_ready": false,
	}


func _append_record(event_type: String, data: Dictionary) -> void:
	if _file == null:
		return
	var record := {
		"document_type": "author_strategy_match_evidence_event_v1",
		"schema_version": 1,
		"match_id": _match_id,
		"ordinal": _ordinal,
		"event_type": event_type,
		"recorded_at_utc": "%sZ" % Time.get_datetime_string_from_system(true),
		"data": data.duplicate(true),
	}
	var line := JSON.stringify(record)
	var stored := _file.store_line(line)
	if not stored or _file.get_error() != OK:
		_io_failed = true
		return
	_pending_record_count += 1
	_pending_byte_count += line.to_utf8_buffer().size() + 1
	_ordinal += 1
	if _pending_record_count >= BATCH_MAX_RECORDS or _pending_byte_count >= BATCH_MAX_BYTES:
		_flush_pending()


func _flush_pending() -> bool:
	if _file == null or _pending_record_count <= 0:
		return not _io_failed
	_file.flush()
	if _file.get_error() != OK:
		_io_failed = true
		return false
	_pending_record_count = 0
	_pending_byte_count = 0
	_batch_flush_count += 1
	return true


func _public_action(action: GameAction) -> Dictionary:
	var kind := _action_kind(action.action_type)
	if kind == "":
		return {}
	var facts := {}
	match action.action_type:
		GameAction.ActionType.ATTACK:
			_copy_string_fact(action.data, facts, "attack_name")
			_copy_string_fact(action.data, facts, "target_pokemon_name")
			_copy_int_fact(action.data, facts, "damage")
		GameAction.ActionType.DAMAGE_DEALT:
			_copy_string_fact(action.data, facts, "target")
			_copy_int_fact(action.data, facts, "damage")
		GameAction.ActionType.KNOCKOUT:
			_copy_string_fact(action.data, facts, "pokemon_name")
			_copy_int_fact(action.data, facts, "prize_count")
		GameAction.ActionType.TAKE_PRIZE:
			facts["prize_count"] = maxi(1, int(action.data.get("count", action.data.get("prize_count", 1))))
		GameAction.ActionType.PLAY_TRAINER, GameAction.ActionType.PLAY_TOOL, GameAction.ActionType.PLAY_STADIUM:
			_copy_string_fact(action.data, facts, "card_name")
		GameAction.ActionType.USE_ABILITY:
			_copy_string_fact(action.data, facts, "pokemon_name")
			_copy_string_fact(action.data, facts, "ability_name")
		GameAction.ActionType.ATTACH_ENERGY:
			_copy_string_fact(action.data, facts, "target")
			_copy_string_fact(action.data, facts, "source")
			_copy_string_fact(action.data, facts, "tool")
			_copy_int_fact(action.data, facts, "count")
		GameAction.ActionType.RETREAT:
			_copy_string_fact(action.data, facts, "from")
			_copy_string_fact(action.data, facts, "to")
			_copy_int_fact(action.data, facts, "energy_discarded")
		GameAction.ActionType.SEND_OUT:
			_copy_string_fact(action.data, facts, "pokemon_name")
			_copy_string_fact(action.data, facts, "replacement_pokemon_name")
		GameAction.ActionType.COIN_FLIP:
			_copy_bool_fact(action.data, facts, "result")
			_copy_string_fact(action.data, facts, "reason")
		GameAction.ActionType.STATUS_APPLIED, GameAction.ActionType.STATUS_REMOVED:
			_copy_string_fact(action.data, facts, "pokemon_name")
			_copy_string_fact(action.data, facts, "status")
		GameAction.ActionType.HEAL:
			_copy_string_fact(action.data, facts, "pokemon_name")
			_copy_int_fact(action.data, facts, "amount")
		GameAction.ActionType.GAME_END:
			_copy_string_fact(action.data, facts, "reason")
	return {
		"turn_number": maxi(0, action.turn_number),
		"player_index": action.player_index if action.player_index in [0, 1] else -1,
		"kind": kind,
		"description": _single_line(action.description, 220),
		"facts": facts,
	}


func _review_turns() -> Array[Dictionary]:
	var by_turn := {}
	var order: Array[int] = []
	for action: Dictionary in _public_actions:
		var turn := int(action.get("turn_number", 0))
		if not by_turn.has(turn):
			by_turn[turn] = []
			order.append(turn)
		var facts: Dictionary = action.get("facts", {})
		(by_turn[turn] as Array).append({
			"player_index": int(action.get("player_index", -1)),
			"kind": str(action.get("kind", "")),
			"description": str(action.get("description", "")),
			"attack_name": str(facts.get("attack_name", "")),
			"damage": int(facts.get("damage", 0)),
			"prize_count": int(facts.get("prize_count", 0)),
		})
	order.sort()
	var start_index := maxi(0, order.size() - MAX_REVIEW_TURNS)
	var result: Array[Dictionary] = []
	for index: int in range(start_index, order.size()):
		var turn := order[index]
		var actions: Array = by_turn[turn]
		var first_index := maxi(0, actions.size() - 8)
		result.append({
			"turn_number": turn,
			"key_actions": actions.slice(first_index),
			"key_choices": [],
		})
	return result


func _key_moments() -> Array[Dictionary]:
	var moments: Array[Dictionary] = []
	for action: Dictionary in _public_actions:
		var kind := str(action.get("kind", ""))
		if kind not in ["damage_dealt", "knockout", "take_prize", "game_end"]:
			continue
		moments.append({
			"turn_number": int(action.get("turn_number", 0)),
			"player_index": int(action.get("player_index", -1)),
			"kind": kind,
			"summary": str(action.get("description", "")),
		})
	var first_index := maxi(0, moments.size() - 6)
	return moments.slice(first_index)


func _critical_sequences(turns: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for turn: Dictionary in turns:
		var descriptions: Array[String] = []
		for action: Dictionary in turn.get("key_actions", []):
			var description := str(action.get("description", "")).strip_edges()
			if description != "":
				descriptions.append(description)
		result.append({
			"turn_number": int(turn.get("turn_number", 0)),
			"player_index": -1,
			"kind": "public_turn_sequence",
			"summary": descriptions[-1] if not descriptions.is_empty() else "",
			"actions": descriptions,
		})
	return result


static func _public_identity(identity: Dictionary) -> Dictionary:
	var participant: Dictionary = identity.get("strategy_participant", {})
	return {
		"source_authority": str(identity.get("source_authority", "")),
		"strategy_id": str(participant.get("strategy_id", "")),
		"release_version": str(participant.get("release_version", "")),
		"package_id": str(participant.get("package_id", "")),
		"archive_sha256": str(participant.get("archive_sha256", "")),
	}


static func _owner_audit_summary(audit: Dictionary) -> Dictionary:
	var summary := {}
	for key: String in [
		"package_id", "package_version", "archive_sha256", "policy_calls",
		"policy_successes", "policy_errors", "invalid_outputs", "same_window_fallbacks",
		"engine_commits", "engine_rejections", "last_error_code", "production_ready",
	]:
		if audit.has(key):
			summary[key] = audit.get(key)
	for key: String in ["prompt_counts", "matched_rule_counts"]:
		if audit.get(key) is Dictionary:
			summary[key] = (audit.get(key) as Dictionary).duplicate(true)
	return summary


static func _action_kind(action_type: GameAction.ActionType) -> String:
	match action_type:
		GameAction.ActionType.TURN_START: return "turn_start"
		GameAction.ActionType.TURN_END: return "turn_end"
		GameAction.ActionType.PLAY_POKEMON: return "play_pokemon"
		GameAction.ActionType.EVOLVE: return "evolve"
		GameAction.ActionType.ATTACH_ENERGY: return "attach_energy"
		GameAction.ActionType.PLAY_TRAINER: return "play_trainer"
		GameAction.ActionType.PLAY_TOOL: return "play_tool"
		GameAction.ActionType.PLAY_STADIUM: return "play_stadium"
		GameAction.ActionType.USE_STADIUM: return "use_stadium"
		GameAction.ActionType.USE_ABILITY: return "use_ability"
		GameAction.ActionType.RETREAT: return "retreat"
		GameAction.ActionType.ATTACK: return "attack"
		GameAction.ActionType.COIN_FLIP: return "coin_flip"
		GameAction.ActionType.KNOCKOUT: return "knockout"
		GameAction.ActionType.TAKE_PRIZE: return "take_prize"
		GameAction.ActionType.SEND_OUT: return "send_out"
		GameAction.ActionType.STATUS_APPLIED: return "status_applied"
		GameAction.ActionType.STATUS_REMOVED: return "status_removed"
		GameAction.ActionType.DAMAGE_DEALT: return "damage_dealt"
		GameAction.ActionType.HEAL: return "heal"
		GameAction.ActionType.GAME_END: return "game_end"
		_: return ""


static func _copy_string_fact(source: Dictionary, target: Dictionary, key: String) -> void:
	var value := _single_line(str(source.get(key, "")), 120)
	if value != "":
		target[key] = value


static func _copy_int_fact(source: Dictionary, target: Dictionary, key: String) -> void:
	if source.has(key) and typeof(source.get(key)) in [TYPE_INT, TYPE_FLOAT]:
		target[key] = int(source.get(key))


static func _copy_bool_fact(source: Dictionary, target: Dictionary, key: String) -> void:
	if source.has(key) and typeof(source.get(key)) == TYPE_BOOL:
		target[key] = bool(source.get(key))


static func _single_line(value: String, maximum: int) -> String:
	return value.replace("\r", " ").replace("\n", " ").strip_edges().left(maximum)


func _is_open() -> bool:
	return _started and not _finished and _file != null


func _close_file() -> void:
	if _file != null:
		_flush_pending()
		_file.close()
	_file = null


static func _is_safe_segment(value: String) -> bool:
	if value.is_empty() or value.length() > 96 or value != value.strip_edges():
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 95]
		):
			return false
	return true


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "path": ""}
