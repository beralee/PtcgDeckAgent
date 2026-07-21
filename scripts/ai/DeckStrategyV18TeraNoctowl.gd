class_name DeckStrategyV18TeraNoctowl
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const WATER_TURTLE_SCRIPT = preload("res://scripts/ai/DeckStrategy17WaterTurtle.gd")

const TORD_DECK_ID := 800015934
const FLAREON_DECK_ID := 800017643

const HOOTHOOT_ID := "CSV9C_154"
const HOOTHOOT_ALT_ID := "CSV9.5C_141"
const NOCTOWL_ID := "CSV9C_155"
const FAN_ROTOM_ID := "CSV9C_161"
const TERAPAGOS_ID := "CSV9C_175"
const TEAL_OGERPON_ID := "CSV8C_028"
const WELLSPRING_OGERPON_ID := "CSV8C_067"
const LATIAS_EX_ID := "CSV9C_078"
const FEZANDIPITI_EX_ID := "CSV8C_135"
const PIKACHU_EX_ID := "CSV9C_054"

const FAST_EEVEE_ID := "CSV9C_153"
const EEVEE_EX_ID := "CSV9.5C_140"
const EEVEE_ALT_ID := "151C_133"
const FLAREON_ID := "CSV9.5C_023"
const SYLVEON_ID := "CSV9C_090"
const LEAFEON_ID := "CSV9.5C_006"

const AREA_ZERO_ID := "CSV9C_207"
const CRISPIN_ID := "CSV9C_196"
const TERA_ORB_ID := "CSV9C_181"
const SPARKLING_CRYSTAL_ID := "CSV8C_186"
const NEST_BALL_ID := "CSVH1C_043"
const ULTRA_BALL_ID := "CSV1C_112"
const BUDDY_POFFIN_ID := "CSV7C_177"
const EARTHEN_VESSEL_ID := "CSV6C_115"
const ENERGY_SWITCH_ID := "CSVH1aC_008"
const SWITCH_ID := "CSV1C_113"
const KIERAN_ID := "CSV8C_198"
const NIGHT_STRETCHER_ID := "CSV8C_183"
const SUPER_ROD_ID := "CSV1C_109"
const BENCH_CLEANUP_STEP_PREFIX := "csv9c207_zero_area_discard_p"
const ENERGY_ASSIGNMENT_STEP := "energy_assignments"
const NOCTOWL_TRAINER_STEP := "csv9c_noctowl_trainers"
const CRISPIN_HAND_STEP := "csv9c196_energy_to_hand"
const CRISPIN_ATTACH_STEP := "csv9c196_energy_attachment"
const FLAREON_RWL_COST := "RWL"
const ATTACK_LOCK_ALL_TYPE := "attack_lock_all"
const LOCK_PIVOT_ACTION_SCORE := 4400.0
const CARNELIAN_KO_SCORE := 7200.0
const FULL_RWL_HANDOFF_BONUS := 3600.0

const TORD_PROFILE := {
	"strategy_id": "v18_tord_tera_noctowl_delegate",
	"signatures": [TERAPAGOS_ID, NOCTOWL_ID, AREA_ZERO_ID],
	"active_priority": [FAN_ROTOM_ID, TERAPAGOS_ID, HOOTHOOT_ID, TEAL_OGERPON_ID],
	"bench_priority": [TERAPAGOS_ID, HOOTHOOT_ID, FAN_ROTOM_ID, TEAL_OGERPON_ID, WELLSPRING_OGERPON_ID],
	"search_priority": [NOCTOWL_ID, TERAPAGOS_ID, HOOTHOOT_ID, AREA_ZERO_ID, NEST_BALL_ID, EARTHEN_VESSEL_ID],
	"evolution_priority": [NOCTOWL_ID],
	"energy_priority": [TERAPAGOS_ID, TEAL_OGERPON_ID, WELLSPRING_OGERPON_ID],
	"ability_priority": [NOCTOWL_ID, FAN_ROTOM_ID, TEAL_OGERPON_ID],
}

const FLAREON_PROFILE := {
	"strategy_id": "v18_flareon_tera_noctowl_delegate",
	"signatures": [FLAREON_ID, NOCTOWL_ID, FAST_EEVEE_ID],
	"active_priority": [FAST_EEVEE_ID, EEVEE_EX_ID, FAN_ROTOM_ID, HOOTHOOT_ID],
	"bench_priority": [FAST_EEVEE_ID, EEVEE_EX_ID, HOOTHOOT_ID, FAN_ROTOM_ID, EEVEE_ALT_ID],
	"search_priority": [NOCTOWL_ID, FLAREON_ID, FAST_EEVEE_ID, AREA_ZERO_ID, CRISPIN_ID, SYLVEON_ID, LEAFEON_ID],
	"evolution_priority": [NOCTOWL_ID, FLAREON_ID, SYLVEON_ID, LEAFEON_ID],
	"energy_priority": [FLAREON_ID, SYLVEON_ID, LEAFEON_ID, WELLSPRING_OGERPON_ID],
	"ability_priority": [NOCTOWL_ID, FAN_ROTOM_ID],
}

var _deck_id := TORD_DECK_ID
var _deck_strategy_text := ""
var _tord_delegate: RefCounted = WATER_TURTLE_SCRIPT.new()


func configure_from_deck(deck: DeckData) -> void:
	if deck != null:
		var configured_id := int(deck.id)
		_deck_id = configured_id if configured_id in [TORD_DECK_ID, FLAREON_DECK_ID] else TORD_DECK_ID


func set_deck_strategy_text(strategy_text: String) -> void:
	_deck_strategy_text = strategy_text.strip_edges()


func get_deck_strategy_text() -> String:
	return _deck_strategy_text


func _profile() -> Dictionary:
	return TORD_PROFILE if _is_tord_mode() else FLAREON_PROFILE


func get_strategy_id() -> String:
	return "v18_tera_noctowl_core"


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if _is_tord_mode():
		var delegated: Variant = _tord_delegate.call("plan_opening_setup", player)
		if delegated is Dictionary:
			return delegated
	return super.plan_opening_setup(player)


func build_turn_plan(game_state: GameState, player_index: int, _context: Dictionary = {}) -> Dictionary:
	var player := _player(game_state, player_index)
	var plan: Dictionary = {}
	if _is_tord_mode():
		var delegated: Variant = _tord_delegate.call("build_turn_plan", game_state, player_index, _context)
		if delegated is Dictionary:
			plan = (delegated as Dictionary).duplicate(true)
	if plan.is_empty():
		plan = super.build_turn_plan(game_state, player_index, _context)

	var owner := _best_route_owner(player, game_state)
	var jewel_live := _jewel_search_live(player, game_state)
	var bridge := NOCTOWL_ID if jewel_live else owner
	var area_live := _is_area_zero_active(game_state)
	var ready_attacker := _best_ready_attacker(player, game_state)
	var flareon_attack_debt := not _is_tord_mode() and _flareon_attack_debt(player, game_state)
	var flareon_lock_pivot_live := _flareon_lock_pivot_live(player, game_state)
	var intent := "evolve_noctowl_for_jewel_search" if jewel_live else "establish_tera_board"
	if not jewel_live and ready_attacker != null:
		intent = "convert_with_tera_attacker"
	elif flareon_attack_debt:
		intent = "fund_flareon_attack_route"

	plan["id"] = "v18_tera_noctowl_route"
	plan["intent"] = intent
	var plan_owner: Dictionary = plan.get("owner", {}) if plan.get("owner", {}) is Dictionary else {}
	plan_owner["turn_owner_name"] = owner
	plan_owner["bridge_target_name"] = bridge
	plan_owner["pivot_target_name"] = owner
	plan["owner"] = plan_owner
	plan["targets"] = {
		"primary_attacker_name": owner,
		"bridge_target_name": bridge,
		"pivot_target_name": owner,
	}
	plan["priorities"] = {
		"attach": _profile_list("energy_priority"),
		"handoff": _profile_list("energy_priority"),
		"search": _profile_list("search_priority"),
		"evolve": _profile_list("evolution_priority"),
		"ability": _profile_list("ability_priority"),
	}
	plan["flags"] = {
		"tera_in_play": _has_tera_on_field(player),
		"noctowl_jewel_search_live": jewel_live,
		"area_zero_live": area_live,
		"bench_limit": _bench_limit(game_state, player),
		"flareon_attack_debt": flareon_attack_debt,
		"flareon_attack_locked": _active_flareon_attack_locked(player, game_state),
		"flareon_lock_pivot_live": flareon_lock_pivot_live,
	}
	return plan


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _player(game_state, player_index)
	if player == null:
		return {}
	var jewel_live := _jewel_search_live(player, game_state)
	var area_debt := _has_tera_on_field(player) \
		and not _is_area_zero_active(game_state) \
		and player.bench.size() >= 4
	var action_bonuses := _tera_continuity_action_bonuses(
		game_state,
		player,
		jewel_live,
		area_debt
	)
	var safe_setup_live := jewel_live and _continuity_has_action_kind(action_bonuses, "evolve")
	return {
		"enabled": not action_bonuses.is_empty(),
		"safe_setup_before_attack": safe_setup_live,
		"setup_debt": {
			"need_tera_in_play": not _has_tera_on_field(player),
			"need_noctowl_evolution": jewel_live,
			"need_area_zero": area_debt,
			"bench_space": maxi(0, _bench_limit(game_state, player) - player.bench.size()),
		},
		"action_bonuses": action_bonuses,
		"attack_penalty": 1800.0 if safe_setup_live else 0.0,
	}


func _score_continuity_action_bonus(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary
) -> float:
	if str(action.get("kind", "")) in ["attack", "granted_attack"] \
			and bool(action.get("projected_knockout", false)):
		return 0.0
	return super._score_continuity_action_bonus(action, game_state, player_index, turn_contract)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := _delegated_or_base_action_score(action, game_state, player_index)
	var player := _player(game_state, player_index)
	if player == null:
		return score
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	var lock_pivot_live := _flareon_lock_pivot_live(player, game_state)

	match kind:
		"evolve":
			if _matches_key(card, NOCTOWL_ID):
				if not _has_tera_on_field(player):
					return minf(score, -2400.0)
				if _is_hoothoot(action.get("target_slot", null)):
					return maxf(score, 5200.0)
			if not _is_tord_mode() and _is_eeveelution(card):
				return maxf(score, _eeveelution_evolution_score(action, player))
		"play_stadium":
			if _stadium_replacement_collapses_own_bench(card, game_state, player):
				return minf(score, -5200.0)
			if _matches_key(card, AREA_ZERO_ID):
				if not _has_tera_on_field(player):
					return minf(score, -1500.0)
				if _is_area_zero_active(game_state):
					return minf(score, -1300.0)
				return maxf(score, 3900.0 if player.bench.size() >= 4 else 2300.0)
		"play_trainer":
			if _search_action_is_unproductive(card, action, game_state, player):
				return minf(score, -2600.0)
			if _matches_key(card, CRISPIN_ID):
				if _is_tord_mode():
					return maxf(score, 3800.0) if _route_attack_debt(player, game_state) else minf(score, -2800.0)
				if _flareon_crispin_route_live(player, game_state):
					return maxf(score, 3600.0)
				return minf(score, -3200.0)
			if lock_pivot_live and _matches_any(card, [SWITCH_ID, KIERAN_ID]):
				return maxf(score, LOCK_PIVOT_ACTION_SCORE)
		"play_basic_to_bench":
			if player.bench.size() >= _bench_limit(game_state, player):
				return minf(score, -3200.0)
			if not _has_tera_on_field(player) and _is_tera(card):
				return maxf(score, 3800.0)
			if _is_hoothoot(card) and _count_on_field(player, NOCTOWL_ID) >= 2:
				score -= 700.0
		"attach_energy":
			if _tord_active_pivot_attachment_unlocks_ready_tera(action, game_state, player_index, player):
				return maxf(score, LOCK_PIVOT_ACTION_SCORE)
			if _tord_blocked_pivot_prefers_direct_ready_tera_attachment(
				action,
				game_state,
				player_index,
				player
			):
				return maxf(score, 900.0)
			var tord_bank_score: Variant = _tord_prebank_energy_switch_score(action, player)
			if tord_bank_score != null:
				return maxf(score, float(tord_bank_score))
			if _is_tord_mode() and _is_tera(action.get("target_slot", null)) \
					and not _attachment_advances_any_attack(
						action.get("target_slot", null),
						action.get("card", null)
					):
				return minf(score, -1800.0)
			if not _is_tord_mode():
				score = _score_flareon_attachment(action, player, score)
		"attach_tool":
			if _matches_key(card, SPARKLING_CRYSTAL_ID):
				var target: PokemonSlot = action.get("target_slot", null)
				if target == null or not _is_tera(target):
					return minf(score, -2400.0)
				var before := _best_attack_gap(target)
				var after := maxi(0, before - 1)
				return maxf(score, 3200.0 + float(before - after) * 900.0)
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _is_tord_mode() and _matches_key(source, FAN_ROTOM_ID) \
					and int(_tord_fan_call_route_debt(player).get("total", 0)) <= 0 \
					and not (_jewel_search_live(player, game_state) and _tord_fan_call_has_legal_target(action)):
				return minf(score, -5000.0)
		"attack", "granted_attack":
			var source: PokemonSlot = action.get("source_slot", null)
			if not _is_tord_mode() and _is_flareon(source) \
					and int(action.get("attack_index", -1)) == 1 \
					and bool(action.get("projected_knockout", false)):
				return maxf(score, CARNELIAN_KO_SCORE)
			if _jewel_search_live(player, game_state) and not bool(action.get("projected_knockout", false)):
				score = minf(score, -1400.0)
			if lock_pivot_live and _matches_key(source, FAN_ROTOM_ID) \
					and int(action.get("projected_damage", 0)) <= 0 \
					and not bool(action.get("projected_knockout", false)):
				return minf(score, -1800.0)
			if not _is_tord_mode() and _is_flareon(source) \
					and int(action.get("attack_index", -1)) == 0 \
					and _basic_energy_in_deck(player) > 0:
				score += 1200.0
		"retreat":
			if _is_tord_mode():
				return score
			return _score_flareon_retreat(
					action,
					game_state,
					player_index,
					player,
					score,
					lock_pivot_live
				)
	return score


func evaluate_board(game_state: GameState, player_index: int) -> float:
	var score := super.evaluate_board(game_state, player_index)
	if _is_tord_mode():
		score = float(_tord_delegate.call("evaluate_board", game_state, player_index))
	var player := _player(game_state, player_index)
	if player == null:
		return score
	if _has_tera_on_field(player):
		score += 260.0
	if _is_area_zero_active(game_state):
		score += float(maxi(0, player.bench.size() - 5)) * 120.0
	return score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if _is_tord_mode():
		var delegated: Variant = _tord_delegate.call("predict_attacker_damage", slot, extra_context)
		if delegated is Dictionary:
			return delegated
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_cost_gap(slot, str(attack.get("cost", "")), null, extra_context) > 0:
			continue
		can_attack = true
		best_damage = maxi(best_damage, _parse_damage(str(attack.get("damage", "0"))))
	return {"damage": best_damage, "can_attack": can_attack, "description": "typed_tera_route"}


func get_search_priority(card: CardInstance) -> int:
	var score := super.get_search_priority(card)
	if _is_tord_mode():
		score = int(_tord_delegate.call("get_search_priority", card))
	if _matches_key(card, NOCTOWL_ID):
		return maxi(score, 1000)
	if _matches_key(card, AREA_ZERO_ID):
		return maxi(score, 920)
	if not _is_tord_mode() and _matches_any(card, [FLAREON_ID, FAST_EEVEE_ID, EEVEE_EX_ID]):
		return maxi(score, 960)
	if not _is_tord_mode() and _matches_key(card, CRISPIN_ID):
		return maxi(score, 880)
	return score


func get_discard_priority(card: CardInstance) -> int:
	var priority := super.get_discard_priority(card)
	if _is_tord_mode():
		priority = int(_tord_delegate.call("get_discard_priority", card))
	return _preserve_core_discard_priority(card, priority)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var priority := super.get_discard_priority_contextual(card, game_state, player_index)
	if _is_tord_mode():
		priority = int(_tord_delegate.call("get_discard_priority_contextual", card, game_state, player_index))
	priority = _preserve_core_discard_priority(card, priority)
	var player := _player(game_state, player_index)
	if player != null and _matches_key(card, NOCTOWL_ID) and _count_hoothoot_on_field(player) > 0:
		priority = mini(priority, 3)
	if player != null and not _is_tord_mode() and _is_basic_energy(card) and _flareon_attack_debt(player, game_state):
		priority = mini(priority, 5)
	return priority


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	if not _is_tord_mode() and step_id == "search_pokemon":
		var live_evolution := _pick_live_flareon_search_evolution(items, context)
		if live_evolution != null:
			return [live_evolution]
	if step_id == "basic_pokemon":
		var missing_hoothoot_pick := _pick_missing_hoothoot_basic(items, context)
		if missing_hoothoot_pick != null:
			return [missing_hoothoot_pick]
	if step_id == NOCTOWL_TRAINER_STEP or step_id.contains("noctowl"):
		return _pick_noctowl_trainers(items, step, context)
	if step_id.contains("fan_call"):
		var fan_call_pick: Variant = _pick_fan_call_targets(items, step, context)
		if fan_call_pick is Dictionary:
			var selected: Variant = (fan_call_pick as Dictionary).get("items", [])
			return selected as Array if selected is Array else []
		return fan_call_pick as Array if fan_call_pick is Array else []
	if not _is_tord_mode() and step_id in [CRISPIN_HAND_STEP, CRISPIN_ATTACH_STEP]:
		var crispin_pick := _pick_flareon_crispin_energy(items, step, context)
		if not crispin_pick.is_empty():
			return crispin_pick
	if not _is_tord_mode() and step_id == ENERGY_ASSIGNMENT_STEP:
		var picked := _pick_flareon_energy_sources(items, step, context)
		if not picked.is_empty():
			return picked
	if _is_tord_mode():
		var delegated: Variant = _tord_delegate.call("pick_interaction_items", items, step, context)
		if delegated is Array and not (delegated as Array).is_empty():
			return delegated
	return super.pick_interaction_items(items, step, context)


func _pick_live_flareon_search_evolution(items: Array, context: Dictionary) -> CardInstance:
	var player := _context_player(context)
	if player == null:
		return null
	var noctowl_live := _has_tera_on_field(player)
	if noctowl_live:
		noctowl_live = false
		for slot: PokemonSlot in _all_slots(player):
			if _is_hoothoot(slot):
				noctowl_live = true
				break
	if noctowl_live:
		return null
	var eevee_live := false
	for slot: PokemonSlot in _all_slots(player):
		if _is_eevee(slot):
			eevee_live = true
			break
	if not eevee_live:
		return null
	for item: Variant in items:
		if item is CardInstance and _is_flareon(item):
			return item as CardInstance
	for item: Variant in items:
		if item is CardInstance and _is_eeveelution(item):
			return item as CardInstance
	return null


func pick_interaction_items_envelope(items: Array, step: Dictionary, context: Dictionary = {}) -> Dictionary:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id == NOCTOWL_TRAINER_STEP or step_id.contains("noctowl"):
		return {"handled": true, "items": _pick_noctowl_trainers(items, step, context)}
	return {"handled": false, "items": []}


func _pick_missing_hoothoot_basic(items: Array, context: Dictionary) -> CardInstance:
	var player := _context_player(context)
	if player == null or _count_hoothoot_on_field(player) > 0 or _hand_has_hoothoot(player):
		return null
	if not _has_tera_on_field(player):
		return null
	var attacker_route_live := _count_tera_on_field(player) >= 2 if _is_tord_mode() else _count_on_field(player, FLAREON_ID) > 0
	if not attacker_route_live:
		return null
	for item: Variant in items:
		if item is CardInstance and _is_hoothoot(item):
			return item as CardInstance
	return null


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var game_state: GameState = context.get("game_state", null)
	var player := _context_player(context)
	var lock_pivot_live := _flareon_lock_pivot_live(player, game_state)
	if lock_pivot_live and step_id == "kieran_mode":
		return 3200.0 if str(item) == "switch_active" else -200.0
	if not _is_tord_mode() and item is PokemonSlot \
			and step_id in ["kieran_switch_target", "self_switch_target", "switch_target", "pivot_target"]:
		return score_handoff_target(item, step, context)
	if item is PokemonSlot and step_id.begins_with(BENCH_CLEANUP_STEP_PREFIX):
		return _bench_cleanup_discard_score(item as PokemonSlot)
	if item is CardInstance and (step_id == NOCTOWL_TRAINER_STEP or step_id.contains("noctowl")):
		return _noctowl_trainer_score(item as CardInstance, context)
	if not _is_tord_mode() and step_id in [CRISPIN_HAND_STEP, CRISPIN_ATTACH_STEP]:
		if item is CardInstance:
			return _flareon_crispin_energy_score(item as CardInstance, step_id, context)
		if item is PokemonSlot and step_id == CRISPIN_ATTACH_STEP:
			return _flareon_crispin_target_score(item as PokemonSlot, context)
	if not _is_tord_mode() and step_id == ENERGY_ASSIGNMENT_STEP:
		if item is CardInstance:
			return _flareon_energy_source_score(item as CardInstance, _best_assignment_target(context))
		if item is PokemonSlot:
			return _flareon_energy_target_score(item as PokemonSlot, context)
	if item is CardInstance and step_id.contains("fan_call"):
		return _fan_call_score(item as CardInstance, context)
	if _is_tord_mode() and item is CardInstance and step_id == "basic_pokemon" \
			and player != null and _deck_has_tera_candidate(player):
		var tera_count := _count_tera_on_field(player)
		if tera_count <= 0:
			return 7200.0 if _is_tera(item) else -1200.0
		if tera_count == 1:
			return 6500.0 if _is_tera(item) else -800.0
	if _is_tord_mode():
		return float(_tord_delegate.call("score_interaction_target", item, step, context))
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		var game_state: GameState = context.get("game_state", null)
		if _flareon_attack_locked(slot, game_state):
			return -1600.0
		if _best_attack_gap(slot) == 0 and _is_route_attacker(slot):
			var ready_score := 4400.0 + float(_best_printed_damage(slot))
			if not _is_tord_mode() and _is_flareon(slot) \
					and _attack_cost_gap(slot, FLAREON_RWL_COST) == 0:
				ready_score += FULL_RWL_HANDOFF_BONUS
			return ready_score
		if _is_route_attacker(slot):
			return 1200.0 - float(_best_attack_gap(slot)) * 260.0
	if _is_tord_mode():
		return float(_tord_delegate.call("score_handoff_target", item, step, context))
	return super.score_handoff_target(item, step, context)


func _delegated_or_base_action_score(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _is_tord_mode():
		return float(_tord_delegate.call("score_action_absolute", action, game_state, player_index))
	return super.score_action_absolute(action, game_state, player_index)


func _is_tord_mode() -> bool:
	return _deck_id == TORD_DECK_ID


func _player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	return game_state.players[player_index]


func _context_player(context: Dictionary) -> PlayerState:
	var game_state: GameState = context.get("game_state", null)
	return _player(game_state, int(context.get("player_index", -1)))


func _tera_continuity_action_bonuses(
	game_state: GameState,
	player: PlayerState,
	jewel_live: bool,
	area_debt: bool
) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	if player == null:
		return bonuses
	if jewel_live:
		var noctowl := _first_hand_card(player, NOCTOWL_ID)
		bonuses.append({
			"kind": "evolve",
			"card_names": [_primary_name(noctowl)],
			"bonus": 1800.0,
		})
	if area_debt and not game_state.stadium_played_this_turn:
		var area_zero := _first_hand_card(player, AREA_ZERO_ID)
		if area_zero != null:
			bonuses.append({
				"kind": "play_stadium",
				"card_names": [_primary_name(area_zero)],
				"bonus": 900.0,
			})
	if not _has_tera_on_field(player) and player.bench.size() < _bench_limit(game_state, player):
		var tera_basic := _first_hand_tera_basic(player)
		if tera_basic != null:
			bonuses.append({
				"kind": "play_basic_to_bench",
				"card_names": [_primary_name(tera_basic)],
				"bonus": 720.0,
			})
	if not game_state.energy_attached_this_turn \
			and (not _has_tera_on_field(player) or _route_attack_debt(player, game_state)):
		var attachment := _first_productive_continuity_attachment(player)
		if not attachment.is_empty():
			bonuses.append({
				"kind": "attach_energy",
				"card_names": [_primary_name(attachment.get("card", null))],
				"target_names": [_primary_name(attachment.get("target_slot", null))],
				"bonus": 420.0,
			})
	return bonuses


func _continuity_has_action_kind(bonuses: Array[Dictionary], kind: String) -> bool:
	for bonus: Dictionary in bonuses:
		if str(bonus.get("kind", "")) == kind:
			return true
	return false


func _first_hand_card(player: PlayerState, key: String) -> CardInstance:
	if player == null:
		return null
	for card: CardInstance in player.hand:
		if _matches_key(card, key):
			return card
	return null


func _first_hand_tera_basic(player: PlayerState) -> CardInstance:
	if player == null:
		return null
	for card: CardInstance in player.hand:
		if card != null and card.is_basic_pokemon() and _is_tera(card):
			return card
	return null


func _first_productive_continuity_attachment(player: PlayerState) -> Dictionary:
	if player == null:
		return {}
	for card: CardInstance in player.hand:
		if not _is_basic_energy(card):
			continue
		for slot: PokemonSlot in _all_slots(player):
			if not _is_route_attacker(slot):
				continue
			var before := _best_attack_gap(slot)
			if before > 0 and _best_attack_gap(slot, card) < before:
				return {"card": card, "target_slot": slot}
	return {}


func _best_route_owner(player: PlayerState, game_state: GameState = null) -> String:
	var ready := _best_ready_attacker(player, game_state)
	if ready != null:
		return _primary_name(ready)
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if _is_route_attacker(slot) and not _flareon_attack_locked(slot, game_state):
				return _primary_name(slot)
		if _active_flareon_attack_locked(player, game_state):
			for slot: PokemonSlot in player.bench:
				if slot != null and slot.get_card_data() != null and slot.get_remaining_hp() > 0:
					return _primary_name(slot)
			return ""
	return TERAPAGOS_ID if _is_tord_mode() else FLAREON_ID


func _best_ready_attacker(player: PlayerState, game_state: GameState = null) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_damage := -1
	if player == null:
		return null
	var live_flareon_lane := not _is_tord_mode() and _has_live_flareon_evolution_lane(player)
	for slot: PokemonSlot in _all_slots(player):
		if not _is_route_attacker(slot) or _flareon_attack_locked(slot, game_state) \
				or _best_attack_gap(slot) > 0:
			continue
		var damage := _best_printed_damage(slot) if _is_tord_mode() else _executable_damage(slot, game_state)
		if live_flareon_lane and damage < 100:
			continue
		if damage > best_damage:
			best = slot
			best_damage = damage
	return best


func _tord_active_pivot_attachment_unlocks_ready_tera(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState
) -> bool:
	if not _is_tord_mode() or player == null or player.active_pokemon == null:
		return false
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	var active := player.active_pokemon
	if not _is_basic_energy(energy) or target != active:
		return false
	if not (_is_hoothoot(active) \
			or _matches_any(active, [NOCTOWL_ID, FAN_ROTOM_ID, PIKACHU_EX_ID])):
		return false
	if _best_attack_gap(active) <= 0:
		return false
	if game_state == null or not RuleValidator.new().can_retreat(game_state, player_index):
		return false
	var retreat_cost := active.get_retreat_cost()
	var attached_units := _retreat_payment_units(active.attached_energy)
	var proposed_units := int(_energy_provision(energy).get("units", 0))
	if attached_units >= retreat_cost or attached_units + proposed_units < retreat_cost:
		return false
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and bench_slot.get_remaining_hp() > 0 \
				and _is_tera(bench_slot) and _best_attack_gap(bench_slot) == 0:
			return true
	return false


func _retreat_payment_units(energies: Array[CardInstance]) -> int:
	var units := 0
	for energy: CardInstance in energies:
		units += int(_energy_provision(energy).get("units", 0))
	return units


func _tord_blocked_pivot_prefers_direct_ready_tera_attachment(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState
) -> bool:
	if not _is_tord_mode() or game_state == null or player == null \
			or player.active_pokemon == null:
		return false
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if not _is_basic_energy(energy) or target == null or target not in player.bench \
			or not _is_tera(target) or _best_attack_gap(target) > 0 \
			or _attachment_advances_any_attack(target, energy):
		return false
	if not (_is_hoothoot(player.active_pokemon) \
			or _matches_any(player.active_pokemon, [NOCTOWL_ID, FAN_ROTOM_ID])):
		return false
	return not RuleValidator.new().can_retreat(game_state, player_index)


func _tord_prebank_energy_switch_score(action: Dictionary, player: PlayerState) -> Variant:
	if not _is_tord_mode() or player == null or _has_tera_on_field(player):
		return null
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if not _is_basic_energy(energy) or target == null or not _tord_has_energy_switch_access(player):
		return null
	if _matches_key(target, LATIAS_EX_ID):
		return 2900.0 if target.attached_energy.is_empty() else 900.0
	if _matches_key(target, FEZANDIPITI_EX_ID):
		return 2700.0 if target.attached_energy.is_empty() else 800.0
	return null


func _tord_has_energy_switch_access(player: PlayerState) -> bool:
	if player == null:
		return false
	for cards: Array[CardInstance] in [player.hand, player.deck]:
		for card: CardInstance in cards:
			if _matches_key(card, ENERGY_SWITCH_ID):
				return true
	return false


func _jewel_search_live(player: PlayerState, game_state: GameState) -> bool:
	if player == null or not _has_tera_on_field(player) or not _hand_has(player, NOCTOWL_ID):
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _is_hoothoot(slot) and (game_state == null or slot.turn_played < int(game_state.turn_number)):
			return true
	return false


func _has_tera_on_field(player: PlayerState) -> bool:
	return _count_tera_on_field(player) > 0


func _count_tera_on_field(player: PlayerState) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _is_tera(slot):
			count += 1
	return count


func _is_tera(item: Variant) -> bool:
	var data := _card_data_from_item(item)
	return data != null and data.is_tera_pokemon()


func _is_area_zero_active(game_state: GameState) -> bool:
	return game_state != null \
		and game_state.stadium_card != null \
		and _matches_key(game_state.stadium_card, AREA_ZERO_ID)


func _bench_limit(game_state: GameState, player: PlayerState) -> int:
	return 8 if _is_area_zero_active(game_state) and _has_tera_on_field(player) else 5


func _stadium_replacement_collapses_own_bench(card: Variant, game_state: GameState, player: PlayerState) -> bool:
	return player != null \
		and player.bench.size() > 5 \
		and _is_area_zero_active(game_state) \
		and not _matches_key(card, AREA_ZERO_ID)


func _search_action_is_unproductive(
	card: Variant,
	action: Dictionary,
	game_state: GameState,
	player: PlayerState
) -> bool:
	if not bool(action.get("productive", true)):
		return true
	if _matches_key(card, NEST_BALL_ID):
		return player.bench.size() >= _bench_limit(game_state, player) \
			or not _deck_has_basic_candidate(player, false)
	if _matches_key(card, BUDDY_POFFIN_ID):
		return player.bench.size() >= _bench_limit(game_state, player) \
			or not _deck_has_basic_candidate(player, true)
	if _matches_key(card, TERA_ORB_ID):
		return not _deck_has_tera_candidate(player)
	if _matches_key(card, ULTRA_BALL_ID):
		return not _deck_has_productive_pokemon(player)
	return false


func _deck_has_basic_candidate(player: PlayerState, poffin_only: bool) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null or not card.is_basic_pokemon():
			continue
		if poffin_only and int(card.card_data.hp) > 70:
			continue
		return true
	return false


func _deck_has_tera_candidate(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if _is_tera(card):
			return true
	return false


func _deck_has_productive_pokemon(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		if card == null or card.card_data == null or not card.card_data.is_pokemon():
			continue
		if card.is_basic_pokemon() or _has_evolution_target(player, card.card_data):
			return true
	return false


func _has_evolution_target(player: PlayerState, evolution: CardData) -> bool:
	if player == null or evolution == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if evolution.evolves_from_matches(slot.get_card_data()):
			return true
	return false


func _eeveelution_evolution_score(action: Dictionary, player: PlayerState) -> float:
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null or not _is_eevee(target):
		return -1800.0
	var score := 3300.0
	if target == player.active_pokemon and _matches_key(target, FAST_EEVEE_ID):
		score += 1700.0
	if _matches_key(action.get("card", null), FLAREON_ID):
		score += 500.0
	return score


func _score_flareon_attachment(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or target == null:
		return base_score
	if _matches_key(target, WELLSPRING_OGERPON_ID) \
			and _has_live_flareon_evolution_lane(player) \
			and _projected_executable_damage(target, energy) < 100:
		return minf(base_score, -900.0)
	if _is_eevee(target) and _has_flareon_route(player):
		var symbol := _energy_symbol(energy)
		if symbol not in ["R", "W", "L"]:
			return minf(base_score, -1400.0)
		return maxf(base_score, 3000.0 if symbol == "R" else 1900.0)
	if not _is_route_attacker(target):
		return minf(base_score, -1900.0)
	var before := _best_attack_gap(target)
	var after := _best_attack_gap(target, energy)
	if after >= before:
		return minf(base_score, -1300.0)
	var score := 2400.0 + float(before - after) * 1100.0
	if after == 0:
		score += 1900.0
	if _is_flareon(target) and _energy_symbol(energy) == "R":
		score += 450.0
	return maxf(base_score, score)


func _pick_flareon_crispin_energy(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	if max_select <= 0:
		return []
	var target := _best_flareon_crispin_target(context)
	if target == null:
		return []
	var step_id := str(step.get("id", "")).to_lower()
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if not item is CardInstance:
			continue
		ranked.append({
			"item": item,
			"score": _flareon_crispin_energy_score(item as CardInstance, step_id, context, target, items),
			"index": index,
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", -INF))
		var right_score := float(right.get("score", -INF))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	for entry: Dictionary in ranked:
		if picked.size() >= max_select or float(entry.get("score", -INF)) <= 0.0:
			break
		picked.append(entry.get("item"))
	return picked


func _flareon_crispin_energy_score(
	energy: CardInstance,
	step_id: String,
	context: Dictionary,
	target_override: PokemonSlot = null,
	all_items: Array = []
) -> float:
	if energy == null or not _is_basic_energy(energy):
		return -2400.0
	var symbol := _energy_symbol(energy)
	if symbol not in ["R", "W", "L"]:
		return -2200.0
	if step_id == CRISPIN_ATTACH_STEP and symbol == _flareon_crispin_hand_symbol(context):
		return -2200.0
	var target := target_override if target_override != null else _best_flareon_crispin_target(context)
	if target == null:
		return -2400.0
	var before := _attack_cost_gap(target, FLAREON_RWL_COST)
	var after := _attack_cost_gap(target, FLAREON_RWL_COST, energy)
	if before <= 0 or after >= before:
		return -1800.0
	var score := 3200.0 + float(before - after) * 1800.0
	if after == 0:
		score += 2400.0
	if step_id == CRISPIN_HAND_STEP:
		var candidates := all_items
		if candidates.is_empty() and context.get("all_items", []) is Array:
			candidates = context.get("all_items", [])
		if _has_distinct_flareon_crispin_partner(candidates, energy, target):
			score += 1800.0
		if symbol == "W" and _has_productive_flareon_crispin_symbol(candidates, "L", target):
			score += 240.0
	return score


func _has_distinct_flareon_crispin_partner(
	items: Array,
	selected: CardInstance,
	target: PokemonSlot
) -> bool:
	var selected_symbol := _energy_symbol(selected)
	var before := _attack_cost_gap(target, FLAREON_RWL_COST)
	for item: Variant in items:
		if not item is CardInstance or item == selected:
			continue
		var energy := item as CardInstance
		var symbol := _energy_symbol(energy)
		if symbol == selected_symbol or symbol not in ["R", "W", "L"]:
			continue
		if _attack_cost_gap(target, FLAREON_RWL_COST, energy) < before:
			return true
	return false


func _has_productive_flareon_crispin_symbol(
	items: Array,
	wanted_symbol: String,
	target: PokemonSlot
) -> bool:
	var before := _attack_cost_gap(target, FLAREON_RWL_COST)
	for item: Variant in items:
		if item is CardInstance and _energy_symbol(item as CardInstance) == wanted_symbol \
				and _attack_cost_gap(target, FLAREON_RWL_COST, item as CardInstance) < before:
			return true
	return false


func _flareon_crispin_hand_symbol(context: Dictionary) -> String:
	var selected: Variant = context.get(CRISPIN_HAND_STEP, [])
	if selected is Array:
		for item: Variant in selected:
			if item is CardInstance:
				return _energy_symbol(item as CardInstance)
	return ""


func _best_flareon_crispin_target(context: Dictionary) -> PokemonSlot:
	var player := _context_player(context)
	if player == null:
		return null
	var raw_targets: Variant = context.get("target_items", [])
	var candidates: Array[PokemonSlot] = []
	if raw_targets is Array:
		for item: Variant in raw_targets:
			if item is PokemonSlot:
				candidates.append(item as PokemonSlot)
	if candidates.is_empty():
		candidates = _all_slots(player)
	var state: GameState = context.get("game_state", null)
	var best: PokemonSlot = null
	var best_score := 0.0
	for slot: PokemonSlot in candidates:
		var score := _flareon_crispin_target_base_score(slot, player, state)
		if score > best_score:
			best = slot
			best_score = score
	return best


func _flareon_crispin_target_score(target: PokemonSlot, context: Dictionary) -> float:
	var player := _context_player(context)
	var state: GameState = context.get("game_state", null)
	var score := _flareon_crispin_target_base_score(target, player, state)
	if score <= 0.0:
		return score
	var source: Variant = context.get("assignment_source", context.get("source_card", null))
	if source is CardInstance:
		var before := _attack_cost_gap(target, FLAREON_RWL_COST)
		var after := _attack_cost_gap(target, FLAREON_RWL_COST, source as CardInstance)
		if _energy_symbol(source as CardInstance) not in ["R", "W", "L"] or after >= before:
			return -2200.0
		score += float(before - after) * 1800.0
		if after == 0:
			score += 2400.0
	return score


func _flareon_crispin_target_base_score(
	target: PokemonSlot,
	player: PlayerState,
	state: GameState
) -> float:
	if target == null or target.get_card_data() == null:
		return -2600.0
	var is_flareon_target := _is_flareon(target)
	var is_evolving_eevee := _is_live_flareon_evolution_target(target, player)
	if not is_flareon_target and not is_evolving_eevee:
		return -2600.0
	var gap := _attack_cost_gap(target, FLAREON_RWL_COST)
	if gap <= 0:
		return -1800.0
	var score := (5600.0 if is_flareon_target else 4300.0) - float(gap) * 260.0
	if _flareon_attack_locked(target, state):
		score -= 3600.0
	return score


func _is_live_flareon_evolution_target(target: PokemonSlot, player: PlayerState) -> bool:
	if target == null or player == null or not _is_eevee(target):
		return false
	var target_data := target.get_card_data()
	if target_data == null:
		return false
	for cards: Array[CardInstance] in [player.hand, player.deck]:
		for card: CardInstance in cards:
			if _is_flareon(card) and card.card_data != null \
					and card.card_data.evolves_from_matches(target_data):
				return true
	return false


func _has_live_flareon_evolution_lane(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _is_live_flareon_evolution_target(slot, player):
			return true
	return false


func _projected_executable_damage(slot: PokemonSlot, energy: CardInstance) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best_damage := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_cost_gap(slot, str(attack.get("cost", "")), energy) == 0:
			best_damage = maxi(best_damage, _parse_damage(str(attack.get("damage", "0"))))
	return best_damage


func _flareon_crispin_route_live(player: PlayerState, state: GameState) -> bool:
	if player == null or not _flareon_attack_debt(player, state):
		return false
	var target := _best_flareon_crispin_target({
		"game_state": state,
		"player_index": int(player.player_index),
	})
	if target == null:
		return false
	var before := _attack_cost_gap(target, FLAREON_RWL_COST)
	for card: CardInstance in player.deck:
		if _is_basic_energy(card) and _energy_symbol(card) in ["R", "W", "L"] \
				and _attack_cost_gap(target, FLAREON_RWL_COST, card) < before:
			return true
	return false


func _pick_flareon_energy_sources(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	if max_select <= 0:
		return []
	var target := _best_assignment_target(context)
	if target == null:
		return []
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if not item is CardInstance or not _is_basic_energy(item as CardInstance):
			continue
		ranked.append({
			"item": item,
			"score": _flareon_energy_source_score(item as CardInstance, target),
			"index": index,
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", -INF))
		var right_score := float(right.get("score", -INF))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	var used_symbols: Dictionary = {}
	for entry: Dictionary in ranked:
		if picked.size() >= max_select or float(entry.get("score", -INF)) <= 0.0:
			break
		var energy := entry.get("item") as CardInstance
		var symbol := _energy_symbol(energy)
		if symbol != "" and used_symbols.has(symbol):
			continue
		picked.append(energy)
		if symbol != "":
			used_symbols[symbol] = true
	return picked


func _best_assignment_target(context: Dictionary) -> PokemonSlot:
	var raw_targets: Variant = context.get("target_items", [])
	var candidates: Array[PokemonSlot] = []
	if raw_targets is Array:
		for item: Variant in raw_targets:
			if item is PokemonSlot:
				candidates.append(item as PokemonSlot)
	if candidates.is_empty():
		var player := _context_player(context)
		if player != null:
			candidates = _all_slots(player)
	var best: PokemonSlot = null
	var best_score := -INF
	for slot: PokemonSlot in candidates:
		if not _is_route_attacker(slot):
			continue
		var score := float(_best_printed_damage(slot)) - float(_best_attack_gap(slot)) * 180.0
		if _is_flareon(slot):
			score += 220.0
		if score > best_score:
			best = slot
			best_score = score
	return best


func _flareon_energy_source_score(energy: CardInstance, target: PokemonSlot) -> float:
	if energy == null or target == null or not _is_basic_energy(energy):
		return -1800.0
	if _is_flareon(target):
		var before_rwl := _attack_cost_gap(target, "RWL")
		var after_rwl := _attack_cost_gap(target, "RWL", energy)
		if after_rwl >= before_rwl:
			return -500.0
		var route_score := float(before_rwl - after_rwl) * 2200.0 + 280.0
		if after_rwl == 0:
			route_score += 4200.0
		elif after_rwl == 1:
			route_score += 900.0
		return route_score
	var best_score := -900.0
	for attack: Dictionary in target.get_card_data().attacks:
		var cost := str(attack.get("cost", ""))
		var before := _attack_cost_gap(target, cost)
		var after := _attack_cost_gap(target, cost, energy)
		var damage := _parse_damage(str(attack.get("damage", "0")))
		var score := float(before - after) * 1700.0 + float(damage)
		if before > 0 and after == 0:
			score += 3600.0
		elif after == 1 and before > after:
			score += 700.0
		best_score = maxf(best_score, score)
	return best_score


func _flareon_energy_target_score(target: PokemonSlot, context: Dictionary) -> float:
	if target == null or not _is_route_attacker(target):
		return -2200.0
	var source: Variant = context.get("assignment_source", context.get("source_card", null))
	if source is CardInstance:
		return _flareon_energy_source_score(source as CardInstance, target) + (900.0 if _is_flareon(target) else 0.0)
	return 1400.0 - float(_best_attack_gap(target)) * 120.0 + (900.0 if _is_flareon(target) else 0.0)


func _noctowl_trainer_score(card: CardInstance, context: Dictionary) -> float:
	if card == null or card.card_data == null:
		return -INF
	var player := _context_player(context)
	var state: GameState = context.get("game_state", null)
	if _matches_key(card, AREA_ZERO_ID):
		if state != null and _is_area_zero_active(state):
			return -1300.0
		if player != null and _hand_has(player, AREA_ZERO_ID):
			return -1100.0
		if player != null and not _has_tera_on_field(player):
			return -900.0
		return 3800.0 if player == null or player.bench.size() < 8 else 400.0
	if _matches_key(card, CRISPIN_ID):
		if player != null and _hand_has(player, CRISPIN_ID):
			return -1000.0
		if not _is_tord_mode():
			return 3500.0 if player == null or _flareon_crispin_route_live(player, state) else -1200.0
		return 2100.0
	if _matches_key(card, NEST_BALL_ID):
		if player != null and (player.bench.size() >= _bench_limit(state, player) or not _deck_has_basic_candidate(player, false)):
			return -1400.0
		return 3400.0 if _is_tord_mode() else 2100.0
	if _matches_key(card, BUDDY_POFFIN_ID):
		if player != null and (player.bench.size() >= _bench_limit(state, player) or not _deck_has_basic_candidate(player, true)):
			return -1400.0
		return 2700.0
	if _matches_key(card, EARTHEN_VESSEL_ID):
		return 2450.0 if _is_tord_mode() else 1900.0
	if _matches_key(card, ENERGY_SWITCH_ID):
		return 2250.0 if _is_tord_mode() else 500.0
	if _matches_key(card, TERA_ORB_ID):
		if player != null and not _deck_has_tera_candidate(player):
			return -1400.0
		return 2400.0 if not _is_tord_mode() else 1100.0
	if _matches_key(card, ULTRA_BALL_ID):
		if player != null and not _deck_has_productive_pokemon(player):
			return -1500.0
		return 1750.0
	if _matches_any(card, [NIGHT_STRETCHER_ID, SUPER_ROD_ID]):
		return 1700.0 if player != null and not player.discard_pile.is_empty() else -800.0
	if _matches_any(card, [SWITCH_ID, KIERAN_ID]):
		return 1200.0
	return float(get_search_priority(card))


func _pick_noctowl_trainers(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 2)))
	if max_select <= 0:
		return []
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if item is CardInstance:
			ranked.append({
				"item": item,
				"score": _noctowl_trainer_score(item as CardInstance, context),
				"role": _trainer_role(item),
				"index": index,
			})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", -INF))
		var right_score := float(right.get("score", -INF))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	var used_roles: Dictionary = {}
	for entry: Dictionary in ranked:
		if picked.size() >= max_select or float(entry.get("score", -INF)) <= 0.0:
			break
		var role := str(entry.get("role", ""))
		if role != "" and used_roles.has(role):
			continue
		picked.append(entry.get("item"))
		if role != "":
			used_roles[role] = true
	return picked


func _trainer_role(item: Variant) -> String:
	if _matches_key(item, AREA_ZERO_ID):
		return "stadium"
	if _matches_any(item, [NEST_BALL_ID, BUDDY_POFFIN_ID, ULTRA_BALL_ID, TERA_ORB_ID]):
		return "pokemon_access"
	if _matches_any(item, [CRISPIN_ID, EARTHEN_VESSEL_ID, ENERGY_SWITCH_ID]):
		return "energy_route"
	if _matches_any(item, [NIGHT_STRETCHER_ID, SUPER_ROD_ID]):
		return "recovery"
	return _primary_name(item).to_lower()


func _pick_fan_call_targets(items: Array, step: Dictionary, context: Dictionary) -> Variant:
	var max_select := maxi(0, int(step.get("max_select", 3)))
	if max_select <= 0:
		return {"handled": true, "items": []} if _is_tord_mode() else []
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if item is CardInstance:
			ranked.append({
				"item": item,
				"score": _fan_call_score(item as CardInstance, context),
				"identity": _fan_call_identity(item),
				"index": index,
			})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", -INF))
		var right_score := float(right.get("score", -INF))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	if _is_tord_mode():
		return _pick_tord_fan_call_targets(ranked, max_select, context)

	var player := _context_player(context)
	if _count_hoothoot_on_field(player) >= 2:
		for identity: String in ["noctowl", "noctowl", "eevee"]:
			_append_first_ranked_fan_call_identity(picked, ranked, identity, max_select)
	else:
		var route_identities := {"eevee": true, "hoothoot": true, "noctowl": true}
		var picked_route_identities: Dictionary = {}
		for entry: Dictionary in ranked:
			if picked.size() >= max_select or float(entry.get("score", -INF)) <= 0.0:
				break
			var identity := str(entry.get("identity", ""))
			if not route_identities.has(identity) or picked_route_identities.has(identity):
				continue
			picked.append(entry.get("item"))
			picked_route_identities[identity] = true

	var picked_identities: Dictionary = {}
	for item: Variant in picked:
		var identity := _fan_call_identity(item)
		if identity != "":
			picked_identities[identity] = true
	for entry: Dictionary in ranked:
		if picked.size() >= max_select:
			break
		if float(entry.get("score", -INF)) <= 0.0:
			continue
		var item: Variant = entry.get("item")
		if picked.has(item):
			continue
		var identity := str(entry.get("identity", ""))
		if identity != "" and picked_identities.has(identity):
			continue
		picked.append(item)
		if identity != "":
			picked_identities[identity] = true
	for entry: Dictionary in ranked:
		if picked.size() >= max_select:
			break
		if float(entry.get("score", -INF)) <= 0.0:
			continue
		var item: Variant = entry.get("item")
		if not picked.has(item):
			picked.append(item)
	return picked


func _pick_tord_fan_call_targets(
	ranked: Array[Dictionary],
	max_select: int,
	context: Dictionary
) -> Dictionary:
	var debt := _tord_fan_call_route_debt(_context_player(context))
	var remaining := {
		"hoothoot": int(debt.get("hoothoot", 0)),
		"noctowl": int(debt.get("noctowl", 0)),
	}
	var picked: Array = []
	for entry: Dictionary in ranked:
		if picked.size() >= max_select:
			break
		var identity := str(entry.get("identity", ""))
		if not remaining.has(identity) or int(remaining.get(identity, 0)) <= 0:
			continue
		var item: Variant = entry.get("item")
		if picked.has(item):
			continue
		picked.append(item)
		remaining[identity] = int(remaining.get(identity, 0)) - 1
	return {"handled": true, "items": picked}


func _tord_fan_call_route_debt(player: PlayerState) -> Dictionary:
	if not _is_tord_mode():
		return {"hoothoot": 0, "noctowl": 0, "total": 0}
	var hoothoot_count := 0
	var noctowl_count := 0
	if player != null:
		for card: CardInstance in player.hand:
			if _is_hoothoot(card):
				hoothoot_count += 1
			elif _matches_key(card, NOCTOWL_ID):
				noctowl_count += 1
		for slot: PokemonSlot in _all_slots(player):
			for card: CardInstance in slot.pokemon_stack:
				if _is_hoothoot(card):
					hoothoot_count += 1
				elif _matches_key(card, NOCTOWL_ID):
					noctowl_count += 1
	var hoothoot_debt := maxi(0, 2 - hoothoot_count)
	var noctowl_debt := maxi(0, 2 - noctowl_count)
	return {
		"hoothoot": hoothoot_debt,
		"noctowl": noctowl_debt,
		"total": hoothoot_debt + noctowl_debt,
	}


func _tord_fan_call_has_legal_target(action: Dictionary) -> bool:
	var raw_targets: Variant = action.get("targets", [])
	if not raw_targets is Array:
		return false
	for target: Variant in raw_targets:
		if not target is Dictionary:
			continue
		var fan_call_targets: Variant = (target as Dictionary).get("csv9c_fan_call_cards", [])
		if not fan_call_targets is Array:
			continue
		for item: Variant in fan_call_targets:
			if item is CardInstance:
				return true
	return false


func _append_first_ranked_fan_call_identity(
	picked: Array,
	ranked: Array[Dictionary],
	identity: String,
	max_select: int
) -> void:
	if picked.size() >= max_select:
		return
	for entry: Dictionary in ranked:
		if float(entry.get("score", -INF)) <= 0.0:
			return
		var item: Variant = entry.get("item")
		if not picked.has(item) and str(entry.get("identity", "")) == identity:
			picked.append(item)
			return


func _fan_call_identity(item: Variant) -> String:
	if _matches_any(item, [FAST_EEVEE_ID, EEVEE_EX_ID, EEVEE_ALT_ID]):
		return "eevee"
	if _matches_any(item, [HOOTHOOT_ID, HOOTHOOT_ALT_ID]):
		return "hoothoot"
	if _matches_key(item, NOCTOWL_ID):
		return "noctowl"
	var card_data := _card_data_from_item(item)
	if card_data == null:
		return ""
	var names: Array[String] = [str(card_data.name), str(card_data.name_en), str(card_data.name_zh)]
	for raw_name: String in names:
		var normalized := raw_name.strip_edges().to_lower().replace(" ", "")
		if normalized in ["eevee", "eeveeex", "伊布", "伊布ex"]:
			return "eevee"
		if normalized in ["hoothoot", "咕咕"]:
			return "hoothoot"
		if normalized in ["noctowl", "猫头夜鹰"]:
			return "noctowl"
	var uid := str(card_data.get_uid()).strip_edges().to_lower()
	if uid != "" and uid != "_":
		return "uid:%s" % uid
	for raw_name: String in names:
		var normalized := raw_name.strip_edges().to_lower()
		if normalized != "":
			return "name:%s" % normalized
	return ""


func _fan_call_score(card: CardInstance, context: Dictionary) -> float:
	var player := _context_player(context)
	if _is_hoothoot(card):
		return 3600.0 - float(_count_hoothoot_on_field(player)) * 500.0
	if _matches_key(card, NOCTOWL_ID):
		return 3300.0 if player == null or _count_hoothoot_on_field(player) > 0 else 2100.0
	if _matches_key(card, FAN_ROTOM_ID):
		return 900.0
	return float(get_search_priority(card))


func _bench_cleanup_discard_score(slot: PokemonSlot) -> float:
	if slot == null or slot.get_card_data() == null:
		return 5000.0
	var score := 400.0
	if _is_tera(slot) or _is_route_attacker(slot):
		score -= 3600.0
	if not slot.attached_energy.is_empty():
		score -= 900.0 * float(slot.attached_energy.size())
	if _matches_key(slot, FAN_ROTOM_ID):
		score += 2500.0
	elif _matches_key(slot, NOCTOWL_ID):
		score += 2100.0
	elif _is_hoothoot(slot):
		score += 1200.0
	return score


func _flareon_attack_debt(player: PlayerState, game_state: GameState = null) -> bool:
	if player == null:
		return true
	var found := false
	for slot: PokemonSlot in _all_slots(player):
		if not _is_flareon(slot):
			continue
		found = true
		if _flareon_attack_locked(slot, game_state):
			continue
		if _attack_cost_gap(slot, FLAREON_RWL_COST) == 0:
			return false
	return found or _has_flareon_route(player)


func _route_attack_debt(player: PlayerState, game_state: GameState = null) -> bool:
	if not _is_tord_mode():
		return _flareon_attack_debt(player, game_state)
	if player == null:
		return true
	var found := false
	for slot: PokemonSlot in _all_slots(player):
		if not _is_route_attacker(slot):
			continue
		found = true
		if not _flareon_attack_locked(slot, game_state) and _best_attack_gap(slot) == 0:
			return false
	return found or _has_flareon_route(player)


func _active_flareon_attack_locked(player: PlayerState, game_state: GameState) -> bool:
	return player != null and _flareon_attack_locked(player.active_pokemon, game_state)


func _flareon_lock_pivot_live(player: PlayerState, game_state: GameState) -> bool:
	if _is_tord_mode() or player == null or player.active_pokemon == null:
		return false
	if _active_flareon_attack_locked(player, game_state):
		for slot: PokemonSlot in player.bench:
			if slot != null and slot.get_card_data() != null and slot.get_remaining_hp() > 0 \
					and _is_route_attacker(slot) \
					and not _flareon_attack_locked(slot, game_state) \
					and _best_attack_gap(slot) == 0:
				return true
		return false
	if _executable_damage(player.active_pokemon, game_state) > 0:
		return false
	if _retreat_payment_units(player.active_pokemon.attached_energy) >= player.active_pokemon.get_retreat_cost():
		return false
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.get_card_data() == null or slot.get_remaining_hp() <= 0:
			continue
		if _is_route_attacker(slot) and not _flareon_attack_locked(slot, game_state) and _best_attack_gap(slot) == 0:
			return true
	return false


func _score_flareon_retreat(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	player: PlayerState,
	base_score: float,
	lock_pivot_live: bool
) -> float:
	var target: PokemonSlot = action.get("bench_target", null)
	if target == null or target not in player.bench or target.get_remaining_hp() <= 0:
		return minf(base_score, -3200.0)
	var active := player.active_pokemon
	if active == null:
		return minf(base_score, -3200.0)
	if _is_unlocked_full_rwl_flareon(active, game_state) \
			or _active_has_projected_knockout(player, game_state, player_index):
		return minf(base_score, -5200.0)
	var handoff_score := score_handoff_target(target, {"id": "retreat_target"}, {
		"game_state": game_state,
		"player_index": player_index,
	})
	if lock_pivot_live:
		return handoff_score
	var active_damage := _executable_damage(active, game_state)
	var target_damage := _executable_damage(target, game_state)
	if target_damage <= active_damage:
		return minf(base_score, -1800.0)
	return maxf(base_score, handoff_score)


func _is_unlocked_full_rwl_flareon(slot: PokemonSlot, game_state: GameState) -> bool:
	return _is_flareon(slot) \
		and not _flareon_attack_locked(slot, game_state) \
		and _attack_cost_gap(slot, FLAREON_RWL_COST) == 0


func _active_has_projected_knockout(
	player: PlayerState,
	game_state: GameState,
	player_index: int
) -> bool:
	if player == null or game_state == null or game_state.players.size() != 2:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var defender: PokemonSlot = game_state.players[opponent_index].active_pokemon
	var projected_damage := _executable_damage(player.active_pokemon, game_state)
	return defender != null and projected_damage > 0 \
		and projected_damage >= defender.get_remaining_hp()


func _executable_damage(slot: PokemonSlot, game_state: GameState) -> int:
	if slot == null or slot.get_card_data() == null or _flareon_attack_locked(slot, game_state):
		return 0
	var best_damage := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_cost_gap(slot, str(attack.get("cost", ""))) == 0:
			best_damage = maxi(best_damage, _parse_damage(str(attack.get("damage", "0"))))
	return best_damage


func _flareon_attack_locked(slot: PokemonSlot, game_state: GameState) -> bool:
	return not _is_tord_mode() and _is_flareon(slot) and _attack_lock_all_active(slot, game_state)


func _attack_lock_all_active(slot: PokemonSlot, game_state: GameState) -> bool:
	if slot == null or game_state == null:
		return false
	var top := slot.get_top_card()
	if top != null and int(top.owner_index) != int(game_state.current_player_index):
		return false
	for effect_data: Dictionary in slot.effects:
		if str(effect_data.get("type", "")) == ATTACK_LOCK_ALL_TYPE \
				and int(effect_data.get("turn", -999)) == int(game_state.turn_number) - 2:
			return true
	return false


func _has_flareon_route(player: PlayerState) -> bool:
	if player == null:
		return false
	if _hand_has(player, FLAREON_ID):
		return true
	for card: CardInstance in player.deck:
		if _matches_key(card, FLAREON_ID):
			return true
	return false


func _best_attack_gap(slot: PokemonSlot, extra_energy: CardInstance = null) -> int:
	if slot == null or slot.get_card_data() == null or slot.get_card_data().attacks.is_empty():
		return 99
	var best := 99
	for attack: Dictionary in slot.get_card_data().attacks:
		best = mini(best, _attack_cost_gap(slot, str(attack.get("cost", "")), extra_energy))
	return best


func _best_printed_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best := 0
	for attack: Dictionary in slot.get_card_data().attacks:
		best = maxi(best, _parse_damage(str(attack.get("damage", "0"))))
	return best


func _attachment_advances_any_attack(slot: PokemonSlot, energy: CardInstance) -> bool:
	if slot == null or slot.get_card_data() == null or not _is_basic_energy(energy):
		return false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost := str(attack.get("cost", ""))
		if _attack_cost_gap(slot, cost, energy) < _attack_cost_gap(slot, cost):
			return true
	return false


func _attack_cost_gap(
	slot: PokemonSlot,
	raw_cost: String,
	extra_energy: CardInstance = null,
	extra_colorless_units: int = 0
) -> int:
	var cost := CardData.normalize_attack_cost(raw_cost)
	var required: Dictionary = {}
	for symbol: String in cost:
		if symbol != "C":
			required[symbol] = int(required.get(symbol, 0)) + 1
	var provided: Dictionary = {}
	var any_units := 0
	var total_units := extra_colorless_units
	var energies: Array[CardInstance] = slot.attached_energy.duplicate() if slot != null else []
	if extra_energy != null:
		energies.append(extra_energy)
	for energy: CardInstance in energies:
		var provision := _energy_provision(energy)
		total_units += int(provision.get("units", 0))
		any_units += int(provision.get("any", 0))
		var typed: Dictionary = provision.get("typed", {})
		for symbol: Variant in typed:
			provided[symbol] = int(provided.get(symbol, 0)) + int(typed[symbol])
	var missing_specific := 0
	for symbol: Variant in required:
		missing_specific += maxi(0, int(required[symbol]) - int(provided.get(symbol, 0)))
	missing_specific = maxi(0, missing_specific - any_units)
	var gap := maxi(missing_specific, maxi(0, cost.length() - total_units))
	return maxi(0, gap - _sparkling_crystal_discount(slot))


func _energy_provision(energy: CardInstance) -> Dictionary:
	var result := {"units": 0, "any": 0, "typed": {}}
	if energy == null or energy.card_data == null:
		return result
	var provides := str(energy.card_data.energy_provides)
	if provides == "":
		provides = str(energy.card_data.energy_type)
	if provides == "ANY":
		return {"units": 1, "any": 1, "typed": {}}
	var typed: Dictionary = {}
	for symbol: String in provides:
		result["units"] = int(result["units"]) + 1
		if symbol != "C":
			typed[symbol] = int(typed.get(symbol, 0)) + 1
	if int(result["units"]) == 0 and energy.card_data.is_energy():
		result["units"] = 1
	result["typed"] = typed
	return result


func _sparkling_crystal_discount(slot: PokemonSlot) -> int:
	if slot == null or not _is_tera(slot) or slot.attached_tool == null:
		return 0
	return 1 if _matches_key(slot.attached_tool, SPARKLING_CRYSTAL_ID) else 0


func _energy_symbol(energy: CardInstance) -> String:
	if not _is_basic_energy(energy):
		return ""
	var provides := str(energy.card_data.energy_provides)
	return provides if provides != "" else str(energy.card_data.energy_type)


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and str(card.card_data.card_type) == "Basic Energy"


func _basic_energy_in_deck(player: PlayerState) -> int:
	var count := 0
	if player == null:
		return count
	for card: CardInstance in player.deck:
		if _is_basic_energy(card):
			count += 1
	return count


func _preserve_core_discard_priority(card: CardInstance, priority: int) -> int:
	if _matches_any(card, [NOCTOWL_ID, AREA_ZERO_ID]):
		return mini(priority, 6)
	if not _is_tord_mode() and _matches_any(card, [FLAREON_ID, FAST_EEVEE_ID, EEVEE_EX_ID, CRISPIN_ID]):
		return mini(priority, 5)
	return priority


func _count_on_field(player: PlayerState, key: String) -> int:
	var count := 0
	if player == null:
		return count
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, key):
			count += 1
	return count


func _count_hoothoot_on_field(player: PlayerState) -> int:
	return _count_on_field(player, HOOTHOOT_ID) + _count_on_field(player, HOOTHOOT_ALT_ID)


func _hand_has(player: PlayerState, key: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if _matches_key(card, key):
			return true
	return false


func _hand_has_hoothoot(player: PlayerState) -> bool:
	return _hand_has(player, HOOTHOOT_ID) or _hand_has(player, HOOTHOOT_ALT_ID)


func _is_hoothoot(item: Variant) -> bool:
	return _matches_any(item, [HOOTHOOT_ID, HOOTHOOT_ALT_ID])


func _is_eevee(item: Variant) -> bool:
	return _matches_any(item, [FAST_EEVEE_ID, EEVEE_EX_ID, EEVEE_ALT_ID])


func _is_flareon(item: Variant) -> bool:
	return _matches_key(item, FLAREON_ID)


func _is_eeveelution(item: Variant) -> bool:
	return _matches_any(item, [FLAREON_ID, SYLVEON_ID, LEAFEON_ID])


func _is_route_attacker(item: Variant) -> bool:
	if _is_tord_mode():
		return _is_tera(item)
	return _matches_any(item, [FLAREON_ID, SYLVEON_ID, LEAFEON_ID, WELLSPRING_OGERPON_ID])


func _matches_any(item: Variant, keys: Array) -> bool:
	for key: Variant in keys:
		if _matches_key(item, str(key)):
			return true
	return false
