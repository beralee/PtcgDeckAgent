class_name TestGardevoirLLM
extends TestBase

const RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGardevoir.gd"
const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyGardevoirLLM.gd"
const RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")


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
			ids.append(str(action.get("id", action.get("action_id", action.get("legal_action_id", "")))))
	return ids


func _card_names(cards: Array) -> Array[String]:
	var names: Array[String] = []
	for raw_card: Variant in cards:
		if raw_card is CardInstance and (raw_card as CardInstance).card_data != null:
			names.append(str((raw_card as CardInstance).card_data.name_en))
	return names


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


func test_gardevoir_llm_builder_exposes_scream_tail_scaling_attack() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_game_state(8)
	gsm.game_state.current_player_index = 0
	var player: PlayerState = gsm.game_state.players[0]
	var scream_tail_cd := _make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"cost": "P", "damage": "30", "name": "Slap", "text": ""},
		{"cost": "PC", "damage": "", "name": "Roaring Scream", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	])
	scream_tail_cd.effect_id = "12c9416c64d1a8cfbbf0a3000a9f3d50"
	player.active_pokemon = _make_slot(scream_tail_cd, 0)
	player.active_pokemon.damage_counters = 40
	player.active_pokemon.attached_energy = [
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
	]
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	var builder = AILegalActionBuilderScript.new()
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	var has_scaling_attack := false
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "attack" and int(action.get("attack_index", -1)) == 1:
			has_scaling_attack = true
			break
	return assert_true(has_scaling_attack, "Scream Tail's scaling second attack should be legal with Psychic+Colorless paid by two Psychic Energy")


func test_gardevoir_llm_position_match_survives_same_slot_evolution() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0))
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var runtime_attach := {"kind": "attach_tool", "card": tm, "target_slot": player.bench[0]}
	var queued_attach := {"type": "attach_tool", "card": "Technical Machine: Evolution", "position": "bench_0", "target": "Ralts"}
	var wrong_position := queued_attach.duplicate(true)
	wrong_position["position"] = "bench_1"
	var runtime_retreat := {"kind": "retreat", "bench_index": 0, "bench_target": player.bench[0]}
	var runtime_retreat_without_index := {"kind": "retreat", "bench_target": player.bench[0]}
	var queued_retreat := {"type": "retreat", "bench_position": "bench_0", "bench_target": "Ralts"}
	return run_checks([
		assert_true(bool(strategy.call("_match_card_and_target", queued_attach, runtime_attach, gs, 0)), "Position should stay authoritative when the same bench slot evolved after planning"),
		assert_false(bool(strategy.call("_match_card_and_target", wrong_position, runtime_attach, gs, 0)), "Wrong bench position should still fail even if the old target name is stale"),
		assert_true(bool(strategy.call("_match_retreat", queued_retreat, runtime_retreat, gs, 0)), "Retreat matching should accept evolved same-slot targets by position"),
		assert_true(bool(strategy.call("_match_retreat", queued_retreat, runtime_retreat_without_index, gs, 0)), "Retreat matching should resolve bench_target slots when runtime action omits bench_index"),
	])


func test_gardevoir_llm_replans_after_evolution_changes_action_surface() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var before := {
		"turn": 4,
		"phase": int(GameState.GamePhase.MAIN),
		"player_index": 0,
		"current_player_index": 0,
		"hand_ids": ["c1", "c2"],
		"hand_count": 2,
		"deck_count": 40,
		"discard_count": 0,
		"active_name": "Ralts",
		"bench_names": ["Ralts"],
	}
	var after := before.duplicate(true)
	after["active_name"] = "Kirlia"
	var evolve_trigger: Dictionary = strategy.call("_llm_replan_trigger", before, after, {
		"success": true,
		"action_kind": "evolve",
		"step_kind": "main_action",
	})
	var attach_trigger: Dictionary = strategy.call("_llm_replan_trigger", before, after, {
		"success": true,
		"action_kind": "attach_energy",
		"step_kind": "main_action",
	})
	return run_checks([
		assert_true(bool(evolve_trigger.get("should_replan", false)), "Evolution should trigger a replan because it can unlock new abilities or attacks"),
		assert_eq(str(evolve_trigger.get("reason", "")), "evolution_changed_action_surface", "Evolution replan reason should be explicit"),
		assert_false(bool(attach_trigger.get("should_replan", false)), "Non-evolution board snapshots should not use the evolution replan path"),
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


func test_gardevoir_llm_discard_protection_preserves_bravery_charm_for_first_attacker_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(21)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var bravery := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var picked: Array = strategy.call("_protect_gardevoir_discard_picks", [bravery], [bravery, iono, boss], {"id": "discard_cards", "max_select": 1}, {
		"game_state": gs,
		"player_index": 0,
	})
	var first_pick: Variant = picked[0] if picked.size() > 0 else null
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", bravery.card_data, gs, 0)), "Bravery Charm should be protected once Kirlia can convert into a self-damage attacker route"),
		assert_true(first_pick != bravery, "Discard bridge should not spend the only Bravery Charm needed for Drifloon/Scream Tail prize math"),
	])


func test_gardevoir_llm_discard_protection_preserves_bravery_charm_even_with_two_attackers() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(42)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 50)
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 59)
	var picked: Array = strategy.call("_protect_gardevoir_discard_picks", [charm], [charm, poffin], {"id": "discard_cards", "max_select": 1}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", charm.card_data, gs, 0)), "Bravery Charm should remain protected while scaling Gardevoir attackers are live, even with two attacker bodies"),
		assert_eq(picked[0] if picked.size() > 0 else null, poffin, "Discard bridge should replace Bravery Charm with a less route-critical card"),
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
	var full_hp_retreat_blocked := bool(strategy.call("_deck_should_block_exact_queue_match", {}, useful_retreat, gs, 0))
	player.active_pokemon.damage_counters = 220
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_retreat, gs, 0)), "Gardevoir ex should not retreat into a passive support target"),
		assert_true(full_hp_retreat_blocked, "Full-HP Gardevoir ex should not retreat into an unready attacker"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, useful_retreat, gs, 0)), "Heavily damaged Gardevoir ex may retreat into a real attacker to preserve the engine"),
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
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attacker_to_attacker, gs, 0)), "Scream Tail should not retreat into another unready attacker"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, seed_to_kirlia, gs, 0)), "Active Ralts should not burn a retreat into Kirlia setup core"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, seed_to_attacker, gs, 0)), "Active Ralts should not retreat into an unready attacker before same-turn conversion is available"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, support_to_kirlia, gs, 0)), "Support attackers should not retreat into Kirlia setup core"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, support_to_manaphy, gs, 0)), "Support attackers should not retreat into passive Manaphy"),
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", attacker_to_seed, gs, 0)), "Bad retreat should not replace a queued end_turn"),
	])


func test_gardevoir_llm_tm_evolution_bridge_blocks_non_pressure_retreat() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(26)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var kirlia_slot := _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	player.bench.append(kirlia_slot)
	player.bench.append(drifloon_slot)
	var runtime_retreat := {"kind": "retreat", "bench_target": drifloon_slot}
	var payload_retreat := {"id": "retreat:bench_1", "type": "retreat", "bench_position": "bench_1", "bench_target_name_en": "Drifloon"}
	var blocked_runtime := bool(strategy.call("_deck_should_block_exact_queue_match", {}, runtime_retreat, gs, 0))
	var blocked_payload := bool(strategy.call("_is_bad_gardevoir_retreat_ref", payload_retreat, gs, 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.damage_counters = 40
	var pressure_runtime := bool(strategy.call("_deck_should_block_exact_queue_match", {}, runtime_retreat, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_has_tm_evolution_bench_target", player)), "TM Evolution bridge should recognize benched Kirlia as a valid evolution target"),
		assert_true(blocked_runtime, "Active TM Evolution bridge should block retreating into an uncharged Drifloon"),
		assert_true(blocked_payload, "Payload filtering should hide the same uncharged retreat before prompt selection"),
		assert_false(pressure_runtime, "A pressure-ready bench attacker may still receive a handoff retreat"),
	])


func test_gardevoir_llm_tm_evolution_bridge_preserves_manual_psychic_for_active() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(27)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0))
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	player.bench.append(drifloon_slot)
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var attach_active := {"kind": "attach_energy", "card": psychic, "target": player.active_pokemon}
	var attach_attacker := {"kind": "attach_energy", "card": psychic, "target": drifloon_slot}
	var payload_active := {"id": "attach_energy:c13:active", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "P", "target_position": "active"}
	var payload_attacker := {"id": "attach_energy:c13:bench_1", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "P", "target_position": "bench_1"}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attach_active, gs, 0)), "Manual Psychic attach to the active TM Evolution carrier should remain executable"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", attach_active, gs, 0)), "Active TM Evolution bridge attach should be allowed to replace stale end_turn"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attach_attacker, gs, 0)), "Manual Psychic attach to a bench attacker should be blocked while the active TM Evolution bridge is unpowered"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_manual_attach_ref", payload_active, gs, 0)), "Prompt payload should keep the active TM bridge attach visible"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_manual_attach_ref", payload_attacker, gs, 0)), "Prompt payload should hide off-bridge attacker attach in this exact bridge window"),
	])


func test_gardevoir_llm_blocks_tm_evolution_on_unpowered_support_without_psychic_fuel() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(29)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var tm := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var runtime_tool := {"kind": "attach_tool", "type": "attach_tool", "card": tm, "target": player.active_pokemon}
	return run_checks([
		assert_eq(player.active_pokemon.attached_energy.size(), 0, "Regression state should keep active Munkidori unpowered"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, runtime_tool, gs, 0)), "Do not attach TM Evolution to an unpowered active support Pokemon when it cannot be paid this turn"),
	])


func test_gardevoir_llm_active_retreat_bridge_preserves_manual_psychic_for_active() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(28)
	var player := gs.players[0]
	var kirlia_cd := _make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts")
	kirlia_cd.retreat_cost = 2
	player.active_pokemon = _make_slot(kirlia_cd, 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(drifloon_slot)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var attach_active := {"kind": "attach_energy", "card": psychic, "target": player.active_pokemon}
	var attach_attacker := {"kind": "attach_energy", "card": psychic, "target": drifloon_slot}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attach_active, gs, 0)), "Manual Psychic attach to active Kirlia should be legal when it preserves discard fuel for a retreat bridge"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", attach_active, gs, 0)), "Active retreat bridge attach should be a productive replacement for stale end_turn"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attach_attacker, gs, 0)), "Manual Psychic attach to the bench attacker should wait until active retreat cost is covered"),
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


func test_gardevoir_llm_bravery_charm_blocks_core_targets_from_serialized_actions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 50)
	var bad_to_gardevoir_name := {"kind": "attach_tool", "card": charm, "target_name_en": "Gardevoir ex"}
	var bad_to_gardevoir_localized := {"kind": "attach_tool", "card": charm, "target": "沙奈朵ex"}
	var bad_to_active_position := {"kind": "attach_tool", "card": charm, "position": "active"}
	var bad_unknown_target := {"kind": "attach_tool", "card": charm}
	var good_to_bench_position := {"kind": "attach_tool", "card": charm, "position": "bench_0"}
	var payload_bad_to_gardevoir := {"type": "attach_tool", "card": "Bravery Charm", "target_name_en": "Gardevoir ex"}
	var payload_good_to_scream_tail := {"type": "attach_tool", "card": "Bravery Charm", "position": "bench_0"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_to_gardevoir_name, gs, 0)), "Bravery Charm must not attach to Gardevoir ex when target_name_en is serialized"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_to_gardevoir_localized, gs, 0)), "Bravery Charm must not attach to localized Gardevoir ex target names"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_to_active_position, gs, 0)), "Bravery Charm must not attach to active Gardevoir ex through a position-only action"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_unknown_target, gs, 0)), "Unknown Bravery Charm targets should be blocked rather than guessed safe"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_to_bench_position, gs, 0)), "Position-only Bravery Charm remains legal for a bench Scream Tail"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", payload_bad_to_gardevoir, gs, 0)), "Prompt payload should hide Bravery Charm to Gardevoir ex"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", payload_good_to_scream_tail, gs, 0)), "Prompt payload should keep Bravery Charm to Scream Tail"),
	])


func test_gardevoir_llm_bravery_charm_prefers_current_active_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(45)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0))
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	var charm_to_active := {"kind": "attach_tool", "card": charm, "target_slot": player.active_pokemon}
	var charm_to_bench := {"kind": "attach_tool", "card": charm, "target_slot": player.bench[0]}
	var ref_to_active := {"id": "attach_tool:c50:active", "type": "attach_tool", "card": "Bravery Charm", "target": "Drifloon", "position": "active"}
	var ref_to_bench := {"id": "attach_tool:c50:bench_0", "type": "attach_tool", "card": "Bravery Charm", "target": "Scream Tail", "position": "bench_0"}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, charm_to_active, gs, 0)), "Current active Drifloon should receive Bravery Charm before a benched backup attacker"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, charm_to_bench, gs, 0)), "Do not route Bravery Charm to bench while the active scaling attacker lacks one"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", ref_to_active, gs, 0)), "Payload should keep active-attacker Bravery Charm visible"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", ref_to_bench, gs, 0)), "Payload should hide bench Bravery Charm when the active scaling attacker needs it"),
	])


func test_gardevoir_llm_bravery_charm_prefers_drifloon_over_scream_tail_backup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(46)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0)
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.bench.append(drifloon)
	player.bench.append(scream_tail)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0))
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	var charm_to_drifloon := {"kind": "attach_tool", "card": charm, "target_slot": drifloon}
	var charm_to_scream_tail := {"kind": "attach_tool", "card": charm, "target_slot": scream_tail}
	var ref_to_drifloon := {"id": "attach_tool:c50:bench_0", "type": "attach_tool", "card": "Bravery Charm", "target": "Drifloon", "position": "bench_0"}
	var ref_to_scream_tail := {"id": "attach_tool:c50:bench_1", "type": "attach_tool", "card": "Bravery Charm", "target": "Scream Tail", "position": "bench_1"}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, charm_to_drifloon, gs, 0)), "When Gardevoir ex is online, the first Bravery Charm should stay available for Drifloon prize math"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, charm_to_scream_tail, gs, 0)), "Do not spend Bravery Charm on Scream Tail while an uncharmed Drifloon backup exists"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", ref_to_drifloon, gs, 0)), "Payload should keep Drifloon Bravery Charm visible"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", ref_to_scream_tail, gs, 0)), "Payload should hide Scream Tail Bravery Charm while Drifloon lacks one"),
	])


func test_gardevoir_llm_blocks_tm_evolution_on_scaling_attackers() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var tm_evolution := CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var attacker_state := _make_game_state(47)
	var attacker_player := attacker_state.players[0]
	attacker_player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	var setup_state := _make_game_state(48)
	var setup_player := setup_state.players[0]
	setup_player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var tm_to_attacker := {"kind": "attach_tool", "card": tm_evolution, "target_slot": attacker_player.active_pokemon}
	var tm_to_ralts := {"kind": "attach_tool", "card": tm_evolution, "target_slot": setup_player.active_pokemon}
	var ref_to_attacker := {"id": "attach_tool:c51:active", "type": "attach_tool", "card": "Technical Machine: Evolution", "target": "Drifloon", "position": "active"}
	var ref_to_ralts := {"id": "attach_tool:c51:active", "type": "attach_tool", "card": "Technical Machine: Evolution", "target": "Ralts", "position": "active"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_to_attacker, attacker_state, 0)), "TM Evolution should not occupy Drifloon/Scream Tail tool slots"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_to_ralts, setup_state, 0)), "TM Evolution should remain legal on a setup carrier like active Ralts"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", ref_to_attacker, attacker_state, 0)), "Payload should hide TM Evolution to Drifloon"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_tool_attach_ref", ref_to_ralts, setup_state, 0)), "Payload should keep TM Evolution to active Ralts"),
	])


func test_gardevoir_llm_prefers_bench_gardevoir_ex_evolution_over_active_kirlia() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(24)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var gardevoir_card := CardInstance.create(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	var evolve_active := {"kind": "evolve", "card": gardevoir_card, "target": player.active_pokemon}
	var evolve_bench := {"kind": "evolve", "card": gardevoir_card, "target": player.bench[0]}
	var ref_active := {"id": "evolve:c45:active", "type": "evolve", "card": "Gardevoir ex", "position": "active", "target": "Kirlia"}
	var ref_bench := {"id": "evolve:c45:bench_0", "type": "evolve", "card": "Gardevoir ex", "position": "bench_0", "target": "Kirlia"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, evolve_active, gs, 0)), "Do not expose active Kirlia as Gardevoir ex while a bench Kirlia can become the engine"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, evolve_bench, gs, 0)), "Bench Kirlia should remain the preferred Gardevoir ex evolution target"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_evolve_ref", ref_active, gs, 0)), "Payload should hide active Gardevoir ex evolution when bench Kirlia exists"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_evolve_ref", ref_bench, gs, 0)), "Payload should keep bench Gardevoir ex evolution visible"),
	])


func test_gardevoir_llm_blocks_second_active_gardevoir_ex_after_bench_engine_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(24)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var gardevoir_card := CardInstance.create(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0)
	var evolve_active := {"kind": "evolve", "card": gardevoir_card, "target": player.active_pokemon}
	var ref_active := {"id": "evolve:c45:active", "type": "evolve", "card": "Gardevoir ex", "position": "active", "target": "Kirlia"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, evolve_active, gs, 0)), "Do not turn active Kirlia into a second 2-prize Gardevoir ex after a bench engine is already online"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_evolve_ref", ref_active, gs, 0)), "Payload should hide active Gardevoir ex evolution once another Gardevoir ex is already online"),
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
	var player := gs.players[0]
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	player.bench.append(drifloon_slot)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var darkness := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var darkness_for_slot := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var darkness_for_munkidori := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var bad_psychic_to_kirlia := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Kirlia"}}
	var bad_darkness_to_ralts := {"kind": "attach_energy", "card": darkness, "target": {"name_en": "Ralts"}}
	var bad_darkness_to_drifloon_slot := {"kind": "attach_energy", "card": darkness_for_slot, "target_slot": drifloon_slot}
	var good_darkness_to_munkidori := {"kind": "attach_energy", "card": darkness_for_munkidori, "target": {"name_en": "Munkidori"}}
	var bad_psychic_to_manaphy := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Manaphy"}}
	var bad_psychic_to_flutter_mane := {"kind": "attach_energy", "card": psychic, "target": {"name_en": "Flutter Mane"}}
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
	var bad_darkness_score: float = float(strategy.call("score_action_absolute", bad_darkness_to_drifloon_slot, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_psychic_to_kirlia, gs, 0)), "Psychic Energy should not be manually attached to Kirlia without a TM Evolution route"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_darkness_to_ralts, gs, 0)), "Darkness Energy should not be manually attached to Ralts without a TM Evolution route"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_darkness_to_drifloon_slot, gs, 0)), "Darkness Energy should be preserved for Munkidori instead of manually attached to Drifloon"),
		assert_true(bad_darkness_score <= -50000.0, "Hard-blocked Darkness attaches must score below blocked end_turn and shared setup bonuses"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_darkness_to_munkidori, gs, 0)), "Darkness Energy should remain legal for Munkidori"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_psychic_to_manaphy, gs, 0)), "Psychic Energy should not be manually attached to passive Manaphy"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_psychic_to_flutter_mane, gs, 0)), "Psychic Energy should not be manually attached to passive Flutter Mane"),
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


func test_gardevoir_llm_manual_attach_unlocks_active_scream_tail_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(52)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.damage_counters = 60
	var hand_psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	player.hand.append(hand_psychic)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Zapdos", "Basic", "L", 120), 1)
	var attach_active := {"kind": "attach_energy", "card": hand_psychic, "target": player.active_pokemon}
	var end_turn := {"kind": "end_turn"}
	var attach_score := float(strategy.call("score_action_absolute", attach_active, gs, 0))
	var end_score := float(strategy.call("score_action_absolute", end_turn, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_active_attacker_manual_attach_pressure_available", gs, 0)), "Active Scream Tail one manual Psychic away from Roaring Scream should be recognized as a pressure route"),
		assert_true(attach_score >= 90500.0, "Manual attach that unlocks active Scream Tail pressure should override stale LLM end_turn queues"),
		assert_true(end_score <= -1000.0, "End turn should be blocked while active Scream Tail can be unlocked by hand attach"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", attach_active, gs, 0)), "Active pressure attach should be allowed to replace queued end_turn"),
	])


func test_gardevoir_llm_allows_active_gardevoir_emergency_psychic_attach_when_no_fuel_or_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(43)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var attach_active := {"kind": "attach_energy", "card": psychic, "target_slot": player.active_pokemon}
	var attach_bench := {"kind": "attach_energy", "card": psychic, "target_slot": player.bench[0]}
	var active_ref := {"id": "attach_energy:c16:active", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "Psychic", "position": "active", "target": "Gardevoir ex", "target_name_en": "Gardevoir ex"}
	var bench_ref := {"id": "attach_energy:c16:bench_0", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "Psychic", "position": "bench_0", "target": "Kirlia", "target_name_en": "Kirlia"}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attach_active, gs, 0)), "Active Gardevoir ex may be manually charged when no Psychic discard fuel or attacker conversion exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, attach_bench, gs, 0)), "Emergency attach should not drift to benched core pieces"),
		assert_false(bool(strategy.call("_is_bad_gardevoir_manual_attach_ref", active_ref, gs, 0)), "Payload should keep active Gardevoir emergency attach visible"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_manual_attach_ref", bench_ref, gs, 0)), "Payload should still hide benched Kirlia emergency attach"),
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


func test_gardevoir_llm_repair_inserts_attacker_before_psychic_embrace_without_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var catalog := {
		"play_basic_to_bench:c20": {"id": "play_basic_to_bench:c20", "type": "play_basic_to_bench", "card": "Drifloon"},
		"use_ability:gardevoir": {"id": "use_ability:gardevoir", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	strategy.call("make_llm_runtime_snapshot", gs, 0)
	var tree := {"actions": [{"id": "use_ability:gardevoir", "type": "use_ability", "pokemon": "Gardevoir ex"}, {"id": "end_turn", "type": "end_turn"}]}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", tree, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("play_basic_to_bench:c20"), "Psychic Embrace route without an attacker should first create a real attacker body"),
		assert_true(ids.find("play_basic_to_bench:c20") < ids.find("use_ability:gardevoir"), "Attacker body must be inserted before Psychic Embrace self-damage risk"),
	])


func test_gardevoir_llm_blocks_psychic_embrace_until_attacker_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(11)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var embrace := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability": {"name": "Psychic Embrace"}}
	var blocked_without_attacker := bool(strategy.call("_deck_should_block_exact_queue_match", {}, embrace, gs, 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var blocked_with_attacker := bool(strategy.call("_deck_should_block_exact_queue_match", {}, embrace, gs, 0))
	return run_checks([
		assert_true(blocked_without_attacker, "Psychic Embrace should be blocked before a real Gardevoir attacker exists"),
		assert_false(blocked_with_attacker, "Psychic Embrace should become legal once Drifloon/Scream Tail exists"),
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


func test_gardevoir_llm_productive_candidates_include_iono_when_attacker_chain_is_missing() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	strategy.set("_llm_action_catalog", {
		"play_trainer:c41": {"id": "play_trainer:c41", "type": "play_trainer", "card": "Iono"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var target: Array[Dictionary] = []
	var route_actions: Array[Dictionary] = []
	strategy.call("_deck_append_productive_engine_candidates", target, {}, route_actions, false, false)
	var ids := _action_ids(target)
	return assert_true(ids.has("play_trainer:c41"), "Iono should be a productive recovery engine when no attack route is available")


func test_gardevoir_llm_inserts_attacker_body_before_gardevoir_ex_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var catalog := {
		"play_basic_to_bench:c30": {"id": "play_basic_to_bench:c30", "type": "play_basic_to_bench", "card": "Drifloon"},
		"attack:0:Miracle Force": {"id": "attack:0:Miracle Force", "type": "attack", "attack_name": "Miracle Force", "card": "Gardevoir ex"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	}
	strategy.set("_llm_action_catalog", catalog)
	strategy.call("make_llm_runtime_snapshot", gs, 0)
	var tree := {"actions": [{"id": "attack:0:Miracle Force", "type": "attack", "attack_name": "Miracle Force"}]}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", tree, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("play_basic_to_bench:c30"), "Gardevoir ex attack route should first bench a real attacker when no attacker body exists"),
		assert_false(ids.has("attack:0:Miracle Force") and ids.find("attack:0:Miracle Force") < ids.find("play_basic_to_bench:c30"), "Gardevoir ex attack must not run before attacker continuity is repaired; ids=%s" % JSON.stringify(ids)),
	])


func test_gardevoir_llm_priority_hand_gain_replans_past_generic_limit() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var before := {
		"turn": 8,
		"hand_names": ["Ultra Ball"],
		"gardevoir_engine_online": true,
		"attacker_count": 0,
		"ready_attacker_count": 0,
		"kirlia_count": 0,
		"ralts_count": 0,
	}
	var after := before.duplicate(true)
	after["hand_names"] = ["Drifloon"]
	var trigger: Dictionary = strategy.call("_deck_replan_trigger_after_state_change", before, after, {
		"action_kind": "play_trainer",
		"action_card_name": "Ultra Ball",
	})
	return run_checks([
		assert_true(bool(trigger.get("should_replan", false)), "Finding a first real attacker after engine setup must trigger a new LLM plan"),
		assert_true(bool(trigger.get("ignore_replan_limit", false)), "Priority hand gains must bypass the generic replan cap so searched attackers can be benched"),
		assert_eq(str(trigger.get("reason", "")), "gardevoir_priority_hand_gain", "Priority Gardevoir hand gains should use an auditable trigger reason"),
	])


func test_gardevoir_llm_psychic_embrace_active_attacker_building_pressure_does_not_fresh_replan() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var before := {
		"turn": 8,
		"gardevoir_engine_online": true,
		"psychic_energy_discard_count": 3,
		"ready_attacker_count": 1,
		"active_retreat_gap": 0,
		"active_gardevoir_attacker_name": "Scream Tail",
		"active_gardevoir_attacker_ready": true,
		"active_gardevoir_attacker_damage": 40,
		"active_gardevoir_attacker_energy_count": 1,
	}
	var after := before.duplicate(true)
	after["psychic_energy_discard_count"] = 2
	after["active_gardevoir_attacker_damage"] = 80
	after["active_gardevoir_attacker_energy_count"] = 2
	var trigger: Dictionary = strategy.call("_deck_replan_trigger_after_state_change", before, after, {
		"action_kind": "use_ability",
		"action_card_name": "Gardevoir ex",
	})
	return run_checks([
		assert_false(bool(trigger.get("should_replan", false)), "Psychic Embrace should keep local execution while it is only building pressure"),
	])


func test_gardevoir_llm_pressure_ready_embrace_conversion_can_suppress_extra_llm_request() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var before := {
		"turn": 8,
		"gardevoir_engine_online": true,
		"psychic_energy_discard_count": 2,
		"ready_attacker_count": 1,
		"active_retreat_gap": 0,
		"active_gardevoir_attacker_name": "Drifloon",
		"active_gardevoir_attacker_ready": true,
		"active_gardevoir_attacker_pressure_ready": false,
		"active_gardevoir_attacker_needs_more_embrace_pressure": true,
		"active_gardevoir_attacker_damage": 60,
		"active_gardevoir_attacker_energy_count": 2,
	}
	var after := before.duplicate(true)
	after["psychic_energy_discard_count"] = 1
	after["active_gardevoir_attacker_pressure_ready"] = true
	after["active_gardevoir_attacker_needs_more_embrace_pressure"] = false
	after["active_gardevoir_attacker_damage"] = 120
	after["active_gardevoir_attacker_energy_count"] = 3
	var trigger: Dictionary = strategy.call("_deck_replan_trigger_after_state_change", before, after, {
		"action_kind": "use_ability",
		"action_card_name": "Gardevoir ex",
	})
	return run_checks([
		assert_true(bool(trigger.get("should_replan", false)), "Pressure conversion still marks the queue as changed"),
		assert_false(bool(trigger.get("ignore_replan_limit", false)), "Pressure-ready conversion should allow the runtime to prune to attack instead of forcing another LLM request"),
		assert_eq(str(trigger.get("reason", "")), "gardevoir_active_attacker_conversion_changed", "The trigger should remain auditable"),
	])


func test_gardevoir_llm_escape_after_nonterminal_embrace_respects_replan_cap() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.damage_counters = 20
	var embrace := {"kind": "use_ability", "source_slot": _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0), "ability": {"name": "Psychic Embrace"}}
	var retreat := {"kind": "retreat", "bench_target": player.active_pokemon}
	return run_checks([
		assert_false(bool(strategy.call("_deck_escape_action_bypasses_replan_limit", embrace, gs, 0)), "Escaped Psychic Embrace should not bypass the generic cap unless it opened a terminal window"),
		assert_false(bool(strategy.call("_deck_escape_action_bypasses_replan_limit", retreat, gs, 0)), "Escaped retreat into an undercharged attacker should stay cap-aware"),
	])


func test_gardevoir_llm_skips_llm_for_single_psychic_embrace_runtime_action() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(20)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0))
	var legal_actions := [
		{"kind": "use_ability", "pokemon": "Gardevoir ex", "ability": {"name": "Psychic Embrace"}},
		{"kind": "end_turn"},
	]
	return assert_true(bool(strategy.call("_should_skip_llm_for_local_rules", gs, 0, legal_actions)), "A single deck-guarded Psychic Embrace action should use local rules instead of spending a full LLM request")


func test_gardevoir_llm_blocks_end_turn_when_active_attacker_has_real_damage() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(21)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.damage_counters = 60
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 120, "", "V"), 1)
	var end_turn := {"kind": "end_turn"}
	var attack := {"kind": "attack", "attack_index": 1, "attack_name": "Balloon Bomb", "pokemon": player.active_pokemon}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "Do not end with a charged Drifloon dealing real pressure damage"),
		assert_true(float(strategy.call("score_action_absolute", end_turn, gs, 0)) < 0.0, "Stale end_turn should be scored below any productive attack"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", attack, gs, 0)), "A charged active attacker should replace stale end_turn even if it does not take an immediate KO"),
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


func test_gardevoir_llm_search_cards_prioritizes_attacker_over_second_gardevoir_when_engine_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(15)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var gardevoir := CardInstance.create(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var drifloon := CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	var scream_tail := CardInstance.create(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	_inject_llm_tree(strategy, 15, {
		"actions": [{
			"type": "play_trainer",
			"card": "Ultra Ball",
			"interactions": {"search_cards": {"prefer": ["Gardevoir ex"]}},
		}],
	})
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.call("pick_interaction_items", [gardevoir, drifloon, scream_tail], {"id": "search_cards", "max_select": 1}, context)
	var picked_card: Variant = picked[0] if picked.size() > 0 else null
	var drifloon_score := float(strategy.call("score_interaction_target", drifloon, {"id": "search_cards"}, context))
	var gardevoir_score := float(strategy.call("score_interaction_target", gardevoir, {"id": "search_cards"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Search should choose exactly one Pokemon"),
		assert_true(picked_card == drifloon, "With Gardevoir ex online and no attacker, search_cards should take Drifloon before a redundant Gardevoir ex"),
		assert_true(drifloon_score > gardevoir_score, "Attacker search score should outrank redundant second Gardevoir ex"),
	])


func test_gardevoir_llm_arven_item_search_prefers_attacker_access_item() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(16)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	var night := CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0)
	var ultra := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item"), 0)
	var nest := CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)
	_inject_llm_tree(strategy, 16, {
		"actions": [{
			"type": "play_trainer",
			"card": "Arven",
			"interactions": {"search_item": {"prefer": ["Ultra Ball"]}},
		}],
	})
	var context := {"game_state": gs, "player_index": 0}
	var picked_no_discard: Array = strategy.call("pick_interaction_items", [night, ultra, nest], {"id": "search_item", "max_select": 1}, context)
	var picked_no_discard_card: Variant = picked_no_discard[0] if picked_no_discard.size() > 0 else null
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	var picked_with_discard: Array = strategy.call("pick_interaction_items", [night, ultra, nest], {"id": "search_item", "max_select": 1}, context)
	var picked_with_discard_card: Variant = picked_with_discard[0] if picked_with_discard.size() > 0 else null
	return run_checks([
		assert_eq(picked_no_discard.size(), 1, "Arven item search should pick one item without discard recovery target"),
		assert_true(picked_no_discard_card == nest, "Without attacker in discard, Arven should prefer direct Basic access over Night Stretcher"),
		assert_eq(picked_with_discard.size(), 1, "Arven item search should pick one item with discard recovery target"),
		assert_true(picked_with_discard_card == night, "With attacker in discard, Arven should prefer Night Stretcher for immediate recovery"),
	])


func test_gardevoir_llm_headless_night_stretcher_recovers_attacker_over_support() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_game_state(20)
	var player := gsm.game_state.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("沙奈朵ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0)
	var manaphy := CardInstance.create(_make_pokemon_cd("玛纳霏", "Basic", "W", 70), 0)
	var drifloon := CardInstance.create(_make_pokemon_cd("飘飘球", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0)
	var builder := AILegalActionBuilderScript.new()
	builder.set_deck_strategy(strategy)
	var picked: Array = builder.call("_select_headless_items", gsm, 0, 0, {
		"id": "night_stretcher_choice",
		"max_select": 1,
	}, [manaphy, drifloon], 1, {})
	return run_checks([
		assert_eq(picked.size(), 1, "Night Stretcher headless recovery should pick exactly one card"),
		assert_true(picked[0] == drifloon, "Night Stretcher should recover a real attacker before passive support when Gardevoir ex is online"),
	])


func test_gardevoir_llm_super_rod_returns_attackers_before_passive_support() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(22)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0)
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0))
	var manaphy := CardInstance.create(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	var ralts := CardInstance.create(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var drifloon := CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"}]), 0)
	var scream_tail := CardInstance.create(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [{"name": "Roaring Scream", "cost": "PC", "damage": ""}]), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	player.discard_pile.append_array([manaphy, ralts, drifloon, scream_tail, psychic])
	var picked: Array = strategy.call("pick_interaction_items", [manaphy, ralts, drifloon, scream_tail, psychic], {
		"id": "cards_to_return",
		"max_select": 3,
	}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 3, "Super Rod should still use all productive recovery slots when attackers and Psychic fuel are available"),
		assert_true(picked.has(drifloon), "Super Rod must return Drifloon before passive support when Gardevoir has no attacker body"),
		assert_true(picked.has(scream_tail), "Super Rod must return Scream Tail before passive support when Gardevoir has no attacker body"),
		assert_true(picked.has(psychic), "Super Rod should use the third recovery slot on Psychic fuel after attacker bodies"),
		assert_false(picked.has(manaphy), "Super Rod should not spend recovery slots on passive support before attacker continuity"),
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


func test_gardevoir_llm_arven_item_search_prefers_vessel_when_engine_has_no_psychic_fuel() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(31)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}], [
		{"name": "Miracle Force", "cost": "PPC", "damage": "190"},
	]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item"), 0)
	var stretcher := CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0)
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item"), 0)
	_inject_llm_tree(strategy, 31, {
		"actions": [{
			"type": "play_trainer",
			"card": "Arven",
			"interactions": {"search_item": {"prefer": ["Night Stretcher"]}},
		}],
	})
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_card": CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0),
		"card": "Arven",
	}
	var picked: Array = strategy.call("pick_interaction_items", [stretcher, vessel, ultra_ball], {"id": "search_item", "max_select": 1}, context)
	var picked_card: Variant = picked[0] if not picked.is_empty() else null
	var vessel_score: float = float(strategy.call("score_interaction_target", vessel, {"id": "search_item"}, context))
	var stretcher_score: float = float(strategy.call("score_interaction_target", stretcher, {"id": "search_item"}, context))
	return run_checks([
		assert_eq(picked.size(), 1, "Arven item search should pick one Item in a no-fuel Gardevoir engine state"),
		assert_true(picked_card == vessel, "No-fuel Gardevoir engine should use Arven to find Earthen Vessel before recovery cards"),
		assert_true(vessel_score > stretcher_score, "Earthen Vessel must outrank Night Stretcher when Psychic Embrace has no fuel"),
	])


func test_gardevoir_llm_earthen_vessel_energy_search_takes_two_psychic() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(36)
	_inject_llm_tree(strategy, 36, {
		"actions": [{
			"type": "play_trainer",
			"card": "Earthen Vessel",
			"interactions": {
				"search_targets": {"items": ["Psychic Energy"], "max_select": 2.0},
			},
		}],
	})
	var items: Array = [
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
	]
	var picked: Array = strategy.call("pick_interaction_items", items, {
		"id": "search_energy",
		"max_select": 2,
	}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 2, "Earthen Vessel energy search should take the full two-card selection when two Psychic Energy are available"),
		assert_eq(_card_names(picked), ["Psychic Energy", "Psychic Energy"], "Gardevoir should prioritize two Psychic Energy over Darkness for Embrace fuel"),
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


func test_gardevoir_llm_preserves_last_bench_slot_for_first_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(15)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var greninja_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 0)}
	var flutter_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Flutter Mane", "Basic", "P", 90), 0)}
	var drifloon_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, greninja_action, gs, 0)), "Do not spend the last bench slot on Radiant Greninja before the first real attacker exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, flutter_action, gs, 0)), "Do not spend the last bench slot on support pivots before the first real attacker exists"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, drifloon_action, gs, 0)), "The last protected slot should remain available for Drifloon/Scream Tail"),
	])


func test_gardevoir_llm_manaphy_ignores_raikou_bench_count_damage() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(16)
	var player := gs.players[0]
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var opponent := gs.players[1]
	var manaphy_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)}
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130, "", "Radiant", [], [
		{"name": "Moonlight Shuriken", "cost": "WWC", "damage": "", "text": "This attack does 90 damage to 2 of your opponent's Benched Pokemon."},
	]), 1)
	var spread_blocked := bool(strategy.call("_deck_should_block_exact_queue_match", {}, manaphy_action, gs, 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V", [], [
		{"name": "Lightning Rondo", "cost": "LC", "damage": "20+", "text": "This attack does 20 more damage for each Benched Pokemon."},
	]), 1)
	var raikou_blocked := bool(strategy.call("_deck_should_block_exact_queue_match", {}, manaphy_action, gs, 0))
	return run_checks([
		assert_false(spread_blocked, "Manaphy may be benched against real Benched Pokemon damage"),
		assert_true(raikou_blocked, "Raikou bench-count damage should not be treated as Manaphy-protected spread"),
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


func test_gardevoir_llm_payload_filters_passive_support_routes_before_catalog_registration() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(24)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V", [], [
		{"name": "Lightning Rondo", "cost": "LC", "damage": "20+", "text": "This attack does 20 more damage for each Benched Pokemon."},
	]), 1)
	var payload := {
		"legal_actions": [
			{"id": "play_basic_to_bench:c0", "type": "play_basic_to_bench", "card": "Manaphy"},
			{"id": "play_basic_to_bench:c1", "type": "play_basic_to_bench", "card": "Ralts"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"future_actions": [],
		"legal_action_groups": {
			"search_or_setup": ["play_basic_to_bench:c0", "play_basic_to_bench:c1"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:engine_before_end", "goal": "engine_setup", "actions": [{"id": "play_basic_to_bench:c0"}, {"id": "end_turn"}]},
			{"route_action_id": "route:basic_setup", "goal": "board_setup", "actions": [{"id": "play_basic_to_bench:c1"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"productive_engine_actions": [{"id": "play_basic_to_bench:c0"}, {"id": "play_basic_to_bench:c1"}],
		},
	}
	strategy.set("_llm_action_catalog", {
		"play_basic_to_bench:c0": {"id": "play_basic_to_bench:c0", "type": "play_basic_to_bench", "card": "Manaphy"},
		"play_basic_to_bench:c1": {"id": "play_basic_to_bench:c1", "type": "play_basic_to_bench", "card": "Ralts"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var setup_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("search_or_setup", [])
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var fact_ids := _action_ids((filtered.get("turn_tactical_facts", {}) as Dictionary).get("productive_engine_actions", []))
	var catalog: Dictionary = strategy.get("_llm_action_catalog")
	return run_checks([
		assert_false(legal_ids.has("play_basic_to_bench:c0"), "Prompt payload should remove passive Manaphy from early Gardevoir legal actions"),
		assert_true(legal_ids.has("play_basic_to_bench:c1"), "Prompt payload should preserve core Ralts setup"),
		assert_false(setup_group.has("play_basic_to_bench:c0"), "Legal action groups should not advertise filtered passive support"),
		assert_false(route_ids.has("route:engine_before_end"), "Candidate route containing only filtered Manaphy plus end_turn should be dropped"),
		assert_true(route_ids.has("route:basic_setup"), "Candidate route with real core setup should remain"),
		assert_false(fact_ids.has("play_basic_to_bench:c0"), "Tactical facts should not advertise filtered passive support"),
		assert_false(catalog.has("play_basic_to_bench:c0"), "Filtered support actions must be removed from the runtime catalog too"),
	])


func test_gardevoir_llm_blocks_support_bench_until_backup_attacker_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(25)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var munkidori_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)}
	var drifloon_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)}
	var payload := {
		"legal_actions": [
			{"id": "play_basic_to_bench:c30", "type": "play_basic_to_bench", "card": "Munkidori"},
			{"id": "play_basic_to_bench:c31", "type": "play_basic_to_bench", "card": "Drifloon"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {
			"search_or_setup": ["play_basic_to_bench:c30", "play_basic_to_bench:c31"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:support_bench", "goal": "board_setup", "actions": [{"id": "play_basic_to_bench:c30"}, {"id": "end_turn"}]},
			{"route_action_id": "route:backup_attacker", "goal": "board_setup", "actions": [{"id": "play_basic_to_bench:c31"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"productive_engine_actions": [{"id": "play_basic_to_bench:c30"}, {"id": "play_basic_to_bench:c31"}],
		},
	}
	strategy.set("_llm_action_catalog", {
		"play_basic_to_bench:c30": {"id": "play_basic_to_bench:c30", "type": "play_basic_to_bench", "card": "Munkidori"},
		"play_basic_to_bench:c31": {"id": "play_basic_to_bench:c31", "type": "play_basic_to_bench", "card": "Drifloon"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var setup_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("search_or_setup", [])
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var fact_ids := _action_ids((filtered.get("turn_tactical_facts", {}) as Dictionary).get("productive_engine_actions", []))
	var catalog: Dictionary = strategy.get("_llm_action_catalog")
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, munkidori_action, gs, 0)), "Do not bench support Pokemon while Gardevoir ex has only one real attacker body"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, drifloon_action, gs, 0)), "A backup Drifloon should remain playable in the same window"),
		assert_false(legal_ids.has("play_basic_to_bench:c30"), "Payload should hide Munkidori until backup attacker continuity exists"),
		assert_true(legal_ids.has("play_basic_to_bench:c31"), "Payload should keep the backup Drifloon line visible"),
		assert_false(setup_group.has("play_basic_to_bench:c30"), "Legal action group should remove support bench before backup attacker"),
		assert_false(route_ids.has("route:support_bench"), "Candidate route containing support bench should be dropped"),
		assert_true(route_ids.has("route:backup_attacker"), "Backup attacker route should remain"),
		assert_false(fact_ids.has("play_basic_to_bench:c30"), "Tactical facts should not advertise support bench before backup attacker"),
		assert_false(catalog.has("play_basic_to_bench:c30"), "Filtered support bench must leave the runtime catalog"),
	])


func test_gardevoir_llm_allows_munkidori_once_attacker_package_and_darkness_are_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(51)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	var munkidori_action := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)}
	var payload := {
		"legal_actions": [
			{"id": "play_basic_to_bench:c30", "type": "play_basic_to_bench", "card": "Munkidori"},
			{"id": "attach_energy:c40:bench_4", "type": "attach_energy", "card": "Darkness Energy", "target": "Munkidori", "target_name_en": "Munkidori", "position": "bench_4"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {
			"search_or_setup": ["play_basic_to_bench:c30"],
			"manual_attach": ["attach_energy:c40:bench_4"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:munkidori_setup", "goal": "damage_counter_conversion", "actions": [{"id": "play_basic_to_bench:c30"}, {"id": "attach_energy:c40:bench_4"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"productive_engine_actions": [{"id": "play_basic_to_bench:c30"}, {"id": "attach_energy:c40:bench_4"}],
		},
	}
	strategy.set("_llm_action_catalog", {
		"play_basic_to_bench:c30": {"id": "play_basic_to_bench:c30", "type": "play_basic_to_bench", "card": "Munkidori"},
		"attach_energy:c40:bench_4": {"id": "attach_energy:c40:bench_4", "type": "attach_energy", "card": "Darkness Energy", "target": "Munkidori", "target_name_en": "Munkidori", "position": "bench_4"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var catalog: Dictionary = strategy.get("_llm_action_catalog")
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, munkidori_action, gs, 0)), "Munkidori should become playable once core, two attackers, and Darkness access are established"),
		assert_true(legal_ids.has("play_basic_to_bench:c30"), "Payload should keep Munkidori visible in the midgame conversion window"),
		assert_true(legal_ids.has("attach_energy:c40:bench_4"), "Payload should keep Darkness attach to Munkidori visible"),
		assert_true(route_ids.has("route:munkidori_setup"), "Candidate route containing Munkidori setup should survive filtering"),
		assert_true(catalog.has("play_basic_to_bench:c30"), "Munkidori setup should remain in the runtime catalog"),
	])


func test_gardevoir_llm_blocks_duplicate_munkidori_even_after_core_is_stable() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(26)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0))
	var duplicate_munkidori := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)}
	var radiant_greninja := {"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 0)}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, duplicate_munkidori, gs, 0)), "A second Munkidori should be blocked even after Gardevoir core and attacker continuity are stable"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, radiant_greninja, gs, 0)), "Other support can still be considered once core, attackers, and existing Munkidori are established"),
	])


func test_gardevoir_llm_payload_filters_bad_tool_attach_and_catalog_refs() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(27)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var payload := {
		"legal_actions": [
			{"id": "attach_tool:c50:active", "type": "attach_tool", "card": "Bravery Charm", "target": "Kirlia", "target_name_en": "Kirlia", "position": "active"},
			{"id": "attach_tool:c50:bench_0", "type": "attach_tool", "card": "Bravery Charm", "target": "Drifloon", "target_name_en": "Drifloon", "position": "bench_0"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {
			"tool_or_modifier": ["attach_tool:c50:active", "attach_tool:c50:bench_0"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:bad_tool", "goal": "engine_setup", "actions": [{"id": "attach_tool:c50:active"}, {"id": "end_turn"}]},
			{"route_action_id": "route:attacker_tool", "goal": "engine_setup", "actions": [{"id": "attach_tool:c50:bench_0"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"legal_survival_tool_actions": [{"id": "attach_tool:c50:active"}, {"id": "attach_tool:c50:bench_0"}],
		},
	}
	strategy.set("_llm_action_catalog", {
		"attach_tool:c50:active": {"id": "attach_tool:c50:active", "type": "attach_tool", "card": "Bravery Charm", "target": "Kirlia", "target_name_en": "Kirlia", "position": "active"},
		"attach_tool:c50:bench_0": {"id": "attach_tool:c50:bench_0", "type": "attach_tool", "card": "Bravery Charm", "target": "Drifloon", "target_name_en": "Drifloon", "position": "bench_0"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var tool_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("tool_or_modifier", [])
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var fact_ids := _action_ids((filtered.get("turn_tactical_facts", {}) as Dictionary).get("legal_survival_tool_actions", []))
	var catalog: Dictionary = strategy.get("_llm_action_catalog")
	return run_checks([
		assert_false(legal_ids.has("attach_tool:c50:active"), "Bravery Charm should not be advertised for core Kirlia"),
		assert_true(legal_ids.has("attach_tool:c50:bench_0"), "Bravery Charm should remain available for Drifloon"),
		assert_false(tool_group.has("attach_tool:c50:active"), "Tool group should remove bad Bravery target"),
		assert_false(route_ids.has("route:bad_tool"), "Route containing only bad Bravery target plus end_turn should be dropped"),
		assert_true(route_ids.has("route:attacker_tool"), "Route targeting the attacker should remain"),
		assert_false(fact_ids.has("attach_tool:c50:active"), "Tactical facts should remove bad Bravery target"),
		assert_false(catalog.has("attach_tool:c50:active"), "Filtered Bravery target must leave the runtime catalog"),
	])


func test_gardevoir_llm_payload_filters_bad_manual_attach_and_retreat_refs() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(28)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(drifloon_slot)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var payload := {
		"legal_actions": [
			{"id": "attach_energy:c18:bench_0", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "Psychic", "target": "Ralts", "target_name_en": "Ralts", "position": "bench_0"},
			{"id": "attach_energy:c18:bench_1", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "Psychic", "target": "Drifloon", "target_name_en": "Drifloon", "position": "bench_1"},
			{"id": "retreat:bench_0:c13", "type": "retreat", "bench_target": "Ralts", "bench_target_name_en": "Ralts", "bench_position": "bench_0"},
			{"id": "retreat:bench_1:c13", "type": "retreat", "bench_target": "Drifloon", "bench_target_name_en": "Drifloon", "bench_position": "bench_1"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {
			"manual_attach": ["attach_energy:c18:bench_0", "attach_energy:c18:bench_1"],
			"pivot_or_gust": ["retreat:bench_0:c13", "retreat:bench_1:c13"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:bad_attach", "goal": "manual_attach_setup", "actions": [{"id": "attach_energy:c18:bench_0"}, {"id": "end_turn"}]},
			{"route_action_id": "route:good_attach", "goal": "manual_attach_setup", "actions": [{"id": "attach_energy:c18:bench_1"}, {"id": "end_turn"}]},
			{"route_action_id": "route:bad_retreat", "goal": "pivot_to_attack", "actions": [{"id": "retreat:bench_0:c13"}, {"id": "end_turn"}]},
			{"route_action_id": "route:good_retreat", "goal": "pivot_to_attack", "actions": [{"id": "retreat:bench_1:c13"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"safe_pre_primary_actions": [{"id": "attach_energy:c18:bench_0"}, {"id": "attach_energy:c18:bench_1"}, {"id": "retreat:bench_0:c13"}, {"id": "retreat:bench_1:c13"}],
		},
	}
	strategy.set("_llm_action_catalog", {
		"attach_energy:c18:bench_0": {"id": "attach_energy:c18:bench_0", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "Psychic", "target": "Ralts", "target_name_en": "Ralts", "position": "bench_0"},
		"attach_energy:c18:bench_1": {"id": "attach_energy:c18:bench_1", "type": "attach_energy", "card": "Psychic Energy", "card_type": "Basic Energy", "energy_type": "Psychic", "target": "Drifloon", "target_name_en": "Drifloon", "position": "bench_1"},
		"retreat:bench_0:c13": {"id": "retreat:bench_0:c13", "type": "retreat", "bench_target": "Ralts", "bench_target_name_en": "Ralts", "bench_position": "bench_0"},
		"retreat:bench_1:c13": {"id": "retreat:bench_1:c13", "type": "retreat", "bench_target": "Drifloon", "bench_target_name_en": "Drifloon", "bench_position": "bench_1"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var attach_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("manual_attach", [])
	var pivot_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("pivot_or_gust", [])
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var fact_ids := _action_ids((filtered.get("turn_tactical_facts", {}) as Dictionary).get("safe_pre_primary_actions", []))
	var catalog: Dictionary = strategy.get("_llm_action_catalog")
	return run_checks([
		assert_false(legal_ids.has("attach_energy:c18:bench_0"), "Manual attach to bench Ralts should be hidden from Gardevoir LLM payload"),
		assert_true(legal_ids.has("attach_energy:c18:bench_1"), "Manual attach to a real attacker should remain visible"),
		assert_false(legal_ids.has("retreat:bench_0:c13"), "Retreat into bench Ralts should be hidden"),
		assert_true(legal_ids.has("retreat:bench_1:c13"), "Retreat into a real attacker should remain visible"),
		assert_false(attach_group.has("attach_energy:c18:bench_0"), "Manual attach group should remove bad core target"),
		assert_false(pivot_group.has("retreat:bench_0:c13"), "Pivot group should remove bad core target"),
		assert_false(route_ids.has("route:bad_attach"), "Bad manual attach route should be dropped"),
		assert_true(route_ids.has("route:good_attach"), "Good manual attach route should remain"),
		assert_false(route_ids.has("route:bad_retreat"), "Bad retreat route should be dropped"),
		assert_true(route_ids.has("route:good_retreat"), "Good retreat route should remain"),
		assert_false(fact_ids.has("attach_energy:c18:bench_0"), "Facts should remove bad manual attach"),
		assert_false(fact_ids.has("retreat:bench_0:c13"), "Facts should remove bad retreat"),
		assert_false(catalog.has("attach_energy:c18:bench_0"), "Filtered manual attach must leave the runtime catalog"),
		assert_false(catalog.has("retreat:bench_0:c13"), "Filtered retreat must leave the runtime catalog"),
	])


func test_gardevoir_llm_blocks_darkness_attach_to_psychic_attackers() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(17)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	player.bench.append(drifloon)
	player.bench.append(munkidori)
	var darkness := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var dark_to_drifloon := {"kind": "attach_energy", "card": darkness, "target_slot": drifloon}
	var psychic_to_drifloon := {"kind": "attach_energy", "card": psychic, "target_slot": drifloon}
	var dark_to_munkidori := {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}
	var dark_ref_to_drifloon := {"id": "attach_energy:c40:bench_0", "type": "attach_energy", "card": "Darkness Energy", "card_type": "Basic Energy", "target": "Drifloon", "target_name_en": "Drifloon", "position": "bench_0"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, dark_to_drifloon, gs, 0)), "Darkness Energy must not be attached to Drifloon"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, psychic_to_drifloon, gs, 0)), "Psychic Energy should remain valid for Drifloon"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, dark_to_munkidori, gs, 0)), "Darkness Energy should remain valid for Munkidori"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_manual_attach_ref", dark_ref_to_drifloon, gs, 0)), "Payload filter should hide Darkness attach refs targeting Drifloon"),
	])


func test_gardevoir_llm_blocks_duplicate_darkness_attach_to_munkidori() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(43)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	var darkness := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var duplicate_darkness := {"kind": "attach_energy", "card": darkness, "target_slot": munkidori}
	var duplicate_ref := {"id": "attach_energy:c41:bench_0", "type": "attach_energy", "card": "Darkness Energy", "card_type": "Basic Energy", "target": "Munkidori", "target_name_en": "Munkidori", "position": "bench_0"}
	var payload: Dictionary = strategy.call("_deck_augment_action_id_payload", {
		"legal_actions": [
			duplicate_ref,
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {"manual_attach": ["attach_energy:c41:bench_0"], "fallback": ["end_turn"]},
		"candidate_routes": [
			{"id": "bad_darkness", "goal": "manual_attach_setup", "actions": [{"id": "attach_energy:c41:bench_0"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {},
	}, gs, 0)
	var legal_ids := _action_ids(payload.get("legal_actions", []))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, duplicate_darkness, gs, 0)), "Munkidori only needs one Darkness Energy to enable Adrena-Brain"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_manual_attach_ref", duplicate_ref, gs, 0)), "Payload filter should hide duplicate Darkness attach to an already enabled Munkidori"),
		assert_false(legal_ids.has("attach_energy:c41:bench_0"), "Duplicate Darkness attach should be removed from the LLM legal-action surface"),
	])


func test_gardevoir_llm_payload_filters_core_pivot_attack_but_keeps_tm_evolution_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(32)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var payload := {
		"legal_actions": [
			{"id": "attack:0:teleportation_burst", "type": "attack", "attack_index": 0, "attack_name": "Teleportation Burst", "requires_interaction": true, "interaction_schema": {"switch_target": {"type": "string"}}},
			{"id": "granted_attack:-1:evolution", "type": "granted_attack", "attack_index": -1, "attack_name": "进化", "pokemon": "Ralts", "position": "active", "requires_interaction": true, "interaction_schema": {"search_targets": {"type": "array"}}, "attack_rules": {"id": "tm_evolution", "name": "进化", "cost": "C"}},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {
			"attack": ["attack:0:teleportation_burst", "granted_attack:-1:evolution"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:bad_core_attack", "goal": "attack", "actions": [{"id": "attack:0:teleportation_burst"}]},
			{"route_action_id": "route:tm_evolution_attack", "goal": "attack", "actions": [{"id": "granted_attack:-1:evolution"}]},
		],
		"turn_tactical_facts": {
			"safe_pre_primary_actions": [{"id": "attack:0:teleportation_burst"}, {"id": "granted_attack:-1:evolution"}],
			"ready_attacks": [{"legal_action_id": "attack:0:teleportation_burst"}, {"legal_action_id": "granted_attack:-1:evolution"}],
			"active_attack_options": [{"legal_action_id": "attack:0:teleportation_burst"}, {"legal_action_id": "granted_attack:-1:evolution"}],
			"attack_quality_by_action_id": {
				"attack:0:teleportation_burst": {"role": "chip_damage"},
				"granted_attack:-1:evolution": {"role": "setup"},
			},
		},
	}
	strategy.set("_llm_action_catalog", {
		"attack:0:teleportation_burst": {"id": "attack:0:teleportation_burst", "type": "attack", "attack_index": 0, "attack_name": "Teleportation Burst", "requires_interaction": true, "interaction_schema": {"switch_target": {"type": "string"}}},
		"granted_attack:-1:evolution": {"id": "granted_attack:-1:evolution", "type": "granted_attack", "attack_index": -1, "attack_name": "进化", "pokemon": "Ralts", "position": "active", "requires_interaction": true, "interaction_schema": {"search_targets": {"type": "array"}}, "attack_rules": {"id": "tm_evolution", "name": "进化", "cost": "C"}},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var attack_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("attack", [])
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var filtered_facts: Dictionary = filtered.get("turn_tactical_facts", {}) as Dictionary
	var fact_ids := _action_ids(filtered_facts.get("safe_pre_primary_actions", []))
	var ready_ids := _action_ids(filtered_facts.get("ready_attacks", []))
	var active_option_ids := _action_ids(filtered_facts.get("active_attack_options", []))
	var quality: Dictionary = filtered_facts.get("attack_quality_by_action_id", {})
	var catalog: Dictionary = strategy.get("_llm_action_catalog")
	return run_checks([
		assert_false(legal_ids.has("attack:0:teleportation_burst"), "Core pivot attack should not be exposed as a Gardevoir LLM attack option"),
		assert_true(legal_ids.has("granted_attack:-1:evolution"), "TM Evolution granted attack should remain visible"),
		assert_false(attack_group.has("attack:0:teleportation_burst"), "Attack group should remove bad core pivot attack"),
		assert_true(attack_group.has("granted_attack:-1:evolution"), "Attack group should keep TM Evolution granted attack"),
		assert_false(route_ids.has("route:bad_core_attack"), "Bad core pivot attack route should be dropped"),
		assert_true(route_ids.has("route:tm_evolution_attack"), "TM Evolution attack route should remain"),
		assert_false(fact_ids.has("attack:0:teleportation_burst"), "Tactical facts should remove bad core pivot attack"),
		assert_false(ready_ids.has("attack:0:teleportation_burst"), "Ready attack facts should remove bad core pivot attack"),
		assert_false(active_option_ids.has("attack:0:teleportation_burst"), "Active attack options should remove bad core pivot attack"),
		assert_false(quality.has("attack:0:teleportation_burst"), "Attack quality facts should remove bad core pivot attack"),
		assert_false(catalog.has("attack:0:teleportation_burst"), "Bad core pivot attack must leave the runtime catalog"),
	])


func test_gardevoir_llm_payload_filters_low_value_support_attack_when_tm_evolution_is_visible() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(36)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70, "", "", [], [
		{"name": "Drop Shot", "cost": "P", "damage": "30"},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var payload := {
		"legal_actions": [
			{"id": "attack:0:drop_shot", "type": "attack", "attack_index": 0, "attack_name": "Drop Shot", "projected_damage": 30},
			{"id": "granted_attack:-1:evolution", "type": "granted_attack", "attack_index": -1, "attack_name": "进化", "pokemon": "Klefki", "position": "active", "attack_rules": {"id": "tm_evolution", "name": "进化", "cost": "C"}},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {
			"attack": ["attack:0:drop_shot", "granted_attack:-1:evolution"],
			"fallback": ["end_turn"],
		},
		"candidate_routes": [
			{"route_action_id": "route:bad_support_attack", "goal": "attack", "actions": [{"id": "attack:0:drop_shot"}]},
			{"route_action_id": "route:tm_evolution_attack", "goal": "attack", "actions": [{"id": "granted_attack:-1:evolution"}]},
		],
		"turn_tactical_facts": {
			"ready_attacks": [{"legal_action_id": "attack:0:drop_shot"}, {"legal_action_id": "granted_attack:-1:evolution"}],
			"attack_quality_by_action_id": {
				"attack:0:drop_shot": {"role": "chip_damage"},
				"granted_attack:-1:evolution": {"role": "setup"},
			},
		},
	}
	strategy.set("_llm_action_catalog", {
		"attack:0:drop_shot": {"id": "attack:0:drop_shot", "type": "attack", "attack_index": 0, "attack_name": "Drop Shot", "projected_damage": 30},
		"granted_attack:-1:evolution": {"id": "granted_attack:-1:evolution", "type": "granted_attack", "attack_index": -1, "attack_name": "进化", "pokemon": "Klefki", "position": "active", "attack_rules": {"id": "tm_evolution", "name": "进化", "cost": "C"}},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var attack_group: Array = (filtered.get("legal_action_groups", {}) as Dictionary).get("attack", [])
	var route_ids: Array[String] = []
	for route: Dictionary in filtered.get("candidate_routes", []):
		route_ids.append(str(route.get("route_action_id", "")))
	var facts: Dictionary = filtered.get("turn_tactical_facts", {}) as Dictionary
	var ready_ids := _action_ids(facts.get("ready_attacks", []))
	var quality: Dictionary = facts.get("attack_quality_by_action_id", {})
	return run_checks([
		assert_false(legal_ids.has("attack:0:drop_shot"), "Low-value Klefki support attack should not be exposed while TM Evolution attack is available"),
		assert_true(legal_ids.has("granted_attack:-1:evolution"), "TM Evolution granted attack should remain visible"),
		assert_false(attack_group.has("attack:0:drop_shot"), "Attack group should remove low-value support attack"),
		assert_false(route_ids.has("route:bad_support_attack"), "Low-value support attack route should be dropped"),
		assert_true(route_ids.has("route:tm_evolution_attack"), "TM Evolution route should remain"),
		assert_false(ready_ids.has("attack:0:drop_shot"), "Ready attack facts should remove low-value support attack"),
		assert_false(quality.has("attack:0:drop_shot"), "Attack quality facts should remove low-value support attack"),
	])


func test_gardevoir_llm_payload_normalizes_psychic_embrace_schema() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(35)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var payload := {
		"legal_actions": [
			{
				"id": "use_ability:bench_0:0",
				"type": "use_ability",
				"pokemon": "Gardevoir ex",
				"ability": "Psychic Embrace",
				"position": "bench_0",
				"interaction_schema": {
					"discard_cards": {"type": "array"},
					"damage_target": {"type": "string"},
				},
			},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {"search_or_setup": ["use_ability:bench_0:0"], "fallback": ["end_turn"]},
		"candidate_routes": [],
		"turn_tactical_facts": {},
	}
	strategy.set("_llm_action_catalog", {})
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var action: Dictionary = {}
	for raw: Variant in filtered.get("legal_actions", []):
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "use_ability:bench_0:0":
			action = raw as Dictionary
			break
	var schema: Dictionary = action.get("interaction_schema", {}) if action.get("interaction_schema", {}) is Dictionary else {}
	var interactions: Dictionary = action.get("interactions", {}) if action.get("interactions", {}) is Dictionary else {}
	return run_checks([
		assert_true(schema.has("psychic_embrace_assignments"), "Psychic Embrace payload should expose the supported assignment schema"),
		assert_true(schema.has("embrace_energy"), "Psychic Embrace payload should expose the real energy-selection step"),
		assert_true(schema.has("embrace_target"), "Psychic Embrace payload should expose the real target-selection step"),
		assert_false(schema.has("discard_cards"), "Psychic Embrace payload must not expose discard-style schema keys"),
		assert_true(interactions.has("psychic_embrace_assignments"), "Psychic Embrace payload should include executable interaction intent"),
	])


func test_gardevoir_llm_replans_when_tm_evolution_bridge_becomes_attack_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var before := {
		"active_energy_count": 0,
		"active_has_tm_evolution": true,
		"active_tm_evolution_bridge_ready": false,
	}
	var after := {
		"active_energy_count": 1,
		"active_has_tm_evolution": true,
		"active_tm_evolution_bridge_ready": true,
	}
	var trigger: Dictionary = strategy.call("_deck_replan_trigger_after_state_change", before, after, {"action_kind": "attach_energy"})
	return run_checks([
		assert_true(bool(trigger.get("should_replan", false)), "TM Evolution carrier should replan after manual attach unlocks attack access"),
		assert_eq(str(trigger.get("reason", "")), "gardevoir_tm_evolution_bridge_action_surface_changed", "Replan reason should identify TM Evolution bridge"),
		assert_true(bool(trigger.get("ignore_replan_limit", false)), "TM Evolution attack unlock should bypass the generic replan cap because it is a terminal attack-surface change"),
	])


func test_gardevoir_llm_matches_tm_evolution_attack_queue_to_granted_attack_runtime_action() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(29)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var queued := {"id": "attack:0:teleportation_burst", "type": "attack", "attack_index": 0, "attack_name": "Teleportation Burst"}
	var runtime_action := {
		"kind": "granted_attack",
		"attack_index": -1,
		"pokemon": player.active_pokemon,
		"granted_attack_data": {"name": "Teleportation Burst", "text": "Search your deck for evolution Pokemon."},
	}
	var matches := bool(strategy.call("_deck_queue_item_matches_action", queued, runtime_action, gs, 0))
	return assert_true(matches, "Queued TM Evolution attack id should match runtime granted_attack action")


func test_gardevoir_llm_matches_tm_evolution_attack_from_serialized_runtime_pokemon_tool() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(31)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	var queued := {"id": "attack:0:teleportation_burst", "type": "attack", "attack_index": 0, "attack_name": "Teleportation Burst"}
	var runtime_action := {
		"kind": "granted_attack",
		"attack_index": -1,
		"pokemon": {
			"name": "拉鲁拉丝",
			"name_en": "Ralts",
			"tool": {"name": "招式学习器 进化", "name_en": "Technical Machine: Evolution"},
		},
		"requires_interaction": true,
	}
	var matches := bool(strategy.call("_deck_queue_item_matches_action", queued, runtime_action, gs, 0))
	return assert_true(matches, "Serialized runtime granted_attack with TM Evolution tool should match queued TM attack even if game_state slot lacks the tool")


func test_gardevoir_llm_scores_tm_evolution_granted_attack_from_queued_attack_head() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(30)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	var queued := {
		"id": "attack:0:teleportation_burst",
		"action_id": "attack:0:teleportation_burst",
		"type": "attack",
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Teleportation Burst",
	}
	strategy.set("_llm_queue_turn", 30)
	strategy.set("_llm_decision_tree", {"actions": [queued]})
	strategy.set("_llm_action_queue", [queued])
	var runtime_action := {
		"kind": "granted_attack",
		"attack_index": -1,
		"pokemon": player.active_pokemon,
		"granted_attack_data": {"name": "Teleportation Burst", "text": "Search your deck for evolution Pokemon."},
	}
	var score := float(strategy.call("score_action_absolute", runtime_action, gs, 0))
	return assert_true(score > 0.0, "Runtime granted_attack should receive LLM queue score when queued attack head is TM Evolution")


func test_gardevoir_llm_does_not_block_runtime_tm_evolution_when_setup_is_visible() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(32)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var queued := {
		"id": "granted_attack:-1:evolution",
		"action_id": "granted_attack:-1:evolution",
		"type": "granted_attack",
		"kind": "granted_attack",
		"attack_index": -1,
		"attack_name": "Evolution",
	}
	strategy.set("_llm_queue_turn", 32)
	strategy.set("_llm_decision_tree", {"actions": [queued]})
	strategy.set("_llm_action_queue", [queued])
	var runtime_action := {
		"kind": "granted_attack",
		"attack_index": -1,
		"pokemon": player.active_pokemon,
		"granted_attack_data": {"id": "tm_evolution", "name": "Evolution", "text": "Search your deck for evolution Pokemon."},
	}
	var score := float(strategy.call("score_action_absolute", runtime_action, gs, 0))
	return run_checks([
		assert_false(bool(strategy.call("_deck_is_low_value_runtime_attack_action", runtime_action, gs, 0)), "TM Evolution granted attack must not be treated as a low-value Ralts attack"),
		assert_true(score >= 90000.0, "Runtime TM Evolution granted attack should keep LLM queue ownership even while setup remains visible"),
	])


func test_gardevoir_llm_blocks_tm_evolution_attack_when_active_attacker_can_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(49)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.damage_counters = 40
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace"}]), 0))
	var queued := {
		"id": "granted_attack:-1:evolution",
		"action_id": "granted_attack:-1:evolution",
		"type": "granted_attack",
		"kind": "granted_attack",
		"attack_index": -1,
		"attack_name": "Evolution",
	}
	strategy.set("_llm_queue_turn", 49)
	strategy.set("_llm_decision_tree", {"actions": [queued]})
	strategy.set("_llm_action_queue", [queued])
	var runtime_action := {
		"kind": "granted_attack",
		"attack_index": -1,
		"pokemon": player.active_pokemon,
		"granted_attack_data": {"id": "tm_evolution", "name": "Evolution", "text": "Search your deck for evolution Pokemon."},
	}
	var score := float(strategy.call("score_action_absolute", runtime_action, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, runtime_action, gs, 0)), "TM Evolution granted attack should be blocked when active Drifloon can use a real pressure attack"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_tm_evolution_attack_ref", queued, gs, 0)), "Payload queue repair should reject TM Evolution as terminal attack on an active scaling attacker"),
		assert_true(score <= -1000.0, "Runtime scoring should not let LLM queue ownership force TM Evolution over Balloon Bomb"),
	])


func test_gardevoir_llm_repairs_empty_end_into_visible_tm_evolution_attack_now() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(33)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0)
	strategy.set("_llm_action_catalog", {
		"granted_attack:-1:evolution": {
			"id": "granted_attack:-1:evolution",
			"type": "granted_attack",
			"attack_index": -1,
			"attack_name": "Evolution",
			"pokemon": "Kirlia",
			"position": "active",
		},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	strategy.set("_llm_route_candidates_by_id", {
		"route:attack_now": {
			"route_action_id": "route:attack_now",
			"id": "attack_now",
			"goal": "attack",
			"base_priority": 950,
			"actions": [{"id": "granted_attack:-1:evolution"}],
		},
		"route:preserve_end": {
			"route_action_id": "route:preserve_end",
			"id": "preserve_end",
			"goal": "fallback",
			"base_priority": 100,
			"actions": [{"id": "end_turn"}],
		},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [{"id": "end_turn", "type": "end_turn"}],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("granted_attack:-1:evolution"), "Visible TM Evolution attack-now route should replace empty end_turn"),
		assert_false(ids.has("end_turn"), "The repaired route should not preserve the empty terminal end before the TM Evolution attack"),
	])


func test_gardevoir_llm_repairs_empty_end_into_catalog_attack_when_route_missing() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(34)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	strategy.set("_llm_action_catalog", {
		"granted_attack:-1:tm_evolution": {
			"id": "granted_attack:-1:tm_evolution",
			"type": "granted_attack",
			"attack_index": -1,
			"attack_name": "broken_localized_name",
			"pokemon": "Klefki",
			"position": "active",
		},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	strategy.set("_llm_route_candidates_by_id", {
		"route:preserve_end": {
			"route_action_id": "route:preserve_end",
			"id": "preserve_end",
			"goal": "fallback",
			"base_priority": 100,
			"actions": [{"id": "end_turn"}],
		},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [{"id": "end_turn", "type": "end_turn"}],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("granted_attack:-1:tm_evolution"), "Catalog-visible TM Evolution attack should replace empty end_turn even when route builder omitted attack_now"),
		assert_false(ids.has("end_turn"), "Catalog attack repair should remove the empty terminal end"),
	])


func test_gardevoir_llm_deck_repair_inserts_handoff_retreat_before_end() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(25)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 90, "Ralts"), 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0)
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.damage_counters = 40
	player.bench.append(drifloon_slot)
	strategy.set("_llm_action_catalog", {
		"retreat:bench_0:c10": {"id": "retreat:bench_0:c10", "type": "retreat", "bench_target": "飘飘球", "bench_target_name_en": "Drifloon", "bench_position": "bench_0"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {"actions": [{"id": "end_turn", "type": "end_turn"}]}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("retreat:bench_0:c10"), "Ready bench Drifloon should create a handoff retreat before end_turn"),
		assert_true(ids.find("retreat:bench_0:c10") < ids.find("end_turn"), "Handoff retreat must execute before terminal end_turn so the attack can replace it"),
	])


func test_gardevoir_llm_deck_repair_pays_active_gardevoir_retreat_before_handoff() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(53)
	var player := gs.players[0]
	var gardevoir_slot := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	gardevoir_slot.get_card_data().retreat_cost = 2
	player.active_pokemon = gardevoir_slot
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0)
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.damage_counters = 40
	player.bench.append(drifloon_slot)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	strategy.set("_llm_action_catalog", {
		"use_ability:gardevoir:0": {"id": "use_ability:gardevoir:0", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
		"retreat:bench_0:c10": {"id": "retreat:bench_0:c10", "type": "retreat", "bench_target": "Drifloon", "bench_target_name_en": "Drifloon", "bench_position": "bench_0"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {"actions": [{"id": "end_turn", "type": "end_turn"}]}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	var first_embrace := ids.find("use_ability:gardevoir:0")
	var second_embrace := ids.find("use_ability:gardevoir:0", first_embrace + 1)
	var retreat_index := ids.find("retreat:bench_0:c10")
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn must be blocked while active Gardevoir can be Embrace-retreated into a ready attacker"),
		assert_true(first_embrace >= 0 and second_embrace > first_embrace, "Repair should queue enough Psychic Embrace uses to pay active Gardevoir ex's retreat cost"),
		assert_true(retreat_index > second_embrace, "Handoff retreat must happen after the active retreat cost is actually paid"),
	])


func test_gardevoir_llm_psychic_embrace_targets_active_when_it_completes_handoff_retreat() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(26)
	var player := gs.players[0]
	var gardevoir_slot := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	gardevoir_slot.get_card_data().retreat_cost = 2
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0)
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon_slot.damage_counters = 40
	player.active_pokemon = gardevoir_slot
	player.bench.append(drifloon_slot)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": gardevoir_slot.get_top_card(),
	}
	var active_score: float = float(strategy.call("score_interaction_target", gardevoir_slot, {"id": "embrace_target"}, context))
	var drifloon_score: float = float(strategy.call("score_interaction_target", drifloon_slot, {"id": "embrace_target"}, context))
	return run_checks([
		assert_true(active_score > drifloon_score, "When a ready bench attacker exists, Psychic Embrace should pay active retreat cost before overcharging the attacker"),
		assert_true(active_score >= 88000.0, "Active retreat bridge should receive a dominant Psychic Embrace target score"),
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


func test_gardevoir_llm_blocks_low_value_core_attack_after_engine_online_without_visible_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var kirlia := _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts", "", [], [
		{"name": "Slap", "cost": "PC", "damage": "30"},
	]), 0)
	kirlia.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	kirlia.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = kirlia
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	strategy.set("_llm_action_catalog", {"end_turn": {"id": "end_turn", "type": "end_turn"}})
	var low_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", {}, low_attack, gs, 0)),
		"Once Gardevoir ex and an attacker body exist, Kirlia should not spend the turn on a non-KO 30-damage attack just because no setup action is visible"
	)


func test_gardevoir_llm_allows_core_attack_when_it_takes_active_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(30)
	var player := gs.players[0]
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	], [
		{"name": "Miracle Force", "cost": "PPC", "damage": "190"},
	]), 0)
	gardevoir.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gardevoir.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gardevoir.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = gardevoir
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var opponent_active := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	opponent_active.damage_counters = 180
	gs.players[1].active_pokemon = opponent_active
	var ko_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Miracle Force"}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, ko_attack, gs, 0)), "A non-main attacker should still take a visible active KO"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", ko_attack, gs, 0)), "Visible active KO should be allowed to replace stale end_turn"),
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


func test_gardevoir_llm_blocks_dangerous_ralts_pivot_attack_without_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(23)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70, "", "", [], [
		{"name": "Teleportation Break", "cost": "P", "damage": "10", "text": "Switch this Pokemon with 1 of your Benched Pokemon."},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	strategy.set("_llm_action_catalog", {
		"attack:0:Teleportation Break": {
			"id": "attack:0:Teleportation Break",
			"type": "attack",
			"attack_index": 0,
			"attack_name": "Teleportation Break",
			"interaction_schema": {"switch_target": {"type": "string"}},
		},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var dangerous_attack := {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Teleportation Break",
		"requires_interaction": true,
	}
	strategy.set("_llm_queue_turn", 23)
	strategy.set("_llm_decision_tree", {"actions": [{"id": "attack:0:Teleportation Break"}]})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [{
			"id": "attack:0:Teleportation Break",
			"type": "attack",
			"attack_index": 0,
			"attack_name": "Teleportation Break",
			"interaction_schema": {"switch_target": {"type": "string"}},
		}],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, dangerous_attack, gs, 0)), "Ralts pivot attack should not expose Kirlia when it cannot take a prize or hand off to a ready attacker"),
		assert_true(float(strategy.call("score_action_absolute", dangerous_attack, gs, 0)) <= -1000.0, "Wrapper scoring should hard-block dangerous Ralts pivot attacks instead of letting rules fallback revive them"),
		assert_false(ids.has("attack:0:Teleportation Break"), "Deck repair should remove the dangerous Ralts pivot attack even when no other setup action is visible"),
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


func test_gardevoir_llm_psychic_embrace_and_attach_can_build_active_retreat_bridge() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var gardevoir_cd := _make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	)
	gardevoir_cd.retreat_cost = 2
	var gardevoir_slot := _make_slot(gardevoir_cd, 0)
	var drifloon_slot := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0)
	drifloon_slot.damage_counters = 40
	drifloon_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = gardevoir_slot
	player.bench.append(drifloon_slot)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var context := {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_kind": "ability",
		"pending_effect_card": gardevoir_slot.get_top_card(),
		"all_items": [gardevoir_slot, drifloon_slot],
	}
	var active_score: float = float(strategy.call("score_interaction_target", gardevoir_slot, {"id": "embrace_target"}, context))
	var attacker_score: float = float(strategy.call("score_interaction_target", drifloon_slot, {"id": "embrace_target"}, context))
	var manual_attach := {
		"kind": "attach_energy",
		"card": CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		"target_slot": gardevoir_slot,
	}
	return run_checks([
		assert_true(active_score > attacker_score, "Psychic Embrace should prioritize active Gardevoir ex when energy is needed to retreat into a ready attacker"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, manual_attach, gs, 0)), "Manual Psychic attach to active Gardevoir ex should be allowed when it builds the retreat bridge"),
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


func test_gardevoir_llm_blocks_low_pressure_payoff_attack_when_more_embrace_is_safe() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(24)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "起风", "cost": "CC", "damage": "10"},
		{"name": "气球炸弹", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 120, "", "V"), 1)
	var payoff_attack := {"kind": "attack", "attack_index": 1, "attack_name": "气球炸弹"}
	var embrace_action := {"kind": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, payoff_attack, gs, 0)), "Drifloon should not cash a 60-damage payoff while safe Psychic Embrace can raise pressure"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", embrace_action, gs, 0)), "Psychic Embrace should be allowed to replace stale end_turn while active attacker needs more pressure"),
	])


func test_gardevoir_llm_low_pressure_ready_attacker_is_not_live_terminal_conversion() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(24)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 120, "", "V"), 1)
	var low_pressure_snapshot: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	drifloon.damage_counters = 40
	var pressure_snapshot: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	return run_checks([
		assert_true(bool(low_pressure_snapshot.get("active_gardevoir_attacker_ready", false)), "Two-energy Drifloon is attack-ready"),
		assert_false(bool(low_pressure_snapshot.get("active_gardevoir_attacker_pressure_ready", false)), "60-damage Drifloon should not be treated as a live terminal conversion"),
		assert_false(bool(strategy.call("_deck_snapshot_has_live_terminal_conversion", low_pressure_snapshot)), "Low-pressure ready attacker should not suppress replan"),
		assert_true(bool(pressure_snapshot.get("active_gardevoir_attacker_pressure_ready", false)), "120-damage Drifloon should count as pressure-ready"),
		assert_true(bool(strategy.call("_deck_snapshot_has_live_terminal_conversion", pressure_snapshot)), "Pressure-ready attacker can suppress redundant replans"),
	])


func test_gardevoir_llm_low_pressure_attacker_blocks_generic_end_turn_setup_replacement() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(24)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var embrace_action := {"kind": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"}
	var generic_setup := {"kind": "use_stadium_effect", "card": "Artazon"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", embrace_action, gs, 0)), "Psychic Embrace should replace stale end_turn while active attacker is undercharged"),
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", generic_setup, gs, 0)), "Generic setup should not steal stale end_turn before pressure-building Psychic Embrace"),
	])


func test_gardevoir_llm_embrace_target_bridge_keeps_pressure_on_active_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(25)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "起风", "cost": "CC", "damage": "10"},
		{"name": "气球炸弹", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var picked: Array = strategy.call("_protect_psychic_embrace_target_picks", [scream_tail], [scream_tail, drifloon], {"max_select": 1}, {"game_state": gs, "player_index": 0})
	var first_pick: Variant = picked[0] if picked.size() > 0 else null
	return run_checks([
		assert_eq(first_pick, drifloon, "When active Drifloon needs more pressure, LLM-proposed bench Embrace target should be redirected to active"),
	])


func test_gardevoir_llm_embrace_target_scoring_forces_low_pressure_active_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(26)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 20
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "embrace_target"}
	var active_score := float(strategy.call("score_interaction_target", drifloon, step, context))
	var bench_score := float(strategy.call("score_interaction_target", scream_tail, step, context))
	return run_checks([
		assert_true(active_score > bench_score, "Low-pressure active Drifloon should outrank bench attackers for the next Psychic Embrace"),
		assert_true(bench_score < 0.0, "Bench Embrace target should be blocked until the active attacker reaches pressure damage"),
	])


func test_gardevoir_llm_embrace_target_bridge_forces_unready_active_attacker_conversion() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(26)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var picked: Array = strategy.call("_protect_psychic_embrace_target_picks", [scream_tail], [scream_tail, drifloon], {"max_select": 1}, {"game_state": gs, "player_index": 0})
	var first_pick: Variant = picked[0] if picked.size() > 0 else null
	var active_score := float(strategy.call("score_interaction_target", drifloon, {"id": "embrace_target"}, {"game_state": gs, "player_index": 0}))
	var bench_score := float(strategy.call("score_interaction_target", scream_tail, {"id": "embrace_target"}, {"game_state": gs, "player_index": 0}))
	return run_checks([
		assert_eq(first_pick, drifloon, "If active Drifloon can be converted into an attack line this turn, override an LLM-planned bench Embrace target"),
		assert_true(active_score > bench_score, "Unready active attacker conversion should outrank bench charging"),
		assert_true(bench_score < 0.0, "Bench target should be blocked until the stranded active attacker is charged"),
	])


func test_gardevoir_llm_embrace_continues_when_next_counter_step_kos() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(27)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 40
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 180, "", "V"), 1)
	var needs_more := bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0))
	return assert_true(needs_more, "Do not stop at generic 120 pressure when one more Psychic Embrace creates an immediate KO")


func test_gardevoir_llm_embrace_continues_past_generic_pressure_vs_high_hp_active() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(28)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 40
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var needs_more := bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0))
	return assert_true(needs_more, "Do not stop at 120 generic pressure against a high-HP active when another safe Psychic Embrace improves prize math")


func test_gardevoir_llm_bravery_charm_effective_hp_allows_extra_drifloon_embrace() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(29)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 60
	player.active_pokemon = drifloon
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var needs_more_with_charm := bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0))
	var active_score_with_charm := float(strategy.call("score_interaction_target", drifloon, {"id": "embrace_target"}, {"game_state": gs, "player_index": 0}))
	drifloon.attached_tool = null
	var needs_more_without_charm := bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0))
	var active_score_without_charm := float(strategy.call("score_interaction_target", drifloon, {"id": "embrace_target"}, {"game_state": gs, "player_index": 0}))
	return run_checks([
		assert_true(needs_more_with_charm, "Bravery Charm effective HP should let Drifloon take one more Psychic Embrace to reach a 240-damage KO line"),
		assert_true(active_score_with_charm > 0.0, "Psychic Embrace target scoring should not reject a Bravery Charm Drifloon at raw 10 HP"),
		assert_false(needs_more_without_charm, "Without Bravery Charm, the same 10HP Drifloon must not be over-Embraced"),
		assert_true(active_score_without_charm < 0.0, "Without effective HP support, raw 10HP Drifloon remains an illegal Embrace target"),
	])


func test_gardevoir_llm_munkidori_scores_damage_transfer_source_and_ko_target() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(30)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.damage_counters = 60
	player.active_pokemon = drifloon
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110, "", "", [{"name": "Adrena-Brain", "text": "Move up to 3 damage counters from 1 of your Pokemon to 1 of your opponent's Pokemon."}]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	gardevoir.damage_counters = 20
	player.bench.append(gardevoir)
	var opp_active := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	opp_active.damage_counters = 180
	gs.players[1].active_pokemon = opp_active
	var opp_bench := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	gs.players[1].bench.append(opp_bench)
	var context := {"game_state": gs, "player_index": 0}
	var source_drifloon_score := float(strategy.call("score_interaction_target", drifloon, {"id": "source_pokemon"}, context))
	var source_gardevoir_score := float(strategy.call("score_interaction_target", gardevoir, {"id": "source_pokemon"}, context))
	var target_active_score := float(strategy.call("score_interaction_target", opp_active, {"id": "target_damage_counters"}, context))
	var target_bench_score := float(strategy.call("score_interaction_target", opp_bench, {"id": "target_damage_counters"}, context))
	return run_checks([
		assert_true(source_drifloon_score > source_gardevoir_score, "Munkidori should prefer moving Psychic Embrace damage off the active scaling attacker"),
		assert_true(source_drifloon_score >= 80000.0, "Damaged Drifloon should be a dominant Munkidori source target"),
		assert_true(target_active_score > target_bench_score, "Munkidori should send counters to the opponent target that is within 30 damage of KO"),
		assert_true(target_active_score >= 120000.0, "A Munkidori 30-damage KO target should receive a dominant interaction score"),
	])


func test_gardevoir_llm_scream_tail_attack_targets_low_hp_prize_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(37)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 60
	player.active_pokemon = scream_tail
	var opponent := gs.players[1]
	var iron_hands := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var mew := _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180, "", "ex"), 1)
	mew.damage_counters = 120
	opponent.active_pokemon = iron_hands
	opponent.bench.append(mew)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "target_pokemon"}
	var active_score := float(strategy.call("score_interaction_target", iron_hands, step, context))
	var bench_ko_score := float(strategy.call("score_interaction_target", mew, step, context))
	var embrace_score := float(strategy.call("score_interaction_target", player.active_pokemon, step, {
		"game_state": gs,
		"player_index": 0,
		"pending_effect_ability": "Psychic Embrace",
	}))
	return run_checks([
		assert_true(bench_ko_score > active_score, "Scream Tail should target a visible low-HP two-prize bench KO over non-KO active pressure"),
		assert_true(bench_ko_score > 150000.0, "Scream Tail KO target should get a dominant interaction score"),
		assert_true(embrace_score != bench_ko_score, "Psychic Embrace target_pokemon prompts must not be scored as Scream Tail attack targets"),
	])


func test_gardevoir_llm_munkidori_preserves_ko_ready_scream_tail_damage() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(44)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	player.active_pokemon.damage_counters = 20
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 5:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 50
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	player.bench.append(scream_tail)
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110, "", "", [{"name": "Adrena-Brain", "text": "Move damage counters."}]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	var miraidon := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	miraidon.damage_counters = 130
	gs.players[1].active_pokemon = miraidon
	var context := {"game_state": gs, "player_index": 0}
	var scream_score := float(strategy.call("score_interaction_target", scream_tail, {"id": "source_pokemon"}, context))
	var gardevoir_score := float(strategy.call("score_interaction_target", player.active_pokemon, {"id": "source_pokemon"}, context))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_should_preserve_attacker_damage_for_attack", scream_tail, gs, 0)), "Scream Tail already has enough self-damage to KO the active and should keep its damage counters"),
		assert_true(scream_score < 0.0, "Munkidori should not drain damage from the KO-ready Scream Tail before the handoff attack"),
		assert_true(gardevoir_score > scream_score, "If Munkidori is used, it should prefer non-attacker damage over stripping the KO attacker"),
	])


func test_gardevoir_llm_munkidori_does_not_drain_active_scream_tail_before_pressure_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(53)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 5:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 50
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	player.active_pokemon = scream_tail
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110, "", "", [{"name": "Adrena-Brain", "text": "Move damage counters."}]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	gardevoir.damage_counters = 40
	player.bench.append(gardevoir)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var context := {"game_state": gs, "player_index": 0}
	var scream_score := float(strategy.call("score_interaction_target", scream_tail, {"id": "source_pokemon"}, context))
	var gardevoir_score := float(strategy.call("score_interaction_target", gardevoir, {"id": "source_pokemon"}, context))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_should_preserve_attacker_damage_for_attack", scream_tail, gs, 0)), "Active Scream Tail should keep self-damage when Roaring Scream is the live pressure attack and Munkidori is not taking a prize"),
		assert_true(scream_score < 0.0, "Munkidori should not reduce active Scream Tail's upcoming Roaring Scream damage"),
		assert_true(gardevoir_score > scream_score, "Munkidori should move counters from a non-attacking damaged support instead"),
	])


func test_gardevoir_llm_blocks_munkidori_when_only_source_is_active_drifloon_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(57)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x", "text": "This attack does 30 damage for each damage counter on this Pokemon."},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	drifloon.damage_counters = 40
	player.active_pokemon = drifloon
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110, "", "", [{"name": "Adrena-Brain", "text": "Move damage counters."}]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var context := {"game_state": gs, "player_index": 0}
	var source_score := float(strategy.call("score_interaction_target", drifloon, {"id": "source_pokemon"}, context))
	var protected_plan: Array = strategy.call("_protect_gardevoir_damage_counter_source_picks", [drifloon], [drifloon], {"id": "source_pokemon"}, context)
	var runtime_action := {"kind": "use_ability", "pokemon": munkidori, "ability_index": 0, "ability": "Adrena-Brain"}
	var payload_ref := {"id": "use_ability:bench_0:0", "type": "use_ability", "pokemon": "Munkidori", "ability": "Adrena-Brain"}
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_should_preserve_attacker_damage_for_attack", drifloon, gs, 0)), "Active Drifloon should preserve damage when Munkidori cannot take a prize"),
		assert_true(source_score < 0.0, "Munkidori source scoring must reject stripping active Drifloon pressure damage"),
		assert_true(protected_plan.is_empty(), "Interaction bridge must not fall back to a planned active Drifloon source when it is strategically harmful"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, runtime_action, gs, 0)), "Runtime should block Munkidori ability when the only source is active Drifloon pressure damage"),
		assert_true(bool(strategy.call("_is_bad_gardevoir_payload_action_ref", payload_ref, gs, 0)), "Prompt payload should hide the same bad Munkidori route"),
	])


func test_gardevoir_llm_munkidori_preserves_active_attacker_damage_when_embrace_can_unlock_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(54)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 40
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	player.active_pokemon = scream_tail
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110, "", "", [{"name": "Adrena-Brain", "text": "Move damage counters."}]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	gardevoir.damage_counters = 30
	player.bench.append(gardevoir)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var context := {"game_state": gs, "player_index": 0}
	var scream_score := float(strategy.call("score_interaction_target", scream_tail, {"id": "source_pokemon"}, context))
	var gardevoir_score := float(strategy.call("score_interaction_target", gardevoir, {"id": "source_pokemon"}, context))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_should_preserve_attacker_damage_for_attack", scream_tail, gs, 0)), "Do not drain active Scream Tail when one Psychic Embrace can unlock the payoff attack"),
		assert_true(scream_score < 0.0, "Munkidori should not steal damage counters from an active attacker that is about to be charged"),
		assert_true(gardevoir_score > scream_score, "Munkidori can still use damage from non-attacking support instead"),
	])


func test_gardevoir_llm_ready_scream_tail_attacks_instead_of_greedy_extra_embrace() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(34)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	for i: int in 4:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 60
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	var payoff_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	var low_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", 34)
	strategy.set("_llm_decision_tree", {"actions": [end_ref]})
	strategy.set("_llm_action_queue", [end_ref])
	var payoff_score := float(strategy.call("score_action_absolute", payoff_attack, gs, 0))
	var low_score := float(strategy.call("score_action_absolute", low_attack, gs, 0))
	return run_checks([
		assert_false(bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0)), "A 120-damage Scream Tail should attack now when the next Embrace still does not KO"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", payoff_attack, gs, 0)), "Ready Scream Tail payoff attack should replace stale end_turn"),
		assert_true(payoff_score >= 90000.0, "Payoff attack should keep LLM queue ownership over terminal end_turn"),
		assert_true(low_score <= -1000.0, "Weak first attack should still be blocked"),
	])


func test_gardevoir_llm_serialized_scream_tail_slap_is_blocked_when_payoff_attack_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(52)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 6:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 70
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 1)
	var serialized_slap := {"id": "attack:0:巴掌", "type": "attack", "attack_name": "巴掌"}
	var serialized_roar := {"id": "attack:1:凶暴吼叫", "type": "attack", "attack_name": "凶暴吼叫", "requires_interaction": true}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, serialized_slap, gs, 0)), "Serialized Scream Tail Slap must be blocked even when attack_index is only encoded in the action id"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, serialized_roar, gs, 0)), "Serialized Roaring Scream should remain legal as the payoff attack"),
	])


func test_gardevoir_llm_ready_scream_tail_does_not_end_on_munkidori_followup_damage() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(47)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 4:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 50
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110, "", "", [{"name": "Adrena-Brain", "text": "Move up to 3 damage counters from 1 of your Pokemon to 1 of your opponent's Pokemon."}]), 0))
	var raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	raikou.damage_counters = 90
	gs.players[1].active_pokemon = raikou
	var payoff_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", 47)
	strategy.set("_llm_decision_tree", {"actions": [end_ref]})
	strategy.set("_llm_action_queue", [end_ref])
	var attack_score := float(strategy.call("score_action_absolute", payoff_attack, gs, 0))
	var end_score := float(strategy.call("score_action_absolute", end_ref, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_active_is_productive_ready_gardevoir_attacker", player, gs, 0)), "Scream Tail for 100 into a 110HP active should be treated as productive Munkidori-followup pressure"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn should be blocked while productive Scream Tail damage is legal"),
		assert_true(attack_score >= 90000.0, "Ready Scream Tail payoff attack should replace stale end_turn queue ownership"),
		assert_true(end_score <= -1000.0, "Terminal end_turn should lose to the ready Scream Tail pressure attack"),
	])


func test_gardevoir_llm_active_ko_ready_scream_tail_blocks_optional_churn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(48)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	for i: int in 2:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 40
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts", "", [{"name": "Refinement", "text": "Discard a card and draw 2."}]), 0))
	var raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	raikou.damage_counters = 120
	gs.players[1].active_pokemon = raikou
	var payoff_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	var refinement := {"kind": "use_ability", "ability_name": "Refinement", "ability_source_name": "Kirlia"}
	var nest_ball := {"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball", "Item"), 0)}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", 48)
	strategy.set("_llm_decision_tree", {"actions": [end_ref]})
	strategy.set("_llm_action_queue", [end_ref])
	var attack_score := float(strategy.call("score_action_absolute", payoff_attack, gs, 0))
	var refinement_score := float(strategy.call("score_action_absolute", refinement, gs, 0))
	var nest_score := float(strategy.call("score_action_absolute", nest_ball, gs, 0))
	var end_score := float(strategy.call("score_action_absolute", end_ref, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_active_gardevoir_attacker_kos_now", gs, 0)), "Scream Tail should recognize the current active KO before optional churn"),
		assert_true(attack_score >= 90000.0, "The payoff attack should replace stale end_turn once KO is ready"),
		assert_true(refinement_score <= -1000.0, "Kirlia churn must not continue after active KO is ready"),
		assert_true(nest_score <= -1000.0, "Optional setup search must not continue after active KO is ready"),
		assert_true(end_score <= -1000.0, "End turn must remain blocked after active KO is ready"),
	])


func test_gardevoir_llm_scream_tail_slap_not_treated_as_scaling_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(39)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 40
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	var raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	raikou.damage_counters = 120
	gs.players[1].active_pokemon = raikou
	var slap := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var roar := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream", "requires_interaction": true}
	return run_checks([
		assert_false(bool(strategy.call("_gardevoir_runtime_attack_kos_opponent", scream_tail, slap, gs, 0)), "Scream Tail's 30-damage first attack must not inherit the scaling attack's KO estimate"),
		assert_true(bool(strategy.call("_gardevoir_runtime_attack_kos_opponent", scream_tail, roar, gs, 0)), "Scream Tail's scaling second attack should be recognized as the KO attack"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, slap, gs, 0)), "Queued Slap should be blocked when Roaring Scream is available for the payoff"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, roar, gs, 0)), "Queued Roaring Scream should remain executable"),
	])


func test_gardevoir_llm_blocks_zero_damage_scream_tail_payoff_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(45)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 5:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 1)
	var roar := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, roar, gs, 0)), "Scream Tail's scaling attack should be blocked when it has no damage counters to convert"),
	])


func test_gardevoir_llm_blocks_scream_tail_slap_when_ready_bench_attacker_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(40)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Balloon Bomb", "cost": "P", "damage": "30×", "text": "This attack does 30 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 4:
		drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 60
	player.bench.append(drifloon)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var slap := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var retreat := {"kind": "retreat", "bench_target": drifloon}
	var end_turn := {"kind": "end_turn"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, slap, gs, 0)), "Do not spend the turn on Scream Tail's 30-damage attack while a ready Drifloon handoff exists"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, retreat, gs, 0)), "Retreat into the ready bench attacker should remain legal while active is low-pressure"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", retreat, gs, 0)), "Ready bench handoff should replace stale end_turn before a weak active attack"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn should be blocked while a ready bench attacker handoff exists"),
	])


func test_gardevoir_llm_blocks_stale_retreat_after_active_attacker_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(41)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 80
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	var kirlia := _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.bench.append(kirlia)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	var stale_retreat := {"kind": "retreat", "bench_target": kirlia}
	return run_checks([
		assert_true(bool(strategy.call("_active_is_pressure_ready_gardevoir_attacker", player, gs, 0)), "Scream Tail with damage and enough energy should be treated as pressure-ready"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, stale_retreat, gs, 0)), "After handoff succeeds, stale extra retreat queue entries should be blocked"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn should be blocked while the active pressure attacker can still attack"),
	])


func test_gardevoir_llm_send_out_prefers_ready_pressure_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(44)
	var player := gs.players[0]
	player.active_pokemon = null
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 80
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	var empty_drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	player.bench.append(empty_drifloon)
	player.bench.append(scream_tail)
	player.bench.append(gardevoir)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	var context := {"game_state": gs, "player_index": 0, "all_items": player.bench}
	var step := {"id": "send_out"}
	var scream_score := float(strategy.call("score_handoff_target", scream_tail, step, context))
	var drifloon_score := float(strategy.call("score_handoff_target", empty_drifloon, step, context))
	var gardevoir_score := float(strategy.call("score_handoff_target", gardevoir, step, context))
	return run_checks([
		assert_true(scream_score > 200000.0, "Ready Bravery Charm Scream Tail should be an urgent pressure send-out"),
		assert_true(scream_score > drifloon_score, "Do not send out an empty Drifloon over a ready Scream Tail"),
		assert_true(scream_score > gardevoir_score, "Do not send out Gardevoir ex over an already pressure-ready attacker"),
	])


func test_gardevoir_llm_send_out_prefers_gardevoir_ex_attack_bridge_over_unpowered_support() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(44)
	var player := gs.players[0]
	player.active_pokemon = null
	var gardevoir := _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110, "", "", [
		{"name": "Adrena-Brain", "text": "Move up to 3 damage counters."}
	]), 0)
	var ralts := _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(gardevoir)
	player.bench.append(munkidori)
	player.bench.append(ralts)
	for i: int in 3:
		player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	raikou.damage_counters = 120
	gs.players[1].active_pokemon = raikou
	var context := {"game_state": gs, "player_index": 0, "all_items": player.bench}
	var step := {"id": "send_out"}
	var gardevoir_score := float(strategy.call("score_handoff_target", gardevoir, step, context))
	var munkidori_score := float(strategy.call("score_handoff_target", munkidori, step, context))
	var ralts_score := float(strategy.call("score_handoff_target", ralts, step, context))
	return run_checks([
		assert_true(gardevoir_score > 160000.0, "Gardevoir ex with discard Psychic should be recognized as an immediate Embrace -> Miracle Force send-out bridge"),
		assert_true(gardevoir_score > munkidori_score, "Do not send out unpowered Munkidori when Gardevoir ex can take the active KO next turn"),
		assert_true(gardevoir_score > ralts_score, "Do not send out a passive core basic over the Gardevoir ex attack bridge"),
	])


func test_gardevoir_llm_blocks_end_turn_without_active_queue_when_bench_attacker_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(46)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 5:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 50
	scream_tail.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	player.bench.append(scream_tail)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var miraidon := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	miraidon.damage_counters = 130
	gs.players[1].active_pokemon = miraidon
	var end_score := float(strategy.call("score_action_absolute", {"kind": "end_turn", "id": "end_turn"}, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn should be blocked while an active retreat bridge can hand off to a KO-ready bench attacker"),
		assert_true(end_score <= -1000.0, "End turn should stay blocked even after an LLM queue escape or cleared plan"),
	])


func test_gardevoir_llm_munkidori_ability_replaces_stale_end_turn_for_damage_transfer() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(36)
	var player := gs.players[0]
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	gardevoir.damage_counters = 180
	player.active_pokemon = gardevoir
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "D", 110, "", "", [{"name": "Adrena-Brain", "text": "Move up to 3 damage counters from 1 of your Pokemon to 1 of your opponent's Pokemon."}]), 0)
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	player.bench.append(munkidori)
	var raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	raikou.damage_counters = 180
	gs.players[1].active_pokemon = raikou
	strategy.set("_llm_action_catalog", {
		"use_ability:bench_0:0": {"id": "use_ability:bench_0:0", "type": "use_ability", "pokemon": "Munkidori", "ability": "Adrena-Brain"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", 36)
	strategy.set("_llm_decision_tree", {"actions": [end_ref]})
	strategy.set("_llm_action_queue", [end_ref])
	var munkidori_action := {"kind": "use_ability", "pokemon": munkidori, "ability_index": 0, "ability": "Adrena-Brain"}
	var score := float(strategy.call("score_action_absolute", munkidori_action, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_munkidori_has_damage_transfer_value", gs, 0)), "Munkidori should see a valuable damage-transfer window when own damage and an opponent target exist"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", munkidori_action, gs, 0)), "Munkidori ability should replace stale end_turn instead of wasting a KO setup"),
		assert_true(score >= 90000.0, "Munkidori ability should receive queue ownership through end_turn replacement"),
	])


func test_gardevoir_llm_embrace_charges_active_munkidori_for_low_hp_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(46)
	var player := gs.players[0]
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110, "", "", [
		{"name": "Adrena-Brain", "text": "Move damage counters."},
	], [
		{"name": "Mind Bend", "cost": "PC", "damage": "60"},
	]), 0)
	player.active_pokemon = munkidori
	var gardevoir := _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0)
	player.bench.append(gardevoir)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	raikou.damage_counters = 180
	gs.players[1].active_pokemon = raikou
	strategy.set("_llm_action_catalog", {
		"use_ability:bench_0:0": {"id": "use_ability:bench_0:0", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var end_ref := {"id": "end_turn", "type": "end_turn"}
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {"actions": [end_ref]}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	var embrace_action := {"kind": "use_ability", "pokemon": gardevoir, "ability": "Psychic Embrace"}
	var munkidori_target_score := float(strategy.call("score_interaction_target", munkidori, {"id": "embrace_target"}, {"game_state": gs, "player_index": 0, "pending_effect_card": gardevoir.get_top_card()}))
	var gardevoir_target_score := float(strategy.call("score_interaction_target", gardevoir, {"id": "embrace_target"}, {"game_state": gs, "player_index": 0, "pending_effect_card": gardevoir.get_top_card()}))
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_active_embrace_attack_setup_needed", gs, 0)), "Active Munkidori should be recognized as an Embrace-charge KO bridge against a 20 HP active"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn must be blocked while active Munkidori can be charged for KO"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", embrace_action, gs, 0)), "Psychic Embrace should replace stale end_turn when it charges active Munkidori for KO"),
		assert_eq(ids.count("use_ability:bench_0:0"), 2, "Repair should insert enough Psychic Embrace uses to pay Munkidori's PC attack cost"),
		assert_true(munkidori_target_score > gardevoir_target_score, "Psychic Embrace target scoring should force the active Munkidori in this KO window"),
	])


func test_gardevoir_llm_active_gardevoir_attacks_after_embrace_when_no_attacker_body() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(18)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	for i: int in 3:
		player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var attack := {"kind": "attack", "attack_index": 0, "attack_name": "Miracle Force", "pokemon": player.active_pokemon}
	var snapshot: Dictionary = strategy.call("make_llm_runtime_snapshot", gs, 0)
	var remaining: Array[Dictionary] = [{"id": "end_turn", "type": "end_turn"}]
	var pruned: Array = strategy.call("_deck_pruned_live_terminal_conversion_queue", snapshot, remaining)
	return run_checks([
		assert_true(bool(strategy.call("_gardevoir_active_core_attack_ready", gs, 0)), "Active Gardevoir ex should be a fallback attacker after Psychic Embrace pays Miracle Force and no real attacker body exists"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn must be blocked while active Gardevoir ex can attack for real pressure"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", attack, gs, 0)), "Ready active Gardevoir ex attack should replace stale end_turn when no Drifloon/Scream Tail exists"),
		assert_eq(str((pruned[0] as Dictionary).get("route_goal", "")), "active_gardevoir_core_emergency_conversion", "Terminal queue pruning should convert stale end_turn to active Gardevoir attack"),
	])


func test_gardevoir_llm_scream_tail_bench_ko_blocks_tm_evolution_terminal() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(47)
	var player := gs.players[0]
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110, "", "", [
		{"name": "Adrena-Brain", "text": "Move damage counters."},
	], [
		{"name": "Mind Bend", "cost": "PC", "damage": "60"},
	]), 0)
	munkidori.attached_tool = CardInstance.create(_make_trainer_cd("Technical Machine: Evolution", "Pokemon Tool"), 0)
	player.active_pokemon = munkidori
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0))
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack may target 1 of your opponent's Pokemon and does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	for i: int in 3:
		scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 40
	player.bench.append(scream_tail)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var damaged_miraidon := _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	damaged_miraidon.damage_counters = 150
	gs.players[1].bench.append(damaged_miraidon)
	var tm_attack := {"kind": "granted_attack", "attack_name": "Evolution", "card": "Technical Machine: Evolution"}
	var bad_end := {"id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	return run_checks([
		assert_true(bool(strategy.call("_slot_has_pressure_ready_gardevoir_attack", scream_tail, gs, 0)), "Scream Tail should be pressure-ready when its Roaring Scream can KO a visible bench Pokemon"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, tm_attack, gs, 0)), "TM Evolution terminal should be blocked when a bench Scream Tail can take a prize"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn must remain blocked while Scream Tail can take the visible bench KO"),
		assert_true(float(strategy.call("score_action_absolute", bad_end, gs, 0)) <= -1000.0, "Stale end_turn should lose to the visible Scream Tail prize route"),
	])


func test_gardevoir_llm_scream_tail_continues_embrace_for_visible_bench_ko() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(52)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": "", "text": "This attack may target 1 of your opponent's Pokemon and does 20 damage for each damage counter on this Pokemon."},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 60
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [
		{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."},
	]), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180, "", "ex"), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 1))
	var low_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	return run_checks([
		assert_false(bool(strategy.call("_gardevoir_slot_can_take_visible_prize", scream_tail, gs, 0)), "Current 120-damage Scream Tail should not see a visible KO yet"),
		assert_true(bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0)), "Scream Tail should keep using Psychic Embrace when the next damage step reaches a visible bench KO"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, low_attack, gs, 0)), "The 120-damage attack should be blocked until the visible bench KO threshold is reached"),
	])


func test_gardevoir_llm_discard_bridge_preserves_munkidori_and_darkness_after_engine_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(37)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var munkidori_a := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var munkidori_b := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var dark := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var artazon := CardInstance.create(_make_trainer_cd("Artazon", "Stadium"), 0)
	player.hand.append_array([munkidori_a, munkidori_b, dark, iono, artazon])
	var picked: Array = strategy.call("_protect_gardevoir_discard_picks", [munkidori_a, munkidori_b], [munkidori_a, munkidori_b, dark, iono, artazon], {"id": "discard_cards", "max_select": 2}, {"game_state": gs, "player_index": 0})
	var picked_names := _card_names(picked)
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", munkidori_a.card_data, gs, 0)), "Munkidori in hand should be protected once Gardevoir engine and an attacker route are online"),
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", dark.card_data, gs, 0)), "The Darkness Energy needed to activate Munkidori should also be protected"),
		assert_false(picked_names.has("Munkidori"), "Discard fallback should not spend Munkidori when safer discard cards exist"),
		assert_false(picked_names.has("Darkness Energy"), "Discard fallback should preserve the Munkidori activation energy"),
	])


func test_gardevoir_llm_empty_discard_plan_preserves_backup_attacker_package() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(42)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var scream_tail := CardInstance.create(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	var munkidori := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var charm := CardInstance.create(_make_trainer_cd("Bravery Charm", "Pokemon Tool"), 0)
	player.hand.append_array([scream_tail, munkidori, psychic, charm])
	var queue_ref := {"id": "play_trainer:c40", "action_id": "play_trainer:c40", "type": "play_trainer", "card": "Ultra Ball"}
	strategy.set("_llm_queue_turn", 42)
	strategy.set("_llm_decision_tree", {"actions": [queue_ref]})
	strategy.set("_llm_action_queue", [queue_ref])
	var picked: Array = strategy.call("pick_interaction_items", [scream_tail, munkidori, psychic, charm], {"id": "discard_cards", "max_select": 2}, {"game_state": gs, "player_index": 0})
	var picked_names := _card_names(picked)
	return run_checks([
		assert_eq(2, picked.size(), "Ultra Ball fallback should still provide the required two discard cards"),
		assert_false(picked_names.has("Scream Tail"), "When only one attacker body is on board, empty LLM discard plans must preserve Scream Tail as the backup attacker"),
		assert_false(picked_names.has("Munkidori"), "When Gardevoir engine is online, empty LLM discard plans must preserve Munkidori for damage-counter conversion"),
		assert_true(picked_names.has("Psychic Energy"), "Psychic Energy is the safest discard fuel in this forced discard window"),
		assert_true(picked_names.has("Bravery Charm"), "A backup Charm is less critical than losing the only follow-up attacker or Munkidori package"),
	])


func test_gardevoir_llm_blocks_costly_ultra_ball_when_poffin_can_find_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(43)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var ultra := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item"), 0)
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin", "Item"), 0)
	var dark := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	player.hand.append_array([ultra, poffin, dark])
	player.deck.append(CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0))
	var ultra_action := {"kind": "play_trainer", "card": ultra}
	var poffin_action := {"kind": "play_trainer", "card": poffin}
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", dark.card_data, gs, 0)), "Darkness Energy should be route-critical once Gardevoir is online and Munkidori remains accessible"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, ultra_action, gs, 0)), "Do not pay Ultra Ball's discard cost when Buddy-Buddy Poffin can find the attacker without spending Munkidori's Darkness Energy"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, poffin_action, gs, 0)), "Buddy-Buddy Poffin should remain playable as the low-cost attacker search"),
	])


func test_gardevoir_llm_blocks_premature_super_rod_before_attacker_discard() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(49)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts", "", [{"name": "Refinement", "text": "Discard and draw."}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	for i: int in 9:
		player.deck.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var super_rod_card := CardInstance.create(_make_trainer_cd("Super Rod", "Item"), 0)
	var super_rod_action := {"kind": "play_trainer", "card": super_rod_card}
	var super_rod_ref := {"id": "play_trainer:c12", "type": "play_trainer", "card": "Super Rod"}
	var premature_score := float(strategy.call("score_action_absolute", super_rod_action, gs, 0))
	var premature_payload_blocked := bool(strategy.call("_is_bad_gardevoir_premature_recovery_ref", super_rod_ref, gs, 0))
	var premature_discard_protected := bool(strategy.call("_is_gardevoir_protected_discard_card", super_rod_card.card_data, gs, 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	var live_score := float(strategy.call("score_action_absolute", super_rod_action, gs, 0))
	var live_payload_blocked := bool(strategy.call("_is_bad_gardevoir_premature_recovery_ref", super_rod_ref, gs, 0))
	var live_discard_protected := bool(strategy.call("_is_gardevoir_protected_discard_card", super_rod_card.card_data, gs, 0))
	var night_stretcher := CardInstance.create(_make_trainer_cd("Night Stretcher", "Item"), 0)
	var night_stretcher_protected := bool(strategy.call("_is_gardevoir_protected_discard_card", night_stretcher.card_data, gs, 0))
	return run_checks([
		assert_true(premature_score <= -1000.0, "Super Rod should be preserved when no attacker body is in discard and deck count is still safe"),
		assert_true(premature_payload_blocked, "Prompt payload should hide premature Super Rod routes before attacker recovery matters"),
		assert_true(premature_discard_protected, "Super Rod should not be thrown away as discard fuel before its recovery window"),
		assert_true(live_score > -1000.0, "Super Rod should become available once Drifloon/Scream Tail recovery matters"),
		assert_false(live_payload_blocked, "Prompt payload should keep Super Rod visible once an attacker body is in discard"),
		assert_true(live_discard_protected, "Live Super Rod should be protected from Refinement/Ultra Ball discard costs"),
		assert_true(night_stretcher_protected, "Night Stretcher should be protected when an attacker body is waiting in discard"),
	])


func test_gardevoir_llm_reorders_super_rod_before_iono_when_recovering_attackers() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(50)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var iono := {"id": "play_trainer:c41", "type": "play_trainer", "card": "Iono"}
	var super_rod := {"id": "play_trainer:c12", "type": "play_trainer", "card": "Super Rod"}
	var attack := {"id": "attack:1:roaring_scream", "type": "attack", "attack_name": "Roaring Scream"}
	var actions: Array[Dictionary] = [iono, super_rod, attack]
	var ordered: Array = strategy.call("_gardevoir_reorder_super_rod_before_shuffle_draw", actions, gs, 0)
	var no_recovery_state := _make_game_state(51)
	no_recovery_state.players[0].active_pokemon = player.active_pokemon
	no_recovery_state.players[0].bench.append(player.bench[0])
	var unchanged: Array = strategy.call("_gardevoir_reorder_super_rod_before_shuffle_draw", actions, no_recovery_state, 0)
	return run_checks([
		assert_eq("play_trainer:c12", str((ordered[0] as Dictionary).get("id", "")), "Super Rod must happen before Iono so recovered attackers can be drawn this turn"),
		assert_eq("play_trainer:c41", str((ordered[1] as Dictionary).get("id", "")), "Iono should remain immediately after the recovery shuffle"),
		assert_eq("play_trainer:c41", str((unchanged[0] as Dictionary).get("id", "")), "Do not reorder Super Rod before draw when no attacker body is in discard"),
	])


func test_gardevoir_llm_reorders_super_rod_before_artazon_when_recovering_attackers() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(52)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Flutter Mane", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var artazon := {"id": "use_stadium_effect:artazon", "type": "use_stadium_effect", "card": "Artazon"}
	var attach_dark := {"id": "attach_energy:c31:bench_2", "type": "attach_energy", "card": "Darkness Energy", "target": "bench_2"}
	var super_rod := {"id": "play_trainer:c12", "type": "play_trainer", "card": "Super Rod"}
	var iono := {"id": "play_trainer:c41", "type": "play_trainer", "card": "Iono"}
	var actions: Array[Dictionary] = [artazon, attach_dark, super_rod, iono]
	var ordered: Array = strategy.call("_gardevoir_reorder_super_rod_before_shuffle_draw", actions, gs, 0)
	return run_checks([
		assert_eq("play_trainer:c12", str((ordered[0] as Dictionary).get("id", "")), "Super Rod must recover Drifloon/Scream Tail before Artazon consumes the deck-search window"),
		assert_eq("use_stadium_effect:artazon", str((ordered[1] as Dictionary).get("id", "")), "Artazon should run after recovery so it can find the recovered attacker"),
		assert_eq("attach_energy:c31:bench_2", str((ordered[2] as Dictionary).get("id", "")), "Non-search setup should keep relative order after the recovery/search pair"),
	])


func test_gardevoir_llm_no_plan_refinement_discards_duplicate_munkidori_before_darkness() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(47)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	var munkidori_a := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var munkidori_b := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var dark := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var kirlia := CardInstance.create(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.hand.append_array([munkidori_a, dark, munkidori_b, kirlia])
	strategy.set("_llm_queue_turn", -1)
	strategy.set("_llm_decision_tree", {})
	strategy.set("_llm_action_queue", [])
	var picked: Array = strategy.call("pick_interaction_items", [munkidori_a, dark, munkidori_b, kirlia], {"id": "discard_card", "max_select": 1}, {"game_state": gs, "player_index": 0})
	var picked_names := _card_names(picked)
	return run_checks([
		assert_eq(1, picked.size(), "Kirlia Refinement fallback should still pick one discard card without an active LLM queue"),
		assert_true(picked_names.has("Munkidori"), "When two Munkidori are in hand, discard the duplicate before the only Darkness Energy"),
		assert_false(picked_names.has("Darkness Energy"), "Preserve the only Darkness Energy needed to activate the remaining Munkidori"),
	])


func test_gardevoir_llm_discard_bridge_preserves_munkidori_and_darkness_when_kirlia_can_convert() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(38)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var munkidori := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "D", 110), 0)
	var dark := CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0)
	var drifloon := CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var artazon := CardInstance.create(_make_trainer_cd("Artazon", "Stadium"), 0)
	player.hand.append_array([munkidori, dark, drifloon, iono, artazon])
	var picked: Array = strategy.call("_protect_gardevoir_discard_picks", [munkidori, dark], [munkidori, dark, drifloon, iono, artazon], {"id": "discard_cards", "max_select": 2}, {"game_state": gs, "player_index": 0})
	var picked_names := _card_names(picked)
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", munkidori.card_data, gs, 0)), "Munkidori should be protected once Kirlia can imminently convert into the Gardevoir engine"),
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", dark.card_data, gs, 0)), "Darkness Energy should be protected with Kirlia plus a visible Munkidori route"),
		assert_false(picked_names.has("Munkidori"), "Discard fallback should not spend the pending Munkidori package before Gardevoir ex hits board"),
		assert_false(picked_names.has("Darkness Energy"), "Discard fallback should not spend the pending Darkness Energy before Munkidori can come online"),
	])


func test_gardevoir_llm_search_bridge_does_not_fill_last_slot_with_passive_support() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(27)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Flutter Mane", "Basic", "P", 90), 0))
	var munkidori := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "search_targets", "max_select": 1}
	var picked: Array = strategy.call("_protect_gardevoir_search_picks", [munkidori], [munkidori], step, context)
	var score := float(strategy.call("score_interaction_target", munkidori, step, context))
	return run_checks([
		assert_true(picked.is_empty(), "When only one bench slot remains and attacker continuity is low, Artazon/Poffin should not fill it with passive support"),
		assert_true(score < 0.0, "Passive support search target should score negative in the last-slot continuity window"),
	])


func test_gardevoir_llm_search_bridge_blocks_localized_duplicate_munkidori() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(27)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var localized_existing := _make_pokemon_cd("愿增猿", "Basic", "P", 110)
	localized_existing.name_en = ""
	player.bench.append(_make_slot(localized_existing, 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var localized_target_cd := _make_pokemon_cd("愿增猿", "Basic", "P", 110)
	localized_target_cd.name_en = ""
	var localized_munkidori := CardInstance.create(localized_target_cd, 0)
	var context := {"game_state": gs, "player_index": 0}
	var step := {"id": "search_targets", "max_select": 1}
	var picked: Array = strategy.call("_protect_gardevoir_search_picks", [localized_munkidori], [localized_munkidori], step, context)
	var score := float(strategy.call("score_interaction_target", localized_munkidori, step, context))
	return run_checks([
		assert_true(picked.is_empty(), "Localized duplicate Munkidori should be filtered from Nest Ball/Poffin target selection"),
		assert_true(score < 0.0, "Localized Munkidori should still match support-name guards"),
	])


func test_gardevoir_llm_artazon_does_not_auto_fill_duplicate_munkidori() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(28)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Ralts", "Basic", "P", 70), 0))
	var duplicate_munkidori := CardInstance.create(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	player.deck.append(duplicate_munkidori)
	var artazon := CardInstance.create(_make_trainer_cd("Artazon", "Stadium"), 0)
	var action := {"kind": "use_stadium_effect", "type": "use_stadium_effect", "card": artazon}
	var step := {"id": "artazon_pokemon", "max_select": 1}
	var context := {"game_state": gs, "player_index": 0}
	var picked: Array = strategy.call("_protect_gardevoir_search_picks", [duplicate_munkidori], [duplicate_munkidori], step, context)
	var score := float(strategy.call("score_interaction_target", duplicate_munkidori, step, context))
	return run_checks([
		assert_true(picked.is_empty(), "Artazon interaction should not select a duplicate Munkidori when only one bench slot remains"),
		assert_true(score < 0.0, "Artazon Munkidori duplicate should score negative through the same search bridge"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, action, gs, 0)), "Runtime Artazon action should be blocked when its only visible target is a bad duplicate support Pokemon"),
	])


func test_gardevoir_llm_discard_bridge_preserves_backup_attacker_after_engine_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(26)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts", "", [{"name": "Refinement", "text": "Discard one card and draw two."}]), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0))
	var scream_tail := CardInstance.create(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 5)
	var counter_catcher := CardInstance.create(_make_trainer_cd("Counter Catcher", "Item"), 2)
	player.hand.append(scream_tail)
	player.hand.append(counter_catcher)
	var picked: Array = strategy.call("_protect_gardevoir_discard_picks", [scream_tail], [scream_tail, counter_catcher], {"id": "discard_card", "max_select": 1}, {"game_state": gs, "player_index": 0})
	var first_pick: Variant = picked[0] if picked.size() > 0 else null
	return run_checks([
		assert_true(bool(strategy.call("_is_gardevoir_protected_discard_card", scream_tail.card_data, gs, 0)), "Second attacker in hand should be protected while only one attacker body is on board"),
		assert_eq(first_pick, counter_catcher, "Discard bridge should replace a planned backup attacker discard with a non-critical card"),
	])


func test_gardevoir_llm_filters_attacker_first_attack_when_payoff_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(23)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 40
	player.active_pokemon = scream_tail
	var low_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var payload := {
		"legal_actions": [
			{"id": "attack:0:Slap", "type": "attack", "attack_index": 0, "attack_name": "Slap"},
			{"id": "attack:1:Roaring Scream", "type": "attack", "attack_index": 1, "attack_name": "Roaring Scream"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {"attack": ["attack:0:Slap", "attack:1:Roaring Scream"], "fallback": ["end_turn"]},
		"candidate_routes": [
			{"id": "attack_now", "goal": "attack", "actions": [{"id": "attack:0:Slap"}]},
		],
		"turn_tactical_facts": {
			"ready_attacks": [{"id": "attack:0:Slap"}, {"id": "attack:1:Roaring Scream"}],
			"attack_quality_by_action_id": {"attack:0:Slap": {}, "attack:1:Roaring Scream": {}},
		},
	}
	var filtered: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids := _action_ids(filtered.get("legal_actions", []))
	var route_count := 0
	for raw: Variant in filtered.get("candidate_routes", []):
		if raw is Dictionary and str((raw as Dictionary).get("id", "")) == "attack_now":
			route_count += 1
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, low_attack, gs, 0)), "Ready Scream Tail must not use its first chip attack when the payoff attack is ready"),
		assert_false(legal_ids.has("attack:0:Slap"), "Payload should hide the ready attacker's first chip attack"),
		assert_true(legal_ids.has("attack:1:Roaring Scream"), "Payload should preserve the ready payoff attack"),
		assert_eq(route_count, 0, "Candidate route that only contained the filtered chip attack should be removed"),
	])


func test_gardevoir_llm_end_turn_queue_can_convert_to_ready_attacker_attack_after_embrace() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(34)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	scream_tail.damage_counters = 20
	player.active_pokemon = scream_tail
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn", "capability": "end_turn"}
	strategy.set("_llm_queue_turn", 34)
	strategy.set("_llm_decision_tree", {"actions": [end_ref]})
	strategy.set("_llm_action_queue", [end_ref])
	var low_attack := {"kind": "attack", "attack_index": 0, "attack_name": "Slap"}
	var payoff_attack := {"kind": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}
	var payoff_score := float(strategy.call("score_action_absolute", payoff_attack, gs, 0))
	var low_score := float(strategy.call("score_action_absolute", low_attack, gs, 0))
	return run_checks([
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", payoff_attack, gs, 0)), "Ready Gardevoir attacker payoff attack should replace a stale end_turn queue after Psychic Embrace"),
		assert_true(payoff_score >= 90000.0, "Payoff attack should receive queue ownership instead of letting end_turn consume the conversion turn"),
		assert_true(low_score <= -1000.0, "First weak attack should remain blocked when the payoff attack is ready"),
	])


func test_gardevoir_llm_retreat_to_pressure_attacker_prunes_end_turn_to_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var before := {
		"active_gardevoir_attacker_pressure_ready": false,
		"active_gardevoir_attacker_needs_more_embrace_pressure": false,
		"active_gardevoir_attacker_damage": 0,
		"active_gardevoir_attacker_energy_count": 0,
	}
	var after := {
		"active_gardevoir_attacker_pressure_ready": true,
		"active_gardevoir_attacker_needs_more_embrace_pressure": false,
		"active_gardevoir_attacker_name": "Scream Tail",
		"active_gardevoir_attacker_damage": 120,
		"active_gardevoir_attacker_energy_count": 4,
	}
	var trigger: Dictionary = strategy.call("_deck_replan_trigger_after_state_change", before, after, {
		"success": true,
		"action_kind": "retreat",
		"step_kind": "main_action",
	})
	var remaining: Array[Dictionary] = [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	]
	var pruned: Array = strategy.call("_deck_pruned_live_terminal_conversion_queue", after, remaining)
	return run_checks([
		assert_true(bool(trigger.get("should_replan", false)), "Retreating into a pressure-ready attacker must reopen terminal conversion before stale end_turn"),
		assert_eq(str(trigger.get("reason", "")), "gardevoir_active_attacker_terminal_conversion_ready", "Retreat-triggered conversion should be explicit in audit context"),
		assert_false(bool(trigger.get("ignore_replan_limit", true)), "The runtime should prefer local live-terminal pruning over a slow fresh LLM request"),
		assert_true(pruned.size() >= 2, "Live terminal conversion should produce attack followed by end_turn"),
		assert_eq(str((pruned[0] as Dictionary).get("type", "")), "attack", "Pressure-ready active attacker should attack before terminal end_turn"),
		assert_eq(int((pruned[0] as Dictionary).get("attack_index", -1)), 1, "Gardevoir pressure attackers should prefer the payoff second attack"),
		assert_eq(str((pruned[1] as Dictionary).get("id", "")), "end_turn", "Terminal end_turn remains only after the attack"),
	])


func test_gardevoir_llm_bench_pressure_handoff_prunes_stale_end_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	strategy.set("_llm_action_catalog", {
		"retreat:bench_0:c16": {
			"id": "retreat:bench_0:c16",
			"action_id": "retreat:bench_0:c16",
			"type": "retreat",
			"kind": "retreat",
			"bench_target": "Drifloon",
			"bench_target_name_en": "Drifloon",
			"bench_position": "bench_0",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	})
	var snapshot := {
		"active_gardevoir_core_attack_ready": false,
		"active_gardevoir_attacker_pressure_ready": false,
		"active_gardevoir_attacker_needs_more_embrace_pressure": false,
		"pressure_ready_bench_gardevoir_attacker_count": 1,
		"active_retreat_gap": 0,
	}
	var remaining: Array[Dictionary] = [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	]
	var pruned: Array = strategy.call("_deck_pruned_live_terminal_conversion_queue", snapshot, remaining)
	var ids := _action_ids(pruned)
	if pruned.size() < 3:
		return run_checks([
			assert_true(false, "Bench pressure handoff should produce retreat, attack, and terminal end_turn"),
		])
	return run_checks([
		assert_eq(ids[0], "retreat:bench_0:c16", "Bench pressure conversion should retreat before stale end_turn"),
		assert_eq(str((pruned[1] as Dictionary).get("type", "")), "attack", "Handoff pruning should immediately close with the payoff attack"),
		assert_eq(int((pruned[1] as Dictionary).get("attack_index", -1)), 1, "Gardevoir handoff attackers should prefer the payoff second attack"),
		assert_eq(ids[2], "end_turn", "End turn remains terminal only after handoff attack"),
	])


func test_gardevoir_llm_ready_bench_attacker_handoff_from_core_bridge_prunes_end_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	strategy.set("_llm_action_catalog", {
		"retreat:bench_0:c16": {
			"id": "retreat:bench_0:c16",
			"action_id": "retreat:bench_0:c16",
			"type": "retreat",
			"kind": "retreat",
			"bench_target": "Drifloon",
			"bench_target_name_en": "Drifloon",
			"bench_position": "bench_0",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	})
	var snapshot := {
		"active_slot_name": "Kirlia",
		"active_gardevoir_core_attack_ready": false,
		"active_gardevoir_attacker_pressure_ready": false,
		"active_gardevoir_attacker_needs_more_embrace_pressure": false,
		"ready_bench_gardevoir_attacker_count": 1,
		"pressure_ready_bench_gardevoir_attacker_count": 0,
		"active_retreat_gap": 0,
	}
	var remaining: Array[Dictionary] = [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	]
	var pruned: Array = strategy.call("_deck_pruned_live_terminal_conversion_queue", snapshot, remaining)
	var ids := _action_ids(pruned)
	if pruned.size() < 3:
		return run_checks([
			assert_true(false, "Ready bench attacker should still hand off from a one-prize Kirlia bridge instead of ending"),
		])
	return run_checks([
		assert_eq(ids[0], "retreat:bench_0:c16", "Ready bench attacker should receive a tempo handoff from Kirlia"),
		assert_eq(str((pruned[1] as Dictionary).get("type", "")), "attack", "Ready attacker handoff should close with the payoff attack"),
		assert_eq(str((pruned[1] as Dictionary).get("route_goal", "")), "bench_gardevoir_pressure_handoff", "Queued attack remains a Gardevoir handoff terminal action"),
		assert_eq(ids[2], "end_turn", "End turn remains terminal only after the ready-attacker attack"),
	])


func test_gardevoir_llm_ready_bench_attacker_handoff_does_not_pull_active_gardevoir_ex_for_chip() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	strategy.set("_llm_action_catalog", {
		"retreat:bench_0:c16": {
			"id": "retreat:bench_0:c16",
			"action_id": "retreat:bench_0:c16",
			"type": "retreat",
			"kind": "retreat",
			"bench_target": "Drifloon",
			"bench_target_name_en": "Drifloon",
			"bench_position": "bench_0",
		},
		"end_turn": {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	})
	var snapshot := {
		"active_slot_name": "Gardevoir ex",
		"active_gardevoir_core_attack_ready": false,
		"active_gardevoir_attacker_pressure_ready": false,
		"ready_bench_gardevoir_attacker_count": 1,
		"pressure_ready_bench_gardevoir_attacker_count": 0,
		"active_retreat_gap": 0,
	}
	var remaining: Array[Dictionary] = [
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	]
	var pruned: Array = strategy.call("_deck_pruned_live_terminal_conversion_queue", snapshot, remaining)
	return assert_true(pruned.is_empty(), "Active Gardevoir ex should not retreat into a low-pressure chip attacker unless the bench attacker has real pressure")


func test_gardevoir_llm_repair_inserts_bravery_before_handoff_pressure_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(52)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0))
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 40
	player.bench.append(drifloon)
	strategy.set("_llm_action_catalog", {
		"attach_tool:c50:bench_1": {
			"id": "attach_tool:c50:bench_1",
			"action_id": "attach_tool:c50:bench_1",
			"type": "attach_tool",
			"card": "Bravery Charm",
			"target": "bench_1",
			"position": "bench_1",
		},
		"retreat:bench_1:c16": {
			"id": "retreat:bench_1:c16",
			"action_id": "retreat:bench_1:c16",
			"type": "retreat",
			"bench_target": "Drifloon",
			"bench_position": "bench_1",
		},
		"attack:1:Balloon Bomb": {"id": "attack:1:Balloon Bomb", "type": "attack", "attack_index": 1, "attack_name": "Balloon Bomb"},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [
			{"id": "retreat:bench_1:c16", "type": "retreat", "bench_target": "Drifloon"},
			{"id": "attack:1:Balloon Bomb", "type": "attack", "attack_index": 1, "attack_name": "Balloon Bomb"},
		],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("attach_tool:c50:bench_1"), "Bravery Charm should be inserted before a Drifloon handoff pressure attack"),
		assert_true(ids.find("attach_tool:c50:bench_1") < ids.find("retreat:bench_1:c16"), "Bench-targeted Bravery Charm must be attached before retreat changes positions: %s" % str(ids)),
		assert_true(ids.find("retreat:bench_1:c16") < ids.find("attack:1:Balloon Bomb"), "Handoff attack order should stay retreat before payoff attack"),
	])


func test_gardevoir_llm_repair_converts_pressure_active_route_to_attack_before_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(34)
	var player := gs.players[0]
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 40
	player.active_pokemon = drifloon
	strategy.set("_llm_action_catalog", {
		"attack:1:Balloon Bomb": {"id": "attack:1:Balloon Bomb", "type": "attack", "attack_index": 1, "attack_name": "Balloon Bomb"},
		"evolve:c25:bench_0": {"id": "evolve:c25:bench_0", "type": "evolve", "card": "Kirlia"},
		"play_trainer:c40": {"id": "play_trainer:c40", "type": "play_trainer", "card": "Ultra Ball"},
		"end_turn": {"id": "end_turn", "type": "end_turn"},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [
			{"id": "evolve:c25:bench_0", "type": "evolve", "card": "Kirlia"},
			{"id": "play_trainer:c40", "type": "play_trainer", "card": "Ultra Ball"},
			{"id": "end_turn", "type": "end_turn"},
		],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("attack:1:Balloon Bomb"), "Pressure-ready active attacker route should be repaired into an immediate payoff attack"),
		assert_true(ids.find("attack:1:Balloon Bomb") < ids.find("end_turn"), "Payoff attack must be inserted before terminal end_turn"),
		assert_false(ids.has("evolve:c25:bench_0"), "Optional setup should not block a pressure-ready active attack"),
		assert_false(ids.has("play_trainer:c40"), "Search/churn should not block a pressure-ready active attack"),
		])


func test_gardevoir_llm_repair_inserts_backup_attacker_before_terminal_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(31)
	var player := gs.players[0]
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.damage_counters = 60
	player.active_pokemon = scream_tail
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex", [{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	player.discard_pile.append(CardInstance.create(_make_pokemon_cd("Drifloon", "Basic", "P", 70), 0))
	strategy.set("_llm_action_catalog", {
		"play_trainer:c12": {"id": "play_trainer:c12", "type": "play_trainer", "card": "Night Stretcher"},
		"attack:1:Roaring Scream": {"id": "attack:1:Roaring Scream", "type": "attack", "attack_index": 1, "attack_name": "Roaring Scream"},
	})
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [{"id": "attack:1:Roaring Scream", "type": "attack", "attack_index": 1, "attack_name": "Roaring Scream"}],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	return run_checks([
		assert_true(ids.has("play_trainer:c12"), "One-attacker terminal route should recover a backup attacker before attacking"),
		assert_true(ids.find("play_trainer:c12") < ids.find("attack:1:Roaring Scream"), "Backup attacker continuity must happen before terminal attack"),
	])


func test_gardevoir_llm_blocks_turo_when_single_engine_has_attacker_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(40)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 60
	player.bench.append(drifloon)
	var payload: Dictionary = strategy.call("_deck_augment_action_id_payload", {
		"legal_actions": [
			{"id": "play_trainer:c35", "type": "play_trainer", "card": "Professor Turo's Scenario"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {"other_play": ["play_trainer:c35"], "fallback": ["end_turn"]},
		"candidate_routes": [
			{"id": "bad_preserve", "goal": "engine_setup", "actions": [{"id": "play_trainer:c35"}, {"id": "end_turn"}]},
			{"id": "preserve_end", "goal": "fallback", "actions": [{"id": "end_turn"}]},
		],
		"turn_tactical_facts": {},
	}, gs, 0)
	var legal_ids := _action_ids(payload.get("legal_actions", []))
	var trainer_action := {"kind": "play_trainer", "card": "Professor Turo's Scenario"}
	return run_checks([
		assert_false(legal_ids.has("play_trainer:c35"), "Payload should hide Turo when it breaks the only Gardevoir ex engine while attacker pressure exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, trainer_action, gs, 0)), "Runtime guard should block serialized Turo in the same pressure window"),
	])


func test_gardevoir_llm_blocks_turo_when_it_breaks_only_gardevoir_engine_without_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(42)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Kirlia", "Stage 1", "P", 80, "Ralts"), 0))
	var payload: Dictionary = strategy.call("_deck_augment_action_id_payload", {
		"legal_actions": [
			{"id": "play_trainer:c35", "type": "play_trainer", "card": "Professor Turo's Scenario"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {"other_play": ["play_trainer:c35"], "fallback": ["end_turn"]},
		"candidate_routes": [
			{"id": "bad_preserve", "goal": "engine_setup", "actions": [{"id": "play_trainer:c35"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {},
	}, gs, 0)
	var legal_ids := _action_ids(payload.get("legal_actions", []))
	var trainer_action := {"kind": "play_trainer", "card": "Professor Turo's Scenario"}
	return run_checks([
		assert_false(legal_ids.has("play_trainer:c35"), "Payload should hide Turo when it removes the only Gardevoir ex engine"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, trainer_action, gs, 0)), "Runtime guard should block Turo even before an attacker body exists"),
	])


func test_gardevoir_llm_blocks_turo_when_active_gardevoir_has_energy_progress() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(44)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}],
		[{"name": "Miracle Force", "cost": "PPC", "damage": "190"}]
	), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	var payload: Dictionary = strategy.call("_deck_augment_action_id_payload", {
		"legal_actions": [
			{"id": "play_trainer:c35", "type": "play_trainer", "card": "Professor Turo's Scenario"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"legal_action_groups": {"other_play": ["play_trainer:c35"], "fallback": ["end_turn"]},
		"candidate_routes": [
			{"id": "bad_preserve", "goal": "engine_setup", "actions": [{"id": "play_trainer:c35"}, {"id": "end_turn"}]},
		],
		"turn_tactical_facts": {},
	}, gs, 0)
	var legal_ids := _action_ids(payload.get("legal_actions", []))
	var trainer_action := {"kind": "play_trainer", "card": "Professor Turo's Scenario"}
	return run_checks([
		assert_false(legal_ids.has("play_trainer:c35"), "Payload should hide Turo when active Gardevoir has attack energy progress"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, trainer_action, gs, 0)), "Runtime guard should block Turo instead of resetting active Gardevoir's energy progress"),
	])


func test_gardevoir_llm_blocks_unready_handoff_when_ready_bench_attacker_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(35)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	var scream_tail := _make_slot(_make_pokemon_cd("Scream Tail", "Basic", "P", 90, "", "", [], [
		{"name": "Slap", "cost": "P", "damage": "30"},
		{"name": "Roaring Scream", "cost": "PC", "damage": ""},
	]), 0)
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	scream_tail.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	scream_tail.damage_counters = 40
	player.bench.append(drifloon)
	player.bench.append(scream_tail)
	var bad_retreat := {"kind": "retreat", "bench_target": drifloon}
	var good_retreat := {"kind": "retreat", "bench_target": scream_tail}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_retreat, gs, 0)), "Do not retreat into an unready Gardevoir attacker while a ready bench attacker is available"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_retreat, gs, 0)), "Ready Gardevoir attacker handoff should stay legal"),
	])


func test_gardevoir_llm_blocks_premature_retreat_to_unready_attacker_without_engine() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(35)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Klefki", "Basic", "P", 70), 0)
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	player.bench.append(drifloon)
	var premature_retreat := {"kind": "retreat", "bench_target": drifloon}
	var blocks_premature := bool(strategy.call("_deck_should_block_exact_queue_match", {}, premature_retreat, gs, 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var live_retreat := {"kind": "retreat", "bench_target": drifloon}
	return run_checks([
		assert_true(blocks_premature, "Do not actively retreat into Drifloon before Gardevoir/Embrace can convert it into an attack"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, live_retreat, gs, 0)), "Retreat to Drifloon should be allowed once Gardevoir ex plus discard Psychic makes it a live conversion target"),
	])


func test_gardevoir_llm_embrace_extends_charmed_drifloon_to_ko_threshold() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(36)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	for i: int in 3:
		player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.active_pokemon.damage_counters = 60
	player.active_pokemon.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0))
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200), 1)
	var needs_more_with_charm := bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0))
	player.active_pokemon.attached_tool = null
	var avoids_self_ko_without_charm := bool(strategy.call("_active_gardevoir_attacker_needs_more_embrace_pressure", gs, 0))
	return run_checks([
		assert_true(needs_more_with_charm, "Charmed Drifloon at 180 should keep using Psychic Embrace when one more attach reaches a 200 HP KO"),
		assert_false(avoids_self_ko_without_charm, "Uncharmed Drifloon at 60 self-damage should not over-Embrace into self-KO range"),
	])


func test_gardevoir_llm_blocks_retreat_to_support_when_attacker_handoff_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(35)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Gardevoir ex", "Stage 2", "P", 310, "Kirlia", "ex"), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var drifloon := _make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [
		{"name": "Gust", "cost": "CC", "damage": "10"},
		{"name": "Balloon Bomb", "cost": "PP", "damage": "30x"},
	]), 0)
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	drifloon.damage_counters = 40
	var munkidori := _make_slot(_make_pokemon_cd("Munkidori", "Basic", "P", 110), 0)
	var flutter_mane := _make_slot(_make_pokemon_cd("Flutter Mane", "Basic", "P", 90), 0)
	player.bench.append(drifloon)
	player.bench.append(munkidori)
	player.bench.append(flutter_mane)
	var bad_munkidori_retreat := {"kind": "retreat", "bench_target": munkidori}
	var bad_flutter_retreat := {"kind": "retreat", "bench_target": flutter_mane}
	var serialized_munkidori_retreat := {"type": "retreat", "bench_target": "Munkidori"}
	var good_retreat := {"kind": "retreat", "bench_target": drifloon}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_munkidori_retreat, gs, 0)), "Do not hand off into Munkidori while a charged Drifloon attacker exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bad_flutter_retreat, gs, 0)), "Do not hand off into Flutter Mane while a charged Drifloon attacker exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, serialized_munkidori_retreat, gs, 0)), "Serialized support retreat targets should be blocked too"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, good_retreat, gs, 0)), "Charged Drifloon handoff should stay legal"),
	])


func test_gardevoir_llm_psychic_embrace_does_not_consume_stale_end_turn_queue() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Drifloon", "Basic", "P", 70, "", "", [], [{"name": "Balloon Bomb", "cost": "P", "damage": "30x"}]), 0))
	var end_ref := {"id": "end_turn", "type": "end_turn"}
	strategy.set("_llm_queue_turn", 12)
	strategy.set("_llm_action_queue", [end_ref])
	var embrace := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability": {"name": "Psychic Embrace"}}
	return run_checks([
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", embrace, gs, 0)), "Psychic Embrace must be explicitly queued; it should not consume a stale end_turn and hand control to rules fallback"),
	])


func test_gardevoir_llm_prunes_psychic_embrace_without_discard_fuel() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0)
	var repaired: Dictionary = strategy.call("_apply_deck_specific_llm_repairs", {
		"actions": [
			{"id": "use_ability:active:0", "type": "use_ability", "pokemon": "Gardevoir ex", "ability": "Psychic Embrace"},
			{"id": "play_trainer:c31", "type": "play_trainer", "card": "Arven"},
			{"id": "end_turn", "type": "end_turn"},
		],
	}, gs, 0)
	var ids := _action_ids(repaired.get("actions", []))
	var runtime_embrace := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability": {"name": "Psychic Embrace"}}
	return run_checks([
		assert_false(ids.has("use_ability:active:0"), "Psychic Embrace should be pruned when no Psychic Energy is in discard"),
		assert_true(ids.has("play_trainer:c31"), "Pruning dead Psychic Embrace must preserve later productive trainer actions"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, runtime_embrace, gs, 0)), "Runtime guard should also block Psychic Embrace with no Psychic discard fuel"),
	])


func test_gardevoir_llm_rules_fallback_blocks_unproductive_psychic_embrace() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(21)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd(
		"Gardevoir ex",
		"Stage 2",
		"P",
		310,
		"Kirlia",
		"ex",
		[{"name": "Psychic Embrace", "text": "Attach Psychic Energy from discard."}]
	), 0)
	player.discard_pile.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var embrace := {"kind": "use_ability", "source_slot": player.active_pokemon, "ability": {"name": "Psychic Embrace"}}
	var score := float(strategy.call("score_action_absolute", embrace, gs, 0))
	return assert_true(score <= -1000.0, "Rules fallback must not keep using Psychic Embrace on Gardevoir ex when no real attacker or retreat bridge exists")


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


func test_gardevoir_llm_payload_classifies_kirlia_refinement_as_draw_not_search() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyGardevoirLLM.gd should exist"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var kirlia_cd := _make_pokemon_cd(
		"Kirlia",
		"Stage 1",
		"P",
		90,
		"Ralts",
		"",
		[{"name": "Refinement", "text": "Discard 1 card from your hand and draw 2 cards from the top of your deck."}]
	)
	kirlia_cd.effect_id = "4abd956bdf3e956fcf679120601760ff"
	var kirlia_slot := _make_slot(kirlia_cd, 0)
	player.bench.append(kirlia_slot)
	player.hand.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "use_ability", "source_slot": kirlia_slot, "ability_index": 0, "ability_name": "Refinement", "ability_text": "Discard 1 card from your hand and draw 2 cards from the top of your deck."},
		{"kind": "end_turn"},
	])
	var groups: Dictionary = payload.get("legal_action_groups", {}) if payload.get("legal_action_groups", {}) is Dictionary else {}
	var engine_group: Array = groups.get("engine_or_draw", []) if groups.get("engine_or_draw", []) is Array else []
	var setup_group: Array = groups.get("search_or_setup", []) if groups.get("search_or_setup", []) is Array else []
	var refinement_ref: Dictionary = {}
	for raw_ref: Variant in payload.get("legal_actions", []):
		if raw_ref is Dictionary and str((raw_ref as Dictionary).get("type", "")) == "use_ability":
			refinement_ref = raw_ref as Dictionary
			break
	var schema: Dictionary = refinement_ref.get("interaction_schema", {}) if refinement_ref.get("interaction_schema", {}) is Dictionary else {}
	var ability_rules: Dictionary = refinement_ref.get("ability_rules", {}) if refinement_ref.get("ability_rules", {}) is Dictionary else {}
	var tags: Array = ability_rules.get("tags", []) if ability_rules.get("tags", []) is Array else []
	return run_checks([
		assert_true(engine_group.has("use_ability:bench_0:0"), "Kirlia Refinement should be surfaced as engine_or_draw"),
		assert_false(setup_group.has("use_ability:bench_0:0"), "Kirlia Refinement should not be grouped as search/setup just because it draws from deck"),
		assert_true(schema.has("discard_cards"), "Refinement should expose discard_cards interaction"),
		assert_false(schema.has("search_targets"), "Refinement must not expose fake search_targets"),
		assert_true(tags.has("draw"), "Refinement tags should include draw"),
		assert_true(tags.has("discard"), "Refinement tags should include discard"),
		assert_false(tags.has("search_deck"), "Refinement tags should not claim deck search"),
	])
