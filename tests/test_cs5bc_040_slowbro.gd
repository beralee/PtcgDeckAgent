class_name TestCS5bC040Slowbro
extends TestBase


class RiggedCoinFlipper extends CoinFlipper:
	var sequence: Array[bool] = []
	var index: int = 0

	func _init(results: Array[bool]) -> void:
		sequence = results

	func flip() -> bool:
		if sequence.is_empty():
			return false
		var result: bool = sequence[min(index, sequence.size() - 1)]
		index += 1
		return result


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.first_player_index = 0
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_pokemon_data(name: String, energy_type: String = "C", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.retreat_cost = 1
	return cd


func _make_energy_data(name: String = "Colorless Energy", energy_type: String = "C") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _fill_prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_pokemon_data("Prize%d" % i), player.player_index))
	player.reset_prize_layout()


func _attach_colorless(slot: PokemonSlot, owner: int, count: int) -> void:
	slot.attached_energy.clear()
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_make_energy_data("Energy%d" % i), owner))


func test_cs5bc_040_slowbro_is_bundled() -> String:
	var db := CardDatabase
	var card: CardData = db.get_card("CS5bC", "040")
	return run_checks([
		assert_not_null(card, "CS5bC_040 Slowbro should load from the bundled card pool"),
		assert_eq(str(card.name_en) if card != null else "", "Slowbro", "CS5bC_040 should keep API English name"),
		assert_eq(str(card.card_type) if card != null else "", "Pokemon", "CS5bC_040 should be a Pokemon"),
		assert_eq(str(card.stage) if card != null else "", "Stage 1", "CS5bC_040 should be a Stage 1 Pokemon"),
		assert_eq(str(card.effect_id) if card != null else "", "24f6629cb78fa8e4a940f49f67736afa", "CS5bC_040 should keep the API effect_id"),
	])


func test_cs5bc_040_attack_effect_instances_are_scoped_to_separate_attacks() -> String:
	var slowbro_cd: CardData = CardDatabase.get_card("CS5bC", "040")
	if slowbro_cd == null:
		return "CS5bC_040 Slowbro should be bundled before effect scope tests run"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(slowbro_cd)
	var attacker := _make_slot(slowbro_cd, 0)

	var first_attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var second_attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 1)
	var shared_instances := []
	for first_effect: BaseEffect in first_attack_effects:
		for second_effect: BaseEffect in second_attack_effects:
			if first_effect.get_instance_id() == second_effect.get_instance_id():
				shared_instances.append(first_effect.get_instance_id())

	return run_checks([
		assert_eq(first_attack_effects.size(), 1, "Tumbling Tackle should have exactly one scoped effect instance"),
		assert_eq(second_attack_effects.size(), 1, "Twilight Inspiration should have exactly one scoped effect instance"),
		assert_true(first_attack_effects[0] is CS5bC040SlowbroEffects if not first_attack_effects.is_empty() else false, "Tumbling Tackle should use the Slowbro effect script"),
		assert_true(second_attack_effects[0] is CS5bC040SlowbroEffects if not second_attack_effects.is_empty() else false, "Twilight Inspiration should use the Slowbro effect script"),
		assert_eq(shared_instances.size(), 0, "Slowbro's two attacks should not share one attack effect instance"),
	])


func test_cs5bc_040_tumbling_tackle_sleeps_both_active() -> String:
	var slowbro_cd: CardData = CardDatabase.get_card("CS5bC", "040")
	if slowbro_cd == null:
		return "CS5bC_040 Slowbro should be bundled before effect tests run"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.active_pokemon = _make_slot(slowbro_cd, 0)
	opponent.active_pokemon = _make_slot(_make_pokemon_data("Defender", "W", 100), 1)
	_attach_colorless(player.active_pokemon, 0, 1)
	var flipper := RiggedCoinFlipper.new([false, false])
	gsm.coin_flipper = flipper
	gsm.effect_processor.coin_flipper = flipper
	gsm.effect_processor.register_pokemon_card(slowbro_cd)

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attacked, "Slowbro should be able to use Tumbling Tackle with one Colorless Energy"),
		assert_eq(opponent.active_pokemon.damage_counters, 20, "Tumbling Tackle should deal its printed 20 damage"),
		assert_true(bool(player.active_pokemon.status_conditions.get("asleep", false)), "Tumbling Tackle should make Slowbro Asleep"),
		assert_true(bool(opponent.active_pokemon.status_conditions.get("asleep", false)), "Tumbling Tackle should make the opponent Active Asleep"),
	])


func test_cs5bc_040_twilight_inspiration_requires_opponent_final_prize_and_takes_two() -> String:
	var slowbro_cd: CardData = CardDatabase.get_card("CS5bC", "040")
	if slowbro_cd == null:
		return "CS5bC_040 Slowbro should be bundled before effect tests run"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.active_pokemon = _make_slot(slowbro_cd, 0)
	opponent.active_pokemon = _make_slot(_make_pokemon_data("Defender", "W", 100), 1)
	_attach_colorless(player.active_pokemon, 0, 2)
	_fill_prizes(player, 3)
	_fill_prizes(opponent, 2)
	gsm.effect_processor.register_pokemon_card(slowbro_cd)

	var unusable_before := gsm.can_use_attack(0, 1)
	_fill_prizes(opponent, 1)
	var hand_before := player.hand.size()
	var prizes_before := player.prizes.size()
	var attacked := gsm.use_attack(0, 1)

	return run_checks([
		assert_false(unusable_before, "Twilight Inspiration should be unusable unless the opponent has exactly 1 Prize remaining"),
		assert_true(attacked, "Twilight Inspiration should be usable when the opponent has exactly 1 Prize remaining"),
		assert_eq(player.prizes.size(), prizes_before - 2, "Twilight Inspiration should take 2 of the user's own Prize cards"),
		assert_eq(player.hand.size(), hand_before + 2, "Taken Prize cards should move to the user's hand"),
		assert_eq(opponent.active_pokemon.damage_counters, 0, "Twilight Inspiration should not deal damage"),
	])
