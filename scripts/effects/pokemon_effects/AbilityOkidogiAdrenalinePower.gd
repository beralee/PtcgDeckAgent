class_name AbilityOkidogiAdrenalinePower
extends BaseEffect

const BOOST_AMOUNT := 100


func get_hp_modifier_for_source(slot: PokemonSlot, state: GameState) -> int:
	return BOOST_AMOUNT if _has_attached_darkness_energy(slot, state) else 0


func get_attack_modifier_for_attacker(
	source: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	defender: PokemonSlot = null
) -> int:
	if source == null or source != attacker or state == null or defender == null:
		return 0
	var top := source.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return 0
	if state.players[1 - top.owner_index].active_pokemon != defender:
		return 0
	return BOOST_AMOUNT if _has_attached_darkness_energy(source, state) else 0


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func _has_attached_darkness_energy(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if (
			processor != null
			and processor.has_method("is_special_energy_suppressed")
			and bool(processor.call("is_special_energy_suppressed", energy, state))
		):
			continue
		if energy.card_data.energy_provides == "D" or energy.card_data.energy_type == "D":
			return true
		if processor != null and processor.has_method("get_energy_types"):
			var provided_types: PackedStringArray = processor.call("get_energy_types", energy, state)
			if "D" in provided_types or "ANY" in provided_types:
				return true
	return false


func get_description() -> String:
	return "If this Pokemon has any Darkness Energy attached, it gets +100 HP and its attacks do 100 more damage to the opponent's Active Pokemon."
