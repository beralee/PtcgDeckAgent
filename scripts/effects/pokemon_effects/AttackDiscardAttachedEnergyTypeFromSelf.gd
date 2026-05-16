class_name AttackDiscardAttachedEnergyTypeFromSelf
extends BaseEffect

const STEP_ID := "discard_typed_attached_energy_from_self"

var energy_type: String = "L"
var discard_count: int = 1
var attack_index_to_match: int = -1


func _init(required_type: String = "L", count: int = 1, match_attack_index: int = -1) -> void:
	energy_type = required_type
	discard_count = count
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	if attacker == null:
		return []
	var matching: Array[CardInstance] = _matching_energy(attacker, state)
	if matching.is_empty():
		return []
	var required: int = _discard_limit(matching.size())
	if required <= 0 or required >= matching.size():
		return []
	var labels: Array[String] = []
	for energy: CardInstance in matching:
		labels.append(energy.card_data.name if energy.card_data != null else "")
	return [{
		"id": STEP_ID,
		"title": "Choose %d attached Energy to discard" % required,
		"items": matching,
		"labels": labels,
		"min_select": required,
		"max_select": required,
		"allow_cancel": false,
	}]


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
	var matching: Array[CardInstance] = _matching_energy(attacker, state)
	if matching.is_empty():
		return
	var limit: int = _discard_limit(matching.size())
	var selected: Array[CardInstance] = _selected_energy(matching, limit)
	if selected.is_empty():
		selected = matching.slice(0, limit)
	var player: PlayerState = state.players[top.owner_index]
	var kept: Array[CardInstance] = []
	for attached: CardInstance in attacker.attached_energy:
		if attached in selected:
			player.discard_pile.append(attached)
		else:
			kept.append(attached)
	attacker.attached_energy = kept


func _discard_limit(matching_count: int) -> int:
	if discard_count < 0:
		return matching_count
	return mini(discard_count, matching_count)


func _selected_energy(matching: Array[CardInstance], limit: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	for entry: Variant in selected_raw:
		var selected: CardInstance = null
		if entry is CardInstance:
			selected = entry
		elif entry is Dictionary:
			var instance_id := int((entry as Dictionary).get("instance_id", (entry as Dictionary).get("card_instance_id", -1)))
			for energy: CardInstance in matching:
				if energy.instance_id == instance_id:
					selected = energy
					break
		if selected != null and selected in matching and selected not in result:
			result.append(selected)
			if result.size() >= limit:
				break
	return result


func _matching_energy(attacker: PokemonSlot, state: GameState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for energy: CardInstance in attacker.attached_energy:
		if _matches_energy(energy, state):
			result.append(energy)
	return result


func _matches_energy(card: CardInstance, state: GameState) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	if energy_type == "":
		return true
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if processor != null and processor.has_method("get_energy_type"):
		var provided := str(processor.call("get_energy_type", card, state))
		return provided == energy_type or provided == "ANY"
	var cd: CardData = card.card_data
	return cd.energy_provides == energy_type or cd.energy_type == energy_type


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Discard matching attached Energy from this Pokemon."
