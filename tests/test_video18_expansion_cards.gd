class_name TestVideo18ExpansionCards
extends TestBase

const IMPORTED_REFS := ["CSV5C_022", "CS6bC_047", "CS1bC_128", "CSV2C_041"]
const EFFECT_CHI_YU := "4e1e775eaafb11028f5378ede92cb964"
const EFFECT_AIR_BALLOON := "55fc891681dd9731f7206cd75e908704"
const EFFECT_LUXRAY := "a4f457f1464c3410022b76ab77c11272"


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, owner: int = 0, retreat_cost: int = 1) -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.energy_type = "C"
	card_data.hp = 200
	card_data.retreat_cost = retreat_cost
	return _slot(card_data, owner)


func _basic_energy(name: String, energy_type: String, owner: int = 0) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Basic Energy"
	card_data.energy_type = energy_type
	card_data.energy_provides = energy_type
	return CardInstance.create(card_data, owner)


func _prize(owner: int, index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = "Prize %d" % index
	card_data.card_type = "Item"
	return CardInstance.create(card_data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 8
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, owner)
		state.players.append(player)
	return state


func _script_name(effect: BaseEffect) -> String:
	if effect == null or effect.get_script() == null:
		return ""
	return str(effect.get_script().resource_path).get_file()


func test_expansion_cards_are_bundled_with_valid_images_and_manifest_entries() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for ref: String in IMPORTED_REFS:
		var card := _load_card(ref)
		checks.append(assert_not_null(card, "%s should load from the bundled card pool" % ref))
		if card == null:
			continue
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [card.set_code, card.card_index]
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s should bundle a valid image" % ref))
		checks.append(assert_str_contains(manifest, "cards/%s.json" % ref, "%s JSON should be in the bundle manifest" % ref))
		checks.append(assert_str_contains(manifest, "cards/images/%s/%s.png.bin" % [card.set_code, card.card_index], "%s image should be in the bundle manifest" % ref))
	return run_checks(checks)


func test_chi_yu_attaches_up_to_two_basic_fire_energy_to_one_chosen_own_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var chi_yu := _slot(_load_card("CSV5C_022"), 0)
	var bench_target := _pokemon("Bench Target", 0)
	state.players[0].active_pokemon = chi_yu
	state.players[0].bench = [bench_target]
	var fire_a := _basic_energy("Fire A", "R")
	var fire_b := _basic_energy("Fire B", "R")
	var water := _basic_energy("Water", "W")
	state.players[0].discard_pile = [fire_a, water, fire_b]
	processor.register_pokemon_card(chi_yu.get_card_data())
	var effects := processor.get_attack_effects_for_slot(chi_yu, 0)
	var attach_effect: BaseEffect = null
	for effect: BaseEffect in effects:
		if _script_name(effect) == "AttackAttachBasicEnergyFromDiscard.gd":
			attach_effect = effect
			break
	if attach_effect == null:
		return "CSV5C_022 first attack should register discard Fire Energy attachment"
	var steps: Array[Dictionary] = attach_effect.get_attack_interaction_steps(chi_yu.get_top_card(), chi_yu.get_card_data().attacks[0], state)
	attach_effect.set_attack_interaction_context([{
		AttackAttachBasicEnergyFromDiscard.ENERGY_STEP_ID: [fire_a, fire_b],
		AttackAttachBasicEnergyFromDiscard.TARGET_STEP_ID: [bench_target],
	}])
	attach_effect.execute_attack(chi_yu, state.players[1].active_pokemon, 0, state)
	return run_checks([
		assert_eq(steps.size(), 2, "Flame Surge should expose Energy and target choices"),
		assert_contains(steps[1].get("items", []), chi_yu, "Flame Surge should allow the Active Chi-Yu as a target"),
		assert_contains(steps[1].get("items", []), bench_target, "Flame Surge should allow an own Benched Pokemon as a target"),
		assert_eq(bench_target.attached_energy, [fire_a, fire_b], "Flame Surge should attach the two selected Basic Fire Energy"),
		assert_contains(state.players[0].discard_pile, water, "Flame Surge should leave off-type Basic Energy in discard"),
	])


func test_chi_yu_revenge_attack_adds_ninety_only_after_last_turn_knockout() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var chi_yu := _slot(_load_card("CSV5C_022"), 0)
	state.players[0].active_pokemon = chi_yu
	processor.register_pokemon_card(chi_yu.get_card_data())
	var effects := processor.get_attack_effects_for_slot(chi_yu, 1)
	if effects.is_empty():
		return "CSV5C_022 second attack should register its revenge bonus"
	var revenge: BaseEffect = effects[0]
	state.last_knockout_turn_against[0] = state.turn_number - 1
	var active_bonus := int(revenge.call("get_damage_bonus", chi_yu, state))
	state.last_knockout_turn_against[0] = -999
	var inactive_bonus := int(revenge.call("get_damage_bonus", chi_yu, state))
	return run_checks([
		assert_eq(_script_name(revenge), "AttackRevengeBonus.gd", "Jealousy Burn should use the shared last-turn knockout bonus"),
		assert_eq(active_bonus, 90, "Jealousy Burn should add exactly 90 after an own Pokemon was Knocked Out last turn"),
		assert_eq(inactive_bonus, 0, "Jealousy Burn should add no damage without the last-turn knockout condition"),
	])


func test_air_balloon_reduces_only_its_holders_retreat_cost_by_two() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var holder := _pokemon("Holder", 0, 3)
	var other := _pokemon("Other", 0, 3)
	holder.attached_tool = CardInstance.create(_load_card("CS1bC_128"), 0)
	state.players[0].active_pokemon = holder
	state.players[0].bench = [other]
	return run_checks([
		assert_eq(_script_name(processor.get_effect(EFFECT_AIR_BALLOON)), "EffectToolRetreatModifier.gd", "Simplified-Chinese Air Balloon should register the shared retreat modifier"),
		assert_eq(processor.get_effective_retreat_cost(holder, state), 1, "Air Balloon should reduce its holder's Retreat Cost by 2"),
		assert_eq(processor.get_effective_retreat_cost(other, state), 3, "Air Balloon should not reduce another Pokemon's Retreat Cost"),
	])


func test_luxray_swelling_flash_is_a_legal_hand_to_bench_action_only_while_behind_on_prizes() -> String:
	var gsm := GameStateMachine.new()
	var state := _state()
	gsm.game_state = state
	var luxray := CardInstance.create(_load_card("CSV2C_041"), 0)
	gsm.effect_processor.register_pokemon_card(luxray.card_data)
	state.players[0].hand.append(luxray)
	for index: int in 6:
		state.players[0].prizes.append(_prize(0, index))
	for index: int in 4:
		state.players[1].prizes.append(_prize(1, index))
	var legal_while_behind := gsm.rule_validator.can_play_basic_to_bench(state, 0, luxray, gsm.effect_processor)
	var ai_actions := AILegalActionBuilder.new().build_actions(gsm, 0, true)
	var ai_has_action := ai_actions.any(func(action: Dictionary) -> bool:
		return str(action.get("kind", "")) == "play_basic_to_bench" and action.get("card", null) == luxray
	)
	var played := gsm.play_basic_to_bench(0, luxray)
	var placed_slot: PokemonSlot = state.players[0].bench.back() if not state.players[0].bench.is_empty() else null

	var blocked_state := _state()
	var blocked_luxray := CardInstance.create(_load_card("CSV2C_041"), 0)
	blocked_state.players[0].hand.append(blocked_luxray)
	for index: int in 3:
		blocked_state.players[0].prizes.append(_prize(0, index))
	for index: int in 4:
		blocked_state.players[1].prizes.append(_prize(1, index))
	var blocked_when_ahead := not gsm.rule_validator.can_play_basic_to_bench(blocked_state, 0, blocked_luxray, gsm.effect_processor)
	return run_checks([
		assert_eq(_script_name(gsm.effect_processor.get_effect(EFFECT_LUXRAY)), "AbilitySwellingFlash.gd", "Luxray should register Swelling Flash"),
		assert_true(legal_while_behind, "Swelling Flash should be legal from hand while its owner has more Prize cards remaining"),
		assert_true(ai_has_action, "Headless legal actions should expose Swelling Flash as a hand-to-Bench action"),
		assert_true(played, "Swelling Flash should place Luxray directly from hand onto the Bench"),
		assert_not_null(placed_slot, "Swelling Flash should create a Bench slot"),
		assert_eq(placed_slot.get_top_card() if placed_slot != null else null, luxray, "The exact Luxray hand card should enter the Bench"),
		assert_false(luxray in state.players[0].hand, "The played Luxray should leave the hand"),
		assert_true(blocked_when_ahead, "Swelling Flash should be blocked when its owner does not have more Prize cards remaining"),
	])
