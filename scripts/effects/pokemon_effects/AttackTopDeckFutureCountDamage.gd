class_name AttackTopDeckFutureCountDamage
extends BaseEffect

var reveal_count: int = 5
var damage_per_future: int = 70
var printed_damage_unit: int = 70
var attack_index_to_match: int = -1


func _init(count: int = 5, per_future: int = 70, printed_unit: int = 70, match_attack_index: int = -1) -> void:
	reveal_count = max(0, count)
	damage_per_future = max(0, per_future)
	printed_damage_unit = max(0, printed_unit)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var player := _get_attacking_player(attacker, state)
	if player == null:
		return -printed_damage_unit
	var future_count := 0
	var max_reveal := mini(reveal_count, player.deck.size())
	for i: int in max_reveal:
		var card: CardInstance = player.deck[i]
		if _is_future_card(card):
			future_count += 1
	return future_count * damage_per_future - printed_damage_unit


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var player := _get_attacking_player(attacker, state)
	if player == null:
		return
	var to_reveal := mini(reveal_count, player.deck.size())
	if to_reveal <= 0:
		return
	var revealed: Array[CardInstance] = []
	for _i: int in to_reveal:
		var card: CardInstance = player.deck.pop_front()
		card.face_up = true
		revealed.append(card)
	for card: CardInstance in revealed:
		if _is_future_card(card):
			player.discard_pile.append(card)
		else:
			card.face_up = false
			player.deck.append(card)
	player.shuffle_deck()


func _get_attacking_player(attacker: PokemonSlot, state: GameState) -> PlayerState:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return null
	var owner_index := attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return null
	return state.players[owner_index]


func _is_future_card(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.has_tag(CardData.FUTURE_TAG)


func get_description() -> String:
	return "Reveal the top %d cards of your deck. This attack does %d damage for each Future card revealed. Discard those Future cards and shuffle the rest into your deck." % [reveal_count, damage_per_future]
