class_name TestBattleReplayStateRestorer
extends TestBase

const BattleReplayStateRestorerScript = preload("res://scripts/engine/BattleReplayStateRestorer.gd")


func _sample_card(card_name: String, owner_index: int, card_type: String = "Pokemon") -> Dictionary:
	return {
		"card_name": card_name,
		"instance_id": owner_index * 100 + card_name.length(),
		"owner_index": owner_index,
		"face_up": true,
		"card_type": card_type,
		"mechanic": "",
		"description": "",
		"stage": "Basic" if card_type == "Pokemon" else "",
		"hp": 120 if card_type == "Pokemon" else 0,
		"energy_type": "R" if card_type == "Pokemon" else "",
		"effect_id": "",
		"energy_provides": "R" if card_type == "Basic Energy" else "",
		"attacks": [{"name": "Test Attack", "cost": "R", "damage": "30", "text": "", "is_vstar_power": false}] if card_type == "Pokemon" else [],
		"abilities": [],
	}


func _sample_slot(card_name: String, owner_index: int) -> Dictionary:
	return {
		"pokemon_name": card_name,
		"prize_count": 1,
		"damage_counters": 2,
		"remaining_hp": 100,
		"max_hp": 120,
		"retreat_cost": 1,
		"attached_energy": [_sample_card("Fire Energy", owner_index, "Basic Energy")],
		"attached_tool": {},
		"status_conditions": {
			"poisoned": false,
			"burned": false,
			"asleep": false,
			"paralyzed": false,
			"confused": false,
		},
		"effects": [],
		"turn_played": 5,
		"turn_evolved": -1,
		"pokemon_stack": [_sample_card(card_name, owner_index)],
	}


func _sample_raw_replay_snapshot() -> Dictionary:
	return {
		"event_index": 12,
		"event_type": "state_snapshot",
		"turn_number": 6,
		"phase": "main",
		"player_index": 1,
		"snapshot_reason": "turn_start",
		"state": {
			"turn_number": 6,
			"phase": "main",
			"current_player_index": 1,
			"first_player_index": 0,
			"winner_index": -1,
			"win_reason": "",
			"energy_attached_this_turn": false,
			"supporter_used_this_turn": false,
			"stadium_played_this_turn": false,
			"retreat_used_this_turn": false,
			"stadium_card": {},
			"stadium_owner_index": -1,
			"players": [
				{
					"player_index": 0,
					"hand": [_sample_card("Opponent Card", 0, "Trainer")],
					"deck": [_sample_card("Opponent Deck", 0, "Trainer")],
					"prizes": [_sample_card("Opponent Prize", 0, "Trainer")],
					"discard_pile": [],
					"lost_zone": [],
					"active": _sample_slot("Opponent Active", 0),
					"bench": [],
				},
				{
					"player_index": 1,
					"hand": [
						_sample_card("Charmander", 1),
						_sample_card("Rare Candy", 1, "Trainer"),
						_sample_card("Ultra Ball", 1, "Trainer"),
						_sample_card("Switch", 1, "Trainer"),
					],
					"deck": [_sample_card("Top Deck", 1, "Trainer")],
					"prizes": [
						_sample_card("Prize A", 1, "Trainer"),
						_sample_card("Prize B", 1, "Trainer"),
					],
					"discard_pile": [_sample_card("Discarded Card", 1, "Trainer")],
					"lost_zone": [],
					"active": _sample_slot("Dragonite", 1),
					"bench": [_sample_slot("Bench Mon", 1)],
				},
			],
		},
	}


func test_state_restorer_rebuilds_live_state_from_raw_snapshot() -> String:
	var restorer = BattleReplayStateRestorerScript.new()
	var state: GameState = restorer.restore(_sample_raw_replay_snapshot())

	return run_checks([
		assert_eq(state.turn_number, 6, "Restored state should keep turn number"),
		assert_eq(state.current_player_index, 1, "Restored state should keep current actor"),
		assert_eq(state.phase, GameState.GamePhase.MAIN, "Restored state should map the phase correctly"),
		assert_eq(state.players[1].hand.size(), 4, "Restored state should rebuild acting-player hand"),
		assert_eq(state.players[1].active_pokemon.get_pokemon_name(), "Dragonite", "Restored state should rebuild the active slot"),
	])
