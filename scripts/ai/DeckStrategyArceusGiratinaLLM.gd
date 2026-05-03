extends "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"

const ArceusGiratinaRulesScript = preload("res://scripts/ai/DeckStrategyArceusGiratina.gd")

const ARCEUS_GIRATINA_LLM_ID := "arceus_giratina_llm"
const ARCEUS_V := "Arceus V"
const ARCEUS_VSTAR := "Arceus VSTAR"
const GIRATINA_V := "Giratina V"
const GIRATINA_VSTAR := "Giratina VSTAR"
const BIDOOF := "Bidoof"
const BIBAREL := "Bibarel"
const SKWOVET := "Skwovet"
const IRON_LEAVES_EX := "Iron Leaves ex"
const RADIANT_GARDEVOIR := "Radiant Gardevoir"
const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"
const CAPTURING_AROMA := "Capturing Aroma"
const BOSSS_ORDERS := "Boss's Orders"
const IONO := "Iono"
const JUDGE := "Judge"
const SWITCH := "Switch"
const MAXIMUM_BELT := "Maximum Belt"
const CHOICE_BELT := "Choice Belt"
const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GRASS_ENERGY := "Grass Energy"
const PSYCHIC_ENERGY := "Psychic Energy"
const JET_ENERGY := "Jet Energy"
const ABYSS_SEEKING := "Abyss Seeking"

var _deck_strategy_text: String = ""
var _rules: RefCounted = ArceusGiratinaRulesScript.new()


func get_strategy_id() -> String:
	return ARCEUS_GIRATINA_LLM_ID


func get_signature_names() -> Array[String]:
	var names: Array[String] = []
	if _rules != null and _rules.has_method("get_signature_names"):
		for raw_name: Variant in _rules.call("get_signature_names"):
			names.append(str(raw_name))
	for name: String in [
		ARCEUS_V,
		ARCEUS_VSTAR,
		GIRATINA_V,
		GIRATINA_VSTAR,
		BIDOOF,
		BIBAREL,
		SKWOVET,
		IRON_LEAVES_EX,
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
	return _rules.call("build_turn_plan", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_plan") else {}


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	return _rules.call("build_turn_contract", game_state, player_index, context) if _rules != null and _rules.has_method("build_turn_contract") else super.build_turn_contract(game_state, player_index, context)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if game_state != null and has_llm_plan_for_turn(int(game_state.turn_number)):
		var llm_score := super.score_action_absolute(action, game_state, player_index)
		if llm_score >= 10000.0 or llm_score <= -1000.0:
			return llm_score
		if _is_low_value_arceus_giratina_llm_action(action, game_state, player_index):
			return -10000.0
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


func should_preserve_empty_interaction_selection(step: Dictionary, context: Dictionary = {}) -> bool:
	return bool(_rules.call("should_preserve_empty_interaction_selection", step, context)) if _rules != null and _rules.has_method("should_preserve_empty_interaction_selection") else false


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
	snapshot["arceus_field_count"] = _count_field_name(player, ARCEUS_V) + _count_field_name(player, ARCEUS_VSTAR)
	snapshot["arceus_vstar_field_count"] = _count_field_name(player, ARCEUS_VSTAR)
	snapshot["giratina_field_count"] = _count_field_name(player, GIRATINA_V) + _count_field_name(player, GIRATINA_VSTAR)
	snapshot["giratina_vstar_field_count"] = _count_field_name(player, GIRATINA_VSTAR)
	snapshot["draw_engine_field_count"] = _count_field_name(player, BIDOOF) + _count_field_name(player, BIBAREL) + _count_field_name(player, SKWOVET)
	snapshot["active_arceus_trinity_nova_ready"] = player.active_pokemon != null and _slot_name_matches_any(player.active_pokemon, [ARCEUS_VSTAR]) and _slot_can_attack(player.active_pokemon)
	snapshot["giratina_attacker_ready"] = _has_ready_named_attacker(player, [GIRATINA_VSTAR, GIRATINA_V])
	return snapshot


func get_llm_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return "support"
	var name := _best_card_name(cd)
	if _name_contains(name, ARCEUS_V):
		return "highest priority opener; first attacker and Trinity Nova energy accelerator"
	if _name_contains(name, ARCEUS_VSTAR):
		return "VSTAR evolution, Starbirth exact two-card search, and Trinity Nova attacker"
	if _name_contains(name, GIRATINA_V):
		return "backup lane and transition attacker seed; power it with Trinity Nova"
	if _name_contains(name, GIRATINA_VSTAR):
		return "late-game high-damage finisher once Giratina V has energy"
	if _name_contains(name, BIDOOF):
		return "bench seed for Bibarel draw engine after Arceus/Giratina basics"
	if _name_contains(name, BIBAREL):
		return "draw engine evolution; useful after main lanes are established"
	if _name_contains(name, SKWOVET):
		return "draw smoothing support; do not bench after formation is complete"
	if _name_contains(name, IRON_LEAVES_EX):
		return "matchup and closeout side attacker, mainly when Grass-heavy prize math matters"
	if _name_contains(name, RADIANT_GARDEVOIR):
		return "defensive support tech; avoid opening unless forced"
	return "support"


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Deck plan: Arceus V / Arceus VSTAR plus Giratina VSTAR is a shell-and-convert deck. Open on Arceus V, evolve to Arceus VSTAR, use Starbirth for exact missing pieces, and use Trinity Nova to power the next Arceus or Giratina lane.")
	lines.append("Setup priority: establish Arceus V first, then a backup Arceus V or Giratina V, then Bidoof/Skwovet/Bibarel support. Stop benching extra basics once active Arceus, backup Arceus or Giratina, and the draw engine are already sufficient.")
	lines.append("Starbirth policy: Starbirth is the exact two-card shell finisher. Use it for concrete missing pieces such as Arceus VSTAR, Double Turbo Energy, Grass/Psychic Energy, Giratina VSTAR, Switch, Maximum Belt, or Choice Belt when those pieces complete the current route. Do not spend Starbirth on padding when the missing pieces are already in hand.")
	lines.append("Trinity Nova policy: attack is terminal. Before Trinity Nova, perform safe search, evolution, manual attach, belt attachment, pivot, and gust actions that improve this turn's KO or next-turn continuity. Trinity Nova should accelerate typed Energy to the next attacker, usually Giratina first when it lacks Psychic or Grass, otherwise backup Arceus.")
	lines.append("Energy policy: Double Turbo Energy usually belongs on Arceus; Grass and Psychic fix Giratina attack costs and Trinity Nova assignment. Jet Energy and Switch are pivot resources. Avoid attaching typed Energy to support-only Pokemon unless it immediately enables a required retreat.")
	lines.append("Tool policy: Maximum Belt and Choice Belt should land on the attacker that converts prize math, usually ready active Arceus VSTAR or a backup Arceus lane in exact shell-finish windows. Do not attach belts to support Pokemon.")
	lines.append("Redraw policy: Judge and Iono are route tools, not automatic plays. Use them before a nonlethal attack only when the shell is thin or a needed transition piece is missing. Do not redraw away an already complete Starbirth, evolution, attach, or attack route.")
	lines.append("Targeting policy: prefer exact prize math. Use Boss's Orders or switch effects for a bench KO, a game-winning prize, or a Giratina/Arceus conversion target; otherwise keep pressure on the active.")
	lines.append("Replan policy: after Starbirth, Ball search, Capturing Aroma, Judge, Iono, or Bibarel changes hand or board, reassess from the updated legal_actions instead of following stale assumptions.")
	var custom_text := get_deck_strategy_text().strip_edges()
	if custom_text != "":
		lines.append("Player-authored Arceus/Giratina strategy text follows; obey it when it does not conflict with legal_actions, card rules, current board facts, or resource constraints:")
		lines.append(custom_text)
	lines.append("Execution boundary: exact action ids, legal actions, card rules, interaction_schema fields, HP, attached tools, energy, hand, discard, prizes, and opponent board come from the structured payload. Never invent ids, card effects, targets, or interaction keys.")
	return lines


func _deck_action_ref_enables_attack(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "use_ability" and _ref_has_any_name(ref, [ARCEUS_VSTAR, "Starbirth", "Star Birth"]):
		return true
	if action_type == "attack" and _ref_has_any_name(ref, ["Trinity Nova"]):
		return true
	if action_type == "evolve" and _ref_has_any_name(ref, [ARCEUS_VSTAR, GIRATINA_VSTAR, BIBAREL]):
		return true
	if action_type == "attach_energy" and _ref_has_any_name(ref, [ARCEUS_V, ARCEUS_VSTAR, GIRATINA_V, GIRATINA_VSTAR]):
		return true
	if action_type == "attach_tool" and _ref_has_any_name(ref, [MAXIMUM_BELT, CHOICE_BELT, ARCEUS_VSTAR, GIRATINA_VSTAR]):
		return true
	if action_type == "play_trainer" and _ref_has_any_name(ref, [
		ULTRA_BALL,
		NEST_BALL,
		CAPTURING_AROMA,
		SWITCH,
		BOSSS_ORDERS,
	]):
		return true
	return false


func _deck_validate_action_interactions(_action_id: String, ref: Dictionary, interactions: Dictionary, path: String, errors: Array[String]) -> void:
	if _ref_has_any_name(ref, [ARCEUS_VSTAR, "Starbirth", "Star Birth"]):
		for bad_key: String in ["energy_assignments", "assignment_target", "basic_energy_from_hand"]:
			if interactions.has(bad_key):
				errors.append("%s gives Starbirth invalid interaction '%s'; use search_cards/search_target style intent" % [path, bad_key])
	if _ref_has_any_name(ref, ["Trinity Nova"]):
		for bad_key: String in ["search_cards", "search_pokemon", "search_target"]:
			if interactions.has(bad_key):
				errors.append("%s gives Trinity Nova invalid interaction '%s'; use energy_assignments/assignment intent after the attack resolves" % [path, bad_key])


func _deck_hand_card_is_productive_piece(card_data: CardData) -> bool:
	return _is_arceus_giratina_setup_card(card_data)


func _deck_is_setup_or_resource_card(card_data: CardData) -> bool:
	return _is_arceus_giratina_setup_card(card_data)


func _deck_append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_arceus_giratina_setup_catalog(target, seen_ids, false)


func _deck_append_productive_engine_candidates(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	_actions: Array[Dictionary],
	has_attack: bool,
	_no_deck_draw_lock: bool
) -> void:
	_append_arceus_giratina_setup_catalog(target, seen_ids, has_attack)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _has_visible_arceus_giratina_setup(game_state, player_index)


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_arceus_giratina_runtime_setup_action(action, game_state, player_index)


func _deck_should_block_exact_queue_match(_queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(runtime_action.get("kind", runtime_action.get("type", "")))
	if kind == "attach_energy" and _is_bad_arceus_giratina_energy_attach(runtime_action):
		return true
	if kind == "retreat" and _is_bad_arceus_giratina_retreat(runtime_action, game_state, player_index):
		return true
	if _is_low_value_arceus_giratina_llm_action(runtime_action, game_state, player_index):
		return true
	return false


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) not in ["attack", "granted_attack"]:
		return false
	var attack_name := str(action.get("attack_name", ""))
	if _name_contains(attack_name, "Trinity Nova") or _name_contains(attack_name, "Lost Impact"):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active := game_state.players[player_index].active_pokemon
	return active != null and _slot_name_matches_any(active, [ARCEUS_VSTAR, GIRATINA_VSTAR]) and _slot_can_attack(active)


func _deck_is_low_value_runtime_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _is_giratina_v_setup_draw_attack(action, game_state, player_index)


func _is_low_value_arceus_giratina_llm_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind in ["attack", "granted_attack"] and _is_low_value_giratina_v_setup_draw(action, game_state, player_index):
		return true
	if kind == "use_ability" and _runtime_action_has_any_name(action, [BIBAREL, SKWOVET]):
		return _is_unsafe_optional_deck_draw(game_state, player_index)
	if kind == "play_trainer":
		if _runtime_action_has_any_name(action, [BOSSS_ORDERS]):
			return not _llm_queue_or_board_has_attack_pressure(game_state, player_index)
		if _runtime_action_has_any_name(action, [IONO, JUDGE]):
			return _should_block_arceus_giratina_redraw(action, game_state, player_index)
	return false


func _should_block_arceus_giratina_redraw(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _redraw_has_clear_arceus_giratina_value(action, game_state, player_index):
		return false
	var deck_count := _player_deck_count(game_state, player_index)
	if deck_count >= 0 and deck_count <= 16:
		return true
	return _llm_queue_has_concrete_arceus_giratina_progress()


func _redraw_has_clear_arceus_giratina_value(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var deck_count := _player_deck_count(game_state, player_index)
	if deck_count >= 0 and deck_count <= 14:
		return false
	var rules_score := _rules_score_action_absolute(action, game_state, player_index)
	if rules_score >= 500.0:
		return true
	if player.hand.size() <= 2 and deck_count > 16:
		return true
	if _player_is_behind_in_prizes(game_state, player_index) and deck_count > 16:
		return true
	if _has_missing_arceus_giratina_shell_piece(player) and deck_count > 18:
		return true
	return false


func _is_unsafe_optional_deck_draw(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var deck_count := _player_deck_count(game_state, player_index)
	if deck_count >= 0 and deck_count <= 14:
		return true
	if deck_count >= 0 and deck_count <= 18 and player.hand.size() >= 4:
		return true
	return false


func _is_low_value_giratina_v_setup_draw(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_giratina_v_setup_draw_attack(action, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var deck_count := _player_deck_count(game_state, player_index)
	if deck_count >= 0 and deck_count <= 24:
		return true
	if player.hand.size() >= 4 and _llm_queue_has_concrete_arceus_giratina_progress():
		return true
	return false


func _is_giratina_v_setup_draw_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if _slot_best_name_equals(player.active_pokemon, GIRATINA_VSTAR):
		return false
	if not _slot_best_name_equals(player.active_pokemon, GIRATINA_V):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_name := _runtime_attack_name(action, player.active_pokemon, attack_index)
	if attack_index == 0 and attack_name.strip_edges() == "":
		return true
	if _name_contains(attack_name, ABYSS_SEEKING):
		return true
	return attack_index == 0 and not _name_contains(attack_name, "Lost Impact")


func _runtime_attack_name(action: Dictionary, active_slot: PokemonSlot, attack_index: int) -> String:
	var attack_name := str(action.get("attack_name", ""))
	if attack_name.strip_edges() != "":
		return attack_name
	if active_slot == null or active_slot.get_card_data() == null:
		return ""
	var attacks: Array = active_slot.get_card_data().attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return ""
	var attack: Variant = attacks[attack_index]
	if attack is Dictionary:
		return str((attack as Dictionary).get("name", ""))
	return ""


func _slot_best_name_equals(slot: PokemonSlot, query: String) -> bool:
	if slot == null:
		return false
	return _slot_best_name(slot).strip_edges().to_lower() == query.strip_edges().to_lower()


func _has_missing_arceus_giratina_shell_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	var arceus_total := _count_field_name(player, ARCEUS_V) + _count_field_name(player, ARCEUS_VSTAR)
	var arceus_vstar := _count_field_name(player, ARCEUS_VSTAR)
	var giratina_total := _count_field_name(player, GIRATINA_V) + _count_field_name(player, GIRATINA_VSTAR)
	if arceus_total == 0 or giratina_total == 0:
		return true
	if arceus_vstar == 0 and _hand_has_named_card(player, ARCEUS_VSTAR) == false:
		return true
	if not _has_ready_named_attacker(player, [ARCEUS_VSTAR, GIRATINA_VSTAR]) and not _hand_has_named_card(player, DOUBLE_TURBO_ENERGY):
		return true
	return false


func _player_is_behind_in_prizes(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	return game_state.players[player_index].prizes.size() > game_state.players[opponent_index].prizes.size()


func _player_deck_count(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return -1
	var player: PlayerState = game_state.players[player_index]
	return player.deck.size() if player != null else -1


func _hand_has_named_card(player: PlayerState, query: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and _name_contains(_best_card_name(card.card_data), query):
			return true
	return false


func _llm_queue_or_board_has_attack_pressure(game_state: GameState, player_index: int) -> bool:
	for action: Dictionary in _llm_action_queue:
		var kind := str(action.get("kind", action.get("type", "")))
		if kind in ["attack", "granted_attack"]:
			return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if _slot_name_matches_any(player.active_pokemon, [ARCEUS_VSTAR, GIRATINA_VSTAR, IRON_LEAVES_EX]) and _slot_can_attack(player.active_pokemon):
		return true
	return _active_attack_can_pressure_bench_ko(game_state, player_index)


func _active_attack_can_pressure_bench_ko(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[opponent_index]
	if player == null or opponent == null or player.active_pokemon == null:
		return false
	var prediction: Dictionary = predict_attacker_damage(player.active_pokemon)
	if not bool(prediction.get("can_attack", false)):
		return false
	var damage := int(prediction.get("damage", 0))
	if damage <= 0:
		return false
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_remaining_hp() > 0 and damage >= slot.get_remaining_hp():
			return true
	return false


func _llm_queue_has_concrete_arceus_giratina_progress() -> bool:
	for action: Dictionary in _llm_action_queue:
		var kind := str(action.get("kind", action.get("type", "")))
		if kind in ["attack", "granted_attack", "evolve", "attach_energy", "attach_tool", "play_basic_to_bench"]:
			return true
		if kind == "use_ability" and _ref_has_any_name(action, [ARCEUS_VSTAR, "Starbirth", "Star Birth", BIBAREL, SKWOVET]):
			return true
		if kind == "play_trainer" and _ref_has_any_name(action, [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA, SWITCH]):
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


func _append_arceus_giratina_setup_catalog(target: Array[Dictionary], seen_ids: Dictionary, has_attack: bool) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", ARCEUS_V, "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", GIRATINA_V, "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", BIDOOF, "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", SKWOVET, "")
	_append_catalog_match(target, seen_ids, "evolve", ARCEUS_VSTAR, "")
	_append_catalog_match(target, seen_ids, "evolve", GIRATINA_VSTAR, "")
	_append_catalog_match(target, seen_ids, "evolve", BIBAREL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", ULTRA_BALL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", NEST_BALL, "")
	_append_catalog_match(target, seen_ids, "play_trainer", CAPTURING_AROMA, "")
	_append_catalog_match(target, seen_ids, "use_ability", "", ARCEUS_VSTAR)
	if not has_attack:
		_append_catalog_match(target, seen_ids, "attach_energy", "", ARCEUS_VSTAR)
		_append_catalog_match(target, seen_ids, "attach_energy", "", GIRATINA_VSTAR)
		_append_catalog_match(target, seen_ids, "attach_tool", MAXIMUM_BELT, "")
		_append_catalog_match(target, seen_ids, "attach_tool", CHOICE_BELT, "")


func _has_visible_arceus_giratina_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if _target_formation_estimate_complete(player) and _has_ready_named_attacker(player, [ARCEUS_VSTAR, GIRATINA_VSTAR]):
		return false
	if _catalog_has_arceus_giratina_setup_action():
		return true
	for card: CardInstance in player.hand:
		if card != null and _is_arceus_giratina_setup_card(card.card_data):
			return true
	return false


func _catalog_has_arceus_giratina_setup_action() -> bool:
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
			ULTRA_BALL,
			NEST_BALL,
			CAPTURING_AROMA,
			SWITCH,
			BOSSS_ORDERS,
			MAXIMUM_BELT,
			CHOICE_BELT,
		]):
			return true
		if action_type == "use_ability" and _ref_has_any_name(ref, [ARCEUS_VSTAR, BIBAREL, SKWOVET]):
			return true
	return false


func _is_arceus_giratina_setup_card(card_data: CardData) -> bool:
	if card_data == null:
		return false
	var name := _best_card_name(card_data)
	if name.strip_edges() == "":
		return false
	for query: String in [
		ARCEUS_V,
		ARCEUS_VSTAR,
		GIRATINA_V,
		GIRATINA_VSTAR,
		BIDOOF,
		BIBAREL,
		SKWOVET,
		IRON_LEAVES_EX,
		RADIANT_GARDEVOIR,
		ULTRA_BALL,
		NEST_BALL,
		CAPTURING_AROMA,
		BOSSS_ORDERS,
		IONO,
		JUDGE,
		SWITCH,
		MAXIMUM_BELT,
		CHOICE_BELT,
		DOUBLE_TURBO_ENERGY,
		GRASS_ENERGY,
		PSYCHIC_ENERGY,
		JET_ENERGY,
	]:
		if _name_contains(name, query):
			return true
	return false


func _is_arceus_giratina_runtime_setup_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	match kind:
		"play_basic_to_bench":
			if _runtime_action_has_any_name(action, [ARCEUS_V, GIRATINA_V]):
				return not _target_formation_estimate_complete(player)
			if _runtime_action_has_any_name(action, [BIDOOF]):
				return _count_field_name(player, BIDOOF) + _count_field_name(player, BIBAREL) == 0
			if _runtime_action_has_any_name(action, [SKWOVET]):
				return _count_field_name(player, SKWOVET) == 0 and _player_deck_safe_for_optional_draw(player)
			return false
		"evolve":
			return _runtime_action_has_any_name(action, [ARCEUS_VSTAR, GIRATINA_VSTAR, BIBAREL])
		"attach_energy":
			if _deck_should_block_exact_queue_match({}, action, game_state, player_index):
				return false
			return _runtime_action_has_any_name(action, [ARCEUS_V, ARCEUS_VSTAR, GIRATINA_V, GIRATINA_VSTAR])
		"attach_tool":
			return _runtime_action_has_any_name(action, [MAXIMUM_BELT, CHOICE_BELT]) \
				and _runtime_action_has_any_name(action, [ARCEUS_V, ARCEUS_VSTAR, GIRATINA_V, GIRATINA_VSTAR])
		"use_ability":
			if _runtime_action_has_any_name(action, [ARCEUS_VSTAR]):
				return true
			if _runtime_action_has_any_name(action, [BIBAREL, SKWOVET]):
				return _player_deck_safe_for_optional_draw(player)
			return false
		"play_trainer":
			return _runtime_action_has_any_name(action, [ULTRA_BALL, NEST_BALL, CAPTURING_AROMA]) \
				and not _target_formation_estimate_complete(player)
	return false


func _is_bad_arceus_giratina_energy_attach(action: Dictionary) -> bool:
	var target_slot: PokemonSlot = action.get("target_slot", null)
	var card: CardInstance = action.get("card", null)
	if target_slot == null or card == null or card.card_data == null:
		return false
	if not _slot_is_support_only(target_slot):
		return false
	return card.card_data.is_energy()


func _is_bad_arceus_giratina_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active := game_state.players[player_index].active_pokemon
	if active == null or not _slot_name_matches_any(active, [ARCEUS_VSTAR, GIRATINA_VSTAR, IRON_LEAVES_EX]):
		return false
	var bench_target: PokemonSlot = action.get("bench_target", null)
	if bench_target == null:
		return false
	return _slot_is_support_only(bench_target)


func _target_formation_estimate_complete(player: PlayerState) -> bool:
	if player == null:
		return false
	var arceus_count := _count_field_name(player, ARCEUS_V) + _count_field_name(player, ARCEUS_VSTAR)
	var giratina_count := _count_field_name(player, GIRATINA_V) + _count_field_name(player, GIRATINA_VSTAR)
	var draw_count := _count_field_name(player, BIDOOF) + _count_field_name(player, BIBAREL) + _count_field_name(player, SKWOVET)
	return arceus_count >= 2 and giratina_count >= 1 and draw_count >= 1


func _player_deck_safe_for_optional_draw(player: PlayerState) -> bool:
	return player != null and player.deck.size() > 8


func _has_ready_named_attacker(player: PlayerState, names: Array[String]) -> bool:
	if player == null:
		return false
	if player.active_pokemon != null and _slot_name_matches_any(player.active_pokemon, names) and _slot_can_attack(player.active_pokemon):
		return true
	for slot: PokemonSlot in player.bench:
		if slot != null and _slot_name_matches_any(slot, names) and _slot_can_attack(slot):
			return true
	return false


func _slot_can_attack(slot: PokemonSlot) -> bool:
	return bool(predict_attacker_damage(slot).get("can_attack", false)) if slot != null else false


func _ref_has_any_name(ref: Dictionary, queries: Array[String]) -> bool:
	var combined := " ".join([
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("attack_name", "")),
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
	var attack_rules: Variant = ref.get("attack_rules", {})
	if attack_rules is Dictionary:
		combined += " %s %s" % [
			str((attack_rules as Dictionary).get("name", "")),
			str((attack_rules as Dictionary).get("text", "")),
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
		str(action.get("attack_name", "")),
	])
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		combined += " %s %s" % [str((card as CardInstance).card_data.name), str((card as CardInstance).card_data.name_en)]
	var source_slot: Variant = action.get("source_slot")
	if source_slot is PokemonSlot:
		combined += " %s" % _slot_best_name(source_slot as PokemonSlot)
	var target_slot: Variant = action.get("target_slot")
	if target_slot is PokemonSlot:
		combined += " %s" % _slot_best_name(target_slot as PokemonSlot)
	for query: String in queries:
		if _name_contains(combined, query):
			return true
	return false


func _slot_is_support_only(slot: PokemonSlot) -> bool:
	return _slot_name_matches_any(slot, [BIDOOF, BIBAREL, SKWOVET, RADIANT_GARDEVOIR])


func _slot_name_matches_any(slot: PokemonSlot, queries: Array[String]) -> bool:
	return _name_matches_any(_slot_best_name(slot), queries)


func _slot_best_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	return _best_card_name(slot.get_card_data())


func _name_matches_any(name: String, queries: Array[String]) -> bool:
	if name.strip_edges() == "":
		return false
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
