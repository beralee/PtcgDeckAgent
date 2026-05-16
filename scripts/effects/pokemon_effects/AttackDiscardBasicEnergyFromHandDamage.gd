## Discard any number of Basic Energy cards from hand. Damage scales with the discard count.
class_name AttackDiscardBasicEnergyFromHandDamage
extends BaseEffect

var damage_per_card: int = 50


func _init(damage: int = 50) -> void:
	damage_per_card = damage


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if not _is_basic_energy(hand_card):
			continue
		items.append(hand_card)
		labels.append(hand_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": "discard_basic_energy",
		"title": "选择要弃置的基本能量",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": items.size(),
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
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var discarded_cards: Array[CardInstance] = _selected_basic_energy_from_context(ctx, player)
	discarded_cards = _discard_cards_from_hand_with_log(state, top.owner_index, discarded_cards, top, "attack")


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null:
		return -damage_per_card
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return -damage_per_card
	var player: PlayerState = state.players[top.owner_index]
	var selected_cards: Array[CardInstance] = _selected_basic_energy_from_context(get_attack_interaction_context(), player)
	return (selected_cards.size() - 1) * damage_per_card


func _selected_basic_energy_from_context(ctx: Dictionary, player: PlayerState) -> Array[CardInstance]:
	var selected: Array[CardInstance] = []
	if player == null:
		return selected
	if ctx.has("discard_basic_energy"):
		var selected_raw: Array = ctx.get("discard_basic_energy", [])
		for entry: Variant in selected_raw:
			if not entry is CardInstance:
				continue
			var selected_card: CardInstance = entry
			if selected_card in selected:
				continue
			if selected_card in player.hand and _is_basic_energy(selected_card):
				selected.append(selected_card)
		return selected
	for hand_card: CardInstance in player.hand:
		if _is_basic_energy(hand_card):
			selected.append(hand_card)
	return selected


func _is_basic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy"


func get_description() -> String:
	return "Discard any number of Basic Energy cards from your hand. This attack does %d damage for each card discarded." % damage_per_card
