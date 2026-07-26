class_name TestTCGMikCSV6C056CSV9C086087
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")

const CSV6C_056_EFFECT_ID := "61acdd76828977fa4ea85995594b3933"
const CSV9C_086_EFFECT_ID := "44f103a4497ed27afdd7b0c5b107ad12"
const CSV9C_087_EFFECT_ID := "17727f6b35cbad5906fab2edecf4236d"
const TARGET_STEP_ID := "opponent_pokemon_damage_counter_target"
const MIST_ENERGY_EFFECT_ID := "fb0948c721db1f31767aa6cf0c2ea692"


func test_imported_cards_are_bundled_and_visible_in_the_deck_editor_pool() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var expected_files := [
		"res://data/bundled_user/cards/CSV6C_056.json",
		"res://data/bundled_user/cards/images/CSV6C/056.png.bin",
		"res://data/bundled_user/cards/CSV9C_086.json",
		"res://data/bundled_user/cards/images/CSV9C/086.png.bin",
		"res://data/bundled_user/cards/CSV9C_087.json",
		"res://data/bundled_user/cards/images/CSV9C/087.png.bin",
	]
	var checks: Array[String] = []
	for path: String in expected_files:
		checks.append(assert_true(FileAccess.file_exists(path), "%s should exist in the bundled card payload" % path))
		checks.append(assert_str_contains(manifest, path, "%s should be included in the bundled manifest" % path))

	var db := CardDatabaseScript.new()
	var all_uids := {}
	for card: CardData in db.get_all_cards():
		all_uids[card.get_uid()] = true
	for uid: String in ["CSV6C_056", "CSV9C_086", "CSV9C_087"]:
		checks.append(assert_true(all_uids.has(uid), "%s should materialize from CardDatabase" % uid))
	db.free()

	var editor := DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_uids := {}
	var categories: Array = editor.get("_pool_by_category")
	for category: Array in categories:
		for card: CardData in category:
			pool_uids[card.get_uid()] = true
	for uid: String in ["CSV6C_056", "CSV9C_086", "CSV9C_087"]:
		checks.append(assert_true(pool_uids.has(uid), "%s should be selectable in the deck editor card pool" % uid))
	editor.free()
	return run_checks(checks)


func test_csv9c_086_and_087_preserve_printed_metadata_and_evolution_legality() -> String:
	var yamask := _load_card("CSV9C", "086")
	var cofagrigus := _load_card("CSV9C", "087")
	if yamask == null or cofagrigus == null:
		return assert_true(false, "CSV9C_086 and CSV9C_087 should both load")

	var gsm := _make_gsm()
	var yamask_slot := _make_slot(yamask, 0)
	yamask_slot.turn_played = gsm.game_state.turn_number - 1
	gsm.game_state.players[0].active_pokemon = yamask_slot
	var evolution := CardInstance.create(cofagrigus, 0)
	gsm.game_state.players[0].hand.append(evolution)
	var legal := gsm.rule_validator.can_evolve(
		gsm.game_state,
		0,
		yamask_slot,
		evolution,
		gsm.effect_processor,
	)
	var evolved := gsm.evolve_pokemon(0, evolution, yamask_slot)

	return run_checks([
		assert_eq(yamask.name, "哭哭面具", "CSV9C_086 should preserve the Chinese name"),
		assert_eq(yamask.name_en, "Yamask", "CSV9C_086 should preserve the English name"),
		assert_eq(yamask.effect_id, CSV9C_086_EFFECT_ID, "CSV9C_086 should preserve its source effect id"),
		assert_eq(yamask.attacks.size(), 2, "CSV9C_086 should expose both printed attacks"),
		assert_eq(str(yamask.attacks[0].get("damage", "")), "10", "Mumble should deal 10"),
		assert_eq(str(yamask.attacks[1].get("damage", "")), "20", "Little Grudge should deal 20"),
		assert_false(CardImplementationStatus.is_unimplemented(yamask), "CSV9C_086 has only fixed-damage attacks and should be marked implemented"),
		assert_eq(cofagrigus.name, "迭失棺", "CSV9C_087 should preserve the Chinese name"),
		assert_eq(cofagrigus.name_en, "Cofagrigus", "CSV9C_087 should preserve the English name"),
		assert_eq(cofagrigus.effect_id, CSV9C_087_EFFECT_ID, "CSV9C_087 should preserve its source effect id"),
		assert_eq(cofagrigus.stage, "Stage 1", "CSV9C_087 should remain a Stage 1 Pokemon"),
		assert_eq(cofagrigus.evolves_from, "哭哭面具", "CSV9C_087 should display its printed evolution source"),
		assert_true(cofagrigus.evolves_from_matches(yamask), "CSV9C_087 should recognize CSV9C_086 as a legal pre-evolution"),
		assert_true(legal, "RuleValidator should allow CSV9C_087 to evolve from CSV9C_086"),
		assert_true(evolved, "GameStateMachine should execute the imported evolution"),
		assert_eq(yamask_slot.get_card_data(), cofagrigus, "CSV9C_087 should be placed on top after evolution"),
	])


func test_csv6c_056_requires_one_explicit_target_and_places_three_counters() -> String:
	var card := _load_card("CSV6C", "056")
	if card == null:
		return assert_not_null(card, "CSV6C_056 should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _make_slot(card, 0)
	var opponent_active := _make_slot(_pokemon("Opponent Active", 200), 1)
	var opponent_bench := _make_slot(_pokemon("Opponent Bench", 200), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = opponent_active
	opponent.bench.append(opponent_bench)
	_attach_energy(attacker, "P", 2)
	gsm.effect_processor.register_pokemon_card(card)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var target_effect: BaseEffect = null
	for effect: BaseEffect in effects:
		var script_path := str(effect.get_script().resource_path) if effect.get_script() != null else ""
		if script_path.ends_with("AttackChooseOpponentPokemonDamageCounters.gd"):
			target_effect = effect
			break
	var steps: Array = target_effect.get_attack_interaction_steps(
		attacker.get_top_card(),
		card.attacks[0],
		gsm.game_state,
	) if target_effect != null else []
	var items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var missing_target_valid := gsm.effect_processor.validate_attack_effect_context(
		attacker,
		0,
		opponent_active,
		gsm.game_state,
		[],
	)
	var own_target_valid := gsm.effect_processor.validate_attack_effect_context(
		attacker,
		0,
		opponent_active,
		gsm.game_state,
		[{TARGET_STEP_ID: [attacker]}],
	)
	var used := gsm.use_attack(0, 0, [{TARGET_STEP_ID: [opponent_bench]}])

	return run_checks([
		assert_eq(card.effect_id, CSV6C_056_EFFECT_ID, "CSV6C_056 should preserve its source effect id"),
		assert_eq(card.attacks.size(), 1, "CSV6C_056 should expose its printed attack"),
		assert_eq(str(card.attacks[0].get("cost", "")), "PP", "Ominous Eyes should cost two Psychic Energy"),
		assert_not_null(target_effect, "Ominous Eyes should register the reusable arbitrary-target counter effect"),
		assert_eq(steps.size(), 1, "Ominous Eyes should expose one target-selection step"),
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 1, "Ominous Eyes target should be mandatory"),
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 1, "Ominous Eyes should select exactly one target"),
		assert_true(opponent_active in items, "Ominous Eyes should allow the opponent Active Pokemon"),
		assert_true(opponent_bench in items, "Ominous Eyes should allow an opponent Benched Pokemon"),
		assert_false(missing_target_valid, "Ominous Eyes should reject a missing mandatory target"),
		assert_false(own_target_valid, "Ominous Eyes should reject a stale or friendly target"),
		assert_true(used, "Ominous Eyes should resolve through GameStateMachine"),
		assert_eq(opponent_active.damage_counters, 0, "The unselected Active Pokemon should not receive counters"),
		assert_eq(opponent_bench.damage_counters, 30, "The selected Benched Pokemon should receive exactly 3 damage counters"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV6C_056 should be marked implemented"),
	])


func test_csv9c_087_places_six_counters_on_each_ability_pokemon_with_opponent_protection() -> String:
	var card := _load_card("CSV9C", "087")
	if card == null:
		return assert_not_null(card, "CSV9C_087 should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _make_slot(card, 0)
	var own_ability := _make_slot(_pokemon("Own Ability", 200, true), 0)
	var own_no_ability := _make_slot(_pokemon("Own Plain", 200), 0)
	var opponent_ability := _make_slot(_pokemon("Opponent Ability", 200, true), 1)
	var opponent_mist_ability := _make_slot(_pokemon("Opponent Mist Ability", 200, true), 1)
	var opponent_no_ability := _make_slot(_pokemon("Opponent Plain", 200), 1)
	player.active_pokemon = attacker
	player.bench = [own_ability, own_no_ability]
	opponent.active_pokemon = opponent_ability
	opponent.bench = [opponent_mist_ability, opponent_no_ability]
	_attach_energy(attacker, "P", 1)
	_attach_mist_energy(own_ability, 0)
	_attach_mist_energy(opponent_mist_ability, 1)
	gsm.effect_processor.register_pokemon_card(card)

	var route_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var damage_effect: BaseEffect = null
	for effect: BaseEffect in route_effects:
		var script_path := str(effect.get_script().resource_path) if effect.get_script() != null else ""
		if script_path.ends_with("AttackDamageCountersToAllPokemonWithAbilities.gd"):
			damage_effect = effect
			break
	var second_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(damage_effect, "Underworld Rule should register its field-wide counter effect"),
		assert_eq(route_effects.size(), 1, "Underworld Rule should register exactly one custom attack effect"),
		assert_eq(second_attack_effects.size(), 0, "Shadow Shot should remain a fixed 100-damage attack without custom effects"),
		assert_true(used, "Underworld Rule should resolve through GameStateMachine"),
		assert_eq(attacker.damage_counters, 0, "Cofagrigus has no printed Ability and should not receive counters"),
		assert_eq(own_ability.damage_counters, 60, "Own Mist Energy must not prevent the attack owner's field-wide effect"),
		assert_eq(own_no_ability.damage_counters, 0, "Own Pokemon without an Ability should not receive counters"),
		assert_eq(opponent_ability.damage_counters, 60, "Each opponent Pokemon with a printed Ability should receive 6 counters"),
		assert_eq(opponent_mist_ability.damage_counters, 0, "Mist Energy should prevent the opponent attack effect"),
		assert_eq(opponent_no_ability.damage_counters, 0, "Opponent Pokemon without an Ability should not receive counters"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV9C_087 should be marked implemented"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card(set_code, card_index)
	db.free()
	return card


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
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


func _pokemon(name: String, hp: int, has_ability: bool = false) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	card.abilities.clear()
	if has_ability:
		card.abilities.append({"name": "Test Ability", "text": "Printed Ability"})
	return card


func _energy(energy_type: String, index: int) -> CardData:
	var card := CardData.new()
	card.name = "%s Energy %d" % [energy_type, index]
	card.name_en = card.name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _attach_energy(slot: PokemonSlot, energy_type: String, count: int) -> void:
	for index: int in count:
		slot.attached_energy.append(CardInstance.create(_energy(energy_type, index), 0))


func _attach_mist_energy(slot: PokemonSlot, owner_index: int) -> void:
	var card := CardData.new()
	card.name = "薄雾能量"
	card.name_en = "Mist Energy"
	card.card_type = "Special Energy"
	card.energy_type = "C"
	card.energy_provides = "C"
	card.effect_id = MIST_ENERGY_EFFECT_ID
	slot.attached_energy.append(CardInstance.create(card, owner_index))
