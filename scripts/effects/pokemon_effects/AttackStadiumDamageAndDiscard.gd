extends "res://scripts/effects/pokemon_effects/AttackDiscardStadium.gd"

## Mandatory Stadium-conditioned damage. Damage resolves while the Stadium is
## still in play; only then is it discarded. There is no optional payment.
var damage_bonus: int = 0
var bench_damage: int = 0


func _init(bonus: int = 0, splash: int = 0, match_attack_index: int = -1) -> void:
	super(match_attack_index)
	damage_bonus = bonus
	bench_damage = splash


func get_damage_bonus(_attacker: PokemonSlot, state: GameState) -> int:
	return damage_bonus if state != null and state.stadium_card != null else 0


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index) or state == null or state.stadium_card == null:
		return
	if bench_damage > 0:
		# Reuse the shared all-Bench damage protections and no-weakness/resistance
		# semantics before removing any Stadium that may affect those protections.
		EffectBenchDamage.new(bench_damage, true, "opponent").execute_attack(
			attacker, defender, attack_index, state)
	super.execute_attack(attacker, defender, attack_index, state)


func get_description() -> String:
	return "If a Stadium is in play, add %d damage and deal %d damage to each opposing Benched Pokemon, then discard the Stadium." % [damage_bonus, bench_damage]
