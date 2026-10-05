class_name TestCSV10C121To125
extends TestBase


class TailsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(false)
		return false

	func flip_with_metadata(_metadata: Dictionary) -> bool:
		return flip()


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


func _arbok_gsm(player_index: int) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = player_index
	var arbok := _load_card("121")
	gsm.game_state.players[1 - player_index].active_pokemon = _slot(arbok, 1 - player_index)
	gsm.effect_processor.register_pokemon_card(arbok)
	gsm.game_state.shared_turn_flags["_draw_effect_processor"] = gsm.effect_processor
	return gsm


func test_arbok_rejects_live_hand_bench_and_evolution_for_both_seats() -> String:
	var checks: Array[String] = []
	for owner: int in 2:
		var gsm := _arbok_gsm(owner)
		var state := gsm.game_state
		var player := state.players[owner]
		var basic := CardInstance.create(_pokemon("Ability Basic", "Basic", "P", "", true), owner)
		var evolution := CardInstance.create(_pokemon("Ability Evolution", "Stage 1", "P", player.active_pokemon.get_pokemon_name(), true), owner)
		player.hand = [basic, evolution]
		var intents := BattleActionIntentModel.build(gsm, owner)
		checks.append(assert_eq(intents.hand_intents[basic.instance_id].state, "blocked", "Player UI must mark basic as blocked"))
		checks.append(assert_eq(intents.hand_intents[evolution.instance_id].state, "blocked", "Player UI must mark evolution as blocked"))
		var builder := preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd").LegalityOnlyActionBuilder.new()
		for action: Dictionary in builder.build_actions(gsm, owner):
			checks.append(assert_false(action.kind in ["play_basic_to_bench", "evolve"], "Author action frontier must omit blocked hand plays"))
		checks.append(assert_false(gsm.rule_validator.can_play_basic_to_bench(state, owner, basic, gsm.effect_processor), "Glare must remove illegal bench actions"))
		checks.append(assert_false(gsm.play_basic_to_bench(owner, basic), "Live bench command must reject Glare"))
		checks.append(assert_false(gsm.evolve_pokemon(owner, evolution, player.active_pokemon), "Live evolution must reject Glare"))
		checks.append(assert_eq(player.hand.size(), 2, "Rejected actions must preserve hand"))
		checks.append(assert_eq(player.bench.size(), 0, "Rejected actions must preserve bench"))
		checks.append(assert_eq(player.active_pokemon.pokemon_stack.size(), 1, "Rejected evolution must preserve stack"))
	return run_checks(checks)


func test_arbok_hand_lock_exceptions_and_active_lifecycle() -> String:
	var gsm := _arbok_gsm(0)
	var state := gsm.game_state
	var player := state.players[0]
	var arbok := state.players[1].active_pokemon
	var checks: Array[String] = []
	for card_name: String in ["Plain", "火箭队的能力宝可梦", "Team Rocket's Ability Pokemon"]:
		var card := CardInstance.create(_pokemon(card_name, "Basic", "D", "", card_name != "Plain"), 0)
		player.hand.append(card)
		checks.append(assert_true(gsm.play_basic_to_bench(0, card), "Plain and Rocket Pokemon remain playable"))
	var blocked := CardInstance.create(_pokemon("Other Ability", "Basic", "P", "", true), 0)
	player.hand.append(blocked)
	checks.append(assert_true(gsm.rule_validator.get_play_basic_to_bench_unusable_reason(state, 0, blocked, gsm.effect_processor).contains("阿柏怪"), "UI rejection should identify Arbok"))
	state.players[1].bench = [arbok]
	state.players[1].active_pokemon = _slot(_pokemon("Replacement"), 1)
	checks.append(assert_true(gsm.rule_validator.can_play_basic_to_bench(state, 0, blocked, gsm.effect_processor), "Benched Arbok must not lock"))
	state.players[1].bench.clear()
	state.players[1].active_pokemon = arbok
	checks.append(assert_false(gsm.rule_validator.can_play_basic_to_bench(state, 0, blocked, gsm.effect_processor), "Returning Active restores lock"))
	arbok.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_true(gsm.play_basic_to_bench(0, blocked), "Suppressed Glare must allow play"))
	return run_checks(checks)


func test_arbok_blocks_rare_candy_candidates_and_stale_execution() -> String:
	var gsm := _arbok_gsm(0)
	var state := gsm.game_state
	var target := state.players[0].active_pokemon
	var stage1 := CardInstance.create(_pokemon("Middle", "Stage 1", "P", target.get_pokemon_name()), 0)
	var stage2 := CardInstance.create(_pokemon("Final", "Stage 2", "P", "Middle", true), 0)
	var candy_data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSVH1C_045.json")))
	var candy := CardInstance.create(candy_data, 0)
	state.players[0].hand = [stage2, candy]
	state.players[0].deck = [stage1]
	var effect := EffectRareCandy.new()
	var checks: Array[String] = []
	checks.append(assert_false(effect.can_execute(candy, state), "Candy cannot play a blocked ability Pokemon"))
	checks.append(assert_eq(effect.build_ucis_interaction_steps_spec_steps(candy, state)[0].items.size(), 0, "Candy must omit blocked evolution pairs"))
	effect.execute(candy, [{"rare_candy_evolve": [{"card": stage2, "target_slot": target}]}], state)
	checks.append(assert_eq(target.pokemon_stack.size(), 1, "Stale Candy selection must not bypass Glare"))
	checks.append(assert_true(stage2 in state.players[0].hand, "Blocked evolution remains in hand"))
	state.players[1].active_pokemon.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_true(effect.can_execute(candy, state), "Candy becomes available when Glare is suppressed"))
	checks.append(assert_true(gsm.effect_processor.execute_card_effect(candy, [{"rare_candy_evolve": [{"card": stage2, "target_slot": target}]}], state), "Registered Candy must execute after suppression"))
	checks.append(assert_eq(target.get_top_card(), stage2, "Allowed Candy must actually evolve the target"))
	return run_checks(checks)


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
