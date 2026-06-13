class_name TestCS5aC068Crobat
extends TestBase

const EFFECT_ID := "930008a5b5f22ceabca6767aafd93a35"
const TARGET_STEP_ID := "cs5ac_068_critical_bite_target"


func test_cs5ac_068_crobat_registers_poison_and_critical_bite_interaction() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var crobat_cd := _crobat()
	processor.register_pokemon_card(crobat_cd)
	var crobat := _make_slot(crobat_cd, 0)
	state.players[0].active_pokemon = crobat
	var bench_target := _make_slot(_pokemon("Bench Target", "Basic", "C", 80), 1)
	state.players[1].bench.append(bench_target)

	var first_attack_effects := processor.get_attack_effects_for_slot(crobat, 0)
	var second_attack_effects := processor.get_attack_effects_for_slot(crobat, 1)
	var steps := processor.get_attack_interaction_steps_by_id(
		EFFECT_ID,
		1,
		crobat.get_top_card(),
		crobat_cd.attacks[1],
		state
	)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = step.get("items", [])

	return run_checks([
		assert_true(processor.has_attack_effect(EFFECT_ID), "CS5aC_068 should register native attack effects"),
		assert_eq(first_attack_effects.size(), 1, "Poison Fang should have one poison effect"),
		assert_eq(second_attack_effects.size(), 1, "Critical Bite should have one target-damage effect"),
		assert_eq(steps.size(), 1, "Critical Bite should expose one target interaction step"),
		assert_eq(str(step.get("id", "")), TARGET_STEP_ID, "Critical Bite target step should use a stable id"),
		assert_true(state.players[1].active_pokemon in items, "Critical Bite should allow targeting the opponent Active Pokemon"),
		assert_true(bench_target in items, "Critical Bite should allow targeting an opponent Benched Pokemon"),
	])


func test_cs5ac_068_poison_fang_poisons_opponent_active() -> String:
	var gsm := _make_gsm()
	var crobat_cd := _crobat()
	var crobat := _make_slot(crobat_cd, 0)
	var defender := _make_slot(_pokemon("Defender", "Basic", "P", 120), 1)
	gsm.game_state.players[0].active_pokemon = crobat
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(crobat, 0, "D", 1)
	gsm.effect_processor.register_pokemon_card(crobat_cd)

	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "Poison Fang should be usable with one Darkness Energy"),
		assert_eq(defender.damage_counters, 60, "Poison Fang should deal 50 damage, then poison should add 10 during Pokemon Check"),
		assert_true(bool(defender.status_conditions.get("poisoned", false)), "Poison Fang should poison the opponent Active Pokemon"),
	])


func test_cs5ac_068_critical_bite_targets_bench_and_sets_two_extra_prizes_on_damage_ko() -> String:
	var gsm := _make_gsm()
	var crobat_cd := _crobat()
	var crobat := _make_slot(crobat_cd, 0)
	var active_defender := _make_slot(_pokemon("Active Defender", "Basic", "P", 120), 1)
	var bench_target := _make_slot(_pokemon("Bench Target", "Basic", "P", 30), 1)
	gsm.game_state.players[0].active_pokemon = crobat
	gsm.game_state.players[1].active_pokemon = active_defender
	gsm.game_state.players[1].bench.append(bench_target)
	_attach_energy(crobat, 0, "C", 3)
	_add_prizes(gsm.game_state.players[0], 6, 0)
	_add_prizes(gsm.game_state.players[1], 6, 1)
	gsm.effect_processor.register_pokemon_card(crobat_cd)

	var choice_events: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(choice_type: String, data: Dictionary) -> void:
		choice_events.append({"type": choice_type, "data": data.duplicate(true)})
	)
	var used := gsm.use_attack(0, 1, [{TARGET_STEP_ID: [bench_target]}])
	var prize_remaining := int(gsm.get("_pending_prize_remaining"))
	var prize_owner := int(gsm.get("_pending_prize_player_index"))
	var took: Array[bool] = [
		gsm.resolve_take_prize(0, 0),
		gsm.resolve_take_prize(0, 1),
		gsm.resolve_take_prize(0, 2),
	]

	return run_checks([
		assert_true(used, "Critical Bite should be usable with three Colorless Energy"),
		assert_eq(bench_target.damage_counters, 30, "Critical Bite should deal 30 damage to the selected Bench Pokemon"),
		assert_eq(prize_owner, 0, "The attacking Crobat player should be prompted to take prizes"),
		assert_eq(prize_remaining, 3, "Critical Bite should award base prize plus two extra prizes on a damage KO"),
		assert_true(choice_events.any(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "take_prize"), "Critical Bite knockout should enter take-prize flow"),
		assert_eq(took, [true, true, true], "Critical Bite should require resolving all three prize cards"),
		assert_eq(gsm.game_state.players[0].hand.size(), 3, "Critical Bite should move three prize cards to hand"),
		assert_eq(gsm.game_state.players[0].prizes.size(), 3, "Critical Bite should remove three prize cards from prizes"),
	])


func test_cs5ac_068_critical_bite_does_not_add_extra_prizes_without_damage_ko() -> String:
	var gsm := _make_gsm()
	var crobat_cd := _crobat()
	var crobat := _make_slot(crobat_cd, 0)
	var active_defender := _make_slot(_pokemon("Active Defender", "Basic", "P", 120), 1)
	var bench_target := _make_slot(_pokemon("Bench Target", "Basic", "P", 70), 1)
	gsm.game_state.players[0].active_pokemon = crobat
	gsm.game_state.players[1].active_pokemon = active_defender
	gsm.game_state.players[1].bench.append(bench_target)
	_attach_energy(crobat, 0, "C", 3)
	_add_prizes(gsm.game_state.players[0], 6, 0)
	_add_prizes(gsm.game_state.players[1], 6, 1)
	gsm.effect_processor.register_pokemon_card(crobat_cd)

	var used := gsm.use_attack(0, 1, [{TARGET_STEP_ID: [bench_target]}])

	return run_checks([
		assert_true(used, "Critical Bite should resolve against a non-KO Bench target"),
		assert_eq(bench_target.damage_counters, 30, "Critical Bite should still place 30 attack damage"),
		assert_eq(int(gsm.get("_pending_prize_remaining")), 0, "Critical Bite should not award prizes when its damage does not Knock Out"),
		assert_eq(gsm.game_state.players[0].prizes.size(), 6, "No prizes should be removed without a Knock Out"),
	])


func test_cs5ac_068_critical_bite_only_adds_extra_prizes_when_this_damage_causes_ko() -> String:
	var gsm := _make_gsm()
	var crobat_cd := _crobat()
	var crobat := _make_slot(crobat_cd, 0)
	var active_defender := _make_slot(_pokemon("Active Defender", "Basic", "P", 120), 1)
	var bench_target := _make_slot(_pokemon("Already Knocked Out", "Basic", "P", 30), 1)
	bench_target.damage_counters = 30
	gsm.game_state.players[0].active_pokemon = crobat
	gsm.game_state.players[1].active_pokemon = active_defender
	gsm.game_state.players[1].bench.append(bench_target)
	_attach_energy(crobat, 0, "C", 3)
	_add_prizes(gsm.game_state.players[0], 6, 0)
	_add_prizes(gsm.game_state.players[1], 6, 1)
	gsm.effect_processor.register_pokemon_card(crobat_cd)

	var used := gsm.use_attack(0, 1, [{TARGET_STEP_ID: [bench_target]}])

	return run_checks([
		assert_true(used, "Critical Bite should still resolve in the test fixture"),
		assert_eq(int(gsm.get("_pending_prize_remaining")), 1, "Critical Bite should not add extra prizes if the target was already effectively Knocked Out before this damage"),
	])


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _make_state() -> GameState:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "Basic", "C", 120), pi)
		state.players.append(player)
	return state


func _crobat() -> CardData:
	var cd := _pokemon("叉字蝠", "Stage 2", "D", 130)
	cd.effect_id = EFFECT_ID
	cd.evolves_from = "大嘴蝠"
	cd.name_en = "Crobat"
	cd.attacks = [
		{"name": "毒牙", "cost": "D", "damage": "50", "text": "使对手的战斗宝可梦陷入【中毒】状态。", "is_vstar_power": false},
		{"name": "重伤啃咬", "cost": "CCC", "damage": "", "text": "给对手的1只宝可梦，造成30点伤害。如果因为这个招式的伤害，对手的宝可梦【昏厥】的话，则多拿取2张奖赏卡。[备战宝可梦不计算弱点、抗性。]", "is_vstar_power": false},
	]
	return cd


func _pokemon(name: String, stage: String, energy_type: String, hp: int) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		var energy := CardData.new()
		energy.name = "%s Energy %d" % [energy_type, i]
		energy.card_type = "Basic Energy"
		energy.energy_type = energy_type
		energy.energy_provides = energy_type
		slot.attached_energy.append(CardInstance.create(energy, owner_index))


func _add_prizes(player: PlayerState, count: int, owner_index: int) -> void:
	for i: int in count:
		var card := CardData.new()
		card.name = "Prize %d" % i
		card.card_type = "Item"
		player.prizes.append(CardInstance.create(card, owner_index))
