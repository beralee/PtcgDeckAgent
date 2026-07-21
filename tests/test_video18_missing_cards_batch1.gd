class_name TestVideo18MissingCardsBatch1
extends TestBase

const CARD_REFS := ["SVP_080", "CSV4C_074", "CSV8C_056", "CSV8C_154", "CSV2C_125"]
const EFFECT_NACLI := "f0453eea8a2c67c4034c82adf034fc84"
const EFFECT_GARGANACL := "73c1d28d980ebe98f205db87eb647fe8"
const EFFECT_FEEBAS := "d7fd6b6e4df58df509e15a929754b2fe"
const EFFECT_TURTONATOR := "5924d0f73f2e04f4cd258136ea138594"
const EFFECT_TEAM_STAR_GRUNT := "b54276b42598426febfe34bb67d5f075"


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _pokemon(name: String, owner: int = 0, mechanic: String = "") -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.mechanic = mechanic
	card_data.hp = 300
	return _slot(card_data, owner)


func _energy(name: String, owner: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Basic Energy"
	card_data.energy_type = "F"
	card_data.energy_provides = "F"
	return CardInstance.create(card_data, owner)


func _item(name: String, owner: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Item"
	return CardInstance.create(card_data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 8
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func _script_name(effect: BaseEffect) -> String:
	if effect == null or effect.get_script() == null:
		return ""
	return str(effect.get_script().resource_path).get_file()


func test_batch1_cards_are_bundled_with_images_and_manifest_entries() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for ref: String in CARD_REFS:
		var card := _load_card(ref)
		checks.append(assert_not_null(card, "%s should load from the bundled card pool" % ref))
		if card == null:
			continue
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [card.set_code, card.card_index]
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s should bundle its card image" % ref))
		checks.append(assert_str_contains(manifest, "cards/%s.json" % ref, "%s JSON should be in the bundle manifest" % ref))
		checks.append(assert_str_contains(manifest, "cards/images/%s/%s.png.bin" % [card.set_code, card.card_index], "%s image should be in the bundle manifest" % ref))
	return run_checks(checks)


func test_nacli_corner_locks_only_the_first_attack_defender_from_retreating() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var nacli := _slot(_load_card("SVP_080"), 0)
	state.players[0].active_pokemon = nacli
	state.players[1].active_pokemon.attached_energy.append(_energy("Fighting", 1))
	state.players[1].bench = [_pokemon("Backup", 1)]
	processor.register_pokemon_card(nacli.get_card_data())
	var effects := processor.get_attack_effects_for_slot(nacli, 0)
	if effects.is_empty():
		return "SVP_080 should register Corner's retreat-lock effect"
	processor.execute_attack_effect(nacli, 0, state.players[1].active_pokemon, state)
	state.turn_number += 1
	state.current_player_index = 1
	return run_checks([
		assert_eq(_script_name(effects[0]), "AttackDefenderRetreatLockNextTurn.gd", "SVP_080 should reuse the audited retreat-lock effect"),
		assert_false(RuleValidator.new().can_retreat(state, 1, processor), "Corner should prevent the affected Defending Pokemon from retreating next turn"),
	])


func test_garganacl_blessed_salt_heals_each_own_pokemon_and_knocking_hammer_mills_one() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var garganacl := _slot(_load_card("CSV4C_074"), 0)
	var own_bench := _pokemon("Own Bench", 0)
	var opponent_bench := _pokemon("Opponent Bench", 1)
	garganacl.damage_counters = 50
	own_bench.damage_counters = 30
	state.players[0].active_pokemon = garganacl
	state.players[0].bench = [own_bench]
	state.players[1].active_pokemon.damage_counters = 40
	state.players[1].bench = [opponent_bench]
	var top := _item("Top", 1)
	var second := _item("Second", 1)
	state.players[1].deck = [top, second]
	processor.register_pokemon_card(garganacl.get_card_data())
	var ability := processor.get_effect(EFFECT_GARGANACL)
	var attacks := processor.get_attack_effects_for_slot(garganacl, 0)
	if ability == null or attacks.is_empty():
		return "CSV4C_074 should register Blessed Salt and Knocking Hammer"
	processor.process_pokemon_check(state)
	processor.execute_attack_effect(garganacl, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(garganacl.damage_counters, 30, "Blessed Salt should heal 20 damage from Garganacl"),
		assert_eq(own_bench.damage_counters, 10, "Blessed Salt should heal 20 damage from every other own Pokemon"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 40, "Blessed Salt should not heal the opponent"),
		assert_eq(_script_name(attacks[0]), "AttackMillOpponentDeck.gd", "Knocking Hammer should reuse the audited opponent-mill effect"),
		assert_eq(state.players[1].discard_pile, [top], "Knocking Hammer should discard exactly the opponent's top card"),
		assert_eq(state.players[1].deck, [second], "Knocking Hammer should leave the remaining deck in order"),
	])


func test_feebas_leap_out_exposes_and_uses_the_explicit_bench_choice() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var feebas := _slot(_load_card("CSV8C_056"), 0)
	var first := _pokemon("First Bench", 0)
	var selected := _pokemon("Selected Bench", 0)
	state.players[0].active_pokemon = feebas
	state.players[0].bench = [first, selected]
	processor.register_pokemon_card(feebas.get_card_data())
	var effects := processor.get_attack_effects_for_slot(feebas, 0)
	if effects.is_empty():
		return "CSV8C_056 should register Leap Out's self-switch effect"
	var steps := effects[0].get_attack_interaction_steps(feebas.get_top_card(), feebas.get_card_data().attacks[0], state)
	processor.execute_attack_effect(feebas, 0, state.players[1].active_pokemon, state, [{"switch_target": [selected]}])
	return run_checks([
		assert_eq(_script_name(effects[0]), "AttackSwitchSelfToBench.gd", "CSV8C_056 should reuse the audited self-switch effect"),
		assert_eq(steps.size(), 1, "Leap Out should expose one required battlefield choice"),
		assert_eq(str(steps[0].get("id", "")), "switch_target", "Leap Out should use the shared switch-target interaction contract"),
		assert_eq(steps[0].get("items", []), [first, selected], "Leap Out should expose all legal Benched Pokemon"),
		assert_eq(state.players[0].active_pokemon, selected, "Leap Out should promote the explicitly selected Benched Pokemon"),
		assert_eq(state.players[0].bench[1], feebas, "Leap Out should move Feebas into the selected Bench slot"),
	])


func test_turtonator_fully_singe_discards_selected_energy_only_from_active_pokemon_ex() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var turtonator := _slot(_load_card("CSV8C_154"), 0)
	var active_ex := _pokemon("Active ex", 1, "ex")
	var first_energy := _energy("First Energy", 1)
	var selected_energy := _energy("Selected Energy", 1)
	active_ex.attached_energy = [first_energy, selected_energy]
	state.players[0].active_pokemon = turtonator
	state.players[1].active_pokemon = active_ex
	processor.register_pokemon_card(turtonator.get_card_data())
	var effects := processor.get_attack_effects_for_slot(turtonator, 0)
	if effects.is_empty():
		return "CSV8C_154 should register Fully Singe's conditional Energy discard"
	var steps := effects[0].get_attack_interaction_steps(turtonator.get_top_card(), turtonator.get_card_data().attacks[0], state)
	processor.execute_attack_effect(turtonator, 0, active_ex, state, [{"target_energy": [selected_energy]}])
	return run_checks([
		assert_eq(steps.size(), 1, "Fully Singe should request one Energy when the opponent's Active is a Pokemon ex"),
		assert_eq(steps[0].get("items", []), [first_energy, selected_energy], "Fully Singe should expose only Energy on the opponent's Active Pokemon ex"),
		assert_eq(active_ex.attached_energy, [first_energy], "Fully Singe should remove the explicitly selected Energy"),
		assert_eq(state.players[1].discard_pile, [selected_energy], "Fully Singe should discard the explicitly selected Energy"),
	])


func test_turtonator_fully_singe_has_no_effect_against_a_non_ex_active() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var turtonator := _slot(_load_card("CSV8C_154"), 0)
	var plain_active := _pokemon("Plain Active", 1)
	var energy := _energy("Energy", 1)
	plain_active.attached_energy = [energy]
	state.players[0].active_pokemon = turtonator
	state.players[1].active_pokemon = plain_active
	processor.register_pokemon_card(turtonator.get_card_data())
	var effects := processor.get_attack_effects_for_slot(turtonator, 0)
	if effects.is_empty():
		return "CSV8C_154 should register Fully Singe's conditional Energy discard"
	var steps := effects[0].get_attack_interaction_steps(turtonator.get_top_card(), turtonator.get_card_data().attacks[0], state)
	processor.execute_attack_effect(turtonator, 0, plain_active, state)
	return run_checks([
		assert_true(steps.is_empty(), "Fully Singe should not prompt against a non-ex Active Pokemon"),
		assert_eq(plain_active.attached_energy, [energy], "Fully Singe should not discard Energy from a non-ex Active Pokemon"),
		assert_true(state.players[1].discard_pile.is_empty(), "Fully Singe should leave the discard pile unchanged against a non-ex"),
		assert_true(processor.get_attack_effects_for_slot(turtonator, 1).is_empty(), "Steaming Stomp should remain numeric-only"),
	])


func test_team_star_grunt_moves_selected_active_energy_to_opponent_deck_top() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var grunt_data := _load_card("CSV2C_125")
	var grunt := CardInstance.create(grunt_data, 0)
	var first_energy := _energy("First Energy", 1)
	var selected_energy := _energy("Selected Energy", 1)
	var old_top := _item("Old Top", 1)
	state.players[1].active_pokemon.attached_energy = [first_energy, selected_energy]
	state.players[1].deck = [old_top]
	var effect := processor.get_effect(EFFECT_TEAM_STAR_GRUNT)
	if effect == null:
		return "CSV2C_125 should register Team Star Grunt by effect_id"
	var steps := effect.get_interaction_steps(grunt, state)
	var executed: bool = processor.execute_card_effect(grunt, [{"target_energy": [selected_energy]}], state)
	return run_checks([
		assert_true(effect.can_execute(grunt, state), "Team Star Grunt should be playable while the opponent's Active has Energy"),
		assert_eq(steps.size(), 1, "Team Star Grunt should request one attached Energy"),
		assert_eq(steps[0].get("items", []), [first_energy, selected_energy], "Team Star Grunt should expose only the opponent's Active Energy"),
		assert_true(executed, "Team Star Grunt should execute through EffectProcessor"),
		assert_eq(state.players[1].active_pokemon.attached_energy, [first_energy], "Team Star Grunt should remove the selected Energy from the Active Pokemon"),
		assert_eq(state.players[1].deck, [selected_energy, old_top], "Team Star Grunt should put the selected Energy on top of the opponent's deck"),
	])


func test_team_star_grunt_cannot_execute_without_active_energy() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var grunt := CardInstance.create(_load_card("CSV2C_125"), 0)
	var benched_energy := _energy("Benched Energy", 1)
	state.players[1].bench = [_pokemon("Opponent Bench", 1)]
	state.players[1].bench[0].attached_energy = [benched_energy]
	var effect := processor.get_effect(EFFECT_TEAM_STAR_GRUNT)
	if effect == null:
		return "CSV2C_125 should register Team Star Grunt by effect_id"
	return run_checks([
		assert_false(effect.can_execute(grunt, state), "Team Star Grunt should require Energy on the opponent's Active Pokemon"),
		assert_true(effect.get_interaction_steps(grunt, state).is_empty(), "Team Star Grunt should not expose Benched Energy"),
	])
