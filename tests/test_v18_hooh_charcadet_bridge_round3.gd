class_name TestV18HoOhCharcadetBridgeRound3
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_seed_15403_ready_ho_oh_keeps_absolute_send_out_priority() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var ready_ho_oh := _real_slot("CSV10C_035")
	var charcadet := _real_slot("CSV9C_033")
	_attach_basic_fire(ready_ho_oh, 4)
	state.players[0].bench.assign([ready_ho_oh, charcadet])
	state.players[0].hand.append(_basic_fire())
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var ready_score: float = strategy.call("score_handoff_target", ready_ho_oh, step, context)
	var charcadet_score: float = strategy.call("score_handoff_target", charcadet, step, context)
	return run_checks([
		assert_eq(ready_score, 5600.0, "Seed 15403 ready Ho-Oh must keep the fixed 5600 send_out score"),
		assert_true(
			ready_score >= charcadet_score + 2000.0,
			"Seed 15403 ready Ho-Oh must decisively outrank the Charcadet bridge (ho_oh=%f charcadet=%f)" % [ready_score, charcadet_score]
		),
	])


func test_seed_15306_vessel_enables_zero_energy_charcadet_bridge() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var charcadet := _real_slot("CSV9C_033")
	_attach_basic_fire(rebuild_ho_oh, 2)
	state.players[0].bench.assign([rebuild_ho_oh, charcadet])
	state.players[0].hand.assign([_real_card("CSV6C_115"), _filler_card()])
	state.players[0].deck.assign([_basic_fire(), _basic_fire()])
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var charcadet_score: float = strategy.call("score_handoff_target", charcadet, step, context)
	var rebuild_score: float = strategy.call("score_handoff_target", rebuild_ho_oh, step, context)
	var non_send_out_score: float = strategy.call(
		"score_handoff_target",
		charcadet,
		{"id": "handoff"},
		context
	)
	charcadet.attached_energy.append(_basic_fire())
	var funded_charcadet_score: float = strategy.call("score_handoff_target", charcadet, step, context)
	return run_checks([
		assert_eq(charcadet_score, 3500.0, "Seed 15306 Vessel route should give Charcadet the Round 3 bridge score"),
		assert_true(
			charcadet_score >= rebuild_score + 2500.0,
			"Seed 15306 Charcadet must outrank the unready Ho-Oh while Vessel can find both missing Fire (charcadet=%f ho_oh=%f)" % [charcadet_score, rebuild_score]
		),
		assert_true(
			non_send_out_score < 1000.0,
			"Charcadet bridge must be limited to the exact send_out step (score=%f)" % non_send_out_score
		),
		assert_true(
			funded_charcadet_score < 1000.0,
			"Charcadet with attached Energy must not receive the zero-Energy bridge reward (score=%f)" % funded_charcadet_score
		),
	])


func test_no_immediate_fire_resource_does_not_reward_charcadet() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var charcadet := _real_slot("CSV9C_033")
	_attach_basic_fire(rebuild_ho_oh, 3)
	state.players[0].bench.assign([rebuild_ho_oh, charcadet])
	state.players[0].hand.append(_real_card("CSVH1C_034"))
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var dead_retrieval_score: float = strategy.call("score_handoff_target", charcadet, step, context)
	var rebuild_score: float = strategy.call("score_handoff_target", rebuild_ho_oh, step, context)

	var dead_vessel_state := _base_state()
	var vessel_ho_oh := _real_slot("CSV10C_035")
	var vessel_charcadet := _real_slot("CSV9C_033")
	_attach_basic_fire(vessel_ho_oh, 3)
	dead_vessel_state.players[0].bench.assign([vessel_ho_oh, vessel_charcadet])
	dead_vessel_state.players[0].hand.assign([_real_card("CSV6C_115"), _filler_card()])
	var dead_vessel_score: float = strategy.call(
		"score_handoff_target",
		vessel_charcadet,
		step,
		{"game_state": dead_vessel_state, "player_index": 0}
	)

	var insufficient_state := _base_state()
	var one_fire_ho_oh := _real_slot("CSV10C_035")
	var insufficient_charcadet := _real_slot("CSV9C_033")
	_attach_basic_fire(one_fire_ho_oh, 1)
	insufficient_state.players[0].bench.assign([one_fire_ho_oh, insufficient_charcadet])
	insufficient_state.players[0].hand.append(_basic_fire())
	var insufficient_fire_score: float = strategy.call(
		"score_handoff_target",
		insufficient_charcadet,
		step,
		{"game_state": insufficient_state, "player_index": 0}
	)
	return run_checks([
		assert_eq(state.players[0].discard_pile.size(), 0, "Energy Retrieval fixture must have no recoverable Fire"),
		assert_true(
			dead_retrieval_score < 1000.0,
			"Energy Retrieval without discarded basic Fire must not reward Charcadet (score=%f)" % dead_retrieval_score
		),
		assert_true(
			dead_retrieval_score < rebuild_score,
			"Without an immediate Fire route, Charcadet must stay below the unready Ho-Oh (charcadet=%f ho_oh=%f)" % [dead_retrieval_score, rebuild_score]
		),
		assert_true(
			dead_vessel_score < 1000.0,
			"Earthen Vessel without basic Fire in deck must not reward Charcadet (score=%f)" % dead_vessel_score
		),
		assert_true(
			insufficient_fire_score < 1000.0,
			"One hand Fire must not reward Charcadet when a one-Fire Ho-Oh still needs three (score=%f)" % insufficient_fire_score
		),
	])


func test_hand_fire_and_usable_retrieval_complete_identity_routes() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()

	var hand_state := _base_state()
	var hand_ho_oh := _real_slot("CSV10C_035")
	var english_charcadet := _english_charcadet_slot()
	_attach_basic_fire(hand_ho_oh, 3)
	hand_state.players[0].bench.assign([hand_ho_oh, english_charcadet])
	hand_state.players[0].hand.append(_basic_fire())
	var hand_score: float = strategy.call(
		"score_handoff_target",
		english_charcadet,
		{"id": "send_out"},
		{"game_state": hand_state, "player_index": 0}
	)

	var retrieval_state := _base_state()
	var retrieval_ho_oh := _real_slot("CSV10C_035")
	var uid_charcadet := _uid_charcadet_slot()
	_attach_basic_fire(retrieval_ho_oh, 2)
	retrieval_state.players[0].bench.assign([retrieval_ho_oh, uid_charcadet])
	retrieval_state.players[0].hand.append(_english_trainer("Energy Retrieval"))
	retrieval_state.players[0].discard_pile.assign([_basic_fire(), _basic_fire()])
	var retrieval_score: float = strategy.call(
		"score_handoff_target",
		uid_charcadet,
		{"id": "send_out"},
		{"game_state": retrieval_state, "player_index": 0}
	)
	return run_checks([
		assert_eq(hand_score, 3500.0, "English Charcadet should bridge when a hand Fire completes Ho-Oh"),
		assert_eq(retrieval_score, 3500.0, "UID Charcadet should bridge when English Energy Retrieval can recover both missing Fire"),
	])


func test_ready_ho_oh_suppresses_mew_and_charcadet_bridges() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var ready_ho_oh := _real_slot("CSV10C_035")
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var charcadet := _real_slot("CSV9C_033")
	var mew := _real_slot("151C_151")
	_attach_basic_fire(ready_ho_oh, 4)
	_attach_basic_fire(rebuild_ho_oh, 2)
	state.players[0].bench.assign([ready_ho_oh, rebuild_ho_oh, charcadet, mew])
	state.players[0].hand.assign([_basic_fire(), _basic_fire(), _real_card("CSV6C_115"), _filler_card()])
	state.players[0].deck.assign([_basic_fire(), _basic_fire()])
	state.players[0].discard_pile.assign([_basic_fire(), _basic_fire()])
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var ready_score: float = strategy.call("score_handoff_target", ready_ho_oh, step, context)
	var charcadet_score: float = strategy.call("score_handoff_target", charcadet, step, context)
	var mew_score: float = strategy.call("score_handoff_target", mew, step, context)
	return run_checks([
		assert_eq(ready_score, 5600.0, "A ready Ho-Oh must keep the absolute handoff score"),
		assert_true(charcadet_score < 3500.0, "A ready Ho-Oh must suppress the Charcadet bridge"),
		assert_true(mew_score < 3600.0, "A ready Ho-Oh must continue to suppress the existing Mew bridge"),
		assert_true(
			ready_score >= maxf(charcadet_score, mew_score) + 2000.0,
			"Ready Ho-Oh must decisively outrank every bridge (ho_oh=%f charcadet=%f mew=%f)" % [ready_score, charcadet_score, mew_score]
		),
	])


func test_existing_mew_bridge_stays_3600_and_suppresses_charcadet() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _base_state()
	var rebuild_ho_oh := _real_slot("CSV10C_035")
	var charcadet := _real_slot("CSV9C_033")
	var mew := _real_slot("151C_151")
	_attach_basic_fire(rebuild_ho_oh, 3)
	state.players[0].bench.assign([rebuild_ho_oh, charcadet, mew])
	state.players[0].hand.append(_basic_fire())
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "send_out"}
	var mew_score: float = strategy.call("score_handoff_target", mew, step, context)
	var charcadet_score: float = strategy.call("score_handoff_target", charcadet, step, context)
	return run_checks([
		assert_eq(mew_score, 3600.0, "Existing zero-Energy Mew bridge must keep its exact R2 score"),
		assert_true(
			charcadet_score < 3500.0,
			"A benched Mew must suppress the Charcadet bridge (charcadet=%f mew=%f)" % [charcadet_score, mew_score]
		),
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
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_real_card(ref))
	return slot


func _real_card(ref: String) -> CardInstance:
	var path := "res://data/bundled_user/cards/%s.json" % ref
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardInstance.create(CardData.from_dict(parsed), 0)


func _english_charcadet_slot() -> PokemonSlot:
	var card := CardData.new()
	card.name_en = "Charcadet"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "R"
	card.hp = 70
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot


func _uid_charcadet_slot() -> PokemonSlot:
	var card := CardData.new()
	card.set_code = "CSV9C"
	card.card_index = "033"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "R"
	card.hp = 70
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot


func _english_trainer(name_en: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name_en
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _filler_card() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Professor's Research"
	card.card_type = "Supporter"
	return CardInstance.create(card, 0)


func _attach_basic_fire(slot: PokemonSlot, count: int) -> void:
	for _index: int in count:
		slot.attached_energy.append(_basic_fire())


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name = "基本火能量"
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)
