class_name TestLugiaArcheopsLLM
extends TestBase

const LUGIA_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd"
const LUGIA_RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheops.gd"
const RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(LUGIA_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.abilities.clear()
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.description = "%s test rules text" % pname
	return cd


func _make_energy_cd(pname: String = "Double Turbo Energy", card_type: String = "Special Energy") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.energy_provides = ""
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_game_state(turn: int = 4) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % player_index), player_index)
		gs.players.append(player)
	return gs


func _lugia_v_cd() -> CardData:
	return _make_pokemon_cd(
		"Lugia V",
		"Basic",
		"C",
		220,
		"",
		"V",
		[],
		[
			{"name": "Read the Wind", "cost": "C", "damage": "0", "text": "Discard a card from your hand. If you do, draw 3 cards."},
			{"name": "Aero Dive", "cost": "CCCC", "damage": "130"},
		]
	)


func _lugia_vstar_cd() -> CardData:
	return _make_pokemon_cd(
		"Lugia VSTAR",
		"VSTAR",
		"C",
		280,
		"Lugia V",
		"V",
		[{"name": "Summoning Star", "text": "Put up to 2 Colorless Pokemon from discard onto your Bench."}],
		[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
	)


func _archeops_cd() -> CardData:
	return _make_pokemon_cd(
		"Archeops",
		"Stage 2",
		"C",
		150,
		"Archen",
		"",
		[{"name": "Primal Turbo", "text": "Search your deck for up to 2 Special Energy cards and attach them to 1 of your Pokemon."}],
		[{"name": "Speed Wing", "cost": "CCC", "damage": "120"}]
	)


func _cinccino_cd() -> CardData:
	return _make_pokemon_cd(
		"Cinccino",
		"Stage 1",
		"C",
		110,
		"Minccino",
		"",
		[],
		[{"name": "Special Roll", "cost": "CC", "damage": "70x", "text": "This attack does 70 damage for each Special Energy attached to this Pokemon."}]
	)


func _minccino_cd() -> CardData:
	return _make_pokemon_cd("Minccino", "Basic", "C", 70)


func _fill_deck(player: PlayerState, count: int, owner: int = 0) -> void:
	player.deck.clear()
	for i: int in count:
		player.deck.append(CardInstance.create(_make_energy_cd("Gift Energy"), owner))


func _find_route(payload: Dictionary, route_id: String) -> Dictionary:
	for raw_route: Variant in payload.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == route_id:
			return raw_route
	return {}


func _route_action_ids(route: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var raw_actions: Variant = route.get("actions", [])
	if raw_actions is Array:
		for raw_action: Variant in raw_actions:
			if raw_action is Dictionary:
				ids.append(str((raw_action as Dictionary).get("id", "")))
	return ids


func _card_names(items: Array) -> Array[String]:
	var names: Array[String] = []
	for item: Variant in items:
		if item is CardInstance and (item as CardInstance).card_data != null:
			names.append(str((item as CardInstance).card_data.name_en))
	return names


func test_lugia_archeops_llm_scripts_load() -> String:
	return run_checks([
		assert_not_null(_load_script(RUNTIME_SCRIPT_PATH), "DeckStrategyLLMRuntimeBase.gd should load"),
		assert_not_null(_load_script(LUGIA_RULES_SCRIPT_PATH), "DeckStrategyLugiaArcheops.gd should load"),
		assert_not_null(_load_script(LUGIA_LLM_SCRIPT_PATH), "DeckStrategyLugiaArcheopsLLM.gd should load"),
	])


func test_lugia_llm_payload_exposes_summoning_star_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_vstar_cd(), 0)
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	_fill_deck(player, 20)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": player.active_pokemon, "ability_index": 0, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var route := _find_route(payload, "route:lugia_summoning_star")
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var shell: Dictionary = facts.get("lugia_shell", {}) if facts.get("lugia_shell", {}) is Dictionary else {}
	var actions := _route_action_ids(route)
	var policy_text := JSON.stringify((route.get("actions", [])[0] as Dictionary).get("selection_policy", {})) if not route.get("actions", []).is_empty() and route.get("actions", [])[0] is Dictionary else ""
	return run_checks([
		assert_true(bool(shell.get("summoning_star_ready", false)), "Payload facts should mark Summoning Star ready with Archeops in discard"),
		assert_true(not route.is_empty(), "Payload should expose the Lugia Summoning Star route"),
		assert_true(not actions.is_empty() and actions[0].begins_with("use_ability:"), "Summoning Star route should start from the exact ability action"),
		assert_true(policy_text.contains("Archeops"), "Summoning Star route should carry a policy that summons Archeops"),
	])


func test_lugia_llm_primal_turbo_route_targets_lugia_before_archeops_padding() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_vstar_cd(), 0)
	var archeops := _make_slot(_archeops_cd(), 0)
	player.bench.append(archeops)
	_fill_deck(player, 20)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": archeops, "ability_index": 0, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var route := _find_route(payload, "route:lugia_primal_turbo_to_attacker")
	var actions := _route_action_ids(route)
	var first_action: Dictionary = route.get("actions", [])[0] if not route.get("actions", []).is_empty() and route.get("actions", [])[0] is Dictionary else {}
	var policy_text := JSON.stringify(first_action.get("selection_policy", {}))
	return run_checks([
		assert_true(not route.is_empty(), "Payload should expose a Primal Turbo route"),
		assert_true(not actions.is_empty() and actions[0].begins_with("use_ability:"), "Primal Turbo route should start from Archeops ability"),
		assert_true(policy_text.contains("Lugia VSTAR"), "Primal Turbo policy should prioritize Lugia VSTAR as the closest attacker"),
		assert_true(policy_text.contains("Archeops"), "Primal Turbo policy should explicitly avoid padding Archeops"),
	])


func test_lugia_llm_discard_fallback_protects_lugia_vstar_and_discards_archeops() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	var lugia_vstar := CardInstance.create(_lugia_vstar_cd(), 0)
	var archeops := CardInstance.create(_archeops_cd(), 0)
	var fez := CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	var picked: Array = strategy.call("pick_interaction_items", [lugia_vstar, archeops, fez], {"id": "discard_cards", "count": 2}, {"game_state": gs, "player_index": 0})
	var names := _card_names(picked)
	return run_checks([
		assert_true(names.has("Archeops"), "Discard fallback should choose Archeops to enable Summoning Star"),
		assert_false(names.has("Lugia VSTAR"), "Discard fallback should protect the only Lugia VSTAR while Lugia V is on board"),
	])


func test_lugia_llm_ultra_ball_search_overrides_duplicate_vstar_for_backup_lugia() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_lugia_vstar_cd(), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	strategy.set("_cached_turn_number", 2)
	strategy.set("_llm_queue_turn", 2)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "play_trainer:c31"}]})
	strategy.set("_llm_action_catalog", {
		"play_trainer:c31": {"id": "play_trainer:c31", "action_id": "play_trainer:c31", "type": "play_trainer", "card": "Ultra Ball"},
	})
	strategy.set("_llm_action_queue", [{
		"id": "play_trainer:c31",
		"action_id": "play_trainer:c31",
		"kind": "play_trainer",
		"interactions": {"search_targets": ["Lugia VSTAR"]},
	}])
	var search_items := [
		CardInstance.create(_lugia_vstar_cd(), 0),
		CardInstance.create(_lugia_v_cd(), 0),
		CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0),
		CardInstance.create(_make_pokemon_cd("Bloodmoon Ursaluna ex", "Basic", "C", 260, "", "ex"), 0),
	]
	var picked: Array = strategy.call("pick_interaction_items", search_items, {"id": "search_pokemon", "max_select": 1}, {"game_state": gs, "player_index": 0})
	var names := _card_names(picked)
	return run_checks([
		assert_eq(names[0] if not names.is_empty() else "", "Lugia V", "Trace repair should override duplicate VSTAR search and find backup Lugia V"),
	])


func test_lugia_llm_backup_basic_search_route_policy_prefers_lugia_v_when_vstar_in_hand() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 60), 0))
	player.hand.append(CardInstance.create(_lugia_vstar_cd(), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	_fill_deck(player, 20)
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": ultra_ball, "requires_interaction": true},
		{"kind": "end_turn"},
	])
	var route := _find_route(payload, "route:lugia_backup_basic_search")
	var facts: Dictionary = payload.get("turn_tactical_facts", {})
	var shell: Dictionary = facts.get("lugia_shell", {}) if facts.get("lugia_shell", {}) is Dictionary else {}
	var first_action: Dictionary = route.get("actions", [])[0] if not route.get("actions", []).is_empty() and route.get("actions", [])[0] is Dictionary else {}
	var policy: Dictionary = first_action.get("selection_policy", {}) if first_action.get("selection_policy", {}) is Dictionary else {}
	var search: Dictionary = policy.get("search", {}) if policy.get("search", {}) is Dictionary else {}
	var prefer: Array = search.get("prefer", []) if search.get("prefer", []) is Array else []
	return run_checks([
		assert_true(bool(shell.get("backup_basic_search_preferred", false)), "Payload facts should mark backup Basic search as preferred"),
		assert_true(not route.is_empty(), "Payload should expose a backup-basic Ultra Ball route"),
		assert_eq(str(prefer[0]) if not prefer.is_empty() else "", "Lugia V", "Backup route should put Lugia V before duplicate VSTAR"),
		assert_true(prefer.find("Lugia VSTAR") > prefer.find("Lugia V"), "Duplicate VSTAR should stay behind backup Lugia V when VSTAR is already in hand"),
	])


func test_lugia_llm_repairs_no_bench_search_from_archeops_to_basic_backup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.hand.append(CardInstance.create(_lugia_vstar_cd(), 0))
	var lugia := CardInstance.create(_lugia_v_cd(), 0)
	var minccino := CardInstance.create(_minccino_cd(), 0)
	var archeops := CardInstance.create(_archeops_cd(), 0)
	var items: Array = [archeops, lugia, minccino]
	var step := {"id": "search_pokemon", "max_select": 1}
	var context := {"game_state": gs, "player_index": 0}
	var lugia_score: float = strategy.score_interaction_target(lugia, step, context)
	var archeops_score: float = strategy.score_interaction_target(archeops, step, context)
	var repaired_variant: Variant = strategy.call("_repair_lugia_search_interaction_picks", [archeops], items, step, context)
	var repaired: Array = repaired_variant if repaired_variant is Array else []
	var repaired_names := _card_names(repaired)
	return run_checks([
		assert_true(lugia_score > archeops_score, "No-bench emergency search should score Lugia V above Archeops (Lugia %f vs Archeops %f)" % [lugia_score, archeops_score]),
		assert_true(bool(strategy.call("_lugia_should_prioritize_backup_basic_search", player)), "No-bench emergency should activate backup Basic search policy"),
		assert_true(repaired_names.has("Lugia V"), "Search repair should override a planned Archeops pick with Lugia V when the board has no backup Basic"),
		assert_false(repaired_names.has("Archeops"), "Search repair should not keep Archeops as the emergency no-bench pick"),
	])


func test_lugia_llm_search_still_prefers_vstar_when_vstar_missing() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 60), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	player.discard_pile.append(CardInstance.create(_archeops_cd(), 0))
	var search_items := [
		CardInstance.create(_lugia_vstar_cd(), 0),
		CardInstance.create(_lugia_v_cd(), 0),
		CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0),
	]
	var picked: Array = strategy.call("pick_interaction_items", search_items, {"id": "search_pokemon", "max_select": 1}, {"game_state": gs, "player_index": 0})
	var names := _card_names(picked)
	return run_checks([
		assert_eq(names[0] if not names.is_empty() else "", "Lugia VSTAR", "Search fallback must still protect the Summoning Star mainline when VSTAR is missing"),
	])


func test_lugia_llm_blocks_bad_retreat_and_low_deck_research() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_vstar_cd(), 0)
	var archeops := _make_slot(_archeops_cd(), 0)
	player.bench.append(archeops)
	var cinccino := _make_slot(_cinccino_cd(), 0)
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	player.bench.append(cinccino)
	_fill_deck(player, 5)
	var bad_retreat := {"kind": "retreat", "bench_target": archeops}
	var good_retreat := {"kind": "retreat", "bench_target": cinccino}
	var research := CardInstance.create(_make_trainer_cd("Professor's Research", "Supporter"), 0)
	var research_action := {"kind": "play_trainer", "card": research}
	var blocked_bad_retreat: bool = strategy.call("_deck_should_block_exact_queue_match", {}, bad_retreat, gs, 0)
	var blocked_good_retreat: bool = strategy.call("_deck_should_block_exact_queue_match", {}, good_retreat, gs, 0)
	var can_replace_ready_retreat: bool = strategy.call("_deck_can_replace_end_turn_with_action", good_retreat, gs, 0)
	var research_score: float = strategy.call("score_action_absolute", research_action, gs, 0)
	return run_checks([
		assert_true(blocked_bad_retreat, "Lugia shell should not retreat into Archeops padding"),
		assert_false(blocked_good_retreat, "Lugia shell should still allow retreat into a ready Cinccino attacker"),
		assert_true(can_replace_ready_retreat, "Ready Cinccino handoff may still replace a queued end_turn"),
		assert_true(research_score <= -1000.0, "Low-deck Research should be blocked once the Lugia engine/attacker is online"),
	])


func test_lugia_llm_ready_backup_handoff_route_is_attack_pivot() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_vstar_cd(), 0)
	var archeops_a := _make_slot(_archeops_cd(), 0)
	var archeops_b := _make_slot(_archeops_cd(), 0)
	var cinccino := _make_slot(_cinccino_cd(), 0)
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	player.bench.append(archeops_a)
	player.bench.append(archeops_b)
	player.bench.append(cinccino)
	_fill_deck(player, 20)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "retreat", "bench_target": cinccino},
		{"kind": "end_turn"},
	])
	var route := _find_route(payload, "route:lugia_ready_backup_handoff")
	var actions := _route_action_ids(route)
	return run_checks([
		assert_true(not route.is_empty(), "Payload should expose a ready-backup handoff route when active cannot attack"),
		assert_eq(str(route.get("goal", "")), "pivot_to_attack", "Ready-backup route should be hard-preferred as an attack pivot"),
		assert_true(not actions.is_empty() and actions[0].begins_with("retreat:"), "Ready-backup route should pivot before any padding action"),
	])


func test_lugia_llm_vstar_evolution_replans_for_primal_turbo_after_limit() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var before_snapshot := {
		"turn": 12,
		"active_name": "Lugia V",
		"bench_names": ["Archeops", "Archeops", "Lumineon V"],
		"archeops_field_count": 2,
		"ready_attacker_count": 0,
		"ready_backup_attacker_count": 0,
		"field_energy_count": 2,
	}
	var after_snapshot := before_snapshot.duplicate(true)
	after_snapshot["active_name"] = "Lugia VSTAR"
	var trigger: Dictionary = strategy.call("_deck_replan_trigger_after_state_change", before_snapshot, after_snapshot, {
		"action_kind": "evolve",
		"action_card_name": "Lugia VSTAR",
	})
	return run_checks([
		assert_true(bool(trigger.get("should_replan", false)), "Lugia VSTAR evolution with Archeops online should force a fresh Primal Turbo plan"),
		assert_eq(str(trigger.get("reason", "")), "lugia_vstar_evolved_needs_primal_turbo", "The trigger should explain the missing energy-conversion window"),
		assert_true(bool(trigger.get("ignore_replan_limit", false)), "This replan must bypass the per-turn limit after a draw/search-heavy route"),
	])


func test_lugia_llm_manual_attach_can_substitute_special_energy_before_draw() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Jet Energy"), 0))
	_fill_deck(player, 16)
	strategy.set("_cached_turn_number", 12)
	strategy.set("_llm_queue_turn", 12)
	strategy.set("_llm_decision_tree", {"actions": [{"type": "play_trainer"}, {"type": "attach_energy"}]})
	strategy.set("_llm_action_catalog", {"queued": {"id": "queued"}})
	strategy.set("_llm_action_queue", [
		{"kind": "play_trainer", "action_id": "play_trainer:c39", "capability": "discard_to_draw", "card": "Professor's Research"},
		{"kind": "attach_energy", "action_id": "attach_energy:c1:active", "capability": "manual_attach", "card": "Jet Energy", "position": "active", "target": "Lugia V"},
		{"kind": "end_turn", "action_id": "end_turn"},
	])
	var gift_attach := {
		"kind": "attach_energy",
		"card": CardInstance.create(_make_energy_cd("Gift Energy"), 0),
		"target_slot": player.active_pokemon,
	}
	var attach_score: float = strategy.call("score_action_absolute", gift_attach, gs, 0)
	return assert_true(attach_score > 10000.0, "Any useful Special Energy attach to active Lugia should be treated as the queued manual attach before non-critical discard draw")


func test_lugia_llm_attack_cannot_skip_queued_primal_turbo() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var cinccino := _make_slot(_cinccino_cd(), 0)
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Gift Energy"), 0))
	cinccino.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	player.active_pokemon = cinccino
	player.bench.append(_make_slot(_lugia_v_cd(), 0))
	player.bench.append(_make_slot(_archeops_cd(), 0))
	_fill_deck(player, 20)
	strategy.set("_cached_turn_number", 8)
	strategy.set("_llm_queue_turn", 8)
	strategy.set("_llm_decision_tree", {"actions": [{"type": "use_ability"}, {"type": "attack"}]})
	strategy.set("_llm_action_catalog", {"queued": {"id": "queued"}})
	strategy.set("_llm_action_queue", [
		{"type": "use_ability", "kind": "use_ability", "capability": "ability", "pokemon": "Archeops"},
		{"type": "attack", "kind": "attack", "attack_name": "Special Roll"},
	])
	var attack_action := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Special Roll",
		"attack_rules": _cinccino_cd().attacks[0],
		"projected_damage": 140,
	}
	var unplanned_attack := {
		"kind": "attack",
		"attack_index": 1,
		"attack_name": "Pound",
		"attack_rules": {"name": "Pound", "cost": "C", "damage": "10"},
		"projected_damage": 10,
	}
	var attack_score: float = strategy.call("score_action_absolute", attack_action, gs, 0)
	var unplanned_attack_score: float = strategy.call("score_action_absolute", unplanned_attack, gs, 0)
	return run_checks([
		assert_true(attack_score <= -1000.0, "Lugia route must not skip queued Primal Turbo before attacking"),
		assert_true(unplanned_attack_score <= -1000.0, "Lugia route must not allow an unplanned fallback attack while Primal Turbo is queued"),
	])


func test_lugia_llm_end_turn_repair_does_not_insert_unready_lugia_retreat() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	var backup_lugia := _make_slot(_lugia_v_cd(), 0)
	player.bench.append(backup_lugia)
	var retreat_to_unready_backup := {"kind": "retreat", "bench_target": backup_lugia}
	var can_replace_end_turn: bool = strategy.call("_deck_can_replace_end_turn_with_action", retreat_to_unready_backup, gs, 0)
	var globally_blocked: bool = strategy.call("_deck_should_block_exact_queue_match", {}, retreat_to_unready_backup, gs, 0)
	return run_checks([
		assert_false(can_replace_end_turn, "Queued end_turn should not be repaired into a retreat to an unready backup Lugia V"),
		assert_false(globally_blocked, "Exact LLM retreat actions stay legal; only terminal end_turn repair is narrowed"),
	])


func test_lugia_llm_end_turn_repair_allows_read_the_wind_after_dte() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	_fill_deck(player, 20)
	var read_the_wind := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Read the Wind",
		"attack_rules": _lugia_v_cd().attacks[0],
		"projected_damage": 0,
	}
	var can_replace_end_turn: bool = strategy.call("_deck_can_replace_end_turn_with_action", read_the_wind, gs, 0)
	return assert_true(can_replace_end_turn, "Queued end_turn may be repaired into Lugia V Read the Wind after DTE when the deck is safe")


func test_lugia_llm_end_turn_repair_blocks_read_the_wind_on_low_deck() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_v_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy"), 0))
	_fill_deck(player, 8)
	var read_the_wind := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Read the Wind",
		"attack_rules": _lugia_v_cd().attacks[0],
		"projected_damage": 0,
	}
	var can_replace_end_turn: bool = strategy.call("_deck_can_replace_end_turn_with_action", read_the_wind, gs, 0)
	return assert_false(can_replace_end_turn, "Low deck should not repair queued end_turn into a draw attack")


func test_lugia_llm_queue_guards_ignore_virtual_refs_without_runtime_objects() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheopsLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_lugia_vstar_cd(), 0)
	player.bench.append(_make_slot(_archeops_cd(), 0))
	_fill_deck(player, 6)
	var string_card_trainer := {"kind": "play_trainer", "card": "Professor's Research"}
	var virtual_attach := {"kind": "attach_energy", "card": "Gift Energy", "target_slot": "bench_0"}
	var virtual_ability := {"kind": "use_ability", "source_slot": "bench_0"}
	var virtual_retreat := {"kind": "retreat", "bench_target": "bench_0"}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, string_card_trainer, gs, 0)), "String-card trainer refs should not crash or become blocked as runtime draw actions"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, virtual_attach, gs, 0)), "Virtual attach refs without CardInstance/PokemonSlot objects should be ignored by Lugia guards"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, virtual_ability, gs, 0)), "Virtual ability refs without source slots should be ignored by low-deck guards"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, virtual_retreat, gs, 0)), "Virtual retreat refs without bench target slots should be ignored by Lugia guards"),
	])
