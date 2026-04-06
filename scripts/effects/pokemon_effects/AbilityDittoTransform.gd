## 百变怪 - 变身启动：第一回合从牌库选1张基础宝可梦替换自身
class_name AbilityDittoTransform
extends BaseEffect

const USED_KEY := "ditto_transform_used"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	# 仅在战斗场上可用
	if state.players[pi].active_pokemon != pokemon:
		return false
	# 仅在第一个自己的回合可用
	if not _is_first_own_turn(pi, state):
		return false
	# 每局仅一次
	if state.shared_turn_flags.get(USED_KEY + str(pi), false):
		return false
	# 牌库里需要有非百变怪的基础宝可梦
	return _has_valid_target(state.players[pi])


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.deck:
		if _is_valid_replacement(c):
			items.append(c)
			labels.append(c.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": "transform_target",
		"title": "选择1张基础宝可梦替换百变怪",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var pi: int = top.owner_index
	var player: PlayerState = state.players[pi]

	var replacement: CardInstance = null
	var ctx: Dictionary = get_interaction_context(targets)
	var raw: Array = ctx.get("transform_target", [])
	if not raw.is_empty() and raw[0] is CardInstance:
		var selected: CardInstance = raw[0]
		if selected in player.deck and _is_valid_replacement(selected):
			replacement = selected

	if replacement == null:
		for c: CardInstance in player.deck:
			if _is_valid_replacement(c):
				replacement = c
				break

	if replacement == null:
		return

	# 将百变怪及其身上所有卡放入弃牌区
	for card: CardInstance in pokemon.collect_all_cards():
		player.discard_pile.append(card)
	pokemon.pokemon_stack.clear()
	pokemon.attached_energy.clear()
	if pokemon.attached_tool != null:
		player.discard_pile.append(pokemon.attached_tool)
		pokemon.attached_tool = null

	# 从牌库取出替换宝可梦
	player.deck.erase(replacement)
	pokemon.pokemon_stack.append(replacement)
	pokemon.turn_played = state.turn_number
	pokemon.damage_counters = 0
	pokemon.clear_all_status()

	player.shuffle_deck()
	state.shared_turn_flags[USED_KEY + str(pi)] = true


func _is_first_own_turn(pi: int, state: GameState) -> bool:
	if state.first_player_index == pi:
		return state.turn_number == 1
	else:
		return state.turn_number == 2


func _has_valid_target(player: PlayerState) -> bool:
	for c: CardInstance in player.deck:
		if _is_valid_replacement(c):
			return true
	return false


func _is_valid_replacement(c: CardInstance) -> bool:
	if c == null or c.card_data == null:
		return false
	var cd: CardData = c.card_data
	return cd.is_pokemon() and cd.stage == "Basic" and cd.name != "百变怪"


func get_description() -> String:
	return "第一回合在战斗场上时：从牌库选1张基础宝可梦替换自身"
