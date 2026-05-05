class_name AttackSearchEnergyFromDeckToSelf
extends BaseEffect

const STEP_ID := "deck_energy"

var energy_type: String = ""
var max_count: int = 1


func _init(required_type: String = "", count: int = 1) -> void:
	energy_type = required_type
	max_count = count


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	for deck_card: CardInstance in player.deck:
		if _matches_energy(deck_card):
			items.append(deck_card)
	if items.is_empty():
		return []
	return [build_full_library_search_step(
		STEP_ID,
		"选择最多%d张要附着的能量" % mini(max_count, items.size()),
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		mini(max_count, items.size()),
		{"allow_cancel": true}
	)]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if attacker == null or attacker.get_top_card() == null:
		return
	var player: PlayerState = state.players[attacker.get_top_card().owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected: Array[CardInstance] = _resolve_selected_energy(player, ctx.get(STEP_ID, []))
	if selected.is_empty():
		selected = _fallback_selection(player)
	if selected.is_empty():
		player.shuffle_deck()
		return

	for energy_card: CardInstance in selected:
		player.deck.erase(energy_card)
		energy_card.face_up = true
		attacker.attached_energy.append(energy_card)
	player.shuffle_deck()


func _resolve_selected_energy(player: PlayerState, selected_raw: Array) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected: CardInstance = entry as CardInstance
		if selected not in player.deck or not _matches_energy(selected) or selected in result:
			continue
		result.append(selected)
		if result.size() >= max_count:
			break
	return result


func _fallback_selection(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for deck_card: CardInstance in player.deck:
		if not _matches_energy(deck_card):
			continue
		result.append(deck_card)
		if result.size() >= max_count:
			break
	return result


func _matches_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	if energy_type == "":
		return true
	return (
		card.card_data.energy_provides == energy_type
		or card.card_data.energy_type == energy_type
	)


func get_description() -> String:
	return "从牌库选择能量附着到这只宝可梦。"
