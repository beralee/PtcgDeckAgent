class_name TestCSV95C128129VaroomRevavroom
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AttackReduceDamageNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd")
const AttackCoinFlipBonusDamageScript := preload("res://scripts/effects/pokemon_effects/AttackCoinFlipBonusDamage.gd")

const VAROOM_EFFECT_ID := "10fae18e35ba5ba1481dda8253f4b4d8"
const REVAVROOM_EFFECT_ID := "a3fb29e6398509034c1f225f49ecb000"


class FixedCoinFlipper extends CoinFlipper:
	var results: Array[bool] = []
	var index: int = 0

	func _init(next_results: Array[bool]) -> void:
		results = next_results.duplicate()

	func flip() -> bool:
		var result := true
		if index < results.size():
			result = bool(results[index])
		index += 1
		coin_flipped.emit(result)
		return result


func test_csv95c_128_129_are_bundled_with_images() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var expected := {
		"CSV9.5C_128": {"effect_id": VAROOM_EFFECT_ID, "card_type": "Pokemon", "name_en": "Varoom"},
		"CSV9.5C_129": {"effect_id": REVAVROOM_EFFECT_ID, "card_type": "Pokemon", "name_en": "Revavroom"},
	}
	var pool_ids := {}
	for pool_card: CardData in db.get_all_cards():
		if pool_card != null:
			pool_ids[pool_card.get_uid()] = true
	var checks: Array[String] = []
	for card_id: String in expected.keys():
		var parts := card_id.split("_", false, 1)
		var set_code := str(parts[0])
		var card_index := str(parts[1])
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		var spec: Dictionary = expected[card_id]
		checks.append(assert_true(card_path in manifest, "%s should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in bundled seed manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled card image should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % card_id))
		checks.append(assert_not_null(card, "%s should load through CardDatabase" % card_id))
		checks.append(assert_true(pool_ids.has(card_id), "%s should appear in CardDatabase.get_all_cards" % card_id))
		if card != null:
			checks.append(assert_eq(str(card.effect_id), str(spec["effect_id"]), "%s should keep source effect id" % card_id))
			checks.append(assert_eq(str(card.card_type), str(spec["card_type"]), "%s should keep source card type" % card_id))
			checks.append(assert_eq(str(card.name_en), str(spec["name_en"]), "%s should keep source English name" % card_id))
	db.free()
	return run_checks(checks)


func test_csv95c_128_varoom_harden_registers_and_reduces_next_turn_damage() -> String:
	var card := _varoom()
	var gsm := _make_gsm()
	var attacker := _make_slot(card, 0)
	var defender := _make_slot(_pokemon("Defender", "C", 200), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(card)

	var first_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var second_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	if not first_attack_effects.is_empty():
		first_attack_effects[0].execute_attack(attacker, defender, 0, gsm.game_state)
	gsm.game_state.turn_number += 1
	var modifier := gsm.effect_processor.get_defender_modifier(attacker, gsm.game_state, defender)
	var first_attack_is_reduction := false
	if not first_attack_effects.is_empty():
		first_attack_is_reduction = is_instance_of(first_attack_effects[0], AttackReduceDamageNextTurnScript)

	return run_checks([
		assert_true(gsm.effect_processor.has_attack_effect(VAROOM_EFFECT_ID), "CSV9.5C_128 should register Harden by API effect_id"),
		assert_eq(first_attack_effects.size(), 1, "Harden should have one next-turn damage reduction effect"),
		assert_true(first_attack_is_reduction, "Harden should use AttackReduceDamageNextTurn"),
		assert_eq(second_attack_effects.size(), 0, "Reckless Headbutt should not receive Harden's effect"),
		assert_eq(modifier, -30, "Harden should reduce damage taken by 30 during the next opponent turn"),
	])


func test_csv95c_129_revavroom_registers_ability_and_coin_attack() -> String:
	var flipper := FixedCoinFlipper.new([true])
	var gsm := _make_gsm(flipper)
	var card := _revavroom()
	var attacker := _make_slot(card, 0)
	var defender := _make_slot(_pokemon("Defender", "C", 300), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(card)
	var ability_effect := gsm.effect_processor.get_ability_effect(attacker, 0, gsm.game_state)
	var attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	if not attack_effects.is_empty():
		attack_effects[0].execute_attack(attacker, defender, 0, gsm.game_state)
	var attack_is_coin_bonus := false
	if not attack_effects.is_empty():
		attack_is_coin_bonus = is_instance_of(attack_effects[0], AttackCoinFlipBonusDamageScript)

	return run_checks([
		assert_true(gsm.effect_processor.has_effect(REVAVROOM_EFFECT_ID), "CSV9.5C_129 should register Rumbling Engine by API effect_id"),
		assert_true(gsm.effect_processor.has_attack_effect(REVAVROOM_EFFECT_ID), "CSV9.5C_129 should register Knock Away by API effect_id"),
		assert_not_null(ability_effect, "Rumbling Engine should expose an ability effect"),
		assert_eq(attack_effects.size(), 1, "Knock Away should have one coin-flip bonus effect"),
		assert_true(attack_is_coin_bonus, "Knock Away should use AttackCoinFlipBonusDamage"),
		assert_eq(defender.damage_counters, 90, "Knock Away should add 90 damage on heads"),
	])


func test_csv95c_129_rumbling_engine_discards_energy_and_draws_to_six_once_per_turn() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var card := _revavroom()
	var revavroom := _make_slot(card, 0)
	gsm.game_state.players[0].active_pokemon = revavroom
	var energy := CardInstance.create(_energy("Metal Energy", "M"), 0)
	var keep_card := CardInstance.create(_pokemon("Keep Card", "C", 60), 0)
	player.hand.append_array([energy, keep_card])
	for i: int in 5:
		player.deck.append(CardInstance.create(_pokemon("Draw %d" % i, "C", 60), 0))
	gsm.effect_processor.register_pokemon_card(card)
	var ability_effect := gsm.effect_processor.get_ability_effect(revavroom, 0, gsm.game_state)

	var steps: Array = ability_effect.get_interaction_steps(revavroom.get_top_card(), gsm.game_state) if ability_effect != null else []
	var can_before: bool = bool(ability_effect.can_use_ability(revavroom, gsm.game_state)) if ability_effect != null else false
	if ability_effect != null:
		ability_effect.execute_ability(revavroom, 0, [{"discard_energy": [energy]}], gsm.game_state)
	var can_after: bool = bool(ability_effect.can_use_ability(revavroom, gsm.game_state)) if ability_effect != null else false

	return run_checks([
		assert_true(can_before, "Rumbling Engine should be usable with an Energy card in hand and fewer than six cards"),
		assert_eq(steps.size(), 1, "Rumbling Engine should ask which hand Energy to discard"),
		assert_true(energy in player.discard_pile, "Rumbling Engine should discard the selected Energy from hand"),
		assert_true(keep_card in player.hand, "Rumbling Engine should keep non-selected hand cards"),
		assert_eq(player.hand.size(), 6, "Rumbling Engine should draw until the player has six cards after discarding the cost"),
		assert_false(can_after, "Rumbling Engine should be once per turn"),
	])


func test_csv95c_129_rumbling_engine_requires_energy_and_can_pay_cost_at_six_cards() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var card := _revavroom()
	var revavroom := _make_slot(card, 0)
	gsm.game_state.players[0].active_pokemon = revavroom
	gsm.effect_processor.register_pokemon_card(card)
	var ability_effect := gsm.effect_processor.get_ability_effect(revavroom, 0, gsm.game_state)
	player.hand.append(CardInstance.create(_pokemon("No Energy", "C", 60), 0))
	var no_energy: bool = bool(ability_effect.can_use_ability(revavroom, gsm.game_state)) if ability_effect != null else false
	player.hand.clear()
	var energy := CardInstance.create(_energy("Metal Energy", "M"), 0)
	player.hand.append(energy)
	for i: int in 5:
		player.hand.append(CardInstance.create(_pokemon("Held %d" % i, "C", 60), 0))
	var drawn := CardInstance.create(_pokemon("Drawn", "C", 60), 0)
	player.deck.append(drawn)
	var six_cards: bool = bool(ability_effect.can_use_ability(revavroom, gsm.game_state)) if ability_effect != null else false
	if ability_effect != null:
		ability_effect.execute_ability(revavroom, 0, [{"discard_energy": [energy]}], gsm.game_state)

	return run_checks([
		assert_false(no_energy, "Rumbling Engine should require an Energy card in hand"),
		assert_true(six_cards, "Rumbling Engine should be usable with six cards because discarding the Energy creates room to draw"),
		assert_true(energy in player.discard_pile, "Rumbling Engine should still discard the selected Energy at six cards"),
		assert_true(drawn in player.hand, "Rumbling Engine should draw back up to six after paying the Energy cost"),
		assert_eq(player.hand.size(), 6, "Rumbling Engine should end at six cards after starting with six and discarding an Energy"),
	])


func _make_gsm(flipper: CoinFlipper = null) -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	if flipper != null:
		gsm.coin_flipper = flipper
		gsm.effect_processor = EffectProcessor.new(flipper)
	gsm.game_state.players.clear()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func _varoom() -> CardData:
	var card := _pokemon("噗隆隆", "M", 70)
	card.name_en = "Varoom"
	card.set_code = "CSV9.5C"
	card.card_index = "128"
	card.effect_id = VAROOM_EFFECT_ID
	card.weakness_energy = "R"
	card.weakness_value = "x2"
	card.resistance_energy = "G"
	card.resistance_value = "-30"
	card.retreat_cost = 1
	card.attacks = [
		{"name": "硬直", "cost": "M", "damage": "", "text": "During your opponent's next turn, this Pokemon takes 30 less damage from attacks.", "is_vstar_power": false},
		{"name": "鲁莽头击", "cost": "MM", "damage": "20", "text": "", "is_vstar_power": false},
	]
	return card


func _revavroom() -> CardData:
	var card := _pokemon("普隆隆姆", "M", 140)
	card.name_en = "Revavroom"
	card.stage = "Stage 1"
	card.evolves_from = "噗隆隆"
	card.set_code = "CSV9.5C"
	card.card_index = "129"
	card.effect_id = REVAVROOM_EFFECT_ID
	card.weakness_energy = "R"
	card.weakness_value = "x2"
	card.resistance_energy = "G"
	card.resistance_value = "-30"
	card.retreat_cost = 2
	card.abilities = [
		{"name": "轰鸣引擎", "text": "Once during your turn, you may discard an Energy card from your hand. Draw cards until you have 6 cards in your hand.", "is_vstar_power": false},
	]
	card.attacks = [
		{"name": "弹飞", "cost": "MCCC", "damage": "90+", "text": "Flip a coin. If heads, this attack does 90 more damage.", "is_vstar_power": false},
	]
	return card


func _pokemon(name: String, energy_type: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = energy_type
	card.hp = hp
	return card


func _energy(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _make_slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot
