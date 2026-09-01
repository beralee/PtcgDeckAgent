extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const MAX_OPTIONS := 1024
const FRAME_WIDTH := 24
const OPTION_WIDTH := 16
const OPTION_FIELDS := ["type", "number", "area", "index", "playerIndex", "toolIndex", "energyIndex", "count", "inPlayArea", "inPlayIndex", "attackId", "cardId", "serial", "specialConditionType"]
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
const CLOCK_FIELDS := ["turn", "turn_action_count", "remaining_overage_time", "acting_prizes_remaining", "opponent_prizes_remaining", "acting_deck_count", "opponent_deck_count", "acting_hand_count", "opponent_hand_count"]
const FLAG_FIELDS := ["first_player", "result", "supporter_played", "stadium_played", "energy_attached", "retreated"]
const FORBIDDEN_KEYS := ["private_state", "raw_private_hash", "token_free_callback_hash", "search_begin_input", "session", "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial", "credentials", "deck_order", "face_down_prizes", "rng"]

var _policy_mode := "rules_only"
var _native: Variant = null
var _load_error := ""
var _allowed_uids := {}
var _model_manifest_sha256: Variant = null
var _model_artifact_sha256: Variant = null


static func create(handle: Variant) -> Dictionary:
	if handle == null or not handle.has_method("model_payloads"):
		return {"ok": false, "error_code": "package_model_relation_invalid"}
	var payloads: Dictionary = handle.model_payloads()
	if not bool(payloads.get("ok", false)):
		return payloads
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd")
	var owner: RefCounted = script.new()
	owner._policy_mode = str(payloads.get("policy_mode", "rules_only"))
	owner._model_manifest_sha256 = payloads.get("model_manifest_sha256")
	owner._model_artifact_sha256 = payloads.get("model_artifact_sha256")
	for row: Variant in handle.local_deck_snapshot():
		if row is Dictionary and typeof(row.get("local_card_uid")) == TYPE_STRING:
			owner._allowed_uids[str(row.get("local_card_uid"))] = true
	if owner._policy_mode == "rules_with_model":
		if not ClassDB.class_exists("PtcgOrtActor"):
			owner._load_error = "model_runtime_unavailable"
		else:
			owner._native = ClassDB.instantiate("PtcgOrtActor")
			var loaded: Variant = owner._native.load_actor(payloads.get("actor_ort", PackedByteArray()))
			if not loaded is Dictionary or not bool(loaded.get("ok", false)):
				owner._load_error = str(loaded.get("error_code", "model_unavailable")) if loaded is Dictionary else "model_unavailable"
	return {"ok": true, "error_code": "", "owner": owner}


func decide(context: Variant, local_context: Variant, prompt: Dictionary, rule_indexes: Array) -> Dictionary:
	if _policy_mode != "rules_with_model":
		return _fallback(rule_indexes, "", false)
	if not _load_error.is_empty() or _native == null:
		return _fallback(rule_indexes, _load_error if not _load_error.is_empty() else "model_unavailable", false)
	if not prompt.get("mandatory_indexes", []).is_empty():
		return _fallback(rule_indexes, "model_bypassed_mandatory", false)
	if not prompt.get("terminal_indexes", []).is_empty():
		return _fallback(rule_indexes, "model_bypassed_terminal", false)
	if rule_indexes.is_empty():
		return _fallback(rule_indexes, "model_bypassed_empty_rule_result", false)
	var tensorized := _tensorize(context, local_context)
	if not bool(tensorized.get("ok", false)):
		return _fallback(rule_indexes, str(tensorized.get("error_code", "model_public_frame_invalid")), false)
	var runtime: Variant = _native.run(
		tensorized.get("frame_i32"),
		tensorized.get("frame_presence_i32"),
		tensorized.get("option_i32"),
		tensorized.get("option_presence_i32"),
		tensorized.get("option_mask_i32")
	)
	if not runtime is Dictionary or not bool(runtime.get("ok", false)):
		return _fallback(rule_indexes, str(runtime.get("error_code", "model_inference_failed")) if runtime is Dictionary else "model_inference_failed", false)
	var scores: Variant = runtime.get("option_scores")
	var desired: Variant = runtime.get("desired_count")
	if not scores is PackedInt32Array or scores.size() != MAX_OPTIONS or typeof(desired) != TYPE_INT:
		return _fallback(rule_indexes, "model_output_shape_invalid", false)
	var min_count := int(tensorized.get("min_count"))
	var max_count := int(tensorized.get("max_count"))
	if int(desired) < min_count or int(desired) > max_count:
		return _fallback(rule_indexes, "model_desired_count_invalid", false)
	var tier_by_index := {}
	for entry: Variant in prompt.get("base_hard_tiers", []):
		if not entry is Dictionary or not _exact_keys(entry, ["index", "tier"]):
			return _fallback(rule_indexes, "model_authority_input_invalid", false)
		tier_by_index[int(entry.get("index"))] = entry.get("tier", []).duplicate(true)
	if tier_by_index.size() != int(tensorized.get("option_count")) or not tier_by_index.has(int(rule_indexes[0])):
		return _fallback(rule_indexes, "model_authority_input_invalid", false)
	var rule_tier: Array = tier_by_index[int(rule_indexes[0])]
	for index: Variant in rule_indexes:
		if not tier_by_index.has(int(index)) or tier_by_index[int(index)] != rule_tier:
			return _fallback(rule_indexes, "model_authority_input_invalid", false)
	var vetoed := {}
	for index: Variant in prompt.get("base_vetoed_indexes", []): vetoed[int(index)] = true
	var ranked: Array = []
	var row_to_index: Array = tensorized.get("row_to_current_index")
	var semantic_keys: Array = tensorized.get("semantic_keys")
	for row in range(row_to_index.size()):
		var current_index := int(row_to_index[row])
		if not vetoed.has(current_index) and tier_by_index.get(current_index) == rule_tier:
			ranked.append({"index":current_index, "score":int(scores[row]), "semantic_key":str(semantic_keys[row])})
	if int(desired) > ranked.size():
		return _fallback(rule_indexes, "model_desired_count_invalid", false)
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["score"] != right["score"]: return left["score"] > right["score"]
		if left["semantic_key"] != right["semantic_key"]: return left["semantic_key"] < right["semantic_key"]
		return left["index"] < right["index"]
	)
	var selected: Array = []
	for row in ranked.slice(0, int(desired)): selected.append(int(row["index"]))
	return {
		"selected_indexes": selected,
		"model_used": true,
		"diagnostic_code": "",
		"elapsed_us": runtime.get("elapsed_us", 0),
		"model_manifest_sha256": _model_manifest_sha256,
		"model_artifact_sha256": _model_artifact_sha256,
	}


func decide_development_frame(
	frame: Dictionary,
	rule_indexes: Array,
	eligible_indexes: Array = [],
) -> Dictionary:
	# The full battle owner already ran legality, mandatory/terminal handling,
	# Competitive IR, hard guards and vetoes. Its returned indexes are therefore
	# the only same-tier tie-break frontier exposed to this compatibility seam.
	if _policy_mode != "rules_with_model":
		return _fallback(rule_indexes, "", false)
	if not _load_error.is_empty() or _native == null:
		return _fallback(
			rule_indexes,
			_load_error if not _load_error.is_empty() else "model_unavailable",
			false
		)
	if rule_indexes.is_empty():
		return _fallback(rule_indexes, "model_bypassed_empty_rule_result", false)
	var model_frontier: Array = eligible_indexes if not eligible_indexes.is_empty() else rule_indexes
	if str(frame.get("prompt_kind", "")) in [
		"starting_player_choice", "mulligan_draw_count", "setup_active",
		"setup_bench", "take_prize", "send_out",
	]:
		return _fallback(rule_indexes, "model_bypassed_mandatory", false)
	var tensorized := _tensorize_development_frame(frame)
	if not bool(tensorized.get("ok", false)):
		return _fallback(
			rule_indexes,
			str(tensorized.get("error_code", "model_public_frame_invalid")),
			false
		)
	var runtime: Variant = _native.run(
		tensorized.get("frame_i32"),
		tensorized.get("frame_presence_i32"),
		tensorized.get("option_i32"),
		tensorized.get("option_presence_i32"),
		tensorized.get("option_mask_i32")
	)
	if not runtime is Dictionary or not bool(runtime.get("ok", false)):
		return _fallback(
			rule_indexes,
			str(runtime.get("error_code", "model_inference_failed")) \
				if runtime is Dictionary else "model_inference_failed",
			false
		)
	var scores: Variant = runtime.get("option_scores")
	var desired: Variant = runtime.get("desired_count")
	if not scores is PackedInt32Array or scores.size() != MAX_OPTIONS or typeof(desired) != TYPE_INT:
		return _fallback(rule_indexes, "model_output_shape_invalid", false)
	var semantics: Dictionary = frame.get("select_semantics", {}) \
		if frame.get("select_semantics") is Dictionary else {}
	var min_count := int(semantics.get("min_count", -1))
	var max_count := int(semantics.get("max_count", -1))
	if (
		int(desired) < min_count
		or int(desired) > max_count
		or int(desired) > model_frontier.size()
	):
		return _fallback(rule_indexes, "model_desired_count_invalid", false)
	var row_by_index: Dictionary = tensorized.get("current_index_to_row", {})
	var semantic_keys: Array = tensorized.get("semantic_keys", [])
	var ranked: Array = []
	for index_value: Variant in model_frontier:
		var index := int(index_value)
		if not row_by_index.has(index):
			return _fallback(rule_indexes, "model_authority_input_invalid", false)
		var row := int(row_by_index[index])
		ranked.append({
			"index": index,
			"score": int(scores[row]),
			"semantic_key": str(semantic_keys[row]),
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["score"] != right["score"]: return left["score"] > right["score"]
		if left["semantic_key"] != right["semantic_key"]: return left["semantic_key"] < right["semantic_key"]
		return left["index"] < right["index"]
	)
	var selected: Array = []
	for row: Dictionary in ranked.slice(0, int(desired)):
		selected.append(int(row["index"]))
	return {
		"selected_indexes": selected,
		"model_used": true,
		"diagnostic_code": "",
		"elapsed_us": runtime.get("elapsed_us", 0),
		"model_manifest_sha256": _model_manifest_sha256,
		"model_artifact_sha256": _model_artifact_sha256,
	}


func _tensorize_development_frame(frame: Dictionary) -> Dictionary:
	if _contains_forbidden(frame):
		return _error("model_hidden_field")
	var state: Variant = frame.get("public_state")
	var semantics: Variant = frame.get("select_semantics")
	var options: Variant = frame.get("options")
	if not state is Dictionary or not semantics is Dictionary or not options is Array:
		return _error("model_public_frame_invalid")
	if options.size() > MAX_OPTIONS or not state.get("self") is Dictionary \
		or not state.get("opponent") is Dictionary:
		return _error("model_public_frame_invalid")
	var own: Dictionary = state.get("self")
	var opponent: Dictionary = state.get("opponent")
	var own_turn: Dictionary = own.get("turn", {}) if own.get("turn") is Dictionary else {}
	var frame_values := PackedInt32Array()
	var frame_presence := PackedInt32Array()
	for value: Variant in [
		state.get("turn_number"), frame.get("sequence"), null,
		own.get("prizes_remaining"), opponent.get("prizes_remaining"),
		own.get("deck_count"), opponent.get("deck_count"),
		own.get("hand", []).size() if own.get("hand") is Array else null,
		opponent.get("hand_count"),
		null, null,
		not bool(own_turn.get("supporter_available", true)), null,
		not bool(own_turn.get("manual_attachment_available", true)),
		not bool(own_turn.get("retreat_available", true)),
		semantics.get("select_type_raw"), semantics.get("select_context_raw"),
		semantics.get("min_count"), semantics.get("max_count"),
		semantics.get("remain_damage_counter"), semantics.get("remain_energy_cost"),
		options.size(), null, null,
	]:
		if not _append_i32(frame_values, frame_presence, value):
			return _error("model_feature_range_invalid")
	if frame_values.size() != FRAME_WIDTH:
		return _error("model_tensor_profile_invalid")
	var rows: Array = []
	for current_index: int in options.size():
		var option_value: Variant = options[current_index]
		if not option_value is Dictionary or option_value.get("index") != current_index:
			return _error("model_unknown_option_shape")
		var option: Dictionary = option_value
		var option_type: Variant = option.get("option_type_raw")
		if typeof(option_type) != TYPE_INT or int(option_type) < 0 or int(option_type) > 16:
			return _error("model_unknown_option_shape")
		var uid: Variant = option.get("target_uid") \
			if str(option.get("kind", "")) == "evolve" else option.get("card_uid")
		if uid == null:
			uid = option.get("source_uid")
		if uid != null and (typeof(uid) != TYPE_STRING or not _allowed_uids.has(str(uid))):
			return _error("model_unknown_uid")
		var values := PackedInt32Array()
		var presence := PackedInt32Array()
		var stable_serial: Variant = option.get("card_serial")
		if stable_serial == null: stable_serial = option.get("target_serial")
		if stable_serial == null: stable_serial = option.get("source_serial")
		var feature_values: Array = [
			option_type,
			option.get("option_number"),
			option.get("option_area_raw"),
			stable_serial,
			null,
			option.get("energy_type_raw"),
			option.get("energy_count"),
			option.get("pending_assignment_count"),
			null, null,
			option.get("attack_index"),
			_uid_feature(str(uid)) if uid != null else null,
			stable_serial,
			option.get("special_condition_type"),
			_uid_feature(str(uid)) if uid != null else null,
			null,
		]
		for value: Variant in feature_values:
			if not _append_i32(values, presence, value):
				return _error("model_feature_range_invalid")
		var semantic_option := option.duplicate(true)
		semantic_option.erase("index")
		var semantic_key := _semantic_key(semantic_option, uid)
		if semantic_key.is_empty():
			return _error("model_public_frame_invalid")
		rows.append({
			"values": values,
			"presence": presence,
			"semantic_key": semantic_key,
			"current_index": current_index,
			"sort_key": _row_sort_key(values, presence, semantic_key),
		})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["sort_key"] != right["sort_key"]: return left["sort_key"] < right["sort_key"]
		return left["current_index"] < right["current_index"]
	)
	var option_values := PackedInt32Array()
	var option_presence := PackedInt32Array()
	var mask := PackedInt32Array()
	var row_to_index: Array = []
	var semantic_keys: Array = []
	var index_to_row := {}
	for row_index: int in rows.size():
		var row: Dictionary = rows[row_index]
		option_values.append_array(row["values"])
		option_presence.append_array(row["presence"])
		mask.append(1)
		row_to_index.append(row["current_index"])
		semantic_keys.append(row["semantic_key"])
		index_to_row[row["current_index"]] = row_index
	while mask.size() < MAX_OPTIONS:
		for _field: int in OPTION_WIDTH:
			option_values.append(0)
			option_presence.append(0)
		mask.append(0)
	return {
		"ok": true,
		"error_code": "",
		"frame_i32": frame_values,
		"frame_presence_i32": frame_presence,
		"option_i32": option_values,
		"option_presence_i32": option_presence,
		"option_mask_i32": mask,
		"row_to_current_index": row_to_index,
		"current_index_to_row": index_to_row,
		"semantic_keys": semantic_keys,
	}


func _tensorize(context: Variant, local_context: Variant) -> Dictionary:
	if context == null or not context.has_method("to_public_dict"):
		return _error("model_public_frame_invalid")
	var public: Variant = context.to_public_dict()
	if not public is Dictionary or _contains_forbidden(public):
		return _error("model_hidden_field")
	var clocks: Variant = public.get("clocks")
	var state: Variant = public.get("public_state")
	var semantics: Variant = public.get("select_semantics")
	if not clocks is Dictionary or not state is Dictionary or not state.get("turn_flags") is Dictionary or not semantics is Dictionary or not semantics.get("options") is Array:
		return _error("model_public_frame_invalid")
	var options: Array = semantics.get("options")
	if options.size() > MAX_OPTIONS:
		return _error("model_public_frame_invalid")
	var frame := PackedInt32Array()
	var frame_presence := PackedInt32Array()
	for key in CLOCK_FIELDS:
		if not clocks.has(key) or not _append_i32(frame, frame_presence, clocks[key]): return _error("model_public_frame_invalid")
	for key in FLAG_FIELDS:
		if not state.get("turn_flags").has(key) or not _append_i32(frame, frame_presence, state.get("turn_flags")[key]): return _error("model_public_frame_invalid")
	for key in ["select_type_raw", "select_context_raw", "min_count", "max_count", "remain_damage_counter", "remain_energy_cost"]:
		if not semantics.has(key) or not _append_i32(frame, frame_presence, semantics[key]): return _error("model_public_frame_invalid")
	frame.append(options.size()); frame_presence.append(1)
	while frame.size() < FRAME_WIDTH: frame.append(0); frame_presence.append(0)
	var uid_by_index := {}
	if local_context is Dictionary:
		for entry: Variant in local_context.get("options", []):
			if not entry is Dictionary or typeof(entry.get("index")) != TYPE_INT: return _error("model_unknown_uid")
			var uid: Variant = entry.get("local_card_uid")
			if uid != null and (typeof(uid) != TYPE_STRING or not _allowed_uids.has(str(uid))): return _error("model_unknown_uid")
			uid_by_index[int(entry.get("index"))] = uid
	var rows: Array = []
	for current_index in range(options.size()):
		var wrapper: Variant = options[current_index]
		if not wrapper is Dictionary or not _exact_keys(wrapper, ["index", "fingerprint", "raw"]) or wrapper.get("index") != current_index or not wrapper.get("raw") is Dictionary:
			return _error("model_unknown_option_shape")
		var raw: Dictionary = wrapper.get("raw")
		if typeof(raw.get("type")) != TYPE_INT or not OPTION_SHAPES.has(int(raw.get("type"))) or not _exact_keys(raw, OPTION_SHAPES[int(raw.get("type"))]):
			return _error("model_unknown_option_shape")
		var values := PackedInt32Array(); var presence := PackedInt32Array()
		for field in OPTION_FIELDS:
			if raw.has(field):
				if not _append_i32(values, presence, raw[field]): return _error("model_feature_range_invalid")
				if field == "cardId" and presence[presence.size() - 1] == 1 and values[values.size() - 1] <= 0: return _error("model_unknown_uid")
			else: values.append(0); presence.append(0)
		var uid: Variant = uid_by_index.get(current_index)
		if uid != null: values.append(_uid_feature(str(uid))); presence.append(1)
		else: values.append(0); presence.append(0)
		values.append(0); presence.append(0)
		var semantic_key := _semantic_key(raw, uid)
		if semantic_key.is_empty(): return _error("model_public_frame_invalid")
		rows.append({"values":values, "presence":presence, "semantic_key":semantic_key, "current_index":current_index, "sort_key":_row_sort_key(values, presence, semantic_key)})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["sort_key"] != right["sort_key"]: return left["sort_key"] < right["sort_key"]
		return left["current_index"] < right["current_index"]
	)
	var option_values := PackedInt32Array(); var option_presence := PackedInt32Array(); var mask := PackedInt32Array()
	var row_to_index: Array = []; var semantic_keys: Array = []
	for row: Dictionary in rows:
		option_values.append_array(row["values"]); option_presence.append_array(row["presence"]); mask.append(1)
		row_to_index.append(row["current_index"]); semantic_keys.append(row["semantic_key"])
	while mask.size() < MAX_OPTIONS:
		for _field in range(OPTION_WIDTH): option_values.append(0); option_presence.append(0)
		mask.append(0)
	return {"ok":true, "error_code":"", "frame_i32":frame, "frame_presence_i32":frame_presence, "option_i32":option_values, "option_presence_i32":option_presence, "option_mask_i32":mask, "row_to_current_index":row_to_index, "semantic_keys":semantic_keys, "option_count":options.size(), "min_count":int(semantics.get("min_count")), "max_count":int(semantics.get("max_count"))}


static func _append_i32(values: PackedInt32Array, presence: PackedInt32Array, value: Variant) -> bool:
	if value == null: values.append(0); presence.append(0); return true
	if typeof(value) == TYPE_BOOL: values.append(1 if value else 0); presence.append(1); return true
	if typeof(value) != TYPE_INT or int(value) < -2147483648 or int(value) > 2147483647: return false
	values.append(int(value)); presence.append(1); return true


static func _semantic_key(raw: Dictionary, uid: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(JSON.stringify({"local_card_uid":uid, "option":raw}).to_utf8_buffer())
	if not bool(canonical.get("ok", false)): return ""
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update("PTCGDAP\u0000MODEL_OPTION_V1\u0000".to_utf8_buffer()); context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _uid_feature(uid: String) -> int:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update("PTCGDAP\u0000MODEL_UID_V1\u0000".to_utf8_buffer()); context.update(uid.to_ascii_buffer())
	var bytes := context.finish()
	var value := (int(bytes[0]) << 24) | (int(bytes[1]) << 16) | (int(bytes[2]) << 8) | int(bytes[3])
	return value - 4294967296 if value >= 2147483648 else value


static func _row_sort_key(values: PackedInt32Array, presence: PackedInt32Array, semantic_key: String) -> String:
	return "%s|%s|%s" % [Array(values), Array(presence), semantic_key]


static func _contains_forbidden(root: Variant) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key: Variant in current:
				var folded := str(key).to_lower()
				if folded in FORBIDDEN_KEYS or folded.contains("private") or folded.contains("hidden"): return true
				stack.append(current[key])
		elif current is Array: stack.append_array(current)
	return false


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true


func _fallback(indexes: Array, code: String, used: bool) -> Dictionary:
	return {"selected_indexes":indexes.duplicate(), "model_used":used, "diagnostic_code":code, "elapsed_us":0, "model_manifest_sha256":_model_manifest_sha256, "model_artifact_sha256":_model_artifact_sha256}


static func _error(code: String) -> Dictionary:
	return {"ok":false, "error_code":code}
