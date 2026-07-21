class_name DeckStrategyV18Rules
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const ProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")

const PHASE_SETUP := "setup"
const PHASE_LAUNCH := "launch"
const PHASE_CONVERT := "convert"
const PHASE_REBUILD := "rebuild"
const PHASE_CLOSE := "close"
const FORBIDDEN_ACTION_SCORE := -100000.0

const LOW_DECK_CHURN_NAMES: Array[String] = [
	"Iono", "奇树", "Judge", "裁判", "Professor's Research", "博士的研究",
	"Bibarel", "大尾狸", "Skwovet", "贪心栗鼠", "Fezandipiti ex", "吉雉鸡ex",
	"Professor Sada's Vitality", "奥琳博士的气魄", "Gholdengo ex", "赛富豪ex",
	"Teal Mask Ogerpon ex", "厄诡椪 碧草面具ex", "Radiant Greninja", "光辉甲贺忍蛙",
	"Rotom V", "洛托姆V", "Squawkabilly ex", "怒鹦哥ex", "Mew ex", "梦幻ex",
]
const LOW_DECK_SEARCH_NAMES: Array[String] = [
	"Nest Ball", "巢穴球", "Ultra Ball", "高级球", "Buddy-Buddy Poffin", "友好宝芬",
	"Earthen Vessel", "大地容器", "Precious Trolley", "珍贵手推车", "Noctowl", "猫头夜鹰",
]
const RECOVERY_RESERVE_NAMES: Array[String] = [
	"Super Rod", "厉害钓竿", "Night Stretcher", "夜间担架",
]
const CRISPIN_HAND_STEP := "csv9c196_energy_to_hand"
const CRISPIN_ATTACH_STEP := "csv9c196_energy_attachment"
const NOCTOWL_TRAINER_STEP := "csv9c_noctowl_trainers"
const DELEGATE_FIRST_INTERACTION_STEPS: Array[String] = [
	CRISPIN_HAND_STEP,
	CRISPIN_ATTACH_STEP,
	NOCTOWL_TRAINER_STEP,
]

var _profile_data: Dictionary = {}
var _delegate: RefCounted = null
var _configured_deck: DeckData = null
var _deck_strategy_text := ""


func configure_profile(profile: Dictionary) -> void:
	_profile_data = profile.duplicate(true)
	_delegate = null
	var delegate_path := str(_profile_data.get("delegate_script_path", ""))
	if delegate_path != "":
		var delegate_script: Variant = load(delegate_path)
		if delegate_script is GDScript:
			_delegate = (delegate_script as GDScript).new()
	_apply_delegate_configuration()


func configure_from_deck(deck: DeckData) -> void:
	_configured_deck = deck
	if deck != null and _profile_data.is_empty():
		configure_profile(ProfileCatalogScript.get_profile_for_deck(int(deck.id)))
	_apply_delegate_configuration()


func set_deck_strategy_text(strategy_text: String) -> void:
	_deck_strategy_text = strategy_text.strip_edges()
	_apply_delegate_configuration()


func get_deck_strategy_text() -> String:
	return _deck_strategy_text


func _profile() -> Dictionary:
	return _profile_data


func get_mcts_config() -> Dictionary:
	var config := super.get_mcts_config()
	config["max_actions_per_turn"] = 10
	config["time_budget_ms"] = 140
	return config


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var profile_plan := super.plan_opening_setup(player)
	if _delegate == null or not _delegate.has_method("plan_opening_setup"):
		return _adjust_v18_opening(player, profile_plan)
	var delegate_plan: Variant = _delegate.call("plan_opening_setup", player)
	if not (delegate_plan is Dictionary):
		return _adjust_v18_opening(player, profile_plan)
	var normalized: Dictionary = (delegate_plan as Dictionary).duplicate(true)
	if int(normalized.get("active_hand_index", -1)) < 0:
		return _adjust_v18_opening(player, profile_plan)
	if not normalized.has("bench_hand_indices"):
		normalized["bench_hand_indices"] = profile_plan.get("bench_hand_indices", [])
	return _adjust_v18_opening(player, normalized)


func _adjust_v18_opening(player: PlayerState, plan: Dictionary) -> Dictionary:
	var adjusted := _adjust_gardevoir_single_seed_opening(player, plan)
	adjusted = _adjust_flareon_early_evolution_opening(player, adjusted)
	return _adjust_raging_bolt_ditto_opening(player, adjusted)


func _adjust_raging_bolt_ditto_opening(player: PlayerState, plan: Dictionary) -> Dictionary:
	if player == null or int(_profile_data.get("deck_id", 0)) != 800018509:
		return plan
	var current_active := int(plan.get("active_hand_index", -1))
	var ditto_index := -1
	for index: int in player.hand.size():
		if _matches_key(player.hand[index], "151C_132"):
			ditto_index = index
			break
	if ditto_index < 0 or current_active == ditto_index:
		return plan
	if current_active >= 0 and current_active < player.hand.size():
		var active_card: CardInstance = player.hand[current_active]
		if _matches_key(active_card, "CSV7C_154") \
				or _matches_key(active_card, "CSV8C_028") \
				or _matches_key(active_card, "CSV9C_161"):
			return _opening_without_bench_index(plan, ditto_index)
	var has_transform_target := false
	for deck_card: CardInstance in player.deck:
		if deck_card != null and deck_card.card_data != null \
				and deck_card.card_data.is_basic_pokemon() \
				and not _matches_key(deck_card, "151C_132"):
			has_transform_target = true
			break
	if not has_transform_target:
		return _opening_without_bench_index(plan, ditto_index)
	var result := plan.duplicate(true)
	var bench_indices: Array = result.get("bench_hand_indices", []).duplicate()
	bench_indices.erase(ditto_index)
	if current_active >= 0 and current_active < player.hand.size() and current_active not in bench_indices:
		bench_indices.push_front(current_active)
	result["active_hand_index"] = ditto_index
	result["bench_hand_indices"] = bench_indices
	return result


func _opening_without_bench_index(plan: Dictionary, hand_index: int) -> Dictionary:
	var result := plan.duplicate(true)
	var bench_indices: Array = result.get("bench_hand_indices", []).duplicate()
	bench_indices.erase(hand_index)
	result["bench_hand_indices"] = bench_indices
	return result


func _adjust_flareon_early_evolution_opening(player: PlayerState, plan: Dictionary) -> Dictionary:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("flareon_noctowl"):
		return plan
	var eevee_index := -1
	var has_evolution := false
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		if _matches_key(card, "CSV9C_153"):
			eevee_index = index
		if _matches_key(card, "CSV9.5C_023") \
				or _matches_key(card, "CSV9C_090") \
				or _matches_key(card, "CSV9.5C_006"):
			has_evolution = true
	if eevee_index < 0 or not has_evolution:
		return plan
	var current_active := int(plan.get("active_hand_index", -1))
	if current_active == eevee_index:
		return plan
	var result := plan.duplicate(true)
	var bench_indices: Array = result.get("bench_hand_indices", []).duplicate()
	bench_indices.erase(eevee_index)
	if current_active >= 0 and current_active < player.hand.size() and current_active not in bench_indices:
		bench_indices.push_front(current_active)
	result["active_hand_index"] = eevee_index
	result["bench_hand_indices"] = bench_indices
	return result


func _adjust_gardevoir_single_seed_opening(player: PlayerState, plan: Dictionary) -> Dictionary:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return plan
	var active_index: int = int(plan.get("active_hand_index", -1))
	if active_index < 0 or active_index >= player.hand.size() or not _matches_key(player.hand[active_index], "Ralts"):
		return plan
	var ralts_count := 0
	for card: CardInstance in player.hand:
		if _matches_key(card, "Ralts"):
			ralts_count += 1
	if ralts_count != 1:
		return plan
	var pivot_index := -1
	for pivot_name: String in ["Flutter Mane", "Klefki", "Munkidori", "Manaphy", "Radiant Greninja", "Scream Tail", "Drifloon"]:
		for index: int in player.hand.size():
			var card: CardInstance = player.hand[index]
			if index == active_index or not _matches_key(card, pivot_name):
				continue
			if card.card_data != null and card.card_data.is_basic_pokemon() and int(card.card_data.retreat_cost) <= 1:
				pivot_index = index
				break
		if pivot_index >= 0:
			break
	if pivot_index < 0:
		return plan
	var adjusted := plan.duplicate(true)
	var bench_indices: Array = adjusted.get("bench_hand_indices", []).duplicate()
	var original_bench_size := bench_indices.size()
	bench_indices.erase(pivot_index)
	if active_index not in bench_indices:
		bench_indices.push_front(active_index)
	while original_bench_size > 0 and bench_indices.size() > original_bench_size:
		bench_indices.pop_back()
	adjusted["active_hand_index"] = pivot_index
	adjusted["bench_hand_indices"] = bench_indices
	return adjusted


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var phase := _detect_phase(game_state, player)
	var primary_name := _best_profile_name_on_field(player, "energy_priority")
	if primary_name == "":
		primary_name = _first_profile_name("energy_priority")
	var bridge_name := _best_bridge_name(player, primary_name)
	var ready_attackers := _count_ready_attackers(player)
	var setup_debt := _setup_debt(player)
	var low_deck := player != null and player.deck.size() <= _deck_churn_floor()
	var contract := {
		"id": "%s:%s" % [get_strategy_id(), phase],
		"intent": _phase_intent(phase),
		"phase": phase,
		"flags": {
			"setup_debt": setup_debt,
			"ready_attackers": ready_attackers,
			"low_deck": low_deck,
		},
		"owner": {
			"turn_owner_name": primary_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": primary_name,
		},
		"targets": {
			"primary_attacker_name": primary_name,
			"bridge_target_name": bridge_name,
		},
		"priorities": {
			"attach": _profile_list("energy_priority"),
			"handoff": _profile_list("energy_priority"),
			"search": _profile_list("search_priority"),
			"evolve": _profile_list("evolution_priority"),
			"ability": _profile_list("ability_priority"),
			"trainer": _profile_list("trainer_priority"),
		},
		"constraints": {
			"forbid_engine_churn": low_deck and ready_attackers > 0,
			"forbid_extra_bench_padding": player != null and player.bench.size() >= 4 and setup_debt <= 0,
		},
		"context": context.duplicate(true),
	}
	return _merge_delegate_plan(contract, game_state, player_index, context)


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var setup_debt := _setup_debt(player)
	var phase := str(turn_contract.get("phase", _detect_phase(game_state, player)))
	var action_bonuses: Array[Dictionary] = [
		{"kind": "play_basic_to_bench", "bonus": 150.0 if setup_debt > 0 else 35.0},
		{"kind": "evolve", "bonus": 210.0 if phase in [PHASE_SETUP, PHASE_LAUNCH, PHASE_REBUILD] else 70.0},
		{"kind": "attach_energy", "target_names": _profile_list("energy_priority"), "bonus": 125.0},
		{"kind": "use_ability", "target_names": _profile_list("ability_priority"), "bonus": 90.0},
	]
	var shared := {
		"enabled": true,
		"safe_setup_before_attack": setup_debt > 0 and _count_ready_attackers(player) > 0,
		"setup_debt": {
			"missing_core_bodies": setup_debt,
			"phase": phase,
		},
		"action_bonuses": action_bonuses,
		"attack_penalty": 330.0,
	}
	return _merge_delegate_continuity(shared, game_state, player_index, turn_contract)


func _merge_delegate_continuity(
	shared: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary
) -> Dictionary:
	if _delegate == null or not _delegate.has_method("build_continuity_contract"):
		return shared
	var delegate_variant: Variant = _delegate.call("build_continuity_contract", game_state, player_index, turn_contract)
	if not delegate_variant is Dictionary:
		return shared
	var delegate: Dictionary = delegate_variant
	var merged := shared.duplicate(true)
	var shared_bonuses: Array = merged.get("action_bonuses", [])
	var delegate_bonuses: Variant = delegate.get("action_bonuses", [])
	if delegate_bonuses is Array:
		shared_bonuses.append_array((delegate_bonuses as Array).duplicate(true))
	merged["action_bonuses"] = shared_bonuses
	merged["enabled"] = bool(shared.get("enabled", false)) or bool(delegate.get("enabled", false))
	merged["safe_setup_before_attack"] = (
		bool(delegate.get("safe_setup_before_attack", false))
		if delegate.has("safe_setup_before_attack")
		else bool(shared.get("safe_setup_before_attack", false))
	)
	merged["attack_penalty"] = (
		maxf(
			float(shared.get("attack_penalty", 0.0)),
			float(delegate.get("attack_penalty", 0.0))
		)
		if bool(merged.get("safe_setup_before_attack", false))
		else 0.0
	)
	merged["setup_debt"] = {
		"shared": shared.get("setup_debt", {}),
		"delegate": delegate.get("setup_debt", {}),
	}
	for key: Variant in delegate:
		if key not in ["enabled", "safe_setup_before_attack", "setup_debt", "action_bonuses", "attack_penalty"]:
			merged[key] = delegate[key]
	return merged


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var profile_score := super.score_action_absolute(action, game_state, player_index)
	var delegate_score := _delegate_action_score(action, game_state, player_index)
	var score := profile_score if is_nan(delegate_score) else delegate_score + profile_score * 0.24
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	var phase := str(get_turn_plan_context().get("phase", _detect_phase(game_state, player)))
	var kind := str(action.get("kind", ""))
	var card: Variant = action.get("card", null)
	var is_knockout_attack := kind in ["attack", "granted_attack"] \
		and bool(action.get("projected_knockout", false))

	if kind in ["play_trainer", "play_stadium"]:
		score += _profile_score(card, "trainer_priority", 240.0, 18.0)
		if _tord_terapagos_damage_setup_live(game_state, player):
			if kind == "play_stadium" and _matches_key(card, "CSV9C_207"):
				score += 1400.0
			elif kind == "play_trainer" and _matches_key(card, "Nest Ball") and not player.is_bench_full():
				score += 1050.0
		if not bool(action.get("productive", true)):
			score -= 360.0
		if _discard_search_replaces_same_identity(action):
			score = minf(score, -1800.0)
		if _discard_action_breaks_visible_attack_core(action, player, game_state):
			score = minf(score, -1900.0)
		if _is_energy_switch_card(card):
			var transfer_gain := _best_energy_transfer_gain(player)
			if transfer_gain <= 0.0:
				score = minf(score, -1800.0)
			else:
				score += minf(900.0, transfer_gain * 0.50)
	if kind == "play_basic_to_bench":
		score += _profile_score(card, "bench_priority", 170.0, 12.0)
		if _tord_terapagos_damage_setup_live(game_state, player) and player.bench.size() < 6:
			score += 1050.0
		if player.bench.size() >= 4 and _setup_debt(player) <= 0:
			score -= 260.0
	elif kind == "evolve":
		score += _profile_score(card, "evolution_priority", 230.0, 16.0)
		if _tera_noctowl_first_search_live(player) and _matches_key(card, "CSV9C_155"):
			score += 1400.0
	elif kind == "attach_energy":
		score += _profile_score(action.get("target_slot", null), "energy_priority", 210.0, 16.0)
		score += _energy_route_score(action)
		score += _raging_bolt_core_attachment_score(action, player)
		if _missing_primary_basic_attacker(player) \
				and not _matches_profile(action.get("target_slot", null), "energy_priority"):
			score = minf(score, -1800.0)
		if _is_basic_energy_of_type(card, "G") \
				and _matches_key(action.get("target_slot", null), "CSV8C_028") \
				and _teal_dance_available(player, int(game_state.turn_number)):
			score -= 900.0
		if (_gardevoir_secret_box_pivot_route_live(player) or _gardevoir_candy_retreat_route_live(player)) \
				and _matches_key(card, "Psychic Energy"):
			if action.get("target_slot", null) == player.active_pokemon:
				score += 1800.0
			else:
				score -= 900.0
		if _gardevoir_gusted_engine_escape_live(player) and _matches_key(card, "Psychic Energy"):
			if action.get("target_slot", null) == player.active_pokemon:
				score += 2200.0
			else:
				score -= 1100.0
	elif kind == "attach_tool":
		if _gardevoir_candy_launch_route_live(player) and _matches_key(card, "Bravery Charm"):
			if action.get("target_slot", null) == player.active_pokemon:
				score += 1600.0
			else:
				score -= 800.0
	elif kind == "retreat":
		score += _low_deck_retreat_safety_score(action, player)
		if _gardevoir_candy_handoff_route_live(player):
			if _matches_key(action.get("bench_target", null), "Scream Tail"):
				score += 1600.0
			else:
				score -= 800.0
		elif _gardevoir_gusted_engine_escape_live(player) and _gardevoir_retreat_gap(player.active_pokemon) <= 0:
			if _matches_key(action.get("bench_target", null), "Scream Tail"):
				score = maxf(score, 2600.0)
			else:
				score = minf(score, -2000.0)
	elif kind == "use_ability":
		score += _profile_score(action.get("source_slot", null), "ability_priority", 180.0, 14.0)
		if _gardevoir_gusted_engine_escape_live(player) \
				and _matches_key(action.get("source_slot", null), "Gardevoir ex") \
				and _count_matching_cards(player.discard_pile, "Psychic Energy") > 0:
			var active_is_rebuilding := _matches_key(player.active_pokemon, "Scream Tail")
			var active_has_retreat_progress := _matches_key(player.active_pokemon, "Gardevoir ex") \
					and (not player.active_pokemon.attached_energy.is_empty() \
					or _count_matching_cards(player.hand, "Psychic Energy") == 0)
			if active_is_rebuilding or active_has_retreat_progress:
				score = maxf(score, 2600.0)
		if _matches_key(action.get("source_slot", null), "CSV8C_028") \
				and _teal_dance_available(player, int(game_state.turn_number), action.get("source_slot", null)):
			score += 900.0
	elif kind in ["attack", "granted_attack"]:
		score += _terminal_attack_bonus(action, game_state, player_index, phase)
		if _attack_has_draw_text(action) and _hand_advances_non_draw_attack(player, action):
			score = minf(score, -1600.0)
		if _tera_noctowl_first_search_live(player) and not bool(action.get("projected_knockout", false)):
			score -= 1100.0
		elif _tord_terapagos_damage_setup_live(game_state, player) \
				and player.bench.size() < 6 \
				and not bool(action.get("projected_knockout", false)):
			score -= 850.0
	elif kind == "end_turn":
		if _is_low_deck_turn(player):
			score -= 120.0
		else:
			score -= 900.0 if _has_productive_board_debt(player) else 120.0

	if player.deck.size() <= _deck_churn_floor() \
			and _is_churn_action(action) \
			and not is_knockout_attack:
		score -= _deck_churn_penalty(player)
	if player.deck.size() <= 8 and _count_ready_attackers(player) > 0 and _is_deck_search_action(action):
		score -= _deck_search_penalty(player.deck.size())
	var turn_flags: Dictionary = get_turn_plan_context().get("flags", {}) if get_turn_plan_context().get("flags", {}) is Dictionary else {}
	if bool(turn_flags.get("low_deck", false)) \
			and _count_ready_attackers(player) > 0 \
			and _is_churn_action(action) \
			and not is_knockout_attack:
		score = minf(score, -1800.0)
	return score
func _tera_noctowl_first_search_live(player: PlayerState) -> bool:
	if player == null:
		return false
	var strategy_id := str(_profile_data.get("strategy_id", ""))
	if not strategy_id.contains("tord_tera_box") \
			and not strategy_id.contains("flareon_noctowl"):
		return false
	var has_tera := false
	var has_noctowl_in_play := false
	var has_hoothoot_in_play := false
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		has_tera = has_tera or slot.get_card_data().is_tera_pokemon()
		has_noctowl_in_play = has_noctowl_in_play or _matches_key(slot, "CSV9C_155")
		has_hoothoot_in_play = has_hoothoot_in_play \
			or _matches_key(slot, "CSV9C_154") \
			or _matches_key(slot, "CSV9.5C_141")
	if not has_tera or has_noctowl_in_play or not has_hoothoot_in_play:
		return false
	for hand_card: CardInstance in player.hand:
		if _matches_key(hand_card, "CSV9C_155"):
			return true
	return false


func _tord_terapagos_damage_setup_live(game_state: GameState, player: PlayerState) -> bool:
	if game_state == null or player == null:
		return false
	if not str(_profile_data.get("strategy_id", "")).contains("tord_tera_box"):
		return false
	if player.active_pokemon == null or not _matches_key(player.active_pokemon, "CSV9C_175"):
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches_key(slot, "CSV9C_155"):
			return true
	return false


func _low_deck_retreat_safety_score(action: Dictionary, player: PlayerState) -> float:
	if player == null or not _is_low_deck_turn(player):
		return 0.0
	var target: PokemonSlot = action.get("bench_target", null)
	if target == null:
		return -700.0
	var active_ready := player.active_pokemon != null \
		and bool(predict_attacker_damage(player.active_pokemon).get("can_attack", false))
	var target_ready := bool(predict_attacker_damage(target).get("can_attack", false))
	if target_ready:
		return 900.0 if not active_ready else 160.0
	return -1600.0 if active_ready else -500.0


func _is_low_deck_turn(player: PlayerState) -> bool:
	if player == null:
		return false
	var flags_variant: Variant = get_turn_plan_context().get("flags", {})
	var turn_started_low := flags_variant is Dictionary and bool((flags_variant as Dictionary).get("low_deck", false))
	return turn_started_low or player.deck.size() <= _deck_churn_floor()


func _teal_dance_available(
	player: PlayerState,
	turn_number: int,
	source: PokemonSlot = null
) -> bool:
	if player == null:
		return false
	var has_grass := false
	for hand_card: CardInstance in player.hand:
		if hand_card != null \
				and hand_card.card_data != null \
				and hand_card.card_data.card_type == "Basic Energy" \
				and str(hand_card.card_data.energy_provides) == "G":
			has_grass = true
			break
	if not has_grass:
		return false
	var candidates: Array[PokemonSlot] = []
	if source != null:
		candidates.append(source)
	else:
		for field_slot: PokemonSlot in player.get_all_pokemon():
			candidates.append(field_slot)
	for slot: PokemonSlot in candidates:
		if slot == null or not _matches_key(slot, "CSV8C_028"):
			continue
		var used_this_turn := false
		for effect: Dictionary in slot.effects:
			if str(effect.get("type", "")) == "ability_attach_basic_energy_from_hand_draw_used" \
					and int(effect.get("turn", -1)) == turn_number:
				used_this_turn = true
				break
		if not used_this_turn:
			return true
	return false


func _is_basic_energy_of_type(item: Variant, energy_type: String) -> bool:
	var card_data := _card_data_from_item(item)
	return card_data != null \
		and str(card_data.card_type) == "Basic Energy" \
		and str(card_data.energy_provides) == energy_type


func score_action_absolute_with_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary = {}
) -> float:
	var score := super.score_action_absolute_with_plan(action, game_state, player_index, turn_plan)
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]
	if _turn_plan_forbids_action(action, turn_plan, player):
		return minf(score, FORBIDDEN_ACTION_SCORE)
	if player == null:
		return score
	if str(action.get("kind", "")) == "retreat" \
			and _gardevoir_gusted_engine_escape_live(player) \
			and _gardevoir_retreat_gap(player.active_pokemon) <= 0:
		if _matches_key(action.get("bench_target", null), "Scream Tail"):
			return maxf(score, 2600.0)
		return minf(score, -2000.0)
	return score


func _turn_plan_forbids_action(action: Dictionary, turn_plan: Dictionary, player: PlayerState) -> bool:
	var raw_forbidden: Variant = turn_plan.get("forbidden_action_kinds", [])
	if not raw_forbidden is Array:
		return false
	var action_kind := str(action.get("kind", "")).strip_edges().to_lower()
	for raw_token: Variant in raw_forbidden:
		var token := str(raw_token).strip_edges()
		if token == "":
			continue
		var separator := token.find(":")
		var forbidden_kind := (token if separator < 0 else token.substr(0, separator)).strip_edges().to_lower()
		if forbidden_kind != action_kind:
			continue
		if separator < 0:
			if action_kind == "play_basic_to_bench" and _turn_plan_marks_action_as_core(action, turn_plan, player):
				continue
			return true
		var forbidden_key := token.substr(separator + 1).strip_edges()
		if forbidden_key != "" and _matches_key(_forbidden_action_subject(action, action_kind), forbidden_key):
			return true
	return false


func _turn_plan_marks_action_as_core(
	action: Dictionary,
	turn_plan: Dictionary,
	player: PlayerState
) -> bool:
	if not str(turn_plan.get("intent", "")).to_lower().contains("rebuild"):
		return false
	var subject: Variant = _forbidden_action_subject(action, str(action.get("kind", "")).to_lower())
	var subject_data: CardData = _card_data_from_item(subject)
	if player != null and subject_data != null and _count_card_identity_on_field(player, subject_data) > 0:
		return false
	for section_name: String in ["owner", "targets", "priorities"]:
		if _turn_plan_value_matches_subject(turn_plan.get(section_name, null), subject):
			return true
	return false


func _turn_plan_value_matches_subject(value: Variant, subject: Variant) -> bool:
	if value is String:
		var key := str(value).strip_edges()
		return key != "" and _matches_key(subject, key)
	if value is Array:
		for child: Variant in value:
			if _turn_plan_value_matches_subject(child, subject):
				return true
		return false
	if value is Dictionary:
		for child: Variant in (value as Dictionary).values():
			if _turn_plan_value_matches_subject(child, subject):
				return true
	return false


func _forbidden_action_subject(action: Dictionary, action_kind: String) -> Variant:
	if action_kind in ["use_ability", "attack", "granted_attack"]:
		return action.get("source_slot", null)
	if action_kind == "retreat":
		return action.get("bench_target", null)
	return action.get("card", null)


func _gardevoir_secret_box_pivot_route_live(player: PlayerState) -> bool:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return false
	if player.active_pokemon == null or not _matches_key(player.active_pokemon, "Munkidori"):
		return false
	if not player.active_pokemon.attached_energy.is_empty():
		return false
	for hand_card: CardInstance in player.hand:
		if _matches_key(hand_card, "Secret Box"):
			return true
	return false


func _gardevoir_candy_retreat_route_live(player: PlayerState) -> bool:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return false
	if player.active_pokemon == null or not _matches_key(player.active_pokemon, "Munkidori"):
		return false
	if not player.active_pokemon.attached_energy.is_empty():
		return false
	return _gardevoir_candy_pair_in_hand(player)


func _gardevoir_candy_launch_route_live(player: PlayerState) -> bool:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return false
	if player.active_pokemon == null or not _matches_key(player.active_pokemon, "Scream Tail"):
		return false
	return _gardevoir_candy_pair_in_hand(player)


func _gardevoir_candy_handoff_route_live(player: PlayerState) -> bool:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return false
	if player.active_pokemon == null or not _matches_key(player.active_pokemon, "Munkidori"):
		return false
	if player.active_pokemon.attached_energy.is_empty():
		return false
	return _gardevoir_candy_pair_in_hand(player)


func _gardevoir_candy_pair_in_hand(player: PlayerState) -> bool:
	var has_gardevoir := false
	var has_rare_candy := false
	for hand_card: CardInstance in player.hand:
		has_gardevoir = has_gardevoir or _matches_key(hand_card, "Gardevoir ex")
		has_rare_candy = has_rare_candy or _matches_key(hand_card, "Rare Candy")
	return has_gardevoir and has_rare_candy


func _gardevoir_gusted_engine_escape_live(player: PlayerState) -> bool:
	if player == null or not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return false
	if player.active_pokemon == null:
		return false
	if _matches_key(player.active_pokemon, "Scream Tail"):
		var has_bench_gardevoir := false
		for bench_slot: PokemonSlot in player.bench:
			if _matches_key(bench_slot, "Gardevoir ex"):
				has_bench_gardevoir = true
				break
		var attack_cost := _minimum_printed_attack_cost(player.active_pokemon)
		if player.active_pokemon.get_card_data().attacks.size() > 1:
			var normalized_cost := CardData.normalize_attack_cost(str(
				player.active_pokemon.get_card_data().attacks[1].get("cost", "")
			))
			if normalized_cost != "":
				attack_cost = normalized_cost.length()
		var rebuild_gap := maxi(0, attack_cost - player.active_pokemon.attached_energy.size())
		return has_bench_gardevoir \
				and rebuild_gap > 0 \
				and rebuild_gap <= _count_matching_cards(player.discard_pile, "Psychic Energy")
	if not _matches_key(player.active_pokemon, "Gardevoir ex"):
		return false
	var scream_tail: PokemonSlot = null
	for bench_slot: PokemonSlot in player.bench:
		if _matches_key(bench_slot, "Scream Tail"):
			scream_tail = bench_slot
			break
	if scream_tail == null:
		return false
	var hand_psychic := _count_matching_cards(player.hand, "Psychic Energy")
	var discard_psychic := _count_matching_cards(player.discard_pile, "Psychic Energy")
	var active_psychic := _count_matching_cards(player.active_pokemon.attached_energy, "Psychic Energy")
	var available_psychic := hand_psychic + discard_psychic
	var active_gap := _gardevoir_retreat_gap(player.active_pokemon)
	var attack_cost := _minimum_printed_attack_cost(scream_tail)
	if scream_tail.get_card_data().attacks.size() > 1:
		var normalized_cost := CardData.normalize_attack_cost(str(
			scream_tail.get_card_data().attacks[1].get("cost", "")
		))
		if normalized_cost != "":
			attack_cost = normalized_cost.length()
	var attacker_gap := maxi(0, attack_cost - scream_tail.attached_energy.size())
	return active_gap <= available_psychic and attacker_gap <= available_psychic + active_psychic


func _gardevoir_retreat_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


func _minimum_printed_attack_cost(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	var minimum := 999
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
		if cost != "":
			minimum = mini(minimum, cost.length())
	return minimum


func _count_matching_cards(cards: Array, identity_name: String) -> int:
	var count := 0
	for card: Variant in cards:
		if _matches_key(card, identity_name):
			count += 1
	return count


func evaluate_board(game_state: GameState, player_index: int) -> float:
	var profile_score := super.evaluate_board(game_state, player_index)
	if _delegate != null and _delegate.has_method("evaluate_board"):
		return float(_delegate.call("evaluate_board", game_state, player_index)) + profile_score * 0.20
	return profile_score


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if _delegate != null and _delegate.has_method("predict_attacker_damage"):
		var prediction: Variant = _delegate.call("predict_attacker_damage", slot, extra_context)
		if prediction is Dictionary:
			return prediction
	return _predict_typed_attacker_damage(slot, extra_context)


func get_discard_priority(card: CardInstance) -> int:
	var profile_priority := super.get_discard_priority(card)
	if _delegate != null and _delegate.has_method("get_discard_priority"):
		return int(_delegate.call("get_discard_priority", card))
	return profile_priority


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	var profile_priority := super.get_discard_priority_contextual(card, game_state, player_index)
	if _delegate != null and _delegate.has_method("get_discard_priority_contextual"):
		return int(_delegate.call("get_discard_priority_contextual", card, game_state, player_index))
	return profile_priority


func get_search_priority(card: CardInstance) -> int:
	var profile_priority := super.get_search_priority(card)
	if _delegate != null and _delegate.has_method("get_search_priority"):
		return maxi(profile_priority, int(_delegate.call("get_search_priority", card)))
	return profile_priority


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id in DELEGATE_FIRST_INTERACTION_STEPS:
		var priority_delegate_pick := _delegate_interaction_pick(items, step, context)
		if bool(priority_delegate_pick.get("handled", false)):
			var priority_items: Array = priority_delegate_pick.get("items", [])
			return priority_items
	if step_id in [CRISPIN_HAND_STEP, CRISPIN_ATTACH_STEP]:
		return _pick_crispin_energy(items, step, context)
	if step_id == NOCTOWL_TRAINER_STEP:
		return _pick_distinct_ranked_cards(items, step, context)
	if step_id == "embrace_target":
		var state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		if state != null and player_index >= 0 and player_index < state.players.size():
			var player: PlayerState = state.players[player_index]
			if _gardevoir_gusted_engine_escape_live(player) \
					and _gardevoir_retreat_gap(player.active_pokemon) > 0 \
					and player.active_pokemon in items:
				return [player.active_pokemon]
	if _gardevoir_secret_box_interaction_live(context):
		var wanted_name := ""
		match step_id:
			"search_item": wanted_name = "Rare Candy"
			"search_tool": wanted_name = "Bravery Charm"
			"search_supporter": wanted_name = "Boss's Orders"
			"search_stadium": wanted_name = "Artazon"
		for item: Variant in items:
			if wanted_name != "" and _matches_key(item, wanted_name):
				return [item]
	if step_id == "embrace_target" and _delegate != null and _delegate.has_method("pick_embrace_target"):
		var target: Variant = _delegate.call(
			"pick_embrace_target",
			items,
			context.get("game_state", null),
			int(context.get("player_index", -1))
		)
		if target != null and target in items:
			return [target]
	var fallback_delegate_pick := _delegate_interaction_pick(items, step, context)
	if bool(fallback_delegate_pick.get("handled", false)):
		var fallback_items: Array = fallback_delegate_pick.get("items", [])
		return fallback_items
	return super.pick_interaction_items(items, step, context)


# Legacy delegates handle with a non-empty Array; the envelope permits an explicit empty selection.
func _delegate_interaction_pick(items: Array, step: Dictionary, context: Dictionary) -> Dictionary:
	if _delegate == null:
		return {"handled": false, "items": []}
	var response: Variant = null
	if _delegate.has_method("pick_interaction_items_envelope"):
		response = _delegate.call("pick_interaction_items_envelope", items, step, context)
		if response is Dictionary and bool((response as Dictionary).get("handled", false)):
			var explicit_items: Variant = (response as Dictionary).get("items", [])
			if explicit_items is Array:
				return {"handled": true, "items": explicit_items}
	if not _delegate.has_method("pick_interaction_items"):
		return {"handled": false, "items": []}
	response = _delegate.call("pick_interaction_items", items, step, context)
	if response is Array:
		var legacy_items := response as Array
		return {
			"handled": not legacy_items.is_empty(),
			"items": legacy_items,
		}
	if response is Dictionary:
		var envelope := response as Dictionary
		var envelope_items: Variant = envelope.get("items", [])
		if bool(envelope.get("handled", false)) and envelope_items is Array:
			return {"handled": true, "items": envelope_items}
	return {"handled": false, "items": []}


func _gardevoir_secret_box_interaction_live(context: Dictionary) -> bool:
	if not str(_profile_data.get("strategy_id", "")).contains("gardevoir"):
		return false
	for key: String in ["pending_effect_card", "effect_card", "source_card", "pending_card"]:
		if _matches_key(context.get(key, null), "Secret Box"):
			return true
	return false


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id == CRISPIN_ATTACH_STEP:
		var crispin_score: Variant = _crispin_attachment_interaction_score(item, context)
		if crispin_score != null:
			return float(crispin_score)
	var recovery_reserve_score: Variant = _recovery_reserve_discard_score(item, step, context)
	if recovery_reserve_score != null:
		return float(recovery_reserve_score)
	var transfer_score: Variant = _energy_transfer_interaction_score(item, step, context)
	if transfer_score != null:
		return float(transfer_score)
	var profile_score := super.score_interaction_target(item, step, context)
	var route_score := _evolution_search_route_score(item, step, context)
	var recovery_route_score := _continuity_recovery_route_score(item, step, context)
	var trainer_route_score := 0.0
	if item is CardInstance and str(step.get("id", "")).to_lower() == "csv9c_noctowl_trainers":
		trainer_route_score = _profile_score(item, "trainer_priority", 900.0, 60.0)
	if _delegate != null and _delegate.has_method("score_interaction_target"):
		var delegate_score := float(_delegate.call("score_interaction_target", item, step, context))
		if item is CardInstance and step_id == NOCTOWL_TRAINER_STEP and delegate_score < 0.0:
			return delegate_score
		if _delegate_prefers_non_energy_recovery(item, step, context, delegate_score):
			recovery_route_score = 0.0
		return delegate_score + profile_score * 0.30 + route_score + recovery_route_score + trainer_route_score
	return profile_score + route_score + recovery_route_score + trainer_route_score


func _delegate_prefers_non_energy_recovery(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	item_delegate_score: float
) -> bool:
	if not item is CardInstance or _delegate == null:
		return false
	var item_card := item as CardInstance
	if item_card.card_data == null or not item_card.card_data.is_energy():
		return false
	var step_id := str(step.get("id", "")).to_lower()
	if not step_id.contains("recover") and not step_id.contains("stretcher") and not step_id.contains("rod"):
		return false
	var all_items: Array = context.get("all_items", []) if context.get("all_items", []) is Array else []
	if all_items.is_empty():
		var game_state: GameState = context.get("game_state", null)
		var player_index := int(context.get("player_index", -1))
		if game_state != null and player_index >= 0 and player_index < game_state.players.size():
			for discard_card: CardInstance in game_state.players[player_index].discard_pile:
				all_items.append(discard_card)
	for candidate_raw: Variant in all_items:
		if not candidate_raw is CardInstance:
			continue
		var candidate := candidate_raw as CardInstance
		if candidate == item_card or candidate.card_data == null or candidate.card_data.is_energy():
			continue
		var candidate_score := float(_delegate.call("score_interaction_target", candidate, step, context))
		if candidate_score >= 500.0 and candidate_score > item_delegate_score:
			return true
	return false


func _pick_crispin_energy(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	if max_select <= 0:
		return []
	var step_id := str(step.get("id", "")).to_lower()
	var player := _context_player(context)
	if player == null:
		return []
	var state: GameState = context.get("game_state", null)
	var ranked: Array[Dictionary] = []
	for index: int in items.size():
		var item: Variant = items[index]
		if not item is CardInstance or not _is_basic_energy_card(item as CardInstance):
			continue
		var score := _crispin_hand_energy_score(item as CardInstance, items, player, state) \
			if step_id == CRISPIN_HAND_STEP \
			else _crispin_attachment_energy_score(item as CardInstance, player)
		ranked.append({"item": item, "score": score, "index": index})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", -INF))
		var right_score := float(right.get("score", -INF))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	for entry: Dictionary in ranked:
		if float(entry.get("score", -INF)) <= 0.0:
			continue
		picked.append(entry.get("item"))
		if picked.size() >= max_select:
			break
	return picked


func _crispin_hand_energy_score(
	hand_energy: CardInstance,
	all_items: Array,
	player: PlayerState,
	state: GameState
) -> float:
	var hand_symbol := _basic_energy_symbol(hand_energy)
	if hand_symbol == "":
		return -INF
	var manual_attach_live := state == null or not state.energy_attached_this_turn
	var best_pair_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_profile(slot, "energy_priority") or slot.get_card_data() == null:
			continue
		for attack: Dictionary in slot.get_card_data().attacks:
			if _attack_dict_has_draw_text(attack):
				continue
			var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
			var before := _attack_cost_gap(slot, cost)
			for raw_attach: Variant in all_items:
				if not raw_attach is CardInstance:
					continue
				var attach_energy := raw_attach as CardInstance
				if not _is_basic_energy_card(attach_energy) \
						or _basic_energy_symbol(attach_energy) == hand_symbol:
					continue
				var pair_extras: Array = [hand_energy] if manual_attach_live else []
				var after := _attack_cost_gap(slot, cost, attach_energy, 0, null, pair_extras)
				var pair_score := float(before - after) * 1000.0
				if before > 0 and after == 0:
					pair_score += 4200.0
				elif after == 1:
					pair_score += 600.0
				pair_score += _profile_score(slot, "energy_priority", 420.0, 35.0)
				best_pair_score = maxf(best_pair_score, pair_score)
	var hand_utility := _crispin_attachment_energy_score(hand_energy, player) * 0.18
	if hand_symbol == "G":
		for slot: PokemonSlot in _all_slots(player):
			if _matches_key(slot, "CSV8C_028"):
				hand_utility += 900.0
				break
	return maxf(40.0, best_pair_score + hand_utility)


func _crispin_attachment_energy_score(energy: CardInstance, player: PlayerState) -> float:
	if not _is_basic_energy_card(energy) or player == null:
		return -INF
	var best_score := -INF
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_profile(slot, "energy_priority") or slot.get_card_data() == null:
			continue
		for attack: Dictionary in slot.get_card_data().attacks:
			if _attack_dict_has_draw_text(attack):
				continue
			var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
			var before := _attack_cost_gap(slot, cost)
			var after := _attack_cost_gap(slot, cost, energy)
			var score := float(before - after) * 1000.0
			if before > 0 and after == 0:
				score += 4200.0
			elif after == 1 and before > after:
				score += 600.0
			score += _profile_score(slot, "energy_priority", 420.0, 35.0)
			best_score = maxf(best_score, score)
	return maxf(20.0, best_score)


func _crispin_attachment_interaction_score(item: Variant, context: Dictionary) -> Variant:
	var player := _context_player(context)
	if player == null:
		return null
	if item is CardInstance:
		return _crispin_attachment_energy_score(item as CardInstance, player)
	if not item is PokemonSlot:
		return null
	var source: Variant = context.get("assignment_source", context.get("source_card", null))
	if not source is CardInstance or not _is_basic_energy_card(source as CardInstance):
		return null
	var slot := item as PokemonSlot
	if not _matches_profile(slot, "energy_priority") or slot.get_card_data() == null:
		return -1800.0
	var best_score := -500.0
	for attack: Dictionary in slot.get_card_data().attacks:
		if _attack_dict_has_draw_text(attack):
			continue
		var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
		var before := _attack_cost_gap(slot, cost)
		var after := _attack_cost_gap(slot, cost, source as CardInstance)
		var score := float(before - after) * 1100.0
		if before > 0 and after == 0:
			score += 4400.0
		elif after == 1 and before > after:
			score += 700.0
		score += _profile_score(slot, "energy_priority", 420.0, 35.0)
		best_score = maxf(best_score, score)
	return best_score


func _context_player(context: Dictionary) -> PlayerState:
	var state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if state == null or player_index < 0 or player_index >= state.players.size():
		return null
	return state.players[player_index]


func _is_basic_energy_card(card: CardInstance) -> bool:
	return card != null and card.card_data != null and str(card.card_data.card_type) == "Basic Energy"


func _basic_energy_symbol(card: CardInstance) -> String:
	if not _is_basic_energy_card(card):
		return ""
	var provides := str(card.card_data.energy_provides)
	return provides if provides != "" else str(card.card_data.energy_type)


func _recovery_reserve_discard_score(item: Variant, step: Dictionary, context: Dictionary) -> Variant:
	if not item is CardInstance or not str(step.get("id", "")).to_lower().contains("discard"):
		return null
	var is_recovery_reserve := false
	for recovery_name: String in RECOVERY_RESERVE_NAMES:
		if _matches_key(item, recovery_name):
			is_recovery_reserve = true
			break
	if not is_recovery_reserve:
		return null
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	var primary_name := _first_profile_name("energy_priority")
	if primary_name == "":
		return null
	var live_primary_count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, primary_name):
			live_primary_count += 1
	for hand_card: CardInstance in player.hand:
		if _matches_key(hand_card, primary_name):
			live_primary_count += 1
	return -2500.0 if live_primary_count <= 1 else null


func _continuity_recovery_route_score(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if not item is CardInstance:
		return 0.0
	var step_id := str(step.get("id", "")).to_lower()
	if not step_id.contains("recover") and not step_id.contains("stretcher") and not step_id.contains("rod"):
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	var card := item as CardInstance
	var card_data := card.card_data
	if card_data == null:
		return 0.0
	var primary_name := _first_profile_name("energy_priority")
	if primary_name != "" and _matches_key(card, primary_name):
		var primary_on_field := false
		for slot: PokemonSlot in _all_slots(player):
			if _matches_key(slot, primary_name):
				primary_on_field = true
				break
		if not primary_on_field:
			return 4200.0
	if not card_data.is_energy():
		return 0.0
	var best_improvement := 0
	var completes_attack := false
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_profile(slot, "energy_priority") or slot.get_card_data() == null:
			continue
		for attack: Dictionary in slot.get_card_data().attacks:
			if _attack_dict_has_draw_text(attack):
				continue
			var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
			var before := _attack_cost_gap(slot, cost)
			var after := _attack_cost_gap(slot, cost, card)
			best_improvement = maxi(best_improvement, before - after)
			completes_attack = completes_attack or (before > 0 and after == 0)
	if completes_attack:
		return 3600.0
	return 1800.0 * float(best_improvement)


func _pick_distinct_ranked_cards(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := maxi(0, int(step.get("max_select", 1)))
	if max_select <= 0:
		return []
	var ranked: Array[Dictionary] = []
	for item: Variant in items:
		if item is CardInstance and (item as CardInstance).card_data != null:
			ranked.append({
				"item": item,
				"score": score_interaction_target(item, step, context),
			})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", 0.0))
		var right_score := float(right.get("score", 0.0))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int((left.get("item") as CardInstance).instance_id) < int((right.get("item") as CardInstance).instance_id)
	)
	var selected: Array = []
	for entry: Dictionary in ranked:
		var candidate := entry.get("item") as CardInstance
		var duplicate_identity := false
		for selected_raw: Variant in selected:
			var selected_card := selected_raw as CardInstance
			if _same_rule_identity(candidate.card_data, selected_card.card_data):
				duplicate_identity = true
				break
		if duplicate_identity:
			continue
		selected.append(candidate)
		if selected.size() >= max_select:
			break
	return selected


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var profile_score := super.score_handoff_target(item, step, context)
	if _delegate != null and _delegate.has_method("score_handoff_target"):
		return float(_delegate.call("score_handoff_target", item, step, context)) + profile_score * 0.30
	return profile_score


func _apply_delegate_configuration() -> void:
	if _delegate == null:
		return
	if _delegate.has_method("set_deck_strategy_text"):
		_delegate.call("set_deck_strategy_text", _deck_strategy_text)
	if _configured_deck != null and _delegate.has_method("configure_from_deck"):
		_delegate.call("configure_from_deck", _configured_deck)


func _is_energy_switch_card(item: Variant) -> bool:
	return _matches_key(item, "Energy Switch") or _matches_key(item, "能量转移")


func _discard_search_replaces_same_identity(action: Dictionary) -> bool:
	var discarded: Array[CardInstance] = []
	var searched: Array[CardInstance] = []
	var raw_targets: Variant = action.get("targets", [])
	if not raw_targets is Array:
		return false
	for raw_group: Variant in raw_targets:
		if not raw_group is Dictionary:
			continue
		var group: Dictionary = raw_group
		for raw_card: Variant in group.get("discard_cards", []):
			if raw_card is CardInstance:
				discarded.append(raw_card)
		for key: String in ["search_pokemon", "search_cards"]:
			for raw_card: Variant in group.get(key, []):
				if raw_card is CardInstance:
					searched.append(raw_card)
	if discarded.is_empty() or searched.is_empty():
		return false
	for searched_card: CardInstance in searched:
		if searched_card.card_data == null:
			continue
		for discarded_card: CardInstance in discarded:
			if discarded_card.card_data != null and _same_rule_identity(searched_card.card_data, discarded_card.card_data):
				return true
	return false


func _discard_action_breaks_visible_attack_core(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState
) -> bool:
	if player == null or str(action.get("kind", "")) != "play_trainer":
		return false
	var discarded_energies: Array[CardInstance] = []
	var searched_cards: Array[CardInstance] = []
	var raw_targets: Variant = action.get("targets", [])
	if not raw_targets is Array:
		return false
	for raw_group: Variant in raw_targets:
		if not raw_group is Dictionary:
			continue
		var group := raw_group as Dictionary
		for raw_card: Variant in group.get("discard_cards", []):
			if raw_card is CardInstance and _is_basic_energy_card(raw_card as CardInstance):
				discarded_energies.append(raw_card as CardInstance)
		for key: String in ["search_pokemon", "search_cards"]:
			for raw_card: Variant in group.get(key, []):
				if raw_card is CardInstance:
					searched_cards.append(raw_card as CardInstance)
	if discarded_energies.is_empty():
		return false
	var primary_name := _first_profile_name("energy_priority")
	var primary_on_field := false
	for slot: PokemonSlot in _all_slots(player):
		primary_on_field = primary_on_field or _matches_key(slot, primary_name)
	if not primary_on_field:
		for searched_card: CardInstance in searched_cards:
			if _matches_key(searched_card, primary_name):
				return false
	if game_state != null and not game_state.supporter_used_this_turn:
		for hand_card: CardInstance in player.hand:
			if _matches_key(hand_card, "Professor Sada's Vitality"):
				return false
	var completion_cards := 0
	for discarded_energy: CardInstance in discarded_energies:
		var completes_visible_route := false
		for slot: PokemonSlot in _all_slots(player):
			if not _matches_profile(slot, "energy_priority") or slot.get_card_data() == null:
				continue
			for attack: Dictionary in slot.get_card_data().attacks:
				if _attack_dict_has_draw_text(attack):
					continue
				var cost := CardData.normalize_attack_cost(str(attack.get("cost", "")))
				var before := _attack_cost_gap(slot, cost)
				if before > 0 and _attack_cost_gap(slot, cost, discarded_energy) == 0:
					completes_visible_route = true
					break
			if completes_visible_route:
				break
		if completes_visible_route:
			completion_cards += 1
	return completion_cards > 0


func _same_rule_identity(left: CardData, right: CardData) -> bool:
	if left == null or right == null:
		return false
	var left_uid := left.get_uid()
	var right_uid := right.get_uid()
	return (
		(left_uid != "" and left_uid != "_" and left_uid == right_uid)
		or left.matches_rule_identity_name(right.name)
		or (str(right.name_en) != "" and left.matches_rule_identity_name(right.name_en))
	)


func _best_energy_transfer_gain(player: PlayerState) -> float:
	if player == null:
		return -INF
	var best_gain := -INF
	var slots := _all_slots(player)
	for source: PokemonSlot in slots:
		for energy: CardInstance in source.attached_energy:
			if energy == null or energy.card_data == null or str(energy.card_data.card_type) != "Basic Energy":
				continue
			for target: PokemonSlot in slots:
				if target == source:
					continue
				best_gain = maxf(best_gain, _energy_transfer_pair_gain(source, target, energy, player))
	return best_gain


func _energy_transfer_pair_gain(
	source: PokemonSlot,
	target: PokemonSlot,
	energy: CardInstance,
	player: PlayerState = null
) -> float:
	if source == null or target == null or source == target or energy == null or energy not in source.attached_energy:
		return -INF
	var source_before := _energy_route_slot_value(source)
	var target_before := _energy_route_slot_value(target)
	var source_after := _energy_route_slot_value(source, energy)
	var target_after := _energy_route_slot_value(target, null, energy)
	var retreat_bonus := _retreat_unlock_transfer_bonus(player, source, target, energy)
	var route_gain := (
		source_after + target_after - source_before - target_before
		+ retreat_bonus
	)
	if not _matches_profile(target, "energy_priority") and retreat_bonus <= 0.0:
		return minf(route_gain, -1800.0)
	return route_gain


func _retreat_unlock_transfer_bonus(
	player: PlayerState,
	source: PokemonSlot,
	target: PokemonSlot,
	energy: CardInstance
) -> float:
	if player == null or target != player.active_pokemon or source not in player.bench:
		return 0.0
	var retreat_cost := target.get_retreat_cost()
	var before_units := target.get_total_energy_count()
	var added_units := int(_energy_provision(energy).get("units", 0))
	if retreat_cost <= 0 or before_units >= retreat_cost or before_units + added_units < retreat_cost:
		return 0.0
	for attack: Dictionary in source.get_card_data().attacks:
		if _attack_cost_gap(source, str(attack.get("cost", "")), null, 0, energy) == 0:
			return 1200.0
	return 0.0


func _energy_route_slot_value(
	slot: PokemonSlot,
	excluded_energy: CardInstance = null,
	extra_energy: CardInstance = null
) -> float:
	if slot == null or slot.get_card_data() == null:
		return -1000.0
	var role_value := _profile_score(slot, "energy_priority", 450.0, 35.0)
	var best_value := -1000.0
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
		var gap := _attack_cost_gap(slot, cost, extra_energy, 0, excluded_energy)
		var damage := _parse_damage(str(attack.get("damage", "0")))
		var value := float(damage) * 1.5 - float(gap) * 500.0
		if gap == 0:
			value += 300.0 + float(damage) * 4.0 + role_value * 1.5
		elif gap == 1:
			value += 100.0 + role_value * 0.8
		best_value = maxf(best_value, value)
	return best_value


func _energy_transfer_interaction_score(item: Variant, step: Dictionary, context: Dictionary) -> Variant:
	if str(step.get("id", "")).to_lower() != "energy_assignment":
		return null
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	if item is CardInstance:
		var energy: CardInstance = item
		var source := _slot_holding_energy(player, energy)
		if source == null:
			return null
		var best_gain := -INF
		for target: PokemonSlot in _all_slots(player):
			if target != source:
				best_gain = maxf(best_gain, _energy_transfer_pair_gain(source, target, energy, player))
		return best_gain
	var selected_source: Variant = context.get("assignment_source", context.get("source_card", null))
	if item is PokemonSlot and selected_source is CardInstance:
		var selected_energy: CardInstance = selected_source
		var source := _slot_holding_energy(player, selected_energy)
		return _energy_transfer_pair_gain(source, item, selected_energy, player) if source != null else null
	return null


func _slot_holding_energy(player: PlayerState, energy: CardInstance) -> PokemonSlot:
	if player == null or energy == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if energy in slot.attached_energy:
			return slot
	return null


func _evolution_search_route_score(item: Variant, step: Dictionary, context: Dictionary) -> float:
	if not item is CardInstance:
		return 0.0
	var card: CardInstance = item
	var cd: CardData = card.card_data
	if cd == null or not cd.is_pokemon():
		return 0.0
	var step_id := str(step.get("id", "")).to_lower()
	if step_id.contains("discard") or step_id.contains("energy") or step_id.contains("attach"):
		return 0.0
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0.0
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return 0.0
	var stage := str(cd.stage)
	if stage == "Basic":
		var primary_attacker_bonus := _missing_primary_basic_search_bonus(card, player)
		var field_count := _count_card_identity_on_field(player, cd)
		if field_count <= 0 and player.bench.size() < 5:
			return 520.0 + primary_attacker_bonus
		if field_count == 1 and _matches_profile(card, "bench_priority") and player.bench.size() < 4:
			return 180.0 + primary_attacker_bonus
		return -80.0 * float(field_count) + primary_attacker_bonus
	if stage not in ["Stage 1", "Stage 2", "VSTAR", "VMAX"]:
		return 0.0
	if _has_direct_evolution_target(player, cd):
		return 900.0
	if stage == "Stage 2" and _has_live_rare_candy_route(player, cd, context):
		return 760.0
	return -620.0


func _missing_primary_basic_search_bonus(card: CardInstance, player: PlayerState) -> float:
	if card == null or card.card_data == null or player == null:
		return 0.0
	var primary_name := _first_profile_name("energy_priority")
	if primary_name == "" or not _matches_key(card, primary_name):
		return 0.0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, primary_name):
			return 0.0
	for hand_card: CardInstance in player.hand:
		if _matches_key(hand_card, primary_name):
			return 0.0
	return 1000.0


func _missing_primary_basic_attacker(player: PlayerState) -> bool:
	if player == null:
		return false
	var primary_name := _first_profile_name("energy_priority")
	if primary_name == "":
		return false
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, primary_name):
			return false
	for zone: Array in [player.hand, player.deck, player.discard_pile]:
		for card: CardInstance in zone:
			if not _matches_key(card, primary_name):
				continue
			var card_data := _card_data_from_item(card)
			return card_data != null and str(card_data.stage) == "Basic"
	return false


func _has_direct_evolution_target(player: PlayerState, evolution: CardData) -> bool:
	if player == null or evolution == null:
		return false
	for slot: PokemonSlot in _all_slots(player):
		if slot == null or slot.get_card_data() == null:
			continue
		if evolution.evolves_from_matches(slot.get_card_data()):
			return true
	return false


func _has_live_rare_candy_route(player: PlayerState, stage_two: CardData, context: Dictionary) -> bool:
	if player == null or stage_two == null or not _player_has_rare_candy(player, context):
		return false
	for slot: PokemonSlot in _all_slots(player):
		var basic: CardData = slot.get_card_data() if slot != null else null
		if basic == null or str(basic.stage) != "Basic":
			continue
		for stage_one: CardData in _stage_one_cards_for_player(player):
			if stage_two.evolves_from_matches(stage_one) and stage_one.evolves_from_matches(basic):
				return true
	return false


func _player_has_rare_candy(player: PlayerState, context: Dictionary) -> bool:
	var pending: Variant = context.get("pending_effect_card", null)
	if _matches_key(pending, "Rare Candy") or _matches_key(pending, "神奇糖果"):
		return true
	for card: CardInstance in player.hand:
		if _matches_key(card, "Rare Candy") or _matches_key(card, "神奇糖果"):
			return true
	return false


func _stage_one_cards_for_player(player: PlayerState) -> Array[CardData]:
	var result: Array[CardData] = []
	for zone: Array in [player.hand, player.deck, player.discard_pile]:
		for card: CardInstance in zone:
			if card != null and card.card_data != null and str(card.card_data.stage) == "Stage 1":
				result.append(card.card_data)
	return result


func _count_card_identity_on_field(player: PlayerState, wanted: CardData) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		var actual: CardData = slot.get_card_data() if slot != null else null
		if actual != null and (
			actual.matches_rule_identity_name(wanted.name)
			or (str(wanted.name_en) != "" and actual.matches_rule_identity_name(wanted.name_en))
		):
			count += 1
	return count


func _delegate_action_score(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _delegate == null:
		return NAN
	if _delegate.has_method("score_action_absolute_with_plan_context_only"):
		return float(_delegate.call(
			"score_action_absolute_with_plan_context_only",
			action,
			game_state,
			player_index,
			get_turn_plan_context()
		))
	if _delegate.has_method("score_action_absolute_with_plan"):
		return float(_delegate.call("score_action_absolute_with_plan", action, game_state, player_index, get_turn_plan_context()))
	if _delegate.has_method("score_action_absolute"):
		return float(_delegate.call("score_action_absolute", action, game_state, player_index))
	return NAN


func _merge_delegate_plan(
	profile_plan: Dictionary,
	game_state: GameState,
	player_index: int,
	context: Dictionary
) -> Dictionary:
	if _delegate == null or not _delegate.has_method("build_turn_plan"):
		return profile_plan
	var delegate_variant: Variant = _delegate.call("build_turn_plan", game_state, player_index, context)
	if not (delegate_variant is Dictionary) or (delegate_variant as Dictionary).is_empty():
		return profile_plan
	var merged := profile_plan.duplicate(true)
	var delegate_plan: Dictionary = delegate_variant
	for key: String in ["owner", "targets", "flags", "priorities", "constraints", "context"]:
		var delegate_value: Variant = delegate_plan.get(key, null)
		if delegate_value is Dictionary:
			var current: Dictionary = merged.get(key, {}) if merged.get(key, {}) is Dictionary else {}
			merged[key] = _deep_merge_plan_dictionary(current, delegate_value as Dictionary)
	if delegate_plan.has("intent"):
		merged["intent"] = delegate_plan.get("intent", "")
	if delegate_plan.has("phase"):
		merged["phase"] = delegate_plan.get("phase", "")
	merged["delegate_plan_id"] = str(delegate_plan.get("id", ""))
	return merged


func _deep_merge_plan_dictionary(shared: Dictionary, delegate: Dictionary) -> Dictionary:
	var merged := shared.duplicate(true)
	for key: Variant in delegate:
		var delegate_value: Variant = delegate[key]
		var shared_value: Variant = merged.get(key, null)
		if shared_value is Dictionary and delegate_value is Dictionary:
			merged[key] = _deep_merge_plan_dictionary(
				shared_value as Dictionary,
				delegate_value as Dictionary
			)
		else:
			merged[key] = delegate_value
	return merged


func _detect_phase(game_state: GameState, player: PlayerState) -> String:
	if player == null:
		return PHASE_SETUP
	if player.prizes.size() <= 2 and _count_ready_attackers(player) > 0:
		return PHASE_CLOSE
	if _setup_debt(player) > 0 or int(game_state.turn_number) <= 2:
		return PHASE_SETUP
	if _count_ready_attackers(player) <= 0:
		return PHASE_REBUILD
	if _count_profile_bodies(player, "energy_priority") <= 1:
		return PHASE_LAUNCH
	return PHASE_CONVERT


func _phase_intent(phase: String) -> String:
	match phase:
		PHASE_SETUP:
			return "establish_engine"
		PHASE_LAUNCH:
			return "launch_first_attacker"
		PHASE_REBUILD:
			return "rebuild_next_attacker"
		PHASE_CLOSE:
			return "take_final_prizes"
	return "preserve_pressure"


func _setup_debt(player: PlayerState) -> int:
	if player == null:
		return _setup_floor()
	return maxi(0, _setup_floor() - _count_profile_bodies(player, "bench_priority"))


func _setup_floor() -> int:
	var continuity: Variant = _profile_data.get("continuity", {})
	return int((continuity as Dictionary).get("setup_floor", 2)) if continuity is Dictionary else 2


func _deck_churn_floor() -> int:
	var continuity: Variant = _profile_data.get("continuity", {})
	var configured := int((continuity as Dictionary).get("deck_churn_floor", 12)) if continuity is Dictionary else 12
	return clampi(configured, 2, 20)


func _count_profile_bodies(player: PlayerState, profile_key: String) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if _matches_profile(slot, profile_key):
			count += 1
	return count


func _count_ready_attackers(player: PlayerState) -> int:
	var count := 0
	for slot: PokemonSlot in _all_slots(player):
		if bool(predict_attacker_damage(slot).get("can_attack", false)):
			count += 1
	return count


func _best_bridge_name(player: PlayerState, fallback: String) -> String:
	var best_name := _best_profile_name_on_field(player, "evolution_priority")
	return best_name if best_name != "" else fallback


func _first_profile_name(key: String) -> String:
	var names := _profile_list(key)
	return names[0] if not names.is_empty() else ""


func _has_productive_board_debt(player: PlayerState) -> bool:
	return _setup_debt(player) > 0 or _count_ready_attackers(player) <= 0


func _terminal_attack_bonus(action: Dictionary, game_state: GameState, player_index: int, phase: String) -> float:
	var score := float(int(action.get("projected_damage", 0))) * 0.9
	if bool(action.get("projected_knockout", false)):
		score += 780.0
		if _is_continuity_final_prize_attack(action, game_state, player_index):
			score += 5000.0
	elif phase == PHASE_SETUP and _setup_debt(game_state.players[player_index]) > 0:
		score -= 180.0
	return score


func _is_churn_action(action: Dictionary) -> bool:
	var kind := str(action.get("kind", ""))
	if kind in ["attack", "granted_attack"]:
		return _attack_has_draw_text(action)
	if kind not in ["play_trainer", "use_ability", "use_stadium_effect"]:
		return false
	var item: Variant = action.get("card", action.get("source_slot", null))
	for name: String in LOW_DECK_CHURN_NAMES:
		if _matches_key(item, name):
			return true
	var action_id := str(action.get("id", action.get("action_id", ""))).to_lower()
	return action_id.contains("draw") or action_id.contains("shuffle_hand") or _item_has_draw_text(item)


func _deck_churn_penalty(player: PlayerState) -> float:
	if player == null:
		return 0.0
	var deck_size := player.deck.size()
	var has_ready_attacker := _count_ready_attackers(player) > 0
	if has_ready_attacker:
		if deck_size <= 4:
			return 3200.0
		if deck_size <= 8:
			return 1900.0
		return 1150.0
	if deck_size <= 2:
		return 900.0
	return 420.0


func _deck_search_penalty(deck_size: int) -> float:
	if deck_size <= 2:
		return 1200.0
	if deck_size <= 4:
		return 700.0
	return 260.0


func _is_deck_search_action(action: Dictionary) -> bool:
	if str(action.get("kind", "")) not in ["play_trainer", "use_ability", "use_stadium_effect"]:
		return false
	var item: Variant = action.get("card", action.get("source_slot", null))
	if _matches_key(item, "Ciphermaniac's Codebreaking") or _matches_key(item, "暗码迷的解读"):
		return false
	for name: String in LOW_DECK_SEARCH_NAMES:
		if _matches_key(item, name):
			return true
	return _variant_has_search_selection(action.get("targets", []))


func _variant_has_search_selection(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			var lowered := str(key).to_lower()
			var nested: Variant = value[key]
			if (lowered.begins_with("search_") or lowered.contains("from_deck")) and nested is Array and not (nested as Array).is_empty():
				return true
			if _variant_has_search_selection(nested):
				return true
	elif value is Array:
		for nested: Variant in value:
			if _variant_has_search_selection(nested):
				return true
	return false


func _attack_has_draw_text(action: Dictionary) -> bool:
	for key: String in ["attack", "attack_data", "copied_attack"]:
		var attack_variant: Variant = action.get(key, null)
		if attack_variant is Dictionary and _attack_dict_has_draw_text(attack_variant as Dictionary):
			return true
	var source_data := _card_data_from_item(action.get("source_slot", action.get("source_card", null)))
	var attack_index := int(action.get("attack_index", -1))
	if source_data != null and attack_index >= 0 and attack_index < source_data.attacks.size():
		return _attack_dict_has_draw_text(source_data.attacks[attack_index])
	return _text_has_draw_effect(str(action.get("attack_name", "")))


func _attack_dict_has_draw_text(attack: Dictionary) -> bool:
	return _text_has_draw_effect(
		"%s %s" % [str(attack.get("name", "")), str(attack.get("text", ""))]
	)


func _hand_advances_non_draw_attack(player: PlayerState, action: Dictionary) -> bool:
	if player == null:
		return false
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	if source == null or source.get_card_data() == null:
		return false
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card.card_data == null or not hand_card.card_data.is_energy():
			continue
		for attack: Dictionary in source.get_card_data().attacks:
			if _attack_dict_has_draw_text(attack):
				continue
			var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
			var before := _attack_cost_gap(source, cost)
			if before > 0 and _attack_cost_gap(source, cost, hand_card) < before:
				return true
	return false


func _text_has_draw_effect(text: String) -> bool:
	var lowered := text.to_lower()
	return lowered.contains("draw") \
		or lowered.contains("抽取") \
		or lowered.contains("抽卡") \
		or lowered.contains("抽牌")


func _item_has_draw_text(item: Variant) -> bool:
	var card_data := _card_data_from_item(item)
	if card_data == null:
		return false
	var text := (str(card_data.description) + " " + str(card_data.name) + " " + str(card_data.name_en)).to_lower()
	for ability: Dictionary in card_data.abilities:
		text += " " + str(ability.get("name", "")).to_lower() + " " + str(ability.get("text", "")).to_lower()
	return text.contains("draw") or text.contains("抽取") or text.contains("抽卡") or text.contains("抽牌")


func _energy_route_score(action: Dictionary) -> float:
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if energy == null or energy.card_data == null or target == null or target.get_card_data() == null:
		return 0.0
	var attacks: Array[Dictionary] = target.get_card_data().attacks
	if attacks.is_empty():
		return -180.0
	var best_before := 999
	var best_after := 999
	var best_improvement := 0
	var has_typed_requirement := false
	for attack: Dictionary in attacks:
		var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
		if cost == "":
			continue
		for symbol: String in cost:
			if symbol != "C":
				has_typed_requirement = true
		var before := _attack_cost_gap(target, cost)
		var after := _attack_cost_gap(target, cost, energy)
		best_before = mini(best_before, before)
		best_after = mini(best_after, after)
		best_improvement = maxi(best_improvement, before - after)
	if best_before == 999:
		return -120.0
	if best_before == 0:
		return -70.0
	if best_improvement <= 0:
		return -430.0 if has_typed_requirement else -140.0
	var score := float(best_improvement) * 220.0
	if best_after == 0:
		score += 280.0
	return score


func _raging_bolt_core_attachment_score(action: Dictionary, player: PlayerState) -> float:
	if int(_profile_data.get("deck_id", 0)) != 800018509 or player == null:
		return 0.0
	var energy: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if target != null and _matches_key(target, "151C_132"):
		return -10000.0
	var symbol := _basic_energy_symbol(energy)
	if target != null and symbol == "G" and not _matches_key(target, "CSV8C_028"):
		return -10000.0
	if target == null or symbol not in ["L", "F"]:
		return 0.0
	var completing_targets: Array[PokemonSlot] = []
	for slot: PokemonSlot in _all_slots(player):
		if not _matches_key(slot, "CSV7C_154") and not _matches_key(slot, "Raging Bolt ex"):
			continue
		var before := _attack_cost_gap(slot, "LF")
		if before > 0 and _attack_cost_gap(slot, "LF", energy) == 0:
			completing_targets.append(slot)
	if completing_targets.is_empty() and _raging_bolt_stretcher_can_complete_any_core(player):
		return -10000.0
	if completing_targets.is_empty():
		return 0.0
	return 5000.0 if target in completing_targets else -3000.0


func _raging_bolt_stretcher_can_complete_any_core(player: PlayerState) -> bool:
	if player == null or player.deck.size() > 12:
		return false
	var has_stretcher := false
	for hand_card: CardInstance in player.hand:
		if _matches_key(hand_card, "Night Stretcher") or _matches_key(hand_card, "夜间担架") or _matches_key(hand_card, "夜晚担架"):
			has_stretcher = true
			break
	if not has_stretcher:
		return false
	for discard_card: CardInstance in player.discard_pile:
		if _basic_energy_symbol(discard_card) not in ["L", "F"]:
			continue
		for slot: PokemonSlot in _all_slots(player):
			if not _matches_key(slot, "CSV7C_154") and not _matches_key(slot, "Raging Bolt ex"):
				continue
			if _attack_cost_gap(slot, "LF") > 0 and _attack_cost_gap(slot, "LF", discard_card) == 0:
				return true
	return false


func _predict_typed_attacker_damage(slot: PokemonSlot, extra_colorless_units: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var best_damage := 0
	var can_attack := false
	for attack: Dictionary in slot.get_card_data().attacks:
		var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
		if _attack_cost_gap(slot, cost, null, extra_colorless_units) == 0:
			can_attack = true
			best_damage = maxi(best_damage, _parse_damage(str(attack.get("damage", "0"))))
	return {"damage": best_damage, "can_attack": can_attack, "description": ""}


func _attack_cost_gap(
	slot: PokemonSlot,
	cost: String,
	extra_energy: CardInstance = null,
	extra_colorless_units: int = 0,
	excluded_energy: CardInstance = null,
	extra_energies: Array = []
) -> int:
	var normalized_cost := CardData.normalize_attack_cost(cost)
	var required_by_type: Dictionary = {}
	for symbol: String in normalized_cost:
		if symbol != "C":
			required_by_type[symbol] = int(required_by_type.get(symbol, 0)) + 1
	var provided_by_type: Dictionary = {}
	var any_units := 0
	var total_units := extra_colorless_units
	var energies: Array[CardInstance] = slot.attached_energy.duplicate() if slot != null else []
	if excluded_energy != null:
		energies.erase(excluded_energy)
	if extra_energy != null:
		energies.append(extra_energy)
	for additional_energy: Variant in extra_energies:
		if additional_energy is CardInstance:
			energies.append(additional_energy as CardInstance)
	for energy: CardInstance in energies:
		var provision := _energy_provision(energy)
		total_units += int(provision.get("units", 0))
		any_units += int(provision.get("any", 0))
		var typed: Dictionary = provision.get("typed", {})
		for symbol: Variant in typed:
			provided_by_type[symbol] = int(provided_by_type.get(symbol, 0)) + int(typed[symbol])
	var missing_specific := 0
	for symbol: Variant in required_by_type:
		missing_specific += maxi(0, int(required_by_type[symbol]) - int(provided_by_type.get(symbol, 0)))
	missing_specific = maxi(0, missing_specific - any_units)
	var raw_gap := maxi(missing_specific, maxi(0, normalized_cost.length() - total_units))
	return maxi(0, raw_gap - _attack_cost_discount(slot))


func _attack_cost_discount(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null or slot.attached_tool == null or slot.attached_tool.card_data == null:
		return 0
	var pokemon_data := slot.get_card_data()
	var trait_name := str(pokemon_data.ancient_trait).to_lower()
	if trait_name != "tera" and not str(pokemon_data.ancient_trait).contains("太晶"):
		return 0
	var tool_data := slot.attached_tool.card_data
	var tool_name := "%s %s" % [str(tool_data.name), str(tool_data.name_en)]
	return 1 if tool_name.contains("璀璨结晶") or tool_name.to_lower().contains("sparkling crystal") else 0


func _energy_provision(energy: CardInstance) -> Dictionary:
	var result := {"units": 0, "any": 0, "typed": {}}
	if energy == null or energy.card_data == null:
		return result
	var card_data := energy.card_data
	var name := "%s %s" % [str(card_data.name), str(card_data.name_en)]
	if name.contains("双重涡轮能量") or name.to_lower().contains("double turbo energy"):
		result["units"] = 2
		return result
	var provides := str(card_data.energy_provides)
	if provides == "":
		provides = str(card_data.energy_type)
	if provides == "":
		result["units"] = 1 if card_data.is_energy() else 0
		return result
	if provides == "ANY":
		result["units"] = 1
		result["any"] = 1
		return result
	var typed: Dictionary = {}
	for symbol: String in provides:
		if symbol == "C":
			result["units"] = int(result["units"]) + 1
		else:
			typed[symbol] = int(typed.get(symbol, 0)) + 1
			result["units"] = int(result["units"]) + 1
	result["typed"] = typed
	return result
