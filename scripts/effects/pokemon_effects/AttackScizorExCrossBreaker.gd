class_name AttackScizorExCrossBreaker
extends BaseEffect

const STEP_ID := "discard_scizor_metal_energy"


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index == 1


func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var attacker := state.players[card.owner_index].active_pokemon
	var legal := _metal_energy(attacker, state)
	var labels: Array[String] = []
	for energy: CardInstance in legal:
		labels.append(energy.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "Discard up to 2 Metal Energy from this Pokemon",
		"items": legal,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(2, legal.size()),
		"allow_cancel": true,
	}]


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var count := _selected(_metal_energy(attacker, state)).size()
	return (count - 1) * 120


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(attack_index) or attacker == null or attacker.get_top_card() == null:
		return
	var selected := _selected(_metal_energy(attacker, state))
	var player := state.players[attacker.get_top_card().owner_index]
	for energy: CardInstance in selected:
		attacker.attached_energy.erase(energy)
		player.discard_pile.append(energy)
		_record_attack_effect_discarded_attached_energy(attacker, energy, state)


func _selected(legal: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
		if entry is CardInstance and entry in legal and entry not in result:
			result.append(entry)
			if result.size() >= 2:
				break
	return result


func _metal_energy(attacker: PokemonSlot, state: GameState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if attacker == null:
		return result
	for energy: CardInstance in attacker.attached_energy:
		if energy == null or energy.card_data == null or not energy.card_data.is_energy():
			continue
		var provided := energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type
		if provided == "M":
			result.append(energy)
	return result


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", -1))
