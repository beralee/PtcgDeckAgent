class_name V18CPGRulesFallbackAdapter
extends RefCounted

const RulesStrategyScript = preload("res://scripts/ai/DeckStrategyV18Rules.gd")

var _strategy: RefCounted = null


func configure(rule_profile: Dictionary, deck: DeckData = null) -> void:
	_strategy = RulesStrategyScript.new()
	if not rule_profile.is_empty() and _strategy.has_method("configure_profile"):
		_strategy.call("configure_profile", rule_profile.duplicate(true))
	# Match DeckStrategyRegistry's configuration contract exactly.  Several V18
	# rule delegates use the deck-authored strategy text, so omitting it changes
	# decisions even when the model runtime is disabled.
	if deck != null and _strategy.has_method("set_deck_strategy_text"):
		_strategy.call("set_deck_strategy_text", str(deck.strategy))
	if deck != null and _strategy.has_method("configure_from_deck"):
		_strategy.call("configure_from_deck", deck)


func is_ready() -> bool:
	return _strategy != null


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if _strategy == null:
		return {}
	if _strategy.has_method("build_turn_contract"):
		return _strategy.call("build_turn_contract", game_state, player_index, context)
	if _strategy.has_method("build_turn_plan"):
		return _strategy.call("build_turn_plan", game_state, player_index, context)
	return {}


func score_action(action: Dictionary, game_state: GameState, player_index: int, turn_plan: Dictionary = {}) -> float:
	if _strategy == null:
		return 0.0
	if _strategy.has_method("score_action_absolute_with_plan"):
		return float(_strategy.call("score_action_absolute_with_plan", action, game_state, player_index, turn_plan))
	if _strategy.has_method("score_action_absolute"):
		return float(_strategy.call("score_action_absolute", action, game_state, player_index))
	return 0.0


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if _strategy != null and _strategy.has_method("pick_interaction_items"):
		var picked: Variant = _strategy.call("pick_interaction_items", items, step, context)
		return picked if picked is Array else []
	return []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _strategy != null and _strategy.has_method("score_interaction_target"):
		return float(_strategy.call("score_interaction_target", item, step, context))
	return 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _strategy != null and _strategy.has_method("score_handoff_target"):
		return float(_strategy.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if _strategy != null and _strategy.has_method("plan_opening_setup"):
		return _strategy.call("plan_opening_setup", player)
	return {}


func get_intent_planner_profile() -> Dictionary:
	if _strategy != null and _strategy.has_method("get_intent_planner_profile"):
		return _strategy.call("get_intent_planner_profile")
	return {}
