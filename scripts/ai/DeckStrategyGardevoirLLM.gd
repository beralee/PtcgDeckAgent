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
const PROFESSOR_TUROS_SCENARIO := "Professor Turo's Scenario"
const IONO := "Iono"
const PSYCHIC_ENERGY := "Psychic Energy"
const DARKNESS_ENERGY := "Darkness Energy"
const GARDEVOIR_HARD_BLOCK_SCORE := -100000.0

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
var _last_gardevoir_pressure_ready_attacker_count := 0
var _last_gardevoir_active_ready_attacker := false
var _last_gardevoir_active_pressure_ready_attacker := false
var _last_gardevoir_ready_bench_attacker_count := 0
var _last_gardevoir_pressure_ready_bench_attacker_count := 0


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


func configure_from_deck(deck: DeckData) -> void:
	if deck != null:
		set_deck_strategy_text(str(deck.strategy))
	if _rules != null and _rules.has_method("configure_from_deck"):
		_rules.call("configure_from_deck", deck)


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
	if game_state != null and _gardevoir_runtime_manual_attach_enables_active_attacker_pressure(action, game_state, player_index):
		return 90500.0
	if game_state != null and _active_gardevoir_attacker_kos_now(game_state, player_index) and _is_optional_gardevoir_action_after_active_ko_ready(action):
		return GARDEVOIR_HARD_BLOCK_SCORE
	if game_state != null and _is_end_turn_action_ref(action) and _deck_should_block_end_turn(game_state, player_index):
		return -10000.0
	if game_state != null and _deck_should_block_exact_queue_match({}, action, game_state, player_index):
		return GARDEVOIR_HARD_BLOCK_SCORE
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
			if _is_gardevoir_energy_search_step(step, context):
				var energy_search_plan := _protect_gardevoir_energy_search_picks(planned, items, step, context)
				if not energy_search_plan.is_empty():
					return energy_search_plan
			if _is_gardevoir_search_step(step, context):
				var search_plan := _protect_gardevoir_search_picks(planned, items, step, context)
				if not search_plan.is_empty():
					return search_plan
				if _gardevoir_search_override_active(context):
					return []
			if _is_gardevoir_damage_counter_source_step(step):
				var counter_source_plan := _protect_gardevoir_damage_counter_source_picks(planned, items, step, context)
				if not counter_source_plan.is_empty():
					return counter_source_plan
			if _is_gardevoir_recovery_step(step):
				var recovery_plan := _protect_gardevoir_recovery_picks(planned, items, step, context)
				if not recovery_plan.is_empty():
					return recovery_plan
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
		var fallback_energy_search_plan := _protect_gardevoir_energy_search_picks([], items, step, context)
		if not fallback_energy_search_plan.is_empty():
			return fallback_energy_search_plan
		var fallback_search_plan := _protect_gardevoir_search_picks([], items, step, context)
		if not fallback_search_plan.is_empty():
			return fallback_search_plan
		if _is_gardevoir_search_step(step, context) and _gardevoir_search_override_active(context):
			return []
		if _is_gardevoir_damage_counter_source_step(step):
			var fallback_counter_source_plan := _protect_gardevoir_damage_counter_source_picks([], items, step, context)
			if not fallback_counter_source_plan.is_empty():
				return fallback_counter_source_plan
		if _is_gardevoir_recovery_step(step):
			var fallback_recovery_plan := _protect_gardevoir_recovery_picks([], items, step, context)
			if not fallback_recovery_plan.is_empty():
				return fallback_recovery_plan
		if _is_discard_step(step):
			var fallback_discard_plan := _gardevoir_discard_fallback_for_step(items, step, context)
			if not fallback_discard_plan.is_empty():
				return fallback_discard_plan
	if _is_gardevoir_recovery_step(step):
		var fallback_recovery_without_plan := _protect_gardevoir_recovery_picks([], items, step, context)
		if not fallback_recovery_without_plan.is_empty():
			return fallback_recovery_without_plan
	if _is_discard_step(step):
		var fallback_discard_without_plan := _gardevoir_discard_fallback_for_step(items, step, context)
		if not fallback_discard_without_plan.is_empty():
			return fallback_discard_without_plan
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if item is PokemonSlot:
		var scream_tail_target_score := _score_gardevoir_scream_tail_attack_target(item as PokemonSlot, step, context)
		if scream_tail_target_score != 0.0:
			return scream_tail_target_score
		var counter_score := _score_gardevoir_damage_counter_interaction(item as PokemonSlot, step, context)
		if counter_score != 0.0:
			return counter_score
	if _is_psychic_embrace_target_step(step, context) and item is PokemonSlot:
		var pressure_active := _gardevoir_forced_active_embrace_target(game_state, player_index)
		if pressure_active != null:
			return 200000.0 + float(_gardevoir_embrace_damage_estimate(pressure_active, 1)) if item == pressure_active else -1000.0
	if _is_discard_step(step) and item is CardInstance:
		var discard_card_for_protection: CardInstance = item as CardInstance
		if discard_card_for_protection.card_data != null and _is_gardevoir_protected_discard_card(discard_card_for_protection.card_data, game_state, player_index):
			return -1000.0
	if _is_gardevoir_recovery_step(step) and item is CardInstance:
		var recovery_score := _score_gardevoir_recovery_target(item as CardInstance, step, context)
		if recovery_score != 0.0:
			return recovery_score
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
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
				var energy_search_score := _score_gardevoir_energy_search_target(item as CardInstance, step, context)
				if energy_search_score != 0.0:
					return energy_search_score
				var search_score := _score_gardevoir_search_target(item as CardInstance, step, context)
				if search_score != 0.0:
					return search_score
				var planned_recovery_score := _score_gardevoir_recovery_target(item as CardInstance, step, context)
				if planned_recovery_score != 0.0:
					return planned_recovery_score
			return planned_score
		if _is_psychic_embrace_energy_step(step, context) and item is CardInstance:
			return _score_psychic_embrace_energy_item(item as CardInstance)
		if _is_psychic_embrace_target_step(step, context) and item is PokemonSlot:
			var fallback_embrace_score := _score_gardevoir_embrace_target(item as PokemonSlot, step, context)
			if fallback_embrace_score != 0.0:
				return fallback_embrace_score
	if _is_psychic_embrace_energy_step(step, context) and item is CardInstance:
		return _score_psychic_embrace_energy_item(item as CardInstance)
	if _is_psychic_embrace_target_step(step, context) and item is PokemonSlot:
		var fallback_embrace_score_no_plan := _score_gardevoir_embrace_target(item as PokemonSlot, step, context)
		if fallback_embrace_score_no_plan != 0.0:
			return fallback_embrace_score_no_plan
	if item is CardInstance:
		var fallback_item_search_score := _score_gardevoir_item_search_target(item as CardInstance, step, context)
		if fallback_item_search_score != 0.0:
			return fallback_item_search_score
		var fallback_energy_search_score := _score_gardevoir_energy_search_target(item as CardInstance, step, context)
		if fallback_energy_search_score != 0.0:
			return fallback_energy_search_score
		var fallback_search_score := _score_gardevoir_search_target(item as CardInstance, step, context)
		if fallback_search_score != 0.0:
			return fallback_search_score
		var fallback_recovery_score := _score_gardevoir_recovery_target(item as CardInstance, step, context)
		if fallback_recovery_score != 0.0:
			return fallback_recovery_score
	return float(_rules.call("score_interaction_target", item, step, context)) if _rules != null and _rules.has_method("score_interaction_target") else 0.0


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	if item is PokemonSlot:
		var gardevoir_handoff_score := _score_gardevoir_handoff_target_slot(item as PokemonSlot, step, context)
		if gardevoir_handoff_score != 0.0:
			return gardevoir_handoff_score
	if _rules != null and _rules.has_method("score_handoff_target"):
		return float(_rules.call("score_handoff_target", item, step, context))
	return score_interaction_target(item, step, context)


func _score_gardevoir_handoff_target_slot(slot: PokemonSlot, step: Dictionary, context: Dictionary) -> float:
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var step_id := str(step.get("id", ""))
	if step_id not in ["send_out", "switch_target", "self_switch_target", "pivot_target", "own_bench_target"]:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var damage := _gardevoir_current_attacker_damage_estimate(slot)
	if _slot_has_pressure_ready_gardevoir_attack(slot, game_state, player_index):
		return 220000.0 + float(damage)
	if _slot_has_ready_gardevoir_attack(slot):
		return 180000.0 + float(damage)
	if _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		if slot.attached_energy.size() > 0 or _slot_has_tool_name(slot, BRAVERY_CHARM):
			return 90000.0 + float(slot.attached_energy.size() * 1000)
		return 50000.0
	if _slot_name_matches_any(slot, [MUNKIDORI]) and _slot_has_energy_type(slot, "Darkness") and _gardevoir_munkidori_has_damage_transfer_value(game_state, player_index):
		return 70000.0
	if _gardevoir_ex_handoff_attack_bridge(slot, game_state, player_index):
		return 160000.0 + float(mini(190, _opponent_active_remaining_hp(game_state, player_index)))
	if _slot_name_matches_any(slot, GARDEVOIR_CORE_NAMES):
		return -20000.0
	if _slot_name_matches_any(slot, GARDEVOIR_SUPPORT_NAMES):
		return -10000.0
	return 0.0


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
	snapshot["pressure_ready_attacker_count"] = _count_pressure_ready_attackers(player, game_state, player_index)
	snapshot["active_gardevoir_attacker_ready"] = _active_is_ready_gardevoir_attacker(player)
	snapshot["active_gardevoir_attacker_pressure_ready"] = _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index)
	snapshot["active_gardevoir_attacker_needs_more_embrace_pressure"] = _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index)
	snapshot["ready_bench_gardevoir_attacker_count"] = _count_ready_bench_attackers(player)
	snapshot["pressure_ready_bench_gardevoir_attacker_count"] = _count_pressure_ready_bench_attackers(player, game_state, player_index)
	snapshot["active_retreat_gap"] = _gardevoir_retreat_energy_gap(player.active_pokemon)
	snapshot["active_energy_count"] = player.active_pokemon.attached_energy.size() if player.active_pokemon != null else 0
	snapshot["active_slot_name"] = _slot_best_name(player.active_pokemon)
	snapshot["active_gardevoir_attacker_name"] = _slot_best_name(player.active_pokemon) if _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES) else ""
	snapshot["active_gardevoir_attacker_energy_count"] = player.active_pokemon.attached_energy.size() if _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES) else 0
	snapshot["active_gardevoir_attacker_damage"] = _gardevoir_current_attacker_damage_estimate(player.active_pokemon) if _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES) else 0
	snapshot["active_has_tm_evolution"] = _slot_has_tool_name(player.active_pokemon, TM_EVOLUTION)
	snapshot["active_tm_evolution_bridge_ready"] = bool(snapshot["active_has_tm_evolution"]) and int(snapshot["active_energy_count"]) > 0
	var active_core_attack := _gardevoir_best_active_core_attack(game_state, player_index)
	snapshot["active_gardevoir_core_attack_ready"] = not active_core_attack.is_empty()
	snapshot["active_gardevoir_core_attack_index"] = int(active_core_attack.get("attack_index", -1))
	snapshot["active_gardevoir_core_attack_name"] = str(active_core_attack.get("attack_name", ""))
	snapshot["active_gardevoir_core_attack_damage"] = int(active_core_attack.get("damage", 0))
	snapshot["gardevoir_engine_online"] = gardevoir_count > 0
	snapshot["kirlia_draw_engine_online"] = kirlia_count > 0
	_last_gardevoir_engine_online = gardevoir_count > 0
	_last_gardevoir_attacker_count = int(snapshot.get("attacker_count", 0))
	_last_gardevoir_ready_attacker_count = int(snapshot.get("ready_attacker_count", 0))
	_last_gardevoir_pressure_ready_attacker_count = int(snapshot.get("pressure_ready_attacker_count", 0))
	_last_gardevoir_active_ready_attacker = bool(snapshot.get("active_gardevoir_attacker_ready", false))
	_last_gardevoir_active_pressure_ready_attacker = bool(snapshot.get("active_gardevoir_attacker_pressure_ready", false))
	_last_gardevoir_ready_bench_attacker_count = int(snapshot.get("ready_bench_gardevoir_attacker_count", 0))
	_last_gardevoir_pressure_ready_bench_attacker_count = int(snapshot.get("pressure_ready_bench_gardevoir_attacker_count", 0))
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


func get_intent_planner_profile() -> Dictionary:
	return {
		"primary_attackers": [DRIFLOON, SCREAM_TAIL, DRIFBLIM],
		"secondary_attackers": [GARDEVOIR_EX],
		"support_only": [RADIANT_GRENINJA, KLEFKI, FLUTTER_MANE, MANAPHY],
		"evolution_lines": [
			{"basic": RALTS, "stages": [KIRLIA, GARDEVOIR_EX], "role": "engine_owner_primary_line", "desired_count": 2, "energy": {"P": 1}},
			{"basic": DRIFLOON, "stages": [DRIFBLIM], "role": "secondary_attacker", "desired_count": 1, "energy": {"P": 1}},
		],
		"energy_needs": {
			RALTS: {"P": 1},
			KIRLIA: {"P": 1},
			GARDEVOIR_EX: {"P": 2},
			DRIFLOON: {"P": 1},
			DRIFBLIM: {"P": 1},
			SCREAM_TAIL: {"P": 1},
			MUNKIDORI: {"D": 1},
		},
		"primary_attacks": [
			{"pokemon": DRIFLOON, "attack": "Balloon Blast"},
			{"pokemon": SCREAM_TAIL, "attack": "Roaring Scream"},
			{"pokemon": DRIFBLIM, "attack": "Balloon Blast"},
		],
		"scaling_attackers": [DRIFLOON, DRIFBLIM, SCREAM_TAIL],
		"setup_draw_attacks": [],
		"low_value_attacks": [{"pokemon": RALTS, "attack": "Memory Skip"}],
	}


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
	lines.append("Replan policy: after Kirlia, Radiant Greninja, Ultra Ball, Arven, Nest Ball, Poffin, Earthen Vessel, Secret Box, Night Stretcher, TM Evolution setup, or Psychic Embrace changes hand, board, or attack access, reassess using the updated legal_actions instead of blindly continuing an old route.")
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
	if action_type == "use_ability" and _ref_has_any_name(ref, [MUNKIDORI, "Adrena-Brain", "亢奋脑力"]):
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
	for raw_index: int in raw_actions.size():
		var raw_action: Variant = raw_actions[raw_index]
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = (raw_action as Dictionary).duplicate(true)
		if _is_low_value_gardevoir_attack_ref(action, game_state, player_index) \
				and not _gardevoir_attack_follows_attacker_handoff(raw_actions, raw_index, game_state, player_index):
			removed_low_value_attack = true
			continue
		if _is_dead_gardevoir_embrace_ref(action, game_state, player_index):
			continue
		if _is_bad_gardevoir_preserve_supporter_ref(action, game_state, player_index):
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
	var attack_now_repair := _gardevoir_attack_now_replacement_for_empty_terminal(pruned_actions, game_state, player_index)
	if not attack_now_repair.is_empty():
		return {"actions": attack_now_repair}
	var pressure_attack_repair := _gardevoir_attack_now_replacement_for_pressure_route(pruned_actions, game_state, player_index)
	if not pressure_attack_repair.is_empty():
		return {"actions": pressure_attack_repair}
	pruned_actions = _gardevoir_insert_bravery_before_pressure_route(pruned_actions, game_state, player_index)
	pruned_actions = _gardevoir_insert_backup_attacker_before_terminal_attack(pruned_actions, game_state, player_index)
	var conversion_candidates := _gardevoir_conversion_candidates_for_route(pruned_actions, game_state, player_index)
	if conversion_candidates.is_empty():
		return {"actions": _gardevoir_reorder_super_rod_before_shuffle_draw(pruned_actions, game_state, player_index)}
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in pruned_actions:
		if not inserted and (
			_is_attack_action_ref(action)
			or _is_end_turn_action_ref(action)
			or _is_unproductive_gardevoir_embrace_ref(action, game_state, player_index)
		):
			result.append_array(conversion_candidates)
			inserted = true
		result.append(action)
	if not inserted:
		result.append_array(conversion_candidates)
	return {"actions": _gardevoir_reorder_super_rod_before_shuffle_draw(result, game_state, player_index)}


func _gardevoir_reorder_super_rod_before_shuffle_draw(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	return _gardevoir_reorder_super_rod_before_recovery_consumer(actions, game_state, player_index)


func _gardevoir_reorder_super_rod_before_recovery_consumer(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if actions.size() < 2 or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return actions
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _gardevoir_discard_has_attacker_body(player):
		return actions
	var super_rod_index := -1
	var consumer_index := -1
	for i: int in actions.size():
		var action: Dictionary = actions[i]
		if super_rod_index < 0 and _ref_has_any_name(action, [SUPER_ROD]):
			super_rod_index = i
		if consumer_index < 0 and _is_gardevoir_recovery_consumer_ref(action):
			consumer_index = i
	if super_rod_index < 0 or consumer_index < 0 or super_rod_index < consumer_index:
		return actions
	var result := actions.duplicate(true)
	var super_rod_action: Dictionary = result[super_rod_index]
	result.remove_at(super_rod_index)
	result.insert(consumer_index, super_rod_action)
	return result


func _is_gardevoir_recovery_consumer_ref(ref: Dictionary) -> bool:
	return _ref_has_any_name(ref, [
		IONO,
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		ARVEN,
		ARTAZON,
		SECRET_BOX,
	])


func _gardevoir_insert_backup_attacker_before_terminal_attack(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	var backup_candidates := _gardevoir_backup_attacker_candidates_for_attack_route(actions, game_state, player_index)
	if backup_candidates.is_empty():
		return actions
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		if not inserted and _is_attack_action_ref(action):
			result.append_array(backup_candidates)
			inserted = true
		result.append(action)
	return result


func _gardevoir_insert_bravery_before_pressure_route(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	var bravery := _gardevoir_bravery_candidate_for_pressure_route(actions, game_state, player_index)
	if bravery.is_empty():
		return actions
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		if not inserted and (
			_is_attack_action_ref(action)
			or str(action.get("type", action.get("kind", ""))) == "retreat"
			or _ref_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"])
		):
			result.append(bravery)
			inserted = true
		result.append(action)
	if not inserted:
		result.append(bravery)
	return result


func _gardevoir_bravery_candidate_for_pressure_route(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	if _gardevoir_route_has_bravery_attach(actions):
		return {}
	if not _gardevoir_route_has_pressure_terminal(actions, game_state, player_index):
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_field_name(player, GARDEVOIR_EX) <= 0:
		return {}
	if not _gardevoir_any_attacker_can_use_bravery(player):
		return {}
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id := str(raw_key)
		if action_id == "":
			continue
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != "attach_tool":
			continue
		if not _ref_has_any_name(ref, [BRAVERY_CHARM]):
			continue
		if _is_bad_gardevoir_tool_attach_ref(ref, game_state, player_index):
			continue
		var copy := ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		copy["type"] = "attach_tool"
		copy["kind"] = "attach_tool"
		copy["route_goal"] = "gardevoir_bravery_before_pressure_attack"
		return copy
	return {}


func _gardevoir_route_has_bravery_attach(actions: Array[Dictionary]) -> bool:
	for action: Dictionary in actions:
		if str(action.get("type", action.get("kind", ""))) == "attach_tool" and _ref_has_any_name(action, [BRAVERY_CHARM]):
			return true
	return false


func _gardevoir_route_has_pressure_terminal(actions: Array[Dictionary], game_state: GameState, player_index: int) -> bool:
	for action: Dictionary in actions:
		if _is_attack_action_ref(action):
			return true
		if str(action.get("type", action.get("kind", ""))) == "retreat" and _ref_has_any_name(action, GARDEVOIR_ATTACKER_NAMES):
			return true
		if _ref_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]) \
				and game_state != null \
				and player_index >= 0 \
				and player_index < game_state.players.size() \
				and _count_attacker_bodies(game_state.players[player_index]) > 0:
			return true
	return false


func _gardevoir_any_attacker_can_use_bravery(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_player_slots(player):
		if slot == null or not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
			continue
		if not _slot_has_tool_name(slot, BRAVERY_CHARM):
			return true
	return false


func _gardevoir_ex_handoff_attack_bridge(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if slot == null or not _slot_name_matches_any(slot, [GARDEVOIR_EX]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var psychic_fuel := _count_psychic_energy_in_discard(player)
	if psychic_fuel <= 0:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	for raw_attack: Variant in cd.attacks:
		if not (raw_attack is Dictionary):
			continue
		var attack: Dictionary = raw_attack
		var damage := _gardevoir_fixed_attack_damage(attack)
		if damage < 120 and (opponent_hp <= 0 or damage < opponent_hp):
			continue
		var missing := _gardevoir_attack_cost_gap(slot, str(attack.get("cost", "")))
		if missing <= 0:
			return true
		if missing > psychic_fuel:
			continue
		var remaining_hp := int(cd.hp) - int(slot.damage_counters)
		if remaining_hp > missing * 20:
			return true
	return false


func _empty_gardevoir_action_refs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	return result


func _gardevoir_attack_now_replacement_for_empty_terminal(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if not _gardevoir_actions_are_empty_or_terminal_end(actions):
		return _empty_gardevoir_action_refs()
	var route := _gardevoir_candidate_attack_now_route()
	if route.is_empty():
		return _empty_gardevoir_action_refs()
	var materialized: Array[Dictionary] = _materialize_candidate_route_actions(route.get("actions", []))
	if materialized.is_empty():
		return _empty_gardevoir_action_refs()
	var has_good_attack := false
	for action: Dictionary in materialized:
		if not _is_attack_action_ref(action):
			continue
		if _is_low_value_gardevoir_attack_ref(action, game_state, player_index):
			return _empty_gardevoir_action_refs()
		has_good_attack = true
	return materialized if has_good_attack else _empty_gardevoir_action_refs()


func _gardevoir_attack_now_replacement_for_pressure_route(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if _gardevoir_actions_have_attack(actions):
		return _empty_gardevoir_action_refs()
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return _empty_gardevoir_action_refs()
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index):
		return _empty_gardevoir_action_refs()
	if _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return _empty_gardevoir_action_refs()
	var route := _gardevoir_candidate_attack_now_route()
	if route.is_empty():
		return _empty_gardevoir_action_refs()
	var materialized: Array[Dictionary] = _materialize_candidate_route_actions(route.get("actions", []))
	var attack_actions: Array[Dictionary] = []
	for action: Dictionary in materialized:
		if not _is_attack_action_ref(action):
			continue
		if _is_low_value_gardevoir_attack_ref(action, game_state, player_index):
			continue
		attack_actions.append(action)
	if attack_actions.is_empty():
		return _empty_gardevoir_action_refs()
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		if _is_end_turn_action_ref(action):
			if not inserted:
				result.append_array(attack_actions)
				inserted = true
			result.append(action)
			continue
		if _gardevoir_pressure_route_action_can_precede_attack(action, game_state, player_index):
			result.append(action)
	if not inserted:
		result.append_array(attack_actions)
	return result


func _gardevoir_actions_have_attack(actions: Array[Dictionary]) -> bool:
	for action: Dictionary in actions:
		if _is_attack_action_ref(action):
			return true
	return false


func _gardevoir_pressure_route_action_can_precede_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_end_turn_action_ref(action):
		return false
	var action_type := str(action.get("type", action.get("kind", "")))
	if action_type == "attach_tool":
		return not _is_bad_gardevoir_tool_attach_ref(action, game_state, player_index)
	if action_type == "use_ability" and _ref_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]):
		return _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index)
	return false


func _gardevoir_actions_are_empty_or_terminal_end(actions: Array[Dictionary]) -> bool:
	if actions.is_empty():
		return true
	for action: Dictionary in actions:
		if not _is_end_turn_action_ref(action):
			return false
	return true


func _gardevoir_candidate_attack_now_route() -> Dictionary:
	for raw_key: Variant in _llm_route_candidates_by_id.keys():
		var route: Dictionary = _llm_route_candidates_by_id.get(raw_key, {}) if _llm_route_candidates_by_id.get(raw_key, {}) is Dictionary else {}
		if route.is_empty():
			continue
		var route_id := str(route.get("id", route.get("route_action_id", "")))
		var goal := str(route.get("goal", ""))
		if goal == "attack" or route_id.contains("attack_now"):
			return route
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty():
			continue
		if not _is_attack_action_ref(ref):
			continue
		return {
			"route_action_id": "route:gardevoir_catalog_attack_now",
			"id": "gardevoir_catalog_attack_now",
			"goal": "attack",
			"actions": [{"id": str(ref.get("id", ref.get("action_id", raw_key)))}],
		}
	return {}


func _is_low_value_gardevoir_attack_ref(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if _is_tm_evolution_granted_attack_ref(action, game_state, player_index):
		return false
	if _is_dangerous_gardevoir_core_pivot_attack(action, game_state, player_index):
		return true
	if _deck_is_low_value_runtime_attack_action(action, game_state, player_index):
		if _gardevoir_active_is_attacker(game_state, player_index) or _has_visible_gardevoir_setup(game_state, player_index):
			return true
		return _gardevoir_engine_or_attacker_exists(game_state, player_index)
	return false


func _gardevoir_attack_follows_attacker_handoff(actions: Array, attack_index: int, game_state: GameState, player_index: int) -> bool:
	if attack_index <= 0:
		return false
	var limit: int = min(attack_index, actions.size())
	for i: int in limit:
		var raw_action: Variant = actions[i]
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action as Dictionary
		if str(action.get("type", action.get("kind", ""))) != "retreat":
			continue
		var target_slot := _ref_retreat_target_slot(action, game_state, player_index)
		if target_slot != null and _slot_name_matches_any(target_slot, GARDEVOIR_ATTACKER_NAMES):
			return true
		if _ref_has_any_name(action, GARDEVOIR_ATTACKER_NAMES):
			return true
	return false


func _gardevoir_engine_or_attacker_exists(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	return _count_field_name(player, GARDEVOIR_EX) > 0 or _count_attacker_bodies(player) > 0


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
		return _empty_gardevoir_action_refs()
	var seen_ids: Dictionary = {}
	for action: Dictionary in actions:
		var action_id := str(action.get("action_id", action.get("id", "")))
		if action_id != "":
			seen_ids[action_id] = true
	var candidates: Array[Dictionary] = []
	var local_seen := seen_ids.duplicate(true)
	var player: PlayerState = game_state.players[player_index]
	if _gardevoir_active_embrace_attack_setup_needed(game_state, player_index):
		_append_gardevoir_active_attack_charge_catalog(candidates, local_seen, game_state, player_index)
	elif _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index) and not _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index):
		_append_gardevoir_handoff_catalog(candidates, local_seen, game_state, player_index)
	elif _count_attacker_bodies(player) > 0 and _count_pressure_ready_attackers(player, game_state, player_index) == 0:
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
	if player == null:
		return false
	if _count_ready_attackers(player) > 0:
		if _count_pressure_ready_attackers(player, game_state, player_index) <= 0:
			return _count_psychic_energy_in_discard(player) > 0 or _catalog_has_gardevoir_handoff_action()
		return not _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index) and _catalog_has_gardevoir_handoff_action()
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


func _gardevoir_backup_attacker_candidates_for_attack_route(actions: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if not _gardevoir_actions_have_attack(actions):
		return _empty_gardevoir_action_refs()
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return _empty_gardevoir_action_refs()
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_field_name(player, GARDEVOIR_EX) <= 0:
		return _empty_gardevoir_action_refs()
	if not _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES):
		return _empty_gardevoir_action_refs()
	if _count_attacker_bodies(player) > 1:
		return _empty_gardevoir_action_refs()
	if _gardevoir_bench_slots_remaining(player) <= 0:
		return _empty_gardevoir_action_refs()
	var seen_ids: Dictionary = {}
	for action: Dictionary in actions:
		var action_id := str(action.get("action_id", action.get("id", "")))
		if action_id != "":
			seen_ids[action_id] = true
	var candidates: Array[Dictionary] = []
	var local_seen := seen_ids.duplicate(true)
	_append_gardevoir_backup_attacker_catalog(candidates, local_seen)
	var result: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if result.size() >= 1:
			break
		var candidate_id := str(candidate.get("action_id", candidate.get("id", "")))
		if candidate_id == "" or bool(seen_ids.get(candidate_id, false)):
			continue
		if _candidate_conflicts_with_route(candidate, actions):
			continue
		result.append(candidate)
	return result


func _is_unproductive_gardevoir_embrace_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(ref.get("type", ref.get("kind", ""))) != "use_ability":
		return false
	if not _ref_has_any_name(ref, [GARDEVOIR_EX, "Psychic Embrace"]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) == 0:
		return false
	if _gardevoir_active_embrace_attack_setup_needed(game_state, player_index):
		return false
	if _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index) and not _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return true
	if _count_attacker_bodies(player) > 0:
		return false
	return not _gardevoir_active_embrace_retreat_bridge_live(player)


func _is_dead_gardevoir_embrace_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(ref.get("type", ref.get("kind", ""))) != "use_ability":
		return false
	if not _ref_has_any_name(ref, [GARDEVOIR_EX, "Psychic Embrace"]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_field_name(player, GARDEVOIR_EX) == 0:
		return false
	return _count_psychic_energy_in_discard(player) <= 0


func _is_unproductive_gardevoir_embrace_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "use_ability":
		return false
	if not _runtime_action_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) == 0:
		return false
	if _gardevoir_active_embrace_attack_setup_needed(game_state, player_index):
		return false
	if _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index) and not _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return true
	if _count_attacker_bodies(player) > 0:
		return false
	return not _gardevoir_active_embrace_retreat_bridge_live(player)


func _is_dead_gardevoir_embrace_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "use_ability":
		return false
	if not _runtime_action_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_field_name(player, GARDEVOIR_EX) == 0:
		return false
	return _count_psychic_energy_in_discard(player) <= 0


func _deck_is_low_value_runtime_attack_action(_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if _is_tm_evolution_granted_attack_ref(_action, game_state, player_index):
		return false
	if _is_dangerous_gardevoir_core_pivot_attack(_action, game_state, player_index):
		return true
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or active.get_card_data() == null:
		return false
	if _gardevoir_runtime_attack_kos_opponent(active, _action, game_state, player_index):
		return false
	var name := _slot_best_name(active)
	if _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
		return _is_low_value_gardevoir_attacker_attack(_action, active, game_state, player_index)
	return int(predict_attacker_damage(active).get("damage", 0)) < 120 and _name_matches_any(name, GARDEVOIR_CORE_NAMES + GARDEVOIR_SUPPORT_NAMES)


func _is_low_value_gardevoir_attacker_attack(action: Dictionary, active: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	var attack_index := _attack_index_from_ref(action)
	if active == null or active.get_card_data() == null:
		return false
	if attack_index > 0:
		var attacks_for_index: Array = active.get_card_data().attacks
		var attack_for_index: Dictionary = attacks_for_index[attack_index] if attack_index < attacks_for_index.size() and attacks_for_index[attack_index] is Dictionary else {}
		if _gardevoir_attack_uses_self_damage_scaling(active, attack_for_index) and _gardevoir_current_attacker_damage_estimate(active) <= 0:
			return true
		return _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index)
	if attack_index != 0:
		return false
	var attacks: Array = active.get_card_data().attacks
	if attacks.size() < 2:
		return false
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index):
			return true
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


func _active_gardevoir_attacker_needs_more_embrace_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return false
	if not _slot_has_ready_gardevoir_attack(active):
		return false
	if _count_field_name(player, GARDEVOIR_EX) <= 0 or _count_psychic_energy_in_discard(player) <= 0:
		return false
	if _gardevoir_effective_remaining_hp(active, game_state) <= 20:
		return false
	var predicted := _gardevoir_current_attacker_damage_estimate(active)
	if predicted <= 0:
		predicted = _gardevoir_embrace_damage_estimate(active, 0)
	if predicted <= 0:
		return false
	var opponent_index := 1 - player_index
	if opponent_index >= 0 and opponent_index < game_state.players.size():
		var opponent_active: PokemonSlot = game_state.players[opponent_index].active_pokemon
		if opponent_active != null:
			var opponent_hp := _gardevoir_effective_remaining_hp(opponent_active, game_state)
			if predicted >= opponent_hp:
				return false
			var next_embrace_damage := _gardevoir_embrace_damage_estimate(active, 1)
			if _gardevoir_slot_can_take_visible_prize_with_damage(active, game_state, player_index, predicted):
				return false
			if _gardevoir_slot_can_take_visible_prize_with_damage(active, game_state, player_index, next_embrace_damage):
				return true
			if next_embrace_damage >= opponent_hp:
				return true
			var next_damage_gain := next_embrace_damage - predicted
			if _gardevoir_effective_remaining_hp(active, game_state) > 20 \
					and next_embrace_damage > predicted \
					and (predicted < 120 or next_damage_gain >= 60):
				return true
	if predicted >= 120:
		return false
	return true


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_gardevoir_setup_or_resource_card(card_data)


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) not in ["attack", "granted_attack"]:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null:
		return false
	if _gardevoir_runtime_attack_kos_opponent(active, action, game_state, player_index):
		return true
	if not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
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
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player != null:
		if _gardevoir_active_embrace_retreat_setup_needed(player, game_state):
			return true
		if _gardevoir_active_embrace_attack_setup_needed(game_state, player_index):
			return true
		if _gardevoir_active_core_attack_ready(game_state, player_index):
			return true
		if _active_is_productive_ready_gardevoir_attacker(player, game_state, player_index):
			return true
		if _active_is_ready_gardevoir_attacker(player):
			var active_damage := _gardevoir_current_attacker_damage_estimate(player.active_pokemon)
			if active_damage >= 80:
				return true
		if _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index) \
				and not _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
			return true
		if _gardevoir_active_attacker_manual_attach_pressure_available(game_state, player_index):
			return true
		if _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index) \
				and not _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index):
			return true
	return _has_visible_gardevoir_setup(game_state, player_index)


func _deck_should_skip_llm_for_local_rules(game_state: GameState, player_index: int, legal_actions: Array) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var productive: Array[Dictionary] = []
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		if str(action.get("kind", action.get("type", ""))) == "end_turn":
			continue
		productive.append(action)
	if productive.size() != 1:
		return false
	var only_action: Dictionary = productive[0]
	var kind := str(only_action.get("kind", only_action.get("type", "")))
	if kind in ["attack", "granted_attack"]:
		return _deck_is_high_pressure_attack_action(only_action, game_state, player_index) \
			or _is_gardevoir_runtime_attack_conversion(only_action, game_state, player_index)
	if kind == "use_ability":
		if _runtime_action_has_any_name(only_action, [GARDEVOIR_EX, "Psychic Embrace"]):
			var player: PlayerState = game_state.players[player_index]
			return player != null and (
				_count_attacker_bodies(player) > 0
				or _gardevoir_active_embrace_retreat_bridge_live(player)
				or _gardevoir_active_embrace_attack_setup_needed(game_state, player_index)
			)
	return false


func _deck_queue_item_matches_action(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_attack_action_ref(queued_action) and str(runtime_action.get("kind", runtime_action.get("type", ""))) == "granted_attack":
		return _gardevoir_tm_evolution_queue_attack_matches_runtime(queued_action, runtime_action, game_state, player_index)
	return false


func _gardevoir_tm_evolution_queue_attack_matches_runtime(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if not _runtime_granted_attack_has_tm_evolution_source(runtime_action, player.active_pokemon):
		return false
	var queued_name := str(queued_action.get("attack_name", "")).strip_edges()
	if queued_name == "":
		return true
	var granted_name := _runtime_granted_attack_name(runtime_action)
	if granted_name == "":
		return true
	return _name_contains(granted_name, queued_name) or _name_contains(queued_name, granted_name)


func _runtime_granted_attack_has_tm_evolution_source(runtime_action: Dictionary, active_slot: PokemonSlot) -> bool:
	var raw_pokemon: Variant = runtime_action.get("pokemon", null)
	if raw_pokemon is PokemonSlot:
		return raw_pokemon == active_slot and _slot_has_tool_name(raw_pokemon as PokemonSlot, TM_EVOLUTION)
	if raw_pokemon is Dictionary:
		var raw_tool: Variant = (raw_pokemon as Dictionary).get("tool", (raw_pokemon as Dictionary).get("attached_tool", {}))
		if raw_tool is Dictionary:
			var tool_dict: Dictionary = raw_tool
			return _name_contains(str(tool_dict.get("name_en", tool_dict.get("name", ""))), TM_EVOLUTION)
		return _name_contains(str(raw_tool), TM_EVOLUTION)
	return _slot_has_tool_name(active_slot, TM_EVOLUTION)


func _runtime_granted_attack_name(runtime_action: Dictionary) -> String:
	var raw_granted: Variant = runtime_action.get("granted_attack_data", {})
	if raw_granted is Dictionary:
		var granted: Dictionary = raw_granted
		var name := str(granted.get("name", "")).strip_edges()
		if name != "":
			return name
	var attack_name := str(runtime_action.get("attack_name", "")).strip_edges()
	if attack_name != "":
		return attack_name
	return ""


func _deck_snapshot_has_live_terminal_conversion(snapshot: Dictionary) -> bool:
	if bool(snapshot.get("active_gardevoir_core_attack_ready", false)):
		return true
	if bool(snapshot.get("active_gardevoir_attacker_pressure_ready", false)) \
			and not bool(snapshot.get("active_gardevoir_attacker_needs_more_embrace_pressure", false)):
		return true
	return _gardevoir_snapshot_has_bench_handoff_conversion(snapshot)


func _deck_replan_trigger_after_state_change(before_snapshot: Dictionary, after_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var action_kind := str(context.get("action_kind", ""))
	if action_kind in ["attach_energy", "attach_tool"] and bool(after_snapshot.get("active_tm_evolution_bridge_ready", false)):
		var bridge_changed := not bool(before_snapshot.get("active_tm_evolution_bridge_ready", false)) \
			or int(before_snapshot.get("active_energy_count", 0)) != int(after_snapshot.get("active_energy_count", 0)) \
			or bool(before_snapshot.get("active_has_tm_evolution", false)) != bool(after_snapshot.get("active_has_tm_evolution", false))
		if bridge_changed:
			return {
				"should_replan": true,
				"reason": "gardevoir_tm_evolution_bridge_action_surface_changed",
				"ignore_replan_limit": true,
				"before_active_energy_count": int(before_snapshot.get("active_energy_count", 0)),
				"after_active_energy_count": int(after_snapshot.get("active_energy_count", 0)),
				"before_active_has_tm_evolution": bool(before_snapshot.get("active_has_tm_evolution", false)),
				"after_active_has_tm_evolution": bool(after_snapshot.get("active_has_tm_evolution", false)),
			}
	if action_kind in ["retreat", "attach_energy", "attach_tool"] \
			and bool(after_snapshot.get("active_gardevoir_attacker_pressure_ready", false)) \
			and not bool(after_snapshot.get("active_gardevoir_attacker_needs_more_embrace_pressure", false)):
		var conversion_changed := action_kind == "retreat" \
			or not bool(before_snapshot.get("active_gardevoir_attacker_pressure_ready", false)) \
			or int(before_snapshot.get("active_gardevoir_attacker_damage", 0)) != int(after_snapshot.get("active_gardevoir_attacker_damage", 0)) \
			or int(before_snapshot.get("active_gardevoir_attacker_energy_count", 0)) != int(after_snapshot.get("active_gardevoir_attacker_energy_count", 0))
		if conversion_changed:
			return {
				"should_replan": true,
				"reason": "gardevoir_active_attacker_terminal_conversion_ready",
				"ignore_replan_limit": false,
				"action_kind": action_kind,
				"active_gardevoir_attacker_name": str(after_snapshot.get("active_gardevoir_attacker_name", "")),
				"active_gardevoir_attacker_damage": int(after_snapshot.get("active_gardevoir_attacker_damage", 0)),
				"active_gardevoir_attacker_energy_count": int(after_snapshot.get("active_gardevoir_attacker_energy_count", 0)),
			}
	var priority_hand_gains := _gardevoir_priority_hand_gains(before_snapshot, after_snapshot)
	if not priority_hand_gains.is_empty() and _gardevoir_priority_gain_needs_replan(after_snapshot, priority_hand_gains):
		return {
			"should_replan": true,
			"reason": "gardevoir_priority_hand_gain",
			"ignore_replan_limit": true,
			"gained_priority_cards": priority_hand_gains,
			"action_kind": action_kind,
			"action_card_name": str(context.get("action_card_name", "")),
		}
	if action_kind != "use_ability":
		return {"should_replan": false}
	if not (bool(before_snapshot.get("gardevoir_engine_online", false)) or bool(after_snapshot.get("gardevoir_engine_online", false))):
		return {"should_replan": false}
	var before_core_ready := bool(before_snapshot.get("active_gardevoir_core_attack_ready", false))
	var after_core_ready := bool(after_snapshot.get("active_gardevoir_core_attack_ready", false))
	if after_core_ready and (
		before_core_ready != after_core_ready
		or int(before_snapshot.get("active_gardevoir_core_attack_damage", 0)) != int(after_snapshot.get("active_gardevoir_core_attack_damage", 0))
	):
		return {
			"should_replan": true,
			"reason": "gardevoir_active_core_attack_conversion_ready",
			"ignore_replan_limit": false,
			"active_gardevoir_core_attack_name": str(after_snapshot.get("active_gardevoir_core_attack_name", "")),
			"active_gardevoir_core_attack_damage": int(after_snapshot.get("active_gardevoir_core_attack_damage", 0)),
		}
	var before_active_ready := bool(before_snapshot.get("active_gardevoir_attacker_ready", false))
	var after_active_ready := bool(after_snapshot.get("active_gardevoir_attacker_ready", false))
	var before_active_damage := int(before_snapshot.get("active_gardevoir_attacker_damage", 0))
	var after_active_damage := int(after_snapshot.get("active_gardevoir_attacker_damage", 0))
	var before_active_attacker_energy := int(before_snapshot.get("active_gardevoir_attacker_energy_count", 0))
	var after_active_attacker_energy := int(after_snapshot.get("active_gardevoir_attacker_energy_count", 0))
	if after_active_ready and (
		before_active_ready != after_active_ready
		or after_active_damage > before_active_damage
		or after_active_attacker_energy != before_active_attacker_energy
	):
		if not (
			bool(after_snapshot.get("active_gardevoir_attacker_pressure_ready", false))
			and not bool(after_snapshot.get("active_gardevoir_attacker_needs_more_embrace_pressure", false))
		):
			return {"should_replan": false}
		return {
			"should_replan": true,
			"reason": "gardevoir_active_attacker_conversion_changed",
			"ignore_replan_limit": false,
			"before_active_gardevoir_attacker_ready": before_active_ready,
			"after_active_gardevoir_attacker_ready": after_active_ready,
			"before_active_gardevoir_attacker_damage": before_active_damage,
			"after_active_gardevoir_attacker_damage": after_active_damage,
			"before_active_gardevoir_attacker_energy_count": before_active_attacker_energy,
			"after_active_gardevoir_attacker_energy_count": after_active_attacker_energy,
			"active_gardevoir_attacker_name": str(after_snapshot.get("active_gardevoir_attacker_name", "")),
		}
	var before_psychic := int(before_snapshot.get("psychic_energy_discard_count", -1))
	var after_psychic := int(after_snapshot.get("psychic_energy_discard_count", -1))
	var before_ready := int(before_snapshot.get("ready_attacker_count", -1))
	var after_ready := int(after_snapshot.get("ready_attacker_count", -1))
	var before_gap := int(before_snapshot.get("active_retreat_gap", 99))
	var after_gap := int(after_snapshot.get("active_retreat_gap", 99))
	if before_psychic != after_psychic or before_ready != after_ready or before_gap != after_gap:
		if not _deck_snapshot_has_live_terminal_conversion(after_snapshot):
			return {"should_replan": false}
		return {
			"should_replan": true,
			"reason": "gardevoir_embrace_opened_terminal_conversion",
			"before_psychic_discard": before_psychic,
			"after_psychic_discard": after_psychic,
			"before_ready_attacker_count": before_ready,
			"after_ready_attacker_count": after_ready,
			"before_active_retreat_gap": before_gap,
			"after_active_retreat_gap": after_gap,
			"ignore_replan_limit": false,
		}
	return {"should_replan": false}


func _deck_pruned_live_terminal_conversion_queue(snapshot: Dictionary, remaining_queue: Array[Dictionary]) -> Array[Dictionary]:
	var active_core_attack: Dictionary = _gardevoir_active_core_attack_ref_from_snapshot(snapshot)
	if not active_core_attack.is_empty():
		var core_result: Array[Dictionary] = [active_core_attack]
		for core_action: Dictionary in remaining_queue:
			if _is_end_turn_action_ref(core_action):
				core_result.append(core_action)
				return core_result
		core_result.append({"type": "end_turn", "kind": "end_turn", "id": "end_turn", "action_id": "end_turn", "capability": "end_turn"})
		return core_result
	var handoff_retreat: Dictionary = _gardevoir_handoff_retreat_ref_from_catalog_snapshot(snapshot)
	if not handoff_retreat.is_empty():
		var handoff_result: Array[Dictionary] = [
			handoff_retreat,
			{
				"type": "attack",
				"kind": "attack",
				"capability": "attack",
				"attack_index": 1,
				"route_goal": "bench_gardevoir_pressure_handoff",
			},
		]
		for handoff_action: Dictionary in remaining_queue:
			if _is_end_turn_action_ref(handoff_action):
				handoff_result.append(handoff_action)
				return handoff_result
		handoff_result.append({"type": "end_turn", "kind": "end_turn", "id": "end_turn", "action_id": "end_turn", "capability": "end_turn"})
		return handoff_result
	if not bool(snapshot.get("active_gardevoir_attacker_pressure_ready", false)):
		return _empty_gardevoir_action_refs()
	if bool(snapshot.get("active_gardevoir_attacker_needs_more_embrace_pressure", false)):
		return _empty_gardevoir_action_refs()
	var result: Array[Dictionary] = [
		{
			"type": "attack",
			"kind": "attack",
			"capability": "attack",
			"attack_index": 1,
			"route_goal": "active_gardevoir_pressure_conversion",
		},
	]
	for action: Dictionary in remaining_queue:
		if _is_end_turn_action_ref(action):
			result.append(action)
			return result
	result.append({"type": "end_turn", "kind": "end_turn", "id": "end_turn", "action_id": "end_turn", "capability": "end_turn"})
	return result


func _gardevoir_handoff_retreat_ref_from_catalog_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _gardevoir_snapshot_has_bench_handoff_conversion(snapshot):
		return {}
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id := str(raw_key)
		if action_id == "":
			continue
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		if str(ref.get("type", ref.get("kind", ""))) != "retreat":
			continue
		if not _ref_has_any_name(ref, GARDEVOIR_ATTACKER_NAMES):
			continue
		var copy := ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		copy["type"] = "retreat"
		copy["kind"] = "retreat"
		copy["capability"] = "pivot_to_attack"
		copy["route_goal"] = "bench_gardevoir_pressure_handoff" if int(snapshot.get("pressure_ready_bench_gardevoir_attacker_count", 0)) > 0 else "bench_gardevoir_ready_chip_handoff"
		return copy
	return {}


func _gardevoir_snapshot_has_bench_handoff_conversion(snapshot: Dictionary) -> bool:
	if int(snapshot.get("active_retreat_gap", 99)) > 0:
		return false
	if int(snapshot.get("pressure_ready_bench_gardevoir_attacker_count", 0)) > 0:
		return true
	if int(snapshot.get("ready_bench_gardevoir_attacker_count", 0)) <= 0:
		return false
	var active_name := str(snapshot.get("active_slot_name", ""))
	return _name_matches_any(active_name, [RALTS, KIRLIA, KLEFKI])


func _deck_escape_action_bypasses_replan_limit(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "use_ability" and _runtime_action_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]):
		return _gardevoir_has_live_terminal_conversion(game_state, player_index)
	if kind == "retreat" and game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if player != null and _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES):
			return _active_is_productive_ready_gardevoir_attacker(player, game_state, player_index)
	return false


func _gardevoir_has_live_terminal_conversion(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _gardevoir_active_core_attack_ready(game_state, player_index):
		return true
	if _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index) \
			and not _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return true
	return _gardevoir_active_embrace_retreat_bridge_live(player) and _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index)


func _gardevoir_priority_hand_gains(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array[String]:
	var before_counts := _gardevoir_name_count_dict(before_snapshot.get("hand_names", []))
	var result: Array[String] = []
	var seen: Dictionary = {}
	for raw_name: Variant in after_snapshot.get("hand_names", []):
		var name := str(raw_name).strip_edges()
		if name == "" or bool(seen.get(name, false)):
			continue
		var after_count := _gardevoir_name_occurrences(after_snapshot.get("hand_names", []), name)
		if after_count <= int(before_counts.get(name, 0)):
			continue
		if _name_matches_any(name, [
			RALTS,
			KIRLIA,
			GARDEVOIR_EX,
			DRIFLOON,
			SCREAM_TAIL,
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
			BRAVERY_CHARM,
			PSYCHIC_ENERGY,
		]):
			result.append(name)
			seen[name] = true
	return result


func _gardevoir_priority_gain_needs_replan(snapshot: Dictionary, gained_names: Array[String]) -> bool:
	var engine_online := bool(snapshot.get("gardevoir_engine_online", false))
	var attacker_count := int(snapshot.get("attacker_count", 0))
	var ready_attacker_count := int(snapshot.get("ready_attacker_count", 0))
	var kirlia_count := int(snapshot.get("kirlia_count", 0))
	var ralts_count := int(snapshot.get("ralts_count", 0))
	for name: String in gained_names:
		if _name_matches_any(name, [DRIFLOON, SCREAM_TAIL, NIGHT_STRETCHER, BRAVERY_CHARM]):
			return engine_online or attacker_count == 0
		if _name_matches_any(name, [GARDEVOIR_EX, RARE_CANDY]):
			return kirlia_count > 0 or ralts_count > 0
		if _name_matches_any(name, [KIRLIA, TM_EVOLUTION]):
			return ralts_count > 0
		if _name_matches_any(name, [BUDDY_BUDDY_POFFIN, NEST_BALL, ULTRA_BALL, ARVEN, ARTAZON, SECRET_BOX]):
			return attacker_count == 0 or not engine_online
		if _name_matches_any(name, [PSYCHIC_ENERGY]):
			return engine_online and ready_attacker_count == 0
	return false


func _gardevoir_name_count_dict(raw_names: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if not (raw_names is Array):
		return counts
	for raw_name: Variant in raw_names:
		var name := str(raw_name).strip_edges()
		if name == "":
			continue
		counts[name] = int(counts.get(name, 0)) + 1
	return counts


func _gardevoir_name_occurrences(raw_names: Variant, query: String) -> int:
	if not (raw_names is Array):
		return 0
	var count := 0
	for raw_name: Variant in raw_names:
		if str(raw_name).strip_edges() == query:
			count += 1
	return count


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["attack", "granted_attack"]:
		return _is_gardevoir_runtime_attack_conversion(action, game_state, player_index)
	if kind == "use_ability" and _runtime_action_has_any_name(action, [MUNKIDORI, "Adrena-Brain", "亢奋脑力"]):
		return _gardevoir_munkidori_has_damage_transfer_value(game_state, player_index)
	if kind == "use_ability" and _runtime_action_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"]):
		var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
		return _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index) \
			or _gardevoir_active_embrace_retreat_setup_needed(player, game_state) \
			or _gardevoir_active_embrace_attack_setup_needed(game_state, player_index)
	if _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return false
	return _is_gardevoir_runtime_setup_action(action, game_state, player_index)


func _is_gardevoir_runtime_attack_conversion(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if _gardevoir_runtime_attack_kos_opponent(player.active_pokemon, action, game_state, player_index):
		return true
	if _gardevoir_active_core_attack_ready(game_state, player_index) and _gardevoir_runtime_attack_matches_active_core_conversion(action, game_state, player_index):
		return true
	if not _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES):
		return false
	if _is_low_value_gardevoir_attack_ref(action, game_state, player_index):
		return false
	return _slot_has_ready_gardevoir_attack(player.active_pokemon)


func _gardevoir_runtime_attack_kos_opponent(active: PokemonSlot, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if active == null:
		return false
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	if opponent_hp <= 0:
		return false
	var cd: CardData = active.get_card_data()
	if cd == null:
		return false
	var attack_index := int(action.get("attack_index", -1))
	if attack_index >= 0 and attack_index < cd.attacks.size():
		var attack: Dictionary = cd.attacks[attack_index] if cd.attacks[attack_index] is Dictionary else {}
		if _gardevoir_attack_ref_can_ko_with_current_energy(active, attack, opponent_hp):
			return true
		if _gardevoir_attack_uses_self_damage_scaling(active, attack):
			return _gardevoir_current_attacker_damage_estimate(active) >= opponent_hp
		return false
	var predicted: Dictionary = predict_attacker_damage(active)
	if bool(predicted.get("can_attack", false)) and int(predicted.get("damage", 0)) >= opponent_hp:
		return true
	for raw_attack: Variant in cd.attacks:
		var attack_dict: Dictionary = raw_attack if raw_attack is Dictionary else {}
		if _gardevoir_attack_ref_can_ko_with_current_energy(active, attack_dict, opponent_hp):
			return true
	return false


func _gardevoir_attack_ref_can_ko_with_current_energy(active: PokemonSlot, attack: Dictionary, opponent_hp: int) -> bool:
	if active == null or attack.is_empty() or opponent_hp <= 0:
		return false
	if _gardevoir_attack_cost_gap(active, str(attack.get("cost", ""))) > 0:
		return false
	var damage := int(str(attack.get("damage", "0")).to_int())
	return damage >= opponent_hp


func _gardevoir_attack_uses_self_damage_scaling(active: PokemonSlot, attack: Dictionary) -> bool:
	if active == null or attack.is_empty():
		return false
	if not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return false
	var text := ("%s %s %s" % [
		str(attack.get("name", "")),
		str(attack.get("damage", "")),
		str(attack.get("text", "")),
	]).to_lower()
	return (
		text.contains("damage counter")
		or text.contains("damage counters")
		or text.contains("伤害指示物")
		or text.contains("放置的伤害")
		or text.contains("气球")
		or text.contains("凶暴")
	)


func _deck_should_block_exact_queue_match(_queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(runtime_action.get("kind", runtime_action.get("type", "")))
	if kind in ["attack", "granted_attack"]:
		if _is_bad_gardevoir_tm_evolution_attack_ref(runtime_action, game_state, player_index):
			return true
		if _is_dangerous_gardevoir_core_pivot_attack(runtime_action, game_state, player_index):
			return true
		if _deck_is_low_value_runtime_attack_action(runtime_action, game_state, player_index):
			if _gardevoir_active_is_attacker(game_state, player_index) or _has_visible_gardevoir_setup(game_state, player_index):
				return true
			return _gardevoir_engine_or_attacker_exists(game_state, player_index)
		return false
	if kind == "use_ability":
		if _is_bad_gardevoir_munkidori_ability(runtime_action, game_state, player_index):
			return true
		if _is_dead_gardevoir_embrace_action(runtime_action, game_state, player_index):
			return true
		if _is_unproductive_gardevoir_embrace_action(runtime_action, game_state, player_index):
			return true
		return _is_bad_gardevoir_deck_draw_ability(runtime_action, game_state, player_index)
	if kind == "play_basic_to_bench":
		return _is_bad_gardevoir_support_bench(runtime_action, game_state, player_index)
	if kind == "attach_energy":
		return _is_bad_gardevoir_manual_attach(runtime_action, game_state, player_index)
	if kind == "evolve":
		return _is_bad_gardevoir_evolve(runtime_action, game_state, player_index)
	if kind == "play_trainer":
		if _is_dead_gardevoir_gust_action(runtime_action):
			return true
		if _is_bad_gardevoir_basic_search_action(runtime_action, game_state, player_index):
			return true
		if _is_bad_gardevoir_premature_recovery_action(runtime_action, game_state, player_index):
			return true
		if _is_bad_gardevoir_preserve_supporter_action(runtime_action, game_state, player_index):
			return true
		if _is_bad_gardevoir_costly_ultra_ball_action(runtime_action, game_state, player_index):
			return true
	if kind == "use_stadium_effect" and _is_bad_gardevoir_basic_search_action(runtime_action, game_state, player_index):
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
	if _last_gardevoir_pressure_ready_bench_attacker_count > 0 and not _last_gardevoir_active_pressure_ready_attacker:
		_append_gardevoir_handoff_catalog(target, seen_ids)
	if _last_gardevoir_engine_online and _last_gardevoir_attacker_count > 0 and _last_gardevoir_pressure_ready_attacker_count == 0:
		_append_gardevoir_attacker_charge_catalog(target, seen_ids)
	elif _gardevoir_route_has_engine_conversion(_actions):
		if _last_gardevoir_attacker_count > 0 and _last_gardevoir_pressure_ready_attacker_count == 0:
			_append_gardevoir_attacker_charge_catalog(target, seen_ids)
		else:
			_append_gardevoir_prize_conversion_catalog(target, seen_ids)
	_append_gardevoir_setup_catalog(target, seen_ids, has_attack, _no_deck_draw_lock)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_gardevoir_setup_or_resource_card(card_data)


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var removed_action_ids: Dictionary = {}
	payload["legal_actions"] = _filter_gardevoir_payload_action_refs(payload.get("legal_actions", []), game_state, player_index, removed_action_ids)
	payload["future_actions"] = _filter_gardevoir_payload_action_refs(payload.get("future_actions", []), game_state, player_index, removed_action_ids)
	payload["legal_action_groups"] = _filter_gardevoir_payload_groups(payload.get("legal_action_groups", {}), removed_action_ids)
	payload["candidate_routes"] = _filter_gardevoir_candidate_routes(payload.get("candidate_routes", []), removed_action_ids)
	payload["turn_tactical_facts"] = _filter_gardevoir_tactical_facts(payload.get("turn_tactical_facts", {}), removed_action_ids)
	_remove_gardevoir_filtered_catalog_refs(removed_action_ids)
	return payload


func _remove_gardevoir_filtered_catalog_refs(removed_action_ids: Dictionary) -> void:
	for raw_action_id: Variant in removed_action_ids.keys():
		var action_id := str(raw_action_id)
		if action_id != "":
			_llm_action_catalog.erase(action_id)


func _filter_gardevoir_payload_action_refs(raw_actions: Variant, game_state: GameState, player_index: int, removed_action_ids: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_actions is Array):
		return result
	for raw_action: Variant in raw_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = (raw_action as Dictionary).duplicate(true)
		var action_id := str(action.get("action_id", action.get("id", "")))
		if _is_bad_gardevoir_payload_action_ref(action, game_state, player_index):
			if action_id != "":
				removed_action_ids[action_id] = true
			continue
		action = _normalize_gardevoir_payload_action_ref(action)
		result.append(action)
	return result


func _normalize_gardevoir_payload_action_ref(ref: Dictionary) -> Dictionary:
	var result := ref.duplicate(true)
	var action_type := str(result.get("type", result.get("kind", "")))
	if action_type == "use_ability" and _ref_has_any_name(result, [GARDEVOIR_EX, "Psychic Embrace"]):
		result["interaction_schema"] = _psychic_embrace_interaction_schema()
		result["interactions"] = _psychic_embrace_interactions()
	if action_type == "use_ability" and _ref_has_any_name(result, [MUNKIDORI, "Adrena-Brain", "亢奋脑力"]):
		result["interaction_schema"] = _munkidori_interaction_schema()
		result["interactions"] = _munkidori_interactions()
	return result


func _psychic_embrace_interaction_schema() -> Dictionary:
	return {
		"psychic_embrace_assignments": {
			"type": "object",
			"prefer": [PSYCHIC_ENERGY, DRIFLOON, SCREAM_TAIL],
			"description": "Choose Psychic Energy from discard and attach it to a Psychic attacker that becomes ready or improves prize pressure.",
		},
		"embrace_energy": {
			"type": "string",
			"prefer": [PSYCHIC_ENERGY],
			"description": "Visible Psychic Energy card in discard.",
		},
		"embrace_target": {
			"type": "string",
			"prefer": [DRIFLOON, SCREAM_TAIL],
			"description": "Own Psychic Pokemon target, usually the active/bench attacker that becomes ready.",
		},
	}


func _munkidori_interaction_schema() -> Dictionary:
	return {
		"source_pokemon": {
			"type": "string",
			"prefer": [DRIFLOON, SCREAM_TAIL, DRIFBLIM],
			"description": "Choose a damaged source only when it does not reduce this turn's scaling attack math, unless the transfer itself takes a prize. Prefer non-attacking damaged support before active Drifloon/Scream Tail/Drifblim.",
		},
		"target_damage_counters": {
			"type": "object",
			"items": {"target_position": "opponent active/bench_N", "counters": "1-3"},
			"description": "Put up to 3 moved counters on the opponent Pokemon that is KO'd, sets up a prize, or is the active pressure target.",
		},
		"damage_target": {
			"type": "string",
			"items": "opponent active/bench_N",
			"description": "Fallback target for Munkidori damage-counter transfer.",
		},
	}


func _filter_gardevoir_payload_groups(raw_groups: Variant, removed_action_ids: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not (raw_groups is Dictionary):
		return result
	var groups: Dictionary = raw_groups
	for raw_key: Variant in groups.keys():
		var key := str(raw_key)
		var filtered: Array = []
		var raw_ids: Variant = groups.get(raw_key, [])
		if raw_ids is Array:
			for raw_id: Variant in raw_ids:
				var action_id := str(raw_id)
				if action_id != "" and not bool(removed_action_ids.get(action_id, false)):
					filtered.append(raw_id)
		result[key] = filtered
	return result


func _filter_gardevoir_candidate_routes(raw_routes: Variant, removed_action_ids: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_routes is Array):
		return result
	for raw_route: Variant in raw_routes:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = (raw_route as Dictionary).duplicate(true)
		var filtered_actions: Array[Dictionary] = []
		var raw_actions: Variant = route.get("actions", [])
		if raw_actions is Array:
			for raw_action: Variant in raw_actions:
				if not (raw_action is Dictionary):
					continue
				var action: Dictionary = raw_action
				var action_id := str(action.get("action_id", action.get("id", "")))
				if action_id != "" and bool(removed_action_ids.get(action_id, false)):
					continue
				filtered_actions.append(action.duplicate(true))
		if _gardevoir_route_has_only_terminal_end(filtered_actions) and str(route.get("goal", "")) != "fallback":
			continue
		if filtered_actions.is_empty() and str(route.get("goal", "")) != "fallback":
			continue
		route["actions"] = filtered_actions
		result.append(route)
	return result


func _filter_gardevoir_tactical_facts(raw_facts: Variant, removed_action_ids: Dictionary) -> Dictionary:
	if not (raw_facts is Dictionary):
		return {}
	var facts: Dictionary = (raw_facts as Dictionary).duplicate(true)
	for key: String in [
		"productive_engine_actions",
		"safe_pre_primary_actions",
		"legal_survival_tool_actions",
		"resource_negative_actions",
		"turn_ending_actions",
	]:
		if facts.has(key):
			facts[key] = _filter_gardevoir_fact_action_refs(facts.get(key, []), removed_action_ids)
	if facts.has("ready_attacks"):
		facts["ready_attacks"] = _filter_gardevoir_fact_action_refs(facts.get("ready_attacks", []), removed_action_ids)
	if facts.has("active_attack_options"):
		facts["active_attack_options"] = _filter_gardevoir_fact_action_refs(facts.get("active_attack_options", []), removed_action_ids)
	if facts.has("attack_quality_by_action_id"):
		var filtered_quality := {}
		var raw_quality: Variant = facts.get("attack_quality_by_action_id", {})
		if raw_quality is Dictionary:
			for raw_id: Variant in (raw_quality as Dictionary).keys():
				var action_id := str(raw_id)
				if action_id == "" or bool(removed_action_ids.get(action_id, false)):
					continue
				filtered_quality[action_id] = (raw_quality as Dictionary).get(raw_id)
		facts["attack_quality_by_action_id"] = filtered_quality
	var ready_attacks: Array = facts.get("ready_attacks", []) if facts.get("ready_attacks", []) is Array else []
	var attack_quality: Dictionary = facts.get("attack_quality_by_action_id", {}) if facts.get("attack_quality_by_action_id", {}) is Dictionary else {}
	if ready_attacks.is_empty() and attack_quality.is_empty():
		facts["attack_legal_now"] = false
	return facts


func _filter_gardevoir_fact_action_refs(raw_actions: Variant, removed_action_ids: Dictionary) -> Array:
	var result: Array = []
	if not (raw_actions is Array):
		return result
	for raw_action: Variant in raw_actions:
		if raw_action is Dictionary:
			var action_id := str((raw_action as Dictionary).get("action_id", (raw_action as Dictionary).get("id", (raw_action as Dictionary).get("legal_action_id", ""))))
			if action_id != "" and bool(removed_action_ids.get(action_id, false)):
				continue
		result.append(raw_action)
	return result


func _gardevoir_route_has_only_terminal_end(actions: Array[Dictionary]) -> bool:
	if actions.is_empty():
		return true
	for action: Dictionary in actions:
		if not _is_end_turn_action_ref(action):
			return false
	return true


func _is_bad_gardevoir_payload_action_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "play_basic_to_bench" and _ref_has_any_name(ref, GARDEVOIR_SUPPORT_NAMES):
		return _is_bad_gardevoir_support_bench_ref(ref, game_state, player_index)
	if action_type == "attach_tool":
		return _is_bad_gardevoir_tool_attach_ref(ref, game_state, player_index)
	if action_type == "attach_energy":
		return _is_bad_gardevoir_manual_attach_ref(ref, game_state, player_index)
	if action_type == "evolve":
		return _is_bad_gardevoir_evolve_ref(ref, game_state, player_index)
	if action_type == "retreat":
		return _is_bad_gardevoir_retreat_ref(ref, game_state, player_index)
	if action_type == "use_ability":
		return _is_bad_gardevoir_munkidori_ability_ref(ref, game_state, player_index) \
			or _is_dead_gardevoir_embrace_ref(ref, game_state, player_index)
	if action_type in ["play_trainer", "use_stadium_effect"] and _is_bad_gardevoir_basic_search_ref(ref, game_state, player_index):
		return true
	if action_type == "play_trainer" and _is_bad_gardevoir_preserve_supporter_ref(ref, game_state, player_index):
		return true
	if action_type == "play_trainer" and _is_bad_gardevoir_premature_recovery_ref(ref, game_state, player_index):
		return true
	if action_type in ["attack", "granted_attack"]:
		return _is_bad_gardevoir_tm_evolution_attack_ref(ref, game_state, player_index) \
			or _is_dangerous_gardevoir_core_pivot_attack(ref, game_state, player_index) \
			or _is_low_value_gardevoir_payload_attack_ref(ref, game_state, player_index)
	return false


func _is_low_value_gardevoir_payload_attack_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _is_bad_gardevoir_tm_evolution_attack_ref(ref, game_state, player_index):
		return true
	if _is_tm_evolution_granted_attack_ref(ref, game_state, player_index):
		return false
	if _is_low_value_gardevoir_attack_ref(ref, game_state, player_index):
		return true
	if not _gardevoir_catalog_has_tm_evolution_granted_attack(game_state, player_index):
		return false
	if bool(ref.get("projected_knockout", false)):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, GARDEVOIR_CORE_NAMES + GARDEVOIR_SUPPORT_NAMES):
		return false
	var projected_damage := int(ref.get("projected_damage", 0))
	if projected_damage <= 0 and ref.has("damage"):
		projected_damage = int(str(ref.get("damage", "0")).to_int())
	return projected_damage < 120


func _gardevoir_catalog_has_tm_evolution_granted_attack(game_state: GameState = null, player_index: int = -1) -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty():
			continue
		if str(ref.get("type", ref.get("kind", ""))) != "granted_attack":
			continue
		if _is_tm_evolution_granted_attack_ref(ref, game_state, player_index):
			return true
	return false


func _is_bad_gardevoir_tool_attach_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	var tool_name := _ref_card_name(ref)
	if tool_name == "":
		return false
	var target_name := _ref_target_name(ref, game_state, player_index)
	if _name_contains(tool_name, TM_EVOLUTION):
		if target_name == "":
			return false
		if _gardevoir_payload_tm_target_does_not_solve_attacker_gap(ref, game_state, player_index):
			return true
		if _ref_target_is_gardevoir_attacker(ref, game_state, player_index):
			return true
		if _ref_targets_known_non_active(ref):
			return true
		return not _name_matches_any(target_name, [KLEFKI, FLUTTER_MANE, MUNKIDORI, RALTS])
	if _name_contains(tool_name, BRAVERY_CHARM):
		if target_name == "":
			return true
		if _gardevoir_active_attacker_should_receive_bravery(game_state, player_index) and not _ref_targets_active_slot(ref, game_state, player_index):
			return true
		if _gardevoir_drifloon_should_receive_bravery(game_state, player_index) and not _ref_targets_name_or_slot(ref, [DRIFLOON], game_state, player_index):
			return true
		return not _name_matches_any(target_name, GARDEVOIR_ATTACKER_NAMES)
	return false


func _is_bad_gardevoir_manual_attach_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _ref_is_energy_card(ref):
		return false
	var target_name := _ref_target_name(ref, game_state, player_index)
	if target_name == "":
		return false
	var energy_name := _ref_card_name(ref)
	if _name_contains(energy_name, DARKNESS_ENERGY) and _name_matches_any(target_name, [MUNKIDORI]):
		var target_slot := _ref_target_slot(ref, game_state, player_index)
		if _slot_has_energy_type(target_slot, "Darkness"):
			return true
	if _name_contains(energy_name, DARKNESS_ENERGY) and not _name_matches_any(target_name, [MUNKIDORI]):
		return true
	if _ref_is_psychic_energy(ref) and _name_matches_any(target_name, [MUNKIDORI]):
		return true
	if _ref_is_psychic_energy(ref) and _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state, player_index):
		return not _ref_targets_active_slot(ref, game_state, player_index)
	if _ref_is_psychic_energy(ref) and _gardevoir_active_manual_attach_retreat_setup_needed(game_state, player_index, energy_name):
		return not _ref_targets_active_slot(ref, game_state, player_index)
	if _ref_is_psychic_energy(ref) and _gardevoir_active_manual_attach_emergency_attack_needed(game_state, player_index, energy_name) and _ref_targets_active_slot(ref, game_state, player_index):
		return false
	var low_value_targets: Array[String] = []
	low_value_targets.append_array(GARDEVOIR_CORE_NAMES)
	low_value_targets.append_array([MANAPHY, RADIANT_GRENINJA, KLEFKI, FLUTTER_MANE])
	if _ref_targets_active_slot(ref, game_state, player_index) and _gardevoir_active_manual_attach_retreat_setup_needed(game_state, player_index, energy_name):
		return false
	if not _name_matches_any(target_name, low_value_targets):
		return false
	if _ref_targets_known_non_active(ref):
		return true
	if _ref_target_has_tool_name(ref, TM_EVOLUTION):
		return false
	return not _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state, player_index)


func _gardevoir_payload_tm_target_does_not_solve_attacker_gap(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if not _gardevoir_needs_first_attacker_body(player):
		return false
	var target_name := _ref_target_name(ref, game_state, player_index)
	return _name_matches_any(target_name, [FLUTTER_MANE, MUNKIDORI])


func _gardevoir_runtime_tm_target_does_not_solve_attacker_gap(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if not _gardevoir_needs_first_attacker_body(player):
		return false
	var target_name := _runtime_action_target_name(action, "target", game_state, player_index)
	return _name_matches_any(target_name, [FLUTTER_MANE, MUNKIDORI])


func _is_bad_gardevoir_evolve_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _name_contains(_ref_card_name(ref), GARDEVOIR_EX):
		return false
	var target_slot := _ref_target_slot(ref, game_state, player_index)
	return _gardevoir_should_preserve_active_kirlia_from_ex_evolve(target_slot, game_state, player_index)


func _is_bad_gardevoir_retreat_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	var target_slot := _ref_retreat_target_slot(ref, game_state, player_index)
	if _gardevoir_active_tm_evolution_bridge_available(game_state, player_index):
		if target_slot != null and _slot_has_pressure_ready_gardevoir_attack(target_slot, game_state, player_index):
			return false
		return true
	if target_slot != null and _is_gardevoir_bad_handoff_target(target_slot, game_state, player_index):
		return true
	var target_name := _ref_retreat_target_name(ref, game_state, player_index)
	if target_name == "":
		return false
	var bad_targets: Array[String] = []
	bad_targets.append_array(GARDEVOIR_CORE_NAMES)
	bad_targets.append_array(GARDEVOIR_SUPPORT_NAMES)
	return _name_matches_any(target_name, bad_targets)


func _ref_card_name(ref: Dictionary) -> String:
	var card_name := str(ref.get("card", ""))
	if card_name != "":
		return card_name
	var raw_rules: Variant = ref.get("card_rules", {})
	if raw_rules is Dictionary:
		var rules: Dictionary = raw_rules
		var name_en := str(rules.get("name_en", ""))
		if name_en != "":
			return name_en
		return str(rules.get("name", ""))
	return ""


func _ref_is_energy_card(ref: Dictionary) -> bool:
	var card_type := str(ref.get("card_type", ""))
	if card_type == "Basic Energy" or card_type == "Special Energy":
		return true
	var energy_type := str(ref.get("energy_type", ""))
	if energy_type != "":
		return true
	var raw_rules: Variant = ref.get("card_rules", {})
	if raw_rules is Dictionary:
		card_type = str((raw_rules as Dictionary).get("card_type", ""))
		return card_type == "Basic Energy" or card_type == "Special Energy"
	return _ref_has_any_name(ref, [PSYCHIC_ENERGY, DARKNESS_ENERGY])


func _ref_is_psychic_energy(ref: Dictionary) -> bool:
	if not _ref_is_energy_card(ref):
		return false
	if _name_contains(_ref_card_name(ref), PSYCHIC_ENERGY):
		return true
	for key: String in ["energy_type", "energy", "energy_provides"]:
		var value := str(ref.get(key, ""))
		if _energy_type_matches("Psychic", value):
			return true
	var raw_rules: Variant = ref.get("card_rules", {})
	if raw_rules is Dictionary:
		var rules: Dictionary = raw_rules
		if _energy_type_matches("Psychic", str(rules.get("energy_type", ""))):
			return true
		if _energy_type_matches("Psychic", str(rules.get("energy", ""))):
			return true
		if _energy_type_matches("Psychic", str(rules.get("energy_provides", ""))):
			return true
	return false


func _ref_target_name(ref: Dictionary, game_state: GameState, player_index: int) -> String:
	var name_en := str(ref.get("target_name_en", ""))
	if name_en != "":
		return name_en
	var target_name := str(ref.get("target_name", ref.get("target_pokemon_name", ref.get("pokemon_name", ""))))
	if target_name != "":
		return target_name
	var raw_target: Variant = ref.get("target", "")
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		name_en = str(target_dict.get("name_en", ""))
		if name_en != "":
			return name_en
		var name := str(target_dict.get("name", ""))
		if name != "":
			return name
	var position := str(ref.get("position", ref.get("target_position", ""))).strip_edges().to_lower()
	var slot := _slot_for_position(game_state, player_index, position)
	if slot != null:
		return _slot_best_name(slot)
	if str(raw_target).strip_edges().to_lower() in ["active", "bench_0", "bench_1", "bench_2", "bench_3", "bench_4"]:
		slot = _slot_for_position(game_state, player_index, str(raw_target).strip_edges().to_lower())
		if slot != null:
			return _slot_best_name(slot)
	return str(raw_target)


func _ref_target_slot(ref: Dictionary, game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var raw_target: Variant = ref.get("target", null)
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		var dict_position := str(target_dict.get("position", target_dict.get("target_position", ""))).strip_edges().to_lower()
		var dict_slot := _slot_for_position(game_state, player_index, dict_position)
		if dict_slot != null:
			return dict_slot
	var position := str(ref.get("position", ref.get("target_position", ""))).strip_edges().to_lower()
	var slot := _slot_for_position(game_state, player_index, position)
	if slot != null:
		return slot
	if str(raw_target).strip_edges().to_lower() in ["active", "bench_0", "bench_1", "bench_2", "bench_3", "bench_4"]:
		slot = _slot_for_position(game_state, player_index, str(raw_target).strip_edges().to_lower())
		if slot != null:
			return slot
	var target_name := _ref_target_name(ref, game_state, player_index)
	if target_name == "":
		return null
	var player: PlayerState = game_state.players[player_index]
	if _slot_name_matches_any(player.active_pokemon, [target_name]):
		return player.active_pokemon
	for bench_slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(bench_slot, [target_name]):
			return bench_slot
	return null


func _ref_retreat_target_name(ref: Dictionary, game_state: GameState, player_index: int) -> String:
	var name_en := str(ref.get("bench_target_name_en", ""))
	if name_en != "":
		return name_en
	var raw_target: Variant = ref.get("bench_target", "")
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		name_en = str(target_dict.get("name_en", ""))
		if name_en != "":
			return name_en
		var name := str(target_dict.get("name", ""))
		if name != "":
			return name
	var position := str(ref.get("bench_position", ref.get("target_position", ""))).strip_edges().to_lower()
	var slot := _slot_for_position(game_state, player_index, position)
	if slot != null:
		return _slot_best_name(slot)
	return str(raw_target)


func _ref_retreat_target_slot(ref: Dictionary, game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var raw_target: Variant = ref.get("bench_target", null)
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		var dict_position := str(target_dict.get("position", target_dict.get("target_position", ""))).strip_edges().to_lower()
		var dict_slot := _slot_for_position(game_state, player_index, dict_position)
		if dict_slot != null:
			return dict_slot
	var position := str(ref.get("bench_position", ref.get("target_position", ""))).strip_edges().to_lower()
	var slot := _slot_for_position(game_state, player_index, position)
	if slot != null:
		return slot
	var target_name := _ref_retreat_target_name(ref, game_state, player_index)
	if target_name == "":
		return null
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return null
	for bench_slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(bench_slot, [target_name]):
			return bench_slot
	return null


func _ref_targets_active_slot(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var position := str(ref.get("position", ref.get("target_position", ""))).strip_edges().to_lower()
	if position == "active":
		return true
	if position.begins_with("bench"):
		return false
	var target_name := _ref_target_name(ref, game_state, player_index)
	return target_name != "" and _name_matches_any(target_name, [_slot_best_name(player.active_pokemon)])


func _slot_for_position(game_state: GameState, player_index: int, position: String) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return null
	if position == "active":
		return player.active_pokemon
	if position.begins_with("bench_"):
		var raw_index := position.trim_prefix("bench_")
		if raw_index.is_valid_int():
			var bench_index := int(raw_index)
			if bench_index >= 0 and bench_index < player.bench.size():
				return player.bench[bench_index]
	return null


func _ref_targets_known_non_active(ref: Dictionary) -> bool:
	var position := str(ref.get("position", ref.get("target_position", ""))).strip_edges().to_lower()
	return position.begins_with("bench")


func _ref_target_has_tool_name(ref: Dictionary, query: String) -> bool:
	var raw_target: Variant = ref.get("target", {})
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		var raw_tool: Variant = target_dict.get("tool", target_dict.get("attached_tool", ""))
		if raw_tool is Dictionary:
			var tool_dict: Dictionary = raw_tool
			return _name_contains(str(tool_dict.get("name_en", tool_dict.get("name", ""))), query)
		return _name_contains(str(raw_tool), query)
	return false


func _is_bad_gardevoir_support_bench_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _ref_has_any_name(ref, [MANAPHY]):
		return not _opponent_has_bench_spread_pressure(game_state, player_index) or _gardevoir_needs_core_redundancy(player)
	if _ref_has_any_name(ref, [MUNKIDORI]):
		if _count_field_name(player, MUNKIDORI) > 0:
			return true
		return not _gardevoir_munkidori_bench_window_open(player)
	if _count_attacker_bodies(player) == 0 and _gardevoir_bench_slots_remaining(player) <= 1:
		return true
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) < 2:
		return true
	if _gardevoir_needs_core_redundancy(player):
		return true
	return _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) == 0


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _append_gardevoir_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool, no_deck_draw_lock: bool = false) -> void:
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [RALTS])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [BUDDY_BUDDY_POFFIN], _core_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NEST_BALL], _core_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ARTAZON])
	_append_gardevoir_catalog_match(target, seen_ids, "use_stadium_effect", [ARTAZON], _core_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ULTRA_BALL], _core_ultra_ball_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ARVEN])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [RARE_CANDY])
	_append_gardevoir_catalog_match(target, seen_ids, "evolve", [KIRLIA])
	_append_gardevoir_catalog_match(target, seen_ids, "evolve", [GARDEVOIR_EX])
	_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [TM_EVOLUTION])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [EARTHEN_VESSEL], _earthen_vessel_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [SECRET_BOX])
	if not has_attack and not no_deck_draw_lock:
		_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [IONO])
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
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [SUPER_ROD], _attacker_recovery_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [ULTRA_BALL], _attacker_ultra_ball_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [MUNKIDORI], _munkidori_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [MUNKIDORI])
	_append_gardevoir_catalog_match(target, seen_ids, "attach_energy", [MUNKIDORI, DARKNESS_ENERGY])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [IONO])
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [BRAVERY_CHARM])


func _append_gardevoir_active_attack_charge_catalog(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	game_state: GameState,
	player_index: int
) -> void:
	var gap := _gardevoir_active_embrace_attack_gap(game_state, player_index)
	if gap <= 0:
		return
	var before_size := target.size()
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_active_attack_interactions())
	if target.size() <= before_size:
		return
	var embrace_ref: Dictionary = target[target.size() - 1].duplicate(true)
	for _i: int in maxi(0, gap - 1):
		if target.size() >= 8:
			break
		target.append(embrace_ref.duplicate(true))


func _append_gardevoir_attacker_charge_catalog(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [MUNKIDORI], _munkidori_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [MUNKIDORI])
	_append_gardevoir_catalog_match(target, seen_ids, "attach_energy", [MUNKIDORI, DARKNESS_ENERGY])
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "attach_energy", [DRIFLOON, SCREAM_TAIL, PSYCHIC_ENERGY])
	_append_gardevoir_catalog_match(target, seen_ids, "attach_tool", [BRAVERY_CHARM])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NIGHT_STRETCHER], _attacker_recovery_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [SUPER_ROD], _attacker_recovery_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [IONO])


func _append_gardevoir_backup_attacker_catalog(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [DRIFLOON])
	_append_gardevoir_catalog_match(target, seen_ids, "play_basic_to_bench", [SCREAM_TAIL])
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [BUDDY_BUDDY_POFFIN], _attacker_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NEST_BALL], _attacker_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "use_stadium_effect", [ARTAZON], _attacker_basic_search_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [NIGHT_STRETCHER], _attacker_recovery_interactions())
	_append_gardevoir_catalog_match(target, seen_ids, "play_trainer", [SUPER_ROD], _attacker_recovery_interactions())


func _append_gardevoir_handoff_catalog(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	game_state: GameState = null,
	player_index: int = -1
) -> void:
	var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
	if player != null and _gardevoir_active_embrace_retreat_setup_needed(player, game_state):
		var gap := mini(_gardevoir_retreat_energy_gap(player.active_pokemon), _count_psychic_energy_in_discard(player))
		var before_size := target.size()
		_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_retreat_interactions())
		if target.size() > before_size:
			var embrace_ref: Dictionary = target[target.size() - 1].duplicate(true)
			for _i: int in maxi(0, gap - 1):
				if target.size() >= 8:
					break
				target.append(embrace_ref.duplicate(true))
		_append_gardevoir_catalog_match(target, seen_ids, "retreat", GARDEVOIR_ATTACKER_NAMES)
		return
	_append_gardevoir_catalog_match(target, seen_ids, "retreat", GARDEVOIR_ATTACKER_NAMES)
	_append_gardevoir_catalog_match(target, seen_ids, "use_ability", [GARDEVOIR_EX], _psychic_embrace_retreat_interactions())


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


func _psychic_embrace_retreat_interactions() -> Dictionary:
	return {
		"psychic_embrace_assignments": {"prefer": [PSYCHIC_ENERGY, GARDEVOIR_EX, DRIFLOON, SCREAM_TAIL]},
	}


func _psychic_embrace_active_attack_interactions() -> Dictionary:
	return {
		"psychic_embrace_assignments": {"prefer": [PSYCHIC_ENERGY, "active", MUNKIDORI, GARDEVOIR_EX, FLUTTER_MANE]},
	}


func _munkidori_interactions() -> Dictionary:
	return {
		"source_pokemon": {"prefer": [DRIFLOON, SCREAM_TAIL, DRIFBLIM]},
		"target_damage_counters": {"prefer": ["opponent_active_if_KO", "lowest_remaining_HP_rule_box"]},
		"damage_target": {"prefer": ["opponent_active_if_KO", "lowest_remaining_HP_rule_box"]},
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
		"target_card",
		"target_cards",
		"select_card",
		"selected_card",
		"choose_card",
		"chosen_card",
		"searched_pokemon",
		"basic_pokemon",
		"buddy_poffin_pokemon",
		"bench_pokemon",
		"artazon_pokemon",
		"pokemon_card",
		"pokemon_cards",
		"pokemon",
	]


func _is_gardevoir_item_search_step(step: Dictionary, _context: Dictionary = {}) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id in ["search_item", "search_items", "item_card", "item_cards"]


func _is_gardevoir_energy_search_step(step: Dictionary, _context: Dictionary = {}) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id in ["search_energy", "search_energies", "search_basic_energy", "basic_energy", "energy_card", "energy_cards"]


func _is_gardevoir_recovery_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id in [
		"cards_to_return",
		"night_stretcher_choice",
		"recover_target",
		"recover_card",
		"recover_targets",
		"recover_energy",
	]


func _is_gardevoir_damage_counter_source_step(step: Dictionary) -> bool:
	return str(step.get("id", "")).strip_edges() == "source_pokemon"


func _is_gardevoir_damage_counter_target_step(step: Dictionary) -> bool:
	var step_id := str(step.get("id", "")).strip_edges()
	return step_id in ["target_damage_counters", "damage_target", "bench_damage_counters"] \
		or str(step.get("ui_mode", "")).strip_edges() == "counter_distribution" \
		or bool(step.get("use_counter_distribution_ui", false))


func _protect_gardevoir_damage_counter_source_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_gardevoir_damage_counter_source_step(step):
		return planned
	var max_select := int(step.get("max_select", planned.size()))
	if max_select <= 0:
		max_select = planned.size()
	if max_select <= 0:
		max_select = 1
	var ranked: Array[Dictionary] = []
	var saw_source_candidate := false
	for item: Variant in items:
		if not (item is PokemonSlot):
			continue
		saw_source_candidate = true
		var score := _score_gardevoir_damage_counter_source(item as PokemonSlot, context)
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
	if not result.is_empty():
		return result
	return [] if saw_source_candidate else planned


func _score_gardevoir_damage_counter_interaction(slot: PokemonSlot, step: Dictionary, context: Dictionary) -> float:
	if _is_gardevoir_damage_counter_source_step(step):
		return _score_gardevoir_damage_counter_source(slot, context)
	if _is_gardevoir_damage_counter_target_step(step):
		return _score_gardevoir_damage_counter_target(slot, context)
	return 0.0


func _score_gardevoir_scream_tail_attack_target(slot: PokemonSlot, step: Dictionary, context: Dictionary) -> float:
	if str(step.get("id", "")).strip_edges() != "target_pokemon":
		return 0.0
	if _pending_effect_is_psychic_embrace(context):
		return 0.0
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_name_matches_any(player.active_pokemon, [SCREAM_TAIL]):
		return 0.0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0.0
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or not (slot in opponent.get_all_pokemon()):
		return 0.0
	var damage := _gardevoir_current_attacker_damage_estimate(player.active_pokemon)
	if damage <= 0:
		return 0.0
	var remaining_hp := _gardevoir_effective_remaining_hp(slot, game_state)
	if remaining_hp <= 0:
		return -1000.0
	var prize_count := slot.get_prize_count()
	var score := 52000.0 + float(prize_count * 7000) + float(slot.damage_counters * 2) - float(remaining_hp)
	if slot == opponent.active_pokemon:
		score += 4000.0
	if remaining_hp <= damage:
		score += 120000.0 + float(prize_count * 16000) - float(remaining_hp * 15)
	return score


func _score_gardevoir_damage_counter_source(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	if player != null and not (slot in player.get_all_pokemon()):
		return 0.0
	if slot.damage_counters < 10:
		return -1000.0
	if _gardevoir_should_preserve_attacker_damage_for_attack(slot, game_state, player_index):
		return -1000.0
	var score := 50000.0 + float(mini(slot.damage_counters, 30) * 1000)
	if _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		score += 35000.0
	if slot == (player.active_pokemon if player != null else null):
		score += 8000.0
	if _gardevoir_effective_remaining_hp(slot, game_state) <= 40:
		score += 12000.0
	if _gardevoir_embrace_damage_estimate(slot, 0) >= 120:
		score += 5000.0
	return score


func _is_bad_gardevoir_munkidori_ability_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _ref_has_any_name(ref, [MUNKIDORI, "Adrena-Brain", "亢奋脑力"]):
		return false
	return not _gardevoir_has_safe_munkidori_source(game_state, player_index)


func _is_bad_gardevoir_munkidori_ability(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _runtime_action_has_any_name(action, [MUNKIDORI, "Adrena-Brain", "亢奋脑力"]):
		return false
	return not _gardevoir_has_safe_munkidori_source(game_state, player_index)


func _gardevoir_has_safe_munkidori_source(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	for slot: PokemonSlot in _all_player_slots(player):
		if slot == null or slot.damage_counters < 10:
			continue
		if _gardevoir_should_preserve_attacker_damage_for_attack(slot, game_state, player_index):
			continue
		return true
	return false


func _score_gardevoir_damage_counter_target(slot: PokemonSlot, context: Dictionary) -> float:
	if slot == null or slot.get_card_data() == null:
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var opponent: PlayerState = null
	if game_state != null:
		var opponent_index := 1 - player_index
		if opponent_index >= 0 and opponent_index < game_state.players.size():
			opponent = game_state.players[opponent_index]
	if opponent != null and not (slot in opponent.get_all_pokemon()):
		return 0.0
	var remaining_hp := _gardevoir_effective_remaining_hp(slot, game_state)
	if remaining_hp <= 0:
		return -1000.0
	var transferable_damage := _gardevoir_available_munkidori_transfer_damage(game_state, player_index)
	if transferable_damage <= 0:
		transferable_damage = 30
	var score := 45000.0 + float(slot.damage_counters * 2) - float(remaining_hp)
	score += float(slot.get_prize_count() * 6000)
	if opponent != null and slot == opponent.active_pokemon:
		score += 5000.0
	if remaining_hp <= transferable_damage:
		score += 90000.0 + float(slot.get_prize_count() * 12000) - float(remaining_hp * 20)
	return score


func _gardevoir_available_munkidori_transfer_damage(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return 0
	var max_damage := 0
	for slot: PokemonSlot in _all_player_slots(player):
		if slot == null or slot.damage_counters < 10:
			continue
		max_damage = maxi(max_damage, mini(30, int(slot.damage_counters / 10) * 10))
	return max_damage


func _gardevoir_munkidori_has_damage_transfer_value(game_state: GameState, player_index: int) -> bool:
	var transferable_damage := _gardevoir_available_munkidori_transfer_damage(game_state, player_index)
	if transferable_damage <= 0:
		return false
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_player_slots(opponent):
		if slot == null:
			continue
		if _gardevoir_effective_remaining_hp(slot, game_state) > 0:
			return true
	return false


func _gardevoir_should_preserve_attacker_damage_for_attack(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if slot == null or not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player != null and slot == player.active_pokemon:
		var active_attack_is_live := _slot_has_ready_gardevoir_attack(slot) \
			or _gardevoir_retreat_target_is_live_conversion(slot, game_state, player_index)
		if active_attack_is_live:
			return not _gardevoir_munkidori_transfer_can_take_prize(game_state, player_index, slot)
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	if opponent_hp <= 0:
		return false
	if _gardevoir_current_attacker_damage_estimate(slot) < opponent_hp:
		return false
	if _gardevoir_munkidori_transfer_can_take_prize(game_state, player_index, slot):
		return false
	return true


func _gardevoir_munkidori_transfer_can_take_prize(game_state: GameState, player_index: int, source_slot: PokemonSlot = null) -> bool:
	if game_state == null or player_index < 0:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var transfer_damage := 30
	if source_slot != null:
		transfer_damage = mini(30, int(source_slot.damage_counters / 10) * 10)
	else:
		transfer_damage = _gardevoir_available_munkidori_transfer_damage(game_state, player_index)
	if transfer_damage <= 0:
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_player_slots(opponent):
		if slot != null and _gardevoir_effective_remaining_hp(slot, game_state) > 0 and _gardevoir_effective_remaining_hp(slot, game_state) <= transfer_damage:
			return true
	return false


func _protect_gardevoir_item_search_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_gardevoir_item_search_step(step, context) or not _gardevoir_item_search_override_active(context):
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
	return result if not result.is_empty() or _gardevoir_item_search_override_active(context) else planned


func _protect_gardevoir_energy_search_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_gardevoir_energy_search_step(step, context):
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
		var score := _score_gardevoir_energy_search_target(item as CardInstance, step, context)
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
	return result if not result.is_empty() or _gardevoir_search_override_active(context) else planned


func _score_gardevoir_energy_search_target(item: CardInstance, step: Dictionary, context: Dictionary) -> float:
	if item == null or item.card_data == null or not _is_gardevoir_energy_search_step(step, context):
		return 0.0
	if not item.card_data.is_energy():
		return 0.0
	var provides := str(item.card_data.energy_provides)
	if _energy_type_matches("Psychic", provides):
		return 120000.0
	if _energy_type_matches("Darkness", provides):
		return 60000.0
	return 1000.0


func _protect_gardevoir_recovery_picks(planned: Array, items: Array, step: Dictionary, context: Dictionary) -> Array:
	if not _is_gardevoir_recovery_step(step) or not _gardevoir_recovery_override_active(context):
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
		var score := _score_gardevoir_recovery_target(item as CardInstance, step, context)
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


func _score_gardevoir_recovery_target(item: CardInstance, step: Dictionary, context: Dictionary) -> float:
	if item == null or item.card_data == null or not _is_gardevoir_recovery_step(step):
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
	var no_attacker := _count_attacker_bodies(player) == 0
	var continuity_needed := _gardevoir_needs_attacker_continuity_slot(player)
	if engine_online and (no_attacker or continuity_needed):
		if _name_contains(name, DRIFLOON):
			return 130000.0
		if _name_contains(name, SCREAM_TAIL):
			return 126000.0
		if _name_contains(name, DRIFBLIM):
			return 118000.0
		if item.card_data.is_energy() and _energy_type_matches("Psychic", str(item.card_data.energy_provides)):
			return 80000.0
		if _name_matches_any(name, GARDEVOIR_CORE_NAMES):
			return 20000.0
		if _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
			return -1000.0
	if engine_online and _gardevoir_discard_has_attacker_body(player):
		if _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
			return 90000.0
		if item.card_data.is_energy() and _energy_type_matches("Psychic", str(item.card_data.energy_provides)):
			return 50000.0
	if not engine_online and _count_field_name(player, KIRLIA) > 0:
		if _name_contains(name, GARDEVOIR_EX):
			return 90000.0
		if _name_contains(name, KIRLIA):
			return 70000.0
		if _name_contains(name, RALTS):
			return 50000.0
	if item.card_data.is_energy() and _energy_type_matches("Psychic", str(item.card_data.energy_provides)):
		return 1000.0
	return 0.0


func _gardevoir_recovery_override_active(context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) == 0 and _gardevoir_discard_has_attacker_body(player):
		return true
	if _gardevoir_needs_attacker_continuity_slot(player) and _gardevoir_discard_has_attacker_body(player):
		return true
	if _count_field_name(player, KIRLIA) > 0 and _gardevoir_discard_has_attacker_body(player):
		return true
	return false


func _score_gardevoir_item_search_target(item: CardInstance, step: Dictionary, context: Dictionary) -> float:
	if item == null or item.card_data == null or not _is_gardevoir_item_search_step(step, context):
		return 0.0
	if not _gardevoir_item_search_override_active(context):
		return 0.0
	var name := _best_card_name(item.card_data)
	if _gardevoir_item_search_needs_first_attacker(context):
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		var player: PlayerState = game_state.players[player_index] if game_state != null and player_index >= 0 and player_index < game_state.players.size() else null
		var attacker_in_discard := _gardevoir_discard_has_attacker_body(player)
		if _name_contains(name, NIGHT_STRETCHER) and attacker_in_discard:
			return 130000.0
		if _name_contains(name, BUDDY_BUDDY_POFFIN):
			return 122000.0
		if _name_contains(name, NEST_BALL):
			return 118000.0
		if _name_contains(name, ULTRA_BALL):
			return 98000.0
		if _name_contains(name, SUPER_ROD) and attacker_in_discard:
			return 76000.0
		if _name_contains(name, "Hisuian Heavy Ball"):
			return 70000.0
		if _name_contains(name, SECRET_BOX):
			return 50000.0
		if _name_contains(name, EARTHEN_VESSEL):
			return 250.0
		return 0.0
	if _name_contains(name, EARTHEN_VESSEL):
		return 125000.0
	if _name_contains(name, ULTRA_BALL):
		return 250.0
	if _name_contains(name, BUDDY_BUDDY_POFFIN) or _name_contains(name, NEST_BALL):
		return 200.0
	if _name_contains(name, SECRET_BOX):
		return 150.0
	return 0.0


func _gardevoir_item_search_override_active(context: Dictionary) -> bool:
	return _gardevoir_item_search_needs_vessel(context) or _gardevoir_item_search_needs_first_attacker(context)


func _gardevoir_item_search_needs_first_attacker(context: Dictionary) -> bool:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return _gardevoir_needs_first_attacker_body(player)


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
	return result if not result.is_empty() or _gardevoir_search_override_active(context) else planned


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
	if engine_online and _gardevoir_bench_slots_remaining(player) <= 1 and _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
		return -500.0
	if _gardevoir_needs_first_attacker_body(player):
		if _name_contains(name, DRIFLOON):
			return 150000.0
		if _name_contains(name, SCREAM_TAIL):
			return 146000.0
		if _name_contains(name, DRIFBLIM):
			return 110000.0
		if _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
			return -1000.0
		if _name_contains(name, GARDEVOIR_EX) and _count_field_name(player, GARDEVOIR_EX) > 0:
			return -500.0
		if _name_matches_any(name, GARDEVOIR_CORE_NAMES):
			return 500.0
	if _name_contains(name, MUNKIDORI):
		if _count_field_name(player, MUNKIDORI) > 0:
			return -1000.0
		if _gardevoir_munkidori_bench_window_open(player):
			return 65000.0
	if engine_online and _gardevoir_needs_attacker_continuity_slot(player):
		if _name_contains(name, DRIFLOON):
			return 120000.0
		if _name_contains(name, SCREAM_TAIL):
			return 116000.0
		if _name_contains(name, DRIFBLIM):
			return 100000.0
		if _name_contains(name, RALTS):
			return 60000.0
		if _name_contains(name, KIRLIA):
			return 50000.0
		if _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
			return -500.0
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
	if _gardevoir_needs_first_attacker_body(player):
		return true
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) == 0:
		return true
	if _gardevoir_needs_attacker_continuity_slot(player):
		return true
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _gardevoir_bench_slots_remaining(player) <= 1:
		return true
	if _count_field_name(player, GARDEVOIR_EX) == 0 and _count_field_name(player, KIRLIA) > 0:
		return true
	return _gardevoir_needs_core_redundancy(player)


func _gardevoir_needs_attacker_continuity_slot(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return false
	if _gardevoir_bench_slots_remaining(player) > 1:
		return false
	return _count_attacker_bodies(player) < 3


func _gardevoir_needs_first_attacker_body(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return false
	return _count_attacker_bodies(player) == 0


func _gardevoir_bench_slots_remaining(player: PlayerState) -> int:
	if player == null:
		return 0
	return maxi(0, 5 - player.bench.size())


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


func _gardevoir_item_search_needs_vessel(context: Dictionary) -> bool:
	if _gardevoir_tm_evolution_bridge_needs_vessel(context):
		return true
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return false
	if _count_psychic_energy_in_discard(player) > 0:
		return false
	if _gardevoir_hand_has_psychic_energy(player):
		return true
	if _count_attacker_bodies(player) > 0:
		return true
	return _slot_name_matches_any(player.active_pokemon, [GARDEVOIR_EX])


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
		if _slot_name_matches_any(slot, [RALTS, KIRLIA]):
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
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var pressure_active := _gardevoir_forced_active_embrace_target(game_state, player_index)
	for item: Variant in planned:
		if pressure_active != null and item != pressure_active:
			continue
		if item is PokemonSlot and _score_gardevoir_embrace_target(item as PokemonSlot, step, context) > 0.0:
			result.append(item)
			if result.size() >= max_select:
				return result
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is PokemonSlot):
			continue
		if pressure_active != null and item != pressure_active:
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


func _gardevoir_pressure_active_embrace_target(game_state: GameState, player_index: int) -> PokemonSlot:
	if not _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return null
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return null
	return player.active_pokemon


func _gardevoir_forced_active_embrace_target(game_state: GameState, player_index: int) -> PokemonSlot:
	var pressure_active := _gardevoir_pressure_active_embrace_target(game_state, player_index)
	if pressure_active != null:
		return pressure_active
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return null
	var active: PokemonSlot = player.active_pokemon
	if _gardevoir_active_embrace_attack_setup_needed(game_state, player_index):
		return active
	if not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return null
	if _slot_has_ready_gardevoir_attack(active):
		return null
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return null
	var discard_psychic := _count_psychic_energy_in_discard(player)
	if discard_psychic <= 0:
		return null
	var gap := _gardevoir_min_attack_cost_gap(active, 0)
	if gap <= 0:
		return null
	var safe_embrace_count := maxi(0, int((_gardevoir_effective_remaining_hp(active, game_state) - 10) / 20))
	if gap > mini(discard_psychic, safe_embrace_count):
		return null
	if _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index) and _gardevoir_retreat_energy_gap(active) <= 0:
		return null
	return active


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
	if slot == null or slot.get_card_data() == null or _gardevoir_effective_remaining_hp(slot, game_state) <= 0:
		return -1000.0
	if _gardevoir_effective_remaining_hp(slot, game_state) <= 20:
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
	if player != null and slot == player.active_pokemon and _gardevoir_active_embrace_attack_setup_needed(game_state, player_index):
		return 158000.0 - float(_gardevoir_active_embrace_attack_gap(game_state, player_index) * 1000)
	if player != null and slot == player.active_pokemon and _gardevoir_active_embrace_retreat_setup_needed(player, game_state):
		return 160000.0 - float(_gardevoir_retreat_energy_gap(slot) * 1000)
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
		if opponent_active != null and damage_after >= _gardevoir_effective_remaining_hp(opponent_active, game_state):
			score += 15000.0
		return score
	if player != null and slot == player.active_pokemon and _gardevoir_active_embrace_retreat_bridge_live(player):
		return 150000.0
	if player != null and _count_field_name(player, GARDEVOIR_EX) > 0:
		return -1000.0
	return -200.0


func _gardevoir_active_embrace_retreat_bridge_live(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _name_matches_any(_slot_best_name(player.active_pokemon), GARDEVOIR_ATTACKER_NAMES):
		return false
	var gap := _gardevoir_retreat_energy_gap(player.active_pokemon)
	if gap <= 0 or gap > 2:
		return false
	return _has_ready_bench_gardevoir_attacker(player) and _count_psychic_energy_in_discard(player) >= gap


func _gardevoir_active_embrace_retreat_setup_needed(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES):
		return false
	var gap := _gardevoir_retreat_energy_gap(player.active_pokemon)
	if gap <= 0 or gap > 2:
		return false
	var discard_psychic := _count_psychic_energy_in_discard(player)
	if discard_psychic <= 0:
		return false
	if _has_ready_bench_gardevoir_attacker(player):
		return true
	var manual_psychic := 0
	if game_state != null and not bool(game_state.energy_attached_this_turn) and _count_psychic_energy_in_hand(player) > 0:
		manual_psychic = 1
	for slot: PokemonSlot in player.bench:
		if not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
			continue
		var remaining_after_active := maxi(0, discard_psychic - 1)
		if _gardevoir_min_attack_cost_gap(slot, remaining_after_active + manual_psychic) <= 0:
			return true
	return false


func _gardevoir_active_manual_attach_retreat_setup_needed(game_state: GameState, player_index: int, energy_name: String) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if not _name_contains(energy_name, PSYCHIC_ENERGY):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES):
		return false
	var gap := _gardevoir_retreat_energy_gap(player.active_pokemon)
	if gap <= 0 or gap > 2:
		return false
	if _has_ready_bench_gardevoir_attacker(player):
		return true
	return _count_attacker_bodies(player) > 0 and _count_psychic_energy_in_discard(player) > 0


func _gardevoir_active_manual_attach_emergency_attack_needed(game_state: GameState, player_index: int, energy_name: String) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if not _name_contains(energy_name, PSYCHIC_ENERGY):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [GARDEVOIR_EX]):
		return false
	if _slot_has_pressure_ready_gardevoir_attack(player.active_pokemon, game_state, player_index):
		return false
	if _count_pressure_ready_attackers(player, game_state, player_index) > 0:
		return false
	if _count_psychic_energy_in_discard(player) > 0 and _count_attacker_bodies(player) > 0:
		return false
	return true


func _gardevoir_active_attacker_manual_attach_pressure_available(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if bool(game_state.energy_attached_this_turn):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return false
	if _slot_has_pressure_ready_gardevoir_attack(active, game_state, player_index):
		return false
	if _count_psychic_energy_in_hand(player) <= 0:
		return false
	if _gardevoir_min_attack_cost_gap(active, 1) > 0:
		return false
	var damage := _gardevoir_current_attacker_damage_estimate(active)
	if damage <= 0:
		return false
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	if opponent_hp > 0 and damage >= opponent_hp:
		return true
	return damage >= 120


func _gardevoir_runtime_manual_attach_enables_active_attacker_pressure(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	if not _runtime_action_card_is_psychic_energy(action):
		return false
	if not _runtime_action_targets_active_slot(action, game_state, player_index):
		return false
	return _gardevoir_active_attacker_manual_attach_pressure_available(game_state, player_index)


func _gardevoir_active_embrace_attack_setup_needed(game_state: GameState, player_index: int) -> bool:
	return _gardevoir_active_embrace_attack_gap(game_state, player_index) > 0


func _gardevoir_active_embrace_attack_gap(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return 0
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return 0
	var active: PokemonSlot = player.active_pokemon
	if _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return 0
	if not _gardevoir_slot_is_psychic(active):
		return 0
	if _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index) and _gardevoir_retreat_energy_gap(active) <= 0:
		return 0
	var discard_psychic := _count_psychic_energy_in_discard(player)
	if discard_psychic <= 0:
		return 0
	var active_remaining := _gardevoir_effective_remaining_hp(active, game_state)
	if active_remaining <= 20:
		return 0
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	var cd: CardData = active.get_card_data()
	if cd == null:
		return 0
	var best_gap := 99
	for raw_attack: Variant in cd.attacks:
		var attack: Dictionary = raw_attack if raw_attack is Dictionary else {}
		if attack.is_empty():
			continue
		var damage := _gardevoir_fixed_attack_damage(attack)
		if damage <= 0:
			continue
		var gap := _gardevoir_attack_cost_gap(active, str(attack.get("cost", "")), 0)
		if gap <= 0 or gap > discard_psychic:
			continue
		if active_remaining - gap * 20 <= 0:
			continue
		var takes_active_ko := opponent_hp > 0 and damage >= opponent_hp
		var emergency_pressure := _count_attacker_bodies(player) == 0 and damage >= 120 and _slot_name_matches_any(active, [GARDEVOIR_EX])
		if takes_active_ko or emergency_pressure:
			best_gap = mini(best_gap, gap)
	return best_gap if best_gap < 99 else 0


func _gardevoir_fixed_attack_damage(attack: Dictionary) -> int:
	var damage_text := str(attack.get("damage", "")).strip_edges()
	if damage_text == "" or damage_text.contains("x") or damage_text.contains("×") or damage_text.contains("+"):
		return 0
	return int(damage_text.to_int())


func _gardevoir_slot_is_psychic(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd: CardData = slot.get_card_data()
	return _energy_type_matches("Psychic", str(cd.energy_type)) or _energy_type_matches("Psychic", str(cd.energy_provides))


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
	var required_count := mini(max_select, items.size())
	var ranked: Array[Dictionary] = []
	var protected_ranked: Array[Dictionary] = []
	for item: Variant in items:
		if not (item is CardInstance) or (item as CardInstance).card_data == null:
			continue
		var card := item as CardInstance
		var protection_rank := _gardevoir_discard_protection_rank(card.card_data, game_state, player_index)
		if protection_rank > 0:
			protected_ranked.append({
				"card": item,
				"score": get_discard_priority_contextual(card, game_state, player_index),
				"protection": protection_rank,
			})
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
	if result.size() < required_count:
		protected_ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var protection_a := int(a.get("protection", 0))
			var protection_b := int(b.get("protection", 0))
			if protection_a == protection_b:
				return int(a.get("score", 0)) > int(b.get("score", 0))
			return protection_a < protection_b
		)
		for entry: Dictionary in protected_ranked:
			if result.size() >= required_count:
				break
			var picked: Variant = entry.get("card")
			if picked != null and not result.has(picked):
				result.append(picked)
	return result


func _is_gardevoir_protected_discard_card(card_data: CardData, game_state: GameState, player_index: int) -> bool:
	return _gardevoir_discard_protection_rank(card_data, game_state, player_index) > 0


func _gardevoir_discard_protection_rank(card_data: CardData, game_state: GameState, player_index: int) -> int:
	if card_data == null:
		return 0
	var name := _best_card_name(card_data)
	if _name_matches_any(name, GARDEVOIR_CORE_NAMES):
		return 1000
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return 0
	var engine_online := _count_field_name(player, GARDEVOIR_EX) > 0
	if _name_contains(name, SUPER_ROD) and (_gardevoir_super_rod_is_premature(game_state, player_index) or _gardevoir_discard_has_attacker_body(player)):
		return 700
	if _name_contains(name, NIGHT_STRETCHER) and _gardevoir_discard_has_attacker_body(player):
		return 720
	if not engine_online and _name_matches_any(name, [
		BUDDY_BUDDY_POFFIN,
		NEST_BALL,
		ULTRA_BALL,
		ARVEN,
		RARE_CANDY,
		TM_EVOLUTION,
		SECRET_BOX,
	]):
		return 850
	if card_data.is_energy() \
		and _energy_type_matches("Psychic", str(card_data.energy_provides)) \
		and _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state, player_index):
		return 800
	if _name_contains(name, BRAVERY_CHARM) and _gardevoir_bravery_charm_is_route_critical(player):
		return 450 if _count_attacker_bodies(player) <= 1 else 300
	if _name_contains(name, MUNKIDORI) and _gardevoir_munkidori_is_route_critical(player):
		if _gardevoir_accessible_copy_count(player, MUNKIDORI) > 1:
			return 650
		return 950
	if card_data.is_energy() \
		and _energy_type_matches("Darkness", str(card_data.energy_provides)) \
		and _gardevoir_darkness_energy_is_route_critical(player):
		return 930
	if engine_online and _name_matches_any(name, GARDEVOIR_ATTACKER_NAMES):
		return 940 if _count_attacker_bodies(player) < 2 else 0
	if engine_online and _count_attacker_bodies(player) == 0 and _name_matches_any(name, [DRIFLOON, SCREAM_TAIL, NIGHT_STRETCHER]):
		return 920
	return 0


func _gardevoir_bravery_charm_is_route_critical(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) > 0:
		return true
	if _count_field_name(player, KIRLIA) > 0:
		return true
	if _count_attacker_bodies(player) > 0:
		return true
	return false


func _gardevoir_munkidori_is_route_critical(player: PlayerState) -> bool:
	if player == null:
		return false
	if _count_field_name(player, MUNKIDORI) > 0:
		return false
	if not _gardevoir_munkidori_support_window_open(player):
		return false
	return (
		_count_attacker_bodies(player) > 0
		or _gardevoir_hand_has_any_card_name(player, GARDEVOIR_ATTACKER_NAMES)
		or _gardevoir_has_damage_counter_source(player)
		or _gardevoir_has_low_cost_basic_search_access(player)
	)


func _gardevoir_darkness_energy_is_route_critical(player: PlayerState) -> bool:
	if player == null:
		return false
	if not _gardevoir_munkidori_support_window_open(player):
		return false
	if _gardevoir_munkidori_has_dark_energy(player):
		return false
	var has_munkidori_access := _count_field_name(player, MUNKIDORI) > 0 or _gardevoir_hand_has_card_name(player, MUNKIDORI)
	if not has_munkidori_access and _count_field_name(player, GARDEVOIR_EX) > 0:
		has_munkidori_access = _gardevoir_player_has_card_name(player, MUNKIDORI)
	if not has_munkidori_access:
		return false
	return (
		_count_attacker_bodies(player) > 0
		or _gardevoir_hand_has_any_card_name(player, GARDEVOIR_ATTACKER_NAMES)
		or _gardevoir_has_damage_counter_source(player)
		or _gardevoir_has_low_cost_basic_search_access(player)
	)


func _gardevoir_munkidori_bench_window_open(player: PlayerState) -> bool:
	if player == null:
		return false
	if not _gardevoir_munkidori_support_window_open(player):
		return false
	if not _gardevoir_has_darkness_energy_access(player):
		return false
	if _gardevoir_has_damage_counter_source(player):
		return true
	return _count_attacker_bodies(player) >= 2


func _gardevoir_has_darkness_energy_access(player: PlayerState) -> bool:
	if player == null:
		return false
	if _gardevoir_munkidori_has_dark_energy(player):
		return true
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null:
			if card.card_data.is_energy() and _energy_type_matches("Darkness", str(card.card_data.energy_provides)):
				return true
			if _name_contains(_best_card_name(card.card_data), EARTHEN_VESSEL):
				return true
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type_matches("Darkness", str(card.card_data.energy_provides)):
			return true
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type_matches("Darkness", str(card.card_data.energy_provides)):
			return true
	return false


func _gardevoir_munkidori_support_window_open(player: PlayerState) -> bool:
	if player == null:
		return false
	return _count_field_name(player, GARDEVOIR_EX) > 0 or _count_field_name(player, KIRLIA) > 0


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
		if action_type == "use_ability" and _ref_has_any_name(ref, [KIRLIA, RADIANT_GRENINJA, GARDEVOIR_EX, MUNKIDORI]):
			return true
		if action_type in ["play_trainer", "play_stadium", "use_stadium_effect"] and _ref_has_any_name(ref, [
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


func _is_bad_gardevoir_costly_ultra_ball_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _runtime_action_has_any_name(action, [ULTRA_BALL]):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_field_name(player, GARDEVOIR_EX) <= 0:
		return false
	if not _gardevoir_has_low_cost_basic_search_access(player):
		return false
	var safe_discard_count := 0
	var route_critical_discard_count := 0
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _name_contains(_best_card_name(card.card_data), ULTRA_BALL):
			continue
		var protection_rank := _gardevoir_discard_protection_rank(card.card_data, game_state, player_index)
		if protection_rank >= 900:
			route_critical_discard_count += 1
		elif protection_rank <= 0:
			safe_discard_count += 1
	return route_critical_discard_count > 0 and safe_discard_count < 2


func _gardevoir_has_low_cost_basic_search_access(player: PlayerState) -> bool:
	if player == null:
		return false
	if _gardevoir_hand_has_card_name(player, BUDDY_BUDDY_POFFIN) or _gardevoir_hand_has_card_name(player, NEST_BALL):
		return true
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {}) if _llm_action_catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_action_ref(ref):
			continue
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type in ["play_trainer", "use_stadium_effect"] and _ref_has_any_name(ref, [BUDDY_BUDDY_POFFIN, NEST_BALL, ARTAZON]):
			return true
	return false


func _is_bad_gardevoir_basic_search_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	var search_step := _gardevoir_basic_search_step_for_ref(ref)
	if search_step == "":
		return false
	return not _gardevoir_has_good_basic_search_target(game_state, player_index, search_step)


func _is_bad_gardevoir_basic_search_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var search_step := _gardevoir_basic_search_step_for_action(action)
	if search_step == "":
		return false
	return not _gardevoir_has_good_basic_search_target(game_state, player_index, search_step)


func _gardevoir_basic_search_step_for_ref(ref: Dictionary) -> String:
	if _ref_has_any_name(ref, [BUDDY_BUDDY_POFFIN]):
		return "buddy_poffin_pokemon"
	if _ref_has_any_name(ref, [NEST_BALL]):
		return "basic_pokemon"
	if _ref_has_any_name(ref, [ARTAZON]):
		return "artazon_pokemon"
	return ""


func _gardevoir_basic_search_step_for_action(action: Dictionary) -> String:
	if _runtime_action_has_any_name(action, [BUDDY_BUDDY_POFFIN]):
		return "buddy_poffin_pokemon"
	if _runtime_action_has_any_name(action, [NEST_BALL]):
		return "basic_pokemon"
	if _runtime_action_has_any_name(action, [ARTAZON]):
		return "artazon_pokemon"
	return ""


func _gardevoir_has_good_basic_search_target(game_state: GameState, player_index: int, step_id: String) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var step := {"id": step_id, "max_select": 1}
	var context := {"game_state": game_state, "player_index": player_index}
	var saw_searchable := false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		if not _gardevoir_card_matches_basic_search_step(card.card_data, step_id):
			continue
		saw_searchable = true
		if _score_gardevoir_search_target(card, step, context) > 0.0:
			return true
	if not saw_searchable:
		return true
	return false


func _gardevoir_card_matches_basic_search_step(card_data: CardData, step_id: String) -> bool:
	if card_data == null or not card_data.is_pokemon() or not card_data.is_basic_pokemon():
		return false
	if step_id == "buddy_poffin_pokemon":
		return int(card_data.hp) <= 70
	if step_id == "artazon_pokemon":
		var mechanic := str(card_data.mechanic).strip_edges().to_lower()
		return mechanic == "" or mechanic == "none"
	return true


func _is_gardevoir_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["play_basic_to_bench", "evolve", "use_ability", "attach_tool"]:
		return not _deck_should_block_exact_queue_match({}, action, game_state, player_index)
	if kind == "attach_energy":
		if _is_bad_gardevoir_manual_attach(action, game_state, player_index):
			return false
		if _gardevoir_runtime_attach_enables_active_tm_bridge(action, game_state, player_index):
			return true
		if _gardevoir_runtime_attach_enables_active_retreat_bridge(action, game_state, player_index):
			return true
		if _gardevoir_active_manual_attach_emergency_attack_needed(game_state, player_index, _runtime_action_card_name(action)):
			return _runtime_action_targets_active_slot(action, game_state, player_index)
		return _runtime_action_has_any_name(action, [DRIFLOON, SCREAM_TAIL, MUNKIDORI])
	if kind == "retreat":
		return not _is_bad_gardevoir_retreat(action, game_state, player_index)
	if kind in ["play_trainer", "play_stadium", "use_stadium_effect"]:
		if _is_dead_gardevoir_gust_action(action):
			return false
		if _is_bad_gardevoir_basic_search_action(action, game_state, player_index):
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


func _gardevoir_runtime_attach_enables_active_tm_bridge(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	if not _runtime_action_card_is_psychic_energy(action):
		return false
	if not _runtime_action_targets_active_slot(action, game_state, player_index):
		return false
	return _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state, player_index)


func _gardevoir_runtime_attach_enables_active_retreat_bridge(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	if not _runtime_action_card_is_psychic_energy(action):
		return false
	if not _runtime_action_targets_active_slot(action, game_state, player_index):
		return false
	return _gardevoir_active_manual_attach_retreat_setup_needed(game_state, player_index, _runtime_action_card_name(action))


func _is_bad_gardevoir_tool_attach(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var tool_name := _runtime_action_card_name(action)
	if tool_name == "":
		return false
	if _name_contains(tool_name, TM_EVOLUTION) and _runtime_action_targets_known_non_active(action, game_state, player_index):
		return true
	var target_name := _runtime_action_target_name(action, "target", game_state, player_index)
	if _name_contains(tool_name, TM_EVOLUTION):
		if target_name == "":
			return false
		if _gardevoir_tm_active_support_has_no_psychic_fuel(action, game_state, player_index, target_name):
			return true
		if _gardevoir_runtime_tm_target_does_not_solve_attacker_gap(action, game_state, player_index):
			return true
		if _runtime_action_target_is_gardevoir_attacker(action, game_state, player_index):
			return true
		return not _name_matches_any(target_name, [KLEFKI, FLUTTER_MANE, MUNKIDORI, RALTS])
	if _name_contains(tool_name, BRAVERY_CHARM):
		if target_name == "":
			return true
		if _gardevoir_active_attacker_should_receive_bravery(game_state, player_index) and not _runtime_action_targets_active_slot(action, game_state, player_index):
			return true
		if _gardevoir_drifloon_should_receive_bravery(game_state, player_index) and not _runtime_action_targets_name_or_slot(action, "target", [DRIFLOON], game_state, player_index):
			return true
		return not _name_matches_any(target_name, GARDEVOIR_ATTACKER_NAMES)
	return false


func _gardevoir_tm_active_support_has_no_psychic_fuel(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	target_name: String
) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _runtime_action_targets_active_slot(action, game_state, player_index):
		return false
	if not _name_matches_any(target_name, [FLUTTER_MANE, MUNKIDORI]):
		return false
	if not player.active_pokemon.attached_energy.is_empty():
		return false
	return _count_psychic_energy_in_hand(player) <= 0 and _count_psychic_energy_in_discard(player) <= 0


func _gardevoir_active_attacker_should_receive_bravery(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if not _slot_name_matches_any(active, GARDEVOIR_ATTACKER_NAMES):
		return false
	if _slot_has_tool_name(active, BRAVERY_CHARM):
		return false
	return _count_field_name(player, GARDEVOIR_EX) > 0 or _slot_has_ready_gardevoir_attack(active)


func _gardevoir_drifloon_should_receive_bravery(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _gardevoir_active_attacker_should_receive_bravery(game_state, player_index):
		return false
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return false
	for slot: PokemonSlot in _all_player_slots(player):
		if slot != null and _slot_name_matches_any(slot, [DRIFLOON]) and not _slot_has_tool_name(slot, BRAVERY_CHARM):
			return true
	return false


func _ref_target_is_gardevoir_attacker(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	var target_slot := _ref_target_slot(ref, game_state, player_index)
	if target_slot != null:
		return _slot_name_matches_any(target_slot, GARDEVOIR_ATTACKER_NAMES)
	return _name_matches_any(_ref_target_name(ref, game_state, player_index), GARDEVOIR_ATTACKER_NAMES)


func _runtime_action_target_is_gardevoir_attacker(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var target_slot := _runtime_action_target_slot(action, "target", game_state, player_index)
	if target_slot != null:
		return _slot_name_matches_any(target_slot, GARDEVOIR_ATTACKER_NAMES)
	return _name_matches_any(_runtime_action_target_name(action, "target", game_state, player_index), GARDEVOIR_ATTACKER_NAMES)


func _ref_targets_name_or_slot(ref: Dictionary, names: Array[String], game_state: GameState, player_index: int) -> bool:
	var target_slot := _ref_target_slot(ref, game_state, player_index)
	if target_slot != null:
		return _slot_name_matches_any(target_slot, names)
	return _name_matches_any(_ref_target_name(ref, game_state, player_index), names)


func _runtime_action_targets_name_or_slot(action: Dictionary, key: String, names: Array[String], game_state: GameState, player_index: int) -> bool:
	var target_slot := _runtime_action_target_slot(action, key, game_state, player_index)
	if target_slot != null:
		return _slot_name_matches_any(target_slot, names)
	return _name_matches_any(_runtime_action_target_name(action, key, game_state, player_index), names)


func _is_dead_gardevoir_gust_action(action: Dictionary) -> bool:
	if not _runtime_action_has_any_name(action, [COUNTER_CATCHER, BOSSS_ORDERS]):
		return false
	return not _gardevoir_current_queue_has_attack_terminal()


func _is_bad_gardevoir_premature_recovery_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _ref_has_any_name(ref, [SUPER_ROD]):
		return false
	return _gardevoir_super_rod_is_premature(game_state, player_index)


func _is_bad_gardevoir_premature_recovery_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _runtime_action_has_any_name(action, [SUPER_ROD]):
		return false
	return _gardevoir_super_rod_is_premature(game_state, player_index)


func _gardevoir_super_rod_is_premature(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _gardevoir_discard_has_attacker_body(player):
		return false
	if player.deck.size() <= 8:
		return false
	return true


func _gardevoir_discard_has_attacker_body(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		if _name_matches_any(_best_card_name(card.card_data), GARDEVOIR_ATTACKER_NAMES):
			return true
	return false


func _is_bad_gardevoir_preserve_supporter_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _ref_has_any_name(ref, [PROFESSOR_TUROS_SCENARIO]):
		return false
	return _gardevoir_preserve_supporter_breaks_attack_pressure(game_state, player_index)


func _is_bad_gardevoir_preserve_supporter_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _runtime_action_has_any_name(action, [PROFESSOR_TUROS_SCENARIO]):
		return false
	return _gardevoir_preserve_supporter_breaks_attack_pressure(game_state, player_index)


func _gardevoir_preserve_supporter_breaks_attack_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) > 0:
		return true
	if _count_pressure_ready_attackers(player, game_state, player_index) > 0:
		return true
	if _count_attacker_bodies(player) > 0 and _count_psychic_energy_in_discard(player) > 0:
		return true
	return false


func _is_gardevoir_gust_ref(ref: Dictionary) -> bool:
	return _ref_has_any_name(ref, [COUNTER_CATCHER, BOSSS_ORDERS])


func _is_bad_gardevoir_manual_attach(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> bool:
	if not _runtime_action_card_is_energy(action):
		return false
	var target_name := _runtime_action_target_name(action, "target", game_state, player_index)
	if target_name == "":
		return false
	var energy_name := _runtime_action_card_name(action)
	if _name_contains(energy_name, DARKNESS_ENERGY) and _name_matches_any(target_name, [MUNKIDORI]):
		var target_slot := _runtime_action_target_slot(action, "target", game_state, player_index)
		if _slot_has_energy_type(target_slot, "Darkness"):
			return true
	if _name_contains(energy_name, DARKNESS_ENERGY) and not _name_matches_any(target_name, [MUNKIDORI]):
		return true
	if _runtime_action_card_is_psychic_energy(action) and _name_matches_any(target_name, [MUNKIDORI]):
		return true
	if _runtime_action_card_is_psychic_energy(action) and _gardevoir_tm_evolution_bridge_needs_hand_psychic(game_state, player_index):
		return not _runtime_action_targets_active_slot(action, game_state, player_index)
	if _runtime_action_card_is_psychic_energy(action) and _gardevoir_active_manual_attach_retreat_setup_needed(game_state, player_index, energy_name):
		return not _runtime_action_targets_active_slot(action, game_state, player_index)
	if _runtime_action_card_is_psychic_energy(action) and _gardevoir_active_manual_attach_emergency_attack_needed(game_state, player_index, energy_name) and _runtime_action_targets_active_slot(action, game_state, player_index):
		return false
	var low_value_targets: Array[String] = []
	low_value_targets.append_array(GARDEVOIR_CORE_NAMES)
	low_value_targets.append_array([MANAPHY, RADIANT_GRENINJA, KLEFKI, FLUTTER_MANE])
	if _runtime_action_targets_active_slot(action, game_state, player_index) and _gardevoir_active_manual_attach_retreat_setup_needed(game_state, player_index, energy_name):
		return false
	if not _name_matches_any(target_name, low_value_targets):
		return false
	if _runtime_action_targets_known_non_active(action, game_state, player_index):
		return true
	if _runtime_action_target_has_tool_name(action, "target", TM_EVOLUTION):
		return false
	return not _gardevoir_current_queue_has_tm_evolution_route()


func _is_bad_gardevoir_evolve(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _name_contains(_runtime_action_card_name(action), GARDEVOIR_EX):
		return false
	var target_slot := _runtime_action_target_slot(action, "target", game_state, player_index)
	return _gardevoir_should_preserve_active_kirlia_from_ex_evolve(target_slot, game_state, player_index)


func _is_bad_gardevoir_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var raw_bench_target: Variant = action.get("bench_target", null)
	var bench_target: PokemonSlot = raw_bench_target as PokemonSlot if raw_bench_target is PokemonSlot else null
	var bad_targets: Array[String] = []
	bad_targets.append_array(GARDEVOIR_CORE_NAMES)
	bad_targets.append_array(GARDEVOIR_SUPPORT_NAMES)
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index):
			return true
	if bench_target == null:
		var target_name := _runtime_action_target_name(action, "bench_target")
		return target_name != "" and _name_matches_any(target_name, bad_targets)
	if _gardevoir_active_tm_evolution_bridge_available(game_state, player_index):
		return not _slot_has_pressure_ready_gardevoir_attack(bench_target, game_state, player_index)
	if _is_gardevoir_bad_handoff_target(bench_target, game_state, player_index):
		return true
	if _slot_name_matches_any(bench_target, bad_targets):
		return true
	return false


func _is_gardevoir_bad_handoff_target(target_slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if target_slot == null or not _slot_name_matches_any(target_slot, GARDEVOIR_ATTACKER_NAMES):
		return false
	if _gardevoir_retreat_target_is_live_conversion(target_slot, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _slot_name_matches_any(player.active_pokemon, [GARDEVOIR_EX]) and _gardevoir_effective_remaining_hp(player.active_pokemon, game_state) <= 120:
		return false
	return true


func _gardevoir_retreat_target_is_live_conversion(target_slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if target_slot == null:
		return false
	if _slot_has_ready_gardevoir_attack(target_slot):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, GARDEVOIR_EX) <= 0:
		return false
	var gap := _gardevoir_min_attack_cost_gap(target_slot, 0)
	if gap <= 0:
		return true
	return _count_psychic_energy_in_discard(player) >= gap


func _is_bad_gardevoir_deck_draw_ability(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.deck.size() > 12:
		return false
	if not _runtime_action_has_any_name(action, [KIRLIA, RADIANT_GRENINJA, "Refinement", "Concealed Cards"]):
		return false
	return not _runtime_action_has_any_name(action, [GARDEVOIR_EX, "Psychic Embrace"])


func _is_dangerous_gardevoir_core_pivot_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if _is_tm_evolution_granted_attack_ref(action, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _slot_name_matches_any(player.active_pokemon, [RALTS]):
		return false
	if _gardevoir_attack_kos_opponent_active(player.active_pokemon, game_state, player_index):
		return false
	return _attack_ref_can_switch_own_active(action, player.active_pokemon) and not player.bench.is_empty()


func _attack_ref_can_switch_own_active(action: Dictionary, active: PokemonSlot) -> bool:
	if _slot_name_matches_any(active, [RALTS]) and int(action.get("attack_index", -1)) == 0 and bool(action.get("requires_interaction", false)):
		return true
	var schema: Dictionary = action.get("interaction_schema", {}) if action.get("interaction_schema", {}) is Dictionary else {}
	if schema.has("switch_target") or schema.has("own_bench_target"):
		return true
	var attack_name := str(action.get("attack_name", "")).to_lower()
	if attack_name.contains("teleport"):
		return true
	var attack_index := int(action.get("attack_index", -1))
	if active == null or active.get_card_data() == null or attack_index < 0 or attack_index >= active.get_card_data().attacks.size():
		return false
	var attack: Dictionary = active.get_card_data().attacks[attack_index] if active.get_card_data().attacks[attack_index] is Dictionary else {}
	var text := "%s %s" % [str(attack.get("name", "")), str(attack.get("text", attack.get("description", "")))]
	var lower := text.to_lower()
	return lower.contains("teleport") or (lower.contains("switch") and lower.contains("bench"))


func _is_tm_evolution_granted_attack_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(ref.get("type", ref.get("kind", ""))) != "granted_attack":
		return false
	if _ref_has_any_name(ref, [TM_EVOLUTION, "Evolution", "tm_evolution", "进化"]):
		return true
	if int(ref.get("attack_index", -1)) != -1:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and _slot_has_tool_name(player.active_pokemon, TM_EVOLUTION)


func _is_bad_gardevoir_tm_evolution_attack_ref(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_tm_evolution_granted_attack_ref(ref, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if _has_pressure_ready_bench_gardevoir_attacker(player, game_state, player_index) \
			and not _active_is_pressure_ready_gardevoir_attacker(player, game_state, player_index):
		return true
	if not _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES):
		return false
	if _slot_has_ready_gardevoir_attack(player.active_pokemon) and _gardevoir_current_attacker_damage_estimate(player.active_pokemon) > 0:
		return true
	return _count_field_name(player, GARDEVOIR_EX) > 0 and _count_psychic_energy_in_discard(player) > 0


func _gardevoir_active_tm_evolution_bridge_available(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if player.active_pokemon.attached_energy.is_empty():
		return false
	if not _slot_has_tool_name(player.active_pokemon, TM_EVOLUTION):
		return false
	if _gardevoir_catalog_has_tm_evolution_granted_attack(game_state, player_index):
		return true
	return _gardevoir_has_tm_evolution_bench_target(player)


func _gardevoir_attack_kos_opponent_active(active: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if active == null or game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null:
		return false
	var damage := int(predict_attacker_damage(active).get("damage", 0))
	return damage > 0 and damage >= _gardevoir_effective_remaining_hp(opponent.active_pokemon, game_state)


func _is_bad_gardevoir_support_bench(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var name := _runtime_action_card_name(action)
	if not _name_matches_any(name, GARDEVOIR_SUPPORT_NAMES):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _name_contains(name, MANAPHY):
		return not _opponent_has_bench_spread_pressure(game_state, player_index) or _gardevoir_needs_core_redundancy(player)
	if _name_contains(name, MUNKIDORI):
		if _count_field_name(player, MUNKIDORI) > 0:
			return true
		return not _gardevoir_munkidori_bench_window_open(player)
	if _count_attacker_bodies(player) == 0 and _gardevoir_bench_slots_remaining(player) <= 1:
		return true
	if _count_field_name(player, GARDEVOIR_EX) > 0 and _count_attacker_bodies(player) < 2:
		return true
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
			if lower.contains("damage counter"):
				continue
			if lower.contains("damage to 2") or lower.contains("each of your opponent") or lower.contains("all of your opponent"):
				return true
			if text.contains("备战") and text.contains("造成") and not text.contains("数量"):
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
		IONO,
	]:
		if _name_contains(name, query):
			return true
	return false


func _name_contains(full_name: String, query: String) -> bool:
	if super._name_contains(full_name, query):
		return true
	for alias: String in _gardevoir_name_aliases(query):
		if super._name_contains(full_name, alias):
			return true
	return false


func _gardevoir_name_aliases(query: String) -> Array[String]:
	match query.strip_edges().to_lower():
		"ralts":
			return ["拉鲁拉丝"]
		"kirlia":
			return ["奇鲁莉安"]
		"gardevoir ex":
			return ["沙奈朵ex"]
		"drifloon":
			return ["飘飘球"]
		"drifblim":
			return ["随风球"]
		"scream tail":
			return ["吼叫尾"]
		"munkidori":
			return ["愿增猿"]
		"radiant greninja":
			return ["光辉甲贺忍蛙"]
		"klefki":
			return ["钥圈儿"]
		"flutter mane":
			return ["振翼发"]
		"manaphy":
			return ["玛纳霏"]
		"buddy-buddy poffin":
			return ["友好宝芬"]
		"nest ball":
			return ["巢穴球"]
		"ultra ball":
			return ["高级球"]
		"earthen vessel":
			return ["大地容器"]
		"rare candy":
			return ["神奇糖果"]
		"technical machine: evolution":
			return ["招式学习器 进化"]
		"arven":
			return ["派帕"]
		"artazon":
			return ["深钵镇"]
		"secret box":
			return ["秘密箱"]
		"night stretcher":
			return ["夜间担架"]
		"super rod":
			return ["厉害钓竿"]
		"bravery charm":
			return ["勇气护符"]
		"counter catcher":
			return ["反击捕捉器"]
		"boss's orders":
			return ["老大的指令"]
		"professor turo's scenario":
			return ["弗图博士的剧本"]
		"iono":
			return ["奇树"]
		"psychic energy":
			return ["基本超能量"]
		"darkness energy":
			return ["基本恶能量"]
		_:
			return []


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("attack_name", "")),
		str(ref.get("target", "")),
		str(ref.get("target_name_en", "")),
		str(ref.get("pokemon_name_en", "")),
		str(ref.get("bench_target", "")),
		str(ref.get("bench_target_name_en", "")),
		str(ref.get("summary", "")),
	]
	for key: String in ["card_rules", "ability_rules", "attack_rules", "granted_attack_data"]:
		var raw: Variant = ref.get(key, {})
		if raw is Dictionary:
			var rules: Dictionary = raw
			parts.append(str(rules.get("id", "")))
			parts.append(str(rules.get("name", "")))
			parts.append(str(rules.get("name_en", "")))
			parts.append(str(rules.get("cost", "")))
			parts.append(str(rules.get("damage", "")))
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


func _runtime_action_card_is_psychic_energy(action: Dictionary) -> bool:
	var card: Variant = action.get("card", null)
	if card is CardInstance and (card as CardInstance).card_data != null:
		var card_data: CardData = (card as CardInstance).card_data
		return card_data.is_energy() and (_name_contains(_best_card_name(card_data), PSYCHIC_ENERGY) or _energy_type_matches("Psychic", str(card_data.energy_provides)))
	if card is CardData:
		var card_data := card as CardData
		return card_data.is_energy() and (_name_contains(_best_card_name(card_data), PSYCHIC_ENERGY) or _energy_type_matches("Psychic", str(card_data.energy_provides)))
	if card is Dictionary:
		var card_dict: Dictionary = card
		if _name_contains(str(card_dict.get("name_en", card_dict.get("name", ""))), PSYCHIC_ENERGY):
			return true
		if _energy_type_matches("Psychic", str(card_dict.get("energy_provides", ""))):
			return true
	return _name_contains(str(card), PSYCHIC_ENERGY)


func _runtime_action_card_is_energy(action: Dictionary) -> bool:
	var card: Variant = action.get("card", null)
	if card is CardInstance and (card as CardInstance).card_data != null:
		return (card as CardInstance).card_data.is_energy()
	if card is CardData:
		return (card as CardData).is_energy()
	if card is Dictionary:
		var card_dict: Dictionary = card
		if str(card_dict.get("energy_provides", "")) != "":
			return true
		if str(card_dict.get("energy", "")) != "":
			return true
		var card_type := str(card_dict.get("card_type", card_dict.get("type", "")))
		if _name_contains(card_type, "Energy") or _name_contains(card_type, "能量"):
			return true
	var card_name := _runtime_action_card_name(action)
	if _name_contains(card_name, "Energy") or _name_contains(card_name, "能量"):
		return true
	return str(action.get("kind", action.get("type", ""))) == "attach_energy"


func _runtime_action_target_name(action: Dictionary, key: String, game_state: GameState = null, player_index: int = -1) -> String:
	for name_key: String in _runtime_action_target_name_keys(key):
		var explicit_name := str(action.get(name_key, ""))
		if explicit_name != "":
			return explicit_name
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
		var name := str(target_dict.get("name", ""))
		if name != "":
			return name
		var position := str(target_dict.get("position", target_dict.get("target_position", ""))).strip_edges().to_lower()
		var slot := _slot_for_position(game_state, player_index, position)
		if slot != null:
			return _slot_best_name(slot)
	var position := str(action.get("position", action.get("target_position", ""))).strip_edges().to_lower()
	var slot := _slot_for_position(game_state, player_index, position)
	if slot != null:
		return _slot_best_name(slot)
	if raw_target != null:
		var target_text := str(raw_target).strip_edges()
		if target_text.to_lower() in ["active", "bench_0", "bench_1", "bench_2", "bench_3", "bench_4"]:
			slot = _slot_for_position(game_state, player_index, target_text.to_lower())
			if slot != null:
				return _slot_best_name(slot)
		return target_text
	return ""


func _runtime_action_target_slot(action: Dictionary, key: String, game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var slot_key := "target_slot" if key == "target" else key
	var slot_value: Variant = action.get(slot_key, null)
	if slot_value is PokemonSlot:
		return slot_value as PokemonSlot
	var raw_target: Variant = action.get(key, null)
	if raw_target is PokemonSlot:
		return raw_target as PokemonSlot
	if raw_target is Dictionary:
		var target_dict: Dictionary = raw_target
		var dict_position := str(target_dict.get("position", target_dict.get("target_position", ""))).strip_edges().to_lower()
		var dict_slot := _slot_for_position(game_state, player_index, dict_position)
		if dict_slot != null:
			return dict_slot
	var position := str(action.get("position", action.get("target_position", ""))).strip_edges().to_lower()
	var slot := _slot_for_position(game_state, player_index, position)
	if slot != null:
		return slot
	if raw_target != null:
		var target_text := str(raw_target).strip_edges().to_lower()
		if target_text in ["active", "bench_0", "bench_1", "bench_2", "bench_3", "bench_4"]:
			slot = _slot_for_position(game_state, player_index, target_text)
			if slot != null:
				return slot
	var target_name := _runtime_action_target_name(action, key, game_state, player_index)
	if target_name == "":
		return null
	var player: PlayerState = game_state.players[player_index]
	if _slot_name_matches_any(player.active_pokemon, [target_name]):
		return player.active_pokemon
	for bench_slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(bench_slot, [target_name]):
			return bench_slot
	return null


func _runtime_action_target_name_keys(key: String) -> Array[String]:
	if key == "target":
		return [
			"target_name_en",
			"target_name",
			"target_pokemon_name_en",
			"target_pokemon_name",
		]
	return [
		"%s_name_en" % key,
		"%s_name" % key,
	]


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


func _runtime_action_targets_active_slot(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var target_slot: Variant = action.get("target_slot", null)
	if target_slot is PokemonSlot:
		return (target_slot as PokemonSlot) == player.active_pokemon
	var raw_target: Variant = action.get("target", null)
	if raw_target is PokemonSlot:
		return (raw_target as PokemonSlot) == player.active_pokemon
	if raw_target is Dictionary:
		var position := str((raw_target as Dictionary).get("position", (raw_target as Dictionary).get("target_position", ""))).strip_edges().to_lower()
		if position == "active":
			return true
		if position.begins_with("bench"):
			return false
	var target_name := _runtime_action_target_name(action, "target")
	return target_name != "" and _name_matches_any(target_name, [_slot_best_name(player.active_pokemon)])


func _gardevoir_current_queue_has_tm_evolution_route() -> bool:
	for queued_action: Dictionary in _llm_action_queue:
		var kind := str(queued_action.get("kind", queued_action.get("type", "")))
		if kind == "attach_tool" and _ref_has_any_name(queued_action, [TM_EVOLUTION]):
			return true
		if kind in ["attack", "granted_attack"] and (_ref_has_any_name(queued_action, [TM_EVOLUTION]) or _ref_has_any_name(queued_action, ["Evolution", "tm_evolution", "进化"])):
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


func _gardevoir_should_preserve_active_kirlia_from_ex_evolve(target_slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if target_slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or target_slot != player.active_pokemon:
		return false
	if not _slot_name_matches_any(target_slot, [KIRLIA]):
		return false
	if _has_bench_slot_name(player, KIRLIA):
		return true
	if _count_field_name(player, GARDEVOIR_EX) > 0:
		return true
	return false


func _has_bench_slot_name(player: PlayerState, query: String) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_name_matches_any(slot, [query]):
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


func _count_psychic_energy_in_hand(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy() and _energy_type_matches("Psychic", str(card.card_data.energy_provides)):
			count += 1
	return count


func _gardevoir_hand_has_card_name(player: PlayerState, query: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _name_contains(_best_card_name(card.card_data), query):
			return true
	return false


func _gardevoir_hand_has_any_card_name(player: PlayerState, queries: Array) -> bool:
	for query: Variant in queries:
		if _gardevoir_hand_has_card_name(player, str(query)):
			return true
	return false


func _gardevoir_accessible_copy_count(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := _count_field_name(player, query)
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			count += 1
	return count


func _gardevoir_has_damage_counter_source(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_player_slots(player):
		if slot != null and slot.damage_counters >= 10:
			return true
	return false


func _gardevoir_munkidori_has_dark_energy(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_player_slots(player):
		if not _slot_name_matches_any(slot, [MUNKIDORI]):
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and _energy_type_matches("Darkness", str(energy.card_data.energy_provides)):
				return true
	return false


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


func _count_ready_bench_attackers(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _slot_has_ready_gardevoir_attack(slot):
			count += 1
	return count


func _count_pressure_ready_attackers(player: PlayerState, game_state: GameState, player_index: int) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_player_slots(player):
		if _slot_has_pressure_ready_gardevoir_attack(slot, game_state, player_index):
			count += 1
	return count


func _count_pressure_ready_bench_attackers(player: PlayerState, game_state: GameState, player_index: int) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if _slot_has_pressure_ready_gardevoir_attack(slot, game_state, player_index):
			count += 1
	return count


func _active_is_ready_gardevoir_attacker(player: PlayerState) -> bool:
	return player != null and _slot_has_ready_gardevoir_attack(player.active_pokemon)


func _active_is_pressure_ready_gardevoir_attacker(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	return player != null and _slot_has_pressure_ready_gardevoir_attack(player.active_pokemon, game_state, player_index)


func _active_is_productive_ready_gardevoir_attacker(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null or not _slot_has_ready_gardevoir_attack(player.active_pokemon):
		return false
	if _active_gardevoir_attacker_needs_more_embrace_pressure(game_state, player_index):
		return false
	var damage := _gardevoir_current_attacker_damage_estimate(player.active_pokemon)
	if damage <= 0:
		return false
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	if opponent_hp > 0 and damage >= opponent_hp - 30:
		return true
	return damage >= 80


func _active_gardevoir_attacker_kos_now(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _slot_has_ready_gardevoir_attack(player.active_pokemon):
		return false
	var damage := _gardevoir_current_attacker_damage_estimate(player.active_pokemon)
	if damage <= 0:
		return false
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	return opponent_hp > 0 and damage >= opponent_hp


func _gardevoir_active_core_attack_ready(game_state: GameState, player_index: int) -> bool:
	return not _gardevoir_best_active_core_attack(game_state, player_index).is_empty()


func _gardevoir_best_active_core_attack(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return {}
	if _count_attacker_bodies(player) > 0:
		return {}
	if not _slot_name_matches_any(player.active_pokemon, [GARDEVOIR_EX]):
		return {}
	var cd: CardData = player.active_pokemon.get_card_data()
	if cd == null:
		return {}
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	var best: Dictionary = {}
	for i: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[i] if cd.attacks[i] is Dictionary else {}
		if attack.is_empty():
			continue
		if _gardevoir_attack_cost_gap(player.active_pokemon, str(attack.get("cost", ""))) > 0:
			continue
		var damage := _gardevoir_fixed_attack_damage(attack)
		if damage <= 0:
			continue
		var takes_ko := opponent_hp > 0 and damage >= opponent_hp
		if damage < 120 and not takes_ko:
			continue
		if best.is_empty() or damage > int(best.get("damage", 0)):
			best = {
				"attack_index": i,
				"attack_name": str(attack.get("name", "")),
				"damage": damage,
				"takes_ko": takes_ko,
			}
	return best


func _gardevoir_active_core_attack_ref_from_snapshot(snapshot: Dictionary) -> Dictionary:
	if not bool(snapshot.get("active_gardevoir_core_attack_ready", false)):
		return {}
	var attack_index := int(snapshot.get("active_gardevoir_core_attack_index", -1))
	if attack_index < 0:
		return {}
	return {
		"type": "attack",
		"kind": "attack",
		"capability": "attack",
		"attack_index": attack_index,
		"attack_name": str(snapshot.get("active_gardevoir_core_attack_name", "")),
		"route_goal": "active_gardevoir_core_emergency_conversion",
	}


func _gardevoir_runtime_attack_matches_active_core_conversion(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var best := _gardevoir_best_active_core_attack(game_state, player_index)
	if best.is_empty():
		return false
	var attack_index := int(action.get("attack_index", -1))
	if attack_index >= 0:
		return attack_index == int(best.get("attack_index", -2))
	var attack_name := str(action.get("attack_name", ""))
	return attack_name == "" or _name_contains(attack_name, str(best.get("attack_name", ""))) or _name_contains(str(best.get("attack_name", "")), attack_name)


func _is_optional_gardevoir_action_after_active_ko_ready(action: Dictionary) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["attack", "granted_attack", "end_turn"]:
		return false
	return true


func _gardevoir_active_is_attacker(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null and _slot_name_matches_any(player.active_pokemon, GARDEVOIR_ATTACKER_NAMES)


func _has_ready_bench_gardevoir_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_has_ready_gardevoir_attack(slot):
			return true
	return false


func _has_pressure_ready_bench_gardevoir_attacker(player: PlayerState, game_state: GameState, player_index: int) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _slot_has_pressure_ready_gardevoir_attack(slot, game_state, player_index):
			return true
	return false


func _slot_has_ready_gardevoir_attack(slot: PokemonSlot) -> bool:
	if slot == null or not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		return false
	if _gardevoir_payoff_attack_cost_gap(slot, 0) <= 0 and _gardevoir_embrace_damage_estimate(slot, 0) > 0:
		return true
	return false


func _slot_has_any_ready_gardevoir_attack(slot: PokemonSlot) -> bool:
	if slot == null or not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		return false
	var predicted: Dictionary = predict_attacker_damage(slot)
	if bool(predicted.get("can_attack", false)) and int(predicted.get("damage", 0)) > 0:
		return true
	return _gardevoir_min_attack_cost_gap(slot, 0) <= 0 and _gardevoir_embrace_damage_estimate(slot, 0) > 0


func _slot_has_pressure_ready_gardevoir_attack(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	if not _slot_has_ready_gardevoir_attack(slot):
		return false
	var damage := _gardevoir_current_attacker_damage_estimate(slot)
	if damage <= 0:
		return false
	if _gardevoir_slot_can_take_visible_prize(slot, game_state, player_index):
		return true
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	if opponent_hp > 0 and damage >= opponent_hp:
		return true
	return damage >= 120


func _gardevoir_slot_can_take_visible_prize(slot: PokemonSlot, game_state: GameState, player_index: int) -> bool:
	return _gardevoir_slot_can_take_visible_prize_with_damage(slot, game_state, player_index, _gardevoir_current_attacker_damage_estimate(slot))


func _gardevoir_slot_can_take_visible_prize_with_damage(slot: PokemonSlot, game_state: GameState, player_index: int, damage: int) -> bool:
	if slot == null or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if damage <= 0:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	if opponent.active_pokemon != null and _gardevoir_effective_remaining_hp(opponent.active_pokemon, game_state) <= damage:
		return true
	if not _slot_name_matches_any(slot, [SCREAM_TAIL]):
		return false
	for bench_slot: PokemonSlot in opponent.bench:
		if bench_slot == null:
			continue
		if _gardevoir_effective_remaining_hp(bench_slot, game_state) <= damage:
			return true
	return false


func _gardevoir_current_attacker_damage_estimate(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var name := _slot_best_name(slot)
	if _name_contains(name, DRIFLOON) or _name_contains(name, DRIFBLIM) or _name_contains(name, SCREAM_TAIL):
		return _gardevoir_embrace_damage_estimate(slot, 0)
	return int(predict_attacker_damage(slot).get("damage", 0))


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	if game_state == null:
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null:
		return 0
	return _gardevoir_effective_remaining_hp(opponent.active_pokemon, game_state)


func _gardevoir_min_attack_cost_gap(slot: PokemonSlot, extra_psychic_energy: int = 0) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	if _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		return _gardevoir_payoff_attack_cost_gap(slot, extra_psychic_energy)
	return _gardevoir_min_any_attack_cost_gap(slot, extra_psychic_energy)


func _gardevoir_min_any_attack_cost_gap(slot: PokemonSlot, extra_psychic_energy: int = 0) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	var cd: CardData = slot.get_card_data()
	if cd.attacks.is_empty():
		return 99
	var best_gap := 99
	for attack: Dictionary in cd.attacks:
		best_gap = mini(best_gap, _gardevoir_attack_cost_gap(slot, str(attack.get("cost", "")), extra_psychic_energy))
	return best_gap


func _gardevoir_payoff_attack_cost_gap(slot: PokemonSlot, extra_psychic_energy: int = 0) -> int:
	if slot == null or slot.get_card_data() == null:
		return 99
	var cd: CardData = slot.get_card_data()
	if cd.attacks.is_empty():
		return 99
	var best_payoff_gap := 99
	for i: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[i]
		if _gardevoir_is_payoff_attacker_attack(slot, attack, i, cd.attacks.size()):
			best_payoff_gap = mini(best_payoff_gap, _gardevoir_attack_cost_gap(slot, str(attack.get("cost", "")), extra_psychic_energy))
	if best_payoff_gap < 99:
		return best_payoff_gap
	return _gardevoir_min_any_attack_cost_gap(slot, extra_psychic_energy)


func _gardevoir_is_payoff_attacker_attack(slot: PokemonSlot, attack: Dictionary, attack_index: int, attack_count: int) -> bool:
	if slot == null or not _slot_name_matches_any(slot, GARDEVOIR_ATTACKER_NAMES):
		return false
	if attack_count <= 1:
		return true
	var attack_name := str(attack.get("name", ""))
	if _name_contains(attack_name, "Balloon") or _name_contains(attack_name, "Roaring") or _name_contains(attack_name, "Scream"):
		return true
	if _name_contains(attack_name, "气球") or _name_contains(attack_name, "凶暴") or _name_contains(attack_name, "吼叫"):
		return true
	var damage_text := str(attack.get("damage", "")).to_lower()
	if damage_text.contains("x") or damage_text.contains("×"):
		return true
	var rules_text := str(attack.get("text", "")).to_lower()
	if rules_text.contains("damage counter") or rules_text.contains("伤害指示"):
		return true
	if (_slot_name_matches_any(slot, [DRIFLOON, DRIFBLIM, SCREAM_TAIL]) and attack_index >= 1):
		return true
	return false


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


func _slot_has_tool_name(slot: PokemonSlot, query: String) -> bool:
	if slot == null or slot.attached_tool == null or slot.attached_tool.card_data == null:
		return false
	return _name_contains(_best_card_name(slot.attached_tool.card_data), query)


func _slot_has_energy_type(slot: PokemonSlot, query: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if _energy_type_matches(query, str(energy.card_data.energy_provides)):
			return true
		if _name_contains(_best_card_name(energy.card_data), "%s Energy" % query):
			return true
	return false


func _gardevoir_effective_remaining_hp(slot: PokemonSlot, game_state: GameState = null) -> int:
	if slot == null:
		return 0
	var raw_remaining := slot.get_remaining_hp()
	if game_state != null:
		var processor := EffectProcessor.new()
		var processor_remaining := processor.get_effective_remaining_hp(slot, game_state)
		if processor_remaining != raw_remaining:
			return processor_remaining
	return raw_remaining + _gardevoir_known_tool_hp_bonus(slot)


func _gardevoir_known_tool_hp_bonus(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	if str(slot.get_card_data().stage) != "Basic":
		return 0
	if _slot_has_tool_name(slot, BRAVERY_CHARM):
		return 50
	return 0


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
