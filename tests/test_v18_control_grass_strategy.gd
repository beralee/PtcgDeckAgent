class_name TestV18ControlGrassStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategyV18ControlGrass.gd"
const CONTROL_DECK_ID := 800018359
const GRASS_DECK_ID := 800018500


func test_delegate_exposes_the_v18_plan_and_interaction_contract_for_both_decks() -> String:
	var control := _strategy(CONTROL_DECK_ID)
	var grass := _strategy(GRASS_DECK_ID)
	var state := _state(12)
	var control_plan: Dictionary = control.call("build_turn_plan", state, 0, {})
	var grass_plan: Dictionary = grass.call("build_turn_plan", state, 0, {})
	return run_checks([
		assert_true(control.has_method("score_action_absolute_with_plan"), "Control delegate should expose plan-aware V18 scoring"),
		assert_true(control.has_method("score_interaction_target"), "Control delegate should expose interaction scoring"),
		assert_true(control.has_method("score_handoff_target"), "Control delegate should expose handoff scoring"),
		assert_true(str(control_plan.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Control plan should use a shared V18 phase"),
		assert_true(str(grass_plan.get("phase", "")) in ["setup", "launch", "convert", "rebuild", "close"], "Grass plan should use a shared V18 phase"),
		assert_true(control_plan.get("owner", {}) is Dictionary and grass_plan.get("owner", {}) is Dictionary, "Both plans should declare route ownership"),
		assert_true(control_plan.get("constraints", {}) is Dictionary and grass_plan.get("constraints", {}) is Dictionary, "Both plans should preserve safety constraints"),
	])


func test_pidgeot_quick_search_prefers_pal_pad_when_control_supporters_need_recycling() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var state := _state(14)
	state.players[0].active_pokemon = _slot(_pokemon("Pidgeot ex", "Stage 2", "C", "CC", "120", "ex"))
	state.players[0].discard_pile.assign([
		_card(_trainer("Team Star Grunt", "Supporter")),
		_card(_trainer("Boss's Orders", "Supporter")),
	])
	state.players[1].active_pokemon.attached_energy.append(_card(_energy("Lightning Energy", "L"), 1))
	var pal_pad := _card(_trainer("Pal Pad", "Item"))
	var research := _card(_trainer("Professor's Research", "Supporter"))
	var context := {"game_state": state, "player_index": 0}
	var pad_score: float = strategy.call("score_interaction_target", pal_pad, {"id": "search_cards"}, context)
	var research_score: float = strategy.call("score_interaction_target", research, {"id": "search_cards"}, context)
	return assert_true(
		pad_score >= research_score + 2000.0,
		"Quick Search should preserve the control loop through Pal Pad before generic draw (pad=%f research=%f)" % [pad_score, research_score]
	)


func test_pidgeot_quick_search_completes_the_garganacl_candy_pair() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var state := _state(14)
	state.players[0].active_pokemon = _slot(_pokemon("Pidgeot ex", "Stage 2", "C", "CC", "120", "ex"))
	state.players[0].bench.append(_slot(_pokemon("Nacli", "Basic", "F", "F", "20")))
	var rare_candy := _card(_trainer("Rare Candy", "Item"))
	var second_rare_candy := _card(_trainer("Rare Candy", "Item"))
	var garganacl := _card(_pokemon("Garganacl", "Stage 2", "F", "FF", "120"))
	var context := {"game_state": state, "player_index": 0}
	state.players[0].hand.append(rare_candy)
	var garganacl_score: float = strategy.call("score_interaction_target", garganacl, {"id": "search_cards"}, context)
	var redundant_candy_score: float = strategy.call("score_interaction_target", second_rare_candy, {"id": "search_cards"}, context)
	var picked: Array = strategy.call("pick_interaction_items", [second_rare_candy, garganacl], {
		"id": "search_cards",
		"max_select": 1,
	}, context)
	return run_checks([
		assert_true(garganacl_score >= redundant_candy_score + 3000.0, "With Rare Candy already in hand, Quick Search should complete the Nacli route with Garganacl"),
		assert_true(picked.size() == 1 and picked[0] == garganacl, "Quick Search should not take a duplicate Rare Candy before Garganacl"),
	])


func test_pidgeot_quick_search_completes_the_candy_garganacl_pair() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var state := _state(14)
	state.players[0].active_pokemon = _slot(_pokemon("Pidgeot ex", "Stage 2", "C", "CC", "120", "ex"))
	state.players[0].bench.append(_slot(_pokemon("Nacli", "Basic", "F", "F", "20")))
	var rare_candy := _card(_trainer("Rare Candy", "Item"))
	var garganacl := _card(_pokemon("Garganacl", "Stage 2", "F", "FF", "120"))
	var second_garganacl := _card(_pokemon("Garganacl", "Stage 2", "F", "FF", "120"))
	var context := {"game_state": state, "player_index": 0}
	state.players[0].hand.append(garganacl)
	var candy_score: float = strategy.call("score_interaction_target", rare_candy, {"id": "search_cards"}, context)
	var redundant_garganacl_score: float = strategy.call("score_interaction_target", second_garganacl, {"id": "search_cards"}, context)
	var picked: Array = strategy.call("pick_interaction_items", [second_garganacl, rare_candy], {
		"id": "search_cards",
		"max_select": 1,
	}, context)
	return run_checks([
		assert_true(candy_score >= redundant_garganacl_score + 300.0, "With Garganacl already in hand, Quick Search should complete its Nacli route with Rare Candy"),
		assert_true(picked.size() == 1 and picked[0] == rare_candy, "Quick Search should take Rare Candy instead of a duplicate Garganacl"),
	])


func test_control_uses_pal_pad_only_with_live_supporters_and_protects_it_from_discard() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var live_state := _state(8)
	var dead_state := _state(8)
	var pal_pad := _card(_trainer("Pal Pad", "Item"))
	live_state.players[0].discard_pile.assign([
		_card(_trainer("Team Star Grunt", "Supporter")),
		_card(_trainer("Boss's Orders", "Supporter")),
	])
	var live_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": pal_pad,
		"productive": true,
	}, live_state, 0)
	var dead_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": pal_pad,
		"productive": false,
	}, dead_state, 0)
	return run_checks([
		assert_true(live_score >= dead_score + 4000.0, "Pal Pad should be committed only when it restores the control loop"),
		assert_true(int(strategy.call("get_discard_priority_contextual", pal_pad, live_state, 0)) <= 2, "A live Pal Pad should be protected from discard costs"),
	])


func test_switching_ticket_uses_public_exchange_size_not_hidden_prize_identity() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var core_identity_state := _state(12)
	var filler_identity_state := _state(12)
	var full_exchange_state := _state(7)
	var ticket := _card(_trainer("Switching Ticket", "Item"))
	core_identity_state.players[0].prizes.append(_card(_pokemon("Pidgeot ex", "Stage 2", "C", "CC", "120", "ex")))
	filler_identity_state.players[0].prizes.append(_card(_trainer("Hidden filler", "Item")))
	for index: int in 6:
		full_exchange_state.players[0].prizes.append(_card(_trainer("Hidden prize %d" % index, "Item")))
	var core_identity_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": ticket,
	}, core_identity_state, 0)
	var filler_identity_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": ticket,
	}, filler_identity_state, 0)
	var full_exchange_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": ticket,
	}, full_exchange_state, 0)
	return run_checks([
		assert_eq(core_identity_score, filler_identity_score, "Face-down prize identity must not affect Switching Ticket scoring"),
		assert_true(full_exchange_score >= filler_identity_score + 2000.0, "Switching Ticket should model every card exchanged, not one guessed prize"),
	])


func test_turtonator_energy_denial_beats_ending_against_an_energized_pokemon_ex() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var state := _state(10)
	var turtonator := _slot(_pokemon("Turtonator", "Basic", "R", "R", "0"))
	turtonator.attached_energy.append(_card(_energy("Fire Energy", "R")))
	state.players[0].active_pokemon = turtonator
	var opponent_ex := _slot(_pokemon("Opponent ex", "Basic", "L", "L", "100", "ex"), 1)
	opponent_ex.attached_energy.append(_card(_energy("Lightning Energy", "L"), 1))
	state.players[1].active_pokemon = opponent_ex
	var attack_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": turtonator,
		"attack_index": 0,
		"projected_damage": 0,
	}, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	return assert_true(attack_score >= end_score + 3000.0, "Turtonator should convert its Fire Energy into immediate ex Energy denial")


func test_grass_setup_establishes_toedscool_and_two_ogerpon_engines_before_padding() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(18)
	state.players[0].active_pokemon = _slot(_pokemon("Mew ex", "Basic", "P", "C", "10", "ex"))
	var toedscool := _card(_pokemon("Toedscool", "Basic", "G", "G", "20"))
	var ogerpon := _card(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	var support := _card(_pokemon("Fezandipiti ex", "Basic", "D", "C", "20", "ex"))
	var toedscool_score: float = strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": toedscool}, state, 0)
	var ogerpon_score: float = strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": ogerpon}, state, 0)
	var support_score: float = strategy.call("score_action_absolute", {"kind": "play_basic_to_bench", "card": support}, state, 0)
	return run_checks([
		assert_true(toedscool_score >= support_score + 2500.0, "The first Toedscool lane should beat support padding"),
		assert_true(ogerpon_score >= support_score + 2200.0, "The first Ogerpon Energy engine should beat support padding"),
	])


func test_grass_attachment_funds_toedscruel_then_spreads_to_an_unenergized_bench() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(16)
	var toedscruel := _slot(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	var toedscool := _slot(_pokemon("Toedscool", "Basic", "G", "G", "20"))
	toedscruel.attached_energy.append(_card(_energy("Grass A", "G")))
	ogerpon.attached_energy.assign([_card(_energy("Grass B", "G")), _card(_energy("Grass C", "G"))])
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench.assign([ogerpon, toedscool])
	var hand_grass := _card(_energy("Grass Energy", "G"))
	state.players[0].hand.append(hand_grass)
	var attacker_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": hand_grass, "target_slot": toedscruel}, state, 0)
	var stack_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": hand_grass, "target_slot": ogerpon}, state, 0)
	toedscruel.attached_energy.append(_card(_energy("Grass D", "G")))
	var spread_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": hand_grass, "target_slot": toedscool}, state, 0)
	var post_ready_stack_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": hand_grass, "target_slot": ogerpon}, state, 0)
	return run_checks([
		assert_true(attacker_score >= stack_score + 3500.0, "The second Grass must complete Colony Rush before extra Ogerpon stacking"),
		assert_true(spread_score >= post_ready_stack_score + 3000.0, "Once Toedscruel is ready, Grass should create a new Colony Rush bench body"),
	])


func test_energy_switch_uses_spare_ogerpon_energy_without_erasing_a_colony_body() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(14)
	var toedscruel := _slot(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	var toedscool := _slot(_pokemon("Toedscool", "Basic", "G", "G", "20"))
	var active_grass := _card(_energy("Active Grass", "G"))
	var spare_grass := _card(_energy("Spare Grass", "G"))
	var ogerpon_floor := _card(_energy("Ogerpon Floor", "G"))
	var only_grass := _card(_energy("Only Grass", "G"))
	toedscruel.attached_energy.append(active_grass)
	ogerpon.attached_energy.assign([ogerpon_floor, spare_grass])
	toedscool.attached_energy.append(only_grass)
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench.assign([ogerpon, toedscool])
	var context := {"game_state": state, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", [only_grass, spare_grass], {
		"id": "energy_assignment",
		"max_select": 1,
	}, context)
	var spare_score: float = strategy.call("score_interaction_target", spare_grass, {"id": "energy_assignment"}, context)
	var only_score: float = strategy.call("score_interaction_target", only_grass, {"id": "energy_assignment"}, context)
	var target_score: float = strategy.call("score_interaction_target", toedscruel, {"id": "energy_assignment"}, context.merged({"source_card": spare_grass}))
	return run_checks([
		assert_true(picked.size() == 1 and picked[0] == spare_grass, "Field assignment should explicitly select Ogerpon's spare Grass source"),
		assert_true(spare_score >= only_score + 2000.0, "Energy Switch should donate Ogerpon's spare Grass and preserve Toedscool's only Colony Rush Energy"),
		assert_true(target_score > 2000.0, "The incomplete active Toedscruel should be the productive Energy Switch target"),
	])


func test_bug_catching_set_takes_the_live_evolution_and_grass_pair() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(20)
	state.players[0].active_pokemon = _slot(_pokemon("Toedscool", "Basic", "G", "G", "20"))
	state.players[0].bench.append(_slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex")))
	var evolution := _card(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	var grass := _card(_energy("Grass Energy", "G"))
	var extra_ogerpon := _card(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	var picked: Array = strategy.call("pick_interaction_items", [extra_ogerpon, grass, evolution], {
		"id": "bug_catching_set_cards",
		"max_select": 2,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 2, "Bug Catching Set should take two productive cards"),
		assert_true(evolution in picked, "Bug Catching Set should complete the live Toedscruel evolution lane"),
		assert_true(grass in picked, "Bug Catching Set should pair the evolution with its required Grass Energy"),
	])


func test_low_deck_grass_route_uses_super_rod_and_suppresses_teal_dance_draw() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(2)
	var toedscruel := _slot(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	toedscruel.attached_energy.assign([_card(_energy("Grass A", "G")), _card(_energy("Grass B", "G"))])
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench.append(ogerpon)
	state.players[0].hand.append(_card(_energy("Grass Energy", "G")))
	var discard_grass_a := _card(_energy("Discard Grass A", "G"))
	var discard_grass_b := _card(_energy("Discard Grass B", "G"))
	var discard_toedscruel := _card(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	var discard_support := _card(_pokemon("Mew ex", "Basic", "P", "C", "10", "ex"))
	state.players[0].discard_pile.assign([discard_support, discard_grass_a, discard_toedscruel, discard_grass_b])
	var super_rod := _card(_trainer("Super Rod", "Item"))
	var rod_score: float = strategy.call("score_action_absolute", {"kind": "play_trainer", "card": super_rod}, state, 0)
	var dance_score: float = strategy.call("score_action_absolute", {"kind": "use_ability", "source_slot": ogerpon}, state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": toedscruel,
		"attack_index": 0,
		"projected_damage": 80,
	}, state, 0)
	var picked: Array = strategy.call("pick_interaction_items", state.players[0].discard_pile, {
		"id": "cards_to_return",
		"max_select": 3,
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(rod_score >= dance_score + 5000.0, "Low-deck play should refill with Super Rod instead of drawing through Teal Dance"),
		assert_true(attack_score >= dance_score + 2500.0, "A ready Colony Rush should beat low-deck Teal Dance churn"),
		assert_eq(picked.size(), 3, "Super Rod should return a full three-card reserve when deck-out is close"),
		assert_true(
			discard_grass_a in picked and discard_grass_b in picked and discard_toedscruel in picked,
			"Super Rod should recover Grass fuel and the backup Toedscruel lane (picked=%s)" % str(picked.map(func(item: CardInstance) -> String: return str(item.card_data.name))),
		),
	])


func test_teal_dance_runtime_path_builds_a_typed_candidate_list() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(12)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	state.players[0].active_pokemon = ogerpon
	state.players[0].hand.append(_card(_energy("Grass Energy", "G")))
	return assert_true(
		bool(strategy.call("_teal_dance_available", state.players[0], state.turn_number)),
		"The live-match Teal Dance scan should accept the untyped field-slot list without a runtime type error"
	)


func test_route_owner_prefers_a_ready_core_attacker_over_generic_active_pressure() -> String:
	var control := _strategy(CONTROL_DECK_ID)
	var grass := _strategy(GRASS_DECK_ID)
	var control_state := _state(12)
	var grass_state := _state(12)
	var control_active := _slot(_pokemon("Generic control Active", "Basic", "C", "C", "20"))
	control_active.attached_energy.append(_card(_energy("Colorless", "C")))
	var garganacl := _slot(_pokemon("Garganacl", "Stage 2", "F", "FF", "120"))
	garganacl.attached_energy.assign([
		_card(_energy("Fighting A", "F")),
		_card(_energy("Fighting B", "F")),
	])
	control_state.players[0].active_pokemon = control_active
	control_state.players[0].bench = [garganacl]
	var grass_active := _slot(_pokemon("Generic grass Active", "Basic", "C", "C", "20"))
	grass_active.attached_energy.append(_card(_energy("Colorless", "C")))
	var toedscruel := _slot(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	toedscruel.attached_energy.assign([
		_card(_energy("Grass A", "G")),
		_card(_energy("Grass B", "G")),
	])
	grass_state.players[0].active_pokemon = grass_active
	grass_state.players[0].bench = [toedscruel]
	var control_plan: Dictionary = control.call("build_turn_plan", control_state, 0, {})
	var grass_plan: Dictionary = grass.call("build_turn_plan", grass_state, 0, {})
	var control_owner: Dictionary = control_plan.get("owner", {})
	var grass_owner: Dictionary = grass_plan.get("owner", {})
	return run_checks([
		assert_eq(str(control_owner.get("turn_owner_name", "")), "Garganacl", "A ready control core attacker should own the route before a generic Active"),
		assert_eq(str(grass_owner.get("turn_owner_name", "")), "Toedscruel ex", "A ready Grass core attacker should own the route before a generic Active"),
	])


func test_grass_continuity_penalty_requires_a_live_setup_action_and_exempts_ko() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(12)
	var toedscruel := _slot(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	toedscruel.attached_energy.assign([
		_card(_energy("Grass A", "G")),
		_card(_energy("Grass B", "G")),
	])
	var energized := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	energized.attached_energy.append(_card(_energy("Grass C", "G")))
	var unenergized := _slot(_pokemon("Toedscool", "Basic", "G", "G", "20"))
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench = [energized, unenergized]
	state.players[0].prizes = [
		_card(_trainer("Prize A", "Item")),
		_card(_trainer("Prize B", "Item")),
	]
	var blocked_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var hand_grass := _card(_energy("Grass Energy", "G"))
	state.players[0].hand.append(hand_grass)
	var live_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var non_ko := {
		"kind": "attack",
		"source_slot": toedscruel,
		"attack_index": 0,
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var knockout := non_ko.duplicate()
	knockout["projected_knockout"] = true
	var direct_non_ko: float = strategy.call("score_action_absolute", non_ko, state, 0)
	var planned_non_ko: float = strategy.call("score_action_absolute_with_plan", non_ko, state, 0, plan)
	var direct_ko: float = strategy.call("score_action_absolute", knockout, state, 0)
	var planned_ko: float = strategy.call("score_action_absolute_with_plan", knockout, state, 0, plan)
	return run_checks([
		assert_false(bool(blocked_contract.get("safe_setup_before_attack", false)), "Setup debt without an executable action must not penalize attack"),
		assert_true(bool(live_contract.get("safe_setup_before_attack", false)), "A legal Grass attachment should activate continuity setup"),
		assert_true(planned_non_ko <= direct_non_ko - 600.0, "A non-KO attack should pay the live continuity penalty"),
		assert_true(absf(planned_ko - direct_ko) < 0.01, "A projected KO must be exempt from continuity attack penalty"),
	])


func test_control_continuity_penalty_requires_a_live_setup_action_and_exempts_ko() -> String:
	var strategy := _strategy(CONTROL_DECK_ID)
	var state := _state(12)
	var garganacl := _slot(_pokemon("Garganacl", "Stage 2", "F", "FF", "120"))
	garganacl.attached_energy = [
		_card(_energy("Fighting A", "F")),
		_card(_energy("Fighting B", "F")),
	]
	state.players[0].active_pokemon = garganacl
	state.players[0].prizes = [
		_card(_trainer("Prize A", "Item")),
		_card(_trainer("Prize B", "Item")),
	]
	var blocked_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	state.players[0].hand.append(_card(_pokemon("Pidgey", "Basic", "C", "C", "20")))
	var live_contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var non_ko := {
		"kind": "attack",
		"source_slot": garganacl,
		"attack_index": 0,
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var knockout := non_ko.duplicate()
	knockout["projected_knockout"] = true
	var direct_non_ko: float = strategy.call("score_action_absolute", non_ko, state, 0)
	var planned_non_ko: float = strategy.call("score_action_absolute_with_plan", non_ko, state, 0, plan)
	var direct_ko: float = strategy.call("score_action_absolute", knockout, state, 0)
	var planned_ko: float = strategy.call("score_action_absolute_with_plan", knockout, state, 0, plan)
	return run_checks([
		assert_false(bool(blocked_contract.get("safe_setup_before_attack", false)), "Control debt without a playable setup card must not penalize attack"),
		assert_true(bool(live_contract.get("safe_setup_before_attack", false)), "A playable Pidgey should activate Control continuity setup"),
		assert_true(planned_non_ko <= direct_non_ko - 500.0, "A non-KO control attack should pay the live continuity penalty"),
		assert_true(absf(planned_ko - direct_ko) < 0.01, "A projected KO must bypass Control continuity penalty"),
	])


func test_colony_rush_waits_for_safe_spread_debt_then_converts() -> String:
	var strategy := _strategy(GRASS_DECK_ID)
	var state := _state(12)
	var toedscruel := _slot(_pokemon("Toedscruel ex", "Stage 1", "G", "GG", "80", "ex"))
	toedscruel.attached_energy.assign([_card(_energy("Grass A", "G")), _card(_energy("Grass B", "G"))])
	var energized := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", "GGG", "30", "ex"))
	energized.attached_energy.append(_card(_energy("Grass C", "G")))
	var unenergized := _slot(_pokemon("Toedscool", "Basic", "G", "G", "20"))
	state.players[0].active_pokemon = toedscruel
	state.players[0].bench.assign([energized, unenergized])
	var hand_grass := _card(_energy("Grass Energy", "G"))
	state.players[0].hand.append(hand_grass)
	var attack := {
		"kind": "attack",
		"source_slot": toedscruel,
		"attack_index": 0,
		"projected_damage": 120,
		"projected_knockout": false,
	}
	var debt_attack_score: float = strategy.call("score_action_absolute", attack, state, 0)
	var spread_score: float = strategy.call("score_action_absolute", {"kind": "attach_energy", "card": hand_grass, "target_slot": unenergized}, state, 0)
	unenergized.attached_energy.append(hand_grass)
	state.players[0].hand.erase(hand_grass)
	var convert_attack_score: float = strategy.call("score_action_absolute", attack, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	return run_checks([
		assert_true(spread_score >= debt_attack_score + 1500.0, "A safe Grass attachment should retire Colony Rush spread debt before a nonlethal attack"),
		assert_true(convert_attack_score >= end_score + 3000.0, "After spread debt is retired, Colony Rush should convert instead of ending the turn"),
	])


func _strategy(deck_id: int) -> RefCounted:
	var script: GDScript = load(STRATEGY_PATH)
	var strategy: RefCounted = script.new()
	var deck := DeckData.new()
	deck.id = deck_id
	strategy.call("configure_from_deck", deck)
	return strategy


func _state(deck_size: int) -> GameState:
	var state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot(_pokemon("Active %d" % player_index, "Basic", "C", "C", "10"), player_index)
		state.players.append(player)
	for index: int in deck_size:
		state.players[0].deck.append(_card(_trainer("Deck card %d" % index, "Item")))
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _pokemon(
	name: String,
	stage: String,
	energy_type: String,
	attack_cost: String,
	damage: String,
	mechanic: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.energy_type = energy_type
	card.mechanic = mechanic
	card.hp = 280
	card.attacks = [{"name": "Test attack", "cost": attack_cost, "damage": damage}]
	return card


func _energy(name: String, symbol: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = symbol
	card.energy_provides = symbol
	return card


func _trainer(name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return card


func _card(card_data: CardData, owner: int = 0) -> CardInstance:
	return CardInstance.create(card_data, owner)


func _slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card(card_data, owner))
	return slot
