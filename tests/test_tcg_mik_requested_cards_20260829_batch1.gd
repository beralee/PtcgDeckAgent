class_name TestTcgMikRequestedCards20260829Batch1
extends TestBase

const TAPU_EFFECT_ID := "b7337b94bb9779b843cf7c00f703119a"
const MEOWSCARADA_EFFECT_ID := "0779cd043d2977d004c2cfff5503c939"
const SLOWKING_EFFECT_ID := "a7eb3d36fe16b1c33fbc3b6badaf3553"
const BOUQUET_ENERGY_STEP := "bouquet_magic_grass_energy"
const BOUQUET_TARGET_STEP := "bouquet_magic_bench_target"
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")


func test_csv4c032_tapu_koko_revenge_paralysis_and_energy_discard_are_exact() -> String:
	var card := _load_card("CSV4C", "032")
	if card == null:
		return assert_not_null(card, "CSV4C_032 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _state()
	var attacker := _slot(card, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker
	state.turn_number = 3
	state.current_player_index = 1
	state.record_knockout_against(0, 1)
	state.shared_turn_flags["attack_damage_knockout_names:0:3"] = ["Knocked Out Pokemon"]
	state.turn_number = 4
	state.current_player_index = 0
	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var revenge := _effect_with_method(first_effects, "get_damage_bonus")
	var bonus := int(revenge.call("get_damage_bonus", attacker, state)) if revenge != null else -1
	if revenge != null:
		revenge.call("execute_attack", attacker, defender, 0, state)
	var non_attack_state := _state()
	var non_attack_attacker := _slot(card, 0)
	var non_attack_defender := non_attack_state.players[1].active_pokemon
	non_attack_state.players[0].active_pokemon = non_attack_attacker
	non_attack_state.turn_number = 3
	non_attack_state.current_player_index = 1
	non_attack_state.record_knockout_against(0, 1)
	non_attack_state.shared_turn_flags["knockout_names:0:3"] = ["Knocked Out by a non-attack effect"]
	non_attack_state.turn_number = 4
	non_attack_state.current_player_index = 0
	var non_attack_bonus := int(revenge.call("get_damage_bonus", non_attack_attacker, non_attack_state)) if revenge != null else -1
	if revenge != null:
		revenge.call("execute_attack", non_attack_attacker, non_attack_defender, 0, non_attack_state)

	var energy_a := _energy("Lightning A", "L", 0)
	var energy_b := _energy("Lightning B", "L", 0)
	attacker.attached_energy = [energy_a, energy_b]
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	var discard_effect := _effect_with_attack_steps(second_effects, attacker.get_top_card(), card.attacks[1], state)
	var steps: Array = discard_effect.get_attack_interaction_steps(attacker.get_top_card(), card.attacks[1], state) if discard_effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	if discard_effect != null and not step.is_empty():
		discard_effect.set_attack_interaction_context([{str(step.get("id", "")): [energy_b]}])
		discard_effect.execute_attack(attacker, defender, 1, state)
		discard_effect.clear_attack_interaction_context()
	return run_checks([
		assert_eq(bonus, 90, "Revenge Shock should add exactly 90 after an attack-damage Knock Out during the opponent's last turn"),
		assert_true(defender.status_conditions.get("paralyzed", false), "The same qualifying Revenge Shock should Paralyze the opponent's Active Pokemon"),
		assert_eq(non_attack_bonus, 0, "Revenge Shock must not gain damage after a non-attack-effect Knock Out"),
		assert_false(non_attack_defender.status_conditions.get("paralyzed", false), "A non-attack-effect Knock Out must not activate Revenge Shock's Paralysis"),
		assert_not_null(discard_effect, "Exciting Bolt should expose its attached-Energy discard choice"),
		assert_eq(int(step.get("min_select", 0)), 1, "Exciting Bolt should require exactly one attached Energy"),
		assert_true(energy_b in state.players[0].discard_pile, "Exciting Bolt should discard the selected attached Energy"),
		assert_eq(attacker.attached_energy, [energy_a], "Exciting Bolt should preserve the unselected attached Energy"),
	])


func test_csv2c012_meowscarada_bouquet_magic_and_scratching_nails_match_card_text() -> String:
	var card := _load_card("CSV2C", "012")
	if card == null:
		return assert_not_null(card, "CSV2C_012 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _state()
	var meowscarada := _slot(card, 0)
	state.players[0].active_pokemon = meowscarada
	var grass_data := _load_card("CSVE1C", "GRA")
	if grass_data == null:
		return assert_not_null(grass_data, "The bundled Basic Grass Energy should load")
	var grass := CardInstance.create(grass_data, 0)
	var fire := _energy("Basic Fire", "R", 0)
	var special_grass_data := CardData.new()
	special_grass_data.name = "Special Grass"
	special_grass_data.card_type = "Special Energy"
	special_grass_data.energy_provides = "G"
	var special_grass := CardInstance.create(special_grass_data, 0)
	state.players[0].hand = [grass, fire, special_grass]
	var bench_target := _slot(_pokemon("Bench Target", 120), 1)
	state.players[1].bench = [bench_target]
	var ability := processor.get_effect(MEOWSCARADA_EFFECT_ID)
	var steps: Array = ability.get_interaction_steps(meowscarada.get_top_card(), state) if ability != null else []
	var rejected_fire := processor.execute_ability_effect(meowscarada, 0, [{
		BOUQUET_ENERGY_STEP: [fire],
		BOUQUET_TARGET_STEP: [bench_target],
	}], state)
	var rejected_special_grass := processor.execute_ability_effect(meowscarada, 0, [{
		BOUQUET_ENERGY_STEP: [special_grass],
		BOUQUET_TARGET_STEP: [bench_target],
	}], state)
	var rejected_active_target := processor.execute_ability_effect(meowscarada, 0, [{
		BOUQUET_ENERGY_STEP: [grass],
		BOUQUET_TARGET_STEP: [state.players[1].active_pokemon],
	}], state)
	state.current_player_index = 1
	var usable_during_opponent_turn := processor.can_use_ability(meowscarada, state)
	state.current_player_index = 0
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var ability_action := _find_ability_action(AILegalActionBuilderScript.new().build_actions(gsm, 0), meowscarada)
	var used := processor.execute_ability_effect(meowscarada, 0, [{
		BOUQUET_ENERGY_STEP: [grass],
		BOUQUET_TARGET_STEP: [bench_target],
	}], state)
	var attack_effects := processor.get_attack_effects_for_slot(meowscarada, 0)
	var bonus_effect := _effect_with_method(attack_effects, "get_damage_bonus")
	var healthy_bonus := int(bonus_effect.call("get_damage_bonus", meowscarada, state)) if bonus_effect != null else -1
	state.players[1].active_pokemon.damage_counters = 10
	var damaged_bonus := int(bonus_effect.call("get_damage_bonus", meowscarada, state)) if bonus_effect != null else -1
	return run_checks([
		assert_not_null(ability, "Bouquet Magic should register as Meowscarada ex's Ability"),
		assert_eq(grass_data.energy_type, "", "The production Basic Grass Energy keeps Pokemon type empty"),
		assert_eq(grass_data.energy_provides, "G", "The production Basic Grass Energy declares its type through energy_provides"),
		assert_eq(steps.size(), 2, "Bouquet Magic should expose both its Grass Energy cost and opponent Bench target choices"),
		assert_false(rejected_fire, "Bouquet Magic must reject a non-Grass Energy as its discard cost"),
		assert_false(rejected_special_grass, "Bouquet Magic must reject Special Energy even when it provides Grass Energy"),
		assert_false(rejected_active_target, "Bouquet Magic must reject the opponent's Active Pokemon as its target"),
		assert_false(usable_during_opponent_turn, "Bouquet Magic must only be usable during its owner's turn"),
		assert_false(ability_action.is_empty(), "The AI/headless legal-action builder should expose a usable Bouquet Magic action"),
		assert_false(bool(ability_action.get("requires_interaction", true)), "The AI/headless path should auto-resolve Bouquet Magic's two legal choices"),
		assert_true(used, "Bouquet Magic should resolve with one legal Basic Grass Energy and one opponent Benched Pokemon"),
		assert_true(grass in state.players[0].discard_pile, "Bouquet Magic should discard the selected Basic Grass Energy"),
		assert_true(fire in state.players[0].hand, "Bouquet Magic must not discard an unselected non-Grass Energy"),
		assert_true(special_grass in state.players[0].hand, "Bouquet Magic must preserve an unselected Special Grass Energy"),
		assert_eq(bench_target.damage_counters, 30, "Bouquet Magic should place exactly 3 damage counters on the selected opponent Bench target"),
		assert_false(processor.can_use_ability(meowscarada, state), "Bouquet Magic should be limited to once during the turn"),
		assert_eq(healthy_bonus, 0, "Scratching Nails should stay at 100 against an undamaged Active Pokemon"),
		assert_eq(damaged_bonus, 120, "Scratching Nails should add exactly 120 against a damaged Active Pokemon"),
	])


func test_csv4c043_slowking_confuses_and_optional_search_shows_the_full_deck() -> String:
	var card := _load_card("CSV4C", "043")
	if card == null:
		return assert_not_null(card, "CSV4C_043 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _state()
	var slowking := _slot(card, 0)
	state.players[0].active_pokemon = slowking
	var defender := state.players[1].active_pokemon
	processor.execute_attack_effect(slowking, 0, defender, state)
	var first := _trainer("First", "Item", 0)
	var second := _trainer("Second", "Supporter", 0)
	var third := _pokemon_instance("Third", 0)
	state.players[0].deck = [first, second, third]
	var effects := processor.get_attack_effects_for_slot(slowking, 1)
	var search := _effect_with_attack_steps(effects, slowking.get_top_card(), card.attacks[1], state)
	var steps: Array = search.get_attack_interaction_steps(slowking.get_top_card(), card.attacks[1], state) if search != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	if search != null:
		search.set_attack_interaction_context([{"search_cards": []}])
		search.execute_attack(slowking, defender, 1, state)
		search.clear_attack_interaction_context()
	var declined_cleanly := state.players[0].hand.is_empty() and state.players[0].deck.size() == 3
	state.players[0].deck.assign([first, second, third])
	if search != null:
		search.set_attack_interaction_context([{"search_cards": [second, third]}])
		search.execute_attack(slowking, defender, 1, state)
		search.clear_attack_interaction_context()
	return run_checks([
		assert_true(defender.status_conditions.get("confused", false), "Profound Knowledge should Confuse the opponent's Active Pokemon"),
		assert_not_null(search, "Wisdom Headbutt should register its optional any-card search"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Wisdom Headbutt should expose the complete own deck"),
		assert_eq(step.get("card_items", []), [first, second, third], "Wisdom Headbutt should keep every deck card visible"),
		assert_eq(int(step.get("min_select", -1)), 0, "Wisdom Headbutt should allow declining the search"),
		assert_eq(int(step.get("max_select", -1)), 2, "Wisdom Headbutt should allow up to two cards"),
		assert_true(declined_cleanly, "Declining Wisdom Headbutt should leave hand and deck counts unchanged"),
		assert_true(second in state.players[0].hand and third in state.players[0].hand, "Wisdom Headbutt should move exactly the selected two cards to hand"),
	])


func test_csv1c009_sprigatito_and_csv1c010_floragato_numeric_attacks_stay_exact() -> String:
	var sprigatito := _load_card("CSV1C", "009")
	var floragato := _load_card("CSV1C", "010")
	return run_checks([
		assert_not_null(sprigatito, "CSV1C_009 should load"),
		assert_not_null(floragato, "CSV1C_010 should load"),
		assert_eq(sprigatito.attacks[0].get("cost", "") if sprigatito != null else "", "C", "Sprigatito's first attack should cost one Colorless Energy"),
		assert_eq(sprigatito.attacks[0].get("damage", "") if sprigatito != null else "", "10", "Sprigatito's first attack should deal 10"),
		assert_eq(sprigatito.attacks[1].get("cost", "") if sprigatito != null else "", "GC", "Sprigatito's second attack should cost Grass and Colorless"),
		assert_eq(sprigatito.attacks[1].get("damage", "") if sprigatito != null else "", "20", "Sprigatito's second attack should deal 20"),
		assert_eq(floragato.attacks[0].get("damage", "") if floragato != null else "", "20", "Floragato's first attack should deal 20"),
		assert_eq(floragato.attacks[1].get("cost", "") if floragato != null else "", "GC", "Floragato's second attack should cost Grass and Colorless"),
		assert_eq(floragato.attacks[1].get("damage", "") if floragato != null else "", "60", "Floragato's second attack should deal 60"),
		assert_false(CardImplementationStatus.is_unimplemented(sprigatito), "Numeric-only Sprigatito should run through base damage rules"),
		assert_false(CardImplementationStatus.is_unimplemented(floragato), "Numeric-only Floragato should run through base damage rules"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner, 300), owner)
		state.players.append(player)
	return state


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _energy(name: String, energy_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner)


func _trainer(name: String, card_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return CardInstance.create(card, owner)


func _pokemon_instance(name: String, owner: int) -> CardInstance:
	return CardInstance.create(_pokemon(name, 80), owner)


func _effect_with_method(effects: Array[BaseEffect], method_name: String) -> BaseEffect:
	for effect: BaseEffect in effects:
		if effect != null and effect.has_method(method_name):
			return effect
	return null


func _effect_with_attack_steps(effects: Array[BaseEffect], card: CardInstance, attack: Dictionary, state: GameState) -> BaseEffect:
	for effect: BaseEffect in effects:
		if effect != null and not effect.get_attack_interaction_steps(card, attack, state).is_empty():
			return effect
	return null


func _find_ability_action(actions: Array[Dictionary], source_slot: PokemonSlot) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "use_ability" and action.get("source_slot", null) == source_slot and int(action.get("ability_index", -1)) == 0:
			return action
	return {}
