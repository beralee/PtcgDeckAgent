class_name CSV9CSimpleHealOwnPokemon
extends BaseEffect

const STEP_ID := "csv9c_heal_own_pokemon"

var heal_amount: int = 30
var attack_index_to_match: int = -1


func _init(amount: int = 30, match_attack_index: int = -1) -> void:
	heal_amount = max(0, amount)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var candidates := _damaged_own_pokemon(player)
	if candidates.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "Choose one of your Pokemon to heal",
		"items": candidates,
		"labels": _target_labels(candidates),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var candidates := _damaged_own_pokemon(player)
	var target := _selected_target(candidates)
	if target == null and not get_attack_interaction_context().has(STEP_ID) and not candidates.is_empty():
		target = candidates[0]
	if target != null:
		target.damage_counters = maxi(0, target.damage_counters - heal_amount)


func _damaged_own_pokemon(player: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	if player == null:
		return result
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.damage_counters > 0:
			result.append(slot)
	return result


func _target_labels(targets: Array[PokemonSlot]) -> Array[String]:
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		labels.append("%s (%d damage)" % [slot.get_pokemon_name(), slot.damage_counters])
	return labels


func _selected_target(candidates: Array[PokemonSlot]) -> PokemonSlot:
	var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
	if raw.is_empty():
		return null
	if raw[0] is PokemonSlot and raw[0] in candidates:
		return raw[0]
	if raw[0] is Dictionary:
		var entry: Dictionary = raw[0]
		var instance_id := int(entry.get("slot_instance_id", entry.get("instance_id", -1)))
		for slot: PokemonSlot in candidates:
			if int(slot.get_instance_id()) == instance_id:
				return slot
	return null


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
	return "Heal one of your Pokemon."
