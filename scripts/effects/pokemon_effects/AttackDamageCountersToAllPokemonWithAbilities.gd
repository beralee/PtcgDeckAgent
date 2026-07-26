class_name AttackDamageCountersToAllPokemonWithAbilities
extends BaseEffect

const AbilityIgnoreEffectsScript := preload("res://scripts/effects/pokemon_effects/AbilityIgnoreEffects.gd")

var counter_count: int = 6
var attack_index_to_match: int = -1


func _init(count: int = 6, match_attack_index: int = -1) -> void:
	counter_count = maxi(0, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return
	var owner_index := top.owner_index
	for player_index: int in state.players.size():
		var player: PlayerState = state.players[player_index]
		for target: PokemonSlot in player.get_all_pokemon():
			if not _has_printed_ability(target):
				continue
			if player_index != owner_index and _opponent_effect_is_prevented(attacker, target, player, state):
				continue
			target.damage_counters += counter_count * 10
			_mark_attack_damage_counter_placement(target, state)


func _has_printed_ability(slot: PokemonSlot) -> bool:
	var card_data := slot.get_card_data() if slot != null else null
	return card_data != null and not card_data.abilities.is_empty()


func _opponent_effect_is_prevented(
	attacker: PokemonSlot,
	target: PokemonSlot,
	opponent: PlayerState,
	state: GameState
) -> bool:
	if target == null:
		return true
	if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
		return true
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		return bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state))
	return AbilityIgnoreEffectsScript.has_ignore_effects(target)


func get_description() -> String:
	return "Put %d damage counters on every Pokemon in play that has an Ability." % counter_count
