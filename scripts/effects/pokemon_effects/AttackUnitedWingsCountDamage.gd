class_name AttackUnitedWingsCountDamage
extends BaseEffect

const UNITED_WINGS_NAMES := ["united wings", "团结之翼"]

var damage_per_pokemon: int = 20
var attack_index_to_match: int = -1
var replaces_printed_multiplier_base: bool = true


func _init(per_pokemon: int = 20, match_attack_index: int = -1, replace_printed_base: bool = true) -> void:
	damage_per_pokemon = per_pokemon
	attack_index_to_match = match_attack_index
	replaces_printed_multiplier_base = replace_printed_base


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var united_wings_count := 0
	for card: CardInstance in state.players[owner_index].discard_pile:
		if card != null and _card_has_united_wings_attack(card.card_data):
			united_wings_count += 1
	var damage := united_wings_count * damage_per_pokemon
	if replaces_printed_multiplier_base:
		damage -= damage_per_pokemon
	return damage


static func _card_has_united_wings_attack(card_data: CardData) -> bool:
	if card_data == null or not card_data.is_pokemon():
		return false
	for attack: Dictionary in card_data.attacks:
		if _is_united_wings_attack_name(str(attack.get("name", ""))):
			return true
		if _is_united_wings_attack_name(str(attack.get("name_en", ""))):
			return true
		if _is_united_wings_attack_name(str(attack.get("name_zh", ""))):
			return true
	return false


static func _is_united_wings_attack_name(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return UNITED_WINGS_NAMES.has(normalized)


func get_description() -> String:
	return "This attack does 20 damage for each Pokemon in your discard pile that has United Wings."
