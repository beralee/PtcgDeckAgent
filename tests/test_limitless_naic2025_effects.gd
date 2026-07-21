class_name TestLimitlessNaic2025Effects
extends TestBase

const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")
const EffectRareCandyScript := preload("res://scripts/effects/trainer_effects/EffectRareCandy.gd")
const AttackOpponentActiveEnergyCountDamageScript := preload("res://scripts/effects/pokemon_effects/AttackOpponentActiveEnergyCountDamage.gd")
const AttackItemLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackItemLockNextTurn.gd")
const AbilityPreventSleepSelfScript := preload("res://scripts/effects/pokemon_effects/AbilityPreventSleepSelf.gd")
const AttackFixedCoinFlipDamageScript := preload("res://scripts/effects/pokemon_effects/AttackFixedCoinFlipDamage.gd")
const AttackSelfLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfLockNextTurn.gd")
const AbilityNonRuleBoxBenchDamageShieldScript := preload("res://scripts/effects/pokemon_effects/AbilityNonRuleBoxBenchDamageShield.gd")
const AttackDrawCardsScript := preload("res://scripts/effects/pokemon_effects/AttackDrawCards.gd")
const AbilityMarniesGrimmsnarlPunkUpScript := preload("res://scripts/effects/pokemon_effects/AbilityMarniesGrimmsnarlPunkUp.gd")
const AttackSelectOpponentBenchDamageScript := preload("res://scripts/effects/pokemon_effects/AttackSelectOpponentBenchDamage.gd")
const EffectSpikemuthGymScript := preload("res://scripts/effects/stadium_effects/EffectSpikemuthGym.gd")
const EffectBrocksScoutingScript := preload("res://scripts/effects/trainer_effects/EffectBrocksScouting.gd")
const EffectNamedPokemonFreeRetreatScript := preload("res://scripts/effects/stadium_effects/EffectNamedPokemonFreeRetreat.gd")
const AttackOpponentDiscardBasicEnergyCountDamageScript := preload("res://scripts/effects/pokemon_effects/AttackOpponentDiscardBasicEnergyCountDamage.gd")
const AbilityOpponentDragonWeaknessToPsychicScript := preload("res://scripts/effects/pokemon_effects/AbilityOpponentDragonWeaknessToPsychic.gd")
const AbilityExplodingNeedlesScript := preload("res://scripts/effects/pokemon_effects/AbilityExplodingNeedles.gd")
const CSV9C196CrispinScript := preload("res://scripts/effects/trainer_effects/CSV9C196Crispin.gd")
const CSV9C198CilanScript := preload("res://scripts/effects/trainer_effects/CSV9C198Cilan.gd")
const CSV9C207AreaZeroUnderdepthsScript := preload("res://scripts/effects/stadium_effects/CSV9C207AreaZeroUnderdepths.gd")

const V18_DECK_DISPLAY_NAMES := {
	800018497: "18.0 沙奈朵",
	800018499: "18.0 多龙巴鲁托",
	800018501: "18.0 玛俐的长毛巨魔",
	800018502: "18.0 N的索罗亚克",
	800018509: "18.0 猛雷鼓厄诡椪",
}
const V18_REQUIRED_SIMPLIFIED_CHINESE_REFS := {
	800018497: ["CSV2C_054", "CSV10C_082"],
	800018499: ["CSV9.5C_004", "CSV9C_078", "CSV10C_008", "CSV10C_207"],
	800018501: ["CSV10C_007", "CSV10C_146", "CSV10C_147", "CSV10C_148", "CSV10C_216"],
	800018502: ["CSV9C_198", "CSV10C_040", "CSV10C_041", "CSV10C_144", "CSV10C_145", "CSV10C_166", "CSV10C_190", "CSV10C_215"],
	800018509: ["CSV9.5C_141", "CSV9C_078", "CSV9C_154", "CSV9C_155", "CSV9C_161", "CSV9C_196", "CSV9C_207"],
}


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []
	var flip_count: int = 0

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		flip_count += 1
		var result := false
		if not _results.is_empty():
			result = _results.pop_front()
		coin_flipped.emit(result)
		return result


func test_len_svi_85_kirlia_psychic_counts_opponent_active_energy() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SVI", "85")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var kirlia := _slot(card, 0) if card != null else null
	if kirlia != null:
		state.players[0].active_pokemon = kirlia
		state.players[1].active_pokemon.attached_energy.append_array([
			CardInstance.create(_energy("Psychic Energy", "P"), 1),
			CardInstance.create(_energy("Darkness Energy", "D"), 1),
		])
	var effects := processor.get_attack_effects_for_slot(kirlia, 1) if kirlia != null else []
	var effect: BaseEffect = effects[0] if not effects.is_empty() else null
	var bonus := int(effect.call("get_damage_bonus", kirlia, state)) if effect != null and effect.has_method("get_damage_bonus") else -1

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SVI_85 should load from CardDatabase"),
		assert_eq(card.name, "Kirlia", "LEN_SVI_85 rule name should stay English"),
		assert_eq(card.name_en, "Kirlia", "LEN_SVI_85 English identity should be preserved"),
		assert_eq(card.attacks[1].get("name", ""), "Psychic", "LEN_SVI_85 attack rule name should stay English"),
		assert_true(effect is AttackOpponentActiveEnergyCountDamageScript, "LEN_SVI_85 Psychic should register opponent Active Energy damage"),
		assert_eq(bonus, 40, "LEN_SVI_85 Psychic should add 20 damage for each opponent Active Energy"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SVI_85 should be marked implemented"),
	])


func test_naic2025_gardevoir_mixed_language_kirlia_evolves_from_ralts() -> String:
	var ralts: CardData = CardDatabase.get_card("CSV2C", "053")
	var kirlia: CardData = CardDatabase.get_card("LEN_SVI", "85")
	var gardevoir: CardData = CardDatabase.get_card("CSV2C", "055")
	var state := _make_state()
	state.turn_number = 3
	var player: PlayerState = state.players[0]
	var ralts_slot := _slot(ralts, 0)
	player.active_pokemon = ralts_slot
	var kirlia_instance := CardInstance.create(kirlia, 0) if kirlia != null else null
	if kirlia_instance != null:
		player.hand = [kirlia_instance]

	var validator := RuleValidator.new()
	var can_evolve := validator.can_evolve(state, 0, ralts_slot, kirlia_instance) if kirlia_instance != null else false
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder = AILegalActionBuilderScript.new()
	var ai_has_evolve_action := false
	for action: Dictionary in builder.build_actions(gsm, 0):
		if str(action.get("kind", "")) == "evolve" and action.get("card") == kirlia_instance and action.get("target_slot") == ralts_slot:
			ai_has_evolve_action = true
			break
	var evolved := gsm.evolve_pokemon(0, kirlia_instance, ralts_slot) if kirlia_instance != null else false
	var top_card: CardInstance = ralts_slot.get_top_card()

	return run_checks([
		assert_not_null(ralts, "CSV2C_053 Ralts should load from CardDatabase"),
		assert_not_null(kirlia, "LEN_SVI_85 Kirlia should load from CardDatabase"),
		assert_not_null(gardevoir, "CSV2C_055 Gardevoir ex should load from CardDatabase"),
		assert_eq(ralts.name, "拉鲁拉丝", "CSV2C_053 local rule name should stay Chinese"),
		assert_eq(ralts.name_en, "Ralts", "CSV2C_053 should expose the English identity alias"),
		assert_eq(kirlia.name, "Kirlia", "LEN_SVI_85 rule name should stay English"),
		assert_eq(kirlia.name_zh, "奇鲁莉安", "LEN_SVI_85 should expose the Chinese identity alias"),
		assert_eq(kirlia.evolves_from, "Ralts", "LEN_SVI_85 should keep English evolves_from"),
		assert_eq(gardevoir.evolves_from, "奇鲁莉安", "CSV2C_055 should keep Chinese Stage 1 reference"),
		assert_true(can_evolve, "Kirlia should be able to evolve from Chinese Ralts via name_en alias"),
		assert_true(ai_has_evolve_action, "AI legal actions should expose the mixed-language Kirlia evolution"),
		assert_true(evolved, "GameStateMachine should execute the mixed-language Kirlia evolution"),
		assert_eq(top_card, kirlia_instance, "Ralts slot should have Kirlia on top after evolution"),
	])


func test_naic2025_gardevoir_rare_candy_pairs_chinese_stage2_with_english_stage1_alias() -> String:
	var ralts: CardData = CardDatabase.get_card("CSV2C", "053")
	var gardevoir: CardData = CardDatabase.get_card("CSV2C", "055")
	var rare_candy_data: CardData = CardDatabase.get_card("CSVH1C", "045")
	var direct_state := _make_state()
	direct_state.turn_number = 3
	var direct_player: PlayerState = direct_state.players[0]
	direct_player.active_pokemon = _slot(_pokemon("Other Basic", "Basic", "", "C", 70), 0)
	var direct_ralts_slot := _slot(ralts, 0)
	direct_player.bench = [direct_ralts_slot]
	var direct_rare := CardInstance.create(rare_candy_data, 0) if rare_candy_data != null else null
	var direct_gardevoir := CardInstance.create(gardevoir, 0) if gardevoir != null else null
	if direct_rare != null and direct_gardevoir != null:
		direct_player.hand = [direct_rare, direct_gardevoir]
	var effect = EffectRareCandyScript.new()
	var can_execute := effect.can_execute(direct_rare, direct_state) if direct_rare != null else false
	var steps: Array[Dictionary] = effect.get_interaction_steps(direct_rare, direct_state) if direct_rare != null else []
	var stage2_items: Array = steps[0].get("items", []) if steps.size() > 0 else []
	var target_items: Array = steps[1].get("items", []) if steps.size() > 1 else []
	if direct_rare != null and direct_gardevoir != null:
		effect.execute(direct_rare, [{
			"stage2_card": [direct_gardevoir],
			"target_pokemon": [direct_ralts_slot],
		}], direct_state)
	var direct_top: CardInstance = direct_ralts_slot.get_top_card()

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.game_state.turn_number = 3
	var ai_player: PlayerState = gsm.game_state.players[0]
	ai_player.active_pokemon = _slot(_pokemon("Other Basic", "Basic", "", "C", 70), 0)
	var ai_ralts_slot := _slot(ralts, 0)
	ai_player.bench = [ai_ralts_slot]
	var ai_rare := CardInstance.create(rare_candy_data, 0) if rare_candy_data != null else null
	var ai_gardevoir := CardInstance.create(gardevoir, 0) if gardevoir != null else null
	if ai_rare != null and ai_gardevoir != null:
		ai_player.hand = [ai_rare, ai_gardevoir]
	var builder = AILegalActionBuilderScript.new()
	var ai_action := {}
	for action: Dictionary in builder.build_actions(gsm, 0, true):
		if str(action.get("kind", "")) == "play_trainer" and action.get("card") == ai_rare:
			ai_action = action
			break
	var ai_targets: Array = ai_action.get("targets", []) if not ai_action.is_empty() else []
	var ai_ctx: Dictionary = ai_targets[0] if not ai_targets.is_empty() and ai_targets[0] is Dictionary else {}
	var ai_stage2: Array = ai_ctx.get("stage2_card", [])
	var ai_target: Array = ai_ctx.get("target_pokemon", [])

	return run_checks([
		assert_not_null(ralts, "CSV2C_053 Ralts should load for Rare Candy"),
		assert_not_null(gardevoir, "CSV2C_055 Gardevoir ex should load for Rare Candy"),
		assert_not_null(rare_candy_data, "CSVH1C_045 Rare Candy should load from CardDatabase"),
		assert_true(can_execute, "Rare Candy should be playable without a Kirlia card in player zones"),
		assert_true(direct_gardevoir in stage2_items, "Rare Candy should list Chinese Gardevoir ex as a valid Stage 2 choice"),
		assert_true(direct_ralts_slot in target_items, "Rare Candy should list Chinese Ralts as the matching Basic target"),
		assert_false(direct_player.active_pokemon in target_items, "Rare Candy should not list an unrelated Basic as a target for Gardevoir ex"),
		assert_eq(direct_top, direct_gardevoir, "Rare Candy should evolve Chinese Ralts directly into Gardevoir ex"),
		assert_false(ai_action.is_empty(), "AI should expose a headless Rare Candy action for the NAIC Gardevoir line"),
		assert_eq(ai_stage2[0] if not ai_stage2.is_empty() else null, ai_gardevoir, "AI should select Gardevoir ex as the Rare Candy Stage 2"),
		assert_eq(ai_target[0] if not ai_target.is_empty() else null, ai_ralts_slot, "AI should pair Gardevoir ex with the matching Ralts slot, not the first Basic"),
	])


func test_len_pre_4_budew_itchy_pollen_blocks_opponent_items_next_turn() -> String:
	var card: CardData = CardDatabase.get_card("LEN_PRE", "4")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var budew := _slot(card, 0) if card != null else null
	if budew != null:
		state.players[0].active_pokemon = budew
	var effects := processor.get_attack_effects_for_slot(budew, 0) if budew != null else []
	var effect: BaseEffect = effects[0] if not effects.is_empty() else null
	if effect != null:
		effect.execute_attack(budew, state.players[1].active_pokemon, 0, state)
	var locked_turn := int(state.shared_turn_flags.get("item_lock_1", 0))
	state.current_player_index = 1
	state.turn_number += 1
	var item_blocked := not RuleValidator.new().can_play_item(state, 1)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_PRE_4 should load from CardDatabase"),
		assert_eq(card.name, "Budew", "LEN_PRE_4 rule name should stay English"),
		assert_eq(card.attacks[0].get("name", ""), "Itchy Pollen", "LEN_PRE_4 attack rule name should stay English"),
		assert_true(effect is AttackItemLockNextTurnScript, "LEN_PRE_4 Itchy Pollen should register item lock"),
		assert_eq(locked_turn, 3, "LEN_PRE_4 should lock opponent Items during their next turn"),
		assert_true(item_blocked, "LEN_PRE_4 should make the opponent unable to play Item cards next turn"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_PRE_4 should be marked implemented"),
	])


func test_len_pre_77_hoothoot_insomnia_prevents_sleep_only() -> String:
	var card: CardData = CardDatabase.get_card("LEN_PRE", "77")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var hoothoot := _slot(card, 0) if card != null else null
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_PRE_77 should load from CardDatabase"),
		assert_eq(card.name, "Hoothoot", "LEN_PRE_77 rule name should stay English"),
		assert_eq(card.abilities[0].get("name", ""), "Insomnia", "LEN_PRE_77 ability rule name should stay English"),
		assert_true(effect is AbilityPreventSleepSelfScript, "LEN_PRE_77 Insomnia should register prevent-sleep ability"),
		assert_true(bool(effect.call("prevents_special_status", hoothoot, state, "asleep")) if effect != null else false, "LEN_PRE_77 should prevent Asleep"),
		assert_false(bool(effect.call("prevents_special_status", hoothoot, state, "poisoned")) if effect != null else true, "LEN_PRE_77 should not prevent other status conditions"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_PRE_77 should be marked implemented"),
	])


func test_len_scr_114_hoothoot_triple_stab_flips_three_coins() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SCR", "114")
	var flipper := RiggedCoinFlipper.new([true, false, true])
	var processor := EffectProcessor.new(flipper)
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var hoothoot := _slot(card, 0) if card != null else null
	if hoothoot != null:
		state.players[0].active_pokemon = hoothoot
	var defender := state.players[1].active_pokemon
	defender.damage_counters = 10
	var effects := processor.get_attack_effects_for_slot(hoothoot, 0) if hoothoot != null else []
	var effect: BaseEffect = effects[0] if not effects.is_empty() else null
	if effect != null:
		effect.execute_attack(hoothoot, defender, 0, state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SCR_114 should load from CardDatabase"),
		assert_eq(card.name, "Hoothoot", "LEN_SCR_114 rule name should stay English"),
		assert_eq(card.attacks[0].get("name", ""), "Triple Stab", "LEN_SCR_114 attack rule name should stay English"),
		assert_true(effect is AttackFixedCoinFlipDamageScript, "LEN_SCR_114 Triple Stab should register fixed coin-flip damage"),
		assert_eq(flipper.flip_count, 3, "LEN_SCR_114 should flip exactly three coins"),
		assert_eq(defender.damage_counters, 20, "LEN_SCR_114 should deal 10 damage per heads after printed 10x base"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SCR_114 should be marked implemented"),
	])


func test_len_ssp_76_latias_ex_skyliner_and_eon_blade() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SSP", "76")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var latias := _slot(card, 0) if card != null else null
	var own_basic := state.players[0].active_pokemon
	own_basic.get_card_data().retreat_cost = 3
	if latias != null:
		state.players[0].bench.append(latias)
	var own_stage1 := _slot(_pokemon("Own Stage 1", "Stage 1", "Own Basic", "C", 100), 0)
	own_stage1.get_card_data().retreat_cost = 2
	var opponent_basic := state.players[1].active_pokemon
	opponent_basic.get_card_data().retreat_cost = 3

	var basic_retreat := processor.get_effective_retreat_cost(own_basic, state)
	state.players[0].active_pokemon = own_stage1
	var stage1_retreat := processor.get_effective_retreat_cost(own_stage1, state)
	var opponent_retreat := processor.get_effective_retreat_cost(opponent_basic, state)
	if latias != null:
		state.players[0].active_pokemon = latias
		state.players[0].bench.erase(latias)
	processor.execute_attack_effect(latias, 0, opponent_basic, state)
	var attack_effects := processor.get_attack_effects_for_slot(latias, 0) if latias != null else []
	var attack_effect: BaseEffect = attack_effects[0] if not attack_effects.is_empty() else null
	var locked := latias != null and latias.effects.any(func(e: Dictionary) -> bool:
		return e.get("type", "") == "attack_lock" and int(e.get("attack_index", -1)) == 0
	)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SSP_76 should load from CardDatabase"),
		assert_eq(card.name, "Latias ex", "LEN_SSP_76 rule name should stay English"),
		assert_eq(card.abilities[0].get("name", ""), "Skyliner", "LEN_SSP_76 ability rule name should stay English"),
		assert_eq(card.attacks[0].get("name", ""), "Eon Blade", "LEN_SSP_76 attack rule name should stay English"),
		assert_true(processor.has_effect(card.effect_id) if card != null else false, "LEN_SSP_76 Skyliner should register an ability effect"),
		assert_true(attack_effect is AttackSelfLockNextTurnScript, "LEN_SSP_76 Eon Blade should register self-lock"),
		assert_eq(basic_retreat, 0, "LEN_SSP_76 should make own Basic Pokemon retreat for free"),
		assert_eq(stage1_retreat, 2, "LEN_SSP_76 should not make own Evolution Pokemon retreat for free"),
		assert_eq(opponent_retreat, 3, "LEN_SSP_76 should not affect opponent Basic Pokemon retreat"),
		assert_true(locked, "LEN_SSP_76 Eon Blade should lock itself next own turn"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SSP_76 should be marked implemented"),
	])


func test_len_dri_10_shaymin_flower_curtain_protects_only_non_rule_box_bench() -> String:
	var card: CardData = CardDatabase.get_card("LEN_DRI", "10")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var shaymin := _slot(card, 0) if card != null else null
	var non_rule_target := _slot(_pokemon("Bench Basic", "Basic", "", "G", 80), 0)
	var rule_box_data := _pokemon("Bench ex", "Basic", "", "G", 180)
	rule_box_data.mechanic = "ex"
	rule_box_data.is_tags = PackedStringArray(["ex"])
	var rule_box_target := _slot(rule_box_data, 0)
	if shaymin != null:
		state.players[0].bench.append(shaymin)
	state.players[0].bench.append(non_rule_target)
	state.players[0].bench.append(rule_box_target)
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var non_rule_protected := AbilityBenchImmune.prevents_opponent_attack_damage(
		non_rule_target,
		state.players[1].active_pokemon,
		state
	)
	var rule_box_protected := AbilityBenchImmune.prevents_opponent_attack_damage(
		rule_box_target,
		state.players[1].active_pokemon,
		state
	)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_DRI_10 should load from CardDatabase"),
		assert_eq(card.name, "Shaymin", "LEN_DRI_10 rule name should stay English"),
		assert_eq(card.abilities[0].get("name", ""), "Flower Curtain", "LEN_DRI_10 ability rule name should stay English"),
		assert_true(effect is AbilityNonRuleBoxBenchDamageShieldScript, "LEN_DRI_10 Flower Curtain should register bench damage shield"),
		assert_true(non_rule_protected, "Flower Curtain should prevent attack damage to own Benched non-Rule Box Pokemon"),
		assert_false(rule_box_protected, "Flower Curtain should not prevent attack damage to own Benched Rule Box Pokemon"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_DRI_10 should be marked implemented"),
	])


func test_len_dri_134_impidimp_filch_draws_one_card() -> String:
	var card: CardData = CardDatabase.get_card("LEN_DRI", "134")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var impidimp := _slot(card, 0) if card != null else null
	if impidimp != null:
		state.players[0].active_pokemon = impidimp
	var drawn_card := CardInstance.create(_trainer("Drawn Item", "Item"), 0)
	state.players[0].deck.append(drawn_card)
	var effects := processor.get_attack_effects_for_slot(impidimp, 0) if impidimp != null else []
	var effect: BaseEffect = effects[0] if not effects.is_empty() else null
	processor.execute_attack_effect(impidimp, 0, state.players[1].active_pokemon, state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_DRI_134 should load from CardDatabase"),
		assert_eq(card.name, "Marnie's Impidimp", "LEN_DRI_134 rule name should stay English"),
		assert_eq(card.attacks[0].get("name", ""), "Filch", "LEN_DRI_134 attack rule name should stay English"),
		assert_true(effect is AttackDrawCardsScript, "LEN_DRI_134 Filch should register draw-1 attack effect"),
		assert_true(drawn_card in state.players[0].hand, "LEN_DRI_134 Filch should draw 1 card"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_DRI_134 should be marked implemented"),
	])


func test_len_dri_136_grimmsnarl_punk_up_and_shadow_bullet() -> String:
	var card: CardData = CardDatabase.get_card("LEN_DRI", "136")
	var impidimp_card: CardData = CardDatabase.get_card("LEN_DRI", "134")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var player := state.players[0]
	var grimmsnarl := _slot(card, 0) if card != null else null
	var marnies_bench := _slot(impidimp_card, 0) if impidimp_card != null else null
	if grimmsnarl != null:
		grimmsnarl.turn_evolved = state.turn_number
		player.active_pokemon = grimmsnarl
	if marnies_bench != null:
		player.bench.append(marnies_bench)
	var dark1 := CardInstance.create(_energy("Darkness Energy 1", "D"), 0)
	var fire := CardInstance.create(_energy("Fire Energy", "R"), 0)
	var dark2 := CardInstance.create(_energy("Darkness Energy 2", "D"), 0)
	player.deck = [dark1, fire, dark2]
	var ability_effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var steps: Array[Dictionary] = ability_effect.get_interaction_steps(grimmsnarl.get_top_card(), state) if ability_effect != null and grimmsnarl != null else []
	var assignment_step: Dictionary = steps[0] if not steps.is_empty() else {}
	if ability_effect != null and grimmsnarl != null and marnies_bench != null:
		ability_effect.execute_ability(grimmsnarl, 0, [{
			AbilityMarniesGrimmsnarlPunkUpScript.ASSIGNMENT_STEP_ID: [
				{"source": dark1, "target": grimmsnarl},
				{"source": dark2, "target": marnies_bench},
			],
		}], state)
	var ability_can_reuse := bool(ability_effect.call("can_use_ability", grimmsnarl, state)) if ability_effect != null and grimmsnarl != null else true
	var attack_effects := processor.get_attack_effects_for_slot(grimmsnarl, 0) if grimmsnarl != null else []
	var attack_effect: BaseEffect = attack_effects[0] if not attack_effects.is_empty() else null
	var opponent_bench := _slot(_pokemon("Opponent Bench", "Basic", "", "C", 100), 1)
	state.players[1].bench.append(opponent_bench)
	processor.execute_attack_effect(grimmsnarl, 0, state.players[1].active_pokemon, state, [{
		AttackSelectOpponentBenchDamageScript.STEP_ID: [opponent_bench],
	}])

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_DRI_136 should load from CardDatabase"),
		assert_eq(card.name, "Marnie's Grimmsnarl ex", "LEN_DRI_136 rule name should stay English"),
		assert_eq(card.abilities[0].get("name", ""), "Punk Up", "LEN_DRI_136 ability rule name should stay English"),
		assert_true(ability_effect is AbilityMarniesGrimmsnarlPunkUpScript, "LEN_DRI_136 Punk Up should register an ability effect"),
		assert_eq(assignment_step.get("source_card_indices", []), [0, -1, 1], "Punk Up should expose the full deck and only enable Basic Darkness Energy"),
		assert_true(dark1 in grimmsnarl.attached_energy, "Punk Up should attach selected Darkness Energy to Marnie's Grimmsnarl ex"),
		assert_true(dark2 in marnies_bench.attached_energy, "Punk Up should attach selected Darkness Energy to another Marnie's Pokemon"),
		assert_true(fire in player.deck, "Punk Up should leave non-Darkness Energy in deck"),
		assert_false(ability_can_reuse, "Punk Up should be consumed after resolving once for this evolution"),
		assert_true(attack_effect is AttackSelectOpponentBenchDamageScript, "LEN_DRI_136 Shadow Bullet should register opponent Bench damage"),
		assert_eq(opponent_bench.damage_counters, 30, "Shadow Bullet should place 30 damage on the selected opponent Bench Pokemon"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_DRI_136 should be marked implemented"),
	])


func test_len_dri_169_spikemuth_gym_searches_marnies_pokemon() -> String:
	var card: CardData = CardDatabase.get_card("LEN_DRI", "169")
	var impidimp_card: CardData = CardDatabase.get_card("LEN_DRI", "134")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var state := _make_state()
	var player := state.players[0]
	var stadium := CardInstance.create(card, 0) if card != null else null
	var marnies_card := CardInstance.create(impidimp_card, 0) if impidimp_card != null else null
	var generic_card := CardInstance.create(_pokemon("Generic Basic", "Basic", "", "C", 70), 0)
	if marnies_card != null:
		player.deck.append(marnies_card)
	player.deck.append(generic_card)
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium, state) if effect != null else []
	if effect != null and stadium != null and marnies_card != null:
		effect.execute(stadium, [{
			EffectSpikemuthGymScript.STEP_ID: [marnies_card],
		}], state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_DRI_169 should load from CardDatabase"),
		assert_eq(card.name, "Spikemuth Gym", "LEN_DRI_169 rule name should stay English"),
		assert_true(effect is EffectSpikemuthGymScript, "LEN_DRI_169 should register Spikemuth Gym effect"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1], "Spikemuth Gym should expose full deck and only enable Marnie's Pokemon"),
		assert_true(marnies_card in player.hand, "Spikemuth Gym should move the selected Marnie's Pokemon to hand"),
		assert_true(generic_card in player.deck, "Spikemuth Gym should leave non-Marnie's Pokemon in deck"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_DRI_169 should be marked implemented"),
	])


func test_len_jtg_146_brocks_scouting_searches_basic_or_evolution() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "146")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var state := _make_state()
	var player := state.players[0]
	var scouting := CardInstance.create(card, 0) if card != null else null
	var basic1 := CardInstance.create(_pokemon("Basic A", "Basic", "", "C", 70), 0)
	var stage1 := CardInstance.create(_pokemon("Stage 1 A", "Stage 1", "Basic A", "C", 100), 0)
	var basic2 := CardInstance.create(_pokemon("Basic B", "Basic", "", "C", 80), 0)
	player.deck = [basic1, stage1, basic2]
	var steps: Array[Dictionary] = effect.get_interaction_steps(scouting, state) if effect != null else []
	var basic_followup: Array[Dictionary] = effect.get_followup_interaction_steps(scouting, state, {
		EffectBrocksScoutingScript.MODE_STEP_ID: [EffectBrocksScoutingScript.MODE_BASIC],
	}) if effect != null else []
	if effect != null and scouting != null:
		effect.execute(scouting, [{
			EffectBrocksScoutingScript.MODE_STEP_ID: [EffectBrocksScoutingScript.MODE_BASIC],
			EffectBrocksScoutingScript.BASIC_STEP_ID: [basic1, basic2],
		}], state)

	var state_evolution := _make_state()
	var player_evolution := state_evolution.players[0]
	var scouting_evolution := CardInstance.create(card, 0) if card != null else null
	var evo_basic := CardInstance.create(_pokemon("Basic C", "Basic", "", "C", 70), 0)
	var evo_stage1 := CardInstance.create(_pokemon("Stage 1 C", "Stage 1", "Basic C", "C", 100), 0)
	var evo_basic2 := CardInstance.create(_pokemon("Basic D", "Basic", "", "C", 70), 0)
	player_evolution.deck = [evo_basic, evo_stage1, evo_basic2]
	var evolution_followup: Array[Dictionary] = effect.get_followup_interaction_steps(scouting_evolution, state_evolution, {
		EffectBrocksScoutingScript.MODE_STEP_ID: [EffectBrocksScoutingScript.MODE_EVOLUTION],
	}) if effect != null else []
	if effect != null and scouting_evolution != null:
		effect.execute(scouting_evolution, [{
			EffectBrocksScoutingScript.MODE_STEP_ID: [EffectBrocksScoutingScript.MODE_EVOLUTION],
			EffectBrocksScoutingScript.EVOLUTION_STEP_ID: [evo_stage1],
		}], state_evolution)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_JTG_146 should load from CardDatabase"),
		assert_eq(card.name, "Brock's Scouting", "LEN_JTG_146 rule name should stay English"),
		assert_true(effect is EffectBrocksScoutingScript, "LEN_JTG_146 should register Brock's Scouting effect"),
		assert_true(bool(steps[0].get("requires_followup_interaction", false)) if not steps.is_empty() else false, "Brock's Scouting should split mode and deck search into follow-up steps"),
		assert_eq(basic_followup[0].get("card_indices", []) if not basic_followup.is_empty() else [], [0, -1, 1], "Brock's Scouting Basic mode should expose full deck and only enable Basic Pokemon"),
		assert_true(basic1 in player.hand, "Brock's Scouting Basic mode should move the first selected Basic Pokemon to hand"),
		assert_true(basic2 in player.hand, "Brock's Scouting Basic mode should move the second selected Basic Pokemon to hand"),
		assert_true(stage1 in player.deck, "Brock's Scouting Basic mode should leave Evolution Pokemon in deck"),
		assert_eq(evolution_followup[0].get("card_indices", []) if not evolution_followup.is_empty() else [], [-1, 0, -1], "Brock's Scouting Evolution mode should expose full deck and only enable Evolution Pokemon"),
		assert_true(evo_stage1 in player_evolution.hand, "Brock's Scouting Evolution mode should move the selected Evolution Pokemon to hand"),
		assert_true(evo_basic in player_evolution.deck, "Brock's Scouting Evolution mode should leave Basic Pokemon in deck"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_JTG_146 should be marked implemented"),
	])


func test_len_jtg_152_ns_castle_makes_ns_pokemon_retreat_free() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "152")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var state := _make_state()
	state.stadium_card = CardInstance.create(card, 0) if card != null else null
	var ns_data := _pokemon("N's Zorua", "Basic", "", "D", 70)
	ns_data.retreat_cost = 3
	var generic_data := _pokemon("Generic Pokemon", "Basic", "", "D", 70)
	generic_data.retreat_cost = 2
	var ns_slot := _slot(ns_data, 0)
	var generic_slot := _slot(generic_data, 0)
	state.players[0].active_pokemon = ns_slot
	state.players[0].bench.append(generic_slot)
	var ns_cost := processor.get_effective_retreat_cost(ns_slot, state)
	var generic_cost := processor.get_effective_retreat_cost(generic_slot, state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_JTG_152 should load from CardDatabase"),
		assert_eq(card.name, "N's Castle", "LEN_JTG_152 rule name should stay English"),
		assert_true(effect is EffectNamedPokemonFreeRetreatScript, "LEN_JTG_152 should register N's Pokemon free retreat"),
		assert_eq(ns_cost, 0, "N's Castle should make N's Pokemon retreat for free"),
		assert_eq(generic_cost, 2, "N's Castle should not affect non-N's Pokemon"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_JTG_152 should be marked implemented"),
	])


func test_len_jtg_27_ns_darmanitan_back_draft_and_flamebody_cannon() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "27")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var darmanitan := _slot(card, 0) if card != null else null
	if darmanitan != null:
		state.players[0].active_pokemon = darmanitan
	var basic_fire := CardInstance.create(_energy("Fire Energy", "R"), 1)
	var basic_dark := CardInstance.create(_energy("Darkness Energy", "D"), 1)
	var special := CardInstance.create(_energy("Special Energy", "C", "Special Energy"), 1)
	state.players[1].discard_pile.append_array([basic_fire, basic_dark, special])
	var first_effects := processor.get_attack_effects_for_slot(darmanitan, 0) if darmanitan != null else []
	var first_effect: BaseEffect = first_effects[0] if not first_effects.is_empty() else null
	var bonus := int(first_effect.call("get_damage_bonus", darmanitan, state)) if first_effect != null and first_effect.has_method("get_damage_bonus") else -999
	var resolved_damage := DamageCalculator.new().calculate_damage(darmanitan, state.players[1].active_pokemon, card.attacks[0], state, bonus) if darmanitan != null and card != null else -1
	var attached_fire := CardInstance.create(_energy("Attached Fire", "R"), 0)
	var attached_colorless := CardInstance.create(_energy("Attached Colorless", "C"), 0)
	if darmanitan != null:
		darmanitan.attached_energy.append_array([attached_fire, attached_colorless])
	var opponent_bench := _slot(_pokemon("Opponent Bench", "Basic", "", "C", 100), 1)
	state.players[1].bench.append(opponent_bench)
	processor.execute_attack_effect(darmanitan, 1, state.players[1].active_pokemon, state, [{
		AttackSelectOpponentBenchDamageScript.STEP_ID: [opponent_bench],
	}])
	var second_effects := processor.get_attack_effects_for_slot(darmanitan, 1) if darmanitan != null else []
	var second_steps: Array[Dictionary] = []
	if darmanitan != null and card != null:
		for effect: BaseEffect in second_effects:
			second_steps.append_array(effect.get_attack_interaction_steps(darmanitan.get_top_card(), card.attacks[1], state))
	var bench_step: Dictionary = second_steps[0] if not second_steps.is_empty() else {}

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_JTG_27 should load from CardDatabase"),
		assert_eq(card.name, "N's Darmanitan", "LEN_JTG_27 rule name should stay English"),
		assert_eq(card.name_en, "N's Darmanitan", "LEN_JTG_27 English identity should be preserved"),
		assert_eq(str(card.attacks[1].get("name", "")), "Flamebody Cannon", "LEN_JTG_27 second attack rule name should stay English"),
		assert_true(first_effect is AttackOpponentDiscardBasicEnergyCountDamageScript, "Back Draft should count opponent discard Basic Energy"),
		assert_eq(bonus, 30, "Back Draft should add one extra 30 after printed 30x base for two Basic Energy"),
		assert_eq(resolved_damage, 60, "Back Draft should deal 30 damage per opponent discard Basic Energy"),
		assert_eq(second_effects.size(), 2, "Flamebody Cannon should register discard-all-energy plus Bench damage effects"),
		assert_eq(second_steps.size(), 1, "Flamebody Cannon should expose one Bench target interaction step"),
		assert_eq(str(bench_step.get("id", "")), AttackSelectOpponentBenchDamageScript.STEP_ID, "Flamebody Cannon should ask for opponent Bench damage targets"),
		assert_eq(int(bench_step.get("min_select", 0)), 1, "Flamebody Cannon should require one opponent Bench target"),
		assert_eq(int(bench_step.get("max_select", 0)), 1, "Flamebody Cannon should cap opponent Bench target selection at one"),
		assert_true(attached_fire in state.players[0].discard_pile, "Flamebody Cannon should discard all attached Energy from self"),
		assert_true(attached_colorless in state.players[0].discard_pile, "Flamebody Cannon should discard every attached Energy type"),
		assert_eq(opponent_bench.damage_counters, 90, "Flamebody Cannon should deal 90 damage to selected opponent Bench Pokemon"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_JTG_27 should be marked implemented"),
	])


func test_len_jtg_27_ns_darmanitan_flamebody_cannon_still_asks_with_shaymin() -> String:
	var darmanitan_card: CardData = CardDatabase.get_card("LEN_JTG", "27")
	var shaymin_card: CardData = CardDatabase.get_card("LEN_DRI", "10")
	var processor := EffectProcessor.new()
	if darmanitan_card != null:
		processor.register_pokemon_card(darmanitan_card)
	if shaymin_card != null:
		processor.register_pokemon_card(shaymin_card)
	var state := _make_state()
	var darmanitan := _slot(darmanitan_card, 0) if darmanitan_card != null else null
	if darmanitan != null:
		state.players[0].active_pokemon = darmanitan
	var shaymin := _slot(shaymin_card, 1) if shaymin_card != null else null
	var protected_bench := _slot(_pokemon("Protected Bench", "Basic", "", "C", 100), 1)
	if shaymin != null:
		state.players[1].bench.append(shaymin)
	state.players[1].bench.append(protected_bench)
	var second_effects := processor.get_attack_effects_for_slot(darmanitan, 1) if darmanitan != null else []
	var second_steps: Array[Dictionary] = []
	if darmanitan != null and darmanitan_card != null:
		for effect: BaseEffect in second_effects:
			second_steps.append_array(effect.get_attack_interaction_steps(darmanitan.get_top_card(), darmanitan_card.attacks[1], state))
	var bench_step: Dictionary = second_steps[0] if not second_steps.is_empty() else {}
	processor.execute_attack_effect(darmanitan, 1, state.players[1].active_pokemon, state, [{
		AttackSelectOpponentBenchDamageScript.STEP_ID: [protected_bench],
	}])

	return run_checks([
		assert_not_null(darmanitan_card, "LEN_JTG_27 should load from CardDatabase"),
		assert_not_null(shaymin_card, "LEN_DRI_10 Shaymin should load from CardDatabase"),
		assert_eq(second_steps.size(), 1, "Flamebody Cannon should still ask for a Bench target when Flower Curtain is in play"),
		assert_eq(str(bench_step.get("id", "")), AttackSelectOpponentBenchDamageScript.STEP_ID, "Flamebody Cannon should keep the opponent Bench target picker under Shaymin"),
		assert_eq((bench_step.get("items", []) as Array).size(), 2, "Shaymin should not remove opponent Bench choices from the picker"),
		assert_eq(protected_bench.damage_counters, 0, "Flower Curtain should prevent Flamebody Cannon damage to a non-Rule Box Benched Pokemon after selection"),
	])


func test_len_jtg_56_lillies_clefairy_fairy_zone_and_full_moon_rondo() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "56")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var clefairy := _slot(card, 0) if card != null else null
	if clefairy != null:
		state.players[0].active_pokemon = clefairy
	state.players[0].bench.append(_slot(_pokemon("Own Bench", "Basic", "", "C", 70), 0))
	state.players[1].bench.append(_slot(_pokemon("Opp Bench A", "Basic", "", "C", 70), 1))
	state.players[1].bench.append(_slot(_pokemon("Opp Bench B", "Basic", "", "C", 70), 1))
	var dragon_data := _pokemon("Opponent Dragon", "Basic", "", "N", 120)
	dragon_data.weakness_energy = ""
	dragon_data.weakness_value = ""
	var dragon := _slot(dragon_data, 1)
	state.players[1].active_pokemon = dragon
	var ability_effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var weakness_energy := processor.get_weakness_energy_override(clefairy, dragon, state) if clefairy != null else ""
	var weakness_value := processor.get_weakness_value_override(clefairy, dragon, state) if clefairy != null else ""
	var damage_with_fairy_zone := DamageCalculator.new().calculate_damage(clefairy, dragon, {"damage": "20"}, state, 0, 0, 0, false, false, weakness_value, weakness_energy) if clefairy != null else -1
	var attack_effects := processor.get_attack_effects_for_slot(clefairy, 0) if clefairy != null else []
	var rondo_effect: BaseEffect = attack_effects[0] if not attack_effects.is_empty() else null
	var rondo_bonus := int(rondo_effect.call("get_damage_bonus", clefairy, state)) if rondo_effect != null and rondo_effect.has_method("get_damage_bonus") else -1

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_JTG_56 should load from CardDatabase"),
		assert_eq(card.name, "Lillie's Clefairy ex", "LEN_JTG_56 rule name should stay English"),
		assert_true(ability_effect is AbilityOpponentDragonWeaknessToPsychicScript, "Fairy Zone should register Dragon Weakness override ability"),
		assert_eq(weakness_energy, "P", "Fairy Zone should make opponent Dragon Pokemon weak to Psychic"),
		assert_eq(weakness_value, "x2", "Fairy Zone should apply Dragon Pokemon's new Psychic Weakness as x2 even when printed Weakness is blank"),
		assert_eq(damage_with_fairy_zone, 40, "Psychic Clefairy attack should hit opponent Dragon for Weakness after Fairy Zone"),
		assert_eq(rondo_bonus, 60, "Full Moon Rondo should add 20 damage for each Benched Pokemon on both sides"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_JTG_56 should be marked implemented"),
	])


func test_len_jtg_56_lillies_clefairy_bench_fairy_zone_applies_in_gsm_damage_path() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "56")
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var attacker_data := _pokemon("Psychic Attacker", "Basic", "", "P", 100, [
		{"name": "Psy Hit", "cost": "", "damage": "20", "is_vstar_power": false}
	])
	var dragon_data := _pokemon("No Weakness Dragon", "Basic", "", "N", 120)
	dragon_data.weakness_energy = ""
	dragon_data.weakness_value = ""
	var attacker := _slot(attacker_data, 0)
	var clefairy := _slot(card, 0) if card != null else null
	var dragon := _slot(dragon_data, 1)
	player.active_pokemon = attacker
	if clefairy != null:
		player.bench = [clefairy]
	opponent.active_pokemon = dragon

	var weakness_energy := gsm.effect_processor.get_weakness_energy_override(attacker, dragon, state)
	var weakness_value := gsm.effect_processor.get_weakness_value_override(attacker, dragon, state)
	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(card, "LEN_JTG_56 should load from CardDatabase"),
		assert_eq(weakness_energy, "P", "Bench Fairy Zone should expose a Psychic Weakness override through the bound EffectProcessor"),
		assert_eq(weakness_value, "x2", "Bench Fairy Zone should expose an x2 Weakness value override through the bound EffectProcessor"),
		assert_eq(preview_damage, 40, "Bench Fairy Zone should affect the GameStateMachine preview damage path"),
		assert_true(attacked, "Zero-cost test attack should execute through GameStateMachine"),
		assert_eq(dragon.damage_counters, 40, "Bench Fairy Zone should affect the live GameStateMachine attack damage path"),
	])


func test_len_jtg_8_maractus_exploding_needles_and_corner() -> String:
	var card: CardData = CardDatabase.get_card("LEN_JTG", "8")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var maractus := _slot(card, 1) if card != null else null
	if maractus != null:
		state.players[1].active_pokemon = maractus
		maractus.damage_counters = maractus.get_max_hp()
	var ability_effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	processor.apply_attack_damage_knockout_reactive_effects(attacker, maractus, state)
	processor.execute_attack_effect(maractus, 0, attacker, state)
	var retreat_locked := false
	for effect_data: Dictionary in attacker.effects:
		if effect_data.get("type", "") == "retreat_lock":
			retreat_locked = true
			break

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_JTG_8 should load from CardDatabase"),
		assert_eq(card.name, "Maractus", "LEN_JTG_8 rule name should stay English"),
		assert_true(ability_effect is AbilityExplodingNeedlesScript, "Exploding Needles should register KO reactive ability"),
		assert_eq(attacker.damage_counters, 60, "Exploding Needles should put 6 damage counters on the Attacking Pokemon"),
		assert_true(retreat_locked, "Corner should prevent the Defending Pokemon from retreating next turn"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_JTG_8 should be marked implemented"),
	])


func test_len_scr_115_noctowl_jewel_seeker_searches_trainers_with_tera_in_play() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SCR", "115")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	var player := state.players[0]
	var noctowl := _slot(card, 0) if card != null else null
	if noctowl != null:
		player.active_pokemon = noctowl
		CSV9CHelpers.mark_evolved_from_hand(noctowl, state)
	var tera_data := _pokemon("Tera Pokemon ex", "Basic", "", "C", 230)
	tera_data.mechanic = "ex"
	tera_data.ancient_trait = "Tera"
	player.bench.append(_slot(tera_data, 0))
	var trainer_a := CardInstance.create(_trainer("Trainer A", "Item"), 0)
	var trainer_b := CardInstance.create(_trainer("Trainer B", "Supporter"), 0)
	var pokemon := CardInstance.create(_pokemon("Deck Pokemon", "Basic", "", "C", 70), 0)
	player.deck = [trainer_a, trainer_b, pokemon]
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var can_use := bool(effect.call("can_use_ability", noctowl, state)) if effect != null and noctowl != null else false
	var steps: Array[Dictionary] = effect.get_interaction_steps(noctowl.get_top_card(), state) if effect != null and noctowl != null else []
	if effect != null and noctowl != null:
		effect.execute_ability(noctowl, 0, [{
			CSV9CEffects.AbilityNoctowlTeraTrainerSearch.STEP_ID: [trainer_a, trainer_b],
		}], state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SCR_115 should load from CardDatabase"),
		assert_eq(card.name, "Noctowl", "LEN_SCR_115 rule name should stay English"),
		assert_true(effect != null and effect.has_method("can_use_ability"), "Jewel Seeker should register a usable ability effect"),
		assert_true(can_use, "Jewel Seeker should be usable after evolving with a Tera Pokemon in play"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, 1, -1], "Jewel Seeker should expose full deck and only enable Trainer cards"),
		assert_true(bool(steps[0].get("force_confirm", false)) if not steps.is_empty() else false, "Jewel Seeker full-deck search should require explicit confirm"),
		assert_true(trainer_a in player.hand, "Jewel Seeker should move selected Trainer A to hand"),
		assert_true(trainer_b in player.hand, "Jewel Seeker should move selected Trainer B to hand"),
		assert_true(pokemon in player.deck, "Jewel Seeker should leave non-Trainer cards in deck"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SCR_115 should be marked implemented"),
	])


func test_len_scr_118_fan_rotom_fan_call_and_assault_landing() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SCR", "118")
	var processor := EffectProcessor.new()
	if card != null:
		processor.register_pokemon_card(card)
	var state := _make_state()
	state.turn_number = 1
	state.first_player_index = 0
	state.current_player_index = 0
	var player := state.players[0]
	var fan_rotom := _slot(card, 0) if card != null else null
	if fan_rotom != null:
		player.active_pokemon = fan_rotom
	var valid_a := CardInstance.create(_pokemon("Colorless A", "Basic", "", "C", 80), 0)
	var too_big := CardInstance.create(_pokemon("Colorless Too Big", "Basic", "", "C", 110), 0)
	var wrong_type := CardInstance.create(_pokemon("Fire Basic", "Basic", "", "R", 80), 0)
	var valid_b := CardInstance.create(_pokemon("Colorless B", "Basic", "", "C", 100), 0)
	player.deck = [valid_a, too_big, wrong_type, valid_b]
	var ability_effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var can_use := bool(ability_effect.call("can_use_ability", fan_rotom, state)) if ability_effect != null and fan_rotom != null else false
	var steps: Array[Dictionary] = ability_effect.get_interaction_steps(fan_rotom.get_top_card(), state) if ability_effect != null and fan_rotom != null else []
	if ability_effect != null and fan_rotom != null:
		ability_effect.execute_ability(fan_rotom, 0, [{
			CSV9CEffects.AbilityFanCall.STEP_ID: [valid_a, valid_b],
		}], state)
	var can_reuse := bool(ability_effect.call("can_use_ability", fan_rotom, state)) if ability_effect != null and fan_rotom != null else true
	var attack_effects := processor.get_attack_effects_for_slot(fan_rotom, 0) if fan_rotom != null else []
	var attack_effect: BaseEffect = attack_effects[0] if not attack_effects.is_empty() else null
	var bonus_without_stadium := int(attack_effect.call("get_damage_bonus", fan_rotom, state)) if attack_effect != null and attack_effect.has_method("get_damage_bonus") else 999
	var damage_without_stadium := DamageCalculator.new().calculate_damage(fan_rotom, state.players[1].active_pokemon, card.attacks[0], state, bonus_without_stadium) if fan_rotom != null and card != null else -1
	state.stadium_card = CardInstance.create(_trainer("Any Stadium", "Stadium"), 0)
	var bonus_with_stadium := int(attack_effect.call("get_damage_bonus", fan_rotom, state)) if attack_effect != null and attack_effect.has_method("get_damage_bonus") else 999
	var damage_with_stadium := DamageCalculator.new().calculate_damage(fan_rotom, state.players[1].active_pokemon, card.attacks[0], state, bonus_with_stadium) if fan_rotom != null and card != null else -1

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SCR_118 should load from CardDatabase"),
		assert_eq(card.name, "Fan Rotom", "LEN_SCR_118 rule name should stay English"),
		assert_eq(card.abilities[0].get("name", ""), "Fan Call", "LEN_SCR_118 ability rule name should stay English"),
		assert_true(ability_effect != null and ability_effect.has_method("can_use_ability"), "LEN_SCR_118 Fan Call should register a usable ability"),
		assert_true(can_use, "Fan Call should be usable during its owner's first turn with valid deck targets"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1, -1, 1], "Fan Call should expose full deck and only enable Colorless Pokemon with 100 HP or less"),
		assert_true(bool(steps[0].get("force_confirm", false)) if not steps.is_empty() else false, "Fan Call full-deck search should require explicit confirm"),
		assert_true(valid_a in player.hand, "Fan Call should move selected valid Colorless Pokemon A to hand"),
		assert_true(valid_b in player.hand, "Fan Call should move selected valid Colorless Pokemon B to hand"),
		assert_true(too_big in player.deck, "Fan Call should leave Colorless Pokemon above 100 HP in deck"),
		assert_true(wrong_type in player.deck, "Fan Call should leave non-Colorless Pokemon in deck"),
		assert_false(can_reuse, "Only one Fan Call Ability should be usable per turn"),
		assert_true(attack_effect != null and attack_effect.has_method("get_damage_bonus"), "Assault Landing should register Stadium-required damage logic"),
		assert_eq(bonus_without_stadium, -70, "Assault Landing should subtract its printed damage when no Stadium is in play"),
		assert_eq(damage_without_stadium, 0, "Assault Landing should do no damage when no Stadium is in play"),
		assert_eq(bonus_with_stadium, 0, "Assault Landing should keep printed damage when a Stadium is in play"),
		assert_eq(damage_with_stadium, 70, "Assault Landing should deal printed damage when a Stadium is in play"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SCR_118 should be marked implemented"),
	])


func test_len_scr_131_area_zero_underdepths_uses_limitless_effect_id() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SCR", "131")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var state := _make_state()
	state.stadium_card = CardInstance.create(card, 0) if card != null else null
	var tera_data := _pokemon("Tera Pokemon ex", "Basic", "", "C", 230)
	tera_data.mechanic = "ex"
	tera_data.ancient_trait = "Tera"
	state.players[0].bench.append(_slot(tera_data, 0))
	var own_limit := int(effect.call("get_bench_limit_for_player", state.players[0], state)) if effect != null and effect.has_method("get_bench_limit_for_player") else -1
	var opponent_limit := int(effect.call("get_bench_limit_for_player", state.players[1], state)) if effect != null and effect.has_method("get_bench_limit_for_player") else -1
	var active_by_static := CSV9C207AreaZeroUnderdepthsScript.is_area_zero_active(state)
	var static_own_limit := CSV9C207AreaZeroUnderdepthsScript.static_bench_limit_for_player(state.players[0], state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SCR_131 should load from CardDatabase"),
		assert_eq(card.name, "Area Zero Underdepths", "LEN_SCR_131 rule name should stay English"),
		assert_true(effect is CSV9C207AreaZeroUnderdepthsScript, "LEN_SCR_131 should register Area Zero Underdepths effect"),
		assert_true(active_by_static, "Area Zero static helpers should recognize the Limitless effect id"),
		assert_eq(own_limit, 8, "Area Zero should expand Bench limit to 8 for the player with a Tera Pokemon"),
		assert_eq(opponent_limit, 5, "Area Zero should keep Bench limit 5 for a player without Tera Pokemon"),
		assert_eq(static_own_limit, 8, "Area Zero static bench limit should also honor the Limitless effect id"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SCR_131 should be marked implemented"),
	])


func test_len_scr_133_crispin_searches_and_attaches_basic_energy() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SCR", "133")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var state := _make_state()
	var player := state.players[0]
	var crispin := CardInstance.create(card, 0) if card != null else null
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	var fire_duplicate := CardInstance.create(_energy("Fire Duplicate", "R"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	var filler := CardInstance.create(_trainer("Filler", "Item"), 0)
	player.deck = [fire, fire_duplicate, water, filler]
	var steps: Array[Dictionary] = effect.get_interaction_steps(crispin, state) if effect != null and crispin != null else []
	var followup: Array[Dictionary] = effect.get_followup_interaction_steps(crispin, state, {
		CSV9C196CrispinScript.HAND_STEP_ID: [fire],
	}) if effect != null and crispin != null else []
	var followup_step: Dictionary = followup[0] if not followup.is_empty() else {}
	if effect != null and crispin != null:
		effect.execute(crispin, [{
			CSV9C196CrispinScript.HAND_STEP_ID: [fire],
			CSV9C196CrispinScript.ATTACH_STEP_ID: [{"source": water, "target": player.active_pokemon}],
		}], state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SCR_133 should load from CardDatabase"),
		assert_eq(card.name, "Crispin", "LEN_SCR_133 rule name should stay English"),
		assert_true(effect is CSV9C196CrispinScript, "LEN_SCR_133 should register Crispin effect"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1, 1, -1], "Crispin should expose full deck and disable duplicate Energy types"),
		assert_true(bool(steps[0].get("force_confirm", false)) if not steps.is_empty() else false, "Crispin hand search should require explicit confirm"),
		assert_eq(followup_step.get("source_card_indices", []), [-1, -1, 0, -1], "Crispin attachment follow-up should expose full deck and only enable a different Energy type"),
		assert_true(fire in player.hand, "Crispin should move selected Energy to hand"),
		assert_true(water in player.active_pokemon.attached_energy, "Crispin should attach selected different-type Energy"),
		assert_true(fire_duplicate in player.deck, "Crispin should leave duplicate-type Energy in deck"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SCR_133 should be marked implemented"),
	])


func test_len_ssp_170_cyrano_searches_pokemon_ex() -> String:
	var card: CardData = CardDatabase.get_card("LEN_SSP", "170")
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(card.effect_id) if card != null else null
	var state := _make_state()
	var player := state.players[0]
	var cyrano := CardInstance.create(card, 0) if card != null else null
	var ex_a_data := _pokemon("Pokemon ex A", "Basic", "", "C", 180)
	ex_a_data.mechanic = "ex"
	var non_ex_data := _pokemon("Regular Pokemon", "Basic", "", "C", 80)
	var ex_b_data := _pokemon("Pokemon ex B", "Basic", "", "C", 220)
	ex_b_data.mechanic = "ex"
	var ex_a := CardInstance.create(ex_a_data, 0)
	var non_ex := CardInstance.create(non_ex_data, 0)
	var ex_b := CardInstance.create(ex_b_data, 0)
	player.deck = [ex_a, non_ex, ex_b]
	var steps: Array[Dictionary] = effect.get_interaction_steps(cyrano, state) if effect != null and cyrano != null else []
	if effect != null and cyrano != null:
		effect.execute(cyrano, [{
			CSV9C198CilanScript.STEP_ID: [ex_a, ex_b],
		}], state)

	CardImplementationStatusScript.clear_cache()
	return run_checks([
		assert_not_null(card, "LEN_SSP_170 should load from CardDatabase"),
		assert_eq(card.name, "Cyrano", "LEN_SSP_170 rule name should stay English"),
		assert_true(effect is CSV9C198CilanScript, "LEN_SSP_170 should register Cyrano/Cilan Pokemon ex search effect"),
		assert_eq(steps[0].get("card_indices", []) if not steps.is_empty() else [], [0, -1, 1], "Cyrano should expose full deck and only enable Pokemon ex"),
		assert_true(bool(steps[0].get("force_confirm", false)) if not steps.is_empty() else false, "Cyrano search should require explicit confirm"),
		assert_true(ex_a in player.hand, "Cyrano should move selected Pokemon ex A to hand"),
		assert_true(ex_b in player.hand, "Cyrano should move selected Pokemon ex B to hand"),
		assert_true(non_ex in player.deck, "Cyrano should leave non-ex Pokemon in deck"),
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "LEN_SSP_170 should be marked implemented"),
	])


func test_v18_decks_are_rebuilt_with_simplified_chinese_cards() -> String:
	var checks: Array[String] = []
	for deck_id: int in V18_DECK_DISPLAY_NAMES.keys():
		var expected_name := str(V18_DECK_DISPLAY_NAMES[deck_id])
		var deck_json := _read_json("res://data/bundled_user/decks/%d.json" % deck_id)
		var runtime_deck: DeckData = CardDatabase.get_deck(deck_id)
		checks.append(assert_false(deck_json.is_empty(), "18.0 deck %d should load from bundled JSON" % deck_id))
		checks.append(assert_eq(str(deck_json.get("deck_name", "")), expected_name, "18.0 deck %d should use the expected display name" % deck_id))
		checks.append(assert_eq(str(deck_json.get("variant_name", "")), expected_name, "18.0 deck %d variant should use the expected display name" % deck_id))
		checks.append(assert_false(expected_name.contains(str(deck_json.get("source_id", ""))), "18.0 deck %d display name should not keep the source id suffix" % deck_id))
		checks.append(assert_not_null(runtime_deck, "18.0 deck %d should load through CardDatabase" % deck_id))
		if runtime_deck != null:
			checks.append(assert_eq(runtime_deck.deck_name, expected_name, "18.0 deck %d runtime deck should use the expected display name" % deck_id))
			checks.append(assert_eq(runtime_deck.variant_name, expected_name, "18.0 deck %d runtime variant should use the expected display name" % deck_id))
			checks.append(assert_eq(CardDatabase.build_deck_instances(runtime_deck, 0).size(), 60, "18.0 deck %d should build all 60 runtime card instances" % deck_id))
		var cards: Array = deck_json.get("cards", [])
		var total_cards := 0
		var local_refs: Array[String] = []
		for entry: Variant in cards:
			if not (entry is Dictionary):
				continue
			var deck_entry := entry as Dictionary
			var set_code := str(deck_entry.get("set_code", ""))
			var card_index := str(deck_entry.get("card_index", ""))
			total_cards += int(deck_entry.get("count", 0))
			local_refs.append("%s_%s" % [set_code, card_index])
			checks.append(assert_false(set_code.begins_with("LEN_"), "18.0 deck %d must not retain generated Limitless card %s/%s" % [deck_id, set_code, card_index]))
			var card: CardData = CardDatabase.get_card(set_code, card_index)
			var ref := "%s/%s in deck %d" % [set_code, card_index, deck_id]
			checks.append(assert_not_null(card, "%s should load from CardDatabase" % ref))
			if card == null:
				continue
			checks.append(assert_true(str(card.display_name()).strip_edges() != "", "%s should have a display name" % ref))
			checks.append(assert_eq(str(deck_entry.get("name", "")), str(card.display_name()), "%s deck entry should use the local Simplified-Chinese display name" % ref))
			checks.append(assert_false(CardImplementationStatusScript.is_unimplemented(card), "%s should remain implemented after the 18.0 rebuild: %s" % [ref, CardImplementationStatusScript.get_reason(card)]))
		checks.append(assert_eq(total_cards, 60, "18.0 deck %d should contain exactly 60 cards" % deck_id))
		for expected_ref: String in V18_REQUIRED_SIMPLIFIED_CHINESE_REFS.get(deck_id, []):
			checks.append(assert_contains(local_refs, expected_ref, "18.0 deck %d should include Simplified-Chinese replacement %s" % [deck_id, expected_ref]))
	return run_checks(checks)


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
		player.active_pokemon = _slot(_pokemon("Active %d" % player_index, "Basic", "", "C", 100), player_index)
		state.players.append(player)
	return state


func _pokemon(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	energy_type: String = "C",
	hp: int = 100,
	attacks: Array[Dictionary] = []
) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.evolves_from = evolves_from
	data.energy_type = energy_type
	data.hp = hp
	data.attacks = attacks
	return data


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	data.energy_type = energy_type
	data.energy_provides = energy_type
	return data


func _trainer(name: String, card_type: String, effect_id: String = "") -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	data.effect_id = effect_id
	return data


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card_data != null:
		slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot
