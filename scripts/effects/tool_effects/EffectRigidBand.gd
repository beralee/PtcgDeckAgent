class_name EffectRigidBand
extends BaseEffect

const DAMAGE_REDUCTION := -30


func get_defense_modifier(defender: PokemonSlot, state: GameState = null, attacker: PokemonSlot = null) -> int:
	if not _applies(defender, state, attacker):
		return 0
	return DAMAGE_REDUCTION


func _applies(defender: PokemonSlot, state: GameState = null, attacker: PokemonSlot = null) -> bool:
	if defender == null or state == null or defender.get_top_card() == null or attacker == null or attacker.get_top_card() == null:
		return false
	var defender_data := defender.get_card_data()
	if defender_data == null or defender_data.stage != "Stage 1":
		return false
	var owner_index := defender.get_top_card().owner_index
	var attacker_owner := attacker.get_top_card().owner_index
	if owner_index < 0 or attacker_owner < 0:
		return false
	return attacker_owner != owner_index


func get_description() -> String:
	return "Damage taken by the attached Stage 1 Pokemon from opponent Pokemon attacks is reduced by 30."
