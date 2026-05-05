extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const DragapultDusknoirRulesScript = preload("res://scripts/ai/DeckStrategyDragapultDusknoir.gd")

const DRAGAPULT_DUSKNOIR_LLM_ID := "dragapult_dusknoir_llm"
const DREEPY := "Dreepy"
const DRAKLOAK := "Drakloak"
const DRAGAPULT_EX := "Dragapult ex"
const DUSKULL := "Duskull"
const DUSCLOPS := "Dusclops"
const DUSKNOIR := "Dusknoir"
const TATSUGIRI := "Tatsugiri"
const ROTOM_V := "Rotom V"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const RADIANT_ALAKAZAM := "Radiant Alakazam"
const RARE_CANDY := "Rare Candy"
const BUDDY_BUDDY_POFFIN := "Buddy-Buddy Poffin"
const NEST_BALL := "Nest Ball"
const ULTRA_BALL := "Ultra Ball"
const ARVEN := "Arven"
const EARTHEN_VESSEL := "Earthen Vessel"
const SPARKLING_CRYSTAL := "Sparkling Crystal"
const RESCUE_BOARD := "Rescue Board"
const FOREST_SEAL_STONE := "Forest Seal Stone"
const COUNTER_CATCHER := "Counter Catcher"
const BOSSS_ORDERS := "Boss's Orders"
const NIGHT_STRETCHER := "Night Stretcher"
const TM_DEVOLUTION := "Technical Machine: Devolution"

var _deck_strategy_text: String = ""
var _rules: RefCounted = DragapultDusknoirRulesScript.new()


func get_strategy_id() -> String:
	return DRAGAPULT_DUSKNOIR_LLM_ID


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


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	super.build_turn_plan(game_state, player_index, context)
	return _rules.call("build_turn_plan", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_plan") else {}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	return _rules.call("build_turn_contract", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_contract") else super.build_turn_contract(game_state, player_index, context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _is_bad_dragapult_dusknoir_plan_action(action, game_state, player_index):
		return -10000.0
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return _rules.call("score_action_absolute", action, game_state, player_index) if _rules != null and _rules.has_method("score_action_absolute") else 0.0


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _is_bad_dragapult_dusknoir_plan_action(action, game_state, player_index):
		return -10000.0
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var absolute := score_action_absolute(action, game_state, player_index)
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
			return planned
	var deck_picks := _pick_dragapult_dusknoir_interaction_items(items, step, context)
	if not deck_picks.is_empty():
		return deck_picks
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	var deck_score := _score_dragapult_dusknoir_interaction_target(item, step, context)
	if deck_score > -900000000.0:
		return deck_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func _score_dragapult_dusknoir_interaction_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	var step_id := str(step.get("id", ""))
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if item is CardInstance:
		var card := item as CardInstance
		if card.card_data == null:
			return -987654321.0
		var name := _best_card_name(card.card_data)
		if step_id == "stage2_card":
			if _name_contains(name, DRAGAPULT_EX):
				return 1200.0
			if _name_contains(name, DUSKNOIR):
				return 1300.0 if _dusknoir_conversion_ready(game_state, player_index) else 240.0
			return 0.0
	if item is PokemonSlot and step_id == "target_pokemon":
		var slot := item as PokemonSlot
		if _slot_name_matches_any(slot, [DREEPY]):
			return 1200.0
		if _slot_name_matches_any(slot, [DUSKULL]):
			return 900.0 if _dusknoir_conversion_ready(game_state, player_index) else 180.0
		return 0.0
	if item is PokemonSlot and step_id in ["bench_damage_counters", "bench_target"]:
		return _score_dragapult_spread_target(item as PokemonSlot)
	if item is PokemonSlot and step_id == "self_ko_target":
		return _score_dusk_blast_target_for_llm(item as PokemonSlot, step, context)
	return -987654321.0


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot := super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	snapshot["dreepy_line_count"] = _count_field_names(player, [DREEPY, DRAKLOAK, DRAGAPULT_EX])
	snapshot["dragapult_ex_count"] = _count_field_name(player, DRAGAPULT_EX)
	snapshot["dusknoir_line_count"] = _count_field_names(player, [DUSKULL, DUSCLOPS, DUSKNOIR])
	snapshot["dusknoir_count"] = _count_field_name(player, DUSKNOIR)
	snapshot["dragapult_attack_ready"] = _active_dragapult_pressure_ready(game_state, player_index)
	snapshot["phantom_dive_pickoff_visible"] = _phantom_dive_pickoff_visible(opponent)
	snapshot["dusknoir_conversion_ready"] = _dusknoir_conversion_ready(game_state, player_index)
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, DREEPY):
		return "priority opener: main Basic for the Dreepy -> Drakloak -> Dragapult ex Stage 2 line"
	if _name_contains(name, DRAKLOAK):
		return "Stage 1 bridge and draw/search engine; evolve Dreepy before optional support padding"
	if _name_contains(name, DRAGAPULT_EX):
		return "primary Stage 2 spread attacker; build through Drakloak or Rare Candy before support-only routes"
	if _name_contains(name, DUSKULL):
		return "secondary Basic for the Dusknoir conversion lane; bench after the Dragapult seed is covered"
	if _name_contains(name, DUSCLOPS):
		return "conversion support Stage 1; self-KO damage ability only matters with prize math"
	if _name_contains(name, DUSKNOIR):
		return "high-risk self-KO conversion piece; use only when the damage creates or protects a prize conversion"
	if _name_contains(name, TATSUGIRI):
		return "opening pivot and supporter finder; protect Dreepy by opening here when available"
	if _name_contains(name, ROTOM_V):
		return "opening draw and Forest Seal Stone carrier; terminal draw only after safe setup actions"
	if _name_contains(name, LUMINEON_V):
		return "supporter search piece; bench only when the searched supporter completes the line"
	if _name_contains(name, FEZANDIPITI_EX):
		return "comeback draw support after a knockout; avoid early bench unless recovery draw matters"
	if _name_contains(name, RADIANT_ALAKAZAM):
		return "damage-counter support for Dragapult prize math; not an opening priority"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: Dragapult ex / Dusknoir is a Stage 2 pressure deck. Build Dreepy -> Drakloak -> Dragapult ex first, then use Duskull -> Dusclops -> Dusknoir as a high-risk prize-conversion package.")
	lines.append("Setup priority: establish Dreepy early, then Duskull when bench space allows. Buddy-Buddy Poffin, Nest Ball, Ultra Ball, Arven, Rare Candy, Drakloak, and Dragapult ex are main setup pieces. Do not over-bench Rotom V, Lumineon V, Fezandipiti ex, Tatsugiri, or Radiant Alakazam before the evolution seeds are in play.")
	lines.append("Stage 2 policy: Rare Candy and evolution actions should usually finish Dragapult ex before Dusknoir unless the Dusknoir line creates an immediate prize conversion. Drakloak draw/search is valuable when it finds Rare Candy, Dragapult ex, Dusknoir pieces, or Fire/Psychic energy.")
	lines.append("Engine policy: Arven should find the exact item/tool pair for the current bottleneck: Rare Candy, Buddy-Buddy Poffin, Ultra Ball, Earthen Vessel, Sparkling Crystal, Rescue Board, Forest Seal Stone, Technical Machine: Devolution, Counter Catcher, or Night Stretcher. Use Rotom V terminal draw only after all legal setup, attach, search, pivot, or attack routes are worse.")
	lines.append("Forest Seal Stone policy: attach Forest Seal Stone only to Rotom V or Lumineon V. Its deck search is a later VSTAR ability, not an attach_tool interaction; never put search_targets on the attach_tool action.")
	lines.append("Energy policy: attach Fire and Psychic to the Dreepy/Drakloak/Dragapult line closest to attacking. Sparkling Crystal belongs on Dragapult ex or the line that is about to become Dragapult ex. Avoid feeding energy to support-only Pokemon unless it immediately enables retreat into Dragapult ex.")
	lines.append("Attack policy: Dragapult ex is the main attacker. Phantom Dive-style spread is strongest when it takes the active KO while placing bench damage that finishes a prize, sets up the next prize, or protects the current prize map. Lower-damage setup attacks are fallback only.")
	lines.append("Spread targeting policy: place spread counters on damaged, low-HP, or multi-prize bench targets first. Prioritize exact KOs, then targets that Dragapult or Dusknoir can convert next turn. Do not scatter counters randomly when a bench prize or two-turn prize map exists.")
	lines.append("Dusknoir policy: Dusclops and Dusknoir damage abilities self-KO the source. Use them only when the damage immediately takes a prize, turns Phantom Dive into a prize conversion, or prevents losing the prize race. Never spend the self-KO ability just because it is legal.")
	lines.append("Gust policy: Boss's Orders and Counter Catcher should target a bench KO or a target that Dragapult ex can convert immediately. If no real attack or Dusknoir conversion follows, preserve gust resources.")
	lines.append("Resource policy: preserve Rare Candy, Dragapult ex, Drakloak, Dusknoir pieces, Sparkling Crystal, Counter Catcher, Boss, and Night Stretcher for concrete routes. Stop optional draw/churn once a KO or stable Stage 2 route is already available.")
	lines.append("Replan policy: after Drakloak, Rotom V, Lumineon V, Arven, Ultra Ball, Earthen Vessel, Night Stretcher, or other search/draw effects change hand or board, reassess with the updated legal_actions before continuing.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored Dragapult / Dusknoir strategy text follows; obey it when it does not conflict with legal_actions, card rules, current board facts, or resource constraints:")
		lines.append(custom_text)
	lines.append("Execution boundary: exact action ids, legal actions, card rules, interaction_schema fields, HP, attached tools, energy, hand, discard, prizes, and opponent board come from the structured payload. Never invent ids, card effects, targets, or interaction keys.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "evolve" and _ref_has_any_name(ref, [DRAKLOAK, DRAGAPULT_EX, DUSCLOPS, DUSKNOIR]):
		return true
	if action_type == "attach_energy" and _ref_has_any_name(ref, ["Fire Energy", "Psychic Energy"]):
		return true
	if action_type == "attach_tool" and _ref_has_any_name(ref, [SPARKLING_CRYSTAL, RESCUE_BOARD]):
		return true
	if action_type == "use_ability" and _ref_has_any_name(ref, [DRAKLOAK, DUSCLOPS, DUSKNOIR, ROTOM_V, LUMINEON_V]):
		return true
	if action_type == "play_trainer" and _ref_has_any_name(ref, [
		RARE_CANDY,
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		ARVEN,
		EARTHEN_VESSEL,
		COUNTER_CATCHER,
		BOSSS_ORDERS,
		NIGHT_STRETCHER,
	]):
		return true
	return false


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_dragapult_low_value_attack_action(queued_action, game_state, player_index) \
			and _active_dragapult_pressure_ready(game_state, player_index):
		return true
	if _is_bad_dragapult_dusknoir_plan_action(runtime_action, game_state, player_index):
		return true
	if _is_bad_dragapult_dusknoir_plan_action(queued_action, game_state, player_index):
		return true
	return false


func _deck_queue_item_matches_action(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_dragapult_low_value_attack_action(queued_action, game_state, player_index) \
			and _is_dragapult_phantom_dive_attack_action(runtime_action, game_state, player_index):
		return true
	return false


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_dragapult_dusknoir_plan_action(action, game_state, player_index):
		return false
	if _is_dragapult_phantom_dive_attack_action(action, game_state, player_index):
		return true
	return _is_dragapult_dusknoir_runtime_setup_action(action, game_state, player_index)


func _deck_preferred_terminal_attack_for(action: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if not _is_dragapult_low_value_attack_action(action, game_state, player_index):
		return {}
	return _dragapult_phantom_dive_attack_ref(game_state, player_index)


func _deck_is_low_value_runtime_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_dragapult_low_value_attack_action(action, game_state, player_index)


func _is_bad_dragapult_dusknoir_plan_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_dragapult_low_value_attack(action, game_state, player_index):
		return true
	if _is_bad_dusknoir_self_ko_action(action, game_state, player_index):
		return true
	if _is_bad_dragapult_dusknoir_over_setup(action, game_state, player_index):
		return true
	if _is_bad_dragapult_dusknoir_optional_draw(action, game_state, player_index):
		return true
	if _is_bad_dragapult_dusknoir_energy_attach(action, game_state, player_index):
		return true
	if _is_bad_dragapult_dusknoir_tool_attach(action, game_state, player_index):
		return true
	return _is_bad_dragapult_dusknoir_retreat(action, game_state, player_index)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_dragapult_dusknoir_setup(game_state, player_index)


func _deck_hand_has_recovery_or_pivot_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _name_matches_any(name, [NIGHT_STRETCHER, RESCUE_BOARD, COUNTER_CATCHER, BOSSS_ORDERS, RARE_CANDY, ARVEN]):
			return true
	return false


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_dragapult_dusknoir_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_dragapult_dusknoir_setup_card(card_data)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_dragapult_dusknoir_setup_catalog(target, seen_ids, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_dragapult_dusknoir_setup_catalog(target, seen_ids, has_attack)


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if _ref_has_any_name(action, [DRAGAPULT_EX, "Phantom Dive"]):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	return _slot_name_matches_any(player.active_pokemon, [DRAGAPULT_EX]) and _can_slot_attack(player.active_pokemon)


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _append_dragapult_dusknoir_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", DREEPY, "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", DUSKULL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", BUDDY_BUDDY_POFFIN, "")
	_append_catalog_match(target, seen_ids, "play_trainer", NEST_BALL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", ULTRA_BALL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", ARVEN, "")
	_append_catalog_match(target, seen_ids, "play_trainer", RARE_CANDY, "")
	_append_catalog_match(target, seen_ids, "play_trainer", EARTHEN_VESSEL, "")
	_append_catalog_match(target, seen_ids, "attach_tool", TM_DEVOLUTION, "")
	_append_catalog_match(target, seen_ids, "evolve", DRAKLOAK, "")
	_append_catalog_match(target, seen_ids, "evolve", DRAGAPULT_EX, "")
	_append_catalog_match(target, seen_ids, "evolve", DUSCLOPS, "")
	_append_catalog_match(target, seen_ids, "evolve", DUSKNOIR, "")
	_append_catalog_match(target, seen_ids, "attach_energy", "Psychic Energy", "")
	_append_catalog_match(target, seen_ids, "attach_energy", "Fire Energy", "")
	_append_catalog_match(target, seen_ids, "attach_tool", SPARKLING_CRYSTAL, "")
	if not has_attack:
		_append_catalog_match(target, seen_ids, "use_ability", "", DRAKLOAK)
		_append_catalog_match(target, seen_ids, "play_trainer", NIGHT_STRETCHER, "")
		_append_catalog_match(target, seen_ids, "use_ability", "", ROTOM_V)


func _has_visible_dragapult_dusknoir_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var visible_setup := _catalog_has_dragapult_dusknoir_setup_action()
	for card: CardInstance in player.hand:
		if card != null and _is_dragapult_dusknoir_setup_card(card.card_data):
			visible_setup = true
			break
	if not visible_setup:
		return false
	if _count_field_name(player, DRAGAPULT_EX) <= 0:
		return true
	if _dusknoir_conversion_ready(game_state, player_index):
		return false
	if _count_field_name(player, DREEPY) + _count_field_name(player, DRAKLOAK) <= 0:
		return true
	if _count_field_names(player, [DUSKULL, DUSCLOPS, DUSKNOIR]) <= 0:
		return true
	return visible_setup


func _catalog_has_dragapult_dusknoir_setup_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type in ["end_turn", "attack", "granted_attack", "route"]:
			continue
		if action_type in ["play_basic_to_bench", "evolve", "attach_energy", "attach_tool", "retreat"]:
			return true
		if action_type == "play_trainer" and _ref_has_any_name(ref, [
			BUDDY_BUDDY_POFFIN,
			NEST_BALL,
			ULTRA_BALL,
			ARVEN,
			RARE_CANDY,
			EARTHEN_VESSEL,
			NIGHT_STRETCHER,
			COUNTER_CATCHER,
			BOSSS_ORDERS,
		]):
			return true
		if action_type == "use_ability" and _ref_has_any_name(ref, [DRAKLOAK, ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM]):
			return true
	return false


func _is_dragapult_dusknoir_setup_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	for query: String in [
		DREEPY,
		DRAKLOAK,
		DRAGAPULT_EX,
		DUSKULL,
		DUSCLOPS,
		DUSKNOIR,
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		ARVEN,
		RARE_CANDY,
		EARTHEN_VESSEL,
		SPARKLING_CRYSTAL,
		RESCUE_BOARD,
		FOREST_SEAL_STONE,
		TM_DEVOLUTION,
		NIGHT_STRETCHER,
		COUNTER_CATCHER,
		BOSSS_ORDERS,
		"Fire Energy",
		"Psychic Energy",
	]:
		if _name_contains(name, query):
			return true
	return false


func _is_bad_dusknoir_self_ko_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "use_ability":
		return false
	var raw_source: Variant = action.get("source_slot", null)
	var source_slot: PokemonSlot = raw_source as PokemonSlot if raw_source is PokemonSlot else null
	if source_slot == null or not _slot_name_matches_any(source_slot, [DUSCLOPS, DUSKNOIR]):
		if not _ref_has_any_name(action, [DUSCLOPS, DUSKNOIR, "Cursed Blast"]):
			return false
	return not _dusknoir_conversion_ready_for_action(action, game_state, player_index)


func _dusknoir_conversion_ready_for_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	if _dusk_self_ko_gives_opponent_final_prize(game_state, player_index) \
			and not _dusk_blast_action_wins_game(action, game_state, player_index):
		return false
	var blast_damage := _dusk_blast_damage_for_action(action)
	if _opponent_has_dusk_blast_conversion_target(opponent, blast_damage, game_state, player_index):
		return true
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	if opponent.active_pokemon != null:
		var active_remaining := opponent.active_pokemon.get_remaining_hp()
		if active_remaining > 200 and active_remaining <= 200 + blast_damage:
			return true
	for slot: PokemonSlot in opponent.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= blast_damage + 60:
			return true
	return false


func _dusk_self_ko_gives_opponent_final_prize(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	var opponent_prizes_remaining := opponent.prizes.size()
	return opponent_prizes_remaining > 0 and opponent_prizes_remaining <= 1


func _dusk_blast_action_wins_game(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if player == null or opponent == null:
		return false
	var prizes_remaining := player.prizes.size()
	if prizes_remaining <= 0:
		return false
	var blast_damage := _dusk_blast_damage_for_action(action)
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= blast_damage and slot.get_prize_count() >= prizes_remaining:
			return true
	return false


func _dusk_blast_damage_for_action(action: Dictionary) -> int:
	var raw_source: Variant = action.get("source_slot", null)
	var source_slot: PokemonSlot = raw_source as PokemonSlot if raw_source is PokemonSlot else null
	if _slot_name_matches_any(source_slot, [DUSCLOPS]) or _ref_has_any_name(action, [DUSCLOPS]):
		return 50
	return 130


func _dusknoir_conversion_ready(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	if _opponent_has_dusk_blast_conversion_target(opponent, 130, game_state, player_index):
		return true
	if _active_dragapult_pressure_ready(game_state, player_index) and _phantom_dive_pickoff_visible(opponent):
		return true
	if player != null and _count_field_name(player, DRAGAPULT_EX) > 0 and _opponent_has_high_value_damaged_target(opponent):
		return true
	return false


func _opponent_has_dusk_blast_ko_target(opponent: PlayerState, blast_damage: int) -> bool:
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= blast_damage:
			return true
	return false


func _opponent_has_dusk_blast_conversion_target(opponent: PlayerState, blast_damage: int, game_state: GameState, player_index: int) -> bool:
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() > blast_damage:
			continue
		if slot.get_prize_count() >= 2:
			return true
		if _is_closing_prize_target(slot, game_state, player_index):
			return true
		if _active_dragapult_pressure_ready(game_state, player_index):
			return true
	return false


func _phantom_dive_pickoff_visible(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in opponent.bench:
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.get_remaining_hp() <= 60:
			return true
		if slot.damage_counters >= 40 and slot.get_prize_count() >= 2:
			return true
	return false


func _opponent_has_high_value_damaged_target(opponent: PlayerState) -> bool:
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_top_card() == null:
			continue
		if slot.damage_counters > 0 and (slot.get_remaining_hp() <= 180 or slot.get_prize_count() >= 2):
			return true
	return false


func _active_dragapult_pressure_ready(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [DRAGAPULT_EX]):
		return false
	if _can_slot_use_attack(player.active_pokemon, "Phantom Dive"):
		return true
	var prediction: Dictionary = predict_attacker_damage(player.active_pokemon)
	return bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) >= 180


func _is_bad_dragapult_dusknoir_over_setup(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "play_basic_to_bench":
		if _ref_has_any_name(action, [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM, TATSUGIRI]):
			return true
		if _ref_has_any_name(action, [DREEPY]):
			return _dragapult_backup_line_count(player) >= 1
		if _ref_has_any_name(action, [DUSKULL]):
			return _count_field_names(player, [DUSKULL, DUSCLOPS, DUSKNOIR]) >= 1
		return false
	if kind == "play_trainer" and _ref_has_any_name(action, [BUDDY_BUDDY_POFFIN, NEST_BALL]):
		return _dragapult_board_should_stop_extra_setup(game_state, player_index)
	return false


func _dragapult_board_should_stop_extra_setup(game_state: GameState, player_index: int) -> bool:
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var dragapult_backup_count := _dragapult_backup_line_count(player)
	var dusk_line_count := _count_field_names(player, [DUSKULL, DUSCLOPS, DUSKNOIR])
	return dragapult_backup_count >= 1 and dusk_line_count >= 1


func _dragapult_backup_line_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := _count_field_names(player, [DREEPY, DRAKLOAK, DRAGAPULT_EX])
	if _slot_name_matches_any(player.active_pokemon, [DREEPY, DRAKLOAK, DRAGAPULT_EX]):
		count -= 1
	return maxi(0, count)


func _is_bad_dragapult_dusknoir_optional_draw(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "use_ability":
		return false
	if not _active_dragapult_pressure_ready(game_state, player_index):
		return false
	if _ref_has_any_name(action, [ROTOM_V]):
		return true
	if _ref_has_any_name(action, [FEZANDIPITI_EX]) and _player_hand_size(game_state, player_index) >= 4:
		return true
	return false


func _player_hand_size(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	return player.hand.size() if player != null else 0


func _is_bad_dragapult_dusknoir_energy_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	var raw_target: Variant = action.get("target_slot", null)
	var target_slot: PokemonSlot = raw_target as PokemonSlot if raw_target is PokemonSlot else null
	var target_name := _action_target_name(action)
	if target_slot != null and target_slot.get_card_data() != null:
		if _slot_name_matches_any(target_slot, [DREEPY, DRAKLOAK, DRAGAPULT_EX]) and not _action_energy_is_dragapult_type(action):
			return true
		if _slot_is_support_only(target_slot):
			return true
		if _slot_name_matches_any(target_slot, [DUSKULL, DUSCLOPS, DUSKNOIR]):
			return true
	if _name_matches_any(target_name, [DREEPY, DRAKLOAK, DRAGAPULT_EX]) and not _action_energy_is_dragapult_type(action):
		return true
	if _name_matches_any(target_name, [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM, TATSUGIRI]):
		return true
	if _name_matches_any(target_name, [DUSKULL, DUSCLOPS, DUSKNOIR]):
		return true
	return false


func _has_dragapult_line_available(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_names(player, [DREEPY, DRAKLOAK, DRAGAPULT_EX]) > 0:
		return true
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _name_matches_any(_best_card_name(card.card_data), [DREEPY, DRAKLOAK, DRAGAPULT_EX]):
			return true
	return false


func _is_bad_dragapult_dusknoir_tool_attach(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_tool":
		return false
	var raw_card: Variant = action.get("card", null)
	var raw_target: Variant = action.get("target_slot", null)
	var card: CardInstance = raw_card as CardInstance if raw_card is CardInstance else null
	var target_slot: PokemonSlot = raw_target as PokemonSlot if raw_target is PokemonSlot else null
	var tool_name := _best_card_name(card.card_data) if card != null and card.card_data != null else _action_card_name(action)
	var target_name := _action_target_name(action)
	var target_is_dragapult_line := _slot_name_matches_any(target_slot, [DRAGAPULT_EX, DRAKLOAK, DREEPY]) if target_slot != null else _name_matches_any(target_name, [DRAGAPULT_EX, DRAKLOAK, DREEPY])
	var target_is_v_search_holder := _slot_name_matches_any(target_slot, [ROTOM_V, LUMINEON_V]) if target_slot != null else _name_matches_any(target_name, [ROTOM_V, LUMINEON_V])
	var target_is_stage2 := _slot_name_matches_any(target_slot, [DRAGAPULT_EX, DUSKNOIR]) if target_slot != null else _name_matches_any(target_name, [DRAGAPULT_EX, DUSKNOIR])
	if _name_contains(tool_name, SPARKLING_CRYSTAL) and not target_is_dragapult_line:
		return true
	if _name_contains(tool_name, FOREST_SEAL_STONE) and not target_is_v_search_holder:
		return true
	if _name_contains(tool_name, TM_DEVOLUTION):
		if target_is_stage2:
			return true
		return not _has_real_tm_devolution_window(game_state, player_index)
	return false


func _has_real_tm_devolution_window(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[1 - player_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		if slot == null or slot.get_card_data() == null:
			continue
		var stage := str(slot.get_card_data().stage)
		if stage == "" or _name_contains(stage, "Basic"):
			continue
		if slot.damage_counters > 0:
			return true
		if slot.get_remaining_hp() <= 160:
			return true
	return false


func _is_bad_dragapult_dusknoir_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "retreat":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [DRAGAPULT_EX]):
		return false
	var raw_bench_target: Variant = action.get("bench_target", null)
	var bench_target: PokemonSlot = raw_bench_target as PokemonSlot if raw_bench_target is PokemonSlot else null
	return bench_target != null and _slot_is_support_only(bench_target)


func _slot_is_support_only(slot: PokemonSlot) -> bool:
	return _slot_name_matches_any(slot, [ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM, TATSUGIRI])


func _pick_dragapult_dusknoir_interaction_items(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var step_id := str(step.get("id", ""))
	if step_id not in ["bench_damage_counters", "bench_target", "self_ko_target"]:
		return []
	var max_select := int(step.get("max_select", items.size()))
	if max_select <= 0:
		return []
	var scored: Array[Dictionary] = []
	for i: int in items.size():
		var item: Variant = items[i]
		var score := _score_dragapult_dusknoir_interaction_target(item, step, context)
		if score <= -900000000.0:
			continue
		scored.append({
			"index": i,
			"item": item,
			"score": score,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return int(a.get("index", -1)) < int(b.get("index", -1))
		return score_a > score_b
	)
	var picked: Array = []
	for i: int in mini(max_select, scored.size()):
		picked.append(scored[i].get("item"))
	return picked


func _score_dragapult_spread_target(slot: PokemonSlot) -> float:
	if slot == null or slot.get_top_card() == null:
		return -987654321.0
	var remaining_hp := slot.get_remaining_hp()
	var prize_count := slot.get_prize_count()
	var score := float(prize_count) * 180.0
	if remaining_hp <= 60:
		score += 1000.0 + float(prize_count) * 240.0
	elif remaining_hp <= 120:
		score += 330.0 + float(prize_count) * 100.0
	elif remaining_hp <= 180:
		score += 150.0
	if _is_rule_box(slot):
		score += 120.0
	score += float(slot.damage_counters) * 3.0
	score -= float(remaining_hp) * 0.75
	return score


func _score_dusk_blast_target_for_llm(slot: PokemonSlot, step: Dictionary, context: Dictionary) -> float:
	if slot == null or slot.get_top_card() == null:
		return -987654321.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var remaining_hp := slot.get_remaining_hp()
	var prize_count := slot.get_prize_count()
	var blast_damage := _dusk_blast_damage_for_context(step, context)
	var score := float(prize_count) * 130.0
	if remaining_hp <= blast_damage:
		score += 780.0
		if prize_count >= 2:
			score += 360.0
		if _is_closing_prize_target(slot, game_state, player_index):
			score += 720.0
		if _active_dragapult_pressure_ready(game_state, player_index):
			score += 160.0
		return score
	if _active_dragapult_pressure_ready(game_state, player_index):
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			var opponent: PlayerState = game_state.players[1 - player_index]
			if opponent != null and slot == opponent.active_pokemon and remaining_hp <= blast_damage + 200:
				score += 560.0
				if prize_count >= 2:
					score += 120.0
				return score
		if remaining_hp <= blast_damage + 60:
			score += 420.0
			if prize_count >= 2:
				score += 110.0
			return score
	if slot.damage_counters > 0 and prize_count >= 2:
		score += 160.0 + float(slot.damage_counters) * 2.0
	score -= float(remaining_hp) * 0.4
	return score


func _dusk_blast_damage_for_context(step: Dictionary, context: Dictionary) -> int:
	var raw_source: Variant = context.get("source_slot", step.get("source_slot", null))
	var source_slot: PokemonSlot = raw_source as PokemonSlot if raw_source is PokemonSlot else null
	if _slot_name_matches_any(source_slot, [DUSCLOPS]):
		return 50
	return 130


func _is_closing_prize_target(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var prizes_remaining := game_state.players[player_index].prizes.size()
	return prizes_remaining > 0 and slot.get_prize_count() >= prizes_remaining


func _is_rule_box(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and str(slot.get_card_data().mechanic) != ""


func _is_bad_dragapult_low_value_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_dragapult_low_value_attack_action(action, game_state, player_index) \
		and _active_dragapult_pressure_ready(game_state, player_index)


func _is_dragapult_low_value_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, [DRAGAPULT_EX]):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _runtime_attack_name(action, player.active_pokemon, attack_index)
	if attack_index == 0:
		return true
	if _name_contains(attack_name, "Jet Head") or _name_contains(attack_name, "喷射头击"):
		return true
	var projected_damage := int(action.get("projected_damage", action.get("damage", 0)))
	return projected_damage > 0 and projected_damage <= 90 and not _name_contains(attack_name, "Phantom Dive")


func _is_dragapult_phantom_dive_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, [DRAGAPULT_EX]):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _runtime_attack_name(action, player.active_pokemon, attack_index)
	if attack_index == 1:
		return _dragapult_attack_index_cost_ready(player.active_pokemon, 1)
	if _name_contains(attack_name, "Phantom Dive") or _name_contains(attack_name, "幻影潜袭"):
		return _dragapult_attack_index_cost_ready(player.active_pokemon, 1)
	var projected_damage := int(action.get("projected_damage", action.get("damage", 0)))
	return projected_damage >= 180 and _dragapult_attack_index_cost_ready(player.active_pokemon, 1)


func _dragapult_phantom_dive_attack_ref(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, [DRAGAPULT_EX]):
		return {}
	if not _dragapult_attack_index_cost_ready(player.active_pokemon, 1):
		return {}
	var attacks: Array = player.active_pokemon.get_card_data().attacks
	if attacks.size() <= 1:
		return {}
	var attack: Dictionary = attacks[1] if attacks[1] is Dictionary else {}
	var ref := _catalog_attack_ref_for_dragapult_index(1)
	if ref.is_empty():
		ref = {
			"type": "attack",
			"kind": "attack",
			"id": "attack:1",
			"action_id": "attack:1",
			"attack_index": 1,
			"attack_name": str(attack.get("name", "Phantom Dive")),
			"attack_rules": attack.duplicate(true),
			"projected_damage": _parse_damage_value(str(attack.get("damage", "200"))),
		}
	else:
		ref["attack_index"] = 1
		if not ref.has("attack_name"):
			ref["attack_name"] = str(attack.get("name", "Phantom Dive"))
		if not ref.has("projected_damage"):
			ref["projected_damage"] = _parse_damage_value(str(attack.get("damage", "200")))
	return ref


func _catalog_attack_ref_for_dragapult_index(attack_index: int) -> Dictionary:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if not _is_attack_action_ref(ref):
			continue
		if int(ref.get("attack_index", -1)) != attack_index:
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = str(raw_key)
		copy["action_id"] = str(raw_key)
		return copy
	return {}


func _dragapult_attack_index_cost_ready(slot: PokemonSlot, attack_index: int) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var attacks: Array = slot.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return false
	var attack: Dictionary = attacks[attack_index] if attacks[attack_index] is Dictionary else {}
	return slot.attached_energy.size() >= str(attack.get("cost", "")).length()


func _runtime_attack_name(action: Dictionary, active_slot: PokemonSlot, attack_index: int) -> String:
	var attack_name := str(action.get("attack_name", ""))
	if attack_name.strip_edges() != "":
		return attack_name
	if active_slot == null or active_slot.get_card_data() == null:
		return ""
	var attacks: Array = active_slot.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return ""
	var attack: Dictionary = attacks[attack_index] if attacks[attack_index] is Dictionary else {}
	return str(attack.get("name", ""))


func _is_dragapult_dusknoir_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["play_basic_to_bench", "evolve"]:
		return _ref_has_any_name(action, [DREEPY, DRAKLOAK, DRAGAPULT_EX, DUSKULL, DUSCLOPS, DUSKNOIR])
	if kind == "attach_energy":
		return not _is_bad_dragapult_dusknoir_energy_attach(action, game_state, player_index)
	if kind == "attach_tool":
		return not _is_bad_dragapult_dusknoir_tool_attach(action, game_state, player_index) and _ref_has_any_name(action, [SPARKLING_CRYSTAL, RESCUE_BOARD, FOREST_SEAL_STONE, TM_DEVOLUTION])
	if kind == "play_trainer":
		return _ref_has_any_name(action, [
			RARE_CANDY,
			BUDDY_BUDDY_POFFIN,
			NEST_BALL,
			ULTRA_BALL,
			ARVEN,
			EARTHEN_VESSEL,
			COUNTER_CATCHER,
			BOSSS_ORDERS,
			NIGHT_STRETCHER,
			TM_DEVOLUTION,
		])
	if kind == "use_ability":
		return _ref_has_any_name(action, [DRAKLOAK, ROTOM_V, LUMINEON_V, FEZANDIPITI_EX, RADIANT_ALAKAZAM])
	if kind == "retreat":
		return not _is_bad_dragapult_dusknoir_retreat(action, game_state, player_index)
	return false


func _action_energy_is_dragapult_type(action: Dictionary) -> bool:
	var raw_card: Variant = action.get("card", null)
	if raw_card is CardInstance and (raw_card as CardInstance).card_data != null:
		var cd := (raw_card as CardInstance).card_data
		if cd.is_energy():
			var provides := str(cd.energy_provides)
			return _energy_type_matches("Fire", provides) \
				or _energy_type_matches("R", provides) \
				or _energy_type_matches("Psychic", provides) \
				or _energy_type_matches("P", provides)
	var card_name := _action_card_name(action)
	return _name_matches_any(card_name, ["Fire Energy", "Psychic Energy"])


func _parse_damage_value(text: String) -> int:
	var cleaned := text.replace("+", "").replace("x", "").replace("X", "").strip_edges()
	return int(cleaned) if cleaned.is_valid_int() else 0


func _count_field_names(player: PlayerState, names: Array[String]) -> int:
	var count := 0
	for name: String in names:
		count += _count_field_name(player, name)
	return count


func _count_field_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _slot_name_matches_any(slot, [query]):
			count += 1
	return count


func _all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _action_card_name(action: Dictionary) -> String:
	var raw_card: Variant = action.get("card", null)
	if raw_card is CardInstance and (raw_card as CardInstance).card_data != null:
		return _best_card_name((raw_card as CardInstance).card_data)
	if raw_card is Dictionary:
		var card_dict := raw_card as Dictionary
		return str(card_dict.get("name_en", card_dict.get("name", card_dict.get("card_name", ""))))
	return str(raw_card)


func _action_target_name(action: Dictionary) -> String:
	var raw_slot: Variant = action.get("target_slot", null)
	if raw_slot is PokemonSlot and (raw_slot as PokemonSlot).get_card_data() != null:
		return _best_card_name((raw_slot as PokemonSlot).get_card_data())
	var raw_target: Variant = action.get("target", null)
	if raw_target is PokemonSlot and (raw_target as PokemonSlot).get_card_data() != null:
		return _best_card_name((raw_target as PokemonSlot).get_card_data())
	if raw_target is Dictionary:
		var target_dict := raw_target as Dictionary
		return str(target_dict.get("name_en", target_dict.get("name", target_dict.get("pokemon_name", ""))))
	return str(raw_target)


func _slot_name_matches_any(slot: PokemonSlot, queries: Array[String]) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	return _name_matches_any(_best_card_name(slot.get_card_data()), queries)


func _name_matches_any(name: String, queries: Array[String]) -> bool:
	for query: String in queries:
		if _name_contains(name, query):
			return true
	return false


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	return str(cd.name_en) if str(cd.name_en) != "" else str(cd.name)


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(ref.get("id", "")),
		str(ref.get("action_id", "")),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("attack_name", "")),
		str(ref.get("target", "")),
	])
	var source_slot: PokemonSlot = ref.get("source_slot", null)
	if source_slot != null and source_slot.get_card_data() != null:
		combined += " %s" % _best_card_name(source_slot.get_card_data())
	var card: Variant = ref.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		combined += " %s" % _best_card_name((card as CardInstance).card_data)
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		combined += " %s %s" % [
			str((card_rules as Dictionary).get("name", "")),
			str((card_rules as Dictionary).get("name_en", "")),
		]
	var ability_rules: Variant = ref.get("ability_rules", {})
	if ability_rules is Dictionary:
		combined += " %s %s" % [
			str((ability_rules as Dictionary).get("name", "")),
			str((ability_rules as Dictionary).get("text", "")),
		]
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _can_slot_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if slot.attached_energy.size() >= str(attack.get("cost", "")).length():
			return true
	return false


func _can_slot_use_attack(slot: PokemonSlot, attack_name: String) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		if not _name_contains(str(attack.get("name", "")), attack_name):
			continue
		return slot.attached_energy.size() >= str(attack.get("cost", "")).length()
	return false
