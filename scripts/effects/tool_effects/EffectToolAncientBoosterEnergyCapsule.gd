class_name EffectToolAncientBoosterEnergyCapsule
extends BaseEffect

const EFFECT_ID := "8da8631aa1827b122ec65b712939ad48"
const JAMMING_TOWER_EFFECT_ID := "4e16157bfa88a41e823d058a732df8e0"
const HP_BONUS := 60


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	var slot := _resolve_target_slot(targets)
	if slot == null:
		return
	if _applies_to(slot, state):
		slot.clear_all_status()


func get_hp_modifier(slot: PokemonSlot, state: GameState = null) -> int:
	return HP_BONUS if _applies_to(slot, state) else 0


func prevents_special_status(slot: PokemonSlot, state: GameState = null) -> bool:
	return _applies_to(slot, state)


static func protects(slot: PokemonSlot, state: GameState = null) -> bool:
	if slot == null or slot.attached_tool == null or slot.attached_tool.card_data == null:
		return false
	if slot.attached_tool.card_data.effect_id != EFFECT_ID:
		return false
	if _is_tool_suppressed(slot, state):
		return false
	var data := slot.get_card_data()
	return data != null and data.is_ancient_pokemon()


func _applies_to(slot: PokemonSlot, state: GameState = null) -> bool:
	return protects(slot, state)


static func _is_tool_suppressed(slot: PokemonSlot, state: GameState = null) -> bool:
	if slot == null or slot.attached_tool == null or state == null:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_tool_effect_suppressed"):
		return bool(processor.call("is_tool_effect_suppressed", slot, state))
	if state.stadium_card == null or state.stadium_card.card_data == null:
		return false
	return state.stadium_card.card_data.effect_id == JAMMING_TOWER_EFFECT_ID


func _resolve_target_slot(targets: Array) -> PokemonSlot:
	for entry: Variant in targets:
		if entry is PokemonSlot:
			return entry
		if entry is Dictionary:
			for value: Variant in (entry as Dictionary).values():
				if value is PokemonSlot:
					return value
				if value is Array:
					for nested: Variant in value:
						if nested is PokemonSlot:
							return nested
	return null


func get_description() -> String:
	return "Ancient Pokemon get +%d HP and cannot be affected by Special Conditions." % HP_BONUS
