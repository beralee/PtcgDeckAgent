class_name AttackCoinFlipOrFailAndSelfAllAttacksLock
extends BaseEffect

var base_damage: int = 200
var attack_index_to_match: int = -1
var coin_flipper: CoinFlipper = null
var _pending_flip_results: Dictionary = {}


func _init(
	damage: int = 200,
	match_attack_index: int = -1,
	flipper: CoinFlipper = null
) -> void:
	base_damage = damage
	attack_index_to_match = match_attack_index
	coin_flipper = flipper


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func cancels_attack_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> bool:
	if not applies_to_attack_index(attack_index):
		return false
	var result_key := _result_key(attacker, defender, attack_index, state)
	var is_heads := _flip()
	if result_key != "":
		_pending_flip_results[result_key] = is_heads
	return not is_heads


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var result_key := _result_key(attacker, defender, attack_index, state)
	var is_heads: bool
	if result_key != "" and _pending_flip_results.has(result_key):
		is_heads = bool(_pending_flip_results.get(result_key, false))
		_pending_flip_results.erase(result_key)
	else:
		is_heads = _flip()
	if not is_heads:
		return
	AttackSelfAllAttacksLockNextTurn.new(attack_index_to_match).execute_attack(
		attacker,
		defender,
		attack_index,
		state
	)


func _flip() -> bool:
	var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
	return flipper.flip()


func _result_key(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> String:
	if attacker == null or defender == null or state == null:
		return ""
	if attacker.get_top_card() == null or defender.get_top_card() == null:
		return ""
	return "%d:%d:%d:%d" % [
		int(attacker.get_top_card().instance_id),
		int(defender.get_top_card().instance_id),
		attack_index,
		state.turn_number,
	]


func get_description() -> String:
	return "Flip a coin. If tails, this attack does no damage. If heads, this Pokemon cannot use attacks during your next turn."
