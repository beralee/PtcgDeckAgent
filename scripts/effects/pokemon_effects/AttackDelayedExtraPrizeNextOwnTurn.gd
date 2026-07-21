## Marks the Defending Pokemon so a knockout during the attacker's next turn
## awards additional Prize cards.
class_name AttackDelayedExtraPrizeNextOwnTurn
extends BaseEffect

var extra_prizes: int = 2
var attack_index_to_match: int = -1


func _init(extra: int = 2, match_attack_index: int = -1) -> void:
	extra_prizes = maxi(0, extra)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or defender == null or state == null or not applies_to_attack_index(attack_index):
		return
	var attacker_card := attacker.get_top_card()
	var defender_card := defender.get_top_card()
	if attacker_card == null or defender_card == null:
		return
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
			return

	var kept: Array[Dictionary] = []
	for effect: Dictionary in defender.effects:
		if (
			effect.get("type", "") == PokemonSlot.DELAYED_EXTRA_PRIZE_EFFECT_TYPE
			and int(effect.get("source_owner", -1)) == attacker_card.owner_index
		):
			continue
		kept.append(effect)
	kept.append({
		"type": PokemonSlot.DELAYED_EXTRA_PRIZE_EFFECT_TYPE,
		"count": extra_prizes,
		"source_owner": attacker_card.owner_index,
		"applied_turn": state.turn_number,
		"active_turn": -1,
		"target_card_instance_id": defender_card.instance_id,
	})
	defender.effects = kept


func get_description() -> String:
	return "During your next turn, if the affected Pokemon is Knocked Out, take %d more Prize cards." % extra_prizes
