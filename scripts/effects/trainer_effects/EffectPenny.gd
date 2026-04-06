## 牡丹 - 选择己方1只基础宝可梦，将其及身上所有卡放回手牌
class_name EffectPenny
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_basic(slot):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_basic(slot):
			items.append(slot)
			labels.append(slot.get_pokemon_name())
	if items.is_empty():
		return []
	return [{
		"id": "penny_target",
		"title": "选择1只基础宝可梦放回手牌",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target: PokemonSlot = null

	var raw: Array = ctx.get("penny_target", [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in player.get_all_pokemon() and _is_basic(selected):
			target = selected

	if target == null:
		for slot: PokemonSlot in player.get_all_pokemon():
			if _is_basic(slot):
				target = slot
				break

	if target == null:
		return

	var is_active: bool = (target == player.active_pokemon)
	for c: CardInstance in target.collect_all_cards():
		player.hand.append(c)
	target.pokemon_stack.clear()
	target.attached_energy.clear()
	if target.attached_tool != null:
		target.attached_tool = null
	target.damage_counters = 0
	target.clear_all_status()

	if is_active:
		player.active_pokemon = null
	else:
		player.bench.erase(target)


func _is_basic(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	return cd != null and cd.stage == "Basic"


func get_description() -> String:
	return "选择己方1只基础宝可梦，将其及身上所有卡放回手牌"
