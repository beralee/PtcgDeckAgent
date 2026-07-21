class_name TestVideo18MissingCardsBatch3
extends TestBase

const IMPORTED_REFS := ["CSVSC_005", "CSV5C_010", "CSV9C_192", "CSV7C_190"]
const EFFECT_TOEDSCRUEL_EX := "668c8db0f156c52de12887587ec1b6d8"
const EFFECT_GRAVITY_GEMSTONE := "6d4d9b954e3a2cbad2ae1e0bfad2305a"
const EFFECT_LUCKY_HELMET := "76ed73e869ac742e97ea521f200a360e"


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _pokemon(name: String, owner: int = 0) -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.energy_type = "C"
	card_data.hp = 300
	card_data.retreat_cost = 1
	return _slot(card_data, owner)


func _energy(name: String, energy_type: String, owner: int = 0) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Basic Energy"
	card_data.energy_type = energy_type
	card_data.energy_provides = energy_type
	return CardInstance.create(card_data, owner)


func _item(name: String, owner: int = 0) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Item"
	return CardInstance.create(card_data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 15
	state.current_player_index = 0
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


func test_batch3_cards_are_bundled_with_valid_images_and_manifest_entries() -> String:
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


func test_scr_toedscool_is_correctly_numeric_only() -> String:
	var processor := EffectProcessor.new()
	var toedscool := _slot(_load_card("CSVSC_005"), 0)
	processor.register_pokemon_card(toedscool.get_card_data())
	return run_checks([
		assert_true(processor.get_attack_effects_for_slot(toedscool, 0).is_empty(), "CSVSC_005 Ram should remain numeric-only"),
		assert_true(processor.get_attack_effects_for_slot(toedscool, 1).is_empty(), "CSVSC_005 Gentle Slap should remain numeric-only"),
	])


func test_toedscruel_ex_protective_mycelium_shields_energized_own_pokemon_from_opponent_attack_effects() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var toedscruel := _slot(_load_card("CSV5C_010"), 0)
	var protected := _pokemon("Protected", 0)
	var unenergized := _pokemon("Unenergized", 0)
	var opponent_target := _pokemon("Opponent Target", 1)
	protected.attached_energy = [_energy("Grass", "G", 0)]
	opponent_target.attached_energy = [_energy("Opponent Grass", "G", 1)]
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench = [protected, unenergized]
	state.players[1].bench = [opponent_target]
	processor.register_pokemon_card(toedscruel.get_card_data())
	var ability := processor.get_effect(EFFECT_TOEDSCRUEL_EX)
	return run_checks([
		assert_eq(_script_name(ability), "AbilityProtectiveMycelium.gd", "CSV5C_010 should register Protective Mycelium"),
		assert_true(processor.is_attack_effect_prevented_by_defender_ability(state.players[1].active_pokemon, protected, state), "Protective Mycelium should shield an energized own Pokemon"),
		assert_false(processor.is_attack_effect_prevented_by_defender_ability(state.players[1].active_pokemon, unenergized, state), "Protective Mycelium should not shield an own Pokemon without Energy"),
		assert_false(processor.is_attack_effect_prevented_by_defender_ability(state.players[0].active_pokemon, opponent_target, state), "Protective Mycelium should not shield the opponent's Pokemon"),
	])


func test_toedscruel_ex_colony_rush_counts_each_grass_energized_own_bench_once() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var toedscruel := _slot(_load_card("CSV5C_010"), 0)
	var grass_a := _pokemon("Grass A", 0)
	var grass_b := _pokemon("Grass B", 0)
	var colorless := _pokemon("Colorless", 0)
	grass_a.attached_energy = [_energy("Grass A1", "G"), _energy("Grass A2", "G")]
	grass_b.attached_energy = [_energy("Grass B", "G")]
	colorless.attached_energy = [_energy("Colorless", "C")]
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench = [grass_a, grass_b, colorless]
	processor.register_pokemon_card(toedscruel.get_card_data())
	var effects := processor.get_attack_effects_for_slot(toedscruel, 0)
	if effects.is_empty():
		return "CSV5C_010 should register Colony Rush"
	var bonus := int(effects[0].call("get_damage_bonus", toedscruel, state)) if effects[0].has_method("get_damage_bonus") else -1
	return run_checks([
		assert_eq(_script_name(effects[0]), "AttackBenchGrassEnergyCountBonus.gd", "Colony Rush should use the Bench Grass-Energy count effect"),
		assert_eq(bonus, 80, "Colony Rush should add 40 for each of 2 eligible Benched Pokemon, not for each Energy"),
	])


func test_gravity_gemstone_increases_both_active_retreat_costs_only_while_holder_is_active() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var holder := state.players[0].active_pokemon
	holder.attached_tool = CardInstance.create(_load_card("CSV9C_192"), 0)
	var own_active_modifier := processor.get_retreat_cost_modifier(holder, state)
	var opponent_active_modifier := processor.get_retreat_cost_modifier(state.players[1].active_pokemon, state)
	var replacement := _pokemon("Replacement", 0)
	state.players[0].bench = [holder]
	state.players[0].active_pokemon = replacement
	var after_bench_modifier := processor.get_retreat_cost_modifier(state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(_script_name(processor.get_effect(EFFECT_GRAVITY_GEMSTONE)), "EffectGravityGemstone.gd", "CSV9C_192 should register Gravity Gemstone"),
		assert_eq(own_active_modifier, 1, "Gravity Gemstone should add 1 to its own Active holder's Retreat Cost"),
		assert_eq(opponent_active_modifier, 1, "Gravity Gemstone should add 1 to the opposing Active Pokemon's Retreat Cost"),
		assert_eq(after_bench_modifier, 0, "Gravity Gemstone should stop affecting Retreat Costs when its holder leaves the Active Spot"),
	])


func test_lucky_helmet_draws_two_after_active_holder_takes_opponent_attack_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var holder := state.players[0].active_pokemon
	holder.attached_tool = CardInstance.create(_load_card("CSV7C_190"), 0)
	var draw_a := _item("Draw A")
	var draw_b := _item("Draw B")
	var remains := _item("Remains")
	state.players[0].deck = [draw_a, draw_b, remains]
	processor.process_after_attack_damage(holder, state.players[1].active_pokemon, 30, state)
	return run_checks([
		assert_eq(_script_name(processor.get_effect(EFFECT_LUCKY_HELMET)), "EffectLuckyHelmet.gd", "CSV7C_190 should register Lucky Helmet"),
		assert_eq(state.players[0].hand, [draw_a, draw_b], "Lucky Helmet should draw exactly 2 cards after opponent attack damage"),
		assert_eq(state.players[0].deck, [remains], "Lucky Helmet should leave later deck cards untouched"),
	])


func test_lucky_helmet_does_not_trigger_from_bench_or_same_owner_damage() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var benched_holder := _pokemon("Benched Holder", 0)
	benched_holder.attached_tool = CardInstance.create(_load_card("CSV7C_190"), 0)
	state.players[0].bench = [benched_holder]
	state.players[0].deck = [_item("Draw")]
	processor.process_after_attack_damage(benched_holder, state.players[1].active_pokemon, 30, state)
	var bench_hand_count := state.players[0].hand.size()
	state.players[0].active_pokemon.attached_tool = CardInstance.create(_load_card("CSV7C_190"), 0)
	processor.process_after_attack_damage(state.players[0].active_pokemon, benched_holder, 30, state)
	return run_checks([
		assert_eq(bench_hand_count, 0, "Lucky Helmet should not trigger while its holder is Benched"),
		assert_true(state.players[0].hand.is_empty(), "Lucky Helmet should not trigger from same-owner attack damage"),
	])
