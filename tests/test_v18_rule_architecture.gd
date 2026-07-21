class_name TestV18RuleArchitecture
extends TestBase

const V18_RULES_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Rules.gd")


class ProbeDelegate extends DeckStrategyBase:
	var plan: Dictionary = {}
	var continuity: Dictionary = {}


	func build_turn_plan(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
		return plan.duplicate(true)


	func build_continuity_contract(
		_game_state: GameState,
		_player_index: int,
		_turn_contract: Dictionary = {}
	) -> Dictionary:
		return continuity.duplicate(true)


	func score_action_absolute(_action: Dictionary, _game_state: GameState, _player_index: int) -> float:
		return 0.0


func test_delegate_continuity_bonus_is_applied_exactly_once() -> String:
	var delegate := ProbeDelegate.new()
	delegate.continuity = {
		"enabled": true,
		"safe_setup_before_attack": false,
		"action_bonuses": [{"kind": "architecture_probe", "bonus": 500.0}],
		"attack_penalty": 0.0,
	}
	var strategy: RefCounted = _make_strategy(delegate)
	var score: float = strategy.call(
		"score_action_absolute_with_plan",
		{"kind": "architecture_probe"},
		_make_state(),
		0,
		{}
	)
	return assert_true(
		score >= 500.0 and score < 510.0,
		"The wrapper must apply a delegate continuity bonus exactly once (score=%f)" % score
	)


func test_delegate_retreat_guard_is_applied_exactly_once() -> String:
	var delegate := ProbeDelegate.new()
	var strategy: RefCounted = _make_strategy(delegate)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(_make_pokemon("Route Owner", "", "100"))
	var bench_target := _make_slot(_make_pokemon("Bench Target", "", "100"))
	player.bench.append(bench_target)
	var energy := CardInstance.create(_make_energy("Test Energy", "C"), 0)
	player.active_pokemon.attached_energy.append(energy)
	var score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": bench_target,
		"energy_to_discard": [energy],
	}, state, 0, {
		"owner": {"turn_owner_name": "Route Owner"},
		"targets": {"primary_attacker_name": "Route Owner"},
	})
	return assert_true(
		score > -8000.0 and score < -6000.0,
		"The resource-paid owner retreat guard must be charged once, not twice (score=%f)" % score
	)


func test_delegate_can_explicitly_disable_shared_safe_setup_penalty() -> String:
	var delegate := ProbeDelegate.new()
	delegate.continuity = {
		"enabled": false,
		"safe_setup_before_attack": false,
		"setup_debt": {},
		"action_bonuses": [],
		"attack_penalty": 0.0,
		"stop_reason": "delegate_closeout",
	}
	var strategy: RefCounted = _make_strategy(delegate, {
		"bench_priority": ["Missing Setup Body"],
		"energy_priority": ["Ready Attacker"],
		"continuity": {"setup_floor": 2, "deck_churn_floor": 8},
	})
	var state := _make_state()
	state.players[0].active_pokemon = _make_slot(_make_pokemon("Ready Attacker", "", "100"))
	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {"phase": "close"})
	return run_checks([
		assert_false(bool(contract.get("safe_setup_before_attack", true)), "An explicit delegate closeout must not be reopened by shared setup debt"),
		assert_eq(float(contract.get("attack_penalty", -1.0)), 0.0, "A disabled safe-setup window must carry no attack penalty"),
		assert_eq(str(contract.get("stop_reason", "")), "delegate_closeout", "The delegate closeout reason should survive the merge"),
	])


func test_delegate_plan_preserves_phase_and_deep_merges_constraints_and_context() -> String:
	var delegate := ProbeDelegate.new()
	delegate.plan = {
		"id": "delegate-plan",
		"intent": "finish_game",
		"phase": "close",
		"constraints": {
			"must_attack_if_available": true,
			"route": {"delegate": "preserved"},
		},
		"context": {
			"trace": {"delegate": 2},
			"delegate_only": true,
		},
	}
	var strategy: RefCounted = _make_strategy(delegate)
	var merged: Dictionary = strategy.call("_merge_delegate_plan", {
		"id": "profile-plan",
		"intent": "setup",
		"phase": "setup",
		"constraints": {
			"forbid_engine_churn": true,
			"route": {"shared": "preserved"},
		},
		"context": {
			"trace": {"shared": 1},
			"shared_only": true,
		},
	}, _make_state(), 0, {})
	var constraints: Dictionary = merged.get("constraints", {})
	var route: Dictionary = constraints.get("route", {})
	var context: Dictionary = merged.get("context", {})
	var trace: Dictionary = context.get("trace", {})
	return run_checks([
		assert_eq(str(merged.get("id", "")), "profile-plan", "The wrapper should keep its stable plan id"),
		assert_eq(str(merged.get("delegate_plan_id", "")), "delegate-plan", "The delegate plan id should remain traceable"),
		assert_eq(str(merged.get("phase", "")), "close", "The delegate phase should override the generic phase"),
		assert_true(bool(constraints.get("forbid_engine_churn", false)), "Shared constraints should survive delegate merging"),
		assert_true(bool(constraints.get("must_attack_if_available", false)), "Delegate constraints should survive plan merging"),
		assert_eq(str(route.get("shared", "")), "preserved", "Nested shared constraints should survive deep merging"),
		assert_eq(str(route.get("delegate", "")), "preserved", "Nested delegate constraints should survive deep merging"),
		assert_eq(int(trace.get("shared", 0)), 1, "Nested shared context should survive deep merging"),
		assert_eq(int(trace.get("delegate", 0)), 2, "Nested delegate context should survive deep merging"),
		assert_true(bool(context.get("shared_only", false)), "Shared context keys should survive delegate merging"),
		assert_true(bool(context.get("delegate_only", false)), "Delegate context keys should survive delegate merging"),
	])


func test_final_prize_detection_uses_the_defenders_real_prize_value() -> String:
	var base := DeckStrategyBase.new()
	var strategy: RefCounted = _make_strategy(ProbeDelegate.new())
	var checks: Array[String] = []
	for case: Dictionary in [
		{"remaining": 1, "mechanic": "", "expected": true},
		{"remaining": 2, "mechanic": "ex", "expected": true},
		{"remaining": 3, "mechanic": "VMAX", "expected": true},
		{"remaining": 2, "mechanic": "", "expected": false},
	]:
		var state := _make_state(30, int(case.get("remaining", 0)), str(case.get("mechanic", "")))
		var action := {"kind": "attack", "projected_knockout": true, "projected_damage": 200}
		var actual: bool = bool(base.call("_is_continuity_final_prize_attack", action, state, 0))
		checks.append(assert_eq(actual, bool(case.get("expected", false)), "Final-prize detection should compare remaining prizes with the defender's prize value"))
		var bonus: float = strategy.call("_terminal_attack_bonus", action, state, 0, "close")
		if bool(case.get("expected", false)):
			checks.append(assert_true(bonus >= 5000.0, "A real %d-prize knockout should receive the terminal bonus" % int(case.get("remaining", 0))))
		else:
			checks.append(assert_true(bonus < 5000.0, "A one-prize knockout with two prizes remaining must not be treated as terminal"))
	return run_checks(checks)


func test_low_deck_draw_knockout_is_not_churn_clamped() -> String:
	var strategy: RefCounted = _make_strategy(ProbeDelegate.new(), {
		"continuity": {"setup_floor": 1, "deck_churn_floor": 8},
	})
	var state := _make_state(4, 2, "ex")
	state.players[0].active_pokemon = _make_slot(_make_pokemon("Ready Attacker", "", "200"))
	var plan := {"phase": "close", "flags": {"low_deck": true}}
	var attack_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"attack": {"name": "Closing Draw", "text": "Draw 2 cards."},
		"projected_damage": 200,
		"projected_knockout": true,
	}, state, 0, plan)
	var end_turn_score: float = strategy.call("score_action_absolute_with_plan", {"kind": "end_turn"}, state, 0, plan)
	return run_checks([
		assert_true(attack_score > 0.0, "A low-deck knockout with draw text must not be clamped to a negative churn score"),
		assert_true(attack_score >= end_turn_score + 5000.0, "A terminal draw attack must remain decisively above ending the turn"),
	])


func test_profile_deck_churn_floor_is_respected_exactly() -> String:
	var strategy: RefCounted = _make_strategy(ProbeDelegate.new(), {
		"continuity": {"setup_floor": 1, "deck_churn_floor": 8},
	})
	var nine_card_plan: Dictionary = strategy.call("build_turn_plan", _make_state(9), 0, {})
	var eight_card_plan: Dictionary = strategy.call("build_turn_plan", _make_state(8), 0, {})
	return run_checks([
		assert_eq(int(strategy.call("_deck_churn_floor")), 8, "The profile's configured churn floor should not be raised to 12"),
		assert_false(bool((nine_card_plan.get("flags", {}) as Dictionary).get("low_deck", true)), "Nine cards should be above a configured floor of eight"),
		assert_true(bool((eight_card_plan.get("flags", {}) as Dictionary).get("low_deck", false)), "Eight cards should enter low-deck mode at a configured floor of eight"),
	])


func _make_strategy(delegate: RefCounted, overrides: Dictionary = {}) -> RefCounted:
	var profile := {
		"deck_id": 999999,
		"strategy_id": "v18_architecture_probe",
		"opening_active": ["Ready Attacker"],
		"bench_priority": ["Ready Attacker"],
		"energy_priority": ["Ready Attacker"],
		"evolution_priority": ["Ready Attacker"],
		"search_priority": ["Ready Attacker"],
		"ability_priority": [],
		"trainer_priority": [],
		"continuity": {"setup_floor": 1, "deck_churn_floor": 12},
	}
	profile.merge(overrides, true)
	var strategy: RefCounted = V18_RULES_SCRIPT.new()
	strategy.call("configure_profile", profile)
	strategy.set("_delegate", delegate)
	return strategy


func _make_state(deck_size: int = 30, prize_count: int = 6, opponent_mechanic: String = "") -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	for index: int in deck_size:
		player.deck.append(CardInstance.create(_make_trainer("Deck card %d" % index), 0))
	for index: int in prize_count:
		player.prizes.append(CardInstance.create(_make_trainer("Prize card %d" % index), 0))
	var opponent := PlayerState.new()
	opponent.player_index = 1
	var defender := _make_pokemon("Defender", "", "10")
	defender.mechanic = opponent_mechanic
	opponent.active_pokemon = _make_slot(defender)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, 0))
	return slot


func _make_pokemon(name: String, attack_cost: String, damage: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = 300
	card.attacks = [{"name": "Test Attack", "cost": attack_cost, "damage": damage}]
	return card


func _make_energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _make_trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Supporter"
	return card
