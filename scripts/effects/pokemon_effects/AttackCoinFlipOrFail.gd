class_name AttackCoinFlipOrFail
extends BaseEffect

var base_damage: int = 60
var fail_action: String = "no_damage"
var coin_flipper: CoinFlipper = null
var _pending_flip_results: Dictionary = {}


func _init(base_dmg: int = 60, action: String = "no_damage", flipper: CoinFlipper = null) -> void:
	base_damage = base_dmg
	fail_action = action
	coin_flipper = flipper


func cancels_attack_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> bool:
	var result_key := _result_key(attacker, defender, attack_index, state)
	var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
	var is_heads: bool = flipper.flip()
	if result_key != "":
		_pending_flip_results[result_key] = is_heads
	return not is_heads and fail_action == "no_damage"


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	var result_key := _result_key(attacker, defender, attack_index, state)
	var has_cached_result := result_key != "" and _pending_flip_results.has(result_key)
	var is_heads: bool
	if has_cached_result:
		is_heads = bool(_pending_flip_results.get(result_key, true))
		_pending_flip_results.erase(result_key)
	else:
		var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
		is_heads = flipper.flip()

	if is_heads:
		return

	if fail_action == "no_damage":
		if has_cached_result:
			return
		defender.damage_counters = maxi(0, defender.damage_counters - base_damage)
	elif fail_action == "half_damage":
		var undo_amount: int = base_damage / 2
		defender.damage_counters = maxi(0, defender.damage_counters - undo_amount)


func get_description() -> String:
	if fail_action == "no_damage":
		return "投币，反面时此招式伤害无效"
	return "投币，反面时此招式伤害减半"


func _result_key(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> String:
	if attacker == null or defender == null or attacker.get_top_card() == null or defender.get_top_card() == null or state == null:
		return ""
	return "%d:%d:%d:%d" % [
		int(attacker.get_top_card().instance_id),
		int(defender.get_top_card().instance_id),
		attack_index,
		state.turn_number,
	]
