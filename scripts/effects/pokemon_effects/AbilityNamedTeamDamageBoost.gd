class_name AbilityNamedTeamDamageBoost
extends BaseEffect

var damage_bonus: int = 30
var required_name_prefixes: PackedStringArray = PackedStringArray()


func _init(
	bonus: int = 30,
	name_prefixes: PackedStringArray = PackedStringArray()
) -> void:
	damage_bonus = bonus
	required_name_prefixes = name_prefixes.duplicate()


func get_attack_modifier_for_attacker(
	source: PokemonSlot,
	attacker: PokemonSlot,
	_state: GameState,
	_defender: PokemonSlot = null
) -> int:
	if source == null or attacker == null:
		return 0
	var source_top := source.get_top_card()
	var attacker_top := attacker.get_top_card()
	if source_top == null or attacker_top == null or source_top.owner_index != attacker_top.owner_index:
		return 0
	var card_data := attacker.get_card_data()
	if card_data == null:
		return 0
	for identity_name: String in card_data.rule_identity_names():
		for prefix: String in required_name_prefixes:
			if prefix != "" and identity_name.begins_with(prefix):
				return damage_bonus
	return 0


func get_description() -> String:
	return "Your matching Pokemon's attacks do %d more damage to the opponent's Active Pokemon." % damage_bonus
