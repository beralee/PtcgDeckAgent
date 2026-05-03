class_name TestArceusGiratinaLLM
extends TestBase

const ARCEUS_RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyArceusGiratina.gd"
const ARCEUS_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyArceusGiratinaLLM.gd"
const LLM_RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy(script_path: String) -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(script_path)
	return script.new() if script != null else null


func _new_llm_strategy() -> RefCounted:
	return _new_strategy(ARCEUS_LLM_SCRIPT_PATH)


func _new_rules_strategy() -> RefCounted:
	return _new_strategy(ARCEUS_RULES_SCRIPT_PATH)


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
	cd.description = "%s rule text" % pname
	return cd


func _make_energy_cd(pname: String, energy_provides: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.energy_provides = energy_provides
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


func _arceus_vstar_slot(owner: int = 0) -> PokemonSlot:
	return _make_slot(_make_pokemon_cd(
		"Arceus VSTAR",
		"VSTAR",
		"C",
		280,
		"Arceus V",
		"VSTAR",
		[{"name": "Starbirth", "text": "Search your deck for up to 2 cards and put them into your hand."}],
		[{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}]
	), owner)


func _giratina_v_slot(owner: int = 0) -> PokemonSlot:
	return _make_slot(_make_pokemon_cd(
		"Giratina V",
		"Basic",
		"P",
		220,
		"",
		"V",
		[],
		[{"name": "Lost Impact", "cost": "PPC", "damage": "280"}]
	), owner)


func _giratina_v_setup_draw_slot(owner: int = 0) -> PokemonSlot:
	return _make_slot(_make_pokemon_cd(
		"Giratina V",
		"Basic",
		"P",
		220,
		"",
		"V",
		[],
		[
			{"name": "Abyss Seeking", "cost": "C", "damage": "0", "text": "Look at the top 4 cards of your deck and put 2 of them into your hand."},
			{"name": "Shred", "cost": "PPC", "damage": "160"},
		]
	), owner)


func _card_names(items: Array) -> Array[String]:
	var names: Array[String] = []
	for item: Variant in items:
		if item is CardInstance and (item as CardInstance).card_data != null:
			names.append(str((item as CardInstance).card_data.name))
	return names


func _fill_deck(player: PlayerState, count: int, owner: int = 0) -> void:
	player.deck.clear()
	for i: int in count:
		player.deck.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), owner))


func test_arceus_giratina_llm_scripts_load() -> String:
	return run_checks([
		assert_not_null(_load_script(LLM_RUNTIME_SCRIPT_PATH), "DeckStrategyLLMRuntimeBase.gd should load"),
		assert_not_null(_load_script(ARCEUS_RULES_SCRIPT_PATH), "DeckStrategyArceusGiratina.gd should load"),
		assert_not_null(_load_script(ARCEUS_LLM_SCRIPT_PATH), "DeckStrategyArceusGiratinaLLM.gd should load"),
	])


func test_arceus_giratina_llm_strategy_id_and_runtime_surface() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var signatures: Array = strategy.get_signature_names()
	return run_checks([
		assert_eq(strategy.get_strategy_id(), "arceus_giratina_llm", "LLM wrapper should expose the registry-ready strategy id"),
		assert_true(strategy.has_method("build_action_id_request_payload_for_test"), "LLM wrapper should inherit the shared runtime payload helper"),
		assert_true("Arceus VSTAR" in signatures, "Signature names should include Arceus VSTAR"),
		assert_true("Giratina VSTAR" in signatures, "Signature names should include Giratina VSTAR"),
	])


func test_arceus_giratina_llm_delegates_rules_fallback_when_no_plan_exists() -> String:
	var llm := _new_llm_strategy()
	var rules := _new_rules_strategy()
	if llm == null or rules == null:
		return "Arceus rules and LLM strategies should instantiate"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _arceus_vstar_slot(0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var action := {"kind": "attach_energy", "card": grass, "target_slot": active_arceus}
	var llm_score: float = llm.score_action_absolute(action, gs, 0)
	var rules_score: float = rules.score_action_absolute(action, gs, 0)
	return run_checks([
		assert_false(llm.has_llm_plan_for_turn(int(gs.turn_number)), "Constructed fallback test should not have an active LLM queue"),
		assert_eq(llm_score, rules_score, "Without an active LLM plan, action scoring should delegate exactly to the rules strategy"),
	])


func test_arceus_giratina_llm_prompt_hooks_include_deck_plan_and_custom_text() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	strategy.set_deck_strategy_text("Custom: prioritize exact Starbirth into Trinity Nova setup.")
	var gs := _make_game_state(4)
	var prompt: PackedStringArray = strategy.get_llm_deck_strategy_prompt(gs, 0)
	var joined := "\n".join(Array(prompt))
	var payload: Dictionary = strategy.build_llm_request_payload_for_test(gs, 0)
	var arceus_role: String = strategy.get_llm_setup_role_hint(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"))
	var giratina_role: String = strategy.get_llm_setup_role_hint(_make_pokemon_cd("Giratina V", "Basic", "P", 220, "", "V"))
	return run_checks([
		assert_true("Arceus VSTAR" in joined, "Prompt should name Arceus VSTAR"),
		assert_true("Giratina" in joined, "Prompt should name the Giratina lane"),
		assert_true("Starbirth" in joined, "Prompt should include Starbirth search policy"),
		assert_true("Trinity Nova" in joined, "Prompt should include Trinity Nova assignment policy"),
		assert_true("Custom: prioritize exact Starbirth" in joined, "Prompt should include player-authored strategy text"),
		assert_eq(str(payload.get("deck_strategy_id", "")), "arceus_giratina_llm", "Payload should carry the LLM strategy id"),
		assert_true(payload.has("deck_strategy_prompt"), "Payload should include the deck prompt hook output"),
		assert_true("opener" in arceus_role, "Arceus V role hint should mark the opener plan"),
		assert_true("backup lane" in giratina_role, "Giratina V role hint should mark the backup lane"),
	])


func test_arceus_giratina_llm_starbirth_exact_launch_search_uses_rules_fallback() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player := gs.players[0]
	var active_arceus := _arceus_vstar_slot(0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0))
	player.active_pokemon = active_arceus
	player.bench.append(_make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0))
	player.deck = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0),
	]
	var items: Array = [
		CardInstance.create(_make_pokemon_cd("Arceus VSTAR", "VSTAR", "C", 280, "Arceus V", "V"), 0),
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0),
		CardInstance.create(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0),
	]
	var picked: Array = strategy.pick_interaction_items(
		items,
		{"id": "search_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var picked_names := _card_names(picked)
	return run_checks([
		assert_eq(picked.size(), 2, "Starbirth exact launch search should keep the rules strategy's two-card payload"),
		assert_true("Arceus VSTAR" in picked_names, "Starbirth should fetch backup Arceus VSTAR in the exact launch window"),
		assert_true("Grass Energy" in picked_names, "Starbirth should fetch the typed energy that completes Trinity Nova"),
		assert_false("Double Turbo Energy" in picked_names, "Starbirth should not take a redundant Double Turbo in this window"),
	])


func test_arceus_giratina_llm_trinity_nova_assignment_intent_uses_rules_fallback() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(5)
	var player := gs.players[0]
	var active_arceus := _arceus_vstar_slot(0)
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0))
	active_arceus.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var giratina := _giratina_v_slot(0)
	var bidoof := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 0)
	player.active_pokemon = active_arceus
	player.bench.append(giratina)
	player.bench.append(bidoof)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var extra_grass := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[psychic, grass, extra_grass],
		{"id": "energy_assignments", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var picked_names := _card_names(picked)
	var giratina_target_score: float = strategy.score_interaction_target(
		giratina,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": psychic}
	)
	var support_target_score: float = strategy.score_interaction_target(
		bidoof,
		{"id": "assignment_target"},
		{"game_state": gs, "player_index": 0, "source_card": psychic}
	)
	return run_checks([
		assert_true("Psychic Energy" in picked_names, "Trinity Nova assignment fallback should pick Psychic for Giratina's typed cost"),
		assert_true("Grass Energy" in picked_names, "Trinity Nova assignment fallback should pick Grass for Giratina's typed cost"),
		assert_true(giratina_target_score > support_target_score, "Assignment target scoring should prefer Giratina over support Pokemon"),
	])


func test_arceus_giratina_llm_active_queue_gets_runtime_priority_for_strong_mode() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var arceus := CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var action_id := "play_basic_to_bench:c%d" % int(arceus.instance_id)
	var queued := {
		"id": action_id,
		"action_id": action_id,
		"type": "play_basic_to_bench",
		"card": "Arceus V",
	}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [queued]})
	strategy.set("_llm_action_queue", [queued])
	strategy.set("_llm_action_catalog", {action_id: queued})
	var queued_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": arceus}, gs, 0)
	var ai = AIOpponentScript.new()
	ai.set_deck_strategy(strategy)
	var gsm := GameStateMachine.new()
	gsm.game_state.turn_number = int(gs.turn_number)
	return run_checks([
		assert_true(strategy.has_llm_plan_for_turn(int(gs.turn_number)), "Injected current-turn queue should count as an active LLM plan"),
		assert_true(queued_score >= 90000.0, "Active LLM queue head should receive runtime priority over rules scoring"),
		assert_true(bool(ai.call("_strategy_has_active_llm_plan", gsm)), "AIOpponent strong-mode guard should detect this wrapper's active queue"),
	])


func test_arceus_giratina_llm_end_turn_replacement_only_allows_core_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.deck = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
	]
	var iron_leaves := _make_slot(_make_pokemon_cd("Iron Leaves ex", "Basic", "G", 220, "", "ex"), 0)
	var bibarel := _make_slot(_make_pokemon_cd(
		"Bibarel",
		"Stage 1",
		"C",
		120,
		"Bidoof",
		"",
		[{"name": "Industrious Incisors", "text": "Draw until you have 5 cards in hand."}],
		[]
	), 0)
	player.bench.append(iron_leaves)
	player.bench.append(bibarel)
	var end_queued := {
		"id": "end_turn",
		"action_id": "end_turn",
		"type": "end_turn",
	}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [end_queued]})
	strategy.set("_llm_action_queue", [end_queued])
	strategy.set("_llm_action_catalog", {"end_turn": end_queued})
	var arceus := CardInstance.create(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var lost_city := CardInstance.create(_make_trainer_cd("Lost City", "Stadium"), 0)
	var arceus_setup_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": arceus}, gs, 0)
	var boss_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss, "target_slot": iron_leaves}, gs, 0)
	var lost_city_score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": lost_city}, gs, 0)
	var retreat_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": iron_leaves}, gs, 0)
	var low_deck_draw_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": bibarel}, gs, 0)
	return run_checks([
		assert_true(arceus_setup_score >= 90000.0, "End-turn replacement should still permit missing core Arceus setup"),
		assert_true(boss_score < 10000.0, "Boss's Orders should not consume an end-turn queue as generic setup"),
		assert_true(lost_city_score < 10000.0, "Lost City should not consume an end-turn queue as generic setup"),
		assert_true(retreat_score < 10000.0, "Retreat should not consume an end-turn queue as generic setup"),
		assert_true(low_deck_draw_score < 10000.0, "Low-deck Bibarel draw should not consume an end-turn queue"),
	])


func test_arceus_giratina_llm_redraw_supporter_cannot_skip_concrete_progress() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var active_arceus := _arceus_vstar_slot(0)
	player.active_pokemon = active_arceus
	player.bench.append(_giratina_v_slot(0))
	_fill_deck(player, 24, 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	var dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	player.hand = [
		judge,
		dte,
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
	]
	var judge_id := "play_trainer:c%d" % int(judge.instance_id)
	var attach_id := "attach_energy:c%d:active" % int(dte.instance_id)
	var judge_ref := {
		"id": judge_id,
		"action_id": judge_id,
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Judge",
	}
	var attach_ref := {
		"id": attach_id,
		"action_id": attach_id,
		"type": "attach_energy",
		"kind": "attach_energy",
		"card": "Double Turbo Energy",
		"target": "Arceus VSTAR",
	}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [judge_ref, attach_ref, end_ref]})
	strategy.set("_llm_action_queue", [judge_ref, attach_ref, end_ref])
	strategy.set("_llm_action_catalog", {judge_id: judge_ref, attach_id: attach_ref, "end_turn": end_ref})
	var judge_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": judge}, gs, 0)
	var attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": dte, "target_slot": active_arceus}, gs, 0)
	return run_checks([
		assert_true(judge_score <= -1000.0, "Judge should not override a concrete attach/evolution/setup queue"),
		assert_true(attach_score >= 89000.0, "The concrete progress action after Judge should remain executable by the LLM queue"),
	])


func test_arceus_giratina_llm_redraw_allowed_for_bad_hand_shell_rebuild() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(11)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Arceus V", "Basic", "C", 220, "", "V"), 0)
	_fill_deck(player, 24, 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	var dte := CardInstance.create(_make_energy_cd("Double Turbo Energy", "", "Special Energy"), 0)
	player.hand = [judge]
	var judge_id := "play_trainer:c%d" % int(judge.instance_id)
	var attach_id := "attach_energy:c%d:active" % int(dte.instance_id)
	var judge_ref := {
		"id": judge_id,
		"action_id": judge_id,
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Judge",
	}
	var attach_ref := {
		"id": attach_id,
		"action_id": attach_id,
		"type": "attach_energy",
		"kind": "attach_energy",
		"card": "Double Turbo Energy",
		"target": "Arceus V",
	}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [judge_ref, attach_ref]})
	strategy.set("_llm_action_queue", [judge_ref, attach_ref])
	strategy.set("_llm_action_catalog", {judge_id: judge_ref, attach_id: attach_ref})
	var judge_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": judge}, gs, 0)
	return run_checks([
		assert_true(judge_score >= 90000.0, "Judge should remain available when a bad hand needs shell rebuild cards"),
	])


func test_arceus_giratina_llm_redraw_blocked_under_deck_out_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(13)
	var player := gs.players[0]
	var active_arceus := _arceus_vstar_slot(0)
	player.active_pokemon = active_arceus
	_fill_deck(player, 8, 0)
	var judge := CardInstance.create(_make_trainer_cd("Judge", "Supporter"), 0)
	var judge_id := "play_trainer:c%d" % int(judge.instance_id)
	var judge_ref := {
		"id": judge_id,
		"action_id": judge_id,
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Judge",
	}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [judge_ref, end_ref]})
	strategy.set("_llm_action_queue", [judge_ref, end_ref])
	strategy.set("_llm_action_catalog", {judge_id: judge_ref, "end_turn": end_ref})
	var judge_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": judge}, gs, 0)
	return run_checks([
		assert_true(judge_score <= -1000.0, "Judge should be blocked when low deck count creates deck-out pressure"),
	])


func test_arceus_giratina_llm_optional_draw_ability_blocked_under_deck_out_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(14)
	var player := gs.players[0]
	var bibarel := _make_slot(_make_pokemon_cd(
		"Bibarel",
		"Stage 1",
		"C",
		120,
		"Bidoof",
		"",
		[{"name": "Industrious Incisors", "text": "Draw until you have 5 cards in hand."}],
		[]
	), 0)
	player.bench.append(bibarel)
	_fill_deck(player, 8, 0)
	player.hand = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
		CardInstance.create(_make_trainer_cd("Ultra Ball"), 0),
	]
	var ability_ref := {
		"id": "use_ability:bench_0:0",
		"action_id": "use_ability:bench_0:0",
		"type": "use_ability",
		"kind": "use_ability",
		"pokemon": "Bibarel",
	}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [ability_ref, end_ref]})
	strategy.set("_llm_action_queue", [ability_ref, end_ref])
	strategy.set("_llm_action_catalog", {"use_ability:bench_0:0": ability_ref, "end_turn": end_ref})
	var ability_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": bibarel, "ability_index": 0}, gs, 0)
	return run_checks([
		assert_true(ability_score <= -1000.0, "Bibarel draw should be blocked when low deck count creates deck-out pressure"),
	])


func test_arceus_giratina_llm_abyss_seeking_blocked_when_deck_count_is_midgame_low() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(16)
	var player := gs.players[0]
	player.active_pokemon = _giratina_v_setup_draw_slot(0)
	_fill_deck(player, 20, 0)
	player.hand = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_trainer_cd("Ultra Ball"), 0),
		CardInstance.create(_make_trainer_cd("Nest Ball"), 0),
	]
	var attack_action := {"kind": "attack", "attack_index": 0, "attack_name": "Abyss Seeking"}
	var attack_id: String = str(strategy.call("_action_id_for_action", attack_action, gs, 0))
	var attack_ref := {
		"id": attack_id,
		"action_id": attack_id,
		"type": "attack",
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Abyss Seeking",
	}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [attack_ref]})
	strategy.set("_llm_action_queue", [attack_ref])
	strategy.set("_llm_action_catalog", {attack_id: attack_ref})
	var attack_score: float = strategy.score_action_absolute(attack_action, gs, 0)
	return run_checks([
		assert_true(attack_score <= -1000.0, "Abyss Seeking should be blocked once repeated setup draw creates deck-out pressure"),
	])


func test_arceus_giratina_llm_abyss_seeking_allowed_when_deck_count_is_safe() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _giratina_v_setup_draw_slot(0)
	_fill_deck(player, 36, 0)
	player.hand = [
		CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
	]
	var attack_action := {"kind": "attack", "attack_index": 0, "attack_name": "Abyss Seeking"}
	var attack_id: String = str(strategy.call("_action_id_for_action", attack_action, gs, 0))
	var attack_ref := {
		"id": attack_id,
		"action_id": attack_id,
		"type": "attack",
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Abyss Seeking",
	}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [attack_ref]})
	strategy.set("_llm_action_queue", [attack_ref])
	strategy.set("_llm_action_catalog", {attack_id: attack_ref})
	var attack_score: float = strategy.score_action_absolute(attack_action, gs, 0)
	return run_checks([
		assert_true(attack_score >= 90000.0, "Abyss Seeking should remain available while deck count is safe and the hand still needs setup"),
	])


func test_arceus_giratina_llm_boss_requires_attack_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratinaLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var boss_id := "play_trainer:c%d" % int(boss.instance_id)
	var boss_ref := {
		"id": boss_id,
		"action_id": boss_id,
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Boss's Orders",
	}
	var end_ref := {"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"}
	strategy.set("_llm_queue_turn", int(gs.turn_number))
	strategy.set("_llm_decision_tree", {"actions": [boss_ref, end_ref]})
	strategy.set("_llm_action_queue", [boss_ref, end_ref])
	strategy.set("_llm_action_catalog", {boss_id: boss_ref, "end_turn": end_ref})
	var no_pressure_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)
	var attack_strategy := _new_llm_strategy()
	var attack_gs := _make_game_state(12)
	var attack_boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var attack_boss_id := "play_trainer:c%d" % int(attack_boss.instance_id)
	var attack_boss_ref := {
		"id": attack_boss_id,
		"action_id": attack_boss_id,
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Boss's Orders",
	}
	var attack_ref := {
		"id": "attack:0:Trinity Nova",
		"action_id": "attack:0:Trinity Nova",
		"type": "attack",
		"kind": "attack",
		"attack_name": "Trinity Nova",
	}
	attack_strategy.set("_llm_queue_turn", int(attack_gs.turn_number))
	attack_strategy.set("_llm_decision_tree", {"actions": [attack_boss_ref, attack_ref]})
	attack_strategy.set("_llm_action_queue", [attack_boss_ref, attack_ref])
	attack_strategy.set("_llm_action_catalog", {attack_boss_id: attack_boss_ref, "attack:0:Trinity Nova": attack_ref})
	var attack_route_score: float = attack_strategy.score_action_absolute({"kind": "play_trainer", "card": attack_boss}, attack_gs, 0)
	return run_checks([
		assert_true(no_pressure_score <= -1000.0, "Boss's Orders should be blocked when the LLM queue has no attack pressure"),
		assert_true(attack_route_score > -1000.0, "Boss's Orders should remain legal when the LLM queue includes an attack route"),
	])
