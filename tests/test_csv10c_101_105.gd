class_name TestCSV10C101To105
extends TestBase


class RiggedCoinFlipper extends CoinFlipper:
	var results: Array[bool] = []

	func _init(values: Array[bool]) -> void:
		results = values.duplicate()

	func flip() -> bool:
		var result: bool = bool(results.pop_front()) if not results.is_empty() else false
		coin_flipped.emit(result)
		return result


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, stage: String = "Basic", card_type: String = "Pokemon") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.stage = stage
	card.hp = 120
	card.attacks = [{"name": "Fixture Attack", "cost": "C", "damage": "30", "text": "", "is_vstar_power": false}]
	return card


func _energy(name: String = "Fighting Energy", symbol: String = "F") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return card


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		var active := PokemonSlot.new()
		active.pokemon_stack.append(CardInstance.create(_pokemon("Fixture Active %d" % player_index), player_index))
		active.turn_played = 0
		player.active_pokemon = active
		state.players.append(player)
	return state


func _slot(card: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot


func test_csv10c_101_to_105_registry_contract() -> String:
	var processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	var cards: Dictionary = {}
	for number: int in range(101, 106):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_not_null(cards["101"], "CSV10C_101 should load from the bundled source of truth"),
		assert_true(processor.has_attack_effect(cards["101"].effect_id), "CSV10C_101 should register retreat-lock and coin-copy attacks"),
		assert_true(processor.has_attack_effect(cards["102"].effect_id), "CSV10C_102 should keep the existing Call for Family registration"),
		assert_false(processor.has_attack_effect(cards["103"].effect_id), "CSV10C_103 is numeric-only and should not gain a scripted effect"),
		assert_true(processor.has_effect(cards["104"].effect_id), "CSV10C_104 should register Mammoth Hauling"),
		assert_true(processor.has_attack_effect(cards["104"].effect_id), "CSV10C_104 should register Rumbling March"),
		assert_true(processor.has_attack_effect(cards["105"].effect_id), "CSV10C_105 should register its heads-only Energy discard"),
	])


func test_csv10c_101_coin_copy_and_retreat_lock_semantics() -> String:
	var state := _state()
	var processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	var card := _load_card("101")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	processor.register_pokemon_card(card)

	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state)
	var retreat_locked := state.players[1].active_pokemon.effects.any(
		func(effect: Dictionary) -> bool: return str(effect.get("type", "")).contains("retreat")
	)
	var copy_effect: BaseEffect = null
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 1):
		if not effect.get_attack_preview_interaction_steps(attacker.get_top_card(), card.attacks[1], state).is_empty():
			copy_effect = effect
			break
	var first_steps: Array[Dictionary] = []
	if copy_effect != null:
		first_steps = copy_effect.get_attack_interaction_steps(attacker.get_top_card(), card.attacks[1], state)
	var result_context := {str(first_steps[0].get("id", "")): first_steps[0].get("items", [])} if not first_steps.is_empty() else {}
	var followup: Array[Dictionary] = []
	if copy_effect != null:
		followup = copy_effect.get_followup_attack_interaction_steps(attacker.get_top_card(), card.attacks[1], state, result_context)
	var copy_options: Array = followup[0].get("items", []) if not followup.is_empty() else []
	if copy_effect != null and not copy_options.is_empty():
		var context := result_context.duplicate(true)
		context[str(followup[0].get("id", ""))] = [copy_options[0]]
		copy_effect.set_attack_interaction_context([context])
	var copied_damage: int = int(copy_effect.call("get_damage_bonus", attacker, state)) if copy_effect != null else 0
	return run_checks([
		assert_true(retreat_locked, "CSV10C_101 Surround should stop the opponent Active from retreating next turn"),
		assert_not_null(copy_effect, "CSV10C_101 Make-Believe should expose a coin-result interaction"),
		assert_true(bool(first_steps[0].get("wait_for_coin_animation", false)) if not first_steps.is_empty() else false, "CSV10C_101 should resolve its coin before attack selection"),
		assert_eq(copy_options.size(), 1, "CSV10C_101 heads should expose every attack on the opponent Active"),
		assert_eq(copied_damage, 30, "CSV10C_101 heads should copy the selected opponent attack's printed damage"),
	])


func test_csv10c_102_call_for_family_uses_full_deck_and_respects_zero_choice() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("102")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	var basic := CardInstance.create(_pokemon("Searchable Basic"), 0)
	var stage_one := CardInstance.create(_pokemon("Illegal Stage One", "Stage 1"), 0)
	var item := CardInstance.create(_pokemon("Illegal Item", "", "Item"), 0)
	state.players[0].deck = [basic, stage_one, item]
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state) if not effects.is_empty() else []
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{"search_basic_pokemon": []}])
	var zero_choice_kept_deck := basic in state.players[0].deck and state.players[0].bench.is_empty()
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{"search_basic_pokemon": [basic]}])
	return run_checks([
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1, -1], "CSV10C_102 should show the full deck while enabling only Basic Pokemon"),
		assert_true(zero_choice_kept_deck, "CSV10C_102 should not auto-Bench a Pokemon when the player explicitly chooses zero"),
		assert_eq(state.players[0].bench.size(), 1, "CSV10C_102 should put the selected Basic Pokemon onto the Bench"),
		assert_eq(state.players[0].bench[0].get_pokemon_name(), "Searchable Basic", "CSV10C_102 should Bench the selected card"),
	])


func test_csv10c_104_searches_only_pokemon_and_counts_stage_two_bench() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var card := _load_card("104")
	var mamoswine := _slot(card)
	state.players[0].active_pokemon = mamoswine
	var basic := CardInstance.create(_pokemon("Searchable Basic"), 0)
	var item := CardInstance.create(_pokemon("Illegal Item", "", "Item"), 0)
	state.players[0].deck = [basic, item]
	state.players[0].bench.append(_slot(_pokemon("Stage Two A", "Stage 2")))
	state.players[0].bench.append(_slot(_pokemon("Stage One", "Stage 1")))
	state.players[0].bench.append(_slot(_pokemon("Stage Two B", "Stage 2")))
	processor.register_pokemon_card(card)
	var ability := processor.get_effect(card.effect_id)
	var steps: Array[Dictionary] = []
	if ability != null:
		steps = ability.get_interaction_steps(mamoswine.get_top_card(), state)
	if ability != null:
		ability.execute_ability(mamoswine, 0, [{"search_cards": [basic]}], state)
	var bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(mamoswine, 0):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", mamoswine, state))
	return run_checks([
		assert_not_null(ability, "CSV10C_104 Mammoth Hauling should register"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1], "CSV10C_104 should show the full deck but only enable Pokemon"),
		assert_true(basic in state.players[0].hand, "CSV10C_104 should move the selected Pokemon to hand"),
		assert_true(item in state.players[0].deck, "CSV10C_104 should leave non-Pokemon cards in deck"),
		assert_eq(bonus, 80, "CSV10C_104 Rumbling March should add 40 for each own Benched Stage 2 Pokemon"),
	])


func test_csv10c_105_discards_selected_energy_only_on_heads() -> String:
	var state := _state()
	var processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	var card := _load_card("105")
	var attacker := _slot(card)
	state.players[0].active_pokemon = attacker
	var energy_a := CardInstance.create(_energy("Energy A"), 1)
	var energy_b := CardInstance.create(_energy("Energy B"), 1)
	state.players[1].active_pokemon.attached_energy = [energy_a, energy_b]
	processor.register_pokemon_card(card)
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{"discard_opponent_active_energy": [energy_b]}])
	return run_checks([
		assert_true(energy_a in state.players[1].active_pokemon.attached_energy, "CSV10C_105 should preserve the unselected Energy"),
		assert_false(energy_b in state.players[1].active_pokemon.attached_energy, "CSV10C_105 heads should discard the selected Energy"),
		assert_true(energy_b in state.players[1].discard_pile, "CSV10C_105 should move the selected Energy to the opponent discard pile"),
	])
