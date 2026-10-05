extends RefCounted

static func first_excess(state: GameState, processor: EffectProcessor) -> Dictionary:
	if state == null: return {}
	for offset in 2:
		var owner := (state.current_player_index + offset) % 2
		for slot: PokemonSlot in state.players[owner].get_all_pokemon():
			var limit := processor.get_tool_limit(slot, state)
			if slot.attached_tools.size() <= limit: continue
			var items: Array = slot.get_attached_tools()
			var labels: Array[String] = []
			for card: CardInstance in items: labels.append(card.card_data.display_name())
			var step := {"id": "tool_limit_keep_%d" % slot.get_top_card().instance_id,
				"title": "选择要保留在%s身上的%d张道具" % [slot.get_pokemon_name(), limit],
				"items": items, "labels": labels, "min_select": limit, "max_select": limit,
				"allow_cancel": false, "chooser_player_index": owner}
			return {"kind": "tool_limit_cleanup", "scene_choice": "effect_interaction", "player": owner,
				"owner_player_index": owner, "effect_player_index": owner, "card": slot.get_top_card(),
				"slot": slot, "steps": [step]}
	return {}

static func apply_selection(state: GameState, processor: EffectProcessor, owner: int, targets: Array) -> bool:
	var pending := first_excess(state, processor)
	if pending.is_empty() or int(pending.player) != owner: return false
	var step: Dictionary = pending.steps[0]
	var helper := BaseEffect.new()
	var context := helper.get_interaction_context(targets)
	var validation := helper.validate_context_selection(context, str(step.id), step.items, int(step.min_select), int(step.max_select))
	if not bool(validation.get("valid", false)): return false
	var keep: Array = context[step.id]
	var slot: PokemonSlot = pending.slot
	for tool: CardInstance in slot.get_attached_tools():
		if tool not in keep:
			slot.remove_attached_tool(tool)
			tool.face_up = true
			state.players[owner].discard_pile.append(tool)
	return true
