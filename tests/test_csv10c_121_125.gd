class_name TestCSV10C121To125
extends TestBase


class TailsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(false)
		return false


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, stage: String = "Basic", energy_type: String = "D", evolves_from: String = "", has_ability: bool = false) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.energy_type = energy_type
	card.evolves_from = evolves_from
	card.hp = 150
	card.attacks = [{"name": "Fixture Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	if has_ability:
		card.abilities = [{"name": "Fixture Ability", "text": ""}]
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 6
	state.current_player_index = 0
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_121_to_125_registry_contract() -> String:
	var processor := EffectProcessor.new(TailsCoinFlipper.new())
	var cards: Dictionary = {}
	for number: int in range(121, 126):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_effect(cards["121"].effect_id), "CSV10C_121 should register Glare"),
		assert_true(processor.has_attack_effect(cards["121"].effect_id), "CSV10C_121 should register Tail Spin"),
		assert_true(processor.has_attack_effect(cards["122"].effect_id), "CSV10C_122 should register coin-fail damage"),
		assert_true(processor.has_attack_effect(cards["123"].effect_id), "CSV10C_123 should register multi-Pokemon deck evolution"),
		assert_true(processor.has_attack_effect(cards["124"].effect_id), "CSV10C_124 should register Nidoking bench bonus"),
		assert_false(processor.has_attack_effect(cards["125"].effect_id), "CSV10C_125 is numeric-only"),
	])


func test_csv10c_121_blocks_only_non_rocket_ability_pokemon_and_hits_all_opponents() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("121")
	var arbok := _slot(card)
	state.players[0].active_pokemon = arbok
	var opponent_bench := _slot(_pokemon("Opponent Bench"), 1)
	state.players[1].bench = [opponent_bench]
	processor.register_pokemon_card(card)
	var ability := processor.get_effect(card.effect_id)
	var blocked := CardInstance.create(_pokemon("Generic Ability Pokemon", "Basic", "P", "", true), 1)
	var rocket := CardInstance.create(_pokemon("火箭队的能力宝可梦", "Basic", "D", "", true), 1)
	var no_ability := CardInstance.create(_pokemon("Generic Plain Pokemon", "Basic", "P"), 1)
	var blocks_generic := bool(ability.call("blocks_card_from_hand", arbok, blocked, 1, state)) if ability != null else false
	var blocks_rocket := bool(ability.call("blocks_card_from_hand", arbok, rocket, 1, state)) if ability != null else true
	var blocks_plain := bool(ability.call("blocks_card_from_hand", arbok, no_ability, 1, state)) if ability != null else true
	processor.execute_attack_effect(arbok, 0, state.players[1].active_pokemon, state)
	return run_checks([
		assert_true(blocks_generic, "CSV10C_121 Glare should block opposing non-Rocket Pokemon with Abilities from hand"),
		assert_false(blocks_rocket, "CSV10C_121 Glare should exempt Team Rocket's Pokemon"),
		assert_false(blocks_plain, "CSV10C_121 Glare should not block Pokemon without Abilities"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 30, "CSV10C_121 Tail Spin should damage the opponent Active by 30"),
		assert_eq(opponent_bench.damage_counters, 30, "CSV10C_121 Tail Spin should damage every opponent Benched Pokemon by 30"),
	])


func test_csv10c_122_tails_cancels_attack_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new(TailsCoinFlipper.new())
	var card := _load_card("122")
	var attacker := _slot(card)
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var canceled := false
	for effect: BaseEffect in effects:
		if effect.has_method("cancels_attack_damage"):
			canceled = bool(effect.call("cancels_attack_damage", attacker, state.players[1].active_pokemon, 0, state))
	return assert_true(canceled, "CSV10C_122 Sneak Attack should do no damage on tails")


func test_csv10c_123_evolves_up_to_two_selected_darkness_pokemon_from_full_deck() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("123")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	var dark_bench := _slot(_pokemon("Dark Bench", "Basic", "D"))
	var fire_bench := _slot(_pokemon("Fire Bench", "Basic", "R"))
	state.players[0].bench = [dark_bench, fire_bench]
	var attacker_evo := CardInstance.create(_pokemon("火箭队的尼多后", "Stage 2", "D", card.name), 0)
	var dark_evo := CardInstance.create(_pokemon("Dark Evolution", "Stage 1", "D", "Dark Bench"), 0)
	var illegal := CardInstance.create(_pokemon("Illegal Evolution", "Stage 1", "D", "Fire Bench"), 0)
	state.players[0].deck = [attacker_evo, illegal, dark_evo]
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var first_steps: Array[Dictionary] = []
	if not effects.is_empty():
		first_steps = effects[0].get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state)
	var context := {"csv10c_dark_evolution_targets": [attacker, dark_bench]}
	var followup: Array[Dictionary] = []
	if not effects.is_empty():
		followup = effects[0].get_followup_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state, context)
	context["csv10c_dark_evolution_cards"] = [attacker_evo, dark_evo]
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [context])
	return run_checks([
		assert_eq(first_steps[0].get("items", []) if not first_steps.is_empty() else [], [attacker, dark_bench], "CSV10C_123 should enable only own Darkness Pokemon that can evolve"),
		assert_eq(followup[0].get("card_indices", []) if not followup.is_empty() else [], [0, -1, 1], "CSV10C_123 should reveal the full deck and enable only evolutions for selected targets"),
		assert_eq(attacker.get_card_data().name, "火箭队的尼多后", "CSV10C_123 should evolve the selected Active Darkness Pokemon"),
		assert_eq(dark_bench.get_card_data().name, "Dark Evolution", "CSV10C_123 should evolve the selected Benched Darkness Pokemon"),
		assert_true(illegal in state.players[0].deck, "CSV10C_123 should leave unrelated evolutions in deck"),
	])


func test_csv10c_124_requires_nidoking_on_own_bench() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("124")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	processor.register_pokemon_card(card)
	state.players[0].bench = [_slot(_pokemon("火箭队的尼多王ex"))]
	var with_nidoking := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 0):
		if effect.has_method("get_damage_bonus"):
			with_nidoking += int(effect.call("get_damage_bonus", attacker, state))
	state.players[0].bench = [_slot(_pokemon("Unrelated Bench"))]
	var without_nidoking := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 0):
		if effect.has_method("get_damage_bonus"):
			without_nidoking += int(effect.call("get_damage_bonus", attacker, state))
	return run_checks([
		assert_eq(with_nidoking, 120, "CSV10C_124 Love Impact should add 120 with Nidoking on the own Bench"),
		assert_eq(without_nidoking, 0, "CSV10C_124 Love Impact should not bonus without Nidoking"),
	])
