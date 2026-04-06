## 备战区放置伤害指示物效果 - 将伤害指示物分配给对方备战宝可梦
## 适用: 振翼发"飞来横祸"(对对方备战区放置2个伤害指示物)
## 参数: damage_counters_total
class_name AttackBenchDamageCounters
extends BaseEffect

## 要分配的伤害指示物总量（以伤害计，10=1个指示物）
var damage_counters_total: int = 120


func _init(total: int = 120) -> void:
	damage_counters_total = total


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var opp_pi: int = 1 - card.owner_index
	var opp_bench: Array[PokemonSlot] = state.players[opp_pi].bench
	if opp_bench.is_empty():
		return []
	var counter_count: int = damage_counters_total / 10
	var target_items: Array = opp_bench.duplicate()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())
	return [{
		"id": "bench_damage_counters",
		"title": "将%d个伤害指示物分配到对方备战区宝可梦" % counter_count,
		"ui_mode": "counter_distribution",
		"total_counters": counter_count,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": counter_count,
		"max_select": counter_count,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var opp_pi: int = 1 - pi
	var opp_player: PlayerState = state.players[opp_pi]

	if opp_player.bench.is_empty():
		return

	var ctx: Dictionary = get_attack_interaction_context()
	var assignments_raw: Array = ctx.get("bench_damage_counters", [])
	if not assignments_raw.is_empty():
		for entry: Variant in assignments_raw:
			if not (entry is Dictionary):
				continue
			var assignment: Dictionary = entry
			var target: Variant = assignment.get("target", null)
			var amount: int = int(assignment.get("amount", 10))
			if target is PokemonSlot and target in opp_player.bench:
				(target as PokemonSlot).damage_counters += max(0, amount)
		return

	# 无交互上下文时的后备：均匀分配
	var remaining: int = damage_counters_total
	var bench_count: int = opp_player.bench.size()
	var idx: int = 0
	while remaining > 0 and bench_count > 0:
		var chunk: int = min(10, remaining)
		opp_player.bench[idx % bench_count].damage_counters += chunk
		remaining -= chunk
		idx += 1


func get_description() -> String:
	return "对对方备战区分配%d个伤害指示物" % (damage_counters_total / 10)
