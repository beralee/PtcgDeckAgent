class_name AttackDiscardOwnBenchBasicEnergyBonusDamage
extends BaseEffect

const STEP_ID := "discard_own_bench_basic_energy"

var max_discard_count: int = 2
var bonus_per_energy: int = 90
var attack_index_to_match: int = -1


func _init(max_count: int = 2, bonus_damage: int = 90, match_attack_index: int = -1) -> void:
	max_discard_count = maxi(0, max_count)
	bonus_per_energy = maxi(0, bonus_damage)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	var card_groups: Array[Dictionary] = []
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var group_indices: Array[int] = []
		for energy: CardInstance in slot.attached_energy:
			if not _is_basic_energy(energy):
				continue
			group_indices.append(items.size())
			items.append(energy)
			labels.append("%s（%s）" % [energy.card_data.name, slot.get_pokemon_name()])
		if not group_indices.is_empty():
			card_groups.append({"slot": slot, "energy_indices": group_indices})
	if items.is_empty() or max_discard_count <= 0:
		return []
	return [{
		"id": STEP_ID,
		"title": "可将自己的备战宝可梦身上最多%d张基本能量放于弃牌区" % max_discard_count,
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(max_discard_count, items.size()),
		"allow_cancel": true,
		"force_confirm": true,
		"presentation": "cards",
		"card_items": items,
		"card_groups": card_groups,
		"transparent_battlefield_dialog": true,
	}]


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	return _selected_basic_bench_energy(attacker, state).size() * bonus_per_energy


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var selected := _selected_basic_bench_energy(attacker, state)
	for energy: CardInstance in selected:
		var source := _find_bench_source(player, energy)
		if source == null:
			continue
		source.attached_energy.erase(energy)
		player.discard_card(energy)
		_record_attack_effect_discarded_attached_energy(attacker, energy, state)


func _selected_basic_bench_energy(attacker: PokemonSlot, state: GameState) -> Array[CardInstance]:
	var selected: Array[CardInstance] = []
	if attacker == null or state == null or attacker.get_top_card() == null:
		return selected
	var player: PlayerState = state.players[attacker.get_top_card().owner_index]
	var raw: Variant = get_attack_interaction_context().get(STEP_ID, [])
	if not (raw is Array):
		return selected
	var seen_ids: Dictionary = {}
	for entry: Variant in raw:
		if not (entry is CardInstance):
			continue
		var energy := entry as CardInstance
		if seen_ids.has(energy.instance_id) or _find_bench_source(player, energy) == null:
			continue
		seen_ids[energy.instance_id] = true
		selected.append(energy)
		if selected.size() >= max_discard_count:
			break
	return selected


func _find_bench_source(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	if player == null or not _is_basic_energy(energy):
		return null
	for slot: PokemonSlot in player.bench:
		if slot != null and energy in slot.attached_energy:
			return slot
	return null


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for index: int in card.card_data.attacks.size():
		if card.card_data.attacks[index] == attack:
			return index
	return -1


func get_description() -> String:
	return "Discard up to %d Basic Energy from your Benched Pokemon; add %d damage for each card discarded." % [max_discard_count, bonus_per_energy]
