class_name TestCSV10C216To220
extends TestBase


class NoopSupporterEffect:
	extends BaseEffect

	func can_execute(_card: CardInstance, _state: GameState) -> bool:
		return true

	func execute(_card: CardInstance, _targets: Array, _state: GameState) -> void:
		pass


func test_csv10c_216_220_bundle_metadata_and_assets() -> String:
	var expected := {
		"216": ["尖钉镇道馆", "dc1d73740f5d6e98ad1491ca9067aac3"],
		"217": ["酿光市", "cf88045d66d42c709157d28d64449c64"],
		"218": ["化朗镇", "0c3c21449043e462bb73afac6c389a34"],
		"219": ["火箭队的监视塔", "99173b61a66aa2b9c169e36c8e0a10b4"],
		"220": ["火箭队的工厂", "0efa680f3ebb077cfd90884f9317c93b"],
	}
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for index: String in expected:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var card := _load_card(index)
		checks.append(assert_not_null(card, "CSV10C_%s should load from bundled JSON" % index))
		if card == null:
			continue
		checks.append(assert_eq(card.name, expected[index][0], "CSV10C_%s should preserve the API card name" % index))
		checks.append(assert_eq(card.effect_id, expected[index][1], "CSV10C_%s should preserve the API effect id" % index))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "CSV10C_%s should bundle a valid PNG" % index))
		checks.append(assert_true(card_path in manifest and image_path in manifest, "CSV10C_%s resources should be listed in the manifest" % index))
	return run_checks(checks)


func test_csv10c_216_spikemuth_gym_searches_chinese_marnies_pokemon() -> String:
	var card := _load_card("216")
	if card == null:
		return "CSV10C_216 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_216 should register a Stadium effect"
	var state := _make_state()
	var marnie := _pokemon_card("玛俐的莫鲁贝可", "Basic", "D", 0)
	var ordinary := _pokemon_card("莫鲁贝可", "Basic", "D", 0)
	state.players[0].deck = [ordinary, marnie]
	var source := CardInstance.create(card, 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(source, state)
	effect.execute(source, [{"spikemuth_gym_marnies_pokemon": [marnie]}], state)
	return run_checks([
		assert_true(effect.can_use_as_stadium_action(source, state), "CSV10C_216 should be a once-per-turn Stadium action"),
		assert_eq(str(steps[0].get("visible_scope", "")) if not steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_216 should show the complete own library"),
		assert_true(marnie in state.players[0].hand, "CSV10C_216 should move the selected Chinese Marnie's Pokemon to hand"),
		assert_true(ordinary in state.players[0].deck, "CSV10C_216 should reject unrelated Pokemon"),
	])


func test_csv10c_217_levincia_recovers_up_to_two_basic_lightning_energy() -> String:
	var card := _load_card("217")
	if card == null:
		return "CSV10C_217 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_217 should register a Stadium effect"
	var state := _make_state()
	var lightning_a := _energy("基本雷能量A", "Basic Energy", "L", 0)
	var lightning_b := _energy("基本雷能量B", "Basic Energy", "L", 0)
	var special_lightning := _energy("特殊雷能量", "Special Energy", "L", 0)
	var fire := _energy("基本火能量", "Basic Energy", "R", 0)
	state.players[0].discard_pile = [lightning_a, fire, special_lightning, lightning_b]
	var source := CardInstance.create(card, 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(source, state)
	effect.execute(source, [{"levincia_basic_lightning": [lightning_a, lightning_b]}], state)
	return run_checks([
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 2, "CSV10C_217 should allow up to 2 cards"),
		assert_true(special_lightning not in (steps[0].get("items", []) as Array) and fire not in (steps[0].get("items", []) as Array), "CSV10C_217 should reject Special and non-Lightning Energy"),
		assert_true(lightning_a in state.players[0].hand and lightning_b in state.players[0].hand, "CSV10C_217 should recover both selected Basic Lightning Energy"),
	])


func test_csv10c_218_postwick_adds_thirty_only_for_hops_pokemon() -> String:
	var card := _load_card("218")
	if card == null:
		return "CSV10C_218 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	state.stadium_card = CardInstance.create(card, 0)
	var hop := _slot("赫普的藏玛然特", "M", 0)
	state.players[0].active_pokemon = hop
	var ordinary := _slot("藏玛然特", "M", 0)
	state.players[0].bench = [ordinary]
	return run_checks([
		assert_eq(processor.get_attacker_modifier(hop, state, state.players[1].active_pokemon), 30, "CSV10C_218 should add 30 damage for Hop's Pokemon"),
		assert_eq(processor.get_attacker_modifier(ordinary, state, state.players[1].active_pokemon), 0, "CSV10C_218 should not boost unrelated Pokemon"),
	])


func test_csv10c_219_watchtower_disables_only_colorless_pokemon_abilities() -> String:
	var card := _load_card("219")
	if card == null:
		return "CSV10C_219 bundled card is required"
	var processor := EffectProcessor.new()
	var state := _make_state()
	state.stadium_card = CardInstance.create(card, 0)
	var colorless := _slot("大尾狸", "C", 0)
	var lightning := _slot("电蜘蛛", "L", 0)
	return run_checks([
		assert_true(processor.is_ability_disabled(colorless, state), "CSV10C_219 should disable Colorless Pokemon abilities"),
		assert_false(processor.is_ability_disabled(lightning, state), "CSV10C_219 should preserve non-Colorless Pokemon abilities"),
	])


func test_csv10c_220_factory_requires_rocket_supporter_this_turn_then_draws_two() -> String:
	var card := _load_card("220")
	if card == null:
		return "CSV10C_220 bundled card is required"
	var effect := EffectProcessor.new().get_effect(card.effect_id)
	if effect == null:
		return "CSV10C_220 should register a Stadium effect"
	var state := _make_state()
	state.players[0].deck = [_card("Draw A", "Item", 0), _card("Draw B", "Item", 0), _card("Draw C", "Item", 0)]
	var source := CardInstance.create(card, 0)
	var before_supporter := effect.can_execute(source, state)
	state.shared_turn_flags["rocket_supporter_played_turn:0"] = state.turn_number
	var after_supporter := effect.can_execute(source, state)
	effect.execute(source, [], state)
	return run_checks([
		assert_false(before_supporter, "CSV10C_220 should be unavailable before a Team Rocket Supporter is played"),
		assert_true(after_supporter, "CSV10C_220 should become available after a Team Rocket Supporter is played this turn"),
		assert_eq(state.players[0].hand.size(), 2, "CSV10C_220 should draw 2 cards"),
	])


func test_csv10c_220_game_state_machine_records_rocket_supporter_played_from_hand() -> String:
	var state := _make_state()
	var supporter := _card("火箭队的测试支援者", "Supporter", 0)
	supporter.card_data.effect_id = "test_csv10c_rocket_supporter_tracking"
	state.players[0].hand = [supporter]
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_effect(supporter.card_data.effect_id, NoopSupporterEffect.new())
	var played := gsm.play_trainer(0, supporter, [])
	var recorded_turn := int(state.shared_turn_flags.get("rocket_supporter_played_turn:0", -1))
	gsm.prepare_for_disposal()
	return run_checks([
		assert_true(played, "a Team Rocket Supporter should resolve through the normal trainer path"),
		assert_eq(recorded_turn, state.turn_number, "playing a Team Rocket Supporter from hand should unlock CSV10C_220 for this turn"),
	])


func _load_card(index: String) -> CardData:
	var path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 3
	state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot("Active %d" % pi, "C", pi)
		state.players.append(player)
	return state


func _slot(name: String, energy_type: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_pokemon_card(name, "Basic", energy_type, owner))
	return slot


func _pokemon_card(name: String, stage: String, energy_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.hp = 100
	data.energy_type = energy_type
	return CardInstance.create(data, owner)


func _energy(name: String, card_type: String, energy_type: String, owner: int) -> CardInstance:
	var energy := _card(name, card_type, owner)
	energy.card_data.energy_type = energy_type
	energy.card_data.energy_provides = energy_type
	return energy


func _card(name: String, card_type: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)
