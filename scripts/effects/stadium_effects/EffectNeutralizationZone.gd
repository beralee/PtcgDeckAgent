class_name EffectNeutralizationZone
extends BaseEffect

const EFFECT_ID := "6697150282b5d32d026ce20a993b4b53"


func prevents_attack_damage(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null or state == null:
		return false
	if state.stadium_card == null or state.stadium_card.card_data == null:
		return false
	if state.stadium_card.card_data.effect_id != EFFECT_ID:
		return false
	var attacker_top := attacker.get_top_card()
	var defender_top := defender.get_top_card()
	if attacker_top == null or defender_top == null or attacker_top.owner_index == defender_top.owner_index:
		return false
	var attacker_data := attacker.get_card_data()
	var defender_data := defender.get_card_data()
	if attacker_data == null or defender_data == null or defender_data.is_rule_box_pokemon():
		return false
	return _is_pokemon_ex_or_v(attacker_data)


func get_description() -> String:
	return "Non-rule-box Pokemon take no attack damage from opposing Pokemon ex or Pokemon V. This card cannot leave the discard pile for the hand or deck."


func _is_pokemon_ex_or_v(card_data: CardData) -> bool:
	if card_data.mechanic in ["ex", "V", "VSTAR", "VMAX"]:
		return true
	for tag: String in ["ex", "V", "VSTAR", "VMAX"]:
		if card_data.has_tag(tag):
			return true
	return false
