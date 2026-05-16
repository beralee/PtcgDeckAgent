## 捩木 - 从弃牌区选1只基础宝可梦，与己方场上1只基础宝可梦互换
## 被换下的基础宝可梦放弃牌区，换上的宝可梦继承原位置上的所有附属卡和状态
class_name EffectThorton
extends BaseEffect

const DISCARD_STEP_ID := "thorton_discard_pokemon"
const FIELD_STEP_ID := "thorton_field_pokemon"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]

	## 弃牌区必须有基础宝可梦
	if _get_basic_pokemon_in_discard(player).is_empty():
		return false

	## 场上必须有基础宝可梦（战斗区或备战区的顶层为基础宝可梦）
	return not _get_basic_pokemon_slots_in_play(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var discard_targets: Array[CardInstance] = _get_basic_pokemon_in_discard(player)
	var field_targets: Array[PokemonSlot] = _get_basic_pokemon_slots_in_play(player)
	if discard_targets.is_empty() or field_targets.is_empty():
		return []

	var discard_labels: Array[String] = []
	for discard_card: CardInstance in discard_targets:
		discard_labels.append(_build_card_label(discard_card))

	var field_labels: Array[String] = []
	for slot: PokemonSlot in field_targets:
		field_labels.append(_build_slot_label(slot, player))

	return [{
		"id": DISCARD_STEP_ID,
		"title": "选择弃牌区的1只基础宝可梦",
		"items": discard_targets,
		"labels": discard_labels,
		"presentation": "cards",
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}, {
		"id": FIELD_STEP_ID,
		"title": "选择场上的1只基础宝可梦进行互换",
		"items": field_targets,
		"labels": field_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var from_discard: CardInstance = _get_selected_discard_pokemon(ctx, player)

	if from_discard == null:
		return

	var target_slot: PokemonSlot = _get_selected_field_pokemon(ctx, player)

	if target_slot == null:
		return

	## 从弃牌区移除选中的宝可梦卡
	player.discard_pile.erase(from_discard)

	## 将场上目标槽位的最顶层基础宝可梦卡放入弃牌区
	## 只弃置顶层宝可梦卡本身，附属卡和状态保留在槽位上
	var old_top: CardInstance = target_slot.get_top_card()
	if old_top != null:
		target_slot.pokemon_stack.erase(old_top)
		old_top.face_up = true
		player.discard_pile.append(old_top)

	## 将弃牌区取来的基础宝可梦替换进槽位（作为新的底层/顶层卡）
	from_discard.face_up = true
	## 若进化链已清空（原本是基础宝可梦独占），直接作为新顶层
	## 若进化链还有其他卡（不应出现，因为条件要求顶层是基础宝可梦），仍插入顶部
	target_slot.pokemon_stack.append(from_discard)

	## 被替换后槽位保留原有的能量、道具、伤害计数器和特殊状态
	## （规则说明：继承全部附属卡和状态）


func get_description() -> String:
	return "从弃牌区选1只基础宝可梦，与场上1只基础宝可梦互换，继承所有附属卡和状态"


func _get_basic_pokemon_in_discard(player: PlayerState) -> Array[CardInstance]:
	var targets: Array[CardInstance] = []
	for c: CardInstance in player.discard_pile:
		if c != null and c.card_data != null and c.card_data.is_basic_pokemon():
			targets.append(c)
	return targets


func _get_basic_pokemon_slots_in_play(player: PlayerState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.bench:
		if _is_basic_pokemon_slot(slot):
			targets.append(slot)
	if _is_basic_pokemon_slot(player.active_pokemon):
		targets.append(player.active_pokemon)
	return targets


func _is_basic_pokemon_slot(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var data: CardData = slot.get_card_data()
	return data != null and data.is_basic_pokemon()


func _get_selected_discard_pokemon(ctx: Dictionary, player: PlayerState) -> CardInstance:
	var valid_targets: Array[CardInstance] = _get_basic_pokemon_in_discard(player)
	var selected_raw: Array = ctx.get(DISCARD_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if candidate in valid_targets:
			return candidate
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null


func _get_selected_field_pokemon(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var valid_targets: Array[PokemonSlot] = _get_basic_pokemon_slots_in_play(player)
	var selected_raw: Array = ctx.get(FIELD_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in valid_targets:
			return candidate
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null


func _build_card_label(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return "%s (HP %d)" % [card.card_data.name, card.card_data.hp]


func _build_slot_label(slot: PokemonSlot, player: PlayerState) -> String:
	var zone := "战斗场" if slot == player.active_pokemon else "备战区"
	return "%s: %s (HP %d/%d)" % [
		zone,
		slot.get_pokemon_name(),
		slot.get_remaining_hp(),
		slot.get_max_hp(),
	]
