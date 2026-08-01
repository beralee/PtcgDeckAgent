class_name TestCSV5C073AndCSV9C110
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")
const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")
const AreaZero = preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")

const GLIMMORA_EFFECT_ID := "ea9a967a89789870e4495d6b26f9c8a2"
const GLIMMET_EFFECT_ID := "af4015d8313faa7fe639023c5add6a38"
const COLLAPSED_STADIUM_EFFECT_ID := "fb3628071280487676f79281696ffbd9"


func _load_card(uid: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % uid
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(
	name: String,
	owner_index: int,
	effect_id: String = "",
	energy_type: String = "C",
	abilities: Array[Dictionary] = [],
	attacks: Array[Dictionary] = []
) -> PokemonSlot:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = energy_type
	card.effect_id = effect_id
	var ability_list: Array[Dictionary] = []
	ability_list.assign(abilities)
	card.abilities = ability_list
	var attack_list: Array[Dictionary] = []
	if attacks.is_empty():
		attack_list.append({
			"name": "Fixture Attack",
			"cost": "C",
			"damage": "10",
			"text": "",
			"is_vstar_power": false,
		})
	else:
		attack_list.assign(attacks)
	card.attacks = attack_list
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _pokemon("Active %d" % player_index, player_index)
		state.players.append(player)
	return state


func _dust_field_slot(owner_index: int) -> PokemonSlot:
	return _pokemon(
		"晶光花ex",
		owner_index,
		GLIMMORA_EFFECT_ID,
		"F",
		[{
			"name": "尘埃场地",
			"text": "只要这只宝可梦在战斗场上，对手可放于备战区的宝可梦数量就会变为3只。",
		}],
		[{
			"name": "毒液宝石",
			"cost": "FF",
			"damage": "140",
			"text": "令对手的战斗宝可梦陷入【中毒】状态。",
			"is_vstar_power": false,
		}]
	)


func _glimmet_slot(owner_index: int) -> PokemonSlot:
	return _pokemon(
		"晶光芽",
		owner_index,
		GLIMMET_EFFECT_ID,
		"F",
		[],
		[{
			"name": "岩石投射",
			"cost": "F",
			"damage": "10",
			"text": "这个招式的伤害不计算抗性。",
			"is_vstar_power": false,
		}]
	)


func test_csv5c_073_and_csv9c_110_are_complete_bundled_cards() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var pooled_uids: Dictionary = {}
	for pooled: CardData in db.get_all_cards():
		if pooled != null:
			pooled_uids[pooled.get_uid()] = true
	var specs := {
		"CSV5C_073": {
			"set_code": "CSV5C",
			"card_index": "073",
			"name": "晶光花ex",
			"name_en": "Glimmora ex",
			"effect_id": GLIMMORA_EFFECT_ID,
			"stage": "Stage 1",
			"hp": 270,
		},
		"CSV9C_110": {
			"set_code": "CSV9C",
			"card_index": "110",
			"name": "晶光芽",
			"name_en": "Glimmet",
			"effect_id": GLIMMET_EFFECT_ID,
			"stage": "Basic",
			"hp": 70,
		},
	}
	var checks: Array[String] = []
	for uid: String in specs:
		var spec: Dictionary = specs[uid]
		var set_code := str(spec["set_code"])
		var card_index := str(spec["card_index"])
		var json_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(json_path in manifest, "%s JSON should be in the bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s image should be in the bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(json_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should decode" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase.get_card" % uid))
		checks.append(assert_true(db.has_card(set_code, card_index), "%s should load through CardDatabase.has_card" % uid))
		checks.append(assert_true(pooled_uids.has(uid), "%s should appear in the DeckEditor card pool" % uid))
		if card != null:
			checks.append(assert_eq(card.name, str(spec["name"]), "%s should keep its Chinese name" % uid))
			checks.append(assert_eq(card.name_en, str(spec["name_en"]), "%s should keep its English name" % uid))
			checks.append(assert_eq(card.effect_id, str(spec["effect_id"]), "%s should keep its effect id" % uid))
			checks.append(assert_eq(card.stage, str(spec["stage"]), "%s should keep its stage" % uid))
			checks.append(assert_eq(card.hp, int(spec["hp"]), "%s should keep its HP" % uid))
	db.free()
	return run_checks(checks)


func test_csv5c_073_dust_field_limits_only_the_opponents_bench_while_active() -> String:
	var state := _state()
	var glimmora := _dust_field_slot(0)
	state.players[0].active_pokemon = glimmora
	state.players[0].bench = [
		_pokemon("Own Bench 1", 0),
		_pokemon("Own Bench 2", 0),
		_pokemon("Own Bench 3", 0),
	]
	state.players[1].bench = [
		_pokemon("Opponent Bench 1", 1),
		_pokemon("Opponent Bench 2", 1),
		_pokemon("Opponent Bench 3", 1),
	]
	var opponent_limit_while_active := BenchLimit.get_bench_limit_for_player(state, state.players[1])
	var owner_limit_while_active := BenchLimit.get_bench_limit_for_player(state, state.players[0])
	state.players[0].active_pokemon = _pokemon("Replacement Active", 0)
	state.players[0].bench.append(glimmora)
	var opponent_limit_while_benched := BenchLimit.get_bench_limit_for_player(state, state.players[1])
	return run_checks([
		assert_eq(opponent_limit_while_active, 3, "Dust Field should limit only the opponent to three Benched Pokemon"),
		assert_eq(owner_limit_while_active, 5, "Dust Field should not limit its owner"),
		assert_eq(opponent_limit_while_benched, 5, "Dust Field should stop applying when Glimmora ex leaves the Active Spot"),
	])


func test_csv5c_073_dust_field_blocks_the_fourth_bench_slot_and_respects_ability_suppression() -> String:
	var state := _state()
	state.current_player_index = 1
	var glimmora := _dust_field_slot(0)
	state.players[0].active_pokemon = glimmora
	state.players[1].bench = [
		_pokemon("Opponent Bench 1", 1),
		_pokemon("Opponent Bench 2", 1),
		_pokemon("Opponent Bench 3", 1),
	]
	var new_basic := _pokemon("New Basic", 1).get_top_card()
	state.players[1].hand.append(new_basic)
	var processor := EffectProcessor.new()
	var validator := RuleValidator.new()
	var blocked_reason := validator.get_play_basic_to_bench_unusable_reason(state, 1, new_basic, processor)
	glimmora.effects.append({
		"type": "ability_disabled",
		"turn": state.turn_number,
	})
	var restored_limit := BenchLimit.get_bench_limit_for_player(state, state.players[1], processor)
	var allowed_reason := validator.get_play_basic_to_bench_unusable_reason(state, 1, new_basic, processor)
	processor.prepare_for_disposal()
	return run_checks([
		assert_false(blocked_reason.is_empty(), "Dust Field should make a fourth Bench placement illegal"),
		assert_eq(restored_limit, 5, "Disabling Glimmora ex's ability should restore the normal Bench limit"),
		assert_eq(allowed_reason, "", "The fourth Bench placement should become legal while Dust Field is disabled"),
	])


func test_csv5c_073_uses_the_lower_bench_limit_and_discards_the_opponents_choice() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	gsm.game_state.players[0].active_pokemon = _dust_field_slot(0)
	var collapsed := CardData.new()
	collapsed.name = "Collapsed Stadium"
	collapsed.card_type = "Stadium"
	collapsed.effect_id = COLLAPSED_STADIUM_EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(collapsed, 0)
	gsm.game_state.stadium_owner_index = 0
	var opponent := gsm.game_state.players[1]
	var bench_slots: Array[PokemonSlot] = []
	for index: int in 5:
		var slot := _pokemon("Opponent Bench %d" % index, 1)
		bench_slots.append(slot)
		opponent.bench.append(slot)
	var chosen := [bench_slots[0], bench_slots[2]]
	var context := {
		"%s%d" % [AreaZero.STEP_ID_PREFIX, 1]: chosen,
	}
	var cleaned := gsm.enforce_current_bench_limits("dust_field_test", 0, "", -1, [context])
	var discarded_names: Array[String] = []
	for card: CardInstance in opponent.discard_pile:
		discarded_names.append(card.card_data.name)
	var checks: Array[String] = [
		assert_eq(BenchLimit.get_bench_limit_for_player(gsm.game_state, opponent), 3, "The lower Dust Field limit should win over Collapsed Stadium's limit of four"),
		assert_true(cleaned, "Dust Field should enforce an over-limit opponent Bench"),
		assert_eq(opponent.bench.size(), 3, "The opponent should keep exactly three Benched Pokemon"),
		assert_true("Opponent Bench 0" in discarded_names, "The first chosen Pokemon should be discarded"),
		assert_true("Opponent Bench 2" in discarded_names, "The second chosen Pokemon should be discarded"),
		assert_false(bench_slots[4].get_top_card() in opponent.discard_pile, "Cleanup should not replace a valid player choice with a fallback"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv5c_073_venomous_gem_deals_printed_damage_and_poisons() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var attacker := _dust_field_slot(0)
	var defender := _pokemon("Defender", 1)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender
	processor.register_pokemon_card(attacker.get_card_data())
	var registered := processor.has_effect(GLIMMORA_EFFECT_ID)
	var has_attack_effect := processor.has_attack_effect(GLIMMORA_EFFECT_ID)
	var executed := processor.execute_attack_effect(attacker, 0, defender, state)
	var damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		attacker.get_card_data().attacks[0],
		state
	)
	processor.prepare_for_disposal()
	return run_checks([
		assert_true(registered, "CSV5C_073 should register Dust Field as a passive ability"),
		assert_true(has_attack_effect, "CSV5C_073 should register Venomous Gem's Poison effect"),
		assert_true(executed, "Venomous Gem's scripted effect should execute"),
		assert_eq(damage, 140, "Venomous Gem should deal its printed 140 damage"),
		assert_true(bool(defender.status_conditions.get("poisoned", false)), "Venomous Gem should Poison the opponent's Active Pokemon"),
	])


func test_csv9c_110_rock_throw_ignores_resistance_but_not_weakness() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var attacker := _glimmet_slot(0)
	var defender := _pokemon("Fighting-resistant Defender", 1)
	defender.get_card_data().resistance_energy = "F"
	defender.get_card_data().resistance_value = "-30"
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender
	processor.register_pokemon_card(attacker.get_card_data())
	var ignores_resistance := processor.attack_ignores_resistance(attacker, 0, state)
	var ignores_weakness := processor.attack_ignores_weakness(attacker, 0, state)
	var damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		attacker.get_card_data().attacks[0],
		state,
		0,
		0,
		0,
		ignores_weakness,
		ignores_resistance
	)
	processor.prepare_for_disposal()
	return run_checks([
		assert_true(ignores_resistance, "CSV9C_110 Rock Throw should ignore Resistance"),
		assert_false(ignores_weakness, "CSV9C_110 Rock Throw should still apply Weakness"),
		assert_eq(damage, 10, "CSV9C_110 Rock Throw should deal 10 through Fighting Resistance"),
	])
