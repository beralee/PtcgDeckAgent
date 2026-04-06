class_name TestCoinFlipInteractionOrder
extends TestBase

const EffectPokemonCatcher = preload("res://scripts/effects/trainer_effects/EffectPokemonCatcher.gd")
const EffectCapturingAroma = preload("res://scripts/effects/trainer_effects/EffectCapturingAroma.gd")
const EffectCrushingHammer = preload("res://scripts/effects/trainer_effects/EffectCrushingHammer.gd")
const EffectCyllene = preload("res://scripts/effects/trainer_effects/EffectCyllene.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result: bool = _results.pop_front() if not _results.is_empty() else false
		coin_flipped.emit(result)
		return result


func _make_basic_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic"
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.hp = hp
	cd.energy_type = energy_type
	return cd


func _make_energy_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _make_stage_one_reference(name: String, evolves_from: String, owner_index: int, energy_type: String = "R") -> CardInstance:
	var cd := _make_basic_pokemon_data(name, energy_type, 90, "Stage 1")
	cd.evolves_from = evolves_from
	return CardInstance.create(cd, owner_index)


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	CardInstance.reset_id_counter()

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)

	var player := state.players[0]
	var opponent := state.players[1]

	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Player Active", "P"), 0))
	var player_bench := PokemonSlot.new()
	player_bench.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Player Bench", "P"), 0))
	player.bench = [player_bench]

	opponent.active_pokemon = PokemonSlot.new()
	opponent.active_pokemon.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Opponent Active", "W"), 1))
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Opponent Bench A", "L"), 1))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Opponent Bench B", "M"), 1))
	opponent.bench = [bench_a, bench_b]

	return state


func test_coin_flip_followup_steps_are_marked_to_wait_for_animation() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.deck.clear()
	player.discard_pile.clear()
	player.deck.append(_make_stage_one_reference("Evolution", "Basic", 0))
	player.discard_pile.append(CardInstance.create(_make_trainer_data("Recovered Card", "Item"), 0))
	opponent.active_pokemon.attached_energy = [CardInstance.create(_make_energy_data("Opp Active Energy", "W"), 1)]
	opponent.bench[0].attached_energy = [CardInstance.create(_make_energy_data("Opp Bench Energy", "L"), 1)]

	var aroma_steps: Array[Dictionary] = EffectCapturingAroma.new(RiggedCoinFlipper.new([true])).get_interaction_steps(
		CardInstance.create(_make_trainer_data("Capturing Aroma", "Item", "7cd68d9e286b78a7f9c799fce24a7d6c"), 0),
		state
	)
	var catcher_steps: Array[Dictionary] = EffectPokemonCatcher.new(RiggedCoinFlipper.new([true])).get_interaction_steps(
		CardInstance.create(_make_trainer_data("Pokemon Catcher", "Item", "3a6d419769778b40091e69fbd76737ec"), 0),
		state
	)
	var cyllene_steps: Array[Dictionary] = EffectCyllene.new(RiggedCoinFlipper.new([true, false])).get_interaction_steps(
		CardInstance.create(_make_trainer_data("Cyllene", "Supporter"), 0),
		state
	)
	var hammer_steps: Array[Dictionary] = EffectCrushingHammer.new(RiggedCoinFlipper.new([true])).get_interaction_steps(
		CardInstance.create(_make_trainer_data("Crushing Hammer", "Item"), 0),
		state
	)

	return run_checks([
		assert_eq(str(aroma_steps[0].get("id", "")), "searched_pokemon", "Capturing Aroma should still produce the search step on heads"),
		assert_true(bool(aroma_steps[0].get("wait_for_coin_animation", false)), "Capturing Aroma should wait for the coin animation before showing the search step"),
		assert_eq(str(catcher_steps[0].get("id", "")), "opponent_bench_target", "Pokemon Catcher should still produce the target step on heads"),
		assert_true(bool(catcher_steps[0].get("wait_for_coin_animation", false)), "Pokemon Catcher should wait for the coin animation before showing the target step"),
		assert_eq(str(cyllene_steps[0].get("id", "")), "discard_to_top", "Cyllene should still produce the recovery step when it gets heads"),
		assert_true(bool(cyllene_steps[0].get("wait_for_coin_animation", false)), "Cyllene should wait for the coin animation before showing the recovery step"),
		assert_eq(str(hammer_steps[0].get("id", "")), "target_pokemon", "Crushing Hammer should only choose a discard target after flipping heads"),
		assert_true(bool(hammer_steps[0].get("wait_for_coin_animation", false)), "Crushing Hammer should wait for the coin animation before showing the target step"),
		assert_false(bool(hammer_steps[0].get("allow_cancel", true)), "Crushing Hammer should not allow cancelling the card after flipping heads"),
	])


func test_crushing_hammer_heads_discards_selected_target_after_coin_flip() -> String:
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	var target_slot: PokemonSlot = opponent.bench[0]
	var other_slot: PokemonSlot = opponent.active_pokemon
	var target_energy := CardInstance.create(_make_energy_data("Target Energy", "L"), 1)
	var other_energy := CardInstance.create(_make_energy_data("Other Energy", "W"), 1)
	target_slot.attached_energy = [target_energy]
	other_slot.attached_energy = [other_energy]

	var effect := EffectCrushingHammer.new(RiggedCoinFlipper.new([true]))
	var card := CardInstance.create(_make_trainer_data("Crushing Hammer", "Item"), 0)
	effect.get_interaction_steps(card, state)
	effect.execute(card, [{
		"target_pokemon": [target_slot],
	}], state)

	return run_checks([
		assert_eq(target_slot.attached_energy.size(), 0, "Crushing Hammer should discard Energy from the selected target"),
		assert_eq(other_slot.attached_energy.size(), 1, "Crushing Hammer should not touch unselected Pokemon"),
		assert_true(target_energy in opponent.discard_pile, "Crushing Hammer should move the discarded Energy into the opponent discard pile"),
		assert_true(other_energy not in opponent.discard_pile, "Crushing Hammer should not discard Energy from the wrong target"),
	])
