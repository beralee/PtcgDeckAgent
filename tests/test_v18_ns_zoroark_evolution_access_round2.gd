class_name TestV18NsZoroarkEvolutionAccessRound2
extends TestBase

const DeckStrategyNsZoroarkScript = preload("res://scripts/ai/DeckStrategyNsZoroark.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const NS_ZOROARK_DECK_ID := 800018502


func test_live_cyrano_and_iono_bridges_outrank_a_non_knockout_attack() -> String:
	var checks: Array[String] = []
	for supporter_ref: String in ["CSV9C_198", "CSV3C_123"]:
		var rig := _make_rig(supporter_ref)
		if rig.has("error"):
			return str(rig["error"])
		var strategy: RefCounted = rig["strategy"]
		var state: GameState = rig["state"]
		var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {})
		var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
		var attack_score := _score(strategy, _scratch_action(false), state, plan)
		var bridge_score := _score(strategy, _bridge_action(rig), state, plan)
		checks.append(assert_true(
			bool(continuity.get("safe_setup_before_attack", false)),
			"%s should activate the Zoroark evolution-access debt" % supporter_ref
		))
		checks.append(assert_true(
			bool((continuity.get("setup_debt", {}) as Dictionary).get("evolution_access_active", false)),
			"%s should expose the active debt in the continuity contract" % supporter_ref
		))
		checks.append(assert_gt(
			bridge_score,
			attack_score,
			"%s should outrank a non-KO Scratch while Zoroark evolution access is still missing" % supporter_ref
		))
	return run_checks(checks)


func test_evolution_access_debt_retires_after_access_appears_or_supporter_closes() -> String:
	var hand_rig := _make_rig()
	var field_rig := _make_rig()
	var supporter_used_rig := _make_rig()
	var bench_only_rig := _make_rig()
	for rig: Dictionary in [hand_rig, field_rig, supporter_used_rig, bench_only_rig]:
		if rig.has("error"):
			return str(rig["error"])

	var hand_player: PlayerState = hand_rig["state"].players[0]
	hand_player.hand.append(CardInstance.create(hand_rig["zoroark_data"], 0))

	var field_player: PlayerState = field_rig["state"].players[0]
	field_player.bench.append(_make_slot(field_rig["zoroark_data"], 0))

	(supporter_used_rig["state"] as GameState).supporter_used_this_turn = true

	var bench_only_player: PlayerState = bench_only_rig["state"].players[0]
	bench_only_player.bench.append(bench_only_player.active_pokemon)
	bench_only_player.active_pokemon = _make_slot(_make_filler("Active Pivot"), 0)

	return run_checks([
		_assert_debt_inactive(hand_rig, "Debt should retire as soon as Zoroark ex reaches the hand"),
		_assert_debt_inactive(field_rig, "Debt should retire as soon as Zoroark ex reaches the field"),
		_assert_debt_inactive(supporter_used_rig, "Debt should retire after the Supporter window is spent"),
		_assert_debt_inactive(bench_only_rig, "Debt requires Active Zorua, not merely a Benched Zorua"),
	])


func test_knockout_attack_stays_above_the_live_evolution_bridge() -> String:
	var rig := _make_rig()
	if rig.has("error"):
		return str(rig["error"])
	var strategy: RefCounted = rig["strategy"]
	var state: GameState = rig["state"]
	state.players[1].active_pokemon.damage_counters = 80
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var knockout_score := _score(strategy, _scratch_action(true), state, plan)
	var bridge_score := _score(strategy, _bridge_action(rig), state, plan)
	return assert_gt(
		knockout_score,
		bridge_score,
		"A current-turn KO must bypass the evolution-access debt"
	)


func test_production_wrapper_preserves_the_evolution_access_gate_and_ko_bypass() -> String:
	var rig := _make_rig()
	if rig.has("error"):
		return str(rig["error"])
	var deck := DeckData.new()
	deck.id = NS_ZOROARK_DECK_ID
	var strategy: RefCounted = DeckStrategyRegistryScript.new().resolve_strategy_for_deck(deck)
	if strategy == null:
		return "Production registry did not resolve deck 800018502"
	var state: GameState = rig["state"]
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	var setup_debt: Dictionary = continuity.get("setup_debt", {})
	var delegate_debt: Dictionary = setup_debt.get("delegate", {})
	var non_knockout_score := _score(strategy, _scratch_action(false), state, plan)
	var bridge_score := _score(strategy, _bridge_action(rig), state, plan)
	state.players[1].active_pokemon.damage_counters = 80
	var knockout_plan: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var knockout_score := _score(strategy, _scratch_action(true), state, knockout_plan)
	return run_checks([
		assert_eq(str(strategy.call("get_strategy_id")), "v18_800018502_ns_zoroark", "Round 2 must run through the production V18 registry wrapper"),
		assert_true(bool(delegate_debt.get("evolution_access_active", false)), "The wrapper should retain the delegate's active evolution debt"),
		assert_gt(bridge_score, non_knockout_score, "The production wrapper should place the live bridge above a non-KO attack"),
		assert_gt(knockout_score, bridge_score, "The production wrapper should keep a KO above the live bridge"),
	])


func test_strong_opening_context_does_not_activate_evolution_access_debt() -> String:
	var rig := _make_rig()
	if rig.has("error"):
		return str(rig["error"])
	var strategy: RefCounted = rig["strategy"]
	var state: GameState = rig["state"]
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {
		"strong_fixed_opening": true,
	})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	return run_checks([
		assert_false(bool(continuity.get("safe_setup_before_attack", false)), "Strong opening should not enable the Round 2 attack gate"),
		assert_false(
			bool((continuity.get("setup_debt", {}) as Dictionary).get("evolution_access_active", false)),
			"Strong opening should not carry the normal shuffled-opening evolution debt"
		),
	])


func _assert_debt_inactive(rig: Dictionary, message: String) -> String:
	var strategy: RefCounted = rig["strategy"]
	var state: GameState = rig["state"]
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	return assert_false(
		bool((continuity.get("setup_debt", {}) as Dictionary).get("evolution_access_active", false)),
		message
	)


func _score(strategy: RefCounted, action: Dictionary, state: GameState, plan: Dictionary) -> float:
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _scratch_action(projected_knockout: bool) -> Dictionary:
	return {
		"kind": "attack",
		"attack_name": "Scratch",
		"projected_damage": 20,
		"projected_knockout": projected_knockout,
	}


func _bridge_action(rig: Dictionary) -> Dictionary:
	return {
		"kind": "play_trainer",
		"card": rig["supporter"],
	}


func _make_rig(supporter_ref: String = "CSV9C_198") -> Dictionary:
	var zorua_data: CardData = CardDatabase.get_card("CSV10C", "144")
	var zoroark_data: CardData = CardDatabase.get_card("CSV10C", "145")
	var supporter_parts := supporter_ref.split("_", false, 1)
	var supporter_data: CardData = null
	if supporter_parts.size() == 2:
		supporter_data = CardDatabase.get_card(supporter_parts[0], supporter_parts[1])
	if zorua_data == null or zoroark_data == null or supporter_data == null:
		return {"error": "Required N's Zoroark, Cyrano, or Iono fixture is missing"}

	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(zorua_data, 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_darkness_energy(), 0))
	var supporter := CardInstance.create(supporter_data, 0)
	player.hand.append(supporter)
	player.deck.append(CardInstance.create(zoroark_data, 0))
	player.deck.append(CardInstance.create(_make_filler("Deck Filler"), 0))
	player.prizes.assign([
		CardInstance.create(_make_filler("Prize 1"), 0),
		CardInstance.create(_make_filler("Prize 2"), 0),
	])
	state.players[1].active_pokemon = _make_slot(_make_filler("Defender"), 1)

	return {
		"strategy": DeckStrategyNsZoroarkScript.new(),
		"state": state,
		"supporter": supporter,
		"zoroark_data": zoroark_data,
	}


func _make_darkness_energy() -> CardData:
	var card := CardData.new()
	card.name = "Darkness Energy"
	card.name_en = "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "D"
	return card


func _make_filler(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = 100
	return card


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot
