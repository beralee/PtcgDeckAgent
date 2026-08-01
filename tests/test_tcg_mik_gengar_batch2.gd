class_name TestTcgMikGengarBatch2
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")
const CSV9CHelpers = preload("res://scripts/effects/CSV9CHelpers.gd")

const REQUESTED_CARDS := {
	"CSV8C_130": {
		"set_code": "CSV8C",
		"card_index": "130",
		"name_en": "Scolipede",
		"effect_id": "6e1f0a70900ecdcee11e3a3b1c10e302",
	},
	"CSV9C_082": {
		"set_code": "CSV9C",
		"card_index": "082",
		"name_en": "Uxie",
		"effect_id": "9ed8dedf70df1133f656418c3a41cb0d",
	},
	"151C_092": {
		"set_code": "151C",
		"card_index": "092",
		"name_en": "Gastly",
		"effect_id": "afe72cfaed6efc3c59572098c9db11f9",
	},
	"151C_093": {
		"set_code": "151C",
		"card_index": "093",
		"name_en": "Haunter",
		"effect_id": "645a088d30f06cad09e9f187d68e8235",
	},
	"151C_094": {
		"set_code": "151C",
		"card_index": "094",
		"name_en": "Gengar",
		"effect_id": "ca20baa5307608ad3500c000630bc417",
	},
}


func _load_card(uid: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % uid
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _plain_pokemon(name: String, hp: int, owner_index: int) -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = hp
	card_data.energy_type = "C"
	card_data.attacks = [{
		"name": "Tackle",
		"cost": "C",
		"damage": "10",
		"text": "",
		"is_vstar_power": false,
	}]
	return _slot(card_data, owner_index)


func _trainer(name: String, card_type: String, owner_index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = card_type
	return CardInstance.create(card_data, owner_index)


func _fixture_state(attacker: PokemonSlot, defender: PokemonSlot) -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender
	return state


func test_requested_batch2_cards_are_bundled_and_visible() -> String:
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var pooled_uids: Dictionary = {}
	for card_data: CardData in db.get_all_cards():
		if card_data != null:
			pooled_uids[card_data.get_uid()] = true
	var checks: Array[String] = []
	for uid: String in REQUESTED_CARDS:
		var spec: Dictionary = REQUESTED_CARDS[uid]
		var set_code := str(spec["set_code"])
		var card_index := str(spec["card_index"])
		var json_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card_data := db.get_card(set_code, card_index)
		checks.append(assert_true(json_path in manifest, "%s JSON should be listed in the bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in the bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(json_path), "%s JSON should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s image should be valid" % uid))
		checks.append(assert_not_null(card_data, "%s should load through CardDatabase" % uid))
		checks.append(assert_true(pooled_uids.has(uid), "%s should be visible in the full card pool" % uid))
		if card_data != null:
			checks.append(assert_eq(card_data.name_en, str(spec["name_en"]), "%s should preserve name_en" % uid))
			checks.append(assert_eq(card_data.effect_id, str(spec["effect_id"]), "%s should preserve effect_id" % uid))
	db.free()
	return run_checks(checks)


func test_csv8c_130_brutal_bash_places_counters_until_10_hp_remains() -> String:
	var scolipede := _load_card("CSV8C_130")
	if scolipede == null:
		return "CSV8C_130 must be bundled before testing Brutal Bash"
	var attacker := _slot(scolipede, 0)
	var defender := _plain_pokemon("Defender", 170, 1)
	defender.damage_counters = 30
	var state := _fixture_state(attacker, defender)
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(scolipede)
	var executed := processor.execute_attack_effect(attacker, 0, defender, state)
	var remaining_hp := defender.get_remaining_hp()
	var second_attack_effects := processor.get_attack_effects_for_slot(attacker, 1)
	processor.prepare_for_disposal()
	return run_checks([
		assert_true(executed, "Brutal Bash should execute"),
		assert_eq(defender.damage_counters, 160, "Brutal Bash should place only enough counters to leave 10 HP"),
		assert_eq(remaining_hp, 10, "Brutal Bash should leave exactly 10 HP"),
		assert_true(second_attack_effects.is_empty(), "Scolipede's printed 160-damage second attack should remain numeric-only"),
	])


func test_csv9c_082_painful_memories_places_two_counters_on_every_opposing_pokemon() -> String:
	var uxie := _load_card("CSV9C_082")
	if uxie == null:
		return "CSV9C_082 must be bundled before testing Painful Memories"
	var attacker := _slot(uxie, 0)
	var defender := _plain_pokemon("Defender", 100, 1)
	var bench_a := _plain_pokemon("Bench A", 100, 1)
	var bench_b := _plain_pokemon("Bench B", 100, 1)
	var state := _fixture_state(attacker, defender)
	state.players[1].bench = [bench_a, bench_b]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(uxie)
	var executed := processor.execute_attack_effect(attacker, 0, defender, state)
	var marker_raw: Variant = state.shared_turn_flags.get(BaseEffect.ATTACK_DAMAGE_COUNTER_PLACEMENT_FLAG, {})
	var marker: Dictionary = marker_raw if marker_raw is Dictionary else {}
	processor.prepare_for_disposal()
	return run_checks([
		assert_true(executed, "Painful Memories should execute"),
		assert_eq(defender.damage_counters, 20, "Painful Memories should place 2 counters on the Active Pokemon"),
		assert_eq(bench_a.damage_counters, 20, "Painful Memories should place 2 counters on the first Benched Pokemon"),
		assert_eq(bench_b.damage_counters, 20, "Painful Memories should place 2 counters on the second Benched Pokemon"),
		assert_true(marker.has(int(defender.get_instance_id())), "The Active placement should be marked as attack-effect counters"),
		assert_true(marker.has(int(bench_a.get_instance_id())), "The first Bench placement should be marked as attack-effect counters"),
		assert_true(marker.has(int(bench_b.get_instance_id())), "The second Bench placement should be marked as attack-effect counters"),
	])


func test_151c_093_homecoming_returns_a_chosen_opposing_supporter_after_hand_evolution() -> String:
	var haunter := _load_card("151C_093")
	if haunter == null:
		return "151C_093 must be bundled before testing Homecoming"
	var haunter_slot := _slot(haunter, 0)
	var defender := _plain_pokemon("Defender", 100, 1)
	var state := _fixture_state(haunter_slot, defender)
	haunter_slot.turn_evolved = state.turn_number
	CSV9CHelpers.mark_evolved_from_hand(haunter_slot, state)
	var supporter := _trainer("Boss's Orders", "Supporter", 1)
	var item := _trainer("Switch", "Item", 1)
	state.players[1].discard_pile = [item, supporter]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(haunter)
	var effect := processor.get_effect(haunter.effect_id)
	if effect == null:
		processor.prepare_for_disposal()
		return "151C_093 should register Homecoming"
	var can_use := processor.can_use_ability(haunter_slot, state, 0)
	var steps := effect.get_interaction_steps(haunter_slot.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var context := {str(step.get("id", "")): [supporter]}
	var executed := processor.execute_ability_effect(haunter_slot, 0, [context], state)
	processor.prepare_for_disposal()
	return run_checks([
		assert_true(can_use, "Homecoming should be available immediately after evolving from hand"),
		assert_eq(steps.size(), 1, "Homecoming should expose one opposing-discard choice"),
		assert_eq(step.get("items", []), [supporter], "Homecoming should allow only opposing Supporter cards"),
		assert_true(executed, "Homecoming should execute with the chosen Supporter"),
		assert_true(supporter in state.players[1].hand, "The chosen Supporter should return to the opponent's hand"),
		assert_false(supporter in state.players[1].discard_pile, "The chosen Supporter should leave the opponent's discard pile"),
		assert_true(item in state.players[1].discard_pile, "Non-Supporter cards should remain in the opponent's discard pile"),
	])


func test_151c_094_poltergeist_counts_trainers_and_phantom_dive_distributes_three_counters() -> String:
	var gengar := _load_card("151C_094")
	if gengar == null:
		return "151C_094 must be bundled before testing both attacks"
	var attacker := _slot(gengar, 0)
	var defender := _plain_pokemon("Defender", 200, 1)
	var bench_a := _plain_pokemon("Bench A", 100, 1)
	var bench_b := _plain_pokemon("Bench B", 100, 1)
	var state := _fixture_state(attacker, defender)
	state.players[1].bench = [bench_a, bench_b]
	state.players[1].hand = [
		_trainer("Switch", "Item", 1),
		_trainer("Boss's Orders", "Supporter", 1),
		_plain_pokemon("Hand Pokemon", 60, 1).get_top_card(),
	]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(gengar)
	var poltergeist_steps := processor.get_attack_interaction_steps_by_id(
		gengar.effect_id,
		0,
		attacker.get_top_card(),
		gengar.attacks[0],
		state
	)
	var poltergeist_step: Dictionary = poltergeist_steps[0] if not poltergeist_steps.is_empty() else {}
	var poltergeist_bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 0):
		if effect.has_method("get_damage_bonus"):
			poltergeist_bonus += int(effect.call("get_damage_bonus", attacker, state))
	var poltergeist_damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		gengar.attacks[0],
		state,
		poltergeist_bonus
	)
	var phantom_steps := processor.get_attack_interaction_steps_by_id(
		gengar.effect_id,
		1,
		attacker.get_top_card(),
		gengar.attacks[1],
		state
	)
	var step: Dictionary = phantom_steps[0] if not phantom_steps.is_empty() else {}
	var context := {
		str(step.get("id", "")): [
			{"target": bench_a, "amount": 20},
			{"target": bench_b, "amount": 10},
		],
	}
	var invalid_context := {
		str(step.get("id", "")): [
			{"target": bench_a, "amount": 40},
		],
	}
	var invalid_distribution_accepted := processor.validate_attack_effect_context(
		attacker,
		1,
		defender,
		state,
		[invalid_context]
	)
	var phantom_executed := processor.execute_attack_effect(attacker, 1, defender, state, [context])
	processor.prepare_for_disposal()
	return run_checks([
		assert_eq(poltergeist_steps.size(), 1, "Poltergeist should reveal the opponent's hand before counting Trainers"),
		assert_eq(str(poltergeist_step.get("visible_scope", "")), "opponent_hand_revealed", "Poltergeist should intentionally reveal only the opponent's hand"),
		assert_eq(poltergeist_step.get("items", []), state.players[1].hand, "Poltergeist should show every card in the opponent's hand"),
		assert_eq(int(poltergeist_step.get("max_select", -1)), 0, "Poltergeist's hand reveal should be read-only"),
		assert_eq(poltergeist_bonus, 50, "Poltergeist should produce 100 total damage from two Trainer cards and printed 50"),
		assert_eq(poltergeist_damage, 100, "Poltergeist should deal 50 times the number of Trainer cards"),
		assert_eq(phantom_steps.size(), 1, "Phantom Dive should expose a Bench counter-distribution step"),
		assert_eq(int(step.get("total_counters", 0)), 3, "Phantom Dive should distribute exactly 3 counters"),
		assert_false(invalid_distribution_accepted, "Phantom Dive should reject distributions that do not total exactly 3 counters"),
		assert_true(phantom_executed, "Phantom Dive's scripted effect should execute"),
		assert_eq(bench_a.damage_counters, 20, "Phantom Dive should apply the selected 2 counters to Bench A"),
		assert_eq(bench_b.damage_counters, 10, "Phantom Dive should apply the selected 1 counter to Bench B"),
	])


func test_151c_gastly_haunter_gengar_preserve_evolution_metadata() -> String:
	var gastly := _load_card("151C_092")
	var haunter := _load_card("151C_093")
	var gengar := _load_card("151C_094")
	if gastly == null or haunter == null or gengar == null:
		return "151C_092 through 151C_094 must all be bundled"
	return run_checks([
		assert_eq(gastly.stage, "Basic", "Gastly should remain Basic"),
		assert_eq(haunter.stage, "Stage 1", "Haunter should remain Stage 1"),
		assert_true(haunter.evolves_from_matches(gastly), "Haunter should evolve from Gastly"),
		assert_eq(gengar.stage, "Stage 2", "Gengar should remain Stage 2"),
		assert_true(gengar.evolves_from_matches(haunter), "Gengar should evolve from Haunter"),
	])
