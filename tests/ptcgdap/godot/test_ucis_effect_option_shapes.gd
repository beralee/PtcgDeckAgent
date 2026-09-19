class_name TestUcisEffectOptionShapes
extends TestBase

const CompilerScript = preload("res://scripts/engine/ucis/UcisInteractionCompiler.gd")
const TrekkingShoesScript = preload("res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd")
const MissFortuneSistersScript = preload("res://scripts/effects/trainer_effects/EffectMissFortuneSisters.gd")
const OptionalBonusSelfDamageScript = preload("res://scripts/effects/pokemon_effects/AttackOptionalBonusSelfDamage.gd")
const DiscardStadiumBonusDamageScript = preload("res://scripts/effects/pokemon_effects/AttackDiscardStadiumBonusDamage.gd")
const OptionalReturnSelfScript = preload("res://scripts/effects/pokemon_effects/AttackOptionalReturnSelfAllCardsToHand.gd")
const TcgEffectsScript = preload("res://scripts/effects/pokemon_effects/TcgMikTinkatonSinistchaEffects.gd")
const CSV9CAdvancedEffectsScript = preload("res://scripts/effects/pokemon_effects/CSV9CAdvancedEffects.gd")
const CSV10CEffectsScript = preload("res://scripts/effects/CSV10CEffects.gd")
const CSV10C101To200EffectsScript = preload("res://scripts/effects/CSV10C101To200Effects.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const CompetitivePolicyV2Script = preload("res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd")


func test_murkrow_defender_attack_lock_compiles_and_resolves_selected_typed_attack() -> String:
	var state := _state()
	var attacker := state.players[0].active_pokemon
	attacker.pokemon_stack = [CardInstance.create(CardDatabase.get_card("CSV10C", "135"), 0)]
	var defender := state.players[1].active_pokemon
	defender.get_card_data().set_code = "TEST"
	defender.get_card_data().card_index = "DEFENDER"
	defender.get_card_data().attacks = [{"name": "First", "damage": 10}, {"name": "Second", "damage": 20}]
	var effect := AttackChosenDefenderAttackLockNextTurn.new()
	var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	if not effect.get_ucis_last_error().is_empty() or steps.is_empty():
		return "Murkrow attack-lock window failed UCIS compilation: %s" % effect.get_ucis_last_error()
	var items := _items(steps)
	var metadata := CompilerScript.metadata_for_step(steps[0])
	var owner := OwnerScript.new()
	var options: Array = owner.call("_options_for_items", items, "effect_target", {
		"cabt_select_type_raw": metadata.get("select_type_raw"),
		"cabt_select_context_raw": metadata.get("context_raw"),
		"cabt_option_type_raw": metadata.get("option_type_raw"),
		"pending_effect_card": attacker.get_top_card(),
	})
	effect.set_attack_interaction_context([{effect.STEP_ID: [items[1]]}])
	effect.execute_attack(attacker, defender, 1, state)
	return run_checks([
		assert_eq(metadata.get("select_type_raw"), 6),
		assert_eq(options.size(), 2),
		assert_eq(options[1].get("attack_index"), 1),
		assert_true(CompetitivePolicyV2Script._valid_native_option_shape(options[1])),
		assert_eq(options[1].get("source_uid"), defender.get_top_card().card_data.get_uid()),
		assert_eq(defender.effects[0].get("attack_name") if not defender.effects.is_empty() else null, "Second"),
	])


func test_defender_attack_lock_rejects_invalid_typed_selection_and_keeps_legacy_context() -> String:
	var state := _state()
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	defender.get_card_data().attacks = [{"name": "First"}, {"name": "Second"}]
	var effect := AttackChosenDefenderAttackLockNextTurn.new()
	var checks: Array[String] = []
	for selection: Dictionary in [
		{"source_slot": attacker, "attack_index": 0},
		{"source_slot": defender, "attack_index": -1},
		{"source_slot": defender, "attack_index": 2},
		{"source_slot": defender, "attack_index": true},
	]:
		effect.set_attack_interaction_context([{effect.STEP_ID: [selection]}])
		effect.execute_attack(attacker, defender, 0, state)
		checks.append(assert_true(defender.effects.is_empty(), "Invalid typed selection must not silently lock the first attack"))
	effect.set_attack_interaction_context([{effect.STEP_ID: ["Second"]}])
	effect.execute_attack(attacker, defender, 0, state)
	checks.append(assert_eq(defender.effects[0].get("attack_name") if not defender.effects.is_empty() else null, "Second"))
	return run_checks(checks)


func test_trainer_mode_choices_compile_as_boolean_ucis_windows() -> String:
	var state := _state()
	state.players[0].deck.append(CardInstance.create(_card("Top Item", "Item"), 0))
	var trekking := TrekkingShoesScript.new()
	var trekking_steps: Array[Dictionary] = trekking.get_interaction_steps(
		CardInstance.create(_card("Trekking Shoes", "Item"), 0), state
	)
	state.players[1].deck.clear()
	state.players[1].deck.append(CardInstance.create(_card("Opponent Energy", "Basic Energy"), 1))
	var sisters := MissFortuneSistersScript.new()
	var sisters_steps: Array[Dictionary] = sisters.get_interaction_steps(
		CardInstance.create(_card("Miss Fortune Sisters", "Supporter"), 0), state
	)
	return run_checks([
		assert_eq(trekking.get_ucis_last_error(), "", "Trekking Shoes must compile through UCIS"),
		assert_eq(_items(trekking_steps), [false, true], "Trekking Shoes must publish take/discard as NO/YES"),
		assert_eq(_primitive(trekking_steps), "ChooseBoolean"),
		assert_eq(sisters.get_ucis_last_error(), "", "Miss Fortune Sisters whiff must compile through UCIS"),
		assert_eq(_items(sisters_steps), [true], "The whiff acknowledgement must be a typed YES option"),
		assert_eq(_primitive(sisters_steps), "ChooseBoolean"),
	])


func test_shared_optional_attack_modes_compile_as_boolean_ucis_windows() -> String:
	var state := _state()
	var attack := state.players[0].active_pokemon.get_top_card().card_data.attacks[0]
	var bonus := OptionalBonusSelfDamageScript.new(30, 30, 0)
	var bonus_steps: Array[Dictionary] = bonus.get_attack_interaction_steps(
		state.players[0].active_pokemon.get_top_card(), attack, state
	)
	state.stadium_card = CardInstance.create(_card("Test Stadium", "Stadium"), 1)
	state.stadium_owner_index = 1
	var stadium := DiscardStadiumBonusDamageScript.new(120, 0)
	var stadium_steps: Array[Dictionary] = stadium.get_attack_interaction_steps(
		state.players[0].active_pokemon.get_top_card(), attack, state
	)
	var returning := OptionalReturnSelfScript.new(0)
	var return_steps: Array[Dictionary] = returning.get_attack_interaction_steps(
		state.players[0].active_pokemon.get_top_card(), attack, state
	)
	return run_checks([
		assert_eq(bonus.get_ucis_last_error(), "", "Optional recoil mode must compile through UCIS"),
		assert_eq(_items(bonus_steps), [false, true]),
		assert_eq(_primitive(bonus_steps), "ChooseBoolean"),
		assert_eq(stadium.get_ucis_last_error(), "", "Optional Stadium discard must compile through UCIS"),
		assert_eq(_items(stadium_steps), [false, true]),
		assert_eq(_primitive(stadium_steps), "ChooseBoolean"),
		assert_eq(returning.get_ucis_last_error(), "", "Optional self-return must compile through UCIS"),
		assert_eq(_items(return_steps), [false, true]),
		assert_eq(_primitive(return_steps), "ChooseBoolean"),
	])


func test_catalog_specific_mode_choices_compile_as_boolean_ucis_windows() -> String:
	var state := _state()
	state.players[0].deck.append(CardInstance.create(_card("Top Card", "Item"), 0))
	var attacker := state.players[0].active_pokemon.get_top_card()
	var attack := attacker.card_data.attacks[0]
	var seeking := TcgEffectsScript.AttackSeekingMountain.new(0)
	var seeking_steps: Array[Dictionary] = seeking.get_attack_interaction_steps(attacker, attack, state)
	var surfing := CSV9CAdvancedEffectsScript.GholdengoSurfingTurn.new()
	surfing.attack_index_to_match = 0
	var surfing_steps: Array[Dictionary] = surfing.get_attack_interaction_steps(attacker, attack, state)
	var look_top := CSV10C101To200EffectsScript.AttackLookTopOptionalDiscard.new(0)
	var look_top_steps: Array[Dictionary] = look_top.get_attack_interaction_steps(attacker, attack, state)
	return run_checks([
		assert_eq(seeking.get_ucis_last_error(), "", "Seeking Mountain must compile through UCIS"),
		assert_eq(_items(seeking_steps), [false, true]),
		assert_eq(_primitive(seeking_steps), "ChooseBoolean"),
		assert_eq(surfing.get_ucis_last_error(), "", "Surfing Turn must compile through UCIS"),
		assert_eq(_items(surfing_steps), [false, true]),
		assert_eq(_primitive(surfing_steps), "ChooseBoolean"),
		assert_eq(look_top.get_ucis_last_error(), "", "Top-card discard mode must compile through UCIS"),
		assert_eq(_items(look_top_steps), [false, true]),
		assert_eq(_primitive(look_top_steps), "ChooseBoolean"),
	])


func test_boolean_ucis_candidates_project_to_valid_distinct_no_yes_options() -> String:
	var owner := OwnerScript.new()
	var options: Array = owner.call(
		"_options_for_items",
		[false, true],
		"effect_target",
		{
			"cabt_select_type_raw": 9,
			"cabt_select_context_raw": 43,
		}
	)
	return run_checks([
		assert_eq(options.size(), 2),
		assert_eq(options[0].get("option_type_raw") if options.size() > 0 else null, 2),
		assert_eq(options[1].get("option_type_raw") if options.size() > 1 else null, 1),
		assert_true(
			CompetitivePolicyV2Script._valid_native_option_shape(options[0]) if options.size() > 0 else false
		),
		assert_true(
			CompetitivePolicyV2Script._valid_native_option_shape(options[1]) if options.size() > 1 else false
		),
	])


func test_hidden_opponent_prize_position_step_compiles_without_card_identity() -> String:
	var state := _state()
	state.players[1].prizes.append(CardInstance.create(_card("Hidden Prize", "Item"), 1))
	var attacker := state.players[0].active_pokemon.get_top_card()
	var attack := attacker.card_data.attacks[0]
	var effect := CSV10CEffectsScript.AttackLookAtOpponentPrize.new(0)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker, attack, state)
	return run_checks([
		assert_eq(effect.get_ucis_last_error(), "", "Hidden opponent Prize positions must compile through UCIS"),
		assert_eq(_items(steps), [0]),
		assert_eq(steps[0].get("visible_scope", "") if not steps.is_empty() else "", "opponent_prizes_hidden"),
		assert_eq(_primitive(steps), "SearchAndMove"),
	])


func _items(steps: Array[Dictionary]) -> Array:
	return steps[0].get("items", []) if not steps.is_empty() else []


func _primitive(steps: Array[Dictionary]) -> String:
	if steps.is_empty():
		return ""
	return str(CompilerScript.metadata_for_step(steps[0]).get("primitive", ""))


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot("Active %d" % player_index, player_index)
		player.bench.append(_slot("Bench %d" % player_index, player_index))
		state.players.append(player)
	return state


func _slot(name: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_pokemon(name), owner))
	return slot


func _pokemon(name: String) -> CardData:
	var card := _card(name, "Pokemon")
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = "C"
	card.attacks = [{"name": "Test Attack", "damage": 10}]
	return card


func _card(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return card
