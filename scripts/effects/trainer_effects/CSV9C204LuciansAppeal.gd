class_name CSV9C204LuciansAppeal
extends BaseEffect

const STEP_ID := "csv9c204_basic_bench_target"
const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_basic_bench_targets(state.players[1 - card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var targets := _get_basic_bench_targets(state.players[1 - card.owner_index])
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		labels.append(H.slot_label(slot, state))
	return [{
		"id": STEP_ID,
		"title": "选择对手备战区1只基础宝可梦换到战斗场并混乱",
		"items": targets,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	if opponent.active_pokemon == null:
		return
	var chosen: PokemonSlot = null
	var ctx := get_interaction_context(targets)
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is PokemonSlot and entry in _get_basic_bench_targets(opponent):
			chosen = entry
			break
	if chosen == null:
		var legal_targets := _get_basic_bench_targets(opponent)
		chosen = legal_targets[0] if not legal_targets.is_empty() else null
	if chosen == null:
		return

	var old_active: PokemonSlot = opponent.active_pokemon
	opponent.bench.erase(chosen)
	old_active.clear_on_leave_active()
	opponent.bench.append(old_active)
	opponent.active_pokemon = chosen
	chosen.mark_entered_active_from_bench(state.turn_number)
	_apply_special_status(chosen, "confused", state)


func _get_basic_bench_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.bench:
		var cd := slot.get_card_data()
		if cd != null and cd.is_basic_pokemon():
			result.append(slot)
	return result


func get_description() -> String:
	return "选择对手备战区1只基础宝可梦与战斗宝可梦互换，新出场宝可梦混乱。"
