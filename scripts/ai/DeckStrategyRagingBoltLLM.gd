extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const RagingBoltRulesScript = preload("res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd")

const RAGING_BOLT_LLM_ID := "raging_bolt_ogerpon_llm"

var _deck_strategy_text: String = ""
var _rules: RefCounted = RagingBoltRulesScript.new()


func get_strategy_id() -> String:
	return RAGING_BOLT_LLM_ID


func get_signature_names() -> Array[String]:
	return _rules.call("get_signature_names") if _rules != null and _rules.has_method("get_signature_names") else []


func get_state_encoder_class() -> GDScript:
	return _rules.call("get_state_encoder_class") if _rules != null and _rules.has_method("get_state_encoder_class") else null


func load_value_net(path: String) -> bool:
	return bool(_rules.call("load_value_net", path)) if _rules != null and _rules.has_method("load_value_net") else false


func get_value_net() -> RefCounted:
	return _rules.call("get_value_net") if _rules != null and _rules.has_method("get_value_net") else null


func get_mcts_config() -> Dictionary:
	return _rules.call("get_mcts_config") if _rules != null and _rules.has_method("get_mcts_config") else {}


func set_deck_strategy_text(strategy_text: String) -> void:
	_deck_strategy_text = strategy_text.strip_edges()
	if _rules != null and _rules.has_method("set_deck_strategy_text"):
		_rules.call("set_deck_strategy_text", strategy_text)


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
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var absolute := score_action_absolute(action, context_game_state, int(context.get("player_index", -1)))
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
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			return planned
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty():
		return snapshot
	snapshot["raging_bolt_burst_ready"] = _active_raging_bolt_burst_cost_ready(game_state, player_index)
	snapshot["raging_bolt_burst_damage"] = _raging_bolt_burst_damage_estimate(game_state, player_index)
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	return _raging_bolt_setup_role_hint(cd)


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	return _raging_bolt_strategy_prompt(game_state, player_index)


func _raging_bolt_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return ""
	if _name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt"):
		return "main_attacker"
	if _name_contains(str(cd.name_en), "Teal Mask Ogerpon ex") or _name_contains(str(cd.name), "厄诡椪"):
		return "energy_engine"
	if _name_contains(str(cd.name_en), "Radiant Greninja"):
		return "draw_engine"
	if _name_contains(str(cd.name_en), "Squawkabilly ex"):
		return "opening_draw_support"
	return "support"


func _raging_bolt_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var attack_name := _active_bolt_burst_attack_name(game_state, player_index)
	var active_position_hint := _active_position_hint(game_state, player_index)
	var strategy_text := get_deck_strategy_text()
	if strategy_text.strip_edges() == "":
		strategy_text = _default_raging_bolt_strategy_text()
	var lines: Array[String] = [
		"【卡组编辑器打法思路】以下内容来自卡组编辑器的打法思路；玩家可以编辑它来调整猛雷鼓 AI 的战术偏好。",
	]
	lines.append_array(_strategy_text_to_prompt_lines(strategy_text, 18))
	lines.append("【当前场面提示】%s。如果前场猛雷鼓ex的爆发招式已经满足条件，攻击名必须复制为「%s」；除非没有拿奖压力或稳定展开路线，否则不要优先使用弃手牌抽牌的一技能。" % [active_position_hint, attack_name])
	lines.append("【执行边界】具体每张牌怎么结算，以 legal_actions、card_rules、interaction_hints 为准；打法思路只决定战术优先级，不允许编造动作 id、卡名、攻击名或交互字段。")
	lines.append("【决策树形状】优先给出能拿奖/高压、铺场后攻击、检索/蓄能后攻击、换位后攻击、下回合准备、保手牌兜底这些路线；能攻击时攻击必须放在线路末尾，不能用 end_turn 代替。")
	return PackedStringArray(lines)


func _default_raging_bolt_strategy_text() -> String:
	return "\n".join([
		"【卡组定位】猛雷鼓ex/厄诡椪 碧草面具ex高速爆发卡组。核心目标是让猛雷鼓ex满足【雷】【斗】攻击费用，并把我方场上的基本能量转化为「极雷轰」伤害。",
		"【核心计划】猛雷鼓ex是主要攻击手。「极雷轰」将我方场上任意数量基本能量放入弃牌区，造成70x张数伤害。3能量=210，4能量=280，5能量=350。",
		"厄诡椪 碧草面具ex负责把手牌草能贴到自己身上并抽1张，既增加场上能量数量，也不占用手动贴能。",
		"奥琳博士的气魄负责把弃牌区基本能量贴给古代宝可梦并抽牌，优先让猛雷鼓ex补齐雷+斗攻击费用或增加斩杀能量。",
		"大地容器、能量回收、夜晚担架等资源牌围绕缺失能量服务，优先找雷/斗满足攻击，再考虑草能供厄诡椪继续蓄力。",
		"勇气护符优先给前场或即将上前的基础攻击手，帮助猛雷鼓ex或厄诡椪ex多扛一击。",
		"【回合优先级】能拿奖或形成高压时，先做不影响攻击的安全铺场、贴工具、厄诡椪特性、奥琳/检索/手贴，然后用猛雷鼓ex攻击。",
		"打不出攻击时，目标是保留下回合资源：铺第二只猛雷鼓/厄诡椪，准备雷+斗，增加场上基本能量，不要无意义打空手牌。",
		"如果当前攻击已经足够击倒，不要继续过度抽滤或消耗手牌；停止挖牌并攻击。",
		"攻击会结束回合，所有想做的铺场、检索、贴能、贴工具、切换都必须放在攻击前。",
	])


func _active_bolt_burst_attack_name(game_state: GameState, player_index: int) -> String:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return "<copy from active.attacks>"
	var player: PlayerState = game_state.players[player_index]
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return "<copy from active.attacks>"
	if not _name_contains(str(active.get_card_data().name_en), "Raging Bolt ex") and not _name_contains(str(active.get_card_data().name), "Raging Bolt"):
		return "<copy from active.attacks>"
	var attacks: Array = active.get_card_data().attacks
	if attacks.size() >= 2:
		return str((attacks[1] as Dictionary).get("name", ""))
	if attacks.size() == 1:
		return str((attacks[0] as Dictionary).get("name", ""))
	return "<copy from active.attacks>"


func _apply_deck_specific_llm_repairs(tree: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result := _enrich_sparse_tree_for_raging_bolt(tree)
	return _augment_attack_first_tree_for_raging_bolt(result, game_state, player_index)


func _deck_snapshot_has_live_terminal_conversion(snapshot: Dictionary) -> bool:
	return bool(snapshot.get("raging_bolt_burst_ready", false)) and int(snapshot.get("raging_bolt_burst_damage", 0)) > 0


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_current_action_raging_bolt_burst_ref(action, game_state, player_index)


func _deck_should_block_exact_queue_match(queued_action: Dictionary, _runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_raging_bolt_first_attack_ref(queued_action, game_state, player_index) \
		and _is_current_action_raging_bolt_burst_available(game_state, player_index)


func _deck_queue_item_matches_action(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_raging_bolt_first_attack_ref(queued_action, game_state, player_index) \
		and _is_current_action_raging_bolt_burst_ref(runtime_action, game_state, player_index)


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ""))
	var card_name := str(ref.get("card", ""))
	var pokemon_name := str(ref.get("pokemon", ""))
	if action_type == "play_trainer" and (_name_contains(card_name, "Professor Sada's Vitality") or _name_contains(card_name, "Earthen Vessel")):
		return true
	if action_type == "use_ability" and _name_contains(pokemon_name, "Teal Mask Ogerpon ex"):
		return true
	return false


func _deck_validate_action_interactions(_action_id: String, ref: Dictionary, interactions: Dictionary, path: String, errors: Array[String]) -> void:
	var card_name := str(ref.get("card", ""))
	if _name_contains(card_name, "Professor Sada's Vitality"):
		for bad_key: String in ["search_target", "search_targets", "search_energy", "discard_energy_types", "discard_energy_type"]:
			if interactions.has(bad_key):
				errors.append("%s gives Professor Sada's Vitality invalid interaction '%s'; use sada_assignments instead" % [path, bad_key])
	if _name_contains(card_name, "Earthen Vessel"):
		for key: String in interactions.keys():
			if key not in ["discard_cards", "discard_card", "search_energy", "search_target", "search_targets"]:
				errors.append("%s gives Earthen Vessel unsupported interaction '%s'" % [path, key])
	var pokemon_name := str(ref.get("pokemon", ref.get("card", "")))
	if str(ref.get("type", "")) == "use_ability" and _name_contains(pokemon_name, "Teal Mask Ogerpon ex"):
		for bad_key: String in ["search_target", "search_targets", "search_energy", "search_cards"]:
			if interactions.has(bad_key):
				errors.append("%s gives Teal Mask Ogerpon ex invalid interaction '%s'; use basic_energy_from_hand or energy_card_id instead" % [path, bad_key])


func _deck_preferred_terminal_attack_for(action: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if not _is_raging_bolt_first_attack_ref(action, game_state, player_index):
		return {}
	var burst: Dictionary = _raging_bolt_burst_attack_ref(game_state, player_index)
	if not burst.is_empty() and _raging_bolt_burst_is_pressure(burst, game_state, player_index):
		return burst
	return {}


func _deck_is_low_value_runtime_attack_action(_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var cd: CardData = player.active_pokemon.get_card_data()
	return cd != null and (_name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt"))


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name_en := str(card_data.name_en)
	var name := str(card_data.name)
	return _name_contains(name_en, "Professor Sada") \
		or _name_contains(name_en, "Earthen Vessel") \
		or _name_contains(name, "Raging Bolt")


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_current_action_raging_bolt_burst_ref(action, game_state, player_index)


func _deck_estimate_multiplier_attack_damage(_action: Dictionary, game_state: GameState, player_index: int, _base_damage: int, lower_text: String) -> int:
	if _name_contains(lower_text, "raging bolt") or _name_contains(lower_text, "basic energy") or _name_contains(lower_text, "discard"):
		return _raging_bolt_burst_damage_estimate(game_state, player_index)
	return 0


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	if _active_raging_bolt_burst_cost_ready(game_state, player_index):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return false
	if _is_raging_bolt_card_data(active.get_card_data()):
		return false
	return _bench_has_raging_bolt(player) or _hand_has_recovery_or_pivot_piece(player)


func _deck_hand_has_recovery_or_pivot_piece(player: PlayerState) -> bool:
	return _hand_has_recovery_or_pivot_piece(player)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Teal Mask Ogerpon ex", "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Raging Bolt ex", "")
	_append_best_tool_action(target, seen_ids)
	_append_catalog_match(target, seen_ids, "play_trainer", "Earthen Vessel", "", _earthen_vessel_interactions())
	_append_catalog_match(target, seen_ids, "play_trainer", "Energy Retrieval", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Night Stretcher", "")
	_append_greninja_ability(target, seen_ids, _greninja_interactions())
	_append_fezandipiti_ability(target, seen_ids)
	_append_catalog_match(target, seen_ids, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
	_append_virtual_ogerpon_ability(target, seen_ids)
	_append_catalog_match(target, seen_ids, "play_trainer", "Trekking Shoes", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "gear", "")


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_catalog_match(target, seen_ids, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
	if not has_attack:
		_append_catalog_match(target, seen_ids, "play_trainer", "Trekking Shoes", "")


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	return _name_contains(str(card_data.name_en), "Earthen Vessel")


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0
