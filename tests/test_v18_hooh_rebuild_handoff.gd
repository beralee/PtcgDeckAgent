class_name TestV18HoOhRebuildHandoff
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_ready_ho_oh_outranks_mew_handoff() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var ready_ho_oh := _real_slot("CSV10C_035")
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var mew := _real_slot("151C_151")
	_attach_basic_fire(ready_ho_oh, 4)
	_attach_basic_fire(rebuild_ho_oh, 2)
	state.players[0].bench.assign([ready_ho_oh, rebuild_ho_oh, mew])
	state.players[0].hand.append(_basic_fire())
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var ready_score: float = strategy.call("score_handoff_target", ready_ho_oh, step, context)
	var mew_score: float = strategy.call("score_handoff_target", mew, step, context)
	return run_checks([
		assert_true(
			ready_score >= mew_score + 2000.0,
			"A four-Fire CSV10C_035 must decisively outrank Mew ex for handoff (ho_oh=%f mew=%f)" % [ready_score, mew_score]
		),
	])


func test_zero_energy_mew_bridges_while_benched_ho_oh_rebuilds() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var mew := _real_slot("151C_151")
	_attach_basic_fire(rebuild_ho_oh, 2)
	state.players[0].bench.assign([rebuild_ho_oh, mew])
	state.players[0].hand.append(_basic_fire())
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var mew_score: float = strategy.call("score_handoff_target", mew, step, context)
	var rebuild_score: float = strategy.call("score_handoff_target", rebuild_ho_oh, step, context)
	return run_checks([
		assert_eq(mew.attached_energy.size(), 0, "The bridge reward is only for a zero-Energy Mew ex"),
		assert_true(
			mew_score >= rebuild_score + 2000.0,
			"Mew ex must be the temporary Active while a one-to-three-Fire Ho-Oh rebuilds (mew=%f ho_oh=%f)" % [mew_score, rebuild_score]
		),
	])


func test_mew_rebuild_reward_requires_hand_fire_and_pending_ho_oh() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var no_fire_state := _base_state()
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var no_fire_mew := _real_slot("151C_151")
	_attach_basic_fire(rebuild_ho_oh, 2)
	no_fire_state.players[0].bench.assign([rebuild_ho_oh, no_fire_mew])
	var no_fire_score: float = strategy.call(
		"score_handoff_target",
		no_fire_mew,
		{"id": "send_out"},
		{"game_state": no_fire_state, "player_index": 0}
	)

	var no_rebuild_state := _base_state()
	var no_rebuild_mew := _real_slot("151C_151")
	no_rebuild_state.players[0].bench.append(no_rebuild_mew)
	no_rebuild_state.players[0].hand.append(_basic_fire())
	var no_rebuild_score: float = strategy.call(
		"score_handoff_target",
		no_rebuild_mew,
		{"id": "send_out"},
		{"game_state": no_rebuild_state, "player_index": 0}
	)
	return run_checks([
		assert_true(
			no_fire_score < 1000.0,
			"Mew ex must not receive the rebuild reward without basic Fire in hand (score=%f)" % no_fire_score
		),
		assert_true(
			no_rebuild_score < 1000.0,
			"Mew ex must not receive the rebuild reward without a one-to-three-Fire benched Ho-Oh (score=%f)" % no_rebuild_score
		),
	])


func test_mew_and_terapagos_fire_attachment_remains_low_score() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var mew := _real_slot("151C_151")
	var terapagos := _real_slot("CSV9C_175")
	state.players[0].bench.assign([mew, terapagos])
	var mew_score: float = strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": _basic_fire(), "target_slot": mew},
		state,
		0
	)
	var terapagos_score: float = strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": _basic_fire(), "target_slot": terapagos},
		state,
		0
	)
	return run_checks([
		assert_true(mew_score <= -1700.0, "Mew ex Fire attachment must stay low (score=%f)" % mew_score),
		assert_true(terapagos_score <= -1700.0, "Terapagos ex Fire attachment must stay low (score=%f)" % terapagos_score),
	])


func _base_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	return state


func _real_slot(ref: String) -> PokemonSlot:
	var path := "res://data/bundled_user/cards/%s.json" % ref
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(CardData.from_dict(parsed), 0))
	return slot


func _attach_basic_fire(slot: PokemonSlot, count: int) -> void:
	for _index: int in count:
		slot.attached_energy.append(_basic_fire())


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)
