class_name DeckStrategyBase
extends RefCounted

const AIIntentPlannerCoordinatorScript = preload("res://scripts/ai/intent/AIIntentPlannerCoordinator.gd")
const OpponentDeckFingerprintResolverScript = preload("res://scripts/ai/OpponentDeckFingerprintResolver.gd")
const RESOURCE_PAID_OWNER_RETREAT_PENALTY := 7000.0

var _turn_plan_context: Dictionary = {}
var _turn_contract_context: Dictionary = {}


func get_strategy_id() -> String:
	return ""


func get_signature_names() -> Array[String]:
	return []


## Pure public-state lookup. It never reads the opponent's hand, deck, or
## prizes, and it does not cache simulated/MCTS states between calls.
func resolve_opponent_deck(game_state: GameState, player_index: int) -> Dictionary:
	return OpponentDeckFingerprintResolverScript.classify_game_state(game_state, player_index)


func resolve_opponent_deck_from_visible_cards(visible_cards: Array) -> Dictionary:
	return OpponentDeckFingerprintResolverScript.classify_visible_cards(visible_cards)


func opponent_is_deck(game_state: GameState, player_index: int, deck_id: int) -> bool:
	var result := resolve_opponent_deck(game_state, player_index)
	return bool(result.get("is_unique", false)) and int(result.get("deck_id", 0)) == deck_id


func opponent_uses_strategy(game_state: GameState, player_index: int, strategy_id: String) -> bool:
	var result := resolve_opponent_deck(game_state, player_index)
	return bool(result.get("is_unique", false)) and str(result.get("strategy_id", "")) == strategy_id


## Stable public contract shared by Graph overlays, matchup-specific BC models,
## and decision exports. Exact identity is deliberately blank until the public
## fingerprint is unique.
func build_matchup_context(game_state: GameState, player_index: int) -> Dictionary:
	var resolved := resolve_opponent_deck(game_state, player_index)
	var is_unique := bool(resolved.get("is_unique", false))
	return {
		"status": str(resolved.get("status", "unknown")),
		"is_unique": is_unique,
		"scope": str(resolved.get("scope", "v18_builtin_25")),
		"opponent_deck_id": int(resolved.get("deck_id", 0)) if is_unique else 0,
		"opponent_strategy_id": str(resolved.get("strategy_id", "")) if is_unique else "",
		"opponent_archetype": str(resolved.get("archetype", "")) if is_unique else "",
		"observed_card_count": int(resolved.get("observed_card_count", 0)),
		"evidence_card_count": int(resolved.get("evidence_card_count", 0)),
		"candidate_count": (resolved.get("candidate_deck_ids", []) as Array).size() \
			if resolved.get("candidate_deck_ids", []) is Array else 0,
	}


## Concrete strategies return only public-state-safe deltas here. The host
## applies them after the ordinary turn contract is built, so subclasses do not
## need to duplicate their normal plan just to add a matchup branch.
func build_matchup_overlay(
	_game_state: GameState,
	_player_index: int,
	_matchup_context: Dictionary
) -> Dictionary:
	return {}


func apply_matchup_overlay_to_turn_contract(
	turn_contract: Dictionary,
	game_state: GameState,
	player_index: int,
	matchup_context: Dictionary = {}
) -> Dictionary:
	var normalized_context := matchup_context.duplicate(true)
	if normalized_context.is_empty():
		normalized_context = build_matchup_context(game_state, player_index)
	var merged := _normalize_turn_contract(turn_contract)
	merged["matchup_context"] = normalized_context.duplicate(true)
	var contract_context: Dictionary = merged.get("context", {}) if merged.get("context", {}) is Dictionary else {}
	contract_context["matchup_context"] = normalized_context.duplicate(true)
	merged["context"] = contract_context
	if not bool(normalized_context.get("is_unique", false)):
		return merged

	var overlay := build_matchup_overlay(game_state, player_index, normalized_context)
	if overlay.is_empty():
		return merged
	var resolved_strategy_id := str(normalized_context.get("opponent_strategy_id", ""))
	var required_strategy_id := str(overlay.get("opponent_strategy_id", resolved_strategy_id))
	if resolved_strategy_id == "" or required_strategy_id != resolved_strategy_id:
		return merged

	var overlay_id := str(overlay.get("id", "")).strip_edges()
	merged["matchup_overlay_id"] = overlay_id
	for section: String in ["flags", "targets", "constraints", "owner"]:
		var delta: Variant = overlay.get(section, {})
		if not (delta is Dictionary):
			continue
		var current: Dictionary = merged.get(section, {}) if merged.get(section, {}) is Dictionary else {}
		current.merge(delta as Dictionary, true)
		merged[section] = current
	var priority_delta: Variant = overlay.get("priorities", {})
	if priority_delta is Dictionary:
		var priorities: Dictionary = merged.get("priorities", {}) if merged.get("priorities", {}) is Dictionary else {}
		for raw_key: Variant in (priority_delta as Dictionary).keys():
			var key := str(raw_key)
			var requested: Variant = (priority_delta as Dictionary).get(raw_key, [])
			if not (requested is Array):
				continue
			var combined: Array = []
			for item: Variant in requested as Array:
				if item not in combined:
					combined.append(item)
			var existing: Variant = priorities.get(key, [])
			if existing is Array:
				for item: Variant in existing as Array:
					if item not in combined:
						combined.append(item)
			priorities[key] = combined
		merged["priorities"] = priorities
	var flags: Dictionary = merged.get("flags", {}) if merged.get("flags", {}) is Dictionary else {}
	flags["matchup_overlay_active"] = true
	flags["matchup_overlay_id"] = overlay_id
	merged["flags"] = flags
	return merged


## These two hooks are added by the host after the deck's ordinary Rule score.
## They must return deltas, not absolute scores, so unknown/ambiguous opponents
## and missing overlays naturally fall back to the generic strategy.
func score_matchup_action(
	_action: Dictionary,
	_game_state: GameState,
	_player_index: int,
	_matchup_context: Dictionary,
	_turn_contract: Dictionary = {}
) -> float:
	return 0.0


func score_matchup_interaction_target(
	_item: Variant,
	_step: Dictionary,
	_context: Dictionary,
	_matchup_context: Dictionary
) -> float:
	return 0.0


func get_state_encoder_class() -> GDScript:
	return null


func load_value_net(_path: String) -> bool:
	return false


func get_value_net() -> RefCounted:
	return null


func get_mcts_config() -> Dictionary:
	return {}


func get_intent_planner_profile() -> Dictionary:
	return {}


func build_intent_facts(game_state: GameState, player_index: int, legal_action_refs: Array = []) -> Dictionary:
	var coordinator: RefCounted = AIIntentPlannerCoordinatorScript.new()
	return coordinator.call("build_facts", game_state, player_index, legal_action_refs, get_intent_planner_profile())


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
	var score: float = _score_action_absolute_with_contract_context(
		action,
		game_state,
		player_index,
		turn_contract
	)
	score += _score_continuity_action_bonus(action, game_state, player_index, turn_contract)
	score += _score_resource_paid_owner_retreat_guard(action, game_state, player_index, turn_contract)
	return score


func score_action_absolute_with_plan_context_only(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary = {}
) -> float:
	return _score_action_absolute_with_contract_context(
		action,
		game_state,
		player_index,
		_normalize_turn_contract(turn_plan)
	)


func _score_action_absolute_with_contract_context(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary
) -> float:
	_set_turn_plan_context(turn_contract)
	_set_turn_contract_context(turn_contract)
	var score: float = score_action_absolute(action, game_state, player_index)
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
	if not target_names.is_empty():
		var action_target_names: Array[String] = _continuity_action_target_names(action)
		var has_target_match := false
		for action_target_name: String in action_target_names:
			if target_names.has(action_target_name):
				has_target_match = true
				break
		if not has_target_match:
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
	var names: Array[String] = _continuity_action_target_names(action)
	if not names.is_empty():
		return names[0]
	return ""


func _continuity_action_target_names(action: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var target: Variant = action.get("target_slot", null)
	if target is PokemonSlot:
		names.append(_slot_name(target))
	var source: Variant = action.get("source_slot", null)
	if source is PokemonSlot:
		names.append(_slot_name(source))
	for key: String in ["target_name", "target"]:
		var value := str(action.get(key, ""))
		if value != "":
			names.append(value)
	var targets: Variant = action.get("targets", [])
	if targets is Array:
		for target_entry: Variant in targets:
			_collect_continuity_target_names(target_entry, names)
	return names


func _collect_continuity_target_names(value: Variant, names: Array[String]) -> void:
	if value is Dictionary:
		for nested: Variant in (value as Dictionary).values():
			_collect_continuity_target_names(nested, names)
	elif value is Array:
		for nested: Variant in value:
			_collect_continuity_target_names(nested, names)
	elif value is PokemonSlot:
		names.append(_slot_name(value))
	elif value is CardInstance:
		names.append(_cname(value))
	elif value is CardData:
		var cd: CardData = value
		names.append(cd.name_en if cd.name_en != "" else cd.name)
	else:
		var text := str(value)
		if text != "":
			names.append(text)


func _is_continuity_terminal_attack(action: Dictionary) -> bool:
	return str(action.get("kind", "")) in ["attack", "granted_attack"]


func _is_continuity_final_prize_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not bool(action.get("projected_knockout", false)):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.prizes.is_empty():
		return false
	if player.prizes.size() <= 1:
		return true
	if game_state.players.size() != 2:
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	return opponent.active_pokemon.get_prize_count() >= player.prizes.size()


func _score_resource_paid_owner_retreat_guard(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary
) -> float:
	if str(action.get("kind", "")) != "retreat":
		return 0.0
	var flags: Variant = turn_contract.get("flags", {})
	if flags is Dictionary and bool((flags as Dictionary).get("allow_resource_paid_owner_retreat", false)):
		return 0.0
	var discards: Variant = action.get("energy_to_discard", [])
	if not (discards is Array) or (discards as Array).is_empty():
		return 0.0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return 0.0
	var target: Variant = action.get("bench_target", null)
	if not (target is PokemonSlot):
		return 0.0
	var active: PokemonSlot = player.active_pokemon
	var target_slot: PokemonSlot = target as PokemonSlot
	if not _slot_matches_turn_contract_route_name(active, turn_contract):
		return 0.0
	if _slot_matches_turn_contract_route_name(target_slot, turn_contract) and not _slot_has_printed_ready_attack(active) and _slot_has_printed_ready_attack(target_slot):
		return 0.0
	return -RESOURCE_PAID_OWNER_RETREAT_PENALTY


func _slot_matches_turn_contract_route_name(slot: PokemonSlot, turn_contract: Dictionary) -> bool:
	if slot == null or turn_contract.is_empty():
		return false
	for route_name: String in _turn_contract_route_names(turn_contract):
		if _slot_label_matches(slot, route_name):
			return true
	return false


func _turn_contract_route_names(turn_contract: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var owner: Variant = turn_contract.get("owner", {})
	if owner is Dictionary:
		for key: String in ["turn_owner_name", "bridge_target_name", "pivot_target_name"]:
			_append_unique_contract_name(names, str((owner as Dictionary).get(key, "")))
	var targets: Variant = turn_contract.get("targets", {})
	if targets is Dictionary:
		for key: String in ["primary_attacker_name", "bridge_target_name", "pivot_target_name"]:
			_append_unique_contract_name(names, str((targets as Dictionary).get(key, "")))
	for key: String in ["turn_owner_name", "bridge_target_name", "pivot_target_name", "primary_attacker_name"]:
		_append_unique_contract_name(names, str(turn_contract.get(key, "")))
	return names


func _append_unique_contract_name(names: Array[String], value: String) -> void:
	var text := value.strip_edges()
	if text != "" and not names.has(text):
		names.append(text)


func _slot_label_matches(slot: PokemonSlot, candidate: String) -> bool:
	var wanted := candidate.strip_edges().to_lower()
	if wanted == "" or slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	var labels: Array[String] = [str(cd.name), str(cd.name_en), str(cd.effect_id)]
	if str(cd.set_code) != "" and str(cd.card_index) != "":
		labels.append("%s_%s" % [str(cd.set_code), str(cd.card_index)])
	for label: String in labels:
		if label.strip_edges().to_lower() == wanted:
			return true
	return false


func _slot_has_printed_ready_attack(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	for attack: Dictionary in cd.attacks:
		var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
		if cost == "":
			continue
		if slot.attached_energy.size() >= cost.length():
			return true
	return false


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
