extends "res://scripts/ai/DeckStrategy17LLMBase.gd"

const REGIDRAGO_LLM_APEX_FUEL_NAMES: Array[String] = [
	"Dragapult ex",
	"Giratina VSTAR",
	"Hisuian Goodra VSTAR",
	"Haxorus",
	"Alolan Exeggutor ex",
	"Kyurem",
]
const REGIDRAGO_LLM_RADIANT_CHARIZARD := "Radiant Charizard"


func _llm_strategy_id() -> String:
	return "v17_regidrago_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17Regidrago.gd"


func ensure_llm_request_fired(game_state: GameState, player_index: int, legal_actions: Array = []) -> void:
	if game_state == null or game_state.phase != GameState.GamePhase.MAIN:
		return
	super.ensure_llm_request_fired(game_state, player_index, legal_actions)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _regidrago_llm_should_hard_block_ready_active_apex_pivot(action, game_state, player_index):
		return -13000.0
	if str(action.get("kind", action.get("type", ""))) == "end_turn" and _regidrago_llm_should_block_end_for_ready_active_apex(game_state, player_index):
		return -12000.0
	if _regidrago_llm_should_preserve_mew_draw_engine(action, game_state, player_index):
		return -10000.0
	if _regidrago_llm_should_block_support_pivot_to_liability(action, game_state, player_index):
		return -12000.0
	if _regidrago_llm_should_block_radiant_charizard_resource(action, game_state, player_index):
		return -10000.0
	if _regidrago_llm_should_preserve_active_ogerpon_buffer(action, game_state, player_index):
		return -10000.0
	if _regidrago_llm_should_block_basic_dragon_laser_for_apex(action, game_state, player_index):
		return -10000.0
	if _regidrago_llm_should_block_attack_before_backup_seed(action, game_state, player_index):
		return -10000.0
	if _regidrago_llm_should_block_apex_before_backup_vstar(action, game_state, player_index):
		return -10000.0
	return super.score_action_absolute(action, game_state, player_index)


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
	if _regidrago_llm_should_block_end_for_ready_active_apex(game_state, player_index) \
			and _regidrago_llm_is_apex_dragon_action(action, game_state, player_index):
		return true
	if _regidrago_llm_should_replace_end_with_energy_switch(action, game_state, player_index):
		return true
	return _regidrago_llm_should_allow_celestial_roar_setup(action, game_state, player_index) \
			and not _catalog_has_productive_non_terminal_action()


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return super._deck_should_block_end_turn(game_state, player_index) \
			or _regidrago_llm_should_block_end_for_ready_active_apex(game_state, player_index) \
			or _regidrago_llm_should_block_end_for_energy_switch_setup(game_state, player_index)


func _deck_should_block_exact_queue_match(
	_queued_action: Dictionary,
	runtime_action: Dictionary,
	game_state: GameState,
	player_index: int
) -> bool:
	if _regidrago_llm_is_celestial_roar_action(runtime_action, game_state, player_index):
		return not _regidrago_llm_should_allow_celestial_roar_setup(runtime_action, game_state, player_index)
	if _regidrago_llm_should_block_radiant_charizard_resource(runtime_action, game_state, player_index):
		return true
	if _regidrago_llm_should_block_attack_before_backup_seed(runtime_action, game_state, player_index):
		return true
	if _regidrago_llm_should_block_basic_dragon_laser_for_apex(runtime_action, game_state, player_index):
		return true
	if _regidrago_llm_should_block_apex_before_backup_vstar(runtime_action, game_state, player_index):
		return true
	if str(runtime_action.get("kind", runtime_action.get("type", ""))) == "end_turn" \
			and _regidrago_llm_should_block_end_for_ready_active_apex(game_state, player_index):
		return true
	if _regidrago_llm_should_preserve_active_ogerpon_buffer(runtime_action, game_state, player_index):
		return true
	if _regidrago_llm_should_preserve_mew_draw_engine(runtime_action, game_state, player_index):
		return true
	if _regidrago_llm_should_block_support_pivot_to_liability(runtime_action, game_state, player_index):
		return true
	if _regidrago_llm_should_block_switching_active_primary(runtime_action, game_state, player_index):
		return true
	return false


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _regidrago_llm_is_apex_dragon_action(action, game_state, player_index)


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
		"【喷火龙对局】如果 Charizard ex 已经开始攻击，攻击前优先保留 Energy Switch、铺第二只 Regidrago V，并确保 Hisuian Goodra VSTAR 在弃牌区；200 点不能拿奖时复制 Rolling Iron 争取多活一回合。",
		"【资源原则】龙系燃料在手里通常是弃牌资源，不要用 Nest Ball 把它们放到后场；Super Rod/Night Stretcher 不要把唯一 Dragapult ex 等关键燃料洗回去，除非是救命续航。",
		"【撤退原则】已经带攻击能量的 Regidrago 路线所有者不能随便付能撤退到支援位；只有能交接给已就绪攻击手时才换位。",
	])


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result: Dictionary = super._deck_augment_action_id_payload(payload, game_state, player_index)
	result = _regidrago_apply_active_ogerpon_buffer_lock(result, game_state, player_index)
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
	var charge_apex_route := _regidrago_charge_apex_candidate_route(result, game_state, player_index)
	if not charge_apex_route.is_empty():
		if not _regidrago_payload_has_route(updated_routes, "route:regidrago_charge_apex_attack"):
			updated_routes.push_front(charge_apex_route)
		var charge_actions: Array = charge_apex_route.get("actions", []) if charge_apex_route.get("actions", []) is Array else []
		var charge_attach_id := ""
		var charge_switch_id := ""
		for raw_charge_action: Variant in charge_actions:
			if not (raw_charge_action is Dictionary):
				continue
			var charge_action: Dictionary = raw_charge_action
			var charge_type := str(charge_action.get("type", ""))
			if charge_type == "attach_energy":
				charge_attach_id = str(charge_action.get("id", ""))
			elif charge_type == "play_trainer" and _v17_name_contains(_regidrago_ref_text(charge_action), "Energy Switch"):
				charge_switch_id = str(charge_action.get("id", ""))
		facts["regidrago_charge_apex"] = {
			"route_available": true,
			"route_action_id": "route:regidrago_charge_apex_attack",
			"attach_action_id": charge_attach_id,
			"energy_switch_action_id": charge_switch_id,
			"attack_name": "Apex Dragon",
			"reason": "Active Regidrago VSTAR can be reloaded this turn; attach and/or move Ogerpon Grass before ending the queue so runtime converts into Apex Dragon.",
		}
	var ogerpon_buffer_route := _regidrago_ogerpon_buffer_apex_candidate_route(result, game_state, player_index)
	if not ogerpon_buffer_route.is_empty():
		if not _regidrago_payload_has_route(updated_routes, "route:regidrago_ogerpon_buffer_apex_attack"):
			updated_routes.push_front(ogerpon_buffer_route)
		facts["regidrago_ogerpon_buffer_apex"] = {
			"route_available": true,
			"route_action_id": "route:regidrago_ogerpon_buffer_apex_attack",
			"bench_position": str(ogerpon_buffer_route.get("bench_position", "")),
			"attack_name": "Apex Dragon",
			"reason": "Active Ogerpon has enough Energy to donate one Grass and still retreat, so the protected bench Regidrago can evolve, finish GGR, pivot active, and attack.",
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
	var copied_attack_payload := _regidrago_copied_attack_payload(game_state, player_index)
	if not copied_attack_payload.is_empty():
		facts["regidrago_copied_attack_options"] = copied_attack_payload.get("options", [])
		facts["regidrago_recommended_copied_attack"] = copied_attack_payload.get("recommended", {})
		result["legal_actions"] = _regidrago_rewrite_apex_payload_actions(
			result.get("legal_actions", []) if result.get("legal_actions", []) is Array else [],
			copied_attack_payload
		)
		updated_routes = _regidrago_rewrite_apex_candidate_routes(updated_routes, copied_attack_payload)
		facts = _regidrago_rewrite_apex_tactical_facts(facts)
	result["candidate_routes"] = updated_routes
	result["turn_tactical_facts"] = facts
	return result


func _regidrago_apply_active_ogerpon_buffer_lock(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if not _regidrago_active_ogerpon_buffer_lock_applies(game_state, player_index):
		return payload
	var player: PlayerState = game_state.players[player_index]
	var locked_positions := _regidrago_basic_regidrago_bench_positions(player)
	if locked_positions.is_empty():
		return payload
	var result := payload.duplicate(true)
	var legal_actions: Array = result.get("legal_actions", []) if result.get("legal_actions", []) is Array else []
	var filtered_legal: Array = []
	for raw_action: Variant in legal_actions:
		if raw_action is Dictionary and _regidrago_ref_breaks_active_ogerpon_buffer(raw_action as Dictionary, locked_positions, player):
			continue
		filtered_legal.append(raw_action)
	result["legal_actions"] = filtered_legal

	var future_actions: Array = result.get("future_actions", []) if result.get("future_actions", []) is Array else []
	var filtered_future: Array = []
	for raw_future: Variant in future_actions:
		if raw_future is Dictionary and _regidrago_ref_breaks_active_ogerpon_buffer(raw_future as Dictionary, locked_positions, player):
			continue
		filtered_future.append(raw_future)
	result["future_actions"] = filtered_future

	var candidate_routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var filtered_routes: Array = []
	for raw_route: Variant in candidate_routes:
		if raw_route is Dictionary and _regidrago_route_breaks_active_ogerpon_buffer(raw_route as Dictionary, locked_positions, player):
			continue
		filtered_routes.append(raw_route)
	result["candidate_routes"] = filtered_routes

	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	facts["regidrago_active_ogerpon_buffer_lock"] = {
		"active": true,
		"locked_positions": locked_positions.duplicate(),
		"reason": "Active Ogerpon is the opening damage buffer. Do not spend Energy Switch or pivot into basic Regidrago before a VSTAR Apex attack handoff is actually ready.",
	}
	result["turn_tactical_facts"] = facts
	return result


func _regidrago_active_ogerpon_buffer_lock_applies(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _regidrago_llm_is_ogerpon_slot(player.active_pokemon):
		return false
	return not _regidrago_basic_regidrago_bench_positions(player).is_empty()


func _regidrago_basic_regidrago_bench_positions(player: PlayerState) -> Array[String]:
	var positions: Array[String] = []
	if player == null:
		return positions
	for i: int in player.bench.size():
		var slot: PokemonSlot = player.bench[i]
		if slot != null and _regidrago_llm_is_regidrago_v_slot(slot):
			positions.append("bench_%d" % i)
	return positions


func _regidrago_ref_breaks_active_ogerpon_buffer(ref: Dictionary, locked_positions: Array[String], player: PlayerState) -> bool:
	if _regidrago_llm_is_energy_switch_action(ref) \
			and not _regidrago_active_ogerpon_can_spare_grass(player) \
			and not _regidrago_has_non_active_movable_grass(player):
		return true
	if not _regidrago_ref_targets_any_position(ref, locked_positions):
		return false
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var kind := str(ref.get("type", ref.get("kind", "")))
	if kind == "retreat":
		return not _regidrago_active_ogerpon_can_spare_grass(player)
	if action_id.begins_with("future:retreat_to:"):
		return true
	if action_id.begins_with("future:attack_after_pivot:"):
		return true
	return false


func _regidrago_route_breaks_active_ogerpon_buffer(route: Dictionary, locked_positions: Array[String], player: PlayerState) -> bool:
	var evolves_locked_target := _regidrago_route_evolves_locked_position(route, locked_positions)
	for key: String in ["actions", "future_goals"]:
		var refs: Array = route.get(key, []) if route.get(key, []) is Array else []
		for raw_ref: Variant in refs:
			if not (raw_ref is Dictionary):
				continue
			var ref: Dictionary = raw_ref
			if _regidrago_llm_is_energy_switch_action(ref) \
					and not _regidrago_active_ogerpon_can_spare_grass(player) \
					and not _regidrago_has_non_active_movable_grass(player):
				return true
			if not _regidrago_ref_targets_any_position(ref, locked_positions):
				continue
			var action_id := str(ref.get("id", ref.get("action_id", "")))
			var kind := str(ref.get("type", ref.get("kind", "")))
			if kind == "retreat" or action_id.begins_with("future:retreat_to:") or action_id.begins_with("future:attack_after_pivot:"):
				if not evolves_locked_target:
					return true
	return false


func _regidrago_route_evolves_locked_position(route: Dictionary, locked_positions: Array[String]) -> bool:
	var refs: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	for raw_ref: Variant in refs:
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		var kind := str(ref.get("type", ref.get("kind", "")))
		if kind != "evolve":
			continue
		if _regidrago_ref_targets_any_position(ref, locked_positions):
			return true
	return false


func _regidrago_ref_targets_any_position(ref: Dictionary, positions: Array[String]) -> bool:
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	var position := str(ref.get("position", ref.get("bench_position", "")))
	for target_position: String in positions:
		if position == target_position:
			return true
		if action_id.contains(":%s" % target_position) or action_id.ends_with(target_position):
			return true
	return false


func _regidrago_has_non_active_movable_grass(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _regidrago_llm_all_slots(player):
		if slot == null or slot == player.active_pokemon:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			if _energy_symbol_for_runtime(str(energy.card_data.energy_provides)) == "G":
				return true
	return false


func _regidrago_copied_attack_payload(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or not _regidrago_llm_is_regidrago_vstar_slot(player.active_pokemon):
		return {}
	var options := _regidrago_copied_attack_options(game_state, player_index)
	if options.is_empty():
		return {}
	var recommended := _regidrago_recommended_copied_attack(options, game_state, player_index)
	return {
		"options": options,
		"recommended": recommended,
	}


func _regidrago_copied_attack_options(game_state: GameState, player_index: int) -> Array:
	var player: PlayerState = game_state.players[player_index]
	var options: Array = []
	var seen: Dictionary = {}
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var option := _regidrago_copied_attack_option_for_card(card.card_data, game_state, player_index)
		if option.is_empty():
			continue
		var key := "%s:%s" % [str(option.get("source_card", "")), str(option.get("attack_name", ""))]
		if bool(seen.get(key, false)):
			continue
		seen[key] = true
		options.append(option)
	return options


func _regidrago_copied_attack_option_for_card(cd: CardData, game_state: GameState, player_index: int) -> Dictionary:
	var name := _best_card_name(cd)
	var opponent: PlayerState = game_state.players[1 - player_index]
	var defender: PokemonSlot = opponent.active_pokemon if opponent != null else null
	var defender_remaining := defender.get_remaining_hp() if defender != null else 0
	var defender_name := _slot_name(defender)
	if _v17_name_contains(name, "Giratina VSTAR") or _v17_name_contains(name, "骑拉帝纳VSTAR"):
		return _regidrago_copied_attack_option("Giratina VSTAR", "Lost Impact", 280, defender_remaining, defender_name, "High single-target damage; use when 280 takes or sets up the active Charizard prize.")
	if _v17_name_contains(name, "Dragapult ex") or _v17_name_contains(name, "多龙巴鲁托ex"):
		return _regidrago_copied_attack_option("Dragapult ex", "Phantom Dive", 200, defender_remaining, defender_name, "200 active damage plus bench counters; prefer when 200 takes a prize or Goodra will not keep Regidrago alive.")
	if _v17_name_contains(name, "Hisuian Goodra VSTAR") or _v17_name_contains(name, "洗翠") or _v17_name_contains(name, "黏美龙VSTAR"):
		var survives := _regidrago_goodra_reduction_survives_charizard_return(game_state, player_index)
		var reason := "200 damage and -80 damage taken next opponent turn."
		if not survives:
			reason += " Current Regidrago is too damaged for the reduction to save it against Charizard."
		return _regidrago_copied_attack_option("Hisuian Goodra VSTAR", "Rolling Iron", 200, defender_remaining, defender_name, reason, {"survives_expected_charizard_return": survives})
	if _v17_name_contains(name, "Kyurem") or _v17_name_contains(name, "酋雷姆"):
		return _regidrago_copied_attack_option("Kyurem", "Trifrost", 330, defender_remaining, defender_name, "Spread 110 damage to up to three targets when multiple prizes are exposed.")
	if _v17_name_contains(name, "Alolan Exeggutor ex") or _v17_name_contains(name, "阿罗拉椰蛋树ex"):
		return _regidrago_copied_attack_option("Alolan Exeggutor ex", "Tropical Frenzy", 150, defender_remaining, defender_name, "Utility Dragon option; use only for special target effects.")
	return {}


func _regidrago_copied_attack_option(
	source_card: String,
	attack_name: String,
	damage: int,
	defender_remaining: int,
	defender_name: String,
	reason: String,
	extra: Dictionary = {}
) -> Dictionary:
	var option := {
		"source_card": source_card,
		"attack_name": attack_name,
		"damage": damage,
		"defender": defender_name,
		"defender_remaining_hp": defender_remaining,
		"takes_active_prize": defender_remaining > 0 and damage >= defender_remaining,
		"reason": reason,
	}
	for key: String in extra.keys():
		option[key] = extra.get(key)
	return option


func _regidrago_recommended_copied_attack(options: Array, game_state: GameState, player_index: int) -> Dictionary:
	var opponent: PlayerState = game_state.players[1 - player_index]
	var defender: PokemonSlot = opponent.active_pokemon if opponent != null else null
	var defender_name := _slot_name(defender)
	var charizard_pressure := _regidrago_llm_name_is_charizard_pressure(defender_name) or _regidrago_llm_opponent_has_charizard_pressure(game_state, player_index)
	var giratina := _regidrago_find_copied_option(options, "Giratina VSTAR", "Lost Impact")
	var dragapult := _regidrago_find_copied_option(options, "Dragapult ex", "Phantom Dive")
	var goodra := _regidrago_find_copied_option(options, "Hisuian Goodra VSTAR", "Rolling Iron")
	if charizard_pressure:
		if _regidrago_llm_is_goodra_same_prize_window(defender, goodra):
			return _regidrago_copied_recommendation(goodra, "Goodra takes the same active prize while reducing the Charizard return swing.")
		if not giratina.is_empty() and bool(giratina.get("takes_active_prize", false)):
			return _regidrago_copied_recommendation(giratina, "Giratina 280 takes the active Charizard prize.")
		if not goodra.is_empty() and bool(goodra.get("survives_expected_charizard_return", false)):
			return _regidrago_copied_recommendation(goodra, "Goodra 200 plus -80 keeps Regidrago alive for the next attack.")
		if not giratina.is_empty():
			return _regidrago_copied_recommendation(giratina, "Goodra reduction will not save this Regidrago; push 280 damage into Charizard instead of a 200 hit.")
		if not dragapult.is_empty():
			return _regidrago_copied_recommendation(dragapult, "Goodra reduction will not save this Regidrago; take 200 plus bench counters instead.")
	for option: Dictionary in options:
		if bool(option.get("takes_active_prize", false)):
			return _regidrago_copied_recommendation(option, "This copied attack takes the active prize.")
	if not dragapult.is_empty():
		return _regidrago_copied_recommendation(dragapult, "Default to Dragapult for active damage plus bench pressure.")
	if not goodra.is_empty():
		return _regidrago_copied_recommendation(goodra, "Use Goodra when no higher-value copied attack is available.")
	return _regidrago_copied_recommendation(options[0] as Dictionary, "Only visible copied attack option.")


func _regidrago_llm_is_goodra_same_prize_window(defender: PokemonSlot, goodra: Dictionary) -> bool:
	if defender == null or goodra.is_empty() or not bool(goodra.get("takes_active_prize", false)):
		return false
	return defender.get_remaining_hp() > 0 and defender.get_remaining_hp() <= 200


func _regidrago_find_copied_option(options: Array, source: String, attack: String) -> Dictionary:
	for raw: Variant in options:
		if not (raw is Dictionary):
			continue
		var option: Dictionary = raw
		if str(option.get("source_card", "")) == source or str(option.get("attack_name", "")) == attack:
			return option
	return {}


func _regidrago_copied_recommendation(option: Dictionary, reason: String) -> Dictionary:
	if option.is_empty():
		return {}
	return {
		"source_card": str(option.get("source_card", "")),
		"attack_name": str(option.get("attack_name", "")),
		"copied_attack": str(option.get("attack_name", "")),
		"reason": reason,
	}


func _regidrago_rewrite_apex_payload_actions(actions: Array, copied_attack_payload: Dictionary) -> Array:
	var rewritten: Array = []
	for raw: Variant in actions:
		if not (raw is Dictionary):
			rewritten.append(raw)
			continue
		var action: Dictionary = (raw as Dictionary).duplicate(true)
		if _regidrago_payload_ref_is_apex_attack(action):
			action["requires_interaction"] = true
			action["interaction_schema"] = _regidrago_copied_attack_schema()
			action["attack_quality"] = _regidrago_apex_attack_quality()
			var recommended: Dictionary = copied_attack_payload.get("recommended", {}) if copied_attack_payload.get("recommended", {}) is Dictionary else {}
			if not recommended.is_empty():
				action["selection_policy"] = _regidrago_copied_attack_selection_policy(recommended)
		rewritten.append(action)
	return rewritten


func _regidrago_rewrite_apex_candidate_routes(routes: Array, copied_attack_payload: Dictionary) -> Array:
	var recommended: Dictionary = copied_attack_payload.get("recommended", {}) if copied_attack_payload.get("recommended", {}) is Dictionary else {}
	if recommended.is_empty():
		return routes
	var rewritten: Array = []
	for raw_route: Variant in routes:
		if not (raw_route is Dictionary):
			rewritten.append(raw_route)
			continue
		var route: Dictionary = (raw_route as Dictionary).duplicate(true)
		if route.get("actions", []) is Array:
			var actions: Array = []
			for raw_action: Variant in route.get("actions", []):
				if raw_action is Dictionary:
					var action: Dictionary = (raw_action as Dictionary).duplicate(true)
					if _regidrago_payload_ref_is_apex_attack(action):
						action["selection_policy"] = _regidrago_copied_attack_selection_policy(recommended)
						action["interaction_schema"] = _regidrago_copied_attack_schema()
						action["attack_quality"] = _regidrago_apex_attack_quality()
					actions.append(action)
				else:
					actions.append(raw_action)
			route["actions"] = actions
		rewritten.append(route)
	return rewritten


func _regidrago_rewrite_apex_tactical_facts(facts: Dictionary) -> Dictionary:
	var result := facts.duplicate(true)
	var quality_by_id: Dictionary = result.get("attack_quality_by_action_id", {}) if result.get("attack_quality_by_action_id", {}) is Dictionary else {}
	quality_by_id = quality_by_id.duplicate(true)
	for key: String in quality_by_id.keys():
		if _regidrago_text_is_apex_attack(key):
			quality_by_id[key] = _regidrago_apex_attack_quality()
	result["attack_quality_by_action_id"] = quality_by_id
	if result.get("active_attack_options", []) is Array:
		var active_options: Array = []
		for raw: Variant in result.get("active_attack_options", []):
			if raw is Dictionary:
				var option: Dictionary = (raw as Dictionary).duplicate(true)
				if _regidrago_text_is_apex_attack("%s %s" % [str(option.get("legal_action_id", "")), str(option.get("attack_name", ""))]):
					option["attack_quality"] = _regidrago_apex_attack_quality()
					option["ready_now"] = true
				active_options.append(option)
			else:
				active_options.append(raw)
		result["active_attack_options"] = active_options
	return result


func _regidrago_copied_attack_selection_policy(recommended: Dictionary) -> Dictionary:
	return {
		"copied_attack": str(recommended.get("copied_attack", recommended.get("attack_name", ""))),
		"attack_name": str(recommended.get("attack_name", "")),
		"source_card": str(recommended.get("source_card", "")),
		"reason": str(recommended.get("reason", "")),
	}


func _regidrago_copied_attack_schema() -> Dictionary:
	return {
		"copied_attack": {
			"type": "string",
			"items": "exact copied attack name or source Dragon Pokemon name from the revealed option pool",
			"examples": ["Lost Impact", "Giratina VSTAR", "Phantom Dive", "Dragapult ex", "Rolling Iron", "Hisuian Goodra VSTAR"],
			"max_select": 1,
			"note": "This chooses an attack from a Dragon Pokemon in discard. It does not discard cards from hand.",
		},
	}


func _regidrago_apex_attack_quality() -> Dictionary:
	return {
		"role": "primary_damage",
		"terminal_priority": "high",
		"discard_entire_hand": false,
		"takes_prize": true,
		"copied_attack": true,
		"reason": "Regidrago VSTAR copies the best Dragon attack from discard.",
	}


func _regidrago_payload_ref_is_apex_attack(ref: Dictionary) -> bool:
	var kind := str(ref.get("type", ref.get("kind", "")))
	if kind != "" and kind not in ["attack", "granted_attack"]:
		return false
	return _regidrago_text_is_apex_attack(_regidrago_ref_text(ref))


func _regidrago_text_is_apex_attack(text: String) -> bool:
	return _v17_name_contains(text, "Apex Dragon") \
			or _v17_name_contains(text, "巨龙无双") \
			or _v17_name_contains(text, "瀹搞劑绶抽弮鐘插蓟")


func _regidrago_goodra_reduction_survives_charizard_return(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	var prizes_taken := 0 if player.prizes.is_empty() else maxi(0, 6 - player.prizes.size())
	var expected_charizard_damage := maxi(0, 180 + prizes_taken * 30 - 80)
	return player.active_pokemon.get_remaining_hp() > expected_charizard_damage


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


func _regidrago_charge_apex_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return {}
	var active: PokemonSlot = player.active_pokemon
	if not _regidrago_llm_is_regidrago_vstar_slot(active):
		return {}
	if not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return {}
	var counts := _regidrago_attached_energy_counts(active)
	if _regidrago_energy_counts_can_pay_cost(counts, "GGR"):
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var attach_ref := _best_regidrago_apex_charge_attach_ref(legal_actions, active, counts)
	var switch_ref := _best_regidrago_energy_switch_ref(legal_actions)
	var has_switch := not switch_ref.is_empty() and _regidrago_has_movable_grass_energy(player, active)
	if not attach_ref.is_empty():
		var after_attach := _regidrago_counts_after_symbol(counts, _regidrago_attach_ref_energy_symbol(attach_ref))
		if _regidrago_energy_counts_can_pay_cost(after_attach, "GGR"):
			return _regidrago_charge_apex_route([
				_regidrago_route_ref(attach_ref, "manual_attach_to_apex"),
				{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
			], "manual_attach_apex_attack", "Attach the missing energy to active Regidrago VSTAR, then attack with Apex Dragon.")
	if has_switch:
		var after_switch := _regidrago_counts_after_symbol(counts, "G")
		if _regidrago_energy_counts_can_pay_cost(after_switch, "GGR"):
			return _regidrago_charge_apex_route([
				_regidrago_route_ref(switch_ref, "energy_switch_to_apex"),
				{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
			], "energy_switch_apex_attack", "Move a spare Grass energy from an Ogerpon-style bank to active Regidrago VSTAR, then attack with Apex Dragon.")
	if has_switch and not attach_ref.is_empty():
		var after_both := _regidrago_counts_after_symbol(counts, "G")
		after_both = _regidrago_counts_after_symbol(after_both, _regidrago_attach_ref_energy_symbol(attach_ref))
		if _regidrago_energy_counts_can_pay_cost(after_both, "GGR"):
			return _regidrago_charge_apex_route([
				_regidrago_route_ref(switch_ref, "energy_switch_to_apex"),
				_regidrago_route_ref(attach_ref, "manual_attach_to_apex"),
				{"id": "end_turn", "action_id": "end_turn", "type": "end_turn"},
			], "reload_apex_attack", "Move Ogerpon Grass and manually attach to complete active Regidrago VSTAR's GGR, then attack with Apex Dragon.")
	return {}


func _regidrago_charge_apex_route(actions: Array, goal: String, description: String) -> Dictionary:
	return {
		"id": "regidrago_charge_apex_attack",
		"route_action_id": "route:regidrago_charge_apex_attack",
		"type": "candidate_route",
		"priority": 997,
		"base_priority": 997,
		"goal": goal,
		"description": description,
		"actions": actions,
		"future_goals": [
			{
				"id": "future:regidrago_apex_after_charge",
				"type": "attack",
				"future": true,
				"position": "active",
				"source_pokemon": "Regidrago VSTAR",
				"attack_name": "Apex Dragon",
				"attack_quality": {"role": "primary_damage", "terminal_priority": "high", "takes_prize": true},
			},
		],
		"contract": "Select this route when active Regidrago VSTAR has dragon fuel but is missing GGR energy and visible attach/Energy Switch actions can complete the attack this turn.",
		"strategy_adjustable": true,
	}


func _regidrago_ogerpon_buffer_apex_candidate_route(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return {}
	if not _regidrago_llm_is_ogerpon_slot(player.active_pokemon):
		return {}
	if not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return {}
	if not _regidrago_active_ogerpon_can_spare_grass(player):
		return {}
	var target := _regidrago_best_bench_apex_target(player)
	if target == null:
		return {}
	var bench_position := _regidrago_bench_position(player, target)
	if bench_position == "":
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var pivot_ref := _best_regidrago_handoff_pivot_ref(legal_actions, bench_position)
	if pivot_ref.is_empty():
		return {}
	var actions: Array[Dictionary] = []
	var working_counts := _regidrago_attached_energy_counts(target)
	if _regidrago_llm_is_regidrago_v_slot(target):
		var evolve_ref := _best_regidrago_apex_evolve_ref_for_position(legal_actions, bench_position)
		if evolve_ref.is_empty():
			return {}
		actions.append(_regidrago_route_ref(evolve_ref, "evolve_buffered_apex"))
	elif not _regidrago_llm_is_regidrago_vstar_slot(target):
		return {}
	if not _regidrago_energy_counts_can_pay_cost(working_counts, "GGR"):
		var attach_ref := _best_regidrago_bench_apex_attach_ref(legal_actions, bench_position, working_counts)
		if not attach_ref.is_empty():
			actions.append(_regidrago_route_ref(attach_ref, "manual_attach_buffered_apex"))
			working_counts = _regidrago_counts_after_symbol(working_counts, _regidrago_attach_ref_energy_symbol(attach_ref))
	if not _regidrago_energy_counts_can_pay_cost(working_counts, "GGR"):
		var switch_ref := _best_regidrago_energy_switch_ref(legal_actions)
		if switch_ref.is_empty():
			return {}
		actions.append(_regidrago_route_ref(switch_ref, "energy_switch_buffered_apex"))
		working_counts = _regidrago_counts_after_symbol(working_counts, "G")
	if not _regidrago_energy_counts_can_pay_cost(working_counts, "GGR"):
		return {}
	var pivot_action := _regidrago_route_ref(pivot_ref, "pivot_buffered_apex")
	pivot_action["selection_policy"] = _regidrago_handoff_selection_policy(bench_position)
	actions.append(pivot_action)
	actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "regidrago_ogerpon_buffer_apex_attack",
		"route_action_id": "route:regidrago_ogerpon_buffer_apex_attack",
		"type": "candidate_route",
		"priority": 1001,
		"base_priority": 1001,
		"goal": "ogerpon_buffer_handoff_apex_attack",
		"description": "Keep Ogerpon active as the damage buffer, evolve and charge the benched Regidrago, then pivot into Apex Dragon once Ogerpon can still pay retreat after donating Grass.",
		"bench_position": bench_position,
		"attack_name": "Apex Dragon",
		"actions": actions,
		"future_goals": [
			{
				"id": "future:regidrago_apex_after_ogerpon_buffer",
				"type": "attack",
				"future": true,
				"position": bench_position,
				"source_pokemon": "Regidrago VSTAR",
				"attack_name": "Apex Dragon",
				"attack_quality": {"role": "primary_damage", "terminal_priority": "high", "takes_prize": true},
			},
		],
		"contract": "Select this route when Ogerpon is active with spare retreat Energy and a benched Regidrago can be evolved, charged with manual attach plus Energy Switch, pivoted active, and attack this turn.",
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


func _best_regidrago_apex_evolve_ref_for_position(legal_actions: Array, bench_position: String) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", ref.get("kind", ""))) != "evolve":
			continue
		var text := _regidrago_ref_text(ref)
		if not (_v17_name_contains(text, "Regidrago VSTAR") or _v17_name_contains(text, "闆峰悏閾庢媺鎴圴STAR")):
			continue
		if not _regidrago_ref_matches_position(ref, bench_position):
			continue
		var score := 1000
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


func _best_regidrago_apex_charge_attach_ref(legal_actions: Array, active: PokemonSlot, counts: Dictionary) -> Dictionary:
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
		var after_attach := _regidrago_counts_after_symbol(counts, symbol)
		if not _regidrago_energy_counts_can_pay_cost(after_attach, "GGR") and not _regidrago_apex_needs_symbol(counts, symbol):
			continue
		var score := 1000
		if _regidrago_energy_counts_can_pay_cost(after_attach, "GGR"):
			score += 220
		if symbol == "G":
			score += 90
		elif symbol == "R":
			score += 70
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _best_regidrago_bench_apex_attach_ref(legal_actions: Array, bench_position: String, counts: Dictionary) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", ref.get("kind", ""))) != "attach_energy":
			continue
		if not _regidrago_ref_matches_position(ref, bench_position):
			continue
		var symbol := _regidrago_attach_ref_energy_symbol(ref)
		if symbol == "":
			continue
		if not _regidrago_apex_needs_symbol(counts, symbol):
			continue
		var score := 1000
		if symbol == "G":
			score += 90
		elif symbol == "R":
			score += 70
		if _regidrago_energy_counts_can_pay_cost(_regidrago_counts_after_symbol(counts, symbol), "GGR"):
			score += 180
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _regidrago_ref_matches_position(ref: Dictionary, position: String) -> bool:
	if position == "":
		return false
	if str(ref.get("position", "")).strip_edges() == position:
		return true
	var action_id := str(ref.get("id", ref.get("action_id", "")))
	if action_id.contains(position):
		return true
	return _regidrago_ref_text(ref).contains(position)


func _regidrago_apex_needs_symbol(counts: Dictionary, symbol: String) -> bool:
	var normalized := _energy_symbol_for_runtime(symbol)
	if normalized == "G":
		return int(counts.get("G", 0)) < 2
	if normalized == "R":
		return int(counts.get("R", 0)) < 1
	return false


func _regidrago_counts_after_symbol(counts: Dictionary, symbol: String) -> Dictionary:
	var result := counts.duplicate()
	var normalized := _energy_symbol_for_runtime(symbol)
	if normalized != "":
		result[normalized] = int(result.get(normalized, 0)) + 1
	return result


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


func _regidrago_active_ogerpon_can_spare_grass(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if not _regidrago_llm_is_ogerpon_slot(player.active_pokemon):
		return false
	var cd := player.active_pokemon.get_card_data()
	var retreat_cost := maxi(0, int(cd.retreat_cost) if cd != null else 1)
	if player.active_pokemon.attached_energy.size() - 1 < retreat_cost:
		return false
	for energy: CardInstance in player.active_pokemon.attached_energy:
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


func _regidrago_best_bench_apex_target(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best_slot: PokemonSlot = null
	var best_score := -999999
	for slot: PokemonSlot in player.bench:
		if slot == null:
			continue
		var score := -999999
		if _regidrago_llm_is_regidrago_vstar_slot(slot):
			score = 1000
		elif _regidrago_llm_is_regidrago_v_slot(slot):
			score = 760
		else:
			continue
		score += slot.attached_energy.size() * 80
		if score <= best_score:
			continue
		best_slot = slot
		best_score = score
	return best_slot


func _regidrago_bench_position(player: PlayerState, slot: PokemonSlot) -> String:
	if player == null or slot == null:
		return ""
	for i: int in player.bench.size():
		if player.bench[i] == slot:
			return "bench_%d" % i
	return ""


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
	if _v17_name_contains(text, "Apex Dragon") or _v17_name_contains(text, "巨龙无双"):
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
	if _v17_name_contains(text, "Energy Switch"):
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


func _regidrago_llm_should_replace_end_with_energy_switch(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _regidrago_llm_is_energy_switch_action(action):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	var rules := _ensure_rules()
	if rules != null and rules.has_method("_energy_switch_completes_primary_regidrago_attack"):
		if bool(rules.call("_energy_switch_completes_primary_regidrago_attack", action, player)):
			return true
	if rules != null and rules.has_method("_energy_switch_advances_primary_regidrago"):
		return bool(rules.call("_energy_switch_advances_primary_regidrago", action, player))
	return false


func _regidrago_llm_should_block_end_for_energy_switch_setup(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _regidrago_llm_hand_has_energy_switch(player):
		return false
	var rules := _ensure_rules()
	if rules != null and rules.has_method("_energy_switch_reloads_primary_regidrago"):
		return bool(rules.call("_energy_switch_reloads_primary_regidrago", player))
	return false


func _regidrago_llm_should_block_end_for_ready_active_apex(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _regidrago_llm_is_regidrago_vstar_slot(player.active_pokemon):
		return false
	if not _regidrago_llm_has_dragon_fuel_in_discard(player):
		return false
	return _active_attack_cost_ready(player.active_pokemon, _regidrago_llm_attack_cost(player.active_pokemon, 0, "GGR"))


func _regidrago_llm_should_hard_block_ready_active_apex_pivot(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _regidrago_llm_should_block_end_for_ready_active_apex(game_state, player_index):
		return false
	if not _regidrago_llm_is_self_pivot_action(action):
		return false
	var player: PlayerState = game_state.players[player_index]
	return not _regidrago_llm_action_promotes_ready_primary(action, player)


func _regidrago_llm_should_block_radiant_charizard_resource(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _regidrago_llm_has_live_or_rebuildable_regidrago(player):
		return false
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "play_basic_to_bench":
		var text := _regidrago_ref_text(action)
		var raw_card: Variant = action.get("card", null)
		if raw_card is CardInstance and (raw_card as CardInstance).card_data != null:
			text += " " + _best_card_name((raw_card as CardInstance).card_data)
		elif raw_card is CardData:
			text += " " + _best_card_name(raw_card as CardData)
		return _v17_name_contains(text, REGIDRAGO_LLM_RADIANT_CHARIZARD)
	if kind != "attach_energy":
		return false
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		target = _regidrago_llm_self_pivot_target_slot(action)
	return target != null and _v17_name_contains(_slot_name(target), REGIDRAGO_LLM_RADIANT_CHARIZARD)


func _regidrago_llm_has_live_or_rebuildable_regidrago(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _regidrago_llm_all_slots(player):
		if _regidrago_llm_is_regidrago_v_slot(slot) or _regidrago_llm_is_regidrago_vstar_slot(slot):
			return true
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _v17_name_contains(name, "Regidrago V"):
			return true
		if _v17_name_contains(name, "雷吉铎拉戈V"):
			return true
	return false


func _regidrago_llm_should_preserve_mew_draw_engine(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if not _regidrago_llm_needs_mew_draw_for_backup_vstar(player):
		return false
	return _regidrago_llm_action_discards_named_card(action, "Mew ex") \
		or _regidrago_llm_action_discards_named_card(action, "梦幻ex")


func _regidrago_llm_needs_mew_draw_for_backup_vstar(player: PlayerState) -> bool:
	if player == null or _regidrago_open_bench_slots(player) <= 0:
		return false
	for slot: PokemonSlot in _regidrago_llm_all_slots(player):
		if _regidrago_llm_is_regidrago_vstar_slot(slot):
			return false
	if not _regidrago_llm_has_backup_basic_regidrago(player):
		return false
	if _regidrago_llm_hand_has_vstar(player):
		return false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _v17_name_contains(name, "Regidrago VSTAR") or _v17_name_contains(name, "雷吉铎拉戈VSTAR") or _v17_name_contains(name, "闆峰悏閾庢媺鎴圴STAR"):
			return true
	return false


func _regidrago_llm_action_discards_named_card(action: Dictionary, target_name: String) -> bool:
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return false
	for raw_target: Variant in targets:
		if not (raw_target is Dictionary):
			continue
		var target: Dictionary = raw_target
		for key: Variant in target.keys():
			if not str(key).to_lower().contains("discard"):
				continue
			var value: Variant = target.get(key)
			if value is Array:
				for entry: Variant in value:
					if entry is CardInstance and (entry as CardInstance).card_data != null:
						if _v17_name_contains(_best_card_name((entry as CardInstance).card_data), target_name):
							return true
			elif value is CardInstance and (value as CardInstance).card_data != null:
				if _v17_name_contains(_best_card_name((value as CardInstance).card_data), target_name):
					return true
	return false


func _regidrago_llm_hand_has_energy_switch(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _v17_name_contains(_best_card_name(card.card_data), "Energy Switch") or _v17_name_contains(_best_card_name(card.card_data), "能量转移"):
			return true
	return false


func _regidrago_llm_is_energy_switch_action(action: Dictionary) -> bool:
	var text := _regidrago_ref_text(action)
	var raw_card: Variant = action.get("card", null)
	if raw_card is CardInstance and (raw_card as CardInstance).card_data != null:
		text += " " + _best_card_name((raw_card as CardInstance).card_data)
	elif raw_card is CardData:
		text += " " + _best_card_name(raw_card as CardData)
	return _v17_name_contains(text, "Energy Switch") or _v17_name_contains(text, "能量转移")


func _regidrago_llm_should_preserve_active_ogerpon_buffer(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _regidrago_llm_is_ogerpon_slot(player.active_pokemon):
		return false
	if _regidrago_llm_is_energy_switch_action(action):
		return not _regidrago_active_ogerpon_can_spare_grass(player) and not _regidrago_has_non_active_movable_grass(player)
	if not _regidrago_llm_is_self_pivot_action(action):
		return false
	var target := _regidrago_llm_self_pivot_target_slot(action)
	if target == null or target == player.active_pokemon:
		return false
	if _regidrago_llm_is_regidrago_v_slot(target):
		return true
	if _regidrago_llm_is_regidrago_vstar_slot(target):
		return not _regidrago_llm_action_promotes_ready_primary(action, player)
	return false


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
	if not _regidrago_llm_is_basic_dragon_laser_action(action, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if game_state.turn_number < 4:
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if bool(action.get("projected_knockout", false)) and player.prizes.size() <= 1:
		return false
	if not _regidrago_llm_hand_has_vstar(player):
		return false
	if not _regidrago_llm_has_dragon_fuel_in_discard(player) and not _regidrago_llm_opponent_has_charizard_pressure(game_state, player_index):
		return false
	var active := player.active_pokemon
	if not _active_attack_cost_ready(active, _regidrago_llm_attack_cost(active, 1, "GGR")):
		return false
	return true


func _regidrago_llm_should_block_attack_before_backup_seed(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind not in ["attack", "granted_attack"]:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	if bool(action.get("projected_knockout", false)) and player.prizes.size() <= 1:
		return false
	if _regidrago_live_regidrago_count(player) >= 2:
		return false
	if _regidrago_open_bench_slots(player) <= 0:
		return false
	if not _regidrago_llm_hand_has_basic_regidrago(player):
		return false
	return _regidrago_llm_is_apex_dragon_action(action, game_state, player_index) \
		or _regidrago_llm_is_basic_dragon_laser_action(action, game_state, player_index)


func _regidrago_llm_should_block_apex_before_backup_vstar(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _regidrago_llm_is_apex_dragon_action(action, game_state, player_index):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if bool(action.get("projected_knockout", false)) and player.prizes.size() <= 2:
		return false
	if not _active_attack_cost_ready(player.active_pokemon, _regidrago_llm_attack_cost(player.active_pokemon, 0, "GGR")):
		return false
	if not _regidrago_llm_hand_has_vstar(player):
		return false
	if not _regidrago_llm_has_dragon_fuel_in_discard(player) and not _regidrago_llm_opponent_has_charizard_pressure(game_state, player_index):
		return false
	return _regidrago_llm_has_backup_basic_regidrago(player)


func _regidrago_llm_should_block_switching_active_primary(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if not _regidrago_llm_is_self_pivot_action(action):
		return false
	if _regidrago_llm_action_promotes_ready_primary(action, player):
		return false
	if _regidrago_llm_opponent_has_charizard_pressure(game_state, player_index) \
			and (_regidrago_llm_is_regidrago_v_slot(player.active_pokemon) or _regidrago_llm_is_regidrago_vstar_slot(player.active_pokemon)) \
			and player.active_pokemon.attached_energy.size() > 0:
		return true
	if _regidrago_llm_is_regidrago_vstar_slot(player.active_pokemon):
		return _regidrago_llm_has_dragon_fuel_in_discard(player)
	if _regidrago_llm_is_regidrago_v_slot(player.active_pokemon):
		var attack_cost := _regidrago_llm_attack_cost(player.active_pokemon, 1, "GGR")
		return _active_attack_cost_ready(player.active_pokemon, attack_cost)
	return false


func _regidrago_llm_should_block_support_pivot_to_liability(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	if not _regidrago_llm_is_self_pivot_action(action):
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null:
		return false
	if _regidrago_llm_action_promotes_ready_primary(action, player):
		return not _regidrago_llm_ready_primary_handoff_is_safe(action, player, game_state, player_index)
	var target := _regidrago_llm_self_pivot_target_slot(action)
	if target == null:
		return false
	if _regidrago_llm_is_two_prize_support_liability(target):
		if _regidrago_llm_opponent_has_charizard_pressure(game_state, player_index):
			return true
		if game_state.turn_number > 2 and _regidrago_llm_has_live_or_rebuildable_regidrago(player):
			return (_regidrago_llm_is_regidrago_v_slot(player.active_pokemon) \
				or _regidrago_llm_is_regidrago_vstar_slot(player.active_pokemon) \
				or _regidrago_llm_is_ogerpon_slot(player.active_pokemon)) \
				and player.active_pokemon.attached_energy.size() > 0
	if not _regidrago_llm_opponent_has_charizard_pressure(game_state, player_index):
		return false
	if _regidrago_llm_is_regidrago_v_slot(player.active_pokemon) or _regidrago_llm_is_regidrago_vstar_slot(player.active_pokemon):
		return false
	if _regidrago_llm_is_regidrago_v_slot(target) or _regidrago_llm_is_regidrago_vstar_slot(target):
		return true
	if _regidrago_llm_is_ogerpon_slot(player.active_pokemon) and player.active_pokemon.attached_energy.size() > 0:
		return true
	return false


func _regidrago_llm_ready_primary_handoff_is_safe(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> bool:
	var target := _regidrago_llm_self_pivot_target_slot(action)
	if target == null:
		return false
	if player != null and not player.prizes.is_empty() and player.prizes.size() <= 2:
		return true
	if not _regidrago_llm_is_regidrago_vstar_slot(target):
		return true
	if _regidrago_llm_slot_survives_charizard_return(target, game_state, player_index, 0):
		return true
	return _regidrago_llm_discard_has_goodra(player) and _regidrago_llm_slot_survives_charizard_return(target, game_state, player_index, 80)


func _regidrago_llm_slot_survives_charizard_return(
	slot: PokemonSlot,
	game_state: GameState,
	player_index: int,
	damage_reduction: int
) -> bool:
	if slot == null or slot.get_top_card() == null or slot.get_remaining_hp() <= 0:
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var prizes_taken := 0 if player.prizes.is_empty() else maxi(0, 6 - player.prizes.size())
	var expected_damage := maxi(0, 180 + prizes_taken * 30 - damage_reduction)
	return slot.get_remaining_hp() > expected_damage


func _regidrago_llm_discard_has_goodra(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.discard_pile:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _v17_name_contains(name, "Hisuian Goodra VSTAR") or _v17_name_contains(name, "娲楃繝") or _v17_name_contains(name, "榛忕編榫橵STAR"):
			return true
	return false


func _regidrago_llm_has_backup_basic_regidrago(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if slot != null and _regidrago_llm_is_regidrago_v_slot(slot):
			return true
	return false


func _regidrago_llm_action_promotes_ready_primary(action: Dictionary, player: PlayerState) -> bool:
	var target := _regidrago_llm_self_pivot_target_slot(action)
	if target == null or target == player.active_pokemon:
		return false
	if _regidrago_llm_is_regidrago_vstar_slot(target):
		return _regidrago_llm_has_dragon_fuel_in_discard(player) and _active_attack_cost_ready(target, _regidrago_llm_attack_cost(target, 0, "GGR"))
	if _regidrago_llm_is_regidrago_v_slot(target):
		return _active_attack_cost_ready(target, _regidrago_llm_attack_cost(target, 1, "GGR"))
	return false


func _regidrago_llm_self_pivot_target_slot(action: Dictionary) -> PokemonSlot:
	for key: String in ["target_slot", "bench_target", "switch_target", "own_bench_target", "self_pivot_target"]:
		var raw: Variant = action.get(key, null)
		if raw is PokemonSlot:
			return raw
	var targets: Variant = action.get("targets", [])
	if not (targets is Array):
		return null
	for raw_target: Variant in targets:
		if not (raw_target is Dictionary):
			continue
		var target_dict: Dictionary = raw_target
		for key: String in ["own_bench_target", "switch_target", "self_pivot_target", "target_slot", "bench_target"]:
			var raw_value: Variant = target_dict.get(key, null)
			if raw_value is PokemonSlot:
				return raw_value
			if raw_value is Array:
				for entry: Variant in raw_value:
					if entry is PokemonSlot:
						return entry
	return null


func _regidrago_llm_is_self_pivot_action(action: Dictionary) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind == "retreat":
		return true
	if kind != "play_trainer":
		return false
	var text := _regidrago_ref_text(action)
	if _v17_name_contains(text, "Energy Switch") or _v17_name_contains(text, "Switching Cups"):
		return false
	if _v17_name_contains(text, "Switch") or _v17_name_contains(text, "Pokemon Switch"):
		return true
	if _v17_name_contains(text, "Prime Catcher") or _v17_name_contains(text, "顶尖捕捉器"):
		return true
	return false


func _regidrago_llm_opponent_has_charizard_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	var slots: Array[PokemonSlot] = []
	if opponent.active_pokemon != null:
		slots.append(opponent.active_pokemon)
	for slot: PokemonSlot in opponent.bench:
		if slot != null:
			slots.append(slot)
	for slot: PokemonSlot in slots:
		if _regidrago_llm_slot_is_charizard_pressure(slot):
			return true
	return false


func _regidrago_llm_slot_is_charizard_pressure(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_top_card() == null or slot.get_remaining_hp() <= 0:
		return false
	var names: Array[String] = [_slot_name(slot)]
	var data := slot.get_card_data()
	if data != null:
		names.append(str(data.name))
		names.append(str(data.name_en))
	for raw_name: String in names:
		if _regidrago_llm_name_is_charizard_pressure(raw_name):
			return true
	return false


func _regidrago_llm_name_is_charizard_pressure(name: String) -> bool:
	var compact := name.to_lower().replace(" ", "")
	return compact.contains("charizard") \
		or compact.contains("charmander") \
		or compact.contains("charmeleon") \
		or name.contains("喷火龙") \
		or name.contains("小火龙") \
		or name.contains("火恐龙")


func _regidrago_llm_is_two_prize_support_liability(slot: PokemonSlot) -> bool:
	var name := _slot_name(slot)
	return _v17_name_contains(name, "Mew ex") \
			or _v17_name_contains(name, "Fezandipiti ex") \
			or _v17_name_contains(name, "Squawkabilly ex") \
			or _v17_name_contains(name, "梦幻ex") \
			or _v17_name_contains(name, "吉雉鸡ex") \
			or _v17_name_contains(name, "怒鹦哥ex")


func _regidrago_llm_is_ogerpon_slot(slot: PokemonSlot) -> bool:
	var name := _slot_name(slot)
	return _v17_name_contains(name, "Teal Mask Ogerpon ex") or _v17_name_contains(name, "厄诡椪")


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


func _regidrago_llm_is_apex_dragon_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind not in ["attack", "granted_attack"]:
		return false
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	var source := _regidrago_llm_action_source_slot(action, player)
	if source == null or not _regidrago_llm_is_regidrago_vstar_slot(source):
		return false
	var attack_name := _regidrago_llm_attack_name(action, source)
	if _v17_name_contains(attack_name, "Apex Dragon") or _v17_name_contains(attack_name, "巨龙无双"):
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


func _regidrago_llm_hand_has_basic_regidrago(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var name := _best_card_name(card.card_data)
		if _v17_name_contains(name, "VSTAR"):
			continue
		if _v17_name_contains(name, "Regidrago V") or _v17_name_contains(name, "雷吉铎拉戈V"):
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
