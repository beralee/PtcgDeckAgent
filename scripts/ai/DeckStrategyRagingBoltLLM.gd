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
		if _is_unproductive_gust_commit_action(action, game_state, player_index):
			return -10000.0
		if _is_core_energy_preservation_risk_action(action, game_state, player_index):
			return -10000.0
		if _is_off_plan_attack_energy_attach(action, game_state, player_index):
			return -10000.0
		var handoff_attach_score := _score_backup_attacker_handoff_attach(action, game_state, player_index)
		if handoff_attach_score > 0.0:
			return handoff_attach_score
		if _is_off_plan_survival_tool_attach(action, game_state, player_index):
			return -10000.0
		if _is_off_plan_support_basic_bench(action, game_state, player_index):
			return -10000.0
		if _is_support_active_trap_action(action, game_state, player_index):
			return -10000.0
		if _is_low_deck_unplanned_draw_action(action, game_state, player_index) \
				and not _is_low_deck_attack_unlock_action(action, game_state, player_index):
			return -10000.0
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
		if _is_low_deck_unplanned_draw_action(action, game_state, player_index):
			return -10000.0
	if _is_off_plan_attack_energy_attach(action, game_state, player_index):
		return -10000.0
	var rules_handoff_attach_score := _score_backup_attacker_handoff_attach(action, game_state, player_index)
	if rules_handoff_attach_score > 0.0:
		return rules_handoff_attach_score
	if _is_off_plan_survival_tool_attach(action, game_state, player_index):
		return -10000.0
	if _is_off_plan_support_basic_bench(action, game_state, player_index):
		return -10000.0
	if _is_support_active_trap_action(action, game_state, player_index):
		return -10000.0
	if _is_unproductive_gust_commit_action(action, game_state, player_index):
		return -10000.0
	if _is_core_energy_preservation_risk_action(action, game_state, player_index):
		return -10000.0
	if _is_low_deck_unplanned_draw_action(action, game_state, player_index) \
			and not _is_low_deck_attack_unlock_action(action, game_state, player_index):
		return -10000.0
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
	if _is_self_pivot_target_step(step):
		var pivot_pick := _pick_best_self_pivot_target(items, context)
		if not pivot_pick.is_empty():
			return pivot_pick
	if _is_raging_bolt_burst_field_discard_step(items, step, context):
		var burst_pick: Array = _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
		if not burst_pick.is_empty():
			return burst_pick
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			return planned
		var core_pick := _pick_core_attacker_from_available_items(items, step, context)
		if not core_pick.is_empty():
			return core_pick
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot and _is_self_pivot_target_step(step):
		return _score_self_pivot_target(item as PokemonSlot, context)
	var context_game_state: GameState = context.get("game_state", null)
	if context_game_state != null and has_llm_plan_for_turn(int(context_game_state.turn_number)):
		if item is PokemonSlot and _is_opponent_gust_target_step(step, context):
			var gust_score := _score_raging_bolt_gust_target(item as PokemonSlot, context)
			if gust_score != 0.0:
				return gust_score
		var core_score := _score_core_attacker_search_target(item, step, context)
		if core_score != 0.0:
			return core_score
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
	var player: PlayerState = game_state.players[player_index]
	snapshot["raging_bolt_count"] = _raging_bolt_field_count(player)
	snapshot["active_is_raging_bolt"] = player != null \
		and player.active_pokemon != null \
		and _is_raging_bolt_card_data(player.active_pokemon.get_card_data())
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


func _deck_replan_trigger_after_state_change(before_snapshot: Dictionary, after_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	if str(context.get("action_kind", "")) != "play_basic_to_bench":
		return {"should_replan": false}
	var before_count := int(before_snapshot.get("raging_bolt_count", 0))
	var after_count := int(after_snapshot.get("raging_bolt_count", 0))
	if after_count <= before_count:
		return {"should_replan": false}
	if bool(after_snapshot.get("active_is_raging_bolt", false)):
		return {"should_replan": false}
	return {
		"should_replan": true,
		"reason": "raging_bolt_benched_retarget_attack_energy",
		"before_raging_bolt_count": before_count,
		"after_raging_bolt_count": after_count,
	}


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_current_action_raging_bolt_burst_ref(action, game_state, player_index)


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_raging_bolt_first_attack_ref(queued_action, game_state, player_index) \
			and _is_current_action_raging_bolt_burst_available(game_state, player_index):
		return true
	return _is_off_plan_attack_energy_attach(runtime_action, game_state, player_index) \
		or _is_off_plan_survival_tool_attach(runtime_action, game_state, player_index) \
		or _is_off_plan_support_basic_bench(runtime_action, game_state, player_index) \
		or _is_unproductive_gust_commit_action(runtime_action, game_state, player_index) \
		or _is_core_energy_preservation_risk_action(runtime_action, game_state, player_index)


func _deck_queue_item_matches_action(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_raging_bolt_first_attack_ref(queued_action, game_state, player_index) \
			and _is_current_action_raging_bolt_burst_ref(runtime_action, game_state, player_index):
		return true
	return _queued_raging_bolt_attach_matches_runtime_attach(queued_action, runtime_action, game_state, player_index)


func _queued_raging_bolt_attach_matches_runtime_attach(
	queued_action: Dictionary,
	runtime_action: Dictionary,
	game_state: GameState,
	player_index: int
) -> bool:
	if str(queued_action.get("type", queued_action.get("kind", ""))) != "attach_energy":
		return false
	if str(runtime_action.get("kind", runtime_action.get("type", ""))) != "attach_energy":
		return false
	var runtime_card: CardInstance = runtime_action.get("card", null)
	if runtime_card == null or runtime_card.card_data == null:
		return false
	if not _queued_attach_uses_same_card(queued_action, runtime_card):
		return false
	var target_slot: PokemonSlot = runtime_action.get("target_slot", null)
	if target_slot == null or target_slot.get_card_data() == null:
		return false
	if not _is_raging_bolt_card_data(target_slot.get_card_data()):
		return false
	if _is_off_plan_attack_energy_attach(runtime_action, game_state, player_index):
		return false
	var energy_symbol := _energy_symbol_for_runtime(str(runtime_card.card_data.energy_provides))
	if energy_symbol not in ["L", "F", "G"]:
		return false
	if energy_symbol == "G" and not _raging_bolt_slot_has_core_attack_cost(target_slot):
		return false
	return true


func _queued_attach_uses_same_card(queued_action: Dictionary, runtime_card: CardInstance) -> bool:
	var action_id := str(queued_action.get("action_id", queued_action.get("id", ""))).strip_edges()
	var token := _card_token_from_action_id(action_id)
	if token != "" and token != "c%d" % int(runtime_card.instance_id):
		return false
	var queued_card_name := str(queued_action.get("card", "")).strip_edges()
	if queued_card_name == "":
		return true
	var runtime_name := "%s %s" % [str(runtime_card.card_data.name_en), str(runtime_card.card_data.name)]
	return _name_contains(runtime_name, queued_card_name) or _name_contains(queued_card_name, runtime_name)


func _card_token_from_action_id(action_id: String) -> String:
	var parts := action_id.split(":")
	for part: String in parts:
		if part.begins_with("c") and part.length() > 1:
			return part
	return ""


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
		if not interactions.has("sada_assignments"):
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
	if cd == null:
		return false
	var name_en := str(cd.name_en)
	var name := str(cd.name)
	if _name_contains(name_en, "Raging Bolt ex") or _name_contains(name, "Raging Bolt"):
		return true
	return _name_contains(name_en, "Squawkabilly ex") \
		or _name_contains(name_en, "Radiant Greninja") \
		or _name_contains(name_en, "Iron Bundle") \
		or _name_contains(name_en, "Slither Wing") \
		or _name_contains(name, "Squawkabilly") \
		or _name_contains(name, "Radiant Greninja") \
		or _name_contains(name, "Iron Bundle") \
		or _name_contains(name, "Slither Wing")


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


func _raging_bolt_field_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _is_raging_bolt_card_data(player.active_pokemon.get_card_data()):
		count += 1
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and _is_raging_bolt_card_data(bench_slot.get_card_data()):
			count += 1
	return count


func _is_off_plan_attack_energy_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var target_slot: PokemonSlot = action.get("target_slot", null)
	if target_slot == null or target_slot.get_card_data() == null:
		return false
	var energy_card: CardInstance = action.get("card", null)
	if energy_card == null or energy_card.card_data == null:
		return false
	var energy_symbol := _energy_symbol_for_runtime(str(energy_card.card_data.energy_provides))
	if _is_raging_bolt_card_data(target_slot.get_card_data()):
		if _is_doomed_active_raging_bolt_attach(player, target_slot, energy_symbol):
			return true
		return energy_symbol == "G" and not _raging_bolt_slot_has_core_attack_cost(target_slot)
	if _is_support_engine_slot(target_slot):
		return true
	if not (_bench_has_raging_bolt(player) or _hand_has_raging_bolt(player) or _hand_has_raging_bolt_access_card(player)):
		return false
	return energy_symbol in ["L", "F"]


func _is_doomed_active_raging_bolt_attach(player: PlayerState, target_slot: PokemonSlot, energy_symbol: String) -> bool:
	if player == null or target_slot == null:
		return false
	if target_slot != player.active_pokemon:
		return false
	if energy_symbol not in ["L", "F"]:
		return false
	if target_slot.get_remaining_hp() > 180:
		return false
	if _raging_bolt_attach_would_complete_core_cost(target_slot, energy_symbol):
		return false
	return _bench_has_raging_bolt(player)


func _score_backup_attacker_handoff_attach(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return 0.0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return 0.0
	if not _is_raging_bolt_card_data(player.active_pokemon.get_card_data()):
		return 0.0
	if player.active_pokemon.get_remaining_hp() > 180:
		return 0.0
	var energy_card: CardInstance = action.get("card", null)
	if energy_card == null or energy_card.card_data == null:
		return 0.0
	var energy_symbol := _energy_symbol_for_runtime(str(energy_card.card_data.energy_provides))
	if energy_symbol not in ["L", "F"]:
		return 0.0
	var target_slot: PokemonSlot = action.get("target_slot", null)
	if target_slot == null or target_slot == player.active_pokemon:
		return 0.0
	if not _is_raging_bolt_card_data(target_slot.get_card_data()):
		return 0.0
	if _raging_bolt_slot_has_core_symbol(target_slot, energy_symbol):
		return 0.0
	return 88500.0 + float(maxi(0, 2 - _raging_bolt_slot_missing_core_count(target_slot)) * 100)


func _raging_bolt_attach_would_complete_core_cost(slot: PokemonSlot, energy_symbol: String) -> bool:
	if slot == null:
		return false
	var has_lightning := energy_symbol == "L"
	var has_fighting := energy_symbol == "F"
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		has_lightning = has_lightning or symbol == "L"
		has_fighting = has_fighting or symbol == "F"
	return has_lightning and has_fighting


func _raging_bolt_slot_has_core_symbol(slot: PokemonSlot, energy_symbol: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if _energy_symbol_for_runtime(str(energy.card_data.energy_provides)) == energy_symbol:
			return true
	return false


func _is_off_plan_survival_tool_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_tool":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var tool_card: CardInstance = action.get("card", null)
	if tool_card == null or tool_card.card_data == null:
		return false
	var tool_name := "%s %s" % [str(tool_card.card_data.name_en), str(tool_card.card_data.name)]
	if not _name_contains(tool_name, "Bravery Charm"):
		return false
	var target_slot: PokemonSlot = action.get("target_slot", null)
	if target_slot == null or target_slot.get_card_data() == null:
		return false
	var target_cd: CardData = target_slot.get_card_data()
	if _is_raging_bolt_card_data(target_cd):
		return false
	var name_text := "%s %s" % [str(target_cd.name_en), str(target_cd.name)]
	if _name_contains(name_text, "Teal Mask Ogerpon"):
		return false
	return true


func _is_off_plan_support_basic_bench(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "play_basic_to_bench":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player != null and player.bench.is_empty():
		return false
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var name_text := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
	if _name_contains(name_text, "Squawkabilly ex"):
		return true
	if _name_contains(name_text, "Fezandipiti ex"):
		return not _opponent_has_taken_prize(game_state, player_index)
	return false


func _is_support_active_trap_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "retreat":
		var target_slot: PokemonSlot = action.get("bench_target", action.get("target_slot", null))
		return _is_support_engine_slot(target_slot)
	if kind != "play_trainer":
		return false
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var card_name := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
	if not _name_contains(card_name, "Switch Cart"):
		return false
	return not _has_good_self_pivot_target(player)


func _is_self_pivot_target_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	return step_id in [
		"switch_target",
		"self_switch_target",
		"retreat_target",
		"own_bench_target",
		"pivot_target",
		"self_target",
	]


func _is_opponent_gust_target_step(step: Dictionary, context: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	if step_id.contains("opponent") and (step_id.contains("bench") or step_id.contains("target")):
		return true
	if step_id.contains("gust") and step_id.contains("target"):
		return true
	var pending_card: Variant = context.get("pending_effect_card", null)
	return _is_gust_card_instance(pending_card) and step_id.contains("target")


func _is_raging_bolt_burst_field_discard_step(items: Array, step: Dictionary, context: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	if step_id not in ["discard_basic_energy", "attack_energy_discard", "discard_energy", "discard_cards"]:
		return false
	if str(context.get("pending_effect_kind", "")).strip_edges().to_lower() != "attack":
		return false
	var pending_card: Variant = context.get("pending_effect_card", null)
	if not (pending_card is CardInstance):
		return false
	var card := pending_card as CardInstance
	if card.card_data == null or not _is_raging_bolt_card_data(card.card_data):
		return false
	var player: PlayerState = _player_from_interaction_context(context)
	if player == null or items.is_empty():
		return false
	for item: Variant in items:
		if not (item is CardInstance):
			return false
		if _field_energy_holder(player, item as CardInstance) == null:
			return false
	return true


func _player_from_interaction_context(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _field_energy_holder(player: PlayerState, card: CardInstance) -> PokemonSlot:
	if player == null or card == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and card in slot.attached_energy:
			return slot
	return null


func _score_raging_bolt_gust_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var damage := _raging_bolt_burst_damage_estimate(game_state, player_index)
	if damage <= 0:
		return 0.0
	var remaining_hp := slot.get_remaining_hp()
	if remaining_hp <= 0:
		return 0.0
	if damage >= remaining_hp:
		return 120000.0 + float(slot.get_prize_count()) * 3000.0 - float(remaining_hp)
	return -500.0 - float(remaining_hp - damage)


func _is_unproductive_gust_commit_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_gust_trainer_action(action):
		return false
	if _has_gust_burst_ko_target(game_state, player_index):
		return false
	if _prime_catcher_can_self_pivot_to_ready_burst(action, game_state, player_index):
		return false
	return true


func _is_gust_trainer_action(action: Dictionary) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "play_trainer":
		return false
	var card: CardInstance = action.get("card", null)
	return _is_gust_card_instance(card)


func _is_gust_card_instance(raw_card: Variant) -> bool:
	if not (raw_card is CardInstance):
		return false
	var card: CardInstance = raw_card
	if card.card_data == null:
		return false
	var name_text := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
	return _name_contains(name_text, "Boss's Orders") \
		or _name_contains(name_text, "Prime Catcher") \
		or _name_contains(name_text, "Pokemon Catcher")


func _prime_catcher_can_self_pivot_to_ready_burst(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var card: CardInstance = action.get("card", null)
	if not _is_prime_catcher_card(card):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if player.active_pokemon.get_card_data() != null and _is_raging_bolt_card_data(player.active_pokemon.get_card_data()):
		return false
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null or bench_slot.get_card_data() == null:
			continue
		if _is_raging_bolt_card_data(bench_slot.get_card_data()) and _raging_bolt_slot_has_core_attack_cost(bench_slot):
			return true
	return false


func _is_prime_catcher_card(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var name_text := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
	return _name_contains(name_text, "Prime Catcher")


func _has_gust_burst_ko_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if not _active_raging_bolt_burst_cost_ready(game_state, player_index):
		return false
	var damage := _raging_bolt_burst_damage_estimate(game_state, player_index)
	if damage <= 0:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for bench_slot: PokemonSlot in opponent.bench:
		if bench_slot == null or bench_slot.get_card_data() == null:
			continue
		var remaining_hp := bench_slot.get_remaining_hp()
		if remaining_hp > 0 and damage >= remaining_hp:
			return true
	return false


func _score_self_pivot_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var player: PlayerState = null
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	if _is_raging_bolt_card_data(slot.get_card_data()):
		var missing := _raging_bolt_slot_missing_core_count(slot)
		if missing <= 0:
			return 920.0
		if missing == 1:
			return 760.0
		return 560.0
	if _is_teal_mask_ogerpon_slot(slot):
		return 420.0 if slot.attached_energy.size() > 0 else 340.0
	if _is_slither_wing_slot(slot):
		return 260.0
	if _is_support_engine_slot(slot):
		return -10000.0
	if player != null and player.bench.size() <= 1:
		return 80.0
	return 40.0


func _pick_best_self_pivot_target(items: Array, context: Dictionary) -> Array:
	var best_slot: PokemonSlot = null
	var best_score := -INF
	for item: Variant in items:
		if not (item is PokemonSlot):
			continue
		var score := _score_self_pivot_target(item as PokemonSlot, context)
		if score > best_score:
			best_score = score
			best_slot = item as PokemonSlot
	if best_slot == null or best_score <= -9000.0:
		return []
	return [best_slot]


func _pick_core_attacker_from_available_items(items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_core_attacker_search_or_recover_step(step):
		return []
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return []
	var player: PlayerState = game_state.players[player_index]
	if player == null or _raging_bolt_on_board(player):
		return []
	for item: Variant in items:
		if _item_matches_raging_bolt(item):
			return [item]
	return []


func _score_core_attacker_search_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if not _is_core_attacker_search_or_recover_step(step):
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null or _raging_bolt_on_board(player):
		return 0.0
	return 100000.0 if _item_matches_raging_bolt(item) else -1000.0


func _is_core_attacker_search_or_recover_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges().to_lower()
	if step_id == "":
		return false
	return step_id.contains("search") \
		or step_id.contains("recover") \
		or step_id.contains("night_stretcher") \
		or step_id in ["target", "choice"]


func _item_matches_raging_bolt(item: Variant) -> bool:
	if item is CardInstance:
		var card: CardInstance = item
		return card.card_data != null and _is_raging_bolt_card_data(card.card_data)
	if item is CardData:
		return _is_raging_bolt_card_data(item as CardData)
	if item is Dictionary:
		var dict: Dictionary = item
		var text := "%s %s %s" % [str(dict.get("name_en", "")), str(dict.get("name", "")), JSON.stringify(dict)]
		return _name_contains(text, "Raging Bolt")
	return _name_contains(str(item), "Raging Bolt")


func _has_good_self_pivot_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null or bench_slot.get_card_data() == null:
			continue
		if _is_raging_bolt_card_data(bench_slot.get_card_data()) \
				or _is_teal_mask_ogerpon_slot(bench_slot) \
				or _is_slither_wing_slot(bench_slot):
			return true
	return false


func _is_support_engine_slot(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	var name_text := "%s %s" % [str(cd.name_en), str(cd.name)]
	return _name_contains(name_text, "Radiant Greninja") \
		or _name_contains(name_text, "Squawkabilly ex") \
		or _name_contains(name_text, "Fezandipiti ex") \
		or _name_contains(name_text, "Iron Bundle")


func _is_teal_mask_ogerpon_slot(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	return _name_contains(str(cd.name_en), "Teal Mask Ogerpon") or _name_contains(str(cd.name), "Teal Mask Ogerpon")


func _is_slither_wing_slot(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	return _name_contains(str(cd.name_en), "Slither Wing") or _name_contains(str(cd.name), "Slither Wing")


func _raging_bolt_slot_missing_core_count(slot: PokemonSlot) -> int:
	if slot == null:
		return 2
	var has_lightning := false
	var has_fighting := false
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		has_lightning = has_lightning or symbol == "L"
		has_fighting = has_fighting or symbol == "F"
	var missing := 0
	if not has_lightning:
		missing += 1
	if not has_fighting:
		missing += 1
	return missing


func _is_core_energy_preservation_risk_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var missing_symbols := _raging_bolt_missing_core_symbols(player)
	if missing_symbols.is_empty():
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "use_ability":
		return _is_risky_greninja_draw_action(action, game_state, player_index, missing_symbols)
	if kind == "play_trainer":
		return _is_risky_hand_reset_action(action, game_state, player_index, missing_symbols)
	return false


func _is_risky_greninja_draw_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	missing_symbols: Dictionary
) -> bool:
	var source_slot: PokemonSlot = action.get("source_slot", null)
	if source_slot == null or source_slot.get_card_data() == null:
		return false
	if not _name_contains(str(source_slot.get_card_data().name_en), "Radiant Greninja") \
			and not _name_contains(str(source_slot.get_card_data().name), "Radiant Greninja"):
		return false
	var player: PlayerState = game_state.players[player_index]
	if _has_sada_available_for_core_energy_recovery(game_state, player_index):
		return false
	return not _hand_has_expendable_energy_for_greninja(player, missing_symbols)


func _is_risky_hand_reset_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	missing_symbols: Dictionary
) -> bool:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var name_text := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
	if not (
			_name_contains(name_text, "Iono")
			or _name_contains(name_text, "Professor's Research")
			or _name_contains(name_text, "Professor Research")
			or _name_contains(name_text, "Research")
			or _name_contains(name_text, "奇树")
			or _name_contains(name_text, "博士的研究")
	):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.hand.size() <= 3:
		return false
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(hand_card.card_data.energy_provides))
		if symbol != "" and bool(missing_symbols.get(symbol, false)):
			return true
		if _is_raging_bolt_card_data(hand_card.card_data) and not _raging_bolt_on_board(player):
			return true
	return false


func _raging_bolt_missing_core_symbols(player: PlayerState) -> Dictionary:
	var missing := {}
	if player == null:
		return missing
	var saw_raging_bolt := false
	var slots: Array[PokemonSlot] = []
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null:
			slots.append(bench_slot)
	for slot: PokemonSlot in slots:
		if slot == null or slot.get_card_data() == null or not _is_raging_bolt_card_data(slot.get_card_data()):
			continue
		saw_raging_bolt = true
		var has_lightning := false
		var has_fighting := false
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
			has_lightning = has_lightning or symbol == "L"
			has_fighting = has_fighting or symbol == "F"
		if not has_lightning:
			missing["L"] = true
		if not has_fighting:
			missing["F"] = true
	if not saw_raging_bolt and _hand_has_raging_bolt(player):
		missing["L"] = true
		missing["F"] = true
	return missing


func _hand_has_expendable_energy_for_greninja(player: PlayerState, missing_symbols: Dictionary) -> bool:
	if player == null:
		return false
	var counts := _hand_energy_symbol_counts(player)
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(hand_card.card_data.energy_provides))
		if symbol == "":
			continue
		if symbol == "G":
			return true
		if not bool(missing_symbols.get(symbol, false)):
			return true
		if int(counts.get(symbol, 0)) > 1:
			return true
	return false


func _hand_energy_symbol_counts(player: PlayerState) -> Dictionary:
	var counts := {}
	if player == null:
		return counts
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(hand_card.card_data.energy_provides))
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func _has_sada_available_for_core_energy_recovery(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if bool(game_state.supporter_used_this_turn):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _raging_bolt_on_board(player):
		return false
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		var name_text := "%s %s" % [str(hand_card.card_data.name_en), str(hand_card.card_data.name)]
		if _name_contains(name_text, "Professor Sada") or _name_contains(name_text, "奥琳"):
			return true
	return false


func _raging_bolt_on_board(player: PlayerState) -> bool:
	if player == null:
		return false
	if player.active_pokemon != null and _is_raging_bolt_card_data(player.active_pokemon.get_card_data()):
		return true
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and _is_raging_bolt_card_data(bench_slot.get_card_data()):
			return true
	return false


func _opponent_has_taken_prize(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	var remaining_prizes := opponent.prizes.size()
	return remaining_prizes > 0 and remaining_prizes < 6


func _hand_has_raging_bolt(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _is_raging_bolt_card_data(card.card_data):
			return true
	return false


func _hand_has_raging_bolt_access_card(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var name_text := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
		if _name_contains(name_text, "Nest Ball") \
				or _name_contains(name_text, "Ultra Ball") \
				or _name_contains(name_text, "Hisuian Heavy Ball"):
			return true
	return false


func _raging_bolt_slot_has_core_attack_cost(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var has_lightning := false
	var has_fighting := false
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		has_lightning = has_lightning or symbol == "L"
		has_fighting = has_fighting or symbol == "F"
	return has_lightning and has_fighting


func _is_low_deck_unplanned_draw_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.deck.size() <= 0 or player.deck.size() > 12:
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "use_ability":
		var source_slot: PokemonSlot = action.get("source_slot", null)
		if source_slot == null or source_slot.get_card_data() == null:
			return false
		var cd: CardData = source_slot.get_card_data()
		return _name_contains(str(cd.name_en), "Teal Mask Ogerpon") \
			or _name_contains(str(cd.name_en), "Radiant Greninja") \
			or _name_contains(str(cd.name_en), "Fezandipiti") \
			or _name_contains(str(cd.name), "Teal Mask Ogerpon") \
			or _name_contains(str(cd.name), "Radiant Greninja") \
			or _name_contains(str(cd.name), "Fezandipiti")
	if kind == "play_trainer":
		var card: CardInstance = action.get("card", null)
		if card == null or card.card_data == null:
			return false
		var name_en := str(card.card_data.name_en)
		var name := str(card.card_data.name)
		return _name_contains(name_en, "Trekking Shoes") \
			or _name_contains(name_en, "Iono") \
			or _name_contains(name_en, "Professor's Research") \
			or _name_contains(name_en, "Professor Sada") \
			or _name_contains(name, "Trekking Shoes") \
			or _name_contains(name, "Iono") \
			or _name_contains(name, "Professor")
	return false


func _is_low_deck_attack_unlock_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.deck.size() <= 3:
		return false
	if str(action.get("kind", action.get("type", ""))) != "play_trainer":
		return false
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var card_name := "%s %s" % [str(card.card_data.name_en), str(card.card_data.name)]
	if not (_name_contains(card_name, "Professor Sada") or _name_contains(card_name, "奥琳")):
		return false
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null or not _is_raging_bolt_card_data(active.get_card_data()):
		return false
	var missing := _raging_bolt_slot_missing_core_symbols(active)
	if missing.is_empty() or missing.size() > 2:
		return false
	var discard_counts := _basic_energy_counts_in_discard(player)
	for symbol: String in missing.keys():
		if int(discard_counts.get(symbol, 0)) <= 0:
			return false
	return true


func _raging_bolt_slot_missing_core_symbols(slot: PokemonSlot) -> Dictionary:
	var missing := {}
	if slot == null:
		missing["L"] = true
		missing["F"] = true
		return missing
	var has_lightning := false
	var has_fighting := false
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		has_lightning = has_lightning or symbol == "L"
		has_fighting = has_fighting or symbol == "F"
	if not has_lightning:
		missing["L"] = true
	if not has_fighting:
		missing["F"] = true
	return missing


func _basic_energy_counts_in_discard(player: PlayerState) -> Dictionary:
	var counts := {}
	if player == null:
		return counts
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) != "Basic Energy":
			continue
		var symbol := _energy_symbol_for_runtime(str(card.card_data.energy_provides))
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


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
	no_deck_draw_lock: bool
) -> void:
	if no_deck_draw_lock:
		return
	_append_catalog_match(target, seen_ids, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
	if not has_attack:
		_append_catalog_match(target, seen_ids, "play_trainer", "Trekking Shoes", "")


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	return _name_contains(str(card_data.name_en), "Earthen Vessel")


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result := payload.duplicate(true)
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var core_setup := _raging_bolt_core_setup_fact(result, game_state, player_index)
	if not core_setup.is_empty():
		facts["core_attacker_setup"] = core_setup
	var continuity: Dictionary = {}
	if _rules != null and _rules.has_method("build_continuity_contract"):
		continuity = _rules.call("build_continuity_contract", game_state, player_index, {})
	if not continuity.is_empty():
		facts["continuity_contract"] = _compact_continuity_contract_for_llm(continuity)
	result["turn_tactical_facts"] = facts
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes := routes.duplicate(true)
	var continuity_route := _raging_bolt_continuity_candidate_route(result, continuity)
	if not continuity_route.is_empty():
		updated_routes.push_front(continuity_route)
	var visible_engine_route := _raging_bolt_visible_engine_attack_candidate_route(result, facts)
	if not visible_engine_route.is_empty():
		updated_routes.push_front(visible_engine_route)
	var core_route := _raging_bolt_core_attacker_candidate_route(result, core_setup)
	if not core_route.is_empty():
		updated_routes.push_front(core_route)
	var ready_handoff_route := _raging_bolt_ready_backup_handoff_candidate_route(result, game_state, player_index)
	if not ready_handoff_route.is_empty():
		updated_routes.push_front(ready_handoff_route)
	result["candidate_routes"] = updated_routes
	return result


func _raging_bolt_core_setup_fact(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return {}
	var has_bolt := _raging_bolt_on_board(player)
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var direct_bench_id := _first_payload_action_id(legal_actions, "play_basic_to_bench", "Raging Bolt ex")
	var search_id := _first_payload_core_search_action_id(legal_actions)
	var recovery_id := _first_payload_core_recovery_action_id(legal_actions)
	var support_active := player.active_pokemon != null and _is_support_engine_slot(player.active_pokemon)
	return {
		"has_raging_bolt_on_board": has_bolt,
		"needs_first_raging_bolt": not has_bolt,
		"support_active_without_bolt": support_active and not has_bolt,
		"direct_bench_action_id": direct_bench_id,
		"search_action_id": search_id,
		"recovery_action_id": recovery_id,
		"core_route_available": (not has_bolt) and (direct_bench_id != "" or search_id != "" or recovery_id != ""),
		"draw_discipline": "Before the first Raging Bolt ex is on board, do not spend optional draw/churn support before the core search/bench route.",
		"deck_count": player.deck.size(),
	}


func _raging_bolt_core_attacker_candidate_route(_payload: Dictionary, core_setup: Dictionary) -> Dictionary:
	if core_setup.is_empty() or not bool(core_setup.get("core_route_available", false)):
		return {}
	var route_actions: Array[Dictionary] = []
	var direct_bench_id := str(core_setup.get("direct_bench_action_id", "")).strip_edges()
	if direct_bench_id != "":
		route_actions.append({
			"id": direct_bench_id,
			"action_id": direct_bench_id,
			"type": "play_basic_to_bench",
			"capability": "core_attacker_setup",
		})
	else:
		var search_id := str(core_setup.get("search_action_id", "")).strip_edges()
		if search_id != "":
			route_actions.append({
				"id": search_id,
				"action_id": search_id,
				"type": "play_trainer",
				"capability": "core_attacker_setup",
				"selection_policy": _raging_bolt_core_search_selection_policy(),
			})
		else:
			var recovery_id := str(core_setup.get("recovery_action_id", "")).strip_edges()
			if recovery_id != "":
				route_actions.append({
					"id": recovery_id,
					"action_id": recovery_id,
					"type": "play_trainer",
					"capability": "core_attacker_recovery",
					"selection_policy": _raging_bolt_core_recovery_selection_policy(),
				})
	if route_actions.is_empty():
		return {}
	route_actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "core_attacker_setup",
		"route_action_id": "route:core_attacker_setup",
		"type": "candidate_route",
		"priority": 986,
		"goal": "core_attacker_setup",
		"description": "Find or bench the first Raging Bolt ex before optional support draw/churn when no core attacker is on board.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:first_raging_bolt_online",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "Raging Bolt LLM strong mode must establish the primary attacker before spending support draw actions.",
		}],
		"contract": "Select this route when core_attacker_setup.core_route_available is true.",
	}


func _raging_bolt_core_search_selection_policy() -> Dictionary:
	return {
		"search": {"prefer": ["Raging Bolt ex", "Teal Mask Ogerpon ex", "Radiant Greninja", "Squawkabilly ex"]},
		"search_targets": {"prefer": ["Raging Bolt ex", "Teal Mask Ogerpon ex", "Radiant Greninja", "Squawkabilly ex"]},
		"search_pokemon": {"prefer": ["Raging Bolt ex", "Teal Mask Ogerpon ex", "Radiant Greninja", "Squawkabilly ex"]},
	}


func _raging_bolt_core_recovery_selection_policy() -> Dictionary:
	return {
		"night_stretcher_choice": {"prefer": ["Raging Bolt ex", "Lightning Energy", "Fighting Energy", "Teal Mask Ogerpon ex"]},
		"recover_target": {"prefer": ["Raging Bolt ex", "Lightning Energy", "Fighting Energy", "Teal Mask Ogerpon ex"]},
		"recover_card": {"prefer": ["Raging Bolt ex", "Lightning Energy", "Fighting Energy", "Teal Mask Ogerpon ex"]},
	}


func _raging_bolt_ready_backup_handoff_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return {}
	if _active_raging_bolt_burst_cost_ready(game_state, player_index):
		return {}
	var bench_position := _ready_backup_raging_bolt_position(player)
	if bench_position == "":
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var pivot_ref := _best_ready_backup_pivot_ref(legal_actions, bench_position)
	if pivot_ref.is_empty():
		return {}
	var pivot_action := _continuity_route_ref(pivot_ref)
	pivot_action["selection_policy"] = _ready_backup_handoff_selection_policy(bench_position)
	return {
		"id": "raging_bolt_ready_backup_handoff",
		"route_action_id": "route:raging_bolt_ready_backup_handoff",
		"type": "candidate_route",
		"priority": 992,
		"goal": "ready_backup_handoff_attack",
		"description": "Pivot to an already charged benched Raging Bolt ex and convert the terminal step into Thundering Bolt.",
		"actions": [pivot_action, {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}],
		"future_goals": [{
			"id": "future:attack_after_handoff:%s:1:Thundering Bolt" % bench_position,
			"action_id": "future:attack_after_handoff:%s:1:Thundering Bolt" % bench_position,
			"type": "attack",
			"future": true,
			"position": bench_position,
			"attack_index": 1,
			"attack_name": "Thundering Bolt",
			"source_pokemon": "Raging Bolt ex",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "A backup Raging Bolt already has Lightning plus Fighting and should take over before more draw/search.",
		}],
		"contract": "Select this route when a benched Raging Bolt ex is already attack-ready and the active is not.",
	}


func _ready_backup_raging_bolt_position(player: PlayerState) -> String:
	if player == null:
		return ""
	var best_position := ""
	var best_hp := -1
	for index: int in player.bench.size():
		var slot: PokemonSlot = player.bench[index]
		if slot == null or slot.get_card_data() == null:
			continue
		if not _is_raging_bolt_card_data(slot.get_card_data()):
			continue
		if not _raging_bolt_slot_has_core_attack_cost(slot):
			continue
		var hp := slot.get_remaining_hp()
		if hp > best_hp:
			best_hp = hp
			best_position = "bench_%d" % index
	return best_position


func _best_ready_backup_pivot_ref(legal_actions: Array, bench_position: String) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		var score := _ready_backup_pivot_ref_score(ref, bench_position)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _ready_backup_pivot_ref_score(ref: Dictionary, bench_position: String) -> int:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _continuity_ref_text(ref)
	if kind == "retreat" and action_id.contains("retreat:%s" % bench_position):
		return 850
	if kind != "play_trainer":
		return -999999
	if _name_contains(text, "Prime Catcher"):
		return 1100
	if _name_contains(text, "Switch Cart"):
		return 1050
	if _name_contains(text, "Switch") and not _name_contains(text, "Switching Cups"):
		return 1000
	if _name_contains(text, "Escape Rope"):
		return 700
	return -999999


func _ready_backup_handoff_selection_policy(bench_position: String) -> Dictionary:
	return {
		"own_bench_target": bench_position,
		"switch_target": bench_position,
		"self_pivot_target": bench_position,
		"target_position": bench_position,
		"gust_target": {"prefer": ["lowest_hp_ex", "lowest_hp_v", "active"]},
		"opponent_bench_target": {"prefer": ["lowest_hp_ex", "lowest_hp_v", "lowest_hp"]},
	}


func _raging_bolt_visible_engine_attack_candidate_route(payload: Dictionary, facts: Dictionary) -> Dictionary:
	if not bool(facts.get("primary_attack_reachable_after_visible_engine", false)):
		return {}
	var future_goal := _raging_bolt_visible_engine_future_attack_goal(payload, facts)
	if future_goal.is_empty():
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	if legal_actions.is_empty():
		return {}
	var route_steps: Array = facts.get("primary_attack_route", []) if facts.get("primary_attack_route", []) is Array else []
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	if route_steps.has("energy_search"):
		_append_payload_ref_to_route(route_actions, seen_ids, _first_payload_ref(legal_actions, "play_trainer", "Earthen Vessel"), _earthen_vessel_interactions())
	if route_steps.has("discard_energy_engine"):
		var deck_count := int(facts.get("deck_count", 99))
		if deck_count > 8:
			_append_payload_ref_to_route(route_actions, seen_ids, _first_payload_ref(legal_actions, "use_ability", "Radiant Greninja"), _greninja_interactions())
	if route_steps.has("discard_energy_acceleration_supporter") or _payload_has_ref(legal_actions, "play_trainer", "Professor Sada"):
		var before_sada_size := route_actions.size()
		_append_payload_ref_to_route(route_actions, seen_ids, _first_payload_ref(legal_actions, "play_trainer", "Professor Sada"), {})
		if route_actions.size() > before_sada_size:
			route_actions[route_actions.size() - 1]["allow_deck_draw_lock"] = true
			route_actions[route_actions.size() - 1]["deck_draw_lock_exception"] = "primary_attack_unlock"
	var manual_attach_id := str(facts.get("best_manual_attach_to_primary_attack_action_id", "")).strip_edges()
	if manual_attach_id != "":
		_append_payload_ref_to_route(route_actions, seen_ids, _payload_ref_by_id(legal_actions, manual_attach_id), {})
	if route_actions.is_empty():
		return {}
	route_actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "raging_bolt_primary_visible_engine",
		"route_action_id": "route:raging_bolt_primary_visible_engine",
		"type": "candidate_route",
		"priority": 988,
		"goal": "setup_to_primary_attack",
		"description": "Use the visible Raging Bolt engine pieces, then let runtime convert end_turn into the now-legal Thundering Bolt attack.",
		"actions": route_actions,
		"future_goals": [future_goal],
		"contract": "Select this route when primary_attack_reachable_after_visible_engine is true and the current legal attack is not the primary burst attack.",
	}


func _raging_bolt_visible_engine_future_attack_goal(payload: Dictionary, facts: Dictionary) -> Dictionary:
	var future_actions: Array = payload.get("future_actions", []) if payload.get("future_actions", []) is Array else []
	var primary_name := str(facts.get("primary_attack_name", "")).strip_edges()
	for raw: Variant in future_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_id := str(ref.get("id", ref.get("action_id", "")))
		if not action_id.begins_with("future:attack"):
			continue
		var attack_name := str(ref.get("attack_name", ""))
		if primary_name != "" and attack_name != "" and not _name_contains(attack_name, primary_name):
			continue
		var goal := ref.duplicate(true)
		goal["type"] = "attack"
		goal["future"] = true
		goal["attack_quality"] = {"role": "primary_damage", "terminal_priority": "high"}
		if not goal.has("source_pokemon"):
			goal["source_pokemon"] = "Raging Bolt ex"
		return goal
	if primary_name == "":
		primary_name = "Thundering Bolt"
	return {
		"id": "future:attack_after_visible_engine:active:1:%s" % primary_name,
		"action_id": "future:attack_after_visible_engine:active:1:%s" % primary_name,
		"type": "attack",
		"future": true,
		"attack_index": 1,
		"attack_name": primary_name,
		"source_pokemon": "Raging Bolt ex",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}


func _append_payload_ref_to_route(route_actions: Array[Dictionary], seen_ids: Dictionary, ref: Dictionary, interactions: Dictionary = {}) -> void:
	if ref.is_empty():
		return
	var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	if action_id == "" or bool(seen_ids.get(action_id, false)):
		return
	var route_ref := _continuity_route_ref(ref)
	if not interactions.is_empty():
		route_ref["interactions"] = interactions
	route_actions.append(route_ref)
	seen_ids[action_id] = true


func _payload_has_ref(legal_actions: Array, action_type: String, query: String) -> bool:
	return not _first_payload_ref(legal_actions, action_type, query).is_empty()


func _payload_ref_by_id(legal_actions: Array, action_id: String) -> Dictionary:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("id", ref.get("action_id", ""))) == action_id:
			return ref
	return {}


func _first_payload_ref(legal_actions: Array, action_type: String, query: String) -> Dictionary:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != action_type:
			continue
		var queries: Array[String] = [query]
		if query != "" and not _text_matches_any_name(_continuity_ref_text(ref), queries):
			continue
		return ref
	return {}


func _first_payload_action_id(legal_actions: Array, action_type: String, query: String) -> String:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != action_type:
			continue
		var queries: Array[String] = [query]
		if query != "" and not _text_matches_any_name(_continuity_ref_text(ref), queries):
			continue
		var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
		if action_id != "":
			return action_id
	return ""


func _first_payload_core_search_action_id(legal_actions: Array) -> String:
	var best_id := ""
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != "play_trainer":
			continue
		var text := _continuity_ref_text(ref)
		var score := -999999
		if _name_contains(text, "Nest Ball"):
			score = 1000
		elif _name_contains(text, "Ultra Ball"):
			score = 850
		elif _name_contains(text, "Hisuian Heavy Ball"):
			score = 650
		if score <= best_score:
			continue
		var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
		if action_id == "":
			continue
		best_id = action_id
		best_score = score
	return best_id


func _first_payload_core_recovery_action_id(legal_actions: Array) -> String:
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if _payload_ref_is_future(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != "play_trainer":
			continue
		var text := _continuity_ref_text(ref)
		if not _name_contains(text, "Night Stretcher"):
			continue
		var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
		if action_id != "":
			return action_id
	return ""


func _payload_ref_is_future(ref: Dictionary) -> bool:
	if bool(ref.get("future", false)):
		return true
	var action_id := str(ref.get("id", ref.get("action_id", ""))).strip_edges()
	if action_id.begins_with("future:"):
		return true
	return str(ref.get("summary", "")).strip_edges().to_lower().begins_with("future:")


func _compact_continuity_contract_for_llm(continuity: Dictionary) -> Dictionary:
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var compact_bonuses: Array[Dictionary] = []
	for raw: Variant in bonuses:
		if not (raw is Dictionary):
			continue
		var bonus: Dictionary = raw
		compact_bonuses.append({
			"kind": str(bonus.get("kind", "")),
			"card_names": bonus.get("card_names", []),
			"target_names": bonus.get("target_names", []),
			"energy_types": bonus.get("energy_types", []),
			"bonus": float(bonus.get("bonus", 0.0)),
			"reason": str(bonus.get("reason", "")),
		})
		if compact_bonuses.size() >= 8:
			break
	return {
		"enabled": bool(continuity.get("enabled", false)),
		"safe_setup_before_attack": bool(continuity.get("safe_setup_before_attack", false)),
		"terminal_attack_locked": bool(continuity.get("terminal_attack_locked", false)),
		"setup_debt": setup_debt,
		"action_bonuses": compact_bonuses,
		"contract": "If enabled, perform listed non-conflicting continuity actions before a non-final attack.",
	}


func _raging_bolt_continuity_candidate_route(payload: Dictionary, continuity: Dictionary) -> Dictionary:
	if not bool(continuity.get("enabled", false)):
		return {}
	if bool(continuity.get("terminal_attack_locked", false)):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	if legal_actions.is_empty():
		return {}
	var route_actions: Array[Dictionary] = []
	var seen_ids := {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	for raw_bonus: Variant in _sorted_continuity_bonuses(bonuses):
		if route_actions.size() >= 5:
			break
		if not (raw_bonus is Dictionary):
			continue
		var bonus: Dictionary = raw_bonus
		var ref := _best_payload_ref_for_continuity_bonus(legal_actions, bonus, route_actions)
		if ref.is_empty():
			continue
		var action_id := str(ref.get("id", ref.get("action_id", "")))
		if action_id == "" or bool(seen_ids.get(action_id, false)):
			continue
		var route_ref := _continuity_route_ref(ref)
		route_actions.append(route_ref)
		seen_ids[action_id] = true
	var terminal_ref := _continuity_terminal_ref(legal_actions)
	if terminal_ref.is_empty():
		return {}
	if route_actions.is_empty():
		return {}
	route_actions.append(terminal_ref)
	return {
		"id": "continuity_before_attack",
		"route_action_id": "route:continuity_before_attack",
		"type": "candidate_route",
		"priority": 982,
		"goal": "continuity_before_attack",
		"description": "Pay visible continuity debt such as backup Raging Bolt, Ogerpon engine, follow-up Energy, or safe recovery before a non-final attack.",
		"actions": route_actions,
		"future_goals": [{
			"id": "goal:maintain_next_attacker_chain",
			"type": "goal",
			"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			"reason": "LLM strong mode should attack while preserving the next Raging Bolt turn.",
		}],
		"contract": "Select this route when current attack pressure exists but continuity_contract.enabled is true.",
	}


func _sorted_continuity_bonuses(bonuses: Array) -> Array:
	var result := bonuses.duplicate(true)
	result.sort_custom(Callable(self, "_sort_continuity_bonus_desc"))
	return result


func _sort_continuity_bonus_desc(a: Variant, b: Variant) -> bool:
	var left: Dictionary = a if a is Dictionary else {}
	var right: Dictionary = b if b is Dictionary else {}
	var left_score := float(left.get("bonus", 0.0))
	var right_score := float(right.get("bonus", 0.0))
	if left_score != right_score:
		return left_score > right_score
	return str(left.get("reason", "")) < str(right.get("reason", ""))


func _best_payload_ref_for_continuity_bonus(
	legal_actions: Array,
	bonus: Dictionary,
	route_actions: Array[Dictionary]
) -> Dictionary:
	var scored: Array[Dictionary] = []
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if bool(ref.get("future", false)):
			continue
		if not _payload_ref_matches_continuity_bonus(ref, bonus):
			continue
		if _continuity_ref_conflicts_with_route(ref, route_actions):
			continue
		scored.append({
			"score": _continuity_ref_score(ref, bonus),
			"ref": ref,
		})
	scored.sort_custom(Callable(self, "_sort_scored_continuity_ref_desc"))
	if scored.is_empty():
		return {}
	return scored[0].get("ref", {}) if scored[0].get("ref", {}) is Dictionary else {}


func _sort_scored_continuity_ref_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := float(a.get("score", 0.0))
	var right := float(b.get("score", 0.0))
	if left != right:
		return left > right
	var left_ref: Dictionary = a.get("ref", {}) if a.get("ref", {}) is Dictionary else {}
	var right_ref: Dictionary = b.get("ref", {}) if b.get("ref", {}) is Dictionary else {}
	return str(left_ref.get("id", "")) < str(right_ref.get("id", ""))


func _payload_ref_matches_continuity_bonus(ref: Dictionary, bonus: Dictionary) -> bool:
	var kind := str(bonus.get("kind", ""))
	if kind != "" and str(ref.get("type", ref.get("kind", ""))) != kind:
		return false
	var ref_text := _continuity_ref_text(ref)
	var card_names: Array[String] = _string_array_from_variant(bonus.get("card_names", []))
	if not card_names.is_empty() and not _text_matches_any_name(ref_text, card_names):
		return false
	var target_names: Array[String] = _string_array_from_variant(bonus.get("target_names", []))
	if not target_names.is_empty():
		var target_text := "%s %s %s" % [str(ref.get("target", "")), str(ref.get("pokemon", "")), str(ref.get("summary", ""))]
		if not _text_matches_any_name(target_text, target_names):
			return false
	var pokemon_names: Array[String] = _string_array_from_variant(bonus.get("pokemon_names", []))
	if not pokemon_names.is_empty():
		var pokemon_text := "%s %s %s" % [str(ref.get("pokemon", "")), str(ref.get("card", "")), str(ref.get("summary", ""))]
		if not _text_matches_any_name(pokemon_text, pokemon_names):
			return false
	var energy_types: Array[String] = _string_array_from_variant(bonus.get("energy_types", []))
	if not energy_types.is_empty():
		var ref_symbol := _energy_symbol_for_runtime(str(ref.get("energy_type", "")))
		if ref_symbol == "":
			ref_symbol = _energy_symbol_for_runtime(str(ref.get("card", "")))
		if not energy_types.has(ref_symbol):
			return false
	return true


func _continuity_ref_score(ref: Dictionary, bonus: Dictionary) -> float:
	var score := float(bonus.get("bonus", 0.0))
	var kind := str(ref.get("type", ref.get("kind", "")))
	var position := str(ref.get("position", ""))
	if bool(bonus.get("prefer_non_active", false)):
		score += 80.0 if position != "active" else -40.0
	if kind == "attach_energy":
		var target_text := "%s %s" % [str(ref.get("target", "")), str(ref.get("summary", ""))]
		if _name_contains(target_text, "Raging Bolt"):
			score += 120.0
		var symbol := _energy_symbol_for_runtime(str(ref.get("energy_type", "")))
		if symbol in ["L", "F"]:
			score += 60.0
		elif symbol == "G":
			score -= 20.0
	elif kind == "play_basic_to_bench":
		if _name_contains(_continuity_ref_text(ref), "Raging Bolt"):
			score += 100.0
		elif _name_contains(_continuity_ref_text(ref), "Teal Mask Ogerpon"):
			score += 70.0
	elif kind == "use_ability" and _name_contains(_continuity_ref_text(ref), "Teal Mask Ogerpon"):
		score += 90.0
	elif kind == "play_trainer":
		var text := _continuity_ref_text(ref)
		if _name_contains(text, "Professor Sada"):
			score += 90.0
		elif _name_contains(text, "Earthen Vessel"):
			score += 70.0
		elif _name_contains(text, "Nest Ball"):
			score += 60.0
	return score


func _continuity_ref_conflicts_with_route(ref: Dictionary, route_actions: Array[Dictionary]) -> bool:
	var ref_id := str(ref.get("id", ref.get("action_id", "")))
	var ref_conflicts: Array[String] = _string_array_from_variant(ref.get("resource_conflicts", []))
	for existing: Dictionary in route_actions:
		var existing_id := str(existing.get("id", existing.get("action_id", "")))
		if ref_id != "" and existing_id == ref_id:
			return true
		if ref_conflicts.has(existing_id):
			return true
		var existing_conflicts: Array[String] = _string_array_from_variant(existing.get("resource_conflicts", []))
		if ref_id != "" and existing_conflicts.has(ref_id):
			return true
	return false


func _continuity_route_ref(ref: Dictionary) -> Dictionary:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var result := {
		"id": action_id,
		"action_id": action_id,
		"type": str(ref.get("type", ref.get("kind", ""))),
		"capability": str(ref.get("capability", "")),
	}
	var interactions := _default_continuity_interactions_for_ref(ref)
	if not interactions.is_empty():
		result["interactions"] = interactions
	if ref.has("selection_policy"):
		result["selection_policy"] = ref.get("selection_policy")
	return result


func _default_continuity_interactions_for_ref(ref: Dictionary) -> Dictionary:
	var text := _continuity_ref_text(ref)
	if str(ref.get("type", ref.get("kind", ""))) == "use_ability" and _name_contains(text, "Teal Mask Ogerpon"):
		return _ogerpon_interactions()
	if str(ref.get("type", ref.get("kind", ""))) == "play_trainer" and _name_contains(text, "Earthen Vessel"):
		return _earthen_vessel_interactions()
	if str(ref.get("type", ref.get("kind", ""))) == "use_ability" and _name_contains(text, "Radiant Greninja"):
		return _greninja_interactions()
	return {}


func _continuity_terminal_ref(legal_actions: Array) -> Dictionary:
	var best_attack: Dictionary = {}
	var best_score := -999999
	var end_turn: Dictionary = {}
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_id := str(ref.get("id", ref.get("action_id", "")))
		if action_id == "end_turn":
			end_turn = {"id": "end_turn", "action_id": "end_turn", "type": "end_turn"}
			continue
		if str(ref.get("type", ref.get("kind", ""))) not in ["attack", "granted_attack"]:
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if str(quality.get("terminal_priority", "")) == "low":
			continue
		var score := 500
		if str(quality.get("role", "")) == "primary_damage":
			score += 300
		score += int(ref.get("attack_index", 0)) * 20
		if score > best_score:
			best_score = score
			best_attack = ref
	if not best_attack.is_empty():
		return {"id": str(best_attack.get("id", best_attack.get("action_id", "")))}
	return end_turn


func _continuity_ref_text(ref: Dictionary) -> String:
	return "%s %s %s %s %s" % [
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("target", "")),
		str(ref.get("summary", "")),
		JSON.stringify(ref.get("card_rules", {})),
	]


func _text_matches_any_name(text: String, names: Array[String]) -> bool:
	for name: String in names:
		if name == "":
			continue
		if _name_contains(text, name):
			return true
	return false


func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var text := str(raw)
			if text != "":
				result.append(text)
	elif value is PackedStringArray:
		for text: String in value:
			if text != "":
				result.append(text)
	elif str(value) != "":
		result.append(str(value))
	return result


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0
