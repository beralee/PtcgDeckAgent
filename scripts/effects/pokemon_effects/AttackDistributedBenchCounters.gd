class_name AttackDistributedBenchCounters
extends BaseEffect

var total_damage: int = 60
var attack_index_to_match: int = -1


func _init(total: int = 60, match_attack_index: int = -1) -> void:
	total_damage = total
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var attacker := _find_slot_for_card(card, state)
	var opponent_bench: Array[PokemonSlot] = []
	for slot: PokemonSlot in state.players[1 - card.owner_index].bench:
		if not _is_attack_effect_prevented(slot, attacker, state):
			opponent_bench.append(slot)
	if opponent_bench.is_empty():
		return []
	var counter_count: int = total_damage / 10
	var target_items: Array = opponent_bench.duplicate()
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
		"allow_cancel": true,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var assignments_raw: Array = ctx.get("bench_damage_counters", [])
	for entry: Variant in assignments_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var target: Variant = assignment.get("target", null)
		var amount: int = int(assignment.get("amount", 10))
		if target is PokemonSlot and target in opponent.bench:
			if _is_attack_effect_prevented(target as PokemonSlot, attacker, state):
				continue
			var target_slot := target as PokemonSlot
			target_slot.damage_counters += max(0, amount)
			_mark_attack_damage_counter_placement(target_slot, state)


func _is_attack_effect_prevented(target: PokemonSlot, attacker: PokemonSlot, state: GameState) -> bool:
	if target == null:
		return true
	if AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
		return true
	if state == null:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		return bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state))
	return false


func _find_slot_for_card(card: CardInstance, state: GameState) -> PokemonSlot:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return null
	for slot: PokemonSlot in state.players[card.owner_index].get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return int(attack.get("_override_attack_index", -1))
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", -1))


func get_description() -> String:
	return "将%d个伤害指示物以任意方式分配到对方备战区宝可梦。" % (total_damage / 10)
