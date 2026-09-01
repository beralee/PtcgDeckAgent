class_name PlatformNpcRuleDecisionPort
extends RefCounted

## Data-only platform NPC policy.  Its only live input is the primitive
## competitive public frame and its only output is current-window indexes.

const PROFILE_ID := "platform-npc-rule-public-v1"
const SELECTION_SOURCE := "platform_npc_rule_public_v1"
const MAX_OPTIONS := 512

var _npc_profile_id := ""
var _release_id := ""
var _manifest_sha256 := ""
var _roles_by_uid: Dictionary = {}
var _ready := false
var _pending_observation_hash := ""
var _pending_window_id := ""
var _pending_indexes: Array[int] = []
var _calls := 0
var _successes := 0
var _rejections := 0
var _acknowledgements := 0
var _matched_rule_counts: Dictionary = {}


static func create(
	npc_profile_id: String,
	release_id: String,
	semantic_manifest: Dictionary,
	manifest_sha256: String
) -> Dictionary:
	var port := new()
	var configured := port._configure(
		npc_profile_id, release_id, semantic_manifest, manifest_sha256
	)
	if not configured:
		return {"ok": false, "error_code": "platform_npc_manifest_invalid"}
	return {"ok": true, "error_code": "", "port": port}


func _configure(
	npc_profile_id: String,
	release_id: String,
	semantic_manifest: Dictionary,
	manifest_sha256: String
) -> bool:
	if (
		npc_profile_id.is_empty()
		or not npc_profile_id.is_valid_int()
		or release_id.is_empty()
		or not _is_sha256(manifest_sha256)
		or not semantic_manifest.get("cards") is Array
	):
		return false
	var roles: Dictionary = {}
	var card_count := 0
	for value: Variant in semantic_manifest.get("cards", []):
		if not value is Dictionary:
			return false
		var card: Dictionary = value
		var uid := str(card.get("uid", ""))
		var raw_roles: Variant = card.get("roles", [])
		var count := int(card.get("count", 0))
		if uid.is_empty() or not raw_roles is Array or count <= 0:
			return false
		var normalized_roles: Array[String] = []
		for raw_role: Variant in raw_roles:
			var role := str(raw_role)
			if role.is_empty():
				return false
			normalized_roles.append(role)
		roles[uid] = normalized_roles
		card_count += count
	if card_count != 60 or roles.is_empty():
		return false
	_npc_profile_id = npc_profile_id
	_release_id = release_id
	_manifest_sha256 = manifest_sha256
	_roles_by_uid = roles
	_ready = true
	return true


func validate_integrity() -> bool:
	return (
		_ready
		and not _npc_profile_id.is_empty()
		and not _release_id.is_empty()
		and _is_sha256(_manifest_sha256)
		and not _roles_by_uid.is_empty()
	)


func get_strategy_id() -> String:
	return "platform.npc.v18.%s" % _npc_profile_id


func expected_selection_source() -> String:
	return SELECTION_SOURCE


func select(frame: Dictionary) -> Dictionary:
	_calls += 1
	var validation_error := _frame_error(frame)
	if not validation_error.is_empty():
		_rejections += 1
		return _error(validation_error, frame)
	if not _pending_window_id.is_empty():
		_rejections += 1
		return {
			"ok": false,
			"error_code": "platform_npc_previous_window_unacknowledged",
			"decision_pending": true,
		}
	var source: Dictionary = frame.get("source", {})
	var semantics: Dictionary = frame.get("select_semantics", {})
	var minimum := int(semantics.get("min_count", -1))
	var maximum := int(semantics.get("max_count", -1))
	var options: Array = frame.get("options", [])
	var scored: Array[Dictionary] = []
	for value: Variant in options:
		var option: Dictionary = value
		var evaluated := _score_option(frame, option)
		scored.append({
			"index": int(option.get("index", -1)),
			"score": int(evaluated.get("score", 0)),
			"rule_id": str(evaluated.get("rule_id", "stable_index")),
		})
	scored.sort_custom(_score_row_before)
	var selected: Array[int] = []
	var matched_rules: Array[String] = []
	for row: Dictionary in scored:
		if selected.size() >= maximum:
			break
		if selected.size() >= minimum and int(row.get("score", 0)) <= 0:
			break
		selected.append(int(row.get("index", -1)))
		matched_rules.append(str(row.get("rule_id", "stable_index")))
	if selected.size() < minimum:
		_rejections += 1
		return _error("platform_npc_cardinality_unavailable", frame)
	selected.sort()
	_pending_observation_hash = str(source.get("public_observation_hash", ""))
	_pending_window_id = str(source.get("window_id", ""))
	_pending_indexes = selected.duplicate()
	_successes += 1
	for rule_id: String in matched_rules:
		_matched_rule_counts[rule_id] = int(_matched_rule_counts.get(rule_id, 0)) + 1
	return {
		"ok": true,
		"error_code": "",
		"decision_pending": false,
		"selection_source": SELECTION_SOURCE,
		"public_observation_hash": _pending_observation_hash,
		"window_id": _pending_window_id,
		"selected_indexes": selected,
		"matched_rule_ids": matched_rules,
		"decision_audit": {
			"profile_id": PROFILE_ID,
			"npc_profile_id": _npc_profile_id,
			"release_id": _release_id,
			"manifest_sha256": _manifest_sha256,
			"input_domain": "competitive_public_frame_v2",
			"output_domain": "current_window_indexes",
		},
	}


func acknowledge_selection(frame: Dictionary, indexes: Array) -> bool:
	if _pending_window_id.is_empty() or not frame.get("source") is Dictionary:
		return false
	var source: Dictionary = frame.get("source", {})
	var normalized: Array[int] = []
	for value: Variant in indexes:
		if typeof(value) != TYPE_INT:
			return false
		normalized.append(int(value))
	var accepted := (
		str(source.get("public_observation_hash", "")) == _pending_observation_hash
		and str(source.get("window_id", "")) == _pending_window_id
		and normalized == _pending_indexes
	)
	_pending_observation_hash = ""
	_pending_window_id = ""
	_pending_indexes.clear()
	if accepted:
		_acknowledgements += 1
	else:
		_rejections += 1
	return accepted


func audit_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"npc_profile_id": _npc_profile_id,
		"strategy_id": get_strategy_id(),
		"release_id": _release_id,
		"policy_package_id": "platform-npc-rule:%s" % _npc_profile_id,
		"policy_package_version": "1",
		"policy_package_manifest_canonical_sha256": _manifest_sha256,
		"execution_location": "godot_process_local",
		"learned_model": false,
		"model_backend": "none",
		"learned_model_invoked": false,
		"network_attempts": 0,
		"calls": _calls,
		"successes": _successes,
		"rejections": _rejections,
		"acknowledgements": _acknowledgements,
		"pending_window": not _pending_window_id.is_empty(),
		"matched_rule_counts": _matched_rule_counts.duplicate(true),
	}


func _frame_error(frame: Dictionary) -> String:
	if not validate_integrity():
		return "platform_npc_policy_not_ready"
	if (
		int(frame.get("schema_version", 0)) != 2
		or str(frame.get("profile_id", "")) != "ptcgdap-competitive-public-frame-v2"
		or not frame.get("source") is Dictionary
		or not frame.get("public_state") is Dictionary
		or not frame.get("select_semantics") is Dictionary
		or not frame.get("options") is Array
	):
		return "platform_npc_public_frame_invalid"
	var source: Dictionary = frame.get("source", {})
	if (
		not _is_sha256(str(source.get("public_observation_hash", "")))
		or not _is_sha256(str(source.get("window_id", "")))
	):
		return "platform_npc_window_identity_invalid"
	var semantics: Dictionary = frame.get("select_semantics", {})
	var minimum := int(semantics.get("min_count", -1))
	var maximum := int(semantics.get("max_count", -1))
	var options: Array = frame.get("options", [])
	if minimum < 0 or maximum < minimum or maximum > options.size() \
			or options.is_empty() or options.size() > MAX_OPTIONS:
		return "platform_npc_window_cardinality_invalid"
	for index: int in options.size():
		var value: Variant = options[index]
		if not value is Dictionary or int((value as Dictionary).get("index", -1)) != index:
			return "platform_npc_option_index_invalid"
	return ""


func _score_option(frame: Dictionary, option: Dictionary) -> Dictionary:
	var prompt_kind := str(frame.get("prompt_kind", ""))
	var kind := str(option.get("kind", ""))
	var score := -int(option.get("index", 0))
	var rule_id := "stable_index"
	match kind:
		"attack", "granted_attack":
			var raw_damage: Variant = option.get("projected_damage")
			var projected_damage := int(raw_damage) if typeof(raw_damage) == TYPE_INT else 0
			score += 8000 + maxi(0, projected_damage) * 10
			rule_id = "attack_pressure"
			if bool(option.get("projected_knockout", false)):
				score += 100000
				rule_id = "projected_knockout"
		"use_ability", "use_stadium_effect":
			score += 7200
			rule_id = "ability_engine"
		"evolve":
			score += 6800
			rule_id = "evolution_piece"
		"attach_energy":
			score += 6200 + maxi(0, int(option.get("target_energy_debt", 0))) * 80
			rule_id = "energy_continuity"
		"play_basic_to_bench":
			score += 5600
			rule_id = "bench_development"
		"play_trainer", "play_stadium", "attach_tool":
			score += 4800
			rule_id = "trainer_development"
		"retreat":
			score += 1400
			rule_id = "retreat_mobility"
		"yes":
			score += 1000
			rule_id = "mandatory_yes"
		"no":
			rule_id = "optional_no"
		"end_turn":
			score -= 100000
			rule_id = "end_turn_last"
		_:
			score += 1000
			rule_id = "legal_prompt_choice"
	var role_bonus := _role_bonus(prompt_kind, kind, option)
	score += int(role_bonus.get("score", 0))
	if int(role_bonus.get("score", 0)) > 0:
		rule_id = str(role_bonus.get("rule_id", rule_id))
	if prompt_kind == "send_out":
		score += 3000 if bool(option.get("target_attack_ready", false)) else 0
		score += maxi(0, int(option.get("target_remaining_hp", 0)))
	if prompt_kind == "take_prize":
		score = 1000 - int(option.get("index", 0))
		rule_id = "stable_prize_index"
	return {"score": score, "rule_id": rule_id}


func _role_bonus(prompt_kind: String, kind: String, option: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var score := 0
	var strongest_rule := ""
	for key: String in ["card_uid", "source_uid", "target_uid"]:
		var uid := str(option.get(key, ""))
		if uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		for role: String in _roles_by_uid.get(uid, []):
			var weight := _role_weight(role, prompt_kind, kind)
			if weight > score:
				strongest_rule = "semantic_role:%s" % role
			score += weight
	return {"score": score, "rule_id": strongest_rule}


static func _role_weight(role: String, prompt_kind: String, kind: String) -> int:
	match role:
		"opening_active_candidate":
			return 12000 if prompt_kind == "setup_active" else 300
		"signature_piece":
			return 1600
		"attacker":
			return 1400 if prompt_kind in ["setup_active", "send_out"] else 500
		"energy_target":
			return 1200 if kind in ["attach_energy", "assignment_target"] else 350
		"evolution_piece", "stage2_dependency":
			return 1000 if kind in ["evolve", "play_basic_to_bench"] else 250
		"ability_engine":
			return 900
		"development_piece":
			return 700 if prompt_kind in ["setup_bench", "main"] else 150
		"gust":
			return 800
		"draw_engine", "trainer_tutor", "search_target":
			return 600
		_:
			return 0


static func _score_row_before(left: Dictionary, right: Dictionary) -> bool:
	var left_score := int(left.get("score", 0))
	var right_score := int(right.get("score", 0))
	if left_score == right_score:
		return int(left.get("index", 0)) < int(right.get("index", 0))
	return left_score > right_score


static func _error(code: String, frame: Dictionary) -> Dictionary:
	var source: Dictionary = frame.get("source", {}) if frame.get("source") is Dictionary else {}
	return {
		"ok": false,
		"error_code": code,
		"decision_pending": false,
		"selection_source": SELECTION_SOURCE,
		"public_observation_hash": str(source.get("public_observation_hash", "")),
		"window_id": str(source.get("window_id", "")),
		"selected_indexes": [],
		"matched_rule_ids": [],
	}


static func _is_sha256(value: String) -> bool:
	return value.length() == 64 and value.is_valid_hex_number(false)
