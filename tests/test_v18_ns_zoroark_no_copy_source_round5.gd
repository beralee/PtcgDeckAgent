class_name TestV18NsZoroarkNoCopySourceRound5
extends TestBase

const NS_ZOROARK_SCRIPT := preload("res://scripts/ai/DeckStrategyNsZoroark.gd")


func test_night_joker_without_benched_copy_source_loses_to_end_turn() -> String:
	var strategy := NS_ZOROARK_SCRIPT.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(_make_zoroark())
	state.players[1].active_pokemon = _make_slot(_make_defender())
	var night_joker := {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Night Joker",
		"projected_damage": 0,
		"projected_knockout": false,
	}
	var night_joker_score: float = strategy.call("score_action_absolute", night_joker, state, 0)
	var end_turn_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	return run_checks([
		assert_true(night_joker_score < end_turn_score, "A source-less Night Joker must score below end_turn"),
		assert_true(night_joker_score <= -2000.0, "A source-less Night Joker must be hard-rejected by the picker"),
	])


func test_benched_copy_source_keeps_attack_and_interaction_routes_positive() -> String:
	var strategy := NS_ZOROARK_SCRIPT.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(_make_zoroark())
	var reshiram := _make_reshiram()
	player.bench.append(_make_slot(reshiram))
	state.players[1].active_pokemon = _make_slot(_make_defender())
	var night_joker := {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"attack_name": "Night Joker",
		"projected_damage": 0,
		"projected_knockout": false,
	}
	var attack_score: float = strategy.call("score_action_absolute", night_joker, state, 0)
	var interaction_score: float = strategy.call(
		"score_interaction_target",
		{"attack": reshiram.attacks[1]},
		{"id": "copied_attack"},
		{"game_state": state, "player_index": 0}
	)
	return run_checks([
		assert_true(attack_score > 0.0, "A Night Joker with a legal Benched N attack source must stay positive"),
		assert_true(interaction_score > 900.0, "The copied_attack interaction route must keep its positive scoring"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _make_slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, 0))
	return slot


func _make_zoroark() -> CardData:
	return _make_pokemon("N's Zoroark ex", "Stage 1", [
		{"name": "Night Joker", "cost": "DD", "damage": "0", "text": "Choose 1 of your Benched N's Pokemon's attacks and use it as this attack."},
	])


func _make_reshiram() -> CardData:
	return _make_pokemon("N's Reshiram", "Basic", [
		{"name": "Powerful Rage", "cost": "RL", "damage": "20x", "text": ""},
		{"name": "Virtuous Flame", "cost": "RRLC", "damage": "170", "text": ""},
	])


func _make_defender() -> CardData:
	return _make_pokemon("Defender", "Basic", [])


func _make_pokemon(name: String, stage: String, attacks: Array[Dictionary]) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.energy_type = "D"
	card.hp = 280 if stage != "Basic" else 130
	card.attacks = attacks
	return card
