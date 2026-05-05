class_name TestCharizardExLLM
extends TestBase

const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyCharizardExLLM.gd"
const RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategyCharizardEx.gd"
const RUNTIME_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLLMRuntimeBase.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_rules_strategy() -> RefCounted:
	var script := _load_script(RULES_SCRIPT_PATH)
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


func _make_energy_cd(pname: String = "Fire Energy", energy_provides: String = "R") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_game_state(turn: int = 3) -> GameState:
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


func _make_charizard_cd() -> CardData:
	return _make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"R",
		330,
		"Charmeleon",
		"ex",
		[{"name": "Infernal Reign", "text": "attach Fire Energy from deck"}],
		[{"name": "Burning Darkness", "cost": "RR", "damage": "180"}]
	)


func _make_pidgeot_cd() -> CardData:
	return _make_pokemon_cd(
		"Pidgeot ex",
		"Stage 2",
		"C",
		280,
		"Pidgeotto",
		"ex",
		[{"name": "Quick Search", "text": "search your deck"}],
		[{"name": "Blustery Wind", "cost": "CC", "damage": "120"}]
	)


func _prompt_lines_from_payload(payload: Dictionary, key: String) -> PackedStringArray:
	var result := PackedStringArray()
	var raw: Variant = payload.get(key, PackedStringArray())
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for line: Variant in raw:
			result.append(str(line))
	return result


func _payload_legal_actions(payload: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_actions: Variant = payload.get("legal_actions", [])
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		if raw is Dictionary:
			result.append(raw)
	return result


func _compact_cards(refs: Array[Dictionary]) -> Array[String]:
	var cards: Array[String] = []
	for ref: Dictionary in refs:
		var card_name := str(ref.get("card", ref.get("pokemon", "")))
		if card_name != "" and not cards.has(card_name):
			cards.append(card_name)
	return cards


func _best_item_name(strategy: RefCounted, items: Array, step: Dictionary, context: Dictionary) -> String:
	var best_name := ""
	var best_score := -INF
	for item: Variant in items:
		var score: float = strategy.call("score_interaction_target", item, step, context)
		if score > best_score and item is CardInstance:
			best_score = score
			best_name = str((item as CardInstance).card_data.name_en)
	return best_name


func test_charizard_ex_llm_script_loads_and_reports_strategy_id() -> String:
	var runtime_script := _load_script(RUNTIME_SCRIPT_PATH)
	var rules_script := _load_script(RULES_SCRIPT_PATH)
	var llm_script := _load_script(LLM_SCRIPT_PATH)
	var llm_strategy: RefCounted = llm_script.new() if llm_script != null else null
	var rules_strategy: RefCounted = rules_script.new() if rules_script != null else null
	var source := FileAccess.get_file_as_string(LLM_SCRIPT_PATH)
	return run_checks([
		assert_not_null(runtime_script, "DeckStrategyLLMRuntimeBase.gd should load before Charizard LLM"),
		assert_not_null(rules_script, "DeckStrategyCharizardEx.gd should load as the rules fallback"),
		assert_not_null(llm_script, "DeckStrategyCharizardExLLM.gd should load without compile errors"),
		assert_not_null(llm_strategy, "DeckStrategyCharizardExLLM.gd should instantiate"),
		assert_eq(str(llm_strategy.call("get_strategy_id")) if llm_strategy != null else "", "charizard_ex_llm", "LLM strategy id should be registry-ready and stable"),
		assert_eq(str(rules_strategy.call("get_strategy_id")) if rules_strategy != null else "", "charizard_ex", "Rules strategy id should remain unchanged"),
		assert_true(source.contains("DeckStrategyLLMRuntimeBase.gd"), "Wrapper should extend the shared LLM runtime"),
		assert_true(source.contains("DeckStrategyCharizardEx.gd"), "Wrapper should compose the existing rules strategy"),
		assert_false(source.contains("DeckStrategyRagingBoltLLM.gd"), "Wrapper must not inherit another deck-specific LLM variant"),
	])


func test_charizard_ex_llm_delegates_rules_fallback_scoring_and_interactions() -> String:
	var llm_strategy := _new_llm_strategy()
	var rules_strategy := _new_rules_strategy()
	if llm_strategy == null or rules_strategy == null:
		return "Charizard LLM and rules strategies should both load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.hand.append(CardInstance.create(_make_charizard_cd(), 0))
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var action := {"kind": "play_trainer", "card": rare_candy}
	var llm_score: float = llm_strategy.call("score_action_absolute", action, gs, 0)
	var rules_score: float = rules_strategy.call("score_action_absolute", action, gs, 0)
	var charizard_target := CardInstance.create(_make_charizard_cd(), 0)
	var pidgeot_target := CardInstance.create(_make_pidgeot_cd(), 0)
	var step := {"id": "search_pokemon"}
	var context := {"game_state": gs, "player_index": 0}
	var llm_search_score: float = llm_strategy.call("score_interaction_target", charizard_target, step, context)
	var rules_search_score: float = rules_strategy.call("score_interaction_target", charizard_target, step, context)
	var raw_llm_picked: Variant = llm_strategy.call("pick_interaction_items", [pidgeot_target, charizard_target], {"id": "search_pokemon", "max_select": 1}, context)
	var raw_rules_picked: Variant = rules_strategy.call("pick_interaction_items", [pidgeot_target, charizard_target], {"id": "search_pokemon", "max_select": 1}, context)
	var llm_picked: Array = raw_llm_picked if raw_llm_picked is Array else []
	var rules_picked: Array = raw_rules_picked if raw_rules_picked is Array else []
	return run_checks([
		assert_true(abs(llm_score - rules_score) < 0.001, "Without an active LLM plan, action scoring should delegate to rules fallback"),
		assert_true(abs(llm_search_score - rules_search_score) < 0.001, "Without an active LLM plan, interaction scoring should delegate to rules fallback"),
		assert_eq(llm_picked.size(), rules_picked.size(), "Interaction item count should match rules fallback"),
		assert_eq(str((llm_picked[0] as CardInstance).card_data.name_en), str((rules_picked[0] as CardInstance).card_data.name_en), "Interaction item choice should match rules fallback"),
	])


func test_charizard_ex_llm_payload_includes_prompt_and_setup_role_hooks() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	var gs := _make_game_state(3)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	gs.players[0].bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", gs, 0)
	var prompt_lines := _prompt_lines_from_payload(payload, "deck_strategy_prompt")
	var prompt_text := "\n".join(prompt_lines)
	var charmander_hint := str(strategy.call("get_llm_setup_role_hint", _make_pokemon_cd("Charmander", "Basic", "R", 70)))
	var pidgey_hint := str(strategy.call("get_llm_setup_role_hint", _make_pokemon_cd("Pidgey", "Basic", "C", 60)))
	var pidgeot_hint := str(strategy.call("get_llm_setup_role_hint", _make_pidgeot_cd()))
	return run_checks([
		assert_eq(str(payload.get("deck_strategy_id", "")), "charizard_ex_llm", "Payload should identify the Charizard LLM strategy id"),
		assert_true(prompt_lines.size() >= 8, "Prompt should provide real deck-specific tactical guidance"),
		assert_str_contains(prompt_text, "Charizard ex", "Prompt should name the main attacker"),
		assert_str_contains(prompt_text, "Pidgeot ex", "Prompt should name the search engine"),
		assert_str_contains(prompt_text, "Rare Candy", "Prompt should cover Stage 2 conversion"),
		assert_str_contains(prompt_text, "Fire", "Prompt should cover energy assignment priorities"),
		assert_str_contains(charmander_hint, "Charizard ex", "Charmander role hint should identify the Charizard line"),
		assert_str_contains(pidgey_hint, "Pidgeot ex", "Pidgey role hint should identify the Pidgeot line"),
		assert_str_contains(pidgeot_hint, "search engine", "Pidgeot ex role hint should mark the search engine"),
	])


func test_charizard_ex_llm_payload_preserves_player_authored_strategy_text() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	strategy.call("set_deck_strategy_text", "Prefer second Charmander before Duskull when Rare Candy is already visible.")
	var payload: Dictionary = strategy.call("build_llm_request_payload_for_test", _make_game_state(2), 0)
	var prompt_text := "\n".join(_prompt_lines_from_payload(payload, "deck_strategy_prompt"))
	return run_checks([
		assert_str_contains(prompt_text, "Prefer second Charmander before Duskull", "Prompt should preserve player-authored deck strategy text"),
		assert_str_contains(prompt_text, "Execution boundary", "Custom prompt should still keep action ids and card text delegated to payload data"),
	])


func test_charizard_ex_llm_marks_rare_candy_and_stage2_route_intent() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(charmander)
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var charizard := CardInstance.create(_make_charizard_cd(), 0)
	var pidgeot := CardInstance.create(_make_pidgeot_cd(), 0)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": rare_candy, "requires_interaction": true},
		{"kind": "evolve", "card": charizard, "target_slot": charmander},
		{"kind": "evolve", "card": pidgeot, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	var followups: Array[Dictionary] = []
	strategy.call("_deck_append_short_route_followups", followups, {})
	var followup_cards := _compact_cards(followups)
	var legal_cards := _compact_cards(_payload_legal_actions(payload))
	var hints_text := "\n".join(_prompt_lines_from_payload(payload, "deck_strategy_hints"))
	return run_checks([
		assert_true(legal_cards.has("Rare Candy"), "Prompt payload should expose Rare Candy as a legal action"),
		assert_true(legal_cards.has("Charizard ex"), "Prompt payload should expose Charizard ex evolution action"),
		assert_true(legal_cards.has("Pidgeot ex"), "Prompt payload should expose Pidgeot ex evolution action"),
		assert_true(followup_cards.has("Rare Candy"), "Charizard hook should add Rare Candy to short-route followups"),
		assert_true(followup_cards.has("Charizard ex"), "Charizard hook should add Charizard ex evolution to short-route followups"),
		assert_true(followup_cards.has("Pidgeot ex"), "Charizard hook should add Pidgeot ex evolution to short-route followups"),
		assert_true(bool(strategy.call("_deck_is_setup_or_resource_card", rare_candy.card_data)), "Rare Candy should be marked as setup/resource"),
		assert_true(bool(strategy.call("_deck_action_ref_enables_attack", {"type": "play_trainer", "card": "Rare Candy", "requires_interaction": true, "interaction_schema": {"stage2_card": {}, "target_pokemon": {}}})), "Rare Candy route refs should be attack-enabling only when a real Stage 2 target is exposed"),
		assert_str_contains(hints_text, "Rare Candy", "Action-id prompt hints should include Rare Candy route guidance"),
	])


func test_charizard_ex_llm_blocks_noop_rare_candy_and_prioritizes_rotom_after_core_seeds() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0))
	var rare_candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var noop_candy := {"kind": "play_trainer", "card": rare_candy, "requires_interaction": false}
	var valid_candy := {"kind": "play_trainer", "card": rare_candy, "requires_interaction": true}
	var rotom := CardInstance.create(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var extra_charmander := CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var context := {"game_state": gs, "player_index": 0}
	var rotom_score: float = strategy.call("_charizard_llm_search_item_score", rotom, context)
	var charmander_score: float = strategy.call("_charizard_llm_search_item_score", extra_charmander, context)
	var nest_policy: Dictionary = strategy.call("_charizard_basic_search_policy_for_ref", {"card": "Nest Ball"}, {"charmander_count": 1, "pidgey_count": 1, "rotom_v_count": 0})
	var nest_prefer: Array = []
	var nest_search_raw: Variant = nest_policy.get("search", {})
	if nest_search_raw is Dictionary:
		nest_prefer = (nest_search_raw as Dictionary).get("prefer", [])
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "play_trainer"}, noop_candy, gs, 0)), "LLM queue guard should block Rare Candy actions that expose no target or interaction"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "play_trainer"}, valid_candy, gs, 0)), "LLM queue guard should allow Rare Candy when the engine will resolve a real interaction"),
		assert_true(rotom_score > charmander_score, "After Charmander and Pidgey are already established, Nest Ball search should value Rotom V draw setup above extra Charmander padding"),
		assert_eq(str(nest_prefer[0]) if not nest_prefer.is_empty() else "", "Rotom V", "Nest Ball policy should put Rotom V first after the two core seeds exist"),
	])


func test_charizard_ex_llm_pidgeot_search_target_intent_delegates_to_rules() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	var gs := _make_game_state(6)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_charizard_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	player.bench.append(_make_slot(_make_pidgeot_cd(), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.prizes = [
		CardInstance.create(_make_pokemon_cd("Prize A"), 0),
		CardInstance.create(_make_pokemon_cd("Prize B"), 0),
		CardInstance.create(_make_pokemon_cd("Prize C"), 0),
		CardInstance.create(_make_pokemon_cd("Prize D"), 0),
	]
	gs.players[1].prizes = [
		CardInstance.create(_make_pokemon_cd("Prize X"), 1),
		CardInstance.create(_make_pokemon_cd("Prize Y"), 1),
	]
	player.deck.append(CardInstance.create(_make_charizard_cd(), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.deck.append(CardInstance.create(_make_trainer_cd("Defiance Band", "Tool"), 0))
	var candidates: Array = [
		CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0),
		CardInstance.create(_make_trainer_cd("Rare Candy"), 0),
		CardInstance.create(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0),
	]
	var picked_name := _best_item_name(
		strategy,
		candidates,
		{"id": "search_cards"},
		{"game_state": gs, "player_index": 0, "all_items": candidates}
	)
	return assert_eq(picked_name, "Rare Candy", "Pidgeot-style search should prefer the direct Rare Candy conversion piece on an online engine board")


func test_charizard_ex_llm_energy_assignment_intent_prefers_attackers_and_blocks_support_attach() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_charizard_cd(), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 1", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire 2", "R"), 0))
	var pidgeot := _make_slot(_make_pidgeot_cd(), 0)
	var backup_charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.append(pidgeot)
	player.bench.append(backup_charmander)
	player.bench.append(rotom)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var active_score: float = strategy.call("score_interaction_target", player.active_pokemon, {"id": "manual_attach_energy_target"}, {"game_state": gs, "player_index": 0, "source_card": fire})
	var bad_pidgeot_attach := {"kind": "attach_energy", "card": fire, "target_slot": pidgeot}
	var bad_rotom_attach := {"kind": "attach_energy", "card": fire, "target_slot": rotom}
	var good_backup_attach := {"kind": "attach_energy", "card": fire, "target_slot": backup_charmander}
	return run_checks([
		assert_true(active_score <= 0.0, "Attack-ready Charizard ex should not keep receiving extra Fire assignment"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, bad_pidgeot_attach, gs, 0)), "LLM queue guard should block Fire attach to Pidgeot when Charizard lanes are visible"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, bad_rotom_attach, gs, 0)), "LLM queue guard should block Fire attach to support-only Rotom V"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_energy"}, good_backup_attach, gs, 0)), "LLM queue guard should allow Fire attach to the backup Charizard lane"),
	])


func test_charizard_ex_llm_tool_assignment_blocks_forest_seal_stone_on_non_v_targets() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategyCharizardExLLM.gd should exist"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	var pidgey := _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var lumineon := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.bench.append(pidgey)
	player.bench.append(rotom)
	player.bench.append(lumineon)
	var forest_seal := CardInstance.create(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var defiance_band := CardInstance.create(_make_trainer_cd("Defiance Band", "Tool"), 0)
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_tool"}, {"kind": "attach_tool", "card": forest_seal, "target_slot": player.active_pokemon}, gs, 0)), "Forest Seal Stone should not be queued onto Charmander"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_tool"}, {"kind": "attach_tool", "card": forest_seal, "target_slot": pidgey}, gs, 0)), "Forest Seal Stone should not be queued onto Pidgey"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_tool"}, {"kind": "attach_tool", "card": forest_seal, "target_slot": rotom}, gs, 0)), "Forest Seal Stone should remain legal for Rotom V"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_tool"}, {"kind": "attach_tool", "card": forest_seal, "target_slot": lumineon}, gs, 0)), "Forest Seal Stone should remain legal for Lumineon V"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {"type": "attach_tool"}, {"kind": "attach_tool", "card": defiance_band, "target_slot": player.active_pokemon}, gs, 0)), "The Forest Seal guard should not block unrelated tools"),
	])
