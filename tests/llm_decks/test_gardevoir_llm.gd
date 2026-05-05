class_name TestGardevoirLLM
extends TestBase

const RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGardevoir.gd"
const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGardevoirLLM.gd"
const RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_llm_strategy() -> RefCounted:
	var script := _load_script(LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_rules_strategy() -> RefCounted:
	var script := _load_script(RULES_SCRIPT_PATH)
	return script.new() if script != null else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = []
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
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.description = "%s rule text" % pname
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_game_state(turn: int = 3) -> GameState:
	CardInstance.reset_id_counter()
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


func _inject_llm_queue(strategy: RefCounted, turn: int, actions: Array) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"actions": actions, "reasoning": "test"}
	strategy.call("_on_llm_response", mock_response, turn)


func _inject_llm_tree(strategy: RefCounted, turn: int, decision_tree: Dictionary) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"decision_tree": decision_tree, "reasoning": "tree test"}
	strategy.call("_on_llm_response", mock_response, turn)


func _action_ids(actions: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			var action: Dictionary = raw_action
			ids.append(str(action.get("id", action.get("action_id", ""))))
	return ids


func test_gardevoir_llm_script_loads() -> String:
	var rules_script := _load_script(RULES_SCRIPT_PATH)
	var runtime_script := _load_script(RUNTIME_SCRIPT_PATH)
	var llm_script := _load_script(LLM_SCRIPT_PATH)
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyGardevoir.gd should load"),
		assert_not_null(runtime_script, "DeckStrategyLLMRuntimeBase.gd should load"),
		assert_not_null(llm_script, "DeckStrategyGardevoirLLM.gd should load"),
		assert_not_null(llm_instance, "DeckStrategyGardevoirLLM.gd should instantiate"),
	])


func test_gardevoir_llm_strategy_id_and_value_net_surface() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var loaded: bool = bool(strategy.call("load_gardevoir_value_net", "user://missing_gardevoir_llm_value_net.json"))
	return run_checks([
		assert_eq(str(strategy.call("get_strategy_id")), "gardevoir_llm", "Gardevoir LLM strategy id should be stable"),
		assert_false(loaded, "Missing value-net load should fail through the delegated Gardevoir loader"),
		assert_false(bool(strategy.call("has_gardevoir_value_net")), "Delegated Gardevoir value-net status should remain false"),
		assert_null(strategy.call("get_value_net"), "Delegated value net should be null after a failed load"),
		assert_null(strategy.get("gardevoir_value_net"), "Wrapper should expose the legacy gardevoir_value_net property as null after failed load"),
	])


func test_gardevoir_llm_rules_fallback_delegates_action_scoring() -> String:
	var rules := _new_rules_strategy()
	var llm := _new_llm_strategy()
	if rules == null or llm == null:
		return "Rules and LLM strategies should instantiate"
	var gs := _make_game_state(3)
	var kirlia := CardInstance.create(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	var action := {"kind": "evolve", "card": kirlia}
	var rules_score: float = float(rules.call("score_action_absolute", action, gs, 0))
	var llm_score: float = float(llm.call("score_action_absolute", action, gs, 0))
	return assert_eq(llm_score, rules_score, "No-plan Gardevoir LLM scoring should delegate to rules fallback exactly")


func test_gardevoir_llm_prompt_hook_mentions_core_plan() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	strategy.call("set_deck_strategy_text", "Custom note: prioritize the second Kirlia before optional bench padding.")
	var gs := _make_game_state(3)
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines: PackedStringArray = payload.get("deck_strategy_prompt", PackedStringArray())
	var prompt_text := "\n".join(prompt_lines)
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "gardevoir_llm", "Payload should identify the Gardevoir LLM prompt"),
		assert_true(prompt_lines.size() >= 8, "Gardevoir prompt should provide deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "Ralts -> Kirlia -> Gardevoir ex", "Prompt should describe the core evolution chain"),
		assert_str_contains(prompt_text, "Psychic Energy", "Prompt should describe Psychic Energy discard setup"),
		assert_str_contains(prompt_text, "Psychic Embrace", "Prompt should describe Psychic Embrace assignment"),
		assert_str_contains(prompt_text, "Attacker selection", "Prompt should describe attacker selection policy"),
		assert_str_contains(prompt_text, "Fast-prize survival", "Prompt should call out fast Miraidon-style prize pressure"),
		assert_str_contains(prompt_text, "Post-engine pressure", "Prompt should reject low-value post-engine slap/end routes"),
		assert_str_contains(prompt_text, "Custom note: prioritize the second Kirlia", "Prompt should include player-authored strategy text"),
		assert_str_contains(prompt_text, "exact action ids", "Prompt should keep execution delegated to structured payload ids"),
	])


func test_gardevoir_llm_setup_roles_and_evolution_intent_hooks() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var ralts_hint: String = str(strategy.call("get_llm_setup_role_hint", _make_pokemon_cd("Ralts", "Basic", "P", 70)))
	var kirlia_hint: String = str(strategy.call("get_llm_setup_role_hint", _make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts")))
	var gardevoir_hint: String = str(strategy.call("get_llm_setup_role_hint", _make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex")))
	var rare_candy := _make_trainer_cd("Rare Candy")
	var tm_evolution := _make_trainer_cd("Technical Machine: Evolution", "Tool")
	return run_checks([
		assert_str_contains(ralts_hint, "priority opener", "Ralts setup hint should mark it as an opening evolution seed"),
		assert_str_contains(kirlia_hint, "draw engine", "Kirlia setup hint should mark it as the draw/evolution engine"),
		assert_str_contains(gardevoir_hint, "Psychic Embrace", "Gardevoir ex setup hint should mark the Stage 2 payoff"),
		assert_true(bool(strategy.call("_deck_is_setup_or_resource_card", rare_candy)), "Rare Candy should be a setup/resource card"),
		assert_true(bool(strategy.call("_deck_is_setup_or_resource_card", tm_evolution)), "TM Evolution should be a setup/resource card"),
		assert_true(bool(strategy.call("_deck_action_ref_enables_attack", {"type": "evolve", "card": "Gardevoir ex"})), "Gardevoir ex evolve refs should be attack-enabling setup"),
		assert_true(bool(strategy.call("_deck_action_ref_enables_attack", {"type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"})), "Psychic Embrace refs should be attack-enabling setup"),
	])


func test_gardevoir_llm_discard_protection_preserves_core_evolution_piece() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var kirlia_slot := _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts", "", [{"name": "Refinement", "text": "Discard a card and draw cards."}]), 0)
	player.bench.append(kirlia_slot)
	var gardevoir := CardInstance.create(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	_inject_llm_queue(strategy, 3, [
		{"type": "use_ability", "pokemon": "Kirlia", "interactions": {"discard_cards": {"prefer": ["Gardevoir ex"]}}},
	])
	var picked: Array = strategy.call("pick_interaction_items", [gardevoir, psychic, iono], {"id": "discard_cards", "max_select": 1}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": kirlia_slot.get_top_card(),
	})
	var core_score: float = float(strategy.call("score_interaction_target", gardevoir, {"id": "discard_cards"}, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": kirlia_slot.get_top_card(),
	}))
	return run_checks([
		assert_eq(picked.size(), 1, "Discard protection should still choose exactly one discard"),
		assert_true(picked[0] == psychic, "Discard protection should replace a planned Gardevoir ex discard with Psychic Energy fuel"),
		assert_true(core_score <= -1000.0, "Protected Gardevoir ex should not receive a dominant LLM discard score"),
	])


func test_gardevoir_llm_discard_protection_preserves_psychic_for_tm_bridge() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(20)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	player.hand.append(CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0))
	_inject_llm_tree(strategy, 20, {
		"actions": [{
			"type": "play_trainer",
			"card": "Ultra Ball",
			"interactions": {"discard_cards": {"prefer": ["Psychic Energy"]}},
		}],
	})
	var protected_score: float = float(strategy.call("score_interaction_target", psychic, {"id": "discard_cards"}, {
		"game_state": gs,
		"player_index": 0,
	}))
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", psychic.card_data, gs, 0)), "Psychic Energy should be marked route-critical for the active TM Evolution attack bridge"),
		assert_true(protected_score <= -1000.0, "Bridge-critical Psychic Energy should be protected from Ultra Ball-style discard scoring"),
	])


func test_gardevoir_llm_psychic_embrace_assignment_intent_controls_real_steps() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var gardevoir_slot := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"}]), 0)
	player.active_pokemon = gardevoir_slot
	player.bench.append(drifloon_slot)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	_inject_llm_tree(strategy, 4, {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [{
				"type": "use_ability",
				"pokemon": "Gardevoir ex",
				"interactions": {
					"psychic_embrace_assignments": {"prefer": ["Psychic Energy", "Drifloon"]},
				},
			}],
		}],
	})
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": gardevoir_slot.get_top_card(),
	}
	var picked_energy: Array = strategy.call("pick_interaction_items", [psychic], {"id": "embrace_energy", "max_select": 1}, context)
	var drifloon_score: float = float(strategy.call("score_interaction_target", drifloon_slot, {"id": "embrace_target"}, context))
	var gardevoir_score: float = float(strategy.call("score_interaction_target", gardevoir_slot, {"id": "embrace_target"}, context))
	return run_checks([
		assert_eq(picked_energy.size(), 1, "Psychic Embrace alias should select the real embrace_energy source"),
		assert_true(picked_energy[0] == psychic, "Psychic Embrace alias should pick Psychic Energy"),
		assert_true(drifloon_score > gardevoir_score, "Psychic Embrace alias should prefer the requested Drifloon target"),
		assert_true(drifloon_score >= 90000.0, "Requested Psychic Embrace target should receive a dominant score"),
	])


func test_gardevoir_llm_retreat_block_hook_handles_gardevoir_active() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var manaphy_slot := _make_slot(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	player.bench.append(manaphy_slot)
	player.bench.append(drifloon_slot)
	var bad_retreat := {"kind": "retreat", "bench_target": manaphy_slot}
	var useful_retreat := {"kind": "retreat", "bench_target": drifloon_slot}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_retreat, gs, 0)), "Gardevoir ex should not retreat into a passive support target"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, useful_retreat, gs, 0)), "Gardevoir ex may retreat into a real attacker"),
	])


func test_gardevoir_llm_retreat_block_hook_preserves_core_setup_targets() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var ralts_slot := _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var kirlia_slot := _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	var manaphy_slot := _make_slot(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	player.bench.append(ralts_slot)
	player.bench.append(kirlia_slot)
	player.bench.append(drifloon_slot)
	player.bench.append(manaphy_slot)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	var attacker_to_seed := {"kind": "retreat", "bench_target": ralts_slot}
	var attacker_to_attacker := {"kind": "retreat", "bench_target": drifloon_slot}
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var seed_to_kirlia := {"kind": "retreat", "bench_target": kirlia_slot}
	var seed_to_attacker := {"kind": "retreat", "bench_target": drifloon_slot}
	player.active_pokemon = _make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var support_to_kirlia := {"kind": "retreat", "bench_target": kirlia_slot}
	var support_to_manaphy := {"kind": "retreat", "bench_target": manaphy_slot}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attacker_to_seed, gs, 0)), "Scream Tail should not retreat into a core Ralts setup seed"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attacker_to_attacker, gs, 0)), "Scream Tail may retreat into a real attacker"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, seed_to_kirlia, gs, 0)), "Active Ralts should not burn a retreat into Kirlia setup core"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, seed_to_attacker, gs, 0)), "Active Ralts may retreat into a real attacker"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, support_to_kirlia, gs, 0)), "Support attackers should not retreat into Kirlia setup core"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, support_to_manaphy, gs, 0)), "Support attackers should not retreat into passive Manaphy"),
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", attacker_to_seed, gs, 0)), "Bad retreat should not replace a queued end_turn"),
	])


func test_gardevoir_llm_tool_attach_block_hook_handles_serialized_target_dict() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(5)
	var tm_evolution := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var bravery_charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	var bad_tm_to_greninja := {"kind": "attach_tool", "card": tm_evolution, "target": {"name_en": "Radiant Greninja"}}
	var good_tm_to_ralts := {"kind": "attach_tool", "card": tm_evolution, "target": {"name_en": "Ralts"}}
	var bad_charm_to_ralts := {"kind": "attach_tool", "card": bravery_charm, "target": {"name_en": "Ralts"}}
	var good_charm_to_scream_tail := {"kind": "attach_tool", "card": bravery_charm, "target": {"name_en": "Scream Tail"}}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_tm_to_greninja, gs, 0)), "TM Evolution should not attach to Radiant Greninja when only serialized target data is present"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_tm_to_ralts, gs, 0)), "TM Evolution may attach to Ralts for the evolution attack route"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_charm_to_ralts, gs, 0)), "Bravery Charm should not attach to Ralts setup core"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_charm_to_scream_tail, gs, 0)), "Bravery Charm may attach to a Gardevoir attacker"),
	])


func test_gardevoir_llm_blocks_tm_evolution_to_known_bench_target() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	var active_klefki := _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	var bench_ralts := _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.active_pokemon = active_klefki
	player.bench.append(bench_ralts)
	var tm_evolution := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var tm_to_bench := {"kind": "attach_tool", "card": tm_evolution, "target_slot": bench_ralts}
	var tm_to_active := {"kind": "attach_tool", "card": tm_evolution, "target_slot": active_klefki}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_to_bench, gs, 0)), "Strong opening TM Evolution should not attach to a known bench Ralts when the active carrier needs to attack"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_to_active, gs, 0)), "Strong opening TM Evolution may attach to the active Klefki carrier"),
	])


func test_gardevoir_llm_manual_attach_block_preserves_energy_without_tm_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(5)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var darkness := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var bad_psychic_to_kirlia := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Kirlia"}}
	var bad_darkness_to_ralts := {"kind": "attach_energy", "card": darkness, "target": {"name_en": "Ralts"}}
	var bad_psychic_to_manaphy := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Manaphy"}}
	var good_psychic_to_scream_tail := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Scream Tail"}}
	var tm_route_psychic_to_ralts := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Ralts"}}
	var tm_queue: Array[Dictionary] = [{"kind": "attach_tool", "card": "Technical Machine: Evolution", "target": "Ralts"}]
	strategy.set("_llm_action_queue", tm_queue)
	var tm_route_allowed := not bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_route_psychic_to_ralts, gs, 0))
	var tm_attack_queue: Array[Dictionary] = [{"kind": "granted_attack", "card": "Technical Machine: Evolution", "attack_name": "Evolution"}]
	strategy.set("_llm_action_queue", tm_attack_queue)
	var tm_attack_route_allowed := not bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_route_psychic_to_ralts, gs, 0))
	var empty_queue: Array[Dictionary] = []
	strategy.set("_llm_action_queue", empty_queue)
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_psychic_to_kirlia, gs, 0)), "Psychic Energy should not be manually attached to Kirlia without a TM Evolution route"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_darkness_to_ralts, gs, 0)), "Darkness Energy should not be manually attached to Ralts without a TM Evolution route"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_psychic_to_manaphy, gs, 0)), "Psychic Energy should not be manually attached to passive Manaphy"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_psychic_to_scream_tail, gs, 0)), "Psychic Energy may be manually attached to a real Gardevoir attacker"),
		assert_true(tm_route_allowed, "Manual attach to Ralts should remain legal when the active queue has a TM Evolution route"),
		assert_true(tm_attack_route_allowed, "Manual attach to Ralts should remain legal when the queue is already on the TM Evolution granted attack"),
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", bad_psychic_to_kirlia, gs, 0)), "Bad manual attach should not replace a queued end_turn"),
	])


func test_gardevoir_llm_blocks_manual_attach_to_known_bench_tm_carrier() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(19)
	var player := gs.players[0]
	var active_klefki := _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	var bench_ralts := _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var tm_evolution := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var active_tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	bench_ralts.attached_tool = tm_evolution
	active_klefki.attached_tool = active_tm
	player.active_pokemon = active_klefki
	player.bench.append(bench_ralts)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var psychic_to_bench := {"kind": "attach_energy", "card": psychic, "target_slot": bench_ralts}
	var psychic_to_active := {"kind": "attach_energy", "card": psychic, "target_slot": active_klefki}
	strategy.set("_llm_action_queue", [{"kind": "attach_tool", "card": "Technical Machine: Evolution", "target": "Ralts"}])
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, psychic_to_bench, gs, 0)), "Strong opening should not spend the manual Psychic attach on a bench TM carrier that cannot attack"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, psychic_to_active, gs, 0)), "Strong opening should allow Psychic attach to the active TM carrier"),
	])


func test_gardevoir_llm_deck_repair_prunes_dead_gust_without_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(7)
	var dead_gust_tree := {
		"actions": [
			{"id": "play_trainer:c1", "type": "play_trainer", "card": "Boss's Orders"},
			{"id": "end_turn", "type": "end_turn"},
		],
	}
	var attack_gust_tree := {
		"actions": [
			{"id": "play_trainer:c1", "type": "play_trainer", "card": "Boss's Orders"},
			{"id": "attack:0", "type": "attack", "attack_name": "Balloon Bomb"},
		],
	}
	var repaired_dead: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", dead_gust_tree, gs, 0)
	var repaired_attack: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", attack_gust_tree, gs, 0)
	var dead_ids := _action_ids(repaired_dead.get("actions", []))
	var attack_ids := _action_ids(repaired_attack.get("actions", []))
	return run_checks([
		assert_false(dead_ids.has("play_trainer:c1"), "Boss's Orders without a same-turn attack should be pruned"),
		assert_true(dead_ids.has("end_turn"), "Dead-gust pruning should preserve terminal fallback"),
		assert_true(attack_ids.has("play_trainer:c1"), "Boss's Orders should remain legal when the route attacks after gust"),
	])


func test_gardevoir_llm_deck_repair_inserts_attacker_conversion_before_end() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var catalog := {
		"play_basic_to_bench:c10": {"id": "play_basic_to_bench:c10", "type": "play_basic_to_bench", "card": "Scream Tail"},
		"use_ability:gardevoir": {"id": "use_ability:gardevoir", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	var tree := {"actions": [{"id": "end_turn", "type": "end_turn"}]}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", tree, gs, 0)
	var actions: Array = repaired.get("actions", [])
	var ids := _action_ids(actions)
	return run_checks([
		assert_true(ids.has("play_basic_to_bench:c10"), "Engine-online route with no attacker should insert a visible attacker bench action"),
		assert_true(ids.find("play_basic_to_bench:c10") < ids.find("end_turn"), "Attacker conversion should happen before end_turn"),
		assert_true(ids.has("use_ability:gardevoir"), "Psychic Embrace should be exposed after attacker conversion when legal"),
	])


func test_gardevoir_llm_deck_repair_charges_existing_attacker_before_end() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var catalog := {
		"use_ability:gardevoir": {"id": "use_ability:gardevoir", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
		"attach_energy:c20:bench_0": {"id": "attach_energy:c20:bench_0", "type": "attach_energy", "card": "Psychic Energy", "target": "Drifloon"},
		"attach_tool:c21:bench_0": {"id": "attach_tool:c21:bench_0", "type": "attach_tool", "card": "Bravery Charm", "target": "Drifloon"},
		"play_basic_to_bench:c22": {"id": "play_basic_to_bench:c22", "type": "play_basic_to_bench", "card": "Ralts"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	var tree := {"actions": [{"id": "end_turn", "type": "end_turn"}]}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", tree, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("use_ability:gardevoir"), "Existing unready Drifloon should trigger Psychic Embrace before ending"),
		assert_true(ids.find("use_ability:gardevoir") < ids.find("end_turn"), "Psychic Embrace should be before end_turn"),
		assert_false(ids.has("play_basic_to_bench:c22") and ids.find("play_basic_to_bench:c22") < ids.find("use_ability:gardevoir"), "Charging an existing attacker should outrank extra Ralts bench padding"),
	])


func test_gardevoir_llm_productive_candidates_prioritize_attackers_after_engine_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var catalog := {
		"play_basic_to_bench:c10": {"id": "play_basic_to_bench:c10", "type": "play_basic_to_bench", "card": "Drifloon"},
		"play_trainer:c11": {"id": "play_trainer:c11", "type": "play_trainer", "card": "Buddy-Buddy Poffin"},
		"evolve:c12": {"id": "evolve:c12", "type": "evolve", "card": "Gardevoir ex"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	var target: Array[Dictionary] = []
	var seen: Dictionary = {}
	var route_actions: Array[Dictionary] = [{"id": "evolve:c12", "type": "evolve", "card": "Gardevoir ex"}]
	strategy.call("_deck_append_productive_engine_candidates", target, seen, route_actions, false, false)
	var ids := _action_ids(target)
	var first_id := ids[0] if ids.size() > 0 else ""
	return run_checks([
		assert_true(ids.size() >= 2, "Engine conversion candidate list should include multiple followups"),
		assert_eq(first_id, "play_basic_to_bench:c10", "Attacker bench should outrank generic setup after a Gardevoir ex route"),
		assert_true(ids.has("play_trainer:c11"), "Search setup should remain available after the attacker conversion candidate"),
	])


func test_gardevoir_llm_search_fallback_prioritizes_first_attacker_after_engine_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var ralts := CardInstance.create(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var drifloon := CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	var manaphy := CardInstance.create(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	_inject_llm_tree(strategy, 14, {
		"actions": [{
			"type": "play_trainer",
			"card": "Buddy-Buddy Poffin",
			"interactions": {"search_targets": {"prefer": ["Ralts"]}},
		}],
	})
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", [ralts, drifloon, manaphy], {"id": "search_targets", "max_select": 1}, context)
	var drifloon_score: float = float(strategy.call("score_interaction_target", drifloon, {"id": "search_targets"}, context))
	var ralts_score: float = float(strategy.call("score_interaction_target", ralts, {"id": "search_targets"}, context))
	var manaphy_score: float = float(strategy.call("score_interaction_target", manaphy, {"id": "search_targets"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Engine-online search fallback should still choose one Basic"),
		assert_true(picked[0] == drifloon, "Engine-online Poffin/Nest interaction should override a passive/core plan and take the first Drifloon"),
		assert_true(drifloon_score > ralts_score, "Drifloon should outrank extra Ralts when Gardevoir ex is online and no attacker exists"),
		assert_true(manaphy_score < 0.0, "Passive Manaphy should be demoted in the same post-engine search spot"),
	])


func test_gardevoir_llm_search_fallback_prioritizes_gardevoir_ex_when_kirlia_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(23)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var gardevoir := CardInstance.create(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var ralts := CardInstance.create(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var kirlia := CardInstance.create(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	_inject_llm_tree(strategy, 23, {
		"actions": [{
			"type": "play_trainer",
			"card": "Ultra Ball",
			"interactions": {"search_targets": {"prefer": ["Ralts"]}},
		}],
	})
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", [ralts, kirlia, gardevoir], {"id": "search_targets", "max_select": 1}, context)
	var gardevoir_score: float = float(strategy.call("score_interaction_target", gardevoir, {"id": "search_targets"}, context))
	var ralts_score: float = float(strategy.call("score_interaction_target", ralts, {"id": "search_targets"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Search fallback should still pick one Pokemon"),
		assert_true(picked[0] == gardevoir, "When Kirlia exists and Gardevoir ex is missing, search should complete the Stage 2 engine instead of taking extra Ralts"),
		assert_true(gardevoir_score > ralts_score, "Gardevoir ex should outrank extra Ralts after Kirlia is established"),
	])


func test_gardevoir_llm_arven_item_search_prefers_vessel_for_tm_bridge_without_psychic() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(16)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)
	player.hand.append(arven)
	player.deck.append(CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item"), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	_inject_llm_tree(strategy, 16, {
		"actions": [{
			"type": "play_trainer",
			"card": "Arven",
			"interactions": {
				"search_item": {"prefer": ["Ultra Ball"]},
				"search_tool": {"prefer": ["Technical Machine: Evolution"]},
			},
		}],
	})
	var context := {
		"game_state": gs,
		"player_index": 0,
		"all_items": [ultra_ball, vessel, nest_ball],
		"pending_effect_kind": "trainer",
		"pending_effect_card": arven,
	}
	var picked: Array = strategy.call("pick_interaction_items", [ultra_ball, vessel, nest_ball], {"id": "search_item", "max_select": 1}, context)
	var picked_card: Variant = picked[0] if picked.size() > 0 else null
	var vessel_score: float = float(strategy.call("score_interaction_target", vessel, {"id": "search_item"}, context))
	var ultra_score: float = float(strategy.call("score_interaction_target", ultra_ball, {"id": "search_item"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Arven item search should still choose exactly one Item"),
		assert_true(picked_card == vessel, "TM Evolution bridge with no Psychic in hand should override a planned Ultra Ball and take Earthen Vessel"),
		assert_true(vessel_score > ultra_score, "Earthen Vessel should outrank Ultra Ball only in the missing-energy TM Evolution bridge"),
	])


func test_gardevoir_llm_arven_item_search_preserves_psychic_by_taking_vessel_even_when_psychic_in_hand() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(17)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)
	player.hand.append(arven)
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0))
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item"), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	_inject_llm_tree(strategy, 17, {
		"actions": [{
			"type": "play_trainer",
			"card": "Arven",
			"interactions": {
				"search_item": {"prefer": ["Ultra Ball"]},
				"search_tool": {"prefer": ["Technical Machine: Evolution"]},
			},
		}],
	})
	var context := {
		"game_state": gs,
		"player_index": 0,
		"all_items": [ultra_ball, vessel],
		"pending_effect_kind": "trainer",
		"pending_effect_card": arven,
	}
	var picked: Array = strategy.call("pick_interaction_items", [ultra_ball, vessel], {"id": "search_item", "max_select": 1}, context)
	var picked_card: Variant = picked[0] if picked.size() > 0 else null
	var vessel_score: float = float(strategy.call("score_interaction_target", vessel, {"id": "search_item"}, context))
	var ultra_score: float = float(strategy.call("score_interaction_target", ultra_ball, {"id": "search_item"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Arven item search should still choose one Item for the TM bridge"),
		assert_true(picked_card == vessel, "Strong TM bridge should take Earthen Vessel to preserve the hand Psychic instead of opening Ultra Ball discard risk"),
		assert_true(vessel_score > ultra_score, "Earthen Vessel should outrank Ultra Ball while the active TM carrier still needs a guaranteed Psychic attach"),
	])


func test_gardevoir_llm_blocks_passive_support_bench_until_core_redundancy() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(15)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var manaphy_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)}
	var greninja_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 0)}
	var ralts_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)}
	var drifloon_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, manaphy_action, gs, 0)), "Manaphy bench should be blocked while only one Ralts/Kirlia seed exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, greninja_action, gs, 0)), "Radiant Greninja bench should be blocked before core redundancy"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, ralts_action, gs, 0)), "Second Ralts bench should remain legal"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, drifloon_action, gs, 0)), "First real attacker bench should remain legal"),
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", manaphy_action, gs, 0)), "Passive support bench should not replace a queued end_turn in fixed-opening pressure"),
	])


func test_gardevoir_llm_productive_candidates_charge_existing_attacker_when_engine_already_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var catalog := {
		"use_ability:gardevoir": {"id": "use_ability:gardevoir", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
		"attach_energy:c20:bench_0": {"id": "attach_energy:c20:bench_0", "type": "attach_energy", "card": "Psychic Energy", "target": "Drifloon"},
		"play_basic_to_bench:c21": {"id": "play_basic_to_bench:c21", "type": "play_basic_to_bench", "card": "Ralts"},
		"play_trainer:c22": {"id": "play_trainer:c22", "type": "play_trainer", "card": "Buddy-Buddy Poffin"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	strategy.set("_last_gardevoir_engine_online", true)
	strategy.set("_last_gardevoir_attacker_count", 1)
	strategy.set("_last_gardevoir_ready_attacker_count", 0)
	var target: Array[Dictionary] = []
	var route_actions: Array[Dictionary] = []
	strategy.call("_deck_append_productive_engine_candidates", target, {}, route_actions, false, false)
	var ids := _action_ids(target)
	return run_checks([
		assert_true(ids.size() >= 3, "Engine-online unready attacker route should expose charge and normal setup candidates"),
		assert_eq(ids[0], "use_ability:gardevoir", "Psychic Embrace should be the first productive candidate for an existing unready attacker"),
		assert_true(ids.find("attach_energy:c20:bench_0") < ids.find("play_basic_to_bench:c21"), "Manual attach to the attacker should outrank extra Ralts padding in this state"),
	])


func test_gardevoir_llm_blocks_low_value_core_attack_when_setup_remains() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	var catalog := {
		"play_trainer:c30": {"id": "play_trainer:c30", "type": "play_trainer", "card": "Buddy-Buddy Poffin"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	var low_attack := {"kind": "attack", "attack_name": "Slap"}
	var blocked_low := bool(strategy.call("_deck_should_block_exact_queue_match", {}, low_attack, gs, 0))
	var attacker_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	player.active_pokemon = attacker_slot
	var attacker_attack := {"kind": "attack", "attack_name": "Balloon Bomb"}
	return run_checks([
		assert_true(blocked_low, "Kirlia's low-value attack should not consume the turn while setup remains visible"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attacker_attack, gs, 0)), "Real Gardevoir attackers should not be blocked by the low-value core attack guard"),
	])


func test_gardevoir_llm_repairs_low_value_core_attack_into_setup_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(21)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70, "", "", [], [{"name": "Teleportation Break", "cost": "P", "damage": "10"}]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	strategy.set("_llm_action_catalog", {
		"attack:0:Teleportation Break": {"id": "attack:0:Teleportation Break", "type": "attack", "attack_name": "Teleportation Break"},
		"evolve:c27:active": {"id": "evolve:c27:active", "type": "evolve", "card": "Kirlia"},
		"play_trainer:c40": {"id": "play_trainer:c40", "type": "play_trainer", "card": "Ultra Ball"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [{"id": "attack:0:Teleportation Break", "type": "attack", "attack_name": "Teleportation Break"}],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_false(ids.has("attack:0:Teleportation Break"), "Low-value Ralts attack should be removed while setup actions remain visible"),
		assert_true(ids.has("evolve:c27:active") or ids.has("play_trainer:c40"), "Repair should replace the low-value attack with an evolution/search setup action"),
	])


func test_gardevoir_llm_psychic_embrace_fallback_rejects_wrong_energy_and_support_target() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(11)
	var player := gs.players[0]
	var gardevoir_slot := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"}]), 0)
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = gardevoir_slot
	player.bench.append(drifloon_slot)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var darkness := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	player.discard_pile.append(psychic)
	_inject_llm_tree(strategy, 11, {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [{
				"type": "use_ability",
				"pokemon": "Gardevoir ex",
				"interactions": {
					"psychic_embrace_assignments": {"prefer": ["Darkness Energy", "Gardevoir ex"]},
				},
			}],
		}],
	})
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": gardevoir_slot.get_top_card(),
		"all_items": [gardevoir_slot, drifloon_slot],
	}
	var picked_energy: Array = strategy.call("pick_interaction_items", [darkness, psychic], {"id": "embrace_energy", "max_select": 1}, context)
	var picked_target: Array = strategy.call("pick_interaction_items", [gardevoir_slot, drifloon_slot], {"id": "embrace_target", "max_select": 1}, context)
	var drifloon_score: float = float(strategy.call("score_interaction_target", drifloon_slot, {"id": "embrace_target"}, context))
	var gardevoir_score: float = float(strategy.call("score_interaction_target", gardevoir_slot, {"id": "embrace_target"}, context))
	return run_checks([
		assert_eq(picked_energy.size(), 1, "Psychic Embrace fallback should still choose one legal energy source"),
		assert_true(picked_energy[0] == psychic, "Psychic Embrace fallback should replace a planned Darkness Energy source with Psychic Energy"),
		assert_eq(picked_target.size(), 1, "Psychic Embrace target fallback should still choose one target"),
		assert_true(picked_target[0] == drifloon_slot, "Psychic Embrace target fallback should replace a planned support target with the real attacker"),
		assert_true(drifloon_score > gardevoir_score, "Psychic Embrace target scoring should override a bad planned Gardevoir ex target when Drifloon can attack"),
		assert_true(gardevoir_score <= -500.0, "Psychic Embrace should reject over-damaging the support Gardevoir ex target"),
	])


func test_gardevoir_llm_blocks_low_value_attack_when_ready_bench_attacker_can_be_handed_off() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts", "", [], [{"name": "Slap", "cost": "", "damage": "30"}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0)
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(drifloon_slot)
	strategy.set("_llm_action_catalog", {
		"retreat:bench_1": {"id": "retreat:bench_1", "type": "retreat", "bench_target": "Drifloon"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var low_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var retreat_to_attacker := {"kind": "retreat", "bench_target": drifloon_slot}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, low_attack, gs, 0)), "Active Kirlia should not take a low-value attack while a ready Drifloon handoff is legal"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "Ready bench attacker handoff should also block premature end_turn"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", retreat_to_attacker, gs, 0)), "Retreating to the ready attacker should be eligible to replace end_turn"),
	])


func test_gardevoir_llm_blocks_attacker_first_attack_when_embrace_can_unlock_payoff() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(22)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	strategy.set("_llm_action_catalog", {
		"attack:0:Slap": {"id": "attack:0:Slap", "type": "attack", "attack_index": 0, "attack_name": "Slap"},
		"attack:1:Roaring Scream": {"id": "attack:1:Roaring Scream", "type": "attack", "attack_index": 1, "attack_name": "Roaring Scream"},
		"use_ability:gardevoir": {"id": "use_ability:gardevoir", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
	})
	var low_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var payoff_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [{"id": "attack:0:Slap", "type": "attack", "attack_index": 0, "attack_name": "Slap"}],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, low_attack, gs, 0)), "Scream Tail should not use Slap when Psychic Embrace can unlock its payoff attack"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, payoff_attack, gs, 0)), "Scream Tail payoff attack should remain legal"),
		assert_true(ids.has("use_ability:gardevoir"), "Repair should convert the first-attack route into Psychic Embrace setup"),
	])


func test_gardevoir_llm_low_deck_productive_candidates_skip_optional_draw_engines() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(13)
	var player := gs.players[0]
	for i: int in 5:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Card %d" % i), 0))
	var catalog := {
		"play_trainer:c1": {"id": "play_trainer:c1", "type": "play_trainer", "card": "Rare Candy"},
		"evolve:c2": {"id": "evolve:c2", "type": "evolve", "card": "Gardevoir ex"},
		"use_ability:kirlia": {"id": "use_ability:kirlia", "type": "use_ability", "pokemon": "Kirlia", "ability": "Refinement"},
		"use_ability:greninja": {"id": "use_ability:greninja", "type": "use_ability", "pokemon": "Radiant Greninja", "ability": "Concealed Cards"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	var locked_target: Array[Dictionary] = []
	var route_actions: Array[Dictionary] = []
	strategy.call("_deck_append_productive_engine_candidates", locked_target, {}, route_actions, false, true)
	var locked_ids := _action_ids(locked_target)
	var open_target: Array[Dictionary] = []
	strategy.call("_deck_append_productive_engine_candidates", open_target, {}, route_actions, false, false)
	var open_ids := _action_ids(open_target)
	var kirlia_draw := {"kind": "use_ability", "pokemon": "Kirlia", "ability": "Refinement"}
	var gardevoir_embrace := {"kind": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"}
	return run_checks([
		assert_true(locked_ids.has("play_trainer:c1"), "Low-deck lock should still allow non-draw Rare Candy setup"),
		assert_true(locked_ids.has("evolve:c2"), "Low-deck lock should still allow Stage 2 evolution setup"),
		assert_false(locked_ids.has("use_ability:kirlia"), "Low-deck lock should not insert Kirlia discard-draw before terminal actions"),
		assert_false(locked_ids.has("use_ability:greninja"), "Low-deck lock should not insert Radiant Greninja discard-draw before terminal actions"),
		assert_true(open_ids.has("use_ability:kirlia"), "Kirlia draw should remain a productive candidate when deck count is safe"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, kirlia_draw, gs, 0)), "Low-deck exact queue guard should block Kirlia draw even if it appears in a queue"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, gardevoir_embrace, gs, 0)), "Low-deck guard should not block Psychic Embrace acceleration"),
	])
