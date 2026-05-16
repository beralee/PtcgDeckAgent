class_name TestAIIntentPlanners
extends TestBase

const PROMPT_BUILDER_SCRIPT_PATH := "res://scripts/ai/LLMTurnPlanPromptBuilder.gd"
const COORDINATOR_SCRIPT_PATH := "res://scripts/ai/intent/AIIntentPlannerCoordinator.gd"
const LLM_PROFILE_SCRIPT_PATHS := [
	"res://scripts/ai/DeckStrategyArceusGiratinaLLM.gd",
	"res://scripts/ai/DeckStrategyCharizardExLLM.gd",
	"res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd",
	"res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd",
	"res://scripts/ai/DeckStrategyGardevoirLLM.gd",
	"res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd",
	"res://scripts/ai/DeckStrategyMiraidonLLM.gd",
	"res://scripts/ai/DeckStrategyRagingBoltLLM.gd",
	"res://scripts/ai/DeckStrategy17ArchaludonDialgaLLM.gd",
	"res://scripts/ai/DeckStrategy17WaterTurtleLLM.gd",
	"res://scripts/ai/DeckStrategy17PalkiaGholdengoLLM.gd",
	"res://scripts/ai/DeckStrategy17BombCharizardLLM.gd",
	"res://scripts/ai/DeckStrategy17MiraidonLLM.gd",
	"res://scripts/ai/DeckStrategy17DragapultDusknoirLLM.gd",
	"res://scripts/ai/DeckStrategy17RegidragoLLM.gd",
]


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "N",
	hp: int = 100,
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.retreat_cost = 1
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_dragapult_ex_cd() -> CardData:
	return _make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, [
		{"name": "Jet Head", "cost": "P", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "Put 6 damage counters on your opponent's Benched Pokemon in any way you like."},
	])


func _make_lugia_vstar_cd() -> CardData:
	return _make_pokemon_cd("Lugia VSTAR", "VSTAR", "C", 280, [
		{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"},
	])


func _make_munkidori_cd() -> CardData:
	return _make_pokemon_cd("Munkidori", "Basic", "P", 110, [
		{"name": "Psychic", "cost": "PC", "damage": "60"},
	])


func _make_energy_cd(pname: String, symbol: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = symbol
	return cd


func _make_slot(cd: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner))
	slot.turn_played = 0
	return slot


func _attached_energy(name: String, symbol: String, owner: int = 0) -> CardInstance:
	return CardInstance.create(_make_energy_cd(name, symbol), owner)


func _make_game_state() -> GameState:
	CardInstance.reset_id_counter()
	var gs := GameState.new()
	gs.turn_number = 3
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi), pi)
		gs.players.append(player)
	return gs


func _profile() -> Dictionary:
	return {
		"primary_attackers": ["Dragapult ex", "Lugia VSTAR"],
		"support_only": ["Manaphy", "Lumineon V", "Fezandipiti ex"],
		"evolution_lines": [
			{"basic": "Dreepy", "stages": ["Drakloak", "Dragapult ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"R": 1, "P": 1}},
			{"basic": "Lugia V", "stages": ["Lugia VSTAR"], "role": "primary_attacker", "desired_count": 1, "energy": {"C": 4}},
		],
		"energy_needs": {
			"Dragapult ex": {"R": 1, "P": 1},
			"Lugia VSTAR": {"C": 4},
		},
		"primary_attacks": [
			{"pokemon": "Dragapult ex", "attack": "Phantom Dive"},
			{"pokemon": "Lugia VSTAR", "attack": "Tempest Dive"},
		],
		"low_value_attacks": [{"pokemon": "Dragapult ex", "attack": "Jet Head"}],
	}


func _new_prompt_builder() -> RefCounted:
	var script := _load_script(PROMPT_BUILDER_SCRIPT_PATH)
	return script.new() if script != null else null


func _find_intent(intents: Array, action_id_fragment: String) -> Dictionary:
	var needle := action_id_fragment.to_lower()
	for raw: Variant in intents:
		if not (raw is Dictionary):
			continue
		var intent: Dictionary = raw
		var haystack := "%s %s %s %s" % [
			str(intent.get("action_id", "")),
			str(intent.get("attack_name", "")),
			str(intent.get("energy_name", "")),
			str(intent.get("target_name", "")),
		]
		if haystack.to_lower().find(needle) >= 0:
			return intent
	return {}


func test_prompt_payload_exposes_common_intent_facts() -> String:
	var builder := _new_prompt_builder()
	if builder == null:
		return "LLMTurnPlanPromptBuilder.gd should instantiate"
	builder.call("set_intent_planner_profile", _profile())
	var gs := _make_game_state()
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	gs.players[0].active_pokemon = dragapult
	gs.players[1].active_pokemon = _make_slot(_make_munkidori_cd(), 1)
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, [
		{"kind": "attack", "attack_index": 0},
		{"kind": "attack", "attack_index": 1},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("intent_facts", {}) if payload.get("intent_facts", {}) is Dictionary else {}
	var attack_intents: Array = facts.get("attack_intents", []) if facts.get("attack_intents", []) is Array else []
	var phantom := _find_intent(attack_intents, "phantom")
	var jet := _find_intent(attack_intents, "jet")
	return run_checks([
		assert_false(facts.is_empty(), "Payload should include intent_facts"),
		assert_eq(str(phantom.get("role", "")), "primary_damage", "Phantom Dive should be a primary attack intent"),
		assert_eq(str(jet.get("terminal_priority", "")), "low", "Jet Head should be low priority under the profile"),
		assert_true(bool(jet.get("blocked_by_better_attack", false)), "Jet Head should be blocked when Phantom Dive is ready"),
	])


func test_energy_intent_prefers_missing_attribute_and_penalizes_overfill() -> String:
	var builder := _new_prompt_builder()
	if builder == null:
		return "LLMTurnPlanPromptBuilder.gd should instantiate"
	builder.call("set_intent_planner_profile", _profile())
	var gs := _make_game_state()
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	gs.players[0].active_pokemon = dragapult
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, [
		{"kind": "attach_energy", "card": fire, "target_slot": dragapult},
		{"kind": "attach_energy", "card": psychic, "target_slot": dragapult},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("intent_facts", {}) if payload.get("intent_facts", {}) is Dictionary else {}
	var energy_intents: Array = facts.get("energy_intents", []) if facts.get("energy_intents", []) is Array else []
	var fire_intent := _find_intent(energy_intents, "fire")
	var psychic_intent := _find_intent(energy_intents, "psychic")
	return run_checks([
		assert_eq(str(psychic_intent.get("marginal_value", "")), "high", "Psychic attach should fill Dragapult's missing cost"),
		assert_eq(str(fire_intent.get("marginal_value", "")), "low", "Second Fire attach should be low value while Psychic is missing"),
		assert_true(bool(fire_intent.get("is_overfill", false)) or bool(fire_intent.get("is_wrong_attribute", false)), "Second Fire attach should be marked as overfill or wrong attribute"),
	])


func test_colorless_cost_caps_stop_lugia_energy_overfill() -> String:
	var builder := _new_prompt_builder()
	if builder == null:
		return "LLMTurnPlanPromptBuilder.gd should instantiate"
	builder.call("set_intent_planner_profile", _profile())
	var gs := _make_game_state()
	var lugia := _make_slot(_make_lugia_vstar_cd(), 0)
	for i: int in 4:
		lugia.attached_energy.append(_attached_energy("Colorless Energy %d" % i, "C"))
	gs.players[0].active_pokemon = lugia
	var extra := CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0)
	var payload: Dictionary = builder.call("build_action_id_request_payload", gs, 0, [
		{"kind": "attach_energy", "card": extra, "target_slot": lugia},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("intent_facts", {}) if payload.get("intent_facts", {}) is Dictionary else {}
	var energy_intents: Array = facts.get("energy_intents", []) if facts.get("energy_intents", []) is Array else []
	var attach_intent := _find_intent(energy_intents, "double")
	return run_checks([
		assert_true(bool(attach_intent.get("is_overfill", false)), "Fifth Lugia VSTAR energy should be overfill when the attack cap is 4"),
		assert_eq(str(attach_intent.get("marginal_value", "")), "low", "Overfill Lugia energy should be low marginal value"),
	])


func test_intent_planner_scripts_load() -> String:
	var coordinator_script := _load_script(COORDINATOR_SCRIPT_PATH)
	var coordinator = coordinator_script.new() if coordinator_script != null and coordinator_script.can_instantiate() else null
	return run_checks([
		assert_not_null(coordinator_script, "AIIntentPlannerCoordinator.gd should load"),
		assert_not_null(coordinator, "AIIntentPlannerCoordinator.gd should instantiate"),
	])


func test_all_llm_decks_expose_intent_profiles() -> String:
	var checks: Array[String] = []
	for script_path: String in LLM_PROFILE_SCRIPT_PATHS:
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s should load" % script_path))
		if script == null or not script.can_instantiate():
			checks.append("%s should instantiate" % script_path)
			continue
		var strategy: RefCounted = script.new()
		checks.append(assert_true(strategy.has_method("get_intent_planner_profile"), "%s should expose get_intent_planner_profile" % script_path))
		var profile: Dictionary = strategy.call("get_intent_planner_profile") if strategy.has_method("get_intent_planner_profile") else {}
		checks.append(assert_false(profile.is_empty(), "%s should return a non-empty intent planner profile" % script_path))
		checks.append(assert_true(profile.has("primary_attackers"), "%s profile should declare primary_attackers" % script_path))
		checks.append(assert_true(profile.has("energy_needs") or profile.has("evolution_lines"), "%s profile should declare energy_needs or evolution_lines" % script_path))
	return run_checks(checks)


func test_v17_llm_decks_emit_deck_specific_prompt_lines() -> String:
	var v17_paths := [
		"res://scripts/ai/DeckStrategy17ArchaludonDialgaLLM.gd",
		"res://scripts/ai/DeckStrategy17WaterTurtleLLM.gd",
		"res://scripts/ai/DeckStrategy17PalkiaGholdengoLLM.gd",
		"res://scripts/ai/DeckStrategy17BombCharizardLLM.gd",
		"res://scripts/ai/DeckStrategy17MiraidonLLM.gd",
		"res://scripts/ai/DeckStrategy17DragapultDusknoirLLM.gd",
		"res://scripts/ai/DeckStrategy17RegidragoLLM.gd",
	]
	var checks: Array[String] = []
	for script_path: String in v17_paths:
		var script := _load_script(script_path)
		checks.append(assert_not_null(script, "%s should load" % script_path))
		if script == null or not script.can_instantiate():
			continue
		var strategy: RefCounted = script.new()
		checks.append(assert_true(strategy.has_method("get_llm_deck_strategy_prompt"), "%s should expose get_llm_deck_strategy_prompt" % script_path))
		var prompt: PackedStringArray = strategy.call("get_llm_deck_strategy_prompt", null, -1) if strategy.has_method("get_llm_deck_strategy_prompt") else PackedStringArray()
		var joined := "\n".join(prompt)
		checks.append(assert_true(prompt.size() >= 6, "%s should provide enough deck-specific prompt lines" % script_path))
		checks.append(assert_true(joined.contains("17.0"), "%s prompt should identify the v17 plan family" % script_path))
		checks.append(assert_true(joined.contains("legal_actions") and joined.contains("interaction_schema"), "%s prompt should preserve structured-action constraints" % script_path))
	return run_checks(checks)


func test_v17_llm_blocks_primary_attacker_retreat_to_support_energy_bank() -> String:
	var script := _load_script("res://scripts/ai/DeckStrategy17RegidragoLLM.gd")
	if script == null or not script.can_instantiate():
		return "DeckStrategy17RegidragoLLM.gd should instantiate"
	var strategy: RefCounted = script.new()
	var gs := _make_game_state()
	var drago := _make_slot(_make_pokemon_cd("雷吉铎拉戈VSTAR", "VSTAR", "N", 280, [
		{"name": "巨龙无双", "cost": "GGR", "damage": ""},
	]), 0)
	drago.attached_energy.append(_attached_energy("基本草能量", "G"))
	drago.attached_energy.append(_attached_energy("基本草能量", "G"))
	drago.attached_energy.append(_attached_energy("基本火能量", "R"))
	var ogerpon := _make_slot(_make_pokemon_cd("厄诡椪 碧草面具ex", "Basic", "G", 210, [
		{"name": "万叶阵雨", "cost": "GC", "damage": "120"},
	]), 0)
	ogerpon.attached_energy.append(_attached_energy("基本草能量", "G"))
	ogerpon.attached_energy.append(_attached_energy("基本草能量", "G"))
	gs.players[0].active_pokemon = drago
	gs.players[0].bench.clear()
	gs.players[0].bench.append(ogerpon)
	var blocked_score := float(strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": ogerpon,
	}, gs, 0))
	gs.players[0].active_pokemon = ogerpon
	gs.players[0].bench.clear()
	gs.players[0].bench.append(drago)
	var allowed_score := float(strategy.call("score_action_absolute", {
		"kind": "retreat",
		"bench_target": drago,
	}, gs, 0))
	return run_checks([
		assert_true(blocked_score <= -9000.0, "Charged Regidrago VSTAR should not retreat into Ogerpon support attacker"),
		assert_true(allowed_score > -9000.0, "Support energy bank should still be allowed to retreat into ready Regidrago VSTAR"),
	])
