extends SceneTree

const CARD_ROOT := "res://data/bundled_user/cards"
const OUTPUT_PATH := "res://contracts/ptcgdap/ucis_runtime_attestation_v1.json"

var _registered_primitives: Array[String] = []


func _initialize() -> void:
	var result := build_attestation()
	if not bool(result.get("ok", false)):
		push_error("UCIS runtime attestation failed: %s %s" % [
			str(result.get("error_code", "unknown")),
			JSON.stringify(result.get("invalid_specs", [])),
		])
		quit(1)
		return
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("UCIS runtime attestation cannot write %s" % OUTPUT_PATH)
		quit(1)
		return
	output.store_string(JSON.stringify(result.document, "", true))
	output.close()
	print("UCIS runtime attestation: %d cards, %d effects, compiled=%d automatic=%d unsupported=%d" % [
		int(result.document.closure.total_cards),
		int(result.document.closure.total_effects),
		int(result.document.closure.compiled),
		int(result.document.closure.automatic),
		int(result.document.closure.unsupported),
	])
	quit(0)


func build_attestation() -> Dictionary:
	var registry_result := _load_registered_primitives()
	if not bool(registry_result.get("ok", false)):
		return registry_result
	_registered_primitives = registry_result.primitives
	var loaded := _load_cards()
	if not bool(loaded.get("ok", false)):
		return loaded
	var cards: Array[CardData] = []
	for value: Variant in loaded.cards:
		cards.append(value as CardData)
	var processor := EffectProcessor.new()
	for card: CardData in cards:
		processor.register_pokemon_card(card)

	var card_rows: Array[Dictionary] = []
	var effect_rows: Dictionary = {}
	var invalid_specs: Array[Dictionary] = []
	for card: CardData in cards:
		var row := _attest_card(card, processor, invalid_specs)
		card_rows.append(row)
		var effect_id := str(row.effect_id)
		if not effect_rows.has(effect_id):
			effect_rows[effect_id] = {
				"effect_id": effect_id,
				"status": "automatic",
				"unsupported_reasons": [],
				"card_uids": [],
				"effect_refs": [],
				"capability_ids": [],
				"source_hashes": [],
				"program_templates": [],
			}
		var effect_row: Dictionary = effect_rows[effect_id]
		effect_row.card_uids.append(row.card_uid)
		_merge_unique(effect_row.effect_refs, row.effect_refs)
		_merge_unique(effect_row.capability_ids, row.capability_ids)
		_merge_unique(effect_row.source_hashes, row.source_hashes)
		for program: Dictionary in row.program_templates:
			if program not in effect_row.program_templates:
				effect_row.program_templates.append(program)
		if row.status == "unsupported":
			effect_row.status = "unsupported"
			if str(row.unsupported_reason) not in effect_row.unsupported_reasons:
				effect_row.unsupported_reasons.append(str(row.unsupported_reason))
		elif row.status == "compiled" and effect_row.status != "unsupported":
			effect_row.status = "compiled"

	var effects: Array[Dictionary] = []
	var effect_ids: Array[String] = []
	for value: Variant in effect_rows.keys():
		effect_ids.append(str(value))
	effect_ids.sort()
	var compiled := 0
	var automatic := 0
	var unsupported := 0
	var primitive_coverage: Dictionary = {}
	for primitive: String in _registered_primitives:
		primitive_coverage[primitive] = 0
	for effect_id: String in effect_ids:
		var row: Dictionary = effect_rows[effect_id]
		row.card_uids.sort()
		row.effect_refs.sort()
		row.capability_ids.sort()
		row.source_hashes.sort()
		row.program_templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("program_id", "")) < str(b.get("program_id", ""))
		)
		row.unsupported_reasons.sort()
		for capability_id: String in row.capability_ids:
			if primitive_coverage.has(capability_id):
				primitive_coverage[capability_id] = int(primitive_coverage[capability_id]) + 1
		effects.append(row)
		match str(row.status):
			"compiled": compiled += 1
			"automatic": automatic += 1
			"unsupported": unsupported += 1
			_:
				processor.prepare_for_disposal()
				return {"ok": false, "error_code": "ucis_runtime_status_invalid"}
	processor.prepare_for_disposal()

	if not invalid_specs.is_empty():
		return {
			"ok": false,
			"error_code": "ucis_runtime_effect_spec_invalid",
			"invalid_specs": invalid_specs,
		}
	return {
		"ok": true,
		"document": {
			"document_type": "ptcgdap_ucis_runtime_attestation_v1",
			"schema_version": 1,
			"ucis_generation": 1,
			"contract_generation": 2,
			"card_source_manifest": loaded.source_manifest,
			"card_source_manifest_sha256": _sha256_text(JSON.stringify(loaded.source_manifest, "", true)),
			"cards": card_rows,
			"effects": effects,
			"invalid_specs": [],
			"primitive_coverage": primitive_coverage,
			"closure": {
				"total_cards": card_rows.size(),
				"total_effects": effects.size(),
				"compiled": compiled,
				"automatic": automatic,
				"unsupported": unsupported,
				"unregistered": 0,
				"silent_fallback": 0,
			},
		},
	}


func _attest_card(
	card: CardData,
	processor: EffectProcessor,
	invalid_specs: Array[Dictionary]
) -> Dictionary:
	var status := CardImplementationStatus.get_status(card)
	var effect_instances := processor.get_ucis_effect_instances(card.effect_id)
	var effect_refs: Array[String] = []
	var capability_ids: Array[String] = []
	var source_hashes: Array[String] = []
	var program_templates: Array[Dictionary] = []
	var interactive := false
	for effect: BaseEffect in effect_instances:
		var spec := effect.get_ucis_effect_spec()
		var error_code := _validate_effect_spec(spec)
		if error_code != "":
			invalid_specs.append({
				"card_uid": card.get_uid(),
				"effect_id": card.effect_id,
				"error_code": error_code,
			})
			continue
		var effect_ref := str(spec.effect_ref)
		if effect_ref not in effect_refs:
			effect_refs.append(effect_ref)
		_merge_unique(capability_ids, spec.capability_ids)
		_merge_unique(source_hashes, [str(spec.source_hash)])
		for program: Dictionary in spec.programs:
			if program not in program_templates:
				program_templates.append(program)
		interactive = interactive or str(spec.resolution_kind) == "interactive"
	effect_refs.sort()
	capability_ids.sort()
	var unsupported := bool(status.get("unimplemented", false))
	if unsupported and capability_ids.is_empty():
		capability_ids.append("unsupported_interaction_shape")
	return {
		"card_uid": card.get_uid(),
		"effect_id": card.effect_id,
		"status": "unsupported" if unsupported else ("compiled" if interactive else "automatic"),
		"unsupported_reason": str(status.get("reason", "")) if unsupported else "",
		"effect_refs": effect_refs,
		"capability_ids": capability_ids,
		"source_hashes": source_hashes,
		"program_templates": program_templates,
	}


func _validate_effect_spec(spec: Dictionary) -> String:
	var expected_keys := [
		"schema_version", "effect_ref", "resolution_kind", "program_kind",
		"capability_ids", "builder_entrypoints", "programs", "chooser_rule",
		"visibility_rule", "lifecycle_anchor", "continuation_rule", "stop_rule",
		"information_checkpoints", "contract_generation", "compiler_generation",
		"source_hash",
	]
	var keys: Array = spec.keys()
	keys.sort()
	expected_keys.sort()
	if keys != expected_keys:
		return "ucis_effect_spec_fields_invalid"
	if int(spec.get("schema_version", -1)) != 1:
		return "ucis_effect_spec_schema_invalid"
	if str(spec.get("effect_ref", "")).is_empty():
		return "ucis_effect_spec_ref_missing"
	if str(spec.get("resolution_kind", "")) not in ["interactive", "automatic_resolution"]:
		return "ucis_effect_spec_resolution_invalid"
	if not spec.get("capability_ids", null) is Array \
		or not spec.get("builder_entrypoints", null) is Array \
		or not spec.get("programs", null) is Array:
		return "ucis_effect_spec_capabilities_invalid"
	var capabilities: Array = spec.capability_ids
	var builders: Array = spec.builder_entrypoints
	var programs: Array = spec.programs
	for capability_value: Variant in capabilities:
		if not capability_value is String or str(capability_value) not in _registered_primitives:
			return "ucis_effect_spec_capability_unregistered"
	if str(spec.resolution_kind) == "interactive":
		if capabilities.is_empty() or builders.is_empty() or programs.size() != builders.size():
			return "ucis_effect_spec_program_closure_invalid"
	else:
		if not capabilities.is_empty() or not builders.is_empty() or not programs.is_empty():
			return "ucis_automatic_effect_program_forbidden"
	for program_value: Variant in programs:
		if not program_value is Dictionary:
			return "ucis_effect_spec_program_invalid"
		var program: Dictionary = program_value
		if (
			str(program.get("program_id", "")).is_empty()
			or str(program.get("step_recipe_owner", "")) != "UcisInteractionCompiler"
			or str(program.get("source_hash", "")) != str(spec.source_hash)
			or str(program.get("continuation_rule", "")) != "ordered_steps_fresh_reobserve"
		):
			return "ucis_effect_spec_program_invalid"
		for capability_value: Variant in program.get("capability_ids", []):
			if capability_value not in capabilities:
				return "ucis_effect_spec_program_capability_invalid"
	if int(spec.get("contract_generation", -1)) != 2 or int(spec.get("compiler_generation", -1)) != 1:
		return "ucis_effect_spec_generation_invalid"
	if not _is_upper_sha256(str(spec.get("source_hash", ""))):
		return "ucis_effect_spec_source_hash_invalid"
	return ""


func _load_registered_primitives() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://contracts/ptcgdap/ucis_registry_v1.json"
	))
	if not parsed is Dictionary:
		return {"ok": false, "error_code": "ucis_registry_document_invalid"}
	var document: Dictionary = parsed
	if int(document.get("ucis_generation", -1)) != 1:
		return {"ok": false, "error_code": "ucis_registry_generation_invalid"}
	var primitives: Array[String] = []
	for value: Variant in document.get("primitives", []):
		if not value is Dictionary:
			return {"ok": false, "error_code": "ucis_registry_primitive_invalid"}
		var primitive := str((value as Dictionary).get("primitive", ""))
		if primitive.is_empty() or primitive == "CustomInteraction" or primitive in primitives:
			return {"ok": false, "error_code": "ucis_registry_primitive_invalid"}
		primitives.append(primitive)
	if primitives.size() != 16:
		return {"ok": false, "error_code": "ucis_registry_primitive_incomplete"}
	primitives.sort()
	return {"ok": true, "primitives": primitives}


func _is_upper_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_upper():
		return false
	for character: String in value:
		if character not in "0123456789ABCDEF":
			return false
	return true


func _load_cards() -> Dictionary:
	var dir := DirAccess.open(CARD_ROOT)
	if dir == null:
		return {"ok": false, "error_code": "ucis_card_root_unavailable"}
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	var cards: Array[CardData] = []
	var source_manifest: Array[Dictionary] = []
	var seen: Dictionary = {}
	for file_name: String in names:
		var path := CARD_ROOT.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error_code": "ucis_card_document_unavailable"}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary:
			return {"ok": false, "error_code": "ucis_card_document_invalid"}
		var card := CardData.from_dict(parsed as Dictionary)
		var uid := card.get_uid()
		if uid.is_empty() or card.effect_id.is_empty() or seen.has(uid):
			return {"ok": false, "error_code": "ucis_card_identity_invalid"}
		seen[uid] = true
		cards.append(card)
		source_manifest.append({
			"path": path.trim_prefix("res://"),
			"sha256": FileAccess.get_sha256(path).to_upper(),
		})
	return {"ok": true, "cards": cards, "source_manifest": source_manifest}


func _merge_unique(target: Array, values: Array) -> void:
	for value: Variant in values:
		if value not in target:
			target.append(value)


func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode().to_upper()
