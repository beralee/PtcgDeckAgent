extends TestBase
const Bridge := preload("res://scripts/ui/battle/visuals/ArenaHandEventBridge.gd")

func _state() -> GameState:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 3
	for i in range(2):
		var player := PlayerState.new()
		player.player_index = i
		state.players.append(player)
		for j in range(8):
			var data := CardData.new()
			data.name = "Private identity %d/%d"%[i,j]
			data.card_type = "Basic Energy"
			player.deck.append(CardInstance.create(data,i))
		for j in range(2): player.hand.append(player.deck.pop_back())
	return state

func test_equal_hand_counts_still_animate_returns_and_draws_once() -> String:
	var state := _state()
	var bridge := Bridge.new()
	bridge.prime(state,0)
	for player in state.players:
		player.deck.append_array(player.hand)
		player.hand.clear()
		for j in range(2): player.hand.append(player.deck.pop_front())
	var action := GameAction.create(GameAction.ActionType.DRAW_CARD,0,{"count":2},3,"draw")
	var events := bridge.capture(action,state,0)
	var returns := 0
	var draws := 0
	for event in events:
		if event.direction == "return": returns += event.count
		if event.direction == "draw": draws += event.count
	var private_keys := false
	for event in events:
		var keys := event.keys()
		keys.sort()
		if keys != ["count","direction","mine"]: private_keys = true
	return run_checks([
		assert_eq(returns,4,"Both old hands return even when hand counts stay equal"),
		assert_eq(draws,4,"Both replacement hands draw"),
		assert_false(private_keys,"Renderer accepts only count/direction/role, never identity"),
		assert_true(bridge.capture(action,state,0).is_empty(),"Duplicate action capture cannot duplicate flights"),
	])

func test_view_change_rebinds_without_replaying_old_transfers() -> String:
	var state := _state()
	var bridge := Bridge.new()
	bridge.prime(state,0)
	state.players[1].hand.append(state.players[1].deck.pop_front())
	var rebound := bridge.capture(null,state,1)
	state.players[1].hand.append(state.players[1].deck.pop_front())
	var events := bridge.capture(null,state,1)
	return run_checks([
		assert_true(rebound.is_empty(),"A new viewpoint establishes a fresh baseline"),
		assert_eq(events,[{"mine":true,"count":1,"direction":"draw"}],"Next draw belongs to the new local role"),
	])

func test_projection_excludes_identity_and_unrelated_moves() -> String:
	var events: Array[Dictionary] = [
		{"kind":"zone_transfer","owner_index":1,"count":3,"source_zone":"p1.deck","target_zone":"p1.hand","cards":["secret"],"card_names":["private"],"instance_ids":[123]},
		{"kind":"zone_transfer","owner_index":0,"count":2,"source_zone":"p0.hand","target_zone":"p0.discard","semantic":"discard"},
		{"kind":"zone_transfer","owner_index":0,"count":2,"source_zone":"p0.hand","target_zone":"p0.discard","semantic":"trainer_play"},
		{"kind":"zone_transfer","owner_index":0,"count":3,"source_zone":"p0.discard","target_zone":"p0.deck"},
		{"kind":"zone_transfer","owner_index":0,"count":1,"source_zone":"p0.prize.0","target_zone":"p0.hand"},
		{"kind":"unknown","owner_index":0,"count":7,"source_zone":"p0.deck","target_zone":"p0.hand"},
	]
	return assert_eq(Bridge.project(events,0),[
		{"mine":false,"count":3,"direction":"draw"},
		{"mine":true,"count":2,"direction":"discard"},
	],"No private fields, trainer duplicates, recovery-to-deck or prize animations leak into the hand batch")

func test_setup_refreshes_baseline_without_running_hand_animation() -> String:
	var state := _state()
	state.phase = GameState.GamePhase.SETUP
	var bridge := Bridge.new()
	bridge.prime(state,0)
	state.players[0].hand.append(state.players[0].deck.pop_front())
	var setup := bridge.capture(null,state,0)
	state.phase = GameState.GamePhase.MAIN
	return run_checks([
		assert_true(setup.is_empty(),"Setup remains under its existing presentation owner"),
		assert_true(bridge.capture(null,state,0).is_empty(),"Setup draw is not replayed after entering battle"),
	])
