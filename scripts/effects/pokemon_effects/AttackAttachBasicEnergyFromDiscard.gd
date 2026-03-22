class_name AttackAttachBasicEnergyFromDiscard
extends BaseEffect

const ENERGY_STEP_ID := "discard_energy"
const TARGET_STEP_ID := "attach_target"

var energy_type: String = ""
var max_count: int = 2
var target_filter: String = "self"


func _init(required_type: String = "", count: int = 2, target_mode: String = "self") -> void:
	energy_type = required_type
	max_count = count
	target_filter = target_mode


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if _matches_energy(discard_card):
			energy_items.append(discard_card)
			energy_labels.append(discard_card.card_data.name)
	if energy_items.is_empty():
		return []

	var target_items: Array = _get_target_items(player, card)
	if target_items.is_empty():
		return []
	var target_labels: Array[String] = []
	for target_slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			target_slot.get_pokemon_name(),
			target_slot.get_remaining_hp(),
			target_slot.get_max_hp(),
		])

	return [
		{
			"id": ENERGY_STEP_ID,
			"title": "选择最多%d张要附着的基本能量" % mini(max_count, energy_items.size()),
			"items": energy_items,
			"labels": energy_labels,
			"min_select": 0,
			"max_select": mini(max_count, energy_items.size()),
			"allow_cancel": true,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "选择要附着能量的宝可梦",
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
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var target_slot: PokemonSlot = _resolve_target_slot(player, attacker, ctx.get(TARGET_STEP_ID, []))
	if target_slot == null:
		return

	var selected_energy: Array[CardInstance] = _resolve_selected_energy(player, ctx.get(ENERGY_STEP_ID, []))
	if selected_energy.is_empty():
		selected_energy = _fallback_energy(player)

	for discard_card: CardInstance in selected_energy:
		player.discard_pile.erase(discard_card)
		target_slot.attached_energy.append(discard_card)


func _resolve_target_slot(player: PlayerState, attacker: PokemonSlot, selected_raw: Array) -> PokemonSlot:
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected: PokemonSlot = selected_raw[0]
		if selected in _get_target_items(player, attacker.get_top_card()):
			return selected
	var fallback_targets: Array = _get_target_items(player, attacker.get_top_card())
	return fallback_targets[0] if not fallback_targets.is_empty() else null


func _resolve_selected_energy(player: PlayerState, selected_raw: Array) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected: CardInstance = entry as CardInstance
		if selected not in player.discard_pile or not _matches_energy(selected) or selected in result:
			continue
		result.append(selected)
		if result.size() >= max_count:
			break
	return result


func _fallback_energy(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for discard_card: CardInstance in player.discard_pile:
		if not _matches_energy(discard_card):
			continue
		result.append(discard_card)
		if result.size() >= max_count:
			break
	return result


func _matches_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if card.card_data.card_type != "Basic Energy":
		return false
	if energy_type == "":
		return true
	return card.card_data.energy_provides == energy_type or card.card_data.energy_type == energy_type


func _get_target_items(player: PlayerState, card: CardInstance) -> Array:
	var items: Array = []
	match target_filter:
		"own_bench":
			for slot: PokemonSlot in player.bench:
				items.append(slot)
		_:
			for slot: PokemonSlot in player.get_all_pokemon():
				if slot.get_top_card() == card:
					items.append(slot)
					break
	return items


func get_description() -> String:
	return "Attach Basic Energy from your discard pile to this Pokemon."
