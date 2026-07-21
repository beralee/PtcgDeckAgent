class_name TestTcgMikCsv8c050Csv95c034036205Csv6c112
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const BattleStadiumBackdropCoordinatorScript := preload("res://scripts/ui/battle/display/BattleStadiumBackdropCoordinator.gd")

const GOLDEEN_EFFECT_ID := "7580acd5669bac12cb1af8007d2e6a6a"
const SEAKING_EFFECT_ID := "c03588e3709ba32ad3c63409b64bdf2c"
const NEUTRALIZATION_ZONE_EFFECT_ID := "6697150282b5d32d026ce20a993b4b53"
const VAPOREON_EX_EFFECT_ID := "cd3b65c57a50f301db65efd05d7d79e3"
const BOMBIRDIER_EX_EFFECT_ID := "bbdb7b20fc7c4292acad64687c1ef318"

const FAST_CARRIER_STEP_ID := "bombirdier_fast_carrier"
const SHADOW_WIND_CHOICE_STEP_ID := "bombirdier_shadow_wind_choice"
const RETURN_REPLACEMENT_STEP_ID := "return_self_replacement"


class RiggedCoinFlipper:
	extends CoinFlipper

	var results: Array[bool] = []

	func _init(sequence: Array[bool]) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var result: bool = results.pop_front() if not results.is_empty() else true
		coin_flipped.emit(result)
		return result


func test_batch_cards_are_bundled_with_images_and_source_metadata() -> String:
	CardImplementationStatus.clear_cache()
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var pooled_uids: Dictionary = {}
	for pooled: CardData in db.get_all_cards():
		if pooled != null:
			pooled_uids[pooled.get_uid()] = true
	var specs := [
		{"set": "CSV8C", "index": "050", "name": "角金鱼", "name_en": "Goldeen", "effect_id": GOLDEEN_EFFECT_ID},
		{"set": "CSV9.5C", "index": "034", "name": "金鱼王", "name_en": "Seaking", "effect_id": SEAKING_EFFECT_ID},
		{"set": "CSV9.5C", "index": "205", "name": "中立中心", "name_en": "Neutralization Zone", "effect_id": NEUTRALIZATION_ZONE_EFFECT_ID},
		{"set": "CSV9.5C", "index": "036", "name": "水伊布ex", "name_en": "Vaporeon ex", "effect_id": VAPOREON_EX_EFFECT_ID},
		{"set": "CSV6C", "index": "112", "name": "下石鸟ex", "name_en": "Bombirdier ex", "effect_id": BOMBIRDIER_EX_EFFECT_ID},
	]
	var checks: Array[String] = []
	for spec: Dictionary in specs:
		var set_code := str(spec.get("set", ""))
		var card_index := str(spec.get("index", ""))
		var card_id := "%s_%s" % [set_code, card_index]
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(card_path in manifest, "%s JSON should be listed in the bundled manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in the bundled manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled JSON should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be a valid PNG" % card_id))
		checks.append(assert_not_null(card, "%s should load through CardDatabase" % card_id))
		checks.append(assert_true(db.has_card(set_code, card_index), "%s should be recognized by CardDatabase.has_card" % card_id))
		checks.append(assert_true(pooled_uids.has(card_id), "%s should appear in the full DeckEditor card pool" % card_id))
		if card != null:
			checks.append(assert_eq(card.name, str(spec.get("name", "")), "%s should preserve the source Chinese name" % card_id))
			checks.append(assert_eq(card.name_en, str(spec.get("name_en", "")), "%s should preserve the source English name" % card_id))
			checks.append(assert_eq(card.effect_id, str(spec.get("effect_id", "")), "%s should preserve the source effect_id" % card_id))
			checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "%s should not display the unimplemented badge" % card_id))
	db.free()
	return run_checks(checks)


func test_goldeen_and_seaking_festival_lead_chain_resolves_both_attacks() -> String:
	var goldeen := _load_card("CSV8C", "050")
	var seaking := _load_card("CSV9.5C", "034")
	var checks: Array[String] = [
		assert_not_null(goldeen, "CSV8C_050 Goldeen should load"),
		assert_not_null(seaking, "CSV9.5C_034 Seaking should load"),
	]
	if goldeen == null or seaking == null:
		return run_checks(checks)
	checks.append(assert_true(seaking.evolves_from_matches(goldeen), "Seaking should evolve from the Chinese Goldeen name"))

	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var attacker := _slot(seaking, 0)
	player.active_pokemon = attacker
	opponent.active_pokemon = _slot(_pokemon("Festival Defender", 300), 1)
	_attach_energy(attacker, 0, "C")
	for index: int in 5:
		player.deck.append(CardInstance.create(_trainer("Draw %d" % index, "Item"), 0))
	gsm.game_state.stadium_card = CardInstance.create(_stadium("祭典会场", "357d55b54ded5db071b55ebe165749fc"), 0)
	gsm.game_state.stadium_owner_index = 0
	gsm.effect_processor.register_pokemon_card(seaking)
	checks.append(assert_true(gsm.effect_processor.get_effect(SEAKING_EFFECT_ID) is AbilityFestivalLead, "Seaking should register the shared Festival Lead ability"))
	checks.append(assert_true(AbilityFestivalLead.has_festival_lead(attacker), "Seaking should be recognized as a Festival Lead Pokemon"))
	checks.append(assert_true(AbilityFestivalLead.can_take_second_attack(attacker, gsm.game_state), "Seaking should be eligible for a second attack under Festival Grounds"))

	var first_used := gsm.use_attack(0, 0)
	var returned_to_main := gsm.game_state.current_player_index == 0 and gsm.game_state.phase == GameState.GamePhase.MAIN
	var second_used := gsm.use_attack(0, 0)
	checks.append_array([
		assert_true(first_used, "Seaking should use Rapid Draw the first time"),
		assert_true(returned_to_main, "Festival Lead should return to MAIN for the second attack"),
		assert_true(second_used, "Seaking should use Rapid Draw a second time"),
		assert_eq(player.hand.size(), 4, "Two Rapid Draw attacks should draw four cards total"),
		assert_eq(opponent.active_pokemon.damage_counters, 120, "Two Rapid Draw attacks should deal 120 total damage"),
	])
	return run_checks(checks)


func test_festival_lead_continues_after_knockout_and_opponent_replacement() -> String:
	var seaking := _load_card("CSV9.5C", "034")
	if seaking == null:
		return assert_not_null(seaking, "CSV9.5C_034 Seaking should load")
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var attacker := _slot(seaking, 0)
	var first_defender := _slot(_pokemon("First Defender", 60), 1)
	var replacement := _slot(_pokemon("Replacement Defender", 300), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = first_defender
	opponent.bench.append(replacement)
	_attach_energy(attacker, 0, "C")
	for index: int in 6:
		player.deck.append(CardInstance.create(_trainer("Draw %d" % index, "Item"), 0))
	gsm.game_state.stadium_card = CardInstance.create(_stadium("祭典会场", "357d55b54ded5db071b55ebe165749fc"), 0)
	gsm.game_state.stadium_owner_index = 0
	gsm.effect_processor.register_pokemon_card(seaking)

	var first_used := gsm.use_attack(0, 0)
	var awaiting_prize := int(gsm.get("_pending_prize_remaining")) == 1
	var prize_taken := gsm.resolve_take_prize(0, 0)
	var awaiting_replacement := gsm.game_state.phase == GameState.GamePhase.KNOCKOUT_REPLACE
	var sent_out := gsm.send_out_pokemon(1, replacement)
	var resumed_for_second_attack := (
		gsm.game_state.current_player_index == 0
		and gsm.game_state.phase == GameState.GamePhase.MAIN
	)
	var second_used := gsm.use_attack(0, 0)
	return run_checks([
		assert_true(first_used, "Festival Lead's first attack should resolve"),
		assert_true(awaiting_prize, "The knockout should pause for prize selection before replacement"),
		assert_true(prize_taken, "The attacker should be able to take the knockout prize"),
		assert_true(awaiting_replacement, "A knockout should pause for the opponent's replacement"),
		assert_true(sent_out, "The opponent should be able to send out a replacement"),
		assert_true(resumed_for_second_attack, "Festival Lead should resume the attacker's MAIN phase after replacement"),
		assert_true(second_used, "Festival Lead should allow the second attack against the replacement"),
		assert_eq(replacement.damage_counters, 60, "The replacement should receive the second Rapid Draw attack"),
	])


func test_neutralization_zone_prevents_ex_and_v_damage_to_non_rule_box_pokemon() -> String:
	var zone := _load_card("CSV9.5C", "205")
	if zone == null:
		return assert_not_null(zone, "CSV9.5C_205 Neutralization Zone should load")
	var gsm := _make_gsm()
	var attacker := _slot(_pokemon("Attacking ex", 220, "ex"), 0)
	var v_attacker := _slot(_pokemon("Attacking V", 220, "V"), 0)
	var non_rule_defender := _slot(_pokemon("Plain Defender", 220), 1)
	var rule_box_defender := _slot(_pokemon("Rule Box Defender ex", 220, "ex"), 1)
	attacker.get_card_data().attacks = [_attack("Rule Box Strike", "", "100", "")]
	v_attacker.get_card_data().attacks = [_attack("V Strike", "", "100", "")]
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = non_rule_defender
	gsm.game_state.stadium_card = CardInstance.create(zone, 0)
	gsm.game_state.stadium_owner_index = 0

	var protected_damage := gsm._calculate_attack_damage(attacker, non_rule_defender, attacker.get_card_data().attacks[0], 0)
	var protected_v_damage := gsm._calculate_attack_damage(v_attacker, non_rule_defender, v_attacker.get_card_data().attacks[0], 0)
	var rule_box_damage := gsm._calculate_attack_damage(attacker, rule_box_defender, attacker.get_card_data().attacks[0], 0)
	attacker.get_card_data().mechanic = ""
	var ordinary_damage := gsm._calculate_attack_damage(attacker, non_rule_defender, attacker.get_card_data().attacks[0], 0)
	return run_checks([
		assert_not_null(gsm.effect_processor.get_effect(NEUTRALIZATION_ZONE_EFFECT_ID), "Neutralization Zone should register as a Stadium effect"),
		assert_eq(
			BattleStadiumBackdropCoordinatorScript.new().resolve_stadium_backdrop_path(
				CardInstance.create(zone, 0),
				"res://assets/ui/background.png"
			),
			"res://assets/ui/stadium_backgrounds/area_zero_underdepths.webp",
			"Neutralization Zone should resolve a dynamic Stadium background"
		),
		assert_eq(protected_damage, 0, "Opponent Pokemon ex attacks should not damage non-rule-box Pokemon"),
		assert_eq(protected_v_damage, 0, "Opponent Pokemon V attacks should not damage non-rule-box Pokemon"),
		assert_eq(rule_box_damage, 100, "Pokemon ex attacks should still damage rule-box Pokemon"),
		assert_eq(ordinary_damage, 100, "Non-ex/V attackers should not be blocked"),
	])


func test_neutralization_zone_cannot_leave_discard_for_hand_or_deck() -> String:
	var zone := _load_card("CSV9.5C", "205")
	if zone == null:
		return assert_not_null(zone, "CSV9.5C_205 Neutralization Zone should load before discard restriction tests")
	var state := _make_state()
	var player := state.players[0]
	var zone_card := CardInstance.create(zone, 0)
	player.discard_pile.append(zone_card)
	var processor := EffectProcessor.new()
	state.shared_turn_flags["_draw_effect_processor"] = processor

	var cyllene := EffectCyllene.new(RiggedCoinFlipper.new([true, true]))
	var roseanne := EffectRoseannesBackup.new()
	var recover := AttackRecoverTrainerFromDiscard.new(1, 0)
	var recoverer := _slot(_pokemon("Recoverer", 120), 0)
	player.active_pokemon = recoverer
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", 120), 1)

	var cyllene_steps := cyllene.get_interaction_steps(zone_card, state)
	var roseanne_steps := roseanne.get_interaction_steps(zone_card, state)
	var recover_steps := recover.get_attack_interaction_steps(recoverer.get_top_card(), recoverer.get_card_data().attacks[0], state)
	return run_checks([
		assert_true(cyllene_steps.is_empty(), "Cyllene should not offer Neutralization Zone from the discard pile"),
		assert_true(roseanne_steps.is_empty(), "Roseanne's Backup should not offer Neutralization Zone from the discard pile"),
		assert_true(recover_steps.is_empty(), "Pokemon attacks should not offer Neutralization Zone for recovery to hand"),
		assert_true(zone_card in player.discard_pile, "Neutralization Zone should remain in the discard pile"),
	])


func test_neutralization_zone_is_not_offered_after_previewed_deck_mill() -> String:
	var zone := _load_card("CSV9.5C", "205")
	if zone == null:
		return assert_not_null(zone, "CSV9.5C_205 Neutralization Zone should load before mill preview tests")
	var state := _make_state()
	var player := state.players[0]
	var source := CardInstance.create(_pokemon("Mill Recoverer", 200), 0)
	var source_slot := _slot(source.card_data, 0)
	player.active_pokemon = source_slot
	var zone_card := CardInstance.create(zone, 0)
	var ordinary := CardInstance.create(_trainer("Ordinary Card", "Item"), 0)
	player.deck.append_array([zone_card, ordinary])
	var effect := AbilityMillDeckRecoverToHand.new(2, 2, true)
	var steps := effect.get_interaction_steps(source_slot.get_top_card(), state)
	var items: Array = steps[0].get("items", []) if not steps.is_empty() else []

	effect.execute_ability(source_slot, 0, [{"recover_cards": [zone_card, ordinary]}], state)
	return run_checks([
		assert_false(zone_card in items, "Neutralization Zone should not be offered as recoverable after the previewed mill"),
		assert_true(ordinary in items, "Other previewed cards should remain selectable"),
		assert_true(zone_card in player.discard_pile, "Neutralization Zone should remain in the discard pile after milling"),
		assert_true(ordinary in player.hand, "A legal milled card should still be recoverable"),
	])


func test_vaporeon_ex_damages_every_opposing_ex_and_aquamarine_locks_all_attacks() -> String:
	var vaporeon := _load_card("CSV9.5C", "036")
	if vaporeon == null:
		return assert_not_null(vaporeon, "CSV9.5C_036 Vaporeon ex should load")
	var spread_gsm := _make_gsm()
	var attacker := _slot(vaporeon, 0)
	var active_ex := _slot(_pokemon("Active ex", 220, "ex"), 1)
	var bench_ex := _slot(_pokemon("Bench ex", 220, "ex"), 1)
	var bench_plain := _slot(_pokemon("Bench Plain", 220), 1)
	active_ex.get_card_data().weakness_energy = "W"
	active_ex.get_card_data().weakness_value = "×2"
	bench_ex.get_card_data().resistance_energy = "W"
	bench_ex.get_card_data().resistance_value = "-30"
	spread_gsm.game_state.players[0].active_pokemon = attacker
	spread_gsm.game_state.players[1].active_pokemon = active_ex
	spread_gsm.game_state.players[1].bench.append_array([bench_ex, bench_plain])
	_attach_energy(attacker, 0, "W")
	_attach_energy(attacker, 0, "C")
	spread_gsm.effect_processor.register_pokemon_card(vaporeon)
	var spread_used := spread_gsm.use_attack(0, 0)

	var lock_gsm := _make_gsm()
	var lock_attacker := _slot(vaporeon, 0)
	var lock_defender := _slot(_pokemon("Lock Defender", 400), 1)
	lock_gsm.game_state.players[0].active_pokemon = lock_attacker
	lock_gsm.game_state.players[1].active_pokemon = lock_defender
	_attach_energy(lock_attacker, 0, "R")
	_attach_energy(lock_attacker, 0, "W")
	_attach_energy(lock_attacker, 0, "L")
	lock_gsm.effect_processor.register_pokemon_card(vaporeon)
	var attack_turn := lock_gsm.game_state.turn_number
	var aquamarine_used := lock_gsm.use_attack(0, 1)
	lock_gsm.game_state.current_player_index = 0
	lock_gsm.game_state.turn_number = attack_turn + 2
	lock_gsm.game_state.phase = GameState.GamePhase.MAIN
	return run_checks([
		assert_true(spread_used, "Heavy Squall should be usable with Water and Colorless Energy"),
		assert_eq(active_ex.damage_counters, 60, "Heavy Squall should deal 60 to the opposing Active Pokemon ex"),
		assert_eq(bench_ex.damage_counters, 60, "Heavy Squall should deal 60 to each opposing Benched Pokemon ex"),
		assert_eq(bench_plain.damage_counters, 0, "Heavy Squall should not damage non-ex/V Pokemon"),
		assert_true(aquamarine_used, "Aquamarine should be usable with Fire, Water, and Lightning Energy"),
		assert_eq(lock_defender.damage_counters, 280, "Aquamarine should deal 280 damage"),
		assert_false(lock_gsm.can_use_attack(0, 0), "Aquamarine should lock Vaporeon ex's first attack next turn"),
		assert_false(lock_gsm.can_use_attack(0, 1), "Aquamarine should lock Vaporeon ex's second attack next turn"),
	])


func test_bombirdier_fast_carrier_first_turn_search_and_optional_shadow_wind_return() -> String:
	var bombirdier := _load_card("CSV6C", "112")
	if bombirdier == null:
		return assert_not_null(bombirdier, "CSV6C_112 Bombirdier ex should load")
	var search_gsm := _make_gsm()
	search_gsm.game_state.turn_number = 1
	search_gsm.game_state.first_player_index = 0
	var player := search_gsm.game_state.players[0]
	var attacker := _slot(bombirdier, 0)
	player.active_pokemon = attacker
	search_gsm.game_state.players[1].active_pokemon = _slot(_pokemon("Opponent", 300), 1)
	_attach_energy(attacker, 0, "C")
	var basics: Array[CardInstance] = []
	for index: int in 4:
		var basic := CardInstance.create(_pokemon("Basic %d" % index, 70), 0)
		basics.append(basic)
		player.deck.append(basic)
	var evolution := CardInstance.create(_pokemon("Evolution", 120, "", "Stage 1", "Basic 0"), 0)
	player.deck.append(evolution)
	search_gsm.effect_processor.register_pokemon_card(bombirdier)
	var search_effects := search_gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var search_steps: Array[Dictionary] = []
	for effect: BaseEffect in search_effects:
		search_steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), bombirdier.attacks[0], search_gsm.game_state))
	var search_step: Dictionary = search_steps[0] if not search_steps.is_empty() else {}
	var visible_cards: Array = search_step.get("card_items", [])
	var selectable_cards: Array = search_step.get("items", [])
	var first_turn_allowed := search_gsm.can_use_attack(0, 0)
	var search_used := search_gsm.use_attack(0, 0, [{FAST_CARRIER_STEP_ID: basics.slice(0, 3)}])

	var return_gsm := _make_gsm()
	var return_player := return_gsm.game_state.players[0]
	var return_attacker := _slot(bombirdier, 0)
	var replacement := _slot(_pokemon("Replacement", 100), 0)
	return_player.active_pokemon = return_attacker
	return_player.bench.append(replacement)
	return_gsm.game_state.players[1].active_pokemon = _slot(_pokemon("Return Defender", 400), 1)
	_attach_energy(return_attacker, 0, "C", 3)
	return_gsm.effect_processor.register_pokemon_card(bombirdier)
	var shadow_used := return_gsm.use_attack(0, 1, [{
		SHADOW_WIND_CHOICE_STEP_ID: ["return"],
		RETURN_REPLACEMENT_STEP_ID: [replacement],
	}])

	var keep_gsm := _make_gsm()
	var keep_player := keep_gsm.game_state.players[0]
	var keep_attacker := _slot(bombirdier, 0)
	keep_player.active_pokemon = keep_attacker
	keep_player.bench.append(_slot(_pokemon("Keep Replacement", 100), 0))
	keep_gsm.game_state.players[1].active_pokemon = _slot(_pokemon("Keep Defender", 400), 1)
	_attach_energy(keep_attacker, 0, "C", 3)
	keep_gsm.effect_processor.register_pokemon_card(bombirdier)
	var keep_used := keep_gsm.use_attack(0, 1, [{SHADOW_WIND_CHOICE_STEP_ID: ["keep"]}])
	return run_checks([
		assert_true(first_turn_allowed, "Fast Carrier should be legal during the first player's first turn"),
		assert_eq(int(search_step.get("min_select", -1)), 0, "Fast Carrier should allow taking no Basic Pokemon"),
		assert_eq(int(search_step.get("max_select", -1)), 3, "Fast Carrier should offer up to three Basic Pokemon"),
		assert_eq(str(search_step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Fast Carrier should expose the complete own-library search HUD"),
		assert_eq(visible_cards.size(), 5, "Fast Carrier should visibly show every card in the deck"),
		assert_eq(selectable_cards.size(), 4, "Fast Carrier should make only Basic Pokemon selectable"),
		assert_true(evolution in visible_cards, "The Evolution card should remain visible in the full-library search"),
		assert_false(evolution in selectable_cards, "The Evolution card should be visibly disabled rather than selectable"),
		assert_true(search_used, "Fast Carrier should resolve on the first turn"),
		assert_eq(player.bench.size(), 3, "Fast Carrier should put the selected three Basic Pokemon onto the Bench"),
		assert_eq(player.shuffle_count, 1, "Fast Carrier should shuffle the deck after searching"),
		assert_true(shadow_used, "Shadow Wind should resolve with three Colorless Energy"),
		assert_eq(return_gsm.game_state.players[1].active_pokemon.damage_counters, 130, "Shadow Wind should deal 130 damage"),
		assert_eq(return_player.active_pokemon, replacement, "Returning Bombirdier should promote the selected replacement"),
		assert_eq(return_player.hand.size(), 4, "Bombirdier and its three attached Energy should return to hand"),
		assert_true(keep_used, "Shadow Wind should also resolve when the player declines the optional return"),
		assert_eq(keep_player.active_pokemon, keep_attacker, "Declining Shadow Wind's return should leave Bombirdier Active"),
		assert_eq(keep_attacker.attached_energy.size(), 3, "Declining the return should keep attached Energy in play"),
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
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		for prize_index: int in 6:
			player.prizes.append(CardInstance.create(_trainer("Prize %d-%d" % [player_index, prize_index], "Item"), player_index))
		state.players.append(player)
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card_data != null:
		slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(
	name: String,
	hp: int = 100,
	mechanic: String = "",
	stage: String = "Basic",
	evolves_from: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.hp = hp
	card.energy_type = "C"
	card.mechanic = mechanic
	card.stage = stage
	card.evolves_from = evolves_from
	card.attacks = [_attack("Tackle", "C", "10", "")]
	return card


func _trainer(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return card


func _stadium(name: String, effect_id: String) -> CardData:
	var card := _trainer(name, "Stadium")
	card.effect_id = effect_id
	return card


func _basic_energy(energy_type: String, index: int) -> CardData:
	var card := CardData.new()
	card.name = "%s Energy %d" % [energy_type, index]
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int = 1) -> void:
	for index: int in count:
		slot.attached_energy.append(CardInstance.create(_basic_energy(energy_type, index), owner_index))


func _attack(name: String, cost: String, damage: String, text: String) -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}
