class_name TestV18BlazikenDragapultStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategyV18BlazikenDragapult.gd"
const DECK_DIR := "res://data/bundled_user/decks"
const FIXED_ORDER_DIR := "res://data/bundled_user/ai_fixed_deck_orders"
const SINGLE_PRIZE_BLAZIKEN_EFFECT_ID := "d66a01f98e15b770b2c4bd1372382d4c"

const FAMILY_DECK_IDS: Array[int] = [18000625, 800015734, 800019125]


func test_blaziken_dragapult_family_configures_all_three_exact_decks() -> String:
	var checks: Array[String] = []
	for deck_id: int in FAMILY_DECK_IDS:
		var strategy := _new_strategy(deck_id)
		checks.append(assert_not_null(strategy, "Dedicated delegate should instantiate for deck %d" % deck_id))
		if strategy == null:
			continue
		checks.append(assert_eq(
			str(strategy.call("get_strategy_id")),
			"v18_blaziken_dragapult_%d" % deck_id,
			"The delegate must retain exact deck identity"
		))
		checks.append(assert_true(deck_id in strategy.call("get_supported_deck_ids"), "The exact deck should be declared supported"))
		var state := _make_state()
		if deck_id == 18000625:
			state.players[0].active_pokemon = _slot(_card("CSV9C", "127"))
			state.players[0].bench.append(_slot(_card("CSV10C", "036")))
		else:
			state.players[0].active_pokemon = _slot(_card("CSV9.5C", "004"))
			state.players[0].bench.append(_slot(_card("CSV8C", "157")))
		var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {"prompt_kind": "action_selection"})
		checks.append(assert_true(bool(plan.get("flags", {}).get("blaziken_dragapult_delegate", false)), "All three plans should identify the dedicated delegate"))
		checks.append(assert_true(plan.get("owner", {}) is Dictionary, "The plan should expose turn ownership"))
		checks.append(assert_true(plan.get("constraints", {}) is Dictionary, "The plan should expose safety constraints"))
	return run_checks(checks)


func test_blaziken_dragapult_family_reads_real_effect_ids_from_all_three_decks() -> String:
	var munkidori_deck := _load_deck(18000625)
	var dusknoir_deck := _load_deck(800015734)
	var dragapult_deck := _load_deck(800019125)
	return run_checks([
		assert_true(_deck_has_effect(munkidori_deck, "15eb5f310fd523c4c468e4519e30ae70"), "Munkidori/Blaziken must load real Boiling Spirit Blaziken ex"),
		assert_true(_deck_has_effect(munkidori_deck, "66fee12502043db7d92b97b0d62b0f59"), "Munkidori/Blaziken must load real Adrena-Brain"),
		assert_true(_deck_has_effect(dusknoir_deck, "2a4178f21ba2bf13285bbb43ecaaa472"), "Dusknoir/Dragapult must load real Curse Blast"),
		assert_true(_deck_has_effect(dragapult_deck, "52a205820de799a53a689f23cbeb8622"), "Blaziken/Dragapult must load real Phantom Dive"),
	])


func test_blaziken_dragapult_strong_openings_keep_engine_seeds_off_the_active() -> String:
	var checks: Array[String] = []
	var expected := {
		18000625: {"active": "桃歹郎", "bench": ["火稚鸡", "愿增猿"]},
		800015734: {"active": "含羞苞", "bench": ["多龙梅西亚", "夜巡灵"]},
		800019125: {"active": "含羞苞", "bench": ["多龙梅西亚", "火稚鸡"]},
	}
	for deck_id: int in FAMILY_DECK_IDS:
		var strategy := _new_strategy(deck_id)
		var player := _fixed_opening_player(deck_id)
		checks.append(assert_not_null(player, "Deck %d should expose a legal strong opening" % deck_id))
		if strategy == null or player == null:
			continue
		var plan: Dictionary = strategy.call("plan_opening_setup", player)
		var active_index := int(plan.get("active_hand_index", -1))
		var bench_indices: Array = plan.get("bench_hand_indices", [])
		var expectation: Dictionary = expected[deck_id]
		checks.append(assert_eq(_hand_name(player, active_index), str(expectation["active"]), "Strong opening should preserve the intended pivot"))
		for bench_name: String in expectation["bench"]:
			checks.append(assert_true(_bench_contains(player, bench_indices, bench_name), "Strong opening should Bench %s for deck %d" % [bench_name, deck_id]))
	return run_checks(checks)


func test_munkidori_blaziken_uses_manual_first_player_and_tm_second_player_routes() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var pivot := _slot(_card("CSV9C", "127"))
	var torchic := _slot(_card("CSV10C", "036"))
	player.active_pokemon = pivot
	player.bench.append(torchic)
	player.deck.append(CardInstance.create(_card("CSV10C", "037"), 0))
	var tm := CardInstance.create(_card("CSV5C", "119"), 0)
	state.turn_number = 1
	state.first_player_index = 0
	var first_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": pivot,
	}, state, 0)
	state.turn_number = 2
	state.first_player_index = 1
	var second_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": pivot,
	}, state, 0)
	pivot.attached_tool = tm
	pivot.attached_energy.append(CardInstance.create(_energy("基本火能量", "R"), 0))
	var tm_attack_score: float = strategy.call("score_action_absolute", {
		"kind": "granted_attack",
		"source_slot": pivot,
		"granted_attack_data": {"id": "tm_evolution", "name": "进化", "cost": "C", "damage": ""},
	}, state, 0)
	return run_checks([
		assert_true(first_score <= -1800.0, "Going first must not spend TM Evolution before attacks are legal (score=%f)" % first_score),
		assert_true(second_score >= first_score + 6000.0, "Going second should attach TM to the pivot for immediate evolution"),
		assert_true(tm_attack_score >= 6000.0, "The second-player TM attack should execute while Torchic has a real Combusken target"),
	])


func test_munkidori_blaziken_searches_only_a_live_next_stage() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	player.active_pokemon = _slot(_card("CSV9C", "127"))
	player.bench.append(_slot(_card("CSV10C", "036")))
	var combusken := CardInstance.create(_card("CSV10C", "037"), 0)
	var blaziken_ex := CardInstance.create(_card("CSV7C", "038"), 0)
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "search_pokemon", "max_select": 1}
	var combusken_without_candy: float = strategy.call("score_interaction_target", combusken, step, context)
	var blaziken_without_candy: float = strategy.call("score_interaction_target", blaziken_ex, step, context)
	player.hand.append(CardInstance.create(_card("CSVH1C", "045"), 0))
	var blaziken_with_candy: float = strategy.call("score_interaction_target", blaziken_ex, step, context)
	return run_checks([
		assert_true(combusken_without_candy >= blaziken_without_candy + 4000.0, "Without Rare Candy, search should fetch playable Combusken before dead Stage 2"),
		assert_true(blaziken_with_candy >= combusken_without_candy, "A live Rare Candy should promote Blaziken ex to the immediate engine piece"),
	])


func test_boiling_spirit_prioritizes_dark_munkidori_then_attack_completion() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var blaziken := _slot(_card("CSV7C", "038"))
	var munkidori := _slot(_card("CSV8C", "094"))
	var damaged := _slot(_card("CSV9C", "127"))
	damaged.damage_counters = 40
	player.active_pokemon = damaged
	player.bench.assign([blaziken, munkidori])
	var dark := CardInstance.create(_energy("基本恶能量", "D"), 0)
	var fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	player.discard_pile.assign([dark, fire])
	var context := {"game_state": state, "player_index": 0}
	var dark_score: float = strategy.call("score_interaction_target", dark, {"id": "attach_basic_energy_from_discard"}, context)
	var fire_score: float = strategy.call("score_interaction_target", fire, {"id": "attach_basic_energy_from_discard"}, context)
	var dark_target_context := {"game_state": state, "player_index": 0, "assignment_source": dark}
	var munkidori_target_score: float = strategy.call("score_interaction_target", munkidori, {"id": "attach_basic_energy_from_discard"}, dark_target_context)
	var blaziken_target_score: float = strategy.call("score_interaction_target", blaziken, {"id": "attach_basic_energy_from_discard"}, dark_target_context)
	var boiling_spirit_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": blaziken, "ability_index": 0,
	}, state, 0)
	return run_checks([
		assert_true(dark_score >= fire_score + 500.0, "Boiling Spirit should first switch on Adrena-Brain while damage is movable"),
		assert_true(munkidori_target_score >= blaziken_target_score + 1500.0, "Recovered Darkness should attach to unpowered Munkidori"),
		assert_true(boiling_spirit_score >= 5000.0, "Real Boiling Spirit should be a priority while discard Energy and route debt exist"),
	])


func test_munkidori_moves_damage_from_primary_attacker_to_exact_prize() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var blaziken := _slot(_card("CSV7C", "038"))
	blaziken.damage_counters = 40
	var support := _slot(_card("CSV9C", "127"))
	support.damage_counters = 30
	var munkidori := _slot(_card("CSV8C", "094"))
	munkidori.attached_energy.append(CardInstance.create(_energy("基本恶能量", "D"), 0))
	player.active_pokemon = blaziken
	player.bench.assign([support, munkidori])
	var exact_target := _slot(_pokemon("Exact support", 100), 1)
	exact_target.damage_counters = 70
	var healthy_ex := _slot(_pokemon("Healthy ex", 220, "ex"), 1)
	opponent.active_pokemon = healthy_ex
	opponent.bench.append(exact_target)
	var context := {"game_state": state, "player_index": 0}
	var blaziken_source: float = strategy.call("score_interaction_target", blaziken, {"id": "source_pokemon"}, context)
	var support_source: float = strategy.call("score_interaction_target", support, {"id": "source_pokemon"}, context)
	var exact_score: float = strategy.call("score_interaction_target", exact_target, {"id": "target_damage_counters"}, context)
	var healthy_score: float = strategy.call("score_interaction_target", healthy_ex, {"id": "target_damage_counters"}, context)
	var ability_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": munkidori, "ability_index": 0,
	}, state, 0)
	return run_checks([
		assert_true(blaziken_source >= support_source + 1000.0, "Adrena-Brain should heal the damaged two-prize attacker before support"),
		assert_true(exact_score >= healthy_score + 5000.0, "Thirty moved damage should take an exact prize before speculative spread"),
		assert_true(ability_score >= 5000.0, "Powered Munkidori should use Adrena-Brain when an exact target exists"),
	])


func test_blaziken_attack_lock_hands_off_to_a_ready_single_prize_backup() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var locked_ex := _slot(_card("CSV7C", "038"))
	locked_ex.attached_energy.assign([
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本恶能量", "D"), 0),
	])
	locked_ex.effects.append({"type": "attack_lock", "attack_name": "燃烧旋踢", "turn": 1})
	var backup := _slot(_card("CSV10C", "038"))
	backup.attached_energy.assign([
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本恶能量", "D"), 0),
	])
	state.players[0].active_pokemon = locked_ex
	state.players[0].bench.append(backup)
	var context := {"game_state": state, "player_index": 0}
	var locked_score: float = strategy.call("score_handoff_target", locked_ex, {"id": "switch"}, context)
	var backup_score: float = strategy.call("score_handoff_target", backup, {"id": "switch"}, context)
	state.turn_number = 5
	var expired_lock_score: float = strategy.call("score_handoff_target", locked_ex, {"id": "switch"}, context)
	return run_checks([
		assert_true(backup_score >= locked_score + 3000.0, "A locked Blaziken ex must hand off to the ready single-prize Blaziken"),
		assert_true(expired_lock_score >= 5000.0, "A historical attack-lock marker must not suppress Blaziken ex after its locked turn"),
	])


func test_blaziken_damage_lines_value_two_prize_ko_and_single_prize_snipe() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var blaziken_ex := _slot(_card("CSV7C", "038"))
	blaziken_ex.attached_energy.assign([
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本恶能量", "D"), 0),
	])
	player.active_pokemon = blaziken_ex
	var two_prize := _slot(_pokemon("Two prize target", 260, "ex"), 1)
	two_prize.damage_counters = 60
	opponent.active_pokemon = two_prize
	var two_prize_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": blaziken_ex, "attack_index": 0,
		"projected_damage": 200, "projected_knockout": true,
	}, state, 0)
	var single_blaziken := _slot(_card("CSV10C", "038"))
	single_blaziken.attached_energy.assign([
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本恶能量", "D"), 0),
	])
	player.active_pokemon = single_blaziken
	opponent.active_pokemon = _slot(_pokemon("Healthy active", 250), 1)
	opponent.bench.append(_slot(_pokemon("One prize target", 120), 1))
	var single_prize_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": single_blaziken, "attack_index": 1,
		"projected_damage": 120, "projected_knockout": false,
	}, state, 0)
	return run_checks([
		assert_true(two_prize_score >= 8000.0, "Burning Spin Kick should immediately convert an exact two-prize target"),
		assert_true(single_prize_score >= 6500.0, "The single-prize Blaziken snipe should convert a 120 HP prize"),
		assert_true(two_prize_score > single_prize_score, "Equal certainty should prefer the two-prize exchange"),
	])


func test_single_prize_blaziken_resolves_real_two_energy_and_exact_120_bench_steps() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var blaziken_data := _card("CSV10C", "038")
	if blaziken_data == null:
		return "CSV10C_038 single-prize Blaziken should load"
	var blaziken := _slot(blaziken_data)
	var dark := CardInstance.create(_energy("Darkness", "D"), 0)
	var fire_a := CardInstance.create(_energy("Fire A", "R"), 0)
	var fire_b := CardInstance.create(_energy("Fire B", "R"), 0)
	blaziken.attached_energy.assign([dark, fire_a, fire_b])
	state.players[0].active_pokemon = blaziken
	state.players[1].active_pokemon = _slot(_pokemon("Active defender", 250), 1)
	var healthy_bench := _slot(_pokemon("Healthy bench", 220), 1)
	var exact_bench := _slot(_pokemon("Exact 120 bench", 120), 1)
	state.players[1].bench.assign([healthy_bench, exact_bench])
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(blaziken_data)
	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(blaziken, 1)
	if effects.is_empty():
		return "Single-prize Blaziken should register its real bench-damage attack effect"
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(
		blaziken.get_top_card(),
		blaziken_data.attacks[1],
		state
	)
	if steps.size() != 2:
		return "Single-prize Blaziken should expose its real discard and Bench target steps"
	var context := {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": blaziken.get_top_card(),
	}
	var energy_pick: Array = strategy.call("pick_interaction_items", steps[0].get("items", []), steps[0], context)
	context["discard_two_energy_for_bench_damage"] = energy_pick
	var exact_score: float = strategy.call("score_interaction_target", exact_bench, steps[1], context)
	var healthy_score: float = strategy.call("score_interaction_target", healthy_bench, steps[1], context)
	var target_pick: Array = strategy.call("pick_interaction_items", steps[1].get("items", []), steps[1], context)
	processor.execute_attack_effect(blaziken, 1, state.players[1].active_pokemon, state, [{
		"discard_two_energy_for_bench_damage": energy_pick,
		"bench_damage_target": target_pick,
	}])
	return run_checks([
		assert_eq(str(blaziken_data.effect_id), SINGLE_PRIZE_BLAZIKEN_EFFECT_ID, "The real effect ID should identify single-prize Blaziken"),
		assert_eq(str(steps[0].get("id", "")), "discard_two_energy_for_bench_damage", "Inferno Lariat should use the real two-Energy discard step"),
		assert_eq(str(steps[1].get("id", "")), "bench_damage_target", "Inferno Lariat should use the real Bench target step"),
		assert_eq(energy_pick.size(), 2, "Inferno Lariat should select exactly two attached Energy"),
		assert_true(fire_a in energy_pick and fire_b in energy_pick, "Inferno Lariat should discard the redundant Fire Energy before the protected Darkness Energy"),
		assert_true(exact_score >= healthy_score + 5000.0, "The real Bench step should strongly prefer an exact 120-damage prize"),
		assert_eq(target_pick, [exact_bench], "Inferno Lariat should choose the exact 120 HP Bench target"),
		assert_eq(blaziken.attached_energy, [dark], "Inferno Lariat should preserve the Darkness Energy needed by the Munkidori route"),
		assert_eq(exact_bench.damage_counters, 120, "The selected exact target should receive the real 120 bench damage"),
		assert_eq(healthy_bench.damage_counters, 0, "The healthy Bench alternative should remain untouched"),
	])


func test_dusknoir_dragapult_inherited_route_converts_exact_curse_blast() -> String:
	var strategy := _new_strategy(800015734)
	if strategy == null:
		return "Dusknoir/Dragapult delegate should instantiate"
	var state := _make_state()
	var dusknoir := _slot(_card("CSV8C", "083"))
	state.players[0].active_pokemon = _slot(_card("CSV8C", "159"))
	state.players[0].bench.append(dusknoir)
	var exact_ex := _slot(_pokemon("Loaded ex", 250, "ex"), 1)
	exact_ex.damage_counters = 120
	var healthy := _slot(_pokemon("Healthy", 200), 1)
	state.players[1].active_pokemon = exact_ex
	state.players[1].bench.append(healthy)
	var context := {"game_state": state, "player_index": 0, "source_slot": dusknoir}
	var exact_score: float = strategy.call("score_interaction_target", exact_ex, {"id": "self_ko_target"}, context)
	var healthy_score: float = strategy.call("score_interaction_target", healthy, {"id": "self_ko_target"}, context)
	return run_checks([
		assert_true(exact_score >= healthy_score + 500.0, "Curse Blast should preserve the inherited exact-prize conversion"),
	])


func test_blaziken_dragapult_inherited_route_accelerates_missing_psychic() -> String:
	var strategy := _new_strategy(800019125)
	if strategy == null:
		return "Blaziken/Dragapult delegate should instantiate"
	var state := _make_state()
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.attached_energy.append(CardInstance.create(_energy("基本火能量", "R"), 0))
	var blaziken := _slot(_card("CSV7C", "038"))
	var support := _slot(_pokemon("Support", 100))
	state.players[0].active_pokemon = support
	state.players[0].bench.assign([dragapult, blaziken])
	var psychic := CardInstance.create(_energy("基本超能量", "P"), 0)
	var fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	state.players[0].discard_pile.assign([psychic, fire])
	var context := {"game_state": state, "player_index": 0}
	var psychic_score: float = strategy.call("score_interaction_target", psychic, {"id": "attach_basic_energy_from_discard"}, context)
	var fire_score: float = strategy.call("score_interaction_target", fire, {"id": "attach_basic_energy_from_discard"}, context)
	var target_context := {"game_state": state, "player_index": 0, "assignment_source": psychic}
	var dragapult_score: float = strategy.call("score_interaction_target", dragapult, {"id": "attach_basic_energy_from_discard"}, target_context)
	var support_score: float = strategy.call("score_interaction_target", support, {"id": "attach_basic_energy_from_discard"}, target_context)
	return run_checks([
		assert_true(psychic_score >= fire_score + 500.0, "Boiling Spirit should recover Dragapult's missing Psychic before duplicate Fire"),
		assert_true(dragapult_score >= support_score + 1000.0, "Recovered Psychic should complete Phantom Dive instead of funding support"),
	])


func test_munkidori_blaziken_low_deck_stops_churn_and_continuity_relaxes() -> String:
	var strategy := _new_strategy(18000625)
	if strategy == null:
		return "Munkidori/Blaziken delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var blaziken := _slot(_card("CSV7C", "038"))
	blaziken.attached_energy.assign([
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本恶能量", "D"), 0),
	])
	player.active_pokemon = blaziken
	player.bench.append(_slot(_card("CSV10C", "036")))
	for index: int in 4:
		player.deck.append(CardInstance.create(_trainer("Deck %d" % index), 0))
	var iono := CardInstance.create(_trainer("奇树"), 0)
	var research := CardInstance.create(_trainer("博士的研究"), 0)
	var iono_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": iono}, state, 0)
	var research_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": research}, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	return run_checks([
		assert_true(iono_score <= -3000.0 and research_score <= -3000.0, "Ready low-deck boards must stop Iono/Research churn"),
		assert_true(end_score > iono_score and end_score > research_score, "Passing should beat self-decking draw supporters"),
		assert_false(bool(continuity.get("safe_setup_before_attack", true)), "Critical deck size should relax nonessential setup continuity"),
	])


func test_munkidori_blaziken_normal_and_strong_share_one_tactical_policy() -> String:
	var normal_strategy := _new_strategy(18000625)
	var strong_strategy := _new_strategy(18000625)
	if normal_strategy == null or strong_strategy == null:
		return "Both normal and strong delegates should instantiate"
	var state := _make_state()
	var blaziken := _slot(_card("CSV7C", "038"))
	var munkidori := _slot(_card("CSV8C", "094"))
	var damaged := _slot(_card("CSV9C", "127"))
	damaged.damage_counters = 20
	state.players[0].active_pokemon = damaged
	state.players[0].bench.assign([blaziken, munkidori])
	var dark := CardInstance.create(_energy("基本恶能量", "D"), 0)
	var action := {"kind": "attach_energy", "card": dark, "target_slot": munkidori}
	var normal_score: float = normal_strategy.call("score_action_absolute", action, state, 0)
	var strong_score: float = strong_strategy.call("score_action_absolute", action, state, 0)
	return run_checks([
		assert_true(is_equal_approx(normal_score, strong_score), "Fixed opening mode must not fork the tactical rules after setup"),
		assert_true(normal_score >= 5000.0, "Both modes should switch on damaged-board Munkidori with Darkness"),
	])


func _new_strategy(deck_id: int) -> RefCounted:
	var script: Variant = load(STRATEGY_PATH)
	if not script is GDScript:
		return null
	var strategy: RefCounted = (script as GDScript).new()
	strategy.call("configure_from_deck", _load_deck(deck_id))
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _deck_has_effect(deck: DeckData, effect_id: String) -> bool:
	if deck == null:
		return false
	for entry: Dictionary in deck.cards:
		if str(entry.get("effect_id", "")) == effect_id:
			return true
	return false


func _fixed_opening_player(deck_id: int) -> PlayerState:
	var path := "%s/%d.json" % [FIXED_ORDER_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var order: Array = parsed.get("top_to_bottom", [])
	if order.size() < 7:
		return null
	var player := PlayerState.new()
	for index: int in 7:
		var entry: Dictionary = order[index]
		var card := _card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
		if card == null:
			return null
		player.hand.append(CardInstance.create(card, 0))
	return player


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for index: int in 6:
		player.prizes.append(CardInstance.create(_trainer("Prize %d" % index), 0))
	return state


func _card(set_code: String, card_index: String) -> CardData:
	return CardDatabase.get_card(set_code, card_index)


func _slot(card_data: CardData, owner_index: int = 0) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return result


func _pokemon(name: String, hp: int, mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.mechanic = mechanic
	card.retreat_cost = 1
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	return card


func _hand_name(player: PlayerState, index: int) -> String:
	if player == null or index < 0 or index >= player.hand.size():
		return ""
	var card: CardInstance = player.hand[index]
	return str(card.card_data.name) if card != null and card.card_data != null else ""


func _bench_contains(player: PlayerState, indices: Array, target_name: String) -> bool:
	for raw_index: Variant in indices:
		if _hand_name(player, int(raw_index)) == target_name:
			return true
	return false
