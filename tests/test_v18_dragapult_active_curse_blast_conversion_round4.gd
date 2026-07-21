class_name TestV18DragapultActiveCurseBlastConversionRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FAMILY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18DragapultFamily.gd")
const LEGAL_ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")
const DECK_ID := 800015734
const SIBLING_DECK_ID := 800018499


func test_seed15402_curse_blast_converts_the_active_before_phantom_dive() -> String:
	var strategy := _production_strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800015734 should resolve through the production V18 registry")
	var fixture := _seed15402_fixture()
	var state: GameState = fixture["state"]
	var dusclops: PokemonSlot = fixture["dusclops"]
	var active_target: PokemonSlot = fixture["active_target"]
	var bench_target: PokemonSlot = fixture["bench_target"]
	var context := {
		"game_state": state,
		"player_index": 0,
		"source_slot": dusclops,
	}
	var step := {"id": "self_ko_target", "max_select": 1}
	var active_score := float(strategy.call("score_interaction_target", active_target, step, context))
	var bench_score := float(strategy.call("score_interaction_target", bench_target, step, context))
	var initial_active_remaining := active_target.get_remaining_hp()
	var picked: Array = strategy.call(
		"pick_interaction_items",
		[bench_target, active_target],
		step,
		context
	)
	var blast_score := _score(strategy, {
		"kind": "use_ability",
		"source_slot": dusclops,
		"ability_index": 0,
	}, state)
	var attack_score := _score(strategy, {
		"kind": "attack",
		"source_slot": state.players[0].active_pokemon,
		"attack_index": 1,
		"projected_damage": 200,
		"projected_knockout": false,
	}, state)
	var family := _family_strategy(DECK_ID)
	var family_compound_blast_score := _score(family, {
		"kind": "use_ability",
		"source_slot": dusclops,
		"ability_index": 0,
	}, state)
	var family_compound_attack_score := _score(family, {
		"kind": "attack",
		"source_slot": state.players[0].active_pokemon,
		"attack_index": 1,
		"projected_damage": 200,
		"projected_knockout": false,
	}, state)
	var family_pick: Array = family.call(
		"pick_interaction_items",
		[bench_target, active_target],
		step,
		context
	)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder: RefCounted = LEGAL_ACTION_BUILDER_SCRIPT.new()
	builder.call("set_deck_strategy", strategy)
	var built_target := _built_dusclops_target(builder.call("build_actions", gsm, 0), dusclops)
	return run_checks([
		assert_eq(initial_active_remaining, 230, "The seed-15402 Iron Hands fixture should start at 230 HP"),
		assert_eq(initial_active_remaining - 200, 30, "A non-KO 200-damage Phantom Dive should leave Iron Hands at 30 HP"),
		assert_eq(bench_target.get_remaining_hp(), 120, "The seed-15402 Zapdos fixture should have 120 HP remaining"),
		assert_true(active_score > bench_score, "Curse Blast must rank the opponent Active above the 120 HP Bench target (active=%f bench=%f)" % [active_score, bench_score]),
		assert_eq(picked, [active_target], "Curse Blast interaction resolution must choose the opponent Active"),
		assert_eq(family_pick, [active_target], "The deck delegate must explicitly own the Active Curse Blast interaction target"),
		assert_eq(built_target, active_target, "The production headless legal action must pre-resolve Curse Blast onto the opponent Active"),
		assert_true(blast_score > attack_score, "Curse Blast must precede non-KO Phantom Dive in the Active compound window (blast=%f attack=%f)" % [blast_score, attack_score]),
		assert_true(family_compound_blast_score > family_compound_attack_score, "The deck delegate must own Active compound ordering without wrapper setup debt (blast=%f attack=%f)" % [family_compound_blast_score, family_compound_attack_score]),
		assert_true(bench_score < 2800.0, "Dusclops 50 plus Phantom Dive spread 60 must not convert a 120 HP Bench target (score=%f)" % bench_score),
	])


func test_active_only_conversion_is_scoped_to_self_destruct_dragapult() -> String:
	var sibling_deck := DeckData.new()
	sibling_deck.id = SIBLING_DECK_ID
	var strategy: RefCounted = FAMILY_SCRIPT.new()
	strategy.call("configure_from_deck", sibling_deck)
	var fixture := _seed15402_fixture()
	var state: GameState = fixture["state"]
	var bench_target: PokemonSlot = fixture["bench_target"]
	var score := float(strategy.call("score_interaction_target", bench_target, {
		"id": "self_ko_target",
	}, {
		"game_state": state,
		"player_index": 0,
		"source_slot": fixture["dusclops"],
	}))
	return assert_true(
		score >= 2800.0,
		"The deck-scoped correction must not change another Dragapult-family delegate (score=%f)" % score
	)


func _production_strategy(deck_id: int) -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % deck_id
	))
	if not payload is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(payload))


func _family_strategy(deck_id: int) -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % deck_id
	))
	if not payload is Dictionary:
		return null
	var strategy: RefCounted = FAMILY_SCRIPT.new()
	strategy.call("configure_from_deck", DeckData.from_dict(payload))
	return strategy


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _built_dusclops_target(actions: Array, dusclops: PokemonSlot) -> PokemonSlot:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != "use_ability" or action.get("source_slot", null) != dusclops:
			continue
		var targets: Array = action.get("targets", [])
		if targets.is_empty() or not targets[0] is Dictionary:
			return null
		var selected: Array = (targets[0] as Dictionary).get("self_ko_target", [])
		return selected[0] as PokemonSlot if not selected.is_empty() and selected[0] is PokemonSlot else null
	return null


func _seed15402_fixture() -> Dictionary:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		_set_prizes(player, 6)
		state.players.append(player)

	var dragapult := _slot(_real_card("CSV8C_159"), 0)
	dragapult.attached_energy.assign([
		CardInstance.create(_real_card("CSVE1C_FIR"), 0),
		CardInstance.create(_real_card("CSVE1C_PSY"), 0),
	])
	var dusclops := _slot(_real_card("CSV8C_082"), 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench.append(dusclops)

	var iron_hands := _slot(_real_card("CSV6C_051"), 1)
	var zapdos := _slot(_real_card("CS6aC_057"), 1)
	state.players[1].active_pokemon = iron_hands
	state.players[1].bench.append(zapdos)
	return {
		"state": state,
		"dusclops": dusclops,
		"active_target": iron_hands,
		"bench_target": zapdos,
	}


func _set_prizes(player: PlayerState, count: int) -> void:
	for index: int in count:
		var prize := CardData.new()
		prize.name = "Prize %d" % index
		prize.name_en = prize.name
		prize.card_type = "Item"
		player.prizes.append(CardInstance.create(prize, player.player_index))


func _real_card(uid: String) -> CardData:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % uid
	))
	return CardData.from_dict(payload) if payload is Dictionary else null


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
