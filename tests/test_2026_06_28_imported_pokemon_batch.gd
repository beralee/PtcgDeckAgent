class_name Test20260628ImportedPokemonBatch
extends TestBase

const AttackMoveOpponentHandCardToDeckScript = preload("res://scripts/effects/pokemon_effects/AttackMoveOpponentHandCardToDeck.gd")
const AttackTopDeckPokemonToBenchScript = preload("res://scripts/effects/pokemon_effects/AttackTopDeckPokemonToBench.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")

const EFFECT_SNORUNT := "f6baf0c4c60ff47c7f836c1271f40cb3"
const EFFECT_FROSLASS := "f27a2982c03f5b49a68ec0a77a2d6e48"
const EFFECT_TATSUGIRI_EX := "b1bef15b71f5b719d49ad7376b879a60"
const EFFECT_INCINEROAR_EX := "9a665c4cff5995deffdc83139ca9b39f"
const EFFECT_ZUBAT := "bd712c72418b762b995cf1acd175c688"


class SequenceCoinFlipper extends CoinFlipper:
	var results: Array[bool] = []
	var index: int = 0

	func _init(sequence: Array[bool] = []) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var result := false
		if index < results.size():
			result = results[index]
		index += 1
		coin_flipped.emit(result)
		return result


func test_imported_cards_register_expected_effect_entries() -> String:
	var gsm := _make_gsm()
	var snorunt := _make_slot(_snorunt(), 0)
	var froslass := _make_slot(_froslass(), 0)
	var tatsugiri := _make_slot(_tatsugiri_ex(), 0)
	var incineroar := _make_slot(_incineroar_ex(), 0)
	var zubat := _make_slot(_zubat(), 0)
	for slot: PokemonSlot in [snorunt, froslass, tatsugiri, incineroar, zubat]:
		gsm.effect_processor.register_pokemon_card(slot.get_card_data())

	return run_checks([
		assert_true(gsm.effect_processor.has_attack_effect(EFFECT_SNORUNT), "Snorunt Astonish should register an attack effect"),
		assert_true(gsm.effect_processor.has_effect(EFFECT_FROSLASS), "Froslass Freezing Shroud should register as a passive ability effect"),
		assert_eq(gsm.effect_processor.get_attack_effects_for_slot(tatsugiri, 0).size(), 1, "Tatsugiri ex first attack should register the defender-effect ignore"),
		assert_eq(gsm.effect_processor.get_attack_effects_for_slot(tatsugiri, 1).size(), 1, "Tatsugiri ex second attack should register the top-10 bench effect"),
		assert_true(gsm.effect_processor.has_effect(EFFECT_INCINEROAR_EX), "Incineroar ex should register the attack cost reduction ability"),
		assert_eq(gsm.effect_processor.get_attack_effects_for_slot(incineroar, 0).size(), 1, "Incineroar ex attack should register Burn"),
		assert_eq(gsm.effect_processor.get_attack_effects_for_slot(zubat, 0).size(), 1, "Zubat first attack should register Supporter search"),
		assert_eq(gsm.effect_processor.get_attack_effects_for_slot(zubat, 1).size(), 0, "Zubat second attack should not inherit Supporter search"),
	])


func test_ai_action_builder_exposes_imported_attack_interactions() -> String:
	var snorunt_gsm := _make_gsm()
	var snorunt_player: PlayerState = snorunt_gsm.game_state.players[0]
	var snorunt_opponent: PlayerState = snorunt_gsm.game_state.players[1]
	var snorunt := _make_slot(_snorunt(), 0)
	_attach_energy(snorunt, 0, "W", 1)
	_attach_energy(snorunt, 0, "C", 1)
	snorunt_player.active_pokemon = snorunt
	snorunt_opponent.active_pokemon = _make_slot(_target("Snorunt Defender", 100), 1)
	snorunt_opponent.hand = [CardInstance.create(_trainer("Hidden Opponent Card", "Item"), 1)]
	snorunt_gsm.effect_processor.register_pokemon_card(snorunt.get_card_data())
	var snorunt_action := _find_attack_action(snorunt_gsm, 0)

	var tatsugiri_gsm := _make_gsm()
	var tatsugiri_player: PlayerState = tatsugiri_gsm.game_state.players[0]
	var tatsugiri := _make_slot(_tatsugiri_ex(), 0)
	_attach_energy(tatsugiri, 0, "R", 1)
	_attach_energy(tatsugiri, 0, "W", 1)
	_attach_energy(tatsugiri, 0, "D", 1)
	tatsugiri_player.active_pokemon = tatsugiri
	tatsugiri_gsm.game_state.players[1].active_pokemon = _make_slot(_target("Tatsugiri Defender", 100), 1)
	tatsugiri_player.deck = [CardInstance.create(_pokemon("Top Pokemon"), 0)]
	tatsugiri_gsm.effect_processor.register_pokemon_card(tatsugiri.get_card_data())
	var tatsugiri_first_action := _find_attack_action(tatsugiri_gsm, 0)
	var tatsugiri_second_action := _find_attack_action(tatsugiri_gsm, 1)

	var zubat_gsm := _make_gsm()
	var zubat_player: PlayerState = zubat_gsm.game_state.players[0]
	var zubat := _make_slot(_zubat(), 0)
	_attach_energy(zubat, 0, "D", 1)
	zubat_player.active_pokemon = zubat
	zubat_gsm.game_state.players[1].active_pokemon = _make_slot(_target("Zubat Defender", 100), 1)
	zubat_player.deck = [CardInstance.create(_trainer("Deck Supporter", "Supporter"), 0)]
	zubat_gsm.effect_processor.register_pokemon_card(zubat.get_card_data())
	var zubat_first_action := _find_attack_action(zubat_gsm, 0)
	var zubat_second_action := _find_attack_action(zubat_gsm, 1)

	return run_checks([
		assert_false(snorunt_action.is_empty(), "AI should enumerate Snorunt's Astonish attack"),
		assert_true(bool(snorunt_action.get("requires_interaction", false)), "Snorunt Astonish should require hidden opponent-hand interaction"),
		assert_false(tatsugiri_first_action.is_empty(), "AI should enumerate Tatsugiri ex's first attack"),
		assert_false(bool(tatsugiri_first_action.get("requires_interaction", true)), "Tatsugiri ex's first attack should not require the second attack's top-deck interaction"),
		assert_false(tatsugiri_second_action.is_empty(), "AI should enumerate Tatsugiri ex's Vermilion Lure"),
		assert_true(bool(tatsugiri_second_action.get("requires_interaction", false)), "Tatsugiri ex's Vermilion Lure should require top-10 selection interaction"),
		assert_false(zubat_first_action.is_empty(), "AI should enumerate Zubat's Guiding attack"),
		assert_true(bool(zubat_first_action.get("requires_interaction", false)), "Zubat Guiding should require full-deck Supporter search interaction"),
		assert_false(zubat_second_action.is_empty(), "AI should enumerate Zubat's Dark Fang"),
		assert_false(bool(zubat_second_action.get("requires_interaction", true)), "Zubat Dark Fang should not inherit Guiding's search interaction"),
	])


func test_snorunt_astonish_moves_only_selected_hidden_opponent_hand_card_to_deck() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var snorunt := _make_slot(_snorunt(), 0)
	_attach_energy(snorunt, 0, "W", 1)
	_attach_energy(snorunt, 0, "C", 1)
	player.active_pokemon = snorunt
	opponent.active_pokemon = _make_slot(_target("Opponent Active", 100), 1)
	opponent.hand.clear()
	opponent.deck.clear()
	var item := CardInstance.create(_trainer("Opponent Item", "Item"), 1)
	var basic := CardInstance.create(_pokemon("Opponent Basic", "", [], [], "C", 70), 1)
	var filler := CardInstance.create(_trainer("Deck Filler", "Item"), 1)
	opponent.hand.append_array([item, basic])
	opponent.deck.append(filler)
	gsm.effect_processor.register_pokemon_card(snorunt.get_card_data())

	var effect := AttackMoveOpponentHandCardToDeckScript.new()
	var steps := effect.get_attack_interaction_steps(snorunt.get_top_card(), snorunt.get_card_data().attacks[0], gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var attacked := gsm.use_attack(0, 0, [{AttackMoveOpponentHandCardToDeckScript.STEP_ID: [basic]}])

	return run_checks([
		assert_eq(steps.size(), 1, "Astonish should ask for one opponent hand card when the opponent has cards"),
		assert_eq(str(step.get("visible_scope", "")), "opponent_hand_hidden", "Astonish should not expose a full-library or deck scope"),
		assert_false(step.has("card_items"), "Astonish should use hidden labels instead of revealing opponent hand card faces"),
		assert_eq(int(step.get("min_select", -1)), 1, "Astonish choice is mandatory when the opponent has hand cards"),
		assert_true(attacked, "Snorunt should be able to attack with Water plus Colorless Energy"),
		assert_eq(opponent.active_pokemon.damage_counters, 20, "Astonish should still deal printed 20 damage"),
		assert_true(item in opponent.hand, "Astonish should leave the unselected hand card in hand"),
		assert_false(basic in opponent.hand, "Astonish should remove the selected hand card"),
		assert_true(basic in opponent.deck, "Astonish should shuffle the revealed card into the opponent deck"),
		assert_false(basic.face_up, "Astonish should not leave the shuffled opponent deck card face-up"),
		assert_eq(opponent.shuffle_count, 1, "Astonish should shuffle the opponent deck once"),
	])


func test_froslass_freezing_shroud_pokemon_check_damages_ability_pokemon_except_froslass() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var froslass := _make_slot(_froslass(), 0)
	var own_ability := _make_slot(_pokemon("Own Ability", "", [], [_ability("Own")], "W", 90), 0)
	var own_no_ability := _make_slot(_pokemon("Own No Ability", "", [], [], "W", 90), 0)
	var other_froslass := _make_slot(_pokemon("Froslass", "", [], [_ability("Other Ability")], "W", 90, "Stage 1"), 0)
	var opponent_ability := _make_slot(_pokemon("Opponent Ability", "", [], [_ability("Opp")], "D", 90), 1)
	state.players[0].active_pokemon = froslass
	state.players[0].bench = [own_ability, own_no_ability, other_froslass]
	state.players[1].active_pokemon = opponent_ability
	processor.register_pokemon_card(froslass.get_card_data())

	var damaged := processor.process_pokemon_check(state)

	return run_checks([
		assert_eq(froslass.damage_counters, 0, "Freezing Shroud should not damage Froslass itself"),
		assert_eq(own_ability.damage_counters, 10, "Freezing Shroud should damage own Pokemon with abilities"),
		assert_eq(own_no_ability.damage_counters, 0, "Freezing Shroud should ignore Pokemon without abilities"),
		assert_eq(other_froslass.damage_counters, 0, "Freezing Shroud should exempt other Froslass even when they have abilities"),
		assert_eq(opponent_ability.damage_counters, 10, "Freezing Shroud should damage opponent Pokemon with abilities"),
		assert_true(own_ability in damaged, "Freezing Shroud damage should be reported in damaged slots"),
		assert_false(other_froslass in damaged, "Exempt Froslass should not be reported as damaged"),
		assert_true(opponent_ability in damaged, "Opponent Freezing Shroud damage should be reported in damaged slots"),
	])


func test_tatsugiri_ex_second_attack_only_shows_top_ten_and_benches_selected_pokemon() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var tatsugiri := _make_slot(_tatsugiri_ex(), 0)
	_attach_energy(tatsugiri, 0, "R", 1)
	_attach_energy(tatsugiri, 0, "W", 1)
	_attach_energy(tatsugiri, 0, "D", 1)
	player.active_pokemon = tatsugiri
	player.bench.clear()
	player.bench.append_array([
		_make_slot(_pokemon("Existing 1"), 0),
		_make_slot(_pokemon("Existing 2"), 0),
		_make_slot(_pokemon("Existing 3"), 0),
	])
	var basic_a := CardInstance.create(_pokemon("Basic A"), 0)
	var item := CardInstance.create(_trainer("Item A", "Item"), 0)
	var stage_one := CardInstance.create(_pokemon("Stage One", "", [], [], "W", 90, "Stage 1"), 0)
	var supporter := CardInstance.create(_trainer("Supporter A", "Supporter"), 0)
	var basic_b := CardInstance.create(_pokemon("Basic B"), 0)
	var energy := CardInstance.create(_energy("Water Energy", "W"), 0)
	var item_b := CardInstance.create(_trainer("Item B", "Item"), 0)
	var basic_c := CardInstance.create(_pokemon("Basic C"), 0)
	var stage_two := CardInstance.create(_pokemon("Stage Two", "", [], [], "W", 130, "Stage 2"), 0)
	var item_c := CardInstance.create(_trainer("Item C", "Item"), 0)
	var eleventh_pokemon := CardInstance.create(_pokemon("Eleventh Pokemon"), 0)
	player.deck = [basic_a, item, stage_one, supporter, basic_b, energy, item_b, basic_c, stage_two, item_c, eleventh_pokemon]
	var visible_top_ten := player.deck.slice(0, 10)
	gsm.effect_processor.register_pokemon_card(tatsugiri.get_card_data())
	var effect := AttackTopDeckPokemonToBenchScript.new(10)
	var steps := effect.get_attack_interaction_steps(tatsugiri.get_top_card(), tatsugiri.get_card_data().attacks[1], gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	var attack0_ignores := gsm.effect_processor.attack_ignores_defender_effects(tatsugiri, 0, gsm.game_state)
	var attack1_ignores := gsm.effect_processor.attack_ignores_defender_effects(tatsugiri, 1, gsm.game_state)
	var attacked := gsm.use_attack(0, 1, [{AttackTopDeckPokemonToBenchScript.STEP_ID: [stage_one, basic_b, eleventh_pokemon]}])

	return run_checks([
		assert_true(attack0_ignores, "Tatsugiri ex first attack should ignore defender effects"),
		assert_false(attack1_ignores, "Tatsugiri ex second attack should not ignore defender effects"),
		assert_eq(steps.size(), 1, "Vermilion Lure should prompt when top 10 include Pokemon and bench space exists"),
		assert_eq(step.get("card_items", []), visible_top_ten, "Vermilion Lure should show only the top 10 cards"),
		assert_false(eleventh_pokemon in step.get("card_items", []), "Vermilion Lure should not reveal the 11th deck card"),
		assert_eq(int(step.get("max_select", -1)), 2, "Vermilion Lure should cap selection by remaining bench space"),
		assert_eq(step.get("card_indices", []), [0, -1, 1, -1, 2, -1, -1, 3, 4, -1], "Vermilion Lure should make only Pokemon selectable among the visible cards"),
		assert_true(attacked, "Tatsugiri ex should use Vermilion Lure with the required Energy"),
		assert_eq(_bench_names(player), ["Existing 1", "Existing 2", "Existing 3", "Stage One", "Basic B"], "Vermilion Lure should bench selected visible Pokemon up to space"),
		assert_true(eleventh_pokemon in player.deck, "Vermilion Lure should ignore selected cards outside the visible top 10"),
		assert_eq(player.shuffle_count, 1, "Vermilion Lure should shuffle the deck once"),
	])


func test_incineroar_ex_reduces_colorless_cost_and_burns_with_blaze_bomb() -> String:
	var gsm := _make_gsm([false])
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var incineroar := _make_slot(_incineroar_ex(), 0)
	_attach_energy(incineroar, 0, "R", 1)
	player.active_pokemon = incineroar
	opponent.active_pokemon = _make_slot(_target("Opponent Active", 300), 1)
	opponent.bench = [
		_make_slot(_pokemon("Bench A"), 1),
		_make_slot(_pokemon("Bench B"), 1),
		_make_slot(_pokemon("Bench C"), 1),
		_make_slot(_pokemon("Bench D"), 1),
	]
	gsm.effect_processor.register_pokemon_card(incineroar.get_card_data())

	var reduction := gsm.effect_processor.get_attack_colorless_cost_modifier(incineroar, {"cost": "RCCC"}, gsm.game_state)
	var printed_attack_reduction := gsm.effect_processor.get_attack_colorless_cost_modifier(incineroar, incineroar.get_card_data().attacks[0], gsm.game_state)
	var base_damage := DamageCalculator.new().calculate_damage(
		incineroar,
		opponent.active_pokemon,
		incineroar.get_card_data().attacks[0],
		gsm.game_state,
		0,
		gsm.effect_processor.get_attacker_modifier(incineroar, gsm.game_state, opponent.active_pokemon),
		gsm.effect_processor.get_defender_modifier(opponent.active_pokemon, gsm.game_state, incineroar)
	)
	var attacked := gsm.use_attack(0, 0)

	var short_gsm := _make_gsm()
	var short_player: PlayerState = short_gsm.game_state.players[0]
	var short_opponent: PlayerState = short_gsm.game_state.players[1]
	var short_incineroar := _make_slot(_incineroar_ex(), 0)
	_attach_energy(short_incineroar, 0, "R", 1)
	short_player.active_pokemon = short_incineroar
	short_opponent.active_pokemon = _make_slot(_target("Short Opponent Active", 300), 1)
	short_opponent.bench = [_make_slot(_pokemon("Short Bench A"), 1), _make_slot(_pokemon("Short Bench B"), 1)]
	short_gsm.effect_processor.register_pokemon_card(short_incineroar.get_card_data())

	return run_checks([
		assert_eq(reduction, -3, "Hustle Play should not reduce more Colorless cost than the attack has"),
		assert_eq(printed_attack_reduction, -4, "Hustle Play should reduce Blaze Bomb by the opponent bench count"),
		assert_eq(base_damage, 240, "Blaze Bomb's attack damage calculation should be printed 240 before Burn checkup damage"),
		assert_true(attacked, "Incineroar ex should attack with one Fire Energy when opponent has four Benched Pokemon"),
		assert_false(short_gsm.can_use_attack(0, 0), "Incineroar ex should still need Colorless Energy when the opponent has only two Benched Pokemon"),
		assert_eq(opponent.active_pokemon.damage_counters, 260, "Blaze Bomb should deal 240, then Burn checkup should add 20 with the fixed tails flip"),
		assert_true(bool(opponent.active_pokemon.status_conditions.get("burned", false)), "Blaze Bomb should Burn the opponent Active"),
	])


func test_zubat_guiding_searches_supporter_only_and_second_attack_has_no_search() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var zubat := _make_slot(_zubat(), 0)
	_attach_energy(zubat, 0, "D", 1)
	player.active_pokemon = zubat
	opponent.active_pokemon = _make_slot(_target("Opponent Active", 100), 1)
	player.deck.clear()
	var item := CardInstance.create(_trainer("Item A", "Item"), 0)
	var supporter_a := CardInstance.create(_trainer("Supporter A", "Supporter"), 0)
	var pokemon := CardInstance.create(_pokemon("Deck Pokemon"), 0)
	var supporter_b := CardInstance.create(_trainer("Supporter B", "Supporter"), 0)
	player.deck.append_array([item, supporter_a, pokemon, supporter_b])
	var visible_deck := player.deck.duplicate()
	gsm.effect_processor.register_pokemon_card(zubat.get_card_data())
	var first_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(zubat, 0)
	var second_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(zubat, 1)
	var steps := first_attack_effects[0].get_attack_interaction_steps(zubat.get_top_card(), zubat.get_card_data().attacks[0], gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var attacked := gsm.use_attack(0, 0, [{"search_cards": [supporter_b, item]}])

	var second_gsm := _make_gsm()
	var second_zubat := _make_slot(_zubat(), 0)
	_attach_energy(second_zubat, 0, "D", 1)
	second_gsm.game_state.players[0].active_pokemon = second_zubat
	second_gsm.game_state.players[1].active_pokemon = _make_slot(_target("Second Defender", 100), 1)
	second_gsm.effect_processor.register_pokemon_card(second_zubat.get_card_data())
	var second_attacked := second_gsm.use_attack(0, 1)

	return run_checks([
		assert_eq(second_attack_effects.size(), 0, "Dark Fang should not have the Guiding Supporter search effect"),
		assert_eq(steps.size(), 1, "Guiding should prompt when Supporters exist in deck"),
		assert_eq(step.get("visible_scope", ""), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Guiding should expose the full own deck search UI"),
		assert_eq(step.get("card_items", []), visible_deck, "Guiding should show legal and disabled deck cards"),
		assert_eq(step.get("card_indices", []), [-1, 0, -1, 1], "Guiding should make only Supporters selectable"),
		assert_true(attacked, "Zubat should use Guiding with one Darkness Energy"),
		assert_true(supporter_b in player.hand, "Guiding should put the selected Supporter into hand"),
		assert_true(item in player.deck, "Guiding should ignore selected non-Supporter cards"),
		assert_true(pokemon in player.deck, "Guiding should leave non-Supporter cards in deck"),
		assert_eq(player.shuffle_count, 1, "Guiding should shuffle after searching"),
		assert_true(second_attacked, "Zubat should use Dark Fang"),
		assert_eq(second_gsm.game_state.players[1].active_pokemon.damage_counters, 10, "Dark Fang should deal printed 10 damage"),
	])


func _make_gsm(coin_sequence: Array[bool] = []) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	if not coin_sequence.is_empty():
		var flipper := SequenceCoinFlipper.new(coin_sequence)
		gsm.coin_flipper = flipper
		gsm.effect_processor = EffectProcessor.new(flipper)
		gsm.effect_processor.bind_game_state_machine(gsm)
	gsm.game_state = _make_state()
	return gsm


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = 0
	state.turn_number = 2
	state.first_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_target("Active %d" % pi, 300), pi)
		state.players.append(player)
	return state


func _snorunt() -> CardData:
	var card := _pokemon("Snorunt", EFFECT_SNORUNT, [_attack("Astonish", "WC", "20")], [], "W", 60)
	card.set_code = "CSV9.5C"
	card.card_index = "043"
	return card


func _froslass() -> CardData:
	var card := _pokemon("Froslass", EFFECT_FROSLASS, [_attack("Frost Smash", "WC", "60")], [_ability("Freezing Shroud")], "W", 90, "Stage 1")
	card.set_code = "CSV7C"
	card.card_index = "059"
	return card


func _tatsugiri_ex() -> CardData:
	var card := _pokemon(
		"Tatsugiri ex",
		EFFECT_TATSUGIRI_EX,
		[
			_attack("Sneaky Pump", "RW", "100"),
			_attack("Vermilion Lure", "RWD", ""),
		],
		[],
		"N",
		160,
		"Basic",
		"ex"
	)
	card.set_code = "CSV9C"
	card.card_index = "152"
	card.ancient_trait = "Tera"
	return card


func _incineroar_ex() -> CardData:
	var card := _pokemon("Incineroar ex", EFFECT_INCINEROAR_EX, [_attack("Blaze Bomb", "RCCCC", "240")], [_ability("Hustle Play")], "R", 320, "Stage 2", "ex")
	card.set_code = "CSV7C"
	card.card_index = "047"
	return card


func _zubat() -> CardData:
	var card := _pokemon(
		"Zubat",
		EFFECT_ZUBAT,
		[
			_attack("Guiding", "D", ""),
			_attack("Dark Fang", "D", "10"),
		],
		[],
		"D",
		50
	)
	card.set_code = "CSV8C"
	card.card_index = "122"
	return card


func _target(name: String, hp: int) -> CardData:
	return _pokemon(name, "", [_attack("Hit", "C", "10")], [], "C", hp)


func _attack(name: String, cost: String, damage: String, text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _ability(name: String) -> Dictionary:
	return {"name": name, "text": ""}


func _pokemon(
	name: String,
	effect_id: String = "",
	attacks: Array[Dictionary] = [],
	abilities: Array[Dictionary] = [],
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.attacks = attacks
	cd.abilities = abilities
	return cd


func _trainer(name: String, card_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
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


func _find_attack_action(gsm: GameStateMachine, attack_index: int) -> Dictionary:
	var actions: Array[Dictionary] = AILegalActionBuilderScript.new().build_actions(gsm, 0)
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "attack" and int(action.get("attack_index", -1)) == attack_index:
			return action
	return {}
