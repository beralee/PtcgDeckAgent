class_name AbilityTingLuCursedLand
extends BaseEffect

const EFFECT_ID := "6db296a19d741896c070fe471e92b8f3"
const ABILITY_NAME := "咒缚大地"


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


static func is_locked_by_cursed_land(
	slot: PokemonSlot,
	state: GameState,
	before_order: int = -1
) -> bool:
	if slot == null or state == null or slot.damage_counters <= 0:
		return false
	var card_data := slot.get_card_data()
	var top := slot.get_top_card()
	if card_data == null or top == null or _is_pokemon_ex(card_data):
		return false
	var owner_index := int(top.owner_index)
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	var source := state.players[1 - owner_index].active_pokemon
	if source == null or (before_order > 0 and _source_order(source) >= before_order):
		return false
	if not _is_cursed_land_source(source):
		return false
	return not _is_source_suppressed(source, state)


static func _is_cursed_land_source(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var card_data := slot.get_card_data()
	if card_data == null or card_data.effect_id != EFFECT_ID:
		return false
	for ability: Dictionary in card_data.abilities:
		if str(ability.get("name", "")) == ABILITY_NAME:
			return true
	return false


static func _is_source_suppressed(slot: PokemonSlot, state: GameState) -> bool:
	if EffectCancelCologne.is_slot_directly_ability_disabled(slot, state):
		return true
	var source_order := _source_order(slot)
	if AbilityBasicLock.is_locked_by_basic_lock(slot, state, source_order):
		return true
	if AbilityDisableOpponentAbility.is_locked_by_dark_wing(slot, state, source_order):
		return true
	if AbilityIronThornsInit.is_locked_by_init(slot, state, source_order):
		return true
	if AbilityBasicVLock.is_locked(slot, state, source_order):
		return true
	return false


static func _is_pokemon_ex(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if card_data.mechanic.to_lower() == "ex":
		return true
	for raw_tag: String in card_data.is_tags:
		if raw_tag.strip_edges().to_lower() == "ex":
			return true
	return false


static func _source_order(slot: PokemonSlot) -> int:
	return slot.get_active_continuous_ability_order() if slot != null else 0


func get_description() -> String:
	return "While this Pokemon is Active, each damaged opposing non-ex Pokemon has no Abilities."
