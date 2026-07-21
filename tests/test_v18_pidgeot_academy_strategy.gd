class_name TestV18PidgeotAcademyStrategy
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const FIXED_ORDER_DIR := "res://data/bundled_user/ai_fixed_deck_orders"
const CARD_DIR := "res://data/bundled_user/cards"

const PIDGEOT_DECK_ID := 800018359
const ACADEMY_DECK_ID := 800018498


func test_real_decklists_and_strong_orders_keep_their_exact_engines() -> String:
	var control := _load_deck(PIDGEOT_DECK_ID)
	var academy := _load_deck(ACADEMY_DECK_ID)
	var control_order := _load_json("%s/%d.json" % [FIXED_ORDER_DIR, PIDGEOT_DECK_ID])
	var academy_order := _load_json("%s/%d.json" % [FIXED_ORDER_DIR, ACADEMY_DECK_ID])
	return run_checks([
		assert_not_null(control, "The bundled Pidgeot Control deck should load"),
		assert_not_null(academy, "The bundled Academy Gardevoir deck should load"),
		assert_eq(_deck_count(control, "CSV4C", "101"), 2, "Pidgeot Control should contain two real Pidgeot ex"),
		assert_eq(_deck_count(control, "CSV4C", "074"), 2, "Pidgeot Control should contain two real Garganacl"),
		assert_eq(_deck_count(control, "CSV10C", "193"), 2, "Pidgeot Control should contain both Switching Tickets"),
		assert_eq(_deck_count(academy, "CSV2C", "055"), 2, "Academy Gardevoir should contain two real Gardevoir ex"),
		assert_eq(_deck_count(academy, "CSV8C", "094"), 3, "Academy Gardevoir should contain three real Munkidori"),
		assert_eq(_deck_count(academy, "CSV10C", "007"), 1, "Academy Gardevoir should contain the Shaymin guard"),
		assert_eq(int(control_order.get("deck_id", 0)), PIDGEOT_DECK_ID, "Control strong order should belong to the exact deck"),
		assert_eq(int(academy_order.get("deck_id", 0)), ACADEMY_DECK_ID, "Academy strong order should belong to the exact deck"),
		assert_eq((control_order.get("top_to_bottom", []) as Array).size(), 19, "Control strong order should include setup, Prizes, and bridge cards"),
		assert_eq((academy_order.get("top_to_bottom", []) as Array).size(), 19, "Academy strong order should include setup, Prizes, and bridge cards"),
	])


func test_normal_and_strong_modes_share_a_legal_deck_scoped_opening_policy() -> String:
	var checks: Array[String] = []
	for deck_id: int in [PIDGEOT_DECK_ID, ACADEMY_DECK_ID]:
		var strategy := _strategy(deck_id)
		var strong_player := _fixed_opening_player(deck_id)
		var strong_plan: Dictionary = strategy.call("plan_opening_setup", strong_player)
		var normal_player := _normal_opening_player(deck_id)
		var normal_plan: Dictionary = strategy.call("plan_opening_setup", normal_player)
		var strong_active := int(strong_plan.get("active_hand_index", -1))
		var normal_active := int(normal_plan.get("active_hand_index", -1))
		checks.append(assert_true(strong_active >= 0 and strong_active < strong_player.hand.size(), "Strong mode should choose a legal Basic for deck %d" % deck_id))
		checks.append(assert_true(normal_active >= 0 and normal_active < normal_player.hand.size(), "Normal mode should choose a legal Basic for deck %d" % deck_id))
		checks.append(assert_true(strong_player.hand[strong_active].is_basic_pokemon(), "Strong active should be Basic for deck %d" % deck_id))
		checks.append(assert_true(normal_player.hand[normal_active].is_basic_pokemon(), "Normal active should be Basic for deck %d" % deck_id))
		checks.append(assert_true(_opening_bench_is_legal(strong_plan, strong_player), "Strong setup Bench should contain unique legal Basics for deck %d" % deck_id))
		checks.append(assert_true(_opening_bench_is_legal(normal_plan, normal_player), "Normal setup Bench should contain unique legal Basics for deck %d" % deck_id))
		var expected_strong := "含羞苞" if deck_id == PIDGEOT_DECK_ID else "愿增猿"
		checks.append(assert_eq(_card_name(strong_player.hand[strong_active]), expected_strong, "The strong opening should keep the intended pivot out front"))
	return run_checks(checks)


func test_turn_contracts_expose_dedicated_v18_ownership_and_edge_guards() -> String:
	var checks: Array[String] = []
	for deck_id: int in [PIDGEOT_DECK_ID, ACADEMY_DECK_ID]:
		var strategy := _strategy(deck_id)
		var state := _state(12, 12)
		state.players[0].active_pokemon = _slot(_basic_pivot(deck_id))
		var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
		var flags: Dictionary = contract.get("flags", {})
		var constraints: Dictionary = contract.get("constraints", {})
		checks.append(assert_true(str(contract.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Deck %d should emit a V18 phase" % deck_id))
		checks.append(assert_true(contract.get("owner", null) is Dictionary, "Deck %d should declare route ownership" % deck_id))
		checks.append(assert_eq(str(flags.get("dedicated_family", "")), "pidgeot_control" if deck_id == PIDGEOT_DECK_ID else "academy_gardevoir", "Deck %d should expose its dedicated family" % deck_id))
		checks.append(assert_true(constraints.has("forbid_engine_churn"), "Deck %d should expose the churn guard" % deck_id))
		checks.append(assert_true(constraints.has("forbid_extra_bench_padding"), "Deck %d should expose the Bench guard" % deck_id))
	return run_checks(checks)


func test_pidgeot_control_closes_on_the_garganacl_deckout_window() -> String:
	var strategy := _strategy(PIDGEOT_DECK_ID)
	var state := _state(5, 1)
	var garganacl := _ready_garganacl()
	state.players[0].active_pokemon = garganacl
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	var attack := {
		"kind": "attack", "source_slot": garganacl, "attack_index": 0,
		"projected_damage": 130, "projected_knockout": false,
	}
	var attack_score: float = strategy.call("score_action_absolute", attack, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	return run_checks([
		assert_eq(str(plan.get("phase", "")), "close", "One opposing deck card should switch Pidgeot Control to close"),
		assert_eq(str(plan.get("intent", "")), "finish_garganacl_deckout", "The close intent should name the actual control win condition"),
		assert_true(bool((plan.get("flags", {}) as Dictionary).get("opponent_deckout_pressure", false)), "The plan should expose the deck-out window"),
		assert_false(bool(contract.get("safe_setup_before_attack", false)), "A winning Garganacl attack must not be delayed by setup debt"),
		assert_true(attack_score >= end_score + 5000.0, "The final mill attack should decisively beat ending the turn"),
	])


func test_pidgeot_control_stops_own_deck_churn_but_keeps_live_pal_pad_recovery() -> String:
	var strategy := _strategy(PIDGEOT_DECK_ID)
	var state := _state(2, 8)
	var garganacl := _ready_garganacl()
	var pidgeot := _slot(_pokemon("大比鸟ex", "Pidgeot ex", "Stage 2", "比比鸟", "CC", "120", "CSV4C", "101", 280, "ex", "8105afde9792c2596166f318a480d041"))
	state.players[0].active_pokemon = garganacl
	state.players[0].bench.append(pidgeot)
	var supporter := _instance(_trainer("天星队手下", "Team Star Grunt", "Supporter", "CSV2C", "125", "b54276b42598426febfe34bb67d5f075"))
	state.players[0].discard_pile.append(supporter)
	var pal_pad := _instance(_trainer("朋友手册", "Pal Pad", "Item", "CSV1C", "111", "a47d5a8ed00e14a2146fc511745d23b5"))
	var search_score: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": pidgeot}, state, 0)
	var pad_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": pal_pad}, state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": garganacl, "attack_index": 0, "projected_damage": 130}, state, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return run_checks([
		assert_true(search_score <= -5000.0, "Quick Search should stop when a ready attack can preserve a two-card deck"),
		assert_true(attack_score >= search_score + 6000.0, "A ready control attack should beat optional low-deck search"),
		assert_true(pad_score >= search_score + 7000.0, "Pal Pad should remain live because it increases the deck and restores control supporters"),
		assert_true(bool((plan.get("constraints", {}) as Dictionary).get("forbid_engine_churn", false)), "The low-deck control plan should hard-stop churn"),
	])


func test_pidgeot_control_rejects_unproductive_disruption_actions() -> String:
	var strategy := _strategy(PIDGEOT_DECK_ID)
	var state := _state(12, 12)
	state.players[0].active_pokemon = _ready_garganacl()
	for index: int in 5:
		state.players[1].bench.append(_slot(_pokemon("对手后备%d" % index, "Opponent Bench %d" % index, "Basic", "", "C", "10"), 1))
	var flute := _instance(_trainer("配乐之笛", "Accompanying Flute", "Item", "CSV8C", "175", "e9bd0b4b3d97716a9757e6bccb1446ac"))
	var ruffian := _instance(_trainer("可怕的哥哥", "Ruffian", "Supporter", "CSV10C", "205", "dacd942c84db0948ced6544bacfa08d7"))
	var flute_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": flute}, state, 0)
	var ruffian_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": ruffian}, state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {"kind": "attack", "source_slot": state.players[0].active_pokemon, "attack_index": 0}, state, 0)
	return run_checks([
		assert_true(flute_score <= -4000.0, "Accompanying Flute should be rejected against a full opposing Bench"),
		assert_true(ruffian_score <= -4000.0, "Ruffian should be rejected without an opposing Tool or Special Energy"),
		assert_true(attack_score >= maxf(flute_score, ruffian_score) + 4000.0, "Productive control pressure should beat no-op disruption"),
	])


func test_pidgeot_quick_search_funds_one_energy_garganacl_over_dead_routes() -> String:
	var strategy := _strategy(PIDGEOT_DECK_ID)
	var state := _state(12, 12)
	var pidgeot := _slot(_pokemon("大比鸟ex", "Pidgeot ex", "Stage 2", "比比鸟", "CC", "120", "CSV4C", "101", 280, "ex", "8105afde9792c2596166f318a480d041"))
	var garganacl := _slot(_pokemon("盐石巨灵", "Garganacl", "Stage 2", "盐石垒", "FF", "130", "CSV4C", "074", 180, "", "73c1d28d980ebe98f205db87eb647fe8"))
	garganacl.attached_energy.append(_instance(_energy("基本斗能量", "Fighting Energy", "F")))
	state.players[0].active_pokemon = pidgeot
	state.players[0].bench.append(garganacl)
	var fighting := _instance(_energy("基本斗能量", "Fighting Energy", "F", "CSVE1C", "FIG", "9fedb80a97ddd5cc8b8022a21364c326"))
	var duplicate_pidgeot := _instance(_pokemon("大比鸟ex", "Pidgeot ex", "Stage 2", "比比鸟", "CC", "120", "CSV4C", "101", 280, "ex", "8105afde9792c2596166f318a480d041"))
	var dead_stretcher := _instance(_trainer("夜间担架", "Night Stretcher", "Item", "CSV8C", "183", "3e6f1daf545dfed48d0588dd50792a2e"))
	var candidates: Array = [duplicate_pidgeot, dead_stretcher, fighting]
	var step := {"id": "search_cards", "max_select": 1}
	var context := {"game_state": state, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", candidates, step, context)
	var fighting_score: float = strategy.call("score_interaction_target", fighting, step, context)
	var duplicate_score: float = strategy.call("score_interaction_target", duplicate_pidgeot, step, context)
	var recovery_score: float = strategy.call("score_interaction_target", dead_stretcher, step, context)
	return run_checks([
		assert_true(picked.size() == 1 and picked[0] == fighting, "Quick Search should take Fighting Energy to complete Garganacl instead of a duplicate Stage 2 or dead recovery"),
		assert_true(fighting_score >= maxf(duplicate_score, recovery_score) + 3000.0, "The immediate Garganacl attack route should clearly lead dead search routes"),
		assert_true(duplicate_score <= 400.0, "A duplicate Pidgeot ex without a Pidgey route should be explicitly downweighted"),
	])


func test_pidgeot_control_reserves_fighting_energy_for_the_salt_lane() -> String:
	var strategy := _strategy(PIDGEOT_DECK_ID)
	var state := _state(12, 12)
	var pidgeot := _slot(_pokemon("Pidgeot ex", "Pidgeot ex", "Stage 2", "Pidgeotto", "CC", "120", "CSV4C", "101", 280, "ex", "8105afde9792c2596166f318a480d041"))
	var nacli := _slot(_pokemon("Nacli", "Nacli", "Basic", "", "F", "10"))
	var fighting := _instance(_energy("Fighting Energy", "Fighting Energy", "F", "CSVE1C", "FIG", "9fedb80a97ddd5cc8b8022a21364c326"))
	state.players[0].active_pokemon = _slot(_basic_pivot(PIDGEOT_DECK_ID))
	state.players[0].bench.assign([pidgeot, nacli])
	state.players[0].hand.append(fighting)
	var nacli_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": fighting, "target_slot": nacli}, state, 0)
	var pidgeot_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": fighting, "target_slot": pidgeot}, state, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	var attach_priority: Array = (plan.get("priorities", {}) as Dictionary).get("attach", [])
	var setup_debt: Dictionary = continuity.get("setup_debt", {})

	var one_short := _state(12, 12)
	var one_short_pidgeot := _slot(_pokemon("Pidgeot ex", "Pidgeot ex", "Stage 2", "Pidgeotto", "CC", "120", "CSV4C", "101", 280, "ex", "8105afde9792c2596166f318a480d041"))
	var one_short_garganacl := _slot(_pokemon("Garganacl", "Garganacl", "Stage 2", "Naclstack", "FF", "130", "CSV4C", "074", 180, "", "73c1d28d980ebe98f205db87eb647fe8"))
	one_short_garganacl.attached_energy.append(_instance(_energy("Fighting Energy", "Fighting Energy", "F")))
	one_short.players[0].active_pokemon = _slot(_basic_pivot(PIDGEOT_DECK_ID))
	one_short.players[0].bench.assign([one_short_pidgeot, one_short_garganacl])
	one_short.players[0].hand.append(fighting)
	var one_short_plan: Dictionary = strategy.call("build_turn_plan", one_short, 0, {})
	var one_short_continuity: Dictionary = strategy.call("build_continuity_contract", one_short, 0, one_short_plan)
	var one_short_attach: Array = (one_short_plan.get("priorities", {}) as Dictionary).get("attach", [])

	var funded := _state(12, 12)
	var funded_pidgeot := _slot(_pokemon("Pidgeot ex", "Pidgeot ex", "Stage 2", "Pidgeotto", "CC", "120", "CSV4C", "101", 280, "ex", "8105afde9792c2596166f318a480d041"))
	funded.players[0].active_pokemon = _slot(_basic_pivot(PIDGEOT_DECK_ID))
	funded.players[0].bench.assign([funded_pidgeot, _ready_garganacl()])
	var fire := _instance(_energy("Fire Energy", "Fire Energy", "R"))
	var funded_plan: Dictionary = strategy.call("build_turn_plan", funded, 0, {})
	var funded_continuity: Dictionary = strategy.call("build_continuity_contract", funded, 0, funded_plan)
	var fire_to_pidgeot: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": fire, "target_slot": funded_pidgeot}, funded, 0)
	return run_checks([
		assert_true(nacli_score >= pidgeot_score + 1500.0, "Basic Fighting Energy should stay with Nacli instead of leaking onto Pidgeot ex"),
		assert_true(not attach_priority.is_empty() and str(attach_priority[0]) == "Nacli", "The control plan should put the current Fighting owner first"),
		assert_eq(int(setup_debt.get("missing_salt_lane_fighting", -1)), 2, "An unpowered Nacli should expose exactly two Fighting Energy of continuity debt"),
		assert_true(not one_short_attach.is_empty() and str(one_short_attach[0]) == "Garganacl", "A built Garganacl with a gap should take ownership before Nacli"),
		assert_eq(int((one_short_continuity.get("setup_debt", {}) as Dictionary).get("missing_salt_lane_fighting", -1)), 1, "A one-energy Garganacl should expose exactly one Fighting Energy of continuity debt"),
		assert_eq(int((funded_continuity.get("setup_debt", {}) as Dictionary).get("missing_salt_lane_fighting", -1)), 0, "The Fighting ownership debt should retire once the salt lane has two Fighting Energy"),
		assert_true(fire_to_pidgeot >= 1500.0, "Non-Fighting Energy should remain available to fund Pidgeot ex after the salt lane is complete"),
	])


func test_academy_gardevoir_closes_with_a_ready_one_prize_attacker_without_churn() -> String:
	var strategy := _strategy(ACADEMY_DECK_ID)
	var state := _state(3, 10)
	_set_prizes(state.players[0], 2)
	var scream_tail := _ready_scream_tail()
	var kirlia := _slot(_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "拉鲁拉丝", "PC", "30", "CS6.5C", "030", 80, "", "4abd956bdf3e956fcf679120601760ff"))
	state.players[0].active_pokemon = scream_tail
	state.players[0].bench.append(kirlia)
	var research := _instance(_trainer("博士的研究", "Professor's Research", "Supporter", "CSV1C", "121", "aecd80ca2722885c3d062a2255346f3e"))
	var attack := {"kind": "attack", "source_slot": scream_tail, "attack_index": 0, "projected_damage": 160, "projected_knockout": true}
	var attack_score: float = strategy.call("score_action_absolute", attack, state, 0)
	var research_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": research}, state, 0)
	var refinement_score: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": kirlia}, state, 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	return run_checks([
		assert_eq(str(plan.get("phase", "")), "close", "Two Prizes and a ready attacker should enter the close phase"),
		assert_eq(str(plan.get("intent", "")), "take_final_prizes_without_churn", "Academy should name its final-Prize conversion route"),
		assert_true(research_score <= -6000.0, "Research should be hard-stopped with only three deck cards and a ready attacker"),
		assert_true(refinement_score <= -5000.0, "Kirlia should stop optional draw with only three deck cards and a ready attacker"),
		assert_true(attack_score >= maxf(research_score, refinement_score) + 6500.0, "The ready one-Prize attacker should convert instead of churning"),
		assert_false(bool(continuity.get("safe_setup_before_attack", false)), "A projected closing route must not inherit setup attack debt"),
	])


func test_academy_darkness_energy_activates_each_munkidori_once() -> String:
	var strategy := _strategy(ACADEMY_DECK_ID)
	var state := _state(14, 14)
	var active := _ready_scream_tail()
	var powered := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094", 110, "", "66fee12502043db7d92b97b0d62b0f59"))
	var unpowered := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094", 110, "", "66fee12502043db7d92b97b0d62b0f59"))
	powered.attached_energy.append(_instance(_energy("基本恶能量", "Darkness Energy", "D")))
	state.players[0].active_pokemon = active
	state.players[0].bench.assign([powered, unpowered])
	var darkness := _instance(_energy("基本恶能量", "Darkness Energy", "D", "CSVE1C", "DAR", "46c769fc57a6c250c560df648bb779f8"))
	var unpowered_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": unpowered}, state, 0)
	var duplicate_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": powered}, state, 0)
	return assert_true(unpowered_score >= duplicate_score + 4500.0, "Darkness should activate the next Munkidori instead of duplicating a dead attachment")


func test_academy_munkidori_and_recovery_actions_require_real_value() -> String:
	var strategy := _strategy(ACADEMY_DECK_ID)
	var quiet := _state(12, 12)
	var munkidori := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094", 110, "", "66fee12502043db7d92b97b0d62b0f59"))
	munkidori.attached_energy.append(_instance(_energy("基本恶能量", "Darkness Energy", "D")))
	quiet.players[0].active_pokemon = _ready_scream_tail()
	quiet.players[0].active_pokemon.damage_counters = 0
	quiet.players[0].bench.append(munkidori)
	var stretcher := _instance(_trainer("夜间担架", "Night Stretcher", "Item", "CSV8C", "183", "3e6f1daf545dfed48d0588dd50792a2e"))
	var quiet_ability: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": munkidori}, quiet, 0)
	var dead_stretcher: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": stretcher}, quiet, 0)
	var live := _state(12, 12)
	var damaged_gardevoir := _slot(_pokemon("沙奈朵ex", "Gardevoir ex", "Stage 2", "奇鲁莉安", "PPC", "190", "CSV2C", "055", 310, "ex", "bd134d7d84e9f1a837a74b061fcb5f40"))
	damaged_gardevoir.damage_counters = 40
	live.players[0].active_pokemon = damaged_gardevoir
	live.players[0].bench.append(munkidori)
	live.players[0].discard_pile.append(_instance(_pokemon("吼叫尾", "Scream Tail", "Basic", "", "PP", "160", "CSV6C", "065", 90, "", "12c9416c64d1a8cfbbf0a3000a9f3d50")))
	var live_ability: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": munkidori}, live, 0)
	var live_stretcher: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": stretcher}, live, 0)
	return run_checks([
		assert_true(quiet_ability <= -3500.0, "Adrena-Brain should be rejected when no damage can be moved"),
		assert_true(dead_stretcher <= -3500.0, "Night Stretcher should be rejected with no recoverable Pokemon or Energy"),
		assert_true(live_ability >= quiet_ability + 5000.0, "Adrena-Brain should become productive when damage exists"),
		assert_true(live_stretcher >= dead_stretcher + 4500.0, "Night Stretcher should rebuild a missing one-Prize attacker"),
	])


func test_prize_conditional_counter_catcher_is_not_spent_while_ahead() -> String:
	var checks: Array[String] = []
	for deck_id: int in [PIDGEOT_DECK_ID, ACADEMY_DECK_ID]:
		var strategy := _strategy(deck_id)
		var behind := _state(12, 12)
		var ahead := _state(12, 12)
		behind.players[0].active_pokemon = _slot(_basic_pivot(deck_id))
		ahead.players[0].active_pokemon = _slot(_basic_pivot(deck_id))
		_set_prizes(behind.players[0], 5)
		_set_prizes(behind.players[1], 3)
		_set_prizes(ahead.players[0], 2)
		_set_prizes(ahead.players[1], 5)
		behind.players[1].bench.append(_slot(_pokemon("对手后备ex", "Opponent Bench ex", "Basic", "", "C", "20", "", "", 100, "ex"), 1))
		ahead.players[1].bench.append(_slot(_pokemon("对手后备ex", "Opponent Bench ex", "Basic", "", "C", "20", "", "", 100, "ex"), 1))
		var catcher := _instance(_trainer("反击捕捉器", "Counter Catcher", "Item", "CSV6C", "114", "06bc00d5dcec33898dc6db2e4c4d10ec"))
		var behind_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": catcher}, behind, 0)
		var ahead_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": catcher}, ahead, 0)
		checks.append(assert_true(behind_score >= ahead_score + 4000.0, "Deck %d should reserve Counter Catcher for its legal behind-on-Prizes window" % deck_id))
	return run_checks(checks)


func _strategy(deck_id: int) -> RefCounted:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", _load_deck(deck_id))
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var parsed := _load_json("%s/%d.json" % [DECK_DIR, deck_id])
	return DeckData.from_dict(parsed) if not parsed.is_empty() else null


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _deck_count(deck: DeckData, set_code: String, card_index: String) -> int:
	if deck == null:
		return 0
	for entry: Dictionary in deck.cards:
		if str(entry.get("set_code", "")) == set_code and str(entry.get("card_index", "")) == card_index:
			return int(entry.get("count", 0))
	return 0


func _fixed_opening_player(deck_id: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = 0
	var order := _load_json("%s/%d.json" % [FIXED_ORDER_DIR, deck_id])
	var cards: Array = order.get("top_to_bottom", [])
	for index: int in mini(7, cards.size()):
		var ref: Dictionary = cards[index]
		var card := _load_real_card(str(ref.get("set_code", "")), str(ref.get("card_index", "")))
		if card != null:
			player.hand.append(_instance(card))
	return player


func _normal_opening_player(deck_id: int) -> PlayerState:
	var player := _fixed_opening_player(deck_id)
	player.hand.reverse()
	return player


func _load_real_card(set_code: String, card_index: String) -> CardData:
	var parsed := _load_json("%s/%s_%s.json" % [CARD_DIR, set_code, card_index])
	return CardData.from_dict(parsed) if not parsed.is_empty() else null


func _opening_bench_is_legal(plan: Dictionary, player: PlayerState) -> bool:
	var active_index := int(plan.get("active_hand_index", -1))
	var seen := {}
	for value: Variant in plan.get("bench_hand_indices", []):
		var index := int(value)
		if index < 0 or index >= player.hand.size() or index == active_index or seen.has(index):
			return false
		if not player.hand[index].is_basic_pokemon():
			return false
		seen[index] = true
	return seen.size() <= 5


func _state(own_deck: int, opposing_deck: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	_set_prizes(player, 6)
	_set_prizes(opponent, 6)
	for index: int in own_deck:
		player.deck.append(_instance(_trainer("己方牌库%d" % index, "Own Deck %d" % index, "Item")))
	for index: int in opposing_deck:
		opponent.deck.append(_instance(_trainer("对手牌库%d" % index, "Opponent Deck %d" % index, "Item"), 1))
	opponent.active_pokemon = _slot(_pokemon("对手战斗宝可梦", "Opponent Active", "Basic", "", "C", "20", "", "", 150), 1)
	return state


func _set_prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_instance(_trainer("奖赏%d" % index, "Prize %d" % index, "Item"), player.player_index))


func _basic_pivot(deck_id: int) -> CardData:
	if deck_id == PIDGEOT_DECK_ID:
		return _pokemon("含羞苞", "Budew", "Basic", "", "", "0", "CSV9.5C", "004", 30, "", "28505a8ad6e07e74382c1b5e09737932")
	return _pokemon("拉鲁拉丝", "Ralts", "Basic", "", "P", "10", "CSV2C", "053", 70, "", "daccaa8fc34b41e47e77be2143eea71b")


func _ready_garganacl() -> PokemonSlot:
	var slot := _slot(_pokemon("盐石巨灵", "Garganacl", "Stage 2", "盐石垒", "FF", "130", "CSV4C", "074", 180, "", "73c1d28d980ebe98f205db87eb647fe8"))
	slot.attached_energy.assign([
		_instance(_energy("基本斗能量", "Fighting Energy", "F")),
		_instance(_energy("基本斗能量", "Fighting Energy", "F")),
	])
	return slot


func _ready_scream_tail() -> PokemonSlot:
	var slot := _slot(_pokemon("吼叫尾", "Scream Tail", "Basic", "", "PP", "160", "CSV6C", "065", 90, "", "12c9416c64d1a8cfbbf0a3000a9f3d50"))
	slot.attached_energy.assign([
		_instance(_energy("基本超能量", "Psychic Energy", "P")),
		_instance(_energy("基本超能量", "Psychic Energy", "P")),
	])
	slot.damage_counters = 40
	return slot


func _slot(data: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner_index))
	return slot


func _instance(data: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(data, owner_index)


func _pokemon(
	name: String,
	name_en: String,
	stage: String,
	evolves_from: String,
	cost: String,
	damage: String,
	set_code: String = "",
	card_index: String = "",
	hp: int = 110,
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.name_zh = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.hp = hp
	card.mechanic = mechanic
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	card.attacks = [{"name": "测试招式", "cost": cost, "damage": damage, "text": ""}]
	return card


func _energy(
	name: String,
	name_en: String,
	provides: String,
	set_code: String = "",
	card_index: String = "",
	effect_id: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.name_zh = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	return card


func _trainer(
	name: String,
	name_en: String,
	card_type: String,
	set_code: String = "",
	card_index: String = "",
	effect_id: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.name_zh = name
	card.card_type = card_type
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	return card


func _card_name(card: CardInstance) -> String:
	return str(card.card_data.name) if card != null and card.card_data != null else ""
