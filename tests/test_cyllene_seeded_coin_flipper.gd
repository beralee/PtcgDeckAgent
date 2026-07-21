class_name TestCylleneSeededCoinFlipper
extends TestBase

const CYLLENE_EFFECT_ID := "e5c317e428f0cfd885b53d4d058b5d5b"


class SequenceCoinFlipper extends CoinFlipper:
	var results: Array[bool] = []
	var flip_count: int = 0

	func _init(sequence: Array[bool]) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var result := false
		if flip_count < results.size():
			result = results[flip_count]
		flip_count += 1
		coin_flipped.emit(result)
		return result


func test_registry_injects_processor_coin_flipper_into_cyllene() -> String:
	var flipper := SequenceCoinFlipper.new([true, false])
	var processor := EffectProcessor.new(flipper)
	var effect := processor.get_effect(CYLLENE_EFFECT_ID) as EffectCyllene
	if effect == null:
		return "Cyllene must be registered through EffectProcessor"

	var state := _make_state_with_discard_cards()
	var card := CardInstance.create(_make_trainer_data("Cyllene", CYLLENE_EFFECT_ID), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)

	return run_checks([
		assert_true(effect.coin_flipper == flipper, "Cyllene must reuse EffectProcessor.coin_flipper"),
		assert_eq(flipper.flip_count, 2, "Cyllene must consume both flips from the injected sequence"),
		assert_eq(steps.size(), 1, "One heads should produce a recovery step"),
		assert_eq(int(steps[0].get("max_select", -1)), 1, "One heads should allow one recovered card"),
	])


func test_missing_processor_and_default_initialization_are_safe() -> String:
	EffectRegistry.register_all(null)

	var processor := EffectProcessor.new(null)
	var effect := processor.get_effect(CYLLENE_EFFECT_ID) as EffectCyllene
	if effect == null:
		return "Cyllene must be registered when EffectProcessor creates its default flipper"

	return run_checks([
		assert_not_null(processor.coin_flipper, "EffectProcessor must create a default coin flipper"),
		assert_true(effect.coin_flipper == processor.coin_flipper, "Default initialization must still share one coin flipper"),
	])


func _make_state_with_discard_cards() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	state.players[0].discard_pile.append(CardInstance.create(_make_trainer_data("Recovery A"), 0))
	state.players[0].discard_pile.append(CardInstance.create(_make_trainer_data("Recovery B"), 0))
	return state


func _make_trainer_data(name: String, effect_id: String = "") -> CardData:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Supporter"
	card_data.effect_id = effect_id
	return card_data
