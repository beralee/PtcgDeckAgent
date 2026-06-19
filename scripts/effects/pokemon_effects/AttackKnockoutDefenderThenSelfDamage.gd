class_name AttackKnockoutDefenderThenSelfDamage
extends BaseEffect

const ORDERED_KNOCKOUT_SLOT_IDS_FLAG := "_ordered_knockout_slot_ids"

var self_damage: int = 200
var attack_index_to_match: int = -1


func _init(damage_to_self: int = 200, match_attack_index: int = -1) -> void:
	self_damage = damage_to_self
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(attack_index):
		return
	var ordered_knockout_slot_ids: Array[int] = []
	if defender != null and not AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(defender, state):
		defender.damage_counters = defender.get_max_hp()
		ordered_knockout_slot_ids.append(int(defender.get_instance_id()))
	attacker.damage_counters += self_damage
	ordered_knockout_slot_ids.append(int(attacker.get_instance_id()))
	_append_ordered_knockout_slot_ids(state, ordered_knockout_slot_ids)


func _append_ordered_knockout_slot_ids(state: GameState, slot_ids: Array[int]) -> void:
	if state == null or slot_ids.is_empty():
		return
	var merged: Array[int] = []
	var raw_existing: Variant = state.shared_turn_flags.get(ORDERED_KNOCKOUT_SLOT_IDS_FLAG, [])
	if raw_existing is Array:
		for raw_id: Variant in raw_existing:
			var existing_id := int(raw_id)
			if existing_id not in merged:
				merged.append(existing_id)
	for slot_id: int in slot_ids:
		if slot_id not in merged:
			merged.append(slot_id)
	state.shared_turn_flags[ORDERED_KNOCKOUT_SLOT_IDS_FLAG] = merged


func get_description() -> String:
	return "Knock Out the Defending Pokemon, then deal damage to this Pokemon."
