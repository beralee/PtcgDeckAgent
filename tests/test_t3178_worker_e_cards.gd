class_name TestT3178WorkerECards
extends TestBase

const AbilityDragonHoardScript := preload("res://scripts/effects/pokemon_effects/AbilityDragonHoard.gd")
const NoivernExEffectsScript := preload("res://scripts/effects/pokemon_effects/NoivernExEffects.gd")
const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")


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
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _attack(name: String, cost: String = "", damage: String = "", text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _pokemon(
	name: String,
	effect_id: String,
	attacks: Array[Dictionary],
	abilities: Array[Dictionary] = [],
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	name_en: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en if name_en != "" else name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.attacks = attacks
	cd.abilities = abilities
	return cd


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	cd.description = name
	return cd


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))


func _add_dummy_prizes(state: GameState) -> void:
	for pi: int in state.players.size():
		for i: int in 6:
			state.players[pi].prizes.append(CardInstance.create(_trainer("Prize %d-%d" % [pi, i], "Item"), pi))


func _setup_battle(gsm: GameStateMachine, attacker_cd: CardData, defender_cd: CardData) -> Array[PokemonSlot]:
	var attacker := _slot(attacker_cd, 0)
	var defender := _slot(defender_cd, 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_add_dummy_prizes(gsm.game_state)
	for pi: int in gsm.game_state.players.size():
		for i: int in 3:
			gsm.game_state.players[pi].deck.append(CardInstance.create(_trainer("Turn Draw %d-%d" % [pi, i], "Item"), pi))
	return [attacker, defender]


func _toedscool() -> CardData:
	var cd := _pokemon(
		"原野水母",
		"3c5c8a731e45ff86d10c710edaa9387f",
		[_attack("汁液喷吐", "C", "10")],
		[],
		"F",
		60,
		"Basic",
		"",
		"Toedscool"
	)
	cd.set_code = "SVP"
	cd.card_index = "144"
	cd.description = " 汁液喷吐 10\n\n\n"
	return cd


func _regidrago() -> CardData:
	return _pokemon(
		"雷吉铎拉戈",
		"e49bf2cfe3c7948b0dcebbe1b1b7aa76",
		[_attack("巨大之牙", "GRC", "160")],
		[{"name": "龙之秘宝", "text": "如果这只宝可梦在战斗场上的话，则在自己的回合可以使用1次。从牌库上方抽取卡牌，直到自己的手牌变为4张为止。在这个回合，如果已经使用了其他的「龙之秘宝」了的话，则无法使用这个特性。"}],
		"N",
		130,
		"Basic",
		"",
		"Regidrago"
	)


func _noivern_ex() -> CardData:
	var cd := _pokemon(
		"音波龙ex",
		"7f21a88085207d28e38ca3593994edc2",
		[
			_attack("隐秘飞行", "CC", "70", "在下一个对手的回合，这只宝可梦不会受到【基础】宝可梦的招式的伤害。"),
			_attack("支配回响", "PD", "140", "在下一个对手的回合，对手无法从手牌使出并附着特殊能量，也无法放置竞技场。"),
		],
		[],
		"N",
		260,
		"Stage 1",
		"ex",
		"Noivern ex"
	)
	cd.evolves_from = "嗡蝠"
	return cd


func test_svp_144_toedscool_plain_attack_uses_base_damage_engine() -> String:
	CardImplementationStatusScript.clear_cache()
	var gsm := _make_gsm()
	var toedscool := _toedscool()
	gsm.effect_processor.register_pokemon_card(toedscool)
	var defender := _pokemon("Target", "", [_attack("Hit", "C", "10")], [], "C", 100)
	var slots := _setup_battle(gsm, toedscool, defender)
	_attach_energy(slots[0], 0, "C", 1)
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_false(gsm.effect_processor.has_effect(toedscool.effect_id), "SVP_144 should not need a registered non-damage effect"),
		assert_false(gsm.effect_processor.has_attack_effect(toedscool.effect_id), "SVP_144 should not need a registered attack effect"),
		assert_false(CardImplementationStatusScript.is_unimplemented(toedscool), "SVP_144 should be considered implemented by base damage rules"),
		assert_true(attacked, "SVP_144 should attack when one Colorless cost is paid"),
		assert_eq(slots[1].damage_counters, 10, "SVP_144 Spit should deal its printed 10 damage"),
	])


func test_cs55c_054_regidrago_dragons_hoard_requires_active_and_global_once() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var regidrago := _regidrago()
	gsm.effect_processor.register_pokemon_card(regidrago)
	var first := _slot(regidrago, 0)
	var second := _slot(regidrago, 0)
	var other_active := _slot(_pokemon("Other", "", [_attack("Hit", "C", "10")]), 0)
	state.players[0].active_pokemon = other_active
	state.players[0].bench.append(first)
	var can_use_from_bench := gsm.effect_processor.can_use_ability(first, state, 0)

	state.players[0].active_pokemon = first
	state.players[0].bench.clear()
	state.players[0].hand.append(CardInstance.create(_trainer("Hand", "Item"), 0))
	for i: int in 4:
		state.players[0].deck.append(CardInstance.create(_trainer("Draw %d" % i, "Item"), 0))
	var used_first := gsm.effect_processor.execute_ability_effect(first, 0, [], state)
	var hand_after_first := state.players[0].hand.size()

	state.players[0].hand.clear()
	state.players[0].deck.append(CardInstance.create(_trainer("Second Draw", "Item"), 0))
	state.players[0].active_pokemon = second
	var can_use_second_same_turn := gsm.effect_processor.can_use_ability(second, state, 0)

	return run_checks([
		assert_false(can_use_from_bench, "CS5.5C_054 Dragon's Hoard should require the Active Spot"),
		assert_true(used_first, "CS5.5C_054 Dragon's Hoard should execute from the Active Spot"),
		assert_eq(hand_after_first, 4, "CS5.5C_054 Dragon's Hoard should draw until hand size is four"),
		assert_false(can_use_second_same_turn, "CS5.5C_054 Dragon's Hoard should be limited across all Dragon's Hoard abilities that turn"),
	])


func test_cs55c_054_regidrago_dragons_hoard_registration_and_turn_bounds() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var regidrago := _regidrago()
	gsm.effect_processor.register_pokemon_card(regidrago)
	var active := _slot(regidrago, 0)
	state.players[0].active_pokemon = active
	for i: int in 4:
		state.players[0].deck.append(CardInstance.create(_trainer("Draw Bound %d" % i, "Item"), 0))

	var registered_effect := gsm.effect_processor.get_effect(regidrago.effect_id)
	var can_use_own_turn := gsm.effect_processor.can_use_ability(active, state, 0)
	var builder = AILegalActionBuilderScript.new()
	var own_turn_actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	state.current_player_index = 1
	var can_use_opponent_turn := gsm.effect_processor.can_use_ability(active, state, 0)
	state.current_player_index = 0
	state.players[0].hand = [
		CardInstance.create(_trainer("Full Hand 1", "Item"), 0),
		CardInstance.create(_trainer("Full Hand 2", "Item"), 0),
		CardInstance.create(_trainer("Full Hand 3", "Item"), 0),
		CardInstance.create(_trainer("Full Hand 4", "Item"), 0),
	]
	var can_use_at_four_cards := gsm.effect_processor.can_use_ability(active, state, 0)

	return run_checks([
		assert_true(registered_effect is AbilityDragonHoardScript, "CS5.5C_054 should register AbilityDragonHoard through its effect_id"),
		assert_true(can_use_own_turn, "CS5.5C_054 Dragon's Hoard should be usable on its controller's turn while Active and below four cards"),
		assert_true(_actions_include_kind(own_turn_actions, "use_ability"), "AI/legal action builder should enumerate Dragon's Hoard when it is legal"),
		assert_false(can_use_opponent_turn, "CS5.5C_054 Dragon's Hoard should not be usable during the opponent's turn"),
		assert_false(can_use_at_four_cards, "CS5.5C_054 Dragon's Hoard should not be usable when hand already has four cards"),
	])


func test_csvl1c_045_noivern_ex_hidden_flight_blocks_basic_damage_only() -> String:
	var noivern := _noivern_ex()
	var basic_attacker := _pokemon("Basic Attacker", "", [_attack("Strike", "C", "100")], [], "L", 100, "Basic")
	var stage1_attacker := _pokemon("Stage 1 Attacker", "", [_attack("Strike", "C", "100")], [], "L", 120, "Stage 1")
	var basic_damage := _damage_noivern_after_hidden_flight(noivern, basic_attacker)
	var stage1_damage := _damage_noivern_after_hidden_flight(noivern, stage1_attacker)

	return run_checks([
		assert_eq(basic_damage, 0, "CSVL1C_045 Hidden Flight should prevent attack damage from Basic Pokemon next turn"),
		assert_eq(stage1_damage, 100, "CSVL1C_045 Hidden Flight should not prevent damage from evolved Pokemon"),
	])


func test_csvl1c_045_noivern_ex_dominating_echo_blocks_special_energy_and_stadium() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var noivern := _noivern_ex()
	var defender := _pokemon("Target", "", [_attack("Hit", "C", "10")], [], "C", 300)
	var slots := _setup_battle(gsm, noivern, defender)
	gsm.effect_processor.register_pokemon_card(noivern)
	_attach_energy(slots[0], 0, "P", 1)
	_attach_energy(slots[0], 0, "D", 1)
	var attacked := gsm.use_attack(0, 1)

	var basic_energy := CardInstance.create(_energy("Psychic Energy", "P"), 1)
	var special_energy := CardInstance.create(_energy("Double Turbo Energy", "C", "Special Energy"), 1)
	var stadium := CardInstance.create(_trainer("Test Stadium", "Stadium"), 1)
	var item := CardInstance.create(_trainer("Test Item", "Item"), 1)

	var can_attach_basic := gsm.rule_validator.can_attach_energy(state, 1, basic_energy, gsm.effect_processor)
	var can_attach_special := gsm.rule_validator.can_attach_energy(state, 1, special_energy, gsm.effect_processor)
	var can_play_stadium := gsm.rule_validator.can_play_stadium(state, 1, stadium, gsm.effect_processor)
	var can_play_item := gsm.rule_validator.can_play_item(state, 1, item, gsm.effect_processor)

	gsm.end_turn(1)
	gsm.end_turn(0)
	var can_attach_special_after_expiry := gsm.rule_validator.can_attach_energy(state, 1, special_energy, gsm.effect_processor)
	var can_play_stadium_after_expiry := gsm.rule_validator.can_play_stadium(state, 1, stadium, gsm.effect_processor)

	return run_checks([
		assert_true(attacked, "CSVL1C_045 Dominating Echo should execute when paid"),
		assert_true(can_attach_basic, "CSVL1C_045 Dominating Echo should not block Basic Energy attachments"),
		assert_false(can_attach_special, "CSVL1C_045 Dominating Echo should block Special Energy attachments from hand next turn"),
		assert_false(can_play_stadium, "CSVL1C_045 Dominating Echo should block Stadium play next turn"),
		assert_true(can_play_item, "CSVL1C_045 Dominating Echo should not block unrelated Item cards"),
		assert_true(can_attach_special_after_expiry, "CSVL1C_045 Dominating Echo Special Energy lock should expire after the opponent's next turn"),
		assert_true(can_play_stadium_after_expiry, "CSVL1C_045 Dominating Echo Stadium lock should expire after the opponent's next turn"),
	])


func test_csvl1c_045_noivern_ex_registration_and_attack_index_isolation() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var noivern := _noivern_ex()
	var defender := _pokemon("Target", "", [_attack("Hit", "C", "10")], [], "C", 300)
	var slots := _setup_battle(gsm, noivern, defender)
	gsm.effect_processor.register_pokemon_card(noivern)
	_attach_energy(slots[0], 0, "C", 2)
	_attach_energy(slots[0], 0, "P", 1)
	_attach_energy(slots[0], 0, "D", 1)

	var registered_effect := gsm.effect_processor.get_effect(noivern.effect_id)
	var hidden_effects := gsm.effect_processor.get_attack_effects_for_slot(slots[0], 0)
	var echo_effects := gsm.effect_processor.get_attack_effects_for_slot(slots[0], 1)
	var hidden_attacked := gsm.use_attack(0, 0)

	var special_energy := CardInstance.create(_energy("Double Turbo Energy", "C", "Special Energy"), 1)
	var stadium := CardInstance.create(_trainer("Test Stadium", "Stadium"), 1)
	var special_allowed_after_hidden := gsm.rule_validator.can_attach_energy(state, 1, special_energy, gsm.effect_processor)
	var stadium_allowed_after_hidden := gsm.rule_validator.can_play_stadium(state, 1, stadium, gsm.effect_processor)

	var echo_gsm := _make_gsm()
	var echo_state := echo_gsm.game_state
	var echo_slots := _setup_battle(echo_gsm, noivern, defender)
	echo_gsm.effect_processor.register_pokemon_card(noivern)
	_attach_energy(echo_slots[0], 0, "P", 1)
	_attach_energy(echo_slots[0], 0, "D", 1)
	var echo_attacked := echo_gsm.use_attack(0, 1)
	var basic_attacker := _slot(_pokemon("Basic Attacker", "", [_attack("Strike", "C", "100")], [], "L", 100, "Basic"), 1)
	_attach_energy(basic_attacker, 1, "C", 1)
	echo_state.players[1].active_pokemon = basic_attacker
	var basic_attack_after_echo := echo_gsm.use_attack(1, 0)

	return run_checks([
		assert_true(registered_effect is NoivernExEffectsScript, "CSVL1C_045 should register its persistent Noivern effect through effect_id"),
		assert_true(gsm.effect_processor.has_attack_effect(noivern.effect_id), "CSVL1C_045 should register attack effects through effect_id"),
		assert_eq(hidden_effects.size(), 1, "CSVL1C_045 Hidden Flight should have exactly one attack-index-0 effect"),
		assert_eq(echo_effects.size(), 1, "CSVL1C_045 Dominating Echo should have exactly one attack-index-1 effect"),
		assert_true(hidden_attacked, "CSVL1C_045 Hidden Flight should execute when paid"),
		assert_true(special_allowed_after_hidden, "CSVL1C_045 Hidden Flight should not apply Dominating Echo's Special Energy lock"),
		assert_true(stadium_allowed_after_hidden, "CSVL1C_045 Hidden Flight should not apply Dominating Echo's Stadium lock"),
		assert_true(echo_attacked, "CSVL1C_045 Dominating Echo should execute when paid"),
		assert_true(basic_attack_after_echo, "Opponent Basic Pokemon should still be able to attack after Dominating Echo"),
		assert_eq(echo_state.players[0].active_pokemon.damage_counters, 100, "CSVL1C_045 Dominating Echo should not apply Hidden Flight's Basic Pokemon damage prevention"),
	])


func test_csvl1c_045_noivern_ex_dominating_echo_filters_ai_actions() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var noivern := _noivern_ex()
	var defender := _pokemon("Target", "", [_attack("Hit", "C", "10")], [], "C", 300)
	var slots := _setup_battle(gsm, noivern, defender)
	gsm.effect_processor.register_pokemon_card(noivern)
	_attach_energy(slots[0], 0, "P", 1)
	_attach_energy(slots[0], 0, "D", 1)
	var attacked := gsm.use_attack(0, 1)

	var basic_energy := CardInstance.create(_energy("Psychic Energy", "P"), 1)
	var special_energy := CardInstance.create(_energy("Double Turbo Energy", "C", "Special Energy"), 1)
	var stadium := CardInstance.create(_trainer("Test Stadium", "Stadium"), 1)
	state.players[1].hand.append_array([basic_energy, special_energy, stadium])
	var builder = AILegalActionBuilderScript.new()
	var actions: Array[Dictionary] = builder.build_actions(gsm, 1)

	return run_checks([
		assert_true(attacked, "CSVL1C_045 Dominating Echo should execute before AI action filtering is checked"),
		assert_true(_actions_include_card(actions, "attach_energy", basic_energy), "AI/legal action builder should still enumerate Basic Energy attachments"),
		assert_false(_actions_include_card(actions, "attach_energy", special_energy), "AI/legal action builder should not enumerate Special Energy attachments under Dominating Echo"),
		assert_false(_actions_include_card(actions, "play_stadium", stadium), "AI/legal action builder should not enumerate Stadium play under Dominating Echo"),
		assert_true(NoivernExEffectsScript.is_player_locked(1, state), "CSVL1C_045 Dominating Echo should record the opponent-turn player lock flag"),
	])


func test_csvl1c_045_noivern_ex_dominating_echo_player_lock_survives_source_leaving_play() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var noivern := _noivern_ex()
	var defender := _pokemon("Target", "", [_attack("Hit", "C", "10")], [], "C", 300)
	var slots := _setup_battle(gsm, noivern, defender)
	gsm.effect_processor.register_pokemon_card(noivern)
	_attach_energy(slots[0], 0, "P", 1)
	_attach_energy(slots[0], 0, "D", 1)
	var attacked := gsm.use_attack(0, 1)
	state.players[0].active_pokemon = _slot(_pokemon("Replacement", "", [_attack("Hit", "C", "10")]), 0)

	var basic_energy := CardInstance.create(_energy("Psychic Energy", "P"), 1)
	var special_energy := CardInstance.create(_energy("Double Turbo Energy", "C", "Special Energy"), 1)
	var stadium := CardInstance.create(_trainer("Test Stadium", "Stadium"), 1)
	var can_attach_basic := gsm.rule_validator.can_attach_energy(state, 1, basic_energy, gsm.effect_processor)
	var can_attach_special := gsm.rule_validator.can_attach_energy(state, 1, special_energy, gsm.effect_processor)
	var can_play_stadium := gsm.rule_validator.can_play_stadium(state, 1, stadium, gsm.effect_processor)

	return run_checks([
		assert_true(attacked, "CSVL1C_045 Dominating Echo should execute before source leaves play"),
		assert_true(NoivernExEffectsScript.is_player_locked(1, state), "Dominating Echo should persist as a player-turn lock"),
		assert_true(can_attach_basic, "Dominating Echo source leaving play should not block Basic Energy"),
		assert_false(can_attach_special, "Dominating Echo Special Energy lock should survive the source leaving play"),
		assert_false(can_play_stadium, "Dominating Echo Stadium lock should survive the source leaving play"),
	])


func _damage_noivern_after_hidden_flight(noivern: CardData, incoming_attacker: CardData) -> int:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var defender := _pokemon("Target", "", [_attack("Hit", "C", "10")], [], "C", 300)
	var slots := _setup_battle(gsm, noivern, defender)
	gsm.effect_processor.register_pokemon_card(noivern)
	_attach_energy(slots[0], 0, "C", 2)
	gsm.use_attack(0, 0)

	var incoming_slot := _slot(incoming_attacker, 1)
	_attach_energy(incoming_slot, 1, "C", 1)
	state.players[1].active_pokemon = incoming_slot
	gsm.use_attack(1, 0)
	return state.players[0].active_pokemon.damage_counters


func _actions_include_kind(actions: Array[Dictionary], kind: String) -> bool:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == kind:
			return true
	return false


func _actions_include_card(actions: Array[Dictionary], kind: String, card: CardInstance) -> bool:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if action.get("card", null) == card:
			return true
	return false
