extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const GardevoirRulesScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")

const GARDEVOIR_LLM_ID := "gardevoir_llm"
const RALTS := "Ralts"
const KIRLIA := "Kirlia"
const GARDEVOIR_EX := "Gardevoir ex"
const DRIFLOON := "Drifloon"
const DRIFBLIM := "Drifblim"
const SCREAM_TAIL := "Scream Tail"
const MUNKIDORI := "Munkidori"
const RADIANT_GRENINJA := "Radiant Greninja"
const KLEFKI := "Klefki"
const FLUTTER_MANE := "Flutter Mane"
const MANAPHY := "Manaphy"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const NEST_BALL := "Nest Ball"
const ULTRA_BALL := "Ultra Ball"
const EARTHEN_VESSEL := "Earthen Vessel"
const RARE_CANDY := "Rare Candy"
const TM_EVOLUTION := "Technical Machine: Evolution"
const ARVEN := "Arven"
const ARTAZON := "Artazon"
const SECRET_BOX := "Secret Box"
const NIGHT_STRETCHER := "Night Stretcher"
const SUPER_ROD := "Super Rod"
const BRAVERY_CHARM := "Bravery Charm"
const COUNTER_CATCHER := "Counter Catcher"
const BOSSS_ORDERS := "Boss's Orders"
const PSYCHIC_ENERGY := "Psychic Energy"
const DARKNESS_ENERGY := "Darkness Energy"

const GARDEVOIR_CORE_NAMES: Array[String] = [RALTS, KIRLIA, GARDEVOIR_EX]
const GARDEVOIR_ATTACKER_NAMES: Array[String] = [DRIFLOON, DRIFBLIM, SCREAM_TAIL]
const GARDEVOIR_SUPPORT_NAMES: Array[String] = [MUNKIDORI, RADIANT_GRENINJA, KLEFKI, FLUTTER_MANE, MANAPHY]
const MAX_CONVERSION_REPAIR_ACTIONS := 3
var _deck_strategy_text: String = ""
var _rules: RefCounted = GardevoirRulesScript.new()
var gardevoir_value_net: RefCounted = null
var _last_gardevoir_engine_online := false
var _last_gardevoir_attacker_count := 0
var _last_gardevoir_ready_attacker_count := 0


func get_strategy_id() -> String:
	return GARDEVOIR_LLM_ID


func get_signature_names() -> Array[String]:
	var names: Array[String] = []
	if _rules != null and _rules.has_method("get_signature_names"):
		var raw_names: Variant = _rules.call("get_signature_names")
		if raw_names is Array:
			for raw_name: Variant in raw_names:
				var name := str(raw_name)
				if name != "" and not names.has(name):
					names.append(name)
	for name: String in [
		RALTS,
		KIRLIA,
		GARDEVOIR_EX,
		DRIFLOON,
		SCREAM_TAIL,
		MUNKIDORI,
		RADIANT_GRENINJA,
	]:
		if not names.has(name):
			names.append(name)
	return names


func get_state_encoder_class() -> GDScript:
	return _rules.call("get_state_encoder_class") if _rules != null and _rules.has_method("get_state_encoder_class") else null


func load_value_net(path: String) -> bool:
	return load_gardevoir_value_net(path)


func load_gardevoir_value_net(path: String) -> bool:
	if _rules == null or not _rules.has_method("load_gardevoir_value_net"):
		gardevoir_value_net = null
		return false
	var loaded := bool(_rules.call("load_gardevoir_value_net", path))
	gardevoir_value_net = _rules.call("get_value_net") if loaded and _rules.has_method("get_value_net") else null
	return loaded


func get_value_net() -> RefCounted:
	gardevoir_value_net = _rules.call("get_value_net") if _rules != null and _rules.has_method("get_value_net") else gardevoir_value_net
	return gardevoir_value_net


func has_gardevoir_value_net() -> bool:
	if _rules != null and _rules.has_method("has_gardevoir_value_net"):
		return bool(_rules.call("has_gardevoir_value_net"))
	return gardevoir_value_net != null and gardevoir_value_net.has_method("is_loaded") and bool(gardevoir_value_net.call("is_loaded"))


func get_mcts_config() -> Dictionary:
	return _rules.call("get_mcts_config") if _rules != null and _rules.has_method("get_mcts_config") else {}


func set_deck_strategy_text(text: String) -> void:
	_deck_strategy_text = text.strip_edges()
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


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	super.build_turn_plan(game_state, player_index, context)
	return _rules.call("build_turn_plan", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_plan") else {}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	return _rules.call("build_turn_contract", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_contract") else {}


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
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned: Array = super.pick_interaction_items(items, step, context)
		if not planned.is_empty():
			if _is_psychic_embrace_energy_step(step, context):
				var embrace_energy_plan := _protect_psychic_embrace_energy_picks(planned, items, step)
				if not embrace_energy_plan.is_empty():
					return embrace_energy_plan
				return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
			if _is_psychic_embrace_target_step(step, context):
				var embrace_target_plan := _protect_psychic_embrace_target_picks(planned, items, step, context)
				if not embrace_target_plan.is_empty():
					return embrace_target_plan
				return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
			if _is_gardevoir_item_search_step(step, context):
				var item_search_plan := _protect_gardevoir_item_search_picks(planned, items, step, context)
				if not item_search_plan.is_empty():
					return item_search_plan
			if _is_gardevoir_search_step(step, context):
				var search_plan := _protect_gardevoir_search_picks(planned, items, step, context)
				if not search_plan.is_empty():
					return search_plan
			var protected_plan := _protect_gardevoir_discard_picks(planned, items, step, context)
			if protected_plan.is_empty() and planned.size() > 0:
				var fallback := _gardevoir_discard_fallback_for_step(items, step, context)
				if not fallback.is_empty():
					return fallback
				return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []
			return protected_plan
		var fallback_item_search_plan := _protect_gardevoir_item_search_picks([], items, step, context)
		if not fallback_item_search_plan.is_empty():
			return fallback_item_search_plan
		var fallback_search_plan := _protect_gardevoir_search_picks([], items, step, context)
		if not fallback_search_plan.is_empty():
			return fallback_search_plan
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var player_index := int(context.get("player_index", -1))
		var planned_score := float(super.score_interaction_target(item, step, context))
		if _is_discard_step(step) and item is CardInstance:
			var discard_card: CardInstance = item as CardInstance
			if discard_card.card_data != null and _is_gardevoir_protected_discard_card(discard_card.card_data, game_state, player_index):
				return minf(planned_score, -1000.0)
		if planned_score != 0.0:
			if _is_psychic_embrace_energy_step(step, context) and item is CardInstance:
				return _score_psychic_embrace_energy_item(item as CardInstance)
			if _is_psychic_embrace_target_step(step, context) and item is PokemonSlot:
				var embrace_target_score := _score_gardevoir_embrace_target(item as PokemonSlot, step, context)
				if embrace_target_score <= -500.0:
					return embrace_target_score
				if embrace_target_score > 0.0:
					return maxf(planned_score, embrace_target_score) if planned_score > 0.0 else embrace_target_score
			if item is CardInstance:
				var item_search_score := _score_gardevoir_item_search_target(item as CardInstance, step, context)
				if item_search_score != 0.0:
					return item_search_score
				var search_score := _score_gardevoir_search_target(item as CardInstance, step, context)
				if search_score != 0.0:
					return search_score
			return planned_score
		if _is_psychic_embrace_energy_step(step, context) and item is CardInstance:
			return _score_psychic_embrace_energy_item(item as CardInstance)
		if _is_psychic_embrace_target_step(step, context) and item is PokemonSlot:
			var fallback_embrace_score := _score_gardevoir_embrace_target(item as PokemonSlot, step, context)
			if fallback_embrace_score != 0.0:
				return fallback_embrace_score
	if item is CardInstance:
		var fallback_item_search_score := _score_gardevoir_item_search_target(item as CardInstance, step, context)
		if fallback_item_search_score != 0.0:
			return fallback_item_search_score
		var fallback_search_score := _score_gardevoir_search_target(item as CardInstance, step, context)
		if fallback_search_score != 0.0:
			return fallback_search_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	var gardevoir_count := _count_field_name(player, GARDEVOIR_EX)
	var kirlia_count := _count_field_name(player, KIRLIA)
	snapshot["gardevoir_ex_count"] = gardevoir_count
	snapshot["kirlia_count"] = kirlia_count
	snapshot["ralts_count"] = _count_field_name(player, RALTS)
	snapshot["psychic_energy_discard_count"] = _count_psychic_energy_in_discard(player)
	snapshot["attacker_count"] = _count_attacker_bodies(player)
	snapshot["ready_attacker_count"] = _count_ready_attackers(player)
	snapshot["gardevoir_engine_online"] = gardevoir_count > 0
	snapshot["kirlia_draw_engine_online"] = kirlia_count > 0
	_last_gardevoir_engine_online = gardevoir_count > 0
	_last_gardevoir_attacker_count = int(snapshot.get("attacker_count", 0))
	_last_gardevoir_ready_attacker_count = int(snapshot.get("ready_attacker_count", 0))
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, RALTS):
		return "priority opener and bench seed: build two Ralts early for Kirlia and Gardevoir ex"
	if _name_contains(name, KIRLIA):
		return "Stage 1 draw engine and bridge to Gardevoir ex; protect it from discard"
	if _name_contains(name, GARDEVOIR_EX):
		return "Stage 2 Psychic Embrace engine; not an opening Basic, but the main setup payoff"
	if _name_contains(name, DRIFLOON):
		return "primary Psychic Embrace attacker; damage counters turn into large active KOs"
	if _name_contains(name, SCREAM_TAIL):
		return "bench-sniping attacker; choose when prize map favors a damaged or low-HP bench target"
	if _name_contains(name, MUNKIDORI):
		return "damage-transfer support after attackers take Psychic Embrace damage"
	if _name_contains(name, RADIANT_GRENINJA):
		return "draw and discard-fuel engine; useful when Psychic Energy must enter discard"
	if _name_contains(name, KLEFKI) or _name_contains(name, FLUTTER_MANE):
		return "control opener or pivot; useful early, but do not over-invest after the engine is online"
	if _name_contains(name, MANAPHY):
		return "bench protection tech; bench when opponent spread threatens Ralts/Kirlia"
	return "support"


func get_llm_deck_strategy_prompt(_game_state: GameState, _player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: Gardevoir ex is a Stage 2 setup deck. Build Ralts -> Kirlia -> Gardevoir ex, keep at least one Kirlia draw engine when possible, put Psychic Energy into discard, then use Psychic Embrace to power the correct attacker.")
	lines.append("Setup priority: early turns should establish two Ralts when legal. Buddy-Buddy Poffin, Nest Ball, Artazon, Ultra Ball, Arven, Rare Candy, and Technical Machine: Evolution should serve the Ralts/Kirlia/Gardevoir ex chain before bench padding.")
	lines.append("Kirlia policy: Kirlia is both the draw engine and the bridge to Gardevoir ex. Use Kirlia draw/discard when it improves the hand or puts Psychic Energy into discard, but avoid discarding the last Ralts, Kirlia, Gardevoir ex, Rare Candy, TM Evolution, or the search card that completes the current evolution route.")
	lines.append("Psychic Energy plan: Psychic Energy is usually better in discard than attached manually. Earthen Vessel, Kirlia, Radiant Greninja, Ultra Ball, and Secret Box can create Psychic Embrace fuel. Do not burn setup pieces just to discard energy if the engine is not protected.")
	lines.append("Psychic Embrace policy: use Gardevoir ex to attach Psychic Energy from discard to the attacker that gains a real attack or KO line. Prefer Drifloon or Scream Tail when extra damage counters improve prize math; do not over-damage a support Pokemon or an attacker that already has enough energy/damage.")
	lines.append("Attacker selection: Drifloon is the default high-damage active attacker, Scream Tail is for bench prize maps, Drifblim is a backup attacker, and Munkidori converts self-damage into pressure. Choose the attacker based on prizes, opponent HP thresholds, available Psychic Energy, and whether a gust/bench KO is available.")
	lines.append("Prize conversion priority: once Gardevoir ex is online or about to evolve, the next non-terminal actions should establish a real prize attacker. If no Drifloon/Scream Tail/Drifblim is on board, search, bench, or recover one before passive setup, extra Ralts, support Pokemon, or unsupported gust effects.")
	lines.append("Fast-prize survival: rules Miraidon can KO Klefki, Ralts, or Kirlia before the engine stabilizes. Do not spend early bench slots on Manaphy, Munkidori, Radiant Greninja, or other passive padding unless their threat is real; prioritize a second Ralts/Kirlia line and the first Drifloon or Scream Tail.")
	lines.append("Post-engine pressure: after Gardevoir ex is online, a 10-30 damage core/support attack or premature end_turn is usually losing. Convert the engine into Drifloon/Scream Tail pressure with search, recovery, Psychic Embrace, Bravery Charm, manual attach, or a legal pivot before attacking.")
	lines.append("Attack policy: attack is terminal. Before attacking, complete safe evolution, draw, discard-fuel, Psychic Embrace, tool, pivot, gust, or recovery actions that improve this turn's KO or next-turn continuity. If a KO is already guaranteed, stop optional churn and attack.")
	lines.append("Resource policy: preserve the last copy of Ralts, Kirlia, Gardevoir ex, Rare Candy, TM Evolution, Buddy-Buddy Poffin, Ultra Ball, Arven, Night Stretcher, and Super Rod unless spending it creates a concrete engine or prize route. Psychic Energy is preferred discard fuel; Darkness Energy is mainly for Munkidori or emergency attack/retreat needs.")
	lines.append("Targeting policy: prefer an active KO, a gusted bench KO with Boss's Orders or Counter Catcher, or Scream Tail bench cleanup when it changes the prize race. Do not gust a target without a KO, damage setup, or survival reason.")
	lines.append("Replan policy: after Kirlia, Radiant Greninja, Ultra Ball, Arven, Nest Ball, Poffin, Earthen Vessel, Secret Box, Night Stretcher, or Psychic Embrace changes hand, board, or discard, reassess using the updated legal_actions instead of blindly continuing an old route.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored Gardevoir strategy text follows; use it when it does not conflict with legal_actions, card rules, current board facts, or resource constraints:")
		lines.append(custom_text)
	lines.append("Execution boundary: exact action ids, legal actions, card rules, interaction_schema fields, HP, attached tools, energy, hand, discard, prizes, and opponent board come from the structured payload. Never invent ids, card effects, targets, or interaction keys.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "use_ability" and _ref_has_any_name(ref, [GARDEVOIR_EX, KIRLIA, RADIANT_GRENINJA, "Psychic Embrace", "Refinement", "Concealed Cards"]):
		return true
	if action_type == "evolve" and _ref_has_any_name(ref, [KIRLIA, GARDEVOIR_EX, DRIFBLIM]):
		return true
	if action_type == "attach_energy" and _ref_has_any_name(ref, [DRIFLOON, DRIFBLIM, SCREAM_TAIL, MUNKIDORI, PSYCHIC_ENERGY, DARKNESS_ENERGY]):
		return true
	if action_type == "play_trainer" and _ref_has_any_name(ref, [
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		EARTHEN_VESSEL,
		RARE_CANDY,
		TM_EVOLUTION,
		ARVEN,
		SECRET_BOX,
		NIGHT_STRETCHER,
		COUNTER_CATCHER,
		BOSSS_ORDERS,
	]):
		return true
	return false


func _deck_validate_action_interactions(_action_id: String, ref: Dictionary, interactions: Dictionary, path: String, errors: Array[String]) -> void:
	if str(ref.get("type", ref.get("kind", ""))) == "use_ability" and _ref_has_any_name(ref, [GARDEVOIR_EX, "Psychic Embrace"]):
		for bad_key: String in ["search_target", "search_targets", "discard_cards", "discard_card"]:
			if interactions.has(bad_key):
				errors.append("%s gives Gardevoir ex invalid interaction '%s'; use psychic_embrace_assignments, embrace_energy, and embrace_target" % [path, bad_key])
	if str(ref.get("type", ref.get("kind", ""))) == "play_trainer" and _ref_has_any_name(ref, [EARTHEN_VESSEL]):
		for key: String in interactions.keys():
			if key not in ["discard_cards", "discard_card", "search_energy", "search_target", "search_targets"]:
				errors.append("%s gives Earthen Vessel unsupported interaction '%s'" % [path, key])


func _apply_deck_specific_llm_repairs(tree: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if tree.is_empty():
		return tree
	var repair: Dictionary = _repair_gardevoir_strategy_node(tree, game_state, player_index)
	return repair.get("node", tree)


func _repair_gardevoir_strategy_node(node: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result := node.duplicate(true)
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if result.has(key):
			var action_repair: Dictionary = _repair_gardevoir_strategy_action_array(result.get(key, []), game_state, player_index)
			result[key] = action_repair.get("actions", result.get(key, []))
	for branch_key: String in ["branches", "options"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				var branch_action_repair: Dictionary = _repair_gardevoir_strategy_action_array(branch.get("actions", []), game_state, player_index)
				branch["actions"] = branch_action_repair.get("actions", branch.get("actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				branch["then"] = _repair_gardevoir_strategy_node(then_node as Dictionary, game_state, player_index).get("node", then_node)
			if branch.has("fallback_actions"):
				var fallback_repair: Dictionary = _repair_gardevoir_strategy_action_array(branch.get("fallback_actions", []), game_state, player_index)
				branch["fallback_actions"] = fallback_repair.get("actions", branch.get("fallback_actions", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return {"node": result}


func _repair_gardevoir_strategy_action_array(raw_actions: Variant, game_state: GameState, player_index: int) -> Dictionary:
	if not (raw_actions is Array):
		return {"actions": []}
	var source_actions: Array[Dictionary] = []
	var has_attack := false
	var removed_low_value_attack := false
	for raw_action: Variant in raw_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = (raw_action as Dictionary).duplicate(true)
		if _is_low_value_gardevoir_attack_ref(action, game_state, player_index):
			removed_low_value_attack = true
			continue
		if _is_attack_action_ref(action):
			has_attack = true
		source_actions.append(action)
	var pruned_actions: Array[Dictionary] = []
	for action: Dictionary in source_actions:
		if _is_gardevoir_gust_ref(action) and not has_attack:
			continue
		pruned_actions.append(action)
	if removed_low_value_attack:
		var setup_repair := _gardevoir_setup_replacements_for_low_attack(pruned_actions, game_state, player_index)
		if not setup_repair.is_empty():
			pruned_actions = setup_repair
	var conversion_candidates := _gardevoir_conversion_candidates_for_route(pruned_actions, game_state, player_index)
	if conversion_candidates.is_empty():
		return {"actions": pruned_actions}
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in pruned_actions:
		if not inserted and (_is_attack_action_ref(action) or _is_end_turn_action_ref(action)):
			result.append_array(conversion_candidates)
			inserted = true
		result.append(action)
	if not inserted:
		result.append_array(conversion_candidates)
	return {"actions": result}


func _is_low_value_gardevoir_attack_ref(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if _ref_has_any_name(action, [TM_EVOLUTION, "Evolution"]):
		return false
	return _deck_is_low_value_runtime_attack_action(action, game_state, player_index) and _has_visible_gardevoir_setup(game_state, player_index)


func _gardevoir_setup_replacements_for_low_attack(existing_actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return existing_actions
	var seen_ids: Dictionary = {}
	for action: Dictionary in existing_actions:
		var action_id := str(action.get("action_id", action.get("id", "")))
		if action_id != "":
			seen_ids[action_id] = true
	var candidates: Array[Dictionary] = []
	_append_gardevoir_setup_catalog(candidates, seen_ids, false, false)
	if candidates.is_empty():
		return existing_actions
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in existing_actions:
		if not inserted and _is_end_turn_action_ref(action):
			result.append_array(candidates.slice(0, MAX_CONVERSION_REPAIR_ACTIONS))
			inserted = true
		result.append(action)
	if not inserted:
		result.append_array(candidates.slice(0, MAX_CONVERSION_REPAIR_ACTIONS))
	return result


func _gardevoir_conversion_candidates_for_route(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if not _should_repair_gardevoir_attacker_conversion(actions, game_state, player_index):
		return []
	var seen_ids: Dictionary = {}
	for action: Dictionary in actions:
		var action_id := str(action.get("action_id", action.get("id", "")))
		if action_id != "":
			seen_ids[action_id] = true
	var candidates: Array[Dictionary] = []
	var local_seen := seen_ids.duplicate(true)
	var player: PlayerState = game_state.players[player_index]
	if _count_attacker_bodies(player) > 0 and _count_ready_attackers(player) == 0:
		_append_gardevoir_attacker_charge_catalog(candidates, local_seen)
	else:
		_append_gardevoir_prize_conversion_catalog(candidates, local_seen)
	var result: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if result.size() >= MAX_CONVERSION_REPAIR_ACTIONS:
			break
		var candidate_id := str(candidate.get("action_id", candidate.get("id", "")))
		if candidate_id == "" or bool(seen_ids.get(candidate_id, false)):
			continue
		if _candidate_conflicts_with_route(candidate, actions):
			continue
		result.append(candidate)
	return result


func _should_repair_gardevoir_attacker_conversion(actions: Array[Dictionary], game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if _gardevoir_route_has_attacker_conversion(actions):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_ready_attackers(player) > 0:
		return false
	var engine_online := _count_field_name(player, GARDEVOIR_EX) > 0 or _gardevoir_route_has_engine_conversion(actions)
	if not engine_online:
		return false
	if _count_attacker_bodies(player) == 0:
		return true
	return _count_psychic_energy_in_discard(player) > 0 or _gardevoir_route_has_engine_conversion(actions)


func _gardevoir_route_has_attacker_conversion(actions: Array[Dictionary]) -> bool:
	for action: Dictionary in actions:
		if _ref_has_any_name(action, [DRIFLOON, DRIFBLIM, SCREAM_TAIL, NIGHT_STRETCHER]):
			return true
	return false


func _gardevoir_route_has_engine_conversion(actions: Array[Dictionary]) -> bool:
	for action: Dictionary in actions:
		if _ref_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]):
			return true
	return _last_gardevoir_engine_online and _last_gardevoir_attacker_count == 0


func _deck_is_low_value_runtime_attack_action(_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or active.get_card_data() == null:
		return false
	var name := _slot_best_name(active)
	if _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
		return _is_low_value_gardevoir_attacker_attack(_action, active, game_state, player_index)
	return int(predict_attacker_damage(active).get("damage", 0)) < 120 and _name_matches_any(name, GARDEVOIR_CORE_NAMES + GARDEVOIR_SUPPORT_NAMES)


func _is_low_value_gardevoir_attacker_attack(action: Dictionary, active: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	var attack_index := int(action.get("attack_index", -1))
	if attack_index != 0:
		return false
	if active == null or active.get_card_data() == null:
		return false
	var attacks: Array = active.get_card_data().attacks
	if attacks.size() < 2:
		return false
	var stronger_attack: Dictionary = attacks[1] if attacks[1] is Dictionary else {}
	if stronger_attack.is_empty():
		return false
	var attached_count := active.attached_energy.size()
	var required_count := str(stronger_attack.get("cost", "")).length()
	if attached_count >= required_count:
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return _count_field_name(player, GARDEVOIR_EX) > 0 and _count_psychic_energy_in_discard(player) > 0


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_gardevoir_setup_or_resource_card(card_data)


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) not in ["attack", "granted_attack"]:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return false
	return int(predict_attacker_damage(active).get("damage", 0)) >= 120


func _deck_estimate_multiplier_attack_damage(_action: Dictionary, game_state: GameState, player_index: int, _base_damage: int, lower_text: String) -> int:
	if not (lower_text.contains("damage counter") or lower_text.contains("counter") or lower_text.contains("psychic embrace")):
		return 0
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null:
		return 0
	return int(predict_attacker_damage(active).get("damage", 0))


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_gardevoir_setup(game_state, player_index)


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_gardevoir_runtime_setup_action(action, game_state, player_index)


func _deck_should_block_exact_queue_match(_queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(runtime_action.get("kind", runtime_action.get("type", "")))
	if kind in ["attack", "granted_attack"]:
		return _deck_is_low_value_runtime_attack_action(runtime_action, game_state, player_index) and _has_visible_gardevoir_setup(game_state, player_index)
	if kind == "use_ability":
		return _is_bad_gardevoir_deck_draw_ability(runtime_action, game_state, player_index)
	if kind == "play_basic_to_bench":
		return _is_bad_gardevoir_support_bench(runtime_action, game_state, player_index)
	if kind == "attach_energy":
		return _is_bad_gardevoir_manual_attach(runtime_action, game_state, player_index)
	if kind == "play_trainer" and _is_dead_gardevoir_gust_action(runtime_action):
		return true
	if kind == "attach_tool":
		return _is_bad_gardevoir_tool_attach(runtime_action, game_state, player_index)
	if kind == "retreat":
		return _is_bad_gardevoir_retreat(runtime_action, game_state, player_index)
	return false


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_gardevoir_setup_catalog(target, seen_ids, false, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	if _last_gardevoir_engine_online and _last_gardevoir_attacker_count > 0 and _last_gardevoir_ready_attacker_count == 0:
		_append_gardevoir_attacker_charge_catalog(target, seen_ids)
	elif _gardevoir_route_has_engine_conversion(_actions):
		if _last_gardevoir_attacker_count > 0 and _last_gardevoir_ready_attacker_count == 0:
			_append_gardevoir_attacker_charge_catalog(target, seen_ids)
		else:
			_append_gardevoir_prize_conversion_catalog(target, seen_ids)
	_append_gardevoir_setup_catalog(target, seen_ids, has_attack, _no_deck_draw_lock)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_gardevoir_setup_or_resource_card(card_data)


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _append_gardevoir_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool, no_deck_draw_lock: bool = false) -> void:
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [RALTS])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [BUDDY_BUDDY_POFFIN], _core_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NEST_BALL], _core_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ARTAZON])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ULTRA_BALL], _core_ultra_ball_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ARVEN])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [RARE_CANDY])
	_append_gardevoir_catalog_match(target, seen_ids, "evolve", [KIRLIA])
	_append_gardevoir_catalog_match(target, seen_ids, "evolve", [GARDEVOIR_EX])
	_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [TM_EVOLUTION])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [EARTHEN_VESSEL], _earthen_vessel_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [SECRET_BOX])
	if not no_deck_draw_lock:
		_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [KIRLIA])
		_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [RADIANT_GRENINJA])
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_interactions())
	if not has_attack:
		_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [DRIFLOON])
		_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [SCREAM_TAIL])
		_append_gardevoir_catalog_match(target, seen_ids, "attach_energy", [DRIFLOON, SCREAM_TAIL, PSYCHIC_ENERGY])
		_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NIGHT_STRETCHER])
		_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [BRAVERY_CHARM])


func _append_gardevoir_prize_conversion_catalog(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [DRIFLOON])
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [SCREAM_TAIL])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NIGHT_STRETCHER], _attacker_recovery_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [BUDDY_BUDDY_POFFIN], _attacker_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NEST_BALL], _attacker_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ULTRA_BALL], _attacker_ultra_ball_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [BRAVERY_CHARM])


func _append_gardevoir_attacker_charge_catalog(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "attach_energy", [DRIFLOON, SCREAM_TAIL, PSYCHIC_ENERGY])
	_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [BRAVERY_CHARM])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NIGHT_STRETCHER], _attacker_recovery_interactions())


func _append_gardevoir_catalog_match(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	action_type: String,
	queries: Array[String],
	interactions: Dictionary = {}
) -> void:
	if target.size() >= 8:
		return
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id := str(raw_key)
		if action_id == "" or bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or str(ref.get("type", ref.get("kind", ""))) != action_type:
			continue
		if not queries.is_empty() and not _ref_has_any_name(ref, queries):
			continue
		var copy := ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		if not interactions.is_empty():
			copy["interactions"] = interactions.duplicate(true)
		target.append(copy)
		seen_ids[action_id] = true
		return


func _psychic_embrace_interactions() -> Dictionary:
	return {
		"psychic_embrace_assignments": {"prefer": [PSYCHIC_ENERGY, DRIFLOON, SCREAM_TAIL]},
	}


func _earthen_vessel_interactions() -> Dictionary:
	return {
		"discard_cards": {"prefer": [PSYCHIC_ENERGY, DARKNESS_ENERGY]},
		"search_energy": {"prefer": [PSYCHIC_ENERGY, DARKNESS_ENERGY]},
	}


func _core_basic_search_interactions() -> Dictionary:
	return {
		"search_targets": {"prefer": [RALTS, DRIFLOON, SCREAM_TAIL]},
	}


func _core_ultra_ball_interactions() -> Dictionary:
	return {
		"discard_cards": {"prefer": [PSYCHIC_ENERGY, DARKNESS_ENERGY]},
		"search_targets": {"prefer": [GARDEVOIR_EX, KIRLIA, RALTS, DRIFLOON, SCREAM_TAIL]},
	}


func _attacker_basic_search_interactions() -> Dictionary:
	return {
		"search_targets": {"prefer": [DRIFLOON, SCREAM_TAIL, RALTS]},
	}


func _attacker_ultra_ball_interactions() -> Dictionary:
	return {
		"discard_cards": {"prefer": [PSYCHIC_ENERGY, DARKNESS_ENERGY]},
		"search_targets": {"prefer": [DRIFLOON, SCREAM_TAIL, DRIFBLIM]},
	}


func _attacker_recovery_interactions() -> Dictionary:
	return {
		"recover_target": {"prefer": [DRIFLOON, SCREAM_TAIL, PSYCHIC_ENERGY]},
	}


func _is_gardevoir_search_step(step: Dictionary, _context: Dictionary = {}) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id in [
		"search_target",
		"search_targets",
		"search_pokemon",
		"search_cards",
		"basic_pokemon",
		"buddy_poffin_pokemon",
		"bench_pokemon",
		"pokemon_card",
	]


func _is_gardevoir_item_search_step(step: Dictionary, _context: Dictionary = {}) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id in ["search_item", "search_items", "item_card", "item_cards"]


func _protect_gardevoir_item_search_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_gardevoir_item_search_step(step, context) or not _gardevoir_tm_evolution_bridge_needs_vessel(context):
		return planned
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	if max_select <= 0:
		max_select = 1
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance):
			continue
		var score := _score_gardevoir_item_search_target(item as CardInstance, step, context)
		if score <= 0.0:
			continue
		ranked.append({"item": item, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var result: Array = []
	for entry: Dictionary in ranked:
		if result.size() >= max_select:
			break
		var picked: Variant = entry.get("item", null)
		if picked != null and not result.has(picked):
			result.append(picked)
	return result if not result.is_empty() else planned


func _score_gardevoir_item_search_target(item: CardInstance, step: Dictionary, context: Dictionary) -> float:
	if item == null or item.card_data == null or not _is_gardevoir_item_search_step(step, context):
		return 0.0
	if not _gardevoir_tm_evolution_bridge_needs_vessel(context):
		return 0.0
	var name := _best_card_name(item.card_data)
	if _name_contains(name, EARTHEN_VESSEL):
		return 125000.0
	if _name_contains(name, ULTRA_BALL):
		return 250.0
	if _name_contains(name, BUDDY_BUDDY_POFFIN) or _name_contains(name, NEST_BALL):
		return 200.0
	if _name_contains(name, SECRET_BOX):
		return 150.0
	return 0.0


func _protect_gardevoir_search_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_gardevoir_search_step(step, context) or not _gardevoir_search_override_active(context):
		return planned
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	if max_select <= 0:
		max_select = 1
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance):
			continue
		var score := _score_gardevoir_search_target(item as CardInstance, step, context)
		if score <= 0.0:
			continue
		ranked.append({"item": item, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var result: Array = []
	for entry: Dictionary in ranked:
		if result.size() >= max_select:
			break
		var picked: Variant = entry.get("item", null)
		if picked != null and not result.has(picked):
			result.append(picked)
	return result if not result.is_empty() else planned


func _score_gardevoir_search_target(item: CardInstance, step: Dictionary, context: Dictionary) -> float:
	if item == null or item.card_data == null or not _is_gardevoir_search_step(step, context):
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return 0.0
	var name := _best_card_name(item.card_data)
	var engine_online := _count_field_name(player, GARDEVOIR_EX) > 0
	if engine_online and _count_attacker_bodies(player) == 0:
		if _name_contains(name, DRIFLOON):
			return 110000.0
		if _name_contains(name, SCREAM_TAIL):
			return 106000.0
		if _name_contains(name, DRIFBLIM):
			return 90000.0
		if _name_matches_any(name, GARDEVOIR_CORE_NAMES):
			return 1000.0
		if _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
			return -500.0
	if not engine_online and _count_field_name(player, KIRLIA) > 0:
		if _name_contains(name, GARDEVOIR_EX):
			return 118000.0
		if _name_contains(name, KIRLIA):
			return 70000.0
		if _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
			return 45000.0
		if _name_contains(name, RALTS):
			return 1000.0
		if _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
			return -500.0
	if _gardevoir_needs_core_redundancy(player):
		if _name_contains(name, RALTS):
			return 100000.0
		if _name_contains(name, KIRLIA):
			return 92000.0
		if _name_contains(name, GARDEVOIR_EX):
			return 85000.0 if _count_field_name(player, KIRLIA) > 0 else 50000.0
		if _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
			return 35000.0
		if _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
			return -500.0
	return 0.0


func _gardevoir_search_override_active(context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) == 0:
		return true
	if _count_field_name(player, GARDEVOIR_EX) == 0 and _count_field_name(player, KIRLIA) > 0:
		return true
	return _gardevoir_needs_core_redundancy(player)


func _gardevoir_tm_evolution_bridge_needs_vessel(context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if bool(game_state.energy_attached_this_turn):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if player.active_pokemon.attached_energy.size() > 0:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [RALTS, KLEFKI, FLUTTER_MANE, MUNKIDORI]):
		return false
	if not _gardevoir_has_tm_evolution_access(player):
		return false
	return _gardevoir_has_tm_evolution_bench_target(player)


func _gardevoir_has_tm_evolution_access(player: PlayerState) -> bool:
	if player == null:
		return false
	if _gardevoir_current_queue_has_tm_evolution_route():
		return true
	if _gardevoir_player_has_card_name(player, TM_EVOLUTION):
		return true
	for slot: PokemonSlot in _all_player_slots(player):
		if slot != null and slot.attached_tool != null and slot.attached_tool.card_data != null:
			if _name_contains(_best_card_name(slot.attached_tool.card_data), TM_EVOLUTION):
				return true
	return false


func _gardevoir_has_tm_evolution_bench_target(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(slot, [RALTS]):
			return true
	return false


func _gardevoir_hand_has_psychic_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type_matches("Psychic", str(card.card_data.energy_provides)):
			return true
	return false


func _gardevoir_player_has_card_name(player: PlayerState, query: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			return true
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			return true
	return false


func _is_psychic_embrace_energy_step(step: Dictionary, context: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id == "embrace_energy" or (step_id in ["energy_card", "energy_card_id", "selected_energy_card_id"] and _pending_effect_is_psychic_embrace(context))


func _is_psychic_embrace_target_step(step: Dictionary, context: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id == "embrace_target" or (step_id in ["target_pokemon", "own_bench_target", "target"] and _pending_effect_is_psychic_embrace(context))


func _pending_effect_is_psychic_embrace(context: Dictionary) -> bool:
	var pending_card: Variant = context.get("pending_effect_card", null)
	if pending_card is CardInstance and (pending_card as CardInstance).card_data != null:
		var cd: CardData = (pending_card as CardInstance).card_data
		var text := "%s %s" % [str(cd.name_en), str(cd.name)]
		if _name_contains(text, GARDEVOIR_EX):
			return true
		for ability: Dictionary in cd.abilities:
			if _name_contains(str(ability.get("name", "")), "Psychic Embrace") or _name_contains(str(ability.get("text", "")), "Psychic Embrace"):
				return true
	return _name_contains(str(context.get("pending_effect_ability", "")), "Psychic Embrace")


func _protect_psychic_embrace_energy_picks(planned: Array, items: Array, step: Dictionary) -> Array:
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	var result: Array = []
	for item: Variant in planned:
		if _is_psychic_energy_item(item):
			result.append(item)
			if result.size() >= max_select:
				return result
	for item: Variant in items:
		if _is_psychic_energy_item(item) and not result.has(item):
			result.append(item)
			if result.size() >= max_select:
				break
	return result


func _protect_psychic_embrace_target_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	var result: Array = []
	for item: Variant in planned:
		if item is PokemonSlot and _score_gardevoir_embrace_target(item as PokemonSlot, step, context) > 0.0:
			result.append(item)
			if result.size() >= max_select:
				return result
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is PokemonSlot):
			continue
		var score := _score_gardevoir_embrace_target(item as PokemonSlot, step, context)
		if score <= 0.0:
			continue
		ranked.append({"item": item, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	for entry: Dictionary in ranked:
		if result.size() >= max_select:
			break
		var picked: Variant = entry.get("item", null)
		if picked != null and not result.has(picked):
			result.append(picked)
	return result


func _score_psychic_embrace_energy_item(card: CardInstance) -> float:
	if _is_psychic_energy_item(card):
		return 100000.0
	if card != null and card.card_data != null and card.card_data.is_energy():
		return -1000.0
	return 0.0


func _is_psychic_energy_item(item: Variant) -> bool:
	if not (item is CardInstance):
		return false
	var card: CardInstance = item as CardInstance
	return card.card_data != null and card.card_data.is_energy() and _energy_type_matches("Psychic", str(card.card_data.energy_provides))


func _score_gardevoir_embrace_target(slot: PokemonSlot, _step: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if slot == null or slot.get_card_data() == null or slot.get_remaining_hp() <= 0:
		return -1000.0
	if slot.get_remaining_hp() <= 20:
		return -1000.0
	var player: PlayerState = null
	var opponent_active: PokemonSlot = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
		var opponent_index := 1 - player_index
		if opponent_index >= 0 and opponent_index < game_state.players.size():
			opponent_active = game_state.players[opponent_index].active_pokemon
	if player != null and not (slot in player.get_all_pokemon()):
		return -1000.0
	var name := _slot_best_name(slot)
	if _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
		var gap_now := _gardevoir_min_attack_cost_gap(slot, 0)
		var gap_after := _gardevoir_min_attack_cost_gap(slot, 1)
		var damage_after := _gardevoir_embrace_damage_estimate(slot, 1)
		var score := 72000.0 + float(mini(damage_after, 500))
		if gap_after <= 0:
			score += 15000.0
		if gap_now > 0 and gap_after <= 0:
			score += 10000.0
		if player != null and slot == player.active_pokemon:
			score += 5000.0
		if opponent_active != null and damage_after >= opponent_active.get_remaining_hp():
			score += 15000.0
		return score
	if player != null and slot == player.active_pokemon and _gardevoir_active_embrace_retreat_bridge_live(player):
		return 68000.0
	if player != null and _count_field_name(player, GARDEVOIR_EX) > 0:
		return -1000.0
	return -200.0


func _gardevoir_active_embrace_retreat_bridge_live(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _name_matches_any(_slot_best_name(player.active_pokemon), GARDEVOIR_ATTACKER_NAMES):
		return false
	return _gardevoir_retreat_energy_gap(player.active_pokemon) == 1 and _has_ready_bench_gardevoir_attacker(player)


func _gardevoir_retreat_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


func _protect_gardevoir_discard_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_discard_step(step):
		return planned
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var filtered: Array = []
	for item: Variant in planned:
		if item is CardInstance and (item as CardInstance).card_data != null:
			if _is_gardevoir_protected_discard_card((item as CardInstance).card_data, game_state, player_index):
				continue
		filtered.append(item)
	if filtered.size() == planned.size():
		return planned
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	var required_count := mini(max_select, planned.size())
	if filtered.size() < required_count:
		return _best_gardevoir_discard_fallback(items, step, game_state, player_index)
	if filtered.size() > max_select:
		return filtered.slice(0, max_select)
	return filtered


func _gardevoir_discard_fallback_for_step(items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_discard_step(step):
		return []
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	return _best_gardevoir_discard_fallback(items, step, game_state, player_index)


func _best_gardevoir_discard_fallback(items: Array, step: Dictionary, game_state: GameState, player_index: int) -> Array:
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0:
		max_select = items.size()
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance) or (item as CardInstance).card_data == null:
			continue
		var card := item as CardInstance
		if _is_gardevoir_protected_discard_card(card.card_data, game_state, player_index):
			continue
		ranked.append({
			"card": item,
			"score": get_discard_priority_contextual(card, game_state, player_index),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	var result: Array = []
	for entry: Dictionary in ranked:
		if result.size() >= max_select:
			break
		result.append(entry.get("card"))
	return result


func _is_gardevoir_protected_discard_card(card_data: CardData, game_state: GameState, player_index: int) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	if _name_matches_any(name, GARDEVOIR_CORE_NAMES):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var engine_online := _count_field_name(player, GARDEVOIR_EX) > 0
	if not engine_online and _name_matches_any(name, [
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		ARVEN,
		RARE_CANDY,
		TM_EVOLUTION,
		SECRET_BOX,
	]):
		return true
	if card_data.is_energy() \
		and _energy_type_matches("Psychic", str(card_data.energy_provides)) \
		and _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state, player_index):
		return true
	if engine_online and _count_attacker_bodies(player) == 0 and _name_matches_any(name, [DRIFLOON, SCREAM_TAIL, NIGHT_STRETCHER]):
		return true
	return false


func _is_discard_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", ""))
	return step_id in ["discard_card", "discard_cards", "discard_energy", "discard_basic_energy"]


func _has_visible_gardevoir_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _count_ready_attackers(player) > 0:
		if _active_is_ready_gardevoir_attacker(player):
			return false
		return _catalog_has_gardevoir_handoff_action()
	if _catalog_has_gardevoir_setup_action():
		return true
	for card: CardInstance in player.hand:
		if card != null and _is_gardevoir_setup_or_resource_card(card.card_data):
			return true
	return false


func _catalog_has_gardevoir_handoff_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type == "retreat":
			return true
		if action_type in ["play_trainer", "play_stadium"] and _ref_has_any_name(ref, ["Switch", "Switch Cart", "Escape Rope", "Prime Catcher"]):
			return true
	return false


func _catalog_has_gardevoir_setup_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type in ["end_turn", "attack", "granted_attack", "route"]:
			continue
		if action_type in ["play_basic_to_bench", "evolve", "attach_tool", "retreat"]:
			return true
		if action_type == "attach_energy" and _ref_has_any_name(ref, [DRIFLOON, SCREAM_TAIL, MUNKIDORI]):
			return true
		if action_type == "use_ability" and _ref_has_any_name(ref, [KIRLIA, RADIANT_GRENINJA, GARDEVOIR_EX]):
			return true
		if action_type in ["play_trainer", "play_stadium"] and _ref_has_any_name(ref, [
			BUDDY_BUDDY_POFFIN,
			NEST_BALL,
			ULTRA_BALL,
			EARTHEN_VESSEL,
			RARE_CANDY,
			TM_EVOLUTION,
			ARVEN,
			ARTAZON,
			SECRET_BOX,
			NIGHT_STRETCHER,
			SUPER_ROD,
			BRAVERY_CHARM,
			COUNTER_CATCHER,
			BOSSS_ORDERS,
		]):
			return true
	return false


func _is_gardevoir_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["play_basic_to_bench", "evolve", "use_ability", "attach_tool"]:
		return not _deck_should_block_exact_queue_match({}, action, game_state, player_index)
	if kind == "attach_energy":
		if _is_bad_gardevoir_manual_attach(action, game_state, player_index):
			return false
		return _runtime_action_has_any_name(action, [DRIFLOON, SCREAM_TAIL, MUNKIDORI])
	if kind == "retreat":
		return not _is_bad_gardevoir_retreat(action, game_state, player_index)
	if kind in ["play_trainer", "play_stadium"]:
		if _is_dead_gardevoir_gust_action(action):
			return false
		return _runtime_action_has_any_name(action, [
			BUDDY_BUDDY_POFFIN,
			NEST_BALL,
			ULTRA_BALL,
			EARTHEN_VESSEL,
			RARE_CANDY,
			TM_EVOLUTION,
			ARVEN,
			ARTAZON,
			SECRET_BOX,
			NIGHT_STRETCHER,
			SUPER_ROD,
			COUNTER_CATCHER,
			BOSSS_ORDERS,
		])
	return false


func _is_bad_gardevoir_tool_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null:
		return false
	var tool_name := _best_card_name(card.card_data)
	if _name_contains(tool_name, TM_EVOLUTION) and _runtime_action_targets_known_non_active(action, game_state, player_index):
		return true
	var target_name := _runtime_action_target_name(action, "target")
	if target_name == "":
		return false
	if _name_contains(tool_name, TM_EVOLUTION):
		return not _name_matches_any(target_name, [KLEFKI, FLUTTER_MANE, MUNKIDORI, DRIFLOON, SCREAM_TAIL, RALTS])
	if _name_contains(tool_name, BRAVERY_CHARM):
		return not _name_matches_any(target_name, GARDEVOIR_ATTACKER_NAMES)
	return false


func _is_dead_gardevoir_gust_action(action: Dictionary) -> bool:
	if not _runtime_action_has_any_name(action, [COUNTER_CATCHER, BOSSS_ORDERS]):
		return false
	return not _gardevoir_current_queue_has_attack_terminal()


func _is_gardevoir_gust_ref(ref: Dictionary) -> bool:
	return _ref_has_any_name(ref, [COUNTER_CATCHER, BOSSS_ORDERS])


func _is_bad_gardevoir_manual_attach(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> bool:
	var card: CardInstance = action.get("card", null)
	if card == null or card.card_data == null or not card.card_data.is_energy():
		return false
	var target_name := _runtime_action_target_name(action, "target")
	if target_name == "":
		return false
	var low_value_targets: Array[String] = []
	low_value_targets.append_array(GARDEVOIR_CORE_NAMES)
	low_value_targets.append_array([MANAPHY, RADIANT_GRENINJA, KLEFKI])
	if not _name_matches_any(target_name, low_value_targets):
		return false
	if _runtime_action_targets_known_non_active(action, game_state, player_index):
		return true
	if _runtime_action_target_has_tool_name(action, "target", TM_EVOLUTION):
		return false
	return not _gardevoir_current_queue_has_tm_evolution_route()


func _is_bad_gardevoir_retreat(action: Dictionary, _game_state: GameState, _player_index: int) -> bool:
	var bench_target: PokemonSlot = action.get("bench_target", null)
	if bench_target == null:
		return false
	var bad_targets: Array[String] = []
	bad_targets.append_array(GARDEVOIR_CORE_NAMES)
	bad_targets.append_array([MANAPHY, RADIANT_GRENINJA, KLEFKI])
	if _slot_name_matches_any(bench_target, bad_targets):
		return true
	return false


func _is_bad_gardevoir_deck_draw_ability(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.deck.size() > 12:
		return false
	if not _runtime_action_has_any_name(action, [KIRLIA, RADIANT_GRENINJA, "Refinement", "Concealed Cards"]):
		return false
	return not _runtime_action_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"])


func _is_bad_gardevoir_support_bench(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var name := _runtime_action_card_name(action)
	if not _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
		return false
	if _name_contains(name, MANAPHY) and _opponent_has_bench_spread_pressure(game_state, player_index):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _gardevoir_needs_core_redundancy(player):
		return true
	return _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) == 0


func _gardevoir_needs_core_redundancy(player: PlayerState) -> bool:
	if player == null:
		return false
	var core_seed_count := _count_field_name(player, RALTS) + _count_field_name(player, KIRLIA)
	if core_seed_count < 2:
		return true
	return _count_field_name(player, GARDEVOIR_EX) == 0 and _count_field_name(player, KIRLIA) == 0


func _opponent_has_bench_spread_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_player_slots(opponent):
		if slot == null or slot.get_card_data() == null:
			continue
		var cd: CardData = slot.get_card_data()
		for attack: Dictionary in cd.attacks:
			var text := "%s %s" % [str(attack.get("name", "")), str(attack.get("text", attack.get("description", "")))]
			var lower := text.to_lower()
			if lower.contains("bench") or lower.contains("damage counter") or lower.contains("damage to 2") or lower.contains("all of your opponent"):
				return true
	return false


func _is_gardevoir_setup_or_resource_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if card_data.is_energy():
		return _energy_type_matches("Psychic", str(card_data.energy_provides)) or _energy_type_matches("Dark", str(card_data.energy_provides))
	var name := _best_card_name(card_data)
	for query: String in [
		RALTS,
		KIRLIA,
		GARDEVOIR_EX,
		DRIFLOON,
		DRIFBLIM,
		SCREAM_TAIL,
		MUNKIDORI,
		RADIANT_GRENINJA,
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		EARTHEN_VESSEL,
		RARE_CANDY,
		TM_EVOLUTION,
		ARVEN,
		ARTAZON,
		SECRET_BOX,
		NIGHT_STRETCHER,
		SUPER_ROD,
		BRAVERY_CHARM,
		COUNTER_CATCHER,
		BOSSS_ORDERS,
	]:
		if _name_contains(name, query):
			return true
	return false


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("attack_name", "")),
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
			parts.append(str(rules.get("effect_id", "")))
	var combined := " ".join(parts)
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _runtime_action_has_any_name(action: Dictionary, queries: Array[String]) -> bool:
	var parts: Array[String] = [
		str(action.get("card", "")),
		str(action.get("pokemon", "")),
		_runtime_action_target_name(action, "target"),
		_runtime_action_target_name(action, "bench_target"),
		str(action.get("summary", "")),
		str(action.get("id", action.get("action_id", ""))),
	]
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		parts.append(str((card as CardInstance).card_data.name))
		parts.append(str((card as CardInstance).card_data.name_en))
	var target_slot: Variant = action.get("target_slot")
	if target_slot is PokemonSlot:
		parts.append(_slot_best_name(target_slot as PokemonSlot))
	var source_slot: Variant = action.get("source_slot")
	if source_slot is PokemonSlot:
		parts.append(_slot_best_name(source_slot as PokemonSlot))
	var combined := " ".join(parts)
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _runtime_action_card_name(action: Dictionary) -> String:
	var card: Variant = action.get("card", null)
	if card is CardInstance and (card as CardInstance).card_data != null:
		return _best_card_name((card as CardInstance).card_data)
	if card is CardData:
		return _best_card_name(card as CardData)
	if card is Dictionary:
		var card_dict: Dictionary = card
		var name_en := str(card_dict.get("name_en", ""))
		if name_en != "":
			return name_en
		return str(card_dict.get("name", ""))
	var card_name := str(card)
	if card_name != "":
		return card_name
	var pokemon: Variant = action.get("pokemon", "")
	if pokemon is CardInstance and (pokemon as CardInstance).card_data != null:
		return _best_card_name((pokemon as CardInstance).card_data)
	if pokemon is CardData:
		return _best_card_name(pokemon as CardData)
	if pokemon is Dictionary:
		var pokemon_dict: Dictionary = pokemon
		var pokemon_name_en := str(pokemon_dict.get("name_en", ""))
		if pokemon_name_en != "":
			return pokemon_name_en
		return str(pokemon_dict.get("name", ""))
	return str(pokemon)


func _runtime_action_target_name(action: Dictionary, key: String) -> String:
	var slot_key := "target_slot" if key == "target" else key
	var slot_value: Variant = action.get(slot_key, null)
	if slot_value is PokemonSlot:
		return _slot_best_name(slot_value as PokemonSlot)
	var raw_target: Variant = action.get(key, null)
	if raw_target is PokemonSlot:
		return _slot_best_name(raw_target as PokemonSlot)
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		var name_en := str(target_dict.get("name_en", ""))
		if name_en != "":
			return name_en
		return str(target_dict.get("name", ""))
	return str(raw_target)


func _runtime_action_target_has_tool_name(action: Dictionary, key: String, query: String) -> bool:
	var slot_key := "target_slot" if key == "target" else key
	var slot_value: Variant = action.get(slot_key, null)
	if slot_value is PokemonSlot:
		var slot := slot_value as PokemonSlot
		return slot.attached_tool != null and slot.attached_tool.card_data != null and _name_contains(_best_card_name(slot.attached_tool.card_data), query)
	var raw_target: Variant = action.get(key, null)
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		var raw_tool: Variant = target_dict.get("tool", target_dict.get("attached_tool", {}))
		if raw_tool is Dictionary:
			var tool_dict: Dictionary = raw_tool
			return _name_contains(str(tool_dict.get("name_en", tool_dict.get("name", ""))), query)
		return _name_contains(str(raw_tool), query)
	return false


func _runtime_action_targets_known_non_active(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var target_slot: Variant = action.get("target_slot", null)
	if target_slot is PokemonSlot:
		return (target_slot as PokemonSlot) != player.active_pokemon
	var raw_target: Variant = action.get("target", null)
	if raw_target is PokemonSlot:
		return (raw_target as PokemonSlot) != player.active_pokemon
	if raw_target is Dictionary:
		var position := str((raw_target as Dictionary).get("position", (raw_target as Dictionary).get("target_position", ""))).strip_edges().to_lower()
		return position.begins_with("bench")
	return false


func _gardevoir_current_queue_has_tm_evolution_route() -> bool:
	for queued_action: Dictionary in _llm_action_queue:
		var kind := str(queued_action.get("kind", queued_action.get("type", "")))
		if kind == "attach_tool" and _ref_has_any_name(queued_action, [TM_EVOLUTION]):
			return true
		if kind in ["attack", "granted_attack"] and (_ref_has_any_name(queued_action, [TM_EVOLUTION]) or _ref_has_any_name(queued_action, ["Evolution"])):
			return true
	return false


func _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if bool(game_state.energy_attached_this_turn):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if player.active_pokemon.attached_energy.size() > 0:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [RALTS, KLEFKI, FLUTTER_MANE, MUNKIDORI]):
		return false
	if not _gardevoir_has_tm_evolution_access(player):
		return false
	return _gardevoir_has_tm_evolution_bench_target(player)


func _gardevoir_current_queue_has_attack_terminal() -> bool:
	for queued_action: Dictionary in _llm_action_queue:
		if _is_attack_action_ref(queued_action):
			return true
	return false


func _count_field_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	if player.active_pokemon != null and _slot_name_matches_any(player.active_pokemon, [query]):
		count += 1
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(slot, [query]):
			count += 1
	return count


func _count_psychic_energy_in_discard(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type_matches("Psychic", str(card.card_data.energy_provides)):
			count += 1
	return count


func _count_attacker_bodies(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_player_slots(player):
		if _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
			count += 1
	return count


func _count_ready_attackers(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_player_slots(player):
		if _slot_has_ready_gardevoir_attack(slot):
			count += 1
	return count


func _active_is_ready_gardevoir_attacker(player: PlayerState) -> bool:
	return player != null and _slot_has_ready_gardevoir_attack(player.active_pokemon)


func _has_ready_bench_gardevoir_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_has_ready_gardevoir_attack(slot):
			return true
	return false


func _slot_has_ready_gardevoir_attack(slot: PokemonSlot) -> bool:
	if slot == null or not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		return false
	var predicted: Dictionary = predict_attacker_damage(slot)
	if bool(predicted.get("can_attack", false)) and int(predicted.get("damage", 0)) > 0:
		return true
	return _gardevoir_min_attack_cost_gap(slot, 0) <= 0 and _gardevoir_embrace_damage_estimate(slot, 0) > 0


func _gardevoir_min_attack_cost_gap(slot: PokemonSlot, extra_psychic_energy: int = 0) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	var cd: CardData = slot.get_card_data()
	if cd.attacks.is_empty():
		return 99
	var best_gap := 99
	for attack: Dictionary in cd.attacks:
		best_gap = mini(best_gap, _gardevoir_attack_cost_gap(slot, str(attack.get("cost", "")), extra_psychic_energy))
	return best_gap


func _gardevoir_attack_cost_gap(slot: PokemonSlot, cost: String, extra_psychic_energy: int = 0) -> int:
	if slot == null:
		return 99
	var remaining := {}
	var colorless_pool := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		if symbol == "":
			continue
		remaining[symbol] = int(remaining.get(symbol, 0)) + 1
		colorless_pool += 1
	if extra_psychic_energy > 0:
		remaining["P"] = int(remaining.get("P", 0)) + extra_psychic_energy
		colorless_pool += extra_psychic_energy
	var missing := 0
	var colorless_needed := 0
	for i: int in cost.length():
		var symbol := _energy_symbol_for_runtime(cost.substr(i, 1))
		if symbol == "":
			continue
		if symbol == "C":
			colorless_needed += 1
			continue
		var count := int(remaining.get(symbol, 0))
		if count <= 0:
			missing += 1
			continue
		remaining[symbol] = count - 1
		colorless_pool -= 1
	missing += maxi(0, colorless_needed - colorless_pool)
	return missing


func _gardevoir_embrace_damage_estimate(slot: PokemonSlot, extra_embrace_count: int = 0) -> int:
	if slot == null:
		return 0
	var counters := int((slot.damage_counters + extra_embrace_count * 20) / 10)
	var name := _slot_best_name(slot)
	if _name_contains(name, DRIFLOON) or _name_contains(name, DRIFBLIM):
		return counters * 30
	if _name_contains(name, SCREAM_TAIL):
		return counters * 20
	return int(predict_attacker_damage(slot, extra_embrace_count).get("damage", 0))


func _all_player_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _slot_name_matches_any(slot: PokemonSlot, queries: Array[String]) -> bool:
	return _name_matches_any(_slot_best_name(slot), queries)


func _slot_best_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return _best_card_name(slot.get_card_data())


func _name_matches_any(name: String, queries: Array[String]) -> bool:
	for query: String in queries:
		if _name_contains(name, query):
			return true
	return false


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)
