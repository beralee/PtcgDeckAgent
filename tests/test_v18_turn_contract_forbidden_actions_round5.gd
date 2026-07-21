class_name TestV18TurnContractForbiddenActionsRound5
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800015934


func test_generic_forbidden_kind_scores_below_end_turn() -> String:
	var strategy := _strategy()
	var state := _state()
	var plan := _plan(["play_basic_to_bench"])
	var fan_rotom := _card("Fan Rotom", "Pokemon", "Basic")
	var bench_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": fan_rotom},
		state,
		0,
		plan
	))
	var end_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "end_turn"},
		state,
		0,
		plan
	))
	return assert_true(
		bench_score < end_score,
		"A generic forbidden action kind must be hard-blocked below end_turn (bench=%f end=%f)" % [bench_score, end_score]
	)


func test_qualified_forbidden_card_does_not_block_other_basics() -> String:
	var strategy := _strategy()
	var state := _state()
	var plan := _plan(["play_basic_to_bench:FAN ROTOM"])
	plan["flags"] = {"low_deck": false, "ready_attackers": 0}
	plan["constraints"] = {}
	var fan_rotom_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": _card("Fan Rotom", "Pokemon", "Basic")},
		state,
		0,
		plan
	))
	var hoothoot_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": _card("Hoothoot", "Pokemon", "Basic")},
		state,
		0,
		plan
	))
	var end_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "end_turn"},
		state,
		0,
		plan
	))
	return run_checks([
		assert_true(fan_rotom_score < end_score, "Qualified forbidden Fan Rotom must score below end_turn (Fan Rotom=%f end=%f)" % [fan_rotom_score, end_score]),
		assert_true(
			hoothoot_score > fan_rotom_score,
			"A qualified Fan Rotom ban must not suppress unrelated Basics (Hoothoot=%f Fan Rotom=%f)" % [hoothoot_score, fan_rotom_score]
		),
	])


func test_generic_bench_padding_ban_preserves_contract_core_basic() -> String:
	var strategy := _strategy()
	var state := _state()
	var plan := _plan(["play_basic_to_bench"])
	plan["phase"] = "rebuild"
	plan["intent"] = "rebuild_next_attacker"
	plan["owner"] = {
		"turn_owner_name": "Dragapult ex",
		"bridge_target_name": "Drakloak",
		"pivot_target_name": "Dragapult ex",
	}
	plan["targets"] = {
		"primary_attacker_name": "Dragapult ex",
		"bridge_target_name": "Drakloak",
	}
	plan["priorities"] = {
		"search": ["Dragapult ex", "Drakloak", "Dreepy"],
	}
	var core_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": _card("Dreepy", "Pokemon", "Basic")},
		state,
		0,
		plan
	))
	var filler_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": _card("Fan Rotom", "Pokemon", "Basic")},
		state,
		0,
		plan
	))
	return run_checks([
		assert_true(
			core_score > -50000.0,
			"A generic padding ban must not hard-block a Basic named by the rebuild contract (score=%f)" % core_score
		),
		assert_true(
			filler_score <= -50000.0,
			"The same contract must still hard-block unrelated bench filler (score=%f)" % filler_score
		),
	])


func test_generic_bench_padding_ban_still_blocks_duplicate_contract_core_basic() -> String:
	var strategy := _strategy()
	var state := _state()
	state.players[0].bench.append(_slot(_pokemon("Dreepy", 70, [])))
	var plan := _plan(["play_basic_to_bench"])
	plan["phase"] = "rebuild"
	plan["intent"] = "rebuild_next_attacker"
	plan["priorities"] = {"search": ["Dragapult ex", "Drakloak", "Dreepy"]}
	var duplicate_score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": _card("Dreepy", "Pokemon", "Basic")},
		state,
		0,
		plan
	))
	return assert_true(
		duplicate_score <= -50000.0,
		"A contract priority must not exempt duplicate core Basics from the padding ban (score=%f)" % duplicate_score
	)


func test_generic_bench_padding_ban_only_exempts_explicit_rebuild_intents() -> String:
	var strategy := _strategy()
	var state := _state()
	var plan := _plan(["play_basic_to_bench"])
	plan["phase"] = "rebuild"
	plan["intent"] = "establish_tera_board"
	plan["priorities"] = {"search": ["Noctowl", "Hoothoot"]}
	var score := float(strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "play_basic_to_bench", "card": _card("Hoothoot", "Pokemon", "Basic")},
		state,
		0,
		plan
	))
	return assert_true(
		score <= -50000.0,
		"A rebuild phase must not exempt core padding unless the intent explicitly owns attacker rebuild (score=%f)" % score
	)


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	player.active_pokemon = _slot(_pokemon("Terapagos ex", 230, [{"name": "Unified Beatdown", "cost": "C", "damage": "30"}]))
	player.active_pokemon.attached_energy.append(_energy())
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", 220, [{"name": "Photon Blaster", "cost": "LLC", "damage": "220"}]), 1)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 21
	state.phase = GameState.GamePhase.MAIN
	return state


func _plan(forbidden: Array[String]) -> Dictionary:
	return {
		"id": "v18_contract_forbidden_test",
		"intent": "convert_with_tera_attacker",
		"phase": "launch",
		"flags": {"low_deck": true, "ready_attackers": 1},
		"constraints": {"forbid_engine_churn": true},
		"forbidden_action_kinds": forbidden,
	}


func _card(card_name: String, card_type: String, stage: String = "") -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = card_type
	card.stage = stage
	return CardInstance.create(card, 0)


func _pokemon(card_name: String, hp: int, attacks: Array, owner_index: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	for attack: Dictionary in attacks:
		card.attacks.append(attack)
	return CardInstance.create(card, owner_index)


func _slot(card: CardInstance, _owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _energy() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Grass Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "G"
	card.energy_provides = "G"
	return CardInstance.create(card, 0)
