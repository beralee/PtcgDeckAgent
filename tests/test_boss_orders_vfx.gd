class_name TestBossOrdersVfx
extends TestBase

const BOSS_ORDERS_EFFECT_ID := "8e1fa2c9018db938084c94c7c970d419"


func _make_pokemon_data(name: String, hp: int = 120) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.energy_type = "C"
	card.attacks = [{
		"name": "Test Attack",
		"cost": "C",
		"damage": "20",
		"text": "",
		"is_vstar_power": false,
	}]
	return card


func _make_boss_orders_data() -> CardData:
	var card := CardData.new()
	card.name = "Boss's Orders"
	card.name_en = "Boss's Orders"
	card.card_type = "Supporter"
	card.effect_id = BOSS_ORDERS_EFFECT_ID
	return card


func _make_slot(name: String, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_data(name), owner_index))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot("Active%d" % pi, pi)
		player.bench.append(_make_slot("Bench%d_0" % pi, pi))
		player.bench.append(_make_slot("Bench%d_1" % pi, pi))
		state.players.append(player)
	return state


func test_boss_orders_action_log_carries_vfx_payload_after_switch() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var boss := CardInstance.create(_make_boss_orders_data(), 0)
	player.hand.append(boss)
	var chosen_target: PokemonSlot = opponent.bench[1]

	var used := gsm.play_trainer(0, boss, [{
		"opponent_bench_target": [chosen_target],
	}])
	var action: GameAction = gsm.action_log.back() if not gsm.action_log.is_empty() else null
	var target_spec: Dictionary = action.data.get("target", {}) if action != null else {}

	return run_checks([
		assert_true(used, "Boss's Orders should resolve through the normal trainer path"),
		assert_true(opponent.active_pokemon == chosen_target, "Selected bench Pokemon should become the opponent active Pokemon"),
		assert_true(action != null and action.action_type == GameAction.ActionType.PLAY_TRAINER, "Boss's Orders should log a trainer action"),
		assert_eq(str(action.data.get("trainer_vfx", "")) if action != null else "", "boss_orders", "Boss's Orders action should carry a trainer VFX marker"),
		assert_eq(str(target_spec.get("slot_kind", "")), "active", "VFX target should point at the post-switch active Pokemon"),
		assert_eq(int(target_spec.get("player_index", -1)), 1, "VFX target should identify the opponent"),
		assert_eq(str(target_spec.get("pokemon_name", "")), "Bench1_1", "VFX target should preserve the chosen Pokemon name"),
		assert_eq(int(action.data.get("source_player_index", -1)) if action != null else -1, 0, "VFX source player should be the trainer user"),
	])
