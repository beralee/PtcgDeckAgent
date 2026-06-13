class_name CSV9C180ScrambleSwitch
extends BaseEffect

const SWITCH_STEP_ID := "csv9c180_switch_target"
const ENERGY_STEP_ID := "csv9c180_energy_transfer"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return player.active_pokemon != null and not player.bench.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_preview_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return get_interaction_steps(card, state)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.active_pokemon == null or player.bench.is_empty():
		return []
	var step := _build_switch_step(player)
	if not player.active_pokemon.attached_energy.is_empty():
		step["requires_followup_interaction"] = true
	return [step]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.active_pokemon == null or player.active_pokemon.attached_energy.is_empty():
		return []
	var selected_target := _selected_switch_target(resolved_context, player)
	if selected_target == null:
		return []
	return [_build_energy_transfer_step(player.active_pokemon, selected_target)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	if player.active_pokemon == null or player.bench.is_empty():
		return

	var ctx := get_interaction_context(targets)
	var old_active := player.active_pokemon
	var new_active := _selected_switch_target(ctx, player)
	if new_active == null:
		new_active = _switch_target_from_energy_context(ctx, player)
	if new_active == null:
		new_active = player.bench[0]

	var energy_to_move := _selected_energy_to_move(ctx, old_active, new_active)
	_switch_player_active(player, old_active, new_active, state.turn_number)
	for energy: CardInstance in energy_to_move:
		if energy in old_active.attached_energy:
			old_active.attached_energy.erase(energy)
			new_active.attached_energy.append(energy)


func _build_switch_step(player: PlayerState) -> Dictionary:
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return {
		"id": SWITCH_STEP_ID,
		"title": "选择要换上战斗场的备战宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}


func _build_energy_transfer_step(old_active: PokemonSlot, new_active: PokemonSlot) -> Dictionary:
	var source_items: Array = old_active.attached_energy.duplicate()
	var source_labels: Array[String] = []
	for energy: CardInstance in source_items:
		source_labels.append(energy.card_data.name if energy.card_data != null else "Energy")
	var target_items: Array = [new_active]
	var target_labels: Array[String] = [new_active.get_pokemon_name()]
	var step := build_card_assignment_step(
		ENERGY_STEP_ID,
		"选择要转附给新战斗宝可梦的能量",
		source_items,
		source_labels,
		target_items,
		target_labels,
		0,
		source_items.size(),
		true
	)
	var energy_indices: Array[int] = []
	for i: int in source_items.size():
		energy_indices.append(i)
	step["source_groups"] = [{"slot": old_active, "energy_indices": energy_indices}]
	step["compact_field_assignment_after_source"] = true
	step["field_assignment_require_confirm"] = true
	step["compact_field_assignment_title"] = "能量转附"
	return step


func _selected_switch_target(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var raw: Array = ctx.get(SWITCH_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var candidate: PokemonSlot = raw[0]
		if candidate in player.bench:
			return candidate
	return null


func _switch_target_from_energy_context(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	for entry: Variant in ctx.get(ENERGY_STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var target: Variant = (entry as Dictionary).get("target")
		if target is PokemonSlot and target in player.bench:
			return target
	return null


func _selected_energy_to_move(ctx: Dictionary, old_active: PokemonSlot, new_active: PokemonSlot) -> Array[CardInstance]:
	var selected: Array[CardInstance] = []
	if not ctx.has(ENERGY_STEP_ID):
		return old_active.attached_energy.duplicate()
	for entry: Variant in ctx.get(ENERGY_STEP_ID, []):
		var source: Variant = null
		var target: Variant = null
		if entry is Dictionary:
			source = (entry as Dictionary).get("source")
			target = (entry as Dictionary).get("target")
		elif entry is CardInstance:
			source = entry
		if not (source is CardInstance):
			continue
		var energy: CardInstance = source
		if energy not in old_active.attached_energy or energy in selected:
			continue
		if target is PokemonSlot and target != new_active:
			continue
		selected.append(energy)
	return selected


func _switch_player_active(player: PlayerState, old_active: PokemonSlot, new_active: PokemonSlot, turn_number: int) -> void:
	if old_active == null or new_active == null or new_active not in player.bench:
		return
	player.bench.erase(new_active)
	old_active.clear_on_leave_active()
	player.bench.append(old_active)
	player.active_pokemon = new_active
	new_active.mark_entered_active_from_bench(turn_number)


func get_description() -> String:
	return "将自己的战斗宝可梦与备战宝可梦互换，然后将退下的宝可梦身上任意数量的能量转附给新的战斗宝可梦。"
