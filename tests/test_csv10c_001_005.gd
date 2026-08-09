class_name TestCSV10C001To005
extends TestBase

const REVENENERGY_STEP_ID := "energy_assignments"
const MOVE_ENERGY_STEP_ID := "move_attached_energy"
const MOVE_TARGET_STEP_ID := "move_energy_target"
const OPPONENT_SWITCH_STEP_ID := "opponent_switch_target"


func test_csv10c_001_005_bundle_metadata_and_assets() -> String:
	var expected := {
		"001": ["阿响的凯罗斯", "57937ca2b1d4d1118df547c37b217e65"],
		"002": ["蜻蜻蜓", "2027075ee9baee2e2a52bd1e1a477153"],
		"003": ["远古巨蜓ex", "88367894eb8e5dc6ae6b2b8350eb75f9"],
		"004": ["竹兰的毒蔷薇", "727c75c20bc176aedf17c8190ab91044"],
		"005": ["竹兰的罗丝雷朵", "3040f040cd7a982b18f5e8359ab1ed21"],
	}
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for index: String in expected:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % index
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var card := _load_card(card_path)
		checks.append(assert_not_null(card, "CSV10C_%s should load from bundled JSON" % index))
		if card == null:
			continue
		checks.append(assert_eq(card.name, expected[index][0], "CSV10C_%s should preserve the API card name" % index))
		checks.append(assert_eq(card.display_name(), expected[index][0], "CSV10C_%s should expose the Chinese name in player UI" % index))
		checks.append(assert_false(card.display_name().contains(String.chr(0xFFFD)), "CSV10C_%s UI name should not contain replacement characters" % index))
		checks.append(assert_eq(card.effect_id, expected[index][1], "CSV10C_%s should preserve the API effect id" % index))
		checks.append(assert_true(card.regulation_standard, "CSV10C_%s should be Standard legal" % index))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "CSV10C_%s should bundle a valid image" % index))
		checks.append(assert_true(card_path in manifest, "CSV10C_%s JSON should be listed in the manifest" % index))
		checks.append(assert_true(image_path in manifest, "CSV10C_%s image should be listed in the manifest" % index))
		var detail_text := "\n".join(BattleCardDetailCoordinator.new().detail_lines(card))
		checks.append(assert_true(detail_text.contains(card.display_name()), "CSV10C_%s detail UI should show the card name" % index))
		for ability: Dictionary in card.abilities:
			checks.append(assert_true(detail_text.contains(CardData.dictionary_display_name(ability)), "CSV10C_%s detail UI should show every Ability name" % index))
			checks.append(assert_true(detail_text.contains(CardData.dictionary_display_text(ability)), "CSV10C_%s detail UI should show every Ability text" % index))
		for attack: Dictionary in card.attacks:
			checks.append(assert_true(detail_text.contains(CardData.dictionary_display_name(attack)), "CSV10C_%s detail UI should show every attack name" % index))
			var attack_text := CardData.dictionary_display_text(attack)
			if attack_text != "":
				checks.append(assert_true(detail_text.contains(attack_text), "CSV10C_%s detail UI should show every attack text" % index))
		var card_view := BattleCardView.new()
		card_view.setup_from_card_data(card, BattleCardView.MODE_CHOICE)
		var title_label := card_view.get("_title_label") as Label
		checks.append(assert_not_null(title_label, "CSV10C_%s BattleCardView should build its title label" % index))
		checks.append(assert_eq(title_label.text if title_label != null else "", card.display_name(), "CSV10C_%s BattleCardView should show the Chinese card name" % index))
		card_view.free()
	return run_checks(checks)


func test_csv10c_001_ethans_pinsir_tagged_revenge_requires_attack_damage_ko() -> String:
	var card := _load_card("res://data/bundled_user/cards/CSV10C_001.json")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var attacker := _make_slot(card, 0)
	var effects := processor.get_attack_effects_for_slot(attacker, 1)
	if effects.is_empty():
		return "CSV10C_001 一力反攻 should register a scripted second-attack effect"
	var effect: BaseEffect = effects[0]
	if not effect.has_method("get_damage_bonus"):
		return "CSV10C_001 一力反攻 effect should expose get_damage_bonus"

	var state := _make_state()
	state.players[0].active_pokemon = attacker
	state.shared_turn_flags["attack_damage_knockout_names:0:1"] = ["阿响的火球鼠"]
	var tagged_bonus := int(effect.call("get_damage_bonus", attacker, state))
	state.shared_turn_flags["attack_damage_knockout_names:0:1"] = ["普通火球鼠"]
	var ordinary_bonus := int(effect.call("get_damage_bonus", attacker, state))
	state.shared_turn_flags.erase("attack_damage_knockout_names:0:1")
	state.last_knockout_turn_against[0] = state.turn_number - 1
	var untracked_bonus := int(effect.call("get_damage_bonus", attacker, state))

	return run_checks([
		assert_eq(tagged_bonus, 100, "CSV10C_001 should add 100 after an Ethan's Pokemon attack-damage KO"),
		assert_eq(ordinary_bonus, 0, "CSV10C_001 should not trigger after a non-Ethan's Pokemon KO"),
		assert_eq(untracked_bonus, 0, "CSV10C_001 should not use the generic any-cause knockout flag"),
	])


func test_csv10c_002_whirlwind_exposes_opponent_choice_and_switches_selected_target() -> String:
	var card := _load_card("res://data/bundled_user/cards/CSV10C_002.json")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var attacker := _make_slot(card, 0)
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	if effects.is_empty():
		return "CSV10C_002 吹飞 should register a switch effect"
	var state := _make_state()
	state.players[0].active_pokemon = attacker
	var selected := state.players[1].bench[1]
	var old_active := state.players[1].active_pokemon
	var steps: Array[Dictionary] = effects[0].call("get_attack_interaction_steps", attacker.get_top_card(), card.attacks[0], state)
	effects[0].set_attack_interaction_context([{OPPONENT_SWITCH_STEP_ID: [selected]}])
	effects[0].call("execute_attack", attacker, old_active, 0, state)

	return run_checks([
		assert_eq(steps.size(), 1, "CSV10C_002 should expose one switch choice"),
		assert_true(bool(steps[0].get("opponent_chooses", false)) if not steps.is_empty() else false, "CSV10C_002 switch target must be chosen by the opponent"),
		assert_eq(state.players[1].active_pokemon, selected, "CSV10C_002 should promote the opponent-selected Bench Pokemon"),
		assert_true(old_active in state.players[1].bench, "CSV10C_002 should move the old Active Pokemon to the Bench"),
	])


func test_csv10c_003_yanmega_attaches_three_grass_on_entry_and_moves_three_energy() -> String:
	var card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var yanmega := _make_slot(card, 0)
	state.players[0].active_pokemon = yanmega
	yanmega.mark_entered_active_from_bench(state.turn_number)
	var grass_a := _energy("Grass A", "G", 0)
	var grass_b := _energy("Grass B", "G", 0)
	var grass_c := _energy("Grass C", "G", 0)
	var water := _energy("Water", "W", 0)
	state.players[0].deck = [grass_a, grass_b, grass_c, water]
	var ability: BaseEffect = processor.get_effect(card.effect_id)
	if ability == null:
		return "CSV10C_003 嗡鸣突进 should register an Ability effect"
	var ability_steps: Array[Dictionary] = ability.call("get_interaction_steps", yanmega.get_top_card(), state)
	ability.call("execute_ability", yanmega, 0, [{REVENENERGY_STEP_ID: [
		{"source": grass_a, "target": yanmega},
		{"source": grass_b, "target": yanmega},
		{"source": grass_c, "target": yanmega},
	]}], state)

	var attack_effects := processor.get_attack_effects_for_slot(yanmega, 0)
	if attack_effects.is_empty():
		return "CSV10C_003 喷射旋风 should register an Energy-move effect"
	var target := state.players[0].bench[0]
	var attack_steps: Array[Dictionary] = attack_effects[0].call("get_attack_interaction_steps", yanmega.get_top_card(), card.attacks[0], state)
	attack_effects[0].set_attack_interaction_context([{
		MOVE_ENERGY_STEP_ID: [grass_a, grass_b, grass_c],
		MOVE_TARGET_STEP_ID: [target],
	}])
	attack_effects[0].call("execute_attack", yanmega, state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_true(bool(ability.call("can_use_ability", yanmega, state)) == false, "CSV10C_003 Ability should be consumed after use"),
		assert_eq(ability_steps.size(), 1, "CSV10C_003 Ability should expose one full-library assignment step"),
		assert_eq(str(ability_steps[0].get("visible_scope", "")) if not ability_steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_003 should expose the full own deck during search"),
		assert_true(water in state.players[0].deck, "CSV10C_003 should leave non-Grass Energy in the deck"),
		assert_eq(attack_steps.size(), 2, "CSV10C_003 attack should select three Energy and one Bench target"),
		assert_eq(target.attached_energy, [grass_a, grass_b, grass_c], "CSV10C_003 should move exactly the selected three Energy to one Bench Pokemon"),
		assert_true(yanmega.attached_energy.is_empty(), "CSV10C_003 should remove the moved Energy from itself"),
	])


func test_csv10c_003_yanmega_buzzing_rush_becomes_usable_after_jet_energy_switch() -> String:
	var yanmega_card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.register_pokemon_card(yanmega_card)
	var state := gsm.game_state
	var player: PlayerState = state.players[0]

	var yanmega := _make_slot(yanmega_card, 0)
	player.bench = [yanmega]
	var grass_a := _energy("Grass A", "G", 0)
	var grass_b := _energy("Grass B", "G", 0)
	var grass_c := _energy("Grass C", "G", 0)
	player.deck = [grass_a, grass_b, grass_c]

	var jet_energy_data := CardData.new()
	jet_energy_data.name = "喷射能量"
	jet_energy_data.card_type = "Special Energy"
	jet_energy_data.energy_type = "C"
	jet_energy_data.energy_provides = "C"
	jet_energy_data.effect_id = "1323733f19cc04e54090b39bc1a393b8"
	var jet_energy := CardInstance.create(jet_energy_data, 0)
	player.hand.append(jet_energy)

	var usable_while_benched := gsm.effect_processor.can_use_ability(yanmega, state, 0)
	var attached := gsm.attach_energy(0, jet_energy, yanmega)
	var ability_usable := gsm.effect_processor.can_use_ability(yanmega, state, 0)
	var ability_steps: Array[Dictionary] = []
	if ability_usable:
		var ability := gsm.effect_processor.get_ability_effect(yanmega, 0, state)
		ability_steps = ability.get_interaction_steps(yanmega.get_top_card(), state)
	var ability_used := gsm.use_ability(0, yanmega, 0, [{REVENENERGY_STEP_ID: [
		{"source": grass_a, "target": yanmega},
		{"source": grass_b, "target": yanmega},
		{"source": grass_c, "target": yanmega},
	]}])

	return run_checks([
		assert_false(usable_while_benched, "Buzzing Rush must not be usable while Yanmega ex remains on the Bench"),
		assert_true(attached, "Jet Energy should attach to Benched Yanmega ex"),
		assert_eq(player.active_pokemon, yanmega, "Jet Energy should move Yanmega ex into the Active Spot"),
		assert_true(yanmega.entered_active_from_bench_this_turn(state.turn_number), "Jet Energy must record the Bench-to-Active trigger event"),
		assert_true(ability_usable, "Buzzing Rush should become usable after Jet Energy moves Yanmega ex Active"),
		assert_eq(ability_steps.size(), 1, "Buzzing Rush should open its Grass Energy selection after the real switch path"),
		assert_true(ability_used, "Buzzing Rush should resolve through GameStateMachine after the Jet Energy switch"),
		assert_eq(yanmega.attached_energy, [jet_energy, grass_a, grass_b, grass_c], "Buzzing Rush should attach the selected three Basic Grass Energy to Yanmega ex"),
		assert_false(gsm.effect_processor.can_use_ability(yanmega, state, 0), "Buzzing Rush must not be usable twice in the same turn"),
	])


func test_csv10c_003_yanmega_buzzing_rush_becomes_usable_after_dudunsparce_promotion() -> String:
	var yanmega_card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	var dudunsparce_card := _load_card("res://data/bundled_user/cards/CSV7C_162.json")
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.register_pokemon_card(yanmega_card)
	gsm.effect_processor.register_pokemon_card(dudunsparce_card)
	var state := gsm.game_state
	var player: PlayerState = state.players[0]

	var dudunsparce := _make_slot(dudunsparce_card, 0)
	var yanmega := _make_slot(yanmega_card, 0)
	player.active_pokemon = dudunsparce
	player.bench = [yanmega]
	var draw_a := CardInstance.create(_pokemon("Draw A", "C"), 0)
	var draw_b := CardInstance.create(_pokemon("Draw B", "C"), 0)
	var draw_c := CardInstance.create(_pokemon("Draw C", "C"), 0)
	var grass_a := _energy("Grass A", "G", 0)
	var grass_b := _energy("Grass B", "G", 0)
	var grass_c := _energy("Grass C", "G", 0)
	player.deck = [draw_a, draw_b, draw_c, grass_a, grass_b, grass_c]

	var used := gsm.use_ability(0, dudunsparce, 0, [{
		"replacement_bench": [yanmega],
	}])
	var ability_usable := gsm.effect_processor.can_use_ability(yanmega, state, 0)

	return run_checks([
		assert_true(used, "Dudunsparce Run Away Draw should resolve through GameStateMachine"),
		assert_eq(player.active_pokemon, yanmega, "Run Away Draw should promote the selected Yanmega ex"),
		assert_true(yanmega.entered_active_from_bench_this_turn(state.turn_number), "Every Bench-to-Active path must record the same active-entry event"),
		assert_true(ability_usable, "Buzzing Rush should become usable after Run Away Draw promotes Yanmega ex"),
	])


func test_csv10c_004_is_numeric_only_and_005_boosts_only_cynthias_pokemon() -> String:
	var roselia := _load_card("res://data/bundled_user/cards/CSV10C_004.json")
	var roserade := _load_card("res://data/bundled_user/cards/CSV10C_005.json")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(roselia)
	processor.register_pokemon_card(roserade)
	var roselia_slot := _make_slot(roselia, 0)
	var state := _make_state()
	var source := _make_slot(roserade, 0)
	state.players[0].bench = [source]
	state.players[0].active_pokemon = roselia_slot
	var cynthia_bonus := processor.get_attacker_modifier(roselia_slot, state, state.players[1].active_pokemon)
	var second_source := _make_slot(roserade, 0)
	state.players[0].bench.append(second_source)
	var stacked_bonus := processor.get_attacker_modifier(roselia_slot, state, state.players[1].active_pokemon)
	second_source.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var one_source_disabled_bonus := processor.get_attacker_modifier(roselia_slot, state, state.players[1].active_pokemon)
	source.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var all_sources_disabled_bonus := processor.get_attacker_modifier(roselia_slot, state, state.players[1].active_pokemon)
	var ordinary := _make_slot(_pokemon("普通毒蔷薇", "G"), 0)
	state.players[0].active_pokemon = ordinary
	var ordinary_bonus := processor.get_attacker_modifier(ordinary, state, state.players[1].active_pokemon)

	return run_checks([
		assert_true(processor.get_attack_effects_for_slot(roselia_slot, 0).is_empty(), "CSV10C_004 numeric attack should not register scripted behavior"),
		assert_not_null(processor.get_effect(roserade.effect_id), "CSV10C_005 荣耀声援 should register an Ability effect"),
		assert_eq(cynthia_bonus, 30, "CSV10C_005 should add 30 damage to Cynthia's Pokemon"),
		assert_eq(stacked_bonus, 60, "CSV10C_005 should stack when two 荣耀声援 sources are in play"),
		assert_eq(one_source_disabled_bonus, 30, "CSV10C_005 should ignore only the disabled Ability source"),
		assert_eq(all_sources_disabled_bonus, 0, "CSV10C_005 should stop boosting when every source Ability is disabled"),
		assert_eq(ordinary_bonus, 0, "CSV10C_005 should not boost unrelated Pokemon"),
	])


func test_csv10c_005_lazily_registers_glory_cheer_for_cynthias_garchomp_damage_path() -> String:
	var roserade := _load_card("res://data/bundled_user/cards/CSV10C_005.json")
	var garchomp := _load_card("res://data/bundled_user/cards/CSV10C_113.json")
	var processor := EffectProcessor.new()
	var state := _make_state()
	var attacker := _make_slot(garchomp, 0)
	var source := _make_slot(roserade, 0)
	state.players[0].active_pokemon = attacker
	state.players[0].bench = [source]
	var defender := state.players[1].active_pokemon
	defender.get_card_data().weakness_energy = ""
	defender.get_card_data().resistance_energy = ""

	var modifier := processor.get_attacker_modifier(attacker, state, defender)
	var resolved_damage := DamageCalculator.new().calculate_damage(
		attacker,
		defender,
		garchomp.attacks[0],
		state,
		0,
		modifier
	)

	return run_checks([
		assert_not_null(roserade, "CSV10C_005 Roserade should load"),
		assert_not_null(garchomp, "CSV10C_113 Cynthia's Garchomp ex should load"),
		assert_eq(modifier, 30, "An in-play Roserade must lazily register Glory Cheer before attack modifiers are queried"),
		assert_eq(resolved_damage, 130, "Cynthia's Garchomp ex Spiral Dive should resolve as 100 + 30 through DamageCalculator"),
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
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "C"), pi)
		player.bench = [
			_make_slot(_pokemon("Bench %d A" % pi, "C"), pi),
			_make_slot(_pokemon("Bench %d B" % pi, "C"), pi),
		]
		state.players.append(player)
	return state


func _pokemon(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.energy_type = energy_type
	card.attacks = [{"name": "Strike", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return card


func _energy(name: String, energy_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _make_slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot
