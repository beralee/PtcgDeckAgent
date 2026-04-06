## 月光手里剑 - 选择对手的2只宝可梦，各造成指定伤害（备战宝可梦不计算弱点、抗性）
class_name AttackMoonlightShuriken
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")

var snipe_damage: int = 90
var target_count: int = 2


func _init(damage: int = 90, count: int = 2) -> void:
	snipe_damage = damage
	target_count = count


func get_attack_interaction_steps(
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
		if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			continue
		if AbilityBenchImmune.has_bench_immune(target) and target != opponent.active_pokemon:
			continue
		if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
			continue
		target.damage_counters += snipe_damage


func get_description() -> String:
	return "选择对手的%d只宝可梦，各造成%d伤害" % [target_count, snipe_damage]
