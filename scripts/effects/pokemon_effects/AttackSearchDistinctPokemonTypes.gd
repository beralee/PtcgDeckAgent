class_name AttackSearchDistinctPokemonTypes
extends BaseEffect

const STEP_ID := "colorful_friends"

var search_count: int = 3
var attack_index_to_match: int = -1


func _init(count: int = 3, match_attack_index: int = -1) -> void:
	search_count = maxi(0, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var candidates := _pokemon_cards(player.deck)
	if candidates.is_empty():
		return []
	var step := build_full_library_search_step(
		STEP_ID,
		"从牌库中选择最多3张属性各不相同的宝可梦",
		player.deck,
		candidates,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(search_count, candidates.size()),
		{"allow_cancel": true}
	)
	step["distinct_by"] = "pokemon_energy_type"
	return [step]


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
	var ctx := get_attack_interaction_context()
	var explicit_selection := ctx.has(STEP_ID)
	var raw: Array = ctx.get(STEP_ID, [])
	if not explicit_selection:
		raw = _pokemon_cards(player.deck)
	var selected: Array[CardInstance] = []
	var used_types: Dictionary = {}
	for entry: Variant in raw:
		if not (entry is CardInstance):
			continue
		var candidate := entry as CardInstance
		if candidate not in player.deck or not _is_pokemon(candidate):
			continue
		var pokemon_type := _pokemon_type(candidate)
		if pokemon_type == "" or used_types.has(pokemon_type):
			continue
		used_types[pokemon_type] = true
		selected.append(candidate)
		if selected.size() >= search_count:
			break
	_move_public_cards_to_hand_with_log(state, top.owner_index, selected, top, "attack", "search_to_hand")
	player.shuffle_deck()


func _pokemon_cards(cards: Array[CardInstance]) -> Array:
	var result: Array = []
	for card: CardInstance in cards:
		if _is_pokemon(card):
			result.append(card)
	return result


func _is_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_pokemon()


func _pokemon_type(card: CardInstance) -> String:
	return str(card.card_data.energy_type).strip_edges().to_upper() if _is_pokemon(card) else ""


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
	return "Search your deck for up to 3 Pokemon of different types and put them into your hand."
