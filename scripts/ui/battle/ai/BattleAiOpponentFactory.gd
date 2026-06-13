class_name BattleAiOpponentFactory
extends RefCounted

const AIOpponentScript := preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyGardevoirScript := preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript := preload("res://scripts/ai/DeckStrategyMiraidon.gd")


func build_selected_ai_opponent(
	deck_strategy_registry: RefCounted,
	ai_version_registry: RefCounted,
	agent_version_store: RefCounted,
	host_scene: Node
) -> AIOpponent:
	var selection: Dictionary = GameManager.ai_selection
	if is_strong_fixed_opening_mode():
		return build_default_ai_opponent(deck_strategy_registry, host_scene)
	var source := str(selection.get("source", "default"))
	if source == "default":
		return build_default_ai_opponent(deck_strategy_registry, host_scene)

	var version_record := resolve_selected_ai_version_record(selection, deck_strategy_registry, ai_version_registry)
	if version_record.is_empty():
		return build_default_ai_opponent(deck_strategy_registry, host_scene)

	var agent_config_path := str(version_record.get("agent_config_path", selection.get("agent_config_path", "")))
	if not ai_path_exists(agent_config_path):
		return build_default_ai_opponent(deck_strategy_registry, host_scene)

	var agent_config := load_selected_agent_config(agent_config_path, agent_version_store)
	if agent_config.is_empty():
		return build_default_ai_opponent(deck_strategy_registry, host_scene)

	var ai := build_default_ai_opponent(deck_strategy_registry, host_scene)
	var config_weights: Variant = agent_config.get("heuristic_weights", {})
	if config_weights is Dictionary and not (config_weights as Dictionary).is_empty():
		ai.heuristic_weights = (config_weights as Dictionary).duplicate(true)

	var config_mcts: Variant = agent_config.get("mcts_config", {})
	if config_mcts is Dictionary and not (config_mcts as Dictionary).is_empty():
		ai.use_mcts = true
		ai.mcts_config = (config_mcts as Dictionary).duplicate(true)

	var value_net_path := str(version_record.get("value_net_path", selection.get("value_net_path", agent_config.get("value_net_path", ""))))
	if value_net_path != "":
		if not ai_path_exists(value_net_path):
			return build_default_ai_opponent(deck_strategy_registry, host_scene)
		ai.value_net_path = value_net_path
	var action_scorer_path := str(version_record.get("action_scorer_path", selection.get("action_scorer_path", agent_config.get("action_scorer_path", ""))))
	if action_scorer_path != "":
		if not ai_path_exists(action_scorer_path):
			return build_default_ai_opponent(deck_strategy_registry, host_scene)
		ai.action_scorer_path = action_scorer_path
	var interaction_scorer_path := str(version_record.get("interaction_scorer_path", selection.get("interaction_scorer_path", agent_config.get("interaction_scorer_path", ""))))
	if interaction_scorer_path != "":
		if not ai_path_exists(interaction_scorer_path):
			return build_default_ai_opponent(deck_strategy_registry, host_scene)
		ai.interaction_scorer_path = interaction_scorer_path

	var version_id := str(version_record.get("version_id", selection.get("version_id", "")))
	var display_name := str(version_record.get("display_name", selection.get("display_name", version_id)))
	ai.set_meta("ai_source", source)
	ai.set_meta("ai_version_id", version_id)
	ai.set_meta("ai_display_name", display_name)
	return ai


func build_default_ai_opponent(deck_strategy_registry: RefCounted, host_scene: Node) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(1, GameManager.ai_difficulty)
	ai.use_mcts = true
	ai.mcts_config = {
		"branch_factor": 2,
		"rollouts_per_sequence": 3,
		"rollout_max_steps": 30,
		"time_budget_ms": 2000,
	}
	var strategy_label := "Default AI"
	var selection_display_name := str(GameManager.ai_selection.get("display_name", "")).strip_edges()
	var deck_strategy = resolve_selected_ai_deck_strategy(deck_strategy_registry)
	if deck_strategy != null:
		var variant_strategy := resolve_strategy_variant_override(deck_strategy, deck_strategy_registry, host_scene)
		if variant_strategy != null and variant_strategy != deck_strategy:
			deck_strategy = variant_strategy
		ai.set_deck_strategy(deck_strategy)
		strategy_label = str(deck_strategy.call("get_strategy_id")) if deck_strategy.has_method("get_strategy_id") else "Default AI"
	elif GameManager.selected_deck_ids.size() < 2:
		match GameManager.ai_deck_strategy:
			"gardevoir_mcts":
				var strategy := DeckStrategyGardevoirScript.new()
				ai.set_deck_strategy(strategy)
				ai.use_mcts = true
				ai.mcts_config = strategy.get_mcts_config()
				var vnet_path := "user://ai_agents/gardevoir_value_net.json"
				if strategy.load_value_net(vnet_path):
					ai._mcts_planner.value_net = strategy.get_value_net()
					ai._mcts_planner.state_encoder_class = strategy.get_state_encoder_class()
					strategy_label = "沙奈朵 v8 ValueNet"
				else:
					strategy_label = "沙奈朵 v8 MCTS"
			"gardevoir_greedy":
				var strategy := DeckStrategyGardevoirScript.new()
				ai.set_deck_strategy(strategy)
				ai.use_mcts = false
				strategy_label = "沙奈朵 %s 规则驱动" % DeckStrategyGardevoirScript.VERSION
			"gardevoir":
				strategy_label = "沙奈朵策略 %s" % DeckStrategyGardevoirScript.VERSION
			"miraidon_mcts":
				var m_strategy := DeckStrategyMiraidonScript.new()
				ai.set_deck_strategy(m_strategy)
				ai.use_mcts = true
				ai.mcts_config = m_strategy.get_mcts_config()
				var m_vnet_path := "user://ai_agents/miraidon_value_net.json"
				if m_strategy.load_value_net(m_vnet_path):
					ai._mcts_planner.value_net = m_strategy.get_value_net()
					ai._mcts_planner.state_encoder_class = m_strategy.get_state_encoder_class()
					strategy_label = "密勒顿 v1 ValueNet"
				else:
					strategy_label = "密勒顿 v1 MCTS"
			"miraidon_greedy":
				var m_strategy := DeckStrategyMiraidonScript.new()
				ai.set_deck_strategy(m_strategy)
				ai.use_mcts = false
				strategy_label = "密勒顿 %s 规则驱动" % DeckStrategyMiraidonScript.VERSION
			"generic":
				pass
	if is_strong_fixed_opening_mode():
		ai.use_mcts = false
		ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
		strategy_label += " 强开局"
	ai.set_meta("ai_source", "default")
	ai.set_meta("ai_version_id", "")
	ai.set_meta("ai_display_name", selection_display_name if selection_display_name != "" else strategy_label)
	return ai


func is_strong_fixed_opening_mode() -> bool:
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	var selection: Dictionary = GameManager.ai_selection
	return str(selection.get("opening_mode", "default")) == "fixed_order" \
		and str(selection.get("fixed_deck_order_path", "")) != ""


func resolve_selected_ai_version_record(
	selection: Dictionary,
	deck_strategy_registry: RefCounted,
	ai_version_registry: RefCounted
) -> Dictionary:
	var source := str(selection.get("source", "default"))
	if source == "latest_trained":
		if ai_version_registry != null and ai_version_registry.has_method("get_latest_playable_version"):
			var latest: Variant = ai_version_registry.call("get_latest_playable_version")
			if latest is Dictionary:
				var latest_record: Dictionary = (latest as Dictionary).duplicate(true)
				return latest_record if is_version_record_compatible_with_selected_ai(latest_record, deck_strategy_registry) else {}
		return {}
	if source == "specific_version":
		var version_id := str(selection.get("version_id", ""))
		if version_id != "" and ai_version_registry != null and ai_version_registry.has_method("get_version"):
			var version: Variant = ai_version_registry.call("get_version", version_id)
			if version is Dictionary and not (version as Dictionary).is_empty():
				var version_record: Dictionary = (version as Dictionary).duplicate(true)
				return version_record if is_version_record_compatible_with_selected_ai(version_record, deck_strategy_registry) else {}
	return {}


func resolve_selected_ai_deck_strategy(deck_strategy_registry: RefCounted) -> RefCounted:
	if deck_strategy_registry == null or not deck_strategy_registry.has_method("resolve_strategy_for_deck"):
		return null
	if GameManager.selected_deck_ids.size() < 2:
		return null
	var ai_deck: DeckData = GameManager.resolve_selected_battle_deck(1)
	if ai_deck == null:
		return null
	return deck_strategy_registry.call("resolve_strategy_for_deck", ai_deck)


func resolve_strategy_variant_override(strategy: RefCounted, deck_strategy_registry: RefCounted, host_scene: Node) -> RefCounted:
	var variant_id := str(GameManager.ai_deck_strategy).strip_edges()
	if variant_id == "" or strategy == null or not strategy.has_method("get_strategy_id"):
		return strategy
	var base_id: String = str(strategy.call("get_strategy_id"))
	if variant_id == base_id:
		return strategy
	if deck_strategy_registry == null:
		return strategy
	var variant: RefCounted = deck_strategy_registry.call("create_strategy_by_id", variant_id)
	if variant == null:
		return strategy
	if strategy.has_method("get_deck_strategy_text") and variant.has_method("set_deck_strategy_text"):
		variant.call("set_deck_strategy_text", str(strategy.call("get_deck_strategy_text")))
	var ai_deck: DeckData = GameManager.resolve_selected_battle_deck(1) if GameManager.selected_deck_ids.size() >= 2 else null
	if ai_deck != null and variant.has_method("configure_from_deck"):
		variant.call("configure_from_deck", ai_deck)
	if variant.has_method("set_llm_host_node"):
		variant.call("set_llm_host_node", host_scene)
	connect_llm_strategy_signals(variant, host_scene)
	return variant


func selected_ai_strategy_id(deck_strategy_registry: RefCounted) -> String:
	if deck_strategy_registry == null or not deck_strategy_registry.has_method("resolve_strategy_id_for_deck"):
		return ""
	if GameManager.selected_deck_ids.size() < 2:
		return ""
	var ai_deck: DeckData = GameManager.resolve_selected_battle_deck(1)
	if ai_deck == null:
		return ""
	return str(deck_strategy_registry.call("resolve_strategy_id_for_deck", ai_deck))


func is_version_record_compatible_with_selected_ai(version_record: Dictionary, deck_strategy_registry: RefCounted) -> bool:
	var compatible_strategy_id := str(version_record.get("compatible_strategy_id", ""))
	if compatible_strategy_id == "":
		return true
	var selected_strategy := selected_ai_strategy_id(deck_strategy_registry)
	if selected_strategy == "":
		return false
	return compatible_strategy_id == selected_strategy


func load_selected_agent_config(agent_config_path: String, agent_version_store: RefCounted) -> Dictionary:
	if agent_version_store == null or not agent_version_store.has_method("load_version"):
		return {}
	var loaded: Variant = agent_version_store.call("load_version", agent_config_path)
	return (loaded as Dictionary).duplicate(true) if loaded is Dictionary else {}


func ai_path_exists(path: String) -> bool:
	if path == "":
		return false
	if FileAccess.file_exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func connect_llm_strategy_signals(strategy: RefCounted, host_scene: Node) -> void:
	if strategy == null or host_scene == null:
		return
	var started_cb := Callable(host_scene, "_on_llm_thinking_started")
	var finished_cb := Callable(host_scene, "_on_llm_thinking_finished")
	var failed_cb := Callable(host_scene, "_on_llm_thinking_failed")
	if strategy.has_signal("llm_thinking_started") and not strategy.is_connected("llm_thinking_started", started_cb):
		strategy.connect("llm_thinking_started", started_cb)
	if strategy.has_signal("llm_thinking_finished") and not strategy.is_connected("llm_thinking_finished", finished_cb):
		strategy.connect("llm_thinking_finished", finished_cb)
	if strategy.has_signal("llm_thinking_failed") and not strategy.is_connected("llm_thinking_failed", failed_cb):
		strategy.connect("llm_thinking_failed", failed_cb)
