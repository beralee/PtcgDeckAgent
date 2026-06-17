class_name TestBatch3178WorkerDEffects
extends TestBase

const AttackRagingBoltLightningStorm = preload("res://scripts/effects/pokemon_effects/AttackRagingBoltLightningStorm.gd")
const AttackBruteBonnetDamageCounterBonus = preload("res://scripts/effects/pokemon_effects/AttackBruteBonnetDamageCounterBonus.gd")
const AttackOpponentFuturePokemonBonusDamage = preload("res://scripts/effects/pokemon_effects/AttackOpponentFuturePokemonBonusDamage.gd")
const AbilityToedscruelSlimeMoldColony = preload("res://scripts/effects/pokemon_effects/AbilityToedscruelSlimeMoldColony.gd")
const DiscardToHandBlockHelper = preload("res://scripts/effects/pokemon_effects/DiscardToHandBlockHelper.gd")
const AttackDiscardAttachedEnergyTypeFromSelf = preload("res://scripts/effects/pokemon_effects/AttackDiscardAttachedEnergyTypeFromSelf.gd")
const AttackSweetTrap = preload("res://scripts/effects/pokemon_effects/AttackSweetTrap.gd")
const EffectApplyStatus = preload("res://scripts/effects/pokemon_effects/EffectApplyStatus.gd")
const CSV9CSimpleHealSelfAfterAttack = preload("res://scripts/effects/pokemon_effects/CSV9CSimpleHealSelfAfterAttack.gd")
const EffectNightStretcher = preload("res://scripts/effects/trainer_effects/EffectNightStretcher.gd")
const EffectRecoverBasicEnergy = preload("res://scripts/effects/trainer_effects/EffectRecoverBasicEnergy.gd")
const EffectLanasAid = preload("res://scripts/effects/trainer_effects/EffectLanasAid.gd")
const AbilityRecoverDiscardCardsToHandVSTAR = preload("res://scripts/effects/pokemon_effects/AbilityRecoverDiscardCardsToHandVSTAR.gd")

const RAGING_BOLT_ID := "12b30b5d9a0bd31a8e033bf2f2cfead3"
const BRUTE_BONNET_ID := "c6083ce0a1d2bda048f3eb948b8abca8"
const SLITHER_WING_ID := "f133f2b8d38148794b81a8b4ca135cff"
const MAWILE_ID := "26afb8b359bdeb40834a9dafbba4218b"
const TOEDSCRUEL_ID := "880338810e1bc9460b1d20044377e08c"


func _make_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Test Attack", "cost": "", "damage": "", "text": "", "is_vstar_power": false}]
	return cd


func _make_energy_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _make_trainer_data(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Item"
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_data("Active%d" % pi, "C", 130), pi)
		for bi: int in 2:
			player.bench.append(_make_slot(_make_pokemon_data("Bench%d_%d" % [pi, bi], "C", 100), pi))
		state.players.append(player)
	return state


func _attach_energy(slot: PokemonSlot, name: String, energy_type: String, owner_index: int) -> CardInstance:
	var energy := CardInstance.create(_make_energy_data(name, energy_type), owner_index)
	slot.attached_energy.append(energy)
	return energy


func _has_effect_type(effects: Array[BaseEffect], script_ref: GDScript) -> bool:
	for effect: BaseEffect in effects:
		if is_instance_of(effect, script_ref):
			return true
	return false


func _last_action_of_type(actions: Array[GameAction], action_type: GameAction.ActionType) -> GameAction:
	for i: int in range(actions.size() - 1, -1, -1):
		var action := actions[i]
		if action != null and action.action_type == action_type:
			return action
	return null


func test_batch_3178_worker_d_effect_ids_register_direct_effects() -> String:
	var processor := EffectProcessor.new()

	var raging_cd := _make_pokemon_data("猛雷鼓", "N", 130, "Basic", RAGING_BOLT_ID)
	raging_cd.attacks = [
		{"name": "落雷风暴", "cost": "LF", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "龙之头击", "cost": "LFC", "damage": "130", "text": "", "is_vstar_power": false},
	]
	var raging := _make_slot(raging_cd, 0)

	var bonnet_cd := _make_pokemon_data("猛恶菇", "D", 120, "Basic", BRUTE_BONNET_ID)
	bonnet_cd.attacks = [
		{"name": "毒液喷吐", "cost": "D", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "痛殴", "cost": "DDD", "damage": "50+", "text": "", "is_vstar_power": false},
	]
	var bonnet := _make_slot(bonnet_cd, 0)

	var slither_cd := _make_pokemon_data("爬地翅", "F", 140, "Basic", SLITHER_WING_ID)
	slither_cd.attacks = [
		{"name": "碎铁", "cost": "FC", "damage": "20+", "text": "", "is_vstar_power": false},
		{"name": "粉碎之翼", "cost": "FFC", "damage": "130", "text": "", "is_vstar_power": false},
	]
	var slither := _make_slot(slither_cd, 0)

	var mawile_cd := _make_pokemon_data("大嘴娃", "P", 90, "Basic", MAWILE_ID)
	mawile_cd.attacks = [
		{"name": "甜甜陷阱", "cost": "C", "damage": "", "text": "", "is_vstar_power": false},
		{"name": "咬住", "cost": "PCC", "damage": "90", "text": "", "is_vstar_power": false},
	]
	var mawile := _make_slot(mawile_cd, 0)

	var toedscruel_cd := _make_pokemon_data("陆地水母", "G", 120, "Stage 1", TOEDSCRUEL_ID)
	toedscruel_cd.abilities = [{"name": "黏菌聚落", "text": ""}]
	var toedscruel := _make_slot(toedscruel_cd, 0)

	processor.register_pokemon_card(raging_cd)
	processor.register_pokemon_card(bonnet_cd)
	processor.register_pokemon_card(slither_cd)
	processor.register_pokemon_card(mawile_cd)
	processor.register_pokemon_card(toedscruel_cd)

	return run_checks([
		assert_true(processor.has_attack_effect(RAGING_BOLT_ID), "CSV8C_161 should have direct attack effect_id registration"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(raging, 0), AttackRagingBoltLightningStorm), "CSV8C_161 first attack should register Lightning Storm"),
		assert_false(_has_effect_type(processor.get_attack_effects_for_slot(raging, 1), AttackRagingBoltLightningStorm), "CSV8C_161 second attack should not reuse Lightning Storm"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(bonnet, 0), EffectApplyStatus), "CSV7C_142 first attack should register poison"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(bonnet, 1), AttackBruteBonnetDamageCounterBonus), "CSV7C_142 second attack should register damage-counter bonus"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(slither, 0), AttackOpponentFuturePokemonBonusDamage), "CSV8C_119 first attack should register Future bonus"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(slither, 1), AttackDiscardAttachedEnergyTypeFromSelf), "CSV8C_119 second attack should register self Energy discard"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(mawile, 0), AttackSweetTrap), "CS6bC_035 first attack should register Sweet Trap"),
		assert_false(_has_effect_type(processor.get_attack_effects_for_slot(mawile, 1), AttackSweetTrap), "CS6bC_035 second attack should not apply Sweet Trap"),
		assert_true(processor.get_effect(TOEDSCRUEL_ID) is AbilityToedscruelSlimeMoldColony, "CSV5C_009 should register Slime Mold Colony by effect_id"),
		assert_true(_has_effect_type(processor.get_attack_effects_for_slot(toedscruel, 0), CSV9CSimpleHealSelfAfterAttack), "CSV5C_009 attack should register self-heal"),
	])


func test_csv8c_161_raging_bolt_lightning_storm_targets_any_opponent_pokemon() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var raging_cd := _make_pokemon_data("猛雷鼓", "N", 130, "Basic", RAGING_BOLT_ID)
	raging_cd.attacks = [
		{"name": "落雷风暴", "cost": "LF", "damage": "", "text": "给对手的1只宝可梦，造成这只宝可梦身上附着的能量数量×30伤害。", "is_vstar_power": false},
		{"name": "龙之头击", "cost": "LFC", "damage": "130", "text": "", "is_vstar_power": false},
	]
	player.active_pokemon = _make_slot(raging_cd, 0)
	_attach_energy(player.active_pokemon, "Raging Energy A", "L", 0)
	_attach_energy(player.active_pokemon, "Raging Energy B", "F", 0)
	_attach_energy(player.active_pokemon, "Raging Energy C", "G", 0)
	var bench_target := opponent.bench[1]
	bench_target.get_card_data().weakness_energy = "N"
	bench_target.get_card_data().weakness_value = "x2"
	opponent.active_pokemon.get_card_data().weakness_energy = "N"
	opponent.active_pokemon.get_card_data().weakness_value = "x2"

	var effect := AttackRagingBoltLightningStorm.new(30, 0)
	state.shared_turn_flags["_draw_effect_processor"] = EffectProcessor.new()
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), raging_cd.attacks[0], state)
	effect.set_attack_interaction_context([{AttackRagingBoltLightningStorm.STEP_ID: [bench_target]}])
	effect.execute_attack(player.active_pokemon, opponent.active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	effect.set_attack_interaction_context([{AttackRagingBoltLightningStorm.STEP_ID: [opponent.active_pokemon]}])
	effect.execute_attack(player.active_pokemon, opponent.active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CSV8C_161 should ask which opposing Pokemon to damage"),
		assert_eq((steps[0].get("items", []) as Array).size(), 3, "CSV8C_161 should expose Active plus Benched targets"),
		assert_eq(bench_target.damage_counters, 90, "Bench target damage should use Raging Bolt Energy count x30 without Weakness"),
		assert_eq(opponent.active_pokemon.damage_counters, 180, "Active target should use Raging Bolt Energy count x30 and then apply Weakness"),
	])


func test_csv8c_161_raging_bolt_lightning_storm_uses_attacker_energy_for_bench_target() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player := state.players[0]
	var opponent := state.players[1]
	var raging_cd := _make_pokemon_data("Raging Bolt", "N", 130, "Basic", RAGING_BOLT_ID)
	raging_cd.attacks = [
		{"name": "Lightning Storm", "cost": "LF", "damage": "", "text": "This attack does 30 damage for each Energy attached to this Pokemon to 1 of your opponent's Pokemon.", "is_vstar_power": false},
		{"name": "Dragon Headbutt", "cost": "LFC", "damage": "130", "text": "", "is_vstar_power": false},
	]
	var raging := _make_slot(raging_cd, 0)
	_attach_energy(raging, "Lightning Energy", "L", 0)
	_attach_energy(raging, "Fighting Energy", "F", 0)
	player.active_pokemon = raging
	gsm.effect_processor.register_pokemon_card(raging_cd)

	var active_cd := _make_pokemon_data("Opponent Active", "P", 120, "Basic")
	opponent.active_pokemon = _make_slot(active_cd, 1)
	var kirlia_cd := _make_pokemon_data("Kirlia", "P", 80, "Stage 1")
	var kirlia := _make_slot(kirlia_cd, 1)
	opponent.bench = [kirlia]

	var attacked := gsm.use_attack(0, 0, [{
		AttackRagingBoltLightningStorm.STEP_ID: [kirlia],
	}])
	var damage_action := _last_action_of_type(gsm.action_log, GameAction.ActionType.DAMAGE_DEALT)
	var damage_targets: Array = damage_action.data.get("targets", []) if damage_action != null else []
	var first_target: Dictionary = damage_targets[0] if not damage_targets.is_empty() and damage_targets[0] is Dictionary else {}

	return run_checks([
		assert_true(attacked, "CSV8C_161 should be able to use Lightning Storm with Lightning and Fighting Energy attached"),
		assert_eq(kirlia.damage_counters, 60, "Lightning Storm should use Raging Bolt's attached Energy count, not Kirlia's Energy count"),
		assert_eq(opponent.active_pokemon.damage_counters, 0, "Selecting a Benched Kirlia should not damage the opposing Active"),
		assert_not_null(damage_action, "Bench damage should be logged for VFX and battle history"),
		assert_eq(str(damage_action.data.get("target", "")) if damage_action != null else "", "Kirlia", "Damage log should name the selected Bench target"),
		assert_eq(str(first_target.get("slot_kind", "")), "bench", "Damage VFX target should point to the selected Bench slot"),
		assert_eq(int(first_target.get("slot_index", -1)), 0, "Damage VFX target should preserve the selected Bench index"),
	])


func test_csv7c_142_brute_bonnet_poison_and_damage_counter_bonus() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var bonnet_cd := _make_pokemon_data("猛恶菇", "D", 120, "Basic", BRUTE_BONNET_ID)
	bonnet_cd.attacks = [
		{"name": "毒液喷吐", "cost": "D", "damage": "", "text": "令对手的战斗宝可梦陷入【中毒】状态。", "is_vstar_power": false},
		{"name": "痛殴", "cost": "DDD", "damage": "50+", "text": "追加造成对手战斗宝可梦身上放置的伤害指示物数量×50伤害。", "is_vstar_power": false},
	]
	player.active_pokemon = _make_slot(bonnet_cd, 0)
	opponent.active_pokemon.damage_counters = 30
	var poison := EffectApplyStatus.new("poisoned", false, 0)
	var bonus := AttackBruteBonnetDamageCounterBonus.new(50, 1)
	poison.execute_attack(player.active_pokemon, opponent.active_pokemon, 0, state)

	var processor := EffectProcessor.new()
	processor.register_attack_effect(BRUTE_BONNET_ID, bonus)
	var modifier := processor.get_attack_damage_modifier(player.active_pokemon, opponent.active_pokemon, bonnet_cd.attacks[1], state)
	var final_damage := DamageCalculator.new().calculate_damage(
		player.active_pokemon,
		opponent.active_pokemon,
		bonnet_cd.attacks[1],
		state,
		modifier
	)

	return run_checks([
		assert_true(opponent.active_pokemon.status_conditions.get("poisoned", false), "CSV7C_142 first attack should poison the opponent Active"),
		assert_eq(modifier, 150, "CSV7C_142 second attack should add 50 per damage counter"),
		assert_eq(final_damage, 200, "CSV7C_142 second attack should resolve as 50 plus 150 bonus before damage is applied"),
	])


func test_csv8c_119_slither_wing_future_bonus_and_discard_two_energy() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var slither_cd := _make_pokemon_data("爬地翅", "F", 140, "Basic", SLITHER_WING_ID)
	slither_cd.attacks = [
		{"name": "碎铁", "cost": "FC", "damage": "20+", "text": "如果对手场上有「未来」宝可梦的话，则追加造成120伤害。", "is_vstar_power": false},
		{"name": "粉碎之翼", "cost": "FFC", "damage": "130", "text": "选择这只宝可梦身上附着的2个能量，放于弃牌区。", "is_vstar_power": false},
	]
	player.active_pokemon = _make_slot(slither_cd, 0)
	var future_cd := _make_pokemon_data("Future Target", "L")
	future_cd.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	opponent.bench[0] = _make_slot(future_cd, 1)

	var processor := EffectProcessor.new()
	processor.register_attack_effect(SLITHER_WING_ID, AttackOpponentFuturePokemonBonusDamage.new(120, 0))
	var no_future_state := _make_state()
	no_future_state.players[0].active_pokemon = _make_slot(slither_cd, 0)
	var no_future_bonus := processor.get_attack_damage_modifier(no_future_state.players[0].active_pokemon, no_future_state.players[1].active_pokemon, slither_cd.attacks[0], no_future_state)
	var future_bonus := processor.get_attack_damage_modifier(player.active_pokemon, opponent.active_pokemon, slither_cd.attacks[0], state)

	var discard_effect := AttackDiscardAttachedEnergyTypeFromSelf.new("", 2, 1)
	var keep_energy := _attach_energy(player.active_pokemon, "Keep Energy", "F", 0)
	var discard_a := _attach_energy(player.active_pokemon, "Discard Energy A", "F", 0)
	var discard_b := _attach_energy(player.active_pokemon, "Discard Energy B", "C", 0)
	var steps: Array[Dictionary] = discard_effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), slither_cd.attacks[1], state)
	discard_effect.set_attack_interaction_context([{AttackDiscardAttachedEnergyTypeFromSelf.STEP_ID: [discard_a, discard_b]}])
	discard_effect.execute_attack(player.active_pokemon, opponent.active_pokemon, 1, state)
	discard_effect.clear_attack_interaction_context()

	var exact_state := _make_state()
	exact_state.players[0].active_pokemon = _make_slot(slither_cd, 0)
	var exact_effect := AttackDiscardAttachedEnergyTypeFromSelf.new("", 2, 1)
	var exact_a := _attach_energy(exact_state.players[0].active_pokemon, "Exact Energy A", "F", 0)
	var exact_b := _attach_energy(exact_state.players[0].active_pokemon, "Exact Energy B", "C", 0)
	var exact_steps: Array[Dictionary] = exact_effect.get_attack_interaction_steps(
		exact_state.players[0].active_pokemon.get_top_card(),
		slither_cd.attacks[1],
		exact_state
	)
	exact_effect.execute_attack(exact_state.players[0].active_pokemon, exact_state.players[1].active_pokemon, 1, exact_state)

	return run_checks([
		assert_eq(no_future_bonus, 0, "CSV8C_119 first attack should not gain damage without an opposing Future Pokemon"),
		assert_eq(future_bonus, 120, "CSV8C_119 first attack should add 120 when the opponent has a Future Pokemon in play"),
		assert_eq(steps.size(), 1, "CSV8C_119 second attack should ask which attached Energy to discard when choices exist"),
		assert_true(keep_energy in player.active_pokemon.attached_energy, "CSV8C_119 should keep unselected attached Energy"),
		assert_true(discard_a in player.discard_pile and discard_b in player.discard_pile, "CSV8C_119 should discard exactly the selected 2 Energy"),
		assert_eq(exact_steps.size(), 0, "CSV8C_119 should not prompt when exactly 2 discardable Energy are attached"),
		assert_false(exact_a in exact_state.players[0].active_pokemon.attached_energy, "CSV8C_119 should discard the first Energy when exactly 2 are attached"),
		assert_false(exact_b in exact_state.players[0].active_pokemon.attached_energy, "CSV8C_119 should discard the second Energy when exactly 2 are attached"),
		assert_true(exact_a in exact_state.players[0].discard_pile and exact_b in exact_state.players[0].discard_pile, "CSV8C_119 should move both exactly attached Energy to discard"),
	])


func test_cs6bc_035_mawile_sweet_trap_retreat_lock_and_next_turn_damage_bonus() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	attacker.pokemon_stack[0].card_data.effect_id = MAWILE_ID
	var defender := state.players[1].active_pokemon
	var effect := AttackSweetTrap.new(0)
	effect.execute_attack(attacker, defender, 0, state)
	var retreat_locked_now := defender.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "retreat_lock" and int(e.get("turn", -1)) == 2)
	var bonus_marked := defender.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == AttackSweetTrap.DAMAGE_BONUS_EFFECT_TYPE and int(e.get("amount", 0)) == 90)

	state.turn_number = 3
	state.current_player_index = 1
	var processor := EffectProcessor.new()
	var retreat_blocked := not RuleValidator.new().can_retreat(state, 1, processor)
	var premature_bonus := processor.get_defender_modifier(defender, state, attacker)
	state.turn_number = 4
	state.current_player_index = 0
	var next_own_turn_bonus := processor.get_defender_modifier(defender, state, attacker)

	return run_checks([
		assert_true(retreat_locked_now, "CS6bC_035 should mark the Defending Pokemon with retreat_lock"),
		assert_true(bonus_marked, "CS6bC_035 should mark the Defending Pokemon for +90 damage"),
		assert_true(retreat_blocked, "CS6bC_035 should stop retreat on the opponent's next turn"),
		assert_eq(premature_bonus, 0, "CS6bC_035 should not add damage during the opponent's intervening turn"),
		assert_eq(next_own_turn_bonus, 90, "CS6bC_035 should add 90 damage during the user's next turn"),
	])


func test_csv5c_009_toedscruel_blocks_opponent_trainer_and_ability_discard_recovery() -> String:
	var state := _make_state()
	var toedscruel_cd := _make_pokemon_data("陆地水母", "G", 120, "Stage 1", TOEDSCRUEL_ID)
	toedscruel_cd.abilities = [{"name": "黏菌聚落", "text": "只要这只宝可梦在场上，对手弃牌区中的卡牌，就无法因为对手的特性或训练家的效果，被加入对手的手牌。"}]
	state.players[0].bench[0] = _make_slot(toedscruel_cd, 0)
	var processor := EffectProcessor.new()
	processor.register_effect(TOEDSCRUEL_ID, AbilityToedscruelSlimeMoldColony.new())

	var discard_pokemon := CardInstance.create(_make_pokemon_data("Discard Pokemon", "G"), 1)
	var discard_energy := CardInstance.create(_make_energy_data("Discard Energy", "G"), 1)
	state.players[1].discard_pile.append_array([discard_pokemon, discard_energy])
	var trainer_blocked := DiscardToHandBlockHelper.is_discard_to_hand_blocked(1, state, "trainer", processor)
	var ability_blocked := DiscardToHandBlockHelper.is_discard_to_hand_blocked(1, state, "ability", processor)
	var attack_allowed := not DiscardToHandBlockHelper.is_discard_to_hand_blocked(1, state, "attack", processor)
	var own_recovery_allowed := not DiscardToHandBlockHelper.is_discard_to_hand_blocked(0, state, "trainer", processor)
	var filtered := DiscardToHandBlockHelper.filter_recoverable_discard_cards(1, state, state.players[1].discard_pile, "trainer", processor)

	state.players[0].bench[0].effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var disabled_allows_recovery := not DiscardToHandBlockHelper.is_discard_to_hand_blocked(1, state, "trainer", processor)

	state.players[0].bench[0].damage_counters = 50
	var heal := CSV9CSimpleHealSelfAfterAttack.new(30, 0)
	heal.execute_attack(state.players[0].bench[0], state.players[1].active_pokemon, 0, state)

	return run_checks([
		assert_true(trainer_blocked, "CSV5C_009 should block opponent Trainer effects that recover from discard to hand"),
		assert_true(ability_blocked, "CSV5C_009 should block opponent Ability effects that recover from discard to hand"),
		assert_true(attack_allowed, "CSV5C_009 should not block attack effects recovering from discard to hand"),
		assert_true(own_recovery_allowed, "CSV5C_009 should not block its controller's discard recovery"),
		assert_eq(filtered.size(), 0, "CSV5C_009 helper should expose no recoverable discard cards while blocked"),
		assert_true(disabled_allows_recovery, "CSV5C_009 should stop blocking while its Ability is disabled"),
		assert_eq(state.players[0].bench[0].damage_counters, 20, "CSV5C_009 attack should heal 30 damage after attacking"),
	])


func test_csv5c_009_toedscruel_blocks_real_discard_to_hand_effects() -> String:
	var state := _make_state()
	var toedscruel_cd := _make_pokemon_data("Toedscruel", "G", 120, "Stage 1", TOEDSCRUEL_ID)
	toedscruel_cd.abilities = [{"name": "Slime Mold Colony", "text": ""}]
	state.players[0].bench[0] = _make_slot(toedscruel_cd, 0)

	var processor := EffectProcessor.new()
	processor.register_effect(TOEDSCRUEL_ID, AbilityToedscruelSlimeMoldColony.new())
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var opponent := state.players[1]

	var night_target := CardInstance.create(_make_pokemon_data("Discard Pokemon", "C"), 1)
	opponent.discard_pile.append(night_target)
	var night_card := CardInstance.create(_make_trainer_data("Night Stretcher"), 1)
	var night := EffectNightStretcher.new()
	night.execute(night_card, [{"night_stretcher_choice": [night_target]}], state)

	var energy_target := CardInstance.create(_make_energy_data("Grass Energy", "G"), 1)
	opponent.discard_pile.append(energy_target)
	var retrieval_card := CardInstance.create(_make_trainer_data("Energy Retrieval"), 1)
	var retrieval := EffectRecoverBasicEnergy.new(2, 0)
	retrieval.execute(retrieval_card, [{"recover_energy": [energy_target]}], state)

	var lana_pokemon := CardInstance.create(_make_pokemon_data("Lana Target", "C"), 1)
	opponent.discard_pile.append(lana_pokemon)
	var lana_card := CardInstance.create(_make_trainer_data("Lana's Aid"), 1)
	var lana := EffectLanasAid.new(3)
	lana.execute(lana_card, [{EffectLanasAid.STEP_ID: [lana_pokemon]}], state)

	var ability_item := CardInstance.create(_make_trainer_data("Discard Item"), 1)
	opponent.discard_pile.append(ability_item)
	var ability_source := _make_slot(_make_pokemon_data("Ability Source", "C"), 1)
	opponent.active_pokemon = ability_source
	state.current_player_index = 1
	var ability := AbilityRecoverDiscardCardsToHandVSTAR.new(2, "Item")
	ability.execute_ability(ability_source, 0, [{"recover_cards": [ability_item]}], state)

	return run_checks([
		assert_true(night_target in opponent.discard_pile, "Toedscruel should block Night Stretcher from moving discard Pokemon to hand"),
		assert_false(night_target in opponent.hand, "Blocked Night Stretcher target must not enter hand"),
		assert_true(energy_target in opponent.discard_pile, "Toedscruel should block Energy Retrieval from moving discard Energy to hand"),
		assert_false(energy_target in opponent.hand, "Blocked Energy Retrieval target must not enter hand"),
		assert_true(lana_pokemon in opponent.discard_pile, "Toedscruel should block Lana's Aid from moving discard Pokemon to hand"),
		assert_false(lana_pokemon in opponent.hand, "Blocked Lana's Aid target must not enter hand"),
		assert_true(ability_item in opponent.discard_pile, "Toedscruel should block Ability discard recovery to hand"),
		assert_false(ability_item in opponent.hand, "Blocked Ability target must not enter hand"),
	])
