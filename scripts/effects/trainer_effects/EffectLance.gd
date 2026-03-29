## Lance - search your deck for up to 3 Dragon Pokemon and put them into your hand.
class_name EffectLance
extends BaseEffect

const DRAGON_TYPE: String = "N"
const MAX_SEARCH_COUNT: int = 3


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		if _is_dragon_pokemon(deck_card):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if not _is_dragon_pokemon(deck_card):
			continue
		items.append(deck_card)
		labels.append(deck_card.card_data.name)
	return [{
		"id": "dragon_pokemon",
		"title": "Choose up to 3 Dragon Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(MAX_SEARCH_COUNT, items.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("dragon_pokemon", [])
	var has_explicit_selection: bool = ctx.has("dragon_pokemon")
	var found: Array[CardInstance] = []

	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected: CardInstance = entry
		if selected in player.deck and _is_dragon_pokemon(selected) and selected not in found:
			found.append(selected)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	if found.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if not _is_dragon_pokemon(deck_card):
				continue
			found.append(deck_card)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	for found_card: CardInstance in found:
		player.deck.erase(found_card)
	for found_card: CardInstance in found:
		found_card.face_up = true
		player.hand.append(found_card)

	player.shuffle_deck()


func _is_dragon_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_pokemon() and card.card_data.energy_type == DRAGON_TYPE


func get_description() -> String:
	return "Search your deck for up to 3 Dragon Pokemon."
