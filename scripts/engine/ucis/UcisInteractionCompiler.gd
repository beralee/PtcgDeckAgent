class_name UcisInteractionCompiler
extends RefCounted

const REGISTRY_PATH := "res://contracts/ptcgdap/ucis_registry_v1.json"
const META_KEY := "__ucis"
const GENERATION := 1

static var _registry_cache: Dictionary = {}
static var _registry_error := ""


## Build/load-time source census for CardEffectSpec registration.  Inherited
## BaseEffect methods are deliberately excluded: only functions declared by
## the concrete script are effect capabilities.
static func builder_entrypoints_for_source(source: String) -> Array[String]:
	var matcher := RegEx.new()
	if matcher.compile("(?m)^\\s*func\\s+(build_ucis_[A-Za-z0-9_]+_spec_steps)\\s*\\(") != OK:
		return []
	var result: Array[String] = []
	for match_value: RegExMatch in matcher.search_all(source):
		var method_name := match_value.get_string(1)
		if not method_name.is_empty() and method_name not in result:
			result.append(method_name)
	result.sort()
	return result


## Conservative, source-grounded capability closure.  This runs once while an
## effect catalog is loaded; the live decision path uses only the cached
## registry and the current step.  A runtime step is still validated against
## the registry before it can become a window.
static func declared_capabilities_for_source(
	source: String,
	builder_entrypoints: Array[String]
) -> Array[String]:
	if builder_entrypoints.is_empty():
		return []
	var declared: Array[String] = []
	var normalized := source.to_lower()
	for entrypoint: String in builder_entrypoints:
		if "attack" in entrypoint:
			_add_capability(declared, "AttackAndTarget")
			_add_capability(declared, "ChooseAttack")
		elif "knockout" in entrypoint or "end_turn" in entrypoint:
			_add_capability(declared, "ResolveKnockout")
		else:
			_add_capability(declared, "ChooseCardSet")
	if "card_assignment" in normalized or "source_items" in normalized \
		or "target_items" in normalized or "total_counters" in normalized \
		or "counter_distribution" in normalized:
		_add_capability(declared, "AssignOrDistribute")
	if "full_library" in normalized or "visible_scope" in normalized \
		or "search_" in normalized or "player.deck" in normalized:
		_add_capability(declared, "SearchAndMove")
	if "attached_energy" in normalized or "attached_tools" in normalized \
		or "attached_card" in normalized:
		_add_capability(declared, "ChooseAttachedCardSet")
	if "energy_units" in normalized or "remain_energy_cost" in normalized:
		_add_capability(declared, "ChooseEnergyUnits")
	if "number_option" in normalized or "draw_count" in normalized \
		or "damage_counter_count" in normalized:
		_add_capability(declared, "ChooseNumber")
	if "special_condition" in normalized:
		_add_capability(declared, "ChooseSpecialCondition")
	if "evolv" in normalized or "devolve" in normalized:
		_add_capability(declared, "ChooseEvolution")
	if "switch" in normalized or "retreat" in normalized or "to_active" in normalized:
		_add_capability(declared, "RetreatOrSwitch")
	if "discard" in normalized or "detach" in normalized or "pay_cost" in normalized:
		_add_capability(declared, "PayCost")
	if "ability" in normalized or "activate" in normalized or "on_play" in normalized:
		_add_capability(declared, "ActivateOrPlay")
	if "skill_order" in normalized or "ordered_selection" in normalized:
		_add_capability(declared, "ChooseSkillOrder")
	if "yes" in normalized and "no" in normalized:
		_add_capability(declared, "ChooseBoolean")
	declared.sort()
	return declared


static func declared_program_templates(
	effect_ref: String,
	source_hash: String,
	builder_entrypoints: Array[String],
	capability_ids: Array[String]
) -> Array[Dictionary]:
	var programs: Array[Dictionary] = []
	for entrypoint: String in builder_entrypoints:
		programs.append({
			"program_id": "%s#%s" % [effect_ref, entrypoint],
			"program_kind": "current_legality_program",
			"capability_ids": capability_ids.duplicate(),
			"lifecycle_anchor": entrypoint,
			"chooser_rule": "engine_current_chooser",
			"visibility_rule": "acting_seat_public_only",
			"continuation_rule": "ordered_steps_fresh_reobserve",
			"stop_rule": "program_complete",
			"information_checkpoints": ["fresh_reobserve"],
			"step_recipe_owner": "UcisInteractionCompiler",
			"source_hash": source_hash,
		})
	return programs


static func compile_steps(raw_steps: Array, entrypoint: String, source_effect: Object) -> Dictionary:
	var registry := _registry()
	if registry.is_empty():
		return _error(_registry_error if not _registry_error.is_empty() else "ucis_registry_unavailable")
	if entrypoint.strip_edges().is_empty() or source_effect == null:
		return _error("ucis_compile_source_invalid")
	var compiled: Array[Dictionary] = []
	var step_ids: Dictionary = {}
	for index: int in raw_steps.size():
		var raw: Variant = raw_steps[index]
		if not raw is Dictionary:
			return _error("ucis_step_document_invalid", index)
		var step: Dictionary = (raw as Dictionary).duplicate(true)
		var existing: Variant = step.get(META_KEY)
		if existing is Dictionary and int((existing as Dictionary).get("ucis_generation", -1)) == GENERATION:
			var existing_validation := _validate_metadata(existing as Dictionary, registry)
			if not bool(existing_validation.get("ok", false)):
				return _error(str(existing_validation.get("error_code", "ucis_step_metadata_invalid")), index)
			compiled.append(step)
			continue
		var step_id := str(step.get("id", "")).strip_edges()
		if step_id.is_empty():
			step_id = "%s:%d" % [entrypoint, index]
			step["id"] = step_id
		if step_ids.has(step_id):
			return _error("ucis_duplicate_step_id", index)
		step_ids[step_id] = true
		var metadata := _compile_step(step, entrypoint, step_id, registry)
		if not bool(metadata.get("ok", false)):
			return _error(str(metadata.get("error_code", "unsupported_interaction_shape")), index)
		metadata.erase("ok")
		metadata.erase("error_code")
		step[META_KEY] = metadata
		compiled.append(step)
	var ordered_steps: Array[Dictionary] = []
	var effect_steps: Array[Dictionary] = []
	for compiled_step: Dictionary in compiled:
		var metadata := metadata_for_step(compiled_step)
		ordered_steps.append(_contract_step(metadata, false))
		effect_steps.append(_effect_step(metadata, registry, false))
		if metadata.get("target_semantics") is Dictionary:
			ordered_steps.append(_contract_step(metadata, true))
			effect_steps.append(_effect_step(metadata, registry, true))
	var descriptor: Dictionary = source_effect.call("get_ucis_effect_spec") \
		if source_effect.has_method("get_ucis_effect_spec") else {}
	var source_hash := str(descriptor.get("source_hash", ""))
	if source_hash.is_empty():
		source_hash = _sha256_json({"effect_ref": _effect_ref(source_effect)})
	var capabilities := _capabilities(compiled)
	var program_kind := str(ordered_steps[0].get("primitive", "")) \
		if not ordered_steps.is_empty() else "automatic_resolution"
	var effect_ref := _effect_ref(source_effect)
	var program := {
		"program_kind": program_kind,
		"capability_ids": capabilities,
		"source_effect_ref": effect_ref,
		"chooser_rule": "engine_current_chooser",
		"visibility_rule": "acting_seat_public_only",
		"lifecycle_anchor": entrypoint,
		"ordered_steps": ordered_steps,
		"continuation_rule": "ordered_steps_fresh_reobserve",
		"stop_rule": "program_complete",
		"information_checkpoints": ["fresh_reobserve"],
		"contract_generation": int(registry.get("contract_generation", -1)),
		"compiler_generation": GENERATION,
		"source_hash": source_hash,
		"status": "compiled",
		"unsupported_reason": "",
	}
	program["program_hash"] = _sha256_json(program)
	return {
		"ok": true,
		"error_code": "",
		"steps": compiled,
		"effect_spec": {
			"schema_version": 1,
			"effect_ref": effect_ref,
			"resolution_kind": "interactive",
			"program_kind": program_kind,
			"capability_ids": capabilities,
			"steps": effect_steps,
			"chooser_rule": "engine_current_chooser",
			"visibility_rule": "acting_seat_public_only",
			"lifecycle_anchor": entrypoint,
			"continuation_rule": "ordered_steps_fresh_reobserve",
			"stop_rule": "program_complete",
			"information_checkpoints": ["fresh_reobserve"],
			"source_hash": source_hash,
			"unsupported_reason": "",
		},
		"program": program,
	}


static func _contract_step(metadata: Dictionary, for_target: bool) -> Dictionary:
	var semantics: Dictionary = metadata.get("target_semantics", {}) if for_target else metadata
	return {
		"step_id": "%s:target" % str(metadata.get("step_id", "")) \
			if for_target else str(metadata.get("step_id", "")),
		"primitive": "AssignOrDistribute" if for_target else str(metadata.get("primitive", "")),
		"select_type_raw": int(semantics.get("select_type_raw", -1)),
		"context_raw": int(semantics.get("context_raw", -1)),
		"option_type_raw": int(semantics.get("option_type_raw", -1)),
		"source_zone_query": "current_public_targets" if for_target else str(metadata.get("source_zone_query", "")),
		"candidate_predicate": "engine_legal_current_candidates",
		"target_predicate": "engine_legal_current_targets",
		"quantity_encoding": "result_list_length" if for_target else str(metadata.get("quantity_encoding", "")),
		"min_rule": "current_min_count",
		"max_rule": "current_max_count",
		"remaining_debt_rule": "current_remaining_debt",
		"public_context_projection": "ucis_public_facts_v1",
		"private_binding_recipe": "current_option_private_binding",
		"commit_command_kind": "commit_current_selection",
		"next_checkpoint_rule": "fresh_reobserve",
		"unsupported_if": metadata.get("unsupported_if", []).duplicate(),
		"capability_ids": ["AssignOrDistribute"] if for_target else metadata.get("capability_ids", []).duplicate(),
	}


static func _effect_step(metadata: Dictionary, registry: Dictionary, for_target: bool) -> Dictionary:
	var compiled := _contract_step(metadata, for_target)
	var row: Dictionary = (registry.get("_context_index", {}) as Dictionary).get(
		int(compiled.context_raw), {}
	)
	var option_values: Array = row.get("option_type_raw", [])
	var option_names: Array = row.get("option_type_names", [])
	var option_index := option_values.find(int(compiled.option_type_raw))
	return {
		"step_id": compiled.step_id,
		"primitive": compiled.primitive,
		"context_name": str(row.get("context_name", "")),
		"option_type_name": str(option_names[option_index]) if option_index >= 0 else "",
		"source_zone_query": compiled.source_zone_query,
		"candidate_predicate": compiled.candidate_predicate,
		"target_predicate": compiled.target_predicate,
		"quantity_encoding": compiled.quantity_encoding,
		"min_rule": compiled.min_rule,
		"max_rule": compiled.max_rule,
		"remaining_debt_rule": compiled.remaining_debt_rule,
		"public_context_projection": compiled.public_context_projection,
		"private_binding_recipe": compiled.private_binding_recipe,
		"commit_command_kind": compiled.commit_command_kind,
		"next_checkpoint_rule": compiled.next_checkpoint_rule,
		"unsupported_if": compiled.unsupported_if,
		"capability_ids": compiled.capability_ids,
	}


static func metadata_for_step(step: Dictionary) -> Dictionary:
	var metadata: Variant = step.get(META_KEY)
	if not metadata is Dictionary:
		return {}
	var registry := _registry()
	if registry.is_empty() or not bool(_validate_metadata(metadata as Dictionary, registry).get("ok", false)):
		return {}
	return (metadata as Dictionary).duplicate(true)


static func clear_cache_for_tests() -> void:
	_registry_cache.clear()
	_registry_error = ""


static func _compile_step(step: Dictionary, entrypoint: String, step_id: String, registry: Dictionary) -> Dictionary:
	for forbidden_key: String in ["window_id", "window_handle", "option_index", "option_indexes", "engine_ticket", "callback"]:
		if step.has(forbidden_key):
			return _error("ucis_card_step_authority_forbidden")
	var semantics := _explicit_semantics(step, registry)
	if step.has("ucis_context_name") and semantics.is_empty():
		return _error("ucis_unknown_context")
	if semantics.is_empty():
		semantics = _infer_semantics(step, entrypoint)
	if semantics.is_empty():
		return _error("unsupported_interaction_shape")
	var context_raw := int(semantics.get("context_raw", -1))
	var rows: Dictionary = registry.get("_context_index", {})
	if not rows.has(context_raw):
		return _error("ucis_unknown_context")
	var row: Dictionary = rows[context_raw]
	var select_type_raw := int(semantics.get("select_type_raw", -1))
	if select_type_raw != int(row.get("select_type_raw", -2)):
		return _error("ucis_context_select_type_mismatch")
	var option_type_raw := int(semantics.get("option_type_raw", -1))
	if option_type_raw not in row.get("option_type_raw", []):
		return _error("ucis_context_option_mismatch")
	var primitive := _primitive_for_step(step, context_raw, entrypoint)
	var primitives: Dictionary = registry.get("_primitive_index", {})
	if not primitives.has(primitive):
		return _error("ucis_unknown_primitive")
	var primitive_row: Dictionary = primitives[primitive]
	if context_raw not in primitive_row.get("contexts", []):
		primitive = _fallback_primitive_for_context(context_raw, registry)
		if primitive.is_empty():
			return _error("ucis_primitive_context_mismatch")
		primitive_row = primitives[primitive]
	var quantity := _quantity_encoding(step, context_raw)
	if quantity not in primitive_row.get("quantity_encodings", []):
		quantity = str((primitive_row.get("quantity_encodings", []) as Array)[0])
	var result := {
		"ok": true,
		"error_code": "",
		"ucis_generation": GENERATION,
		"step_id": step_id,
		"primitive": primitive,
		"select_type_raw": select_type_raw,
		"context_raw": context_raw,
		"option_type_raw": option_type_raw,
		"source_zone_query": _source_zone_query(step, context_raw),
		"candidate_predicate": "engine_legal_current_candidates",
		"target_predicate": "engine_legal_current_targets",
		"option_encoder": "ucis_registered_sparse_option",
		"option_order_owner": "engine_current_order",
		"quantity_encoding": quantity,
		"min_rule": "current_min_count",
		"max_rule": "current_max_count",
		"remaining_debt_rule": "current_remaining_debt",
		"public_context_projection": "ucis_public_facts_v1",
		"private_binding_recipe": "current_option_private_binding",
		"commit_command_kind": "commit_current_selection",
		"next_checkpoint_rule": "fresh_reobserve",
		"unsupported_if": [],
		"capability_ids": [primitive],
		"translation_mode": str(semantics.get("translation_mode", "")),
	}
	var remain_damage: Variant = step.get("ucis_remain_damage_counter", step.get("cabt_remain_damage_counter"))
	if typeof(remain_damage) == TYPE_INT:
		result["remain_damage_counter"] = int(remain_damage)
	var remain_energy: Variant = step.get("ucis_remain_energy_cost", step.get("cabt_remain_energy_cost"))
	if typeof(remain_energy) == TYPE_INT:
		result["remain_energy_cost"] = int(remain_energy)
	var target_result := _compile_target_semantics(step, registry)
	if not bool(target_result.get("ok", false)):
		return target_result
	if target_result.has("target_semantics"):
		result["target_semantics"] = target_result.target_semantics
	result["source_hash"] = _sha256_json(result)
	return result


static func _compile_target_semantics(step: Dictionary, registry: Dictionary) -> Dictionary:
	var has_target := step.has("target_items") or step.has("ucis_target_context_name") \
		or step.has("ucis_target_context_raw") \
		or step.has("cabt_target_select_context_raw")
	if not has_target:
		return {"ok": true, "error_code": ""}
	var rows: Dictionary = registry.get("_context_index", {})
	var target_name := str(step.get("ucis_target_context_name", ""))
	var context_raw := int(step.get("ucis_target_context_raw", step.get("cabt_target_select_context_raw", 25)))
	if not target_name.is_empty():
		var name_index: Dictionary = registry.get("_context_name_index", {})
		if not name_index.has(target_name):
			return _error("ucis_unknown_context")
		context_raw = int(name_index[target_name])
	if not rows.has(context_raw):
		return _error("ucis_unknown_context")
	var row: Dictionary = rows[context_raw]
	var select_type_raw := int(step.get(
		"ucis_target_select_type_raw",
		step.get("cabt_target_select_type_raw", row.get("select_type_raw", -1))
	))
	if select_type_raw != int(row.get("select_type_raw", -2)):
		return _error("ucis_context_select_type_mismatch")
	var option_type_raw := int(step.get(
		"ucis_target_option_type_raw",
		step.get("cabt_target_option_type_raw", (row.get("option_type_raw", [-1]) as Array)[0])
	))
	if option_type_raw not in row.get("option_type_raw", []):
		return _error("ucis_context_option_mismatch")
	return {
		"ok": true,
		"error_code": "",
		"target_semantics": {
			"select_type_raw": select_type_raw,
			"context_raw": context_raw,
			"option_type_raw": option_type_raw,
			"next_checkpoint_rule": "fresh_reobserve",
			"translation_mode": "semantic_name" if not target_name.is_empty() else "engine_private_compatibility",
		},
	}


static func _explicit_semantics(step: Dictionary, registry: Dictionary) -> Dictionary:
	var context_name := str(step.get("ucis_context_name", ""))
	if not context_name.is_empty():
		var name_index: Dictionary = registry.get("_context_name_index", {})
		if not name_index.has(context_name):
			return {}
		var context_raw := int(name_index[context_name])
		var row: Dictionary = (registry.get("_context_index", {}) as Dictionary).get(context_raw, {})
		var option_types: Array = row.get("option_type_raw", [])
		var option_names: Array = row.get("option_type_names", [])
		var option_name := str(step.get("ucis_option_type_name", ""))
		var option_index := 0
		if not option_name.is_empty():
			option_index = option_names.find(option_name)
			if option_index < 0:
				return {}
		return {
			"select_type_raw": int(row.get("select_type_raw", -1)),
			"context_raw": context_raw,
			"option_type_raw": int(option_types[option_index]) if option_index < option_types.size() else -1,
			"translation_mode": "semantic_name",
		}
	var select_value: Variant = step.get("ucis_select_type_raw", step.get("cabt_select_type_raw"))
	var context_value: Variant = step.get("ucis_context_raw", step.get("cabt_select_context_raw"))
	if typeof(select_value) != TYPE_INT or typeof(context_value) != TYPE_INT:
		return {}
	var option_value: Variant = step.get("ucis_option_type_raw", step.get("cabt_option_type_raw"))
	var option_type := int(option_value) if typeof(option_value) == TYPE_INT else _option_for_select_context(
		int(select_value), int(context_value), step
	)
	return {
		"select_type_raw": int(select_value),
		"context_raw": int(context_value),
		"option_type_raw": option_type,
		"translation_mode": "engine_private_compatibility",
	}


static func _infer_semantics(step: Dictionary, entrypoint: String) -> Dictionary:
	if step.has("total_counters") or str(step.get("ui_mode", "")) == "counter_distribution":
		return {"select_type_raw": 1, "context_raw": 14, "option_type_raw": 3, "translation_mode": "structural_spec"}
	if str(step.get("ui_mode", "")) == "card_assignment" or step.has("source_items") or step.has("target_items"):
		return {"select_type_raw": 1, "context_raw": 25, "option_type_raw": 3, "translation_mode": "structural_spec"}
	if step.has("pokemon_card") and step.has("card_items"):
		return {"select_type_raw": 1, "context_raw": 21, "option_type_raw": 3, "translation_mode": "structural_spec"}
	var items: Array = step.get("items", [])
	var first: Variant = null
	for item: Variant in items:
		if item != null:
			first = item
			break
	if first is Dictionary and typeof((first as Dictionary).get("number")) == TYPE_INT:
		return {"select_type_raw": 8, "context_raw": 38, "option_type_raw": 0, "translation_mode": "structural_spec"}
	if first is PokemonSlot or first is CardInstance or first is CardData:
		return {"select_type_raw": 1, "context_raw": 25, "option_type_raw": 3, "translation_mode": "structural_spec"}
	if typeof(first) == TYPE_BOOL:
		return {"select_type_raw": 9, "context_raw": 43, "option_type_raw": 1, "translation_mode": "structural_spec"}
	# Empty current candidate sets retain their declared structural family. A
	# mandatory empty window will be rejected by the Host; it is not retyped.
	if items.is_empty() and (entrypoint.contains("interaction") or step.has("min_select")):
		return {"select_type_raw": 1, "context_raw": 25, "option_type_raw": 3, "translation_mode": "structural_spec"}
	return {}


static func _primitive_for_step(step: Dictionary, context_raw: int, entrypoint: String) -> String:
	if step.has("total_counters") or step.has("source_items") or step.has("target_items"):
		return "AssignOrDistribute"
	if context_raw in [21, 22, 23] and step.has("pokemon_card"):
		return "AssignOrDistribute"
	if context_raw in [38, 39, 40]:
		return "ChooseNumber"
	if context_raw in [41, 42, 43, 44, 45, 46]:
		return "ChooseBoolean"
	if context_raw in [47, 48]:
		return "ChooseSpecialCondition"
	if context_raw == 34:
		return "ChooseSkillOrder"
	if context_raw in [35, 36]:
		return "ChooseAttack"
	if context_raw == 37 or context_raw in [18, 19, 20]:
		return "ChooseEvolution"
	if context_raw in [26, 27, 28, 29]:
		return "ChooseAttachedCardSet"
	if context_raw in [30, 31, 32, 33]:
		return "ChooseEnergyUnits"
	if context_raw in [5, 6, 7, 8, 9, 10, 11, 12, 24] and (
		step.has("visible_scope") or step.has("card_items")
	):
		return "SearchAndMove"
	if entrypoint.contains("attack"):
		return "AttackAndTarget"
	if entrypoint.contains("knockout") or entrypoint.contains("end_turn"):
		return "ResolveKnockout"
	return "ChooseCardSet"


static func _fallback_primitive_for_context(context_raw: int, registry: Dictionary) -> String:
	for primitive_value: Variant in registry.get("primitives", []):
		if primitive_value is Dictionary and context_raw in (primitive_value as Dictionary).get("contexts", []):
			return str((primitive_value as Dictionary).get("primitive", ""))
	return ""


static func _quantity_encoding(step: Dictionary, context_raw: int) -> String:
	if context_raw in [38, 39, 40]:
		return "number_option"
	if context_raw in [30, 31, 32, 33]:
		return "energy_units"
	if context_raw == 34 or bool(step.get("ordered_selection", false)):
		return "ordered_result_indexes"
	return "result_list_length"


static func _option_for_select_context(select_type_raw: int, context_raw: int, step: Dictionary) -> int:
	match select_type_raw:
		1: return 3
		2:
			return 4 if context_raw == 27 else 5
		3:
			return int(step.get("cabt_option_type_raw", 3))
		4: return 6
		5: return 15
		6: return 13
		7: return 9
		8: return 0
		9: return 1
		10: return 16
		_: return -1


static func _source_zone_query(step: Dictionary, context_raw: int) -> String:
	if step.has("visible_scope"):
		return str(step.get("visible_scope"))
	if context_raw in [26, 27, 28, 29, 30, 31, 32, 33]:
		return "current_public_attachments"
	return "current_public_frontier"


static func _program_kind(steps: Array[Dictionary]) -> String:
	if steps.is_empty():
		return "automatic_resolution"
	var metadata := metadata_for_step(steps[0])
	return str(metadata.get("primitive", "unsupported_interaction_shape"))


static func _capabilities(steps: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for step: Dictionary in steps:
		var primitive := str(metadata_for_step(step).get("primitive", ""))
		if not primitive.is_empty() and primitive not in result:
			result.append(primitive)
	return result


static func _effect_ref(source_effect: Object) -> String:
	if source_effect != null and source_effect.has_method("get_ucis_registration_ids"):
		var registrations: Array = source_effect.call("get_ucis_registration_ids")
		if not registrations.is_empty():
			return "effect_id:%s" % ",".join(registrations)
	var script: Script = source_effect.get_script() if source_effect != null else null
	if script == null:
		return "builtin:BaseEffect"
	var resource_path := str(script.resource_path).strip_edges()
	if not resource_path.is_empty():
		return resource_path
	var source := str(script.source_code)
	if source.is_empty():
		return "inline:BaseEffect"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(source.to_utf8_buffer())
	return "inline_script_sha256:%s" % context.finish().hex_encode().to_upper()


static func _sha256_json(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value, "", true).to_utf8_buffer())
	return context.finish().hex_encode().to_upper()


static func _validate_metadata(metadata: Dictionary, registry: Dictionary) -> Dictionary:
	if int(metadata.get("ucis_generation", -1)) != GENERATION:
		return _error("ucis_generation_drift")
	var context_raw := int(metadata.get("context_raw", -1))
	var rows: Dictionary = registry.get("_context_index", {})
	if not rows.has(context_raw):
		return _error("ucis_unknown_context")
	var row: Dictionary = rows[context_raw]
	if int(metadata.get("select_type_raw", -1)) != int(row.get("select_type_raw", -2)):
		return _error("ucis_context_select_type_mismatch")
	if int(metadata.get("option_type_raw", -1)) not in row.get("option_type_raw", []):
		return _error("ucis_context_option_mismatch")
	var primitive := str(metadata.get("primitive", ""))
	var primitives: Dictionary = registry.get("_primitive_index", {})
	if not primitives.has(primitive) or context_raw not in (primitives[primitive] as Dictionary).get("contexts", []):
		return _error("ucis_primitive_context_mismatch")
	if str(metadata.get("next_checkpoint_rule", "")) != "fresh_reobserve":
		return _error("ucis_stale_continuation_forbidden")
	if str(metadata.get("translation_mode", "")) not in [
		"semantic_name", "structural_spec", "engine_private_compatibility"
	]:
		return _error("ucis_translation_mode_invalid")
	return {"ok": true, "error_code": ""}


static func _add_capability(target: Array[String], capability_id: String) -> void:
	if capability_id not in target:
		target.append(capability_id)


static func _registry() -> Dictionary:
	if not _registry_cache.is_empty():
		return _registry_cache
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		_registry_error = "ucis_registry_unavailable"
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_registry_error = "ucis_registry_document_invalid"
		return {}
	var registry: Dictionary = (parsed as Dictionary).duplicate(true)
	if (
		str(registry.get("document_type", "")) != "ptcgdap_ucis_registry_v1"
		or int(registry.get("schema_version", -1)) != 1
		or int(registry.get("ucis_generation", -1)) != GENERATION
		or int(registry.get("contract_generation", -1)) != 2
	):
		_registry_error = "ucis_registry_generation_invalid"
		return {}
	var context_index: Dictionary = {}
	var context_name_index: Dictionary = {}
	for row_value: Variant in registry.get("context_rows", []):
		if not row_value is Dictionary:
			_registry_error = "ucis_registry_context_invalid"
			return {}
		var row: Dictionary = row_value
		var raw := int(row.get("context_raw", -1))
		var context_name := str(row.get("context_name", ""))
		if raw < 0 or context_name.is_empty() or context_index.has(raw) or context_name_index.has(context_name):
			_registry_error = "ucis_registry_context_invalid"
			return {}
		var normalized_row := row.duplicate(true)
		var normalized_options: Array[int] = []
		for option_value: Variant in row.get("option_type_raw", []):
			normalized_options.append(int(option_value))
		normalized_row["context_raw"] = raw
		normalized_row["context_name"] = context_name
		normalized_row["select_type_raw"] = int(row.get("select_type_raw", -1))
		normalized_row["option_type_raw"] = normalized_options
		context_index[raw] = normalized_row
		context_name_index[context_name] = raw
	if context_index.size() != 49:
		_registry_error = "ucis_registry_context_incomplete"
		return {}
	var primitive_index: Dictionary = {}
	for primitive_value: Variant in registry.get("primitives", []):
		if not primitive_value is Dictionary:
			_registry_error = "ucis_registry_primitive_invalid"
			return {}
		var primitive: Dictionary = primitive_value
		var name := str(primitive.get("primitive", ""))
		if name.is_empty() or name == "CustomInteraction" or primitive_index.has(name):
			_registry_error = "ucis_registry_primitive_invalid"
			return {}
		var normalized_primitive := primitive.duplicate(true)
		var normalized_contexts: Array[int] = []
		for context_value: Variant in primitive.get("contexts", []):
			normalized_contexts.append(int(context_value))
		normalized_primitive["contexts"] = normalized_contexts
		primitive_index[name] = normalized_primitive
	if primitive_index.size() != 16:
		_registry_error = "ucis_registry_primitive_incomplete"
		return {}
	registry["_context_index"] = context_index
	registry["_context_name_index"] = context_name_index
	registry["_primitive_index"] = primitive_index
	_registry_cache = registry
	return _registry_cache


static func _error(code: String, step_index: int = -1) -> Dictionary:
	var result := {"ok": false, "error_code": code}
	if step_index >= 0:
		result["step_index"] = step_index
	return result
