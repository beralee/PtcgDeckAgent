extends RefCounted

const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const PublicDeckAdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const MAX_SAFE_INTEGER := 9007199254740991
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _context: Variant = null
var _window: Variant = null
var _snapshot: Dictionary = {}
var _local_uid_public_context: Variant = null
var _factory_token: Variant = null
var _claimed_match_id := ""


static func create(
	context: Variant,
	window: Variant,
	prompt_id: Variant,
	prompt_generation: Variant,
	mandatory_indexes: Variant,
	terminal_indexes: Variant,
	base_hard_tiers: Variant,
	base_vetoed_indexes: Variant,
	local_uid_public_context: Variant = null,
) -> Dictionary:
	if not StrategicContextScript.validate_context(context) or window == null or not window.has_method("validate_integrity") or not window.validate_integrity():
		return _error("invalid_current_window_owner")
	if context.get("_window_binding") != window:
		return _error("invalid_current_window_owner")
	var option_count := int(window.get("option_count"))
	if not _identifier(prompt_id) or typeof(prompt_generation) != TYPE_INT or int(prompt_generation) < 1 or int(prompt_generation) > MAX_SAFE_INTEGER:
		return _error("invalid_prompt_authority")
	if not _index_list(mandatory_indexes, option_count) or not _index_list(terminal_indexes, option_count) or not _index_list(base_vetoed_indexes, option_count) or not _tiers(base_hard_tiers, option_count):
		return _error("invalid_prompt_authority")
	var snapshot := {
		"prompt_id": str(prompt_id),
		"prompt_generation": int(prompt_generation),
		"mandatory_indexes": mandatory_indexes.duplicate(true),
		"terminal_indexes": terminal_indexes.duplicate(true),
		"base_hard_tiers": base_hard_tiers.duplicate(true),
		"base_vetoed_indexes": base_vetoed_indexes.duplicate(true),
	}
	if local_uid_public_context != null and not PublicDeckAdapterScript.validate_local_uid_public_context(context, local_uid_public_context):
		return _error("invalid_local_uid_public_context")
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd")
	var prompt: Variant = script.new(context, window, snapshot, local_uid_public_context, _FACTORY_TOKEN)
	if prompt == null or not prompt.validate_integrity():
		return _error("invalid_prompt_authority")
	return {"ok": true, "error_code": "", "prompt": prompt}


func _init(context: Variant = null, window: Variant = null, snapshot: Dictionary = {}, local_uid_public_context: Variant = null, token: Variant = null) -> void:
	if token != _FACTORY_TOKEN:
		return
	_context = context
	_window = window
	_snapshot = snapshot.duplicate(true)
	_local_uid_public_context = local_uid_public_context.duplicate(true) if local_uid_public_context is Dictionary else null
	_factory_token = token


func validate_integrity() -> bool:
	if _factory_token != _FACTORY_TOKEN or not StrategicContextScript.validate_context(_context):
		return false
	if _window == null or not _window.has_method("validate_integrity") or not _window.validate_integrity() or _context.get("_window_binding") != _window:
		return false
	if not _snapshot is Dictionary or not _exact_keys(_snapshot, ["prompt_id", "prompt_generation", "mandatory_indexes", "terminal_indexes", "base_hard_tiers", "base_vetoed_indexes"]):
		return false
	if _local_uid_public_context != null and (not _local_uid_public_context is Dictionary or not PublicDeckAdapterScript.validate_local_uid_public_context(_context, _local_uid_public_context)):
		return false
	var option_count := int(_window.get("option_count"))
	return _identifier(_snapshot.get("prompt_id")) \
		and typeof(_snapshot.get("prompt_generation")) == TYPE_INT \
		and int(_snapshot.get("prompt_generation")) >= 1 \
		and int(_snapshot.get("prompt_generation")) <= MAX_SAFE_INTEGER \
		and _index_list(_snapshot.get("mandatory_indexes"), option_count) \
		and _index_list(_snapshot.get("terminal_indexes"), option_count) \
		and _index_list(_snapshot.get("base_vetoed_indexes"), option_count) \
		and _tiers(_snapshot.get("base_hard_tiers"), option_count)


func snapshot() -> Dictionary:
	return _snapshot.duplicate(true) if validate_integrity() else {}


func context_owner() -> Variant:
	return _context if validate_integrity() else null


func window_owner() -> Variant:
	return _window if validate_integrity() else null


func local_uid_public_context() -> Variant:
	return _local_uid_public_context.duplicate(true) if validate_integrity() and _local_uid_public_context is Dictionary else null


func claim_for_match(match_id: String) -> Dictionary:
	if not validate_integrity():
		return _error("invalid_prompt_authority")
	if not _claimed_match_id.is_empty():
		return _error("prompt_already_consumed")
	_claimed_match_id = match_id
	return {"ok": true, "error_code": ""}


static func _index_list(value: Variant, option_count: int) -> bool:
	if not value is Array:
		return false
	var seen := {}
	for index in value:
		if typeof(index) != TYPE_INT or int(index) < 0 or int(index) >= option_count or seen.has(index):
			return false
		seen[index] = true
	return true


static func _tiers(value: Variant, option_count: int) -> bool:
	if not value is Array or value.size() != option_count:
		return false
	var seen := {}
	for entry_value in value:
		if not entry_value is Dictionary:
			return false
		var entry: Dictionary = entry_value
		if not _exact_keys(entry, ["index", "tier"]):
			return false
		var index: Variant = entry.get("index")
		var tier: Variant = entry.get("tier")
		if typeof(index) != TYPE_INT or int(index) < 0 or int(index) >= option_count or seen.has(index) or not tier is Array or tier.is_empty() or tier.size() > 8:
			return false
		for child in tier:
			if typeof(child) != TYPE_INT or int(child) < 0 or int(child) > MAX_SAFE_INTEGER:
				return false
		seen[index] = true
	return seen.size() == option_count


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128:
		return false
	for index in range(str(value).length()):
		var character := str(value).substr(index, 1)
		var code := character.unicode_at(0)
		var alphanumeric := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if (index == 0 and not alphanumeric) or (index > 0 and not alphanumeric and character not in [".", "_", "-"]):
			return false
	return true


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "prompt": null}
