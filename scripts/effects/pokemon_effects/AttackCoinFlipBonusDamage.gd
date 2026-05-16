class_name AttackCoinFlipBonusDamage
extends BaseEffect

var bonus_damage: int = 20
var attack_index_to_match: int = -1
var coin_flipper: CoinFlipper = CoinFlipper.new()


func _init(bonus: int = 20, match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index
	if flipper != null:
		coin_flipper = flipper


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	_state: GameState
) -> void:
	if defender == null or not applies_to_attack_index(attack_index):
		return
	if coin_flipper.flip():
		defender.damage_counters += bonus_damage


func get_description() -> String:
	return "Flip a coin. If heads, this attack does more damage."
