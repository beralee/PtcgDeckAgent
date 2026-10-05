extends "res://tests/ptcgdap/godot/test_author_public_attack_cost.gd"

const DecisionScript = preload("res://scripts/ai/ptcgdap/public/PublicDecisionFacts.gd")


class ExtraHP extends BaseEffect:
	func get_hp_modifier(_slot: PokemonSlot, _state: GameState) -> int:
		return 50


class SuppressEnergy extends BaseEffect:
	func suppresses_special_energy_effects() -> bool:
		return true


func _decision_fixture(uid: String = "CSV8C_159", energies: Array = []) -> Dictionary:
	var state := _state(uid, energies, 6, false, 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	for player: PlayerState in state.players:
		gsm.effect_processor.register_pokemon_card(player.active_pokemon.get_card_data())
	var owner: RefCounted = OriginalOwner.new()
	owner.set("_gsm", gsm)
	owner.set("player_index", 0)
	owner.set("_external_decision_port", RefCounted.new())
	var result := {"owner": owner, "gsm": gsm, "state": state, "slot": state.players[0].active_pokemon}
	_register_snapshot(result)
	return result


func _register_snapshot(f: Dictionary) -> void:
	# Fixture setup only: each synthetic inventory is sealed before projection.
	var registry := preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd").new()
	f.owner.set("_serial_registry", registry)
	f.owner.set("_match_generation", registry.get_match_generation())
	var counts: Array[int] = []
	for player: PlayerState in f.state.players:
		counts.append(f.owner._collect_player_cards(player).size())
		for card: CardInstance in f.owner._collect_player_cards(player):
			registry.register_card(card, player.player_index)
	registry.seal_card_inventory(counts)
	f.owner._sync_public_pokemon_entities()


func test_effective_hp_is_consistent_on_board_and_options_with_suppression() -> String:
	var f := _decision_fixture()
	var tool := _filler(0)
	tool.card_data.effect_id = "decision_hp"
	f.gsm.effect_processor.register_effect("decision_hp", ExtraHP.new())
	f.slot.attached_tool = tool
	f.slot.damage_counters = 30
	var row: Dictionary = f.owner._public_slot(f.slot)
	var opt: Dictionary = f.owner._make_option(0, f.slot, "effect_target", {})
	var checks: Array[String] = [
		assert_eq(row.remaining_hp, row.max_hp - 30),
		assert_eq(opt.target_remaining_hp, row.max_hp - 30),
	]
	var stadium := _filler(0)
	stadium.card_data.effect_id = "decision_suppress"
	f.gsm.effect_processor.register_effect("decision_suppress", SuppressTools.new())
	f.state.stadium_card = stadium
	f.state.stadium_owner_index = 0
	var suppressed: Dictionary = f.owner._public_slot(f.slot)
	checks.append(assert_eq(suppressed.remaining_hp, row.remaining_hp - 50))
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_each_attack_cost_is_distinct_and_does_not_claim_current_legality() -> String:
	var f := _decision_fixture("CSV8C_159", [FIRE])
	var before: Dictionary = f.owner._public_decision_entity(f.slot, 0)
	f.slot.attached_energy.append(CardInstance.create(_card("CSVE1C_PSY"), 0))
	_register_snapshot(f)
	f.slot.set_status("asleep", true)
	var after: Dictionary = f.owner._public_decision_entity(f.slot, 0)
	var checks: Array[String] = [
		assert_false(before.attacks[1].energy_ready), assert_eq(before.attacks[1].energy_debt, 1),
		assert_true(after.attacks[1].energy_ready), assert_eq(after.attacks[1].energy_debt, 0),
		assert_true("asleep" in after.conditions),
		assert_false(f.gsm.rule_validator.can_use_attack(f.state, 0, 1, f.gsm.effect_processor)),
	]
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_special_energy_supply_and_ability_usage_reproject() -> String:
	var f := _decision_fixture(BEAR, ["CSNC_024"])
	var before: Dictionary = f.owner._public_decision_entity(f.slot, 0)
	var stadium := _filler(0)
	stadium.card_data.effect_id = "decision_suppress_energy"
	f.gsm.effect_processor.register_effect("decision_suppress_energy", SuppressEnergy.new())
	f.state.stadium_card = stadium
	f.slot.mark_ability_used(f.state.turn_number)
	var after: Dictionary = f.owner._public_decision_entity(f.slot, 0)
	var checks: Array[String] = [
		assert_eq(before.energies.size(), 1), assert_eq(before.energies[0].units, 2),
		assert_eq(before.retreat_energy_units, 2), assert_eq(after.energies[0].units, 1),
		assert_eq(after.energies[0].types, ["C"]),
		assert_false(before.ability_use_recorded_this_turn), assert_true(after.ability_use_recorded_this_turn),
	]
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_catalog_energy_supply_satisfies_public_contract() -> String:
	var checks: Array[String] = []
	var checked := 0
	for filename: String in DirAccess.get_files_at("res://data/bundled_user/cards"):
		if not filename.ends_with(".json"): continue
		var card := _card(filename.trim_suffix(".json"))
		if not card.card_type.contains("Energy"): continue
		var f := _decision_fixture(BEAR, [filename.trim_suffix(".json")])
		var state: Dictionary = f.owner._build_public_state()
		checks.append(assert_false(DecisionScript.decision_error(state), "Energy projection: " + filename))
		checked += 1
	checks.append(assert_true(checked >= 36, "Cover all current catalog energy printings"))
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_schema_rejects_trailing_newline_in_cost_identity() -> String:
	var f := _decision_fixture()
	var state: Dictionary = f.owner._build_public_state()
	state.decision.entities[0].attacks[0].cost_candidates = ["C\n"]
	var checks: Array[String] = [assert_true(DecisionScript.decision_error(state))]
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_evolution_markers_public_zones_and_live_selection_budgets() -> String:
	var f := _decision_fixture()
	f.slot.turn_evolved = f.state.turn_number
	f.slot.turn_played = f.state.turn_number - 1
	f.state.players[1].lost_zone.append(_filler(1))
	f.state.vstar_power_used[1] = true
	_register_snapshot(f)
	var opt: Dictionary = f.owner._make_option(0, f.slot, "effect_target", {})
	var raw := {"type": 1, "context": 25, "remainEnergyCost": 2}
	f.owner._add_public_assignment_limits(raw, {"max_assignments": 2, "max_assignments_per_target": 1, "allow_partial": true})
	var frame: Dictionary = f.owner._build_frame("effect_target", [opt], 1, 1,
		raw)
	var d: Dictionary = frame.public_state.decision
	var checks: Array[String] = [
		assert_false(DecisionScript.decision_error(frame.public_state)),
		assert_eq(d.opponent.lost_zone.size(), 1), assert_true(d.opponent.vstar_used),
		assert_true(d.entities[0].evolved_this_turn), assert_false(d.entities[0].played_this_turn),
		assert_eq(d.selection.remaining_energy_cost, 2), assert_eq(d.selection.remaining_damage_counters, null),
		assert_eq(d.selection.max_assignments_per_target, 1), assert_true(d.selection.allow_partial),
		assert_eq(DecisionScript.fact(frame, opt, "decision.option.target.evolved_this_turn"), true),
	]
	var export_path := OS.get_environment("PTCG_DECISION_FRAME_OUTPUT")
	var runtime := preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")
	var cache: Dictionary = runtime._frame_fact_cache(frame)
	var fact_values := {}
	for name: String in DecisionScript.FACT_TYPES:
		var ordinary: Variant = runtime._fact(name, frame, opt, {}, {}, null)
		var cached: Variant = runtime._fact_cached(name, cache, opt, {}, {}, null)
		checks.append(assert_eq(ordinary, cached, "Both runtime paths: " + name))
		checks.append(assert_true(runtime.SCALAR_FACTS.has(name), "Registered fact: " + name))
		checks.append(assert_eq(runtime.NON_NUMERIC_FACTS.has(name), DecisionScript.FACT_TYPES[name] != "integer", "Fact type: " + name))
		fact_values[name] = ordinary
	if not export_path.is_empty():
		var file := FileAccess.open(export_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(frame, "\t"))
		file.close()
		file = FileAccess.open(export_path + ".facts.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(fact_values, "\t"))
		file.close()
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_hidden_identities_cannot_change_decision_extension() -> String:
	var f := _decision_fixture(BEAR, [WATER])
	f.state.players[1].hand.append(_filler(1))
	_register_snapshot(f)
	var before: Dictionary = f.owner._build_public_state()
	for seat: int in [0, 1]:
		for zone: Array in [f.state.players[seat].deck, f.state.players[seat].prizes]:
			for card: CardInstance in zone: card.card_data = _card(FIRE)
	f.state.players[1].hand[0].card_data = _card(FIRE)
	var after: Dictionary = f.owner._build_public_state()
	var checks: Array[String] = [assert_eq(before, after), assert_false(DecisionScript.decision_error(after))]
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)
