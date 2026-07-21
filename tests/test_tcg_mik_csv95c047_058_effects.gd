class_name TestTcgMikCsv95c047058Effects
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AbilityBenchImmuneScript := preload("res://scripts/effects/pokemon_effects/AbilityBenchImmune.gd")

const GLACEON_EFFECT_ID := "4221c41ba964470cc5e7394886cd7716"
const JOLTEON_EFFECT_ID := "ea603744a76e329006742da58c0f7514"
const FARIGIRAF_EFFECT_ID := "fd252ce877c709e9e3161c56ef98aff8"

const BENCH_DAMAGE_STEP_ID := "bench_target"
const EXACT_COUNTER_KO_STEP_ID := "opponent_exact_damage_counter_ko_target"
const BENCH_ENERGY_DISCARD_STEP_ID := "discard_own_bench_basic_energy"

const BENCH_DAMAGE_SCRIPT_PATH := "res://scripts/effects/pokemon_effects/AttackTargetOpponentBenchDamage.gd"
const EXACT_COUNTER_KO_SCRIPT_PATH := "res://scripts/effects/pokemon_effects/AttackKnockOutOpponentWithExactDamageCounters.gd"
const BENCH_ENERGY_DISCARD_SCRIPT_PATH := "res://scripts/effects/pokemon_effects/AttackDiscardOwnBenchBasicEnergyBonusDamage.gd"
const ALL_ATTACKS_LOCK_SCRIPT_PATH := "res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd"


func test_csv95c_047_and_058_are_bundled_with_exact_source_data_and_registered_effects() -> String:
	CardImplementationStatus.clear_cache()
	var db := CardDatabaseScript.new()
	var manifest := db._load_bundled_manifest()
	var specs := [
		{
			"set": "CSV9.5C", "index": "047", "name": "冰伊布ex", "name_en": "Glaceon ex",
			"effect_id": GLACEON_EFFECT_ID, "hp": 270, "energy": "W", "weakness": "M",
			"retreat": 1, "attack_names": ["冰霜子弹", "蓝柱石"], "attack_costs": ["WC", "GWD"],
			"attack_damage": ["110", ""],
		},
		{
			"set": "CSV9.5C", "index": "058", "name": "雷伊布ex", "name_en": "Jolteon ex",
			"effect_id": JOLTEON_EFFECT_ID, "hp": 260, "energy": "L", "weakness": "F",
			"retreat": 0, "attack_names": ["闪光长矛", "镁电气石"], "attack_costs": ["LC", "RWL"],
			"attack_damage": ["60+", "280"],
		},
	]
	var checks: Array[String] = []
	var processor := EffectProcessor.new()
	for spec: Dictionary in specs:
		var set_code := str(spec.get("set", ""))
		var card_index := str(spec.get("index", ""))
		var card_id := "%s_%s" % [set_code, card_index]
		var card_path := "res://data/bundled_user/cards/%s.json" % card_id
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_true(card_path in manifest, "%s JSON should be listed in the bundled manifest" % card_id))
		checks.append(assert_true(image_path in manifest, "%s image should be listed in the bundled manifest" % card_id))
		checks.append(assert_true(FileAccess.file_exists(card_path), "%s bundled JSON should exist" % card_id))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be a valid card image" % card_id))
		checks.append(assert_not_null(card, "%s should load from CardDatabase" % card_id))
		if card == null:
			continue
		checks.append(assert_eq(card.name, str(spec.get("name", "")), "%s should preserve the Chinese source name" % card_id))
		checks.append(assert_eq(card.name_en, str(spec.get("name_en", "")), "%s should preserve the English source name" % card_id))
		checks.append(assert_eq(card.effect_id, str(spec.get("effect_id", "")), "%s should preserve the source effect_id" % card_id))
		checks.append(assert_eq(card.stage, "Stage 1", "%s should be a Stage 1 Pokemon" % card_id))
		checks.append(assert_eq(card.evolves_from, "伊布", "%s should evolve from Eevee" % card_id))
		checks.append(assert_eq(card.mechanic, "ex", "%s should keep the ex mechanic" % card_id))
		checks.append(assert_eq(card.ancient_trait, "Tera", "%s should keep the Tera rule box" % card_id))
		checks.append(assert_eq(card.hp, int(spec.get("hp", 0)), "%s should preserve HP" % card_id))
		checks.append(assert_eq(card.energy_type, str(spec.get("energy", "")), "%s should preserve its type" % card_id))
		checks.append(assert_eq(card.weakness_energy, str(spec.get("weakness", "")), "%s should preserve weakness" % card_id))
		checks.append(assert_eq(card.retreat_cost, int(spec.get("retreat", -1)), "%s should preserve retreat cost" % card_id))
		checks.append(assert_eq(card.attacks.size(), 2, "%s should have exactly two attacks" % card_id))
		if card.attacks.size() == 2:
			checks.append(assert_eq(str(card.attacks[0].get("name", "")), spec.get("attack_names", [])[0], "%s first attack name should match source" % card_id))
			checks.append(assert_eq(str(card.attacks[1].get("name", "")), spec.get("attack_names", [])[1], "%s second attack name should match source" % card_id))
			checks.append(assert_eq(str(card.attacks[0].get("cost", "")), spec.get("attack_costs", [])[0], "%s first attack cost should match source" % card_id))
			checks.append(assert_eq(str(card.attacks[1].get("cost", "")), spec.get("attack_costs", [])[1], "%s second attack cost should match source" % card_id))
			checks.append(assert_eq(str(card.attacks[0].get("damage", "")), spec.get("attack_damage", [])[0], "%s first attack damage should match source" % card_id))
			checks.append(assert_eq(str(card.attacks[1].get("damage", "")), spec.get("attack_damage", [])[1], "%s second attack damage should match source" % card_id))
		processor.register_pokemon_card(card)
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "%s should not be marked unimplemented" % card_id))

	var glaceon := db.get_card("CSV9.5C", "047")
	var jolteon := db.get_card("CSV9.5C", "058")
	checks.append(assert_true(_has_effect_script(processor.get_attack_effects_for_slot(_slot(glaceon, 0), 0), BENCH_DAMAGE_SCRIPT_PATH), "Glaceon Frost Bullet should register targeted Bench damage"))
	checks.append(assert_true(_has_effect_script(processor.get_attack_effects_for_slot(_slot(glaceon, 0), 1), EXACT_COUNTER_KO_SCRIPT_PATH), "Glaceon Euclase should register exact-six-counter Knock Out"))
	checks.append(assert_true(_has_effect_script(processor.get_attack_effects_for_slot(_slot(jolteon, 0), 0), BENCH_ENERGY_DISCARD_SCRIPT_PATH), "Jolteon Flash Spear should register optional Bench Basic Energy discard damage"))
	checks.append(assert_true(_has_effect_script(processor.get_attack_effects_for_slot(_slot(jolteon, 0), 1), ALL_ATTACKS_LOCK_SCRIPT_PATH), "Jolteon Dravite should register the whole-Pokemon next-turn attack lock"))
	db.free()
	return run_checks(checks)


func test_glaceon_frost_bullet_requires_a_bench_target_and_deals_raw_30_damage() -> String:
	var card := _load_card("CSV9.5C", "047")
	if card == null:
		return assert_not_null(card, "CSV9.5C_047 Glaceon ex should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Opponent Active", "C", 400), 1)
	var selected_bench := _slot(_pokemon("Selected Bench", "M", 100), 1)
	var other_bench := _slot(_pokemon("Other Bench", "C", 100), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	opponent.bench.append_array([selected_bench, other_bench])
	_attach_basic_energy(attacker, 0, "W")
	_attach_basic_energy(attacker, 0, "C")
	gsm.effect_processor.register_pokemon_card(card)
	var steps := gsm.effect_processor.get_attack_interaction_steps_by_id(card.effect_id, 0, attacker.get_top_card(), card.attacks[0], gsm.game_state)
	var step: Dictionary = _find_step(steps, BENCH_DAMAGE_STEP_ID)
	var attacked := gsm.use_attack(0, 0, [{BENCH_DAMAGE_STEP_ID: [selected_bench]}])
	var checks: Array[String] = [
		assert_eq(steps.size(), 1, "Frost Bullet should expose one target-selection step when the opponent has a Bench"),
		assert_eq(step.get("items", []), [selected_bench, other_bench], "Frost Bullet should expose every opposing Benched Pokemon"),
		assert_eq(int(step.get("min_select", 0)), 1, "Frost Bullet should require one Bench target"),
		assert_eq(int(step.get("max_select", 0)), 1, "Frost Bullet should allow exactly one Bench target"),
		assert_false(bool(step.get("allow_cancel", true)), "Frost Bullet target selection should not be cancellable"),
		assert_true(attacked, "Frost Bullet should execute with Water and Colorless Energy"),
		assert_eq(defender.damage_counters, 110, "Frost Bullet should deal its printed 110 damage to the Active Pokemon"),
		assert_eq(selected_bench.damage_counters, 30, "Frost Bullet should deal exactly 30 raw damage to the selected Bench target"),
		assert_eq(other_bench.damage_counters, 0, "Frost Bullet should not damage unselected Bench targets"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_shared_bench_damage_alias_remains_mandatory_for_farigiraf_ex() -> String:
	var farigiraf := _load_card("CSV7C", "141")
	if farigiraf == null:
		return assert_not_null(farigiraf, "CSV7C_141 Farigiraf ex should load as the shared-effect representative")
	var state := _make_state()
	var attacker := _slot(farigiraf, 0)
	var target := _slot(_pokemon("Opponent Bench", "C", 100), 1)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = _slot(_pokemon("Opponent Active", "C", 300), 1)
	state.players[1].bench.append(target)
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(farigiraf)
	var steps := processor.get_attack_interaction_steps_by_id(FARIGIRAF_EFFECT_ID, 0, attacker.get_top_card(), farigiraf.attacks[0], state)
	var step: Dictionary = _find_step(steps, BENCH_DAMAGE_STEP_ID)
	return run_checks([
		assert_eq(steps.size(), 1, "Farigiraf ex should retain its shared Bench-damage interaction"),
		assert_eq(step.get("items", []), [target], "Farigiraf ex should retain the legal Bench target"),
		assert_false(bool(step.get("allow_cancel", true)), "Farigiraf ex's mandatory Bench target should not be cancellable"),
	])


func test_imported_tera_rule_prevents_only_attack_damage_while_each_card_is_benched() -> String:
	var checks: Array[String] = []
	for card_index: String in ["047", "058"]:
		var card := _load_card("CSV9.5C", card_index)
		checks.append(assert_not_null(card, "CSV9.5C_%s should load for the Tera rule test" % card_index))
		if card == null:
			continue
		var state := _make_state()
		var attacker := _slot(_pokemon("Opponent Attacker", "C", 200), 0)
		var tera_target := _slot(card, 1)
		state.players[0].active_pokemon = attacker
		state.players[1].active_pokemon = _slot(_pokemon("Other Active", "C", 200), 1)
		state.players[1].bench.append(tera_target)
		checks.append(assert_true(
			AbilityBenchImmuneScript.prevents_opponent_attack_damage(tera_target, attacker, state),
			"CSV9.5C_%s Tera Pokemon should prevent attack damage while on the Bench" % card_index
		))
		checks.append(assert_false(
			AbilityBenchImmuneScript.prevents_opponent_attack_effect(tera_target, attacker, state),
			"CSV9.5C_%s Tera rule should not prevent non-damage attack effects" % card_index
		))
		state.players[1].bench.clear()
		state.players[1].active_pokemon = tera_target
		checks.append(assert_false(
			AbilityBenchImmuneScript.prevents_opponent_attack_damage(tera_target, attacker, state),
			"CSV9.5C_%s Tera rule should not prevent attack damage in the Active Spot" % card_index
		))
	return run_checks(checks)


func test_glaceon_euclase_targets_only_pokemon_with_exactly_six_damage_counters() -> String:
	var card := _load_card("CSV9.5C", "047")
	if card == null:
		return assert_not_null(card, "CSV9.5C_047 Glaceon ex should load")
	var state := _make_state()
	var attacker := _slot(card, 0)
	var exact_active := _slot(_pokemon("Exact Active", "C", 300), 1)
	var exact_bench := _slot(_pokemon("Exact Bench", "C", 100), 1)
	var wrong_bench := _slot(_pokemon("Wrong Bench", "C", 100), 1)
	exact_active.damage_counters = 60
	exact_bench.damage_counters = 60
	wrong_bench.damage_counters = 70
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = exact_active
	state.players[1].bench.append_array([exact_bench, wrong_bench])
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var steps := processor.get_attack_interaction_steps_by_id(card.effect_id, 1, attacker.get_top_card(), card.attacks[1], state)
	var step: Dictionary = _find_step(steps, EXACT_COUNTER_KO_STEP_ID)
	var executed := processor.execute_attack_effect(attacker, 1, exact_active, state, [{EXACT_COUNTER_KO_STEP_ID: [exact_bench]}])
	return run_checks([
		assert_eq(steps.size(), 1, "Euclase should expose one target step when exact-six-counter targets exist"),
		assert_true(exact_active in step.get("items", []), "Euclase should allow the opposing Active Pokemon with exactly 60 damage"),
		assert_true(exact_bench in step.get("items", []), "Euclase should allow an opposing Benched Pokemon with exactly 60 damage"),
		assert_false(wrong_bench in step.get("items", []), "Euclase should reject Pokemon with more or fewer than six damage counters"),
		assert_eq(int(step.get("min_select", 0)), 1, "Euclase should require one target when legal targets exist"),
		assert_false(bool(step.get("allow_cancel", true)), "Euclase target selection should not be cancellable"),
		assert_true(executed, "Euclase's registered attack effect should execute"),
		assert_true(exact_bench.is_knocked_out(), "Euclase should Knock Out the selected exact-six-counter Bench target"),
		assert_eq(exact_active.damage_counters, 60, "Euclase should leave an unselected exact-six-counter target unchanged"),
		assert_eq(wrong_bench.damage_counters, 70, "Euclase should leave an ineligible target unchanged"),
	])


func test_jolteon_flash_spear_discards_up_to_two_bench_basic_energy_for_90_each() -> String:
	var card := _load_card("CSV9.5C", "058")
	if card == null:
		return assert_not_null(card, "CSV9.5C_058 Jolteon ex should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Opponent Active", "C", 400), 1)
	var bench_a := _slot(_pokemon("Bench A", "R", 100), 0)
	var bench_b := _slot(_pokemon("Bench B", "W", 100), 0)
	var active_lightning := _attach_basic_energy(attacker, 0, "L")
	var active_colorless := _attach_basic_energy(attacker, 0, "C")
	var fire := _attach_basic_energy(bench_a, 0, "R")
	var water := _attach_basic_energy(bench_b, 0, "W")
	var special := CardInstance.create(_special_energy("Bench Special Energy", "C"), 0)
	bench_a.attached_energy.append(special)
	player.active_pokemon = attacker
	player.bench.append_array([bench_a, bench_b])
	opponent.active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(card)
	var steps := gsm.effect_processor.get_attack_interaction_steps_by_id(card.effect_id, 0, attacker.get_top_card(), card.attacks[0], gsm.game_state)
	var step: Dictionary = _find_step(steps, BENCH_ENERGY_DISCARD_STEP_ID)
	var attacked := gsm.use_attack(0, 0, [{BENCH_ENERGY_DISCARD_STEP_ID: [fire, water]}])
	var items: Array = step.get("items", [])
	var checks: Array[String] = [
		assert_eq(steps.size(), 1, "Flash Spear should expose one optional Bench Basic Energy selection step"),
		assert_true(fire in items and water in items, "Flash Spear should expose Basic Energy attached to own Bench"),
		assert_false(special in items, "Flash Spear should not expose Special Energy"),
		assert_false(active_lightning in items or active_colorless in items, "Flash Spear should not expose Energy attached to the attacker"),
		assert_eq(int(step.get("min_select", -1)), 0, "Flash Spear should allow choosing no Energy"),
		assert_eq(int(step.get("max_select", -1)), 2, "Flash Spear should cap the discard at two Energy"),
		assert_true(bool(step.get("allow_cancel", false)), "Flash Spear should allow declining the optional discard"),
		assert_true(bool(step.get("force_confirm", false)), "Flash Spear should wait for the player's optional selection"),
		assert_true(attacked, "Flash Spear should execute with Lightning and Colorless Energy"),
		assert_eq(defender.damage_counters, 240, "Flash Spear should deal 60 plus 90 for each of two discarded Basic Energy"),
		assert_true(fire in player.discard_pile and water in player.discard_pile, "Selected Bench Basic Energy should enter the discard pile"),
		assert_false(fire in bench_a.attached_energy or water in bench_b.attached_energy, "Selected Basic Energy should leave their Bench Pokemon"),
		assert_true(special in bench_a.attached_energy, "Unselected Special Energy should remain attached"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_jolteon_flash_spear_can_decline_the_optional_discard() -> String:
	var card := _load_card("CSV9.5C", "058")
	if card == null:
		return assert_not_null(card, "CSV9.5C_058 Jolteon ex should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Opponent Active", "C", 400), 1)
	var bench := _slot(_pokemon("Bench", "R", 100), 0)
	var bench_energy := _attach_basic_energy(bench, 0, "R")
	_attach_basic_energy(attacker, 0, "L")
	_attach_basic_energy(attacker, 0, "C")
	player.active_pokemon = attacker
	player.bench.append(bench)
	opponent.active_pokemon = defender
	gsm.effect_processor.register_pokemon_card(card)
	var attacked := gsm.use_attack(0, 0, [{BENCH_ENERGY_DISCARD_STEP_ID: []}])
	var checks: Array[String] = [
		assert_true(attacked, "Flash Spear should execute after explicitly declining the optional discard"),
		assert_eq(defender.damage_counters, 60, "Flash Spear should deal only its printed base damage when no Energy is discarded"),
		assert_true(bench_energy in bench.attached_energy, "Declining Flash Spear's option should keep Bench Energy attached"),
		assert_false(bench_energy in player.discard_pile, "Declining Flash Spear's option should not discard Energy"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_jolteon_dravite_locks_both_attacks_during_the_next_own_turn() -> String:
	var card := _load_card("CSV9.5C", "058")
	if card == null:
		return assert_not_null(card, "CSV9.5C_058 Jolteon ex should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Opponent Active", "C", 500), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = defender
	_attach_basic_energy(attacker, 0, "R")
	_attach_basic_energy(attacker, 0, "W")
	_attach_basic_energy(attacker, 0, "L")
	gsm.effect_processor.register_pokemon_card(card)
	var attack_turn := gsm.game_state.turn_number
	var attacked := gsm.use_attack(0, 1)
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = attack_turn + 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var checks: Array[String] = [
		assert_true(attacked, "Dravite should execute with Fire, Water, and Lightning Energy"),
		assert_eq(defender.damage_counters, 280, "Dravite should deal its printed 280 damage"),
		assert_false(gsm.can_use_attack(0, 0), "Dravite should lock Flash Spear during Jolteon's next turn"),
		assert_false(gsm.can_use_attack(0, 1), "Dravite should lock itself during Jolteon's next turn"),
		assert_eq(str(attacker.effects[0].get("type", "")) if not attacker.effects.is_empty() else "", "attack_lock_all", "Dravite should use the shared whole-Pokemon lock marker"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


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


func _pokemon(name: String, energy_type: String = "C", hp: int = 100) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = energy_type
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _basic_energy(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _special_energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Special Energy"
	card.energy_provides = provides
	return card


func _attach_basic_energy(slot: PokemonSlot, owner_index: int, energy_type: String) -> CardInstance:
	var energy := CardInstance.create(_basic_energy("%s Energy" % energy_type, energy_type), owner_index)
	slot.attached_energy.append(energy)
	return energy


func _find_step(steps: Array[Dictionary], step_id: String) -> Dictionary:
	for step: Dictionary in steps:
		if str(step.get("id", "")) == step_id:
			return step
	return {}


func _has_effect_script(effects: Array, script_path: String) -> bool:
	for effect: BaseEffect in effects:
		var script: Script = effect.get_script() as Script if effect != null else null
		if script != null and script.resource_path == script_path:
			return true
	return false
