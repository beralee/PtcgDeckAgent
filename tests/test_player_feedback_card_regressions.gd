class_name TestPlayerFeedbackCardRegressions
extends TestBase

const WELLS_PRING_EFFECT_ID := "14cf8080c35f652fe13a579f1b50542a"
const YANMEGA_EFFECT_ID := "88367894eb8e5dc6ae6b2b8350eb75f9"
const FEZANDIPITI_EFFECT_ID := "ab6c3357e2b8a8385a68da738f41e0c1"
const FESTIVAL_GROUNDS_EFFECT_ID := "357d55b54ded5db071b55ebe165749fc"
const RESCUE_BOARD_EFFECT_ID := "0b4cc131a19862f92acf71494f29a0ed"
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const ScenarioStateSnapshotScript = preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")
const ScenarioStateRestorerScript = preload("res://scripts/engine/scenario/ScenarioStateRestorer.gd")
const BattleReplayStateRestorerScript = preload("res://scripts/engine/BattleReplayStateRestorer.gd")
const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")


func test_wellspring_attacks_keep_retreat_lock_scoped_to_sob_defender() -> String:
	var card := _load_card("res://data/bundled_user/cards/CSV8C_067.json")
	if card == null:
		return "CSV8C_067 should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var attacker := _slot(card, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker

	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	processor.execute_attack_effect(attacker, 0, defender, state)
	var first_locked_defender := _has_retreat_lock(defender)
	var first_locked_attacker := _has_retreat_lock(attacker)
	defender.effects.clear()
	attacker.effects.clear()
	processor.execute_attack_effect(attacker, 1, defender, state)

	return run_checks([
		assert_eq(card.effect_id, WELLS_PRING_EFFECT_ID, "CSV8C_067 should retain the audited effect identity"),
		assert_eq(first_effects.size(), 1, "Sob should own exactly one attack effect"),
		assert_eq(second_effects.size(), 1, "Torrential Pump should own exactly one independent attack effect"),
		assert_true(first_locked_defender, "Sob should lock only the Defending Pokemon"),
		assert_false(first_locked_attacker, "Sob must never bind the retreat lock to Wellspring Ogerpon itself"),
		assert_false(_has_retreat_lock(defender), "Torrential Pump must not inherit Sob's retreat lock"),
		assert_false(_has_retreat_lock(attacker), "Torrential Pump must not place a retreat lock on its user"),
	])


func test_yanmega_jet_cyclone_requires_three_grass_and_one_colorless_for_every_print() -> String:
	var checks: Array[String] = []
	var bundled_payload: Dictionary = {}
	for card_index: String in ["003", "229", "262"]:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % card_index
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(card_path))
		if card_index == "003" and parsed is Dictionary:
			bundled_payload = (parsed as Dictionary).duplicate(true)
		var card := CardData.from_dict(parsed) if parsed is Dictionary else null
		checks.append(assert_not_null(card, "CSV10C_%s should load" % card_index))
		if card == null:
			continue
		checks.append(assert_eq(card.effect_id, YANMEGA_EFFECT_ID, "Every Yanmega print should share one effect identity"))
		checks.append(assert_eq(str(card.attacks[0].get("cost", "")), "GGGC", "Jet Cyclone should cost Grass, Grass, Grass, Colorless"))

	var battle_card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	if battle_card == null:
		return run_checks(checks)
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.register_pokemon_card(battle_card)
	var yanmega := _slot(battle_card, 0)
	gsm.game_state.players[0].active_pokemon = yanmega
	yanmega.attached_energy = [
		_energy("Grass A", "G", 0),
		_energy("Grass B", "G", 0),
		_energy("Grass C", "G", 0),
	]
	var usable_with_three_grass := gsm.can_use_attack(0, 0)
	yanmega.attached_energy.append(_energy("Colorless", "C", 0))
	var usable_with_full_cost := gsm.can_use_attack(0, 0)
	checks.append(assert_false(usable_with_three_grass, "Three Grass Energy alone must not pay Jet Cyclone"))
	checks.append(assert_true(usable_with_full_cost, "Three Grass plus one Colorless should pay Jet Cyclone"))
	var cached_payload := bundled_payload.duplicate(true)
	cached_payload["bundled_implementation_revision"] = 1
	if cached_payload.get("attacks", []) is Array and not (cached_payload.get("attacks", []) as Array).is_empty():
		(cached_payload["attacks"] as Array)[0]["cost"] = "GGG"
	var db := CardDatabaseScript.new()
	var should_upgrade_cache := bool(db.call("_bundled_card_json_has_missing_implementation_data", bundled_payload, cached_payload))
	db.free()
	checks.append(assert_eq(int(bundled_payload.get("bundled_implementation_revision", 0)), 2, "Yanmega bundled data should carry a migration revision"))
	checks.append(assert_true(should_upgrade_cache, "Existing revision-1 Yanmega caches must be replaced by the corrected bundled data"))
	return run_checks(checks)


func test_yanmega_retreat_modifiers_follow_stage_and_tool_rules() -> String:
	var yanmega_card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	var latias_card := _load_card("res://data/bundled_user/cards/CSV9C_078.json")
	if yanmega_card == null or latias_card == null:
		return "Yanmega ex and Latias ex bundled cards should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(yanmega_card)
	processor.register_pokemon_card(latias_card)
	var state := _make_state()
	var yanmega := _slot(yanmega_card, 0)
	state.players[0].active_pokemon = yanmega
	state.players[0].bench.append(_slot(latias_card, 0))
	var with_skyliner := processor.get_effective_retreat_cost(yanmega, state)

	var rescue_board_data := CardData.new()
	rescue_board_data.name = "Rescue Board"
	rescue_board_data.card_type = "Tool"
	rescue_board_data.effect_id = RESCUE_BOARD_EFFECT_ID
	yanmega.attached_tool = CardInstance.create(rescue_board_data, 0)
	var with_rescue_board := processor.get_effective_retreat_cost(yanmega, state)

	return run_checks([
		assert_eq(with_skyliner, 1, "Latias ex affects Basic Pokemon only; Stage 1 Yanmega must still pay one retreat"),
		assert_eq(with_rescue_board, 0, "Rescue Board should reduce Yanmega's printed one retreat to zero"),
	])


func test_festival_lead_runs_one_pokemon_check_after_the_second_attack_only() -> String:
	var dipplin_card := _load_card("res://data/bundled_user/cards/CSV8C_024.json")
	var froslass_card := _load_card("res://data/bundled_user/cards/CSV7C_059.json")
	if dipplin_card == null or froslass_card == null:
		return "Dipplin and Froslass bundled cards should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	_add_dummy_prizes(gsm.game_state)
	var state := gsm.game_state
	var attacker := _slot(dipplin_card, 0)
	var froslass := _slot(froslass_card, 0)
	var checked_target_data := _pokemon("Ability Target", 200, "Basic", "ability_target")
	checked_target_data.abilities = [{"name": "Visible Ability", "text": ""}]
	var checked_target := _slot(checked_target_data, 1)
	state.players[0].active_pokemon = attacker
	state.players[0].bench = [froslass]
	state.players[1].active_pokemon = _slot(_pokemon("Festival Defender", 300), 1)
	state.players[1].bench = [checked_target]
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	attacker.attached_energy = [_energy("Grass", "G", 0)]
	var stadium_data := CardData.new()
	stadium_data.name = "Festival Grounds"
	stadium_data.card_type = "Stadium"
	stadium_data.effect_id = FESTIVAL_GROUNDS_EFFECT_ID
	state.stadium_card = CardInstance.create(stadium_data, 0)
	state.stadium_owner_index = 0
	gsm.effect_processor.register_pokemon_card(dipplin_card)
	gsm.effect_processor.register_pokemon_card(froslass_card)

	var first_attack := gsm.use_attack(0, 0)
	var damage_after_first := checked_target.damage_counters
	var second_attack := gsm.use_attack(0, 0)
	var check_actions := gsm.action_log.filter(func(action: GameAction) -> bool:
		return action.action_type == GameAction.ActionType.POKEMON_CHECK
	)

	return run_checks([
		assert_true(first_attack, "Festival Lead's first attack should resolve"),
		assert_eq(damage_after_first, 0, "The first Festival Lead attack must not end the turn or run Pokemon Check"),
		assert_true(second_attack, "Festival Lead's second attack should resolve"),
		assert_eq(checked_target.damage_counters, 10, "Froslass should place one damage counter in the single end-of-turn Pokemon Check"),
		assert_eq(check_actions.size(), 1, "The two-attack turn must emit exactly one Pokemon Check"),
	])


func test_poison_check_knockout_does_not_unlock_fezandipiti_flip_the_script() -> String:
	var fezandipiti_card := _load_card("res://data/bundled_user/cards/CSV8C_135.json")
	if fezandipiti_card == null:
		return "CSV8C_135 should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	_add_dummy_prizes(gsm.game_state)
	var state := gsm.game_state
	state.turn_number = 3
	state.current_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	var victim := _slot(_pokemon("Poisoned victim", 10), 0)
	victim.status_conditions["poisoned"] = true
	var replacement := _slot(_pokemon("Replacement", 100), 0)
	var fezandipiti := _slot(fezandipiti_card, 0)
	state.players[0].active_pokemon = victim
	state.players[0].bench = [replacement, fezandipiti]
	state.players[1].active_pokemon = _slot(_pokemon("Opponent Active", 100), 1)
	state.players[0].deck = [
		_dummy_card("Draw 0", 0),
		_dummy_card("Draw 1", 0),
		_dummy_card("Draw 2", 0),
		_dummy_card("Draw 3", 0),
	]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	gsm.effect_processor.register_pokemon_card(fezandipiti_card)

	gsm.end_turn(1)
	var prize_taken := gsm.resolve_take_prize(1, 0)
	var replacement_sent := gsm.send_out_pokemon(0, replacement)
	var ability_used := gsm.use_ability(0, fezandipiti, 0)

	return run_checks([
		assert_true(prize_taken, "Poison knockout should still award the opponent a Prize"),
		assert_true(replacement_sent, "Poison knockout should complete the replacement flow"),
		assert_eq(state.current_player_index, 0, "The poisoned player's next turn should begin"),
		assert_false(ability_used, "A knockout during Pokemon Check is between turns, not during the opponent's previous turn"),
	])


func test_opponent_attack_knockout_unlocks_fezandipiti_and_survives_state_boundaries() -> String:
	var fezandipiti_card := _load_card("res://data/bundled_user/cards/CSV8C_135.json")
	if fezandipiti_card == null:
		return "CSV8C_135 should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	state.turn_number = 2
	state.current_player_index = 1
	state.phase = GameState.GamePhase.ATTACK
	state.record_knockout_against(0)
	state.turn_number = 3
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var fezandipiti := _slot(fezandipiti_card, 0)
	state.players[0].bench.append(fezandipiti)
	state.players[0].deck = [
		_dummy_card("Draw A", 0),
		_dummy_card("Draw B", 0),
		_dummy_card("Draw C", 0),
	]
	gsm.effect_processor.register_pokemon_card(fezandipiti_card)

	var clone := GameStateClonerScript.new().clone_gsm(gsm)
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(state)
	var scenario_restore: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var restored_gsm: GameStateMachine = scenario_restore.get("gsm")
	var replay_state: GameState = BattleReplayStateRestorerScript.new().restore({"state": snapshot})
	var ability_used := gsm.use_ability(0, fezandipiti, 0)

	return run_checks([
		assert_true(clone.game_state.was_knocked_out_during_opponents_previous_turn(0), "AI clones must preserve qualifying knockout provenance"),
		assert_not_null(restored_gsm, "Scenario snapshot should restore after adding knockout provenance"),
		assert_true(restored_gsm != null and restored_gsm.game_state.was_knocked_out_during_opponents_previous_turn(0), "Scenario restore must preserve qualifying knockout provenance"),
		assert_true(replay_state.was_knocked_out_during_opponents_previous_turn(0), "Replay restore must preserve qualifying knockout provenance"),
		assert_true(ability_used, "An attack knockout during the opponent's turn should unlock Flip the Script"),
		assert_eq(state.players[0].hand.size(), 3, "A legally unlocked Flip the Script should draw exactly three cards"),
	])


func _load_card(path: String) -> CardData:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return null
	return CardData.from_dict(parsed)


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot(_pokemon("Active %d" % player_index, 200), player_index)
		player.bench = [_slot(_pokemon("Bench %d" % player_index, 100), player_index)]
		state.players.append(player)
	return state


func _pokemon(
	name: String,
	hp: int,
	stage: String = "Basic",
	effect_id: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.effect_id = effect_id
	card.retreat_cost = 1
	card.attacks = [{"name": "Strike", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot


func _energy(name: String, energy_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _dummy_card(name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)


func _add_dummy_prizes(state: GameState, count: int = 6) -> void:
	for player_index: int in state.players.size():
		state.players[player_index].prizes.clear()
		for prize_index: int in count:
			state.players[player_index].prizes.append(_dummy_card("Prize %d-%d" % [player_index, prize_index], player_index))


func _has_retreat_lock(slot: PokemonSlot) -> bool:
	return slot.effects.any(func(effect_data: Dictionary) -> bool:
		return str(effect_data.get("type", "")) == "retreat_lock"
	)
