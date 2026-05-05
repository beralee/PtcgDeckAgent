class_name AttackAttachBasicEnergyFromHandToOwnPokemon
extends BaseEffect

const ENERGY_STEP_ID := "hand_basic_energy"
const TARGET_STEP_ID := "attach_target"

var energy_type: String = ""
var attach_count: int = 1
var attack_index_to_match: int = -1


func _init(required_type: String = "", count: int = 1, match_attack_index: int = -1) -> void:
	energy_type = required_type
	attach_count = max(1, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if _matches_energy(hand_card):
			energy_items.append(hand_card)
			energy_labels.append(hand_card.card_data.name)
	if energy_items.is_empty():
		return []
	var target_items: Array = player.get_all_pokemon()
	if target_items.is_empty():
		return []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])
	var max_select := mini(attach_count, energy_items.size())
	return [
		{
			"id": ENERGY_STEP_ID,
			"title": "选择要附着的基本能量",
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 1,
			"max_select": max_select,
			"allow_cancel": true,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "选择要附着能量的自己的宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


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
	var ctx: Dictionary = get_attack_interaction_context()
	var target_slot: PokemonSlot = _first_valid_target(ctx.get(TARGET_STEP_ID, []), player)
	if target_slot == null:
		target_slot = player.active_pokemon
	if target_slot == null:
		return
	var selected_energy: Array[CardInstance] = _resolve_selected_energy(ctx.get(ENERGY_STEP_ID, []), player)
	if selected_energy.is_empty():
		selected_energy = _fallback_energy(player)
	for energy: CardInstance in selected_energy:
		player.hand.erase(energy)
		target_slot.attached_energy.append(energy)


func _resolve_selected_energy(raw: Array, player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in raw:
		if entry is CardInstance and entry in player.hand and _matches_energy(entry) and entry not in result:
			result.append(entry as CardInstance)
			if result.size() >= attach_count:
				break
	return result


func _fallback_energy(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for hand_card: CardInstance in player.hand:
		if not _matches_energy(hand_card):
			continue
		result.append(hand_card)
		if result.size() >= attach_count:
			break
	return result


func _first_valid_target(raw: Array, player: PlayerState) -> PokemonSlot:
	var own_slots: Array = player.get_all_pokemon()
	for entry: Variant in raw:
		if entry is PokemonSlot and entry in own_slots:
			return entry as PokemonSlot
	return null


func _matches_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if card.card_data.card_type != "Basic Energy":
		return false
	if energy_type == "":
		return true
	return card.card_data.energy_provides == energy_type or card.card_data.energy_type == energy_type


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
	return "Attach Basic Energy from your hand to 1 of your Pokemon."
