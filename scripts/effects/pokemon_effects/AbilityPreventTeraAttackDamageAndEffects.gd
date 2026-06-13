class_name AbilityPreventTeraAttackDamageAndEffects
extends BaseEffect

const EFFECT_ID := "57e95f8cb1129f6b45b7bbbc1a45b643"


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func prevents_damage_from(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	return _opponent_tera_attack_matches(attacker, defender, state)


func prevents_effects_from(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	return _opponent_tera_attack_matches(attacker, defender, state)


static func prevents_target_effect_from_tera_attack(
	attacker: PokemonSlot,
	target: PokemonSlot,
	state: GameState
) -> bool:
	if target == null or target.get_card_data() == null:
		return false
	if target.get_card_data().effect_id != EFFECT_ID:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if processor != null and processor.has_method("is_ability_disabled") and bool(processor.call("is_ability_disabled", target, state)):
		return false
	return _opponent_tera_attack_matches(attacker, target, state)


static func _opponent_tera_attack_matches(
	attacker: PokemonSlot,
	target: PokemonSlot,
	state: GameState
) -> bool:
	if attacker == null or target == null or state == null:
		return false
	var attacker_card: CardInstance = attacker.get_top_card()
	var target_card: CardInstance = target.get_top_card()
	if attacker_card == null or target_card == null:
		return false
	if attacker_card.owner_index == target_card.owner_index:
		return false
	return _is_tera(attacker.get_card_data())


static func _is_tera(card_data: CardData) -> bool:
	if card_data == null:
		return false
	return card_data.ancient_trait == "Tera" \
		or card_data.mechanic == "Tera" \
		or card_data.has_tag("Tera") \
		or card_data.label.contains("太晶")


func get_description() -> String:
	return "Prevent all damage and effects from attacks used by opponent Tera Pokemon."
