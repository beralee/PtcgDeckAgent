class_name EffectBenchDamage
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")

var bench_damage: int = 20
var target_all: bool = false
var target_side: String = "opponent"


func _init(damage: int = 20, all_bench: bool = false, side: String = "opponent") -> void:
	bench_damage = damage
	target_all = all_bench
	target_side = side


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var pi: int = attacker.get_top_card().owner_index
	var target_pi: int = 1 - pi if target_side == "opponent" else pi
	var target_player: PlayerState = state.players[target_pi]

	if target_all:
		for slot: PokemonSlot in target_player.bench:
			if _is_opponent_bench_damage_blocked(attacker, slot, state):
				continue
			slot.damage_counters += bench_damage
		return

	if target_player.bench.is_empty():
		return
	var target_slot: PokemonSlot = target_player.bench[0]
	if _is_opponent_bench_damage_blocked(attacker, target_slot, state):
		return
	target_slot.damage_counters += bench_damage


func _is_opponent_bench_damage_blocked(attacker: PokemonSlot, target: PokemonSlot, state: GameState) -> bool:
	if target_side != "opponent":
		return false
	if AbilityBenchImmune.has_bench_immune(target):
		return true
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return true
	return AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state)


func get_description() -> String:
	var side_str: String = "opponent" if target_side == "opponent" else "your"
	if target_all:
		return "Deal %d damage to all %s Benched Pokemon." % [bench_damage, side_str]
	return "Deal %d damage to 1 %s Benched Pokemon." % [bench_damage, side_str]
