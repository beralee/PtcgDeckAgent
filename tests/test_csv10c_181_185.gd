class_name TestCSV10C181To185
extends TestBase


const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 300
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _card(name: String, card_type: String = "Item", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 28
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func test_csv10c_181_to_185_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(181, 186):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_effect(cards["181"].effect_id), "CSV10C_181 should register the conditional free-cost Ability"),
		assert_true(processor.has_attack_effect(cards["181"].effect_id), "CSV10C_181 should register Confusion"),
		assert_true(processor.has_attack_effect(cards["182"].effect_id), "CSV10C_182 should register pre-damage Tool discard"),
		assert_true(processor.has_effect(cards["183"].effect_id), "CSV10C_183 should register its evolve-triggered recovery Ability"),
		assert_true(processor.has_attack_effect(cards["184"].effect_id), "CSV10C_184 should register outgoing damage reduction"),
		assert_false(processor.has_effect(cards["185"].effect_id) or processor.has_attack_effect(cards["185"].effect_id), "CSV10C_185 should remain numeric-only"),
	])


func test_csv10c_181_cost_is_free_only_when_hand_sizes_match_and_attack_confuses() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var noivern := _slot(_load_card("181"))
	state.players[0].active_pokemon = noivern
	state.players[0].hand = [_card("Own")]
	state.players[1].hand = [_card("Opponent", "Item", 1)]
	processor.register_pokemon_card(noivern.get_card_data())
	var attack: Dictionary = noivern.get_card_data().attacks[0]
	var equal_modifier := processor.get_attack_any_cost_modifier(noivern, attack, state)
	state.players[1].hand.append(_card("Opponent Extra", "Item", 1))
	var unequal_modifier := processor.get_attack_any_cost_modifier(noivern, attack, state)
	processor.execute_attack_effect(noivern, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(equal_modifier, -3, "CSV10C_181 should remove all 3 Colorless costs when hand counts match"),
		assert_eq(unequal_modifier, 0, "CSV10C_181 should not reduce cost when hand counts differ"),
		assert_true(state.players[1].active_pokemon.status_conditions.get("confused", false), "CSV10C_181 attack should Confuse the opponent Active Pokemon"),
	])


func test_csv10c_182_discards_the_opponent_active_tool_in_the_pre_damage_hook() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var greedent := _slot(_load_card("182"))
	state.players[0].active_pokemon = greedent
	var tool := _card("Defensive Tool", "Tool", 1)
	var unprotected := state.players[1].active_pokemon
	unprotected.attached_tool = tool
	processor.register_pokemon_card(greedent.get_card_data())
	processor.execute_before_attack_damage_effects(greedent, 0, state.players[1].active_pokemon, state)
	var protected := _pokemon("Mist-Protected Active", 1)
	var protected_tool := _card("Protected Tool", "Tool", 1)
	var mist := _card("Mist Energy", "Special Energy", 1)
	mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected.attached_tool = protected_tool
	protected.attached_energy = [mist]
	state.players[1].active_pokemon = protected
	processor.execute_before_attack_damage_effects(greedent, 0, protected, state)
	return run_checks([
		assert_eq(unprotected.attached_tool, null, "CSV10C_182 should remove the Tool before damage is calculated"),
		assert_true(tool in state.players[1].discard_pile, "CSV10C_182 should put the Tool in its owner's discard pile"),
		assert_eq(protected.attached_tool, protected_tool, "CSV10C_182 should respect Mist Energy attack-effect protection"),
	])


func test_csv10c_183_recovers_up_to_two_arven_sandwiches_only_after_hand_evolution() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var greedent := _slot(_load_card("183"))
	state.players[0].active_pokemon = greedent
	var chinese := _card("派帕的三明治")
	var english := _card("Arven's Sandwich")
	var unrelated := _card("Other Item")
	state.players[0].discard_pile = [chinese, english, unrelated]
	processor.register_pokemon_card(greedent.get_card_data())
	var blocked_before_evolution := not processor.can_use_ability(greedent, state)
	H.mark_evolved_from_hand(greedent, state)
	var used := processor.execute_ability_effect(greedent, 0, [{"csv10c_arven_sandwiches": [english, chinese]}], state)
	var zero_state := _state()
	var zero_greedent := _slot(_load_card("183"))
	zero_state.players[0].active_pokemon = zero_greedent
	zero_state.players[0].discard_pile = [_card("派帕的三明治")]
	H.mark_evolved_from_hand(zero_greedent, zero_state)
	processor.execute_ability_effect(zero_greedent, 0, [{"csv10c_arven_sandwiches": []}], zero_state)
	return run_checks([
		assert_true(blocked_before_evolution, "CSV10C_183 should not trigger without hand evolution"),
		assert_true(used, "CSV10C_183 should resolve after evolving from hand"),
		assert_true(chinese in state.players[0].hand and english in state.players[0].hand, "CSV10C_183 should recover both selected Sandwich cards"),
		assert_true(unrelated in state.players[0].discard_pile, "CSV10C_183 should not recover unrelated cards"),
		assert_true(zero_greedent.has_ability_used(zero_state.turn_number), "CSV10C_183 should consume its once-only evolve trigger after choosing zero cards"),
	])


func test_csv10c_184_reduces_only_the_affected_pokemons_next_turn_outgoing_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var rookidee := _slot(_load_card("184"))
	var affected := state.players[1].active_pokemon
	state.players[0].active_pokemon = rookidee
	processor.register_pokemon_card(rookidee.get_card_data())
	processor.execute_attack_effect(rookidee, 0, affected, state)
	state.turn_number += 1
	var affected_modifier := processor.get_attacker_modifier(affected, state, rookidee)
	var unaffected := _pokemon("Unaffected", 1)
	state.players[1].bench = [unaffected]
	var unaffected_modifier := processor.get_attacker_modifier(unaffected, state, rookidee)
	var protected := _pokemon("Mist-Protected", 1)
	var mist := _card("Mist Energy", "Special Energy", 1)
	mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected.attached_energy = [mist]
	state.turn_number -= 1
	processor.execute_attack_effect(rookidee, 0, protected, state)
	state.turn_number += 1
	var protected_modifier := processor.get_attacker_modifier(protected, state, rookidee)
	return run_checks([
		assert_eq(affected_modifier, -20, "CSV10C_184 should reduce the affected Pokemon's outgoing damage by 20 next turn"),
		assert_eq(unaffected_modifier, 0, "CSV10C_184 should not reduce another Pokemon's damage"),
		assert_eq(protected_modifier, 0, "CSV10C_184 should respect Mist Energy attack-effect protection"),
	])
