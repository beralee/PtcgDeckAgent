extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const LugiaArcheopsRulesScript = preload("res://scripts/ai/DeckStrategyLugiaArcheops.gd")

const LUGIA_ARCHETYPE_LLM_ID := "lugia_archeops_llm"
const LUGIA_V := "Lugia V"
const LUGIA_VSTAR := "Lugia VSTAR"
const ARCHEOPS := "Archeops"
const MINCCINO := "Minccino"
const CINCCINO := "Cinccino"
const LUMINEON_V := "Lumineon V"
const FEZANDIPITI_EX := "Fezandipiti ex"
const IRON_HANDS_EX := "Iron Hands ex"
const BLOODMOON_URSALUNA_EX := "Bloodmoon Ursaluna ex"
const WELLSPRING_OGERPON_EX := "Wellspring Mask Ogerpon ex"
const CORNERSTONE_OGERPON_EX := "Cornerstone Mask Ogerpon ex"

var _deck_strategy_text: String = ""
var _rules: RefCounted = LugiaArcheopsRulesScript.new()


func get_strategy_id() -> String:
	return LUGIA_ARCHETYPE_LLM_ID


func get_signature_names() -> Array[String]:
	var names: Array[String] = []
	if _rules != null and _rules.has_method("get_signature_names"):
		for raw_name: Variant in _rules.call("get_signature_names"):
			names.append(str(raw_name))
	for name: String in [
		LUGIA_V,
		LUGIA_VSTAR,
		ARCHEOPS,
		MINCCINO,
		CINCCINO,
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
	]:
		if not names.has(name):
			names.append(name)
	return names


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


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
	return _rules_score_action_absolute(action, game_state, player_index)


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var absolute := score_action_absolute(action, game_state, player_index)
		return absolute - _rules_heuristic_base(str(action.get("kind", "")))
	var turn_plan := _context_turn_plan(context)
	if not turn_plan.is_empty() and _rules != null and _rules.has_method("score_action_absolute_with_plan"):
		return float(_rules.call("score_action_absolute_with_plan", action, game_state, player_index, turn_plan)) - _rules_heuristic_base(str(action.get("kind", "")))
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
	return _rules.call("pick_interaction_items", items, step, context) if _rules != null and _rules.has_method("pick_interaction_items") else []


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var planned_score := float(super.score_interaction_target(item, step, context))
		if planned_score != 0.0:
			return planned_score
	return _rules_score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _rules != null and _rules.has_method("score_handoff_target"):
		return _rules_score_handoff_target(item, step, context)
	return score_interaction_target(item, step, context)


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	var snapshot: Dictionary = super.make_llm_runtime_snapshot(game_state, player_index)
	if snapshot.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return snapshot
	var player: PlayerState = game_state.players[player_index]
	var archeops_field := _count_field_name(player, ARCHEOPS)
	var archeops_discard := _count_discard_name(player, ARCHEOPS)
	snapshot["lugia_field_count"] = _count_field_name(player, LUGIA_V) + _count_field_name(player, LUGIA_VSTAR)
	snapshot["lugia_vstar_field_count"] = _count_field_name(player, LUGIA_VSTAR)
	snapshot["archeops_field_count"] = archeops_field
	snapshot["archeops_discard_count"] = archeops_discard
	snapshot["minccino_field_count"] = _count_field_name(player, MINCCINO)
	snapshot["cinccino_field_count"] = _count_field_name(player, CINCCINO)
	snapshot["lugia_engine_online"] = archeops_field > 0
	snapshot["summoning_star_ready"] = _count_field_name(player, LUGIA_VSTAR) > 0 and archeops_discard > 0
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, LUGIA_V):
		return "highest priority opener and Summoning Star shell owner; establish it early"
	if _name_contains(name, MINCCINO):
		return "priority bench seed for Cinccino follow-up attacker"
	if _name_contains(name, LUGIA_VSTAR):
		return "evolution and Summoning Star engine piece; not an opening Basic"
	if _name_contains(name, ARCHEOPS):
		return "discard and summon engine; usually wants discard before Lugia VSTAR ability"
	if _name_contains(name, CINCCINO):
		return "special-energy scaling attacker after the Archeops engine is online"
	if _name_contains(name, LUMINEON_V):
		return "supporter search piece; bench only when the supporter route matters"
	if _name_contains(name, FEZANDIPITI_EX):
		return "comeback draw support after a knockout; avoid unnecessary early bench"
	if _is_lugia_side_attacker_name(name):
		return "side attacker for specific prize maps after Lugia engine setup"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: Lugia VSTAR / Archeops is a shell-and-convert deck. Build Lugia V into Lugia VSTAR, discard one or two Archeops, use Summoning Star, then let Archeops attach Special Energy to Lugia VSTAR, Cinccino, Iron Hands ex, Bloodmoon Ursaluna ex, or Ogerpon ex attackers.")
	lines.append("Early setup: prioritize Lugia V plus at least one follow-up seed such as Minccino. Ultra Ball, Capturing Aroma, Great Ball, Professor's Research, Carmine, Jacq, and Lumineon V should serve the Lugia VSTAR plus Archeops-discard plan.")
	lines.append("Capturing Aroma policy: the coin flip determines whether only Evolution or only Basic Pokemon are selectable after the action starts. Give ranked search intent for the current board, but expect execution to choose from the actual revealed pool. If only Basics are offered after Lugia plus Archeops are online, prefer meaningful closers such as Bloodmoon Ursaluna ex or Iron Hands ex over low-impact Ogerpon padding.")
	lines.append("Archeops policy: Archeops in hand is often discard fuel before Summoning Star. Do not preserve two Archeops in hand if a legal discard/search route can put them in discard and create Summoning Star pressure.")
	lines.append("Summoning Star policy: use Lugia VSTAR's VSTAR ability when one or two Archeops are in discard, especially two. Avoid spending the VSTAR ability before Archeops is available unless no productive route remains.")
	lines.append("Primal Turbo policy: after Archeops is online, attach Special Energy to the Pokemon closest to attacking this turn or next turn. Lugia VSTAR stabilizes the board, Cinccino scales with Special Energy, Iron Hands ex is for extra-prize lines, and Bloodmoon Ursaluna ex closes late games.")
	lines.append("Energy policy: protect Special Energy. Double Turbo, Gift, Jet, Mist, V Guard, and Legacy Energy are engine resources, not random attachments. Prefer attack-cost completion and prize pressure over padding a support Pokemon.")
	lines.append("Attack policy: attack is terminal. Before attacking, perform safe setup, evolution, search, tool, Archeops acceleration, pivot, gust, and manual attach that improve this turn's prize pressure or next-turn continuity. Low-value setup or redraw attacks are fallback only.")
	lines.append("Prize policy: prefer a current KO or a two-turn prize map. Use Boss's Orders, Counter Catcher, Iron Hands ex, Cinccino scaling, or Bloodmoon Ursaluna ex when they convert prizes; do not gust without damage or survival purpose.")
	lines.append("Resource policy: once Archeops is online and an attacker is ready, stop optional draw/churn unless it unlocks a KO, a safer attacker, or a required next-turn engine piece.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored Lugia strategy text follows; obey it when it does not conflict with legal_actions, card rules, current board facts, or resource constraints:")
		lines.append(custom_text)
	lines.append("Execution boundary: exact action ids, legal actions, card rules, interaction_schema fields, HP, attached tools, energy, hand, discard, prizes, and opponent board come from the structured payload. Never invent ids, card effects, targets, or interaction keys.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "use_ability" and _ref_has_any_name(ref, [LUGIA_VSTAR, ARCHEOPS, "Summoning Star", "Primal Turbo"]):
		return true
	if action_type == "evolve" and _ref_has_any_name(ref, [LUGIA_VSTAR, CINCCINO]):
		return true
	if action_type == "attach_energy" and _ref_is_special_energy(ref):
		return true
	if action_type == "play_trainer" and _ref_has_any_name(ref, [
		"Ultra Ball",
		"Capturing Aroma",
		"Great Ball",
		"Professor",
		"Carmine",
		"Jacq",
		"Boss",
		"Counter Catcher",
	]):
		return true
	return false


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_lugia_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_lugia_setup_card(card_data)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_lugia_setup_catalog(target, seen_ids, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_lugia_setup_catalog(target, seen_ids, has_attack)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_lugia_setup(game_state, player_index)


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_lugia_runtime_setup_action(action, game_state, player_index)


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(runtime_action.get("kind", runtime_action.get("type", "")))
	if kind == "attach_energy" and _is_bad_lugia_energy_attach(runtime_action):
		return true
	if kind == "retreat" and _is_bad_lugia_retreat(runtime_action, game_state, player_index):
		return true
	return false


func _rules_score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _rules == null:
		return 0.0
	var turn_plan := get_turn_contract_context()
	if not turn_plan.is_empty() and _rules.has_method("score_action_absolute_with_plan"):
		return float(_rules.call("score_action_absolute_with_plan", action, game_state, player_index, turn_plan))
	return float(_rules.call("score_action_absolute", action, game_state, player_index)) if _rules.has_method("score_action_absolute") else 0.0


func _rules_score_interaction_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if _rules == null or not _rules.has_method("score_interaction_target"):
		return 0.0
	var turn_plan := _context_turn_plan(context)
	if not turn_plan.is_empty() and _rules.has_method("_set_turn_contract_context"):
		_rules.call("_set_turn_contract_context", turn_plan)
		var score := float(_rules.call("score_interaction_target", item, step, context))
		if _rules.has_method("_clear_turn_contract_context"):
			_rules.call("_clear_turn_contract_context")
		return score
	return float(_rules.call("score_interaction_target", item, step, context))


func _rules_score_handoff_target(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if _rules == null or not _rules.has_method("score_handoff_target"):
		return 0.0
	var turn_plan := _context_turn_plan(context)
	if not turn_plan.is_empty() and _rules.has_method("_set_turn_contract_context"):
		_rules.call("_set_turn_contract_context", turn_plan)
		var score := float(_rules.call("score_handoff_target", item, step, context))
		if _rules.has_method("_clear_turn_contract_context"):
			_rules.call("_clear_turn_contract_context")
		return score
	return float(_rules.call("score_handoff_target", item, step, context))


func _context_turn_plan(context: Dictionary) -> Dictionary:
	if context.get("turn_contract", {}) is Dictionary:
		return context.get("turn_contract", {})
	if context.get("turn_plan", {}) is Dictionary:
		return context.get("turn_plan", {})
	return get_turn_contract_context()


func _rules_heuristic_base(kind: String) -> float:
	if _rules != null and _rules.has_method("_estimate_heuristic_base"):
		return float(_rules.call("_estimate_heuristic_base", kind))
	return 0.0


func _append_lugia_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", LUGIA_V, "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", MINCCINO, "")
	_append_catalog_match(target, seen_ids, "evolve", LUGIA_VSTAR, "")
	_append_catalog_match(target, seen_ids, "evolve", CINCCINO, "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Ultra Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Capturing Aroma", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Great Ball", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Professor", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Carmine", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Jacq", "")
	_append_catalog_match(target, seen_ids, "use_ability", "", LUGIA_VSTAR)
	_append_catalog_match(target, seen_ids, "use_ability", "", ARCHEOPS)
	if not has_attack:
		_append_catalog_match(target, seen_ids, "attach_energy", "", LUGIA_VSTAR)
		_append_catalog_match(target, seen_ids, "attach_energy", "", CINCCINO)
		_append_catalog_match(target, seen_ids, "play_trainer", "Boss", "")
		_append_catalog_match(target, seen_ids, "play_trainer", "Counter Catcher", "")


func _has_visible_lugia_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _count_field_name(player, LUGIA_VSTAR) > 0 and _count_field_name(player, ARCHEOPS) >= 1 and _has_ready_attacker(player):
		return false
	if _catalog_has_lugia_setup_action():
		return true
	for card: CardInstance in player.hand:
		if card != null and _is_lugia_setup_card(card.card_data):
			return true
	return false


func _catalog_has_lugia_setup_action() -> bool:
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
			"Ultra Ball",
			"Capturing Aroma",
			"Great Ball",
			"Professor",
			"Carmine",
			"Jacq",
			"Boss",
			"Counter Catcher",
			"Forest Seal Stone",
		]):
			return true
		if action_type == "use_ability" and _ref_has_any_name(ref, [LUGIA_VSTAR, ARCHEOPS, LUMINEON_V, FEZANDIPITI_EX]):
			return true
	return false


func _is_lugia_setup_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	if str(card_data.card_type) == "Special Energy":
		return true
	for query: String in [
		LUGIA_V,
		LUGIA_VSTAR,
		ARCHEOPS,
		MINCCINO,
		CINCCINO,
		LUMINEON_V,
		FEZANDIPITI_EX,
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
		WELLSPRING_OGERPON_EX,
		CORNERSTONE_OGERPON_EX,
		"Ultra Ball",
		"Capturing Aroma",
		"Great Ball",
		"Professor",
		"Carmine",
		"Jacq",
		"Boss",
		"Counter Catcher",
		"Forest Seal Stone",
		"Double Turbo Energy",
		"Gift Energy",
		"Jet Energy",
		"Mist Energy",
		"V Guard Energy",
		"Legacy Energy",
	]:
		if _name_contains(name, query):
			return true
	return false


func _is_lugia_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["play_basic_to_bench", "evolve", "attach_energy", "attach_tool", "use_ability", "retreat"]:
		return not _deck_should_block_exact_queue_match({}, action, game_state, player_index)
	if kind == "play_trainer":
		return _runtime_action_has_any_name(action, [
			"Ultra Ball",
			"Capturing Aroma",
			"Great Ball",
			"Professor",
			"Carmine",
			"Jacq",
			"Boss",
			"Counter Catcher",
		])
	return false


func _is_bad_lugia_energy_attach(action: Dictionary) -> bool:
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	if not _slot_is_support_only(target_slot):
		return false
	return str(card.card_data.card_type) == "Special Energy" or card.card_data.is_energy()


func _is_bad_lugia_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active := game_state.players[player_index].active_pokemon
	if active == null or not _slot_name_matches_any(active, [LUGIA_VSTAR, CINCCINO, IRON_HANDS_EX, BLOODMOON_URSALUNA_EX]):
		return false
	var bench_target: PokemonSlot = action.get("bench_target", null)
	if bench_target == null:
		return false
	return _slot_is_support_only(bench_target)


func _has_ready_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	if player.active_pokemon != null and bool(predict_attacker_damage(player.active_pokemon).get("can_attack", false)):
		return true
	for slot: PokemonSlot in player.bench:
		if slot != null and bool(predict_attacker_damage(slot).get("can_attack", false)):
			return true
	return false


func _ref_is_special_energy(ref: Dictionary) -> bool:
	if str(ref.get("card_type", "")) == "Special Energy":
		return true
	var rules: Variant = ref.get("card_rules", {})
	if rules is Dictionary and str((rules as Dictionary).get("card_type", "")) == "Special Energy":
		return true
	return _ref_has_any_name(ref, [
		"Double Turbo Energy",
		"Gift Energy",
		"Jet Energy",
		"Mist Energy",
		"V Guard Energy",
		"Legacy Energy",
	])


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("target", "")),
		str(ref.get("summary", "")),
	])
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		combined += " %s %s %s" % [
			str((card_rules as Dictionary).get("name", "")),
			str((card_rules as Dictionary).get("name_en", "")),
			str((card_rules as Dictionary).get("effect_id", "")),
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


func _runtime_action_has_any_name(action: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(action.get("card", "")),
		str(action.get("pokemon", "")),
		str(action.get("summary", "")),
		str(action.get("id", action.get("action_id", ""))),
	])
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		combined += " %s %s" % [str((card as CardInstance).card_data.name), str((card as CardInstance).card_data.name_en)]
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _slot_is_support_only(slot: PokemonSlot) -> bool:
	return _slot_name_matches_any(slot, [LUMINEON_V, FEZANDIPITI_EX, "Radiant Greninja", "Squawkabilly ex"])


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


func _is_lugia_side_attacker_name(name: String) -> bool:
	return _name_matches_any(name, [
		IRON_HANDS_EX,
		BLOODMOON_URSALUNA_EX,
		WELLSPRING_OGERPON_EX,
		CORNERSTONE_OGERPON_EX,
	])


func _best_card_name(cd: CardData) -> String:
	if cd == null:
		return ""
	if str(cd.name_en) != "":
		return str(cd.name_en)
	return str(cd.name)


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


func _count_discard_name(player: PlayerState, query: String) -> int:
	if player == null:
		return 0
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			count += 1
	return count
