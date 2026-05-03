extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const MiraidonRulesScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")

const MIRAIDON_LLM_ID := "miraidon_llm"

var _deck_strategy_text: String = ""
var _rules: RefCounted = MiraidonRulesScript.new()


func get_strategy_id() -> String:
	return MIRAIDON_LLM_ID


func get_signature_names() -> Array[String]:
	var names: Array[String] = []
	if _rules != null and _rules.has_method("get_signature_names"):
		for raw_name: Variant in _rules.call("get_signature_names"):
			names.append(str(raw_name))
	for name: String in ["Miraidon ex", "Iron Hands ex", "Raikou V", "Raichu V", "Electric Generator"]:
		if not names.has(name):
			names.append(name)
	return names


func get_state_encoder_class() -> GDScript:
	return _rules.call("get_state_encoder_class") if _rules != null and _rules.has_method("get_state_encoder_class") else null


func load_value_net(path: String) -> bool:
	return bool(_rules.call("load_value_net", path)) if _rules != null and _rules.has_method("load_value_net") else false


func get_value_net() -> RefCounted:
	return _rules.call("get_value_net") if _rules != null and _rules.has_method("get_value_net") else null


func get_mcts_config() -> Dictionary:
	return _rules.call("get_mcts_config") if _rules != null and _rules.has_method("get_mcts_config") else {}


func set_deck_strategy_text(text: String) -> void:
	_deck_strategy_text = text
	if _rules != null and _rules.has_method("set_deck_strategy_text"):
		_rules.call("set_deck_strategy_text", text)


func get_deck_strategy_text() -> String:
	if _deck_strategy_text.strip_edges() != "":
		return _deck_strategy_text
	if _rules != null and _rules.has_method("get_deck_strategy_text"):
		return str(_rules.call("get_deck_strategy_text"))
	return ""


func plan_opening_setup(player: PlayerState) -> Dictionary:
	return _rules.call("plan_opening_setup", player) if _rules != null and _rules.has_method("plan_opening_setup") else {}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return _rules.call("score_action_absolute", action, game_state, player_index) if _rules != null and _rules.has_method("score_action_absolute") else 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var absolute := score_action_absolute(action, game_state, int(context.get("player_index", -1)))
		return absolute - _rules_heuristic_base(str(action.get("kind", "")))
	return _rules.call("score_action", action, context) if _rules != null and _rules.has_method("score_action") else 0.0


func evaluate_board(game_state: GameState, player_index: int) -> float:
	return float(_rules.call("evaluate_board", game_state, player_index)) if _rules != null and _rules.has_method("evaluate_board") else 0.0


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	return _rules.call("predict_attacker_damage", slot, extra_context) if _rules != null and _rules.has_method("predict_attacker_damage") else {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	return int(_rules.call("get_discard_priority", card)) if _rules != null and _rules.has_method("get_discard_priority") else 0


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	return int(_rules.call("get_discard_priority_contextual", card, game_state, player_index)) if _rules != null and _rules.has_method("get_discard_priority_contextual") else get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	return int(_rules.call("get_search_priority", card)) if _rules != null and _rules.has_method("get_search_priority") else 0


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var game_state: GameState = context.get("game_state", null)
	if _should_force_rules_top_deck_setup(step, context):
		var forced: Array = _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
		if not forced.is_empty():
			return forced
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var picked: Array = super.pick_interaction_items(items, step, context)
		if not picked.is_empty():
			return picked
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if _should_force_rules_top_deck_setup(step, context):
		return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	return {
		"turn": int(game_state.turn_number),
		"phase": int(game_state.phase),
		"player_index": player_index,
		"current_player_index": int(game_state.current_player_index),
		"energy_attached_this_turn": bool(game_state.energy_attached_this_turn),
		"supporter_used_this_turn": bool(game_state.supporter_used_this_turn),
		"retreat_used_this_turn": bool(game_state.retreat_used_this_turn),
		"stadium_played_this_turn": bool(game_state.stadium_played_this_turn),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard_count": player.discard_pile.size(),
		"hand_ids": _card_instance_id_list(player.hand),
		"hand_names": _card_name_list(player.hand),
		"active_attack_ready": _active_can_attack_now(player),
		"electric_generator_in_hand": _hand_has_name(player, "Electric Generator"),
		"miraidon_count": _count_field_name(player, "Miraidon ex"),
	}


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, "Miraidon ex"):
		return "最高优先级铺场引擎；尽早上场，用特性找雷系基础宝可梦"
	if _name_contains(name, "Iron Hands ex"):
		return "主要奖赏竞速攻击手；优先配 Double Turbo Energy/雷能，并用 Heavy Baton 保护能量"
	if _name_contains(name, "Raikou V"):
		return "高速中期攻击手；双方备战区展开后输出更高"
	if _name_contains(name, "Raichu V"):
		return "后期爆发终结手；早期不要随便放，除非已经接近终结路线"
	if _name_contains(name, "Zapdos"):
		return "雷系伤害支援与一奖攻击手"
	if _name_contains(name, "Mew ex"):
		return "低撤退中转点与补牌支援"
	if _name_contains(name, "Squawkabilly ex"):
		return "开局爆发补牌引擎；过早期后通常不要再放"
	if _name_contains(name, "Lumineon V"):
		return "支援者检索件；只有需要派帕/老板/奇树路线时才放"
	if _name_contains(name, "Radiant Greninja"):
		return "滤牌与弃能引擎；手牌需要过滤时上场"
	if _name_contains(name, "Bloodmoon Ursaluna ex"):
		return "后期低费反打攻击手"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("【卡组定位】密勒顿是高速雷系基础宝可梦卡组。先铺 Miraidon ex 和真实攻击手，再把 Electric Generator 命中的能量转化成立刻进攻，用 Iron Hands ex、Raikou V、Zapdos、Raichu V、Bloodmoon Ursaluna ex 赢奖赏竞速。")
	lines.append("【铺场优先级】第一目标是 Miraidon ex + 至少一个能马上成长为攻击手的宝可梦。场上缺雷系目标时，先用 Miraidon ex 或 Nest Ball 铺目标，再使用 Electric Generator。Iron Hands ex 和 Raikou V 适合早放；Raichu V 主要用于后期终结，不要早期无目的上场当负担。")
	lines.append("【防裸奔原则】如果自己只有前场、后场为空，所有搜索/置顶动作的第一目标都是让下回合或本回合能立刻放下宝可梦。Ciphermaniac's Codebreaking 置顶时第一张必须优先 Miraidon ex、Nest Ball、Raikou V 或 Iron Hands ex，不能先放 Lightning Energy。")
	lines.append("【能量策略】手贴和 Electric Generator 都应给离本回合攻击最近的攻击手。Double Turbo Energy 主要服务 Iron Hands ex 的 Amp You Very Much；除非能马上形成攻击，不要浪费给无关宝可梦。已经满足攻击条件的宝可梦不要再过度贴能。")
	lines.append("【Electric Generator 策略】Generator 不是盲打牌。先确认备战区有可贴雷能的优质目标；如果 Generator 能让 Iron Hands ex、Raikou V 或 Zapdos 本回合攻击，就优先完整执行这条路线。没有好目标时先铺场。")
	lines.append("【攻击策略】攻击会结束回合，所以先完成安全铺场、贴能、工具、换位、抓人，再攻击。优先选择能拿奖、造成两奖节奏、或精确建立下回合奖赏数学的攻击。Iron Hands ex 多拿一奖价值很高；Raikou V 是快速节奏攻击手；Raichu V 是花费雷能的终结爆发，不要在不能赢或逼近胜利时随便用。")
	lines.append("【工具和换位】Heavy Baton 优先贴给已有能量或即将承接能量的 Iron Hands ex。Bravery Charm 给当前或下一只关键攻击手保命。Rescue Board/Emergency Board 给中转点或被卡前场的宝可梦。Switch Cart 和 Prime Catcher 应服务于进攻或拿奖，不要无意义换位。")
	lines.append("【支援者和资源】Arven 优先找能完成本回合路线的 Electric Generator、Nest Ball、Heavy Baton、Forest Seal Stone 或换位工具。Boss's Orders 和 Prime Catcher 只有在能制造击杀、关键压制或终局奖赏路线时才抓后排。Iono 是干扰和补牌工具，不是已有路线时的默认动作。")
	lines.append("【奖赏策略】明确双方剩余奖赏。落后时优先 Iron Hands ex 的额外奖赏和 Bloodmoon Ursaluna ex 的低费反打；领先时保护攻击手，减少不必要的两奖负担。任何能本回合合法取胜的路线都应最高优先级。")
	lines.append("【重规划策略】Miraidon ex、Nest Ball、Arven、Electric Generator、Squawkabilly ex、Radiant Greninja、Forest Seal Stone 改变手牌/场面/能量后，必须基于新的 legal_actions 重新评估，不要机械结束回合。")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("【玩家自定义策略】以下是玩家写入的密勒顿策略；不与 legal_actions 和结构化卡牌规则冲突时优先参考：")
		lines.append(custom_text)
	lines.append("【执行边界】准确的 action id、卡牌文本、interaction schema、HP、工具、能量、手牌、弃牌、奖赏和对手场面都来自结构化 payload。不要编造 action id、卡牌效果、目标或交互字段。")
	return lines


func _apply_deck_specific_llm_repairs(tree: Dictionary, _game_state: GameState, _player_index: int) -> Dictionary:
	return _repair_miraidon_llm_node(tree)


func _deck_replan_trigger_after_state_change(before_snapshot: Dictionary, after_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	if str(context.get("action_kind", "")) != "play_basic_to_bench":
		return {"should_replan": false}
	if int(after_snapshot.get("miraidon_count", 0)) <= int(before_snapshot.get("miraidon_count", 0)):
		return {"should_replan": false}
	return {
		"should_replan": true,
		"reason": "miraidon_benched_tandem_unit_now_legal",
		"before_miraidon_count": int(before_snapshot.get("miraidon_count", 0)),
		"after_miraidon_count": int(after_snapshot.get("miraidon_count", 0)),
	}


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, _game_state: GameState, _player_index: int) -> bool:
	var q_kind := str(queued_action.get("type", queued_action.get("kind", "")))
	var runtime_kind := str(runtime_action.get("kind", ""))
	if q_kind != "" and q_kind != runtime_kind and q_kind != "action_ref":
		return false
	if runtime_kind == "attach_energy":
		return _should_block_miraidon_energy_attach(runtime_action)
	if runtime_kind == "attach_tool":
		return _should_block_miraidon_tool_attach(runtime_action)
	return false


func _should_block_miraidon_energy_attach(runtime_action: Dictionary) -> bool:
	var card: CardInstance = runtime_action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var target_slot: PokemonSlot = runtime_action.get("target_slot", null)
	if target_slot == null or target_slot.get_card_data() == null:
		return true
	var energy_name := _best_card_name(card.card_data)
	var energy_provides := str(card.card_data.energy_provides)
	var target_name := _best_card_name(target_slot.get_card_data())
	if _name_contains(energy_name, "Double Turbo Energy"):
		return not _is_iron_hands_name(target_name)
	if energy_provides == "L" or _name_contains(energy_name, "Lightning Energy"):
		return not _is_miraidon_energy_target_name(target_name)
	return false


func _should_block_miraidon_tool_attach(runtime_action: Dictionary) -> bool:
	var card: CardInstance = runtime_action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var tool_name := _best_card_name(card.card_data)
	var target_slot: PokemonSlot = runtime_action.get("target_slot", null)
	if target_slot == null or target_slot.get_card_data() == null:
		return true
	var target_name := _best_card_name(target_slot.get_card_data())
	if _name_contains(tool_name, "Heavy Baton") or _name_contains(tool_name, "沉重接力棒"):
		return not _is_iron_hands_name(target_name)
	if _name_contains(tool_name, "Bravery Charm") or _name_contains(tool_name, "勇气护符"):
		return not _is_miraidon_attacker_name(target_name)
	if _name_contains(tool_name, "Forest Seal Stone") or _name_contains(tool_name, "森林封印石"):
		return not _is_forest_seal_stone_target_name(target_name)
	return false


func _should_force_rules_top_deck_setup(step: Dictionary, context: Dictionary) -> bool:
	if str(step.get("id", "")) != "top_cards":
		return false
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and player.bench.is_empty()


func _repair_miraidon_llm_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if result.has(key):
			result[key] = _repair_miraidon_action_array(result.get(key, []))
	var parent_actions: Array[Dictionary] = _dictionary_array(result.get("actions", []))
	var parent_generators: Array[Dictionary] = _extract_electric_generators_before_miraidon(parent_actions)
	if not parent_generators.is_empty():
		result["actions"] = parent_actions
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		var generators_pending: Array[Dictionary] = parent_generators.duplicate(true)
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			var branch_actions: Array[Dictionary] = _repair_miraidon_action_array(branch.get("actions", []))
			if not generators_pending.is_empty() and _contains_miraidon_bench_ref(branch_actions):
				for generator_ref: Dictionary in generators_pending:
					branch_actions = _insert_after_first_miraidon_bench(branch_actions, generator_ref)
				generators_pending.clear()
			branch["actions"] = branch_actions
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				branch["then"] = _repair_miraidon_llm_node(then_node as Dictionary)
			if branch.has("fallback_actions"):
				branch["fallback_actions"] = _repair_miraidon_action_array(branch.get("fallback_actions", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return result


func _repair_miraidon_action_array(raw_actions: Variant) -> Array[Dictionary]:
	var actions: Array[Dictionary] = _dictionary_array(raw_actions)
	for i: int in actions.size():
		if _is_miraidon_bench_ref(actions[i]):
			actions[i].erase("interactions")
			actions[i].erase("selection_policy")
	return _move_generators_after_miraidon_bench(actions)


func _move_generators_after_miraidon_bench(actions: Array[Dictionary]) -> Array[Dictionary]:
	var last_setup_index := _last_opening_setup_index(actions)
	if last_setup_index <= 0:
		return actions
	var moved: Array[Dictionary] = []
	for i: int in range(last_setup_index - 1, -1, -1):
		if _is_electric_generator_ref(actions[i]):
			moved.push_front(actions[i])
			actions.remove_at(i)
			last_setup_index -= 1
	for generator_ref: Dictionary in moved:
		actions.insert(last_setup_index + 1, generator_ref)
		last_setup_index += 1
	return actions


func _extract_electric_generators_before_miraidon(actions: Array[Dictionary]) -> Array[Dictionary]:
	var first_setup_index := _first_opening_setup_index(actions)
	if first_setup_index >= 0:
		return []
	var generators: Array[Dictionary] = []
	for i: int in range(actions.size() - 1, -1, -1):
		if _is_electric_generator_ref(actions[i]):
			generators.push_front(actions[i])
			actions.remove_at(i)
	return generators


func _insert_after_first_miraidon_bench(actions: Array[Dictionary], ref: Dictionary) -> Array[Dictionary]:
	var index := _last_opening_setup_index(actions)
	if index < 0:
		actions.push_front(ref)
	else:
		actions.insert(index + 1, ref)
	return actions


func _contains_miraidon_bench_ref(actions: Array[Dictionary]) -> bool:
	return _first_opening_setup_index(actions) >= 0


func _first_miraidon_bench_index(actions: Array[Dictionary]) -> int:
	for i: int in actions.size():
		if _is_miraidon_bench_ref(actions[i]):
			return i
	return -1


func _first_opening_setup_index(actions: Array[Dictionary]) -> int:
	for i: int in actions.size():
		if _is_miraidon_opening_setup_ref(actions[i]):
			return i
	return -1


func _last_opening_setup_index(actions: Array[Dictionary]) -> int:
	for i: int in range(actions.size() - 1, -1, -1):
		if _is_miraidon_opening_setup_ref(actions[i]):
			return i
	return -1


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	if has_attack:
		return
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id := str(raw_key)
		if action_id == "" or bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or not _is_tandem_unit_ref(ref):
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		copy["capability"] = "bench_search"
		target.append(copy)
		seen_ids[action_id] = true


func _dictionary_array(raw_actions: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_actions is Array):
		return result
	for raw_action: Variant in raw_actions:
		if raw_action is Dictionary:
			result.append((raw_action as Dictionary).duplicate(true))
	return result


func _is_electric_generator_ref(ref: Dictionary) -> bool:
	return _action_ref_type(ref) == "play_trainer" and _name_contains(_action_ref_card_name(ref), "Electric Generator")


func _is_miraidon_bench_ref(ref: Dictionary) -> bool:
	return _action_ref_type(ref) == "play_basic_to_bench" and _name_contains(_action_ref_card_name(ref), "Miraidon ex")


func _is_miraidon_opening_setup_ref(ref: Dictionary) -> bool:
	if _is_miraidon_bench_ref(ref) or _is_tandem_unit_ref(ref):
		return true
	var ref_type := _action_ref_type(ref)
	var card_name := _action_ref_card_name(ref)
	if ref_type == "play_basic_to_bench":
		return _is_miraidon_attacker_name(card_name)
	if ref_type == "play_trainer":
		return _name_contains(card_name, "Nest Ball") or _name_contains(card_name, "Buddy-Buddy Poffin")
	return false


func _is_tandem_unit_ref(ref: Dictionary) -> bool:
	if _action_ref_type(ref) != "use_ability":
		return false
	var text := _action_ref_text(ref)
	return _name_contains(text, "Miraidon ex") or _name_contains(text, "Tandem Unit")


func _action_ref_type(ref: Dictionary) -> String:
	return str(ref.get("type", ref.get("kind", "")))


func _action_ref_card_name(ref: Dictionary) -> String:
	var card_name := str(ref.get("card", ""))
	if card_name != "":
		return card_name
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		return str((card_rules as Dictionary).get("name", (card_rules as Dictionary).get("name_en", "")))
	return ""


func _action_ref_text(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("summary", "")),
	]
	for key: String in ["card_rules", "ability_rules"]:
		var raw: Variant = ref.get(key, {})
		if raw is Dictionary:
			var rules: Dictionary = raw
			parts.append(str(rules.get("name", "")))
			parts.append(str(rules.get("name_en", "")))
			parts.append(str(rules.get("text", "")))
			parts.append(str(rules.get("description", "")))
	return " ".join(parts)


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _is_iron_hands_name(name: String) -> bool:
	return _name_contains(name, "Iron Hands ex") or _name_contains(name, "铁臂膀ex")


func _is_miraidon_attacker_name(name: String) -> bool:
	return _is_iron_hands_name(name) \
		or _name_contains(name, "Miraidon ex") or _name_contains(name, "密勒顿ex") \
		or _name_contains(name, "Raikou V") or _name_contains(name, "雷公V") \
		or _name_contains(name, "Raichu V") or _name_contains(name, "雷丘V") \
		or _name_contains(name, "Zapdos") or _name_contains(name, "闪电鸟") \
		or _name_contains(name, "Bloodmoon Ursaluna ex") or _name_contains(name, "月月熊")


func _is_miraidon_energy_target_name(name: String) -> bool:
	return _is_miraidon_attacker_name(name)


func _is_forest_seal_stone_target_name(name: String) -> bool:
	return _name_contains(name, "Raikou V") or _name_contains(name, "雷公V") \
		or _name_contains(name, "Raichu V") or _name_contains(name, "雷丘V") \
		or _name_contains(name, "Lumineon V") or _name_contains(name, "霓虹鱼V")


func _active_can_attack_now(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var prediction: Dictionary = predict_attacker_damage(player.active_pokemon)
	return bool(prediction.get("can_attack", false))


func _hand_has_name(player: PlayerState, query: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _name_contains(str(card.card_data.name_en), query) or _name_contains(str(card.card_data.name), query):
			return true
	return false


func _count_field_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _slot_name_contains(player.active_pokemon, query):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_name_contains(slot, query):
			count += 1
	return count


func _slot_name_contains(slot: PokemonSlot, query: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	return _name_contains(str(cd.name_en), query) or _name_contains(str(cd.name), query)
