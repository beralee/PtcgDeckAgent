class_name TestV17BombCharizardLLM
extends TestBase

const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17BombCharizardLLM.gd"
const RULES_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17BombCharizard.gd"


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(LLM_SCRIPT_PATH)
	return script.new() if script is GDScript else null


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
	return cd


func _make_energy_cd(pname: String = "Fire Energy", energy_provides: String = "R") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_provides
	cd.energy_provides = energy_provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_card(card_data: CardData, owner: int = 0) -> CardInstance:
	return CardInstance.create(card_data, owner)


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
		for i: int in 6:
			player.prizes.append(_make_card(_make_trainer_cd("Prize %d" % i), player_index))
		gs.players.append(player)
	return gs


func _charizard_cd() -> CardData:
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


func test_v17_bomb_charizard_llm_uses_shared_v17_runtime_with_bomb_rules() -> String:
	var llm_script: Variant = load(LLM_SCRIPT_PATH)
	var rules_script: Variant = load(RULES_SCRIPT_PATH)
	var strategy: RefCounted = llm_script.new() if llm_script is GDScript else null
	var rules: RefCounted = rules_script.new() if rules_script is GDScript else null
	var source := FileAccess.get_file_as_string(LLM_SCRIPT_PATH)
	return run_checks([
		assert_not_null(llm_script, "V17 Bomb Charizard LLM script should load"),
		assert_not_null(strategy, "V17 Bomb Charizard LLM strategy should instantiate"),
		assert_not_null(rules, "V17 Bomb Charizard rules strategy should instantiate"),
		assert_eq(str(strategy.call("get_strategy_id")) if strategy != null else "", "v17_bomb_charizard_llm", "LLM strategy id should remain registry-ready"),
		assert_eq(str(rules.call("get_strategy_id")) if rules != null else "", "v17_bomb_charizard", "Rules fallback should be the V17 Bomb Charizard strategy"),
		assert_true(source.contains("DeckStrategy17LLMBase.gd"), "Bomb LLM should inherit the shared V17 LLM runtime"),
		assert_false(source.contains("DeckStrategyCharizardExLLM.gd"), "Bomb LLM should not bypass the shared V17 wrapper through the legacy Charizard LLM"),
	])


func test_v17_bomb_charizard_llm_prompt_is_clean_and_bomb_specific() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "V17 Bomb Charizard LLM strategy should instantiate"
	var question := char(63)
	var garbled_text := question + question + question + "ex/" + question + question + question
	strategy.call("set_deck_strategy_text", garbled_text)
	var lines: PackedStringArray = strategy.call("get_llm_deck_strategy_prompt", _make_game_state(), 0)
	var prompt := "\n".join(lines)
	return run_checks([
		assert_str_contains(prompt, "V17 Bomb Charizard", "Prompt should provide a clean V17 Bomb Charizard plan"),
		assert_str_contains(prompt, "Dusknoir places 130", "Prompt should explain the new Dusknoir conversion damage"),
		assert_str_contains(prompt, "Dusclops places 50", "Prompt should explain the Dusclops conversion damage"),
		assert_false(prompt.contains(garbled_text), "Bundled mojibake strategy text should not pollute the LLM prompt"),
	])


func test_v17_bomb_charizard_llm_delegates_self_ko_targeting_to_bomb_rules() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "V17 Bomb Charizard LLM strategy should instantiate"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var dusknoir := _make_slot(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops"), 0)
	player.bench.append(dusknoir)
	var bulky := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var doomed := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	doomed.damage_counters = 80
	opponent.bench.append(bulky)
	opponent.bench.append(doomed)
	var context := {"game_state": gs, "player_index": 0, "source_slot": dusknoir}
	var doomed_score: float = strategy.call("score_interaction_target", doomed, {"id": "self_ko_target"}, context)
	var bulky_score: float = strategy.call("score_interaction_target", bulky, {"id": "self_ko_target"}, context)
	var picked: Array = strategy.call("pick_interaction_items", [bulky, doomed], {"id": "self_ko_target", "max_select": 1}, context)
	var picked_name := ""
	if not picked.is_empty() and picked[0] is PokemonSlot:
		picked_name = (picked[0] as PokemonSlot).get_pokemon_name()
	return run_checks([
		assert_true(doomed_score >= 650.0, "LLM wrapper should use V17 130-damage Dusknoir target scoring"),
		assert_true(doomed_score > bulky_score + 300.0, "130-damage conversion target should beat non-lethal bulky target"),
		assert_eq(picked_name, "Raikou V", "LLM wrapper should let Bomb rules pick the concrete self-KO target"),
	])


func test_v17_bomb_charizard_llm_payload_exposes_self_ko_conversion_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "V17 Bomb Charizard LLM strategy should instantiate"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var active := _make_slot(_charizard_cd(), 0)
	active.attached_energy.append(_make_card(_make_energy_cd("Fire Energy 1", "R"), 0))
	active.attached_energy.append(_make_card(_make_energy_cd("Fire Energy 2", "R"), 0))
	player.active_pokemon = active
	player.bench.append(_make_slot(_make_pokemon_cd("Pidgeot ex", "Stage 2", "C", 280, "Pidgeotto", "ex"), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops"), 0))
	var damaged_target := _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 1)
	damaged_target.damage_counters = 50
	opponent.bench.append(damaged_target)
	var payload := {
		"legal_actions": [
			{
				"id": "use_ability:bench_1:0:Cursed Blast",
				"type": "use_ability",
				"pokemon": "Dusknoir",
				"position": "bench_1",
				"summary": "use Dusknoir Cursed Blast",
				"requires_interaction": true,
				"interaction_schema": {"self_ko_target": {"type": "target"}},
			},
			{
				"id": "attack:active:0:Burning Darkness",
				"type": "attack",
				"attack_name": "Burning Darkness",
				"summary": "attack with Charizard ex Burning Darkness",
				"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			},
			{"id": "end_turn", "type": "end_turn"},
		],
		"candidate_routes": [
			{
				"id": "attack_now",
				"route_action_id": "route:attack_now",
				"actions": [{"id": "attack:active:0:Burning Darkness"}],
			},
		],
		"turn_tactical_facts": {},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var bomb_fact: Dictionary = facts.get("bomb_charizard_self_ko_conversion", {}) if facts.get("bomb_charizard_self_ko_conversion", {}) is Dictionary else {}
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:bomb_charizard_self_ko_conversion":
			route = raw_route
			break
	var actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	return run_checks([
		assert_true(bool(bomb_fact.get("route_available", false)), "Payload should expose a live self-KO conversion fact"),
		assert_true(bool(bomb_fact.get("direct_prize_available", false)), "Dusknoir 130 should see the direct two-prize target"),
		assert_eq(str(bomb_fact.get("best_target", "")), "Lumineon V", "Conversion fact should identify the best prize target"),
		assert_true(not route.is_empty(), "Payload should add a self-KO conversion route"),
		assert_eq(str(first_action.get("id", "")), "use_ability:bench_1:0:Cursed Blast", "Self-KO route should start from the legal Dusknoir ability"),
	])


func test_v17_bomb_charizard_llm_blocks_early_radiant_resource_sink() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "V17 Bomb Charizard LLM strategy should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var fire_to_radiant := {
		"kind": "attach_energy",
		"type": "attach_energy",
		"card": "Fire Energy",
		"target": "Radiant Charizard",
		"summary": "Attach Fire Energy to Radiant Charizard",
	}
	var stone_to_radiant := {
		"kind": "attach_tool",
		"type": "attach_tool",
		"card": "Forest Seal Stone",
		"target": "Radiant Charizard",
		"summary": "Attach Forest Seal Stone to Radiant Charizard",
	}
	var stone_to_charmander := {
		"kind": "attach_tool",
		"type": "attach_tool",
		"card": "Forest Seal Stone",
		"target": "Charmander",
		"summary": "Attach Forest Seal Stone to Charmander",
	}
	var rotom_slot := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.append(rotom_slot)
	var stone_to_rotom := {
		"kind": "attach_tool",
		"type": "attach_tool",
		"card": "Forest Seal Stone",
		"target": "Rotom V",
		"summary": "Attach Forest Seal Stone to Rotom V",
	}
	var fire_to_charmander := {
		"kind": "attach_energy",
		"type": "attach_energy",
		"card": "Fire Energy",
		"target": "Charmander",
		"summary": "Attach Fire Energy to Charmander",
	}
	var fire_card := _make_card(_make_energy_cd("Fire Energy", "R"), 0)
	var forest_stone_card := _make_card(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var fire_runtime_action := fire_to_radiant.duplicate(true)
	fire_runtime_action["card"] = fire_card
	fire_runtime_action["target_slot"] = player.active_pokemon
	var stone_runtime_action := stone_to_radiant.duplicate(true)
	stone_runtime_action["card"] = forest_stone_card
	stone_runtime_action["target_slot"] = player.active_pokemon
	var stone_to_charmander_runtime := stone_to_charmander.duplicate(true)
	stone_to_charmander_runtime["card"] = forest_stone_card
	stone_to_charmander_runtime["target_slot"] = player.bench[0]
	var stone_to_rotom_runtime := stone_to_rotom.duplicate(true)
	stone_to_rotom_runtime["card"] = forest_stone_card
	stone_to_rotom_runtime["target_slot"] = rotom_slot
	return run_checks([
		assert_true(strategy.call("_deck_should_block_exact_queue_match", {}, fire_to_radiant, gs, 0), "Early Fire should not be spent on Radiant Charizard while Charmander lane exists"),
		assert_true(strategy.call("_deck_should_block_exact_queue_match", {}, stone_to_radiant, gs, 0), "Forest Seal Stone should never be attached to Radiant Charizard"),
		assert_true(strategy.call("_deck_should_block_exact_queue_match", {}, stone_to_charmander, gs, 0), "Forest Seal Stone should not be attached to Charmander"),
		assert_false(strategy.call("_deck_should_block_exact_queue_match", {}, stone_to_rotom, gs, 0), "Forest Seal Stone should remain legal on Rotom V"),
		assert_false(strategy.call("_deck_should_block_exact_queue_match", {}, fire_to_charmander, gs, 0), "Fire attach to the Charmander lane should remain legal"),
		assert_true(float(strategy.call("score_action_absolute", fire_runtime_action, gs, 0)) <= -50000.0, "Local rules-plus-learned scoring should hard-block early Radiant Fire"),
		assert_true(float(strategy.call("score_action_absolute", stone_runtime_action, gs, 0)) <= -50000.0, "Local rules-plus-learned scoring should hard-block Forest Seal Stone on Radiant"),
		assert_true(float(strategy.call("score_action_absolute", stone_to_charmander_runtime, gs, 0)) <= -50000.0, "Local rules-plus-learned scoring should hard-block Forest Seal Stone on Charmander"),
		assert_true(float(strategy.call("score_action_absolute", stone_to_rotom_runtime, gs, 0)) > -50000.0, "Local rules-plus-learned scoring should not hard-block Forest Seal Stone on Rotom V"),
	])


func test_v17_bomb_charizard_llm_deprioritizes_forest_seal_without_v_target() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "V17 Bomb Charizard LLM strategy should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	var forest_stone := _make_card(_make_trainer_cd("Forest Seal Stone", "Tool"), 0)
	var defiance_band := _make_card(_make_trainer_cd("Defiance Band", "Tool"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var forest_without_v := float(strategy.call("score_interaction_target", forest_stone, {"id": "search_tool"}, context))
	var band_without_v := float(strategy.call("score_interaction_target", defiance_band, {"id": "search_tool"}, context))
	player.bench.append(_make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0))
	var forest_with_v := float(strategy.call("score_interaction_target", forest_stone, {"id": "search_tool"}, context))
	return run_checks([
		assert_true(forest_without_v < band_without_v, "Arven tool search should not prefer Forest Seal Stone without Rotom V or Lumineon V"),
		assert_true(forest_with_v > forest_without_v, "Forest Seal Stone should regain value once a valid V target exists"),
	])


func test_v17_bomb_charizard_llm_allows_late_radiant_fire_without_charizard_lane() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "V17 Bomb Charizard LLM strategy should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	var opponent: PlayerState = gs.players[1]
	while opponent.prizes.size() > 2:
		opponent.prizes.pop_back()
	var fire_to_radiant := {
		"kind": "attach_energy",
		"type": "attach_energy",
		"card": "Fire Energy",
		"target": "Radiant Charizard",
		"summary": "Attach Fire Energy to Radiant Charizard",
	}
	return run_checks([
		assert_false(strategy.call("_deck_should_block_exact_queue_match", {}, fire_to_radiant, gs, 0), "Late Radiant Charizard Fire attach should remain available when it is the live attacker"),
	])
