class_name TestV18CynthiaPoffinBeforeChipRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018543.json"
const POFFIN_BONUS := 280.0


func test_gible_and_roserade_enable_exact_poffin_before_chip_debt() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var gible_state := _poffin_state("CSV10C_111", "CSV10C_004")
	var roserade_state := _poffin_state("CSV10C_005", "CSV10C_111")
	var gible_contract := _delegate_contract(strategy, gible_state)
	var roserade_contract := _delegate_contract(strategy, roserade_state)
	var poffin_rule := _poffin_rule(gible_contract)
	var poffin: CardInstance = gible_state.players[0].hand[0]
	var active: PokemonSlot = gible_state.players[0].active_pokemon
	var plan: Dictionary = strategy.call("build_turn_plan", gible_state, 0)
	var poffin_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer",
		"card": poffin,
	}, gible_state, 0, plan)
	var chip_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"projected_knockout": false,
	}, gible_state, 0, plan)
	return run_checks([
		assert_true(bool(gible_contract.get("safe_setup_before_attack", false)), "Active Gible should defer a non-KO chip attack for a live Poffin target"),
		assert_eq(int((gible_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", 0)), 1, "Gible's live Poffin route should expose one self-clearing debt"),
		assert_true(bool(roserade_contract.get("safe_setup_before_attack", false)), "Active Roserade should also defer a non-KO chip attack for a live Poffin target"),
		assert_eq(int((roserade_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", 0)), 1, "Roserade's live Poffin route should expose one self-clearing debt"),
		assert_eq(float(poffin_rule.get("bonus", -1.0)), POFFIN_BONUS, "Poffin should receive the exact small Round 4 continuity bonus"),
		assert_true(poffin_score > chip_score, "Live Poffin must outrank a non-KO shallow attack (poffin=%f chip=%f)" % [poffin_score, chip_score]),
	])


func test_poffin_debt_clears_without_a_target_and_after_resolution() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var state := _poffin_state("CSV10C_111", "CSV10C_004")
	var player: PlayerState = state.players[0]
	var active: PokemonSlot = player.active_pokemon
	var debt_plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var debt_chip_score: float = strategy.call("score_action_absolute_with_plan", _chip_action(active), state, 0, debt_plan)

	player.deck.assign([CardInstance.create(_pokemon("Too Large", "Basic", 80), 0)])
	_append_deck_fillers(player)
	var no_target_contract := _delegate_contract(strategy, state)
	var no_target_plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var no_target_chip_score: float = strategy.call("score_action_absolute_with_plan", _chip_action(active), state, 0, no_target_plan)

	player.bench.append(_slot(_real_card_data("CSV10C_004"), 0))
	player.hand.clear()
	player.deck.assign([_real_card("CSV10C_111")])
	_append_deck_fillers(player)
	var resolved_contract := _delegate_contract(strategy, state)
	var resolved_plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var resolved_chip_score: float = strategy.call("score_action_absolute_with_plan", _chip_action(active), state, 0, resolved_plan)
	return run_checks([
		assert_false(bool(no_target_contract.get("safe_setup_before_attack", true)), "Poffin with no legal 70 HP Basic target must clear the attack debt"),
		assert_eq(int((no_target_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", -1)), 0, "No-target Poffin debt should self-clear to zero"),
		assert_true(no_target_chip_score > debt_chip_score, "The shallow attack score should recover after Poffin loses every legal target"),
		assert_false(bool(resolved_contract.get("safe_setup_before_attack", true)), "Removing the resolved Poffin from hand must clear the attack debt"),
		assert_eq(int((resolved_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", -1)), 0, "Resolved Poffin debt should remain cleared even if another legal Basic is in deck"),
		assert_true(resolved_chip_score > debt_chip_score, "The shallow attack score should recover after Poffin resolves"),
		assert_true(_poffin_rule(resolved_contract).is_empty(), "A cleared debt must not retain the Poffin action bonus"),
	])


func test_live_tm_carrier_and_budew_tm_opening_do_not_create_poffin_debt() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var live_tm_state := _poffin_state("CSV10C_111", "CSV10C_111")
	var live_tm_player: PlayerState = live_tm_state.players[0]
	live_tm_player.active_pokemon.attached_tool = _real_card("CSV5C_119")
	live_tm_player.bench.append(_slot(_real_card_data("CSV10C_004"), 0))
	live_tm_player.deck.append(_real_card("CSV10C_005"))
	var live_tm_contract := _delegate_contract(strategy, live_tm_state)

	var budew_state := _poffin_state("CSV9.5C_004", "CSV10C_111")
	budew_state.turn_number = 1
	budew_state.first_player_index = 0
	var budew_player: PlayerState = budew_state.players[0]
	budew_player.active_pokemon.attached_tool = _real_card("CSV5C_119")
	budew_player.bench.assign([
		_slot(_real_card_data("CSV10C_111"), 0),
		_slot(_real_card_data("CSV10C_004"), 0),
	])
	budew_player.deck.append(_real_card("CSV10C_005"))
	var budew_contract := _delegate_contract(strategy, budew_state)
	return run_checks([
		assert_false(bool(live_tm_contract.get("safe_setup_before_attack", true)), "A live Active TM Evolution carrier already owns setup and must suppress Poffin-before-chip debt"),
		assert_eq(int((live_tm_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", -1)), 0, "The live TM route must report no Poffin-before-chip debt"),
		assert_false(bool(budew_contract.get("safe_setup_before_attack", true)), "The Budew plus TM strong opening must not trigger the Gible/Roserade Poffin gate"),
		assert_eq(int((budew_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", -1)), 0, "Budew plus TM should keep the Round 4 debt cleared"),
	])


func test_poffin_debt_requires_bench_space_and_an_unready_garchomp() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var full_bench_state := _poffin_state("CSV10C_111", "CSV10C_004")
	var full_bench_player: PlayerState = full_bench_state.players[0]
	for index: int in 5:
		full_bench_player.bench.append(_slot(_pokemon("Bench %d" % index, "Basic", 100), 0))
	var full_bench_contract := _delegate_contract(strategy, full_bench_state)

	var ready_state := _poffin_state("CSV10C_111", "CSV10C_004")
	var ready_player: PlayerState = ready_state.players[0]
	var garchomp := _slot(_real_card_data("CSV10C_113"), 0)
	garchomp.attached_energy.append(_real_card("CSVE1C_FIG"))
	ready_player.bench.append(garchomp)
	var ready_contract := _delegate_contract(strategy, ready_state)
	return run_checks([
		assert_false(bool(full_bench_contract.get("safe_setup_before_attack", true)), "A full Bench must suppress Poffin-before-chip debt"),
		assert_eq(int((full_bench_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", -1)), 0, "The debt must stay clear without Bench space"),
		assert_eq(int((ready_contract.get("setup_debt", {}) as Dictionary).get("needs_poffin_before_chip", -1)), 0, "The debt must stay clear once Garchomp is ready"),
		assert_true(_poffin_rule(ready_contract).is_empty(), "A ready Garchomp must remove the Poffin-specific continuity bonus"),
	])


func _strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(parsed))


func _delegate_contract(strategy: RefCounted, state: GameState) -> Dictionary:
	var delegate: Variant = strategy.get("_delegate")
	if delegate == null or not delegate.has_method("build_continuity_contract"):
		return {}
	var contract: Variant = delegate.call("build_continuity_contract", state, 0, {})
	return contract if contract is Dictionary else {}


func _poffin_rule(contract: Dictionary) -> Dictionary:
	for raw_rule: Variant in contract.get("action_bonuses", []):
		if not raw_rule is Dictionary:
			continue
		var rule: Dictionary = raw_rule
		if str(rule.get("kind", "")) == "play_trainer" and "Buddy-Buddy Poffin" in rule.get("card_names", []):
			return rule
	return {}


func _poffin_state(active_ref: String, target_ref: String) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	player.active_pokemon = _slot(_real_card_data(active_ref), 0)
	if active_ref == "CSV10C_111":
		player.active_pokemon.attached_energy.append(_real_card("CSVE1C_FIG"))
	player.hand.assign([_real_card("CSV7C_177")])
	player.deck.assign([_real_card(target_ref)])
	_append_deck_fillers(player)
	opponent.active_pokemon = _slot(_pokemon("Opponent", "Basic", 200), 1)
	return state


func _append_deck_fillers(player: PlayerState) -> void:
	for index: int in 8:
		player.deck.append(CardInstance.create(_pokemon("Deck Filler %d" % index, "Stage 1", 100), 0))


func _chip_action(active: PokemonSlot) -> Dictionary:
	return {
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"projected_knockout": false,
	}


func _real_card(ref: String) -> CardInstance:
	return CardInstance.create(_real_card_data(ref), 0)


func _real_card_data(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name_en: String, stage: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name_en
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.attacks = [{"name": "Chip", "cost": "C", "damage": "10"}]
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
