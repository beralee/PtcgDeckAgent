class_name TestV18DragapultCurseBlastLiability
extends TestBase


const FAMILY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18DragapultFamily.gd")
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800015734


func test_curse_blast_requires_a_direct_final_prize_close() -> String:
	var deck := DeckData.new()
	deck.id = DECK_ID
	var family: RefCounted = FAMILY_SCRIPT.new()
	family.call("configure_from_deck", deck)
	var production: RefCounted = REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)
	if production == null:
		return "Production registry should resolve self-destruct Dragapult"

	var checks: Array[String] = []
	for source_name: String in ["Dusknoir", "Dusclops"]:
		var damage := 130 if source_name == "Dusknoir" else 50
		var fixture := _make_fixture(source_name, damage)
		var state: GameState = fixture["state"]
		var source: PokemonSlot = fixture["source"]
		var closing_target: PokemonSlot = fixture["closing_target"]
		var projected_target: PokemonSlot = fixture["projected_target"]
		var action := {
			"kind": "use_ability",
			"source_slot": source,
			"ability_index": 0,
		}

		_set_prize_count(state.players[0], 3)
		_set_prize_count(state.players[1], 1)
		for strategy_entry: Dictionary in [
			{"name": "direct family", "strategy": family},
			{"name": "production wrapper", "strategy": production},
		]:
			var strategy: RefCounted = strategy_entry["strategy"]
			var rejected := _score(strategy, action, state)
			var end_turn := _score(strategy, {"kind": "end_turn"}, state)
			checks.append(assert_true(
				rejected < end_turn,
				"%s %s must reject a two-prize blast while we have three prizes (ability=%f end=%f)" % [
					strategy_entry["name"], source_name, rejected, end_turn,
				]
			))

		_set_prize_count(state.players[0], 2)
		checks.append(assert_eq(
			_score(family, action, state),
			5200.0,
			"Direct family %s must preserve the exact-prize Curse Blast reward" % source_name
		))
		for strategy_entry: Dictionary in [
			{"name": "direct family", "strategy": family},
			{"name": "production wrapper", "strategy": production},
		]:
			var strategy: RefCounted = strategy_entry["strategy"]
			var admitted := _score(strategy, action, state)
			var end_turn := _score(strategy, {"kind": "end_turn"}, state)
			checks.append(assert_true(
				admitted > end_turn,
				"%s %s must admit a direct two-prize close (ability=%f end=%f)" % [
					strategy_entry["name"], source_name, admitted, end_turn,
				]
			))

		state.players[1].active_pokemon = projected_target
		state.players[1].bench.assign([closing_target])
		closing_target.damage_counters = 0
		for strategy_entry: Dictionary in [
			{"name": "direct family", "strategy": family},
			{"name": "production wrapper", "strategy": production},
		]:
			var strategy: RefCounted = strategy_entry["strategy"]
			var projected_only := _score(strategy, action, state)
			var end_turn := _score(strategy, {"kind": "end_turn"}, state)
			checks.append(assert_true(
				projected_only < end_turn,
				"%s %s must not count a projected Phantom Dive follow-up as a Curse Blast close" % [
					strategy_entry["name"], source_name,
				]
			))

		state.players[1].active_pokemon = closing_target
		closing_target.damage_counters = closing_target.get_card_data().hp - damage
		var overkill_target := _slot(_pokemon("Overkill ex", damage + 10, "ex"), 1)
		overkill_target.damage_counters = damage
		state.players[1].bench.assign([overkill_target])
		var context := {
			"game_state": state,
			"player_index": 0,
			"source_slot": source,
		}
		var exact_score := float(family.call(
			"score_interaction_target", closing_target, {"id": "self_ko_target"}, context
		))
		var overkill_score := float(family.call(
			"score_interaction_target", overkill_target, {"id": "self_ko_target"}, context
		))
		var picked: Array = production.call(
			"pick_interaction_items",
			[overkill_target, closing_target],
			{"id": "self_ko_target", "max_select": 1},
			context
		)
		checks.append(assert_true(
			exact_score > overkill_score,
			"Direct family %s target scoring must keep the exact closing knockout first" % source_name
		))
		checks.append(assert_eq(
			picked,
			[closing_target],
			"Production %s picker must keep the exact closing target" % source_name
		))

	return run_checks(checks)


func test_curse_blast_hard_rejects_subthreshold_liability() -> String:
	var deck := DeckData.new()
	deck.id = DECK_ID
	var family: RefCounted = FAMILY_SCRIPT.new()
	family.call("configure_from_deck", deck)
	var production: RefCounted = REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)
	if production == null:
		return "Production registry should resolve self-destruct Dragapult"

	var checks: Array[String] = []
	for source_name: String in ["Dusknoir", "Dusclops"]:
		var damage := 130 if source_name == "Dusknoir" else 50
		var fixture := _make_fixture(source_name, damage)
		var state: GameState = fixture["state"]
		var source: PokemonSlot = fixture["source"]
		var action := {
			"kind": "use_ability",
			"source_slot": source,
			"ability_index": 0,
		}
		_set_prize_count(state.players[0], 3)
		_set_prize_count(state.players[1], 3)

		var low_target := _slot(_pokemon("Healthy target", damage + 300), 1)
		state.players[1].active_pokemon = low_target
		state.players[1].bench.clear()
		var context := {
			"game_state": state,
			"player_index": 0,
			"source_slot": source,
		}
		var low_target_score := float(family.call(
			"score_interaction_target", low_target, {"id": "self_ko_target"}, context
		))
		checks.append(assert_true(
			low_target_score < 2800.0,
			"%s fixture must stay below the Curse Blast conversion threshold" % source_name
		))
		var family_low_score := _score(family, action, state)
		checks.append(assert_true(
			is_inf(family_low_score) and family_low_score < 0.0,
			"Direct family %s must hard-reject a subthreshold Curse Blast" % source_name
		))
		var production_low_score := _score(production, action, state)
		var punished_end_turn := _score(production, {"kind": "end_turn"}, state)
		checks.append(assert_true(
			punished_end_turn < 0.0,
			"Production %s fixture must retain a punished end_turn" % source_name
		))
		checks.append(assert_true(
			production_low_score < punished_end_turn,
			"Production %s must rank a subthreshold Curse Blast below punished end_turn (ability=%f end=%f)" % [
				source_name, production_low_score, punished_end_turn,
			]
		))

		var conversion_target := _slot(_pokemon("Conversion target", damage + 200), 1)
		state.players[1].active_pokemon = conversion_target
		var conversion_target_score := float(family.call(
			"score_interaction_target", conversion_target, {"id": "self_ko_target"}, context
		))
		checks.append(assert_true(
			conversion_target_score >= 2800.0 and conversion_target_score < 5000.0,
			"%s conversion fixture must stay between the conversion and exact-prize thresholds" % source_name
		))
		checks.append(assert_eq(
			_score(family, action, state),
			3400.0,
			"Direct family %s must preserve the Phantom Dive conversion reward" % source_name
		))
		checks.append(assert_true(
			_score(production, action, state) > _score(production, {"kind": "end_turn"}, state),
			"Production %s must keep a valid Curse Blast conversion above end_turn" % source_name
		))

	return run_checks(checks)


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _make_fixture(source_name: String, damage: int) -> Dictionary:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	var dragapult := _slot(_pokemon("Dragapult ex", 320, "ex"), 0)
	dragapult.attached_energy.assign([
		CardInstance.create(_energy("Fire Energy", "R"), 0),
		CardInstance.create(_energy("Psychic Energy", "P"), 0),
	])
	var drakloak := _slot(_pokemon("Drakloak", 100), 0)
	var source := _slot(_pokemon(source_name, 160), 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench.assign([drakloak, source])
	if source_name == "Dusclops":
		state.players[0].bench.append(_slot(_pokemon("Dusknoir", 160), 0))

	var closing_target := _slot(_pokemon("Closing ex", damage + 130, "ex"), 1)
	closing_target.damage_counters = closing_target.get_card_data().hp - damage
	var projected_target := _slot(_pokemon("Projected ex", damage + 200, "ex"), 1)
	projected_target.damage_counters = 0
	state.players[1].active_pokemon = closing_target
	state.players[1].bench.append(projected_target)
	return {
		"state": state,
		"source": source,
		"closing_target": closing_target,
		"projected_target": projected_target,
	}


func _set_prize_count(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for index: int in count:
		var prize := CardData.new()
		prize.name = "Prize %d" % index
		prize.name_en = prize.name
		prize.card_type = "Item"
		player.prizes.append(CardInstance.create(prize, player.player_index))


func _pokemon(name: String, hp: int, mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Stage 2" if name in ["Dragapult ex", "Dusknoir"] else ("Stage 1" if name in ["Drakloak", "Dusclops"] else "Basic")
	card.hp = hp
	card.mechanic = mechanic
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot
