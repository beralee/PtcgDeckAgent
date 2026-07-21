class_name TestV18HopFroslassStrategy
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18HopFroslass.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const HOP_DECK_ID := 800017407
const FROSLASS_DECK_ID := 800017631


func test_real_decklists_configure_both_family_identities() -> String:
	var hop_deck := _load_deck(HOP_DECK_ID)
	var froslass_deck := _load_deck(FROSLASS_DECK_ID)
	var hop_strategy := _strategy_for_deck(HOP_DECK_ID)
	var froslass_strategy := _strategy_for_deck(FROSLASS_DECK_ID)
	return run_checks([
		assert_not_null(hop_deck, "The bundled Hop deck should load from its real JSON"),
		assert_not_null(froslass_deck, "The bundled Froslass deck should load from its real JSON"),
		assert_eq(_deck_count(hop_deck, "CSV10C", "161"), 2, "The real Hop list should contain two Hop's Zacian ex"),
		assert_eq(_deck_count(hop_deck, "CSV10C", "175"), 2, "The real Hop list should contain two Hop's Snorlax"),
		assert_eq(_deck_count(hop_deck, "CSV8C", "094"), 2, "The real Hop list should contain two Munkidori"),
		assert_eq(_deck_count(froslass_deck, "CSV7C", "059"), 4, "The real Froslass list should contain four Froslass"),
		assert_eq(_deck_count(froslass_deck, "CSV8C", "094"), 4, "The real Froslass list should contain four Munkidori"),
		assert_eq(str(hop_strategy.call("get_strategy_id")), "v18_hop_froslass_800017407_delegate", "Hop should use its deck-scoped family identity"),
		assert_eq(str(froslass_strategy.call("get_strategy_id")), "v18_hop_froslass_800017631_delegate", "Froslass should use its deck-scoped family identity"),
	])


func test_normal_and_strong_orders_share_the_same_opening_delegate() -> String:
	var checks: Array[String] = []
	for deck_id: int in [HOP_DECK_ID, FROSLASS_DECK_ID]:
		var normal := _strategy_for_deck(deck_id)
		var strong := _strategy_for_deck(deck_id)
		var normal_player := _fixed_opening_player(deck_id)
		var strong_player := _fixed_opening_player(deck_id)
		var normal_plan: Dictionary = normal.call("plan_opening_setup", normal_player)
		var strong_plan: Dictionary = strong.call("plan_opening_setup", strong_player)
		checks.append(assert_eq(
			int(normal_plan.get("active_hand_index", -1)),
			int(strong_plan.get("active_hand_index", -1)),
			"Normal and strong deck order should use the same delegate opening policy for deck %d" % deck_id
		))
		checks.append(assert_eq(
			normal_plan.get("bench_hand_indices", []),
			strong_plan.get("bench_hand_indices", []),
			"Normal and strong deck order should produce the same bench policy for deck %d" % deck_id
		))
		var active_index := int(strong_plan.get("active_hand_index", -1))
		var active_name := _card_name(strong_player.hand[active_index]) if active_index >= 0 else ""
		var expected := "赫普的苍响ex" if deck_id == HOP_DECK_ID else "含羞苞"
		checks.append(assert_eq(active_name, expected, "The fixed opening should still choose the deck's tactical pivot"))
	return run_checks(checks)


func test_family_turn_contracts_keep_v18_ownership_and_safety_shape() -> String:
	var checks: Array[String] = []
	for deck_id: int in [HOP_DECK_ID, FROSLASS_DECK_ID]:
		var strategy := _strategy_for_deck(deck_id)
		var state := _make_state()
		var player: PlayerState = state.players[0]
		if deck_id == HOP_DECK_ID:
			player.active_pokemon = _slot(_pokemon("赫普的苍响ex", "Hop's Zacian ex", "Basic", "", "C", "30", "CSV10C", "161"))
		else:
			player.active_pokemon = _slot(_pokemon("含羞苞", "Budew", "Basic", "", "", "10", "CSV9.5C", "004"))
		var contract: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
		var priorities: Dictionary = contract.get("priorities", {})
		var constraints: Dictionary = contract.get("constraints", {})
		checks.append(assert_true(str(contract.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Deck %d should emit a V18 phase" % deck_id))
		checks.append(assert_true(contract.get("owner", null) is Dictionary, "Deck %d should declare route ownership" % deck_id))
		for key: String in ["attach", "handoff", "search", "evolve", "ability", "trainer"]:
			checks.append(assert_true(priorities.has(key), "Deck %d should expose %s priorities" % [deck_id, key]))
		checks.append(assert_true(constraints.has("forbid_engine_churn"), "Deck %d should expose the deck churn guard" % deck_id))
		checks.append(assert_true(constraints.has("forbid_extra_bench_padding"), "Deck %d should expose the bench padding guard" % deck_id))
	return run_checks(checks)


func test_hop_bag_builds_distinct_zacian_and_snorlax_core() -> String:
	var strategy := _strategy_for_deck(HOP_DECK_ID)
	var state := _make_state()
	var snorlax_a := _instance(_pokemon("赫普的卡比兽", "Hop's Snorlax", "Basic", "", "CCC", "140", "CSV10C", "175"))
	var snorlax_b := _instance(_pokemon("赫普的卡比兽", "Hop's Snorlax", "Basic", "", "CCC", "140", "CSV10C", "175"))
	var zacian := _instance(_pokemon("赫普的苍响ex", "Hop's Zacian ex", "Basic", "", "C", "30", "CSV10C", "161"))
	var cramorant := _instance(_pokemon("赫普的古月鸟", "Hop's Cramorant", "Basic", "", "C", "120", "CSV10C", "188"))
	var picked: Array = strategy.call("pick_interaction_items", [snorlax_a, snorlax_b, zacian, cramorant], {
		"id": "csv10c_hop_bag_targets",
		"max_select": 2,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 2, "Hop's Bag should take two core Basics when both are missing"),
		assert_true(_items_have_name(picked, "赫普的卡比兽"), "Hop's Bag should establish the non-stacking Snorlax boost"),
		assert_true(_items_have_name(picked, "赫普的苍响ex"), "Hop's Bag should establish the early one-Energy Zacian lane"),
		assert_eq(_items_count_name(picked, "赫普的卡比兽"), 1, "Hop's Bag should not pad the opening with duplicate Snorlax"),
	])


func test_hop_energy_follows_early_midgame_and_damage_transfer_windows() -> String:
	var strategy := _strategy_for_deck(HOP_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var zacian := _slot(_pokemon("赫普的苍响ex", "Hop's Zacian ex", "Basic", "", "C", "30", "CSV10C", "161"))
	var cramorant := _slot(_pokemon("赫普的古月鸟", "Hop's Cramorant", "Basic", "", "C", "120", "CSV10C", "188"))
	var snorlax := _slot(_pokemon("赫普的卡比兽", "Hop's Snorlax", "Basic", "", "CCC", "140", "CSV10C", "175"))
	var munkidori := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094"))
	player.active_pokemon = zacian
	player.bench.assign([cramorant, snorlax, munkidori])
	var darkness := _instance(_energy("基本恶能量", "Darkness Energy", "D", "CSVE1C", "DAR"))
	var zacian_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": zacian}, state, 0)
	var closed_cramorant_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": cramorant}, state, 0)
	zacian.attached_energy.append(_instance(_energy("基本恶能量", "Darkness Energy", "D")))
	_set_prize_count(state.players[1], 4)
	var window_cramorant_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": cramorant}, state, 0)
	var funded_zacian_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": zacian}, state, 0)
	snorlax.damage_counters = 80
	var munkidori_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}, state, 0)
	var off_route := _slot(_pokemon("米立龙", "Tatsugiri", "Basic", "", "C", "10"))
	var off_route_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": off_route}, state, 0)
	return run_checks([
		assert_true(zacian_score >= closed_cramorant_score + 2500.0, "Before the 4/3-Prize window, the first attachment should launch Zacian instead of dead Cramorant"),
		assert_true(window_cramorant_score >= funded_zacian_score + 2500.0, "At four opponent Prizes, Energy should move to Cramorant instead of overfunding Zacian"),
		assert_true(munkidori_score >= off_route_score + 1800.0, "Once self-damage exists, Darkness Energy should activate Munkidori instead of a support body"),
	])


func test_hop_cramorant_attack_is_hard_gated_to_four_or_three_prizes() -> String:
	var strategy := _strategy_for_deck(HOP_DECK_ID)
	var state := _make_state()
	var cramorant := _slot(_pokemon("赫普的古月鸟", "Hop's Cramorant", "Basic", "", "C", "120", "CSV10C", "188"))
	cramorant.attached_energy.append(_instance(_energy("基本恶能量", "Darkness Energy", "D")))
	state.players[0].active_pokemon = cramorant
	var action := {
		"kind": "attack",
		"source_slot": cramorant,
		"attack_name": "随性喷吐",
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var closed_score: float = strategy.call("score_action_absolute", action, state, 0)
	_set_prize_count(state.players[1], 3)
	var open_score: float = strategy.call("score_action_absolute", action, state, 0)
	return run_checks([
		assert_true(closed_score <= -5000.0, "Cramorant's attack should be rejected outside its exact Prize window"),
		assert_true(open_score >= closed_score + 8000.0, "Three remaining opponent Prizes should reopen Cramorant's 120-damage route"),
	])


func test_froslass_energy_prioritizes_unpowered_munkidori_not_passive_froslass() -> String:
	var strategy := _strategy_for_deck(FROSLASS_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var budew := _slot(_pokemon("含羞苞", "Budew", "Basic", "", "", "10", "CSV9.5C", "004"))
	var munkidori := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094"))
	var froslass := _slot(_pokemon("雪妖女", "Froslass", "Stage 1", "雪童子", "WC", "60", "CSV7C", "059"))
	player.active_pokemon = budew
	player.bench.assign([munkidori, froslass])
	var darkness := _instance(_energy("基本恶能量", "Darkness Energy", "D", "CSVE1C", "DAR"))
	var munkidori_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}, state, 0)
	var froslass_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": darkness, "target_slot": froslass}, state, 0)
	return assert_true(
		munkidori_score >= froslass_score + 6000.0,
		"Darkness Energy should activate Adrena-Brain instead of funding passive Froslass with the wrong type"
	)


func test_froslass_evolution_and_tm_interactions_complete_two_snow_lines() -> String:
	var strategy := _strategy_for_deck(FROSLASS_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var budew := _slot(_pokemon("含羞苞", "Budew", "Basic", "", "", "10", "CSV9.5C", "004"))
	var snorunt_a := _slot(_pokemon("雪童子", "Snorunt", "Basic", "", "WC", "20", "CSV9.5C", "043"))
	var snorunt_b := _slot(_pokemon("雪童子", "Snorunt", "Basic", "", "WC", "20", "CSV9.5C", "043"))
	var munkidori := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094"))
	player.active_pokemon = budew
	player.bench.assign([snorunt_a, snorunt_b, munkidori])
	var froslass_a := _instance(_pokemon("雪妖女", "Froslass", "Stage 1", "雪童子", "WC", "60", "CSV7C", "059"))
	var froslass_b := _instance(_pokemon("雪妖女", "Froslass", "Stage 1", "雪童子", "WC", "60", "CSV7C", "059"))
	player.deck.append_array([froslass_a, froslass_b])
	var unrelated := _instance(_pokemon("无关一阶", "Filler Stage 1", "Stage 1", "无关基础", "C", "20"))
	var bench_score: float = strategy.call("score_interaction_target", snorunt_a, {"id": "evolution_bench"}, {"game_state": state, "player_index": 0})
	var munkidori_bench_score: float = strategy.call("score_interaction_target", munkidori, {"id": "evolution_bench"}, {"game_state": state, "player_index": 0})
	var card_score: float = strategy.call("score_interaction_target", froslass_a, {"id": "evolution_cards"}, {"game_state": state, "player_index": 0})
	var unrelated_score: float = strategy.call("score_interaction_target", unrelated, {"id": "evolution_cards"}, {"game_state": state, "player_index": 0})
	var tm_attack_score: float = strategy.call("score_action_absolute", {
		"kind": "granted_attack",
		"source_slot": budew,
		"attack_id": "tm_evolution",
		"attack_name": "进化",
	}, state, 0)
	return run_checks([
		assert_true(bench_score >= munkidori_bench_score + 5000.0, "TM Evolution should select Snorunt, not the damage-transfer engine"),
		assert_true(card_score >= unrelated_score + 6000.0, "TM Evolution should choose the matching Froslass cards"),
		assert_true(tm_attack_score >= 6400.0, "Two live Snorunt should make the TM Evolution attack a setup priority"),
	])


func test_munkidori_interactions_heal_the_best_source_and_finish_damaged_rule_box() -> String:
	var strategy := _strategy_for_deck(HOP_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var snorlax := _slot(_pokemon("赫普的卡比兽", "Hop's Snorlax", "Basic", "", "CCC", "140", "CSV10C", "175", 150))
	snorlax.damage_counters = 80
	var zacian := _slot(_pokemon("赫普的苍响ex", "Hop's Zacian ex", "Basic", "", "C", "30", "CSV10C", "161", 230))
	var munkidori := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094"))
	munkidori.attached_energy.append(_instance(_energy("基本恶能量", "Darkness Energy", "D")))
	player.active_pokemon = zacian
	player.bench.assign([snorlax, munkidori])
	var ability_score: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": munkidori}, state, 0)
	var damaged_source_score: float = strategy.call("score_interaction_target", snorlax, {"id": "source_pokemon"}, {"game_state": state, "player_index": 0})
	var clean_source_score: float = strategy.call("score_interaction_target", zacian, {"id": "source_pokemon"}, {"game_state": state, "player_index": 0})
	var lethal_target := _slot(_pokemon("对手ex", "Opponent ex", "Basic", "", "C", "100", "", "", 100, "ex"), 1)
	lethal_target.damage_counters = 80
	var healthy_target := _slot(_pokemon("对手后备", "Opponent Bench", "Basic", "", "C", "20", "", "", 180), 1)
	state.players[1].active_pokemon = healthy_target
	state.players[1].bench.append(lethal_target)
	var lethal_score: float = strategy.call("score_interaction_target", lethal_target, {"id": "target_damage_counters"}, {"game_state": state, "player_index": 0})
	var healthy_score: float = strategy.call("score_interaction_target", healthy_target, {"id": "target_damage_counters"}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(ability_score >= 5900.0, "A powered Munkidori with movable damage should use Adrena-Brain"),
		assert_true(damaged_source_score >= clean_source_score + 4000.0, "Adrena-Brain should remove counters from the damaged Snorlax"),
		assert_true(lethal_score >= healthy_score + 4500.0, "Transferred counters should finish a damaged rule-box target before spreading damage"),
	])


func test_contextual_discard_and_recovery_protect_live_engine_pieces() -> String:
	var strategy := _strategy_for_deck(FROSLASS_DECK_ID)
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var budew := _slot(_pokemon("含羞苞", "Budew", "Basic", "", "", "10", "CSV9.5C", "004"))
	var snorunt := _slot(_pokemon("雪童子", "Snorunt", "Basic", "", "WC", "20", "CSV9.5C", "043"))
	var munkidori := _slot(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094"))
	player.active_pokemon = budew
	player.bench.assign([snorunt, munkidori])
	var froslass := _instance(_pokemon("雪妖女", "Froslass", "Stage 1", "雪童子", "WC", "60", "CSV7C", "059"))
	var darkness := _instance(_energy("基本恶能量", "Darkness Energy", "D", "CSVE1C", "DAR"))
	var research := _instance(_trainer("博士的研究", "Professor's Research", "Supporter"))
	player.hand.assign([froslass, darkness, research])
	var froslass_discard := int(strategy.call("get_discard_priority_contextual", froslass, state, 0))
	var darkness_discard := int(strategy.call("get_discard_priority_contextual", darkness, state, 0))
	var research_discard := int(strategy.call("get_discard_priority_contextual", research, state, 0))
	player.hand.assign([research])
	player.discard_pile.assign([froslass, darkness, _instance(_pokemon("填充宝可梦", "Filler Pokemon", "Basic", "", "C", "10"))])
	var recovery_step := {"id": "night_stretcher_choice"}
	var recovery_context := {"game_state": state, "player_index": 0}
	var froslass_recovery: float = strategy.call("score_interaction_target", froslass, recovery_step, recovery_context)
	var darkness_recovery: float = strategy.call("score_interaction_target", darkness, recovery_step, recovery_context)
	return run_checks([
		assert_true(froslass_discard < research_discard - 80, "Discard costs should preserve Froslass that completes the live Snorunt"),
		assert_true(darkness_discard < research_discard - 80, "Discard costs should preserve the only Darkness Energy for unpowered Munkidori"),
		assert_true(froslass_recovery >= darkness_recovery + 800.0, "Night Stretcher should restore the immediately playable Froslass before spare Energy"),
	])


func test_low_deck_guard_stops_draw_and_search_engines_for_both_decks() -> String:
	var checks: Array[String] = []
	for deck_id: int in [HOP_DECK_ID, FROSLASS_DECK_ID]:
		var strategy := _strategy_for_deck(deck_id)
		var state := _make_state()
		var player: PlayerState = state.players[0]
		player.deck.clear()
		for index: int in 3:
			player.deck.append(_instance(_trainer("低牌库卡%d" % index, "Deck Card %d" % index, "Item")))
		if deck_id == HOP_DECK_ID:
			var zacian := _slot(_pokemon("赫普的苍响ex", "Hop's Zacian ex", "Basic", "", "C", "30", "CSV10C", "161"))
			zacian.attached_energy.append(_instance(_energy("基本恶能量", "Darkness Energy", "D")))
			player.active_pokemon = zacian
		else:
			player.active_pokemon = _slot(_pokemon("含羞苞", "Budew", "Basic", "", "", "10", "CSV9.5C", "004"))
		var research := _instance(_trainer("博士的研究", "Professor's Research", "Supporter"))
		var churn_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": research}, state, 0)
		var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
		var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
		checks.append(assert_true(churn_score <= -7000.0, "Deck %d should hard-stop Research with only three cards left" % deck_id))
		checks.append(assert_true(churn_score <= end_score - 6000.0, "Deck %d should prefer stopping over forced deck-out churn" % deck_id))
		checks.append(assert_true(bool((plan.get("constraints", {}) as Dictionary).get("forbid_engine_churn", false)), "Deck %d should expose low-deck shutdown in its turn contract" % deck_id))
	return run_checks(checks)


func test_key_cards_match_english_names_and_uids() -> String:
	var hop_strategy := _strategy_for_deck(HOP_DECK_ID)
	var froslass_strategy := _strategy_for_deck(FROSLASS_DECK_ID)
	var english_snorlax := _instance(_pokemon("Hop's Snorlax", "Hop's Snorlax", "Basic", "", "CCC", "140"))
	var uid_froslass_data := _pokemon("Imported Stage 1", "Imported Stage 1", "Stage 1", "Snorunt", "WC", "60")
	uid_froslass_data.set_code = "CSV7C"
	uid_froslass_data.card_index = "059"
	var uid_froslass := _instance(uid_froslass_data)
	return run_checks([
		assert_true(int(hop_strategy.call("get_search_priority", english_snorlax)) >= 1000, "English Hop identities should preserve the Snorlax route"),
		assert_true(int(froslass_strategy.call("get_search_priority", uid_froslass)) >= 1000, "Card UID matching should preserve the Froslass evolution route"),
	])


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var deck := _load_deck(deck_id)
	if deck == null:
		deck = DeckData.new()
		deck.id = deck_id
	strategy.call("configure_from_deck", deck)
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


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
	if deck_id == HOP_DECK_ID:
		player.hand.assign([
			_instance(_pokemon("赫普的古月鸟", "Hop's Cramorant", "Basic", "", "C", "120", "CSV10C", "188")),
			_instance(_pokemon("赫普的苍响ex", "Hop's Zacian ex", "Basic", "", "C", "30", "CSV10C", "161")),
			_instance(_trainer("赫普的包包", "Hop's Bag", "Item", "CSV10C", "195")),
			_instance(_trainer("赫普的讲究头带", "Hop's Choice Band", "Tool", "CSV10C", "201")),
			_instance(_energy("基本恶能量", "Darkness Energy", "D")),
			_instance(_energy("基本恶能量", "Darkness Energy", "D")),
			_instance(_pokemon("赫普的卡比兽", "Hop's Snorlax", "Basic", "", "CCC", "140", "CSV10C", "175")),
		])
	else:
		player.hand.assign([
			_instance(_pokemon("含羞苞", "Budew", "Basic", "", "", "10", "CSV9.5C", "004")),
			_instance(_pokemon("雪童子", "Snorunt", "Basic", "", "WC", "20", "CSV9.5C", "043")),
			_instance(_trainer("友好宝芬", "Buddy-Buddy Poffin", "Item", "CSV7C", "177")),
			_instance(_trainer("夜间担架", "Night Stretcher", "Item", "CSV8C", "183")),
			_instance(_energy("基本恶能量", "Darkness Energy", "D")),
			_instance(_energy("基本恶能量", "Darkness Energy", "D")),
			_instance(_pokemon("愿增猿", "Munkidori", "Basic", "", "PC", "60", "CSV8C", "094")),
		])
	return player


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	_set_prize_count(player, 6)
	_set_prize_count(opponent, 6)
	for index: int in 12:
		player.deck.append(_instance(_trainer("牌库填充%d" % index, "Deck Filler %d" % index, "Item")))
	return state


func _set_prize_count(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_instance(_trainer("奖赏%d" % index, "Prize %d" % index, "Item")))


func _slot(card_data: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot


func _instance(card_data: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(card_data, owner_index)


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
	mechanic: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.name_zh = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = "D"
	card.hp = hp
	card.mechanic = mechanic
	card.set_code = set_code
	card.card_index = card_index
	card.attacks = [{"name": "测试招式", "cost": cost, "damage": damage, "text": ""}]
	return card


func _energy(
	name: String,
	name_en: String,
	provides: String,
	set_code: String = "",
	card_index: String = ""
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
	return card


func _trainer(
	name: String,
	name_en: String,
	card_type: String,
	set_code: String = "",
	card_index: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.name_zh = name
	card.card_type = card_type
	card.set_code = set_code
	card.card_index = card_index
	return card


func _card_name(item: Variant) -> String:
	if item is CardInstance and (item as CardInstance).card_data != null:
		return str((item as CardInstance).card_data.name)
	return ""


func _items_have_name(items: Array, name: String) -> bool:
	return _items_count_name(items, name) > 0


func _items_count_name(items: Array, name: String) -> int:
	var count := 0
	for item: Variant in items:
		if _card_name(item) == name:
			count += 1
	return count
