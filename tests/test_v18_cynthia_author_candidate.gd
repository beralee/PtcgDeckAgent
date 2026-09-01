class_name TestV18CynthiaAuthorCandidate
extends TestBase


const CANDIDATE_PATH := "res://scripts/ai/DeckStrategyV18CynthiaAuthorV1.gd"
const DECK_PATH := "res://data/bundled_user/decks/800018543.json"


func test_budew_must_play_live_poffin_before_a_non_ko_chip_attack() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var budew := _slot(_load_card("CSV9.5C_004"))
	player.active_pokemon = budew
	var poffin := _instance(_load_card("CSV7C_177"))
	player.hand.append(poffin)
	player.deck.assign([
		_instance(_load_card("CSV10C_111")),
		_instance(_load_card("CSV10C_004")),
	])
	_fill_deck(player, 12)

	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var poffin_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": poffin,
	}, state, 0, plan)
	var chip_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": budew,
		"attack_index": 0,
		"projected_damage": 10,
		"projected_knockout": false,
	}, state, 0, plan)
	var debt: Dictionary = contract.get("setup_debt", {})
	return run_checks([
		assert_true(bool(contract.get("safe_setup_before_attack", false)), "A live Budew/Poffin core route should create safe setup debt"),
		assert_eq(int(debt.get("needs_budew_poffin_before_chip", 0)), 1, "The candidate should expose one self-clearing Budew/Poffin debt"),
		assert_true(poffin_score >= chip_score + 1200.0, "Poffin must decisively outrank Budew's non-KO chip attack"),
	])


func test_budew_uses_arven_to_fetch_poffin_before_chip_attack() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var budew := _slot(_load_card("CSV9.5C_004"))
	player.active_pokemon = budew
	var arven := _instance(_trainer("Arven", "Supporter"))
	player.hand.append(arven)
	player.deck.assign([
		_instance(_load_card("CSV7C_177")),
		_instance(_load_card("CSV10C_111")),
	])
	_fill_deck(player, 12)

	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var arven_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": arven,
	}, state, 0, plan)
	var chip_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": budew,
		"attack_index": 0,
		"projected_damage": 10,
		"projected_knockout": false,
	}, state, 0, plan)
	var debt: Dictionary = contract.get("setup_debt", {})
	return run_checks([
		assert_eq(int(debt.get("needs_arven_poffin_before_chip", 0)), 1, "Arven should expose the missing Poffin bridge as setup debt"),
		assert_true(arven_score >= chip_score + 1200.0, "Arven fetching Poffin must outrank Budew's non-KO chip attack"),
	])


func test_poffin_builds_distinct_roots_for_a_live_tm_evolution_turn() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var budew := _slot(_load_card("CSV9.5C_004"))
	budew.attached_energy.append(_instance(_load_card("CSVE1C_FIG")))
	player.active_pokemon = budew
	player.hand.append(_instance(_load_card("CSV5C_119")))
	player.deck.assign([
		_instance(_load_card("CSV10C_112")),
		_instance(_load_card("CSV10C_005")),
	])
	var gible_a := _instance(_load_card("CSV10C_111"))
	var gible_b := _instance(_load_card("CSV10C_111"))
	var roselia := _instance(_load_card("CSV10C_004"))
	var spare_budew := _instance(_load_card("CSV9.5C_004"))

	var picked: Array = strategy.call("pick_interaction_items", [
		gible_a,
		gible_b,
		roselia,
		spare_budew,
	], {
		"id": "buddy_poffin_pokemon",
		"max_select": 2,
	}, {
		"game_state": state,
		"player_index": 0,
	})
	return run_checks([
		assert_eq(picked.size(), 2, "The live TM Evolution route should claim both Poffin selections"),
		assert_true(gible_a in picked or gible_b in picked, "Poffin should establish one Cynthia's Gible root"),
		assert_true(roselia in picked, "Poffin should establish the distinct Cynthia's Roselia root for the second TM evolution"),
	])


func test_retreat_hands_conversion_to_ready_bench_garchomp() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_load_card("CSV9.5C_004"))
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.append(_instance(_load_card("CSVE1C_FIG")))
	var roselia := _slot(_load_card("CSV10C_004"))
	player.bench.assign([garchomp, roselia])
	_fill_deck(player, 20)
	state.players[1].active_pokemon = _slot(_pokemon("Neutral 220 HP target", 220))
	var one_energy_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": garchomp,
	}, state, 0)
	garchomp.attached_energy.append(_instance(_load_card("CSVE1C_FIG")))
	var ko_ready_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": garchomp,
	}, state, 0)
	var support_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": roselia,
	}, state, 0)
	player.active_pokemon = roselia
	player.bench.assign([garchomp])
	roselia.attached_tool = _instance(_load_card("CSV10C_200"))
	roselia.attached_energy.append(_instance(_load_card("CSVE1C_DAR")))
	var protected_pivot_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": garchomp,
	}, state, 0)
	var roserade := _slot(_load_card("CSV10C_005"))
	roserade.attached_tool = _instance(_load_card("CSV10C_200"))
	roserade.attached_energy.append(_instance(_load_card("CSVE1C_DAR")))
	player.active_pokemon = roserade
	var evolved_support_handoff_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": garchomp,
	}, state, 0)
	var spiritomb := _slot(_load_card("CSV10C_138"))
	spiritomb.attached_energy.append(_instance(_load_card("CSVE1C_FIG")))
	var roserade_a := _slot(_load_card("CSV10C_005"))
	var roserade_b := _slot(_load_card("CSV10C_005"))
	player.active_pokemon = spiritomb
	player.bench.assign([garchomp, roserade_a, roserade_b])
	var live_spiritomb_score: float = strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": garchomp,
	}, state, 0)
	return run_checks([
		assert_true(ko_ready_score >= one_energy_score + 1000.0, "A one-Energy non-KO Garchomp must not receive the same forced handoff score as a converting two-Energy Garchomp"),
		assert_true(ko_ready_score >= support_score + 3500.0, "A Garchomp that converts an immediate KO must own retreat conversion over a support Pokemon"),
		assert_true(ko_ready_score >= protected_pivot_score + 1000.0, "A full-health Cynthia pivot protected by Power Weight should absorb pressure before exposing Garchomp"),
		assert_true(evolved_support_handoff_score >= protected_pivot_score + 1000.0, "An evolved Roserade must hand off to a converting Garchomp instead of staying active as a low-damage pivot"),
		assert_true(ko_ready_score >= live_spiritomb_score + 1000.0, "A live Spiritomb with at least 50 bonus damage should keep the single-Prize pivot before exposing Garchomp"),
	])


func test_roserade_evolves_before_non_final_garchomp_blast() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.assign([
		_instance(_load_card("CSVE1C_FIG")),
		_instance(_load_card("CSVE1C_FIG")),
	])
	player.active_pokemon = garchomp
	var roselia := _slot(_load_card("CSV10C_004"))
	roselia.turn_played = 1
	player.bench.append(roselia)
	var roserade := _instance(_load_card("CSV10C_005"))
	player.hand.append(roserade)
	_fill_deck(player, 20)
	state.players[1].active_pokemon = _slot(_pokemon("Fighting-weak target", 220))

	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var evolve_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "evolve",
		"card": roserade,
		"target_slot": roselia,
	}, state, 0, plan)
	var blast_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 1,
		"attack_name": "Dragon Blast",
		"projected_damage": 520,
		"projected_knockout": true,
	}, state, 0, plan)
	var debt: Dictionary = contract.get("setup_debt", {})
	return run_checks([
		assert_eq(int(debt.get("needs_roserade_evolution_before_attack", 0)), 1, "A legal Roserade evolution should remain explicit setup debt"),
		assert_true(evolve_score >= blast_score + 800.0, "Roserade should evolve before a non-final Dragon Blast so Spiral Dive can preserve Energy"),
	])


func test_power_weight_is_attached_before_a_non_final_garchomp_attack() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.assign([
		_instance(_load_card("CSVE1C_FIG")),
		_instance(_load_card("CSVE1C_FIG")),
	])
	player.active_pokemon = garchomp
	var power_weight := _instance(_load_card("CSV10C_200"))
	player.hand.append(power_weight)
	for index: int in 3:
		player.prizes.append(_instance(_trainer("Prize %d" % index, "Item")))
	_fill_deck(player, 20)
	state.players[1].active_pokemon = _slot(_pokemon("Non-final target", 120))

	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var weight_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool",
		"card": power_weight,
		"target_slot": garchomp,
	}, state, 0, plan)
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 0,
		"attack_name": "Spiral Dive",
		"projected_damage": 200,
		"projected_knockout": true,
	}, state, 0, plan)
	var debt: Dictionary = contract.get("setup_debt", {})

	player.hand.erase(power_weight)
	garchomp.attached_tool = power_weight
	var cleared: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var cleared_debt: Dictionary = cleared.get("setup_debt", {})
	return run_checks([
		assert_eq(int(debt.get("needs_power_weight_before_attack", 0)), 1, "An unprotected active Garchomp should expose one Power Weight setup debt"),
		assert_true(weight_score >= attack_score + 800.0, "Power Weight must resolve before a non-final Garchomp attack"),
		assert_eq(int(cleared_debt.get("needs_power_weight_before_attack", 0)), 0, "Attaching Power Weight must self-clear its setup debt"),
	])


func test_garchomp_builds_a_poffin_backup_before_a_non_final_attack() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.assign([
		_instance(_load_card("CSVE1C_FIG")),
		_instance(_load_card("CSVE1C_FIG")),
	])
	garchomp.attached_tool = _instance(_load_card("CSV10C_200"))
	player.active_pokemon = garchomp
	for index: int in 3:
		player.prizes.append(_instance(_trainer("Prize %d" % index, "Item")))
	var poffin := _instance(_load_card("CSV7C_177"))
	var arven := _instance(_trainer("Arven", "Supporter"))
	player.hand.append(arven)
	player.deck.assign([
		poffin,
		_instance(_load_card("CSV10C_111")),
		_instance(_load_card("CSV10C_004")),
	])
	_fill_deck(player, 20)
	state.players[1].active_pokemon = _slot(_pokemon("Non-final target", 220))
	var attack_action := {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 1,
		"attack_name": "Dragon Blast",
		"projected_damage": 520,
		"projected_knockout": true,
	}

	var arven_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var arven_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var arven_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": arven,
	}, state, 0, arven_plan)
	var attack_before_arven: float = strategy.call("score_action_absolute_with_plan", attack_action, state, 0, arven_plan)
	var arven_debt: Dictionary = arven_contract.get("setup_debt", {})

	player.hand.erase(arven)
	player.deck.erase(poffin)
	player.hand.append(poffin)
	var poffin_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var poffin_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var poffin_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": poffin,
	}, state, 0, poffin_plan)
	var attack_before_poffin: float = strategy.call("score_action_absolute_with_plan", attack_action, state, 0, poffin_plan)
	var poffin_debt: Dictionary = poffin_contract.get("setup_debt", {})

	player.hand.erase(poffin)
	player.hand.append(arven)
	player.deck.append(poffin)
	var roserade := _slot(_load_card("CSV10C_005"))
	roserade.attached_tool = _instance(_load_card("CSV10C_200"))
	roserade.attached_energy.append(_instance(_load_card("CSVE1C_DAR")))
	player.active_pokemon = roserade
	player.bench.assign([garchomp])
	var pre_handoff_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var pre_handoff_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var pre_handoff_arven: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": arven,
	}, state, 0, pre_handoff_plan)
	var immediate_handoff: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": garchomp,
	}, state, 0, pre_handoff_plan)
	var pre_handoff_debt: Dictionary = pre_handoff_contract.get("setup_debt", {})
	return run_checks([
		assert_eq(int(arven_debt.get("needs_arven_poffin_backup_before_attack", 0)), 1, "Arven should expose a live Poffin backup bridge before Garchomp attacks"),
		assert_true(arven_score >= attack_before_arven + 800.0, "Arven fetching Poffin must outrank a non-final Garchomp attack when no backup line exists"),
		assert_eq(int(poffin_debt.get("needs_poffin_backup_before_attack", 0)), 1, "A Poffin already in hand should own the backup setup debt"),
		assert_true(poffin_score >= attack_before_poffin + 800.0, "Poffin must establish a backup line before a non-final Garchomp attack"),
		assert_eq(int(pre_handoff_debt.get("needs_arven_poffin_backup_before_attack", 0)), 1, "The backup bridge must remain visible while the ready Garchomp is still Benched"),
		assert_true(pre_handoff_arven >= immediate_handoff + 300.0, "Arven and Poffin setup should resolve before handing off from Roserade to the ready Garchomp"),
	])


func test_garchomp_uses_minimum_lethal_and_keeps_blast_for_the_260_window() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.assign([
		_instance(_load_card("CSVE1C_FIG")),
		_instance(_load_card("CSVE1C_FIG")),
	])
	player.active_pokemon = garchomp
	player.bench.append(_slot(_load_card("CSV10C_005")))
	_fill_deck(player, 20)
	player.hand.assign([_instance(_trainer("手牌", "Item"))])
	var defender := _slot(_pokemon("Test Defender", 120))
	state.players[1].active_pokemon = defender

	var spiral_action := {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 0,
		"attack_name": "Spiral Dive",
		"projected_damage": 130,
		"projected_knockout": true,
	}
	var blast_action := {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 1,
		"attack_name": "Dragon Blast",
		"projected_damage": 290,
		"projected_knockout": true,
	}
	var same_ko_spiral: float = strategy.call("score_action_absolute", spiral_action, state, 0)
	var same_ko_blast: float = strategy.call("score_action_absolute", blast_action, state, 0)

	defender.damage_counters = 0
	defender.pokemon_stack[0].card_data.hp = 220
	spiral_action["projected_knockout"] = false
	blast_action["projected_knockout"] = true
	var pressure_spiral: float = strategy.call("score_action_absolute", spiral_action, state, 0)
	var pressure_blast: float = strategy.call("score_action_absolute", blast_action, state, 0)
	return run_checks([
		assert_true(same_ko_spiral >= same_ko_blast + 500.0, "Spiral Dive should preserve both Fighting Energy when both attacks take the same KO"),
		assert_true(pressure_blast >= pressure_spiral + 900.0, "Dragon Blast should remain the owner of the 131-290 damage conversion window"),
	])


func test_garchomp_minimum_lethal_uses_projected_weakness_damage() -> String:
	var strategy := _candidate()
	if strategy == null:
		return assert_true(false, "Cynthia author candidate should load")
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.assign([
		_instance(_load_card("CSVE1C_FIG")),
		_instance(_load_card("CSVE1C_FIG")),
	])
	player.active_pokemon = garchomp
	_fill_deck(player, 20)
	player.hand.assign([_instance(_trainer("Weakness fixture", "Item"))])
	state.players[1].active_pokemon = _slot(_pokemon("Fighting-weak Defender", 180))

	var spiral_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 0,
		"attack_name": "Spiral Dive",
		"projected_damage": 200,
		"projected_knockout": true,
	}, state, 0)
	var blast_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": garchomp,
		"attack_index": 1,
		"attack_name": "Dragon Blast",
		"projected_damage": 520,
		"projected_knockout": true,
	}, state, 0)
	return assert_true(
		spiral_score >= blast_score + 500.0,
		"A weakness-assisted Spiral Dive KO should preserve both Fighting Energy",
	)


func _candidate() -> RefCounted:
	var script: Variant = load(CANDIDATE_PATH)
	if not script is GDScript:
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var strategy: RefCounted = (script as GDScript).new()
	strategy.call("configure_from_deck", DeckData.from_dict(parsed))
	return strategy


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_instance(card_data))
	return slot


func _instance(card_data: CardData) -> CardInstance:
	return CardInstance.create(card_data, 0)


func _trainer(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	return card


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _fill_deck(player: PlayerState, count: int) -> void:
	for index: int in count:
		player.deck.append(_instance(_trainer("Deck filler %d" % index, "Item")))
