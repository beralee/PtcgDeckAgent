class_name TestV18TeraNoctowlStrategy
extends TestBase


const DELEGATE_SCRIPT = preload("res://scripts/ai/DeckStrategyV18TeraNoctowl.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const TORD_DECK_ID := 800015934
const FLAREON_DECK_ID := 800017643


func test_delegate_exposes_the_v18_contract_for_both_profiles() -> String:
	var checks: Array[String] = []
	for deck_id: int in [TORD_DECK_ID, FLAREON_DECK_ID]:
		var strategy := _strategy(deck_id)
		checks.append(assert_not_null(strategy, "Delegate should instantiate for deck %d" % deck_id))
		if strategy == null:
			continue
		for method_name: String in [
			"build_turn_plan",
			"build_continuity_contract",
			"score_action_absolute",
			"pick_interaction_items",
			"score_interaction_target",
			"score_handoff_target",
		]:
			checks.append(assert_true(strategy.has_method(method_name), "Deck %d delegate should expose %s" % [deck_id, method_name]))
		checks.append(assert_eq(str(strategy.call("get_strategy_id")), "v18_tera_noctowl_core", "Both profiles should share one reusable delegate id"))
		var plan: Dictionary = strategy.call("build_turn_plan", _make_state(), 0, {})
		checks.append(assert_eq(str(plan.get("id", "")), "v18_tera_noctowl_route", "Delegate should emit its stable plan id"))
		checks.append(assert_true(plan.get("flags", {}) is Dictionary, "Delegate plan should expose route flags"))
	return run_checks(checks)


func test_empty_board_fallback_owner_uses_real_profile_card_ids() -> String:
	var tord := _strategy(TORD_DECK_ID)
	var flareon := _strategy(FLAREON_DECK_ID)
	var state := _make_state()
	var tord_plan: Dictionary = tord.call("build_turn_plan", state, 0, {})
	var flareon_plan: Dictionary = flareon.call("build_turn_plan", state, 0, {})
	var tord_owner: Dictionary = tord_plan.get("owner", {})
	var flareon_owner: Dictionary = flareon_plan.get("owner", {})
	return run_checks([
		assert_eq(str(tord_owner.get("turn_owner_name", "")), "CSV9C_175", "Tord fallback owner should use the real Terapagos card id"),
		assert_eq(str(flareon_owner.get("turn_owner_name", "")), "CSV9.5C_023", "Flareon fallback owner should use the real Flareon card id"),
	])


func test_flareon_opening_prefers_fast_evolution_eevee() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var player := PlayerState.new()
	var fast_eevee := CardDatabase.get_card("CSV9C", "153")
	var fan_rotom := CardDatabase.get_card("CSV9C", "161")
	var hoothoot := CardDatabase.get_card("CSV9C", "154")
	var flareon := CardDatabase.get_card("CSV9.5C", "023")
	if strategy == null or fast_eevee == null or fan_rotom == null or hoothoot == null or flareon == null:
		return assert_true(false, "Flareon opening cards and delegate should load")
	player.hand = [
		CardInstance.create(fan_rotom, 0),
		CardInstance.create(hoothoot, 0),
		CardInstance.create(fast_eevee, 0),
		CardInstance.create(flareon, 0),
	]
	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	return assert_eq(int(plan.get("active_hand_index", -1)), 2, "Fast Evolution Eevee should own the Active route")


func test_noctowl_evolves_only_after_a_tera_pokemon_is_in_play() -> String:
	var strategy := _strategy(TORD_DECK_ID)
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	var noctowl_data := CardDatabase.get_card("CSV9C", "155")
	var rotom_data := CardDatabase.get_card("CSV9C", "161")
	if strategy == null or terapagos_data == null or hoothoot_data == null or noctowl_data == null or rotom_data == null:
		return assert_true(false, "Tera and Noctowl route cards should load")
	var state := _make_state()
	var terapagos := _slot(terapagos_data)
	terapagos.attached_energy = [_energy("G"), _energy("W")]
	var hoothoot := _slot(hoothoot_data)
	hoothoot.turn_played = 1
	var noctowl := CardInstance.create(noctowl_data, 0)
	state.players[0].active_pokemon = terapagos
	state.players[0].bench = [hoothoot]
	state.players[0].hand = [noctowl]
	var evolve_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve",
		"card": noctowl,
		"target_slot": hoothoot,
	}, state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": terapagos,
		"attack_index": 0,
		"projected_damage": 30,
		"projected_knockout": false,
	}, state, 0)
	state.players[0].active_pokemon = _slot(rotom_data)
	var dead_evolution_score: float = strategy.call("score_action_absolute", {
		"kind": "evolve",
		"card": noctowl,
		"target_slot": hoothoot,
	}, state, 0)
	return run_checks([
		assert_true(evolve_score >= attack_score + 2000.0, "Jewel Seeker evolution should precede a non-KO attack when Tera is live"),
		assert_true(dead_evolution_score <= -2000.0, "Noctowl should not evolve before a Tera Pokemon enables Jewel Seeker"),
	])


func test_tord_mode_preserves_terapagos_sparkling_crystal_prediction() -> String:
	var strategy := _strategy(TORD_DECK_ID)
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if strategy == null or terapagos_data == null or crystal_data == null:
		return assert_true(false, "Terapagos and Sparkling Crystal should load")
	var terapagos := _slot(terapagos_data)
	terapagos.attached_energy = [_energy("G")]
	terapagos.attached_tool = CardInstance.create(crystal_data, 0)
	var prediction: Dictionary = strategy.call("predict_attacker_damage", terapagos)
	return run_checks([
		assert_true(bool(prediction.get("can_attack", false)), "Tord mode should retain the mature Terapagos Crystal discount"),
		assert_true(int(prediction.get("damage", 0)) >= 30, "Discounted Alliance Strike should retain non-zero projected damage"),
	])


func test_jewel_search_orders_area_zero_then_each_decks_attack_bridge() -> String:
	var tord := _strategy(TORD_DECK_ID)
	var flareon := _strategy(FLAREON_DECK_ID)
	var nest_ball := _card("CSVH1C", "043")
	var area_zero := _card("CSV9C", "207")
	var crispin := _card("CSV9C", "196")
	var switch_card := _card("CSV1C", "113")
	var kieran := _card("CSV8C", "198")
	if tord == null or flareon == null or nest_ball == null or area_zero == null or crispin == null or switch_card == null or kieran == null:
		return assert_true(false, "Noctowl Trainer search candidates should load")
	var step := {"id": "csv9c_noctowl_trainers", "max_select": 2}
	var tord_picks: Array = tord.call("pick_interaction_items", [crispin, nest_ball, area_zero], step, {})
	var flareon_picks: Array = flareon.call("pick_interaction_items", [switch_card, kieran, crispin, area_zero], step, {})
	return run_checks([
		assert_true(area_zero in tord_picks and nest_ball in tord_picks, "Tord should fetch Area Zero plus Bench access"),
		assert_true(area_zero in flareon_picks and crispin in flareon_picks, "Flareon should fetch Area Zero plus typed Energy access"),
	])


func test_jewel_search_demotes_redundant_area_zero_and_empty_ball_routes() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var area_zero := _card("CSV9C", "207")
	var nest_ball := _card("CSVH1C", "043")
	if strategy == null or flareon_data == null or area_zero == null or nest_ball == null:
		return assert_true(false, "Flareon and search cards should load")
	var state := _make_state()
	state.players[0].active_pokemon = _slot(flareon_data)
	state.stadium_card = area_zero
	for index: int in 8:
		state.players[0].bench.append(_slot(_basic("Bench filler %d" % index)))
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "csv9c_noctowl_trainers", "max_select": 2}
	var area_score: float = strategy.call("score_interaction_target", area_zero, step, context)
	var nest_score: float = strategy.call("score_interaction_target", nest_ball, step, context)
	return run_checks([
		assert_true(area_score < 0.0, "Jewel Seeker should not fetch a second active Area Zero"),
		assert_true(nest_score < 0.0, "Jewel Seeker should not fetch Nest Ball with no space or Basic target"),
	])


func test_ball_and_tera_orb_actions_are_blocked_without_targets() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var nest_ball := _card("CSVH1C", "043")
	var tera_orb := _card("CSV9C", "181")
	if strategy == null or flareon_data == null or nest_ball == null or tera_orb == null:
		return assert_true(false, "Empty-search regression cards should load")
	var state := _make_state()
	state.players[0].active_pokemon = _slot(flareon_data)
	for index: int in 5:
		state.players[0].bench.append(_slot(_basic("Full Bench %d" % index)))
	state.players[0].deck = [_card_from_data(_trainer("Deck filler"))]
	var nest_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": nest_ball,
		"productive": true,
	}, state, 0)
	var orb_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": tera_orb,
		"productive": true,
	}, state, 0)
	return run_checks([
		assert_true(nest_score <= -2500.0, "Nest Ball should be blocked with a full Bench and no Basic in deck"),
		assert_true(orb_score <= -2500.0, "Tera Orb should be blocked when the deck has no Tera Pokemon"),
	])


func test_area_zero_space_management_preserves_funded_attackers() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var rotom_data := CardDatabase.get_card("CSV9C", "161")
	var area_zero := _card("CSV9C", "207")
	var jamming_tower := _card("CSV8C", "203")
	if strategy == null or flareon_data == null or rotom_data == null or area_zero == null or jamming_tower == null:
		return assert_true(false, "Area Zero space-management cards should load")
	var state := _make_state()
	state.players[0].active_pokemon = _slot(flareon_data)
	state.stadium_card = area_zero
	var spent_rotom := _slot(rotom_data)
	var funded_flareon := _slot(flareon_data)
	funded_flareon.attached_energy = [_energy("R"), _energy("W"), _energy("L")]
	state.players[0].bench = [spent_rotom, funded_flareon]
	for index: int in 4:
		state.players[0].bench.append(_slot(_basic("Space filler %d" % index)))
	var replace_score: float = strategy.call("score_action_absolute", {
		"kind": "play_stadium",
		"card": jamming_tower,
		"productive": true,
	}, state, 0)
	var step := {"id": "csv9c207_zero_area_discard_p0"}
	var rotom_discard_score: float = strategy.call("score_interaction_target", spent_rotom, step, {})
	var attacker_discard_score: float = strategy.call("score_interaction_target", funded_flareon, step, {})
	return run_checks([
		assert_true(replace_score <= -5000.0, "Replacing Area Zero should be blocked while six Bench Pokemon depend on it"),
		assert_true(rotom_discard_score >= attacker_discard_score + 4000.0, "Bench cleanup should discard spent Fan Rotom before a funded Tera attacker"),
	])


func test_burning_charge_selects_water_and_lightning_for_flareons_280_route() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var noctowl_data := CardDatabase.get_card("CSV9C", "155")
	if strategy == null or flareon_data == null or noctowl_data == null:
		return assert_true(false, "Flareon energy-route cards should load")
	var state := _make_state()
	var flareon := _slot(flareon_data)
	flareon.attached_energy = [_energy("R")]
	var noctowl := _slot(noctowl_data)
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [noctowl]
	var psychic := _energy("P")
	var water := _energy("W")
	var lightning := _energy("L")
	var context := {
		"game_state": state,
		"player_index": 0,
		"target_items": [flareon, noctowl],
	}
	var picked: Array = strategy.call("pick_interaction_items", [psychic, water, lightning], {
		"id": "energy_assignments",
		"max_select": 2,
	}, context)
	var target_context := context.merged({"source_card": water})
	var flareon_score: float = strategy.call("score_interaction_target", flareon, {"id": "energy_assignments"}, target_context)
	var noctowl_score: float = strategy.call("score_interaction_target", noctowl, {"id": "energy_assignments"}, target_context)
	return run_checks([
		assert_true(water in picked and lightning in picked, "Burning Charge should select the missing Water and Lightning types"),
		assert_false(psychic in picked, "Burning Charge should not spend a slot on Psychic after the 130-damage cost is paid"),
		assert_true(flareon_score >= noctowl_score + 3000.0, "Both searched Energy should stay on Flareon because the effect is single-target"),
	])


func test_flareon_manual_attachment_and_crystal_prediction_follow_typed_costs() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var eevee_data := CardDatabase.get_card("CSV9C", "153")
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var crystal_data := CardDatabase.get_card("CSV8C", "186")
	if strategy == null or eevee_data == null or hoothoot_data == null or flareon_data == null or crystal_data == null:
		return assert_true(false, "Flareon attachment-route cards should load")
	var state := _make_state()
	var eevee := _slot(eevee_data)
	var hoothoot := _slot(hoothoot_data)
	state.players[0].active_pokemon = eevee
	state.players[0].bench = [hoothoot]
	state.players[0].hand = [CardInstance.create(flareon_data, 0)]
	var fire := _energy("R")
	var eevee_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fire, "target_slot": eevee,
	}, state, 0)
	var hoothoot_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fire, "target_slot": hoothoot,
	}, state, 0)
	var flareon := _slot(flareon_data)
	flareon.attached_energy = [_energy("R")]
	flareon.attached_tool = CardInstance.create(crystal_data, 0)
	var prediction: Dictionary = strategy.call("predict_attacker_damage", flareon)
	return run_checks([
		assert_true(eevee_score >= hoothoot_score + 3000.0, "Fire Energy should preload the live Flareon evolution route instead of Hoothoot"),
		assert_true(bool(prediction.get("can_attack", false)), "Sparkling Crystal plus Fire should pay Flareon's RC attack"),
		assert_true(int(prediction.get("damage", 0)) >= 130, "Typed prediction should expose Burning Charge damage"),
	])


func test_continuity_contract_keeps_jewel_search_before_attack() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	var noctowl_data := CardDatabase.get_card("CSV9C", "155")
	if strategy == null or flareon_data == null or hoothoot_data == null or noctowl_data == null:
		return assert_true(false, "Continuity route cards should load")
	var state := _make_state()
	var hoothoot := _slot(hoothoot_data)
	hoothoot.turn_played = 1
	state.players[0].active_pokemon = _slot(flareon_data)
	state.players[0].bench = [hoothoot]
	state.players[0].hand = [CardInstance.create(noctowl_data, 0)]
	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var debt: Dictionary = contract.get("setup_debt", {})
	return run_checks([
		assert_true(bool(contract.get("enabled", false)), "Jewel Search debt should enable continuity scoring"),
		assert_true(bool(contract.get("safe_setup_before_attack", false)), "A live Jewel Search should be safe setup debt before attack"),
		assert_true(bool(debt.get("need_noctowl_evolution", false)), "Continuity debt should name the missing Noctowl evolution"),
		assert_eq((contract.get("action_bonuses", []) as Array).size(), 1, "Continuity should expose only the executable Noctowl evolution"),
	])


func test_jewel_search_continuity_requires_a_live_evolution_and_exempts_ko() -> String:
	var strategy := _strategy(FLAREON_DECK_ID)
	var flareon_data := CardDatabase.get_card("CSV9.5C", "023")
	var hoothoot_data := CardDatabase.get_card("CSV9C", "154")
	var noctowl_data := CardDatabase.get_card("CSV9C", "155")
	if strategy == null or flareon_data == null or hoothoot_data == null or noctowl_data == null:
		return assert_true(false, "Continuity regression cards should load")
	var state := _make_state()
	var flareon := _slot(flareon_data)
	flareon.attached_energy = [_energy("R"), _energy("C")]
	var hoothoot := _slot(hoothoot_data)
	hoothoot.turn_played = 1
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [hoothoot]
	state.players[0].prizes = [
		_card_from_data(_trainer("Prize A")),
		_card_from_data(_trainer("Prize B")),
	]
	var blocked_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	state.players[0].hand = [CardInstance.create(noctowl_data, 0)]
	var live_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var non_ko := {
		"kind": "attack",
		"source_slot": flareon,
		"attack_index": 0,
		"projected_damage": 130,
		"projected_knockout": false,
	}
	var knockout := non_ko.duplicate()
	knockout["projected_knockout"] = true
	var direct_non_ko: float = strategy.call("score_action_absolute", non_ko, state, 0)
	var planned_non_ko: float = strategy.call("score_action_absolute_with_plan", non_ko, state, 0, plan)
	var direct_ko: float = strategy.call("score_action_absolute", knockout, state, 0)
	var planned_ko: float = strategy.call("score_action_absolute_with_plan", knockout, state, 0, plan)
	return run_checks([
		assert_false(bool(blocked_contract.get("safe_setup_before_attack", false)), "A Hoothoot without Noctowl in hand is not executable continuity setup"),
		assert_true(bool(live_contract.get("safe_setup_before_attack", false)), "A legal Noctowl evolution should activate continuity setup"),
		assert_true(planned_non_ko <= direct_non_ko - 1750.0, "A non-KO attack should wait for executable Jewel Search"),
		assert_true(absf(planned_ko - direct_ko) < 0.01, "A projected KO must bypass Jewel Search continuity penalty"),
	])


func _strategy(deck_id: int) -> RefCounted:
	var deck := _load_deck(deck_id)
	if deck == null:
		return null
	var strategy: RefCounted = DELEGATE_SCRIPT.new()
	strategy.call("configure_from_deck", deck)
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


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


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _slot(data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 0))
	return slot


func _energy(symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = "%s Energy" % symbol
	data.name_en = data.name
	data.card_type = "Basic Energy"
	data.energy_provides = symbol
	return CardInstance.create(data, 0)


func _basic(name: String) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 60
	data.attacks = [{"name": "Filler", "cost": "C", "damage": "10"}]
	return data


func _trainer(name: String) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return data


func _card_from_data(data: CardData) -> CardInstance:
	return CardInstance.create(data, 0)
