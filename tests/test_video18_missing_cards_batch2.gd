class_name TestVideo18MissingCardsBatch2
extends TestBase

const IMPORTED_REFS := ["151C_133", "CSV8C_196", "CSV3C_129", "CSVH3aC_002"]
const EFFECT_EEVEE := "9736e35ce77fbf8b005f413e20875a8f"
const EFFECT_SURFER := "565a02f4e75076963c6a884ae3622ff1"
const EFFECT_SNOWY_MOUNTAIN := "ceac9ee87d5850880f7438665925dbd2"
const EFFECT_DUNSPARCE := "0d02b63d128400622f704237482e5829"


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _pokemon(name: String, energy_type: String, owner: int = 0, stage: String = "Basic") -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Pokemon"
	card_data.stage = stage
	card_data.energy_type = energy_type
	card_data.hp = 300
	return _slot(card_data, owner)


func _pokemon_card(name: String, energy_type: String, owner: int = 0) -> CardInstance:
	return _pokemon(name, energy_type, owner).get_top_card()


func _item(name: String, owner: int = 0) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Item"
	return CardInstance.create(card_data, owner)


func _energy(name: String, owner: int = 0) -> CardInstance:
	var card_data := CardData.new()
	card_data.name = name
	card_data.name_en = name
	card_data.card_type = "Basic Energy"
	card_data.energy_type = "C"
	card_data.energy_provides = "C"
	return CardInstance.create(card_data, owner)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 12
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, "C", owner)
		state.players.append(player)
	return state


func _script_name(effect: BaseEffect) -> String:
	if effect == null or effect.get_script() == null:
		return ""
	return str(effect.get_script().resource_path).get_file()


func test_batch2_cards_are_bundled_with_valid_images_and_manifest_entries() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var checks: Array[String] = []
	for ref: String in IMPORTED_REFS:
		var card := _load_card(ref)
		checks.append(assert_not_null(card, "%s should load from the bundled card pool" % ref))
		if card == null:
			continue
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [card.set_code, card.card_index]
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s should bundle a valid image" % ref))
		checks.append(assert_str_contains(manifest, "cards/%s.json" % ref, "%s JSON should be in the bundle manifest" % ref))
		checks.append(assert_str_contains(manifest, "cards/images/%s/%s.png.bin" % [card.set_code, card.card_index], "%s image should be in the bundle manifest" % ref))
	return run_checks(checks)


func test_eevee_colorful_friends_searches_up_to_three_pokemon_of_distinct_types() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var eevee := _slot(_load_card("151C_133"), 0)
	var fire_a := _pokemon_card("Fire A", "R")
	var fire_b := _pokemon_card("Fire B", "R")
	var water := _pokemon_card("Water", "W")
	var grass := _pokemon_card("Grass", "G")
	var trainer := _item("Trainer")
	state.players[0].active_pokemon = eevee
	state.players[0].deck = [fire_a, trainer, fire_b, water, grass]
	processor.register_pokemon_card(eevee.get_card_data())
	var effects := processor.get_attack_effects_for_slot(eevee, 0)
	if effects.is_empty():
		return "151C_133 should register Colorful Friends"
	var steps := effects[0].get_attack_interaction_steps(eevee.get_top_card(), eevee.get_card_data().attacks[0], state)
	processor.execute_attack_effect(eevee, 0, state.players[1].active_pokemon, state, [{"colorful_friends": [fire_a, fire_b, water, grass]}])
	return run_checks([
		assert_eq(steps.size(), 1, "Colorful Friends should expose one full-library search step"),
		assert_eq(str(steps[0].get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Colorful Friends should expose the full own deck"),
		assert_eq(steps[0].get("items", []), [fire_a, fire_b, water, grass], "Colorful Friends should expose every Pokemon and no Trainer cards"),
		assert_eq(state.players[0].hand, [fire_a, water, grass], "Colorful Friends should keep only the first selected Pokemon of each type, up to three"),
		assert_true(fire_b in state.players[0].deck, "Colorful Friends should reject a duplicate selected Pokemon type"),
		assert_true(processor.get_attack_effects_for_slot(eevee, 1).is_empty(), "Eevee's Skip should remain numeric-only"),
	])


func test_surfer_switches_to_explicit_bench_target_then_draws_until_five() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var surfer := CardInstance.create(_load_card("CSV8C_196"), 0)
	var old_active := state.players[0].active_pokemon
	var first := _pokemon("First Bench", "C", 0)
	var selected := _pokemon("Selected Bench", "C", 0)
	state.players[0].bench = [first, selected]
	var hand_a := _item("Hand A")
	var hand_b := _item("Hand B")
	state.players[0].hand = [hand_a, hand_b]
	var draw_a := _item("Draw A")
	var draw_b := _item("Draw B")
	var draw_c := _item("Draw C")
	var remains := _item("Remains")
	state.players[0].deck = [draw_a, draw_b, draw_c, remains]
	var effect := processor.get_effect(EFFECT_SURFER)
	if effect == null:
		return "CSV8C_196 should register Surfer"
	var steps := effect.get_interaction_steps(surfer, state)
	var executed := processor.execute_card_effect(surfer, [{"surfer_switch_target": [selected]}], state)
	return run_checks([
		assert_true(effect.can_execute(surfer, state), "Surfer should be playable when its owner has a Benched Pokemon"),
		assert_eq(steps.size(), 1, "Surfer should expose one required switch choice"),
		assert_eq(steps[0].get("items", []), [first, selected], "Surfer should expose every own Benched Pokemon"),
		assert_true(executed, "Surfer should execute through EffectProcessor"),
		assert_eq(state.players[0].active_pokemon, selected, "Surfer should promote the explicitly selected Benched Pokemon"),
		assert_true(old_active in state.players[0].bench, "Surfer should move the old Active Pokemon to the Bench"),
		assert_eq(state.players[0].hand, [hand_a, hand_b, draw_a, draw_b, draw_c], "Surfer should draw exactly until the hand reaches five"),
		assert_eq(state.players[0].deck, [remains], "Surfer should leave later deck cards untouched after reaching five"),
	])


func test_surfer_cannot_execute_without_a_benched_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var surfer := CardInstance.create(_load_card("CSV8C_196"), 0)
	var effect := processor.get_effect(EFFECT_SURFER)
	if effect == null:
		return "CSV8C_196 should register Surfer"
	return run_checks([
		assert_false(effect.can_execute(surfer, state), "Surfer should require a legal switch target"),
		assert_true(effect.get_interaction_steps(surfer, state).is_empty(), "Surfer should expose no invalid interaction without a Bench"),
	])


func test_calamitous_snowy_mountain_damages_either_players_basic_non_water_after_hand_attachment() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	state.stadium_card = CardInstance.create(_load_card("CSV3C_129"), 0)
	var own_basic := _pokemon("Own Basic", "L", 0)
	var opponent_basic := _pokemon("Opponent Basic", "F", 1)
	state.players[0].bench = [own_basic]
	state.players[1].bench = [opponent_basic]
	processor.process_after_energy_attached_from_hand(0, own_basic, state)
	processor.process_after_energy_attached_from_hand(1, opponent_basic, state)
	return run_checks([
		assert_eq(_script_name(processor.get_effect(EFFECT_SNOWY_MOUNTAIN)), "EffectCalamitousSnowyMountain.gd", "CSV3C_129 should register its Stadium trigger"),
		assert_eq(own_basic.damage_counters, 20, "Snowy Mountain should put 2 damage counters on its controller's Basic non-Water Pokemon"),
		assert_eq(opponent_basic.damage_counters, 20, "Snowy Mountain should put 2 damage counters on the opponent's Basic non-Water Pokemon"),
	])


func test_calamitous_snowy_mountain_excludes_water_and_evolved_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	state.stadium_card = CardInstance.create(_load_card("CSV3C_129"), 0)
	var water_basic := _pokemon("Water Basic", "W", 0)
	var evolved_fire := _pokemon("Evolved Fire", "R", 0, "Stage 1")
	state.players[0].bench = [water_basic, evolved_fire]
	processor.process_after_energy_attached_from_hand(0, water_basic, state)
	processor.process_after_energy_attached_from_hand(0, evolved_fire, state)
	return run_checks([
		assert_eq(water_basic.damage_counters, 0, "Snowy Mountain should exclude Basic Water Pokemon"),
		assert_eq(evolved_fire.damage_counters, 0, "Snowy Mountain should exclude evolved non-Water Pokemon"),
	])


func test_calamitous_snowy_mountain_triggers_through_manual_energy_attachment() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	gsm.game_state.stadium_card = CardInstance.create(_load_card("CSV3C_129"), 0)
	var target := _pokemon("Manual Attach Target", "L", 0)
	var energy := _energy("Hand Energy", 0)
	gsm.game_state.players[0].bench = [target]
	gsm.game_state.players[0].hand = [energy]
	var attached := gsm.attach_energy(0, energy, target)
	return run_checks([
		assert_true(attached, "Manual Energy attachment should succeed in the Stadium integration fixture"),
		assert_true(energy in target.attached_energy, "Manual Energy should attach before Snowy Mountain resolves"),
		assert_eq(target.damage_counters, 20, "GameStateMachine manual attachment should invoke Snowy Mountain's 2 counters"),
	])


func test_dunsparce_find_a_friend_searches_exactly_one_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var dunsparce := _slot(_load_card("CSVH3aC_002"), 0)
	var first := _pokemon_card("First Pokemon", "C")
	var selected := _pokemon_card("Selected Pokemon", "P")
	var trainer := _item("Trainer")
	state.players[0].active_pokemon = dunsparce
	state.players[0].deck = [first, trainer, selected]
	processor.register_pokemon_card(dunsparce.get_card_data())
	var effects := processor.get_attack_effects_for_slot(dunsparce, 0)
	if effects.is_empty():
		return "CSVH3aC_002 should register Find a Friend"
	var steps := effects[0].get_attack_interaction_steps(dunsparce.get_top_card(), dunsparce.get_card_data().attacks[0], state)
	processor.execute_attack_effect(dunsparce, 0, state.players[1].active_pokemon, state, [{"search_cards": [selected]}])
	return run_checks([
		assert_eq(_script_name(effects[0]), "AttackSearchDeckToHand.gd", "Find a Friend should reuse the audited deck-search effect"),
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [first, selected], "Find a Friend should expose only Pokemon from the full deck"),
		assert_eq(state.players[0].hand, [selected], "Find a Friend should move the explicitly selected Pokemon to hand"),
		assert_true(first in state.players[0].deck and trainer in state.players[0].deck, "Find a Friend should leave unselected cards in deck"),
		assert_true(processor.get_attack_effects_for_slot(dunsparce, 1).is_empty(), "Dunsparce's Bite should remain numeric-only"),
	])


func test_existing_hops_zacian_ex_remains_exactly_implemented_for_jtg_111_override() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var zacian := _slot(_load_card("CSV10C_161"), 0)
	var first := _pokemon("First Target", "C", 1)
	var selected := _pokemon("Selected Target", "C", 1)
	state.players[0].active_pokemon = zacian
	state.players[1].bench = [first, selected]
	processor.register_pokemon_card(zacian.get_card_data())
	var first_effects := processor.get_attack_effects_for_slot(zacian, 0)
	var second_effects := processor.get_attack_effects_for_slot(zacian, 1)
	processor.execute_attack_effect(zacian, 0, state.players[1].active_pokemon, state, [{"bench_target": [selected]}])
	processor.execute_attack_effect(zacian, 1, state.players[1].active_pokemon, state)
	return run_checks([
		assert_eq(first_effects.size(), 1, "Hop's Zacian ex first attack should keep only selected Bench damage"),
		assert_eq(second_effects.size(), 1, "Hop's Zacian ex second attack should keep only its self lock"),
		assert_eq(selected.damage_counters, 30, "Slash Down should deal 30 to the selected opposing Benched Pokemon"),
		assert_eq(first.damage_counters, 0, "Slash Down should not hit an unselected Bench target"),
		assert_eq(int(zacian.effects.back().get("attack_index", -1)), 1, "Brave Blade should lock only the second attack"),
	])
