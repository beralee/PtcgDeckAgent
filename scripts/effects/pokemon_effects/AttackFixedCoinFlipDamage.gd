class_name AttackFixedCoinFlipDamage
extends BaseEffect

var coin_count: int = 3
var damage_per_heads: int = 10
var printed_base_damage: int = 10
var attack_index_to_match: int = -1
var coin_flipper: CoinFlipper = CoinFlipper.new()


func _init(
	count: int = 3,
	per_heads: int = 10,
	base_damage: int = 10,
	match_attack_index: int = -1,
	flipper: CoinFlipper = null
) -> void:
	coin_count = max(0, count)
	damage_per_heads = max(0, per_heads)
	printed_base_damage = max(0, base_damage)
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
	var heads := 0
	for _i: int in coin_count:
		if coin_flipper.flip():
			heads += 1
	var total_damage := heads * damage_per_heads
	var delta := total_damage - printed_base_damage
	if delta != 0:
		defender.damage_counters = max(0, defender.damage_counters + delta)


func get_description() -> String:
	return "Flip %d coins. This attack does %d damage for each heads." % [coin_count, damage_per_heads]
