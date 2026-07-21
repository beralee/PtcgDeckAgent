class_name TestV18HoOhDyingHearthflameRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018539


func test_dying_hearthflame_rebuild_attach_stays_below_end_turn() -> String:
	var strategy := _strategy()
	var state := _state()
	var hearthflame := _hearthflame(0)
	hearthflame.damage_counters = 180
	state.players[0].active_pokemon = hearthflame
	state.players[0].bench.assign([_ho_oh(2)])
	var attach_score := _attach_score(strategy, state, hearthflame)
	var end_score := float(strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0))
	return assert_true(
		attach_score < end_score,
		"A 30 HP Hearthflame must not outrank end_turn while Ho-Oh rebuilds (attach=%f end=%f)" % [attach_score, end_score]
	)


func test_healthy_hearthflame_keeps_normal_attachment_score() -> String:
	var strategy := _strategy()
	var state := _state()
	var hearthflame := _hearthflame(0)
	state.players[0].active_pokemon = hearthflame
	state.players[0].bench.assign([_ho_oh(2)])
	var attach_score := _attach_score(strategy, state, hearthflame)
	var dying_hearthflame := _hearthflame(0)
	dying_hearthflame.damage_counters = 180
	state.players[0].active_pokemon = dying_hearthflame
	var dying_score := _attach_score(strategy, state, dying_hearthflame)
	return assert_true(
		attach_score > dying_score,
		"Healthy Hearthflame must stay above the dying rebuild attachment (healthy=%f dying=%f)" % [attach_score, dying_score]
	)


func test_dying_hearthflame_is_exempt_when_attach_completes_attack() -> String:
	var strategy := _strategy()
	var state := _state()
	var hearthflame := _hearthflame(2)
	hearthflame.damage_counters = 180
	state.players[0].active_pokemon = hearthflame
	state.players[0].bench.assign([_ho_oh(2)])
	var attach_score := _attach_score(strategy, state, hearthflame)
	var blocked_hearthflame := _hearthflame(0)
	blocked_hearthflame.damage_counters = 180
	state.players[0].active_pokemon = blocked_hearthflame
	var blocked_score := _attach_score(strategy, state, blocked_hearthflame)
	return assert_true(
		attach_score > blocked_score,
		"A dying Hearthflame that becomes attack-ready must stay above the blocked rebuild attachment (ready=%f blocked=%f)" % [attach_score, blocked_score]
	)


func _attach_score(strategy: RefCounted, state: GameState, target: PokemonSlot) -> float:
	return float(strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": _basic_fire(), "target_slot": target},
		state,
		0
	))


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 21
	state.phase = GameState.GamePhase.MAIN
	return state


func _hearthflame(energy_count: int) -> PokemonSlot:
	var card := CardData.new()
	card.name_en = "Hearthflame Mask Ogerpon ex"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "R"
	card.hp = 210
	card.attacks = [{"name": "Mighty Flame", "cost": "RRR", "damage": "140"}]
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	for _index in energy_count:
		slot.attached_energy.append(_basic_fire())
	return slot


func _ho_oh(energy_count: int) -> PokemonSlot:
	var card := CardData.new()
	card.name_en = "Ethan's Ho-Oh ex"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "R"
	card.hp = 230
	card.attacks = [{"name": "Shining Feather", "cost": "RRRR", "damage": "160"}]
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	for _index in energy_count:
		slot.attached_energy.append(_basic_fire())
	return slot


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)
