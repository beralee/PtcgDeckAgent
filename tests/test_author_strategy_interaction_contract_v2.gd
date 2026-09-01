class_name TestAuthorStrategyInteractionContractV2
extends TestBase

const ResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const AuthorOwnerScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
)


class StrategyStub extends RefCounted:
	var target_calls := 0

	func pick_interaction_items(_items: Array, _step: Dictionary, _context: Dictionary = {}) -> Array:
		return []

	func should_preserve_empty_interaction_selection(_step: Dictionary, _context: Dictionary = {}) -> bool:
		return true

	func pick_interaction_target_index(
		_items: Array,
		_excluded_targets: Array,
		_step: Dictionary,
		_context: Dictionary = {}
	) -> int:
		target_calls += 1
		return 1


class DialogStub extends Control:
	var called := false
	var indexes := PackedInt32Array()

	func _handle_effect_interaction_choice(value: PackedInt32Array) -> void:
		called = true
		indexes = value


class ExplicitFieldStrategyStub extends RefCounted:
	var calls := 0

	func pick_interaction_items(items: Array, _step: Dictionary, _context: Dictionary = {}) -> Array:
		calls += 1
		return [items[1]] if items.size() >= 2 else []

	func should_preserve_empty_interaction_selection(_step: Dictionary, _context: Dictionary = {}) -> bool:
		return false


class FieldSlotStub extends Control:
	var _pending_effect_step_index := 0
	var _pending_effect_steps: Array = []
	var _field_interaction_mode := "slot_select"
	var selected_indexes: Array[int] = []
	var finalized := false

	func _handle_field_slot_select_index(index: int) -> void:
		selected_indexes.append(index)

	func _finalize_field_slot_selection() -> void:
		finalized = true


class OfficialCounterWindowStrategy extends RefCounted:
	var windows: Array[Dictionary] = []

	func uses_external_decision_port() -> bool:
		return true

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		var metadata := UcisInteractionCompiler.metadata_for_step(step)
		var numbers: Array[int] = []
		for item: Variant in items:
			numbers.append(
				int((item as Dictionary).get("number", -1)) if item is Dictionary else -1
			)
		windows.append({
			"select_type_raw": int(metadata.get("select_type_raw", -1)),
			"select_context_raw": int(metadata.get("context_raw", -1)),
			"option_type_raw": int(metadata.get("option_type_raw", -1)),
			"remain_damage_counter": int(metadata.get("remain_damage_counter", 0)),
			"numbers": numbers,
		})
		match int(metadata.get("context_raw", -1)):
			40:
				return [items[1]] if items.size() >= 2 else [items[0]]
			13:
				return [items[1]] if items.size() >= 2 else [items[0]]
			14:
				return [items[1]] if items.size() >= 2 else [items[0]]
		return []

	func should_preserve_empty_interaction_selection(
		_step: Dictionary,
		_context: Dictionary = {}
	) -> bool:
		return false


class CounterDistributionStub extends Control:
	var _field_interaction_assignment_entries: Array[Dictionary] = []
	var _field_interaction_assignment_selected_source_index := -1

	func _on_counter_distribution_amount_chosen(amount: int) -> void:
		_field_interaction_assignment_selected_source_index = amount

	func _handle_counter_distribution_target(target_index: int) -> void:
		if _field_interaction_assignment_selected_source_index <= 0:
			return
		_field_interaction_assignment_entries.append({
			"target_index": target_index,
			"amount": _field_interaction_assignment_selected_source_index * 10,
		})
		_field_interaction_assignment_selected_source_index = -1


class DecisionExporterStub extends RefCounted:
	var records: Array[Dictionary] = []

	func record_interaction_decision(record: Dictionary) -> void:
		records.append(record.duplicate(true))


func test_optional_empty_selection_is_an_explicit_current_window_plan() -> String:
	var strategy := StrategyStub.new()
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var dialog := DialogStub.new()
	var features: Array[float] = []
	var handled: bool = resolver.call(
		"_resolve_dialog_step",
		dialog,
		{
			"id": "punk_up",
			"items": ["dark-1", "dark-2", "dark-3", "dark-4", "dark-5"],
			"min_select": 0,
			"max_select": 5,
		},
		{},
		{},
		features
	)
	var checks: Array[String] = [
		assert_true(handled),
		assert_true(dialog.called),
		assert_eq(dialog.indexes, PackedInt32Array()),
	]
	dialog.free()
	return run_checks(checks)


func test_ucis_yes_no_candidates_keep_distinct_official_option_types() -> String:
	var owner := AuthorOwnerScript.new()
	var options: Array = owner.call(
		"_options_for_items",
		[true, false],
		"effect_target",
		{"cabt_select_type_raw": 9, "cabt_select_context_raw": 43}
	)
	return run_checks([
		assert_eq(options.size(), 2),
		assert_eq(int(options[0].get("option_type_raw", -1)), 1),
		assert_eq(int(options[1].get("option_type_raw", -1)), 2),
	])


func test_each_assignment_source_gets_one_fresh_semantic_target_window() -> String:
	var strategy := StrategyStub.new()
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var features: Array[float] = []
	var first: int = resolver.call(
		"_best_legal_target_index", ["current", "backup"], [], {"id": "assign"}, {}, features
	)
	var second: int = resolver.call(
		"_best_legal_target_index", ["current", "backup"], [1], {"id": "assign"}, {}, features
	)
	return run_checks([
		assert_eq(first, 1),
		assert_eq(second, 0),
		assert_eq(strategy.target_calls, 2),
	])


func test_field_slot_switch_uses_explicit_author_window_before_generic_scoring() -> String:
	var strategy := ExplicitFieldStrategyStub.new()
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var step := {
		"id": "self_switch_target",
		"items": ["support", "ready-attacker"],
		"min_select": 1,
		"max_select": 1,
	}
	var field := FieldSlotStub.new()
	field._pending_effect_steps = [step]
	var handled: bool = resolver.call(
		"_resolve_field_slot_step", field, step, {}, {}, [] as Array[float]
	)
	var checks: Array[String] = [
		assert_true(handled),
		assert_eq(strategy.calls, 1),
		assert_eq(field.selected_indexes, [1]),
		assert_true(field.finalized),
	]
	field.free()
	return run_checks(checks)


func test_munkidori_rich_counter_ui_expands_to_fresh_official_count_then_target_windows() -> String:
	var strategy := OfficialCounterWindowStrategy.new()
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var exporter := DecisionExporterStub.new()
	resolver.decision_exporter = exporter
	var scene := CounterDistributionStub.new()
	var targets: Array = [_make_counter_target("Active"), _make_counter_target("Bench")]
	var step := {
		"id": "target_damage_counters",
		"ui_mode": "counter_distribution",
		"total_counters": 3,
		"max_assignments": 1,
		"max_assignments_per_target": 1,
		"allow_partial": true,
		"ucis_counter_count_window": {
			"ucis_context_name": "REMOVE_DAMAGE_COUNTER_COUNT",
			"ucis_option_type_name": "NUMBER",
		},
		"ucis_counter_target_window": {
			"ucis_context_name": "DAMAGE_COUNTER",
			"ucis_option_type_name": "CARD",
		},
	}
	var resolved_count: bool = resolver.call(
		"_resolve_external_counter_distribution_step", scene, step, {}, targets, 3
	)
	var selected_count := int(scene._field_interaction_assignment_selected_source_index)
	var resolved_target: bool = resolver.call(
		"_resolve_external_counter_distribution_step", scene, step, {}, targets, 3
	)
	var first_window: Dictionary = strategy.windows[0] if strategy.windows.size() > 0 else {}
	var second_window: Dictionary = strategy.windows[1] if strategy.windows.size() > 1 else {}
	var assignment: Dictionary = (
		scene._field_interaction_assignment_entries[0]
		if not scene._field_interaction_assignment_entries.is_empty()
		else {}
	)
	var checks: Array[String] = [
		assert_true(resolved_count),
		assert_eq(selected_count, 2, "The official NUMBER window should select two counters without committing a target"),
		assert_true(resolved_target),
		assert_eq(strategy.windows.size(), 2, "Count and target must be two fresh external decisions"),
		assert_eq(first_window.get("select_type_raw"), 8),
		assert_eq(first_window.get("select_context_raw"), 40),
		assert_eq(first_window.get("option_type_raw"), 0),
		assert_eq(first_window.get("numbers"), [1, 2, 3]),
		assert_eq(second_window.get("select_type_raw"), 1),
		assert_eq(second_window.get("select_context_raw"), 13),
		assert_eq(second_window.get("option_type_raw"), 3),
		assert_eq(int(assignment.get("target_index", -1)), 1),
		assert_eq(int(assignment.get("amount", 0)), 20),
		assert_eq(exporter.records.size(), 2, "Count and target must both be present in developer decision evidence"),
		assert_eq(str(exporter.records[0].get("resolution_kind", "")) if exporter.records.size() > 0 else "", "counter_distribution_count"),
		assert_eq(str(exporter.records[1].get("resolution_kind", "")) if exporter.records.size() > 1 else "", "counter_distribution_target"),
	]
	scene.free()
	return run_checks(checks)


func test_generic_counter_distribution_keeps_one_counter_damage_counter_any_windows() -> String:
	var strategy := OfficialCounterWindowStrategy.new()
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var scene := CounterDistributionStub.new()
	var targets: Array = [_make_counter_target("Active"), _make_counter_target("Bench")]
	var step := {
		"id": "generic_damage_counter_distribution",
		"ui_mode": "counter_distribution",
		"total_counters": 2,
	}
	var resolved: bool = resolver.call(
		"_resolve_external_counter_distribution_step", scene, step, {}, targets, 2
	)
	var window: Dictionary = strategy.windows[0] if not strategy.windows.is_empty() else {}
	var assignment: Dictionary = (
		scene._field_interaction_assignment_entries[0]
		if not scene._field_interaction_assignment_entries.is_empty()
		else {}
	)
	var checks: Array[String] = [
		assert_true(resolved),
		assert_eq(strategy.windows.size(), 1),
		assert_eq(window.get("select_type_raw"), 1),
		assert_eq(window.get("select_context_raw"), 14),
		assert_eq(window.get("option_type_raw"), 3),
		assert_eq(window.get("remain_damage_counter"), 2),
		assert_eq(int(assignment.get("target_index", -1)), 1),
		assert_eq(int(assignment.get("amount", 0)), 10),
	]
	scene.free()
	return run_checks(checks)


func _make_counter_target(card_name: String) -> PokemonSlot:
	var data := CardData.new()
	data.name = card_name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 100
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 1))
	return slot


func test_card_assignment_source_has_a_stable_public_prompt_kind() -> String:
	var prompt_kind: String = AuthorOwnerScript._prompt_kind_for_step(
		{
			"id": "marnies_punk_up_assignments",
			"ui_mode": "card_assignment",
			"source_card_indices": [0, 1, 2, 3, 4],
		}
	)
	return assert_eq(prompt_kind, "assignment_source")


func test_full_library_search_shape_has_a_stable_public_prompt_kind() -> String:
	var prompt_kind: String = AuthorOwnerScript._prompt_kind_for_step(
		{
			"id": "csv9c_fan_call_cards",
			"title": "Choose up to 3 Colorless Pokemon",
			"items": ["hoothoot"],
			"card_items": ["hoothoot"],
			"card_indices": [17],
			"visible_scope": "own_full_deck",
			"min_select": 0,
			"max_select": 3,
		}
	)
	return assert_eq(prompt_kind, "search")


func test_public_attached_energy_discard_has_a_stable_source_prompt_kind() -> String:
	var prompt_kind: String = AuthorOwnerScript._prompt_kind_for_step(
		{
			"id": "discard_basic_energy",
			"title": "Choose Basic Energy to discard",
			"items": ["grass-energy", "fighting-energy"],
			"card_items": ["grass-energy", "fighting-energy"],
			"card_groups": [{"energy_indices": [0, 1]}],
			"min_select": 0,
			"max_select": 2,
		}
	)
	return assert_eq(prompt_kind, "assignment_source")


func test_self_switch_field_slot_has_a_stable_public_prompt_kind() -> String:
	var prompt_kind: String = AuthorOwnerScript._prompt_kind_for_step({
		"id": "self_switch_target",
		"ui_mode": "field_slot",
		"items": ["support", "ready-attacker"],
		"min_select": 1,
		"max_select": 1,
	})
	return run_checks([
		assert_eq(prompt_kind, "self_switch"),
		assert_eq(AuthorOwnerScript._option_kind_for_prompt(prompt_kind), "send_out"),
	])


func test_author_legality_builder_never_preselects_public_interaction_suffixes() -> String:
	var builder := AuthorOwnerScript.LegalityOnlyActionBuilder.new()
	return run_checks([
		assert_false(builder._can_headless_auto_resolve_steps([
			{"id": "discard", "min_select": 2, "max_select": 2},
			{"id": "search", "min_select": 1, "max_select": 1},
		], false)),
		assert_true(builder._can_headless_auto_resolve_steps([], false)),
	])
