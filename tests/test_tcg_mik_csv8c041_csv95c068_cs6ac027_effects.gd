class_name TestTcgMikCsv8c041Csv95c068Cs6ac027Effects
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AttackDiscardAllOpponentSpecialEnergyScript := preload("res://scripts/effects/pokemon_effects/AttackDiscardAllOpponentSpecialEnergy.gd")
const AttackSelfAllAttacksLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd")
const AttackOpponentHiddenHandDiscardScript := preload("res://scripts/effects/pokemon_effects/AttackOpponentHiddenHandDiscard.gd")
const AttackDevolveOpponentEvolutionToDeckScript := preload("res://scripts/effects/pokemon_effects/AttackDevolveOpponentEvolutionToDeck.gd")
const AbilityHealOwnPokemonScript := preload("res://scripts/effects/pokemon_effects/AbilityHealOwnPokemon.gd")
const AttackClearOwnStatusScript := preload("res://scripts/effects/pokemon_effects/AttackClearOwnStatus.gd")

const CERULEDGE_EFFECT_ID := "d765aee0ef7bd61daa1fa40c146d4e33"
const ESPEON_EFFECT_ID := "b8bb46f1d76a9143f1a8fbc74ae80602"
const RADIANT_TSAREENA_EFFECT_ID := "a28dc32ef66ad5de6c6c5e51243703fa"


class RiggedCoinFlipper:
	extends CoinFlipper

	var results: Array[bool] = []

	func _init(sequence: Array[bool]) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var value := true
		if not results.is_empty():
			value = results.pop_front()
		coin_flipped.emit(value)
		return value


func test_tcg_mik_imported_cards_are_seeded_and_register_expected_effects() -> String:
	CardImplementationStatus.clear_cache()
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var specs := [
		{"set": "CSV8C", "index": "041", "name_en": "Ceruledge", "effect_id": CERULEDGE_EFFECT_ID},
		{"set": "CSV9.5C", "index": "068", "name_en": "Espeon ex", "effect_id": ESPEON_EFFECT_ID},
		{"set": "CS6aC", "index": "027", "name_en": "Radiant Tsareena", "effect_id": RADIANT_TSAREENA_EFFECT_ID},
	]
	var checks: Array[String] = []
	var processor := EffectProcessor.new()
	for spec: Dictionary in specs:
		var set_code := str(spec.get("set", ""))
		var card_index := str(spec.get("index", ""))
		var card_id := "%s_%s" % [set_code, card_index]
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(card_path in manifest, "%s card JSON should be listed in bundled manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in bundled manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled card JSON should exist" % card_id))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled image should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % card_id))
		checks.append(assert_not_null(card, "%s should load from CardDatabase" % card_id))
		if card == null:
			continue
		checks.append(assert_eq(str(card.name_en), str(spec.get("name_en", "")), "%s should keep API English name" % card_id))
		checks.append(assert_eq(str(card.effect_id), str(spec.get("effect_id", "")), "%s should keep API effect_id" % card_id))
		processor.register_pokemon_card(card)
	var ceruledge := db.get_card("CSV8C", "041")
	var espeon := db.get_card("CSV9.5C", "068")
	var tsareena := db.get_card("CS6aC", "027")
	checks.append(assert_true(_has_effect_type(processor.get_attack_effects_for_slot(_slot(ceruledge, 0), 0), AttackDiscardAllOpponentSpecialEnergyScript), "CSV8C_041 first attack should register all-opponent Special Energy discard"))
	checks.append(assert_true(_has_effect_type(processor.get_attack_effects_for_slot(_slot(ceruledge, 0), 1), AttackSelfAllAttacksLockNextTurnScript), "CSV8C_041 second attack should register whole-Pokemon attack lock"))
	checks.append(assert_true(_has_effect_type(processor.get_attack_effects_for_slot(_slot(espeon, 0), 0), AttackOpponentHiddenHandDiscardScript), "CSV9.5C_068 first attack should register hidden opponent hand discard"))
	checks.append(assert_true(_has_effect_type(processor.get_attack_effects_for_slot(_slot(espeon, 0), 1), AttackDevolveOpponentEvolutionToDeckScript), "CSV9.5C_068 second attack should register devolution-to-deck"))
	checks.append(assert_true(processor.get_effect(RADIANT_TSAREENA_EFFECT_ID) is AbilityHealOwnPokemonScript, "CS6aC_027 should register Elegant Heal by effect_id"))
	checks.append(assert_true(_has_effect_type(processor.get_attack_effects_for_slot(_slot(tsareena, 0), 0), AttackClearOwnStatusScript), "CS6aC_027 attack should register self status clear"))
	checks.append(assert_false(CardImplementationStatus.is_unimplemented(ceruledge), "CSV8C_041 should not be marked unimplemented"))
	checks.append(assert_false(CardImplementationStatus.is_unimplemented(espeon), "CSV9.5C_068 should not be marked unimplemented"))
	checks.append(assert_false(CardImplementationStatus.is_unimplemented(tsareena), "CS6aC_027 should not be marked unimplemented"))
	db.free()
	return run_checks(checks)


func test_csv8c_041_ceruledge_discards_all_opponent_special_energy_and_locks_attacks() -> String:
	var card := _load_card("CSV8C", "041")
	if card == null:
		return assert_not_null(card, "CSV8C_041 Ceruledge should load from the bundled card pool")
	var discard_gsm := _make_gsm()
	var player: PlayerState = discard_gsm.game_state.players[0]
	var opponent: PlayerState = discard_gsm.game_state.players[1]
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Opponent Active", "C", 300), 1)
	var bench := _slot(_pokemon("Opponent Bench", "C", 100), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	opponent.bench.append(bench)
	_attach_energy(attacker, 0, "C", 1)
	var active_special_a := CardInstance.create(_special_energy("Special A"), 1)
	var active_special_b := CardInstance.create(_special_energy("Special B"), 1)
	var bench_special := CardInstance.create(_special_energy("Special C"), 1)
	var active_basic := CardInstance.create(_basic_energy("Water Energy", "W"), 1)
	defender.attached_energy.append_array([active_special_a, active_basic, active_special_b])
	bench.attached_energy.append(bench_special)
	discard_gsm.effect_processor.register_pokemon_card(card)
	var discarded := discard_gsm.use_attack(0, 0)

	var lock_gsm := _make_gsm()
	var lock_player: PlayerState = lock_gsm.game_state.players[0]
	var lock_opponent: PlayerState = lock_gsm.game_state.players[1]
	var lock_attacker := _slot(card, 0)
	var lock_defender := _slot(_pokemon("Lock Defender", "C", 300), 1)
	lock_player.active_pokemon = lock_attacker
	lock_opponent.active_pokemon = lock_defender
	_attach_energy(lock_attacker, 0, "R", 2)
	_attach_energy(lock_attacker, 0, "C", 1)
	lock_gsm.effect_processor.register_pokemon_card(card)
	var attack_turn := lock_gsm.game_state.turn_number
	var locked_attack_used := lock_gsm.use_attack(0, 1)
	lock_gsm.game_state.current_player_index = 0
	lock_gsm.game_state.turn_number = attack_turn + 2
	lock_gsm.game_state.phase = GameState.GamePhase.MAIN
	var first_attack_locked := not lock_gsm.can_use_attack(0, 0)
	var second_attack_locked := not lock_gsm.can_use_attack(0, 1)

	return run_checks([
		assert_true(discarded, "Ceruledge should use its first attack with one Colorless Energy"),
		assert_true(active_special_a in opponent.discard_pile, "First opponent Active Special Energy should be discarded"),
		assert_true(active_special_b in opponent.discard_pile, "Second opponent Active Special Energy should also be discarded"),
		assert_true(bench_special in opponent.discard_pile, "Opponent Bench Special Energy should be discarded"),
		assert_true(active_basic in defender.attached_energy, "Basic Energy should remain attached"),
		assert_true(locked_attack_used, "Ceruledge should use Black Blaze Slash with RRC attached"),
		assert_eq(lock_defender.damage_counters, 160, "Black Blaze Slash should deal printed 160 damage"),
		assert_true(first_attack_locked, "Black Blaze Slash should lock Ceruledge's first attack next own turn"),
		assert_true(second_attack_locked, "Black Blaze Slash should lock Ceruledge's second attack next own turn"),
	])


func test_csv95c_068_espeon_ex_hidden_hand_discard_and_devolution_to_deck() -> String:
	var card := _load_card("CSV9.5C", "068")
	if card == null:
		return assert_not_null(card, "CSV9.5C_068 Espeon ex should load from the bundled card pool")
	var hand_gsm := _make_gsm()
	var player: PlayerState = hand_gsm.game_state.players[0]
	var opponent: PlayerState = hand_gsm.game_state.players[1]
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Opponent Active", "C", 300), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	_attach_energy(attacker, 0, "P", 1)
	_attach_energy(attacker, 0, "C", 2)
	var item := CardInstance.create(_trainer("Opponent Item", "Item"), 1)
	var basic := CardInstance.create(_pokemon("Opponent Hand Pokemon", "C", 70), 1)
	opponent.hand.append_array([item, basic])
	hand_gsm.effect_processor.register_pokemon_card(card)
	var steps := hand_gsm.effect_processor.get_attack_interaction_steps_by_id(card.effect_id, 0, attacker.get_top_card(), card.attacks[0], hand_gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var attacked := hand_gsm.use_attack(0, 0, [{AttackOpponentHiddenHandDiscardScript.STEP_ID: [basic]}])

	var devolve_gsm := _make_gsm()
	var devolve_player: PlayerState = devolve_gsm.game_state.players[0]
	var devolve_opponent: PlayerState = devolve_gsm.game_state.players[1]
	var devolve_attacker := _slot(card, 0)
	var base_active := CardInstance.create(_pokemon("Base Active", "C", 100), 1)
	var stage1_active := CardInstance.create(_pokemon("Stage1 Active", "C", 140, "Stage 1", "Base Active"), 1)
	var stage2_active := CardInstance.create(_pokemon("Stage2 Active", "C", 180, "Stage 2", "Stage1 Active"), 1)
	var base_bench := CardInstance.create(_pokemon("Base Bench", "C", 100), 1)
	var stage1_bench := CardInstance.create(_pokemon("Stage1 Bench", "C", 140, "Stage 1", "Base Bench"), 1)
	var evolved_active := _stack_slot([base_active, stage1_active, stage2_active], 1)
	var evolved_bench := _stack_slot([base_bench, stage1_bench], 1)
	var basic_bench := _slot(_pokemon("Basic Bench", "C", 100), 1)
	devolve_player.active_pokemon = devolve_attacker
	devolve_opponent.active_pokemon = evolved_active
	devolve_opponent.bench.append_array([evolved_bench, basic_bench])
	devolve_opponent.deck.append(CardInstance.create(_trainer("Deck Filler", "Item"), 1))
	_attach_energy(devolve_attacker, 0, "G", 1)
	_attach_energy(devolve_attacker, 0, "P", 1)
	_attach_energy(devolve_attacker, 0, "D", 1)
	devolve_gsm.effect_processor.register_pokemon_card(card)
	var devolved := devolve_gsm.use_attack(0, 1)

	return run_checks([
		assert_eq(steps.size(), 1, "Psych Out should expose a hidden opponent-hand selection step"),
		assert_eq(str(step.get("visible_scope", "")), "opponent_hand_hidden", "Psych Out must not reveal opponent hand faces"),
		assert_false(step.has("card_items"), "Psych Out should not expose card preview items for hidden hand cards"),
		assert_true(attacked, "Psych Out should execute with PCC attached"),
		assert_eq(defender.damage_counters, 160, "Psych Out should deal printed 160 damage"),
		assert_true(item in opponent.hand, "Psych Out should leave the unselected hidden hand card"),
		assert_false(basic in opponent.hand, "Psych Out should remove the selected hidden hand card"),
		assert_true(basic in opponent.discard_pile, "Psych Out should discard the selected hidden hand card"),
		assert_true(devolved, "Amazez should execute with GPD attached"),
		assert_eq(evolved_active.pokemon_stack.size(), 2, "Amazez should remove one top Evolution card from opponent Active"),
		assert_eq(evolved_bench.pokemon_stack.size(), 1, "Amazez should remove one top Evolution card from opponent Bench"),
		assert_eq(basic_bench.pokemon_stack.size(), 1, "Amazez should leave Basic Pokemon unchanged"),
		assert_true(stage2_active in devolve_opponent.deck, "Removed Active Evolution card should be shuffled into opponent deck"),
		assert_true(stage1_bench in devolve_opponent.deck, "Removed Bench Evolution card should be shuffled into opponent deck"),
		assert_false(stage2_active in devolve_opponent.hand, "Removed Evolution cards should not go to opponent hand"),
		assert_eq(devolve_opponent.shuffle_count, 1, "Amazez should shuffle the opponent deck once after devolution"),
	])


func test_cs6ac_027_radiant_tsareena_heals_own_field_once_and_clears_own_status() -> String:
	var card := _load_card("CS6aC", "027")
	if card == null:
		return assert_not_null(card, "CS6aC_027 Radiant Tsareena should load from the bundled card pool")
	var ability_gsm := _make_gsm()
	var player: PlayerState = ability_gsm.game_state.players[0]
	var opponent: PlayerState = ability_gsm.game_state.players[1]
	var tsareena := _slot(card, 0)
	var own_bench := _slot(_pokemon("Own Bench", "G", 100), 0)
	var opponent_active := _slot(_pokemon("Opponent Active", "C", 200), 1)
	player.active_pokemon = tsareena
	player.bench.append(own_bench)
	opponent.active_pokemon = opponent_active
	tsareena.damage_counters = 30
	own_bench.damage_counters = 10
	opponent_active.damage_counters = 50
	ability_gsm.effect_processor.register_pokemon_card(card)
	var used := ability_gsm.use_ability(0, tsareena, 0, [])
	var repeat_allowed := ability_gsm.effect_processor.can_use_ability(tsareena, ability_gsm.game_state, 0)
	ability_gsm.game_state.current_player_index = 1
	var opponent_turn_allowed := ability_gsm.effect_processor.can_use_ability(tsareena, ability_gsm.game_state, 0)

	var attack_gsm := _make_gsm()
	var attack_player: PlayerState = attack_gsm.game_state.players[0]
	var attack_opponent: PlayerState = attack_gsm.game_state.players[1]
	var status_tsareena := _slot(card, 0)
	var defender := _slot(_pokemon("Status Defender", "C", 200), 1)
	attack_player.active_pokemon = status_tsareena
	attack_opponent.active_pokemon = defender
	_attach_energy(status_tsareena, 0, "G", 1)
	_attach_energy(status_tsareena, 0, "C", 2)
	status_tsareena.status_conditions["poisoned"] = true
	status_tsareena.status_conditions["burned"] = true
	status_tsareena.status_conditions["confused"] = true
	var attack_flipper := RiggedCoinFlipper.new([true])
	attack_gsm.coin_flipper = attack_flipper
	attack_gsm.effect_processor.coin_flipper = attack_flipper
	attack_gsm.effect_processor.register_pokemon_card(card)
	var attacked := attack_gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "Elegant Heal should execute during its owner's turn"),
		assert_eq(tsareena.damage_counters, 10, "Elegant Heal should heal 20 from Radiant Tsareena"),
		assert_eq(own_bench.damage_counters, 0, "Elegant Heal should heal up to 20 from each own Benched Pokemon"),
		assert_eq(opponent_active.damage_counters, 50, "Elegant Heal should not heal opponent Pokemon"),
		assert_false(repeat_allowed, "Elegant Heal should be once during the turn"),
		assert_false(opponent_turn_allowed, "Elegant Heal should not be usable on the opponent's turn"),
		assert_true(attacked, "Aroma Shot should execute with GCC attached"),
		assert_eq(defender.damage_counters, 90, "Aroma Shot should deal printed 90 damage"),
		assert_false(status_tsareena.status_conditions.get("poisoned", false), "Aroma Shot should clear Poison"),
		assert_false(status_tsareena.status_conditions.get("burned", false), "Aroma Shot should clear Burn"),
		assert_false(status_tsareena.status_conditions.get("confused", false), "Aroma Shot should clear Confusion"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card(set_code, card_index)
	db.free()
	return card


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card_data != null:
		slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _stack_slot(cards: Array, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	for card: Variant in cards:
		if card is CardInstance:
			slot.pokemon_stack.append(card)
		elif card is CardData:
			slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(
	name: String,
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	evolves_from: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.evolves_from = evolves_from
	cd.energy_type = energy_type
	cd.hp = hp
	cd.attacks = [_attack("Tackle", "C", "10", "")]
	return cd


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	cd.description = name
	return cd


func _basic_energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _special_energy(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Special Energy"
	cd.energy_provides = "C"
	return cd


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int = 1) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_basic_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))


func _attack(name: String, cost: String, damage: String, text: String) -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _has_effect_type(effects: Array, effect_type: Variant) -> bool:
	for effect: BaseEffect in effects:
		if is_instance_of(effect, effect_type):
			return true
	return false
