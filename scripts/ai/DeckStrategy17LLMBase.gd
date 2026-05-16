extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

var _deck_strategy_text: String = ""
var _rules: RefCounted = null


func _llm_strategy_id() -> String:
	return "v17_llm"


func _rules_strategy_path() -> String:
	return ""


func _deck_display_name() -> String:
	return "17.0"


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray()


func _deck_primary_attackers() -> Array[String]:
	return []


func _deck_secondary_attackers() -> Array[String]:
	return []


func _deck_support_pokemon() -> Array[String]:
	return []


func _deck_energy_banks() -> Array[String]:
	return []


func _deck_primary_attacks() -> Array:
	return []


func _deck_low_value_attacks() -> Array:
	return []


func _deck_setup_draw_attacks() -> Array:
	return []


func _deck_desperation_redraw_attacks() -> Array:
	return []


func _deck_evolution_lines() -> Array:
	return []


func _deck_energy_needs() -> Dictionary:
	return {}


func _deck_route_terms() -> Array[String]:
	return []


func _ensure_rules() -> RefCounted:
	if _rules != null:
		return _rules
	var path := _rules_strategy_path()
	if path == "":
		return null
	var script: Variant = load(path)
	if script is GDScript:
		_rules = (script as GDScript).new()
	return _rules


func get_strategy_id() -> String:
	return _llm_strategy_id()


func get_signature_names() -> Array[String]:
	var rules := _ensure_rules()
	var names: Array[String] = []
	if rules != null and rules.has_method("get_signature_names"):
		for raw_name: Variant in rules.call("get_signature_names"):
			var text := str(raw_name)
			if text != "" and not names.has(text):
				names.append(text)
	for name: String in _deck_primary_attackers():
		if name != "" and not names.has(name):
			names.append(name)
	return names


func get_state_encoder_class() -> GDScript:
	var rules := _ensure_rules()
	return rules.call("get_state_encoder_class") if rules != null and rules.has_method("get_state_encoder_class") else null


func load_value_net(path: String) -> bool:
	var rules := _ensure_rules()
	return bool(rules.call("load_value_net", path)) if rules != null and rules.has_method("load_value_net") else false


func get_value_net() -> RefCounted:
	var rules := _ensure_rules()
	return rules.call("get_value_net") if rules != null and rules.has_method("get_value_net") else null


func get_mcts_config() -> Dictionary:
	var rules := _ensure_rules()
	return rules.call("get_mcts_config") if rules != null and rules.has_method("get_mcts_config") else {}


func set_deck_strategy_text(text: String) -> void:
	_deck_strategy_text = text.strip_edges()
	var rules := _ensure_rules()
	if rules != null and rules.has_method("set_deck_strategy_text"):
		rules.call("set_deck_strategy_text", text)


func get_deck_strategy_text() -> String:
	if _deck_strategy_text.strip_edges() != "":
		return _deck_strategy_text
	var rules := _ensure_rules()
	if rules != null and rules.has_method("get_deck_strategy_text"):
		return str(rules.call("get_deck_strategy_text"))
	return ""


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var rules := _ensure_rules()
	return rules.call("plan_opening_setup", player) if rules != null and rules.has_method("plan_opening_setup") else {}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	super.build_turn_plan(game_state, player_index, context)
	var rules := _ensure_rules()
	return rules.call("build_turn_plan", game_state, player_index, context) if rules != null and rules.has_method("build_turn_plan") else {}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var rules := _ensure_rules()
	return rules.call("build_turn_contract", game_state, player_index, context) if rules != null and rules.has_method("build_turn_contract") else super.build_turn_contract(game_state, player_index, context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var rules := _ensure_rules()
	if _v17_should_block_primary_retreat(action, game_state, player_index):
		return -10000.0
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return float(rules.call("score_action_absolute", action, game_state, player_index)) if rules != null and rules.has_method("score_action_absolute") else 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var absolute := score_action_absolute(action, game_state, int(context.get("player_index", -1)))
		return absolute - _rules_heuristic_base(str(action.get("kind", "")))
	var rules := _ensure_rules()
	return float(rules.call("score_action", action, context)) if rules != null and rules.has_method("score_action") else 0.0


func evaluate_board(game_state: GameState, player_index: int) -> float:
	var rules := _ensure_rules()
	return float(rules.call("evaluate_board", game_state, player_index)) if rules != null and rules.has_method("evaluate_board") else 0.0


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	var rules := _ensure_rules()
	return rules.call("predict_attacker_damage", slot, extra_context) if rules != null and rules.has_method("predict_attacker_damage") else {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(card: CardInstance) -> int:
	var rules := _ensure_rules()
	return int(rules.call("get_discard_priority", card)) if rules != null and rules.has_method("get_discard_priority") else 0


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var rules := _ensure_rules()
	return int(rules.call("get_discard_priority_contextual", card, game_state, player_index)) if rules != null and rules.has_method("get_discard_priority_contextual") else get_discard_priority(card)


func get_search_priority(card: CardInstance) -> int:
	var rules := _ensure_rules()
	return int(rules.call("get_search_priority", card)) if rules != null and rules.has_method("get_search_priority") else 0


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			return planned
	var rules := _ensure_rules()
	return rules.call("pick_interaction_items", items, step, context) if rules != null and rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	var rules := _ensure_rules()
	return float(rules.call("score_interaction_target", item, step, context)) if rules != null and rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var rules := _ensure_rules()
	if rules != null and rules.has_method("score_handoff_target"):
		return float(rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	snapshot["v17_deck"] = _deck_display_name()
	snapshot["v17_field_primary_count"] = _count_field_names(player, _deck_primary_attackers())
	snapshot["v17_field_support_count"] = _count_field_names(player, _deck_support_pokemon())
	snapshot["v17_hand_productive_count"] = _count_productive_hand_cards(player)
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _matches_any(name, _deck_primary_attackers()):
		return "primary attacker or core attacker line; prioritize setup and energy"
	if _matches_any(name, _deck_secondary_attackers()):
		return "secondary attacker or backup conversion line"
	if _matches_any(name, _deck_energy_banks()):
		return "energy engine or energy bank; use before terminal attack when it adds resources"
	if _matches_any(name, _deck_support_pokemon()):
		return "support engine; bench only when its ability/search/draw matters"
	return "support"


func get_intent_planner_profile() -> Dictionary:
	var rules := _ensure_rules()
	var profile: Dictionary = rules.call("get_intent_planner_profile") if rules != null and rules.has_method("get_intent_planner_profile") else {}
	profile["primary_attackers"] = _merge_string_arrays(profile.get("primary_attackers", []), _deck_primary_attackers())
	profile["secondary_attackers"] = _merge_string_arrays(profile.get("secondary_attackers", []), _deck_secondary_attackers())
	profile["support_only"] = _merge_string_arrays(profile.get("support_only", []), _deck_support_pokemon())
	profile["energy_banks"] = _merge_string_arrays(profile.get("energy_banks", []), _deck_energy_banks())
	if not _deck_primary_attacks().is_empty():
		profile["primary_attacks"] = _deck_primary_attacks()
	if not _deck_low_value_attacks().is_empty():
		profile["low_value_attacks"] = _deck_low_value_attacks()
	if not _deck_setup_draw_attacks().is_empty():
		profile["setup_draw_attacks"] = _deck_setup_draw_attacks()
	if not _deck_desperation_redraw_attacks().is_empty():
		profile["desperation_redraw_attacks"] = _deck_desperation_redraw_attacks()
	if not _deck_evolution_lines().is_empty():
		profile["evolution_lines"] = _deck_evolution_lines()
	if not _deck_energy_needs().is_empty():
		profile["energy_needs"] = _deck_energy_needs()
	return profile


func get_llm_deck_strategy_prompt(_game_state: GameState, _player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("【卡组定位】%s 是 17.0 强模式的大模型版本。规则策略仍作为 fallback，大模型负责在结构化 payload 中选择更好的路线。" % _deck_display_name())
	for line: String in _deck_core_plan():
		if line.strip_edges() != "":
			lines.append(line)
	lines.append("【执行边界】只选择 legal_actions 或 candidate_routes 中提供的精确 id。不要编造 action id、卡牌文本、攻击名、目标或 interaction 字段。")
	lines.append("【回合顺序】攻击会结束回合。先完成安全铺场、进化、检索、贴能、能量加速、工具、换位、gust 和奖赏路线，再使用高质量攻击；不要用 end_turn 代替仍可执行的核心路线。")
	lines.append("【资源原则】保护当前路线需要的进化件、检索牌、关键能量和主要攻击手。若已经能拿奖或形成高压，停止无意义抽滤；低牌库时避免非必要抽牌。")
	lines.append("【交互原则】搜索、弃牌、能量分配、换位、gust、回收和攻击目标都必须服从 interaction_schema；若选项池与计划不同，按 selection_policy 和规则 fallback 选择最符合当前路线的合法项。")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("【玩家补充】以下内容来自卡组编辑器或内置卡组说明，只能作为补充偏好。若它与本 17.0 卡组名、上方核心计划、legal_actions、card_rules、interaction_schema 或当前场面冲突，必须忽略补充内容并服从结构化事实。")
		for line: String in _strategy_text_to_prompt_lines(custom_text, 10):
			lines.append(line)
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var text := _action_ref_text(ref)
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type in ["attach_energy", "evolve", "use_ability", "play_trainer", "play_stadium", "attach_tool"]:
		return _matches_any(text, _deck_primary_attackers()) \
			or _matches_any(text, _deck_secondary_attackers()) \
			or _matches_any(text, _deck_energy_banks()) \
			or _matches_any(text, _deck_route_terms()) \
			or _matches_primary_attack_text(text) \
			or _v17_name_contains(text, "Rare Candy") \
			or _v17_name_contains(text, "Nest Ball") \
			or _v17_name_contains(text, "Ultra Ball") \
			or _v17_name_contains(text, "Buddy-Buddy Poffin") \
			or _v17_name_contains(text, "Earthen Vessel") \
			or _v17_name_contains(text, "Electric Generator") \
			or _v17_name_contains(text, "Glass Trumpet") \
			or _v17_name_contains(text, "Energy Search Pro") \
			or _v17_name_contains(text, "Energy Switch")
	return false


func _deck_should_block_exact_queue_match(_queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _v17_should_block_primary_retreat(runtime_action, game_state, player_index)


func _matches_primary_attack_text(text: String) -> bool:
	for raw: Variant in _deck_primary_attacks():
		if not (raw is Dictionary):
			continue
		var attack: Dictionary = raw
		if _v17_name_contains(text, str(attack.get("pokemon", ""))) or _v17_name_contains(text, str(attack.get("attack", ""))):
			return true
	for raw: Variant in _deck_low_value_attacks():
		if raw is Dictionary and _v17_name_contains(text, str((raw as Dictionary).get("attack", ""))):
			return true
	return false


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	return _matches_any(name, _deck_primary_attackers()) \
		or _matches_any(name, _deck_secondary_attackers()) \
		or _matches_any(name, _deck_support_pokemon()) \
		or _matches_any(name, _deck_energy_banks()) \
		or _matches_any(name, _deck_route_terms()) \
		or _v17_name_contains(name, "Rare Candy") \
		or _v17_name_contains(name, "Nest Ball") \
		or _v17_name_contains(name, "Ultra Ball") \
		or _v17_name_contains(name, "Buddy-Buddy Poffin") \
		or _v17_name_contains(name, "Earthen Vessel") \
		or _v17_name_contains(name, "Electric Generator") \
		or _v17_name_contains(name, "Glass Trumpet") \
		or _v17_name_contains(name, "Energy Search Pro") \
		or _v17_name_contains(name, "Boss") \
		or _v17_name_contains(name, "Counter Catcher") \
		or _v17_name_contains(name, "Prime Catcher")


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if _deck_hand_card_is_productive_piece(card_data):
		return true
	var name := _best_card_name(card_data)
	return _v17_name_contains(name, "Energy Retrieval") \
		or _v17_name_contains(name, "Night Stretcher") \
		or _v17_name_contains(name, "Super Rod") \
		or _v17_name_contains(name, "Arven") \
		or _v17_name_contains(name, "Irida") \
		or _v17_name_contains(name, "Crispin")


func _deck_is_low_value_runtime_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) not in ["attack", "granted_attack"]:
		return false
	var attack_name := str(action.get("attack_name", ""))
	for raw: Variant in _deck_low_value_attacks():
		if raw is Dictionary and _v17_name_contains(attack_name, str((raw as Dictionary).get("attack", ""))):
			return true
	return false


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) not in ["attack", "granted_attack"]:
		return false
	if _deck_is_low_value_runtime_attack_action(action, game_state, player_index):
		return false
	if bool(action.get("projected_knockout", false)):
		return true
	if int(action.get("projected_damage", 0)) >= 160:
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and player.active_pokemon != null and _matches_any(_slot_name(player.active_pokemon), _deck_primary_attackers())


func _v17_should_block_primary_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "retreat":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var target: PokemonSlot = action.get("bench_target", null)
	if target == null:
		return false
	var active_name := _slot_name(player.active_pokemon)
	var target_name := _slot_name(target)
	if not _matches_any(active_name, _deck_primary_attackers()):
		return false
	if _slot_energy_count(player.active_pokemon) <= 0:
		return false
	if _matches_any(target_name, _deck_support_pokemon()) or _matches_any(target_name, _deck_energy_banks()):
		return not _slot_has_ready_primary_attack(target)
	if not _matches_any(target_name, _deck_primary_attackers()) and not _matches_any(target_name, _deck_secondary_attackers()):
		return true
	if _slot_energy_count(player.active_pokemon) >= 2 and _slot_energy_count(target) == 0:
		return true
	return false


func _slot_has_ready_primary_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	var pokemon_name := _best_card_name(cd)
	if not _matches_any(pokemon_name, _deck_primary_attackers()) and not _matches_any(pokemon_name, _deck_secondary_attackers()):
		return false
	for attack: Dictionary in cd.attacks:
		var attack_name := str(attack.get("name", ""))
		var text := "%s %s" % [pokemon_name, attack_name]
		if not _matches_primary_attack_text(text):
			continue
		if _active_attack_cost_ready(slot, str(attack.get("cost", ""))):
			return true
	return false


func _slot_energy_count(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _rules_heuristic_base(kind: String) -> float:
	var rules := _ensure_rules()
	if rules != null and rules.has_method("_estimate_heuristic_base"):
		return float(rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


func _slot_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return _best_card_name(slot.get_card_data())


func _count_field_names(player: PlayerState, names: Array[String]) -> int:
	if player == null or names.is_empty():
		return 0
	var count := 0
	if player.active_pokemon != null and _matches_any(_slot_name(player.active_pokemon), names):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _matches_any(_slot_name(slot), names):
			count += 1
	return count


func _count_productive_hand_cards(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _deck_hand_card_is_productive_piece(card.card_data):
			count += 1
	return count


func _matches_any(text: String, names: Array[String]) -> bool:
	for name: String in names:
		if name != "" and _v17_name_contains(text, name):
			return true
	return false


func _v17_name_contains(text: String, query: String) -> bool:
	if query == "":
		return false
	return text.to_lower().contains(query.to_lower())


func _merge_string_arrays(left: Variant, right: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if left is Array:
		for raw: Variant in left:
			var text := str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	elif left is PackedStringArray:
		for text: String in left:
			if text != "" and not result.has(text):
				result.append(text)
	for text: String in right:
		if text != "" and not result.has(text):
			result.append(text)
	return result


func _action_ref_text(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("target", "")),
		str(ref.get("summary", "")),
	]
	for key: String in ["card_rules", "ability_rules", "attack_rules"]:
		var raw: Variant = ref.get(key, {})
		if raw is Dictionary:
			var rules: Dictionary = raw
			parts.append(str(rules.get("name", "")))
			parts.append(str(rules.get("name_en", "")))
			parts.append(str(rules.get("text", "")))
			parts.append(str(rules.get("description", "")))
	return " ".join(parts)
