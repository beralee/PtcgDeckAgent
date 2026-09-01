class_name TestUcisInteractionCompiler
extends TestBase

const Compiler = preload("res://scripts/engine/ucis/UcisInteractionCompiler.gd")
const EnergySwitchEffect = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")


class DeclarativeEffect extends BaseEffect:
	func build_ucis_interaction_steps_spec_steps(
		_card: CardInstance,
		_state: GameState
	) -> Array[Dictionary]:
		return [{
			"id": "choose_from_deck",
			"items": ["second", "first"],
			"labels": ["second", "first"],
			"min_select": 1,
			"max_select": 1,
			"visible_scope": "own_full_deck",
			"cabt_select_type_raw": 1,
			"cabt_select_context_raw": 5,
			"cabt_option_type_raw": 3,
		}]


class HashLockedEffect extends BaseEffect:
	func get_ucis_effect_spec() -> Dictionary:
		return {"source_hash": "A".repeat(64)}


class UnsupportedDiagnosticEffect extends BaseEffect:
	func build_ucis_interaction_steps_spec_steps(
		_card: CardInstance,
		_state: GameState
	) -> Array[Dictionary]:
		return [{"id": "invalid-shape", "window_id": "card-owned-window"}]


func test_explicit_wire_semantics_compile_without_reordering_candidates() -> String:
	Compiler.clear_cache_for_tests()
	var raw_steps: Array = [{
		"id": "search",
		"items": ["second", "first"],
		"labels": ["second", "first"],
		"min_select": 1,
		"max_select": 2,
		"visible_scope": "own_full_deck",
		"cabt_select_type_raw": 1,
		"cabt_select_context_raw": 5,
		"cabt_option_type_raw": 3,
	}]
	var result := Compiler.compile_steps(raw_steps, "interaction", BaseEffect.new())
	if not bool(result.get("ok", false)):
		return "compile failed: %s" % str(result.get("error_code", ""))
	var step: Dictionary = result.steps[0]
	var metadata := Compiler.metadata_for_step(step)
	return run_checks([
		assert_eq(step.items, ["second", "first"], "compiler must preserve current option order"),
		assert_eq(metadata.context_raw, 5, "context must be registry raw value"),
		assert_eq(metadata.select_type_raw, 1),
		assert_eq(metadata.option_type_raw, 3),
		assert_eq(metadata.primitive, "SearchAndMove"),
		assert_eq(metadata.next_checkpoint_rule, "fresh_reobserve"),
		assert_eq(result.program.contract_generation, 2),
		assert_eq(result.program.ordered_steps.size(), 1),
		assert_eq(result.program.ordered_steps[0].context_raw, 5),
		assert_eq(result.effect_spec.steps[0].context_name, "TO_BENCH"),
		assert_eq(result.effect_spec.steps[0].option_type_name, "CARD"),
		assert_false(result.program.has("steps"), "language-neutral program uses ordered_steps"),
	])


func test_structural_assignment_and_number_steps_compile_to_registered_primitives() -> String:
	var assignment := Compiler.compile_steps([{
		"id": "assign",
		"ui_mode": "card_assignment",
		"source_items": ["energy-a", "energy-b", "energy-c"],
		"target_items": ["active", "bench"],
		"min_select": 3,
		"max_select": 3,
	}], "interaction", BaseEffect.new())
	var number := Compiler.compile_steps([{
		"id": "amount",
		"items": [{"number": 1}, {"number": 2}, {"number": 3}],
		"min_select": 1,
		"max_select": 1,
	}], "interaction", BaseEffect.new())
	var assignment_with_target := Compiler.compile_steps([{
		"id": "assign-two-window",
		"ui_mode": "card_assignment",
		"source_items": ["energy-a"],
		"target_items": ["active", "bench"],
		"min_select": 1,
		"max_select": 1,
		"ucis_context_name": "ATTACH_TO",
		"ucis_target_context_name": "ATTACH_FROM",
	}], "interaction", BaseEffect.new())
	if not bool(assignment.get("ok", false)) or not bool(number.get("ok", false)):
		return "structural compile failed: %s / %s" % [
			str(assignment.get("error_code", "")),
			str(number.get("error_code", "")),
		]
	return run_checks([
		assert_eq(Compiler.metadata_for_step(assignment.steps[0]).primitive, "AssignOrDistribute"),
		assert_eq(Compiler.metadata_for_step(number.steps[0]).primitive, "ChooseNumber"),
		assert_eq(Compiler.metadata_for_step(number.steps[0]).quantity_encoding, "number_option"),
		assert_eq(assignment_with_target.program.ordered_steps.size(), 2),
		assert_eq(assignment_with_target.program.ordered_steps[0].context_raw, 22),
		assert_eq(assignment_with_target.program.ordered_steps[1].context_raw, 21),
		assert_eq(assignment_with_target.program.ordered_steps[1].next_checkpoint_rule, "fresh_reobserve"),
	])


func test_energy_switch_uses_attached_energy_source_then_fresh_attach_target_wire() -> String:
	var pokemon_data := CardData.new()
	pokemon_data.name = "UCIS source"
	pokemon_data.card_type = "Pokemon"
	pokemon_data.stage = "Basic"
	pokemon_data.hp = 100
	var target_data := CardData.new()
	target_data.name = "UCIS target"
	target_data.card_type = "Pokemon"
	target_data.stage = "Basic"
	target_data.hp = 100
	var energy_data := CardData.new()
	energy_data.name = "Grass Energy"
	energy_data.card_type = "Basic Energy"
	var trainer_data := CardData.new()
	trainer_data.name = "Energy Switch"
	trainer_data.card_type = "Trainer"
	var source_slot := PokemonSlot.new()
	source_slot.pokemon_stack.append(CardInstance.create(pokemon_data, 0))
	source_slot.attached_energy.append(CardInstance.create(energy_data, 0))
	var target_slot := PokemonSlot.new()
	target_slot.pokemon_stack.append(CardInstance.create(target_data, 0))
	var player := PlayerState.new()
	player.player_index = 0
	player.active_pokemon = source_slot
	player.bench.append(target_slot)
	var opponent := PlayerState.new()
	opponent.player_index = 1
	var state := GameState.new()
	state.players = [player, opponent]
	var effect := EnergySwitchEffect.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(
		CardInstance.create(trainer_data, 0), state
	)
	if steps.size() != 1:
		return "expected one compiled Energy Switch step: %s" % effect.get_ucis_last_diagnostic()
	var metadata := Compiler.metadata_for_step(steps[0])
	var target_semantics: Dictionary = metadata.get("target_semantics", {})
	return run_checks([
		assert_eq(metadata.get("select_type_raw"), 2),
		assert_eq(metadata.get("context_raw"), 28),
		assert_eq(metadata.get("option_type_raw"), 5),
		assert_eq(metadata.get("primitive"), "AssignOrDistribute"),
		assert_eq(target_semantics.get("select_type_raw"), 1),
		assert_eq(target_semantics.get("context_raw"), 22),
		assert_eq(target_semantics.get("option_type_raw"), 3),
		assert_eq(target_semantics.get("next_checkpoint_rule"), "fresh_reobserve"),
	])


func test_unknown_pair_and_card_owned_window_authority_fail_closed() -> String:
	var bad_pair := Compiler.compile_steps([{
		"id": "bad-pair",
		"items": ["x"],
		"cabt_select_type_raw": 8,
		"cabt_select_context_raw": 5,
		"cabt_option_type_raw": 0,
	}], "interaction", BaseEffect.new())
	var forbidden := Compiler.compile_steps([{
		"id": "bad-owner",
		"items": ["x"],
		"window_id": "stale-window",
		"cabt_select_type_raw": 1,
		"cabt_select_context_raw": 5,
		"cabt_option_type_raw": 3,
	}], "interaction", BaseEffect.new())
	return run_checks([
		assert_false(bool(bad_pair.get("ok", true))),
		assert_eq(bad_pair.error_code, "ucis_context_select_type_mismatch"),
		assert_false(bool(forbidden.get("ok", true))),
		assert_eq(forbidden.error_code, "ucis_card_step_authority_forbidden"),
	])


func test_compilation_is_idempotent_and_does_not_persist_option_indexes() -> String:
	var first := Compiler.compile_steps([{
		"id": "choose",
		"items": ["a", "b"],
		"min_select": 1,
		"max_select": 1,
		"cabt_select_type_raw": 1,
		"cabt_select_context_raw": 25,
		"cabt_option_type_raw": 3,
	}], "interaction", BaseEffect.new())
	if not bool(first.get("ok", false)):
		return "initial compile failed"
	var second := Compiler.compile_steps(first.steps, "interaction", BaseEffect.new())
	if not bool(second.get("ok", false)):
		return "idempotent compile failed"
	var encoded := JSON.stringify(second)
	return run_checks([
		assert_eq(second.steps, first.steps),
		assert_false("option_index" in encoded, "compiled program must not persist an old option index"),
		assert_false("window_handle" in encoded, "compiled program must not own window lifecycle"),
	])


func test_base_effect_is_the_only_public_interaction_entrypoint() -> String:
	var effect := DeclarativeEffect.new()
	var steps := effect.get_interaction_steps(null, null)
	if steps.size() != 1:
		return "expected one compiled step, got %d (%s)" % [steps.size(), effect.get_ucis_last_error()]
	var metadata := Compiler.metadata_for_step(steps[0])
	var source := "func build_ucis_interaction_steps_spec_steps(card, state):\n\treturn []\n"
	var builders := Compiler.builder_entrypoints_for_source(source)
	var capabilities := Compiler.declared_capabilities_for_source(source, builders)
	return run_checks([
		assert_eq(metadata.primitive, "SearchAndMove"),
		assert_eq(metadata.translation_mode, "engine_private_compatibility"),
		assert_contains(builders, "build_ucis_interaction_steps_spec_steps"),
		assert_contains(capabilities, "ChooseCardSet"),
	])


func test_rejected_ucis_shape_reports_stable_effect_and_entrypoint_diagnostic() -> String:
	var effect := UnsupportedDiagnosticEffect.new()
	effect.bind_ucis_registration_id("fixture.unsupported-diagnostic")
	var steps := effect.get_preview_interaction_steps(null, null)
	var diagnostic: Dictionary = effect.get_ucis_last_diagnostic()
	return run_checks([
		assert_eq(steps.size(), 1, "Rejected interactions must retain the mandatory fail-closed sentinel"),
		assert_eq(str(diagnostic.get("effect_ref", "")), "effect_id:fixture.unsupported-diagnostic"),
		assert_eq(str(diagnostic.get("entrypoint", "")), "preview_interaction"),
		assert_eq(str(diagnostic.get("error_code", "")), "ucis_card_step_authority_forbidden"),
		assert_eq(
			(steps[0].get("ucis_unsupported_diagnostic", {}) as Dictionary),
			diagnostic,
			"The sentinel and runtime audit must bind the same rejection identity"
		),
	])


func test_python_and_godot_emit_the_same_language_neutral_program_hash() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://contracts/ptcgdap/ucis_conformance_vectors_v1.json"
	))
	if not parsed is Dictionary:
		return "UCIS conformance vectors are unavailable"
	var expected: Dictionary = {}
	for vector_value: Variant in (parsed as Dictionary).get("vectors", []):
		if vector_value is Dictionary and str((vector_value as Dictionary).get("case_id", "")) == "language-neutral-program-hash":
			expected = (vector_value as Dictionary).get("program", {})
			break
	if expected.is_empty():
		return "cross-language program vector is missing"
	var effect := HashLockedEffect.new()
	effect.bind_ucis_registration_id("ucis-cross-language")
	var result := Compiler.compile_steps([{
		"id": "step-1",
		"items": ["card:a"],
		"min_select": 0,
		"max_select": 1,
		"ucis_context_name": "SETUP_ACTIVE_POKEMON",
		"ucis_option_type_name": "CARD",
	}], "interaction", effect)
	if not bool(result.get("ok", false)):
		return "Godot compiler rejected cross-language vector: %s" % result.error_code
	return run_checks([
		assert_eq(result.program.program_hash, expected.program_hash),
		assert_eq(result.program.source_effect_ref, expected.source_effect_ref),
		assert_eq(result.program.ordered_steps.size(), expected.ordered_steps.size()),
		assert_eq(int(result.program.ordered_steps[0].context_raw), int(expected.ordered_steps[0].context_raw)),
		assert_eq(result.effect_spec.steps[0].context_name, "SETUP_ACTIVE_POKEMON"),
	])


func test_engine_private_legacy_translation_shadows_semantic_ucis_without_dual_authority() -> String:
	var effect := HashLockedEffect.new()
	var legacy := Compiler.compile_steps([{
		"id": "shadow-search",
		"title": "legacy display text",
		"items": ["card:b", "card:a"],
		"min_select": 0,
		"max_select": 2,
		"cabt_select_type_raw": 1,
		"cabt_select_context_raw": 7,
		"cabt_option_type_raw": 3,
	}], "interaction", effect)
	var semantic := Compiler.compile_steps([{
		"id": "shadow-search",
		"title": "mutated non-authority display text",
		"items": ["card:b", "card:a"],
		"min_select": 0,
		"max_select": 2,
		"ucis_context_name": "TO_HAND",
		"ucis_option_type_name": "CARD",
	}], "interaction", effect)
	if not bool(legacy.get("ok", false)) or not bool(semantic.get("ok", false)):
		return "shadow compile failed: %s / %s" % [
			str(legacy.get("error_code", "")), str(semantic.get("error_code", ""))
		]
	var legacy_meta := Compiler.metadata_for_step(legacy.steps[0])
	var semantic_meta := Compiler.metadata_for_step(semantic.steps[0])
	return run_checks([
		assert_eq(legacy.program, semantic.program, "legacy translator and semantic spec must emit one canonical program"),
		assert_eq(legacy.steps[0].items, semantic.steps[0].items, "shadow translation must preserve official option order"),
		assert_eq(legacy.steps[0].min_select, semantic.steps[0].min_select),
		assert_eq(legacy.steps[0].max_select, semantic.steps[0].max_select),
		assert_eq(legacy_meta.select_type_raw, semantic_meta.select_type_raw),
		assert_eq(legacy_meta.context_raw, semantic_meta.context_raw),
		assert_eq(legacy_meta.option_type_raw, semantic_meta.option_type_raw),
		assert_eq(legacy_meta.private_binding_recipe, semantic_meta.private_binding_recipe),
		assert_eq(legacy_meta.translation_mode, "engine_private_compatibility"),
		assert_eq(semantic_meta.translation_mode, "semantic_name"),
	])
