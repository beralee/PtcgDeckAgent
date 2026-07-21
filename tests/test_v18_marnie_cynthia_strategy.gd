class_name TestV18MarnieCynthiaStrategy
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18MarnieCynthia.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const MARNIE_DECK_ID := 800018501
const CYNTHIA_DECK_ID := 800018543


func test_real_decks_anchor_the_expected_cards_and_effect_ids() -> String:
	var marnie := _load_deck(MARNIE_DECK_ID)
	var cynthia := _load_deck(CYNTHIA_DECK_ID)
	return run_checks([
		assert_not_null(marnie, "The real 18.0 Marnie deck should load"),
		assert_not_null(cynthia, "The real 18.0 Cynthia deck should load"),
		assert_eq(marnie.total_cards if marnie != null else 0, 60, "Marnie must remain a 60-card built-in deck"),
		assert_eq(cynthia.total_cards if cynthia != null else 0, 60, "Cynthia must remain a 60-card built-in deck"),
		assert_eq(_deck_effect_id(marnie, "CSV10C", "148"), "863479acd128e1e5e2643a3a1e77ce26", "Marnie strategy must anchor the real Punk Up print"),
		assert_eq(_deck_effect_id(marnie, "CSV7C", "059"), "f27a2982c03f5b49a68ec0a77a2d6e48", "Marnie strategy must recognize the real Froslass engine"),
		assert_eq(_deck_effect_id(cynthia, "CSV10C", "112"), "23e6f24fc40bdb19384bc3c7822beea1", "Cynthia strategy must anchor King's Call"),
		assert_eq(_deck_effect_id(cynthia, "CSV10C", "113"), "b494c15a64405edbc24ed017733ad8a5", "Cynthia strategy must anchor both Garchomp attacks"),
		assert_eq(_deck_effect_id(cynthia, "CSV10C", "138"), "3c4ab79ab7320fa3a57639e232f507e9", "Cynthia strategy must anchor Spiritomb's counter scaling"),
	])


func test_both_decks_share_one_normal_and_strong_mode_decision_contract() -> String:
	var checks: Array[String] = []
	for deck_id: int in [MARNIE_DECK_ID, CYNTHIA_DECK_ID]:
		var normal := _strategy_for_deck(deck_id)
		var strong := _strategy_for_deck(deck_id)
		var state := _make_state()
		var normal_plan: Dictionary = normal.call("build_turn_plan", state, 0, {"opening_mode": "normal"})
		var strong_plan: Dictionary = strong.call("build_turn_plan", state, 0, {"opening_mode": "strong"})
		checks.append(assert_eq(normal.call("get_strategy_id"), strong.call("get_strategy_id"), "Normal and strong setup must use the same family policy"))
		checks.append(assert_eq(normal_plan.get("owner", {}), strong_plan.get("owner", {}), "Fixed opening must not fork route ownership"))
		checks.append(assert_true(str(normal_plan.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "The delegate must emit a V18 phase"))
		checks.append(assert_true(normal_plan.get("constraints", {}) is Dictionary, "The delegate must expose shared safety constraints"))
	return run_checks(checks)


func test_marnie_opening_uses_budew_and_keeps_both_engines() -> String:
	var strategy := _strategy_for_deck(MARNIE_DECK_ID)
	var player := PlayerState.new()
	player.hand.assign([
		_instance(_load_card("CSV10C_146")),
		_instance(_load_card("CSV9.5C_043")),
		_instance(_load_card("CSV8C_094")),
		_instance(_load_card("CSV9.5C_004")),
		_instance(_load_card("CSV10C_007")),
	])
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active := _hand_card_name(player, int(plan.get("active_hand_index", -1)))
	var bench_names := _hand_card_names(player, plan.get("bench_hand_indices", []))
	return run_checks([
		assert_eq(active, "含羞苞", "Budew should absorb the opening Active slot"),
		assert_true("玛俐的捣蛋小妖" in bench_names, "The Grimmsnarl seed must be benched"),
		assert_true("雪童子" in bench_names, "The Froslass damage engine must be benched"),
		assert_true("愿增猿" in bench_names, "The damage-transfer route must be retained"),
		assert_true(bench_names.size() <= 4, "Opening setup should preserve one Bench slot for later rebuilding"),
	])


func test_continuity_alias_lists_are_flat_runtime_strings() -> String:
	var checks: Array[String] = []
	for deck_id: int in [MARNIE_DECK_ID, CYNTHIA_DECK_ID]:
		var strategy := _strategy_for_deck(deck_id)
		var state := _make_state()
		var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
		for rule_variant: Variant in contract.get("action_bonuses", []):
			var rule: Dictionary = rule_variant
			for key: String in ["card_names", "target_names"]:
				for alias_variant: Variant in rule.get(key, []):
					checks.append(assert_true(alias_variant is String, "Continuity aliases for deck %d must be flat strings" % deck_id))
	return run_checks(checks)


func test_cynthia_opening_uses_budew_and_builds_two_real_evolution_routes() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var player := PlayerState.new()
	player.hand.assign([
		_instance(_load_card("CSV10C_111")),
		_instance(_load_card("CSV10C_004")),
		_instance(_load_card("CSV8C_094")),
		_instance(_load_card("CSV10C_138")),
		_instance(_load_card("CSV9.5C_004")),
	])
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active := _hand_card_name(player, int(plan.get("active_hand_index", -1)))
	var bench_names := _hand_card_names(player, plan.get("bench_hand_indices", []))
	return run_checks([
		assert_eq(active, "含羞苞", "Budew should be the low-cost opening pivot"),
		assert_true("竹兰的圆陆鲨" in bench_names, "The Garchomp line must start on Bench"),
		assert_true("竹兰的毒蔷薇" in bench_names, "The Roserade damage line must start on Bench"),
		assert_true("愿增猿" in bench_names, "The Darkness-energy utility route should remain available"),
		assert_true(bench_names.size() <= 4, "Opening setup should not fill all five Bench slots"),
	])


func test_marnie_evolution_and_punk_up_complete_two_dd_routes() -> String:
	var strategy := _strategy_for_deck(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var grimmsnarl := _slot(_load_card("CSV10C_148"))
	var impidimp := _slot(_load_card("CSV10C_146"))
	player.active_pokemon = grimmsnarl
	player.bench.append(impidimp)
	var darkness: Array = []
	for index: int in 5:
		darkness.append(_instance(_energy("基本恶能量 %d" % index, "D")))
		player.deck.append(darkness[-1])
	var picked: Array = strategy.call("pick_interaction_items", darkness, {
		"id": "marnies_punk_up_assignments", "max_select": 5,
	}, {"game_state": state, "player_index": 0})
	var first_score: float = strategy.call("score_interaction_target", {
		"source": darkness[0], "target": grimmsnarl,
	}, {"id": "marnies_punk_up_assignments"}, {"game_state": state, "player_index": 0})
	var backup_score: float = strategy.call("score_interaction_target", {
		"source": darkness[0], "target": impidimp,
	}, {"id": "marnies_punk_up_assignments"}, {
		"game_state": state, "player_index": 0,
		"pending_assignment_counts": {grimmsnarl.get_instance_id(): 2},
	})
	var funded_score: float = strategy.call("score_interaction_target", {
		"source": darkness[0], "target": grimmsnarl,
	}, {"id": "marnies_punk_up_assignments"}, {
		"game_state": state, "player_index": 0,
		"pending_assignment_counts": {grimmsnarl.get_instance_id(): 2},
	})
	return run_checks([
		assert_eq(picked.size(), 4, "Punk Up should select only the four Energy needed for two DD routes"),
		assert_true(first_score >= 4500.0, "The current Grimmsnarl must receive the first Punk Up Energy"),
		assert_true(backup_score >= funded_score + 1800.0, "Punk Up must move to the backup line after DD is complete"),
	])


func test_marnie_search_and_discard_protect_the_live_stage2_bridge() -> String:
	var strategy := _strategy_for_deck(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_load_card("CSV10C_146"))
	player.hand.append(_instance(_load_card("CSVH1C_045")))
	var grimmsnarl := _instance(_load_card("CSV10C_148"))
	var morgrem := _instance(_load_card("CSV10C_147"))
	var filler := _instance(_load_card("CSV8C_094"))
	var picked: Array = strategy.call("pick_interaction_items", [filler, morgrem, grimmsnarl], {
		"id": "spikemuth_gym_marnies_pokemon", "max_select": 1,
	}, {"game_state": state, "player_index": 0})
	var candy := player.hand[0]
	var supporter := _instance(_trainer("博士的研究", "Supporter"))
	return run_checks([
		assert_true(picked.size() == 1 and picked[0] == grimmsnarl, "Spikemuth should finish the live Rare Candy route"),
		assert_true(int(strategy.call("get_discard_priority_contextual", candy, state, 0)) < int(strategy.call("get_discard_priority_contextual", supporter, state, 0)), "The only live Rare Candy must survive discard costs"),
	])


func test_marnie_froslass_and_munkidori_wait_until_the_attacker_is_funded() -> String:
	var strategy := _strategy_for_deck(MARNIE_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var grimmsnarl := _slot(_load_card("CSV10C_148"))
	var munkidori := _slot(_load_card("CSV8C_094"))
	player.active_pokemon = grimmsnarl
	player.bench.append(munkidori)
	var darkness := _instance(_energy("基本恶能量", "D"))
	var attacker_before: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": grimmsnarl}, state, 0)
	var utility_before: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}, state, 0)
	grimmsnarl.attached_energy.assign([_instance(_energy("恶1", "D")), _instance(_energy("恶2", "D"))])
	var utility_after: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}, state, 0)
	return run_checks([
		assert_true(attacker_before >= utility_before + 1800.0, "Manual attachment must fund Shadow Bullet before Adrena-Brain"),
		assert_true(utility_after >= utility_before + 900.0, "Munkidori should receive Darkness only after the attacker is ready"),
		assert_true(int(strategy.call("get_search_priority", _instance(_load_card("CSV7C_059")))) >= 800, "The real Froslass line must remain a high-priority search"),
	])


func test_cynthias_kings_call_finishes_the_live_chain_before_padding() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.append(_slot(_load_card("CSV10C_112")))
	var garchomp := _instance(_load_card("CSV10C_113"))
	var spiritomb := _instance(_load_card("CSV10C_138"))
	var garchomp_score: float = strategy.call("score_interaction_target", garchomp, {"id": "csv10c_named_pokemon_search"}, {"game_state": state, "player_index": 0})
	var spiritomb_score: float = strategy.call("score_interaction_target", spiritomb, {"id": "csv10c_named_pokemon_search"}, {"game_state": state, "player_index": 0})
	return assert_true(garchomp_score >= spiritomb_score + 1800.0, "King's Call must complete Garchomp before adding a situational attacker")


func test_cynthia_energy_route_funds_garchomp_before_munkidori() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	var munkidori := _slot(_load_card("CSV8C_094"))
	player.active_pokemon = garchomp
	player.bench.append(munkidori)
	var fighting := _instance(_load_card("CSVE1C_FIG"))
	var luminous := _instance(_load_card("CSV1C_127"))
	var fight_route: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": fighting, "target_slot": garchomp}, state, 0)
	var utility_before: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": luminous, "target_slot": munkidori}, state, 0)
	garchomp.attached_energy.append(fighting)
	var utility_after: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": luminous, "target_slot": munkidori}, state, 0)
	return run_checks([
		assert_true(fight_route >= utility_before + 1700.0, "Garchomp's Fighting route must be funded before Munkidori"),
		assert_true(utility_after >= utility_before + 800.0, "Luminous Energy should open Munkidori only after Garchomp can attack"),
		assert_true(bool(strategy.call("_energy_pays", luminous, "F", garchomp)), "The real Luminous effect ID must pay Fighting while unsuppressed"),
		assert_true(bool(strategy.call("_energy_pays", luminous, "D", munkidori)), "The real Luminous effect ID must pay Darkness while unsuppressed"),
	])


func test_cynthia_tm_and_power_weight_target_the_real_evolution_lane() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var gible := _slot(_load_card("CSV10C_111"))
	var roselia := _slot(_load_card("CSV10C_004"))
	var budew := _slot(_load_card("CSV9.5C_004"))
	var gabite := _instance(_load_card("CSV10C_112"))
	var garchomp := _slot(_load_card("CSV10C_113"))
	var power_weight := _instance(_load_card("CSV10C_200"))
	var state := _make_state()
	state.players[0].active_pokemon = garchomp
	var weight_score: float = strategy.call("score_action_absolute", {"kind": "attach_tool", "card": power_weight, "target_slot": garchomp}, state, 0)
	return run_checks([
		assert_true(float(strategy.call("score_interaction_target", gible, {"id": "evolution_bench"}, {})) > float(strategy.call("score_interaction_target", budew, {"id": "evolution_bench"}, {})) + 1800.0, "TM Evolution should target Gible"),
		assert_true(float(strategy.call("score_interaction_target", roselia, {"id": "evolution_bench"}, {})) > float(strategy.call("score_interaction_target", budew, {"id": "evolution_bench"}, {})) + 1200.0, "TM Evolution should also preserve the Roserade line"),
		assert_true(float(strategy.call("score_interaction_target", gabite, {"id": "evolution_cards"}, {})) >= 4000.0, "TM Evolution should choose the real Gabite"),
		assert_true(weight_score >= 3800.0, "Cynthia's real +70 HP Tool should prefer Garchomp"),
	])


func test_cynthia_attack_policy_uses_spiral_draw_and_preserves_dragon_blast_rebuild() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var garchomp := _slot(_load_card("CSV10C_113"))
	player.active_pokemon = garchomp
	garchomp.attached_energy.assign([_instance(_energy("斗1", "F")), _instance(_energy("斗2", "F"))])
	for index: int in 20:
		player.deck.append(_instance(_trainer("牌库卡 %d" % index, "Item")))
	player.hand.assign([_instance(_trainer("手牌", "Item"))])
	var spiral: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": garchomp, "attack_index": 0, "attack_name": "螺旋俯冲", "projected_damage": 100}, state, 0)
	var blast_without_rebuild: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": garchomp, "attack_index": 1, "attack_name": "龙之爆破", "projected_damage": 260, "projected_knockout": false}, state, 0)
	var ko_blast: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": garchomp, "attack_index": 1, "attack_name": "龙之爆破", "projected_damage": 260, "projected_knockout": true}, state, 0)
	return run_checks([
		assert_true(spiral > blast_without_rebuild, "Spiral Dive should preserve Energy and refill a small hand when 260 does not convert"),
		assert_true(ko_blast > spiral + 900.0, "Dragon Blast should convert a knockout despite its discard cost"),
	])


func test_spiritomb_prediction_reads_real_benched_cynthia_damage() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var spiritomb := _slot(_load_card("CSV10C_138"))
	spiritomb.attached_energy.append(_instance(_load_card("CSV1C_127")))
	player.active_pokemon = spiritomb
	var gible := _slot(_load_card("CSV10C_111"))
	var roselia := _slot(_load_card("CSV10C_004"))
	gible.damage_counters = 60
	roselia.damage_counters = 30
	player.bench.assign([gible, roselia])
	strategy.call("build_turn_plan", state, 0, {})
	var prediction: Dictionary = strategy.call("predict_attacker_damage", spiritomb)
	return run_checks([
		assert_eq(int(prediction.get("damage", 0)), 90, "Spiritomb should deal 10 per real damage counter on Benched Cynthia Pokemon"),
		assert_true(bool(prediction.get("can_attack", false)), "One Colorless-paying Energy should make Angry Spell live"),
	])


func test_low_deck_guards_stop_optional_draw_and_engine_churn() -> String:
	var marnie := _strategy_for_deck(MARNIE_DECK_ID)
	var marnie_state := _make_state()
	var impidimp := _slot(_load_card("CSV10C_146"))
	marnie_state.players[0].active_pokemon = impidimp
	_fill_deck(marnie_state.players[0], 4)
	var draw_attack: float = marnie.call("score_action_absolute", {"kind": "attack", "source_slot": impidimp, "attack_index": 0, "attack_name": "骗取"}, marnie_state, 0)
	var cynthia := _strategy_for_deck(CYNTHIA_DECK_ID)
	var cynthia_state := _make_state()
	var garchomp := _slot(_load_card("CSV10C_113"))
	garchomp.attached_energy.append(_instance(_energy("基本斗能量", "F")))
	cynthia_state.players[0].active_pokemon = garchomp
	_fill_deck(cynthia_state.players[0], 5)
	var draw_choice: float = cynthia.call("score_interaction_target", "draw", {"id": "draw_to_hand_size_choice"}, {"game_state": cynthia_state, "player_index": 0})
	var skip_choice: float = cynthia.call("score_interaction_target", "skip", {"id": "draw_to_hand_size_choice"}, {"game_state": cynthia_state, "player_index": 0})
	var research_score: float = cynthia.call("score_action_absolute", {"kind": "play_trainer", "card": _instance(_trainer("博士的研究", "Supporter"))}, cynthia_state, 0)
	return run_checks([
		assert_true(draw_attack < 0.0, "Impidimp must stop optional deck draw near deck-out"),
		assert_true(skip_choice >= draw_choice + 1500.0, "Spiral Dive must skip its optional draw in a low deck"),
		assert_true(research_score <= -1800.0, "Low-deck policy must suppress generic redraw churn"),
	])


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", _load_deck(deck_id))
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%d.json" % [DECK_DIR, deck_id]))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _load_card(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _deck_effect_id(deck: DeckData, set_code: String, card_index: String) -> String:
	if deck == null:
		return ""
	for entry: Dictionary in deck.cards:
		if str(entry.get("set_code", "")) == set_code and str(entry.get("card_index", "")) == card_index:
			return str(entry.get("effect_id", ""))
	return ""


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _slot(card_data: CardData) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(_instance(card_data))
	return result


func _instance(card_data: CardData) -> CardInstance:
	return CardInstance.create(card_data, 0)


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return card


func _trainer(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.name_zh = name
	card.card_type = card_type
	return card


func _hand_card_name(player: PlayerState, index: int) -> String:
	if index < 0 or index >= player.hand.size() or player.hand[index] == null or player.hand[index].card_data == null:
		return ""
	return player.hand[index].card_data.name


func _hand_card_names(player: PlayerState, indices: Array) -> Array[String]:
	var names: Array[String] = []
	for raw_index: Variant in indices:
		var name := _hand_card_name(player, int(raw_index))
		if name != "":
			names.append(name)
	return names


func _fill_deck(player: PlayerState, count: int) -> void:
	for index: int in count:
		player.deck.append(_instance(_trainer("低牌库卡 %d" % index, "Item")))
