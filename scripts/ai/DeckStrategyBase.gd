class_name DeckStrategyBase
extends RefCounted

var _turn_plan_context: Dictionary = {}
var _turn_contract_context: Dictionary = {}


func get_strategy_id() -> String:
	return ""


func get_signature_names() -> Array[String]:
	return []


func get_state_encoder_class() -> GDScript:
	return null


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {}


func plan_opening_setup(_player: PlayerState) -> Dictionary:
	return {}


func score_action_absolute(_action: Dictionary, _game_state: GameState, _player_index: int) -> float:
	return 0.0


func score_action(_action: Dictionary, _context: Dictionary) -> float:
	return 0.0


func evaluate_board(_game_state: GameState, _player_index: int) -> float:
	return 0.0


func predict_attacker_damage(_slot: PokemonSlot, _extra_context: int = 0) -> Dictionary:
	return {"damage": 0, "can_attack": false, "description": ""}


func get_discard_priority(_card: CardInstance) -> int:
	return 0


func get_discard_priority_contextual(_card: CardInstance, _game_state: GameState, _player_index: int) -> int:
	return 0


func get_search_priority(_card: CardInstance) -> int:
	return 0


func score_interaction_target(_item: Variant, _step: Dictionary, _context: Dictionary = {}) -> float:
	return 0.0


func score_handoff_target(_item: Variant, _step: Dictionary, _context: Dictionary = {}) -> float:
	return score_interaction_target(_item, _step, _context)


func build_turn_plan(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
	return {}


func build_turn_contract(_game_state: GameState, _player_index: int, _context: Dictionary = {}) -> Dictionary:
	return _normalize_turn_contract(build_turn_plan(_game_state, _player_index, _context))


func build_continuity_contract(
	_game_state: GameState,
	_player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	return {}


func score_action_absolute_with_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary = {}
) -> float:
	var turn_contract := _normalize_turn_contract(turn_plan)
	_set_turn_plan_context(turn_contract)
	_set_turn_contract_context(turn_contract)
	var score: float = score_action_absolute(action, game_state, player_index)
	score += _score_continuity_action_bonus(action, game_state, player_index, turn_contract)
	_clear_turn_plan_context()
	_clear_turn_contract_context()
	return score


func get_turn_plan_context() -> Dictionary:
	return _turn_plan_context.duplicate(true)


func get_turn_contract_context() -> Dictionary:
	return _turn_contract_context.duplicate(true)


func _set_turn_plan_context(turn_plan: Dictionary) -> void:
	_turn_plan_context = turn_plan.duplicate(true)


func _clear_turn_plan_context() -> void:
	_turn_plan_context.clear()


func _set_turn_contract_context(turn_contract: Dictionary) -> void:
	_turn_contract_context = turn_contract.duplicate(true)


func _clear_turn_contract_context() -> void:
	_turn_contract_context.clear()


func _normalize_turn_contract(turn_plan: Dictionary) -> Dictionary:
	var normalized: Dictionary = turn_plan.duplicate(true)
	if not normalized.has("id"):
		normalized["id"] = str(normalized.get("intent", normalized.get("phase", "")))
	if not normalized.has("intent"):
		normalized["intent"] = str(normalized.get("id", ""))
	if not normalized.has("phase"):
		normalized["phase"] = ""
	var flags: Variant = normalized.get("flags", {})
	if not (flags is Dictionary):
		normalized["flags"] = {}
	var targets: Dictionary = normalized.get("targets", {}) if normalized.get("targets", {}) is Dictionary else {}
	normalized["targets"] = targets
	var constraints: Dictionary = normalized.get("constraints", {}) if normalized.get("constraints", {}) is Dictionary else {}
	normalized["constraints"] = constraints
	var owner: Dictionary = normalized.get("owner", {}) if normalized.get("owner", {}) is Dictionary else {}
	if not owner.has("turn_owner_name"):
		owner["turn_owner_name"] = str(normalized.get("turn_owner_name", targets.get("primary_attacker_name", "")))
	if not owner.has("bridge_target_name"):
		owner["bridge_target_name"] = str(normalized.get("bridge_target_name", targets.get("bridge_target_name", "")))
	if not owner.has("pivot_target_name"):
		var pivot_name: String = str(owner.get("turn_owner_name", ""))
		owner["pivot_target_name"] = str(normalized.get("pivot_target_name", pivot_name))
	normalized["owner"] = owner
	var priorities: Dictionary = normalized.get("priorities", {}) if normalized.get("priorities", {}) is Dictionary else {}
	if not priorities.has("attach"):
		var attach_priority: Array[String] = []
		if str(owner.get("bridge_target_name", "")) != "":
			attach_priority.append(str(owner.get("bridge_target_name", "")))
		if str(owner.get("turn_owner_name", "")) != "" and str(owner.get("turn_owner_name", "")) != str(owner.get("bridge_target_name", "")):
			attach_priority.append(str(owner.get("turn_owner_name", "")))
		priorities["attach"] = attach_priority
	if not priorities.has("handoff"):
		var handoff_priority: Array[String] = []
		if str(owner.get("pivot_target_name", "")) != "":
			handoff_priority.append(str(owner.get("pivot_target_name", "")))
		priorities["handoff"] = handoff_priority
	if not priorities.has("search"):
		var search_priority: Array[String] = []
		if str(owner.get("bridge_target_name", "")) != "":
			search_priority.append(str(owner.get("bridge_target_name", "")))
		priorities["search"] = search_priority
	normalized["priorities"] = priorities
	if not normalized.has("forbidden_action_kinds"):
		var forbidden: Array[String] = []
		if bool(constraints.get("forbid_engine_churn", false)):
			forbidden.append_array(["play_trainer:IONO", "play_trainer:JUDGE", "use_ability:BIBAREL", "use_ability:SKWOVET"])
		if bool(constraints.get("forbid_extra_bench_padding", false)):
			forbidden.append("play_basic_to_bench")
		normalized["forbidden_action_kinds"] = forbidden
	if not normalized.has("context") or not (normalized.get("context", {}) is Dictionary):
		normalized["context"] = {}
	return normalized


func _score_continuity_action_bonus(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary
) -> float:
	var continuity: Dictionary = _normalize_continuity_contract(
		build_continuity_contract(game_state, player_index, turn_contract)
	)
	if not bool(continuity.get("enabled", false)):
		return 0.0
	var bonus := 0.0
	var action_bonuses: Variant = continuity.get("action_bonuses", [])
	if action_bonuses is Array:
		for rule_variant: Variant in action_bonuses:
			if not (rule_variant is Dictionary):
				continue
			var rule: Dictionary = rule_variant
			if _continuity_action_matches(action, rule):
				bonus += float(rule.get("bonus", 0.0))
	if bool(continuity.get("safe_setup_before_attack", false)) and _is_continuity_terminal_attack(action):
		if not _is_continuity_final_prize_attack(action, game_state, player_index):
			bonus -= float(continuity.get("attack_penalty", 0.0))
	return bonus


func _normalize_continuity_contract(contract: Dictionary) -> Dictionary:
	var normalized: Dictionary = contract.duplicate(true)
	normalized["enabled"] = bool(normalized.get("enabled", false))
	normalized["safe_setup_before_attack"] = bool(normalized.get("safe_setup_before_attack", false))
	if not (normalized.get("setup_debt", {}) is Dictionary):
		normalized["setup_debt"] = {}
	if not (normalized.get("action_bonuses", []) is Array):
		normalized["action_bonuses"] = []
	if not normalized.has("attack_penalty"):
		normalized["attack_penalty"] = 0.0
	return normalized


func _continuity_action_matches(action: Dictionary, rule: Dictionary) -> bool:
	var kind := str(rule.get("kind", ""))
	if kind != "" and str(action.get("kind", "")) != kind:
		return false
	var action_ids: Array[String] = _continuity_string_array(rule.get("action_ids", []))
	if not action_ids.is_empty():
		var id := str(action.get("id", action.get("action_id", "")))
		if not action_ids.has(id):
			return false
	var card_names: Array[String] = _continuity_string_array(rule.get("card_names", []))
	if not card_names.is_empty() and not card_names.has(_continuity_action_card_name(action)):
		return false
	var attack_names: Array[String] = _continuity_string_array(rule.get("attack_names", []))
	if not attack_names.is_empty() and not attack_names.has(_continuity_action_attack_name(action)):
		return false
	var target_names: Array[String] = _continuity_string_array(rule.get("target_names", []))
	if not target_names.is_empty() and not target_names.has(_continuity_action_target_name(action)):
		return false
	return true


func _continuity_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			var text := str(item)
			if text != "":
				result.append(text)
	elif str(value) != "":
		result.append(str(value))
	return result


func _continuity_action_card_name(action: Dictionary) -> String:
	var card: Variant = action.get("card", null)
	if card is CardInstance:
		return _cname(card)
	if card is CardData:
		var cd: CardData = card
		return cd.name_en if cd.name_en != "" else cd.name
	for key: String in ["card_name", "name", "source_name"]:
		var value := str(action.get(key, ""))
		if value != "":
			return value
	return ""


func _continuity_action_attack_name(action: Dictionary) -> String:
	var attack_name := str(action.get("attack_name", ""))
	if attack_name != "":
		return attack_name
	var granted: Variant = action.get("granted_attack_data", {})
	if granted is Dictionary:
		return str((granted as Dictionary).get("name", ""))
	return ""


func _continuity_action_target_name(action: Dictionary) -> String:
	var target: Variant = action.get("target_slot", null)
	if target is PokemonSlot:
		return _slot_name(target)
	var source: Variant = action.get("source_slot", null)
	if source is PokemonSlot:
		return _slot_name(source)
	return str(action.get("target_name", action.get("target", "")))


func _is_continuity_terminal_attack(action: Dictionary) -> bool:
	return str(action.get("kind", "")) in ["attack", "granted_attack"]


func _is_continuity_final_prize_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not bool(action.get("projected_knockout", false)):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and player.prizes.size() <= 1


# ============================================================
#  名称解析工具（优先返回英文名，兼容中英文卡牌数据）
# ============================================================

func _slot_name(slot: PokemonSlot) -> String:
	## 获取宝可梦槽位的名称，优先返回英文名
	if slot == null:
		return ""
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return ""
	if cd.name_en != "":
		return cd.name_en
	return cd.name


func _cname(card: Variant) -> String:
	## 获取卡牌实例的名称，优先返回英文名
	if card is CardInstance:
		var ci: CardInstance = card as CardInstance
		if ci.card_data != null:
			if ci.card_data.name_en != "":
				return ci.card_data.name_en
			return ci.card_data.name
	return ""


func _slot_is(slot: PokemonSlot, names: Array) -> bool:
	## 检查槽位宝可梦名称是否在列表中（同时匹配中英文）
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.name in names or cd.name_en in names


func _count_name_on_field(player: PlayerState, target_name: String) -> int:
	## 计算场上指定名称的宝可梦数量（同时匹配中英文）
	var count: int = 0
	if player.active_pokemon != null:
		if _slot_is(player.active_pokemon, [target_name]):
			count += 1
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_is(slot, [target_name]):
			count += 1
	return count
