class_name BattleActionController
extends RefCounted


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func on_hand_card_clicked(scene: Object, inst: CardInstance, _panel: PanelContainer) -> void:
	scene.call(
		"_runtime_log",
		"hand_card_clicked",
		"card=%s selected_before=%s %s" % [
			scene.call("_card_instance_label", inst),
			scene.call("_card_instance_label", scene.get("_selected_hand_card")),
			scene.call("_state_snapshot"),
		]
	)
	if not bool(scene.call("_can_accept_live_action")):
		return
	if bool(scene.call("_is_field_interaction_active")):
		return
	if scene.get("_selected_hand_card") == inst:
		var selected_card_data: CardData = inst.card_data if inst != null else null
		if selected_card_data != null and selected_card_data.is_pokemon():
			if scene.has_method("_show_selected_hand_card_detail"):
				scene.call("_show_selected_hand_card_detail", inst)
			else:
				scene.call("_show_card_detail", selected_card_data)
			return
		scene.set("_selected_hand_card", null)
		scene.call("_refresh_hand")
		return

	var gsm: Variant = scene.get("_gsm")
	var current_player: int = gsm.game_state.current_player_index
	var card_data: CardData = inst.card_data
	if card_data.card_type == "Supporter":
		if gsm.rule_validator.can_play_supporter(gsm.game_state, current_player, inst, gsm.effect_processor) or gsm._can_play_supporter_exception(current_player, inst):
			try_play_trainer_with_interaction(scene, current_player, inst)
		else:
			var reason: String = gsm.rule_validator.get_play_supporter_unusable_reason(gsm.game_state, current_player, inst, gsm.effect_processor)
			_show_invalid_card_hint(scene, inst, reason, "supporter")
		return
	if card_data.card_type == "Item":
		try_play_trainer_with_interaction(scene, current_player, inst)
		return
	if card_data.card_type == "Stadium":
		try_play_stadium_with_interaction(scene, current_player, inst)
		return
	if card_data.is_basic_pokemon():
		var basic_reason: String = gsm.rule_validator.get_play_basic_to_bench_unusable_reason(gsm.game_state, current_player, inst)
		if basic_reason != "":
			_show_invalid_card_hint(scene, inst, basic_reason, "pokemon")
			return
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_basic_to_bench", {"name": card_data.name}))
		return
	if card_data.is_pokemon() and card_data.stage != "Basic":
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_evolution_target", {"name": card_data.name}))
		return
	if card_data.card_type == "Basic Energy" or card_data.card_type == "Special Energy":
		var energy_reason: String = gsm.rule_validator.get_attach_energy_unusable_reason(gsm.game_state, current_player, inst, gsm.effect_processor)
		if energy_reason != "":
			_show_invalid_card_hint(scene, inst, energy_reason, "energy")
			return
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_attach_energy_target", {"name": card_data.name}))
		return
	if card_data.card_type == "Tool":
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_attach_tool_target", {"name": card_data.name}))


func try_play_trainer_with_interaction(scene: Object, player_index: int, card: CardInstance) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_type: String = card.card_data.card_type
	if card_type == "Item" and not gsm.rule_validator.can_play_item(gsm.game_state, player_index, card, gsm.effect_processor):
		_show_invalid_card_hint(
			scene,
			card,
			gsm.rule_validator.get_play_item_unusable_reason(gsm.game_state, player_index, card, gsm.effect_processor),
			"item"
		)
		return
	if card_type == "Supporter":
		if not gsm.rule_validator.can_play_supporter(gsm.game_state, player_index, card, gsm.effect_processor) and not gsm._can_play_supporter_exception(player_index, card):
			_show_invalid_card_hint(
				scene,
				card,
				gsm.rule_validator.get_play_supporter_unusable_reason(gsm.game_state, player_index, card, gsm.effect_processor),
				"supporter"
			)
			return
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		if not gsm.play_trainer(player_index, card, []):
			_show_invalid_card_hint(scene, card, "%s 当前无法使用。" % card.card_data.name, "trainer")
		else:
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	if not effect.can_execute(card, gsm.game_state):
		_show_invalid_card_hint(scene, card, gsm.effect_processor.get_effect_unusable_reason(card, gsm.game_state), "trainer")
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		if not gsm.play_trainer(player_index, card, []):
			_show_invalid_card_hint(scene, card, gsm.effect_processor.get_effect_unusable_reason(card, gsm.game_state), "trainer")
		else:
			var empty_message: String = effect.get_empty_interaction_message(card, gsm.game_state)
			if empty_message != "":
				scene.call("_log", empty_message)
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	scene.call("_start_effect_interaction", "trainer", player_index, steps, card)
	scene.call("_maybe_run_ai")


func try_play_stadium_with_interaction(scene: Object, player_index: int, card: CardInstance) -> void:
	var gsm: Variant = scene.get("_gsm")
	if not gsm.rule_validator.can_play_stadium(gsm.game_state, player_index, card, gsm.effect_processor):
		_show_invalid_card_hint(
			scene,
			card,
			gsm.rule_validator.get_play_stadium_unusable_reason(gsm.game_state, player_index, card, gsm.effect_processor),
			"stadium"
		)
		return
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		if not gsm.play_stadium(player_index, card):
			_show_invalid_card_hint(scene, card, "%s 当前无法打出。" % card.card_data.name, "stadium")
		else:
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	var steps: Array[Dictionary] = effect.get_on_play_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		if not gsm.play_stadium(player_index, card):
			scene.call("_log", _bt(scene, "battle.log.cannot_play_stadium"))
		else:
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	scene.call("_start_effect_interaction", "play_stadium", player_index, steps, card)
	scene.call("_maybe_run_ai")


func try_use_ability_with_interaction(scene: Object, player_index: int, slot: PokemonSlot, ability_index: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card: CardInstance = gsm.effect_processor.get_ability_source_card(slot, ability_index, gsm.game_state)
	if card == null:
		return
	var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, ability_index, gsm.game_state)
	if effect == null:
		if gsm.use_ability(player_index, slot, ability_index):
			scene.call("_refresh_ui_after_successful_action", true, player_index, "use_ability")
		else:
			_show_invalid_action_hint(scene, {
				"title": "%s 现在不能使用特性" % card.card_data.name,
				"reason": gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, ability_index),
				"detail": "特性需要满足卡面条件，并且可能受到场上特性封锁效果影响。",
				"kind": "ability",
			})
		return
	if not gsm.effect_processor.can_use_ability(slot, gsm.game_state, ability_index):
		_show_invalid_action_hint(scene, {
			"title": "%s 现在不能使用特性" % card.card_data.name,
			"reason": gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, ability_index),
			"detail": "特性需要满足卡面条件，并且可能受到场上特性封锁效果影响。",
			"kind": "ability",
		})
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		if gsm.use_ability(player_index, slot, ability_index):
			var ability_name: String = gsm.effect_processor.get_ability_name(slot, ability_index, gsm.game_state)
			scene.call("_log", _bt(scene, "battle.log.ability_used", {"name": ability_name}))
			scene.call("_refresh_ui_after_successful_action", true, player_index, "use_ability")
		else:
			_show_invalid_action_hint(scene, {
				"title": "%s 现在不能使用特性" % card.card_data.name,
				"reason": gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, ability_index),
				"detail": "特性需要满足卡面条件，并且可能受到场上特性封锁效果影响。",
				"kind": "ability",
			})
		return
	scene.call("_start_effect_interaction", "ability", player_index, steps, card, slot, ability_index)
	scene.call("_maybe_run_ai")


func try_use_stadium_with_interaction(scene: Object, player_index: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state.stadium_card == null:
		return
	var stadium_card: CardInstance = gsm.game_state.stadium_card
	var effect: BaseEffect = gsm.effect_processor.get_effect(stadium_card.card_data.effect_id)
	if effect == null:
		if gsm.use_stadium_effect(player_index):
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		else:
			scene.call("_log", _bt(scene, "battle.log.stadium_unavailable"))
		return
	if not gsm.can_use_stadium_effect(player_index):
		_show_invalid_action_hint(scene, {
			"title": "竞技场能力现在不能使用",
			"reason": _bt(scene, "battle.log.stadium_unavailable"),
			"kind": "stadium",
		})
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium_card, gsm.game_state)
	if steps.is_empty():
		if gsm.use_stadium_effect(player_index):
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		else:
			_show_invalid_action_hint(scene, {
				"title": "竞技场能力现在不能使用",
				"reason": _bt(scene, "battle.log.stadium_unavailable"),
				"kind": "stadium",
			})
		return
	scene.call("_start_effect_interaction", "stadium", player_index, steps, stadium_card)
	scene.call("_maybe_run_ai")


func _show_invalid_card_hint(scene: Object, card: CardInstance, reason: String, kind: String) -> void:
	if reason.strip_edges() == "" and card != null and card.card_data != null:
		reason = "%s 当前无法使用。" % card.card_data.name
	var title := "当前无法执行"
	var detail := ""
	if card != null and card.card_data != null:
		title = "%s 现在不能使用" % card.card_data.name
		detail = _card_detail_summary(card.card_data)
	_show_invalid_action_hint(scene, {
		"title": title,
		"reason": reason,
		"detail": detail,
		"hint": _hint_for_kind(kind),
		"kind": kind,
	})


func _show_invalid_action_hint(scene: Object, payload: Dictionary) -> void:
	var reason := str(payload.get("reason", "")).strip_edges()
	if reason == "":
		reason = "当前无法执行该操作。"
		payload["reason"] = reason
	if scene.has_method("_show_invalid_action_hint"):
		scene.call("_show_invalid_action_hint", payload)
	scene.call("_log", reason)


func _card_detail_summary(card_data: CardData) -> String:
	if card_data == null:
		return ""
	if card_data.description.strip_edges() != "":
		return card_data.description.strip_edges()
	if card_data.is_pokemon():
		if card_data.stage == "Basic":
			return "基础宝可梦可以在主要阶段放到备战区，但需要备战区有空位。"
		return "进化宝可梦需要选择符合进化条件的己方宝可梦。"
	match card_data.card_type:
		"Supporter":
			return "支援者卡通常每回合只能使用 1 张。"
		"Item":
			return "物品卡需要满足卡面效果和场上状态要求。"
		"Stadium":
			return "竞技场卡会替换场上的其他竞技场，但不能替换同名竞技场。"
		"Basic Energy", "Special Energy":
			return "从手牌附着能量通常每回合只能进行 1 次。"
		"Tool":
			return "宝可梦道具需要附着到没有道具的有效目标上。"
		_:
			return ""


func _hint_for_kind(kind: String) -> String:
	match kind:
		"supporter":
			return "可以改用物品、特性、招式，或结束回合等待下回合。"
		"energy":
			return "如果已经手贴过能量，可以寻找卡牌效果带来的额外加速。"
		"pokemon":
			return "先让备战区空出位置，或选择其他操作。"
		"stadium":
			return "如果场上已经是同名竞技场，需要换成不同名称的竞技场。"
		"item", "trainer":
			return "检查场上限制、费用和目标是否满足。"
		_:
			return ""
