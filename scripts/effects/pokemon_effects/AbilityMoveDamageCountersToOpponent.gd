## 亢奋脑力 - 愿增猿
## 附着恶能量时，每回合1次，将己方宝可梦上的最多3个伤害指示物转放到对手宝可梦上。
class_name AbilityMoveDamageCountersToOpponent
extends BaseEffect

const USED_FLAG_TYPE := "ability_move_counters_to_opp_used"
const LUMINOUS_ENERGY_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const LEGACY_ENERGY_EFFECT_ID := "6f31b7241a181631016466e561f148f3"
const TEMPLE_OF_SINNOH_EFFECT_ID := "53864b068a4a1e8dce3c53c884b67efa"

var max_counters: int = 3


func _init(max_count: int = 3) -> void:
	max_counters = max_count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_FLAG_TYPE and eff.get("turn") == state.turn_number:
			return false
	if not _has_dark_energy(pokemon, state):
		return false
	var player: PlayerState = state.players[top.owner_index]
	var has_source := false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_live_slot(slot, state) and slot.damage_counters >= 10:
			has_source = true
			break
	if not has_source:
		return false
	var opponent: PlayerState = state.players[1 - top.owner_index]
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if _is_live_slot(slot, state):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = []
	var source_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_live_slot(slot, state) and slot.damage_counters >= 10:
			source_items.append(slot)
			source_labels.append("%s (%d伤害)" % [slot.get_pokemon_name(), slot.damage_counters])
	if source_items.is_empty():
		return []
	return [{
		"id": "source_pokemon",
		"title": "选择要移走伤害指示物的己方宝可梦",
		"items": source_items,
		"labels": source_labels,
		"min_select": 1,
		"max_select": 1,
		"requires_followup_interaction": true,
		"allow_cancel": true,
	}]


func get_followup_interaction_steps(
	card: CardInstance,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	var source: PokemonSlot = _selected_source_from_context(card, state, resolved_context)
	if source == null:
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if _is_live_slot(slot, state):
			target_items.append(slot)
			target_labels.append(slot.get_pokemon_name())
	if target_items.is_empty():
		return []
	var available_counters: int = mini(max_counters, source.damage_counters / 10)
	if available_counters <= 0:
		return []
	return [{
		"id": "target_damage_counters",
		"title": "选择1-%d个伤害指示物，再点击对手宝可梦" % available_counters,
		"ui_mode": "counter_distribution",
		"use_counter_distribution_ui": true,
		"total_counters": available_counters,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": 1,
		"max_select": available_counters,
		"max_assignments": 1,
		"max_assignments_per_target": 1,
		"allow_partial": true,
		"allow_cancel": true,
	}]


func validate_ability_interaction(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	var transfer := _resolve_transfer(pokemon, targets, state)
	if bool(transfer.get("valid", false)):
		return interaction_validation_ok()
	return interaction_validation_error(str(transfer.get("reason", "invalid damage-counter transfer")))


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var transfer := _resolve_transfer(pokemon, targets, state)
	if not bool(transfer.get("valid", false)):
		return
	var source: PokemonSlot = transfer.get("source", null)
	var target: PokemonSlot = transfer.get("target", null)
	var move_amount: int = int(transfer.get("move_amount", 0))
	source.damage_counters -= move_amount
	target.damage_counters += move_amount

	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func _resolve_transfer(pokemon: PokemonSlot, targets: Array, state: GameState) -> Dictionary:
	if pokemon == null or state == null:
		return {"valid": false, "reason": "ability source is missing"}
	var top: CardInstance = pokemon.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return {"valid": false, "reason": "ability source owner is invalid"}
	var ctx: Dictionary = get_interaction_context(targets)
	var source: PokemonSlot = _selected_source_from_context(top, state, ctx)
	if source == null:
		return {"valid": false, "reason": "damage source is missing or no longer legal"}

	var opponent: PlayerState = state.players[1 - top.owner_index]
	var assignment: Dictionary = _selected_counter_assignment(ctx)
	var target: PokemonSlot = null
	var count: int = 1
	if not assignment.is_empty():
		var assigned_target: Variant = assignment.get("target", null)
		if assigned_target is PokemonSlot:
			target = assigned_target as PokemonSlot
		var amount := int(assignment.get("amount", 10))
		if amount <= 0 or amount % 10 != 0:
			return {"valid": false, "reason": "damage-counter amount is invalid"}
		count = int(amount / 10)
	else:
		var target_raw: Array = ctx.get("target_pokemon", [])
		if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
			target = target_raw[0] as PokemonSlot
		var count_raw: Array = ctx.get("counter_count", [])
		if not count_raw.is_empty():
			count = int(count_raw[0])
	if target == null or target not in opponent.get_all_pokemon() or not _is_live_slot(target, state):
		return {"valid": false, "reason": "damage target is missing or no longer legal"}

	var available_counters: int = mini(max_counters, source.damage_counters / 10)
	if count < 1 or count > available_counters:
		return {"valid": false, "reason": "damage-counter count exceeds the legal transfer amount"}
	return {
		"valid": true,
		"source": source,
		"target": target,
		"move_amount": count * 10,
	}


func _selected_source_from_context(card: CardInstance, state: GameState, ctx: Dictionary) -> PokemonSlot:
	if card == null:
		return null
	var player: PlayerState = state.players[card.owner_index]
	var source_raw: Array = ctx.get("source_pokemon", [])
	if source_raw.is_empty() or not (source_raw[0] is PokemonSlot):
		return null
	var source: PokemonSlot = source_raw[0]
	if source in player.get_all_pokemon() and _is_live_slot(source, state) and source.damage_counters >= 10:
		return source
	return null


func _selected_counter_assignment(ctx: Dictionary) -> Dictionary:
	var assignments: Array = ctx.get("target_damage_counters", [])
	if assignments.is_empty():
		return {}
	var first: Variant = assignments[0]
	return first.duplicate(false) if first is Dictionary else {}


func _is_live_slot(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or slot.get_top_card() == null:
		return false
	return EffectProcessor.new().get_effective_remaining_hp(slot, state) > 0


func _has_dark_energy(pokemon: PokemonSlot, state: GameState = null) -> bool:
	for energy: CardInstance in pokemon.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var energy_type: String = _get_attached_energy_type(pokemon, energy, state)
		if energy_type == "D" or energy_type == "ANY":
			return true
	return false


func _get_attached_energy_type(pokemon: PokemonSlot, energy: CardInstance, state: GameState = null) -> String:
	if energy == null or energy.card_data == null:
		return "C"
	if _is_special_energy_suppressed(energy, state):
		return "C"
	match energy.card_data.effect_id:
		LUMINOUS_ENERGY_EFFECT_ID:
			return "C" if _luminous_energy_is_downgraded(pokemon, energy) else "ANY"
		LEGACY_ENERGY_EFFECT_ID:
			return "ANY"
	var provides: String = energy.card_data.energy_provides
	return provides if provides != "" else "C"


func _is_special_energy_suppressed(energy: CardInstance, state: GameState = null) -> bool:
	return (
		energy.card_data.card_type == "Special Energy"
		and state != null
		and state.stadium_card != null
		and state.stadium_card.card_data != null
		and state.stadium_card.card_data.effect_id == TEMPLE_OF_SINNOH_EFFECT_ID
	)


func _luminous_energy_is_downgraded(pokemon: PokemonSlot, luminous_energy: CardInstance) -> bool:
	if pokemon == null:
		return false
	for other: CardInstance in pokemon.attached_energy:
		if other != luminous_energy and other != null and other.card_data != null and other.card_data.card_type == "Special Energy":
			return true
	return false


func get_description() -> String:
	return "特性【亢奋脑力】：附着恶能量时，每回合1次，将己方宝可梦上最多%d个伤害指示物转放到对手宝可梦上。" % max_counters
