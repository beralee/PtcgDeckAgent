extends TestBase

const RAGING_BOLT_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyRagingBoltLLM.gd"
const DRAGAPULT_CHARIZARD_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd"
const MIRAIDON_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyMiraidonLLM.gd"
const V17_MIRAIDON_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17MiraidonLLM.gd"
const V17_REGIDRAGO_RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17Regidrago.gd"
const V17_REGIDRAGO_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17RegidragoLLM.gd"
const LUGIA_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd"
const LLM_DECK_STRATEGY_BASE_SCRIPT_PATH := "res://scripts/ai/LLMDeckStrategyBase.gd"
const LLM_INTERACTION_BRIDGE_SCRIPT_PATH := "res://scripts/ai/LLMInteractionIntentBridge.gd"
const LLM_DECISION_TREE_EXECUTOR_SCRIPT_PATH := "res://scripts/ai/LLMDecisionTreeExecutor.gd"
const LLM_DECK_CAPABILITY_EXTRACTOR_SCRIPT_PATH := "res://scripts/ai/LLMDeckCapabilityExtractor.gd"
const LLM_TURN_PLAN_PROMPT_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMTurnPlanPromptBuilder.gd"
const LLM_ROUTE_COMPILER_SCRIPT_PATH := "res://scripts/ai/LLMRouteCompiler.gd"
const LLM_ROUTE_CANDIDATE_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMRouteCandidateBuilder.gd"
const LLM_ROUTE_ACTION_REGISTRY_SCRIPT_PATH := "res://scripts/ai/LLMRouteActionRegistry.gd"


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _make_pokemon_cd(pname: String, stage: String = "Basic", energy_type: String = "C", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	return cd


func _make_raging_bolt_cd() -> CardData:
	var cd := _make_pokemon_cd("Raging Bolt ex", "Basic", "L", 240)
	cd.name_en = "Raging Bolt ex"
	cd.mechanic = "ex"
	cd.is_tags = ["Ancient"]
	cd.attacks = [
		{"name": "Bursting Roar", "cost": "C", "damage": ""},
		{"name": "Thundering Bolt", "cost": "LF", "damage": "70x"},
	]
	return cd


func _make_miraidon_cd() -> CardData:
	var cd := _make_pokemon_cd("Miraidon ex", "Basic", "L", 220)
	cd.name_en = "Miraidon ex"
	cd.mechanic = "ex"
	cd.attacks = [
		{"name": "Tandem Unit", "cost": "", "damage": ""},
		{"name": "Photon Blaster", "cost": "LLC", "damage": "220"},
	]
	return cd


func _make_lugia_v_cd() -> CardData:
	var cd := _make_pokemon_cd("Lugia V", "Basic", "C", 220)
	cd.name_en = "Lugia V"
	cd.mechanic = "V"
	cd.attacks = [
		{"name": "Read the Wind", "cost": "C", "damage": ""},
		{"name": "Aero Dive", "cost": "CCCC", "damage": "130"},
	]
	return cd


func _make_lugia_vstar_cd() -> CardData:
	var cd := _make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280)
	cd.name_en = "Lugia VSTAR"
	cd.mechanic = "VSTAR"
	cd.abilities = [{"name": "Summoning Star", "text": "Put up to 2 Colorless Pokemon from your discard pile onto your Bench."}]
	cd.attacks = [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]
	return cd


func _make_archeops_cd() -> CardData:
	var cd := _make_pokemon_cd("Archeops", "Stage2", "C", 150)
	cd.name_en = "Archeops"
	cd.abilities = [{"name": "Primal Turbo", "text": "Search your deck for up to 2 Special Energy cards and attach them to 1 of your Pokemon."}]
	return cd


func _make_minccino_cd() -> CardData:
	var cd := _make_pokemon_cd("Minccino", "Basic", "C", 70)
	cd.name_en = "Minccino"
	return cd


func _make_cinccino_cd() -> CardData:
	var cd := _make_pokemon_cd("Cinccino", "Stage1", "C", 110)
	cd.name_en = "Cinccino"
	cd.attacks = [{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
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


func _make_named_trainer_cd(pname: String, name_en: String, card_type: String = "Item") -> CardData:
	var cd := _make_trainer_cd(pname, card_type)
	cd.name_en = name_en
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


func _fill_player_deck(player: PlayerState, count: int = 30) -> void:
	if player == null:
		return
	for i: int in count:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck filler %d" % i), player.player_index))


func _set_prizes_remaining(player: PlayerState, count: int) -> void:
	if player == null:
		return
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize filler %d" % i), player.player_index))


func _new_llm_strategy() -> RefCounted:
	var script := _load_script(RAGING_BOLT_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_dragapult_charizard_llm_strategy() -> RefCounted:
	var script := _load_script(DRAGAPULT_CHARIZARD_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_miraidon_llm_strategy() -> RefCounted:
	var script := _load_script(MIRAIDON_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_v17_miraidon_llm_strategy() -> RefCounted:
	var script := _load_script(V17_MIRAIDON_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_v17_regidrago_llm_strategy() -> RefCounted:
	var script := _load_script(V17_REGIDRAGO_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_v17_regidrago_rules_strategy() -> RefCounted:
	var script := _load_script(V17_REGIDRAGO_RULES_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_lugia_llm_strategy() -> RefCounted:
	var script := _load_script(LUGIA_LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_route_compiler() -> RefCounted:
	var script := _load_script(LLM_ROUTE_COMPILER_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_route_candidate_builder() -> RefCounted:
	var script := _load_script(LLM_ROUTE_CANDIDATE_BUILDER_SCRIPT_PATH)
	return script.new() if script != null else null


func _new_route_action_registry() -> RefCounted:
	var script := _load_script(LLM_ROUTE_ACTION_REGISTRY_SCRIPT_PATH)
	return script.new() if script != null else null


func _current_legal_actions_from_payload(payload: Dictionary) -> Array:
	var result: Array = []
	for raw: Variant in payload.get("legal_actions", []):
		if not (raw is Dictionary):
			continue
		if bool((raw as Dictionary).get("future", false)):
			continue
		result.append(raw)
	return result


func _inject_llm_queue(strategy: RefCounted, turn: int, actions: Array) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"actions": actions, "reasoning": "test"}
	strategy.call("_on_llm_response", mock_response, turn)


func _inject_llm_tree(strategy: RefCounted, turn: int, decision_tree: Dictionary) -> void:
	strategy.set("_cached_turn_number", turn)
	var mock_response := {"decision_tree": decision_tree, "reasoning": "tree test"}
	strategy.call("_on_llm_response", mock_response, turn)


func _unique_count_for_test(values: Array) -> int:
	var seen := {}
	for raw: Variant in values:
		seen[str(raw)] = true
	return seen.size()


