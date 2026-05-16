class_name AttackOwnFieldTaggedPokemonCountDamage
extends BaseEffect

var tag_filter: String = CardData.ANCIENT_TAG
var damage_per_pokemon: int = 30
var replaces_printed_multiplier_base: bool = true
var attack_index_to_match: int = -1


func _init(
	required_tag: String = CardData.ANCIENT_TAG,
	per_pokemon: int = 30,
	replace_printed_base: bool = true,
	match_attack_index: int = -1
) -> void:
	tag_filter = required_tag
	damage_per_pokemon = max(0, per_pokemon)
	replaces_printed_multiplier_base = replace_printed_base
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var owner_index: int = attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var count := 0
	for slot: PokemonSlot in state.players[owner_index].get_all_pokemon():
		var cd: CardData = slot.get_card_data() if slot != null else null
		if cd != null and cd.has_tag(tag_filter):
			count += 1
	var damage := count * damage_per_pokemon
	if replaces_printed_multiplier_base:
		damage -= damage_per_pokemon
	return damage


func get_description() -> String:
	return "This attack does %d damage for each of your Pokemon in play with tag %s." % [damage_per_pokemon, tag_filter]
