class_name AttackGreatTuskLandCollapse
extends BaseEffect

const BASE_MILL := 1
const ANCIENT_SUPPORTER_EXTRA_MILL := 3
const ANCIENT_SUPPORTER_FLAG_PREFIX := "ancient_supporter_played_turn_"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	if attacker == null or attacker.get_top_card() == null or state == null:
		return
	var owner_index: int = attacker.get_top_card().owner_index
	var opponent_index: int = 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var mill_count := BASE_MILL
	var flag_key := "%s%d" % [ANCIENT_SUPPORTER_FLAG_PREFIX, owner_index]
	if int(state.shared_turn_flags.get(flag_key, -999)) == state.turn_number:
		mill_count += ANCIENT_SUPPORTER_EXTRA_MILL
	var opponent: PlayerState = state.players[opponent_index]
	for _i: int in range(mini(mill_count, opponent.deck.size())):
		var milled: CardInstance = opponent.deck.pop_front()
		milled.face_up = true
		opponent.discard_pile.append(milled)


func get_description() -> String:
	return "Discard 1 card from the top of your opponent's deck, plus 3 more if you played an Ancient Supporter this turn."
