class_name TestTCGMikCSVL1C036037CSV95C100
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")

const TING_LU_EX_EFFECT_ID := "6db296a19d741896c070fe471e92b8f3"
const KORAIDON_EX_EFFECT_ID := "94df9ff8b811a6ae267a87194abd5323"
const TING_LU_EFFECT_ID := "a1a72373d6d9233349e8a3ef92a0c14d"
const TING_LU_EX_TARGET_STEP_ID := "opponent_bench_damage_counter_target"
const KORAIDON_ASSIGNMENT_STEP_ID := "dino_cry_fighting_energy_assignments"
const TING_LU_ENERGY_STEP_ID := "discard_energy"
const TING_LU_TARGET_STEP_ID := "attach_target"


func test_imported_cards_preserve_api_metadata_and_are_visible_in_the_pokemon_pool() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var specs := [
		{
			"uid": "CSVL1C_036",
			"set_code": "CSVL1C",
			"card_index": "036",
			"name": "古鼎鹿ex",
			"name_en": "Ting-Lu ex",
			"effect_id": TING_LU_EX_EFFECT_ID,
			"attack_count": 1,
			"ability_count": 1,
		},
		{
			"uid": "CSVL1C_037",
			"set_code": "CSVL1C",
			"card_index": "037",
			"name": "故勒顿ex",
			"name_en": "Koraidon ex",
			"effect_id": KORAIDON_EX_EFFECT_ID,
			"attack_count": 1,
			"ability_count": 1,
		},
		{
			"uid": "CSV9.5C_100",
			"set_code": "CSV9.5C",
			"card_index": "100",
			"name": "古鼎鹿",
			"name_en": "Ting-Lu",
			"effect_id": TING_LU_EFFECT_ID,
			"attack_count": 2,
			"ability_count": 0,
		},
	]
	var db := CardDatabaseScript.new()
	var pooled_uids := {}
	for pooled: CardData in db.get_all_cards():
		if pooled != null:
			pooled_uids[pooled.get_uid()] = true
	var checks: Array[String] = []
	for spec: Dictionary in specs:
		var uid := str(spec.get("uid", ""))
		var set_code := str(spec.get("set_code", ""))
		var card_index := str(spec.get("card_index", ""))
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_str_contains(manifest, card_path, "%s JSON should be in the bundled manifest" % uid))
		checks.append(assert_str_contains(manifest, image_path, "%s image should be in the bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase" % uid))
		checks.append(assert_true(db.has_card(set_code, card_index), "%s should be recognized by CardDatabase.has_card" % uid))
		checks.append(assert_true(pooled_uids.has(uid), "%s should be present in CardDatabase.get_all_cards" % uid))
		if card != null:
			checks.append(assert_eq(card.name, str(spec.get("name", "")), "%s should preserve its Chinese name" % uid))
			checks.append(assert_eq(card.name_en, str(spec.get("name_en", "")), "%s should preserve its English name" % uid))
			checks.append(assert_eq(card.card_type, "Pokemon", "%s should remain a Pokemon" % uid))
			checks.append(assert_eq(card.stage, "Basic", "%s should remain a Basic Pokemon" % uid))
			checks.append(assert_eq(card.effect_id, str(spec.get("effect_id", "")), "%s should preserve its API effect id" % uid))
			checks.append(assert_eq(card.attacks.size(), int(spec.get("attack_count", -1)), "%s should preserve every printed attack" % uid))
			checks.append(assert_eq(card.abilities.size(), int(spec.get("ability_count", -1)), "%s should preserve every printed Ability" % uid))
	db.free()

	var editor := DeckEditorScript.new()
	editor.call("_build_pool")
	var pokemon_uids := {}
	var categories: Array = editor.get("_pool_by_category")
	if not categories.is_empty():
		for pooled: CardData in categories[0]:
			pokemon_uids[pooled.get_uid()] = true
	for uid: String in ["CSVL1C_036", "CSVL1C_037", "CSV9.5C_100"]:
		checks.append(assert_true(pokemon_uids.has(uid), "%s should be selectable in the DeckEditor Pokemon tab" % uid))
	editor.free()
	return run_checks(checks)


func test_csvl1c036_cursed_land_only_suppresses_damaged_opponent_non_ex_pokemon() -> String:
	var card := _load_card("CSVL1C", "036")
	if card == null:
		return assert_not_null(card, "CSVL1C_036 should load")
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var ting_lu := _make_slot(card, 0)
	var own_damaged := _make_slot(_pokemon("Own Damaged", 120, "C", "Basic", "", true), 0)
	var opponent_damaged_active := _make_slot(_pokemon("Opponent Damaged Active", 120, "C", "Basic", "", true), 1)
	var opponent_damaged_bench := _make_slot(_pokemon("Opponent Damaged Bench", 120, "C", "Stage 1", "", true), 1)
	var opponent_healthy := _make_slot(_pokemon("Opponent Healthy", 120, "C", "Basic", "", true), 1)
	var opponent_damaged_ex := _make_slot(_pokemon("Opponent Damaged ex", 220, "C", "Basic", "ex", true), 1)
	own_damaged.damage_counters = 10
	opponent_damaged_active.damage_counters = 10
	opponent_damaged_bench.damage_counters = 20
	opponent_damaged_ex.damage_counters = 10
	player.active_pokemon = ting_lu
	player.bench = [own_damaged]
	opponent.active_pokemon = opponent_damaged_active
	opponent.bench = [opponent_damaged_bench, opponent_healthy, opponent_damaged_ex]
	gsm.effect_processor.register_pokemon_card(card)

	var active_disabled := gsm.effect_processor.is_ability_disabled(opponent_damaged_active, gsm.game_state)
	var bench_disabled := gsm.effect_processor.is_ability_disabled(opponent_damaged_bench, gsm.game_state)
	var healthy_disabled := gsm.effect_processor.is_ability_disabled(opponent_healthy, gsm.game_state)
	var ex_disabled := gsm.effect_processor.is_ability_disabled(opponent_damaged_ex, gsm.game_state)
	var own_disabled := gsm.effect_processor.is_ability_disabled(own_damaged, gsm.game_state)

	player.active_pokemon = own_damaged
	player.bench = [ting_lu]
	var disabled_while_ting_lu_benched := gsm.effect_processor.is_ability_disabled(opponent_damaged_active, gsm.game_state)

	player.active_pokemon = ting_lu
	player.bench = [own_damaged]
	ting_lu.effects.append({"type": "ability_disabled", "turn": gsm.game_state.turn_number})
	var disabled_while_source_suppressed := gsm.effect_processor.is_ability_disabled(opponent_damaged_active, gsm.game_state)

	return run_checks([
		assert_true(active_disabled, "Cursed Land should suppress a damaged opponent Active non-ex Pokemon"),
		assert_true(bench_disabled, "Cursed Land should suppress a damaged opponent Benched non-ex Pokemon"),
		assert_false(healthy_disabled, "Cursed Land should not suppress an undamaged opponent Pokemon"),
		assert_false(ex_disabled, "Cursed Land should exclude Pokemon ex"),
		assert_false(own_disabled, "Cursed Land should never suppress the controller's Pokemon"),
		assert_false(disabled_while_ting_lu_benched, "Cursed Land should stop when Ting-Lu ex leaves the Active Spot"),
		assert_false(disabled_while_source_suppressed, "A disabled Ting-Lu ex should not keep suppressing the opponent"),
	])


func test_csvl1c036_cursed_land_and_basic_lock_resolve_by_continuous_ability_order() -> String:
	var card := _load_card("CSVL1C", "036")
	if card == null:
		return assert_not_null(card, "CSVL1C_036 should load")

	var earlier_ting_lu_state := _make_state()
	var earlier_ting_lu := _make_slot(card, 0)
	earlier_ting_lu.mark_entered_play(10)
	earlier_ting_lu.mark_became_active(10)
	var later_klefki := _make_basic_lock_slot(1, 20)
	later_klefki.damage_counters = 10
	earlier_ting_lu_state.players[0].active_pokemon = earlier_ting_lu
	earlier_ting_lu_state.players[1].active_pokemon = later_klefki
	var earlier_ting_lu_processor := EffectProcessor.new()

	var earlier_klefki_state := _make_state()
	var earlier_klefki := _make_basic_lock_slot(1, 30)
	earlier_klefki.damage_counters = 10
	var later_ting_lu := _make_slot(card, 0)
	later_ting_lu.mark_entered_play(40)
	later_ting_lu.mark_became_active(40)
	earlier_klefki_state.players[0].active_pokemon = later_ting_lu
	earlier_klefki_state.players[1].active_pokemon = earlier_klefki
	var earlier_klefki_processor := EffectProcessor.new()

	return run_checks([
		assert_true(
			earlier_ting_lu_processor.is_ability_disabled(later_klefki, earlier_ting_lu_state),
			"Earlier Cursed Land should suppress a later damaged opposing Klefki",
		),
		assert_false(
			earlier_ting_lu_processor.is_ability_disabled(earlier_ting_lu, earlier_ting_lu_state),
			"A later suppressed Mischievous Lock should not disable the earlier Ting-Lu ex",
		),
		assert_false(
			earlier_klefki_processor.is_ability_disabled(earlier_klefki, earlier_klefki_state),
			"Earlier Mischievous Lock should remain active against a later Ting-Lu ex",
		),
		assert_true(
			earlier_klefki_processor.is_ability_disabled(later_ting_lu, earlier_klefki_state),
			"Earlier Mischievous Lock should disable the later Basic Ting-Lu ex",
		),
	])


func test_csvl1c036_cursed_land_suppresses_other_damaged_continuous_lock_sources() -> String:
	var card := _load_card("CSVL1C", "036")
	if card == null:
		return assert_not_null(card, "CSVL1C_036 should load")

	var dark_wing_state := _make_state()
	var ting_lu_against_dark_wing := _make_slot(card, 0)
	ting_lu_against_dark_wing.mark_entered_play(50)
	ting_lu_against_dark_wing.mark_became_active(50)
	var flutter_card := _pokemon("Flutter Mane", 90, "P", "Basic", "", true)
	flutter_card.abilities = [{
		"name": AbilityDisableOpponentAbility.ABILITY_NAME,
		"text": "Disable the opposing Active Pokemon's Abilities.",
	}]
	var later_flutter := _make_slot(flutter_card, 1)
	later_flutter.damage_counters = 10
	later_flutter.mark_entered_play(60)
	later_flutter.mark_became_active(60)
	dark_wing_state.players[0].active_pokemon = ting_lu_against_dark_wing
	dark_wing_state.players[1].active_pokemon = later_flutter
	var dark_wing_processor := EffectProcessor.new()

	var basic_v_state := _make_state()
	var ting_lu_against_spiritomb := _make_slot(card, 0)
	ting_lu_against_spiritomb.mark_entered_play(70)
	ting_lu_against_spiritomb.mark_became_active(70)
	var own_basic_v := _make_slot(_pokemon("Own Basic V", 200, "C", "Basic", "V", true), 0)
	var spiritomb_card := _pokemon("Spiritomb", 70, "D", "Basic", "", true)
	spiritomb_card.effect_id = AbilityBasicVLock.SPIRITOMB_EFFECT_ID
	var damaged_spiritomb := _make_slot(spiritomb_card, 1)
	damaged_spiritomb.damage_counters = 10
	damaged_spiritomb.mark_entered_play(80)
	basic_v_state.players[0].active_pokemon = ting_lu_against_spiritomb
	basic_v_state.players[0].bench = [own_basic_v]
	basic_v_state.players[1].active_pokemon = _make_slot(_pokemon("Opponent Active", 120), 1)
	basic_v_state.players[1].bench = [damaged_spiritomb]
	var basic_v_processor := EffectProcessor.new()

	return run_checks([
		assert_true(
			dark_wing_processor.is_ability_disabled(later_flutter, dark_wing_state),
			"Cursed Land should suppress a damaged opposing Flutter Mane",
		),
		assert_false(
			dark_wing_processor.is_ability_disabled(ting_lu_against_dark_wing, dark_wing_state),
			"The suppressed Dark Wing source should not disable Ting-Lu ex",
		),
		assert_true(
			basic_v_processor.is_ability_disabled(damaged_spiritomb, basic_v_state),
			"Cursed Land should suppress a damaged opposing Spiritomb",
		),
		assert_false(
			basic_v_processor.is_ability_disabled(own_basic_v, basic_v_state),
			"The suppressed Spiritomb source should not disable the controller's Basic Pokemon V",
		),
	])


func test_csvl1c036_land_scoop_requires_one_bench_target_and_places_exactly_two_counters() -> String:
	var card := _load_card("CSVL1C", "036")
	if card == null:
		return assert_not_null(card, "CSVL1C_036 should load")
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var attacker := _make_slot(card, 0)
	var defender := _make_slot(_pokemon("Defender", 400), 1)
	var bench_a := _make_slot(_pokemon("Bench A", 200), 1)
	var bench_b := _make_slot(_pokemon("Bench B", 200), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	opponent.bench = [bench_a, bench_b]
	_attach_energy(attacker, "F", 3, 0)
	gsm.effect_processor.register_pokemon_card(card)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var target_effect := _find_effect_by_suffix(effects, "AttackChooseOpponentBenchDamageCounters.gd")
	var steps: Array = target_effect.get_attack_interaction_steps(
		attacker.get_top_card(),
		card.attacks[0],
		gsm.game_state,
	) if target_effect != null else []
	var items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var missing_valid := gsm.effect_processor.validate_attack_effect_context(attacker, 0, defender, gsm.game_state, [])
	var active_valid := gsm.effect_processor.validate_attack_effect_context(
		attacker,
		0,
		defender,
		gsm.game_state,
		[{TING_LU_EX_TARGET_STEP_ID: [defender]}],
	)
	var bench_valid := gsm.effect_processor.validate_attack_effect_context(
		attacker,
		0,
		defender,
		gsm.game_state,
		[{TING_LU_EX_TARGET_STEP_ID: [bench_b]}],
	)
	var used := gsm.use_attack(0, 0, [{TING_LU_EX_TARGET_STEP_ID: [bench_b]}])

	return run_checks([
		assert_not_null(target_effect, "Land Scoop should register a bench-only damage-counter target effect"),
		assert_eq(steps.size(), 1, "Land Scoop should expose one target-selection step"),
		assert_eq(items, [bench_a, bench_b], "Land Scoop should expose only the opponent Bench"),
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 1, "Land Scoop should require one target"),
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 1, "Land Scoop should select exactly one target"),
		assert_false(missing_valid, "Land Scoop should reject a missing mandatory target"),
		assert_false(active_valid, "Land Scoop should reject the opponent Active Pokemon"),
		assert_true(bench_valid, "Land Scoop should accept a legal opponent Bench target"),
		assert_true(used, "Land Scoop should resolve through GameStateMachine"),
		assert_eq(defender.damage_counters, 150, "Land Scoop should still deal its printed 150 Active damage"),
		assert_eq(bench_a.damage_counters, 0, "The unselected Bench Pokemon should not receive counters"),
		assert_eq(bench_b.damage_counters, 20, "The selected Bench Pokemon should receive exactly 2 damage counters"),
	])


func test_csvl1c037_dino_cry_assigns_up_to_two_basic_fighting_energy_and_ends_turn() -> String:
	var card := _load_card("CSVL1C", "037")
	if card == null:
		return assert_not_null(card, "CSVL1C_037 should load")
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var koraidon := _make_slot(card, 0)
	var fighting_basic := _make_slot(_pokemon("Fighting Basic", 120, "F"), 0)
	var fighting_stage_one := _make_slot(_pokemon("Fighting Stage 1", 140, "F", "Stage 1"), 0)
	var colorless_basic := _make_slot(_pokemon("Colorless Basic", 120, "C"), 0)
	player.active_pokemon = koraidon
	player.bench = [fighting_basic, fighting_stage_one, colorless_basic]
	gsm.game_state.players[1].active_pokemon = _make_slot(_pokemon("Opponent Active", 120), 1)
	var fighting_one := _energy_instance("Fighting One", "F", 0)
	var fighting_two := _energy_instance("Fighting Two", "F", 0)
	var water := _energy_instance("Water", "W", 0)
	player.discard_pile = [water, fighting_one, fighting_two]
	gsm.effect_processor.register_pokemon_card(card)

	var effect := gsm.effect_processor.get_effect(KORAIDON_EX_EFFECT_ID)
	var steps: Array = effect.get_interaction_steps(koraidon.get_top_card(), gsm.game_state) if effect != null else []
	var source_items: Array = steps[0].get("source_items", []) if not steps.is_empty() else []
	var target_items: Array = steps[0].get("target_items", []) if not steps.is_empty() else []
	var can_use_before: bool = bool(effect.can_use_ability(koraidon, gsm.game_state)) if effect != null else false
	var ai_actions := AILegalActionBuilderScript.new().build_actions(gsm, 0, true)
	var ai_action: Dictionary = {}
	for action: Dictionary in ai_actions:
		if str(action.get("kind", "")) == "use_ability" and action.get("source_slot", null) == koraidon:
			ai_action = action
			break
	var ai_context: Dictionary = {}
	var ai_targets: Array = ai_action.get("targets", [])
	if not ai_targets.is_empty() and ai_targets[0] is Dictionary:
		ai_context = ai_targets[0]
	var ai_assignments: Array = ai_context.get(KORAIDON_ASSIGNMENT_STEP_ID, [])
	var used := gsm.use_ability(0, koraidon, 0, [{
		KORAIDON_ASSIGNMENT_STEP_ID: [
			{"source": fighting_one, "target": koraidon},
			{"source": fighting_two, "target": fighting_basic},
		],
	}])

	return run_checks([
		assert_not_null(effect, "Dino Cry should be registered by the source effect id"),
		assert_true(can_use_before, "Dino Cry should be usable with legal discard Energy and targets"),
		assert_eq(steps.size(), 1, "Dino Cry should expose one card-assignment step"),
		assert_eq(str(steps[0].get("ui_mode", "")) if not steps.is_empty() else "", "card_assignment", "Dino Cry should use the shared assignment UI"),
		assert_eq(source_items, [fighting_one, fighting_two], "Dino Cry should expose Basic Fighting Energy but not other Energy"),
		assert_true(koraidon in target_items, "Dino Cry should allow Koraidon ex itself as a Basic Fighting target"),
		assert_true(fighting_basic in target_items, "Dino Cry should allow another Basic Fighting Pokemon"),
		assert_false(fighting_stage_one in target_items, "Dino Cry should exclude evolved Fighting Pokemon"),
		assert_false(colorless_basic in target_items, "Dino Cry should exclude non-Fighting Basic Pokemon"),
		assert_false(ai_action.is_empty(), "The headless AI action builder should expose Dino Cry"),
		assert_false(bool(ai_action.get("requires_interaction", true)), "The headless AI builder should resolve the shared assignment payload"),
		assert_eq(ai_assignments.size(), 2, "The headless Dino Cry action should assign up to both available Basic Fighting Energy"),
		assert_true(used, "Dino Cry should resolve through GameStateMachine"),
		assert_true(fighting_one in koraidon.attached_energy, "The first selected Energy should attach to Koraidon ex"),
		assert_true(fighting_two in fighting_basic.attached_energy, "The second selected Energy should attach to the independently selected target"),
		assert_eq(player.discard_pile, [water], "Only the selected Basic Fighting Energy should leave the discard pile"),
		assert_true(koraidon.has_ability_used(1), "Dino Cry should record its once-per-turn use"),
		assert_eq(gsm.game_state.current_player_index, 1, "Dino Cry should immediately end its controller's turn"),
	])


func test_csvl1c037_dino_cry_rejects_missing_duplicate_and_illegal_assignments() -> String:
	var card := _load_card("CSVL1C", "037")
	if card == null:
		return assert_not_null(card, "CSVL1C_037 should load")
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var koraidon := _make_slot(card, 0)
	var legal_target := _make_slot(_pokemon("Legal Fighting Basic", 120, "F"), 0)
	var illegal_target := _make_slot(_pokemon("Illegal Fighting Evolution", 140, "F", "Stage 1"), 0)
	player.active_pokemon = koraidon
	player.bench = [legal_target, illegal_target]
	gsm.game_state.players[1].active_pokemon = _make_slot(_pokemon("Opponent Active", 120), 1)
	var fighting := _energy_instance("Fighting", "F", 0)
	var water := _energy_instance("Water", "W", 0)
	player.discard_pile = [fighting, water]
	gsm.effect_processor.register_pokemon_card(card)
	var effect := gsm.effect_processor.get_effect(KORAIDON_EX_EFFECT_ID)
	if effect == null:
		return assert_not_null(effect, "Dino Cry effect should be registered")

	var missing: Dictionary = effect.validate_ability_interaction(koraidon, 0, [], gsm.game_state)
	var duplicate: Dictionary = effect.validate_ability_interaction(koraidon, 0, [{
		KORAIDON_ASSIGNMENT_STEP_ID: [
			{"source": fighting, "target": koraidon},
			{"source": fighting, "target": legal_target},
		],
	}], gsm.game_state)
	var wrong_energy: Dictionary = effect.validate_ability_interaction(koraidon, 0, [{
		KORAIDON_ASSIGNMENT_STEP_ID: [{"source": water, "target": legal_target}],
	}], gsm.game_state)
	var wrong_target: Dictionary = effect.validate_ability_interaction(koraidon, 0, [{
		KORAIDON_ASSIGNMENT_STEP_ID: [{"source": fighting, "target": illegal_target}],
	}], gsm.game_state)

	var empty_gsm := _make_gsm()
	var empty_koraidon := _make_slot(card, 0)
	empty_gsm.game_state.players[0].active_pokemon = empty_koraidon
	empty_gsm.game_state.players[1].active_pokemon = _make_slot(_pokemon("Opponent Active", 120), 1)
	empty_gsm.effect_processor.register_pokemon_card(card)
	var empty_steps: Array = effect.get_interaction_steps(empty_koraidon.get_top_card(), empty_gsm.game_state)

	return run_checks([
		assert_false(bool(missing.get("valid", true)), "Dino Cry should reject a missing mandatory assignment payload"),
		assert_str_contains(str(missing.get("reason", "")), KORAIDON_ASSIGNMENT_STEP_ID, "The missing-payload failure should identify the interaction step"),
		assert_false(bool(duplicate.get("valid", true)), "Dino Cry should reject assigning one Energy twice"),
		assert_false(bool(wrong_energy.get("valid", true)), "Dino Cry should reject non-Fighting Energy"),
		assert_false(bool(wrong_target.get("valid", true)), "Dino Cry should reject evolved Fighting targets"),
		assert_false(effect.can_use_ability(empty_koraidon, empty_gsm.game_state), "Dino Cry should be unavailable with no Basic Fighting Energy in discard"),
		assert_true(empty_steps.is_empty(), "Dino Cry should expose no dead interaction step when it has no legal source cards"),
	])


func test_csvl1c037_wild_impact_locks_all_attacks_during_the_next_own_turn() -> String:
	var card := _load_card("CSVL1C", "037")
	if card == null:
		return assert_not_null(card, "CSVL1C_037 should load")
	var gsm := _make_gsm()
	var attacker := _make_slot(card, 0)
	var defender := _make_slot(_pokemon("Defender", 400), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(attacker, "F", 2, 0)
	_attach_energy(attacker, "C", 1, 0)
	gsm.effect_processor.register_pokemon_card(card)

	var used := gsm.use_attack(0, 0)
	var has_lock := attacker.effects.any(func(entry: Dictionary) -> bool:
		return (
			str(entry.get("type", "")) == "attack_lock_all"
			and int(entry.get("source_attack_index", -1)) == 0
		)
	)
	gsm.game_state.turn_number = 3
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var next_turn_reason := gsm.rule_validator.get_attack_unusable_reason(
		gsm.game_state,
		0,
		0,
		gsm.effect_processor,
	)

	return run_checks([
		assert_true(used, "Wild Impact should resolve through GameStateMachine"),
		assert_eq(defender.damage_counters, 220, "Wild Impact should deal its printed 220 damage"),
		assert_true(has_lock, "Wild Impact should mark a whole-Pokemon next-turn attack lock"),
		assert_str_contains(next_turn_reason, "cannot use attacks", "Wild Impact should block every attack during Koraidon's next turn"),
	])


func test_csv95c100_sand_generation_attaches_only_basic_fighting_energy_to_one_chosen_pokemon() -> String:
	var card := _load_card("CSV9.5C", "100")
	if card == null:
		return assert_not_null(card, "CSV9.5C_100 should load")
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var attacker := _make_slot(card, 0)
	var target := _make_slot(_pokemon("Chosen Target", 140, "W"), 0)
	var defender := _make_slot(_pokemon("Defender", 400), 1)
	player.active_pokemon = attacker
	player.bench = [target]
	gsm.game_state.players[1].active_pokemon = defender
	var fighting_one := _energy_instance("Fighting One", "F", 0)
	var fighting_two := _energy_instance("Fighting Two", "F", 0)
	var special_fighting := _energy_instance("Special Fighting", "F", 0, "Special Energy")
	player.discard_pile = [special_fighting, fighting_one, fighting_two]
	_attach_energy(attacker, "F", 1, 0)
	gsm.effect_processor.register_pokemon_card(card)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var attach_effect := _find_effect_by_suffix(effects, "AttackAttachBasicEnergyFromDiscard.gd")
	var steps: Array = attach_effect.get_attack_interaction_steps(
		attacker.get_top_card(),
		card.attacks[0],
		gsm.game_state,
	) if attach_effect != null else []
	var source_items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var target_items: Array = steps[1].get("items", []) if steps.size() > 1 else []
	var used := gsm.use_attack(0, 0, [{
		TING_LU_ENERGY_STEP_ID: [fighting_one, fighting_two],
		TING_LU_TARGET_STEP_ID: [target],
	}])

	return run_checks([
		assert_not_null(attach_effect, "Sand Generation should reuse the discard-to-field Basic Energy attachment effect"),
		assert_eq(steps.size(), 2, "Sand Generation should expose Energy and target selection steps"),
		assert_eq(source_items, [fighting_one, fighting_two], "Sand Generation should expose only Basic Fighting Energy"),
		assert_true(attacker in target_items, "Sand Generation should allow the attacking Ting-Lu as a target"),
		assert_true(target in target_items, "Sand Generation should allow any other own Pokemon as the single target"),
		assert_true(used, "Sand Generation should resolve through GameStateMachine"),
		assert_eq(target.attached_energy, [fighting_one, fighting_two], "Both selected Energy should attach to the same chosen Pokemon"),
		assert_eq(player.discard_pile, [special_fighting], "Special Energy should remain in the discard pile"),
		assert_eq(defender.damage_counters, 0, "Sand Generation should not deal attack damage"),
	])


func test_csv95c100_arrogant_impact_failure_threshold_is_exactly_four_damage_counters() -> String:
	var healthy_gsm := _ting_lu_attack_gsm(30)
	var healthy_attacker := healthy_gsm.game_state.players[0].active_pokemon
	var healthy_defender := healthy_gsm.game_state.players[1].active_pokemon
	var healthy_used := healthy_gsm.use_attack(0, 1)

	var damaged_gsm := _ting_lu_attack_gsm(40)
	var damaged_attacker := damaged_gsm.game_state.players[0].active_pokemon
	var damaged_defender := damaged_gsm.game_state.players[1].active_pokemon
	var damaged_used := damaged_gsm.use_attack(0, 1)

	return run_checks([
		assert_eq(healthy_attacker.damage_counters, 30, "The boundary fixture should preserve 3 counters on Ting-Lu"),
		assert_true(healthy_used, "Arrogant Impact should resolve below the failure threshold"),
		assert_eq(healthy_defender.damage_counters, 220, "Arrogant Impact should deal 220 with only 3 counters on Ting-Lu"),
		assert_eq(damaged_attacker.damage_counters, 40, "The failure fixture should preserve 4 counters on Ting-Lu"),
		assert_true(damaged_used, "A failed attack should still consume the attack action"),
		assert_eq(damaged_defender.damage_counters, 0, "Arrogant Impact should fail with 4 or more counters on Ting-Lu"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card(set_code, card_index)
	db.free()
	return card


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 1
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.prizes.append(_energy_instance("Prize", "C", player_index))
		player.deck.append(_energy_instance("Turn Draw", "C", player_index))
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_basic_lock_slot(owner_index: int, order_stamp: int) -> PokemonSlot:
	var card := _pokemon("Klefki", 70, "P", "Basic", "", true)
	card.abilities = [{"name": AbilityBasicLock.ABILITY_NAME, "text": "Lock Basic Pokemon Abilities."}]
	var slot := _make_slot(card, owner_index)
	slot.mark_entered_play(order_stamp)
	slot.mark_became_active(order_stamp)
	return slot


func _pokemon(
	name: String,
	hp: int,
	energy_type: String = "C",
	stage: String = "Basic",
	mechanic: String = "",
	has_ability: bool = false
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = mechanic
	card.energy_type = energy_type
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	if has_ability:
		card.abilities = [{"name": "Test Ability", "text": "Printed Ability"}]
	return card


func _energy_instance(name: String, energy_type: String, owner_index: int, card_type: String = "Basic Energy") -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _attach_energy(slot: PokemonSlot, energy_type: String, count: int, owner_index: int) -> void:
	for index: int in count:
		slot.attached_energy.append(_energy_instance("%s Energy %d" % [energy_type, index], energy_type, owner_index))


func _find_effect_by_suffix(effects: Array[BaseEffect], suffix: String) -> BaseEffect:
	for effect: BaseEffect in effects:
		if effect == null or effect.get_script() == null:
			continue
		if str(effect.get_script().resource_path).ends_with(suffix):
			return effect
	return null


func _ting_lu_attack_gsm(self_damage: int) -> GameStateMachine:
	var card := _load_card("CSV9.5C", "100")
	var gsm := _make_gsm()
	var attacker := _make_slot(card, 0)
	var defender := _make_slot(_pokemon("Boundary Defender", 400), 1)
	attacker.damage_counters = self_damage
	_attach_energy(attacker, "F", 3, 0)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(card)
	return gsm
