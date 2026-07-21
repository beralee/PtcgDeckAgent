class_name DeckStrategyV18Gholdengo
extends "res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd"


const PURE_PROFILE := {
	"strategy_id": "v18_pure_gholdengo_core",
	"signatures": ["Gholdengo ex", "Gimmighoul", "CSV9C_096", "赛富豪ex", "索财灵"],
	"active_priority": ["Gimmighoul", "CSV9C_096", "索财灵", "Iron Bundle", "铁包袱", "Munkidori", "愿增猿"],
	"bench_priority": ["Gimmighoul", "CSV9C_096", "索财灵", "Fezandipiti ex", "吉雉鸡ex", "Munkidori", "愿增猿"],
	"search_priority": ["Gholdengo ex", "赛富豪ex", "Gimmighoul", "CSV9C_096", "索财灵", "Energy Search Pro", "能量输送PRO", "Superior Energy Retrieval", "超级能量回收"],
	"evolution_priority": ["Gholdengo ex", "赛富豪ex", "Gholdengo", "赛富豪"],
	"energy_priority": ["Gholdengo ex", "赛富豪ex", "Gimmighoul", "CSV9C_096", "索财灵"],
	"ability_priority": ["Gholdengo ex", "赛富豪ex", "Gholdengo", "赛富豪", "Fezandipiti ex", "吉雉鸡ex"],
}


func _profile() -> Dictionary:
	return PURE_PROFILE


func get_strategy_id() -> String:
	return "v18_pure_gholdengo_core"


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var owner_name := "Gholdengo ex"
	var bridge_name := "Gholdengo ex"
	var pivot_name := "Gholdengo ex"
	var thin_churn := false
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		var best_attacker := _best_palkia_gholdengo_attacker(player, game_state, player_index)
		if best_attacker != null:
			owner_name = _slot_name(best_attacker)
			bridge_name = owner_name
			pivot_name = owner_name
		elif _count_name_on_field(player, "Gimmighoul") > 0:
			owner_name = "Gimmighoul"
			bridge_name = "Gholdengo ex"
			pivot_name = "Gimmighoul"
		thin_churn = _deck_is_thin(player) and _has_live_attack_route(player, game_state, player_index)
	return {
		"id": "v18_pure_gholdengo_rules",
		"intent": "build_make_it_rain" if not thin_churn else "convert_without_churn",
		"phase": "convert" if thin_churn else "setup",
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": pivot_name,
		},
		"priorities": {
			"attach": ["Gholdengo ex", "Gimmighoul"],
			"handoff": ["Gholdengo ex", "Gimmighoul"],
			"search": ["Gholdengo ex", "Gimmighoul", "Energy Search Pro", "Superior Energy Retrieval"],
		},
		"flags": {
			"thin_deck_churn_guard": thin_churn,
			"live_attack_route": thin_churn,
		},
		"constraints": {
			"forbid_engine_churn": thin_churn,
		},
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.deck.size() <= 8 or not _cipher_route_debt(player):
		return score
	var kind := str(action.get("kind", ""))
	if kind == "play_trainer" and _card_name(action.get("card", null)) == "Ciphermaniac's Codebreaking":
		return maxf(score, 4500.0)
	if kind == "use_ability" \
			and _slot_name(action.get("source_slot", null)) == "Gholdengo ex" \
			and _hand_has_card_name(player, "Ciphermaniac's Codebreaking"):
		return minf(score, -800.0)
	return score


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if str(step.get("id", "")).to_lower() == "top_cards":
		return _pick_cipher_top_cards(items, int(step.get("max_select", 2)), context)
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if item is CardInstance and step_id == "top_cards":
		var card := item as CardInstance
		var player: PlayerState = _player_from_context(context)
		var name := _card_name(card)
		if _is_basic_energy(card):
			if _energy_type(card) == "M" and _pure_metal_route_missing(player):
				return 3400.0
			return 1200.0 + _energy_type_diversity_bonus(card)
		if name == "Gholdengo ex" and _needs_evolution_piece(player):
			return 3200.0
		if name == "Energy Search Pro":
			return 2800.0
		if name == "Superior Energy Retrieval" and _discard_basic_energy_count(player) >= 2:
			return 2500.0
		if name == "Gimmighoul":
			return 120.0 if _pure_lane_count(player) >= 2 else 1800.0
	return super.score_interaction_target(item, step, context)


func _needs_opening_basics(player: PlayerState) -> bool:
	return player != null and _pure_lane_count(player) < 2


func _fragile_gimmighoul_opening(player: PlayerState) -> bool:
	return player != null \
		and _count_name_on_field(player, "Gimmighoul") > 0 \
		and _count_name_on_field(player, "Gholdengo ex") == 0


func _needs_evolution_piece(player: PlayerState) -> bool:
	return player != null \
		and _count_name_on_field(player, "Gimmighoul") > 0 \
		and _count_name_on_field(player, "Gholdengo ex") < 2


func _engine_setup_gap(player: PlayerState) -> int:
	if player == null:
		return 0
	var gap := 0
	if _count_name_on_field(player, "Gimmighoul") == 0:
		gap += 1
	if _count_name_on_field(player, "Gholdengo ex") == 0:
		gap += 1
	if _pure_lane_count(player) < 2:
		gap += 1
	return gap


func _build_palkia_gholdengo_continuity_setup_debt(
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> Dictionary:
	if player == null:
		return {}
	var lane_count := _pure_lane_count(player)
	return {
		"gholdengo_lane_count": lane_count,
		"palkia_lane_count": 0,
		"hand_basic_energy_count": _basic_energy_in_hand(player),
		"discard_basic_energy_count": _discard_basic_energy_count(player),
		"need_backup_gholdengo_seed": player.bench.size() < 5 and lane_count < 2,
		"need_palkia_bridge": false,
		"need_second_attack_fuel": _needs_second_attack_fuel(player, game_state, player_index),
		"need_follow_up_metal": _needs_follow_up_metal(player),
		"need_follow_up_water": false,
	}


func _is_primary_attack_route_name(name: String) -> bool:
	return name == "Gholdengo ex"


func _cipher_route_debt(player: PlayerState) -> bool:
	return player != null \
		and (_pure_metal_route_missing(player) or _needs_evolution_piece(player))


func _pick_cipher_top_cards(items: Array, max_select: int, context: Dictionary) -> Array:
	if max_select <= 0:
		max_select = 1
	var player: PlayerState = _player_from_context(context)
	var preferred_roles: Array[String] = []
	if _needs_evolution_piece(player) and not _hand_has_card_name(player, "Gholdengo ex"):
		preferred_roles.append("evolution")
	if _pure_metal_route_missing(player):
		preferred_roles.append("metal_energy")
	preferred_roles.append_array(["energy_search", "energy_retrieval", "seed"])

	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		ranked.append({
			"item": item,
			"score": score_interaction_target(item, {"id": "top_cards"}, context),
			"role": _cipher_top_card_role(item),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var selected: Array = []
	var used_roles := {}
	for role: String in preferred_roles:
		if selected.size() >= max_select:
			break
		for entry: Dictionary in ranked:
			if str(entry.get("role", "")) != role or entry.get("item") in selected:
				continue
			selected.append(entry.get("item"))
			used_roles[role] = true
			break
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		var item: Variant = entry.get("item")
		var role := str(entry.get("role", ""))
		if item in selected or (role != "" and used_roles.has(role)):
			continue
		selected.append(item)
		if role != "":
			used_roles[role] = true
	for entry: Dictionary in ranked:
		if selected.size() >= max_select:
			break
		if entry.get("item") not in selected:
			selected.append(entry.get("item"))
	return selected


func _cipher_top_card_role(item: Variant) -> String:
	if not item is CardInstance:
		return ""
	var card := item as CardInstance
	if _is_basic_energy(card) and _energy_type(card) == "M":
		return "metal_energy"
	match _card_name(card):
		"Gholdengo ex":
			return "evolution"
		"Energy Search Pro":
			return "energy_search"
		"Superior Energy Retrieval":
			return "energy_retrieval"
		"Gimmighoul":
			return "seed"
	return _card_uid(card.card_data)


func _pure_metal_route_missing(player: PlayerState) -> bool:
	if player == null or _count_energy_in_hand(player, "M") > 0:
		return false
	return _pure_lane_count(player) > 0 \
		or _hand_has_card_name(player, "Gholdengo ex") \
		or _hand_has_card_name(player, "Gimmighoul")


func _pure_lane_count(player: PlayerState) -> int:
	if player == null:
		return 0
	return _count_name_on_field(player, "Gholdengo ex") + _count_name_on_field(player, "Gimmighoul")
