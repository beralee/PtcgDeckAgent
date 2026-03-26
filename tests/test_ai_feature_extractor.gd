class_name TestAIFeatureExtractor
extends TestBase

const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_ai_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 4
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	CardInstance.reset_id_counter()
	return gsm


func _make_pokemon_card(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	attacks: Array = []
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.hp = 70
	card.attacks.clear()
	for attack: Variant in attacks:
		if attack is Dictionary:
			card.attacks.append(attack.duplicate(true))
	return card


func _make_energy_card(name: String, energy_type: String = "L") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return CardInstance.create(card, 0)


func _make_trainer_card(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func test_ai_feature_extractor_marks_attach_target_and_attack_readiness() -> String:
	var extractor := AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Active", "Basic", "", [{
		"name": "Hit",
		"cost": "C",
		"damage": "10",
	}]), 0))
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Bench", "Basic"), 0))
	player.active_pokemon = active_slot
	player.bench = [bench_slot]

	var active_features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "attach_energy",
		"card": _make_energy_card("Lightning Energy"),
		"target_slot": active_slot,
	})
	var bench_features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "attach_energy",
		"card": _make_energy_card("Lightning Energy"),
		"target_slot": bench_slot,
	})

	return run_checks([
		assert_true(bool(active_features.get("is_active_target", false)), "Active attach should be marked as an active target"),
		assert_false(bool(active_features.get("is_bench_target", true)), "Active attach should not be marked as a bench target"),
		assert_true(bool(active_features.get("improves_attack_readiness", false)), "Active attach should expose immediate attack readiness"),
		assert_false(bool(bench_features.get("is_active_target", true)), "Bench attach should not be marked as an active target"),
		assert_true(bool(bench_features.get("is_bench_target", false)), "Bench attach should be marked as a bench target"),
		assert_false(bool(bench_features.get("improves_attack_readiness", true)), "Bench attach should not expose immediate attack readiness"),
	])


func test_ai_feature_extractor_marks_attach_target_when_later_attack_becomes_available() -> String:
	var extractor := AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card("Active", "Basic", "", [
		{
			"name": "Quick Hit",
			"cost": "RRR",
			"damage": "50",
		},
		{
			"name": "Heavy Hit",
			"cost": "RRRR",
			"damage": "120",
		},
	]), 0))
	active_slot.attached_energy.append(_make_energy_card("Fire Energy", "R"))
	active_slot.attached_energy.append(_make_energy_card("Fire Energy", "R"))
	active_slot.attached_energy.append(_make_energy_card("Fire Energy", "R"))
	player.active_pokemon = active_slot
	player.bench = []

	var features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "attach_energy",
		"card": _make_energy_card("Fire Energy", "R"),
		"target_slot": active_slot,
	})

	return run_checks([
		assert_true(bool(features.get("is_active_target", false)), "Active attach should still be marked as an active target"),
		assert_true(bool(features.get("improves_attack_readiness", false)), "Attaching energy should count when it unlocks a later attack"),
	])


func test_ai_feature_extractor_marks_bench_development_for_play_basic_to_bench() -> String:
	var extractor := AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand = [CardInstance.create(_make_pokemon_card("Bench Basic"), 0)]

	var features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "play_basic_to_bench",
		"card": player.hand[0],
	})

	return run_checks([
		assert_true(bool(features.get("improves_bench_development", false)), "Playing a Basic to the bench should be marked as bench development"),
		assert_eq(int(features.get("bench_development_delta", 0)), 1, "Playing a Basic to the bench should add one bench development point"),
	])


func test_ai_feature_extractor_marks_nest_ball_without_basic_targets_unproductive() -> String:
	var extractor := AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var nest_ball := _make_trainer_card("巢穴球")
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand = [nest_ball]
	player.deck = [
		_make_energy_card("Fire Energy", "R"),
		_make_trainer_card("Switch"),
	]

	var features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "play_trainer",
		"card": nest_ball,
		"targets": [],
	})

	return run_checks([
		assert_false(bool(features.get("productive", true)), "Nest Ball should not be productive when no Basic targets remain"),
		assert_eq(int(features.get("remaining_basic_targets", -1)), 0, "Nest Ball should report zero remaining Basic targets"),
	])


func test_ai_feature_extractor_identifies_nest_ball_by_effect_id() -> String:
	var extractor := AIFeatureExtractorScript.new()
	var gsm := _make_ai_manual_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var nest_ball := _make_trainer_card("巢穴球")
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand = [nest_ball]
	player.deck = [
		_make_energy_card("Fire Energy", "R"),
		_make_trainer_card("Switch"),
	]

	var features: Dictionary = extractor.build_context(gsm, 0, {
		"kind": "play_trainer",
		"card": nest_ball,
		"targets": [],
	})

	return run_checks([
		assert_false(bool(features.get("productive", true)), "Nest Ball should be identified by effect_id even when the display name is localized"),
		assert_eq(int(features.get("remaining_basic_targets", -1)), 0, "Localized Nest Ball should still report zero remaining Basic targets"),
	])
