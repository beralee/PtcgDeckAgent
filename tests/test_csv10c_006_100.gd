class_name TestCSV10C006To100
extends TestBase

const CSV10CEffectsScript := preload("res://scripts/effects/CSV10CEffects.gd")

class AlwaysHeads extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(true)
		return true

class AlwaysTails extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(false)
		return false

const BATCH_006_010 := ["CSV10C_006", "CSV10C_007", "CSV10C_008", "CSV10C_009", "CSV10C_010"]
const BATCH_011_015 := ["CSV10C_011", "CSV10C_012", "CSV10C_013", "CSV10C_014", "CSV10C_015"]
const BATCH_016_020 := ["CSV10C_016", "CSV10C_017", "CSV10C_018", "CSV10C_019", "CSV10C_020"]
const BATCH_021_025 := ["CSV10C_021", "CSV10C_022", "CSV10C_023", "CSV10C_024", "CSV10C_025"]
const BATCH_026_030 := ["CSV10C_026", "CSV10C_027", "CSV10C_028", "CSV10C_029", "CSV10C_030"]
const BATCH_031_035 := ["CSV10C_031", "CSV10C_032", "CSV10C_033", "CSV10C_034", "CSV10C_035"]
const BATCH_036_040 := ["CSV10C_036", "CSV10C_037", "CSV10C_038", "CSV10C_039", "CSV10C_040"]
const BATCH_041_045 := ["CSV10C_041", "CSV10C_042", "CSV10C_043", "CSV10C_044", "CSV10C_045"]
const BATCH_046_050 := ["CSV10C_046", "CSV10C_047", "CSV10C_048", "CSV10C_049", "CSV10C_050"]
const BATCH_051_055 := ["CSV10C_051", "CSV10C_052", "CSV10C_053", "CSV10C_054", "CSV10C_055"]
const BATCH_056_060 := ["CSV10C_056", "CSV10C_057", "CSV10C_058", "CSV10C_059", "CSV10C_060"]
const BATCH_061_065 := ["CSV10C_061", "CSV10C_062", "CSV10C_063", "CSV10C_064", "CSV10C_065"]
const BATCH_066_070 := ["CSV10C_066", "CSV10C_067", "CSV10C_068", "CSV10C_069", "CSV10C_070"]
const BATCH_071_075 := ["CSV10C_071", "CSV10C_072", "CSV10C_073", "CSV10C_074", "CSV10C_075"]
const BATCH_076_080 := ["CSV10C_076", "CSV10C_077", "CSV10C_078", "CSV10C_079", "CSV10C_080"]
const BATCH_081_085 := ["CSV10C_081", "CSV10C_082", "CSV10C_083", "CSV10C_084", "CSV10C_085"]
const BATCH_086_090 := ["CSV10C_086", "CSV10C_087", "CSV10C_088", "CSV10C_089", "CSV10C_090"]
const BATCH_091_095 := ["CSV10C_091", "CSV10C_092", "CSV10C_093", "CSV10C_094", "CSV10C_095"]
const BATCH_096_100 := ["CSV10C_096", "CSV10C_097", "CSV10C_098", "CSV10C_099", "CSV10C_100"]


func test_csv10c_006_010_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_006_010)
	var state := _make_state()
	var processor := EffectProcessor.new()

	var rotom := _load_card("006")
	var rotom_slot := _make_slot(rotom, 0)
	processor.register_pokemon_card(rotom)
	var rotom_first := processor.get_attack_effects_for_slot(rotom_slot, 0)
	var rotom_second := processor.get_attack_effects_for_slot(rotom_slot, 1)
	checks.append(assert_false(rotom_first.is_empty(), "CSV10C_006 should discard the Stadium with its first attack"))
	checks.append(assert_false(rotom_second.is_empty(), "CSV10C_006 should count attached Tools with its second attack"))
	if not rotom_second.is_empty():
		state.players[0].active_pokemon = rotom_slot
		checks.append(assert_eq(int(rotom_second[0].call("get_damage_bonus", rotom_slot, state)), -30, "CSV10C_006 should offset printed 30x to zero damage when no Tools are attached"))
		rotom_slot.attached_tool = _trainer_instance("Tool A", "Tool", 0)
		checks.append(assert_eq(int(rotom_second[0].call("get_damage_bonus", rotom_slot, state)), 0, "CSV10C_006 printed 30x should stay at 30 for one Tool"))
		state.players[0].bench[0].attached_tool = _trainer_instance("Tool B", "Tool", 0)
		checks.append(assert_eq(int(rotom_second[0].call("get_damage_bonus", rotom_slot, state)), 30, "CSV10C_006 printed 30x plus bonus should total 60 for two Tools"))

	var shaymin := _load_card("007")
	processor.register_pokemon_card(shaymin)
	var shaymin_effect := processor.get_effect(shaymin.effect_id)
	checks.append(assert_not_null(shaymin_effect, "CSV10C_007 花之纱幔 should register"))
	if shaymin_effect != null:
		var shaymin_source := _make_slot(shaymin, 0)
		var normal_bench := state.players[0].bench[0]
		var rule_bench := _make_slot(_pokemon("Rule Box", "G", "ex"), 0)
		state.players[0].bench = [shaymin_source, normal_bench, rule_bench]
		var opposing_attacker := state.players[1].active_pokemon
		checks.append(assert_true(AbilityNonRuleBoxBenchDamageShield.protects_bench_target(normal_bench, opposing_attacker, state), "CSV10C_007 should protect a non-rule-box Bench Pokemon"))
		checks.append(assert_false(AbilityNonRuleBoxBenchDamageShield.protects_bench_target(rule_bench, opposing_attacker, state), "CSV10C_007 should not protect a rule-box Bench Pokemon"))

	var maractus := _load_card("008")
	processor.register_pokemon_card(maractus)
	var maractus_effect := processor.get_effect(maractus.effect_id)
	var maractus_attacks := processor.get_attack_effects_for_slot(_make_slot(maractus, 0), 0)
	checks.append(assert_not_null(maractus_effect, "CSV10C_008 炸裂针刺 should register"))
	checks.append(assert_false(maractus_attacks.is_empty(), "CSV10C_008 穷追不舍 should register"))
	if maractus_effect != null:
		var source := _make_slot(maractus, 0)
		var attacker := state.players[1].active_pokemon
		state.players[0].active_pokemon = source
		maractus_effect.call("on_knocked_out_by_attack_damage", source, attacker, state)
		checks.append(assert_eq(attacker.damage_counters, 60, "CSV10C_008 should place six damage counters on the attacker"))

	var dwebble := _load_card("009")
	processor.register_pokemon_card(dwebble)
	var dwebble_slot := _make_slot(dwebble, 0)
	state.players[0].active_pokemon = dwebble_slot
	var dwebble_effects := processor.get_attack_effects_for_slot(dwebble_slot, 0)
	checks.append(assert_false(dwebble_effects.is_empty(), "CSV10C_009 觉醒 should register deck evolution"))
	if not dwebble_effects.is_empty():
		var crustle_candidate := _load_card("010")
		var crustle_instance := CardInstance.create(crustle_candidate, 0)
		var unrelated_instance := CardInstance.create(_pokemon("Unrelated Evolution", "G"), 0)
		state.players[0].deck = [unrelated_instance, crustle_instance]
		var evolve_steps: Array[Dictionary] = dwebble_effects[0].call("get_attack_interaction_steps", dwebble_slot.get_top_card(), dwebble.attacks[0], state)
		checks.append(assert_eq(evolve_steps.size(), 1, "CSV10C_009 should expose one evolution search step"))
		checks.append(assert_eq(str(evolve_steps[0].get("visible_scope", "")) if not evolve_steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_009 should show the full own deck while searching"))
		checks.append(assert_true(unrelated_instance in evolve_steps[0].get("card_items", []) if not evolve_steps.is_empty() else false, "CSV10C_009 should show non-candidate deck cards as disabled context"))
		checks.append(assert_false(unrelated_instance in evolve_steps[0].get("items", []) if not evolve_steps.is_empty() else true, "CSV10C_009 should keep unrelated cards unselectable"))
		dwebble_effects[0].set_attack_interaction_context([{"csv9c_evolution_card": [crustle_instance]}])
		dwebble_effects[0].call("execute_attack", dwebble_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_eq(dwebble_slot.get_card_data(), crustle_candidate, "CSV10C_009 should evolve into the selected matching card"))
		checks.append(assert_true(crustle_instance not in state.players[0].deck, "CSV10C_009 should remove the selected evolution from the deck"))

	var crustle := _load_card("010")
	processor.register_pokemon_card(crustle)
	var crustle_effect := processor.get_effect(crustle.effect_id)
	var crustle_attacks := processor.get_attack_effects_for_slot(_make_slot(crustle, 0), 0)
	checks.append(assert_not_null(crustle_effect, "CSV10C_010 神秘石居 should register"))
	checks.append(assert_false(crustle_attacks.is_empty(), "CSV10C_010 超强剪 should ignore defender effects"))
	if crustle_effect != null:
		checks.append(assert_true(bool(crustle_effect.call("prevents_damage_from", _make_slot(_pokemon("Attacker ex", "R", "ex"), 1), null, state)), "CSV10C_010 should prevent damage from Pokemon ex"))
		checks.append(assert_false(bool(crustle_effect.call("prevents_damage_from", _make_slot(_pokemon("Attacker V", "R", "V"), 1), null, state)), "CSV10C_010 should not prevent damage from Pokemon V"))
	return run_checks(checks)


func test_csv10c_011_015_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_011_015)
	var state := _make_state()
	var processor := EffectProcessor.new()

	var venonat := _load_card("011")
	processor.register_pokemon_card(venonat)
	var venonat_slot := _make_slot(venonat, 0)
	state.players[0].active_pokemon = venonat_slot
	state.players[1].prizes = [_trainer_instance("Hidden Prize A", "Item", 1), _trainer_instance("Hidden Prize B", "Item", 1)]
	state.players[1].prizes[0].face_up = true
	var prize_effects := processor.get_attack_effects_for_slot(venonat_slot, 0)
	checks.append(assert_false(prize_effects.is_empty(), "CSV10C_011 搜索之眼 should register"))
	if not prize_effects.is_empty():
		var steps: Array[Dictionary] = prize_effects[0].call("get_attack_interaction_steps", venonat_slot.get_top_card(), venonat.attacks[0], state)
		checks.append(assert_eq(steps[0].get("labels", []) if not steps.is_empty() else [], ["奖赏卡2"], "CSV10C_011 choice must hide identities and exclude face-up Prizes"))
		var followup: Array[Dictionary] = prize_effects[0].call("get_followup_attack_interaction_steps", venonat_slot.get_top_card(), venonat.attacks[0], state, {"opponent_prize_index": [1]})
		checks.append(assert_eq(followup.size(), 1, "CSV10C_011 should show a reveal confirmation after selecting a face-down Prize"))
		checks.append(assert_eq(followup[0].get("card_items", []) if not followup.is_empty() else [], [state.players[1].prizes[1]], "CSV10C_011 reveal UI should expose only the selected Prize"))
		checks.append(assert_eq(followup[0].get("card_indices", []) if not followup.is_empty() else [], [-1], "CSV10C_011 revealed Prize should be view-only"))
		prize_effects[0].set_attack_interaction_context([{"opponent_prize_index": [1]}])
		prize_effects[0].call("execute_attack", venonat_slot, state.players[1].active_pokemon, 0, state)
		var revealed: Dictionary = state.shared_turn_flags.get("csv10c_revealed_opponent_prize:0", {})
		checks.append(assert_eq(int(revealed.get("index", -1)), 1, "CSV10C_011 execution should retain the selected Prize index for replay/audit"))

	var applin := _load_card("012")
	processor.register_pokemon_card(applin)
	var applin_slot := _make_slot(applin, 0)
	applin_slot.damage_counters = 40
	var heal_effects := processor.get_attack_effects_for_slot(applin_slot, 0)
	checks.append(assert_false(heal_effects.is_empty(), "CSV10C_012 微微吸取 should register"))
	if not heal_effects.is_empty():
		heal_effects[0].call("execute_attack", applin_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_eq(applin_slot.damage_counters, 30, "CSV10C_012 should heal 10 HP"))

	var dipplin := _load_card("013")
	processor.register_pokemon_card(dipplin)
	var dipplin_slot := _make_slot(dipplin, 0)
	state.players[0].active_pokemon = dipplin_slot
	var dipplin_grass := _energy_instance("Grass", "G", 0)
	var dipplin_special := _trainer_instance("Special Energy", "Special Energy", 0)
	dipplin_special.card_data.energy_provides = "C"
	dipplin_slot.attached_energy = [dipplin_grass, dipplin_special]
	var dipplin_effects := processor.get_attack_effects_for_slot(dipplin_slot, 0)
	checks.append(assert_false(dipplin_effects.is_empty(), "CSV10C_013 能量环 should return one attached Energy"))
	if not dipplin_effects.is_empty():
		var return_steps: Array[Dictionary] = dipplin_effects[0].call("get_attack_interaction_steps", dipplin_slot.get_top_card(), dipplin.attacks[0], state)
		checks.append(assert_eq(return_steps[0].get("items", []) if not return_steps.is_empty() else [], [dipplin_grass, dipplin_special], "CSV10C_013 should allow any attached Energy to be selected"))
		dipplin_effects[0].set_attack_interaction_context([{"csv9c_return_energy": [dipplin_special]}])
		dipplin_effects[0].call("execute_attack", dipplin_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_true(dipplin_special in state.players[0].hand, "CSV10C_013 should return the specifically selected Energy to hand"))
		checks.append(assert_true(dipplin_grass in dipplin_slot.attached_energy, "CSV10C_013 should leave unselected Energy attached"))

	var hydrapple := _load_card("014")
	processor.register_pokemon_card(hydrapple)
	var hydrapple_slot := _make_slot(hydrapple, 0)
	state.players[0].active_pokemon = hydrapple_slot
	state.players[0].hand.clear()
	for i: int in 6:
		state.players[0].hand.append(_energy_instance("Grass %d" % i, "G", 0))
	var ko_effects := processor.get_attack_effects_for_slot(hydrapple_slot, 0)
	checks.append(assert_false(ko_effects.is_empty(), "CSV10C_014 大蛇吐息 should register"))
	if not ko_effects.is_empty():
		ko_effects[0].call("execute_attack", hydrapple_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_true(state.players[1].active_pokemon.is_knocked_out(), "CSV10C_014 should Knock Out after discarding six Basic Grass Energy"))
		checks.append(assert_eq(state.players[0].discard_pile.size(), 6, "CSV10C_014 should discard exactly six Energy"))

	var sprigatito := _load_card("015")
	processor.register_pokemon_card(sprigatito)
	checks.append(assert_false(processor.get_attack_effects_for_slot(_make_slot(sprigatito, 0), 0).is_empty(), "CSV10C_015 乱踩 should register three coin flips"))
	return run_checks(checks)


func test_csv10c_016_020_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_016_020)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["016", "017", "018", "019", "020"]:
		processor.register_pokemon_card(_load_card(index))

	var floragato := _load_card("016")
	checks.append(assert_false(processor.get_attack_effects_for_slot(_make_slot(floragato, 0), 0).is_empty(), "CSV10C_016 魔法叶 should register coin/heal behavior"))
	var floragato_slot := _make_slot(floragato, 0)
	floragato_slot.damage_counters = 40
	var magic_leaf := CSV10CEffectsScript.AttackCoinFlipBonusAndHeal.new(30, 30, 0, AlwaysHeads.new())
	magic_leaf.execute_attack(floragato_slot, state.players[1].active_pokemon, 0, state)
	checks.append(assert_eq(floragato_slot.damage_counters, 10, "CSV10C_016 heads should heal 30 HP"))

	var meowscarada := _load_card("017")
	var meowscarada_slot := _make_slot(meowscarada, 0)
	state.players[0].bench.append(meowscarada_slot)
	var switch_effect := processor.get_effect(meowscarada.effect_id)
	checks.append(assert_not_null(switch_effect, "CSV10C_017 表演时间 should register"))
	if switch_effect != null:
		checks.append(assert_true(bool(switch_effect.call("can_use_ability", meowscarada_slot, state)), "CSV10C_017 should be usable from the Bench"))
		switch_effect.call("execute_ability", meowscarada_slot, 0, [], state)
		checks.append(assert_eq(state.players[0].active_pokemon, meowscarada_slot, "CSV10C_017 should switch itself into the Active Spot"))
	checks.append(assert_false(processor.get_attack_effects_for_slot(meowscarada_slot, 0).is_empty(), "CSV10C_017 上升绽放 should gain damage against Pokemon ex"))

	var spinarak := _load_card("018")
	var spinarak_slot := _make_slot(spinarak, 0)
	var recoil := processor.get_attack_effects_for_slot(spinarak_slot, 0)
	checks.append(assert_false(recoil.is_empty(), "CSV10C_018 猛撞 should register recoil"))
	if not recoil.is_empty():
		recoil[0].call("execute_attack", spinarak_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_eq(spinarak_slot.damage_counters, 10, "CSV10C_018 should deal 10 recoil damage"))

	var ariados := _load_card("019")
	var ariados_slot := _make_slot(ariados, 0)
	checks.append(assert_eq(ariados.evolves_from, "火箭队的团珠蛛", "CSV10C_019 should preserve its Stage 1 evolution source for rules and UI"))
	checks.append(assert_true(ariados.evolves_from_matches(_load_card("018")), "CSV10C_019 should legally evolve from CSV10C_018"))
	var evolution_gsm := GameStateMachine.new()
	evolution_gsm.game_state = _make_state()
	var live_spinarak_slot := _make_slot(spinarak, 0)
	live_spinarak_slot.turn_played = evolution_gsm.game_state.turn_number - 1
	evolution_gsm.game_state.players[0].active_pokemon = live_spinarak_slot
	var live_ariados := CardInstance.create(ariados, 0)
	evolution_gsm.game_state.players[0].hand = [live_ariados]
	checks.append(assert_true(
		evolution_gsm.rule_validator.can_evolve(
			evolution_gsm.game_state,
			0,
			live_spinarak_slot,
			live_ariados,
			evolution_gsm.effect_processor,
		),
		"CSV10C_019 should be a legal hand evolution target through RuleValidator",
	))
	checks.append(assert_true(
		evolution_gsm.evolve_pokemon(0, live_ariados, live_spinarak_slot),
		"CSV10C_019 should evolve from CSV10C_018 through the production execution path",
	))
	checks.append(assert_eq(live_spinarak_slot.get_card_data(), ariados, "The production evolution path should place CSV10C_019 on top of CSV10C_018"))
	state.players[0].active_pokemon = ariados_slot
	state.players[0].discard_pile = [_energy_instance("Grass", "G", 0)]
	var charge := processor.get_effect(ariados.effect_id)
	checks.append(assert_not_null(charge, "CSV10C_019 充能 should register"))
	if charge != null:
		charge.call("execute_ability", ariados_slot, 0, [], state)
		checks.append(assert_eq(ariados_slot.attached_energy.size(), 1, "CSV10C_019 should attach one Basic Energy from discard to itself"))
	var rocket_damage := processor.get_attack_effects_for_slot(ariados_slot, 0)
	checks.append(assert_false(rocket_damage.is_empty(), "CSV10C_019 火箭突进 should count Rocket's Pokemon"))
	if not rocket_damage.is_empty():
		checks.append(assert_eq(int(rocket_damage[0].call("get_damage_bonus", ariados_slot, state)), 0, "CSV10C_019 printed 30x should total 30 with only itself in play"))
		var copied_attacker := _make_slot(_pokemon("Copied Attacker", "G"), 0)
		state.players[0].active_pokemon = copied_attacker
		checks.append(assert_eq(int(rocket_damage[0].call("get_damage_bonus", copied_attacker, state)), -30, "CSV10C_019 copied attack should total zero with no Rocket Pokemon in play"))
		state.players[0].bench.append(ariados_slot)
		checks.append(assert_eq(int(rocket_damage[0].call("get_damage_bonus", copied_attacker, state)), 0, "CSV10C_019 copied attack should total 30 with one Rocket Pokemon in play"))

	var smoliv := _load_card("020")
	checks.append(assert_true(processor.get_attack_effects_for_slot(_make_slot(smoliv, 0), 0).is_empty(), "CSV10C_020 numeric attack should remain script-free"))
	return run_checks(checks)


func test_csv10c_021_025_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_021_025)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["021", "022", "023", "024", "025"]:
		processor.register_pokemon_card(_load_card(index))

	var dolliv := _load_card("021")
	checks.append(assert_false(processor.get_attack_effects_for_slot(_make_slot(dolliv, 0), 0).is_empty(), "CSV10C_021 营养素 should heal a chosen Pokemon"))
	var arboliva := _load_card("022")
	var arboliva_slot := _make_slot(arboliva, 0)
	state.players[0].active_pokemon = arboliva_slot
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var oil_effects := processor.get_attack_effects_for_slot(arboliva_slot, 0)
	checks.append(assert_false(oil_effects.is_empty(), "CSV10C_022 油之机关枪 should distribute six hits"))
	checks.append(assert_false(processor.get_attack_effects_for_slot(arboliva_slot, 1).is_empty(), "CSV10C_022 芳香射击 should clear Special Conditions"))
	if not oil_effects.is_empty():
		var protected_data := _pokemon("Protected Bench", "G")
		protected_data.abilities = [{"name": "毫不在意", "text": ""}]
		var protected_bench := _make_slot(protected_data, 1)
		state.players[1].bench.append(protected_bench)
		var oil_steps: Array[Dictionary] = oil_effects[0].call("get_attack_interaction_steps", arboliva_slot.get_top_card(), arboliva.attacks[0], state)
		checks.append(assert_eq(int(oil_steps[0].get("total_counters", 0)) if not oil_steps.is_empty() else 0, 6, "CSV10C_022 UI should require exactly six target selections"))
		oil_effects[0].set_attack_interaction_context([{"repeated_target_damage": [
			{"target": state.players[1].active_pokemon, "amount": 3},
			{"target": state.players[1].bench[0], "amount": 1},
			{"target": protected_bench, "amount": 2},
		]}])
		oil_effects[0].call("execute_attack", arboliva_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 60, "CSV10C_022 should deal 20 damage per repeated Active selection"))
		checks.append(assert_eq(state.players[1].bench[0].damage_counters, 20, "CSV10C_022 should apply a separate selected Bench hit"))
		checks.append(assert_eq(protected_bench.damage_counters, 0, "CSV10C_022 should respect opponent Bench damage immunity"))
		var damage_before_invalid := state.players[1].active_pokemon.damage_counters
		oil_effects[0].set_attack_interaction_context([{"repeated_target_damage": [{"target": state.players[1].active_pokemon, "amount": 5}]}])
		oil_effects[0].call("execute_attack", arboliva_slot, state.players[1].active_pokemon, 0, state)
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, damage_before_invalid, "CSV10C_022 should reject an incomplete five-of-six distribution"))
	var ponyta := _load_card("023")
	checks.append(assert_false(processor.get_attack_effects_for_slot(_make_slot(ponyta, 0), 0).is_empty(), "CSV10C_023 二连头锤 should flip two coins"))

	var rapidash := _load_card("024")
	var rapidash_slot := _make_slot(rapidash, 0)
	state.players[0].active_pokemon = rapidash_slot
	state.players[0].deck = [_trainer_instance("Drawn", "Item", 0)]
	var draw_effect := processor.get_effect(rapidash.effect_id)
	checks.append(assert_not_null(draw_effect, "CSV10C_024 急步 should register"))
	if draw_effect != null:
		draw_effect.call("execute_ability", rapidash_slot, 0, [], state)
		checks.append(assert_eq(state.players[0].hand.size(), 1, "CSV10C_024 should draw one card"))
		checks.append(assert_false(bool(draw_effect.call("can_use_ability", rapidash_slot, state)), "CSV10C_024 should be once per turn"))

	var magmar := _load_card("025")
	checks.append(assert_false(processor.get_attack_effects_for_slot(_make_slot(magmar, 0), 0).is_empty(), "CSV10C_025 烧焦 should register a coin-flip Burn"))
	return run_checks(checks)


func test_csv10c_026_030_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_026_030)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["026", "027", "028", "029", "030"]:
		processor.register_pokemon_card(_load_card(index))

	var magmortar := _load_card("026")
	var magmortar_slot := _make_slot(magmortar, 0)
	state.players[0].active_pokemon = magmortar_slot
	state.players[1].active_pokemon.status_conditions["burned"] = true
	processor.process_pokemon_check(state)
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 50, "CSV10C_026 should make the opponent's Burn place five damage counters"))
	checks.append(assert_false(processor.get_attack_effects_for_slot(magmortar_slot, 0).is_empty(), "CSV10C_026 烧焦 should register a coin-flip Burn"))

	var moltres := _load_card("027")
	var moltres_slot := _make_slot(moltres, 0)
	state.players[0].active_pokemon = moltres_slot
	var barrier_effects := processor.get_attack_effects_for_slot(moltres_slot, 0)
	checks.append(assert_false(barrier_effects.is_empty(), "CSV10C_027 火焰屏障 should reduce damage by 50 next turn"))
	processor.execute_attack_effect(moltres_slot, 0, state.players[1].active_pokemon, state)
	state.turn_number += 1
	checks.append(assert_eq(processor.get_defender_modifier(moltres_slot, state, state.players[1].active_pokemon), -50, "CSV10C_027 should retain exactly 50 damage reduction for the opponent's next turn"))
	var rocket_energy := _special_energy_instance("火箭队能量", 0)
	moltres_slot.attached_energy.append(rocket_energy)
	var discarded_active := state.players[1].active_pokemon
	var discarded_active_card := discarded_active.get_top_card()
	processor.execute_attack_effect(moltres_slot, 1, discarded_active, state, [{"discard_team_rocket_energy": [rocket_energy]}])
	checks.append(assert_true(rocket_energy in state.players[0].discard_pile, "CSV10C_027 should discard one attached Team Rocket Energy"))
	checks.append(assert_true(discarded_active_card in state.players[1].discard_pile, "CSV10C_027 should discard the opposing Active Pokemon and all attached cards"))
	checks.append(assert_null(state.players[1].active_pokemon, "CSV10C_027 discards the opposing Active Pokemon without taking Prizes"))
	var protected_defender := _make_slot(_pokemon("Mist Protected", "W"), 1)
	var mist_energy := _special_energy_instance("Mist Energy", 1)
	mist_energy.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected_defender.attached_energy.append(mist_energy)
	state.players[1].active_pokemon = protected_defender
	var second_rocket_energy := _special_energy_instance("火箭队能量", 0)
	moltres_slot.attached_energy.append(second_rocket_energy)
	processor.execute_attack_effect(moltres_slot, 1, protected_defender, state, [{"discard_team_rocket_energy": [second_rocket_energy]}])
	checks.append(assert_true(second_rocket_energy in state.players[0].discard_pile, "CSV10C_027 should still pay its own Team Rocket Energy discard through Mist protection"))
	checks.append(assert_eq(state.players[1].active_pokemon, protected_defender, "CSV10C_027 should let Mist Energy prevent discarding the opposing Active Pokemon"))
	checks.append(assert_true(mist_energy in protected_defender.attached_energy, "CSV10C_027 should leave protected attached cards in play"))

	var cyndaquil := _load_card("028")
	var cyndaquil_slot := _make_slot(cyndaquil, 0)
	state.players[0].active_pokemon = cyndaquil_slot
	var fire_energy := _energy_instance("Fire", "R", 0)
	cyndaquil_slot.attached_energy.append(fire_energy)
	processor.execute_attack_effect(cyndaquil_slot, 0, discarded_active, state, [{"discard_attached_energy_from_self": [fire_energy]}])
	checks.append(assert_true(fire_energy in state.players[0].discard_pile, "CSV10C_028 should discard one chosen attached Energy"))

	var quilava := _load_card("029")
	var quilava_slot := _make_slot(quilava, 0)
	state.players[0].active_pokemon = quilava_slot
	var adventure := _trainer_instance("阿响的冒险", "Supporter", 0)
	var wrong_supporter := _trainer_instance("Other Supporter", "Supporter", 0)
	state.players[0].deck = [wrong_supporter, adventure]
	var bond := processor.get_effect(quilava.effect_id)
	checks.append(assert_not_null(bond, "CSV10C_029 旅途牵绊 should register"))
	if bond != null:
		var bond_steps: Array[Dictionary] = bond.call("get_interaction_steps", quilava_slot.get_top_card(), state)
		checks.append(assert_eq(str(bond_steps[0].get("visible_scope", "")) if not bond_steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_029 should show the full own deck during search"))
		checks.append(assert_true(wrong_supporter in bond_steps[0].get("card_items", []) if not bond_steps.is_empty() else false, "CSV10C_029 should show nonmatching deck cards as disabled context"))
		checks.append(assert_false(wrong_supporter in bond_steps[0].get("items", []) if not bond_steps.is_empty() else true, "CSV10C_029 should keep nonmatching Supporters unselectable"))
		bond.call("execute_ability", quilava_slot, 0, [{"search_named_card": [adventure]}], state)
		checks.append(assert_true(adventure in state.players[0].hand, "CSV10C_029 should search only 阿响的冒险"))
		checks.append(assert_false(wrong_supporter in state.players[0].hand, "CSV10C_029 should not search a different Supporter"))

	var typhlosion := _load_card("030")
	var typhlosion_slot := _make_slot(typhlosion, 0)
	state.players[0].active_pokemon = typhlosion_slot
	state.players[0].discard_pile = [
		_trainer_instance("阿响的冒险", "Supporter", 0),
		_trainer_instance("阿响的冒险", "Supporter", 0),
		_trainer_instance("Other Supporter", "Supporter", 0),
	]
	var partner_effects := processor.get_attack_effects_for_slot(typhlosion_slot, 0)
	checks.append(assert_false(partner_effects.is_empty(), "CSV10C_030 搭档爆破 should count 阿响的冒险 in the discard pile"))
	if not partner_effects.is_empty():
		checks.append(assert_eq(int(partner_effects[0].call("get_damage_bonus", typhlosion_slot, state)), 120, "CSV10C_030 should add 60 damage per 阿响的冒险"))
	return run_checks(checks)


func test_csv10c_031_035_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_031_035)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["031", "032", "033", "034", "035"]:
		processor.register_pokemon_card(_load_card(index))

	checks.append(assert_true(processor.get_attack_effects_for_slot(_make_slot(_load_card("031"), 0), 0).is_empty(), "CSV10C_031 numeric attack should remain script-free"))

	var magcargo := _load_card("032")
	var magcargo_slot := _make_slot(magcargo, 0)
	state.players[0].active_pokemon = magcargo_slot
	var flowing := processor.get_effect(magcargo.effect_id)
	checks.append(assert_not_null(flowing, "CSV10C_032 熔化流动 should register"))
	if flowing != null:
		checks.append(assert_eq(int(flowing.call("get_retreat_cost_modifier", magcargo_slot, state)), -999, "CSV10C_032 should have free Retreat with no attached Energy"))
	var fire_energy: Array[CardInstance] = []
	for i: int in 3:
		fire_energy.append(_energy_instance("Fire %d" % i, "R", 0))
	magcargo_slot.attached_energy.append_array(fire_energy)
	var blast_effects := processor.get_attack_effects_for_slot(magcargo_slot, 0)
	checks.append(assert_false(blast_effects.is_empty(), "CSV10C_032 熔岩爆破 should discard up to five attached Fire Energy"))
	if not blast_effects.is_empty():
		blast_effects[0].set_attack_interaction_context([{"discard_fire_energy_from_self": fire_energy}])
		checks.append(assert_eq(int(blast_effects[0].call("get_damage_bonus", magcargo_slot, state)), 140, "CSV10C_032 three discarded Fire Energy should make the printed 70x total 210"))
		blast_effects[0].clear_attack_interaction_context()
	processor.execute_attack_effect(magcargo_slot, 0, state.players[1].active_pokemon, state, [{"discard_fire_energy_from_self": fire_energy}])
	checks.append(assert_eq(state.players[0].discard_pile.size(), 3, "CSV10C_032 should discard exactly the selected Fire Energy"))

	checks.append(assert_true(processor.get_attack_effects_for_slot(_make_slot(_load_card("033"), 0), 0).is_empty(), "CSV10C_033 numeric attack should remain script-free"))

	var houndoom := _load_card("034")
	var houndoom_slot := _make_slot(houndoom, 0)
	state.players[0].active_pokemon = houndoom_slot
	var target := state.players[1].active_pokemon
	processor.execute_attack_effect(houndoom_slot, 0, target, state)
	checks.append(assert_true(target.status_conditions.get("burned", false), "CSV10C_034 should Burn with 恶之火种"))
	checks.append(assert_true(target.status_conditions.get("confused", false), "CSV10C_034 should Confuse with 恶之火种"))
	var houndoom_energy := _energy_instance("Fire", "R", 0)
	houndoom_slot.attached_energy.append(houndoom_energy)
	processor.execute_attack_effect(houndoom_slot, 1, target, state, [{"discard_attached_energy_from_self": [houndoom_energy]}])
	checks.append(assert_true(houndoom_energy in state.players[0].discard_pile, "CSV10C_034 燃烧驱逐 should discard one chosen attached Energy"))

	var hooh := _load_card("035")
	var hooh_slot := _make_slot(hooh, 0)
	state.players[0].active_pokemon = hooh_slot
	var ethan_bench := _make_slot(_pokemon("阿响的火球鼠", "R"), 0)
	var other_bench := _make_slot(_pokemon("Other Pokemon", "R"), 0)
	state.players[0].bench = [other_bench, ethan_bench]
	var hand_fire_a := _energy_instance("Fire A", "R", 0)
	var hand_fire_b := _energy_instance("Fire B", "R", 0)
	state.players[0].hand = [hand_fire_a, hand_fire_b]
	var golden_flame := processor.get_effect(hooh.effect_id)
	checks.append(assert_not_null(golden_flame, "CSV10C_035 金色火焰 should register"))
	if golden_flame != null:
		var flame_steps: Array[Dictionary] = golden_flame.call("get_interaction_steps", hooh_slot.get_top_card(), state)
		checks.append(assert_true(bool(flame_steps[0].get("single_target_only", false)) if not flame_steps.is_empty() else false, "CSV10C_035 assignment UI should lock both Energy cards to one Benched Ethan's Pokemon"))
		golden_flame.call("execute_ability", hooh_slot, 0, [{"attach_fire_to_benched_ethan": [
			{"source": hand_fire_a, "target": ethan_bench},
			{"source": hand_fire_b, "target": ethan_bench},
		]}], state)
		checks.append(assert_eq(ethan_bench.attached_energy.size(), 2, "CSV10C_035 should attach up to two Basic Fire Energy to one Benched Ethan's Pokemon"))
		checks.append(assert_eq(other_bench.attached_energy.size(), 0, "CSV10C_035 should not attach to a non-Ethan Pokemon"))
	hooh_slot.damage_counters = 60
	ethan_bench.damage_counters = 80
	processor.execute_attack_effect(hooh_slot, 0, target, state)
	checks.append(assert_eq(hooh_slot.damage_counters, 10, "CSV10C_035 should heal itself by 50"))
	checks.append(assert_eq(ethan_bench.damage_counters, 30, "CSV10C_035 should heal every own Pokemon by 50"))
	return run_checks(checks)


func test_csv10c_036_040_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_036_040)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["036", "037", "038", "039", "040"]:
		processor.register_pokemon_card(_load_card(index))

	var torchic := _load_card("036")
	var torchic_slot := _make_slot(torchic, 0)
	state.players[0].active_pokemon = torchic_slot
	state.players[0].deck = [_trainer_instance("Drawn", "Item", 0)]
	processor.execute_attack_effect(torchic_slot, 0, state.players[1].active_pokemon, state)
	checks.append(assert_eq(state.players[0].hand.size(), 1, "CSV10C_036 招来 should draw one card"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(torchic_slot, 1).is_empty(), "CSV10C_036 烈焰 is numeric-only"))

	var combusken := _load_card("037")
	var combusken_slot := _make_slot(combusken, 0)
	var coin_target := state.players[1].active_pokemon
	coin_target.damage_counters = 0
	processor.execute_attack_effect(combusken_slot, 1, coin_target, state)
	checks.append(assert_eq(coin_target.damage_counters, 40, "CSV10C_037 two heads should add 40 beyond the printed 40x base, for 80 total"))

	var blaziken := _load_card("038")
	var blaziken_slot := _make_slot(blaziken, 0)
	state.players[0].active_pokemon = blaziken_slot
	var no_bench_energy_a := _energy_instance("No Bench Fire A", "R", 0)
	var no_bench_energy_b := _energy_instance("No Bench Fire B", "R", 0)
	blaziken_slot.attached_energy = [no_bench_energy_a, no_bench_energy_b]
	var saved_opponent_bench := state.players[1].bench.duplicate()
	state.players[1].bench.clear()
	var hellfire_effects := processor.get_attack_effects_for_slot(blaziken_slot, 1)
	var no_bench_steps: Array[Dictionary] = []
	if not hellfire_effects.is_empty():
		no_bench_steps = hellfire_effects[0].call("get_attack_interaction_steps", blaziken_slot.get_top_card(), blaziken.attacks[1], state)
	checks.append(assert_eq(no_bench_steps.size(), 1, "CSV10C_038 UI should omit an empty Bench-target step"))
	processor.execute_attack_effect(blaziken_slot, 1, coin_target, state, [{"discard_two_energy_for_bench_damage": [no_bench_energy_a, no_bench_energy_b]}])
	checks.append(assert_true(no_bench_energy_a in state.players[0].discard_pile and no_bench_energy_b in state.players[0].discard_pile, "CSV10C_038 should discard two own Energy even when the opponent has no Bench"))
	state.players[1].bench = saved_opponent_bench
	var energy_a := _energy_instance("Fire A", "R", 0)
	var energy_b := _energy_instance("Fire B", "R", 0)
	blaziken_slot.attached_energy = [energy_a, energy_b]
	var bench_target := state.players[1].bench[0]
	processor.execute_attack_effect(blaziken_slot, 1, coin_target, state, [{
		"discard_two_energy_for_bench_damage": [energy_a, energy_b],
		"bench_damage_target": [bench_target],
	}])
	checks.append(assert_true(energy_a in state.players[0].discard_pile and energy_b in state.players[0].discard_pile, "CSV10C_038 should discard exactly the two selected attached Energy"))
	checks.append(assert_eq(bench_target.damage_counters, 120, "CSV10C_038 should deal 120 damage to one opposing Benched Pokemon"))

	var heat_rotom := _load_card("039")
	var heat_rotom_slot := _make_slot(heat_rotom, 0)
	state.players[0].active_pokemon = heat_rotom_slot
	coin_target.status_conditions["burned"] = false
	processor.execute_attack_effect(heat_rotom_slot, 0, coin_target, state)
	checks.append(assert_true(coin_target.status_conditions.get("burned", false), "CSV10C_039 致焦 should Burn without a coin flip"))
	heat_rotom_slot.attached_tool = _trainer_instance("Tool A", "Tool", 0)
	state.players[0].bench[0].attached_tool = _trainer_instance("Tool B", "Tool", 0)
	var accessory_show := processor.get_attack_effects_for_slot(heat_rotom_slot, 1)
	checks.append(assert_false(accessory_show.is_empty(), "CSV10C_039 配件秀 should count own attached Tools"))
	if not accessory_show.is_empty():
		checks.append(assert_eq(int(accessory_show[0].call("get_damage_bonus", heat_rotom_slot, state)), 30, "CSV10C_039 two Tools should make the printed 30x total 60"))

	var darumaka := _make_slot(_load_card("040"), 0)
	checks.append(assert_true(processor.get_attack_effects_for_slot(darumaka, 0).is_empty(), "CSV10C_040 first attack is numeric-only"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(darumaka, 1).is_empty(), "CSV10C_040 second attack is numeric-only"))
	return run_checks(checks)


func test_csv10c_041_045_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_041_045)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["041", "042", "043", "044", "045"]:
		processor.register_pokemon_card(_load_card(index))

	var darmanitan := _load_card("041")
	var darmanitan_slot := _make_slot(darmanitan, 0)
	state.players[0].active_pokemon = darmanitan_slot
	state.players[1].discard_pile = [_energy_instance("Water A", "W", 1), _energy_instance("Fire B", "R", 1)]
	var rekindle := processor.get_attack_effects_for_slot(darmanitan_slot, 0)
	checks.append(assert_false(rekindle.is_empty(), "CSV10C_041 复燃 should count opposing discarded Basic Energy"))
	if not rekindle.is_empty():
		checks.append(assert_eq(int(rekindle[0].call("get_damage_bonus", darmanitan_slot, state)), 30, "CSV10C_041 two Basic Energy should make the printed 30x total 60"))
	var attached_a := _energy_instance("Fire A", "R", 0)
	var attached_b := _energy_instance("Fire B", "R", 0)
	darmanitan_slot.attached_energy = [attached_a, attached_b]
	var darmanitan_bench_target := state.players[1].bench[0]
	processor.execute_attack_effect(darmanitan_slot, 1, state.players[1].active_pokemon, state, [{"opponent_bench_damage_targets": [darmanitan_bench_target]}])
	checks.append(assert_eq(darmanitan_slot.attached_energy.size(), 0, "CSV10C_041 should discard all attached Energy"))
	checks.append(assert_eq(darmanitan_bench_target.damage_counters, 90, "CSV10C_041 should also deal 90 to one opposing Benched Pokemon"))

	var volcanion := _load_card("042")
	var volcanion_slot := _make_slot(volcanion, 0)
	state.players[0].active_pokemon = volcanion_slot
	var steam := processor.get_effect(volcanion.effect_id)
	checks.append(assert_not_null(steam, "CSV10C_042 灼热蒸汽 should register"))
	if steam != null:
		steam.call("execute_ability", volcanion_slot, 0, [], state)
		checks.append(assert_true(state.players[1].active_pokemon.status_conditions.get("burned", false), "CSV10C_042 should Burn the opposing Active Pokemon"))
		checks.append(assert_false(bool(steam.call("can_use_ability", volcanion_slot, state)), "CSV10C_042 should be once per turn"))
	var moved_energy := _energy_instance("Fire", "R", 0)
	volcanion_slot.attached_energy = [moved_energy]
	var energy_target := state.players[0].bench[0]
	processor.execute_attack_effect(volcanion_slot, 0, state.players[1].active_pokemon, state, [{
		"move_attached_energy": [moved_energy],
		"move_energy_target": [energy_target],
	}])
	checks.append(assert_true(moved_energy in energy_target.attached_energy, "CSV10C_042 should move one attached Energy to a Benched Pokemon"))

	var psyduck := _load_card("043")
	var psyduck_slot := _make_slot(psyduck, 0)
	state.players[0].bench = [psyduck_slot]
	var self_ko_data := _pokemon("Self KO Pokemon", "P")
	self_ko_data.effect_id = "test_self_ko_ability"
	self_ko_data.abilities = [{"name": "Self KO", "text": "Knock Out this Pokemon."}]
	var self_ko_slot := _make_slot(self_ko_data, 1)
	state.players[1].active_pokemon = self_ko_slot
	processor.register_effect(self_ko_data.effect_id, AbilitySelfKnockoutDamageCounters.new(5))
	checks.append(assert_false(processor.can_use_ability(self_ko_slot, state, 0), "CSV10C_043 湿气 should disable abilities that Knock Out their user on both sides"))
	psyduck_slot.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_true(processor.can_use_ability(self_ko_slot, state, 0), "CSV10C_043 should stop blocking self-Knock-Out Abilities when 湿气 is disabled"))

	var golduck := _load_card("044")
	var golduck_slot := _make_slot(golduck, 0)
	state.players[0].active_pokemon = golduck_slot
	var rainbow_energy := _special_energy_instance("Rainbow Energy", 0)
	rainbow_energy.card_data.energy_provides = "ANY"
	golduck_slot.attached_energy = [_energy_instance("Water A", "W", 0), _energy_instance("Water B", "W", 0), rainbow_energy]
	var water_target := state.players[1].active_pokemon
	water_target.damage_counters = 0
	processor.execute_attack_effect(golduck_slot, 0, water_target, state)
	checks.append(assert_eq(water_target.damage_counters, 60, "CSV10C_044 should add 20 damage per attached Water Energy, including an all-type Special Energy"))

	var mistys_psyduck := _load_card("045")
	var mistys_psyduck_slot := _make_slot(mistys_psyduck, 0)
	state.players[0].active_pokemon = _make_slot(_pokemon("Other Active", "W"), 0)
	state.players[0].bench = [mistys_psyduck_slot]
	var deck_top := _trainer_instance("Deck Top", "Item", 0)
	var deck_bottom := _trainer_instance("Deck Bottom", "Item", 0)
	state.players[0].deck = [deck_top, deck_bottom]
	var attached_energy := _energy_instance("Water", "W", 0)
	var attached_tool := _trainer_instance("Tool", "Tool", 0)
	var psyduck_card := mistys_psyduck_slot.get_top_card()
	mistys_psyduck_slot.attached_energy = [attached_energy]
	mistys_psyduck_slot.attached_tool = attached_tool
	var skip_jump := processor.get_effect(mistys_psyduck.effect_id)
	checks.append(assert_not_null(skip_jump, "CSV10C_045 踱步跳跃 should register"))
	if skip_jump != null:
		skip_jump.call("execute_ability", mistys_psyduck_slot, 0, [], state)
		checks.append(assert_eq(state.players[0].deck[0], psyduck_card, "CSV10C_045 should put itself on top of the deck"))
		checks.append(assert_true(deck_bottom in state.players[0].discard_pile, "CSV10C_045 should discard the bottom card of the deck"))
		checks.append(assert_true(attached_energy in state.players[0].discard_pile and attached_tool in state.players[0].discard_pile, "CSV10C_045 should discard all cards attached to itself"))
		checks.append(assert_false(mistys_psyduck_slot in state.players[0].bench, "CSV10C_045 should leave the Bench"))
	return run_checks(checks)


func test_csv10c_046_050_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_046_050)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["046", "047", "048", "049", "050"]:
		processor.register_pokemon_card(_load_card(index))

	var staryu := _load_card("046")
	var staryu_slot := _make_slot(staryu, 0)
	var status_target := state.players[1].active_pokemon
	processor.execute_attack_effect(staryu_slot, 0, status_target, state)
	checks.append(assert_true(status_target.status_conditions.get("paralyzed", false), "CSV10C_046 heads should Paralyze the opposing Active Pokemon"))

	var starmie := _load_card("047")
	var starmie_slot := PokemonSlot.new()
	starmie_slot.pokemon_stack = [CardInstance.create(staryu, 0), CardInstance.create(starmie, 0)]
	starmie_slot.turn_evolved = state.turn_number
	var sudden_flash := processor.get_attack_effects_for_slot(starmie_slot, 0)
	checks.append(assert_false(sudden_flash.is_empty(), "CSV10C_047 骤然闪光 should register"))
	if not sudden_flash.is_empty():
		checks.append(assert_eq(int(sudden_flash[0].call("get_damage_bonus", starmie_slot, state)), 80, "CSV10C_047 should add 80 after evolving from 小霞的海星星 this turn"))
		starmie_slot.turn_evolved = state.turn_number - 1
		checks.append(assert_eq(int(sudden_flash[0].call("get_damage_bonus", starmie_slot, state)), 0, "CSV10C_047 should not add damage after the evolution turn"))

	var magikarp := _load_card("048")
	var magikarp_slot := _make_slot(magikarp, 0)
	state.players[0].bench = [magikarp_slot]
	checks.append(assert_true(AbilityBenchImmune.prevents_opponent_attack_damage(magikarp_slot, state.players[1].active_pokemon, state), "CSV10C_048 should prevent opposing attack damage while Benched"))
	checks.append(assert_true(AbilityBenchImmune.prevents_opponent_attack_effect(magikarp_slot, state.players[1].active_pokemon, state), "CSV10C_048 should prevent opposing attack effects while Benched"))
	magikarp_slot.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_false(AbilityBenchImmune.prevents_opponent_attack_damage(magikarp_slot, state.players[1].active_pokemon, state), "CSV10C_048 should lose Bench damage immunity when 深度下潜 is disabled"))
	checks.append(assert_false(AbilityBenchImmune.prevents_opponent_attack_effect(magikarp_slot, state.players[1].active_pokemon, state), "CSV10C_048 should lose Bench effect immunity when 深度下潜 is disabled"))

	var gyarados := _load_card("049")
	var gyarados_slot := _make_slot(gyarados, 0)
	state.players[0].active_pokemon = gyarados_slot
	state.players[0].deck.clear()
	for i: int in 3:
		state.players[0].deck.append(CardInstance.create(_pokemon("小霞的宝可梦 %d" % i, "W"), 0))
	for i: int in 4:
		state.players[0].deck.append(_trainer_instance("Item %d" % i, "Item", 0))
	var panic := processor.get_attack_effects_for_slot(gyarados_slot, 0)
	checks.append(assert_false(panic.is_empty(), "CSV10C_049 哗啦恐慌 should mill and count Misty's Pokemon"))
	if not panic.is_empty():
		checks.append(assert_eq(int(panic[0].call("get_damage_bonus", gyarados_slot, state)), 140, "CSV10C_049 three matching Pokemon should make the printed 70x total 210"))
	processor.execute_attack_effect(gyarados_slot, 0, status_target, state)
	checks.append(assert_eq(state.players[0].deck.size(), 0, "CSV10C_049 should discard the top seven cards"))
	checks.append(assert_eq(state.players[0].discard_pile.size(), 7, "CSV10C_049 should put all seven milled cards in the discard pile"))

	var lapras := _load_card("050")
	var lapras_slot := _make_slot(lapras, 0)
	state.players[0].active_pokemon = lapras_slot
	state.players[0].hand.clear()
	state.players[0].deck.clear()
	var misty_cards: Array[CardInstance] = []
	for i: int in 4:
		var candidate := CardInstance.create(_pokemon("小霞的宝可梦 %d" % i, "W"), 0)
		misty_cards.append(candidate)
		state.players[0].deck.append(candidate)
	state.players[0].deck.append(_trainer_instance("Other", "Item", 0))
	var swim_effects := processor.get_attack_effects_for_slot(lapras_slot, 0)
	if not swim_effects.is_empty():
		var swim_steps: Array[Dictionary] = swim_effects[0].call("get_attack_interaction_steps", lapras_slot.get_top_card(), lapras.attacks[0], state)
		var other_card: CardInstance = state.players[0].deck.back()
		checks.append(assert_eq(str(swim_steps[0].get("visible_scope", "")) if not swim_steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_050 should show the full own deck during search"))
		checks.append(assert_true(other_card in swim_steps[0].get("card_items", []) if not swim_steps.is_empty() else false, "CSV10C_050 should show non-Misty cards as disabled context"))
		checks.append(assert_false(other_card in swim_steps[0].get("items", []) if not swim_steps.is_empty() else true, "CSV10C_050 should keep non-Misty cards unselectable"))
	processor.execute_attack_effect(lapras_slot, 0, status_target, state, [{"search_mistys_pokemon": misty_cards.slice(0, 3)}])
	checks.append(assert_eq(state.players[0].hand.size(), 3, "CSV10C_050 should search up to three Misty's Pokemon"))
	checks.append(assert_true(state.players[0].hand.all(func(card: CardInstance) -> bool: return card.card_data.name.begins_with("小霞的")), "CSV10C_050 should not search non-Misty cards"))
	return run_checks(checks)


func test_csv10c_051_055_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_051_055)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["051", "052", "053", "054", "055"]:
		processor.register_pokemon_card(_load_card(index))

	var articuno := _load_card("051")
	var articuno_slot := _make_slot(articuno, 0)
	state.players[0].active_pokemon = articuno_slot
	var water_a := _energy_instance("Water A", "W", 0)
	var water_b := _energy_instance("Water B", "W", 0)
	var articuno_fire := _energy_instance("Fire", "R", 0)
	state.players[0].deck = [water_a, water_b, articuno_fire]
	var cold_wings := processor.get_attack_effects_for_slot(articuno_slot, 0)
	if not cold_wings.is_empty():
		var cold_steps: Array[Dictionary] = cold_wings[0].call("get_attack_interaction_steps", articuno_slot.get_top_card(), articuno.attacks[0], state)
		checks.append(assert_eq(str(cold_steps[0].get("source_visible_scope", "")) if not cold_steps.is_empty() else "", BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV10C_051 should show the full own deck during Energy search"))
		checks.append(assert_true(articuno_fire in cold_steps[0].get("source_card_items", []) if not cold_steps.is_empty() else false, "CSV10C_051 should show non-Water deck cards as disabled context"))
		checks.append(assert_false(articuno_fire in cold_steps[0].get("source_items", []) if not cold_steps.is_empty() else true, "CSV10C_051 should keep non-Water Energy unselectable"))
	processor.execute_attack_effect(articuno_slot, 0, state.players[1].active_pokemon, state, [{"energy_assignments": [
		{"source": water_a, "target": articuno_slot},
		{"source": water_b, "target": articuno_slot},
	]}])
	checks.append(assert_eq(articuno_slot.attached_energy.size(), 2, "CSV10C_051 should attach up to two Basic Water Energy from the deck to itself"))

	var rocket_articuno := _load_card("052")
	var rocket_articuno_slot := _make_slot(rocket_articuno, 0)
	state.players[0].active_pokemon = rocket_articuno_slot
	var rocket_basic := _make_slot(_pokemon("火箭队的基础宝可梦", "W"), 0)
	var normal_basic := _make_slot(_pokemon("Normal Basic", "W"), 0)
	state.players[0].bench = [rocket_basic, normal_basic]
	checks.append(assert_true(processor.is_attack_effect_prevented_by_defender_ability(state.players[1].active_pokemon, rocket_basic, state), "CSV10C_052 should prevent opposing attack effects on own Basic Team Rocket's Pokemon"))
	checks.append(assert_false(processor.is_attack_effect_prevented_by_defender_ability(state.players[1].active_pokemon, normal_basic, state), "CSV10C_052 should not protect a non-Team-Rocket Pokemon"))
	rocket_articuno_slot.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_false(processor.is_attack_effect_prevented_by_defender_ability(state.players[1].active_pokemon, rocket_basic, state), "CSV10C_052 should stop protecting when 抵抗之幕 is disabled"))
	rocket_articuno_slot.effects.clear()
	rocket_articuno_slot.attached_energy = [_special_energy_instance("火箭队能量", 0)]
	var dark_frost := processor.get_attack_effects_for_slot(rocket_articuno_slot, 0)
	checks.append(assert_false(dark_frost.is_empty(), "CSV10C_052 暗之冰霜 should register"))
	if not dark_frost.is_empty():
		checks.append(assert_eq(int(dark_frost[0].call("get_damage_bonus", rocket_articuno_slot, state)), 60, "CSV10C_052 should add 60 while Team Rocket Energy is attached"))

	checks.append(assert_true(processor.get_attack_effects_for_slot(_make_slot(_load_card("053"), 0), 0).is_empty(), "CSV10C_053 numeric attack should remain script-free"))

	var wailord := _load_card("054")
	var wailord_slot := _make_slot(wailord, 0)
	wailord_slot.attached_energy = [_energy_instance("Water A", "W", 0), _energy_instance("Water B", "W", 0)]
	var water_cannon_target := state.players[1].active_pokemon
	water_cannon_target.damage_counters = 0
	processor.execute_attack_effect(wailord_slot, 0, water_cannon_target, state)
	checks.append(assert_eq(water_cannon_target.damage_counters, 100, "CSV10C_054 should add 50 damage per attached Water Energy"))

	var feebas := _load_card("055")
	var feebas_slot := _make_slot(feebas, 0)
	processor.execute_attack_effect(feebas_slot, 0, state.players[1].active_pokemon, state)
	state.turn_number += 1
	checks.append(assert_true(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(feebas_slot, state), "CSV10C_055 heads should prevent attack damage next turn"))
	checks.append(assert_true(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(feebas_slot, state), "CSV10C_055 heads should prevent attack effects next turn"))
	return run_checks(checks)


func test_csv10c_052_resistance_veil_blocks_dragapult_bench_damage_counters() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var rocket_articuno := _load_card("052")
	var dragapult_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV8C_159.json"))
	var dragapult := CardData.from_dict(dragapult_raw) if dragapult_raw is Dictionary else null
	if rocket_articuno == null or dragapult == null:
		return "CSV10C_052 and CSV8C_159 must load for the cross-card regression"
	processor.register_pokemon_card(rocket_articuno)
	processor.register_pokemon_card(dragapult)

	var attacker := _make_slot(dragapult, 0)
	state.players[0].active_pokemon = attacker
	var shield_source := _make_slot(rocket_articuno, 1)
	var protected_basic := _make_slot(_pokemon("火箭队的基础宝可梦", "W"), 1)
	var unprotected_basic := _make_slot(_pokemon("普通基础宝可梦", "W"), 1)
	state.players[1].active_pokemon = shield_source
	state.players[1].bench = [protected_basic, unprotected_basic]
	var direct_protection := processor.is_attack_effect_prevented_by_defender_ability(attacker, protected_basic, state)
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var dragapult_effects := processor.get_attack_effects_for_slot(attacker, 1)
	var interaction_steps: Array[Dictionary] = dragapult_effects[0].call(
		"get_attack_interaction_steps",
		attacker.get_top_card(),
		dragapult.attacks[1],
		state
	) if not dragapult_effects.is_empty() else []
	var legal_targets: Array = interaction_steps[0].get("target_items", []) if not interaction_steps.is_empty() else []

	processor.execute_attack_effect(attacker, 1, shield_source, state, [{
		"bench_damage_counters": [
			{"target": protected_basic, "amount": 30},
			{"target": unprotected_basic, "amount": 30},
		]
	}])

	return run_checks([
		assert_true(direct_protection, "Resistance Veil should identify the protected Team Rocket target before Dragapult resolves"),
		assert_false(protected_basic in legal_targets, "Dragapult target UI must not offer a Basic Team Rocket's Pokemon protected by Resistance Veil"),
		assert_true(unprotected_basic in legal_targets, "Dragapult target UI should still offer an unprotected opposing Benched Pokemon"),
		assert_eq(protected_basic.damage_counters, 0, "Resistance Veil must block Dragapult ex attack-effect damage counters on a Basic Team Rocket's Pokemon"),
		assert_eq(unprotected_basic.damage_counters, 30, "Resistance Veil must not protect an ordinary Basic Pokemon"),
	])


func test_csv10c_056_060_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_056_060)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["056", "057", "058", "059", "060"]:
		processor.register_pokemon_card(_load_card(index))

	var milotic := _load_card("056")
	var milotic_slot := _make_slot(milotic, 0)
	state.players[0].active_pokemon = milotic_slot
	var bench_a := state.players[1].bench[0]
	var bench_b := _make_slot(_pokemon("Bench B", "C"), 1)
	state.players[1].bench.append(bench_b)
	processor.execute_attack_effect(milotic_slot, 0, state.players[1].active_pokemon, state, [{"opponent_bench_damage_targets": [bench_a, bench_b]}])
	checks.append(assert_eq(bench_a.damage_counters, 30, "CSV10C_056 should deal 30 to the first opposing Benched Pokemon"))
	checks.append(assert_eq(bench_b.damage_counters, 30, "CSV10C_056 should deal 30 to the second opposing Benched Pokemon"))

	var clamperl := _load_card("057")
	var clamperl_slot := _make_slot(clamperl, 0)
	processor.execute_attack_effect(clamperl_slot, 0, state.players[1].active_pokemon, state)
	state.turn_number += 1
	checks.append(assert_eq(processor.get_defender_modifier(clamperl_slot, state, state.players[1].active_pokemon), -10, "CSV10C_057 should reduce attack damage by 10 next turn"))

	var huntail := _load_card("058")
	var huntail_slot := _make_slot(huntail, 0)
	state.players[0].bench = [huntail_slot]
	var knocked_out_water := _make_slot(_pokemon("Water Pokemon", "W"), 0)
	state.players[0].active_pokemon = knocked_out_water
	var basic_water_a := _energy_instance("Water A", "W", 0)
	var basic_water_b := _energy_instance("Water B", "W", 0)
	var basic_fire := _energy_instance("Fire", "R", 0)
	knocked_out_water.attached_energy = [basic_water_a, basic_water_b, basic_fire]
	var return_energy: Array[CardInstance] = processor.get_knockout_attached_cards_to_hand(knocked_out_water, state, true)
	checks.append(assert_eq(return_energy, [basic_water_a, basic_water_b], "CSV10C_058 should return all and only Basic Water Energy from an attack-damage Knock Out"))
	checks.append(assert_true(processor.get_knockout_attached_cards_to_hand(knocked_out_water, state, false).is_empty(), "CSV10C_058 should not trigger for a non-attack-damage Knock Out"))
	huntail_slot.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_true(processor.get_knockout_attached_cards_to_hand(knocked_out_water, state, true).is_empty(), "CSV10C_058 should not return Energy while 潜者捕捉 is disabled"))
	huntail_slot.effects.clear()

	var gorebyss := _load_card("059")
	checks.append(assert_eq(gorebyss.evolves_from, "珍珠贝", "CSV10C_059 should display the evolution source printed on the card"))
	checks.append(assert_true(gorebyss.evolves_from_matches(_load_card("057")), "CSV10C_059 should legally evolve from CSV10C_057"))
	var gorebyss_slot := _make_slot(gorebyss, 0)
	state.players[0].active_pokemon = gorebyss_slot
	gorebyss_slot.attached_energy = [_energy_instance("Attached Water", "W", 0)]
	var hand_water_a := _energy_instance("Hand Water A", "W", 0)
	var hand_water_b := _energy_instance("Hand Water B", "W", 0)
	state.players[0].hand = [hand_water_a, hand_water_b, _energy_instance("Hand Fire", "R", 0)]
	var crescendo := processor.get_attack_effects_for_slot(gorebyss_slot, 0)
	checks.append(assert_false(crescendo.is_empty(), "CSV10C_059 渐强波 should register"))
	if not crescendo.is_empty():
		var crescendo_steps: Array[Dictionary] = crescendo[0].call("get_attack_interaction_steps", gorebyss_slot.get_top_card(), gorebyss.attacks[0], state)
		checks.append(assert_eq(int(crescendo_steps[0].get("min_select", -1)) if not crescendo_steps.is_empty() else -1, 0, "CSV10C_059 UI should allow attaching no Energy"))
		checks.append(assert_eq(int(crescendo_steps[0].get("max_select", -1)) if not crescendo_steps.is_empty() else -1, 2, "CSV10C_059 UI should allow selecting every eligible Basic Water Energy"))
		crescendo[0].set_attack_interaction_context([{"attach_water_from_hand_before_damage": [hand_water_a, hand_water_b]}])
		checks.append(assert_eq(int(crescendo[0].call("get_damage_bonus", gorebyss_slot, state)), 60, "CSV10C_059 three Water Energy after attachment should make the printed 30x total 90"))
		crescendo[0].clear_attack_interaction_context()
	processor.execute_attack_effect(gorebyss_slot, 0, state.players[1].active_pokemon, state, [{"attach_water_from_hand_before_damage": [hand_water_a, hand_water_b]}])
	checks.append(assert_eq(gorebyss_slot.attached_energy.size(), 3, "CSV10C_059 should attach any selected Basic Water Energy before damage"))

	var wash_rotom := _load_card("060")
	var wash_rotom_slot := _make_slot(wash_rotom, 0)
	state.players[0].active_pokemon = wash_rotom_slot
	wash_rotom_slot.damage_counters = 30
	state.players[0].bench[0].damage_counters = 20
	processor.execute_attack_effect(wash_rotom_slot, 0, state.players[1].active_pokemon, state)
	checks.append(assert_eq(wash_rotom_slot.damage_counters, 20, "CSV10C_060 should heal its Active Pokemon by 10"))
	checks.append(assert_eq(state.players[0].bench[0].damage_counters, 10, "CSV10C_060 should heal every own Benched Pokemon by 10"))
	checks.append(assert_false(processor.get_attack_effects_for_slot(wash_rotom_slot, 1).is_empty(), "CSV10C_060 配件秀 should count own Pokemon Tools"))
	return run_checks(checks)


func test_csv10c_061_065_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_061_065)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["061", "062", "063", "064", "065"]:
		processor.register_pokemon_card(_load_card(index))

	var cetoddle := _make_slot(_load_card("061"), 0)
	checks.append(assert_true(processor.get_attack_effects_for_slot(cetoddle, 0).is_empty(), "CSV10C_061 first attack is numeric-only"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(cetoddle, 1).is_empty(), "CSV10C_061 second attack is numeric-only"))

	var cetitan := _load_card("062")
	var cetitan_slot := _make_slot(cetitan, 0)
	state.players[0].active_pokemon = cetitan_slot
	var opponent_item := _trainer_instance("Opponent Item", "Item", 1)
	var own_supporter := _trainer_instance("Own Supporter", "Supporter", 0)
	checks.append(assert_true(processor.is_protected_from_opponent_hand_trainer_effect(cetitan_slot, opponent_item, state), "CSV10C_062 should ignore opponent Item effects played from hand"))
	checks.append(assert_false(processor.is_protected_from_opponent_hand_trainer_effect(cetitan_slot, own_supporter, state), "CSV10C_062 should not ignore its owner's Supporter"))
	state.stadium_card = _trainer_instance("Stadium", "Stadium", 1)
	state.stadium_owner_index = 1
	var stadium := state.stadium_card
	var crush := processor.get_attack_effects_for_slot(cetitan_slot, 0)
	checks.append(assert_false(crush.is_empty(), "CSV10C_062 粉碎压制 should register"))
	if not crush.is_empty():
		crush[0].set_attack_interaction_context([{"discard_stadium_bonus": ["discard"]}])
		checks.append(assert_eq(int(crush[0].call("get_damage_bonus", cetitan_slot, state)), 140, "CSV10C_062 should add 140 when discarding the Stadium"))
		crush[0].clear_attack_interaction_context()
	processor.execute_attack_effect(cetitan_slot, 0, state.players[1].active_pokemon, state, [{"discard_stadium_bonus": ["discard"]}])
	checks.append(assert_null(state.stadium_card, "CSV10C_062 should discard the Stadium when chosen"))
	checks.append(assert_true(stadium in state.players[1].discard_pile, "CSV10C_062 should move the Stadium to its owner's discard pile"))

	var dondozo := _load_card("063")
	var dondozo_slot := _make_slot(dondozo, 0)
	dondozo_slot.damage_counters = 40
	var counterattack := processor.get_attack_effects_for_slot(dondozo_slot, 0)
	checks.append(assert_false(counterattack.is_empty(), "CSV10C_063 骇浪反攻 should register"))
	if not counterattack.is_empty():
		checks.append(assert_eq(int(counterattack[0].call("get_damage_bonus", dondozo_slot, state)), 40, "CSV10C_063 should add 10 per damage counter"))
	var dive := processor.get_attack_effects_for_slot(dondozo_slot, 1)
	checks.append(assert_false(dive.is_empty(), "CSV10C_063 强劲俯冲 should register"))
	if not dive.is_empty():
		dive[0].set_attack_interaction_context([{"optional_bonus_self_damage": ["yes"]}])
		checks.append(assert_eq(int(dive[0].call("get_damage_bonus", dondozo_slot, state)), 120, "CSV10C_063 should add 120 when the option is chosen"))
		dive[0].clear_attack_interaction_context()
	processor.execute_attack_effect(dondozo_slot, 1, state.players[1].active_pokemon, state, [{"optional_bonus_self_damage": ["yes"]}])
	checks.append(assert_eq(dondozo_slot.damage_counters, 90, "CSV10C_063 should deal 50 recoil when taking the bonus"))

	var voltorb := _load_card("064")
	var voltorb_slot := _make_slot(voltorb, 0)
	var iono_bench := _make_slot(_pokemon("奇树的电海燕", "L"), 0)
	var other_bench := _make_slot(_pokemon("Other Pokemon", "L"), 0)
	voltorb_slot.attached_energy = [_energy_instance("Lightning A", "L", 0)]
	iono_bench.attached_energy = [_energy_instance("Lightning B", "L", 0), _energy_instance("Lightning C", "L", 0)]
	var iono_rainbow := _special_energy_instance("Rainbow Energy", 0)
	iono_rainbow.card_data.energy_provides = "ANY"
	iono_bench.attached_energy.append(iono_rainbow)
	other_bench.attached_energy = [_energy_instance("Lightning D", "L", 0)]
	state.players[0].active_pokemon = voltorb_slot
	state.players[0].bench = [iono_bench, other_bench]
	var chain_volt := processor.get_attack_effects_for_slot(voltorb_slot, 0)
	checks.append(assert_false(chain_volt.is_empty(), "CSV10C_064 连锁伏特 should register"))
	if not chain_volt.is_empty():
		checks.append(assert_eq(int(chain_volt[0].call("get_damage_bonus", voltorb_slot, state)), 80, "CSV10C_064 should count Lightning and any-type Energy on Iono's Pokemon"))

	var electrode := _load_card("065")
	var electrode_slot := _make_slot(electrode, 0)
	var bomb_target := state.players[1].active_pokemon
	bomb_target.damage_counters = 0
	processor.execute_attack_effect(electrode_slot, 0, bomb_target, state)
	checks.append(assert_eq(electrode_slot.damage_counters, 100, "CSV10C_065 should deal 100 damage to itself"))
	checks.append(assert_true(bomb_target.is_knocked_out(), "CSV10C_065 heads should Knock Out the opposing Active Pokemon"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(electrode_slot, 1).is_empty(), "CSV10C_065 second attack is numeric-only"))
	return run_checks(checks)


func test_csv10c_066_070_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_066_070)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["066", "067", "068", "069", "070"]:
		processor.register_pokemon_card(_load_card(index))

	checks.append(assert_true(processor.get_attack_effects_for_slot(_make_slot(_load_card("066"), 0), 0).is_empty(), "CSV10C_066 numeric attack should remain script-free"))

	var electivire := _load_card("067")
	var electivire_slot := _make_slot(electivire, 0)
	state.players[0].active_pokemon = electivire_slot
	var target_active := state.players[1].active_pokemon
	var target_bench := state.players[1].bench[0]
	processor.execute_attack_effect(electivire_slot, 0, target_active, state, [{"opponent_two_targets": [target_active, target_bench]}])
	checks.append(assert_eq(target_active.damage_counters, 50, "CSV10C_067 should deal 50 to the first chosen opponent Pokemon"))
	checks.append(assert_eq(target_bench.damage_counters, 50, "CSV10C_067 should deal 50 to the second chosen opponent Pokemon"))
	for i: int in 5:
		electivire_slot.attached_energy.append(_energy_instance("Lightning %d" % i, "L", 0))
	var high_voltage := processor.get_attack_effects_for_slot(electivire_slot, 1)
	checks.append(assert_false(high_voltage.is_empty(), "CSV10C_067 高压电压制 should register"))
	if not high_voltage.is_empty():
		checks.append(assert_eq(int(high_voltage[0].call("get_damage_bonus", electivire_slot, state)), 100, "CSV10C_067 should add 100 with two Energy beyond its three-Energy cost"))
		electivire_slot.attached_energy.pop_back()
		checks.append(assert_eq(int(high_voltage[0].call("get_damage_bonus", electivire_slot, state)), 0, "CSV10C_067 should not add damage with only one excess Energy"))

	var zapdos := _load_card("068")
	var zapdos_slot := _make_slot(zapdos, 0)
	state.players[0].active_pokemon = zapdos_slot
	var opposing_energy := _energy_instance("Opposing Lightning", "L", 1)
	target_active.attached_energy = [opposing_energy]
	var zapdos_move_effects := processor.get_attack_effects_for_slot(zapdos_slot, 0)
	checks.append(assert_false(zapdos_move_effects.is_empty(), "CSV10C_068 阻碍之翼 should register"))
	if not zapdos_move_effects.is_empty():
		var move_steps: Array[Dictionary] = zapdos_move_effects[0].call("get_attack_interaction_steps", zapdos_slot.get_top_card(), zapdos.attacks[0], state)
		checks.append(assert_eq(move_steps.size(), 1, "CSV10C_068 UI should pair the optional Energy and Bench target in one assignment step"))
		checks.append(assert_eq(str(move_steps[0].get("ui_mode", "")) if not move_steps.is_empty() else "", "card_assignment", "CSV10C_068 should use card-assignment UI"))
	processor.execute_attack_effect(zapdos_slot, 0, target_active, state, [{
		"move_opponent_active_energy_assignment": [{"source": opposing_energy, "target": target_bench}],
	}])
	checks.append(assert_true(opposing_energy in target_bench.attached_energy, "CSV10C_068 should move one opposing Active Energy to the opponent's Bench"))
	zapdos_slot.attached_energy = [_special_energy_instance("火箭队能量", 0)]
	var outlaw_lightning := processor.get_attack_effects_for_slot(zapdos_slot, 1)
	checks.append(assert_false(outlaw_lightning.is_empty(), "CSV10C_068 狂徒闪电 should register"))
	if not outlaw_lightning.is_empty():
		checks.append(assert_eq(int(outlaw_lightning[0].call("get_damage_bonus", zapdos_slot, state)), 60, "CSV10C_068 should add 60 with Team Rocket Energy"))

	var pichu := _load_card("069")
	var pichu_slot := _make_slot(pichu, 0)
	state.players[0].deck = [_trainer_instance("Drawn", "Item", 0)]
	state.players[0].hand.clear()
	processor.execute_attack_effect(pichu_slot, 0, target_active, state)
	checks.append(assert_eq(state.players[0].hand.size(), 1, "CSV10C_069 should draw one card"))

	var mareep := _load_card("070")
	var mareep_slot := _make_slot(mareep, 0)
	var item := _trainer_instance("Search Item", "Item", 0)
	var supporter := _trainer_instance("Wrong Supporter", "Supporter", 0)
	state.players[0].deck = [supporter, item]
	state.players[0].hand.clear()
	processor.execute_attack_effect(mareep_slot, 0, target_active, state, [{"search_cards": [item]}])
	checks.append(assert_true(item in state.players[0].hand, "CSV10C_070 should search one Item"))
	checks.append(assert_false(supporter in state.players[0].hand, "CSV10C_070 should not search a Supporter"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(mareep_slot, 1).is_empty(), "CSV10C_070 second attack is numeric-only"))
	return run_checks(checks)


func test_csv10c_071_075_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_071_075)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["071", "072", "073", "074", "075"]:
		processor.register_pokemon_card(_load_card(index))

	var flaaffy := _make_slot(_load_card("071"), 0)
	var paralysis_target := state.players[1].active_pokemon
	processor.execute_attack_effect(flaaffy, 0, paralysis_target, state)
	checks.append(assert_true(paralysis_target.status_conditions.get("paralyzed", false), "CSV10C_071 heads should Paralyze the opposing Active Pokemon"))

	var ampharos := _load_card("072")
	var ampharos_a := _make_slot(ampharos, 0)
	var ampharos_b := _make_slot(ampharos, 0)
	state.players[0].active_pokemon = ampharos_a
	state.players[0].bench = [ampharos_b]
	var evolved_target := _make_slot(_pokemon("Opponent Evolved Pokemon", "G"), 1)
	state.players[1].active_pokemon = evolved_target
	processor.process_after_evolution_from_hand(1, evolved_target, state)
	checks.append(assert_eq(evolved_target.damage_counters, 40, "CSV10C_072 should place four damage counters when the opponent evolves from hand"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(ampharos_a, 0).is_empty(), "CSV10C_072 attack is numeric-only"))

	var electrike := _make_slot(_load_card("073"), 0)
	checks.append(assert_true(processor.get_attack_effects_for_slot(electrike, 0).is_empty(), "CSV10C_073 first attack is numeric-only"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(electrike, 1).is_empty(), "CSV10C_073 second attack is numeric-only"))

	var manectric := _make_slot(_load_card("074"), 0)
	state.players[0].active_pokemon = manectric
	var own_bench_target := _make_slot(_pokemon("Own Bench", "L"), 0)
	state.players[0].bench = [own_bench_target]
	processor.execute_attack_effect(manectric, 1, evolved_target, state, [{"self_bench_target": [own_bench_target]}])
	checks.append(assert_eq(own_bench_target.damage_counters, 40, "CSV10C_074 should deal 40 damage to one chosen own Benched Pokemon"))

	var rotom := _load_card("075")
	var rotom_slot := _make_slot(rotom, 0)
	var hidden_a := _trainer_instance("Secret A", "Item", 1)
	var hidden_b := _trainer_instance("Secret B", "Supporter", 1)
	state.players[1].hand = [hidden_a, hidden_b]
	var astonish := processor.get_attack_effects_for_slot(rotom_slot, 0)
	checks.append(assert_false(astonish.is_empty(), "CSV10C_075 惊吓 should register"))
	if not astonish.is_empty():
		var steps: Array[Dictionary] = astonish[0].call("get_attack_interaction_steps", rotom_slot.get_top_card(), rotom.attacks[0], state)
		checks.append(assert_eq(steps[0].get("labels", []) if not steps.is_empty() else [], ["Opponent hand card 1", "Opponent hand card 2"], "CSV10C_075 must not reveal opponent hand identities before selection"))
		var reveal_steps: Array[Dictionary] = astonish[0].call("get_followup_attack_interaction_steps", rotom_slot.get_top_card(), rotom.attacks[0], state, {"opponent_hand_card_to_deck": [hidden_b]})
		checks.append(assert_eq(reveal_steps.size(), 1, "CSV10C_075 should reveal the selected hand card before shuffling it into the deck"))
		checks.append(assert_eq(reveal_steps[0].get("card_items", []) if not reveal_steps.is_empty() else [], [hidden_b], "CSV10C_075 reveal UI should expose only the selected hand card"))
		checks.append(assert_eq(reveal_steps[0].get("card_indices", []) if not reveal_steps.is_empty() else [], [-1], "CSV10C_075 revealed hand card should be view-only"))
	processor.execute_attack_effect(rotom_slot, 0, evolved_target, state, [{"opponent_hand_card_to_deck": [hidden_b]}])
	checks.append(assert_true(hidden_b in state.players[1].deck and hidden_b not in state.players[1].hand, "CSV10C_075 should shuffle the chosen hidden hand card into the opponent's deck"))
	state.players[1].hand = [hidden_a]
	processor.execute_attack_effect(rotom_slot, 1, evolved_target, state)
	checks.append(assert_true(hidden_a in state.players[1].hand, "CSV10C_075 配件秀 must not also execute 惊吓"))
	return run_checks(checks)


func test_csv10c_076_080_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_076_080)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysHeads.new()
	for index: String in ["076", "077", "078", "079", "080"]:
		processor.register_pokemon_card(_load_card(index))

	var joltik := _make_slot(_load_card("076"), 0)
	var tool_target := state.players[1].active_pokemon
	var opponent_tool := _trainer_instance("Opponent Tool", "Tool", 1)
	tool_target.attached_tool = opponent_tool
	processor.execute_attack_effect(joltik, 0, tool_target, state)
	checks.append(assert_null(tool_target.attached_tool, "CSV10C_076 should discard the opposing Active Pokemon Tool before damage"))
	checks.append(assert_true(opponent_tool in state.players[1].discard_pile, "CSV10C_076 should put the discarded Tool in its owner's discard pile"))
	checks.append(assert_true(tool_target.status_conditions.get("paralyzed", false), "CSV10C_076 should Paralyze only after successfully discarding the Tool"))

	var zeraora := _make_slot(_load_card("077"), 0)
	state.players[0].active_pokemon = zeraora
	zeraora.attached_energy = [_energy_instance("Lightning A", "L", 0), _energy_instance("Lightning B", "L", 0), _energy_instance("Lightning C", "L", 0)]
	var bench_ex := _make_slot(_pokemon("Bench ex", "L", "ex"), 1)
	var bench_normal := _make_slot(_pokemon("Bench Normal", "L"), 1)
	state.players[1].bench = [bench_normal, bench_ex]
	processor.execute_attack_effect(zeraora, 1, tool_target, state, [{"bench_ex_target": [bench_ex]}])
	checks.append(assert_eq(zeraora.attached_energy.size(), 0, "CSV10C_077 should discard all attached Energy"))
	checks.append(assert_eq(bench_ex.damage_counters, 210, "CSV10C_077 should deal 210 only to one opposing Benched Pokemon ex"))
	checks.append(assert_eq(bench_normal.damage_counters, 0, "CSV10C_077 should not damage a non-ex Benched Pokemon"))

	checks.append(assert_true(processor.get_attack_effects_for_slot(_make_slot(_load_card("078"), 0), 0).is_empty(), "CSV10C_078 numeric attack should remain script-free"))

	var bellibolt := _make_slot(_load_card("079"), 0)
	var iono_target := _make_slot(_pokemon("奇树的电海燕", "L"), 0)
	state.players[0].active_pokemon = bellibolt
	state.players[0].bench = [iono_target]
	var lightning_a := _energy_instance("Lightning A", "L", 0)
	var lightning_b := _energy_instance("Lightning B", "L", 0)
	state.players[0].hand = [lightning_a, lightning_b]
	var electric_stream := processor.get_effect(_load_card("079").effect_id)
	checks.append(assert_not_null(electric_stream, "CSV10C_079 电气直播 should register"))
	if electric_stream != null:
		var stream_steps: Array[Dictionary] = electric_stream.call("get_interaction_steps", bellibolt.get_top_card(), state)
		checks.append(assert_eq(stream_steps.size(), 1, "CSV10C_079 UI should pair the Basic Lightning Energy and Iono target in one assignment step"))
		checks.append(assert_eq(str(stream_steps[0].get("ui_mode", "")) if not stream_steps.is_empty() else "", "card_assignment", "CSV10C_079 should use card-assignment UI"))
		electric_stream.call("execute_ability", bellibolt, 0, [{"iono_lightning_assignment": [{"source": lightning_a, "target": iono_target}]}], state)
		checks.append(assert_true(bool(electric_stream.call("can_use_ability", bellibolt, state)), "CSV10C_079 should remain usable multiple times per turn"))
		electric_stream.call("execute_ability", bellibolt, 0, [{"iono_lightning_assignment": [{"source": lightning_b, "target": iono_target}]}], state)
		checks.append(assert_eq(iono_target.attached_energy.size(), 2, "CSV10C_079 should attach one Basic Lightning Energy on each use"))
	processor.execute_attack_effect(bellibolt, 0, tool_target, state)
	checks.append(assert_true(bellibolt.effects.any(func(entry: Dictionary) -> bool: return entry.get("type", "") == "attack_lock_all"), "CSV10C_079 should lock itself from attacking on its next turn"))

	var wattrel := _make_slot(_load_card("080"), 0)
	var coin_target := state.players[1].active_pokemon
	coin_target.damage_counters = 0
	processor.execute_attack_effect(wattrel, 0, coin_target, state)
	checks.append(assert_eq(coin_target.damage_counters, 20, "CSV10C_080 heads should add 20 damage beyond the printed 10"))
	return run_checks(checks)


func test_csv10c_081_085_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_081_085)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysTails.new()
	for index: String in ["081", "082", "083", "084", "085"]:
		processor.register_pokemon_card(_load_card(index))

	var kilowattrel := _make_slot(_load_card("081"), 0)
	state.players[0].active_pokemon = kilowattrel
	var attached_lightning := _energy_instance("Attached Lightning", "L", 0)
	kilowattrel.attached_energy = [attached_lightning]
	state.players[0].hand = [_trainer_instance("Hand A", "Item", 0), _trainer_instance("Hand B", "Item", 0), _trainer_instance("Hand C", "Item", 0)]
	for i: int in 5:
		state.players[0].deck.append(_trainer_instance("Deck %d" % i, "Item", 0))
	var flash_draw := processor.get_effect(_load_card("081").effect_id)
	checks.append(assert_not_null(flash_draw, "CSV10C_081 闪光抽取 should register"))
	if flash_draw != null:
		flash_draw.call("execute_ability", kilowattrel, 0, [{"discard_attached_basic_lightning": [attached_lightning]}], state)
		checks.append(assert_true(attached_lightning in state.players[0].discard_pile, "CSV10C_081 should discard one attached Basic Lightning Energy"))
		checks.append(assert_eq(state.players[0].hand.size(), 6, "CSV10C_081 should draw until the hand contains six cards"))
		checks.append(assert_false(bool(flash_draw.call("can_use_ability", kilowattrel, state)), "CSV10C_081 should be once per turn"))

	var clefairy := _make_slot(_load_card("082"), 0)
	state.players[0].active_pokemon = clefairy
	var dragon := _make_slot(_pokemon("Opponent Dragon", "N"), 1)
	state.players[1].active_pokemon = dragon
	var fairy_zone := processor.get_effect(_load_card("082").effect_id)
	checks.append(assert_not_null(fairy_zone, "CSV10C_082 妖精领域 should register"))
	if fairy_zone != null:
		checks.append(assert_eq(str(fairy_zone.call("get_weakness_energy_override_for_target", clefairy, dragon, state)), "P", "CSV10C_082 should change opposing Dragon Weakness to Psychic"))
		checks.append(assert_eq(str(fairy_zone.call("get_weakness_value_override_for_target", clefairy, dragon, state)), "x2", "CSV10C_082 should set the changed Weakness to x2"))
	state.players[0].bench = [_make_slot(_pokemon("Own Bench", "P"), 0)]
	state.players[1].bench = [_make_slot(_pokemon("Opp Bench A", "P"), 1), _make_slot(_pokemon("Opp Bench B", "P"), 1)]
	var rondo := processor.get_attack_effects_for_slot(clefairy, 0)
	checks.append(assert_false(rondo.is_empty(), "CSV10C_082 满月回旋曲 should register"))
	if not rondo.is_empty():
		checks.append(assert_eq(int(rondo[0].call("get_damage_bonus", clefairy, state)), 60, "CSV10C_082 should add 20 per Benched Pokemon on both sides"))

	var drowzee := _make_slot(_load_card("083"), 0)
	processor.execute_attack_effect(drowzee, 0, dragon, state)
	checks.append(assert_true(dragon.status_conditions.get("asleep", false), "CSV10C_083 should make the opposing Active Pokemon Asleep"))

	var hypno := _make_slot(_load_card("084"), 0)
	var bench_control := processor.get_attack_effects_for_slot(hypno, 1)
	checks.append(assert_false(bench_control.is_empty(), "CSV10C_084 备战操纵 should register"))
	if not bench_control.is_empty():
		checks.append(assert_eq(int(bench_control[0].call("get_damage_bonus", hypno, state)), 80, "CSV10C_084 two tails should make the printed 80x total 160"))
	checks.append(assert_true(processor.attack_ignores_weakness_and_resistance(hypno, 1, state), "CSV10C_084 should ignore Weakness and Resistance"))

	var mewtwo := _make_slot(_load_card("085"), 0)
	state.players[0].active_pokemon = mewtwo
	var rocket_a := _make_slot(_pokemon("火箭队的宝可梦 A", "P"), 0)
	var rocket_b := _make_slot(_pokemon("火箭队的宝可梦 B", "P"), 0)
	state.players[0].bench = [rocket_a, rocket_b]
	var suppressor := processor.get_effect(_load_card("085").effect_id)
	checks.append(assert_not_null(suppressor, "CSV10C_085 力量抑制者 should register"))
	if suppressor != null:
		checks.append(assert_false(str(suppressor.call("get_attack_unusable_reason", mewtwo, 0, state)).is_empty(), "CSV10C_085 should not attack with only three Team Rocket's Pokemon in play"))
		var rocket_c := _make_slot(_pokemon("火箭队的宝可梦 C", "P"), 0)
		state.players[0].bench.append(rocket_c)
		checks.append(assert_true(str(suppressor.call("get_attack_unusable_reason", mewtwo, 0, state)).is_empty(), "CSV10C_085 should attack with four Team Rocket's Pokemon in play"))
	var bench_energy_a := _energy_instance("Bench Energy A", "P", 0)
	var bench_energy_b := _energy_instance("Bench Energy B", "P", 0)
	rocket_a.attached_energy = [bench_energy_a]
	rocket_b.attached_energy = [bench_energy_b]
	var erase_ball := processor.get_attack_effects_for_slot(mewtwo, 0)
	checks.append(assert_false(erase_ball.is_empty(), "CSV10C_085 擦除球 should register"))
	if not erase_ball.is_empty():
		var erase_steps: Array[Dictionary] = erase_ball[0].call("get_attack_interaction_steps", mewtwo.get_top_card(), _load_card("085").attacks[0], state)
		var erase_labels: Array = erase_steps[0].get("labels", []) if not erase_steps.is_empty() else []
		checks.append(assert_true(erase_labels.any(func(label: Variant) -> bool: return rocket_a.get_pokemon_name() in str(label)), "CSV10C_085 UI should identify which Benched Pokemon each selectable Energy belongs to"))
		erase_ball[0].set_attack_interaction_context([{"mewtwo_discard_bench_energy": [bench_energy_a, bench_energy_b]}])
		checks.append(assert_eq(int(erase_ball[0].call("get_damage_bonus", mewtwo, state)), 120, "CSV10C_085 should add 60 per discarded Bench Energy"))
		erase_ball[0].clear_attack_interaction_context()
	processor.execute_attack_effect(mewtwo, 0, dragon, state, [{"mewtwo_discard_bench_energy": [bench_energy_a, bench_energy_b]}])
	checks.append(assert_true(bench_energy_a in state.players[0].discard_pile and bench_energy_b in state.players[0].discard_pile, "CSV10C_085 should discard the selected Bench Energy"))
	return run_checks(checks)


func test_csv10c_086_090_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_086_090)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["086", "087", "088", "089", "090"]:
		processor.register_pokemon_card(_load_card(index))

	var wobbuffet := _make_slot(_load_card("086"), 0)
	state.players[0].active_pokemon = wobbuffet
	var damaged_rocket := _make_slot(_pokemon("Team Rocket's Damaged Pokemon", "P"), 0)
	damaged_rocket.damage_counters = 60
	var damaged_normal := _make_slot(_pokemon("Ordinary Damaged Pokemon", "P"), 0)
	damaged_normal.damage_counters = 40
	state.players[0].bench = [damaged_rocket, damaged_normal]
	var mirror_target := state.players[1].active_pokemon
	processor.execute_attack_effect(wobbuffet, 0, mirror_target, state, [{"rocket_mirror_source": [damaged_rocket]}])
	checks.append(assert_eq(damaged_rocket.damage_counters, 0, "CSV10C_086 should remove all damage counters from the selected Benched Team Rocket's Pokemon"))
	checks.append(assert_eq(damaged_normal.damage_counters, 40, "CSV10C_086 should not move counters from a non-Team-Rocket Pokemon"))
	checks.append(assert_eq(mirror_target.damage_counters, 60, "CSV10C_086 should put all moved counters on the opposing Active Pokemon"))
	damaged_rocket.damage_counters = 30
	var mirror_mist := _special_energy_instance("Mist Energy", 1)
	mirror_mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	mirror_target.attached_energy = [mirror_mist]
	processor.execute_attack_effect(wobbuffet, 0, mirror_target, state, [{"rocket_mirror_source": [damaged_rocket]}])
	checks.append(assert_eq(damaged_rocket.damage_counters, 30, "CSV10C_086 should leave the source counters in place when Mist Energy prevents the move"))
	checks.append(assert_eq(mirror_target.damage_counters, 60, "CSV10C_086 should not place counters through attack-effect protection"))
	mirror_target.attached_energy.clear()

	var baltoy := _make_slot(_load_card("087"), 0)
	state.players[0].active_pokemon = baltoy
	state.players[0].bench.clear()
	var steven_a := CardInstance.create(_pokemon("Steven's Beldum", "M"), 0)
	var steven_b := CardInstance.create(_pokemon("Steven's Skarmory", "M"), 0)
	var wrong_basic := CardInstance.create(_pokemon("Ordinary Basic", "M"), 0)
	state.players[0].deck = [wrong_basic, steven_a, steven_b]
	var rally_effects := processor.get_attack_effects_for_slot(baltoy, 0)
	checks.append(assert_false(rally_effects.is_empty(), "CSV10C_087 召集信号 should register"))
	if not rally_effects.is_empty():
		var rally_steps: Array[Dictionary] = rally_effects[0].call("get_attack_interaction_steps", baltoy.get_top_card(), _load_card("087").attacks[0], state)
		checks.append(assert_true(wrong_basic in rally_steps[0].get("card_items", []) if not rally_steps.is_empty() else false, "CSV10C_087 should show the full deck while disabling unrelated cards"))
	processor.execute_attack_effect(baltoy, 0, mirror_target, state, [{"search_basic_steven_to_bench": [steven_a, steven_b]}])
	checks.append(assert_eq(state.players[0].bench.size(), 2, "CSV10C_087 should put up to two Basic Steven's Pokemon onto the Bench"))
	checks.append(assert_true(state.players[0].bench.all(func(slot: PokemonSlot) -> bool: return slot.get_pokemon_name().begins_with("Steven's ")), "CSV10C_087 must only Bench Steven's Pokemon"))
	checks.append(assert_true(wrong_basic in state.players[0].deck, "CSV10C_087 should leave an unrelated Basic Pokemon in the deck"))

	var claydol := _make_slot(_load_card("088"), 0)
	var claydol_target := state.players[1].active_pokemon
	processor.execute_attack_effect(claydol, 0, claydol_target, state)
	checks.append(assert_true(claydol_target.status_conditions.get("confused", false), "CSV10C_088 first attack should Confuse the opposing Active Pokemon"))
	claydol.attached_energy = [_energy_instance("Psychic A", "P", 0), _energy_instance("Psychic B", "P", 0)]
	processor.execute_attack_effect(claydol, 1, claydol_target, state)
	checks.append(assert_eq(claydol.attached_energy.size(), 0, "CSV10C_088 second attack should discard all attached Energy"))
	checks.append(assert_eq(state.players[0].discard_pile.size(), 2, "CSV10C_088 should put both discarded Energy in the discard pile"))

	var chingling := _make_slot(_load_card("089"), 0)
	var hidden_a := _trainer_instance("Hidden Item", "Item", 1)
	var hidden_b := _trainer_instance("Hidden Supporter", "Supporter", 1)
	state.players[1].hand = [hidden_a, hidden_b]
	var hidden_effects := processor.get_attack_effects_for_slot(chingling, 0)
	checks.append(assert_false(hidden_effects.is_empty(), "CSV10C_089 hidden hand discard should register"))
	if not hidden_effects.is_empty():
		var steps: Array[Dictionary] = hidden_effects[0].call("get_attack_interaction_steps", chingling.get_top_card(), _load_card("089").attacks[0], state)
		checks.append(assert_eq(steps[0].get("labels", []) if not steps.is_empty() else [], ["Opponent hand card 1", "Opponent hand card 2"], "CSV10C_089 must not reveal the opponent's hand identities"))
	processor.execute_attack_effect(chingling, 0, claydol_target, state, [{"opponent_hidden_hand_discard": [hidden_b]}])
	checks.append(assert_true(hidden_b in state.players[1].discard_pile and hidden_b not in state.players[1].hand, "CSV10C_089 should discard the selected hidden hand card"))

	var sigilyph := _make_slot(_load_card("090"), 0)
	state.players[0].prizes = [_trainer_instance("Last Prize", "Item", 0)]
	processor.execute_attack_effect(sigilyph, 1, claydol_target, state)
	checks.append(assert_eq(state.winner_index, 0, "CSV10C_090 should immediately win when its owner has exactly one Prize remaining"))
	checks.append(assert_eq(state.win_reason, "victory_symbol", "CSV10C_090 should record its dedicated alternate-win reason"))
	return run_checks(checks)


func test_csv10c_091_095_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_091_095)
	var state := _make_state()
	var processor := EffectProcessor.new()
	for index: String in ["091", "092", "093", "094", "095"]:
		processor.register_pokemon_card(_load_card(index))

	var steven_defender := _make_slot(_pokemon("Steven's Metagross", "M"), 0)
	var carbink_a := _make_slot(_load_card("091"), 0)
	var carbink_b := _make_slot(_load_card("091"), 0)
	state.players[0].active_pokemon = steven_defender
	state.players[0].bench = [carbink_a, carbink_b]
	checks.append(assert_eq(processor.get_defender_modifier(steven_defender, state, state.players[1].active_pokemon), -30, "CSV10C_091 should reduce damage to Steven's Pokemon by 30 and must not stack"))
	state.players[0].active_pokemon = carbink_a
	state.players[0].bench = [steven_defender, carbink_b]
	checks.append(assert_eq(processor.get_defender_modifier(steven_defender, state, state.players[1].active_pokemon), -30, "CSV10C_091 should work only from a Carbink on the Bench"))

	var cutiefly := _make_slot(_load_card("092"), 0)
	cutiefly.damage_counters = 30
	processor.execute_attack_effect(cutiefly, 0, state.players[1].active_pokemon, state)
	checks.append(assert_eq(cutiefly.damage_counters, 20, "CSV10C_092 should heal itself for 10 HP"))

	var ribombee := _make_slot(_load_card("093"), 0)
	state.players[0].active_pokemon = ribombee
	CSV9CHelpers.mark_evolved_from_hand(ribombee, state)
	var opponent_basic_a := CardInstance.create(_pokemon("Opponent Basic A", "G"), 1)
	var opponent_basic_b := CardInstance.create(_pokemon("Opponent Basic B", "R"), 1)
	var opponent_trainer := _trainer_instance("Opponent Trainer", "Item", 1)
	state.players[1].hand = [opponent_basic_a, opponent_trainer, opponent_basic_b]
	state.players[1].bench.clear()
	var wink := processor.get_effect(_load_card("093").effect_id)
	checks.append(assert_not_null(wink, "CSV10C_093 evolution Ability should register"))
	if wink != null:
		var reveal_steps: Array[Dictionary] = wink.call("get_interaction_steps", ribombee.get_top_card(), state)
		checks.append(assert_eq(reveal_steps[0].get("visible_scope", "") if not reveal_steps.is_empty() else "", "opponent_hand_revealed", "CSV10C_093 should reveal the opponent's hand to its owner"))
		var basic_steps: Array[Dictionary] = wink.call("get_followup_interaction_steps", ribombee.get_top_card(), state, {"opponent_hand_preview": []})
		checks.append(assert_eq(basic_steps[0].get("items", []).size() if not basic_steps.is_empty() else 0, 2, "CSV10C_093 follow-up selection should offer only Basic Pokemon, not other revealed cards"))
		wink.call("execute_ability", ribombee, 0, [{"opponent_basic_to_bench": [opponent_basic_a, opponent_basic_b]}], state)
		checks.append(assert_eq(state.players[1].bench.size(), 2, "CSV10C_093 should put any chosen Basic Pokemon from the opponent's hand onto their Bench"))
		checks.append(assert_true(opponent_trainer in state.players[1].hand, "CSV10C_093 must leave non-Pokemon cards in the opponent's hand"))
		checks.append(assert_false(bool(wink.call("can_use_ability", ribombee, state)), "CSV10C_093 should be usable only once for that evolution"))
		var declined_ribombee := _make_slot(_load_card("093"), 0)
		state.players[0].active_pokemon = declined_ribombee
		CSV9CHelpers.mark_evolved_from_hand(declined_ribombee, state)
		state.players[1].hand = [CardInstance.create(_pokemon("Declined Basic", "G"), 1)]
		state.players[1].bench.clear()
		wink.call("execute_ability", declined_ribombee, 0, [{"opponent_basic_to_bench": []}], state)
		checks.append(assert_false(bool(wink.call("can_use_ability", declined_ribombee, state)), "CSV10C_093 should consume its evolution trigger even when the player chooses zero Basic Pokemon"))

	var comfey := _make_slot(_load_card("094"), 0)
	state.players[0].active_pokemon = comfey
	state.players[0].bench.clear()
	var lillie_a := CardInstance.create(_pokemon("Lillie's Clefairy", "P"), 0)
	var lillie_b := CardInstance.create(_pokemon("Lillie's Ribombee", "P"), 0)
	var unrelated := CardInstance.create(_pokemon("Ordinary Basic", "P"), 0)
	state.players[0].deck = [unrelated, lillie_a, lillie_b]
	var flower_effects := processor.get_attack_effects_for_slot(comfey, 0)
	checks.append(assert_false(flower_effects.is_empty(), "CSV10C_094 招花 should register"))
	if not flower_effects.is_empty():
		var flower_steps: Array[Dictionary] = flower_effects[0].call("get_attack_interaction_steps", comfey.get_top_card(), _load_card("094").attacks[0], state)
		checks.append(assert_true(unrelated in flower_steps[0].get("card_items", []) if not flower_steps.is_empty() else false, "CSV10C_094 should show the full deck while disabling unrelated cards"))
	processor.execute_attack_effect(comfey, 0, state.players[1].active_pokemon, state, [{"search_basic_lillie_to_bench": [lillie_a, lillie_b]}])
	checks.append(assert_eq(state.players[0].bench.size(), 2, "CSV10C_094 should fill available Bench spaces with chosen Basic Lillie's Pokemon"))
	checks.append(assert_true(unrelated in state.players[0].deck, "CSV10C_094 must not Bench an unrelated Basic Pokemon"))
	var comfey_energy := _energy_instance("Comfey Energy", "P", 0)
	var comfey_tool := _trainer_instance("Comfey Tool", "Tool", 0)
	comfey.attached_energy = [comfey_energy]
	comfey.attached_tool = comfey_tool
	var replacement := state.players[0].bench[0] if not state.players[0].bench.is_empty() else _make_slot(_pokemon("Fallback Replacement", "C"), 0)
	if replacement not in state.players[0].bench:
		state.players[0].bench.append(replacement)
	processor.execute_attack_effect(comfey, 1, state.players[1].active_pokemon, state, [{"return_self_replacement": [replacement]}])
	checks.append(assert_true(comfey.get_top_card() == null, "CSV10C_094 should remove itself from the Active Spot"))
	checks.append(assert_true(comfey_energy in state.players[0].hand and comfey_tool in state.players[0].hand, "CSV10C_094 should return all attached cards to hand"))

	var mimikyu := _make_slot(_load_card("095"), 0)
	var tera_data := _pokemon("Opponent Tera Pokemon", "R", "ex")
	tera_data.ancient_trait = "Tera"
	tera_data.attacks = [{"name": "Tera Strike", "cost": "R", "damage": "70", "text": "", "is_vstar_power": false}]
	var tera_target := _make_slot(tera_data, 1)
	state.players[1].active_pokemon = tera_target
	var copy_effects := processor.get_attack_effects_for_slot(mimikyu, 0)
	checks.append(assert_false(copy_effects.is_empty(), "CSV10C_095 Tera attack copy should register"))
	if not copy_effects.is_empty():
		var copy_steps: Array[Dictionary] = copy_effects[0].call("get_attack_interaction_steps", mimikyu.get_top_card(), _load_card("095").attacks[0], state)
		checks.append(assert_eq(copy_steps.size(), 1, "CSV10C_095 should offer attacks when the opposing Active Pokemon is Tera"))
		var copied_option: Dictionary = copy_steps[0].get("items", [])[0] if not copy_steps.is_empty() else {}
		copy_effects[0].set_attack_interaction_context([{"copied_attack": [copied_option]}])
		checks.append(assert_eq(int(copy_effects[0].call("get_damage_bonus", mimikyu, state)), 70, "CSV10C_095 should use the copied attack's printed damage"))
		copy_effects[0].clear_attack_interaction_context()
	state.players[1].active_pokemon = _make_slot(_pokemon("Opponent Non-Tera", "R", "ex"), 1)
	if not copy_effects.is_empty():
		checks.append(assert_true(copy_effects[0].call("get_attack_interaction_steps", mimikyu.get_top_card(), _load_card("095").attacks[0], state).is_empty(), "CSV10C_095 must not copy attacks from a non-Tera Pokemon"))
	return run_checks(checks)


func test_csv10c_096_100_bundle_and_semantics() -> String:
	var checks := _bundle_checks(BATCH_096_100)
	var state := _make_state()
	var processor := EffectProcessor.new()
	processor.coin_flipper = AlwaysTails.new()
	for index: String in ["096", "097", "098", "099", "100"]:
		processor.register_pokemon_card(_load_card(index))

	var dottler := _make_slot(_load_card("096"), 0)
	var opponent_deck: Array[CardInstance] = []
	for i: int in 7:
		opponent_deck.append(_trainer_instance("Opponent Deck %d" % i, "Item", 1))
	state.players[1].deck = opponent_deck.duplicate()
	var reordered := [opponent_deck[4], opponent_deck[2], opponent_deck[0], opponent_deck[3], opponent_deck[1]]
	processor.execute_attack_effect(dottler, 0, state.players[1].active_pokemon, state, [{"opponent_top5_order": reordered}])
	checks.append(assert_eq(state.players[1].deck.slice(0, 5), reordered, "CSV10C_096 should put the chosen order back on top of the opponent's deck"))
	checks.append(assert_eq(state.players[1].deck.slice(5), opponent_deck.slice(5), "CSV10C_096 must not disturb cards below the looked-at top five"))

	var orbeetle := _make_slot(_load_card("097"), 0)
	state.players[0].active_pokemon = orbeetle
	var damaged_rocket := _make_slot(_pokemon("Team Rocket's Damaged Pokemon", "P"), 0)
	var ordinary_target := _make_slot(_pokemon("Ordinary Target", "P"), 0)
	damaged_rocket.damage_counters = 30
	state.players[0].bench = [damaged_rocket, ordinary_target]
	var rocket_brain := processor.get_effect(_load_card("097").effect_id)
	checks.append(assert_not_null(rocket_brain, "CSV10C_097 Rocket Brain should register"))
	if rocket_brain != null:
		rocket_brain.call("execute_ability", orbeetle, 0, [{"rocket_damage_source": [damaged_rocket], "rocket_damage_target": [ordinary_target]}], state)
		rocket_brain.call("execute_ability", orbeetle, 0, [{"rocket_damage_source": [damaged_rocket], "rocket_damage_target": [ordinary_target]}], state)
		checks.append(assert_eq(damaged_rocket.damage_counters, 10, "CSV10C_097 should move exactly one damage counter per use"))
		checks.append(assert_eq(ordinary_target.damage_counters, 20, "CSV10C_097 should remain usable multiple times in the same turn"))
		checks.append(assert_true(bool(rocket_brain.call("can_use_ability", orbeetle, state)), "CSV10C_097 should not acquire a once-per-turn flag"))
	var psychic_bonus := processor.get_attack_effects_for_slot(orbeetle, 0)
	state.players[1].active_pokemon.attached_energy = [_energy_instance("Opp Energy A", "P", 1), _energy_instance("Opp Energy B", "C", 1)]
	checks.append(assert_false(psychic_bonus.is_empty(), "CSV10C_097 Psychic should register its Energy-count bonus"))
	if not psychic_bonus.is_empty():
		checks.append(assert_eq(int(psychic_bonus[0].call("get_damage_bonus", orbeetle, state)), 80, "CSV10C_097 should add 40 per Energy attached to the opposing Active Pokemon"))

	var mankey := _make_slot(_load_card("098"), 0)
	var mankey_target := state.players[1].active_pokemon
	checks.append(assert_true(processor.attack_damage_cancelled(mankey, 0, mankey_target, state), "CSV10C_098 tails should make the attack fail"))

	var primeape := _make_slot(_load_card("099"), 0)
	var old_active := _make_slot(_pokemon("Old Active", "C"), 1)
	var pulled_target := _make_slot(_pokemon("Pulled Target", "C"), 1)
	state.players[1].active_pokemon = old_active
	state.players[1].bench = [pulled_target]
	processor.execute_attack_effect(primeape, 0, old_active, state, [{"force_out_target": [pulled_target]}])
	checks.append(assert_eq(state.players[1].active_pokemon, pulled_target, "CSV10C_099 should switch the chosen opposing Benched Pokemon into the Active Spot"))
	checks.append(assert_eq(pulled_target.damage_counters, 30, "CSV10C_099 should then deal 30 damage to the newly Active Pokemon"))
	checks.append(assert_eq(state.players[1].bench[0], old_active, "CSV10C_099 should move the former Active Pokemon to the Bench"))
	var protected_active := _make_slot(_pokemon("Mist-Protected Active", "C"), 1)
	var protected_bench := _make_slot(_pokemon("Protected Bench Target", "C"), 1)
	var force_out_mist := _special_energy_instance("Mist Energy", 1)
	force_out_mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
	protected_active.attached_energy = [force_out_mist]
	state.players[1].active_pokemon = protected_active
	state.players[1].bench = [protected_bench]
	processor.execute_attack_effect(primeape, 0, protected_active, state, [{"force_out_target": [protected_bench]}])
	checks.append(assert_eq(state.players[1].active_pokemon, protected_active, "CSV10C_099 should not switch a Mist Energy-protected Active Pokemon"))
	checks.append(assert_eq(protected_bench.damage_counters, 0, "CSV10C_099 should not deal follow-up damage when the forced switch is prevented"))

	var annihilape := _make_slot(_load_card("100"), 0)
	state.players[0].active_pokemon = annihilape
	annihilape.damage_counters = 10
	checks.append(assert_eq(processor.get_attacker_modifier(annihilape, state, state.players[1].active_pokemon), 0, "CSV10C_100 should not gain damage with only one damage counter"))
	annihilape.damage_counters = 20
	checks.append(assert_eq(processor.get_attacker_modifier(annihilape, state, state.players[1].active_pokemon), 120, "CSV10C_100 should gain 120 damage with at least two damage counters"))
	processor.execute_attack_effect(annihilape, 0, state.players[1].active_pokemon, state)
	checks.append(assert_true(annihilape.effects.any(func(entry: Dictionary) -> bool: return entry.get("type", "") == "attack_lock" and int(entry.get("attack_index", -1)) == 0), "CSV10C_100 should lock Impact Punch during its next turn"))
	return run_checks(checks)


func _bundle_checks(uids: Array) -> Array[String]:
	var checks: Array[String] = []
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	for uid_raw: Variant in uids:
		var uid := str(uid_raw)
		var index := uid.get_slice("_", 1)
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/CSV10C/%s.png.bin" % index
		var card := _load_card(index)
		checks.append(assert_not_null(card, "%s should load" % uid))
		checks.append(assert_true(card_path in manifest, "%s JSON should be manifested" % uid))
		checks.append(assert_true(image_path in manifest, "%s image should be manifested" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s image should be valid" % uid))
	return checks


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "C"), pi)
		player.bench = [_make_slot(_pokemon("Bench %d" % pi, "C"), pi)]
		state.players.append(player)
	return state


func _pokemon(name: String, energy_type: String, mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = energy_type
	card.hp = 100
	card.mechanic = mechanic
	card.attacks = [{"name": "Strike", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return card


func _trainer_instance(name: String, card_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	return CardInstance.create(card, owner)


func _energy_instance(name: String, energy_type: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner)


func _special_energy_instance(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Special Energy"
	return CardInstance.create(card, owner)


func _make_slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
