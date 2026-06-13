class_name TestCsv95c140EeveeExRainbowFactor
extends TestBase

const AbilityEeveeExRainbowFactorScript = preload("res://scripts/effects/pokemon_effects/AbilityEeveeExRainbowFactor.gd")
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")
const EFFECT_ID := "efa5883e7d648ebc984f161b2c7d8fe9"


func test_csv95c_140_registry_maps_rainbow_factor() -> String:
	var processor := EffectProcessor.new()
	var eevee_ex := _eevee_ex_data()
	processor.register_pokemon_card(eevee_ex)
	var effect := processor.get_effect(EFFECT_ID)

	return assert_true(
		effect != null and effect.get_script() == AbilityEeveeExRainbowFactorScript,
		"CSV9.5C_140 should register Rainbow Factor by effect_id"
	)


func test_csv95c_140_real_imported_eeveelution_ex_cards_are_ai_legal_evolutions() -> String:
	var db := CardDatabaseScript.new()
	var eevee_ex: CardData = db.get_card("CSV9.5C", "140")
	var leafeon_ex: CardData = db.get_card("CSV9.5C", "006")
	var flareon_ex: CardData = db.get_card("CSV9.5C", "023")
	var sylveon_ex: CardData = db.get_card("CSV9C", "090")
	var checks: Array[String] = [
		assert_not_null(eevee_ex, "CSV9.5C_140 Eevee ex should load from the bundled/user card cache"),
		assert_not_null(leafeon_ex, "CSV9.5C_006 Leafeon ex should load as an Eevee-line evolution"),
		assert_not_null(flareon_ex, "CSV9.5C_023 Flareon ex should load as an Eevee-line evolution"),
		assert_not_null(sylveon_ex, "CSV9C_090 Sylveon ex should load as an Eevee-line evolution"),
	]
	if eevee_ex == null or leafeon_ex == null or flareon_ex == null or sylveon_ex == null:
		return run_checks(checks)
	var fixture := _make_gsm_with_imported_eevee_ex(eevee_ex, 3, 0)
	var gsm: GameStateMachine = fixture["gsm"]
	var eevee_slot: PokemonSlot = fixture["slot"]
	var player: PlayerState = gsm.game_state.players[0]
	var leafeon := CardInstance.create(leafeon_ex, 0)
	var flareon := CardInstance.create(flareon_ex, 0)
	var sylveon := CardInstance.create(sylveon_ex, 0)
	player.hand = [leafeon, flareon, sylveon]

	var effect := gsm.effect_processor.get_effect(eevee_ex.effect_id)
	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var evolved := gsm.evolve_pokemon(0, leafeon, eevee_slot)

	checks.append_array([
		assert_true(effect != null and effect.get_script() == AbilityEeveeExRainbowFactorScript, "Imported CSV9.5C_140 should register Rainbow Factor directly by effect_id"),
		assert_true(_has_evolve_action(actions, leafeon, eevee_slot), "AI legal-action builder should expose Leafeon ex onto Eevee ex"),
		assert_true(_has_evolve_action(actions, flareon, eevee_slot), "AI legal-action builder should expose Flareon ex onto Eevee ex"),
		assert_true(_has_evolve_action(actions, sylveon, eevee_slot), "AI legal-action builder should expose Sylveon ex onto Eevee ex"),
		assert_true(evolved, "GameStateMachine should execute the imported Eevee-line ex evolution from hand"),
		assert_eq(eevee_slot.get_top_card(), leafeon, "The selected imported evolution card should become the top card"),
		assert_false(leafeon in player.hand, "The imported evolution card should leave hand after evolving"),
	])
	return run_checks(checks)


func test_csv95c_140_evolves_from_hand_after_normal_limits() -> String:
	var fixture := _make_gsm_with_eevee_ex(3, 0)
	var gsm: GameStateMachine = fixture["gsm"]
	var eevee_slot: PokemonSlot = fixture["slot"]
	var player: PlayerState = gsm.game_state.players[0]
	var jolteon := CardInstance.create(_pokemon_data("Jolteon ex", "Stage 1", "Eevee", "L", 270, "ex"), 0)
	player.hand.append(jolteon)

	var evolved := gsm.evolve_pokemon(0, jolteon, eevee_slot)

	return run_checks([
		assert_true(evolved, "Eevee ex should evolve into an Eevee-line Pokemon ex after normal limits are clear"),
		assert_false(jolteon in player.hand, "Evolution card should leave hand"),
		assert_eq(eevee_slot.pokemon_stack.size(), 2, "Evolution should be placed on the Eevee ex stack"),
		assert_eq(eevee_slot.get_pokemon_name(), "Jolteon ex", "The evolved Pokemon should become the top card"),
		assert_eq(eevee_slot.turn_evolved, gsm.game_state.turn_number, "Evolution turn should be recorded"),
	])


func test_csv95c_140_evolve_pokemon_requires_evolution_card_in_hand() -> String:
	var fixture := _make_gsm_with_eevee_ex(3, 0)
	var gsm: GameStateMachine = fixture["gsm"]
	var eevee_slot: PokemonSlot = fixture["slot"]
	var jolteon := CardInstance.create(_pokemon_data("Jolteon ex", "Stage 1", "Eevee", "L", 270, "ex"), 0)

	var evolved := gsm.evolve_pokemon(0, jolteon, eevee_slot)

	return run_checks([
		assert_false(evolved, "Rainbow Factor should not evolve with a card that is not actually in the player's hand"),
		assert_eq(eevee_slot.pokemon_stack.size(), 1, "A non-hand evolution card must not be placed onto the stack"),
		assert_eq(eevee_slot.get_pokemon_name(), "Eevee ex", "The target Eevee ex should remain unchanged when the evolution card is not in hand"),
	])


func test_csv95c_140_rainbow_factor_respects_ability_disabled() -> String:
	var fixture := _make_gsm_with_eevee_ex(3, 0)
	var gsm: GameStateMachine = fixture["gsm"]
	var eevee_slot: PokemonSlot = fixture["slot"]
	eevee_slot.effects.append({"type": "ability_disabled", "turn": gsm.game_state.turn_number})
	var jolteon := CardInstance.create(_pokemon_data("Jolteon ex", "Stage 1", "Eevee", "L", 270, "ex"), 0)
	gsm.game_state.players[0].hand.append(jolteon)

	return assert_false(
		gsm.rule_validator.can_evolve(gsm.game_state, 0, eevee_slot, jolteon, gsm.effect_processor),
		"Rainbow Factor should not grant the special evolution route while Eevee ex's Ability is disabled"
	)


func test_csv95c_140_allows_bench_eevee_ex_after_normal_limits() -> String:
	var fixture := _make_gsm_with_eevee_ex(3, 0, true)
	var gsm: GameStateMachine = fixture["gsm"]
	var eevee_slot: PokemonSlot = fixture["slot"]
	var player: PlayerState = gsm.game_state.players[0]
	var vaporeon := CardInstance.create(_pokemon_data("Vaporeon ex", "Stage 1", "Eevee", "W", 270, "ex"), 0)
	player.hand.append(vaporeon)

	var evolved := gsm.evolve_pokemon(0, vaporeon, eevee_slot)

	return run_checks([
		assert_true(evolved, "Rainbow Factor should work from the Bench as well as the Active Spot"),
		assert_eq(eevee_slot.get_pokemon_name(), "Vaporeon ex", "Benched Eevee ex should evolve to the selected Pokemon ex"),
	])


func test_csv95c_140_keeps_first_turn_and_same_turn_limits() -> String:
	var first_turn_fixture := _make_gsm_with_eevee_ex(1, 0)
	var first_turn_gsm: GameStateMachine = first_turn_fixture["gsm"]
	var first_turn_slot: PokemonSlot = first_turn_fixture["slot"]
	var first_turn_evolution := CardInstance.create(_pokemon_data("Jolteon ex", "Stage 1", "Eevee", "L", 270, "ex"), 0)

	var same_turn_fixture := _make_gsm_with_eevee_ex(3, 3)
	var same_turn_gsm: GameStateMachine = same_turn_fixture["gsm"]
	var same_turn_slot: PokemonSlot = same_turn_fixture["slot"]
	var same_turn_evolution := CardInstance.create(_pokemon_data("Vaporeon ex", "Stage 1", "Eevee", "W", 270, "ex"), 0)

	return run_checks([
		assert_false(
			first_turn_gsm.rule_validator.can_evolve(first_turn_gsm.game_state, 0, first_turn_slot, first_turn_evolution, first_turn_gsm.effect_processor),
			"Rainbow Factor should not bypass the player's first-turn evolution limit"
		),
		assert_false(
			same_turn_gsm.rule_validator.can_evolve(same_turn_gsm.game_state, 0, same_turn_slot, same_turn_evolution, same_turn_gsm.effect_processor),
			"Rainbow Factor should not bypass the just-played-this-turn evolution limit"
		),
	])


func test_csv95c_140_rejects_non_matching_evolution_cards() -> String:
	var fixture := _make_gsm_with_eevee_ex(3, 0)
	var gsm: GameStateMachine = fixture["gsm"]
	var eevee_slot: PokemonSlot = fixture["slot"]
	var validator := gsm.rule_validator
	var non_ex := CardInstance.create(_pokemon_data("Jolteon", "Stage 1", "Eevee", "L", 110, ""), 0)
	var wrong_line_ex := CardInstance.create(_pokemon_data("Charizard ex", "Stage 2", "Charmeleon", "R", 330, "ex"), 0)
	var basic_ex := CardInstance.create(_pokemon_data("Fake Basic ex", "Basic", "Eevee", "C", 120, "ex"), 0)

	var no_ability_fixture := _make_gsm_with_eevee_ex(3, 0, false, "")
	var no_ability_gsm: GameStateMachine = no_ability_fixture["gsm"]
	var no_ability_slot: PokemonSlot = no_ability_fixture["slot"]
	var valid_eevee_line_ex := CardInstance.create(_pokemon_data("Flareon ex", "Stage 1", "Eevee", "R", 270, "ex"), 0)

	var normal_eevee_slot := _slot(_pokemon_data("Eevee", "Basic", "", "C", 60, ""), 0, 0)
	gsm.game_state.players[0].bench.append(normal_eevee_slot)

	return run_checks([
		assert_false(
			validator.can_evolve(gsm.game_state, 0, eevee_slot, non_ex, gsm.effect_processor),
			"Rainbow Factor should reject non-ex Eevee-line evolutions"
		),
		assert_false(
			validator.can_evolve(gsm.game_state, 0, eevee_slot, wrong_line_ex, gsm.effect_processor),
			"Rainbow Factor should reject Pokemon ex that do not evolve from Eevee"
		),
		assert_false(
			validator.can_evolve(gsm.game_state, 0, eevee_slot, basic_ex, gsm.effect_processor),
			"Rainbow Factor should reject non-evolution Pokemon ex"
		),
		assert_false(
			no_ability_gsm.rule_validator.can_evolve(no_ability_gsm.game_state, 0, no_ability_slot, valid_eevee_line_ex, no_ability_gsm.effect_processor),
			"Eevee ex without the Rainbow Factor effect should not gain this special evolution route"
		),
		assert_true(
			validator.can_evolve(gsm.game_state, 0, normal_eevee_slot, valid_eevee_line_ex, gsm.effect_processor),
			"Normal Eevee evolution rules should remain unchanged when the top name matches evolves_from"
		),
	])


func _make_gsm_with_eevee_ex(
	turn_number: int,
	eevee_turn_played: int,
	put_eevee_on_bench: bool = false,
	effect_id: String = EFFECT_ID
) -> Dictionary:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state.players.clear()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = turn_number

	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot(_pokemon_data("Active %d" % player_index, "Basic", "", "C", 100, ""), player_index, 0)
		gsm.game_state.players.append(player)

	var eevee_ex := _slot(_eevee_ex_data(effect_id), 0, eevee_turn_played)
	if put_eevee_on_bench:
		gsm.game_state.players[0].bench.append(eevee_ex)
	else:
		gsm.game_state.players[0].active_pokemon = eevee_ex
	if effect_id != "":
		gsm.effect_processor.register_pokemon_card(eevee_ex.get_card_data())
	return {"gsm": gsm, "slot": eevee_ex}


func _make_gsm_with_imported_eevee_ex(
	eevee_ex_data: CardData,
	turn_number: int,
	eevee_turn_played: int
) -> Dictionary:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state.players.clear()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.first_player_index = 0
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = turn_number
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot(_pokemon_data("Active %d" % player_index, "Basic", "", "C", 100, ""), player_index, 0)
		gsm.game_state.players.append(player)
	var eevee_slot := _slot(eevee_ex_data, 0, eevee_turn_played)
	gsm.game_state.players[0].active_pokemon = eevee_slot
	gsm.effect_processor.register_pokemon_card(eevee_ex_data)
	return {"gsm": gsm, "slot": eevee_slot}


func _eevee_ex_data(effect_id: String = EFFECT_ID) -> CardData:
	var data := _pokemon_data("Eevee ex", "Basic", "", "C", 200, "ex")
	data.effect_id = effect_id
	data.abilities = [{"name": "Rainbow Factor", "text": ""}]
	data.ancient_trait = "Tera"
	return data


func _pokemon_data(
	name: String,
	stage: String,
	evolves_from: String,
	energy_type: String,
	hp: int,
	mechanic: String
) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.evolves_from = evolves_from
	data.energy_type = energy_type
	data.hp = hp
	data.mechanic = mechanic
	return data


func _slot(card_data: CardData, owner_index: int, turn_played: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = turn_played
	return slot


func _has_evolve_action(actions: Array, card: CardInstance, target_slot: PokemonSlot) -> bool:
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("kind", "")) == "evolve" and action.get("card") == card and action.get("target_slot") == target_slot:
			return true
	return false
