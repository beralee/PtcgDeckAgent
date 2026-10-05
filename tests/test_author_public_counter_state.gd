extends "res://tests/test_author_strategy_interaction_contract_v2.gd"


class ProjectingStrategy extends OfficialCounterWindowStrategy:
	var owner: RefCounted
	var projected: Array = []

	func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
		var metadata := UcisInteractionCompiler.metadata_for_step(step)
		var current := context.duplicate(true)
		current["cabt_select_type_raw"] = metadata.get("select_type_raw")
		current["cabt_select_context_raw"] = metadata.get("context_raw")
		current["cabt_option_type_raw"] = metadata.get("option_type_raw")
		var options: Array = []
		for index: int in items.size():
			options.append(owner.call("_make_option", index, items[index], "assignment_source", current))
		projected.append(options)
		return super.pick_interaction_items(items, step, context)


class CounterSceneWithTargets extends CounterDistributionStub:
	var targets: Array = []

	func _handle_counter_distribution_target(target_index: int) -> void:
		super._handle_counter_distribution_target(target_index)
		_field_interaction_assignment_entries[-1]["target"] = targets[target_index]


class PrizePlanningStrategy extends ProjectingStrategy:
	var plans: Array = []
	func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
		var fallback: Array = super.pick_interaction_items(items, step, context)
		var options: Array = projected[-1]
		var gsm: GameStateMachine = owner.get("_gsm")
		var opponent := {"active": [], "bench": []}
		if gsm.game_state.players[1].active_pokemon != null:
			opponent.active.append(owner.call("_public_slot", gsm.game_state.players[1].active_pokemon))
		for slot: PokemonSlot in gsm.game_state.players[1].bench:
			opponent.bench.append(owner.call("_public_slot", slot))
		var frame := {"select_semantics": {"select_type_raw":1, "select_context_raw":13}, "options":options, "public_state":{"opponent":opponent}}
		var plan: Variant = preload("res://scripts/ai/ptcgdap/public/PublicDecisionFacts.gd").counter_prize_plan(frame)
		plans.append(plan)
		if not plan is Dictionary: return fallback
		var best := -1
		var count := 0
		var identity := 9223372036854775807
		for i: int in options.size():
			var entity: int = int(options[i].target_entity_serial)
			var amount: int = int(plan.get(entity, 0))
			if amount > count or (amount == count and amount > 0 and entity < identity):
				best = i; count = amount; identity = entity
		return [items[best]] if best >= 0 else fallback


func _fixture() -> Dictionary:
	var owner: RefCounted = AuthorOwnerScript.new()
	owner.set("_external_decision_port", RefCounted.new())
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	var targets: Array = [_make_counter_target("Active"), _make_counter_target("Bench")]
	for index: int in targets.size():
		targets[index].get_card_data().set_code = "COUNTERTEST"
		targets[index].get_card_data().card_index = str(index + 1)
	gsm.game_state.players[0].active_pokemon = _make_counter_target("Own")
	gsm.game_state.players[1].active_pokemon = targets[0]
	gsm.game_state.players[1].bench.append(targets[1])
	owner.set("_gsm", gsm)
	var strategy := ProjectingStrategy.new()
	strategy.owner = owner
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var scene := CounterSceneWithTargets.new()
	scene.targets = targets
	return {"owner": owner, "gsm": gsm, "targets": targets, "strategy": strategy, "resolver": resolver, "scene": scene}


func test_counter_progress_reprojects_by_entity_after_reorder_without_changing_hp() -> String:
	var f := _fixture()
	var step := {"id": "target_damage_counters", "ui_mode": "counter_distribution", "total_counters": 6}
	var checks: Array[String] = []
	checks.append(assert_true(f.resolver._resolve_external_counter_distribution_step(f.scene, step, {}, f.targets, 6)))
	var before: Array = f.strategy.projected[0]
	checks.append(assert_eq(before[0].get("remaining_damage_counters"), 6))
	checks.append(assert_eq(before[1].get("target_pending_damage_counters"), 0))
	var assigned_entity: Variant = before[1].get("target_entity_serial")
	f.targets.reverse()
	checks.append(assert_true(f.resolver._resolve_external_counter_distribution_step(f.scene, step, {}, f.targets, 6)))
	var after: Array = f.strategy.projected[1]
	checks.append(assert_eq(after[0].get("target_entity_serial"), assigned_entity))
	checks.append(assert_eq(after[0].get("target_pending_damage_counters"), 1))
	checks.append(assert_eq(after[1].get("target_pending_damage_counters"), 0))
	checks.append(assert_eq(after[0].get("remaining_damage_counters"), 5))
	checks.append(assert_eq(after[1].get("remaining_damage_counters"), 5))
	checks.append(assert_eq(after[0].get("target_remaining_hp"), 100))
	checks.append(assert_eq(after[0].get("pending_assignment_count"), 0))
	checks.append(assert_false(after[0].has("pending_counter_assignments"), "No engine targets in public options"))
	checks.append(assert_eq(before[1].get("target_pending_damage_counters"), 0, "Accepted choices cannot mutate an old public window"))
	f.scene.free()
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_counter_counts_aggregate_only_this_distribution_and_target() -> String:
	var f := _fixture()
	var context := {"remaining_damage_counters": 2, "pending_counter_assignments": [
		{"target": f.targets[0], "amount": 10}, {"target": f.targets[1], "amount": 10},
		{"target": f.targets[0], "amount": 20},
	]}
	var option: Dictionary = f.owner._make_option(0, f.targets[0], "assignment_source", context)
	var fresh: Dictionary = f.owner._make_option(0, f.targets[0], "assignment_source", {"remaining_damage_counters": 6})
	var legacy: Dictionary = f.owner._make_option(0, f.targets[0], "assignment_source", {})
	var checks: Array[String] = [
		assert_eq(option.get("target_pending_damage_counters"), 3),
		assert_eq(option.get("target_remaining_hp"), 100),
		assert_eq(fresh.get("target_pending_damage_counters"), 0),
		assert_eq(fresh.get("remaining_damage_counters"), 6),
		assert_false(legacy.has("target_pending_damage_counters")),
		assert_false(legacy.has("remaining_damage_counters")),
	]
	f.scene.free()
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_partial_movement_keeps_count_window_separate_from_target_budget() -> String:
	var f := _fixture()
	var step := {
		"id": "target_damage_counters", "ui_mode": "counter_distribution", "total_counters": 3,
		"max_assignments": 1, "max_assignments_per_target": 1, "allow_partial": true,
		"ucis_counter_count_window": {"ucis_context_name": "REMOVE_DAMAGE_COUNTER_COUNT"},
		"ucis_counter_target_window": {"ucis_context_name": "DAMAGE_COUNTER"},
	}
	f.resolver._resolve_external_counter_distribution_step(f.scene, step, {}, f.targets, 3)
	f.resolver._resolve_external_counter_distribution_step(f.scene, step, {}, f.targets, 3)
	var count: Dictionary = f.strategy.projected[0][0]
	var target: Dictionary = f.strategy.projected[1][0]
	var checks: Array[String] = [
		assert_false(count.has("remaining_damage_counters")),
		assert_eq(target.get("remaining_damage_counters"), 3, "Remaining is available budget, not the separately selected movement amount"),
		assert_eq(target.get("target_pending_damage_counters"), 0),
		assert_eq(f.scene._field_interaction_assignment_entries[0].amount, 20),
	]
	f.scene.free()
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_real_dragapult_attack_publishes_six_budgets_before_engine_settlement() -> String:
	var f := _fixture()
	var state: GameState = f.gsm.game_state
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 4
	state.current_player_index = 0
	state.first_player_index = 1
	var dragapult := PokemonSlot.new()
	var card := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV8C_159.json")))
	dragapult.pokemon_stack.append(CardInstance.create(card, 0))
	for uid: String in ["CSVE1C_FIR", "CSVE1C_PSY"]:
		var energy := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/" + uid + ".json")))
		dragapult.attached_energy.append(CardInstance.create(energy, 0))
	state.players[0].active_pokemon = dragapult
	state.players[1].active_pokemon = _make_counter_target("Defender")
	state.players[1].active_pokemon.get_card_data().hp = 500
	state.players[1].bench = [f.targets[0], f.targets[1]]
	for seat: int in [0, 1]:
		state.players[seat].player_index = seat
		for _index: int in 4:
			state.players[seat].deck.append(CardInstance.create(card, seat))
			state.players[seat].prizes.append(CardInstance.create(card, seat))
	f.gsm.effect_processor.register_pokemon_card(card)
	var bridge := preload("res://scripts/ai/HeadlessMatchBridge.gd").new()
	bridge.bind(f.gsm)
	var started: bool = bridge._try_use_attack_with_interaction(0, dragapult, 1)
	var checks: Array[String] = [assert_true(started, "Exact CSV8C_159 attack must be legal and open its real effect")]
	for spent: int in 6:
		checks.append(assert_eq(f.targets[1].damage_counters, 0, "Pending counters do not alter actual HP"))
		checks.append(assert_true(f.resolver.resolve_pending_step(bridge, f.gsm, 0, [] as Array[float])))
		if f.strategy.projected.size() != spent + 1:
			checks.append("Missing real counter window %d" % spent)
			break
		var options: Array = f.strategy.projected[spent]
		checks.append(assert_eq(options.size(), 2))
		if options.size() != 2:
			break
		checks.append(assert_eq(options[1].get("remaining_damage_counters"), 6 - spent))
		checks.append(assert_eq(options[1].get("target_pending_damage_counters"), spent))
		checks.append(assert_eq(options[1].get("target_remaining_hp"), 100))
	checks.append(assert_eq(f.strategy.projected.size(), 6))
	checks.append(assert_eq(f.targets[1].damage_counters, 60, "The real attack settles all six accepted counters once"))
	checks.append(assert_eq(f.targets[0].damage_counters, 0))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 200))
	checks.append(assert_eq(str(bridge.get("_pending_choice")), ""))
	bridge.free()
	f.scene.free()
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)


func test_real_dragapult_counter_planner_splits_three_knockouts() -> String:
	var f := _fixture()
	var state: GameState = f.gsm.game_state
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 4
	state.current_player_index = 0
	state.first_player_index = 1
	var dragapult := PokemonSlot.new()
	var card := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV8C_159.json")))
	dragapult.pokemon_stack.append(CardInstance.create(card, 0))
	for uid: String in ["CSVE1C_FIR", "CSVE1C_PSY"]:
		var energy := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/" + uid + ".json")))
		dragapult.attached_energy.append(CardInstance.create(energy, 0))
	state.players[0].active_pokemon = dragapult
	state.players[1].active_pokemon = _make_counter_target("Defender")
	state.players[1].active_pokemon.get_card_data().hp = 500
	var targets: Array = []
	for i: int in 4:
		var target: PokemonSlot = _make_counter_target("PrizeTarget%d" % i)
		target.get_card_data().set_code = "COUNTERTEST"
		target.get_card_data().card_index = str(i + 20)
		target.get_card_data().hp = 60 if i == 3 else 20
		if i == 3: target.get_card_data().mechanic = "ex"
		targets.append(target)
	state.players[1].bench.assign(targets)
	for seat: int in [0, 1]:
		state.players[seat].player_index = seat
		for _index: int in 6:
			state.players[seat].deck.append(CardInstance.create(card, seat))
			state.players[seat].prizes.append(CardInstance.create(card, seat))
	f.gsm.effect_processor.register_pokemon_card(card)
	var strategy := PrizePlanningStrategy.new()
	strategy.owner = f.owner
	f.resolver.set_deck_strategy(strategy)
	var registry := preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd").new()
	f.owner.set("_serial_registry", registry)
	f.owner.set("_match_generation", registry.get_match_generation())
	var counts: Array[int] = []
	for player: PlayerState in state.players:
		counts.append(f.owner._collect_player_cards(player).size())
		for instance: CardInstance in f.owner._collect_player_cards(player): registry.register_card(instance, player.player_index)
	registry.seal_card_inventory(counts)
	f.owner._sync_public_pokemon_entities()
	var bridge := preload("res://scripts/ai/HeadlessMatchBridge.gd").new()
	bridge.bind(f.gsm)
	var checks: Array[String] = [assert_true(bridge._try_use_attack_with_interaction(0, dragapult, 1))]
	for spent: int in 6:
		checks.append(assert_true(f.resolver.resolve_pending_step(bridge, f.gsm, 0, [] as Array[float])))
	checks.append(assert_eq(strategy.projected.size(), 6))
	for plan: Variant in strategy.plans: checks.append(assert_true(plan is Dictionary, "Owner projection must qualify the planner"))
	for i: int in 4:
		checks.append(assert_eq(targets[i].damage_counters, 0 if i == 3 else 20, "Six counters must split 2+2+2"))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 200))
	bridge.free()
	f.scene.free()
	EffectProcessor.cleanup_live_instances_for_tests()
	return run_checks(checks)
