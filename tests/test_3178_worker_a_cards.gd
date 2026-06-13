class_name Test3178WorkerACards
extends TestBase


const KLAWF_EFFECT_ID := "f986b356ae9703ac2d1667d1897cfdb6"
const SNEASLER_EFFECT_ID := "146a354ca20b3943ab792aa29b070fda"
const ORANGURU_EFFECT_ID := "c5783c83303269674231483fede75e99"
const ELECTRODE_EFFECT_ID := "f9a90aafccf9445be72a6ed15f66bcd6"
const BRUTE_BONNET_EFFECT_ID := "a5438c6290fdef331fe1ba579b6f4928"
const ANCIENT_BOOSTER_EFFECT_ID := "8da8631aa1827b122ec65b712939ad48"
const FUTURE_BOOSTER_EFFECT_ID := "54920a273edba38ce45f3bc8f6e8ff25"


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


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(
	name: String,
	effect_id: String,
	attacks: Array[Dictionary],
	abilities: Array[Dictionary],
	energy_type: String,
	hp: int,
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.attacks = attacks
	cd.abilities = abilities
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = "Basic"
	cd.mechanic = mechanic
	return cd


func _trainer(name: String, card_type: String, effect_id: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _energy(name: String, energy_type: String = "C", card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))


func _find_ability_action(actions: Array[Dictionary], source_slot: PokemonSlot, ability_index: int = 0) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != "use_ability":
			continue
		if action.get("source_slot", null) != source_slot:
			continue
		if int(action.get("ability_index", -1)) != ability_index:
			continue
		return action
	return {}


func _klawf() -> CardData:
	var cd := _pokemon(
		"Klawf",
		KLAWF_EFFECT_ID,
		[
			{"name": "Crisis Scissors", "cost": "CC", "damage": "30+", "text": "If this Pokemon is affected by a Special Condition, this attack does 160 more damage.", "is_vstar_power": false},
			{"name": "Boiling Press", "cost": "FF", "damage": "80", "text": "This Pokemon is now Burned.", "is_vstar_power": false},
		],
		[],
		"F",
		120
	)
	cd.set_code = "CSV6C"
	cd.card_index = "080"
	return cd


func _sneasler() -> CardData:
	var cd := _pokemon(
		"Radiant Hisuian Sneasler",
		SNEASLER_EFFECT_ID,
		[{"name": "Poison Jab", "cost": "DCC", "damage": "90", "text": "Your opponent's Active Pokemon is now Poisoned.", "is_vstar_power": false}],
		[{"name": "Poison Peak", "text": "Put 2 more damage counters on your opponent's Poisoned Active Pokemon during Pokemon Check."}],
		"D",
		130,
		"Radiant"
	)
	cd.set_code = "CS5aC"
	cd.card_index = "079"
	return cd


func _oranguru_v() -> CardData:
	var cd := _pokemon(
		"Oranguru V",
		ORANGURU_EFFECT_ID,
		[{"name": "Psychic", "cost": "CCC", "damage": "30+", "text": "This attack does 50 more damage for each Energy attached to your opponent's Active Pokemon.", "is_vstar_power": false}],
		[{"name": "Back Order", "text": "If this Pokemon is in the Active Spot, search your deck for up to 2 Pokemon Tool cards and put them into your hand."}],
		"C",
		210,
		"V"
	)
	cd.set_code = "CS5bC"
	cd.card_index = "113"
	return cd


func _electrode_v() -> CardData:
	var cd := _pokemon(
		"Hisuian Electrode V",
		ELECTRODE_EFFECT_ID,
		[
			{"name": "Tantrum Blast", "cost": "0", "damage": "100x", "text": "This attack does 100 damage for each Special Condition affecting this Pokemon.", "is_vstar_power": false},
			{"name": "Solar Shot", "cost": "GC", "damage": "120", "text": "Discard all Energy from this Pokemon.", "is_vstar_power": false},
		],
		[],
		"G",
		210,
		"V"
	)
	cd.set_code = "CS5.5C"
	cd.card_index = "003"
	return cd


func _brute_bonnet() -> CardData:
	var cd := _pokemon(
		"Brute Bonnet",
		BRUTE_BONNET_EFFECT_ID,
		[{"name": "Rampaging Hammer", "cost": "DDC", "damage": "120", "text": "During your next turn, this Pokemon can't attack.", "is_vstar_power": false}],
		[{"name": "Toxic Powder", "text": "If this Pokemon has Ancient Booster Energy Capsule attached, both Active Pokemon are now Poisoned."}],
		"D",
		120
	)
	cd.set_code = "CSV6C"
	cd.card_index = "095"
	cd.is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	return cd


func test_3178_worker_a_effect_id_registration_resolves_all_five_cards() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var cards: Array[CardData] = [_klawf(), _sneasler(), _oranguru_v(), _electrode_v(), _brute_bonnet()]
	for card: CardData in cards:
		processor.register_pokemon_card(card)

	return run_checks([
		assert_true(processor.has_attack_effect(KLAWF_EFFECT_ID), "Klawf should register attack effects by effect_id"),
		assert_not_null(processor.get_effect(SNEASLER_EFFECT_ID), "Radiant Hisuian Sneasler should register Poison Peak by effect_id"),
		assert_not_null(processor.get_effect(ORANGURU_EFFECT_ID), "Oranguru V should register Back Order by effect_id"),
		assert_true(processor.has_attack_effect(ELECTRODE_EFFECT_ID), "Hisuian Electrode V should register attack effects by effect_id"),
		assert_not_null(processor.get_effect(BRUTE_BONNET_EFFECT_ID), "Brute Bonnet should register Toxic Powder by effect_id"),
		assert_false(CardImplementationStatus.is_unimplemented(_klawf()), "Klawf should not be reported as unimplemented"),
		assert_false(CardImplementationStatus.is_unimplemented(_sneasler()), "Radiant Hisuian Sneasler should not be reported as unimplemented"),
		assert_false(CardImplementationStatus.is_unimplemented(_oranguru_v()), "Oranguru V should not be reported as unimplemented"),
		assert_false(CardImplementationStatus.is_unimplemented(_electrode_v()), "Hisuian Electrode V should not be reported as unimplemented"),
		assert_false(CardImplementationStatus.is_unimplemented(_brute_bonnet()), "Brute Bonnet should not be reported as unimplemented"),
	])


func test_3178_worker_a_klawf_attack_effects_are_bound_to_the_correct_attacks() -> String:
	var scissors_gsm := _make_gsm()
	var scissors_player: PlayerState = scissors_gsm.game_state.players[0]
	var scissors_opponent: PlayerState = scissors_gsm.game_state.players[1]
	var normal_klawf := _make_slot(_klawf(), 0)
	scissors_player.active_pokemon = normal_klawf
	scissors_opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 300), 1)
	_attach_energy(normal_klawf, 0, "C", 2)
	scissors_gsm.effect_processor.register_pokemon_card(normal_klawf.get_card_data())
	var normal_attack := scissors_gsm.use_attack(0, 0)

	var status_gsm := _make_gsm()
	var status_player: PlayerState = status_gsm.game_state.players[0]
	var status_opponent: PlayerState = status_gsm.game_state.players[1]
	var status_klawf := _make_slot(_klawf(), 0)
	status_player.active_pokemon = status_klawf
	status_opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 300), 1)
	_attach_energy(status_klawf, 0, "C", 2)
	status_klawf.set_status("poisoned", true)
	status_gsm.effect_processor.register_pokemon_card(status_klawf.get_card_data())
	var status_attack := status_gsm.use_attack(0, 0)

	var boiling_gsm := _make_gsm()
	var boiling_player: PlayerState = boiling_gsm.game_state.players[0]
	var boiling_opponent: PlayerState = boiling_gsm.game_state.players[1]
	var boiling_klawf := _make_slot(_klawf(), 0)
	boiling_player.active_pokemon = boiling_klawf
	boiling_opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 300), 1)
	_attach_energy(boiling_klawf, 0, "F", 2)
	boiling_gsm.effect_processor.register_pokemon_card(boiling_klawf.get_card_data())
	var boiling_attack := boiling_gsm.use_attack(0, 1)

	return run_checks([
		assert_true(normal_attack, "Klawf should use Crisis Scissors without a Special Condition"),
		assert_eq(scissors_opponent.active_pokemon.damage_counters, 30, "Crisis Scissors should stay at 30 without a Special Condition"),
		assert_false(normal_klawf.status_conditions.get("burned", false), "Crisis Scissors must not apply Boiling Press self Burn"),
		assert_true(status_attack, "Klawf should use Crisis Scissors with a Special Condition"),
		assert_eq(status_opponent.active_pokemon.damage_counters, 190, "Crisis Scissors should add 160 with any Special Condition"),
		assert_true(boiling_attack, "Klawf should use Boiling Press"),
		assert_eq(boiling_opponent.active_pokemon.damage_counters, 80, "Boiling Press should not receive the Crisis Scissors bonus"),
		assert_eq(boiling_klawf.damage_counters, 20, "Boiling Press self Burn should be applied during Pokemon Check"),
	])


func test_3178_worker_a_sneasler_poison_peak_only_boosts_opponents_active_poison() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var own_active := _make_slot(_pokemon("Own Active", "", [], [], "C", 300), 0)
	var sneasler := _make_slot(_sneasler(), 0)
	var opponent_active := _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	state.players[0].active_pokemon = own_active
	state.players[0].bench.append(sneasler)
	state.players[1].active_pokemon = opponent_active
	own_active.set_status("poisoned", true)
	opponent_active.set_status("poisoned", true)
	processor.register_pokemon_card(sneasler.get_card_data())
	processor.process_pokemon_check(state)

	return run_checks([
		assert_eq(own_active.damage_counters, 10, "Poison Peak should not boost poison on Sneasler owner's Active Pokemon"),
		assert_eq(opponent_active.damage_counters, 30, "Poison Peak should add 2 counters to poison on the opponent's Active Pokemon"),
	])


func test_3178_worker_a_iron_thorns_suppresses_radiant_sneasler_poison_peak() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var sneasler := _make_slot(_sneasler(), 0)
	player.bench.append(sneasler)

	var iron_thorns_cd := _pokemon(
		"Iron Thorns ex",
		"",
		[{"name": "Volt Cyclone", "cost": "LC", "damage": "140", "text": "", "is_vstar_power": false}],
		[{"name": "初始化"}],
		"L",
		230,
		"ex"
	)
	iron_thorns_cd.is_tags = ["Future"]
	opponent.active_pokemon = _make_slot(iron_thorns_cd, 1)
	opponent.active_pokemon.set_status("poisoned", true)

	processor.register_pokemon_card(sneasler.get_card_data())
	processor.process_pokemon_check(state)

	return run_checks([
		assert_true(processor.is_ability_disabled(sneasler, state), "Iron Thorns should disable Radiant Hisuian Sneasler as a Rule Box Pokemon"),
		assert_eq(opponent.active_pokemon.damage_counters, 10, "Poison Peak should not add extra poison counters while Iron Thorns is active"),
	])


func test_3178_worker_a_sneasler_poison_jab_poison_is_boosted_by_poison_peak() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var sneasler := _make_slot(_sneasler(), 0)
	player.active_pokemon = sneasler
	opponent.active_pokemon = _make_slot(_pokemon("Poison Defender", "", [], [], "C", 300), 1)
	_attach_energy(sneasler, 0, "D", 1)
	_attach_energy(sneasler, 0, "C", 2)
	gsm.effect_processor.register_pokemon_card(sneasler.get_card_data())
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attacked, "Poison Jab should resolve with its printed Energy cost paid"),
		assert_true(opponent.active_pokemon.status_conditions.get("poisoned", false), "Poison Jab should poison the opponent's Active Pokemon"),
		assert_eq(opponent.active_pokemon.damage_counters, 120, "Poison Jab damage plus Pokemon Check poison should include Poison Peak's 2 extra counters"),
	])


func test_3178_worker_a_brute_bonnet_requires_ancient_booster_and_once_per_turn() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var brute := _make_slot(_brute_bonnet(), 0)
	player.active_pokemon = brute
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active", "", [], [], "C", 300), 1)
	gsm.effect_processor.register_pokemon_card(brute.get_card_data())
	var no_tool_allowed := gsm.effect_processor.can_use_ability(brute, gsm.game_state, 0)
	brute.attached_tool = CardInstance.create(_trainer("Future Booster Energy Capsule", "Tool", FUTURE_BOOSTER_EFFECT_ID), 0)
	var wrong_tool_allowed := gsm.effect_processor.can_use_ability(brute, gsm.game_state, 0)
	brute.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", ANCIENT_BOOSTER_EFFECT_ID), 0)
	var right_tool_allowed := gsm.effect_processor.can_use_ability(brute, gsm.game_state, 0)
	var used := gsm.use_ability(0, brute, 0, [])
	var repeat_allowed := gsm.effect_processor.can_use_ability(brute, gsm.game_state, 0)
	gsm.game_state.current_player_index = 1
	var opponent_turn_allowed := gsm.effect_processor.can_use_ability(brute, gsm.game_state, 0)

	var lock_gsm := _make_gsm()
	var lock_player: PlayerState = lock_gsm.game_state.players[0]
	var lock_opponent: PlayerState = lock_gsm.game_state.players[1]
	var attacking_brute := _make_slot(_brute_bonnet(), 0)
	lock_player.active_pokemon = attacking_brute
	lock_opponent.active_pokemon = _make_slot(_pokemon("Lock Defender", "", [], [], "C", 300), 1)
	_attach_energy(attacking_brute, 0, "D", 2)
	_attach_energy(attacking_brute, 0, "C", 1)
	lock_gsm.effect_processor.register_pokemon_card(attacking_brute.get_card_data())
	var rampaging_hammer_used := lock_gsm.use_attack(0, 0)
	lock_gsm.game_state.current_player_index = 0
	lock_gsm.game_state.turn_number = 4
	lock_gsm.game_state.phase = GameState.GamePhase.MAIN
	var rampaging_hammer_locked := not lock_gsm.can_use_attack(0, 0)

	var bench_gsm := _make_gsm()
	var bench_player: PlayerState = bench_gsm.game_state.players[0]
	var bench_opponent: PlayerState = bench_gsm.game_state.players[1]
	var pivot := _make_slot(_pokemon("Own Active", "", [], [], "C", 300), 0)
	var bench_brute := _make_slot(_brute_bonnet(), 0)
	bench_player.active_pokemon = pivot
	bench_player.bench.append(bench_brute)
	bench_opponent.active_pokemon = _make_slot(_pokemon("Bench Ability Defender", "", [], [], "C", 300), 1)
	bench_brute.attached_tool = CardInstance.create(_trainer("Ancient Booster Energy Capsule", "Tool", ANCIENT_BOOSTER_EFFECT_ID), 0)
	bench_gsm.effect_processor.register_pokemon_card(bench_brute.get_card_data())
	var bench_allowed := bench_gsm.effect_processor.can_use_ability(bench_brute, bench_gsm.game_state, 0)
	var bench_used := bench_gsm.use_ability(0, bench_brute, 0, [])

	return run_checks([
		assert_false(no_tool_allowed, "Toxic Powder should require Ancient Booster Energy Capsule attached"),
		assert_false(wrong_tool_allowed, "Toxic Powder should not accept Future Booster Energy Capsule"),
		assert_true(right_tool_allowed, "Toxic Powder should be usable with Ancient Booster Energy Capsule attached"),
		assert_true(used, "Toxic Powder should resolve"),
		assert_false(brute.status_conditions.get("poisoned", false), "Ancient Booster should prevent Brute Bonnet from poisoning itself"),
		assert_true(opponent.active_pokemon.status_conditions.get("poisoned", false), "Toxic Powder should poison the opponent's Active Pokemon"),
		assert_false(repeat_allowed, "Toxic Powder should be once during your turn"),
		assert_false(opponent_turn_allowed, "Toxic Powder should not be usable during the opponent's turn"),
		assert_true(rampaging_hammer_used, "Rampaging Hammer should resolve"),
		assert_true(rampaging_hammer_locked, "Rampaging Hammer should lock itself during the next own turn"),
		assert_true(bench_allowed, "Toxic Powder should be usable while Brute Bonnet is on the Bench"),
		assert_true(bench_used, "Bench Brute Bonnet should resolve Toxic Powder"),
		assert_true(pivot.status_conditions.get("poisoned", false), "Bench Toxic Powder should poison the owner's Active Pokemon"),
		assert_true(bench_opponent.active_pokemon.status_conditions.get("poisoned", false), "Bench Toxic Powder should poison the opponent's Active Pokemon"),
	])


func test_3178_worker_a_oranguru_back_order_search_boundaries() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var oranguru := _make_slot(_oranguru_v(), 0)
	var pivot := _make_slot(_pokemon("Pivot", "", [], [], "C", 300), 0)
	player.active_pokemon = pivot
	player.bench.append(oranguru)
	opponent.active_pokemon = _make_slot(_pokemon("Energy Defender", "", [], [], "C", 300), 1)
	var tool_a := CardInstance.create(_trainer("Tool A", "Tool", "tool-a"), 0)
	var item := CardInstance.create(_trainer("Item", "Item", "item"), 0)
	var tool_b := CardInstance.create(_trainer("Tool B", "Tool", "tool-b"), 0)
	player.deck.append(tool_a)
	player.deck.append(item)
	player.deck.append(tool_b)
	gsm.effect_processor.register_pokemon_card(oranguru.get_card_data())
	var bench_allowed := gsm.effect_processor.can_use_ability(oranguru, gsm.game_state, 0)
	player.active_pokemon = oranguru
	player.bench.clear()
	var active_allowed := gsm.effect_processor.can_use_ability(oranguru, gsm.game_state, 0)
	var effect := gsm.effect_processor.get_effect(ORANGURU_EFFECT_ID)
	var steps := effect.get_interaction_steps(oranguru.get_top_card(), gsm.game_state)
	var used := gsm.use_ability(0, oranguru, 0, [{"search_cards": [tool_b]}])
	var repeat_allowed := gsm.effect_processor.can_use_ability(oranguru, gsm.game_state, 0)

	return run_checks([
		assert_false(bench_allowed, "Back Order should require Oranguru V in the Active Spot"),
		assert_true(active_allowed, "Back Order should be usable from the Active Spot"),
		assert_eq(str(steps[0].get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Back Order should expose the full own deck for UI inspection"),
		assert_eq(int(steps[0].get("visible_count", 0)), 3, "Back Order should show non-candidate deck cards as visible-only"),
		assert_eq(int(steps[0].get("selectable_count", 0)), 2, "Back Order should only allow Tool cards to be selected"),
		assert_eq(steps[0].get("card_indices", []), [0, -1, 1], "Back Order should mark non-Tool cards unselectable"),
		assert_eq(int(steps[0].get("min_select", -1)), 0, "Back Order should allow choosing zero cards"),
		assert_eq(int(steps[0].get("max_select", -1)), 2, "Back Order should cap the search at 2 Tool cards"),
		assert_true(used, "Back Order should resolve with an explicit partial selection"),
		assert_true(tool_b in player.hand, "Back Order should put the selected Tool into hand"),
		assert_true(tool_a in player.deck and item in player.deck, "Back Order should leave unselected and illegal cards in deck"),
		assert_false(repeat_allowed, "Back Order should be once during your turn"),
	])


func test_3178_worker_a_oranguru_back_order_ai_action_targets_tool_cards_only() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var oranguru := _make_slot(_oranguru_v(), 0)
	player.active_pokemon = oranguru
	opponent.active_pokemon = _make_slot(_pokemon("Energy Defender", "", [], [], "C", 300), 1)
	var tool_a := CardInstance.create(_trainer("Tool A", "Tool", "tool-a"), 0)
	var item := CardInstance.create(_trainer("Item", "Item", "item"), 0)
	var tool_b := CardInstance.create(_trainer("Tool B", "Tool", "tool-b"), 0)
	player.deck.append(tool_a)
	player.deck.append(item)
	player.deck.append(tool_b)

	var builder := AILegalActionBuilder.new()
	var actions := builder.build_actions(gsm, 0)
	var action := _find_ability_action(actions, oranguru, 0)
	var targets: Array = action.get("targets", [])
	var ctx: Dictionary = targets[0] if not targets.is_empty() and targets[0] is Dictionary else {}
	var selected: Array = ctx.get("search_cards", [])
	var used := false
	if not action.is_empty():
		used = gsm.use_ability(0, oranguru, 0, targets)

	return run_checks([
		assert_false(action.is_empty(), "AI legal action builder should enumerate Back Order from the Active Spot"),
		assert_false(bool(action.get("requires_interaction", true)), "Headless Back Order should auto-resolve a legal Tool selection"),
		assert_true(tool_a in selected and tool_b in selected, "Headless Back Order should select the available Tool cards"),
		assert_false(item in selected, "Headless Back Order must not select non-Tool deck cards"),
		assert_true(used, "AI-produced Back Order targets should execute through GameStateMachine.use_ability"),
		assert_true(tool_a in player.hand and tool_b in player.hand, "AI-produced Back Order should put selected Tools into hand"),
		assert_true(item in player.deck, "AI-produced Back Order should leave non-Tool cards in deck"),
	])


func test_3178_worker_a_electrode_zero_cost_and_status_count_damage() -> String:
	var no_status_gsm := _make_gsm()
	var no_status_player: PlayerState = no_status_gsm.game_state.players[0]
	var no_status_opponent: PlayerState = no_status_gsm.game_state.players[1]
	var no_status_electrode := _make_slot(_electrode_v(), 0)
	no_status_player.active_pokemon = no_status_electrode
	no_status_opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 400), 1)
	no_status_gsm.effect_processor.register_pokemon_card(no_status_electrode.get_card_data())
	var zero_cost_attack := no_status_gsm.use_attack(0, 0)

	var status_gsm := _make_gsm()
	var status_player: PlayerState = status_gsm.game_state.players[0]
	var status_opponent: PlayerState = status_gsm.game_state.players[1]
	var status_electrode := _make_slot(_electrode_v(), 0)
	status_player.active_pokemon = status_electrode
	status_opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 400), 1)
	status_electrode.set_status("poisoned", true)
	status_electrode.set_status("burned", true)
	status_gsm.effect_processor.register_pokemon_card(status_electrode.get_card_data())
	var status_preview := status_gsm.get_attack_preview_damage(0, 0)
	var status_attack := status_gsm.use_attack(0, 0)

	var solar_gsm := _make_gsm()
	var solar_player: PlayerState = solar_gsm.game_state.players[0]
	var solar_opponent: PlayerState = solar_gsm.game_state.players[1]
	var solar_electrode := _make_slot(_electrode_v(), 0)
	solar_player.active_pokemon = solar_electrode
	solar_opponent.active_pokemon = _make_slot(_pokemon("Defender", "", [], [], "C", 400), 1)
	_attach_energy(solar_electrode, 0, "G", 1)
	_attach_energy(solar_electrode, 0, "C", 1)
	solar_gsm.effect_processor.register_pokemon_card(solar_electrode.get_card_data())
	var solar_attack := solar_gsm.use_attack(0, 1)

	return run_checks([
		assert_true(zero_cost_attack, "Tantrum Blast should be usable with no Energy attached"),
		assert_eq(no_status_opponent.active_pokemon.damage_counters, 0, "Tantrum Blast should do 0 damage with no Special Conditions"),
		assert_eq(status_preview, 200, "Tantrum Blast preview should count each Special Condition"),
		assert_true(status_attack, "Tantrum Blast should resolve with Special Conditions"),
		assert_eq(status_opponent.active_pokemon.damage_counters, 200, "Tantrum Blast should deal 100 per Special Condition"),
		assert_true(solar_attack, "Solar Shot should resolve"),
		assert_eq(solar_electrode.attached_energy.size(), 0, "Solar Shot should discard all attached Energy"),
		assert_eq(solar_player.discard_pile.size(), 2, "Solar Shot should move discarded Energy to the owner's discard pile"),
	])
