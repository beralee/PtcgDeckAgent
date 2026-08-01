class_name TestTcgMikGlimmetBatch1
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")

const REQUESTED_CARDS := {
	"CSVL2C_041": {
		"set_code": "CSVL2C",
		"card_index": "041",
		"name_en": "Glimmet",
		"effect_id": "6c4382c1f802fa873ec01976306d44be",
	},
	"CSV3C_079": {
		"set_code": "CSV3C",
		"card_index": "079",
		"name_en": "Glimmora",
		"effect_id": "8d661d82a0867cc1d450e0eb137be5ee",
	},
	"CSV5C_073": {
		"set_code": "CSV5C",
		"card_index": "073",
		"name_en": "Glimmora ex",
		"effect_id": "ea9a967a89789870e4495d6b26f9c8a2",
	},
	"CSV9.5C_094": {
		"set_code": "CSV9.5C",
		"card_index": "094",
		"name_en": "Drilbur",
		"effect_id": "7c840e8bed0d40dba697cfd3faeed75d",
	},
	"CSV9C_084": {
		"set_code": "CSV9C",
		"card_index": "084",
		"name_en": "Azelf",
		"effect_id": "eae2a9a7d9e741b30837cc8e41c58780",
	},
}


class RiggedCoinFlipper:
	extends CoinFlipper

	var results: Array[bool] = []
	var flip_count: int = 0

	func _init(sequence: Array[bool]) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		flip_count += 1
		return results.pop_front() if not results.is_empty() else false


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


func _basic_energy(name: String, energy_type: String, owner_index: int) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Basic Energy"
	card_data.energy_type = energy_type
	card_data.energy_provides = energy_type
	return CardInstance.create(card_data, owner_index)


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


func test_requested_batch1_cards_are_bundled_and_visible() -> String:
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


func test_csvl2c_041_awakening_exposes_full_deck_search_and_evolves() -> String:
	var glimmet := _load_card("CSVL2C_041")
	var glimmora := _load_card("CSV3C_079")
	if glimmet == null or glimmora == null:
		return "CSVL2C_041 and CSV3C_079 must be bundled before testing Awakening"
	var attacker := _slot(glimmet, 0)
	var defender := _plain_pokemon("Defender", 100, 1)
	var state := _fixture_state(attacker, defender)
	var evolution := CardInstance.create(glimmora, 0)
	var irrelevant := _basic_energy("Basic Psychic Energy", "P", 0)
	state.players[0].deck = [irrelevant, evolution]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(glimmet)
	var steps := processor.get_attack_interaction_steps_by_id(
		glimmet.effect_id,
		0,
		attacker.get_top_card(),
		glimmet.attacks[0],
		state
	)
	var first_step: Dictionary = steps[0] if not steps.is_empty() else {}
	var context := {str(first_step.get("id", "")): [evolution]}
	var executed := processor.execute_attack_effect(attacker, 0, defender, state, [context])
	processor.prepare_for_disposal()
	return run_checks([
		assert_eq(steps.size(), 1, "Awakening should expose one evolution search step"),
		assert_eq(str(first_step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Awakening should show the full own deck"),
		assert_eq(first_step.get("card_items", []), [irrelevant, evolution], "Awakening should keep illegal deck cards visible"),
		assert_eq(first_step.get("items", []), [evolution], "Awakening should allow only matching evolutions"),
		assert_true(executed, "Awakening should execute with the selected evolution"),
		assert_eq(attacker.get_top_card(), evolution, "Awakening should evolve the attacking Glimmet"),
		assert_false(evolution in state.players[0].deck, "The evolution should leave the deck"),
	])


func test_csv3c_079_crumbling_crystal_and_severe_poison_match_card_text() -> String:
	var glimmora := _load_card("CSV3C_079")
	if glimmora == null:
		return "CSV3C_079 must be bundled before testing Crumbling Crystal"
	var attacker := _slot(glimmora, 0)
	var defender := _plain_pokemon("Defender", 200, 1)
	var state := _fixture_state(attacker, defender)
	var processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	processor.register_pokemon_card(glimmora)
	var attack_executed := processor.execute_attack_effect(attacker, 0, defender, state)
	var poison_damage_bonus := processor.get_poison_damage_bonus(defender, state)
	var prevented_prizes := false
	if processor.has_method("apply_knockout_prize_prevention_ability"):
		prevented_prizes = bool(processor.call("apply_knockout_prize_prevention_ability", attacker, state))
	var has_prevention_marker := false
	for marker: Dictionary in attacker.effects:
		if marker.get("type", "") == "prevent_knockout_prizes":
			has_prevention_marker = true
	processor.prepare_for_disposal()
	return run_checks([
		assert_true(attack_executed, "Toxic Peony should execute"),
		assert_true(bool(defender.status_conditions.get("poisoned", false)), "Toxic Peony should Poison"),
		assert_eq(poison_damage_bonus, 50, "Toxic Peony should make Poison place 6 counters total"),
		assert_true(prevented_prizes, "Crumbling Crystal should be able to prevent Prize cards on heads"),
		assert_true(has_prevention_marker, "Crumbling Crystal should mark this knockout as awarding no Prizes"),
	])


func test_csv3c_079_crumbling_crystal_resolves_a_tails_result_only_once_per_knockout() -> String:
	var glimmora := _load_card("CSV3C_079")
	if glimmora == null:
		return "CSV3C_079 must be bundled before testing Crumbling Crystal"
	var knocked_out := _slot(glimmora, 0)
	var defender := _plain_pokemon("Defender", 200, 1)
	var state := _fixture_state(knocked_out, defender)
	var flipper := RiggedCoinFlipper.new([false, true])
	var processor := EffectProcessor.new(flipper)
	processor.register_pokemon_card(glimmora)
	var first_result := processor.apply_knockout_prize_prevention_ability(knocked_out, state)
	var repeated_result := processor.apply_knockout_prize_prevention_ability(knocked_out, state)
	var has_prevention_marker := false
	for marker: Dictionary in knocked_out.effects:
		if marker.get("type", "") == "prevent_knockout_prizes":
			has_prevention_marker = true
	processor.prepare_for_disposal()
	return run_checks([
		assert_false(first_result, "Crumbling Crystal tails should not prevent Prize cards"),
		assert_false(repeated_result, "Re-entering knockout resolution should preserve the original tails result"),
		assert_eq(flipper.flip_count, 1, "Crumbling Crystal should flip only once for the same knockout"),
		assert_false(has_prevention_marker, "A tails result should not add the no-Prize marker"),
	])


func test_csv9_5c_094_dig_dig_dig_is_optional_full_deck_discard() -> String:
	var drilbur := _load_card("CSV9.5C_094")
	if drilbur == null:
		return "CSV9.5C_094 must be bundled before testing Dig Dig Dig"
	var bench_slot := _slot(drilbur, 0)
	var defender := _plain_pokemon("Defender", 100, 1)
	var active := _plain_pokemon("Own Active", 100, 0)
	var state := _fixture_state(active, defender)
	state.players[0].bench.append(bench_slot)
	bench_slot.turn_played = state.turn_number
	bench_slot.mark_entered_bench_from_hand(state.turn_number)
	var fighting_a := _basic_energy("Basic Fighting Energy A", "F", 0)
	var fighting_b := _basic_energy("Basic Fighting Energy B", "F", 0)
	var psychic := _basic_energy("Basic Psychic Energy", "P", 0)
	state.players[0].deck = [psychic, fighting_a, fighting_b]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(drilbur)
	var effect := processor.get_effect(drilbur.effect_id)
	if effect == null:
		processor.prepare_for_disposal()
		return "CSV9.5C_094 should register Dig Dig Dig"
	var steps := effect.get_interaction_steps(bench_slot.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var context := {str(step.get("id", "")): [fighting_a, fighting_b]}
	var executed := processor.execute_ability_effect(bench_slot, 0, [context], state)
	processor.prepare_for_disposal()
	return run_checks([
		assert_eq(steps.size(), 1, "Dig Dig Dig should expose one optional search step"),
		assert_eq(int(step.get("min_select", -1)), 0, "Dig Dig Dig should allow choosing zero Energy"),
		assert_eq(int(step.get("max_select", -1)), 2, "Dig Dig Dig should cap at available legal Energy up to three"),
		assert_eq(step.get("card_items", []), [psychic, fighting_a, fighting_b], "Dig Dig Dig should visibly show the whole deck"),
		assert_eq(step.get("items", []), [fighting_a, fighting_b], "Only Basic Fighting Energy should be selectable"),
		assert_true(executed, "Dig Dig Dig should execute with two selected Energy"),
		assert_true(fighting_a in state.players[0].discard_pile and fighting_b in state.players[0].discard_pile, "Selected Fighting Energy should move to the discard pile"),
		assert_true(psychic in state.players[0].deck, "Non-Fighting Energy should remain in the deck"),
	])


func test_csv9c_084_mind_ruler_counts_damage_counters_on_all_opposing_pokemon() -> String:
	var azelf := _load_card("CSV9C_084")
	if azelf == null:
		return "CSV9C_084 must be bundled before testing Mind Ruler"
	var attacker := _slot(azelf, 0)
	var defender := _plain_pokemon("Defender", 200, 1)
	var bench := _plain_pokemon("Damaged Bench", 100, 1)
	defender.damage_counters = 20
	bench.damage_counters = 30
	var state := _fixture_state(attacker, defender)
	state.players[1].bench.append(bench)
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(azelf)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	var bonus := 0
	for effect: BaseEffect in effects:
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", attacker, state))
	var damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		azelf.attacks[0],
		state,
		bonus
	)
	processor.prepare_for_disposal()
	return run_checks([
		assert_eq(bonus, 50, "Mind Ruler should add 10 damage per counter across all opposing Pokemon"),
		assert_eq(damage, 60, "Mind Ruler should deal printed 10 plus the 5 opposing counters"),
	])
