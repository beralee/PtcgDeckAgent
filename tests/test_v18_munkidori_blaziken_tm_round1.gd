class_name TestV18MunkidoriBlazikenTMRound1
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 18000625
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18BlazikenDragapult.gd"


func test_second_player_first_turn_tm_route_advances_and_clears_its_debt() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 18000625 should resolve through the production V18 registry")
	var delegate: RefCounted = strategy.get("_delegate")
	var state := _tm_route_state(2, 1)
	var player: PlayerState = state.players[0]
	var pecharunt := player.active_pokemon
	var torchic := player.bench[0]
	var tm: CardInstance = player.hand[0]
	var fire: CardInstance = player.hand[1]
	var checks: Array[String] = [
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "The registry must return the production V18 rules wrapper"),
		assert_not_null(delegate, "The production wrapper must expose the deck delegate"),
		assert_eq(delegate.get_script().resource_path if delegate != null else "", DELEGATE_PATH, "Deck 18000625 must use its owned delegate"),
	]

	var attach_tm_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var attach_tm_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, attach_tm_plan)
	var active_tm_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": pecharunt,
	}, state, 0, attach_tm_plan)
	var torchic_tm_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": torchic,
	}, state, 0, attach_tm_plan)
	var early_fire_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": pecharunt,
	}, state, 0, attach_tm_plan)
	checks.append_array([
		assert_eq(_route_stage(attach_tm_plan), "attach_tm", "The route must start by attaching TM Evolution"),
		assert_eq(str(attach_tm_plan.get("owner", {}).get("turn_owner_name", "")), "桃歹郎", "The live route owner must be active CSV9C_127"),
		assert_eq(str(attach_tm_plan.get("owner", {}).get("bridge_target_name", "")), "火稚鸡", "The live route bridge must be the evolvable Torchic"),
		assert_eq(str(attach_tm_continuity.get("owner", {}).get("turn_owner_name", "")), "桃歹郎", "Continuity must expose the same live owner"),
		assert_eq(str(attach_tm_continuity.get("owner", {}).get("bridge_target_name", "")), "火稚鸡", "Continuity must expose the same live bridge"),
		assert_eq(_tm_debt(attach_tm_continuity), 1, "TM Evolution debt must be live before the Tool attachment"),
		assert_true(active_tm_score >= 5200.0, "TM Evolution must retain its 5200 floor on the active carrier (score=%f)" % active_tm_score),
		assert_true(active_tm_score >= torchic_tm_score + 2000.0, "TM Evolution must target active Pecharunt, not Torchic (active=%f torchic=%f)" % [active_tm_score, torchic_tm_score]),
		assert_true(early_fire_score < 3000.0, "Active Fire must not receive the route floor before TM is attached (score=%f)" % early_fire_score),
	])

	pecharunt.attached_tool = tm
	var attach_fire_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var attach_fire_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, attach_fire_plan)
	var active_fire_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": pecharunt,
	}, state, 0, attach_fire_plan)
	var torchic_fire_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": torchic,
	}, state, 0, attach_fire_plan)
	checks.append_array([
		assert_eq(_route_stage(attach_fire_plan), "attach_active_fire", "Attached TM must advance the route to active Fire"),
		assert_eq(_tm_debt(attach_fire_continuity), 1, "TM Evolution debt must remain live while active Fire is missing"),
		assert_true(bool(attach_fire_continuity.get("safe_setup_before_attack", false)), "Continuity must block a terminal attack until active Fire is attached"),
		assert_true(active_fire_score >= 6200.0, "Basic Fire must receive the active route floor during attach_active_fire (score=%f)" % active_fire_score),
		assert_true(active_fire_score >= torchic_fire_score + 2000.0, "Active Fire must outrank the existing Torchic 3400 route by at least 2000 (active=%f torchic=%f)" % [active_fire_score, torchic_fire_score]),
	])

	pecharunt.attached_energy.append(fire)
	var use_tm_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var use_tm_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, use_tm_plan)
	var tm_attack_score: float = strategy.call("score_action_absolute_with_plan", _tm_attack(pecharunt), state, 0, use_tm_plan)
	var late_fire_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": pecharunt,
	}, state, 0, use_tm_plan)
	checks.append_array([
		assert_eq(_route_stage(use_tm_plan), "use_tm_evolution", "Attached Fire must advance the route to the granted attack"),
		assert_eq(_tm_debt(use_tm_continuity), 1, "The first-turn debt remains live until TM Evolution ends the turn"),
		assert_false(bool(use_tm_continuity.get("safe_setup_before_attack", true)), "TM Evolution itself must not receive the pre-attack debt penalty"),
		assert_true(tm_attack_score >= 6500.0, "TM Evolution must retain its 6500 attack floor after Fire is attached (score=%f)" % tm_attack_score),
		assert_true(late_fire_score < active_fire_score - 2000.0, "The active Fire route floor must clear once TM Evolution is ready (ready=%f late=%f)" % [active_fire_score, late_fire_score]),
	])

	state.turn_number = 4
	var inactive_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var inactive_continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, inactive_plan)
	checks.append_array([
		assert_eq(_route_stage(inactive_plan), "inactive", "The route must become inactive after the second player's first turn"),
		assert_eq(_plan_tm_debt(inactive_plan), 0, "The turn plan must self-clear first-turn TM debt"),
		assert_eq(_tm_debt(inactive_continuity), 0, "Continuity must self-clear first-turn TM debt"),
	])
	return run_checks(checks)


func test_first_player_turn_one_rejects_wasting_tm_evolution() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 18000625 should resolve through the production V18 registry")
	var state := _tm_route_state(1, 0)
	var player: PlayerState = state.players[0]
	var pecharunt := player.active_pokemon
	var tm: CardInstance = player.hand[0]
	var fire: CardInstance = player.hand[1]
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var attach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": pecharunt,
	}, state, 0, plan)
	pecharunt.attached_tool = tm
	pecharunt.attached_energy.append(fire)
	var attack_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var attack_score: float = strategy.call("score_action_absolute_with_plan", _tm_attack(pecharunt), state, 0, attack_plan)
	return run_checks([
		assert_eq(_route_stage(plan), "inactive", "The first player must never enter the turn-one TM route"),
		assert_eq(_route_stage(attack_plan), "inactive", "Attaching resources must not unlock the first-player TM route"),
		assert_eq(_plan_tm_debt(plan), 0, "The first player must not expose TM route debt"),
		assert_true(attach_score < 0.0, "The first player must keep TM Evolution in hand (score=%f)" % attach_score),
		assert_true(attack_score < 0.0, "The first player must reject TM Evolution's unavailable attack (score=%f)" % attack_score),
	])


func _wrapper_strategy() -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % DECK_ID))
	if not payload is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _tm_route_state(turn_number: int, first_player_index: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Opponent Active", 200), 1)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = first_player_index
	state.turn_number = turn_number
	state.phase = GameState.GamePhase.MAIN

	player.active_pokemon = _slot(_real_card_data("CSV9C_127"), 0)
	player.bench.append(_slot(_real_card_data("CSV10C_036"), 0))
	player.hand.assign([
		_real_card("CSV5C_119"),
		_real_card("CSVE1C_FIR"),
	])
	player.deck.append(_real_card("CSV10C_037"))
	for index: int in 10:
		player.deck.append(CardInstance.create(_trainer("Deck filler %d" % index), 0))
	for index: int in 6:
		player.prizes.append(CardInstance.create(_trainer("Prize filler %d" % index), 0))
	return state


func _tm_attack(source: PokemonSlot) -> Dictionary:
	return {
		"kind": "granted_attack",
		"source_slot": source,
		"granted_attack_data": {
			"id": "tm_evolution",
			"name": "Evolution",
			"cost": "C",
			"damage": "",
		},
	}


func _route_stage(plan: Dictionary) -> String:
	var flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	return str(flags.get("tm_evolution_first_turn_route", ""))


func _plan_tm_debt(plan: Dictionary) -> int:
	var flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	var debt: Dictionary = flags.get("setup_debt", {}) if flags.get("setup_debt", {}) is Dictionary else {}
	return int(debt.get("tm_evolution_first_turn", -1))


func _tm_debt(continuity: Dictionary) -> int:
	var merged: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var debt: Dictionary = merged.get("delegate", merged) if merged.get("delegate", merged) is Dictionary else {}
	return int(debt.get("tm_evolution_first_turn", -1))


func _real_card(ref: String) -> CardInstance:
	return CardInstance.create(_real_card_data(ref), 0)


func _real_card_data(ref: String) -> CardData:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(payload) if payload is Dictionary else null


func _pokemon(card_name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _trainer(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Item"
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
