class_name TestInvalidActionReasons
extends TestBase

const EffectNestBallScript := preload("res://scripts/effects/trainer_effects/EffectNestBall.gd")
const EffectBuddyPoffinScript := preload("res://scripts/effects/trainer_effects/EffectBuddyPoffin.gd")
const EffectUltraBallScript := preload("res://scripts/effects/trainer_effects/EffectUltraBall.gd")
const EffectRareCandyScript := preload("res://scripts/effects/trainer_effects/EffectRareCandy.gd")


func _make_state(turn: int = 2, first: int = 0, current: int = 0) -> GameState:
	var state := GameState.new()
	state.turn_number = turn
	state.first_player_index = first
	state.current_player_index = current
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
		player.active_pokemon = _make_slot(_make_pokemon("Active %d" % pi, "Basic", "", pi), turn - 1)
	return state


func _make_slot(card: CardInstance, turn_played: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = turn_played
	return slot


func _make_card(name: String, card_type: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _make_pokemon(name: String, stage: String, evolves_from: String = "", owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.evolves_from = evolves_from
	data.hp = 80
	data.energy_type = "C"
	return CardInstance.create(data, owner)


func _fill_bench(player: PlayerState) -> void:
	for i: int in 5:
		player.bench.append(_make_slot(_make_pokemon("Bench %d" % i, "Basic", "", player.player_index)))


func test_supporter_already_used_has_reason() -> String:
	var state := _make_state()
	state.supporter_used_this_turn = true
	var reason := RuleValidator.new().get_play_supporter_unusable_reason(state, 0, _make_card("博士的研究", "Supporter"))
	return run_checks([
		assert_str_contains(reason, "支援者", "Supporter once-per-turn block should name the rule"),
		assert_str_contains(reason, "已经", "Supporter once-per-turn block should explain it was already used"),
	])


func test_first_player_first_turn_supporter_has_reason() -> String:
	var state := _make_state(1, 0, 0)
	var reason := RuleValidator.new().get_play_supporter_unusable_reason(state, 0, _make_card("博士的研究", "Supporter"))
	return run_checks([
		assert_str_contains(reason, "先攻", "First player first turn block should mention first player"),
		assert_str_contains(reason, "支援者", "First player first turn block should mention Supporter"),
	])


func test_energy_already_attached_has_reason() -> String:
	var state := _make_state()
	state.energy_attached_this_turn = true
	var reason := RuleValidator.new().get_attach_energy_unusable_reason(state, 0, _make_card("基本水能量", "Basic Energy"))
	return run_checks([
		assert_str_contains(reason, "能量", "Energy attachment block should mention Energy"),
		assert_str_contains(reason, "已经", "Energy attachment block should explain the turn limit"),
	])


func test_bench_full_blocks_basic_with_reason() -> String:
	var state := _make_state()
	_fill_bench(state.players[0])
	var reason := RuleValidator.new().get_play_basic_to_bench_unusable_reason(
		state,
		0,
		_make_pokemon("咕咕", "Basic")
	)
	return run_checks([
		assert_str_contains(reason, "备战区", "Bench-full block should mention Bench"),
		assert_str_contains(reason, "满", "Bench-full block should say it is full"),
	])


func test_same_stadium_has_reason() -> String:
	var state := _make_state()
	state.stadium_card = _make_card("零之大空洞", "Stadium")
	var incoming := _make_card("零之大空洞", "Stadium")
	var reason := RuleValidator.new().get_play_stadium_unusable_reason(state, 0, incoming)
	return run_checks([
		assert_str_contains(reason, "同名", "Same Stadium block should mention same-name Stadium"),
		assert_str_contains(reason, "竞技场", "Same Stadium block should mention Stadium"),
	])


func test_tool_target_already_has_tool_reason() -> String:
	var state := _make_state()
	var target := state.players[0].active_pokemon
	target.attached_tool = _make_card("勇气护符", "Tool")
	var reason := RuleValidator.new().get_attach_tool_unusable_reason(
		state,
		0,
		target,
		EffectProcessor.new(CoinFlipper.new()),
		_make_card("极限腰带", "Tool")
	)
	return run_checks([
		assert_str_contains(reason, "道具", "Tool block should mention Tool"),
		assert_str_contains(reason, "已经", "Tool block should explain target already has one"),
	])


func test_nest_ball_bench_full_reason() -> String:
	var state := _make_state()
	_fill_bench(state.players[0])
	var card := _make_card("巢穴球", "Item")
	var reason := EffectNestBallScript.new().get_unusable_reason(card, state)
	return run_checks([
		assert_str_contains(reason, "备战区", "Nest Ball should explain Bench-full failure"),
	])


func test_buddy_poffin_bench_full_reason() -> String:
	var state := _make_state()
	_fill_bench(state.players[0])
	var card := _make_card("宝芬", "Item")
	var reason := EffectBuddyPoffinScript.new().get_unusable_reason(card, state)
	return run_checks([
		assert_str_contains(reason, "备战区", "Buddy-Buddy Poffin should explain Bench-full failure"),
	])


func test_ultra_ball_discard_cost_reason() -> String:
	var state := _make_state()
	var ultra_ball := _make_card("高级球", "Item")
	state.players[0].hand = [ultra_ball, _make_card("手牌1", "Item")]
	state.players[0].deck = [_make_pokemon("任意宝可梦", "Basic")]
	var reason := EffectUltraBallScript.new().get_unusable_reason(ultra_ball, state)
	return run_checks([
		assert_str_contains(reason, "弃", "Ultra Ball should explain discard cost failure"),
		assert_str_contains(reason, "2", "Ultra Ball should mention the 2-card cost"),
	])


func test_rare_candy_no_valid_target_reason() -> String:
	var state := _make_state()
	var rare_candy := _make_card("神奇糖果", "Item")
	state.players[0].hand = [rare_candy]
	var reason := EffectRareCandyScript.new().get_unusable_reason(rare_candy, state)
	return run_checks([
		assert_str_contains(reason, "没有可以", "Rare Candy should explain there is no valid evolution target"),
	])
