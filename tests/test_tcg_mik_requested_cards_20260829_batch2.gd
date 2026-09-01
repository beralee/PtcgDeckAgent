class_name TestTcgMikRequestedCards20260829Batch2
extends TestBase


class RiggedCoinFlipper:
	extends CoinFlipper

	var results: Array[bool] = []

	func _init(sequence: Array[bool]) -> void:
		results = sequence.duplicate()

	func flip() -> bool:
		var result: bool = results.pop_front() if not results.is_empty() else true
		coin_flipped.emit(result)
		return result


func test_csv6c009_bounsweet_and_csv6c010_steenee_coin_math_is_exact() -> String:
	var bounsweet := _load_card("CSV6C", "009")
	var steenee := _load_card("CSV6C", "010")
	if bounsweet == null or steenee == null:
		return "CSV6C_009 and CSV6C_010 should load"
	var state := _state()
	var defender := state.players[1].active_pokemon
	var bounsweet_slot := _slot(bounsweet, 0)
	var bounsweet_processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	bounsweet_processor.register_pokemon_card(bounsweet)
	var bounsweet_effects := bounsweet_processor.get_attack_effects_for_slot(bounsweet_slot, 0)
	if not bounsweet_effects.is_empty():
		bounsweet_effects[0].execute_attack(bounsweet_slot, defender, 0, state)
	var bounsweet_bonus := defender.damage_counters
	defender.damage_counters = 0
	var bounsweet_tails_processor := EffectProcessor.new(RiggedCoinFlipper.new([false]))
	bounsweet_tails_processor.register_pokemon_card(bounsweet)
	var bounsweet_tails_effects := bounsweet_tails_processor.get_attack_effects_for_slot(bounsweet_slot, 0)
	if not bounsweet_tails_effects.is_empty():
		bounsweet_tails_effects[0].execute_attack(bounsweet_slot, defender, 0, state)
	var bounsweet_tails_bonus := defender.damage_counters
	defender.damage_counters = 40
	var steenee_slot := _slot(steenee, 0)
	var steenee_processor := EffectProcessor.new(RiggedCoinFlipper.new([true, false]))
	steenee_processor.register_pokemon_card(steenee)
	var steenee_effects := steenee_processor.get_attack_effects_for_slot(steenee_slot, 1)
	if not steenee_effects.is_empty():
		steenee_effects[0].execute_attack(steenee_slot, defender, 1, state)
	var one_heads_damage := defender.damage_counters
	var steenee_tails_processor := EffectProcessor.new(RiggedCoinFlipper.new([false, false]))
	steenee_tails_processor.register_pokemon_card(steenee)
	var steenee_tails_effects := steenee_tails_processor.get_attack_effects_for_slot(steenee_slot, 1)
	if not steenee_tails_effects.is_empty():
		steenee_tails_effects[0].execute_attack(steenee_slot, defender, 1, state)
	return run_checks([
		assert_false(bounsweet_effects.is_empty(), "Bounsweet's Quick Attack should register its coin effect"),
		assert_eq(bounsweet_bonus, 20, "Bounsweet's Quick Attack should add exactly 20 on heads"),
		assert_eq(bounsweet_tails_bonus, 0, "Bounsweet's Quick Attack should add nothing on tails"),
		assert_false(steenee_effects.is_empty(), "Steenee's Double Spin should register its fixed two-coin effect"),
		assert_eq(one_heads_damage, 40, "One heads out of two should leave Double Spin at exactly 40 total damage"),
		assert_eq(defender.damage_counters, 0, "Two tails should leave Double Spin at exactly 0 total damage"),
	])


func test_csv6c038_tsareena_targets_any_opponent_and_tropical_kick_heals_and_clears_status() -> String:
	var card := _load_card("CSV6C", "038")
	if card == null:
		return assert_not_null(card, "CSV6C_038 should load")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _state()
	var tsareena := _slot(card, 0)
	state.players[0].active_pokemon = tsareena
	var bench_target := _slot(_pokemon("Bench Target", 180), 1)
	bench_target.damage_counters = 20
	state.players[1].bench = [bench_target]
	var first_effects := processor.get_attack_effects_for_slot(tsareena, 0)
	var target_effect := _effect_with_steps(first_effects, tsareena.get_top_card(), card.attacks[0], state)
	var steps: Array = target_effect.get_attack_interaction_steps(tsareena.get_top_card(), card.attacks[0], state) if target_effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	if target_effect != null and not step.is_empty():
		target_effect.set_attack_interaction_context([{str(step.get("id", "")): [bench_target]}])
		target_effect.execute_attack(tsareena, state.players[1].active_pokemon, 0, state)
		target_effect.clear_attack_interaction_context()
	tsareena.damage_counters = 80
	tsareena.set_status("poisoned", true)
	processor.execute_attack_effect(tsareena, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_not_null(target_effect, "Icicle Sole should expose a target choice"),
		assert_true(bench_target in step.get("items", []), "Icicle Sole should allow an opponent Benched Pokemon target"),
		assert_eq(bench_target.get_remaining_hp(), 30, "Icicle Sole should place counters until the selected Pokemon has exactly 30 HP remaining"),
		assert_eq(tsareena.damage_counters, 50, "Tropical Kick should heal exactly 30 damage"),
		assert_false(tsareena.status_conditions.get("poisoned", false), "Tropical Kick should clear all Special Conditions"),
	])


func test_svp175_litten_coin_paralysis_and_svp176_torracat_same_attack_lock() -> String:
	var litten := _load_card("SVP", "175")
	var torracat := _load_card("SVP", "176")
	if litten == null or torracat == null:
		return "SVP_175 and SVP_176 should load"
	var state := _state()
	var defender := state.players[1].active_pokemon
	var litten_slot := _slot(litten, 0)
	var litten_processor := EffectProcessor.new(RiggedCoinFlipper.new([true]))
	litten_processor.register_pokemon_card(litten)
	litten_processor.execute_attack_effect(litten_slot, 0, defender, state)
	var heads_paralyzed: bool = bool(defender.status_conditions.get("paralyzed", false))
	defender.clear_all_status()
	var litten_tails_processor := EffectProcessor.new(RiggedCoinFlipper.new([false]))
	litten_tails_processor.register_pokemon_card(litten)
	litten_tails_processor.execute_attack_effect(litten_slot, 0, defender, state)
	var tails_paralyzed: bool = bool(defender.status_conditions.get("paralyzed", false))
	var torracat_slot := _slot(torracat, 0)
	var torracat_processor := EffectProcessor.new()
	torracat_processor.register_pokemon_card(torracat)
	torracat_processor.execute_attack_effect(torracat_slot, 1, defender, state)
	return run_checks([
		assert_true(heads_paralyzed, "Litten's Fake Out should Paralyze on heads"),
		assert_false(tails_paralyzed, "Litten's Fake Out should not Paralyze on tails"),
		assert_true(torracat_slot.effects.any(func(entry: Dictionary) -> bool: return str(entry.get("type", "")) == "attack_lock" and int(entry.get("attack_index", -1)) == 1), "Torracat's Flare Strike should lock only the same attack next turn"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner, 300), owner)
		state.players.append(player)
	return state


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _effect_with_steps(effects: Array[BaseEffect], card: CardInstance, attack: Dictionary, state: GameState) -> BaseEffect:
	for effect: BaseEffect in effects:
		if effect != null and not effect.get_attack_interaction_steps(card, attack, state).is_empty():
			return effect
	return null
