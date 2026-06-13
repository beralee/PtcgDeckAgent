class_name TestV175GardevoirLLM
extends TestBase

const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy175GardevoirLLM.gd"
const BUDEW_EFFECT_ID := "28505a8ad6e07e74382c1b5e09737932"
const CRESSELIA_EFFECT_ID := "5a56387211377cf56bfeb12751a5eed3"


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(LLM_SCRIPT_PATH)
	return script.new() if script is GDScript else null


func _make_deck_610080() -> DeckData:
	var deck := DeckData.new()
	deck.id = 610080
	deck.deck_name = "17.5 Gardevoir"
	deck.strategy = "Use Budew to slow Charizard while Ralts and Kirlia develop."
	deck.cards = [
		{"name_en": "Budew", "effect_id": BUDEW_EFFECT_ID, "card_type": "Pokemon", "count": 1},
		{"name_en": "Ralts", "card_type": "Pokemon", "count": 4},
		{"name_en": "Kirlia", "card_type": "Pokemon", "count": 4},
		{"name_en": "Gardevoir ex", "card_type": "Pokemon", "count": 2},
		{"name_en": "Scream Tail", "card_type": "Pokemon", "count": 1},
		{"name_en": "Munkidori", "card_type": "Pokemon", "count": 3},
		{"name_en": "Cresselia", "effect_id": CRESSELIA_EFFECT_ID, "card_type": "Pokemon", "count": 1},
	]
	return deck


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	effect_id: String = "",
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.effect_id = effect_id
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_trainer_cd(tname: String, subtype: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = tname
	cd.name_en = tname
	cd.card_type = subtype
	return cd


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


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_budew_cd() -> CardData:
	var cd := _make_pokemon_cd("Budew", "Basic", "G", 30, BUDEW_EFFECT_ID, [
		{"name": "Itchy Pollen", "cost": "0", "damage": "10"},
	])
	cd.retreat_cost = 0
	return cd


func _make_cresselia_cd() -> CardData:
	return _make_pokemon_cd("Cresselia", "Basic", "P", 120, CRESSELIA_EFFECT_ID, [
		{"name": "Moonglow Reverse", "cost": "P", "damage": ""},
		{"name": "Lunar Blast", "cost": "PPC", "damage": "110"},
	])


func _card_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if str(card.card_data.name_en) != "":
		return str(card.card_data.name_en)
	return str(card.card_data.name)


func _array_has_text(values: Variant, expected: String) -> bool:
	if not (values is Array):
		return false
	for raw: Variant in values:
		if str(raw) == expected:
			return true
	return false


func _attack_profile_has(profile: Dictionary, key: String, pokemon: String, attack: String) -> bool:
	var entries: Array = profile.get(key, []) if profile.get(key, []) is Array else []
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		if str(row.get("pokemon", "")) == pokemon and str(row.get("attack", "")) == attack:
			return true
	return false


func test_v175_gardevoir_llm_loads_and_registers() -> String:
	var llm_script := load(LLM_SCRIPT_PATH)
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "v175_gardevoir_llm") if registry != null else null
	return run_checks([
		assert_not_null(llm_script, "DeckStrategy175GardevoirLLM.gd should load"),
		assert_not_null(llm_instance, "DeckStrategy175GardevoirLLM.gd should instantiate"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null else "", "v175_gardevoir_llm", "17.5 Gardevoir LLM id should be stable"),
		assert_not_null(registry_instance, "Registry should create v175_gardevoir_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null else "", "v175_gardevoir_llm", "Registered 17.5 Gardevoir LLM should report its id"),
		assert_true(registry_instance != null and registry_instance.has_method("get_llm_stats"), "17.5 Gardevoir LLM should expose runtime stats"),
	])


func test_v175_gardevoir_llm_configures_budew_opening() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategy175GardevoirLLM.gd should load"
	strategy.call("configure_from_deck", _make_deck_610080())
	var player := PlayerState.new()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Ralts"), 0))
	player.hand.append(CardInstance.create(_make_budew_cd(), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Klefki"), 0))

	var setup: Dictionary = strategy.call("plan_opening_setup", player)
	var active_index := int(setup.get("active_hand_index", -1))
	var bench_indices: Array = setup.get("bench_hand_indices", []) if setup.get("bench_hand_indices", []) is Array else []
	var bench_names: Array[String] = []
	for raw_index: Variant in bench_indices:
		bench_names.append(_card_name(player.hand[int(raw_index)]))

	return run_checks([
		assert_eq(_card_name(player.hand[active_index]) if active_index >= 0 else "", "Budew", "Configured 610080 should use Budew as the opening buffer"),
		assert_true("Ralts" in bench_names, "Configured 610080 should develop Ralts behind Budew"),
	])


func test_v175_gardevoir_llm_prompt_and_profile_match_175_plan() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategy175GardevoirLLM.gd should load"
	strategy.call("configure_from_deck", _make_deck_610080())
	var prompt_text := "\n".join(strategy.call("get_llm_deck_strategy_prompt", null, 0))
	var profile: Dictionary = strategy.call("get_intent_planner_profile")
	return run_checks([
		assert_str_contains(prompt_text, "17.5 Gardevoir", "Prompt should identify the 17.5 Gardevoir deck"),
		assert_str_contains(prompt_text, "Budew", "Prompt should explain the Budew opening lock plan"),
		assert_str_contains(prompt_text, "Charizard ex", "Prompt should include the Charizard matchup anchor"),
		assert_str_contains(prompt_text, "Scream Tail", "Prompt should name Scream Tail as the main payoff"),
		assert_str_contains(prompt_text, "Cresselia", "Prompt should name Cresselia as the counter-conversion attacker"),
		assert_str_contains(prompt_text, "Munkidori", "Prompt should name Munkidori as damage-counter support"),
		assert_str_contains(prompt_text, "Do not plan Drifloon", "Prompt should override the old Drifloon Gardevoir plan"),
		assert_str_contains(prompt_text, "Deck-out policy", "Prompt should explicitly stop low-deck optional draw churn"),
		assert_true(_array_has_text(profile.get("primary_attackers", []), "Scream Tail"), "Profile should treat Scream Tail as primary"),
		assert_true(_array_has_text(profile.get("secondary_attackers", []), "Cresselia"), "Profile should treat Cresselia as a secondary counter attacker"),
		assert_false(_array_has_text(profile.get("primary_attackers", []), "Drifloon"), "17.5 profile should not keep old Drifloon primary routes"),
		assert_true(_attack_profile_has(profile, "setup_draw_attacks", "Budew", "Itchy Pollen"), "Profile should expose Budew's item-lock attack as the opening terminal"),
	])


func test_v175_gardevoir_llm_low_deck_blocks_optional_draw_trainers() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategy175GardevoirLLM.gd should load"
	var gs := _make_game_state(31)
	var player := gs.players[0]
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Card %d" % i), 0))
	var research := {"kind": "play_trainer", "card": "Professor's Research"}
	var iono := {"kind": "play_trainer", "card": "Iono"}
	var rare_candy := {"kind": "play_trainer", "card": "Rare Candy"}
	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, research, gs, 0)), "Low-deck 17.5 Gardevoir should block Professor's Research before deck-out"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, iono, gs, 0)), "Low-deck 17.5 Gardevoir should block optional Iono churn"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, rare_candy, gs, 0)), "Low-deck guard should not block non-draw trainer setup"),
	])


func test_v175_gardevoir_llm_role_hints_cover_new_cards() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategy175GardevoirLLM.gd should load"
	var budew_hint := str(strategy.call("get_llm_setup_role_hint", _make_budew_cd()))
	var cresselia_hint := str(strategy.call("get_llm_setup_role_hint", _make_cresselia_cd()))
	return run_checks([
		assert_str_contains(budew_hint, "item-lock", "Budew hint should describe the item-lock buffer role"),
		assert_str_contains(cresselia_hint, "damage-counter", "Cresselia hint should describe damage-counter conversion"),
	])
