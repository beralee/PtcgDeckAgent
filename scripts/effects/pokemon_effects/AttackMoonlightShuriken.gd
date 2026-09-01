## 月光手里剑 - 选择对手的2只宝可梦，各造成指定伤害（备战宝可梦不计算弱点、抗性）
class_name AttackMoonlightShuriken
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")

var snipe_damage: int = 90
var target_count: int = 2
var ignore_target_effects: bool = false
var ignore_weakness_resistance: bool = false
var attack_index_to_match: int = -1


func _init(
	damage: int = 90,
	count: int = 2,
	ignore_effects_on_targets: bool = false,
	ignore_weakness_and_resistance: bool = false
) -> void:
	snipe_damage = damage
	target_count = count
	ignore_target_effects = ignore_effects_on_targets
	ignore_weakness_resistance = ignore_weakness_and_resistance


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index_to_match == attack_index


func ignores_weakness_and_resistance(_attacker: PokemonSlot, _state: GameState, attack_index: int) -> bool:
	return ignore_weakness_resistance and applies_to_attack_index(attack_index)


func ignores_defender_effects(_attacker: PokemonSlot, _state: GameState, attack_index: int) -> bool:
	return ignore_target_effects and applies_to_attack_index(attack_index)


func build_ucis_attack_interaction_steps_spec_steps(
	_card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - state.current_player_index]
	var items: Array = opponent.get_all_pokemon()
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(slot.get_pokemon_name())
	var select_count: int = mini(target_count, items.size())
	if select_count <= 0:
		return []
	return [{
		"id": "moonlight_shuriken_targets",
		"title": "选择对手的%d只宝可梦" % select_count,
		"items": items,
		"labels": labels,
		"min_select": select_count,
		"max_select": select_count,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var all_opp: Array = opponent.get_all_pokemon()

	var targets: Array[PokemonSlot] = []
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("moonlight_shuriken_targets", [])
	for item: Variant in selected_raw:
		if item is PokemonSlot and item in all_opp and item not in targets:
			targets.append(item)

	# 回退：如果没有有效选择，自动选前N个
	if targets.size() < target_count:
		targets.clear()
		for slot: PokemonSlot in all_opp:
			if targets.size() >= target_count:
				break
			targets.append(slot)

	for target: PokemonSlot in targets:
		if _is_target_damage_prevented(target, attacker, opponent, state):
			continue
		target.damage_counters += _calculate_damage_for_target(attacker, target, state)


func _is_target_damage_prevented(
	target: PokemonSlot,
	attacker: PokemonSlot,
	opponent: PlayerState,
	state: GameState
) -> bool:
	if ignore_target_effects:
		return false
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return true
	if target != opponent.active_pokemon and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
		return true
	return AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state)


func _calculate_damage_for_target(attacker: PokemonSlot, target: PokemonSlot, state: GameState) -> int:
	if not ignore_target_effects and not ignore_weakness_resistance:
		return _calculate_attack_target_damage(attacker, target, snipe_damage, state)
	if not _is_opponent_active_target(attacker, target, state):
		return snipe_damage
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	var attacker_modifier := 0
	if processor != null and processor.has_method("get_attacker_modifier"):
		attacker_modifier = int(processor.call("get_attacker_modifier", attacker, state, target))
	var defender_modifier := 0
	if not ignore_target_effects and processor != null and processor.has_method("get_defender_modifier"):
		defender_modifier = int(processor.call("get_defender_modifier", target, state, attacker))
	return DamageCalculator.new().calculate_damage(
		attacker,
		target,
		{"damage": str(snipe_damage)},
		state,
		0,
		attacker_modifier,
		defender_modifier,
		ignore_weakness_resistance,
		ignore_weakness_resistance
	)


func get_description() -> String:
	return "选择对手的%d只宝可梦，各造成%d伤害" % [target_count, snipe_damage]
