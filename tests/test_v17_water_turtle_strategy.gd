class_name TestV17WaterTurtleStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategy17WaterTurtle.gd"


func test_intent_profile_marks_terapagos_as_scaling_attacker() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var profile: Dictionary = strategy.get_intent_planner_profile()
	var scaling: Array = profile.get("scaling_attackers", [])
	var support: Array = profile.get("support_only", [])
	return run_checks([
		assert_true("太乐巴戈斯ex" in scaling, "Intent profile should match Terapagos by runtime card name"),
		assert_true("猫头夜鹰" in support, "Noctowl should be marked support-only for manual attach planning"),
	])


func test_manual_water_attach_prioritizes_terapagos_over_support_slots() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Bidoof", "Bidoof", "Basic", "C", 60, "CS5bC", "111"), 0)
	var terapagos := _make_slot(_make_pokemon_cd("太乐巴戈斯ex", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
		{"name": "Crown Opal", "cost": "GWL", "damage": "180"},
	]), 0)
	var noctowl := _make_slot(_make_pokemon_cd("猫头夜鹰", "", "Stage 1", "C", 100, "CSV9C", "155"), 0)
	player.bench.append(terapagos)
	player.bench.append(noctowl)
	var water := CardInstance.create(_make_energy_cd("Water Energy", "W"), 0)
	var terapagos_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": terapagos}, gs, 0)
	var bidoof_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": player.active_pokemon}, gs, 0)
	var noctowl_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": noctowl}, gs, 0)
	return run_checks([
		assert_true(
			terapagos_score > bidoof_score + 300.0,
			"Manual Water attach should prefer Terapagos over active Bidoof (Terapagos=%f Bidoof=%f)" % [terapagos_score, bidoof_score]
		),
		assert_true(
			terapagos_score > noctowl_score + 300.0,
			"Manual Water attach should prefer Terapagos over Noctowl support padding (Terapagos=%f Noctowl=%f)" % [terapagos_score, noctowl_score]
		),
	])


func test_opening_setup_keeps_high_hp_attacker_active_when_support_basics_exist() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var player := PlayerState.new()
	player.player_index = 0
	var hoothoot := CardInstance.create(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	var terapagos := CardInstance.create(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	var fan_rotom := CardInstance.create(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0)
	player.hand.append(hoothoot)
	player.hand.append(terapagos)
	player.hand.append(fan_rotom)
	var plan: Dictionary = strategy.plan_opening_setup(player)
	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 1, "Opening should put Terapagos active instead of exposing 70HP support basics"),
		assert_true((plan.get("bench_hand_indices", []) as Array).has(0), "Opening should still bench Hoothoot for Noctowl"),
		assert_true((plan.get("bench_hand_indices", []) as Array).has(2), "Opening should still bench Fan Rotom for first-turn setup"),
	])


func test_terapagos_damage_prediction_handles_csv9c_multiplier_symbol() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var multiplier_damage := "30" + String.chr(0x8133)
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": multiplier_damage},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var prediction: Dictionary = strategy.predict_attacker_damage(terapagos)
	return assert_true(
		int(prediction.get("damage", 0)) >= 150,
		"Terapagos CSV9C multiplier damage should not be parsed as flat 30 (%s)" % str(prediction)
	)


func test_palkia_vstar_prediction_uses_area_zero_shell_expectation() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var palkia_vstar := _make_slot(_make_pokemon_cd("Palkia VSTAR Test", "Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "CS5bC", "051", "V", [
		{"name": "Subspace Swell", "cost": "WW", "damage": "60+"},
	]), 0)
	palkia_vstar.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	palkia_vstar.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var prediction: Dictionary = strategy.predict_attacker_damage(palkia_vstar)
	return assert_true(
		int(prediction.get("damage", 0)) >= 260,
		"Palkia VSTAR generic damage prediction should reflect the normal Area Zero bench shell (%s)" % str(prediction)
	)


func test_palkia_v_zero_damage_stadium_search_is_suppressed_when_area_zero_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V", [
		{"name": "Stadium Search", "cost": "W", "damage": ""},
		{"name": "Hydro Break", "cost": "WWC", "damage": "200"},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	gs.stadium_card = CardInstance.create(_make_trainer_cd("Area Zero Underdepths", "Area Zero Underdepths", "Stadium", "CSV9C", "207"), 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"projected_damage": 0,
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		attack_score < end_score,
		"Palkia V should not spend the attack on zero-damage Stadium Search after Area Zero is already online (Attack=%f End=%f)" % [attack_score, end_score]
	)


func test_low_bench_terapagos_attack_does_not_claim_false_knockout() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var multiplier_damage := "30" + String.chr(0x8133)
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": multiplier_damage},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Miraidon ex", "Basic", "L", 220, "CSV1C", "037", "ex"), 1)
	var score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": terapagos,
		"projected_damage": 240,
		"projected_knockout": true,
	}, gs, 0)
	return assert_true(
		score < 1500.0,
		"Low-bench Terapagos should score as a 60-damage pressure attack, not a false knockout (score=%f)" % score
	)


func test_opening_poffin_outranks_vessel_when_bench_is_empty() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("起源帕路奇亚V", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V"), 0)
	player.deck.append(CardInstance.create(_make_pokemon_cd("咕咕", "", "Basic", "C", 60, "CSV9C", "154"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("旋转洛托姆", "", "Basic", "C", 70, "CSV9C", "161"), 0))
	var poffin := CardInstance.create(_make_trainer_cd("友好宝芬", "Buddy-Buddy Poffin", "Item", "CSV7C", "177"), 0)
	var vessel := CardInstance.create(_make_trainer_cd("大地容器", "Earthen Vessel", "Item", "CSV6C", "115"), 0)
	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	var vessel_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": vessel}, gs, 0)
	return assert_true(
		poffin_score > vessel_score + 180.0,
		"Opening Poffin should fill an empty bench before Earthen Vessel (Poffin=%f Vessel=%f)" % [poffin_score, vessel_score]
	)


func test_noctowl_trainer_search_avoids_duplicate_area_zero_when_setup_search_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("太乐巴戈斯ex", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	var area_a := CardInstance.create(_make_trainer_cd("零之大空洞", "", "Stadium", "CSV9C", "207"), 0)
	var area_b := CardInstance.create(_make_trainer_cd("零之大空洞", "", "Stadium", "CSV9C", "207"), 0)
	var poffin := CardInstance.create(_make_trainer_cd("友好宝芬", "Buddy-Buddy Poffin", "Item", "CSV7C", "177"), 0)
	var nest := CardInstance.create(_make_trainer_cd("巢穴球", "Nest Ball", "Item", "CSVH1C", "043"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[area_a, area_b, poffin, nest],
		{"id": "csv9c_noctowl_trainers", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var area_count := 0
	var setup_count := 0
	for item: Variant in picked:
		if item is CardInstance:
			if _card_matches(item as CardInstance, "CSV9C", "207"):
				area_count += 1
			if _card_matches(item as CardInstance, "CSV7C", "177") or _card_matches(item as CardInstance, "CSVH1C", "043"):
				setup_count += 1
	return run_checks([
		assert_eq(picked.size(), 2, "Noctowl should pick two trainer cards"),
		assert_eq(area_count, 1, "Noctowl should not spend both searches on duplicate Area Zero"),
		assert_true(setup_count >= 1, "Noctowl should include a bench/search stabilizer when available"),
	])


func test_noctowl_trainer_search_delays_glass_trumpet_without_discard_energy() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("澶箰宸存垐鏂痚x", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	var glass := CardInstance.create(_make_trainer_cd("鐜荤拑鍠囧彮", "Glass Trumpet", "Item", "CSV9C", "178"), 0)
	var vessel := CardInstance.create(_make_trainer_cd("大地容器", "Earthen Vessel", "Item", "CSV6C", "115"), 0)
	var step := {"id": "csv9c_noctowl_trainers", "max_select": 2}
	var context := {"game_state": gs, "player_index": 0}
	var glass_score: float = strategy.score_interaction_target(glass, step, context)
	var vessel_score: float = strategy.score_interaction_target(vessel, step, context)
	return assert_true(
		vessel_score > glass_score + 100.0,
		"Noctowl should fetch Energy access before dead Glass Trumpet when discard has no Energy (Vessel=%f Glass=%f)" % [vessel_score, glass_score]
	)


func test_fan_call_prioritizes_hoothoot_noctowl_and_bibarel_bridge() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof Test", "Bidoof", "Basic", "C", 60, "CS5bC", "111"), 0))
	var hoothoot := CardInstance.create(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	var noctowl := CardInstance.create(_make_pokemon_cd("Noctowl Test", "", "Stage 1", "C", 100, "CSV9C", "155"), 0)
	var bibarel := CardInstance.create(_make_pokemon_cd("Bibarel Test", "Bibarel", "Stage 1", "C", 120, "CS5aC", "105"), 0)
	var bidoof := CardInstance.create(_make_pokemon_cd("Bidoof Test", "Bidoof", "Basic", "C", 60, "CS5bC", "111"), 0)
	var fan_rotom := CardInstance.create(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[fan_rotom, bidoof, bibarel, noctowl, hoothoot],
		{"id": "csv9c_fan_call_cards", "max_select": 3},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_eq(picked.size(), 3, "Fan Call should pick three targets when available"),
		assert_true(_card_matches(picked[0] as CardInstance, "CSV9C", "154"), "First Fan Call target should be the second Hoothoot while fewer than two are in play"),
		assert_true(_card_matches(picked[1] as CardInstance, "CSV9C", "155"), "Second Fan Call target should be Noctowl"),
		assert_true(_card_matches(picked[2] as CardInstance, "CS5aC", "105"), "Third Fan Call target should bridge to Bibarel when Bidoof is already in play"),
	])


func test_fan_call_stops_taking_hoothoot_after_two_are_in_play() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Hoothoot A", "", "Basic", "C", 70, "CSV9C", "154"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Hoothoot B", "", "Basic", "C", 70, "CSV9C", "154"), 0))
	var hoothoot := CardInstance.create(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	var noctowl := CardInstance.create(_make_pokemon_cd("Noctowl Test", "", "Stage 1", "C", 100, "CSV9C", "155"), 0)
	var bidoof := CardInstance.create(_make_pokemon_cd("Bidoof Test", "Bidoof", "Basic", "C", 60, "CS5bC", "111"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[hoothoot, noctowl, bidoof],
		{"id": "csv9c_fan_call_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var has_hoothoot := false
	var has_noctowl := false
	for item: Variant in picked:
		if item is CardInstance:
			has_hoothoot = has_hoothoot or _card_matches(item as CardInstance, "CSV9C", "154")
			has_noctowl = has_noctowl or _card_matches(item as CardInstance, "CSV9C", "155")
	return run_checks([
		assert_true(has_noctowl, "Fan Call should still take Noctowl after the second Hoothoot is already established"),
		assert_false(has_hoothoot, "Fan Call should stop taking extra Hoothoot once two are already in play"),
	])


func test_late_bibarel_draw_is_suppressed_under_deckout_pressure() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 19
	var player: PlayerState = gs.players[0]
	var bibarel := _make_slot(_make_pokemon_cd("Bibarel Test", "Bibarel", "Stage 1", "C", 120, "CS5aC", "105"), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	player.bench.append(bibarel)
	player.deck.clear()
	for i: int in 3:
		player.deck.append(CardInstance.create(_make_trainer_cd("Filler%d" % i, "Filler%d" % i, "Item", "CSV1C", "112"), 0))
	var ability_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": bibarel}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		ability_score < end_score,
		"Late Bibarel draw should be below end_turn when the deck is nearly empty (Bibarel=%f End=%f)" % [ability_score, end_score]
	)


func test_t2_noctowl_searches_energy_access_plus_area_zero_for_big_terapagos_turn() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 4
	var player: PlayerState = gs.players[0]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	player.bench.append(_make_slot(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Noctowl Test", "", "Stage 1", "C", 100, "CSV9C", "155"), 0))
	var area_zero := CardInstance.create(_make_trainer_cd("Area Zero", "", "Stadium", "CSV9C", "207"), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Earthen Vessel", "Item", "CSV6C", "115"), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Nest Ball", "Item", "CSVH1C", "043"), 0)
	var ultra := CardInstance.create(_make_trainer_cd("Ultra Ball", "Ultra Ball", "Item", "CSV1C", "112"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[ultra, nest, vessel, area_zero],
		{"id": "csv9c_noctowl_trainers", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var has_area := false
	var has_vessel := false
	for item: Variant in picked:
		if item is CardInstance:
			has_area = has_area or _card_matches(item as CardInstance, "CSV9C", "207")
			has_vessel = has_vessel or _card_matches(item as CardInstance, "CSV6C", "115")
	return run_checks([
		assert_eq(picked.size(), 2, "T2 Noctowl should take two trainer cards"),
		assert_true(has_area, "T2 Noctowl should establish Area Zero before the Terapagos 200+ turn"),
		assert_true(has_vessel, "T2 Noctowl should include Earthen Vessel as the Energy access card"),
	])


func test_t2_conversion_plays_earthen_vessel_before_ultra_ball_when_terapagos_needs_second_energy() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 3
	gs.energy_attached_this_turn = false
	var player: PlayerState = gs.players[0]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	player.bench.append(_make_slot(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Bidoof Test", "Bidoof", "Basic", "C", 60, "CS5bC", "111"), 0))
	player.deck.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Noctowl Test", "", "Stage 1", "C", 100, "CSV9C", "155"), 0))
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Earthen Vessel", "Item", "CSV6C", "115"), 0)
	var ultra := CardInstance.create(_make_trainer_cd("Ultra Ball", "Ultra Ball", "Item", "CSV1C", "112"), 0)
	var vessel_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": vessel}, gs, 0)
	var ultra_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": ultra}, gs, 0)
	return assert_true(
		vessel_score > ultra_score + 300.0,
		"T2 conversion should play Earthen Vessel before Ultra Ball when active Terapagos still needs the second Energy (Vessel=%f Ultra=%f)" % [vessel_score, ultra_score]
	)


func test_t2_conversion_discard_policy_protects_earthen_vessel_before_second_terapagos_attach() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 3
	gs.energy_attached_this_turn = false
	var player: PlayerState = gs.players[0]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	player.deck.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Earthen Vessel", "Item", "CSV6C", "115"), 0)
	var glass := CardInstance.create(_make_trainer_cd("Glass Trumpet", "Glass Trumpet", "Item", "CSV9C", "178"), 0)
	var step := {"id": "discard_cards", "max_select": 1}
	var context := {"game_state": gs, "player_index": 0}
	var vessel_score: float = strategy.score_interaction_target(vessel, step, context)
	var glass_score: float = strategy.score_interaction_target(glass, step, context)
	return assert_true(
		glass_score > vessel_score + 50.0,
		"Discard policy should protect Earthen Vessel until Terapagos can take its second Energy (Glass=%f Vessel=%f)" % [glass_score, vessel_score]
	)


func test_trace_regression_never_routes_energy_or_evolution_to_knocked_out_slots() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var terapagos := _make_slot(_make_pokemon_cd("澶箰宸存垐鏂痚x", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	var knocked_hoothoot := _make_slot(_make_pokemon_cd("鍜曞挄", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	knocked_hoothoot.damage_counters = 70
	player.active_pokemon = terapagos
	player.bench.append(knocked_hoothoot)
	var water := CardInstance.create(_make_energy_cd("Water Energy", "W"), 0)
	var noctowl := CardInstance.create(_make_pokemon_cd("鐚ご澶滈拱", "", "Stage 1", "C", 100, "CSV9C", "155"), 0)
	var live_attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": terapagos}, gs, 0)
	var knocked_attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": knocked_hoothoot}, gs, 0)
	var knocked_evolve_score: float = strategy.score_action_absolute({"kind": "evolve", "card": noctowl, "target_slot": knocked_hoothoot}, gs, 0)
	var knocked_handoff_score: float = strategy.score_handoff_target(knocked_hoothoot, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(
			live_attach_score > knocked_attach_score + 1000.0,
			"Water attach should never route to a knocked-out support slot (live=%f knocked=%f)" % [live_attach_score, knocked_attach_score]
		),
		assert_true(knocked_evolve_score < -90000.0, "Knocked-out slots should not be evolution targets"),
		assert_true(knocked_handoff_score < -90000.0, "Knocked-out slots should not be handoff/send-out targets"),
	])


func test_conversion_attach_prefers_live_attacker_over_live_support_after_shell_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 17
	var player: PlayerState = gs.players[0]
	var terapagos := _make_slot(_make_pokemon_cd("澶箰宸存垐鏂痚x", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
		{"name": "Crown Opal", "cost": "GWL", "damage": "180"},
	]), 0)
	var noctowl := _make_slot(_make_pokemon_cd("鐚ご澶滈拱", "", "Stage 1", "C", 100, "CSV9C", "155"), 0)
	var fez := _make_slot(_make_pokemon_cd("鍚夐泬楦x", "Fezandipiti ex", "Basic", "D", 210, "CSV8C", "135", "ex"), 0)
	player.active_pokemon = fez
	player.bench.append(terapagos)
	player.bench.append(noctowl)
	var water_a := CardInstance.create(_make_energy_cd("Water Energy", "W"), 0)
	var water_b := CardInstance.create(_make_energy_cd("Water Energy", "W"), 0)
	var terapagos_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water_a, "target_slot": terapagos}, gs, 0)
	var noctowl_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water_b, "target_slot": noctowl}, gs, 0)
	return assert_true(
		terapagos_score > noctowl_score + 600.0,
		"Conversion attach should keep powering live Terapagos before Noctowl support padding (Terapagos=%f Noctowl=%f)" % [terapagos_score, noctowl_score]
	)


func test_glass_trumpet_assignment_builds_backup_terapagos_before_overfeeding_ready_one() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var ready_terapagos := _make_slot(_make_pokemon_cd("澶箰宸存垐鏂痚x", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
		{"name": "Crown Opal", "cost": "GWL", "damage": "180"},
	]), 0)
	var backup_terapagos := _make_slot(_make_pokemon_cd("澶箰宸存垐鏂痚x", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
		{"name": "Crown Opal", "cost": "GWL", "damage": "180"},
	]), 0)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Bidoof", "Bidoof", "Basic", "C", 60, "CS5bC", "111"), 0)
	player.bench.append(ready_terapagos)
	player.bench.append(backup_terapagos)
	ready_terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	ready_terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	backup_terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var step := {"id": "csv9c178_energy_assignments"}
	var context := {"game_state": gs, "player_index": 0}
	var ready_score: float = strategy.score_interaction_target(ready_terapagos, step, context)
	var backup_score: float = strategy.score_interaction_target(backup_terapagos, step, context)
	return assert_true(
		backup_score > ready_score + 80.0,
		"Glass Trumpet should build a backup one-energy Terapagos before overfeeding a ready one (Backup=%f Ready=%f)" % [backup_score, ready_score]
	)


func test_conversion_glass_trumpet_outranks_ultra_ball_when_discard_energy_is_ready() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 8
	var player: PlayerState = gs.players[0]
	var palkia := _make_slot(_make_pokemon_cd("Palkia VSTAR Test", "Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "CS5bC", "051", "V", [
		{"name": "Subspace Swell", "cost": "WW", "damage": "60+"},
	]), 0)
	var backup_terapagos_a := _make_slot(_make_pokemon_cd("Terapagos Backup A", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	var backup_terapagos_b := _make_slot(_make_pokemon_cd("Terapagos Backup B", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	var fan_rotom := _make_slot(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0)
	var noctowl := _make_slot(_make_pokemon_cd("Noctowl Test", "", "Stage 1", "C", 100, "CSV9C", "155"), 0)
	player.active_pokemon = palkia
	player.bench.append(backup_terapagos_a)
	player.bench.append(backup_terapagos_b)
	player.bench.append(fan_rotom)
	player.bench.append(noctowl)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var glass := CardInstance.create(_make_trainer_cd("Glass Trumpet", "Glass Trumpet", "Item", "CSV9C", "178"), 0)
	var ultra := CardInstance.create(_make_trainer_cd("Ultra Ball", "Ultra Ball", "Item", "CSV1C", "112"), 0)
	var glass_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": glass}, gs, 0)
	var ultra_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": ultra}, gs, 0)
	return assert_true(
		glass_score > ultra_score + 100.0,
		"Conversion should accelerate discard Energy with Glass Trumpet before generic Ultra Ball churn (Glass=%f Ultra=%f)" % [glass_score, ultra_score]
	)


func test_glass_trumpet_source_selection_matches_real_terapagos_targets() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var palkia := _make_slot(_make_pokemon_cd("Palkia VSTAR Test", "Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "CS5bC", "051", "V"), 0)
	var backup_a := _make_slot(_make_pokemon_cd("Terapagos Backup A", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	var backup_b := _make_slot(_make_pokemon_cd("Terapagos Backup B", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	var fan_rotom := _make_slot(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161"), 0)
	player.active_pokemon = palkia
	player.bench.append(backup_a)
	player.bench.append(fan_rotom)
	var water_a := CardInstance.create(_make_energy_cd("Water Energy A", "W"), 0)
	var water_b := CardInstance.create(_make_energy_cd("Water Energy B", "W"), 0)
	var step := {"id": "csv9c178_energy_assignments", "max_select": 2}
	var one_target_pick: Array = strategy.pick_interaction_items(
		[water_a, water_b],
		step,
		{"game_state": gs, "player_index": 0, "target_items": [backup_a, fan_rotom]}
	)
	var two_target_pick: Array = strategy.pick_interaction_items(
		[water_a, water_b],
		step,
		{"game_state": gs, "player_index": 0, "target_items": [backup_a, backup_b, fan_rotom]}
	)
	return run_checks([
		assert_eq(one_target_pick.size(), 1, "Glass Trumpet should preserve the second discard Energy when only one Terapagos target is worth building"),
		assert_eq(two_target_pick.size(), 2, "Glass Trumpet should use both discard Energy when two Terapagos targets can be advanced"),
	])


func test_handoff_prefers_nearly_ready_terapagos_over_low_pressure_palkia_v() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	var palkia_v := _make_slot(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V", [
		{"name": "Stadium Search", "cost": "W", "damage": ""},
		{"name": "Hydro Break", "cost": "WWC", "damage": "200"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	palkia_v.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.bench.append(terapagos)
	player.bench.append(palkia_v)
	var terapagos_score: float = strategy.score_handoff_target(terapagos, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	var palkia_score: float = strategy.score_handoff_target(palkia_v, {"id": "send_out"}, {"game_state": gs, "player_index": 0})
	return assert_true(
		terapagos_score > palkia_score + 120.0,
		"One-energy Terapagos should be the next attacker plan over one-energy Palkia V's low-pressure stadium search (Terapagos=%f PalkiaV=%f)" % [terapagos_score, palkia_score]
	)


func test_manual_attach_preserves_water_when_only_support_targets_exist() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var fan_rotom := _make_slot(_make_pokemon_cd("Fan Rotom Test", "", "Basic", "C", 70, "CSV9C", "161", "", [
		{"name": "Assault Landing", "cost": "C", "damage": "70"},
	]), 0)
	var hoothoot := _make_slot(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	player.active_pokemon = fan_rotom
	player.bench.append(hoothoot)
	var water := CardInstance.create(_make_energy_cd("Water Energy", "W"), 0)
	var support_attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": water, "target_slot": fan_rotom}, gs, 0)
	return assert_true(
		support_attach_score < 0.0,
		"Water should be preserved instead of enabling low-pressure support attacks when no core attacker is in play (score=%f)" % support_attach_score
	)


func test_irida_searches_real_water_route_and_area_zero_item() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V"), 0))
	var palkia_vstar := CardInstance.create(_make_pokemon_cd("Palkia VSTAR Test", "Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "CS5bC", "051", "V", [
		{"name": "Subspace Swell", "cost": "WW", "damage": "60+"},
	]), 0)
	var palkia_v := CardInstance.create(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V"), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Nest Ball", "Item", "CSVH1C", "043"), 0)
	var earthen := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Earthen Vessel", "Item", "CSV6C", "115"), 0)
	player.deck.append(palkia_vstar)
	player.deck.append(palkia_v)
	player.deck.append(nest)
	player.deck.append(earthen)
	var water_step := {"id": "water_pokemon"}
	var item_step := {"id": "item_card"}
	var context := {"game_state": gs, "player_index": 0}
	var vstar_score: float = strategy.score_interaction_target(palkia_vstar, water_step, context)
	var palkia_v_score: float = strategy.score_interaction_target(palkia_v, water_step, context)
	var nest_score: float = strategy.score_interaction_target(nest, item_step, context)
	var earthen_score: float = strategy.score_interaction_target(earthen, item_step, context)
	return run_checks([
		assert_true(vstar_score > palkia_v_score + 100.0, "Irida should evolve the existing Palkia line before taking another Palkia V"),
		assert_true(nest_score > earthen_score + 100.0, "Irida should find setup Pokemon access before generic Energy access while the bench shell is thin"),
	])


func test_ultra_ball_searches_palkia_vstar_before_extra_terapagos_when_palkia_is_in_play() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V", [
		{"name": "Stadium Search", "cost": "W", "damage": ""},
		{"name": "Hydro Break", "cost": "WWC", "damage": "200"},
	]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0))
	var palkia_vstar := CardInstance.create(_make_pokemon_cd("Palkia VSTAR Test", "Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "CS5bC", "051", "V", [
		{"name": "Subspace Swell", "cost": "WW", "damage": "60+"},
	]), 0)
	var extra_terapagos := CardInstance.create(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	var context := {"game_state": gs, "player_index": 0}
	var vstar_score: float = strategy.score_interaction_target(palkia_vstar, {"id": "search_pokemon"}, context)
	var terapagos_score: float = strategy.score_interaction_target(extra_terapagos, {"id": "search_pokemon"}, context)
	return assert_true(
		vstar_score > terapagos_score + 150.0,
		"Ultra Ball Pokemon search should complete Palkia VSTAR before taking another Terapagos (VSTAR=%f Terapagos=%f)" % [vstar_score, terapagos_score]
	)


func test_gust_targets_bench_knockout_when_terapagos_misses_active() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	for i: int in 7:
		player.bench.append(_make_slot(_make_pokemon_cd("Bench%d" % i, "", "Basic", "C", 70, "CSV9C", "154"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Iron Hands ex", "Basic", "L", 230, "CSV4C", "066", "ex"), 1)
	var mew_ex := _make_slot(_make_pokemon_cd("Mew ex", "Mew ex", "Basic", "P", 210, "CSV4C", "051", "ex"), 1)
	var magneton := _make_slot(_make_pokemon_cd("Magneton", "Magneton", "Stage 1", "L", 100, "CSV9C", "054"), 1)
	opponent.bench.append(mew_ex)
	opponent.bench.append(magneton)
	var boss := CardInstance.create(_make_trainer_cd("Boss Orders", "Boss's Orders", "Supporter", "CSVH1aC", "023"), 0)
	var boss_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)
	var mew_score: float = strategy.score_interaction_target(mew_ex, {"id": "opponent_bench_target"}, {"game_state": gs, "player_index": 0})
	var magneton_score: float = strategy.score_interaction_target(magneton, {"id": "opponent_bench_target"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(boss_score > 900.0, "Boss should be premium when Terapagos can gust a bench rule-box KO but misses active (score=%f)" % boss_score),
		assert_true(mew_score > magneton_score + 120.0, "Gust target should prefer a two-prize bench KO over a one-prize cleanup target"),
	])


func test_terapagos_180_non_ko_waits_for_more_bench_development() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	for i: int in 6:
		player.bench.append(_make_slot(_make_pokemon_cd("Bench%d" % i, "", "Basic", "C", 70, "CSV9C", "154"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Iron Hands ex", "Basic", "L", 230, "CSV4C", "066", "ex"), 1)
	var hoothoot := CardInstance.create(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": terapagos}, gs, 0)
	var bench_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": hoothoot}, gs, 0)
	return assert_true(
		bench_score > attack_score + 40.0,
		"Terapagos should fill toward 7+ bench before taking a 180 non-KO swing (Bench=%f Attack=%f)" % [bench_score, attack_score]
	)


func test_ready_terapagos_benches_palkia_bridge_before_early_prize_trade() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 3
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	for i: int in 6:
		player.bench.append(_make_slot(_make_pokemon_cd("Bench%d" % i, "", "Basic", "C", 70, "CSV9C", "154"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Charizard ex", "Stage 2", "R", 180, "CSV2aC", "066", "ex"), 1)
	var palkia_v := CardInstance.create(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V", [
		{"name": "Stadium Search", "cost": "W", "damage": ""},
		{"name": "Hydro Break", "cost": "WWC", "damage": "200"},
	]), 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": terapagos}, gs, 0)
	var palkia_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": palkia_v}, gs, 0)
	return assert_true(
		palkia_score > attack_score + 40.0,
		"Early ready Terapagos should establish Palkia V bridge before taking a prize trade (Palkia=%f Attack=%f)" % [palkia_score, attack_score]
	)


func test_midgame_ready_terapagos_benches_palkia_when_no_backup_attacker() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 15
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	player.bench.clear()
	for i: int in 7:
		player.bench.append(_make_slot(_make_pokemon_cd("Support%d" % i, "", "Basic", "C", 70, "CSV9C", "154"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Charizard ex", "Stage 2", "R", 330, "CSV2aC", "066", "ex"), 1)
	var palkia_v := CardInstance.create(_make_pokemon_cd("Palkia V Test", "Origin Forme Palkia V", "Basic", "W", 220, "CSNC", "003", "V", [
		{"name": "Stadium Search", "cost": "W", "damage": ""},
		{"name": "Hydro Break", "cost": "WWC", "damage": "200"},
	]), 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": terapagos}, gs, 0)
	var palkia_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": palkia_v}, gs, 0)
	return assert_true(
		palkia_score > attack_score + 120.0,
		"Midgame Terapagos should create a Palkia backup before a non-final attack when no backup attacker exists (Palkia=%f Attack=%f)" % [palkia_score, attack_score]
	)


func test_kieran_boost_turns_210_terapagos_swing_into_rule_box_knockout() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	for i: int in 7:
		player.bench.append(_make_slot(_make_pokemon_cd("Bench%d" % i, "", "Basic", "C", 70, "CSV9C", "154"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Iron Hands ex", "Basic", "L", 230, "CSV4C", "066", "ex"), 1)
	var kieran := CardInstance.create(_make_trainer_cd("Kieran", "Kieran", "Supporter", "CSV8C", "198"), 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": terapagos}, gs, 0)
	var kieran_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": kieran}, gs, 0)
	var boost_score: float = strategy.score_interaction_target("boost_vs_active_rule_box", {"id": "kieran_mode"}, {"game_state": gs, "player_index": 0})
	var switch_score: float = strategy.score_interaction_target("switch_active", {"id": "kieran_mode"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(kieran_score > attack_score + 80.0, "Kieran should be played before a 210 non-KO when +30 takes Iron Hands ex (Kieran=%f Attack=%f)" % [kieran_score, attack_score]),
		assert_true(boost_score > switch_score + 200.0, "Kieran mode should choose damage boost over switch when boost creates the KO (Boost=%f Switch=%f)" % [boost_score, switch_score]),
	])


func test_lost_vacuum_does_not_break_own_area_zero_damage_shell() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 7
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	for i: int in 7:
		player.bench.append(_make_slot(_make_pokemon_cd("Bench%d" % i, "", "Basic", "C", 70, "CSV9C", "154"), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Iron Hands ex", "Basic", "L", 230, "CSV4C", "066", "ex"), 1)
	gs.stadium_card = CardInstance.create(_make_trainer_cd("Area Zero Underdepths", "Area Zero Underdepths", "Stadium", "CSV9C", "207"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum", "Lost Vacuum", "Item", "CS6bC", "123"), 0)
	var attack_score: float = strategy.score_action_absolute({"kind": "attack", "source_slot": terapagos}, gs, 0)
	var vacuum_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": vacuum}, gs, 0)
	return run_checks([
		assert_true(vacuum_score < 0.0, "Lost Vacuum should be suppressed while own Area Zero is enabling the 7-bench damage shell (Vacuum=%f)" % vacuum_score),
		assert_true(attack_score > vacuum_score + 600.0, "Ready Terapagos attack should dominate self-breaking Lost Vacuum (Attack=%f Vacuum=%f)" % [attack_score, vacuum_score]),
	])


func test_lost_vacuum_refuses_own_area_zero_even_before_bench_overflow() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 5
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Palkia VSTAR Test", "Origin Forme Palkia VSTAR", "VSTAR", "W", 280, "CS5bC", "051", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Noctowl Test", "", "Stage 1", "C", 100, "CSV9C", "155"), 0))
	gs.stadium_card = CardInstance.create(_make_trainer_cd("Area Zero Underdepths", "Area Zero Underdepths", "Stadium", "CSV9C", "207"), 0)
	var vacuum := CardInstance.create(_make_trainer_cd("Lost Vacuum", "Lost Vacuum", "Item", "CS6bC", "123"), 0)
	var vacuum_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": vacuum,
		"targets": [{"lost_vacuum_target": [gs.stadium_card]}],
	}, gs, 0)
	return assert_true(
		vacuum_score < -100.0,
		"Lost Vacuum should not be playable over end_turn when it only removes our own Area Zero (Vacuum=%f)" % vacuum_score
	)


func test_retreat_does_not_pivot_into_support_when_attacker_is_available() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	gs.turn_number = 13
	var player: PlayerState = gs.players[0]
	var active_support := _make_slot(_make_pokemon_cd("Hoothoot Test", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	active_support.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var ready_terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	ready_terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	ready_terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	var bench_hoothoot := _make_slot(_make_pokemon_cd("Bench Hoothoot", "", "Basic", "C", 70, "CSV9C", "154"), 0)
	player.active_pokemon = active_support
	player.bench.append(ready_terapagos)
	player.bench.append(bench_hoothoot)
	var water := active_support.attached_energy[0]
	var attacker_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": ready_terapagos, "energy_to_discard": [water]}, gs, 0)
	var support_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": bench_hoothoot, "energy_to_discard": [water]}, gs, 0)
	return assert_true(
		attacker_score > support_score + 900.0,
		"Retreat should pivot to a ready attacker instead of another support slot (Attacker=%f Support=%f)" % [attacker_score, support_score]
	)


func test_gust_card_without_live_conversion_target_stays_below_end_turn() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17WaterTurtle.gd should load"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var terapagos := _make_slot(_make_pokemon_cd("Terapagos Test", "", "Basic", "C", 230, "CSV9C", "175", "ex", [
		{"name": "Unified Beat", "cost": "CC", "damage": "30x"},
	]), 0)
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	terapagos.attached_energy.append(CardInstance.create(_make_energy_cd("Water Energy", "W"), 0))
	player.active_pokemon = terapagos
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Charizard ex", "Stage 2", "R", 330, "CSV2aC", "066", "ex"), 1)
	opponent.bench.clear()
	var boss := CardInstance.create(_make_trainer_cd("Boss Orders", "Boss's Orders", "Supporter", "CSVH1aC", "023"), 0)
	var boss_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		boss_score < end_score,
		"Boss should not be spent when there is no live bench conversion target (Boss=%f End=%f)" % [boss_score, end_score]
	)


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(STRATEGY_PATH)
	return script.new() if script is GDScript else null


func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 2
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Active%d" % pi, "Basic", "C", 100), pi)
		gs.players.append(player)
	return gs


func _make_pokemon_cd(
	pname: String,
	name_en: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	set_code: String = "",
	card_index: String = "",
	mechanic: String = "",
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = name_en
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.set_code = set_code
	cd.card_index = card_index
	cd.mechanic = mechanic
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _make_trainer_cd(
	pname: String,
	name_en: String = "",
	card_type: String = "Item",
	set_code: String = "",
	card_index: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = name_en
	cd.card_type = card_type
	cd.set_code = set_code
	cd.card_index = card_index
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _card_matches(card: CardInstance, set_code: String, card_index: String) -> bool:
	return card != null and card.card_data != null and str(card.card_data.set_code) == set_code and str(card.card_data.card_index) == card_index
