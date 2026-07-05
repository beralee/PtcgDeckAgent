class_name AbilityNonRuleBoxBenchDamageShield
extends BaseEffect

const FLOWER_CURTAIN_EFFECT_ID := "69d439ca1bcf6877afa4d5ad4f369fd3"
const FLOWER_CURTAIN_ABILITY_NAMES := ["Flower Curtain"]


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


static func protects_bench_target(target: PokemonSlot, attacker: PokemonSlot, state: GameState) -> bool:
	if target == null or attacker == null or state == null:
		return false
	var target_top: CardInstance = target.get_top_card()
	var attacker_top: CardInstance = attacker.get_top_card()
	if target_top == null or attacker_top == null:
		return false
	var target_owner := target_top.owner_index
	if target_owner < 0 or target_owner >= state.players.size():
		return false
	if target_owner == attacker_top.owner_index:
		return false
	if target not in state.players[target_owner].bench:
		return false
	if _has_rule_box(target.get_card_data()):
		return false
	for source: PokemonSlot in state.players[target_owner].get_all_pokemon():
		if _is_flower_curtain_source(source) and not _is_source_ability_disabled(source, state):
			return true
	return false


static func _is_flower_curtain_source(source: PokemonSlot) -> bool:
	if source == null:
		return false
	var card_data: CardData = source.get_card_data()
	if card_data == null:
		return false
	if card_data.effect_id == FLOWER_CURTAIN_EFFECT_ID:
		return true
	for ability: Variant in card_data.abilities:
		if ability is Dictionary and str(ability.get("name", "")) in FLOWER_CURTAIN_ABILITY_NAMES:
			return true
	return false


static func _has_rule_box(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if card_data.is_rule_box_pokemon() or card_data.is_radiant():
		return true
	for tag: String in card_data.is_tags:
		if tag in ["Rule Box", "ex", "V", "VSTAR", "VMAX", "Radiant"]:
			return true
	return false


static func _is_source_ability_disabled(source: PokemonSlot, state: GameState) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if processor != null and processor.has_method("is_ability_disabled"):
		return bool(processor.call("is_ability_disabled", source, state))
	return EffectCancelCologne.is_slot_directly_ability_disabled(source, state) if state != null else false


func get_description() -> String:
	return "Prevent attack damage to your Benched non-Rule Box Pokemon."
