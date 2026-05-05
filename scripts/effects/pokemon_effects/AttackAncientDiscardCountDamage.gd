## Roaring Moon - add damage for each Ancient card in the attacker's discard pile.
class_name AttackAncientDiscardCountDamage
extends BaseEffect

var damage_per_ancient_card: int = 10
var attack_index_to_match: int = -1


func _init(per_card: int = 10, match_attack_index: int = -1) -> void:
	damage_per_ancient_card = per_card
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var owner_index: int = attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var ancient_count := 0
	for discard_card: CardInstance in state.players[owner_index].discard_pile:
		if discard_card.card_data != null and discard_card.card_data.has_tag(CardData.ANCIENT_TAG):
			ancient_count += 1
	return ancient_count * damage_per_ancient_card


func get_description() -> String:
	return "This attack does %d more damage for each Ancient card in your discard pile." % damage_per_ancient_card
