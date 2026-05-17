extends "res://scripts/ai/DeckStrategy17LLMBase.gd"

const REGIDRAGO_LLM_APEX_FUEL_NAMES: Array[String] = [
	"Dragapult ex",
	"Giratina VSTAR",
	"Hisuian Goodra VSTAR",
	"Haxorus",
	"Alolan Exeggutor ex",
	"Kyurem",
]


func _llm_strategy_id() -> String:
	return "v17_regidrago_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17Regidrago.gd"


func ensure_llm_request_fired(game_state: GameState, player_index: int, legal_actions: Array = []) -> void:
	if game_state == null or game_state.phase != GameState.GamePhase.MAIN:
		return
	super.ensure_llm_request_fired(game_state, player_index, legal_actions)


func _deck_display_name() -> String:
	return "17.0 龙柱"


func _deck_primary_attackers() -> Array[String]:
	return ["Regidrago VSTAR", "雷吉铎拉戈VSTAR", "Regidrago V", "雷吉铎拉戈V"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Radiant Charizard", "光辉喷火龙", "Alolan Exeggutor ex", "阿罗拉 椰蛋树ex", "Kyurem", "酋雷姆"]


func _deck_support_pokemon() -> Array[String]:
	return [
		"Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex",
		"Squawkabilly ex", "怒鹦哥ex",
		"Fezandipiti ex", "吉雉鸡ex",
		"Mew ex", "梦幻ex",
		"Cleffa", "皮宝宝",
		"Hawlucha", "摔角鹰人",
		"Dragapult ex", "多龙巴鲁托ex",
		"Giratina VSTAR", "骑拉帝纳VSTAR",
		"Hisuian Goodra VSTAR", "洗翠 黏美龙VSTAR",
	]


func _deck_energy_banks() -> Array[String]:
	return ["Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Regidrago VSTAR", "attack": "Apex Dragon"},
		{"pokemon": "雷吉铎拉戈VSTAR", "attack": "巨龙无双"},
		{"pokemon": "Dragapult ex", "attack": "Phantom Dive"},
		{"pokemon": "多龙巴鲁托ex", "attack": "幻影潜袭"},
		{"pokemon": "Giratina VSTAR", "attack": "Lost Impact"},
		{"pokemon": "骑拉帝纳VSTAR", "attack": "迷失冲击"},
		{"pokemon": "Alolan Exeggutor ex", "attack": "Tropical Frenzy"},
		{"pokemon": "阿罗拉 椰蛋树ex", "attack": "热带狂热"},
		{"pokemon": "Kyurem", "attack": "Trifrost"},
		{"pokemon": "酋雷姆", "attack": "三重冰霜"},
	]


func _deck_low_value_attacks() -> Array:
	return []


func _deck_setup_draw_attacks() -> Array:
	return [
		{"pokemon": "Regidrago V", "attack": "Celestial Roar"},
		{"pokemon": "雷吉铎拉戈V", "attack": "天之呐喊"},
	]


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _regidrago_llm_should_allow_celestial_roar_setup(action, game_state, player_index) \
			and not _catalog_has_productive_non_terminal_action()


func _deck_should_block_exact_queue_match(
	_queued_action: Dictionary,
	runtime_action: Dictionary,
	game_state: GameState,
	player_index: int
) -> bool:
	if _regidrago_llm_is_celestial_roar_action(runtime_action, game_state, player_index):
		return not _regidrago_llm_should_allow_celestial_roar_setup(runtime_action, game_state, player_index)
	if _regidrago_llm_should_block_basic_dragon_laser_for_apex(runtime_action, game_state, player_index):
		return true
	return false


func _is_low_value_runtime_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _regidrago_llm_is_celestial_roar_action(action, game_state, player_index):
		return not _regidrago_llm_should_allow_celestial_roar_setup(action, game_state, player_index)
	if _regidrago_llm_should_block_basic_dragon_laser_for_apex(action, game_state, player_index):
		return true
	return super._is_low_value_runtime_attack_action(action, game_state, player_index)


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Regidrago V", "stages": ["Regidrago VSTAR"], "role": "primary_attacker", "desired_count": 2, "energy": {"G": 2, "R": 1}},
		{"basic": "雷吉铎拉戈V", "stages": ["雷吉铎拉戈VSTAR"], "role": "primary_attacker", "desired_count": 2, "energy": {"G": 2, "R": 1}},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Regidrago V": {"G": 2, "R": 1},
		"Regidrago VSTAR": {"G": 2, "R": 1},
		"Teal Mask Ogerpon ex": {"G": 1},
		"雷吉铎拉戈V": {"G": 2, "R": 1},
		"雷吉铎拉戈VSTAR": {"G": 2, "R": 1},
		"厄诡椪 碧草面具ex": {"G": 1},
	}


func _deck_route_terms() -> Array[String]:
	return [
		"巨龙无双", "碧草之舞", "能量转移", "高级球", "博士的研究",
		"热带狂热", "三重冰霜", "幻影潜袭", "迷失冲击", "天之呐喊",
		"基本草能量", "基本火能量",
	]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】T1 铺两只 Regidrago V、两只 Teal Mask Ogerpon ex 和 Squawkabilly ex，利用 Ogerpon 贴草抽牌，再用 Energy Switch 把草能转给 Regidrago，让主攻手接近 GGR 费用。",
		"【T2 转化】优先进化 Regidrago VSTAR，并用 Ultra Ball / Research 等把 Dragapult ex、Giratina VSTAR、Hisuian Goodra VSTAR、Alolan Exeggutor ex 或 Kyurem 等龙系燃料送进弃牌区。",
		"【攻击选择】Apex Dragon 复制弃牌区龙系招式。对展开型后场优先复制 Dragapult ex 的 Phantom Dive；需要高单点时用 Giratina VSTAR；需要特殊局面时选择 Goodra/Exeggutor/Kyurem。",
		"【资源原则】龙系燃料在手里通常是弃牌资源，不要用 Nest Ball 把它们放到后场；Super Rod/Night Stretcher 不要把唯一 Dragapult ex 等关键燃料洗回去，除非是救命续航。",
		"【撤退原则】已经带攻击能量的 Regidrago 路线所有者不能随便付能撤退到支援位；只有能交接给已就绪攻击手时才换位。",
	])


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result: Dictionary = super._deck_augment_action_id_payload(payload, game_state, player_index)
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes := routes.duplicate(true)
	var evolve_apex_route := _regidrago_evolve_apex_candidate_route(result, game_state, player_index)
	if not evolve_apex_route.is_empty():
		if not _regidrago_payload_has_route(updated_routes, "route:regidrago_evolve_apex_attack"):
			updated_routes.push_front(evolve_apex_route)
		var evolve_actions: Array = evolve_apex_route.get("actions", []) if evolve_apex_route.get("actions", []) is Array else []
		var evolve_ref: Dictionary = evolve_actions[0] if not evolve_actions.is_empty() and evolve_actions[0] is Dictionary else {}
		var attach_ref: Dictionary = evolve_actions[1] if evolve_actions.size() > 1 and evolve_actions[1] is Dictionary else {}
		if str(attach_ref.get("id", "")) == "end_turn":
			attach_ref = {}
		facts["regidrago_evolve_apex"] = {
			"route_available": true,
			"route_action_id": "route:regidrago_evolve_apex_attack",
			"evolve_action_id": str(evolve_ref.get("id", "")),
			"attach_action_id": str(attach_ref.get("id", "")),
			"attack_name": "Apex Dragon",
			"reason": "Regidrago V can evolve and reach Apex Dragon this turn; evolve before taking a lower-value Basic attack.",
		}
	var energy_switch_apex_route: Dictionary = self.call("_regidrago_energy_switch_apex_candidate_route", result, game_state, player_index)
	if not energy_switch_apex_route.is_empty():
		if not _regidrago_payload_has_route(updated_routes, "route:regidrago_energy_switch_apex_attack"):
			updated_routes.push_front(energy_switch_apex_route)
		var switch_actions: Array = energy_switch_apex_route.get("actions", []) if energy_switch_apex_route.get("actions", []) is Array else []
		var switch_evolve_ref: Dictionary = switch_actions[0] if not switch_actions.is_empty() and switch_actions[0] is Dictionary else {}
		var switch_ref: Dictionary = switch_actions[1] if switch_actions.size() > 1 and switch_actions[1] is Dictionary else {}
		facts["regidrago_energy_switch_apex"] = {
			"route_available": true,
			"route_action_id": "route:regidrago_energy_switch_apex_attack",
			"evolve_action_id": str(switch_evolve_ref.get("id", "")),
			"energy_switch_action_id": str(switch_ref.get("id", "")),
			"attack_name": "Apex Dragon",
			"reason": "Ogerpon grass energy can be moved to active Regidrago after evolution; avoid invalid Energy Switch interaction contracts.",
		}
	var backup_seed_route := _regidrago_backup_seed_candidate_route(result, game_state, player_index)
	if not backup_seed_route.is_empty():
		if not _regidrago_payload_has_route(updated_routes, "route:regidrago_backup_seed_before_attack"):
			updated_routes.push_front(backup_seed_route)
		var backup_actions: Array = backup_seed_route.get("actions", []) if backup_seed_route.get("actions", []) is Array else []
		var seed_ref: Dictionary = backup_actions[0] if not backup_actions.is_empty() and backup_actions[0] is Dictionary else {}
		facts["regidrago_backup_seed"] = {
			"route_available": true,
			"route_action_id": "route:regidrago_backup_seed_before_attack",
			"seed_action_id": str(seed_ref.get("id", "")),
			"live_regidrago_count": _regidrago_live_regidrago_count(game_state.players[player_index]) if game_state != null and player_index >= 0 and player_index < game_state.players.size() else -1,
			"reason": "Miraidon can take a two-prize Regidrago before the next turn; seed a second Regidrago V before attacking when bench space and a legal search/bench action exist.",
		}
	var handoff_route := _regidrago_ready_handoff_candidate_route(result, facts)
	if not handoff_route.is_empty():
		if not _regidrago_payload_has_route(updated_routes, "route:regidrago_ready_handoff_attack"):
			updated_routes.push_front(handoff_route)
		var route_actions: Array = handoff_route.get("actions", []) if handoff_route.get("actions", []) is Array else []
		var first_action: Dictionary = route_actions[0] if not route_actions.is_empty() and route_actions[0] is Dictionary else {}
		facts["regidrago_ready_handoff"] = {
			"route_available": true,
			"route_action_id": "route:regidrago_ready_handoff_attack",
			"pivot_action_id": str(first_action.get("id", "")),
			"bench_position": str(handoff_route.get("bench_position", "")),
			"attack_name": str(handoff_route.get("attack_name", "")),
			"reason": "A benched Regidrago/Ogerpon attacker is already ready; pivot before preserving the turn.",
		}
	result["candidate_routes"] = updated_routes
	result["turn_tactical_facts"] = facts
	return result


func _regidrago_energy_switch_apex_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return {}
	var active: PokemonSlot = player.active_pokemon
	if not _regidrago_llm_is_regidrago_v_slot(active):
		return {}
	if not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return {}
	if not _regidrago_has_movable_grass_energy(player, active):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var evolve_ref := _best_regidrago_apex_evolve_ref(legal_actions)
	if evolve_ref.is_empty():
		return {}
	var switch_ref := _best_regidrago_energy_switch_ref(legal_actions)
	if switch_ref.is_empty():
		return {}
	var counts := _regidrago_attached_energy_counts(active)
	counts["G"] = int(counts.get("G", 0)) + 1
	if not _regidrago_energy_counts_can_pay_cost(counts, "GGR"):
		return {}
	var actions: Array[Dictionary] = [
		_regidrago_route_ref(evolve_ref, "evolve_to_apex"),
		_regidrago_route_ref(switch_ref, "energy_switch_to_apex"),
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
	]
	return {
		"id": "regidrago_energy_switch_apex_attack",
		"route_action_id": "route:regidrago_energy_switch_apex_attack",
		"type": "candidate_route",
		"priority": 998,
		"base_priority": 998,
		"goal": "energy_switch_apex_attack",
		"description": "Evolve active Regidrago V, move a spare Grass energy from an Ogerpon-style bank, then attack with Apex Dragon.",
		"actions": actions,
		"future_goals": [
			{
				"id": "future:regidrago_apex_after_energy_switch",
				"type": "attack",
				"future": true,
				"position": "active",
				"source_pokemon": "Regidrago VSTAR",
				"attack_name": "Apex Dragon",
				"attack_quality": {"role": "primary_damage", "terminal_priority": "high", "takes_prize": true},
			},
		],
		"contract": "Select this route when active Regidrago V is one Grass short, Energy Switch is legal, and a benched energy bank can donate Grass.",
		"strategy_adjustable": true,
	}


func _regidrago_evolve_apex_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return {}
	var active: PokemonSlot = player.active_pokemon
	if not _regidrago_llm_is_regidrago_v_slot(active):
		return {}
	if not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var evolve_ref := _best_regidrago_apex_evolve_ref(legal_actions)
	if evolve_ref.is_empty():
		return {}
	var attach_ref: Dictionary = {}
	var active_can_pay_after_evolve := _regidrago_slot_can_pay_cost_with_optional_attach(active, "GGR", "")
	if not active_can_pay_after_evolve:
		attach_ref = _best_regidrago_apex_attach_ref(legal_actions, active)
		if attach_ref.is_empty():
			return {}
	var actions: Array[Dictionary] = [
		_regidrago_route_ref(evolve_ref, "evolve_to_apex"),
	]
	if not attach_ref.is_empty():
		actions.append(_regidrago_route_ref(attach_ref, "manual_attach_to_apex"))
	actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "regidrago_evolve_apex_attack",
		"route_action_id": "route:regidrago_evolve_apex_attack",
		"type": "candidate_route",
		"priority": 995,
		"base_priority": 995,
		"goal": "evolve_apex_attack",
		"description": "Evolve active Regidrago V into Regidrago VSTAR, complete GGR if needed, then attack with Apex Dragon instead of a Basic attack.",
		"actions": actions,
		"future_goals": [
			{
				"id": "future:regidrago_apex_after_evolve",
				"type": "attack",
				"future": true,
				"position": "active",
				"source_pokemon": "Regidrago VSTAR",
				"attack_name": "Apex Dragon",
				"attack_quality": {"role": "primary_damage", "terminal_priority": "high", "takes_prize": true},
			},
		],
		"contract": "Select this route before manual_attach_to_attack when active Regidrago V can evolve into VSTAR and Apex Dragon can be paid this turn.",
		"strategy_adjustable": true,
	}


func _best_regidrago_apex_evolve_ref(legal_actions: Array) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type != "evolve":
			continue
		var text := _regidrago_ref_text(ref)
		if not (_v17_name_contains(text, "Regidrago VSTAR") or _v17_name_contains(text, "雷吉铎拉戈VSTAR")):
			continue
		var score := 1000
		if str(ref.get("position", "")).strip_edges() == "active" or _v17_name_contains(text, "active"):
			score += 120
		if _v17_name_contains(text, "Regidrago V"):
			score += 40
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _best_regidrago_energy_switch_ref(legal_actions: Array) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type != "play_trainer":
			continue
		var text := _regidrago_ref_text(ref)
		if not _v17_name_contains(text, "Energy Switch"):
			continue
		var score := 1000
		if str(ref.get("card", "")) == "Energy Switch":
			score += 80
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_has_movable_grass_energy(player: PlayerState, active: PokemonSlot) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _regidrago_llm_all_slots(player):
		if slot == null or slot == active:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			if _energy_symbol_for_runtime(str(energy.card_data.energy_provides)) == "G":
				return true
	return false


func _best_regidrago_apex_attach_ref(legal_actions: Array, active: PokemonSlot) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_type := str(ref.get("type", ref.get("kind", "")))
		if action_type != "attach_energy":
			continue
		var text := _regidrago_ref_text(ref)
		if not (str(ref.get("position", "")).strip_edges() == "active" or _v17_name_contains(text, "active")):
			continue
		var symbol := _regidrago_attach_ref_energy_symbol(ref)
		if symbol == "":
			continue
		if not _regidrago_slot_can_pay_cost_with_optional_attach(active, "GGR", symbol):
			continue
		var score := 1000
		if symbol == "G":
			score += 90
		elif symbol == "R":
			score += 70
		if _matches_any(text, _deck_primary_attackers()):
			score += 30
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_attach_ref_energy_symbol(ref: Dictionary) -> String:
	for key: String in ["energy_symbol", "energy", "energy_type", "card", "summary"]:
		var symbol := _energy_symbol_for_runtime(str(ref.get(key, "")))
		if symbol != "":
			return symbol
	var text := _regidrago_ref_text(ref)
	for token: String in ["Grass", "Fire", "Water", "Psychic", "Metal", "Lightning", "Fighting", "Dark"]:
		var symbol := _energy_symbol_for_runtime(token)
		if symbol != "" and _v17_name_contains(text, token):
			return symbol
	return ""


func _regidrago_slot_can_pay_cost_with_optional_attach(slot: PokemonSlot, cost: String, attach_symbol: String) -> bool:
	var counts := _regidrago_attached_energy_counts(slot)
	var normalized_attach := _energy_symbol_for_runtime(attach_symbol)
	if normalized_attach != "":
		counts[normalized_attach] = int(counts.get(normalized_attach, 0)) + 1
	return _regidrago_energy_counts_can_pay_cost(counts, cost)


func _regidrago_attached_energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	if slot == null:
		return counts
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		if symbol == "":
			continue
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	return counts


func _regidrago_energy_counts_can_pay_cost(counts: Dictionary, cost: String) -> bool:
	var remaining := counts.duplicate()
	var total_attached := 0
	for raw_count: Variant in remaining.values():
		total_attached += int(raw_count)
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
			return false
		remaining[symbol] = count - 1
		total_attached -= 1
	return colorless_needed <= total_attached


func _regidrago_backup_seed_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if not _regidrago_needs_backup_seed(player):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var seed_ref := _best_regidrago_backup_seed_ref(legal_actions)
	if seed_ref.is_empty():
		return {}
	var seed_action := _regidrago_route_ref(seed_ref, "backup_regidrago_seed")
	var policy := _regidrago_backup_seed_selection_policy()
	if not policy.is_empty():
		seed_action["selection_policy"] = policy
	var actions: Array[Dictionary] = [seed_action]
	var attack_ref := _best_regidrago_immediate_attack_ref(legal_actions)
	if not attack_ref.is_empty():
		actions.append(_regidrago_route_ref(attack_ref, "attack_after_backup_seed"))
	return {
		"id": "regidrago_backup_seed_before_attack",
		"route_action_id": "route:regidrago_backup_seed_before_attack",
		"type": "candidate_route",
		"priority": 940,
		"base_priority": 940,
		"goal": "seed_backup_regidrago_before_prize_race_attack",
		"description": "Bench or search a second Regidrago V before committing the current attack so the deck does not collapse after Miraidon removes the first two-prize attacker.",
		"actions": actions,
		"future_goals": [
			{
				"id": "future:backup_regidrago_v_line",
				"type": "board_development",
				"future": true,
				"source_pokemon": "Regidrago V",
				"role": "backup_primary_attacker",
			},
		],
		"contract": "Select this route before attacking when there is only one live Regidrago line, bench space is open, and Regidrago V can be benched or searched now.",
		"strategy_adjustable": true,
	}


func _regidrago_needs_backup_seed(player: PlayerState) -> bool:
	if player == null:
		return false
	if _regidrago_open_bench_slots(player) <= 0:
		return false
	if player.prizes.size() <= 1:
		return false
	return _regidrago_live_regidrago_count(player) < 2


func _regidrago_open_bench_slots(player: PlayerState) -> int:
	if player == null:
		return 0
	return maxi(0, 5 - player.bench.size())


func _regidrago_live_regidrago_count(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in _regidrago_llm_all_slots(player):
		if _regidrago_llm_is_regidrago_v_slot(slot) or _regidrago_llm_is_regidrago_vstar_slot(slot):
			count += 1
	return count


func _best_regidrago_backup_seed_ref(legal_actions: Array) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var score := _regidrago_backup_seed_ref_score(ref)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_backup_seed_ref_score(ref: Dictionary) -> int:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	var text := _regidrago_ref_text(ref)
	if action_type == "play_basic_to_bench" and _v17_name_contains(text, "Regidrago V") and not _v17_name_contains(text, "VSTAR"):
		return 1200
	if action_type != "play_trainer":
		return -999999
	if _v17_name_contains(text, "Nest Ball"):
		return 1050
	if _v17_name_contains(text, "Ultra Ball"):
		return 860
	return -999999


func _best_regidrago_immediate_attack_ref(legal_actions: Array) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var score := _regidrago_immediate_attack_ref_score(ref)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_immediate_attack_ref_score(ref: Dictionary) -> int:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type != "attack" and action_type != "granted_attack":
		return -999999
	var text := _regidrago_ref_text(ref)
	if _v17_name_contains(text, "Apex Dragon"):
		return 1200
	if _v17_name_contains(text, "Dragon Laser"):
		return 700
	if _v17_name_contains(text, "Celestial Roar"):
		return -999999
	return 500


func _regidrago_backup_seed_selection_policy() -> Dictionary:
	var prefer: Array[String] = ["Regidrago V"]
	return {
		"search_pokemon": {"prefer": prefer},
		"basic_pokemon": {"prefer": prefer},
		"bench_pokemon": {"prefer": prefer},
		"search_cards": {"prefer": prefer},
	}


func _regidrago_ready_handoff_candidate_route(payload: Dictionary, facts: Dictionary) -> Dictionary:
	if bool(facts.get("primary_attack_ready", false)):
		return {}
	var future_attack := _best_regidrago_ready_handoff_future(payload)
	if future_attack.is_empty():
		return {}
	var bench_position := str(future_attack.get("position", "")).strip_edges()
	if bench_position == "":
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var pivot_ref := _best_regidrago_handoff_pivot_ref(legal_actions, bench_position)
	if pivot_ref.is_empty():
		return {}
	var pivot_action := _regidrago_route_ref(pivot_ref)
	pivot_action["selection_policy"] = _regidrago_handoff_selection_policy(bench_position)
	var attack_name := str(future_attack.get("attack_name", ""))
	var future_goal := future_attack.duplicate(true)
	future_goal["type"] = "attack"
	future_goal["future"] = true
	if not future_goal.has("attack_quality"):
		future_goal["attack_quality"] = {"role": "primary_damage", "terminal_priority": "high"}
	return {
		"id": "regidrago_ready_handoff_attack",
		"route_action_id": "route:regidrago_ready_handoff_attack",
		"type": "candidate_route",
		"priority": 906,
		"goal": "ready_bench_handoff_attack",
		"description": "Pivot to a benched Regidrago or Ogerpon attacker that can attack now, then let runtime convert end_turn into the attack.",
		"bench_position": bench_position,
		"attack_name": attack_name,
		"actions": [
			pivot_action,
			{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
		],
		"future_goals": [future_goal],
		"contract": "Select this route when the active only has a low-value/no attack and the listed bench attacker is already reachable through this pivot.",
	}


func _best_regidrago_ready_handoff_future(payload: Dictionary) -> Dictionary:
	var future_actions: Array = payload.get("future_actions", []) if payload.get("future_actions", []) is Array else []
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in future_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if not _regidrago_future_attack_is_handoff_candidate(ref):
			continue
		var score := _regidrago_future_attack_score(ref)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_future_attack_is_handoff_candidate(ref: Dictionary) -> bool:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	if not action_id.begins_with("future:attack_after_pivot:"):
		return false
	if not bool(ref.get("reachable_with_known_resources", false)):
		return false
	var position := str(ref.get("position", ""))
	if not position.begins_with("bench_"):
		return false
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	var role := str(quality.get("role", ""))
	var terminal_priority := str(quality.get("terminal_priority", ""))
	if terminal_priority == "low" or role in ["setup_draw", "desperation_redraw"]:
		return false
	var source := str(ref.get("source_pokemon", ""))
	if source != "" and (_matches_any(source, _deck_primary_attackers()) or _matches_any(source, _deck_secondary_attackers()) or _matches_any(source, _deck_energy_banks())):
		return true
	return terminal_priority in ["medium", "high"]


func _regidrago_future_attack_score(ref: Dictionary) -> int:
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	var score := 0
	match str(quality.get("terminal_priority", "")):
		"high":
			score += 1000
		"medium":
			score += 700
		_:
			score += 300
	var source := str(ref.get("source_pokemon", ""))
	if _matches_any(source, _deck_primary_attackers()):
		score += 160
	elif _matches_any(source, _deck_energy_banks()):
		score += 120
	elif _matches_any(source, _deck_secondary_attackers()):
		score += 80
	if bool(quality.get("takes_prize", false)):
		score += 60
	return score


func _best_regidrago_handoff_pivot_ref(legal_actions: Array, bench_position: String) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var score := _regidrago_handoff_pivot_ref_score(ref, bench_position)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_handoff_pivot_ref_score(ref: Dictionary, bench_position: String) -> int:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _regidrago_ref_text(ref)
	if kind == "retreat" and action_id.contains("retreat:%s" % bench_position):
		return 880
	if kind != "play_trainer":
		return -999999
	if _v17_name_contains(text, "Switch") and not _v17_name_contains(text, "Switching Cups"):
		return 1050
	if _v17_name_contains(text, "Prime Catcher"):
		return 990
	if _v17_name_contains(text, "Escape Rope"):
		return 720
	return -999999


func _regidrago_route_ref(ref: Dictionary, capability: String = "ready_bench_handoff") -> Dictionary:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var result := {
		"id": action_id,
		"action_id": action_id,
		"type": str(ref.get("type", ref.get("kind", ""))),
		"capability": capability,
	}
	for key: String in ["card", "summary", "position", "interaction_schema"]:
		if ref.has(key):
			result[key] = ref.get(key)
	return result


func _regidrago_handoff_selection_policy(bench_position: String) -> Dictionary:
	return {
		"own_bench_target": bench_position,
		"switch_target": bench_position,
		"self_pivot_target": bench_position,
		"target_position": bench_position,
	}


func _regidrago_payload_has_route(routes: Array, route_action_id: String) -> bool:
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("route_action_id", "")) == route_action_id:
			return true
	return false


func _regidrago_ref_text(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("type", ref.get("kind", ""))),
		str(ref.get("card", "")),
		str(ref.get("summary", "")),
	]
	return " ".join(parts)


func _regidrago_llm_should_allow_celestial_roar_setup(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _regidrago_llm_is_celestial_roar_action(action, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var source := _regidrago_llm_action_source_slot(action, player)
	if source == null or not _regidrago_llm_is_regidrago_v_slot(source):
		return false
	var deck_count := _player_deck_count_for_llm(game_state, player_index)
	if deck_count >= 0 and deck_count <= 18:
		return false
	var attack_cost := _regidrago_llm_attack_cost(source, int(action.get("attack_index", 0)), "C")
	if not _active_attack_cost_ready(source, attack_cost):
		return false
	if _regidrago_llm_has_ready_apex_line(player):
		return false
	return true


func _regidrago_llm_should_block_basic_dragon_laser_for_apex(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if bool(action.get("projected_knockout", false)):
		return false
	if not _regidrago_llm_is_basic_dragon_laser_action(action, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if game_state.turn_number < 4:
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return false
	if not _regidrago_llm_hand_has_vstar(player):
		return false
	var active := player.active_pokemon
	if not _active_attack_cost_ready(active, _regidrago_llm_attack_cost(active, 1, "GGR")):
		return false
	return true


func _regidrago_llm_is_basic_dragon_laser_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind not in ["attack", "granted_attack"]:
		return false
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	var source := _regidrago_llm_action_source_slot(action, player)
	if source == null or not _regidrago_llm_is_regidrago_v_slot(source):
		return false
	if int(action.get("attack_index", -1)) == 1:
		return true
	var attack_name := _regidrago_llm_attack_name(action, source)
	return _v17_name_contains(attack_name, "Dragon Laser")


func _regidrago_llm_is_celestial_roar_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	var source := _regidrago_llm_action_source_slot(action, player)
	if source == null or not _regidrago_llm_is_regidrago_v_slot(source):
		return false
	var attack_name := _regidrago_llm_attack_name(action, source)
	if _v17_name_contains(attack_name, "Celestial Roar") or _v17_name_contains(attack_name, "天之呐喊"):
		return true
	return int(action.get("attack_index", -1)) == 0


func _regidrago_llm_action_source_slot(action: Dictionary, player: PlayerState) -> PokemonSlot:
	var raw_source: Variant = action.get("source_slot", null)
	if raw_source is PokemonSlot:
		return raw_source
	return player.active_pokemon if player != null else null


func _regidrago_llm_attack_name(action: Dictionary, source: PokemonSlot) -> String:
	var attack_name := str(action.get("attack_name", action.get("attack", ""))).strip_edges()
	if attack_name != "":
		return attack_name
	if source == null or source.get_card_data() == null:
		return ""
	var attack_index := int(action.get("attack_index", -1))
	var attacks: Array = source.get_card_data().attacks
	if attack_index >= 0 and attack_index < attacks.size() and attacks[attack_index] is Dictionary:
		return str((attacks[attack_index] as Dictionary).get("name", "")).strip_edges()
	return ""


func _regidrago_llm_attack_cost(source: PokemonSlot, attack_index: int, fallback: String) -> String:
	if source == null or source.get_card_data() == null:
		return fallback
	var attacks: Array = source.get_card_data().attacks
	if attack_index >= 0 and attack_index < attacks.size() and attacks[attack_index] is Dictionary:
		var cost := str((attacks[attack_index] as Dictionary).get("cost", "")).strip_edges()
		return cost if cost != "" else fallback
	return fallback


func _regidrago_llm_has_ready_apex_line(player: PlayerState) -> bool:
	if player == null or not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return false
	for slot: PokemonSlot in _regidrago_llm_all_slots(player):
		if not _regidrago_llm_is_regidrago_vstar_slot(slot):
			continue
		if _active_attack_cost_ready(slot, _regidrago_llm_attack_cost(slot, 0, "GGR")):
			return true
	return false


func _regidrago_llm_has_dragon_fuel_in_discard(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _matches_any(name, REGIDRAGO_LLM_APEX_FUEL_NAMES) or _matches_any(name, _deck_secondary_attackers()):
			return true
	return false


func _regidrago_llm_hand_has_vstar(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _v17_name_contains(name, "Regidrago VSTAR") or _v17_name_contains(name, "闆峰悏閾庢媺鎴圴STAR"):
			return true
	return false


func _regidrago_llm_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots


func _regidrago_llm_is_regidrago_v_slot(slot: PokemonSlot) -> bool:
	var name := _slot_name(slot)
	if name == "" or _v17_name_contains(name, "VSTAR"):
		return false
	return _v17_name_contains(name, "Regidrago V") or _v17_name_contains(name, "雷吉铎拉戈V")


func _regidrago_llm_is_regidrago_vstar_slot(slot: PokemonSlot) -> bool:
	var name := _slot_name(slot)
	return _v17_name_contains(name, "Regidrago VSTAR") or _v17_name_contains(name, "雷吉铎拉戈VSTAR")
