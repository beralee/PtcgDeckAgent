class_name TestTCGMikTinkatonSinistcha
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AbilityBenchImmuneScript := preload("res://scripts/effects/pokemon_effects/AbilityBenchImmune.gd")
const AttackCoinFlipApplyStatusScript := preload("res://scripts/effects/pokemon_effects/AttackCoinFlipApplyStatus.gd")

const MATERIAL_GATHERING_STEP_ID := "tinkaton_material_gathering_discard"
const SEEKING_MOUNTAIN_STEP_ID := "tinkatink_seeking_mountain_choice"
const CURSE_DROPLETS_STEP_ID := "sinistcha_curse_droplets_counters"
const TEA_SPLASH_ENERGY_STEP_ID := "sinistcha_tea_splash_grass_energy"
const REBREW_TARGET_STEP_ID := "sinistcha_ex_rebrew_target"


func test_tinkaton_ex_big_hammer_uses_own_hand_count_and_pulverizing_press_ignores_defender_effects() -> String:
	var card := _load_card("CSV1C", "068")
	if card == null:
		return assert_not_null(card, "CSV1C_068 Tinkaton ex should load")
	var gsm := _make_gsm()
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Defender", 400), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(attacker, _energy("Colorless 1", "Basic Energy", "C"), 0)
	_attach_energy(attacker, _energy("Colorless 2", "Basic Energy", "C"), 0)
	for index: int in 4:
		gsm.game_state.players[0].hand.append(CardInstance.create(_item("Hand %d" % index), 0))
	gsm.effect_processor.register_pokemon_card(card)
	var first_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	var attacked := gsm.use_attack(0, 0)
	var has_ignore := false
	for effect: BaseEffect in second_effects:
		if effect.has_method("ignores_defender_effects") and bool(effect.call("ignores_defender_effects", attacker, gsm.game_state, 1)):
			has_ignore = true
	return run_checks([
		assert_false(first_effects.is_empty(), "Big Hammer should register its own-hand multiplier"),
		assert_true(has_ignore, "Pulverizing Press should ignore effects on the opposing Active Pokemon"),
		assert_true(attacked, "Big Hammer should execute with two Colorless Energy"),
		assert_eq(defender.damage_counters, 120, "Big Hammer should deal exactly 30 damage for each of 4 cards in hand"),
	])


func test_tinkaton_material_gathering_requires_a_chosen_discard_and_draws_three_once_per_turn() -> String:
	var card := _load_card("CSV1C", "067")
	if card == null:
		return assert_not_null(card, "CSV1C_067 Tinkaton should load")
	var gsm := _make_gsm()
	var tinkaton := _slot(card, 0)
	gsm.game_state.players[0].active_pokemon = tinkaton
	gsm.game_state.players[1].active_pokemon = _slot(_pokemon("Defender"), 1)
	var discarded := CardInstance.create(_item("Chosen discard"), 0)
	gsm.game_state.players[0].hand.append(discarded)
	var draws := [
		CardInstance.create(_item("Draw 1"), 0),
		CardInstance.create(_item("Draw 2"), 0),
		CardInstance.create(_item("Draw 3"), 0),
		CardInstance.create(_item("Remainder"), 0),
	]
	gsm.game_state.players[0].deck.append_array(draws)
	gsm.effect_processor.register_pokemon_card(card)
	var effect := gsm.effect_processor.get_ability_effect(tinkaton, 0, gsm.game_state)
	var steps: Array = effect.get_interaction_steps(tinkaton.get_top_card(), gsm.game_state) if effect != null else []
	var missing_used := gsm.use_ability(0, tinkaton, 0, [])
	var used := gsm.use_ability(0, tinkaton, 0, [{MATERIAL_GATHERING_STEP_ID: [discarded]}])
	return run_checks([
		assert_not_null(effect, "Material Gathering should register by source effect_id"),
		assert_eq(steps.size(), 1, "Material Gathering should expose one hand-discard choice"),
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 1, "Material Gathering should require exactly one card"),
		assert_false(missing_used, "Material Gathering should reject a missing player choice instead of auto-discarding"),
		assert_true(used, "Material Gathering should resolve with a legal discard"),
		assert_true(discarded in gsm.game_state.players[0].discard_pile, "The chosen hand card should enter the discard pile"),
		assert_eq(gsm.game_state.players[0].hand, draws.slice(0, 3), "Material Gathering should draw the top 3 cards"),
		assert_false(gsm.effect_processor.can_use_ability(tinkaton, gsm.game_state, 0), "Material Gathering should be limited to once per turn"),
	])


func test_tinkaton_and_tinkatuff_conditional_damage_is_binary_not_per_energy() -> String:
	var tinkaton_card := _load_card("CSV1C", "067")
	var tinkatuff_card := _load_card("CSV6C", "063")
	if tinkaton_card == null or tinkatuff_card == null:
		return "Requested Tinkaton evolution cards should load"
	var special_gsm := _make_gsm()
	var tinkaton := _slot(tinkaton_card, 0)
	var special_defender := _slot(_pokemon("Special defender", 400), 1)
	special_gsm.game_state.players[0].active_pokemon = tinkaton
	special_gsm.game_state.players[1].active_pokemon = special_defender
	_attach_energy(tinkaton, _energy("Psychic", "Basic Energy", "P"), 0)
	_attach_energy(tinkaton, _energy("Special 1", "Special Energy", "C"), 0)
	_attach_energy(tinkaton, _energy("Special 2", "Special Energy", "C"), 0)
	special_gsm.effect_processor.register_pokemon_card(tinkaton_card)
	var special_attacked := special_gsm.use_attack(0, 0)

	var metal_gsm := _make_gsm()
	var tinkatuff := _slot(tinkatuff_card, 0)
	var metal_defender := _slot(_pokemon("Metal defender", 300), 1)
	metal_gsm.game_state.players[0].active_pokemon = tinkatuff
	metal_gsm.game_state.players[1].active_pokemon = metal_defender
	_attach_energy(tinkatuff, _energy("Psychic", "Basic Energy", "P"), 0)
	_attach_energy(tinkatuff, _energy("Metal special 1", "Special Energy", "M"), 0)
	_attach_energy(tinkatuff, _energy("Metal special 2", "Special Energy", "M"), 0)
	metal_gsm.effect_processor.register_pokemon_card(tinkatuff_card)
	var metal_attacked := metal_gsm.use_attack(0, 0)
	return run_checks([
		assert_true(special_attacked, "Special Hammer should execute"),
		assert_eq(special_defender.damage_counters, 180, "Special Hammer should add 90 once even with two Special Energy"),
		assert_true(metal_attacked, "Alloy Swing should execute"),
		assert_eq(metal_defender.damage_counters, 60, "Alloy Swing should add 40 once when Metal Energy is attached"),
	])


func test_tinkatink_variants_keep_distinct_coin_flip_and_seeking_mountain_effects() -> String:
	var promo := _load_card("SVP", "159")
	var seeking := _load_card("CSV6C", "062")
	if promo == null or seeking == null:
		return "Both requested Tinkatink prints should load"
	var state := _make_state()
	var processor := EffectProcessor.new()
	var promo_slot := _slot(promo, 0)
	var seeking_slot := _slot(seeking, 0)
	processor.register_pokemon_card(promo)
	processor.register_pokemon_card(seeking)
	var promo_effects := processor.get_attack_effects_for_slot(promo_slot, 0)
	var seeking_effects := processor.get_attack_effects_for_slot(seeking_slot, 0)
	state.players[0].active_pokemon = seeking_slot
	state.players[1].active_pokemon = _slot(_pokemon("Defender"), 1)
	var top_card := CardInstance.create(_item("Looked top card"), 0)
	var next_card := CardInstance.create(_item("Replacement draw"), 0)
	state.players[0].deck.append_array([top_card, next_card])
	var steps := processor.get_attack_interaction_steps_by_id(seeking.effect_id, 0, seeking_slot.get_top_card(), seeking.attacks[0], state)
	var executed := processor.execute_attack_effect(seeking_slot, 0, state.players[1].active_pokemon, state, [{SEEKING_MOUNTAIN_STEP_ID: ["discard_draw"]}])
	return run_checks([
		assert_false(promo_effects.is_empty(), "SVP_159 Flail Around should retain its coin-flip bonus"),
		assert_false(seeking_effects.is_empty(), "CSV6C_062 Seeking Mountain should register its distinct top-deck choice"),
		assert_eq(steps.size(), 1, "Seeking Mountain should expose one explicit keep-or-discard choice"),
		assert_true(executed, "Seeking Mountain should resolve with a legal choice"),
		assert_true(top_card in state.players[0].discard_pile, "Discard branch should discard the looked-at top card"),
		assert_eq(state.players[0].hand, [next_card], "Discard branch should then draw the new top card"),
	])


func test_shared_ignore_and_coin_flip_representatives_keep_their_registered_effects() -> String:
	var dundunsparce := _load_card("CSV10C", "179")
	var wattrel := _load_card("CSV10C", "080")
	if dundunsparce == null or wattrel == null:
		return "Shared-effect representative cards should load"
	var state := _make_state()
	var processor := EffectProcessor.new()
	var dundunsparce_slot := _slot(dundunsparce, 0)
	var wattrel_slot := _slot(wattrel, 0)
	processor.register_pokemon_card(dundunsparce)
	processor.register_pokemon_card(wattrel)
	var ignore_effects := processor.get_attack_effects_for_slot(dundunsparce_slot, 1)
	var coin_effects := processor.get_attack_effects_for_slot(wattrel_slot, 0)
	var has_ignore := false
	for effect: BaseEffect in ignore_effects:
		if effect.has_method("ignores_defender_effects") and bool(effect.call("ignores_defender_effects", dundunsparce_slot, state, 1)):
			has_ignore = true
	var has_coin_bonus := false
	for effect: BaseEffect in coin_effects:
		if effect.get_script() != null and str(effect.get_script().resource_path).ends_with("AttackCoinFlipBonusDamage.gd"):
			has_coin_bonus = true
	return run_checks([
		assert_true(has_ignore, "CSV10C_179 should retain its shared ignore-defender-effects behavior"),
		assert_true(has_coin_bonus, "CSV10C_080 should retain its shared coin-flip bonus behavior"),
	])


func test_cached_csv3c_096_confusion_registers_coin_flip_paralysis() -> String:
	var card := _pokemon("麒麟奇")
	card.effect_id = "8e3a8f7248c7087364b542c5e277f6cc"
	card.attacks = [
		{"name": "念力", "cost": "CC", "damage": "30", "text": "抛掷1次硬币如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。", "is_vstar_power": false},
		{"name": "甩头猛撞", "cost": "CCC", "damage": "70", "text": "", "is_vstar_power": false},
	]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var effects: Array = processor.get_attack_effects_for_slot(_slot(card, 0), 0)
	var has_coin_paralysis := false
	for effect: BaseEffect in effects:
		if is_instance_of(effect, AttackCoinFlipApplyStatusScript) and str(effect.status_name) == "paralyzed":
			has_coin_paralysis = true
	return assert_true(has_coin_paralysis, "CSV3C_096 Confusion should reuse the coin-flip paralysis effect")


func test_poltchageist_hiding_prevents_bench_attack_damage_and_effects_only_while_enabled() -> String:
	var card := _load_card("CSV9.5C", "019")
	if card == null:
		return assert_not_null(card, "CSV9.5C_019 Poltchageist should load")
	var state := _make_state()
	var attacker := _slot(_pokemon("Opponent attacker"), 1)
	var target := _slot(card, 0)
	state.players[0].bench.append(target)
	state.players[1].active_pokemon = attacker
	var damage_blocked := AbilityBenchImmuneScript.prevents_opponent_attack_damage(target, attacker, state)
	var effect_blocked := AbilityBenchImmuneScript.prevents_opponent_attack_effect(target, attacker, state)
	target.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var disabled_damage_blocked := AbilityBenchImmuneScript.prevents_opponent_attack_damage(target, attacker, state)
	state.players[0].bench.clear()
	state.players[0].active_pokemon = target
	target.effects.clear()
	var active_damage_blocked := AbilityBenchImmuneScript.prevents_opponent_attack_damage(target, attacker, state)
	return run_checks([
		assert_true(damage_blocked, "Hiding should prevent attack damage while Poltchageist is Benched"),
		assert_true(effect_blocked, "Hiding should prevent attack effects while Poltchageist is Benched"),
		assert_false(disabled_damage_blocked, "Hiding should stop working while the Ability is disabled"),
		assert_false(active_damage_blocked, "Hiding should not protect an Active Poltchageist"),
	])


func test_sinistcha_curse_droplets_requires_exactly_four_distributed_counters() -> String:
	var card := _load_card("CSVH5C", "002")
	if card == null:
		return assert_not_null(card, "CSVH5C_002 Sinistcha should load")
	var gsm := _make_gsm()
	var attacker := _slot(card, 0)
	var active_target := _slot(_pokemon("Active target", 300), 1)
	var bench_target := _slot(_pokemon("Bench target", 200), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = active_target
	gsm.game_state.players[1].bench.append(bench_target)
	_attach_energy(attacker, _energy("Grass", "Basic Energy", "G"), 0)
	gsm.effect_processor.register_pokemon_card(card)
	var steps := gsm.effect_processor.get_attack_interaction_steps_by_id(card.effect_id, 0, attacker.get_top_card(), card.attacks[0], gsm.game_state)
	var invalid := gsm.effect_processor.validate_attack_effect_context(attacker, 0, active_target, gsm.game_state, [{CURSE_DROPLETS_STEP_ID: [{"target": active_target, "amount": 30}]}])
	var attacked := gsm.use_attack(0, 0, [{CURSE_DROPLETS_STEP_ID: [
		{"target": active_target, "amount": 10},
		{"target": bench_target, "amount": 30},
	]}])
	return run_checks([
		assert_eq(steps.size(), 1, "Curse Droplets should expose one counter-distribution step"),
		assert_eq(int(steps[0].get("total_counters", 0)) if not steps.is_empty() else 0, 4, "Curse Droplets should distribute exactly 4 counters"),
		assert_false(invalid, "Curse Droplets should reject a distribution totaling only 3 counters"),
		assert_true(attacked, "Curse Droplets should execute with an exact four-counter distribution"),
		assert_eq(active_target.damage_counters, 10, "Curse Droplets should put 1 counter on the selected Active Pokemon"),
		assert_eq(bench_target.damage_counters, 30, "Curse Droplets should put 3 counters on the selected Benched Pokemon"),
	])


func test_sinistcha_tea_splash_discards_up_to_three_grass_energy_from_any_own_pokemon() -> String:
	var card := _load_card("CSVH5C", "002")
	if card == null:
		return assert_not_null(card, "CSVH5C_002 Sinistcha should load")
	var gsm := _make_gsm()
	var attacker := _slot(card, 0)
	var bench := _slot(_pokemon("Own Bench"), 0)
	var defender := _slot(_pokemon("Defender", 400), 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[0].bench.append(bench)
	gsm.game_state.players[1].active_pokemon = defender
	var grass_a := _attach_energy(attacker, _energy("Grass A", "Basic Energy", "G"), 0)
	var grass_b := _attach_energy(bench, _energy("Grass B", "Basic Energy", "G"), 0)
	var grass_special := _attach_energy(bench, _energy("Grass Special", "Special Energy", "G"), 0)
	var grass_fourth := _attach_energy(bench, _energy("Grass Fourth", "Basic Energy", "G"), 0)
	var metal := _attach_energy(bench, _energy("Metal", "Basic Energy", "M"), 0)
	gsm.effect_processor.register_pokemon_card(card)
	var steps := gsm.effect_processor.get_attack_interaction_steps_by_id(card.effect_id, 1, attacker.get_top_card(), card.attacks[1], gsm.game_state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = step.get("items", [])
	var too_many_valid := gsm.effect_processor.validate_attack_effect_context(attacker, 1, defender, gsm.game_state, [{TEA_SPLASH_ENERGY_STEP_ID: [grass_a, grass_b, grass_special, grass_fourth]}])
	var attacked := gsm.use_attack(0, 1, [{TEA_SPLASH_ENERGY_STEP_ID: [grass_a, grass_b, grass_special]}])

	var zero_gsm := _make_gsm()
	var zero_attacker := _slot(card, 0)
	var zero_defender := _slot(_pokemon("Zero defender", 300), 1)
	zero_gsm.game_state.players[0].active_pokemon = zero_attacker
	zero_gsm.game_state.players[1].active_pokemon = zero_defender
	var kept_grass := _attach_energy(zero_attacker, _energy("Kept Grass", "Basic Energy", "G"), 0)
	zero_gsm.effect_processor.register_pokemon_card(card)
	var zero_attacked := zero_gsm.use_attack(0, 1, [{TEA_SPLASH_ENERGY_STEP_ID: []}])
	return run_checks([
		assert_eq(int(step.get("max_select", 0)), 3, "Tea Splash should cap the discard at 3 Energy"),
		assert_true(grass_a in items and grass_b in items and grass_special in items, "Tea Splash should expose Grass Energy across the whole field, including Special Energy"),
		assert_false(metal in items, "Tea Splash should not expose off-type Energy"),
		assert_false(too_many_valid, "Tea Splash should reject selecting more than 3 Energy"),
		assert_true(attacked, "Tea Splash should execute with a legal three-Energy choice"),
		assert_eq(defender.damage_counters, 210, "Tea Splash should deal 70 damage per discarded Grass Energy"),
		assert_true(grass_a in gsm.game_state.players[0].discard_pile and grass_b in gsm.game_state.players[0].discard_pile and grass_special in gsm.game_state.players[0].discard_pile, "All three chosen Grass Energy should enter the discard pile"),
		assert_true(grass_fourth in bench.attached_energy and metal in bench.attached_energy, "Unselected and off-type Energy should remain attached"),
		assert_true(zero_attacked, "Tea Splash should allow explicitly choosing zero Energy"),
		assert_eq(zero_defender.damage_counters, 0, "Tea Splash should deal zero damage when no Energy is discarded"),
		assert_true(kept_grass in zero_attacker.attached_energy, "Choosing zero should keep all Grass Energy attached"),
	])


func test_sinistcha_ex_rebrew_uses_all_basic_grass_energy_and_matcha_splash_heals_every_own_pokemon() -> String:
	var card := _load_card("CSVNC", "008")
	if card == null:
		return assert_not_null(card, "CSVNC_008 Sinistcha ex should load")
	var rebrew_gsm := _make_gsm()
	var rebrew_attacker := _slot(card, 0)
	var active_target := _slot(_pokemon("Active target", 300), 1)
	var bench_target := _slot(_pokemon("Bench target", 200), 1)
	rebrew_gsm.game_state.players[0].active_pokemon = rebrew_attacker
	rebrew_gsm.game_state.players[1].active_pokemon = active_target
	rebrew_gsm.game_state.players[1].bench.append(bench_target)
	_attach_energy(rebrew_attacker, _energy("Colorless", "Basic Energy", "C"), 0)
	var grass_a := CardInstance.create(_energy("Discard Grass A", "Basic Energy", "G"), 0)
	var grass_b := CardInstance.create(_energy("Discard Grass B", "Basic Energy", "G"), 0)
	var special_grass := CardInstance.create(_energy("Discard Special Grass", "Special Energy", "G"), 0)
	var psychic := CardInstance.create(_energy("Discard Psychic", "Basic Energy", "P"), 0)
	rebrew_gsm.game_state.players[0].discard_pile.append_array([grass_a, special_grass, grass_b, psychic])
	rebrew_gsm.effect_processor.register_pokemon_card(card)
	var rebrew_steps := rebrew_gsm.effect_processor.get_attack_interaction_steps_by_id(card.effect_id, 0, rebrew_attacker.get_top_card(), card.attacks[0], rebrew_gsm.game_state)
	var rebrewed := rebrew_gsm.use_attack(0, 0, [{REBREW_TARGET_STEP_ID: [bench_target]}])

	var heal_gsm := _make_gsm()
	var heal_attacker := _slot(card, 0)
	var own_bench := _slot(_pokemon("Damaged Bench"), 0)
	var heal_defender := _slot(_pokemon("Heal defender", 400), 1)
	heal_attacker.damage_counters = 50
	own_bench.damage_counters = 40
	heal_gsm.game_state.players[0].active_pokemon = heal_attacker
	heal_gsm.game_state.players[0].bench.append(own_bench)
	heal_gsm.game_state.players[1].active_pokemon = heal_defender
	_attach_energy(heal_attacker, _energy("Grass", "Basic Energy", "G"), 0)
	_attach_energy(heal_attacker, _energy("Colorless", "Basic Energy", "C"), 0)
	heal_gsm.effect_processor.register_pokemon_card(card)
	var splashed := heal_gsm.use_attack(0, 1)
	return run_checks([
		assert_eq(rebrew_steps.size(), 1, "Rebrew should require one opponent Pokemon target when Basic Grass Energy is in the discard pile"),
		assert_true(rebrewed, "Rebrew should execute with a legal target"),
		assert_eq(bench_target.damage_counters, 40, "Rebrew should place 2 counters per each of 2 Basic Grass Energy"),
		assert_true(grass_a in rebrew_gsm.game_state.players[0].deck and grass_b in rebrew_gsm.game_state.players[0].deck, "Rebrew should shuffle every revealed Basic Grass Energy into the deck"),
		assert_true(special_grass in rebrew_gsm.game_state.players[0].discard_pile and psychic in rebrew_gsm.game_state.players[0].discard_pile, "Rebrew should leave Special and off-type Energy in the discard pile"),
		assert_true(splashed, "Matcha Splash should execute"),
		assert_eq(heal_attacker.damage_counters, 20, "Matcha Splash should heal 30 from the attacking Pokemon"),
		assert_eq(own_bench.damage_counters, 10, "Matcha Splash should heal 30 from every Benched Pokemon"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card(set_code, card_index)
	db.free()
	return card


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card_data != null:
		slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, hp: int = 100) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _item(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	return card


func _energy(name: String, card_type: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	card.energy_type = provides
	card.energy_provides = provides
	return card


func _attach_energy(slot: PokemonSlot, data: CardData, owner_index: int) -> CardInstance:
	var energy := CardInstance.create(data, owner_index)
	slot.attached_energy.append(energy)
	return energy
