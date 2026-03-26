class_name TestGameStateCloner
extends TestBase

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")


func _make_test_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.energy_attached_this_turn = true
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var card_data := CardData.new()
	card_data.name = "Test Pokemon"
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 100
	var active_card := CardInstance.create(card_data, 0)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(active_card)
	active_slot.damage_counters = 30
	var energy_data := CardData.new()
	energy_data.name = "Lightning Energy"
	energy_data.card_type = "Basic Energy"
	energy_data.energy_provides = "L"
	active_slot.attached_energy.append(CardInstance.create(energy_data, 0))
	gsm.game_state.players[0].active_pokemon = active_slot
	var hand_card := CardInstance.create(card_data, 0)
	gsm.game_state.players[0].hand.append(hand_card)
	var deck_card := CardInstance.create(card_data, 0)
	gsm.game_state.players[0].deck.append(deck_card)
	var bench_card := CardInstance.create(card_data, 0)
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(bench_card)
	gsm.game_state.players[0].bench.append(bench_slot)
	return gsm


func test_clone_produces_independent_game_state() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	cloned.game_state.turn_number = 99
	cloned.game_state.current_player_index = 1
	cloned.game_state.players[0].hand.clear()
	cloned.game_state.players[0].active_pokemon.damage_counters = 999
	return run_checks([
		assert_eq(original.game_state.turn_number, 3, "原始 turn_number 不应被克隆体修改"),
		assert_eq(original.game_state.current_player_index, 0, "原始 current_player 不应被克隆体修改"),
		assert_eq(original.game_state.players[0].hand.size(), 1, "原始手牌不应被克隆体修改"),
		assert_eq(original.game_state.players[0].active_pokemon.damage_counters, 30, "原始伤害不应被克隆体修改"),
	])


func test_clone_preserves_field_values() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	return run_checks([
		assert_eq(cloned.game_state.turn_number, 3, "克隆体应保留 turn_number"),
		assert_eq(cloned.game_state.current_player_index, 0, "克隆体应保留 current_player_index"),
		assert_eq(cloned.game_state.phase, GameState.GamePhase.MAIN, "克隆体应保留 phase"),
		assert_true(cloned.game_state.energy_attached_this_turn, "克隆体应保留回合标志"),
		assert_eq(cloned.game_state.players.size(), 2, "克隆体应保留两个玩家"),
		assert_eq(cloned.game_state.players[0].hand.size(), 1, "克隆体应保留手牌"),
		assert_eq(cloned.game_state.players[0].deck.size(), 1, "克隆体应保留牌库"),
		assert_eq(cloned.game_state.players[0].bench.size(), 1, "克隆体应保留备战区"),
		assert_eq(cloned.game_state.players[0].active_pokemon.damage_counters, 30, "克隆体应保留伤害"),
		assert_eq(cloned.game_state.players[0].active_pokemon.attached_energy.size(), 1, "克隆体应保留附着能量"),
	])


func test_clone_shares_card_data_references() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	var orig_card_data: CardData = original.game_state.players[0].active_pokemon.get_card_data()
	var clone_card_data: CardData = cloned.game_state.players[0].active_pokemon.get_card_data()
	return run_checks([
		assert_eq(orig_card_data, clone_card_data, "CardData 应共享引用不拷贝"),
	])


func test_clone_card_instances_are_independent() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	cloned.game_state.players[0].active_pokemon.get_top_card().face_up = true
	return run_checks([
		assert_false(original.game_state.players[0].active_pokemon.get_top_card().face_up, "修改克隆体的 CardInstance 不应影响原始"),
	])


func test_cloned_gsm_has_working_subsystems() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	return run_checks([
		assert_not_null(cloned.rule_validator, "克隆体应有 rule_validator"),
		assert_not_null(cloned.effect_processor, "克隆体应有 effect_processor"),
		assert_not_null(cloned.coin_flipper, "克隆体应有 coin_flipper"),
	])
