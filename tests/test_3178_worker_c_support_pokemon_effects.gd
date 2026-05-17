class_name Test3178WorkerCSupportPokemonEffects
extends TestBase

const BatchEffects = preload("res://scripts/effects/pokemon_effects/Batch3178WorkerCSupportPokemonEffects.gd")
const EffectSelfDamageScript = preload("res://scripts/effects/pokemon_effects/EffectSelfDamage.gd")
const AttackCallForFamilyScript = preload("res://scripts/effects/pokemon_effects/AttackCallForFamily.gd")


func test_worker_c_mapping_declares_only_cards_with_real_effects() -> String:
	var magnemite_151_effects := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_151C_081_MAGNEMITE)
	var magnemite_csv2_effects := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_CSV2C_036_MAGNEMITE)
	var magnemite_csv9_effects := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_CSV9C_055_MAGNEMITE)
	var pidgey_effects := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_151C_016_PIDGEY)
	var hoothoot_effects := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_CSV7C_159_HOOTHOOT)

	return run_checks([
		assert_eq(magnemite_151_effects.size(), 1, "151C_081 Magnemite Explosion should have one attack effect"),
		assert_true(magnemite_151_effects[0] is EffectSelfDamage, "151C_081 Magnemite should use self-damage"),
		assert_false((magnemite_151_effects[0] as EffectSelfDamage).applies_to_attack_index(0), "151C_081 self-damage must not apply to the first attack"),
		assert_true((magnemite_151_effects[0] as EffectSelfDamage).applies_to_attack_index(1), "151C_081 self-damage must bind to Explosion"),
		assert_eq(magnemite_csv2_effects.size(), 0, "CSV2C_036 Magnemite has only printed damage attacks"),
		assert_eq(magnemite_csv9_effects.size(), 0, "CSV9C_055 Magnemite has only printed damage attacks"),
		assert_eq(pidgey_effects.size(), 1, "151C_016 Pidgey Call for Family should have one attack effect"),
		assert_true(pidgey_effects[0] is AttackCallForFamily, "151C_016 Pidgey should use AttackCallForFamily"),
		assert_eq((pidgey_effects[0] as AttackCallForFamily).search_count, 2, "151C_016 Pidgey should search up to two Basic Pokemon"),
		assert_eq(hoothoot_effects.size(), 1, "CSV7C_159 Hoothoot Silent Wings should have one attack effect"),
		assert_true(hoothoot_effects[0].applies_to_attack_index(0), "CSV7C_159 Hoothoot effect should bind to its only attack"),
	])


func test_worker_c_effect_processor_registration_matches_card_text() -> String:
	var processor := EffectProcessor.new()
	var magnemite_151 := _make_slot(_magnemite_151c_081(), 0)
	var magnemite_csv2 := _magnemite_csv2c_036()
	var magnemite_csv9 := _magnemite_csv9c_055()
	var pidgey := _make_slot(_pidgey_151c_016(), 0)
	var hoothoot := _make_slot(_hoothoot_csv7c_159(), 0)

	processor.register_pokemon_card(magnemite_151.get_card_data())
	processor.register_pokemon_card(magnemite_csv2)
	processor.register_pokemon_card(magnemite_csv9)
	processor.register_pokemon_card(pidgey.get_card_data())
	processor.register_pokemon_card(hoothoot.get_card_data())

	var magnemite_first_attack := processor.get_attack_effects_for_slot(magnemite_151, 0)
	var magnemite_second_attack := processor.get_attack_effects_for_slot(magnemite_151, 1)
	var pidgey_first_attack := processor.get_attack_effects_for_slot(pidgey, 0)
	var pidgey_second_attack := processor.get_attack_effects_for_slot(pidgey, 1)
	var hoothoot_attack := processor.get_attack_effects_for_slot(hoothoot, 0)

	var checks: Array[String] = [
		assert_true(processor.has_attack_effect(BatchEffects.EFFECT_151C_081_MAGNEMITE), "151C_081 should register its Explosion self-damage"),
		assert_false(processor.has_attack_effect(BatchEffects.EFFECT_CSV2C_036_MAGNEMITE), "CSV2C_036 pure-damage Magnemite should not register an effect"),
		assert_false(processor.has_attack_effect(BatchEffects.EFFECT_CSV9C_055_MAGNEMITE), "CSV9C_055 pure-damage Magnemite should not register an effect"),
		assert_true(processor.has_attack_effect(BatchEffects.EFFECT_151C_016_PIDGEY), "151C_016 should register Call for Family"),
		assert_true(processor.has_attack_effect(BatchEffects.EFFECT_CSV7C_159_HOOTHOOT), "CSV7C_159 should register Silent Wings"),
		assert_eq(magnemite_first_attack.size(), 0, "151C_081 first attack should not expose self-damage through EffectProcessor"),
		assert_eq(magnemite_second_attack.size(), 1, "151C_081 second attack should expose self-damage through EffectProcessor"),
		assert_true(magnemite_second_attack[0] is EffectSelfDamage, "151C_081 registered second attack effect should be EffectSelfDamage"),
		assert_eq(pidgey_first_attack.size(), 1, "151C_016 first attack should expose Call for Family through EffectProcessor"),
		assert_true(pidgey_first_attack[0] is AttackCallForFamily, "151C_016 registered first attack effect should be AttackCallForFamily"),
		assert_eq(pidgey_second_attack.size(), 0, "151C_016 second attack should not expose Call for Family"),
		assert_eq(hoothoot_attack.size(), 1, "CSV7C_159 should expose one registered attack effect"),
	]
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_151c_081_magnemite_explosion_self_damage_only_second_attack() -> String:
	var first_attack_gsm := _make_gsm()
	var first_attacker := _make_slot(_magnemite_151c_081(), 0)
	_attach_energy(first_attacker, 0, "L", 1)
	first_attack_gsm.game_state.players[0].active_pokemon = first_attacker
	first_attack_gsm.effect_processor.register_attack_effect(
		first_attacker.get_card_data().effect_id,
		BatchEffects.create_attack_effects_for_effect_id(first_attacker.get_card_data().effect_id)[0]
	)
	var first_attacked := first_attack_gsm.use_attack(0, 0)

	var second_attack_gsm := _make_gsm()
	var second_attacker := _make_slot(_magnemite_151c_081(), 0)
	_attach_energy(second_attacker, 0, "L", 1)
	_attach_energy(second_attacker, 0, "C", 1)
	second_attack_gsm.game_state.players[0].active_pokemon = second_attacker
	second_attack_gsm.effect_processor.register_attack_effect(
		second_attacker.get_card_data().effect_id,
		BatchEffects.create_attack_effects_for_effect_id(second_attacker.get_card_data().effect_id)[0]
	)
	var second_attacked := second_attack_gsm.use_attack(0, 1)

	return run_checks([
		assert_true(first_attacked, "151C_081 Magnemite should use Tiny Charge"),
		assert_eq(first_attack_gsm.game_state.players[1].active_pokemon.damage_counters, 10, "Tiny Charge should deal only printed damage"),
		assert_eq(first_attacker.damage_counters, 0, "Tiny Charge should not self-damage"),
		assert_true(second_attacked, "151C_081 Magnemite should use Explosion"),
		assert_eq(second_attack_gsm.game_state.players[1].active_pokemon.damage_counters, 60, "Explosion should deal printed damage"),
		assert_eq(second_attacker.damage_counters, 60, "Explosion should also damage Magnemite for 60"),
	])


func test_151c_016_pidgey_call_for_family_full_deck_search_filters_basics() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_pidgey_151c_016(), 0)
	player.deck.clear()
	var basic_a := CardInstance.create(_pokemon("Basic A", "Basic A", "", [], "C", 60), 0)
	var stage_one := CardInstance.create(_pokemon("Stage One", "Stage One", "", [], "C", 80, "Stage 1", "Basic A"), 0)
	var item := CardInstance.create(_trainer("Deck Item", "Item", ""), 0)
	var basic_b := CardInstance.create(_pokemon("Basic B", "Basic B", "", [], "L", 70), 0)
	player.deck.append_array([basic_a, stage_one, item, basic_b])
	var visible_deck := player.deck.duplicate()

	var effect := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_151C_016_PIDGEY)[0] as AttackCallForFamily
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), player.active_pokemon.get_card_data().attacks[0], state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{"search_basic_pokemon": [item, basic_b]}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "Pidgey should expose a search interaction when basics and bench space exist"),
		assert_eq(step.get("visible_scope", ""), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Pidgey should show the whole own deck, not only legal candidates"),
		assert_eq(int(step.get("visible_count", -1)), visible_deck.size(), "Pidgey visible deck count should include disabled cards"),
		assert_eq(int(step.get("selectable_count", -1)), 2, "Pidgey should allow only Basic Pokemon to be selected"),
		assert_eq(step.get("card_items", []), visible_deck, "Pidgey card_items should preserve full deck visibility"),
		assert_eq(step.get("card_indices", []), [0, -1, -1, 1], "Pidgey should mark non-Basic cards disabled"),
		assert_eq(int(step.get("min_select", -1)), 0, "Pidgey search is up to two, so zero choices are legal"),
		assert_eq(int(step.get("max_select", -1)), 2, "Pidgey should cap selection at two Basic Pokemon"),
		assert_eq(_bench_names(player), ["Basic B"], "Pidgey should bench only the selected legal Basic Pokemon"),
		assert_true(stage_one in player.deck, "Pidgey should ignore selected non-Basic Pokemon"),
		assert_true(item in player.deck, "Pidgey should ignore selected non-Pokemon cards"),
	])


func test_151c_016_pidgey_call_for_family_caps_selection_at_two_basics() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.active_pokemon = _make_slot(_pidgey_151c_016(), 0)
	player.deck.clear()
	var basic_a := CardInstance.create(_pokemon("Basic A", "Basic A", "", [], "C", 60), 0)
	var basic_b := CardInstance.create(_pokemon("Basic B", "Basic B", "", [], "C", 60), 0)
	var basic_c := CardInstance.create(_pokemon("Basic C", "Basic C", "", [], "C", 60), 0)
	player.deck.append_array([basic_a, basic_b, basic_c])

	var effect := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_151C_016_PIDGEY)[0] as AttackCallForFamily
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), player.active_pokemon.get_card_data().attacks[0], state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{"search_basic_pokemon": [basic_a, basic_b, basic_c]}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(int(step.get("max_select", -1)), 2, "Pidgey interaction should cap selection at two Basic Pokemon"),
		assert_eq(_bench_names(player), ["Basic A", "Basic B"], "Pidgey should bench only the first two legal Basic Pokemon"),
		assert_true(basic_c in player.deck, "Pidgey should leave any extra selected Basic Pokemon in the deck"),
	])


func test_151c_016_pidgey_call_for_family_respects_full_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(_pidgey_151c_016(), 0)
	player.bench.clear()
	for i: int in 5:
		player.bench.append(_make_slot(_pokemon("Bench %d" % i, "Bench %d" % i, "", [], "C", 60), 0))
	var searchable := CardInstance.create(_pokemon("Searchable Basic", "Searchable Basic", "", [], "C", 60), 0)
	player.deck.clear()
	player.deck.append(searchable)
	var deck_before := player.deck.duplicate()

	var effect := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_151C_016_PIDGEY)[0] as AttackCallForFamily
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), player.active_pokemon.get_card_data().attacks[0], state)
	effect.set_attack_interaction_context([{"search_basic_pokemon": [searchable]}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 0, "Pidgey should not prompt when the bench is full"),
		assert_eq(player.bench.size(), 5, "Pidgey should not exceed the normal bench limit"),
		assert_eq(player.deck.size(), deck_before.size(), "Pidgey should leave deck size unchanged with no bench space"),
		assert_true(searchable in player.deck, "Pidgey should not remove a searched Basic when the bench is full"),
	])


func test_151c_016_pidgey_second_attack_does_not_search_when_registered() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var pidgey := _make_slot(_pidgey_151c_016(), 0)
	_attach_energy(pidgey, 0, "C", 2)
	player.active_pokemon = pidgey
	player.bench.clear()
	player.deck.clear()
	var searchable := CardInstance.create(_pokemon("Searchable Basic", "Searchable Basic", "", [], "C", 60), 0)
	player.deck.append(searchable)
	gsm.effect_processor.register_pokemon_card(pidgey.get_card_data())

	var first_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(pidgey, 0)
	var second_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(pidgey, 1)
	var attacked := gsm.use_attack(0, 1, [{"search_basic_pokemon": [searchable]}])

	return run_checks([
		assert_eq(first_attack_effects.size(), 1, "Pidgey first attack should have the search effect after registration"),
		assert_eq(second_attack_effects.size(), 0, "Pidgey second attack should have no search effect after registration"),
		assert_true(attacked, "Pidgey should use Tackle"),
		assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 20, "Tackle should deal only printed damage"),
		assert_eq(player.bench.size(), 0, "Tackle should not place Pokemon onto the Bench"),
		assert_true(searchable in player.deck, "Tackle should not remove Basic Pokemon from the deck"),
	])


func test_csv7c_159_hoothoot_silent_wings_previews_opponent_hand_without_mutation() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var hoothoot := _make_slot(_hoothoot_csv7c_159(), 0)
	_attach_energy(hoothoot, 0, "C", 2)
	player.active_pokemon = hoothoot
	opponent.hand.clear()
	var item := CardInstance.create(_trainer("Opponent Item", "Item", ""), 1)
	var basic := CardInstance.create(_pokemon("Opponent Basic", "Opponent Basic", "", [], "C", 70), 1)
	opponent.hand.append_array([item, basic])
	opponent.deck.clear()
	var hidden_deck_card := CardInstance.create(_trainer("Hidden Deck Card", "Item", ""), 1)
	opponent.deck.append(hidden_deck_card)

	var effect := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_CSV7C_159_HOOTHOOT)[0]
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(hoothoot.get_top_card(), hoothoot.get_card_data().attacks[0], gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	gsm.effect_processor.register_attack_effect(hoothoot.get_card_data().effect_id, effect)
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(steps.size(), 1, "Hoothoot should prompt to view opponent hand when it is not empty"),
		assert_eq(str(step.get("id", "")), "opponent_hand_preview", "Hoothoot should use a readonly opponent-hand step"),
		assert_eq(step.get("items", []), [item, basic], "Hoothoot preview should contain every opponent hand card"),
		assert_eq(step.get("card_items", []), [item, basic], "Hoothoot card preview should be limited to opponent hand cards"),
		assert_eq(str(step.get("visible_scope", "")), "opponent_hand", "Hoothoot preview should be scoped only to the opponent hand"),
		assert_false(hidden_deck_card in step.get("items", []), "Hoothoot should not reveal opponent deck cards"),
		assert_false(hidden_deck_card in step.get("card_items", []), "Hoothoot card preview should not reveal opponent deck cards"),
		assert_eq(int(step.get("min_select", -1)), 0, "Hoothoot preview should require no card selection"),
		assert_eq(int(step.get("max_select", -1)), 0, "Hoothoot preview should be readonly"),
		assert_false(bool(step.get("card_click_selectable", true)), "Hoothoot preview cards should not be selectable"),
		assert_true(attacked, "Hoothoot should still resolve its attack"),
		assert_eq(opponent.active_pokemon.damage_counters, 20, "Silent Wings should deal its printed 20 damage"),
		assert_eq(opponent.hand, [item, basic], "Silent Wings should not move or discard opponent hand cards"),
	])


func test_csv7c_159_hoothoot_empty_opponent_hand_still_attacks() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var hoothoot := _make_slot(_hoothoot_csv7c_159(), 0)
	_attach_energy(hoothoot, 0, "C", 2)
	player.active_pokemon = hoothoot
	opponent.hand.clear()

	var effect := BatchEffects.create_attack_effects_for_effect_id(BatchEffects.EFFECT_CSV7C_159_HOOTHOOT)[0]
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(hoothoot.get_top_card(), hoothoot.get_card_data().attacks[0], gsm.game_state)
	gsm.effect_processor.register_attack_effect(hoothoot.get_card_data().effect_id, effect)
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(steps.size(), 0, "Hoothoot should skip preview when opponent hand is empty"),
		assert_true(attacked, "Hoothoot should still attack with an empty opponent hand"),
		assert_eq(opponent.active_pokemon.damage_counters, 20, "Silent Wings should still deal printed damage"),
	])


func test_worker_c_basic_pokemon_evolution_metadata_is_stable() -> String:
	var cards: Array[CardData] = [
		_magnemite_151c_081(),
		_magnemite_csv2c_036(),
		_magnemite_csv9c_055(),
		_pidgey_151c_016(),
		_hoothoot_csv7c_159(),
	]
	var checks: Array[String] = []
	for card: CardData in cards:
		checks.append(assert_eq(card.stage, "Basic", "%s should remain Basic" % card.name_en))
		checks.append(assert_eq(card.evolves_from, "", "%s should not have evolves_from metadata" % card.name_en))
		checks.append(assert_true(card.is_basic_pokemon(), "%s should satisfy CardData.is_basic_pokemon" % card.name_en))
	return run_checks(checks)


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active%d" % pi, "Active%d" % pi, "", [], "C", 180), pi)
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _pokemon(
	name: String,
	name_en: String,
	effect_id: String,
	attacks: Array[Dictionary],
	energy_type: String = "C",
	hp: int = 60,
	stage: String = "Basic",
	evolves_from: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.evolves_from = evolves_from
	cd.attacks = attacks
	return cd


func _trainer(name: String, card_type: String, effect_id: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	cd.description = name
	return cd


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))


func _bench_names(player: PlayerState) -> Array[String]:
	var names: Array[String] = []
	for slot: PokemonSlot in player.bench:
		names.append(slot.get_pokemon_name())
	return names


func _magnemite_151c_081() -> CardData:
	var cd := _pokemon(
		"Magnemite 151C 081",
		"Magnemite",
		BatchEffects.EFFECT_151C_081_MAGNEMITE,
		[
			{"name": "Tiny Charge", "cost": "L", "damage": "10", "text": "", "is_vstar_power": false},
			{"name": "Explosion", "cost": "LC", "damage": "60", "text": "This Pokemon also does 60 damage to itself.", "is_vstar_power": false},
		],
		"L",
		60
	)
	cd.set_code = "151C"
	cd.card_index = "081"
	return cd


func _magnemite_csv2c_036() -> CardData:
	var cd := _pokemon(
		"Magnemite CSV2C 036",
		"Magnemite",
		BatchEffects.EFFECT_CSV2C_036_MAGNEMITE,
		[
			{"name": "Tackle", "cost": "L", "damage": "10", "text": "", "is_vstar_power": false},
			{"name": "Speed Ball", "cost": "CC", "damage": "20", "text": "", "is_vstar_power": false},
		],
		"L",
		60
	)
	cd.set_code = "CSV2C"
	cd.card_index = "036"
	return cd


func _magnemite_csv9c_055() -> CardData:
	var cd := _pokemon(
		"Magnemite CSV9C 055",
		"Magnemite",
		BatchEffects.EFFECT_CSV9C_055_MAGNEMITE,
		[
			{"name": "Static Shock", "cost": "L", "damage": "20", "text": "", "is_vstar_power": false},
		],
		"L",
		60
	)
	cd.set_code = "CSV9C"
	cd.card_index = "055"
	return cd


func _pidgey_151c_016() -> CardData:
	var cd := _pokemon(
		"Pidgey 151C 016",
		"Pidgey",
		BatchEffects.EFFECT_151C_016_PIDGEY,
		[
			{"name": "Call for Family", "cost": "C", "damage": "", "text": "Search your deck for up to 2 Basic Pokemon and put them onto your Bench. Then shuffle your deck.", "is_vstar_power": false},
			{"name": "Tackle", "cost": "CC", "damage": "20", "text": "", "is_vstar_power": false},
		],
		"C",
		50
	)
	cd.set_code = "151C"
	cd.card_index = "016"
	cd.resistance_energy = "F"
	cd.resistance_value = "-30"
	return cd


func _hoothoot_csv7c_159() -> CardData:
	var cd := _pokemon(
		"Hoothoot CSV7C 159",
		"Hoothoot",
		BatchEffects.EFFECT_CSV7C_159_HOOTHOOT,
		[
			{"name": "Silent Wings", "cost": "CC", "damage": "20", "text": "Look at your opponent's hand.", "is_vstar_power": false},
		],
		"C",
		70
	)
	cd.set_code = "CSV7C"
	cd.card_index = "159"
	cd.resistance_energy = "F"
	cd.resistance_value = "-30"
	return cd
