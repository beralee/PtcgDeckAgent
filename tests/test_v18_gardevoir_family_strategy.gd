class_name TestV18GardevoirFamilyStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategyV18GardevoirFamily.gd"
const AttackTMEvolutionScript = preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const FAMILY_DECK_IDS: Array[int] = [800017097, 800018105, 800018497, 800018498]


func test_family_delegate_exposes_complete_variant_turn_contracts() -> String:
	var checks: Array[String] = []
	for deck_id: int in FAMILY_DECK_IDS:
		var strategy := _strategy_for_deck(deck_id)
		checks.append(assert_not_null(strategy, "Gardevoir family delegate should load for deck %d" % deck_id))
		if strategy == null:
			continue
		var state := _make_state(24)
		state.players[0].active_pokemon = _make_slot(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1))
		state.players[0].bench.append(_make_slot(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝")))
		var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
		var owner: Dictionary = contract.get("owner", {})
		var priorities: Dictionary = contract.get("priorities", {})
		var flags: Dictionary = contract.get("flags", {})
		checks.append(assert_eq(str(strategy.call("get_strategy_id")), "v18_gardevoir_family", "Delegate identity should be stable"))
		checks.append(assert_true(str(contract.get("id", "")).begins_with("v18_gardevoir_family:"), "Deck %d should emit a family contract id" % deck_id))
		checks.append(assert_true(str(contract.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Deck %d should use a canonical V18 phase" % deck_id))
		for key: String in ["turn_owner_name", "bridge_target_name", "pivot_target_name"]:
			checks.append(assert_true(owner.has(key), "Deck %d owner should include %s" % [deck_id, key]))
		for key: String in ["attach", "handoff", "search", "evolve", "ability", "trainer"]:
			checks.append(assert_true(priorities.has(key), "Deck %d priorities should include %s" % [deck_id, key]))
		checks.append(assert_false(str(flags.get("family_variant", "")).is_empty(), "Deck %d should expose its configured variant" % deck_id))
		var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, contract)
		checks.append(assert_true(continuity.get("setup_debt", {}) is Dictionary, "Deck %d should expose setup debt" % deck_id))
	return run_checks(checks)


func test_family_opening_keeps_the_engine_and_variant_seed_off_the_active_spot() -> String:
	var rabsca_strategy := _strategy_for_deck(800018105)
	var rabsca_player := PlayerState.new()
	rabsca_player.hand = [
		CardInstance.create(_make_pokemon("含羞苞", "Budew", "Basic", "G", 30, 0), 0),
		CardInstance.create(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1), 0),
		CardInstance.create(_make_pokemon("虫滚泥", "Rellor", "Basic", "G", 50, 1), 0),
		CardInstance.create(_make_pokemon("愿增猿", "Munkidori", "Basic", "P", 110, 1), 0),
	]
	var rabsca_plan: Dictionary = rabsca_strategy.call("plan_opening_setup", rabsca_player)
	var rabsca_bench: Array = rabsca_plan.get("bench_hand_indices", [])

	var no_disc_strategy := _strategy_for_deck(800017097)
	var no_disc_player := PlayerState.new()
	no_disc_player.hand = [
		CardInstance.create(_make_pokemon("皮宝宝", "Cleffa", "Basic", "P", 30, 0), 0),
		CardInstance.create(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1), 0),
		CardInstance.create(_make_scream_tail(), 0),
	]
	var no_disc_plan: Dictionary = no_disc_strategy.call("plan_opening_setup", no_disc_player)
	var no_disc_bench: Array = no_disc_plan.get("bench_hand_indices", [])
	return run_checks([
		assert_eq(int(rabsca_plan.get("active_hand_index", -1)), 0, "Rabsca Gardevoir should use Budew as its opening pivot"),
		assert_true(1 in rabsca_bench, "Ralts should stay on the Bench for the Gardevoir chain"),
		assert_true(2 in rabsca_bench, "Rellor should stay on the Bench for the Rabsca TM lane"),
		assert_eq(int(no_disc_plan.get("active_hand_index", -1)), 0, "No-disc Gardevoir should use free-retreat Cleffa instead of exposing Ralts"),
		assert_true(1 in no_disc_bench, "No-disc Gardevoir should preserve its Ralts seed"),
		assert_true(2 in no_disc_bench, "No-disc Gardevoir should declare its first one-prize attacker"),
	])


func test_refinement_discards_psychic_fuel_without_spending_the_dark_route() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_state(24)
	var player := state.players[0]
	var kirlia := _make_slot(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"))
	var munkidori := _make_slot(_make_munkidori())
	player.active_pokemon = _make_slot(_make_scream_tail())
	player.bench = [kirlia, munkidori]
	var psychic := CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0)
	var darkness := CardInstance.create(_make_energy("基本恶能量", "Darkness Energy", "D"), 0)
	var gardevoir := CardInstance.create(_make_gardevoir(), 0)
	player.hand = [psychic, darkness, gardevoir]
	var step := {"id": "discard_card", "max_select": 1}
	var context := {"game_state": state, "player_index": 0, "all_items": player.hand}
	var psychic_score: float = strategy.call("score_interaction_target", psychic, step, context)
	var darkness_score: float = strategy.call("score_interaction_target", darkness, step, context)
	var gardevoir_score: float = strategy.call("score_interaction_target", gardevoir, step, context)
	var picked: Array = strategy.call("pick_interaction_items", player.hand, step, context)
	return run_checks([
		assert_true(psychic_score >= darkness_score + 1000.0, "Refinement should create Psychic Embrace fuel before discarding Munkidori's Darkness"),
		assert_true(psychic_score >= gardevoir_score + 1000.0, "Refinement should preserve the first Gardevoir ex evolution"),
		assert_true(picked.size() == 1 and picked[0] == psychic, "Refinement should deterministically discard Psychic Energy while fuel debt is live"),
	])


func test_kirlia_filter_starts_the_engine_but_stops_before_deck_out() -> String:
	var strategy := _strategy_for_deck(800018497)
	var setup_state := _make_state(24)
	var setup_kirlia := _make_slot(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"))
	setup_state.players[0].active_pokemon = _make_slot(_make_pokemon("梦幻ex", "Mew ex", "Basic", "P", 180, 0))
	setup_state.players[0].bench.append(setup_kirlia)
	setup_state.players[0].hand.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	var setup_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": setup_kirlia, "ability_name": "精炼",
	}, setup_state, 0)

	var close_state := _make_state(5)
	var scream_tail := _make_slot(_make_scream_tail())
	scream_tail.attached_energy = [
		CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0),
	]
	scream_tail.damage_counters = 40
	var close_kirlia := _make_slot(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"))
	close_state.players[0].active_pokemon = scream_tail
	close_state.players[0].bench = [_make_slot(_make_gardevoir()), close_kirlia]
	close_state.players[0].hand.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	var churn_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": close_kirlia, "ability_name": "精炼",
	}, close_state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": scream_tail, "attack_index": 1,
		"attack_name": "凶暴吼叫", "projected_damage": 80, "projected_knockout": false,
	}, close_state, 0)
	return run_checks([
		assert_true(setup_score >= 600.0, "Kirlia should actively filter while the first Gardevoir and discard fuel are missing"),
		assert_true(churn_score <= -1200.0, "Kirlia should stop drawing once a thin-deck attack route is ready"),
		assert_true(attack_score >= churn_score + 1500.0, "Thin-deck conversion should attack instead of continuing Refinement"),
	])


func test_first_gardevoir_evolution_is_forced_but_the_last_kirlia_is_preserved() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_state(24)
	var first_kirlia := _make_slot(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"))
	var second_kirlia := _make_slot(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"))
	state.players[0].active_pokemon = first_kirlia
	state.players[0].bench = [second_kirlia]
	var exposed_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve", "card": CardInstance.create(_make_gardevoir(), 0), "target_slot": first_kirlia,
	}, state, 0)
	var first_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve", "card": CardInstance.create(_make_gardevoir(), 0), "target_slot": second_kirlia,
	}, state, 0)

	state.players[0].active_pokemon = _make_slot(_make_gardevoir())
	state.players[0].bench = [second_kirlia]
	var second_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve", "card": CardInstance.create(_make_gardevoir(), 0), "target_slot": second_kirlia,
	}, state, 0)
	return run_checks([
		assert_true(first_score >= 1800.0, "The first Gardevoir ex should be the dominant evolution"),
		assert_true(first_score > exposed_score, "The first Gardevoir ex should be built on the Bench instead of exposing the Active Kirlia"),
		assert_true(second_score <= -800.0, "A second Gardevoir ex should not consume the last Refinement Kirlia"),
	])


func test_rabsca_tm_route_waits_for_a_legal_attack_and_evolves_both_lanes() -> String:
	var strategy := _strategy_for_deck(800018105)
	var state := _make_state(24)
	state.turn_number = 1
	state.first_player_index = 0
	var budew := _make_slot(_make_pokemon("含羞苞", "Budew", "Basic", "G", 30, 0))
	var ralts := _make_slot(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1))
	var rellor := _make_slot(_make_pokemon("虫滚泥", "Rellor", "Basic", "G", 50, 1))
	var support := _make_slot(_make_munkidori())
	state.players[0].active_pokemon = budew
	state.players[0].bench = [ralts, rellor, support]
	var tm := CardInstance.create(_make_tool("招式学习器 进化", "Technical Machine: Evolution"), 0)
	var psychic := CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0)
	state.players[0].hand = [tm, psychic]
	var blocked_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": budew,
	}, state, 0)

	state.turn_number = 2
	var live_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": budew,
	}, state, 0)
	var bench_step := {"id": "evolution_bench", "max_select": 2}
	var context := {"game_state": state, "player_index": 0, "all_items": [ralts, rellor, support]}
	var picked_bench: Array = strategy.call("pick_interaction_items", [support, rellor, ralts], bench_step, context)
	var kirlia := CardInstance.create(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"), 0)
	var rabsca := CardInstance.create(_make_pokemon("虫甲圣", "Rabsca", "Stage 1", "G", 70, 1, "虫滚泥"), 0)
	var unrelated := CardInstance.create(_make_pokemon("辅助进化", "Support Evolution", "Stage 1", "C", 100, 1, "愿增猿"), 0)
	var picked_cards: Array = strategy.call("pick_interaction_items", [unrelated, rabsca, kirlia], {
		"id": "evolution_cards", "max_select": 2,
	}, context)
	return run_checks([
		assert_true(blocked_score <= -2000.0, "TM Evolution must not be attached on the first player's attack-locked turn"),
		assert_true(live_score >= 1200.0, "TM Evolution should become dominant when both Stage 1 lanes can be built"),
		assert_true(picked_bench.size() == 2 and ralts in picked_bench and rellor in picked_bench, "TM Evolution should select Ralts and Rellor together"),
		assert_true(picked_cards.size() == 2 and kirlia in picked_cards and rabsca in picked_cards, "TM Evolution should fetch Kirlia and Rabsca together"),
	])


func test_real_tm_followup_evolves_two_ralts_with_two_kirlia() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_state(24)
	var player := state.players[0]
	var carrier := _make_slot(_make_pokemon("含羞苞", "Budew", "Basic", "G", 30, 0))
	var first_ralts := _make_slot(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1))
	var second_ralts := _make_slot(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1))
	var first_kirlia := CardInstance.create(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"), 0)
	var second_kirlia := CardInstance.create(_make_pokemon("奇鲁莉安", "Kirlia", "Stage 1", "P", 80, 2, "拉鲁拉丝"), 0)
	player.active_pokemon = carrier
	player.bench = [first_ralts, second_ralts]
	player.deck = [first_kirlia, second_kirlia]

	var effect := AttackTMEvolutionScript.new(2)
	var initial_steps: Array[Dictionary] = effect.get_granted_attack_interaction_steps(
		carrier,
		{"id": "tm_evolution"},
		state
	)
	var bench_step: Dictionary = initial_steps[0] if not initial_steps.is_empty() else {}
	var context := {"game_state": state, "player_index": 0}
	var picked_bench: Array = strategy.call("pick_interaction_items", bench_step.get("items", []), bench_step, context)
	var followup_raw: Variant = effect.get_followup_granted_attack_interaction_steps(
		carrier,
		{"id": "tm_evolution"},
		state,
		{"evolution_bench": picked_bench}
	)
	var followup_steps: Array[Dictionary] = followup_raw if followup_raw is Array else []
	var card_step: Dictionary = followup_steps[0] if not followup_steps.is_empty() else {}
	var picked_cards: Array = strategy.call("pick_interaction_items", card_step.get("items", []), card_step, context)
	if picked_bench.size() == 2 and picked_cards.size() == 2:
		effect.execute_granted_attack(carrier, {"id": "tm_evolution"}, state, [{
			"evolution_bench": picked_bench,
			"evolution_cards": picked_cards,
		}])
	return run_checks([
		assert_eq(str(bench_step.get("id", "")), "evolution_bench", "Real TM Evolution should start with its Bench selection step"),
		assert_true(picked_bench.size() == 2 and first_ralts in picked_bench and second_ralts in picked_bench, "TM Evolution should keep both same-route Ralts targets"),
		assert_eq(str(card_step.get("id", "")), "evolution_cards", "Real TM Evolution should generate its card-search follow-up"),
		assert_true(picked_cards.size() == 2 and first_kirlia in picked_cards and second_kirlia in picked_cards, "Same-route TM Evolution should not deduplicate the second Kirlia"),
		assert_eq(first_ralts.get_pokemon_name(), "奇鲁莉安", "The first selected Ralts should evolve through the real TM execution path"),
		assert_eq(second_ralts.get_pokemon_name(), "奇鲁莉安", "The second selected Ralts should evolve through the real TM execution path"),
	])


func test_academy_shaymin_is_reserved_for_real_bench_damage_pressure() -> String:
	var strategy := _strategy_for_deck(800018498)
	var state := _make_state(24)
	state.players[0].active_pokemon = _make_slot(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1))
	var spread_attacker_data := _make_pokemon("扩散攻击手", "Spread Attacker", "Basic", "W", 120, 1)
	spread_attacker_data.attacks = [{
		"name": "月光手里剑",
		"cost": "WWC",
		"damage": "",
		"text": "This attack does 90 damage to 2 of your opponent's Benched Pokemon.",
	}]
	state.players[1].active_pokemon = _make_slot(spread_attacker_data)
	var shaymin := CardInstance.create(_make_shaymin(), 0)
	var pressure_contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var pressure_score: float = strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": shaymin,
	}, state, 0)
	var pressure_flags: Dictionary = pressure_contract.get("flags", {})
	spread_attacker_data.attacks[0]["text"] = ""
	var quiet_score: float = strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": shaymin,
	}, state, 0)
	return run_checks([
		assert_true(bool(pressure_flags.get("academy_guard_debt", false)), "Academy Gardevoir should expose Shaymin debt against real Bench damage"),
		assert_true(pressure_score >= quiet_score + 700.0, "Academy Gardevoir should reserve Shaymin for actual Bench damage pressure"),
	])


func test_family_predicts_clefairy_ex_and_emergency_gardevoir_attacks() -> String:
	var strategy := _strategy_for_deck(800018498)
	var clefairy := _make_slot(_make_clefairy_ex())
	clefairy.attached_energy.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	var clefairy_now: Dictionary = strategy.call("predict_attacker_damage", clefairy, 0)
	var clefairy_after: Dictionary = strategy.call("predict_attacker_damage", clefairy, 1)

	var gardevoir := _make_slot(_make_gardevoir())
	gardevoir.attached_energy = [
		CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0),
	]
	var gardevoir_now: Dictionary = strategy.call("predict_attacker_damage", gardevoir, 0)
	var gardevoir_after: Dictionary = strategy.call("predict_attacker_damage", gardevoir, 1)
	return run_checks([
		assert_eq(int(clefairy_now.get("damage", 0)), 20, "Clefairy ex prediction should expose Full Moon Rondo's guaranteed base damage"),
		assert_false(bool(clefairy_now.get("can_attack", false)), "Clefairy ex should still need its second attack energy"),
		assert_true(bool(clefairy_after.get("can_attack", false)), "One additional Psychic Embrace should complete Clefairy ex's PC cost"),
		assert_eq(int(gardevoir_now.get("damage", 0)), 190, "Emergency Gardevoir prediction should expose Miracle Force's printed damage"),
		assert_false(bool(gardevoir_now.get("can_attack", false)), "Two Energy should not satisfy Gardevoir ex's PPC cost"),
		assert_true(bool(gardevoir_after.get("can_attack", false)), "One additional Psychic Embrace should complete the emergency Gardevoir route"),
	])


func test_darkness_attachment_activates_munkidori_instead_of_stranding_on_gardevoir() -> String:
	var strategy := _strategy_for_deck(800018497)
	var state := _make_state(24)
	var scream_tail := _make_slot(_make_scream_tail())
	var gardevoir := _make_slot(_make_gardevoir())
	var munkidori := _make_slot(_make_munkidori())
	state.players[0].active_pokemon = scream_tail
	state.players[0].bench = [gardevoir, munkidori]
	var darkness := CardInstance.create(_make_energy("基本恶能量", "Darkness Energy", "D"), 0)
	state.players[0].hand = [darkness]
	var munkidori_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": darkness, "target_slot": munkidori,
	}, state, 0)
	var gardevoir_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": darkness, "target_slot": gardevoir,
	}, state, 0)
	return assert_true(
		munkidori_score >= gardevoir_score + 1800.0,
		"Darkness Energy should turn on Adrena-Brain instead of becoming dead Gardevoir attachment (Munkidori=%f Gardevoir=%f)" % [munkidori_score, gardevoir_score]
	)


func test_psychic_embrace_finishes_the_active_attacker_before_optional_insurance() -> String:
	var strategy := _strategy_for_deck(800018498)
	var state := _make_state(24)
	var scream_tail := _make_slot(_make_scream_tail())
	var gardevoir := _make_slot(_make_gardevoir())
	scream_tail.attached_energy.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	state.players[0].active_pokemon = scream_tail
	state.players[0].bench = [gardevoir]
	state.players[0].discard_pile.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	var step := {"id": "embrace_target", "max_select": 1}
	var context := {"game_state": state, "player_index": 0, "all_items": [scream_tail, gardevoir]}
	var attacker_score: float = strategy.call("score_interaction_target", scream_tail, step, context)
	var insurance_score: float = strategy.call("score_interaction_target", gardevoir, step, context)
	var picked: Array = strategy.call("pick_interaction_items", [gardevoir, scream_tail], step, context)
	return run_checks([
		assert_true(attacker_score >= insurance_score + 500.0, "Psychic Embrace should first complete the Active one-prize attack route"),
		assert_true(picked.size() == 1 and picked[0] == scream_tail, "Psychic Embrace should deterministically select the Active attacker"),
	])


func test_low_deck_active_gardevoir_converts_into_an_emergency_attack_route() -> String:
	var strategy := _strategy_for_deck(800017097)
	var state := _make_state(5)
	var gardevoir := _make_slot(_make_gardevoir())
	gardevoir.attached_energy = [
		CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0),
	]
	state.players[0].active_pokemon = gardevoir
	state.players[0].bench = [
		_make_slot(_make_pokemon("拉鲁拉丝", "Ralts", "Basic", "P", 70, 1)),
		_make_slot(_make_munkidori()),
	]
	state.players[0].discard_pile.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	var step := {"id": "embrace_target", "max_select": 1}
	var context := {"game_state": state, "player_index": 0, "all_items": [gardevoir]}
	var charging_contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var embrace_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": gardevoir,
	}, state, 0)
	var picked: Array = strategy.call("pick_interaction_items", [gardevoir], step, context)

	gardevoir.attached_energy.append(CardInstance.create(_make_energy("基本超能量", "Psychic Energy", "P"), 0))
	var ready_contract: Dictionary = strategy.call("build_turn_contract", state, 0, {})
	var attack_score: float = strategy.call("score_action_absolute", {
		"kind": "attack", "source_slot": gardevoir, "attack_index": 0,
		"attack_name": "奇迹之力", "projected_damage": 190, "projected_knockout": false,
	}, state, 0)
	return run_checks([
		assert_eq(str(charging_contract.get("intent", "")), "embrace_gardevoir_fallback", "Low-deck Gardevoir should finish its own attack cost when no one-prize attacker exists"),
		assert_true(embrace_score >= 1500.0, "Psychic Embrace should be live for the low-deck emergency route"),
		assert_true(picked.size() == 1 and picked[0] == gardevoir, "Psychic Embrace should target the stranded Active Gardevoir"),
		assert_eq(str(ready_contract.get("intent", "")), "convert_gardevoir_fallback", "A powered Active Gardevoir should convert instead of drawing toward deck-out"),
		assert_true(attack_score >= 1600.0, "The 190-damage emergency attack should outrank additional engine churn"),
	])


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var script: Variant = load(STRATEGY_PATH)
	if not script is GDScript:
		return null
	var strategy: RefCounted = (script as GDScript).new()
	var deck := _load_deck(deck_id)
	if deck != null:
		strategy.call("configure_from_deck", deck)
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _make_state(deck_size: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	for index: int in deck_size:
		player.deck.append(CardInstance.create(_make_trainer("Deck card %d" % index), 0))
	for index: int in 6:
		player.prizes.append(CardInstance.create(_make_trainer("Prize %d" % index), 0))
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, 0))
	return slot


func _make_pokemon(
	name: String,
	name_en: String,
	stage: String,
	energy_type: String,
	hp: int,
	retreat_cost: int,
	evolves_from: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = stage
	card.energy_type = energy_type
	card.hp = hp
	card.retreat_cost = retreat_cost
	card.evolves_from = evolves_from
	card.attacks = [{"name": "Test attack", "cost": "C", "damage": "10", "text": ""}]
	return card


func _make_gardevoir() -> CardData:
	var card := _make_pokemon("沙奈朵ex", "Gardevoir ex", "Stage 2", "P", 310, 2, "奇鲁莉安")
	card.mechanic = "ex"
	card.abilities = [{"name": "精神拥抱", "text": "Attach Psychic Energy from discard."}]
	card.attacks = [{"name": "奇迹之力", "cost": "PPC", "damage": "190", "text": ""}]
	return card


func _make_clefairy_ex() -> CardData:
	var card := _make_pokemon("莉莉艾的皮皮ex", "Lillie's Clefairy ex", "Basic", "P", 190, 1)
	card.mechanic = "ex"
	card.attacks = [{
		"name": "满月回旋曲",
		"cost": "PC",
		"damage": "20+",
		"text": "追加造成双方备战宝可梦数量x20伤害。",
	}]
	return card


func _make_shaymin() -> CardData:
	var card := _make_pokemon("谢米", "", "Basic", "G", 80, 1)
	card.abilities = [{
		"name": "花之纱幔",
		"text": "自己的备战区没有规则框的宝可梦不会受到对手招式的伤害。",
	}]
	card.attacks = [{"name": "踢飞", "cost": "CC", "damage": "30", "text": ""}]
	return card


func _make_scream_tail() -> CardData:
	var card := _make_pokemon("吼叫尾", "Scream Tail", "Basic", "P", 90, 1)
	card.attacks = [
		{"name": "巴掌", "cost": "P", "damage": "30", "text": ""},
		{"name": "凶暴吼叫", "cost": "PC", "damage": "", "text": "Damage based on this Pokemon's damage counters."},
	]
	return card


func _make_munkidori() -> CardData:
	var card := _make_pokemon("愿增猿", "Munkidori", "Basic", "P", 110, 1)
	card.abilities = [{"name": "亢奋脑力", "text": "Move damage counters while Darkness Energy is attached."}]
	return card


func _make_energy(name: String, name_en: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _make_tool(name: String, name_en: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Tool"
	return card


func _make_trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Supporter"
	return card
