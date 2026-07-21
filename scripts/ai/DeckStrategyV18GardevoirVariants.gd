class_name DeckStrategyV18GardevoirVariants
extends "res://scripts/ai/DeckStrategyGardevoir.gd"


const NO_BALLOON_DECK_ID := 800017097
const RABSCA_DECK_ID := 800018105

const VARIANT_NO_BALLOON := "no_balloon_gardevoir"
const VARIANT_RABSCA := "rabsca_gardevoir"
const VARIANT_UNKNOWN := "gardevoir_variants"

const GARDEVOIR_EFFECT_ID := "bd134d7d84e9f1a837a74b061fcb5f40"
const KIRLIA_EFFECT_ID := "4abd956bdf3e956fcf679120601760ff"
const MUNKIDORI_EFFECT_ID := "66fee12502043db7d92b97b0d62b0f59"
const DRIFLOON_EFFECT_ID := "8e295bb9597fb1ebbc2c6d58a98e0839"
const SCREAM_TAIL_EFFECT_ID := "12c9416c64d1a8cfbbf0a3000a9f3d50"
const RELLOR_EFFECT_ID := "c2d6b5ec0bc365112105fea079a22fd7"
const RABSCA_EFFECT_ID := "4e41398ab9262f85910de1d9b3a4f027"
const BRAVERY_CHARM_EFFECT_ID := "d1c2f018a644e662f2b6895fdfc29281"
const ARTAZON_EFFECT_ID := "c117bea3cc758d46430d6bef11062a56"

const RALTS_NAMES: Array[String] = ["拉鲁拉丝", "Ralts"]
const KIRLIA_NAMES: Array[String] = ["奇鲁莉安", "Kirlia"]
const GARDEVOIR_NAMES: Array[String] = ["沙奈朵ex", "Gardevoir ex"]
const DRIFLOON_NAMES: Array[String] = ["飘飘球", "Drifloon"]
const SCREAM_TAIL_NAMES: Array[String] = ["吼叫尾", "Scream Tail"]
const MUNKIDORI_NAMES: Array[String] = ["愿增猿", "Munkidori"]
const BUDEW_NAMES: Array[String] = ["含羞苞", "Budew"]
const CLEFFA_NAMES: Array[String] = ["皮宝宝", "Cleffa"]
const MEW_EX_NAMES: Array[String] = ["梦幻ex", "Mew ex"]
const FEZANDIPITI_NAMES: Array[String] = ["吉雉鸡ex", "Fezandipiti ex"]
const CLEFAIRY_EX_NAMES: Array[String] = ["莉莉艾的皮皮ex", "Lillie's Clefairy ex"]
const RELLOR_NAMES: Array[String] = ["虫滚泥", "Rellor"]
const RABSCA_NAMES: Array[String] = ["虫甲圣", "Rabsca"]
const BRAVERY_CHARM_NAMES: Array[String] = ["勇气护符", "Bravery Charm"]
const ARTAZON_NAMES: Array[String] = ["深钵镇", "Artazon"]

const DRAW_SUPPORTER_NAMES: Array[String] = [
	"博士的研究", "Professor's Research", "奇树", "Iono",
]
const REFINEMENT_NAMES: Array[String] = ["精炼", "Refinement"]
const PSYCHIC_EMBRACE_NAMES: Array[String] = ["精神拥抱", "Psychic Embrace"]
const MIRACLE_FORCE_NAMES: Array[String] = ["奇迹之力", "Miracle Force"]

var _variant_deck_id: int = 0
var _variant_id: String = VARIANT_UNKNOWN


func configure_from_deck(deck: DeckData) -> void:
	super.configure_from_deck(deck)
	_variant_deck_id = int(deck.id) if deck != null else 0
	match _variant_deck_id:
		NO_BALLOON_DECK_ID:
			_variant_id = VARIANT_NO_BALLOON
		RABSCA_DECK_ID:
			_variant_id = VARIANT_RABSCA
		_:
			_variant_id = VARIANT_UNKNOWN


func get_strategy_id() -> String:
	if _variant_deck_id in [NO_BALLOON_DECK_ID, RABSCA_DECK_ID]:
		return "v18_gardevoir_variants_%d_delegate" % _variant_deck_id
	return "v18_gardevoir_variants_delegate"


func get_family_variant_id() -> String:
	return _variant_id


func _deck_allows_munkidori_damage_transfer_debt() -> bool:
	return _variant_deck_id in [NO_BALLOON_DECK_ID, RABSCA_DECK_ID] \
		or super._deck_allows_munkidori_damage_transfer_debt()


func predict_attacker_damage(slot: PokemonSlot, extra_embrace_count: int = 0) -> Dictionary:
	if _matches(slot, GARDEVOIR_NAMES, GARDEVOIR_EFFECT_ID):
		return {
			"damage": 190,
			"can_attack": _attack_cost_is_met(slot, "PPC", extra_embrace_count),
			"description": "gardevoir_miracle_force",
		}
	return super.predict_attacker_damage(slot, extra_embrace_count)


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var basics: Array[Dictionary] = []
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		if card == null or card.card_data == null:
			continue
		if not card.card_data.is_pokemon() or str(card.card_data.stage) != "Basic":
			continue
		basics.append({"index": index, "card": card})
	if basics.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}

	var active_order: Array[Array] = []
	if _variant_id == VARIANT_NO_BALLOON:
		active_order = [BUDEW_NAMES, CLEFFA_NAMES, FEZANDIPITI_NAMES, MUNKIDORI_NAMES, DRIFLOON_NAMES, SCREAM_TAIL_NAMES, RALTS_NAMES, CLEFAIRY_EX_NAMES]
	else:
		active_order = [MEW_EX_NAMES, FEZANDIPITI_NAMES, DRIFLOON_NAMES, SCREAM_TAIL_NAMES, RELLOR_NAMES, RALTS_NAMES, CLEFAIRY_EX_NAMES, MUNKIDORI_NAMES]
	var active_index := _first_opening_match(basics, active_order)
	if active_index < 0:
		active_index = int(basics[0].get("index", -1))

	var bench_indices: Array[int] = []
	_append_opening_matches(bench_indices, basics, active_index, RALTS_NAMES, 2)
	if _variant_id == VARIANT_RABSCA:
		_append_opening_matches(bench_indices, basics, active_index, RELLOR_NAMES, 1)
	if bench_indices.size() < 3:
		_append_opening_matches(bench_indices, basics, active_index, DRIFLOON_NAMES, 1)
	if bench_indices.size() < 3:
		_append_opening_matches(bench_indices, basics, active_index, SCREAM_TAIL_NAMES, 1)
	if bench_indices.size() < 3:
		_append_opening_matches(bench_indices, basics, active_index, MUNKIDORI_NAMES, 1)
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var plan := super.build_turn_plan(game_state, player_index, context)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return plan
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return plan

	var guard_online := _rabsca_guard_online(player)
	var guard_pressure := _opponent_has_bench_attack_pressure(game_state, player_index)
	var rellor_online := _field_has(player, RELLOR_NAMES, RELLOR_EFFECT_ID)
	var guard_debt := _variant_id == VARIANT_RABSCA and guard_pressure and not guard_online
	var ready_attacker := _best_ready_one_prize_attacker(player)
	var retreat_bridge := ready_attacker != null and _active_needs_retreat_payment(player)
	var gardevoir_closeout := _no_balloon_gardevoir_closeout(game_state, player_index)
	var closeout_live := bool(gardevoir_closeout.get("live", false))
	var low_deck_guard := player.deck.size() <= 8 and ready_attacker != null or closeout_live

	var flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	flags.merge({
		"gardevoir_variant": _variant_id,
		"no_balloon_retreat_bridge": _variant_id == VARIANT_NO_BALLOON and retreat_bridge,
		"rabsca_guard_online": guard_online,
		"rabsca_guard_debt": guard_debt,
		"rabsca_rellor_online": rellor_online,
		"opponent_bench_attack_pressure": guard_pressure,
		"low_deck_conversion_guard": low_deck_guard,
		"no_balloon_gardevoir_closeout": closeout_live,
		"no_balloon_gardevoir_closeout_needs_embrace": bool(gardevoir_closeout.get("needs_embrace", false)),
	}, true)
	plan["flags"] = flags

	var targets: Dictionary = plan.get("targets", {}) if plan.get("targets", {}) is Dictionary else {}
	if closeout_live:
		var active_name := _slot_display_name(player.active_pokemon)
		targets["primary_attacker_name"] = active_name
		targets["bridge_target_name"] = active_name
		targets["pivot_target_name"] = active_name
	elif retreat_bridge:
		targets["primary_attacker_name"] = _slot_display_name(ready_attacker)
		targets["bridge_target_name"] = _slot_display_name(player.active_pokemon)
		targets["pivot_target_name"] = _slot_display_name(ready_attacker)
	elif guard_debt and rellor_online:
		targets["bridge_target_name"] = "虫甲圣"
	plan["targets"] = targets

	var constraints: Dictionary = plan.get("constraints", {}) if plan.get("constraints", {}) is Dictionary else {}
	constraints["must_unlock_ready_bench_attacker"] = bool(constraints.get("must_unlock_ready_bench_attacker", false)) or retreat_bridge
	constraints["must_build_rabsca_guard"] = guard_debt
	constraints["forbid_engine_churn"] = bool(constraints.get("forbid_engine_churn", false)) or low_deck_guard
	constraints["forbid_extra_bench_padding"] = bool(constraints.get("forbid_extra_bench_padding", false)) \
		or closeout_live \
		or (ready_attacker != null and not guard_debt)
	plan["constraints"] = constraints

	if closeout_live:
		var closeout_owner_name := _slot_display_name(player.active_pokemon)
		plan["owner"] = {
			"turn_owner_name": closeout_owner_name,
			"bridge_target_name": closeout_owner_name,
			"pivot_target_name": closeout_owner_name,
		}

	var phase := "setup"
	if closeout_live:
		phase = "close"
		plan["intent"] = "embrace_gardevoir_closeout" \
			if bool(gardevoir_closeout.get("needs_embrace", false)) \
			else "convert_gardevoir_closeout"
	elif low_deck_guard:
		phase = "close"
	elif retreat_bridge:
		phase = "convert"
	elif _field_has(player, GARDEVOIR_NAMES, GARDEVOIR_EFFECT_ID) and ready_attacker != null:
		phase = "convert"
	elif _field_has(player, GARDEVOIR_NAMES, GARDEVOIR_EFFECT_ID):
		phase = "rebuild"
	elif _field_has(player, KIRLIA_NAMES, KIRLIA_EFFECT_ID):
		phase = "launch"
	plan["phase"] = phase
	plan["id"] = "v18_gardevoir_variants:%s:%s" % [_variant_id, str(plan.get("intent", phase))]
	return plan


func build_turn_contract(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var contract := super.build_turn_contract(game_state, player_index, context)
	var priorities: Dictionary = contract.get("priorities", {}) if contract.get("priorities", {}) is Dictionary else {}
	if not priorities.has("attach"):
		priorities["attach"] = []
	if not priorities.has("handoff"):
		priorities["handoff"] = []
	if not priorities.has("search"):
		priorities["search"] = []
	priorities["evolve"] = ["沙奈朵ex", "奇鲁莉安", "虫甲圣"] if _variant_id == VARIANT_RABSCA else ["沙奈朵ex", "奇鲁莉安"]
	priorities["ability"] = ["沙奈朵ex", "奇鲁莉安", "愿增猿"]
	priorities["trainer"] = ["高级球", "大地容器", "神奇糖果", "夜间担架"]
	contract["priorities"] = priorities
	return contract


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	turn_contract: Dictionary = {}
) -> Dictionary:
	var continuity := super.build_continuity_contract(game_state, player_index, turn_contract)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return continuity
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return continuity
	var gardevoir_closeout := _no_balloon_gardevoir_closeout(game_state, player_index)
	if bool(gardevoir_closeout.get("live", false)):
		continuity["enabled"] = false
		continuity["safe_setup_before_attack"] = false
		continuity["action_bonuses"] = []
		continuity["attack_penalty"] = 0.0
		continuity["stop_reason"] = "no_balloon_gardevoir_closeout"
		return continuity
	var ready_attacker := _best_ready_one_prize_attacker(player)
	if player.deck.size() <= 8 and ready_attacker != null:
		continuity["enabled"] = false
		continuity["safe_setup_before_attack"] = false
		continuity["action_bonuses"] = []
		continuity["attack_penalty"] = 0.0
		continuity["stop_reason"] = "low_deck_conversion_guard"
		return continuity
	if _variant_id == VARIANT_RABSCA \
			and _opponent_has_bench_attack_pressure(game_state, player_index) \
			and not _rabsca_guard_online(player):
		var setup_debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
		setup_debt["need_rabsca_guard"] = true
		continuity["setup_debt"] = setup_debt
		var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
		bonuses.append({"kind": "evolve", "card_effect_ids": [RABSCA_EFFECT_ID], "bonus": 1800.0, "reason": "build_rabsca_guard"})
		continuity["action_bonuses"] = bonuses
		continuity["enabled"] = true
		continuity["safe_setup_before_attack"] = true
		continuity["attack_penalty"] = maxf(float(continuity.get("attack_penalty", 0.0)), 800.0)
	return continuity


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return score
	var kind := str(action.get("kind", ""))
	if _variant_deck_id == NO_BALLOON_DECK_ID \
			and kind == "attach_tool" \
			and _matches(action.get("card", null), BRAVERY_CHARM_NAMES, BRAVERY_CHARM_EFFECT_ID) \
			and _matches(action.get("target_slot", null), RALTS_NAMES):
		return minf(score, -4600.0)
	if _variant_deck_id == NO_BALLOON_DECK_ID \
			and kind == "attach_energy" \
			and action.get("target_slot", null) == player.active_pokemon \
			and _matches(player.active_pokemon, RALTS_NAMES) \
			and player.active_pokemon.attached_energy.size() == 1 \
			and _attack_energy_gap(player.active_pokemon) == 1:
		var second_ralts_energy: CardInstance = action.get("card", null)
		var opponent_index := 1 - player_index
		var opponent_active: PokemonSlot = game_state.players[opponent_index].active_pokemon \
			if opponent_index >= 0 and opponent_index < game_state.players.size() else null
		if second_ralts_energy != null \
				and second_ralts_energy.card_data != null \
				and str(second_ralts_energy.card_data.energy_provides) == "P" \
				and opponent_active != null \
				and opponent_active.get_remaining_hp() > _printed_damage(player.active_pokemon):
			return minf(score, -3600.0)
	if _variant_deck_id == NO_BALLOON_DECK_ID \
			and kind == "attach_energy" \
			and _matches(action.get("target_slot", null), RALTS_NAMES) \
			and _attack_energy_gap(action.get("target_slot", null)) <= 0 \
			and _retreat_gap(action.get("target_slot", null)) <= 0:
		return minf(score, -4200.0)
	if _variant_deck_id == NO_BALLOON_DECK_ID \
			and _munkidori_damage_transfer_debt_live(game_state, player, player_index):
		if kind == "use_ability" \
				and _matches(action.get("source_slot", null), MUNKIDORI_NAMES, MUNKIDORI_EFFECT_ID):
			return maxf(score, MUNKIDORI_DEBT_ABILITY_FLOOR)
		if kind in ["attack", "granted_attack"] \
				and not _no_balloon_attack_takes_final_prizes(action, game_state, player_index):
			return minf(score, MUNKIDORI_DEBT_NON_FINAL_ATTACK_CEILING)
	var gardevoir_closeout := _no_balloon_gardevoir_closeout(game_state, player_index)
	if bool(gardevoir_closeout.get("live", false)):
		var active_gardevoir: PokemonSlot = gardevoir_closeout.get("slot", null)
		var needs_embrace := bool(gardevoir_closeout.get("needs_embrace", false))
		if kind == "use_ability":
			if _action_is_refinement(action):
				return minf(score, -2600.0)
			if action.get("source_slot", null) == active_gardevoir and _action_is_psychic_embrace(action):
				return maxf(score, 3200.0) if needs_embrace else minf(score, -900.0)
		if kind == "play_trainer" and _matches(action.get("card", null), DRAW_SUPPORTER_NAMES):
			return minf(score, -2600.0)
		if kind == "attack" \
				and not needs_embrace \
				and action.get("source_slot", player.active_pokemon) == active_gardevoir \
				and _action_is_miracle_force(action, active_gardevoir):
			var attack_score := maxf(score, 3600.0)
			if bool(action.get("projected_knockout", false)):
				attack_score += 900.0
			return attack_score

	if player.deck.size() <= 8 and _best_ready_one_prize_attacker(player) != null:
		if kind == "use_ability" and _action_is_refinement(action):
			return minf(score, -2200.0)
		if kind == "play_trainer" and _matches(action.get("card", null), DRAW_SUPPORTER_NAMES):
			return minf(score, -2200.0)
		if kind == "attack" and _matches(action.get("source_slot", player.active_pokemon), DRIFLOON_NAMES + SCREAM_TAIL_NAMES):
			score = maxf(score, 1400.0)

	if _variant_id == VARIANT_NO_BALLOON:
		if kind == "attach_energy" and action.get("target_slot", null) == player.active_pokemon \
				and _active_needs_retreat_payment(player) \
				and _best_ready_one_prize_attacker(player) != null:
			var energy: CardInstance = action.get("card", null)
			if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == "P":
				return maxf(score, 2000.0)
		if kind == "retreat" and _is_ready_one_prize_attacker(action.get("bench_target", null)):
			return maxf(score, 2400.0)

	if kind == "attach_energy":
		var energy_card: CardInstance = action.get("card", null)
		var target_slot: PokemonSlot = action.get("target_slot", null)
		if _variant_id == VARIANT_RABSCA \
				and target_slot == player.active_pokemon \
				and energy_card != null \
				and energy_card.card_data != null \
				and str(energy_card.card_data.energy_provides) == "P" \
				and _rabsca_engine_preservation_pivot(player) != null:
			return maxf(score, 2600.0)
		if energy_card != null and energy_card.card_data != null \
				and str(energy_card.card_data.energy_provides) == "D" \
				and _matches(target_slot, MUNKIDORI_NAMES, MUNKIDORI_EFFECT_ID) \
				and not _slot_has_energy(target_slot, "D") \
				and _field_has_movable_damage(player):
			return maxf(score, 2300.0)

	if _variant_id == VARIANT_RABSCA:
		var guard_debt := _opponent_has_bench_attack_pressure(game_state, player_index) and not _rabsca_guard_online(player)
		if kind == "use_stadium_effect" \
				and _matches(action.get("card", null), ARTAZON_NAMES, ARTAZON_EFFECT_ID) \
				and player.bench.size() >= 4 \
				and _count_primary_shell_bodies(player) >= 2 \
				and _count_attackers_on_field(player) >= 1:
			return minf(score, -3600.0)
		if kind == "play_basic_to_bench" and _rabsca_should_force_rellor_bench(game_state, player_index) \
				and not _matches(action.get("card", null), RELLOR_NAMES, RELLOR_EFFECT_ID):
			return -100000.0
		if kind == "evolve" and _matches(action.get("card", null), RABSCA_NAMES, RABSCA_EFFECT_ID) \
				and _matches(action.get("target_slot", null), RELLOR_NAMES, RELLOR_EFFECT_ID):
			if guard_debt:
				return maxf(score, 3000.0)
			if _count_attackers_on_field(player) >= 1:
				return minf(score, -4200.0)
			return maxf(score, 950.0)
		if kind == "play_basic_to_bench" and guard_debt and _matches(action.get("card", null), RELLOR_NAMES, RELLOR_EFFECT_ID):
			return maxf(score, 2200.0)
	return score


func _munkidori_source_damage_should_be_preserved(
	slot: PokemonSlot,
	state: GameState,
	player_index: int
) -> bool:
	if _variant_deck_id == NO_BALLOON_DECK_ID \
			and _ready_one_prize_attacker_has_available_knockout(slot, state, player_index):
		return true
	return super._munkidori_source_damage_should_be_preserved(slot, state, player_index)


func _ready_one_prize_attacker_has_available_knockout(
	slot: PokemonSlot,
	state: GameState,
	player_index: int
) -> bool:
	if not _is_ready_one_prize_attacker(slot) \
			or state == null \
			or player_index < 0 \
			or player_index >= state.players.size():
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	var opponent: PlayerState = state.players[opponent_index]
	if opponent == null:
		return false
	var damage := int(predict_attacker_damage(slot).get("damage", 0))
	if damage <= 0:
		return false
	var candidates: Array[PokemonSlot] = []
	if _matches(slot, SCREAM_TAIL_NAMES, SCREAM_TAIL_EFFECT_ID):
		candidates = opponent.get_all_pokemon()
	elif opponent.active_pokemon != null:
		candidates.append(opponent.active_pokemon)
	for candidate: PokemonSlot in candidates:
		if _slot_is_live(candidate) and damage >= candidate.get_remaining_hp():
			return true
	return false


func _no_balloon_attack_takes_final_prizes(
	action: Dictionary,
	state: GameState,
	player_index: int
) -> bool:
	if _is_continuity_final_prize_attack(action, state, player_index):
		return true
	if state == null or player_index < 0 or player_index >= state.players.size():
		return false
	var player: PlayerState = state.players[player_index]
	if player == null or player.prizes.is_empty():
		return false
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	if not _matches(source, SCREAM_TAIL_NAMES, SCREAM_TAIL_EFFECT_ID):
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	var opponent: PlayerState = state.players[opponent_index]
	if opponent == null:
		return false
	var damage := int(predict_attacker_damage(source).get("damage", 0))
	for target: PokemonSlot in opponent.get_all_pokemon():
		if _slot_is_live(target) \
				and damage >= target.get_remaining_hp() \
				and target.get_prize_count() >= player.prizes.size():
			return true
	return false


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var score := super.score_interaction_target(item, step, context)
	var step_id := str(step.get("id", "")).to_lower()
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var player: PlayerState = null
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		player = game_state.players[player_index]

	if step_id == "embrace_target" and item is PokemonSlot and player != null:
		var slot := item as PokemonSlot
		var gardevoir_closeout := _no_balloon_gardevoir_closeout(game_state, player_index)
		if bool(gardevoir_closeout.get("live", false)) and bool(gardevoir_closeout.get("needs_embrace", false)):
			if slot == gardevoir_closeout.get("slot", null):
				return 4000.0
			return minf(score, -1200.0)
		if slot == player.active_pokemon \
				and _active_needs_retreat_payment(player) \
				and _best_ready_one_prize_attacker(player) != null:
			return 2600.0
		var target_slots: Array = context.get("all_items", []) if context.get("all_items", []) is Array else []
		var conversion_target := _no_balloon_embrace_conversion_target(target_slots, game_state, player_index)
		if conversion_target != null:
			if slot == conversion_target:
				return maxf(score, 2800.0)
			return minf(score, 400.0)
		if _is_one_prize_attacker(slot) and _attack_energy_gap(slot) > 0:
			return maxf(score, 1800.0 - float(_attack_energy_gap(slot)) * 100.0)

	if step_id in ["evolution_bench", "tm_evolution_bench"] and item is PokemonSlot:
		if _matches(item, RALTS_NAMES):
			return 1900.0
		if _variant_id == VARIANT_RABSCA and _matches(item, RELLOR_NAMES, RELLOR_EFFECT_ID):
			return 1800.0
		return minf(score, -800.0)
	if step_id in ["evolution_cards", "tm_evolution_cards"] and item is CardInstance:
		if _matches(item, KIRLIA_NAMES, KIRLIA_EFFECT_ID):
			return 1900.0
		if _variant_id == VARIANT_RABSCA and _matches(item, RABSCA_NAMES, RABSCA_EFFECT_ID):
			return 1800.0
		return minf(score, -800.0)

	if item is CardInstance and step_id in ["discard_card", "discard_cards", "discard_energy"]:
		var card := item as CardInstance
		if _variant_id == VARIANT_RABSCA and player != null \
				and _opponent_has_bench_attack_pressure(game_state, player_index) \
				and not _rabsca_guard_online(player) \
				and (_matches(card, RABSCA_NAMES, RABSCA_EFFECT_ID) or _matches(card, RELLOR_NAMES, RELLOR_EFFECT_ID)):
			return -1800.0
		if card.card_data != null and card.card_data.is_energy():
			if str(card.card_data.energy_provides) == "P" and game_state != null:
				var discard_psychic := _count_psychic_energy_in_discard(game_state, player_index)
				return 900.0 if discard_psychic < 3 else 320.0
			if str(card.card_data.energy_provides) == "D" and player != null and _munkidori_needs_darkness(player):
				return -350.0

	if item is CardInstance and step_id in ["search_pokemon", "search_cards", "basic_pokemon", "buddy_poffin_pokemon", "artazon_pokemon"]:
		if _variant_id == VARIANT_RABSCA and player != null \
				and _opponent_has_bench_attack_pressure(game_state, player_index) \
				and not _rabsca_guard_online(player):
			var all_items: Array = context.get("all_items", []) if context.get("all_items", []) is Array else []
			var has_rellor_target := false
			for target: Variant in all_items:
				if _matches(target, RELLOR_NAMES, RELLOR_EFFECT_ID):
					has_rellor_target = true
					break
			if step_id == "artazon_pokemon" and has_rellor_target \
					and _rabsca_guard_debt_allows_rellor_setup(game_state, player_index):
				if _matches(item, RELLOR_NAMES, RELLOR_EFFECT_ID):
					return 10000.0
				if item.card_data != null and item.card_data.is_basic_pokemon():
					return -100000.0
			if _matches(item, RABSCA_NAMES, RABSCA_EFFECT_ID) and _field_has(player, RELLOR_NAMES, RELLOR_EFFECT_ID):
				return 2400.0
			if _matches(item, RELLOR_NAMES, RELLOR_EFFECT_ID):
				return 2100.0
	return score


func pick_embrace_target(target_slots: Array, game_state: GameState = null, player_index: int = -1) -> Variant:
	var gardevoir_closeout := _no_balloon_gardevoir_closeout(game_state, player_index)
	if bool(gardevoir_closeout.get("live", false)) and bool(gardevoir_closeout.get("needs_embrace", false)):
		var active_gardevoir: Variant = gardevoir_closeout.get("slot", null)
		if active_gardevoir in target_slots:
			return active_gardevoir
	var conversion_target := _no_balloon_embrace_conversion_target(target_slots, game_state, player_index)
	if conversion_target != null:
		return conversion_target
	return super.pick_embrace_target(target_slots, game_state, player_index)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	if items.is_empty():
		return []
	var max_select := maxi(1, int(step.get("max_select", 1)))
	var min_select := maxi(0, int(step.get("min_select", 0)))
	var scored: Array[Dictionary] = []
	var full_context := context.duplicate(true)
	full_context["all_items"] = items
	for index: int in items.size():
		scored.append({
			"item": items[index],
			"score": score_interaction_target(items[index], step, full_context),
			"index": index,
		})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", 0.0))
		var right_score := float(right.get("score", 0.0))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var picked: Array = []
	for entry: Dictionary in scored:
		if picked.size() >= max_select:
			break
		if float(entry.get("score", 0.0)) < 0.0 and picked.size() >= min_select:
			continue
		picked.append(entry.get("item"))
	return picked


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var score := super.score_handoff_target(item, step, context)
	if not item is PokemonSlot:
		return score
	var slot := item as PokemonSlot
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _variant_id == VARIANT_RABSCA \
			and game_state != null \
			and player_index >= 0 \
			and player_index < game_state.players.size():
		var player: PlayerState = game_state.players[player_index]
		if slot == _rabsca_engine_preservation_pivot(player):
			return maxf(score, 2700.0)
	if _is_ready_one_prize_attacker(slot):
		return maxf(score, 3000.0)
	if _slot_ready_for_attack(slot) and _slot_is_rule_box(slot):
		return minf(maxf(score, 900.0), 1500.0)
	if _matches(slot, RALTS_NAMES + KIRLIA_NAMES + RELLOR_NAMES + RABSCA_NAMES):
		return minf(score, -600.0)
	return score


func _rabsca_engine_preservation_pivot(player: PlayerState) -> PokemonSlot:
	if player == null or not _matches(player.active_pokemon, GARDEVOIR_NAMES, GARDEVOIR_EFFECT_ID):
		return null
	var retreat_gap := _retreat_gap(player.active_pokemon)
	if retreat_gap < 0 or retreat_gap > 1:
		return null
	for slot: PokemonSlot in player.bench:
		if not _is_one_prize_attacker(slot):
			continue
		if slot.attached_energy.is_empty() or _attack_energy_gap(slot) > 1:
			continue
		return slot
	return null


func _first_opening_match(basics: Array[Dictionary], groups: Array[Array]) -> int:
	for aliases: Array in groups:
		for entry: Dictionary in basics:
			if _matches(entry.get("card", null), aliases):
				return int(entry.get("index", -1))
	return -1


func _append_opening_matches(
	indices: Array[int],
	basics: Array[Dictionary],
	active_index: int,
	aliases: Array[String],
	limit: int
) -> void:
	var added := 0
	for entry: Dictionary in basics:
		var index := int(entry.get("index", -1))
		if index == active_index or index in indices or not _matches(entry.get("card", null), aliases):
			continue
		indices.append(index)
		added += 1
		if added >= limit:
			return


func _matches(value: Variant, aliases: Array[String], effect_id: String = "") -> bool:
	var data: CardData = null
	if value is CardData:
		data = value as CardData
	elif value is CardInstance:
		data = (value as CardInstance).card_data
	elif value is PokemonSlot:
		data = (value as PokemonSlot).get_card_data()
	elif value is Dictionary:
		var entry := value as Dictionary
		if effect_id != "" and str(entry.get("effect_id", "")) == effect_id:
			return true
		return str(entry.get("name", "")) in aliases or str(entry.get("name_en", "")) in aliases
	if data == null:
		return false
	if effect_id != "" and str(data.effect_id) == effect_id:
		return true
	return str(data.name) in aliases or str(data.name_en) in aliases


func _field_has(player: PlayerState, aliases: Array[String], effect_id: String = "") -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches(slot, aliases, effect_id):
			return true
	return false


func _rabsca_guard_online(player: PlayerState) -> bool:
	return _field_has(player, RABSCA_NAMES, RABSCA_EFFECT_ID)


func _rabsca_should_force_rellor_bench(game_state: GameState, player_index: int) -> bool:
	if not _rabsca_guard_debt_allows_rellor_setup(game_state, player_index):
		return false
	var player: PlayerState = game_state.players[player_index]
	for card: CardInstance in player.hand:
		if _matches(card, RELLOR_NAMES, RELLOR_EFFECT_ID):
			return true
	return false


func _rabsca_guard_debt_allows_rellor_setup(game_state: GameState, player_index: int) -> bool:
	if _variant_id != VARIANT_RABSCA \
			or game_state == null \
			or player_index < 0 \
			or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return player != null \
			and not _rabsca_guard_online(player) \
			and _opponent_has_bench_attack_pressure(game_state, player_index) \
			and player.bench.size() < 5


func _no_balloon_gardevoir_closeout(game_state: GameState, player_index: int) -> Dictionary:
	var closed := {"live": false, "needs_embrace": false, "slot": null}
	if _variant_id != VARIANT_NO_BALLOON \
			or game_state == null \
			or player_index < 0 \
			or player_index >= game_state.players.size():
		return closed
	var player: PlayerState = game_state.players[player_index]
	if player == null \
			or player.deck.size() > 8 \
			or not _matches(player.active_pokemon, GARDEVOIR_NAMES, GARDEVOIR_EFFECT_ID) \
			or _field_has(player, DRIFLOON_NAMES, DRIFLOON_EFFECT_ID) \
			or _field_has(player, SCREAM_TAIL_NAMES, SCREAM_TAIL_EFFECT_ID):
		return closed
	var active_gardevoir: PokemonSlot = player.active_pokemon
	var current_prediction := predict_attacker_damage(active_gardevoir)
	if bool(current_prediction.get("can_attack", false)):
		return {"live": true, "needs_embrace": false, "slot": active_gardevoir}
	var after_one_embrace := predict_attacker_damage(active_gardevoir, 1)
	if not bool(after_one_embrace.get("can_attack", false)) \
			or _count_psychic_energy_in_discard(game_state, player_index) <= 0 \
			or not _can_take_more_psychic_embrace_damage(active_gardevoir, game_state):
		return closed
	return {"live": true, "needs_embrace": true, "slot": active_gardevoir}


func _no_balloon_embrace_conversion_target(
	target_slots: Array,
	game_state: GameState,
	player_index: int
) -> PokemonSlot:
	if _variant_id != VARIANT_NO_BALLOON \
			or game_state == null \
			or player_index < 0 \
			or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	var opponent_index := 1 - player_index
	if player == null or opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	var opponent: PlayerState = game_state.players[opponent_index]
	var defender: PokemonSlot = opponent.active_pokemon if opponent != null else null
	var insurance_target: PokemonSlot = null
	var best_attacker: PokemonSlot = null
	var best_tier_gain := 0
	var best_after_tier := 999
	var best_after_damage := -1

	for target_variant: Variant in target_slots:
		if not target_variant is PokemonSlot:
			continue
		var target := target_variant as PokemonSlot
		if not _can_take_more_psychic_embrace_damage(target, game_state):
			continue
		if insurance_target == null and _score_gardevoir_gust_insurance(target, player) > 0.0:
			insurance_target = target
		if defender == null or not _is_one_prize_attacker(target):
			continue
		var current_prediction := predict_attacker_damage(target)
		var after_prediction := predict_attacker_damage(target, 1)
		var current_tier := _attacks_to_defeat_tier(current_prediction, defender.get_remaining_hp())
		var after_tier := _attacks_to_defeat_tier(after_prediction, defender.get_remaining_hp())
		if after_tier >= current_tier:
			continue
		var tier_gain := current_tier - after_tier
		var after_damage := int(after_prediction.get("damage", 0))
		if tier_gain > best_tier_gain \
				or (tier_gain == best_tier_gain and after_tier < best_after_tier) \
				or (tier_gain == best_tier_gain and after_tier == best_after_tier and after_damage > best_after_damage):
			best_attacker = target
			best_tier_gain = tier_gain
			best_after_tier = after_tier
			best_after_damage = after_damage

	return best_attacker if best_attacker != null else insurance_target


func _attacks_to_defeat_tier(prediction: Dictionary, remaining_hp: int) -> int:
	var damage := int(prediction.get("damage", 0))
	if not bool(prediction.get("can_attack", false)) or damage <= 0 or remaining_hp <= 0:
		return 999
	return ceili(float(remaining_hp) / float(damage))


func _opponent_has_bench_attack_pressure(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null:
		return false
	for attack_variant: Variant in opponent.active_pokemon.get_card_data().attacks:
		if not attack_variant is Dictionary:
			continue
		var attack := attack_variant as Dictionary
		if _attack_has_structured_opponent_bench_damage(attack):
			return true
		var text := (str(attack.get("name", "")) + " " + str(attack.get("text", ""))).to_lower()
		if _attack_text_targets_opponent_bench(text):
			return true
	return false


func _attack_has_structured_opponent_bench_damage(attack: Dictionary) -> bool:
	for key: String in [
		"damage_target", "damage_targets", "damage_target_type",
		"damage_counter_target", "damage_counter_targets", "counter_target", "counter_targets",
	]:
		if attack.has(key) and _structured_target_is_opponent_bench(attack.get(key)):
			return true

	var has_printed_damage := not str(attack.get("damage", "")).strip_edges() in ["", "0", "-"]
	if not has_printed_damage:
		return false
	for key: String in ["target", "targets", "target_type"]:
		if attack.has(key) and _structured_target_is_opponent_bench(attack.get(key)):
			return true
	return bool(attack.get("targets_opponent_bench", false))


func _structured_target_is_opponent_bench(target: Variant) -> bool:
	var encoded := JSON.stringify(target).to_lower()
	encoded = encoded.replace("_", " ").replace("-", " ").replace("’", "'")
	var is_opponent := "opponent" in encoded or "对手" in encoded
	var is_bench := "bench" in encoded or "备战" in encoded
	return is_opponent and is_bench


func _attack_text_targets_opponent_bench(text: String) -> bool:
	var normalized := text.replace("’", "'").replace("é", "e")
	if _attack_text_scales_active_damage_by_bench_count(normalized):
		return false
	var targets_opponent_bench := (
		"opponent's benched pokemon" in normalized
		or "opponents' benched pokemon" in normalized
		or "opponent's bench" in normalized
		or "对手的备战宝可梦" in normalized
		or "对手备战宝可梦" in normalized
		or "对手的备战区" in normalized
		or "对手备战区" in normalized
	)
	var deals_damage_or_counters := (
		"damage" in normalized
		or "伤害" in normalized
		or "伤害指示物" in normalized
	)
	return targets_opponent_bench and deals_damage_or_counters


func _attack_text_scales_active_damage_by_bench_count(text: String) -> bool:
	var mentions_bench := "bench" in text or "备战" in text
	if not mentions_bench:
		return false
	for marker: String in [
		"for each benched pokemon",
		"for each of your benched pokemon",
		"for each of your opponent's benched pokemon",
		"for each pokemon on your bench",
		"for each pokemon on your opponent's bench",
		"number of benched pokemon",
		"number of your benched pokemon",
		"number of your opponent's benched pokemon",
	]:
		if marker in text:
			return true
	var compact := text.replace(" ", "")
	return "备战宝可梦数量" in compact or "备战区宝可梦数量" in compact


func _best_ready_one_prize_attacker(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	var best: PokemonSlot = null
	var best_damage := -1
	for slot: PokemonSlot in player.get_all_pokemon():
		if not _is_ready_one_prize_attacker(slot):
			continue
		var damage := _printed_damage(slot)
		if damage > best_damage:
			best = slot
			best_damage = damage
	return best


func _is_ready_one_prize_attacker(value: Variant) -> bool:
	return value is PokemonSlot and _is_one_prize_attacker(value as PokemonSlot) and _slot_ready_for_attack(value as PokemonSlot)


func _is_one_prize_attacker(slot: PokemonSlot) -> bool:
	return _matches(slot, DRIFLOON_NAMES, DRIFLOON_EFFECT_ID) or _matches(slot, SCREAM_TAIL_NAMES, SCREAM_TAIL_EFFECT_ID)


func _slot_ready_for_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var effect_id := str(slot.get_card_data().effect_id)
	if effect_id in [DRIFLOON_EFFECT_ID, SCREAM_TAIL_EFFECT_ID]:
		var prediction := super.predict_attacker_damage(slot)
		return bool(prediction.get("can_attack", false)) and int(prediction.get("damage", 0)) > 0
	return _attack_energy_gap(slot) == 0 and _printed_damage(slot) > 0


func _attack_energy_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	var best_gap := 999
	for attack_variant: Variant in slot.get_card_data().attacks:
		if attack_variant is Dictionary:
			var cost := str((attack_variant as Dictionary).get("cost", ""))
			best_gap = mini(best_gap, maxi(0, cost.length() - slot.attached_energy.size()))
	return best_gap


func _printed_damage(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	var best := 0
	for attack_variant: Variant in slot.get_card_data().attacks:
		if not attack_variant is Dictionary:
			continue
		var digits := ""
		for character: String in str((attack_variant as Dictionary).get("damage", "")):
			if character >= "0" and character <= "9":
				digits += character
			elif not digits.is_empty():
				break
		if not digits.is_empty():
			best = maxi(best, int(digits))
	return best


func _active_needs_retreat_payment(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	if _is_ready_one_prize_attacker(player.active_pokemon):
		return false
	return _retreat_gap(player.active_pokemon) > 0


func _retreat_gap(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 999
	return maxi(0, int(slot.get_card_data().retreat_cost) - slot.attached_energy.size())


func _slot_has_energy(slot: PokemonSlot, energy_type: String) -> bool:
	if slot == null:
		return false
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null and str(energy.card_data.energy_provides) == energy_type:
			return true
	return false


func _field_has_movable_damage(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.damage_counters > 0:
			return true
	return false


func _munkidori_needs_darkness(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches(slot, MUNKIDORI_NAMES, MUNKIDORI_EFFECT_ID) and not _slot_has_energy(slot, "D"):
			return true
	return false


func _slot_is_rule_box(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var mechanic := str(slot.get_card_data().mechanic).to_lower()
	var name := (str(slot.get_card_data().name) + " " + str(slot.get_card_data().name_en)).to_lower()
	return mechanic in ["ex", "v", "vmax", "vstar", "gx"] or " ex" in name or name.ends_with("ex")


func _action_is_refinement(action: Dictionary) -> bool:
	if _matches(action.get("source_slot", null), KIRLIA_NAMES, KIRLIA_EFFECT_ID):
		return true
	var ability_name := str(action.get("ability_name", ""))
	return ability_name in REFINEMENT_NAMES


func _action_is_psychic_embrace(action: Dictionary) -> bool:
	var ability_name := str(action.get("ability_name", ""))
	return ability_name == "" or ability_name in PSYCHIC_EMBRACE_NAMES


func _action_is_miracle_force(action: Dictionary, source_slot: PokemonSlot) -> bool:
	var attack_name := str(action.get("attack_name", ""))
	if attack_name in MIRACLE_FORCE_NAMES:
		return true
	if source_slot == null or source_slot.get_card_data() == null:
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attacks: Array = source_slot.get_card_data().attacks
	return attack_index >= 0 \
		and attack_index < attacks.size() \
		and str((attacks[attack_index] as Dictionary).get("name", "")) in MIRACLE_FORCE_NAMES


func _attack_cost_is_met(slot: PokemonSlot, cost: String, extra_psychic: int = 0) -> bool:
	if slot == null:
		return false
	var normalized_cost := CardData.normalize_attack_cost(cost)
	var required_psychic := 0
	for symbol: String in normalized_cost:
		if symbol == "P":
			required_psychic += 1
	var psychic_units := maxi(0, extra_psychic)
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null or not energy.card_data.is_energy():
			continue
		var provides := str(energy.card_data.energy_provides)
		if provides == "":
			provides = str(energy.card_data.energy_type)
		if provides == "ANY" or provides.contains("P"):
			psychic_units += 1
	return slot.attached_energy.size() + maxi(0, extra_psychic) >= normalized_cost.length() \
		and psychic_units >= required_psychic


func _slot_display_name(slot: PokemonSlot) -> String:
	if slot == null or slot.get_card_data() == null:
		return ""
	var data := slot.get_card_data()
	return str(data.name) if str(data.name) != "" else str(data.name_en)
