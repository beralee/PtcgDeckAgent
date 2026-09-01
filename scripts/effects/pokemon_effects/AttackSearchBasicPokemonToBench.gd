class_name AttackSearchBasicPokemonToBench
extends BaseEffect

const BenchLimit := preload("res://scripts/engine/BenchLimitHelper.gd")
const STEP_ID := "bombirdier_fast_carrier"

var max_count: int = 3
var attack_index_to_match: int = -1
var required_names: PackedStringArray = PackedStringArray()


func _init(
	count: int = 3,
	match_attack_index: int = -1,
	matching_names: PackedStringArray = PackedStringArray()
) -> void:
	max_count = maxi(0, count)
	attack_index_to_match = match_attack_index
	required_names = matching_names.duplicate()


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player := state.players[card.owner_index]
	var available := mini(max_count, BenchLimit.get_available_bench_space(state, player))
	if available <= 0:
		return []
	var legal := _legal_cards(player)
	var target_label := _search_target_label()
	return [build_full_library_search_step(
		STEP_ID,
		"Choose up to %d %s to put onto your Bench" % [available, target_label],
		player.deck,
		legal,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(available, legal.size()),
		{"allow_cancel": true, "force_confirm": true}
	)]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
		return
	var player := state.players[attacker.get_top_card().owner_index]
	var available := mini(max_count, BenchLimit.get_available_bench_space(state, player))
	var legal := _legal_cards(player)
	var chosen: Array[CardInstance] = []
	var context := get_attack_interaction_context()
	for raw: Variant in context.get(STEP_ID, []):
		if raw is CardInstance and raw in legal and raw not in chosen:
			chosen.append(raw)
			if chosen.size() >= available:
				break
	if chosen.is_empty() and not context.has(STEP_ID):
		chosen.assign(legal.slice(0, mini(available, legal.size())))
	for pokemon: CardInstance in chosen:
		if pokemon not in player.deck or BenchLimit.is_bench_full(state, player):
			continue
		player.deck.erase(pokemon)
		pokemon.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(pokemon)
		slot.turn_played = state.turn_number
		player.bench.append(slot)
	player.shuffle_deck()


func get_description() -> String:
	return "Search your deck for up to %d %s, put them onto your Bench, then shuffle your deck." % [
		max_count,
		_search_target_label(),
	]


func _legal_cards(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in player.deck:
		if (
			card != null
			and card.card_data != null
			and card.card_data.is_basic_pokemon()
			and _matches_required_name(card.card_data)
		):
			result.append(card)
	return result


func _matches_required_name(card_data: CardData) -> bool:
	if required_names.is_empty():
		return true
	for required_name: String in required_names:
		if card_data.matches_rule_identity_name(required_name):
			return true
	return false


func _search_target_label() -> String:
	if required_names.is_empty():
		return "Basic Pokemon"
	return "Basic Pokemon named %s" % " / ".join(required_names)


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for index: int in card.card_data.attacks.size():
		if card.card_data.attacks[index] == attack:
			return index
	return -1
