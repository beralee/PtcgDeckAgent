extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018501
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018501.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018501/complex_decision_scenarios.json"

const IMPIDIMP_UID := "CSV10C_146"
const MORGREM_UID := "CSV10C_147"
const GRIMMSNARL_UID := "CSV10C_148"
const MUNKIDORI_UID := "CSV8C_094"
const SNORUNT_UID := "CSV9.5C_043"
const FROSLASS_UID := "CSV7C_059"
const BUDEW_UID := "CSV9.5C_004"
const ARVEN_UID := "CSV1C_123"
const IONO_UID := "CSV3C_123"
const POFFIN_UID := "CSV7C_177"
const RARE_CANDY_UID := "CSVH1C_045"
const TM_EVOLUTION_UID := "CSV5C_119"
const SPIKEMUTH_UID := "CSV10C_216"
const DARKNESS_UID := "CSVE1C_DAR"
const RESEARCH_UID := "CSV1C_121"
const ULTRA_BALL_UID := "CSV1C_112"
const COUNTER_CATCHER_UID := "CSV6C_114"
const IRON_HANDS_UID := "CSV6C_051"

const PUNK_UP_STEP := "marnies_punk_up_assignments"
const SPIKEMUTH_STEP := "spikemuth_gym_marnies_pokemon"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Marnie's Grimmsnarl profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Marnie's Grimmsnarl semantic manifest must load")
	_check(_profile.get("modules", []) == ["stage2_chain", "energy_burst", "damage_counter_control"], \
		"scenarios must use the production Stage 2, Darkness acceleration, and counter-control composition")

	_scenario_a_second_player_arven_poffin_tm_double_root()
	_scenario_b_spikemuth_candy_punk_up_and_manual_dark()
	_scenario_c_froslass_check_feeds_adrena_brain()
	_scenario_d_adrena_brain_before_shadow_bullet_breakpoint()
	_scenario_e_shadow_bullet_three_prize_closeout()
	_scenario_f_preserve_visible_grimmsnarl_setup_before_research()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 6:
		print("optimization21 800018501 complex decision scenarios: PASS (6/6)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018501 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_second_player_arven_poffin_tm_double_root() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(2, 1)
	var budew := _real_slot(_real_card_data(BUDEW_UID), 0)
	budew.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	state.players[0].active_pokemon = budew
	state.players[1].active_pokemon = _real_target("Public opening target", 200, 1)
	var arven := _real_instance(ARVEN_UID, 0)
	var poffin := _real_instance(POFFIN_UID, 0)
	var tm := _real_instance(TM_EVOLUTION_UID, 0)
	var impidimp := _real_instance(IMPIDIMP_UID, 0)
	var snorunt := _real_instance(SNORUNT_UID, 0)
	var morgrem := _real_instance(MORGREM_UID, 0)
	var froslass := _real_instance(FROSLASS_UID, 0)
	state.players[0].hand = [arven]
	state.players[0].deck = [
		poffin, tm, impidimp, snorunt, morgrem, froslass,
		_filler_instance("VISIBLE_OPENING_FILLER", 0),
	]

	var arven_effect := processor.get_effect(arven.card_data.effect_id)
	var arven_steps: Array = arven_effect.get_interaction_steps(arven, state) if arven_effect != null else []
	var item_step := _step(arven_steps, "search_item")
	var tool_step := _step(arven_steps, "search_tool")
	var arven_public := str(item_step.get("visible_scope", "")) == "own_full_deck" \
		and str(tool_step.get("visible_scope", "")) == "own_full_deck" \
		and poffin in (item_step.get("items", []) as Array) \
		and tm in (tool_step.get("items", []) as Array)
	var arven_executed := processor.execute_card_effect(arven, [{
		"search_item": [poffin],
		"search_tool": [tm],
	}], state)

	var poffin_effect := processor.get_effect(poffin.card_data.effect_id)
	var poffin_steps: Array = poffin_effect.get_interaction_steps(poffin, state) if poffin_effect != null else []
	var poffin_step := _step(poffin_steps, "buddy_poffin_pokemon")
	var poffin_public := str(poffin_step.get("visible_scope", "")) == "own_full_deck" \
		and impidimp in (poffin_step.get("items", []) as Array) \
		and snorunt in (poffin_step.get("items", []) as Array)
	var poffin_executed := processor.execute_card_effect(poffin, [{
		"buddy_poffin_pokemon": [impidimp, snorunt],
	}], state)
	var root_uids := _slot_uids(state.players[0].bench)

	state.players[0].hand.erase(tm)
	budew.attached_tool = tm
	var tm_effect := processor.get_effect(tm.card_data.effect_id)
	var granted: Array = processor.get_granted_attacks(budew, state)
	var granted_ready := not granted.is_empty() \
		and RuleValidator.new().can_use_granted_attack(state, 0, budew, granted[0], processor)
	var first_steps: Array = tm_effect.get_granted_attack_interaction_steps(budew, granted[0], state) \
		if tm_effect != null and not granted.is_empty() else []
	var followup: Array = tm_effect.get_followup_granted_attack_interaction_steps(
		budew, granted[0], state, {"evolution_bench": state.players[0].bench}
	) if tm_effect != null and not granted.is_empty() else []
	var evolution_step := _step(followup, "evolution_cards")
	var tm_public := not first_steps.is_empty() \
		and str(evolution_step.get("visible_scope", "")) == "own_full_deck" \
		and morgrem in (evolution_step.get("items", []) as Array) \
		and froslass in (evolution_step.get("items", []) as Array)
	if tm_effect != null and not granted.is_empty():
		tm_effect.execute_granted_attack(budew, granted[0], state, [{
			"evolution_bench": state.players[0].bench,
			"evolution_cards": [morgrem, froslass],
		}])
	var evolved_uids := _slot_uids(state.players[0].bench)

	var no_energy_state := _game_state(2, 1)
	var no_energy_budew := _real_slot(_real_card_data(BUDEW_UID), 0)
	no_energy_budew.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	no_energy_state.players[0].active_pokemon = no_energy_budew
	no_energy_state.players[0].bench = [_real_slot(_real_card_data(IMPIDIMP_UID), 0)]
	no_energy_state.players[0].deck = [_real_instance(MORGREM_UID, 0)]
	no_energy_state.players[1].active_pokemon = _real_target("Public no-energy target", 200, 1)
	var no_energy_granted := processor.get_granted_attacks(no_energy_budew, no_energy_state)
	var no_energy_blocked := not no_energy_granted.is_empty() \
		and not RuleValidator.new().can_use_granted_attack(
			no_energy_state, 0, no_energy_budew, no_energy_granted[0], processor)

	var first_player_state := _game_state(1, 0)
	var first_player_budew := _real_slot(_real_card_data(BUDEW_UID), 0)
	first_player_budew.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	first_player_budew.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	first_player_state.players[0].active_pokemon = first_player_budew
	first_player_state.players[0].bench = [_real_slot(_real_card_data(IMPIDIMP_UID), 0)]
	first_player_state.players[0].deck = [_real_instance(MORGREM_UID, 0)]
	first_player_state.players[1].active_pokemon = _real_target("Public first-player target", 200, 1)
	var first_player_granted := processor.get_granted_attacks(first_player_budew, first_player_state)
	var first_player_blocked := not first_player_granted.is_empty() \
		and not RuleValidator.new().can_use_granted_attack(
			first_player_state, 0, first_player_budew, first_player_granted[0], processor)

	var passed := arven_public and arven_executed and poffin_public and poffin_executed \
		and root_uids == [IMPIDIMP_UID, SNORUNT_UID] and granted_ready and tm_public \
		and evolved_uids == [MORGREM_UID, FROSLASS_UID] \
		and no_energy_blocked and first_player_blocked
	_check(passed, "scenario A must prove real Arven -> Poffin -> payable second-player TM double evolution")
	_rows.append(_row(
		"second_player_arven_poffin_tm_double_root",
		"开局根/支援者/双进化",
		"二后手含羞苞已有1恶能，先用派帕公开检索友好宝芬与进化TM；宝芬铺玛俐的捣蛋小妖、雪童子，TM再分别进化成诈唬魔、雪妖女。",
		"Arven(Poffin+TM) -> Poffin(Impidimp+Snorunt) -> TM Evolution(Morgrem+Froslass)",
		["first player's first turn cannot attack", "TM carrier without one payable Energy cannot use Evolution"],
		passed
	))


func _scenario_b_spikemuth_candy_punk_up_and_manual_dark() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var impidimp_active := _real_slot(_real_card_data(IMPIDIMP_UID), 0)
	impidimp_active.turn_played = 2
	var backup_impidimp := _real_slot(_real_card_data(IMPIDIMP_UID), 0)
	backup_impidimp.turn_played = 4
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	state.players[0].active_pokemon = impidimp_active
	state.players[0].bench = [backup_impidimp, munkidori]
	state.players[1].active_pokemon = _real_target("Public Punk Up target", 260, 2)
	var stadium := _real_instance(SPIKEMUTH_UID, 0)
	state.stadium_card = stadium
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var manual_dark := _real_instance(DARKNESS_UID, 0)
	var grimmsnarl := _real_instance(GRIMMSNARL_UID, 0)
	var morgrem_reference := _real_instance(MORGREM_UID, 0)
	var deck_munkidori := _real_instance(MUNKIDORI_UID, 0)
	var dark_a := _real_instance(DARKNESS_UID, 0)
	var dark_b := _real_instance(DARKNESS_UID, 0)
	var dark_c := _real_instance(DARKNESS_UID, 0)
	var dark_d := _real_instance(DARKNESS_UID, 0)
	state.players[0].hand = [candy, manual_dark, _real_instance(IONO_UID, 0)]
	state.players[0].deck = [
		grimmsnarl, morgrem_reference, deck_munkidori,
		dark_a, dark_b, dark_c, dark_d,
		_filler_instance("FORBIDDEN_SECRET_DECK_FILLER", 0),
	]

	var before := _observation(
		[
			_use_stadium("stadium:spikemuth-before-iono", SPIKEMUTH_UID),
			_play_trainer("supporter:iono-too-early", IONO_UID, false),
			_end_turn("end:before-spikemuth"),
		],
		_slot("slot:active", IMPIDIMP_UID, []),
		[_slot("slot:backup", IMPIDIMP_UID, []), _slot("slot:munkidori", MUNKIDORI_UID, [])],
		8
	)
	before["observation_version"] = 1
	before["observation_hash"] = "marnie-before-spikemuth"
	before["own"]["hand"] = [_card(RARE_CANDY_UID), _energy_card(DARKNESS_UID), _card(IONO_UID)]
	var facts_before := _facts(false, false, true, 3, false, false, 20)
	var frontier := _frontier(before, {
		"stadium:spikemuth-before-iono": 560.0,
		"supporter:iono-too-early": 520.0,
		"end:before-spikemuth": -900.0,
	}, facts_before, "stadium:spikemuth-before-iono")
	var stadium_candidate := _candidate(frontier, "stadium:spikemuth-before-iono")

	var stadium_effect := processor.get_effect(stadium.card_data.effect_id)
	var stadium_steps: Array = stadium_effect.get_interaction_steps(stadium, state) if stadium_effect != null else []
	var stadium_step := _step(stadium_steps, SPIKEMUTH_STEP)
	var stadium_public := str(stadium_step.get("visible_scope", "")) == "own_full_deck" \
		and grimmsnarl in (stadium_step.get("items", []) as Array) \
		and morgrem_reference in (stadium_step.get("items", []) as Array) \
		and deck_munkidori not in (stadium_step.get("items", []) as Array)
	var searched := processor.execute_card_effect(stadium, [{SPIKEMUTH_STEP: [grimmsnarl]}], state)

	var after_search := before.duplicate(true)
	after_search["observation_version"] = 2
	after_search["observation_hash"] = "marnie-after-spikemuth"
	after_search["own"]["hand"] = [
		_card(RARE_CANDY_UID), _energy_card(DARKNESS_UID), _card(IONO_UID), _card(GRIMMSNARL_UID),
	]
	after_search["own"]["deck_count"] = 7
	after_search["legal_actions"] = [
		_evolve("evolve:candy-grimmsnarl", GRIMMSNARL_UID, "slot:active"),
		_play_trainer("supporter:iono-after-search", IONO_UID, false),
	]
	var facts_after_search := _facts(false, false, true, 4, false, false, 20)
	var reopened := _epoch_reopens(
		before, after_search, facts_before, facts_after_search, stadium_candidate, frontier)

	var candy_effect := processor.get_effect(candy.card_data.effect_id)
	var candy_steps: Array = candy_effect.get_interaction_steps(candy, state) if candy_effect != null else []
	var candy_exact := grimmsnarl in (_step(candy_steps, "stage2_card").get("items", []) as Array) \
		and impidimp_active in (_step(candy_steps, "target_pokemon").get("items", []) as Array)
	var candied := processor.execute_card_effect(candy, [{
		"stage2_card": [grimmsnarl],
		"target_pokemon": [impidimp_active],
	}], state)
	processor.register_pokemon_card(grimmsnarl.card_data)

	var punk_effect := processor.get_ability_effect(impidimp_active, 0, state)
	var punk_steps: Array = punk_effect.get_interaction_steps(grimmsnarl, state) if punk_effect != null else []
	var punk_step := _step(punk_steps, PUNK_UP_STEP)
	var punk_contract := str(punk_step.get("visible_scope", "")) == "own_full_deck" \
		and int(punk_step.get("max_select", 0)) == 4 \
		and (punk_step.get("source_items", []) as Array).size() == 4 \
		and impidimp_active in (punk_step.get("target_items", []) as Array) \
		and backup_impidimp in (punk_step.get("target_items", []) as Array) \
		and munkidori not in (punk_step.get("target_items", []) as Array)
	var accelerated := processor.execute_ability_effect(impidimp_active, 0, [{PUNK_UP_STEP: [
		{"source": dark_a, "target": impidimp_active},
		{"source": dark_b, "target": impidimp_active},
		{"source": dark_c, "target": backup_impidimp},
		{"source": dark_d, "target": backup_impidimp},
	]}], state)
	state.players[0].hand.erase(manual_dark)
	munkidori.attached_energy.append(manual_dark)
	var attack_ready := RuleValidator.new().can_use_attack(state, 0, 0, processor)
	var manual_dark_preserved := manual_dark in munkidori.attached_energy \
		and munkidori.attached_energy.size() == 1

	var fresh_root_state := _game_state()
	var fresh_root := _real_slot(_real_card_data(IMPIDIMP_UID), 0)
	fresh_root.turn_played = fresh_root_state.turn_number
	fresh_root_state.players[0].active_pokemon = fresh_root
	var fresh_candy := _real_instance(RARE_CANDY_UID, 0)
	fresh_root_state.players[0].hand = [fresh_candy, _real_instance(GRIMMSNARL_UID, 0)]
	fresh_root_state.players[0].deck = [_real_instance(MORGREM_UID, 0)]
	var fresh_root_blocked := candy_effect != null and not candy_effect.can_execute(fresh_candy, fresh_root_state)

	var passed := stadium_public and searched and grimmsnarl not in state.players[0].hand \
		and reopened and candy_exact and candied \
		and impidimp_active.get_card_data().get_uid() == GRIMMSNARL_UID \
		and punk_contract and accelerated \
		and impidimp_active.attached_energy.size() == 2 \
		and backup_impidimp.attached_energy.size() == 2 \
		and manual_dark_preserved and attack_ready and fresh_root_blocked
	_check(passed, "scenario B must search Grimmsnarl before Iono, Candy an old root, then split Punk Up while reserving hand attachment for Munkidori")
	_rows.append(_row(
		"spikemuth_candy_punk_up_and_manual_dark",
		"场馆检索/糖果/加速/手贴",
		"先用尖钉镇道馆公开找长毛巨魔，再由神奇糖果进化旧捣蛋小妖；庞克泵感给当前与后续玛俐轴各2恶，手贴恶能留给不属于玛俐轴、无法吃特性加速的愿增猿。",
		"Spikemuth(Grimmsnarl) -> Rare Candy -> Punk Up(2+2) -> manual Darkness to Munkidori",
		["Spikemuth cannot search Munkidori", "Punk Up cannot attach to Munkidori", "Rare Candy cannot evolve a root played this turn"],
		passed
	))


func _scenario_c_froslass_check_feeds_adrena_brain() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(10, 0)
	var grimmsnarl := _real_slot(_real_card_data(GRIMMSNARL_UID), 0)
	grimmsnarl.damage_counters = 20
	var froslass := _real_slot(_real_card_data(FROSLASS_UID), 0)
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	munkidori.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	state.players[0].active_pokemon = grimmsnarl
	state.players[0].bench = [froslass, munkidori]
	var opponent_ability := _target_with_ability("Public ability target", 200, 2)
	var opponent_plain := _real_target("Public no-ability target", 100, 1)
	state.players[1].active_pokemon = opponent_ability
	state.players[1].bench = [opponent_plain]
	processor.register_pokemon_card(froslass.get_card_data())
	processor.register_pokemon_card(munkidori.get_card_data())

	var damaged := processor.process_pokemon_check(state)
	var freezing_exact := grimmsnarl.damage_counters == 30 \
		and munkidori.damage_counters == 10 \
		and opponent_ability.damage_counters == 10 \
		and froslass.damage_counters == 0 \
		and opponent_plain.damage_counters == 0 \
		and grimmsnarl in damaged and munkidori in damaged and opponent_ability in damaged

	var ability_effect := processor.get_ability_effect(munkidori, 0, state)
	var source_steps: Array = ability_effect.get_interaction_steps(munkidori.get_top_card(), state) \
		if ability_effect != null else []
	var source_step := _step(source_steps, "source_pokemon")
	var source_exact := grimmsnarl in (source_step.get("items", []) as Array) \
		and froslass not in (source_step.get("items", []) as Array)
	var followup: Array = ability_effect.get_followup_interaction_steps(
		munkidori.get_top_card(), state, {"source_pokemon": [grimmsnarl]}
	) if ability_effect != null else []
	var counter_step := _step(followup, "target_damage_counters")
	var counter_contract := str(counter_step.get("ui_mode", "")) == "counter_distribution" \
		and int(counter_step.get("total_counters", 0)) == 3 \
		and opponent_ability in (counter_step.get("target_items", []) as Array)
	var moved := processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [grimmsnarl],
		"target_damage_counters": [{"target": opponent_ability, "amount": 30}],
	}], state)

	var no_dark_processor := EffectProcessor.new()
	var no_dark_state := _game_state(10, 0)
	var no_dark_munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	var damaged_source := _real_slot(_real_card_data(GRIMMSNARL_UID), 0)
	damaged_source.damage_counters = 30
	no_dark_state.players[0].active_pokemon = damaged_source
	no_dark_state.players[0].bench = [no_dark_munkidori]
	no_dark_state.players[1].active_pokemon = _real_target("Public no-dark target", 200, 1)
	no_dark_processor.register_pokemon_card(no_dark_munkidori.get_card_data())
	var no_dark_blocked := not no_dark_processor.can_use_ability(no_dark_munkidori, no_dark_state, 0)

	var passed := freezing_exact and source_exact and counter_contract and moved \
		and grimmsnarl.damage_counters == 0 and opponent_ability.damage_counters == 40 \
		and froslass.damage_counters == 0 and no_dark_blocked
	_check(passed, "scenario C must turn real Froslass check damage into an exact three-counter Munkidori transfer")
	_rows.append(_row(
		"froslass_check_feeds_adrena_brain",
		"被动铺伤/伤害搬运",
		"雪妖女在宝可梦检查时给双方有特性的非雪妖女宝可梦各放1个指示物，使长毛巨魔从20累积到30；有恶能的愿增猿随后把这3个指示物完整搬到对手公开目标。",
		"Freezing Shroud -> Adrena-Brain move exactly 3 counters from Grimmsnarl",
		["Froslass must not damage itself", "Pokemon without an Ability are excluded", "Munkidori without Darkness Energy cannot use the Ability"],
		passed
	))


func _scenario_d_adrena_brain_before_shadow_bullet_breakpoint() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var grimmsnarl := _real_slot(_real_card_data(GRIMMSNARL_UID), 0)
	grimmsnarl.attached_energy = [_real_instance(DARKNESS_UID, 0), _real_instance(DARKNESS_UID, 0)]
	grimmsnarl.damage_counters = 30
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	munkidori.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	state.players[0].active_pokemon = grimmsnarl
	state.players[0].bench = [munkidori]
	state.players[1].active_pokemon = _real_target("Public 210 HP breakpoint", 210, 1)
	var bench_target := _real_target("Public future Bench target", 120, 1)
	state.players[1].bench = [bench_target]
	processor.register_pokemon_card(grimmsnarl.get_card_data())
	processor.register_pokemon_card(munkidori.get_card_data())

	var observation := _observation(
		[
			_ability("ability:adrena-before-shadow", "slot:munkidori", MUNKIDORI_UID, true),
			_attack("attack:shadow-before-adrena", GRIMMSNARL_UID, 0, 180, false),
		],
		_slot("slot:active", GRIMMSNARL_UID, [_energy_card(DARKNESS_UID), _energy_card(DARKNESS_UID)], 30),
		[_slot("slot:munkidori", MUNKIDORI_UID, [_energy_card(DARKNESS_UID)])],
		10
	)
	observation["opponent"]["active"] = _public_target("PUBLIC_210_HP_SINGLE", 210, 1)
	observation["opponent"]["bench"] = [_public_target("PUBLIC_120_HP_SINGLE", 120, 1)]
	var facts := _facts(true, false, false, 2, false, false, 180)
	var frontier := _frontier(observation, {
		"ability:adrena-before-shadow": 610.0,
		"attack:shadow-before-adrena": 600.0,
	}, facts, "ability:adrena-before-shadow")
	var ability_candidate := _candidate(frontier, "ability:adrena-before-shadow")
	var safety := _route_safety(ability_candidate, frontier, facts)

	var moved := processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [grimmsnarl],
		"target_damage_counters": [{"target": state.players[1].active_pokemon, "amount": 30}],
	}], state)
	var legal := RuleValidator.new().can_use_attack(state, 0, 0, processor)
	var attack_effects := processor.get_attack_effects_for_slot(grimmsnarl, 0)
	var bench_step: Dictionary = {}
	for effect: BaseEffect in attack_effects:
		var steps: Array = effect.get_attack_interaction_steps(
			grimmsnarl.get_top_card(), grimmsnarl.get_card_data().attacks[0], state)
		if bench_step.is_empty():
			bench_step = _step(steps, "opponent_bench_damage_targets")
	var bench_bound := (bench_step.get("items", []) as Array) == [bench_target]
	var attacked := processor.execute_attack_effect(grimmsnarl, 0, state.players[1].active_pokemon, state, [{
		"opponent_bench_damage_targets": [bench_target],
	}])
	var combined_damage := _base_attack_damage(grimmsnarl.get_card_data(), 0) \
		+ state.players[1].active_pokemon.damage_counters
	var direct_attack_only := _base_attack_damage(grimmsnarl.get_card_data(), 0)

	var passed := not ability_candidate.is_empty() and bool(safety.get("valid", false)) \
		and moved and legal and bench_bound and attacked and combined_damage == 210 \
		and direct_attack_only == 180 and direct_attack_only < 210 \
		and grimmsnarl.damage_counters == 0 and bench_target.damage_counters == 30
	_check(passed, "scenario D must move three counters before the terminal attack to cross the public 210 HP breakpoint")
	_rows.append(_row(
		"adrena_brain_before_shadow_bullet_breakpoint",
		"特性顺序/攻击链断点",
		"对手前台剩210HP时，长毛巨魔的180不够；必须先让愿增猿搬3个指示物到前台，再用暗影子弹完成210并同时给备战30伤。",
		"Adrena-Brain 30 to Active -> Shadow Bullet 180 (+30 Bench)",
		["attacking first ends the action window at only 180 of 210 damage", "moving fewer than 3 counters misses the breakpoint"],
		passed
	))


func _scenario_e_shadow_bullet_three_prize_closeout() -> void:
	var processor := EffectProcessor.new()
	var state := _shadow_closeout_state()
	var grimmsnarl := state.players[0].active_pokemon
	var exact_bench := state.players[1].bench[0]
	var tank_bench := state.players[1].bench[1]
	processor.register_pokemon_card(grimmsnarl.get_card_data())
	var legal := RuleValidator.new().can_use_attack(state, 0, 0, processor)
	var bench_step: Dictionary = {}
	for effect: BaseEffect in processor.get_attack_effects_for_slot(grimmsnarl, 0):
		var steps: Array = effect.get_attack_interaction_steps(
			grimmsnarl.get_top_card(), grimmsnarl.get_card_data().attacks[0], state)
		if bench_step.is_empty():
			bench_step = _step(steps, "opponent_bench_damage_targets")
	var exact_contract := int(bench_step.get("min_select", 0)) == 1 \
		and int(bench_step.get("max_select", 0)) == 1 \
		and (bench_step.get("items", []) as Array) == [exact_bench, tank_bench]
	var executed := processor.execute_attack_effect(grimmsnarl, 0, state.players[1].active_pokemon, state, [{
		"opponent_bench_damage_targets": [exact_bench],
	}])
	var active_damage := _base_attack_damage(grimmsnarl.get_card_data(), 0)
	var exact_prizes := (2 if active_damage >= state.players[1].active_pokemon.get_remaining_hp() else 0) \
		+ (1 if exact_bench.damage_counters >= exact_bench.get_remaining_hp() else 0)

	var negative_processor := EffectProcessor.new()
	var negative_state := _shadow_closeout_state()
	var negative_grimmsnarl := negative_state.players[0].active_pokemon
	var negative_exact := negative_state.players[1].bench[0]
	var negative_tank := negative_state.players[1].bench[1]
	negative_processor.register_pokemon_card(negative_grimmsnarl.get_card_data())
	var negative_executed := negative_processor.execute_attack_effect(
		negative_grimmsnarl, 0, negative_state.players[1].active_pokemon, negative_state, [{
			"opponent_bench_damage_targets": [negative_tank],
		}]
	)
	var tank_prizes := 2 \
		+ (1 if negative_exact.damage_counters >= negative_exact.get_remaining_hp() else 0) \
		+ (1 if negative_tank.damage_counters >= negative_tank.get_remaining_hp() else 0)

	var attack := _attack("attack:shadow-three-prize-closeout", GRIMMSNARL_UID, 0, 180, true)
	attack["requires_interaction"] = true
	var observation := _observation(
		[
			_play_trainer("supporter:iono-too-late", IONO_UID, false),
			attack,
		],
		_slot("slot:active", GRIMMSNARL_UID, [_energy_card(DARKNESS_UID), _energy_card(DARKNESS_UID)]),
		[],
		8
	)
	observation["own"]["prizes_remaining"] = 3
	observation["opponent"]["active"] = _public_target("PUBLIC_180_HP_EX", 180, 2)
	observation["opponent"]["bench"] = [
		_public_target("PUBLIC_30_HP_SINGLE", 30, 1),
		_public_target("PUBLIC_130_HP_SINGLE", 130, 1),
	]
	var facts := _facts(true, true, false, 2, false, false, 180)
	facts["resources"]["prizes_remaining"] = 3
	facts["prize"] = {"current_swing": 3, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:shadow-three-prize-closeout": 10.0,
	}, facts, "supporter:iono-too-late")
	var attack_candidate := _candidate(frontier, "attack:shadow-three-prize-closeout")
	var safety := _route_safety(attack_candidate, frontier, facts)

	var passed := legal and exact_contract and executed \
		and exact_bench.damage_counters == 30 and tank_bench.damage_counters == 0 \
		and exact_prizes == 3 and negative_executed and tank_prizes == 2 \
		and bool(safety.get("valid", false))
	_check(passed, "scenario E must bind Shadow Bullet's real Bench target for a public 2+1 three-Prize terminal")
	_rows.append(_row(
		"shadow_bullet_three_prize_closeout",
		"关键奖赏终结",
		"己方剩3奖时，暗影子弹180击倒对手180HP双奖前台，并把固定30伤害绑定到恰好30HP的单奖备战，形成2+1终局。",
		"Shadow Bullet 180 to Active ex + 30 to exact-HP Bench for three Prizes",
		["targeting the public 130 HP Bench yields only two Prizes", "either target above its exact public breakpoint breaks the terminal"],
		passed
	))


func _scenario_f_preserve_visible_grimmsnarl_setup_before_research() -> void:
	var research := _play_trainer("turn2:research", RESEARCH_UID, true)
	var end_turn := _end_turn("turn2:hold-stage2")
	var observation := _turn2_visible_stage2_setup_observation([research, end_turn])
	var facts := _facts(false, false, false, 4, false, false, 0)
	facts["turn"]["supporter_available"] = true
	facts["resources"]["bench_slots_free"] = 4
	facts["resources"]["energy_on_board"] = 1
	var frontier := _frontier(observation, {
		"turn2:research": 390.6,
		"turn2:hold-stage2": -2044.0,
	}, facts, "turn2:research")
	var hold := _candidate(frontier, "turn2:hold-stage2")
	var proof := _module_field(
		hold, "damage_counter_control", "preserve_visible_stage2_setup"
	)
	var safety := _route_safety(hold, frontier, facts)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	var upgrade: Dictionary = strategy.call("_find_module_verified_upgrade", frontier, facts)
	var certificate := "public_visible_stage2_setup_preserved_before_destructive_hand_reset"
	var positive := bool(proof.get("verified", false)) \
		and bool(proof.get("advances_visible_stage2_setup_hold", false)) \
		and str(proof.get("stage", "")) == "hold_candy_stage2_pair" \
		and int(proof.get("opponent_attack_energy_deficit", 0)) == 3 \
		and bool(safety.get("valid", false)) \
		and str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
			== certificate \
		and str(upgrade.get("safe_prefix_action_id", "")) == "turn2:hold-stage2"
	_check(positive,
		"scenario F must hold the exact Rare Candy + Grimmsnarl pair instead of discarding it to Research")

	observation["observation_version"] = 11
	observation["observation_hash"] = "seed-502-visible-stage2-pair"
	var next_turn := _turn2_visible_stage2_setup_observation([
		_evolve("turn4:rare-candy-grimmsnarl", GRIMMSNARL_UID, "slot:impidimp"),
	])
	next_turn["observation_version"] = 12
	next_turn["observation_hash"] = "seed-502-next-turn-stage2-ready"
	next_turn["turn"]["number"] = 4
	var next_facts := _facts(false, false, true, 4, false, false, 0)
	next_facts["resources"]["bench_slots_free"] = 4
	next_facts["resources"]["energy_on_board"] = 1
	var next_frontier := _frontier(next_turn, {
		"turn4:rare-candy-grimmsnarl": 5600.0,
	}, next_facts, "turn4:rare-candy-grimmsnarl")
	var next_evolve := _candidate(next_frontier, "turn4:rare-candy-grimmsnarl")
	var material_delta := MaterialDeltaScript.new().compare(
		observation, next_turn, facts, next_facts
	)
	var continuation_visible := bool(material_delta.get("legal_actions_changed", false)) \
		and str(next_evolve.get("route_id", "")) == "route:evolve" \
		and bool(next_evolve.get("engine_rule_floor_exact", false))
	_check(continuation_visible,
		"scenario F must expose the public Rare Candy evolution on the next observed turn")

	var negative_ids := [
		"missing_candy", "missing_stage2", "wrong_root", "wrong_root_energy",
		"opponent_can_attack", "opponent_bench_present", "wrong_discard_history",
		"attack_ready", "wrong_rule_floor", "extra_hand_card", "wrong_prizes",
	]
	var negatives_failed_closed := true
	for negative: String in negative_ids:
		var negative_observation := _turn2_visible_stage2_setup_observation([
			research,
			end_turn,
		])
		var negative_facts := _facts(false, false, false, 4, false, false, 0)
		negative_facts["turn"]["supporter_available"] = true
		negative_facts["resources"]["bench_slots_free"] = 4
		negative_facts["resources"]["energy_on_board"] = 1
		var negative_rule_id := "turn2:research"
		var negative_scores := {"turn2:research": 390.6, "turn2:hold-stage2": -2044.0}
		match negative:
			"missing_candy": negative_observation["own"]["hand"].remove_at(0)
			"missing_stage2": negative_observation["own"]["hand"].remove_at(3)
			"wrong_root":
				negative_observation["own"]["bench"][0] = _slot(
					"slot:impidimp", SNORUNT_UID, [_energy_card(DARKNESS_UID)]
				)
			"wrong_root_energy":
				negative_observation["own"]["bench"][0]["energy"] = []
				negative_observation["own"]["bench"][0]["energy_count"] = 0
			"opponent_can_attack":
				for _index: int in 3:
					negative_observation["opponent"]["active"]["energy"].append(
						_lightning_energy()
					)
				negative_observation["opponent"]["active"]["energy_count"] = 4
			"opponent_bench_present": negative_observation["opponent"]["bench"] = [
				_public_target("CSV1C_050", 220, 2),
			]
			"wrong_discard_history": negative_observation["own"]["discard_counts"].erase(ULTRA_BALL_UID)
			"attack_ready": negative_facts["attack"]["ready"] = true
			"wrong_rule_floor":
				negative_rule_id = "turn2:hold-stage2"
				negative_scores["turn2:hold-stage2"] = 500.0
			"extra_hand_card": negative_observation["own"]["hand"].append(_card(IONO_UID))
			"wrong_prizes": negative_observation["own"]["prizes_remaining"] = 5
		negative_observation["own"]["hand_count"] = negative_observation["own"]["hand"].size()
		var negative_frontier := _frontier(
			negative_observation, negative_scores, negative_facts, negative_rule_id
		)
		var negative_hold := _candidate(negative_frontier, "turn2:hold-stage2")
		var failed_closed := _module_field(
			negative_hold, "damage_counter_control", "preserve_visible_stage2_setup"
		).is_empty()
		_check(failed_closed, "scenario F negative %s must fail closed" % negative)
		negatives_failed_closed = negatives_failed_closed and failed_closed

	var tampered_frontier: Array[Dictionary] = frontier.duplicate(true)
	var tampered_hold := _candidate(tampered_frontier, "turn2:hold-stage2")
	var tampered_proof := _module_field(
		tampered_hold, "damage_counter_control", "preserve_visible_stage2_setup"
	)
	tampered_proof["opponent_attack_energy_deficit"] = 2
	var tamper_failed := not bool(
		_route_safety(tampered_hold, tampered_frontier, facts).get("valid", false)
	)
	_check(tamper_failed,
		"scenario F stage2-preservation certificate must reject a tampered attack deficit")

	_rows.append(_row(
		"preserve_visible_grimmsnarl_setup_before_research",
		"visible Stage 2 setup preservation",
		"After Ultra Ball publicly produced Grimmsnarl ex, preserve the exact Rare Candy + Grimmsnarl pair behind an energized Impidimp while the opposing Iron Hands remains three Energy short, instead of discarding the guaranteed next-turn evolution to Professor's Research.",
		"end turn -> reobserve -> Rare Candy into Marnie's Grimmsnarl ex",
		negative_ids + ["certificate binding tamper"],
		positive and continuation_visible and negatives_failed_closed and tamper_failed
	))


func _turn2_visible_stage2_setup_observation(actions: Array) -> Dictionary:
	var observation := _observation(
		actions,
		_slot("slot:munkidori", MUNKIDORI_UID, []),
		[_slot("slot:impidimp", IMPIDIMP_UID, [_energy_card(DARKNESS_UID)])],
		43
	)
	observation["turn"] = {
		"number": 2,
		"current_player": 1,
		"viewer": 1,
		"phase": 4,
		"deterministic_attack_window_open": true,
		"quotas": {
			"energy_available": false,
			"supporter_available": true,
			"retreat_available": true,
			"stadium_available": false,
		},
	}
	observation["own"]["hand"] = [
		_card(RARE_CANDY_UID),
		_card(RESEARCH_UID),
		_energy_card(DARKNESS_UID),
		_card(GRIMMSNARL_UID),
	]
	observation["own"]["hand_count"] = 4
	observation["own"]["discard_counts"] = {
		ULTRA_BALL_UID: 1,
		RESEARCH_UID: 1,
		COUNTER_CATCHER_UID: 1,
	}
	observation["own"]["prizes_remaining"] = 6
	var iron_hands := _public_target(IRON_HANDS_UID, 230, 2)
	iron_hands["energy"] = [_lightning_energy()]
	iron_hands["energy_count"] = 1
	observation["opponent"] = {
		"active": iron_hands,
		"bench": [],
		"hand_count": 6,
		"deck_count": 46,
		"prizes_remaining": 6,
	}
	observation["stadium"] = _card(SPIKEMUTH_UID)
	return observation


func _module_field(candidate: Dictionary, module_id: String, field: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_annotation: Dictionary = annotations.get(module_id, {}) \
		if annotations.get(module_id, {}) is Dictionary else {}
	return module_annotation.get(field, {}) \
		if module_annotation.get(field, {}) is Dictionary else {}


func _frontier(
	observation: Dictionary,
	scores: Dictionary,
	facts: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(
		observation, scores, _manifest, facts)
	for candidate: Dictionary in pool:
		candidate["engine_rule_floor_exact"] = \
			str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest)
	_check(not annotated.is_empty() \
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id, \
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), \
		"public scenario frontier must exclude hidden sentinels")
	return annotated


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))


func _epoch_reopens(
	before: Dictionary,
	after: Dictionary,
	facts_before: Dictionary,
	facts_after: Dictionary,
	candidate: Dictionary,
	frontier: Array[Dictionary],
	success: bool = true
) -> bool:
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return bool(strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": success,
			"route_id": str(candidate.get("route_id", "")),
			"candidate_id": str(candidate.get("candidate_id", "")),
		}, delta, frontier))


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	_check(false, "candidate for %s must exist" % action_id)
	return {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "marnies-grimmsnarl-complex-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _public_target("PUBLIC_OPPONENT_ACTIVE", 230, 2),
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"stadium": {},
		"legal_actions": actions,
	}


func _facts(
	attack_ready: bool,
	ko_available: bool,
	energy_available: bool,
	hand_size: int,
	deck_low: bool,
	deck_critical: bool,
	max_damage: int
) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": ko_available, "max_damage": max_damage},
		"turn": {"energy_available": energy_available, "supporter_available": true},
		"resources": {
			"deck_low": deck_low,
			"deck_critical": deck_critical,
			"hand_size": hand_size,
			"bench_slots_free": 3,
			"prizes_remaining": 6,
			"energy_on_board": 0,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _slot(slot_id: String, uid: String, energy: Array, damage: int = 0) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"damage_counters": damage,
		"remaining_hp": (320 - damage) if uid == GRIMMSNARL_UID else (110 - damage if uid == MUNKIDORI_UID else 70 - damage),
		"max_hp": 320 if uid == GRIMMSNARL_UID else (110 if uid == MUNKIDORI_UID else 70),
		"prize_count": 2 if uid == GRIMMSNARL_UID else 1,
	}


func _public_target(uid: String, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": "slot:%s" % uid.to_lower(),
		"pokemon": {"uid": uid},
		"remaining_hp": remaining_hp,
		"prize_count": prize_count,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _use_stadium(action_id: String, uid: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "use_stadium_effect",
		"card": _card(uid),
		"requires_interaction": true,
	}


func _evolve(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "evolve",
		"card": _card(uid),
		"target": target,
	}


func _ability(action_id: String, source: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "use_ability",
		"source": source,
		"source_card": _card(uid),
		"ability_index": 0,
		"requires_interaction": interaction,
	}


func _attack(action_id: String, uid: String, attack_index: int, damage: int, knockout: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": "slot:active",
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": false,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _energy_card(uid: String) -> Dictionary:
	var card := _card(uid)
	card["energy_type"] = "D"
	card["energy_provides"] = "D"
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if "basic_energy" not in roles:
		roles.append("basic_energy")
	card["semantic_roles"] = roles
	return card


func _lightning_energy() -> Dictionary:
	return {
		"uid": "CSVE1C_LIG",
		"name": "Lightning Energy",
		"type": "Basic Energy",
		"energy_type": "L",
		"energy_provides": "L",
	}


func _card(uid: String) -> Dictionary:
	for raw_card: Variant in _manifest.get("cards", []):
		if not (raw_card is Dictionary) or str((raw_card as Dictionary).get("uid", "")) != uid:
			continue
		var source: Dictionary = raw_card
		return {
			"uid": uid,
			"effect_id": str(source.get("effect_id", "")),
			"name": str(source.get("name", "")),
			"type": str(source.get("type", "")),
			"semantic_roles": (source.get("roles", []) as Array).duplicate() \
				if source.get("roles", []) is Array else [],
		}
	_check(false, "manifest card %s must exist" % uid)
	return {"uid": uid}


func _game_state(turn: int = 8, first_player: int = 0) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = first_player
	state.turn_number = turn
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _real_card_data(uid: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % uid
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "real card %s must load" % uid)
	return CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()


func _real_instance(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data(uid), owner)


func _real_slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _real_target(name: String, hp: int, prize_count: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prize_count == 2 else ""
	return _real_slot(data, 1)


func _target_with_ability(name: String, hp: int, prize_count: int) -> PokemonSlot:
	var slot := _real_target(name, hp, prize_count)
	slot.get_card_data().abilities = [{"name": "Public Fixture Ability", "text": ""}]
	return slot


func _filler_instance(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _slot_uids(slots: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_slot: Variant in slots:
		if raw_slot is PokemonSlot and (raw_slot as PokemonSlot).get_card_data() != null:
			result.append((raw_slot as PokemonSlot).get_card_data().get_uid())
	return result


func _step(steps: Array, id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == id:
			return raw_step as Dictionary
	return {}


func _shadow_closeout_state() -> GameState:
	var state := _game_state()
	var grimmsnarl := _real_slot(_real_card_data(GRIMMSNARL_UID), 0)
	grimmsnarl.attached_energy = [_real_instance(DARKNESS_UID, 0), _real_instance(DARKNESS_UID, 0)]
	state.players[0].active_pokemon = grimmsnarl
	state.players[1].active_pokemon = _real_target("Public 180 HP ex", 180, 2)
	state.players[1].bench = [
		_real_target("Public 30 HP single", 30, 1),
		_real_target("Public 130 HP single", 130, 1),
	]
	return state


func _base_attack_damage(card: CardData, attack_index: int) -> int:
	if card == null or attack_index < 0 or attack_index >= card.attacks.size():
		return 0
	var text := str(card.attacks[attack_index].get("damage", ""))
	var digits := ""
	for character: String in text:
		if character >= "0" and character <= "9":
			digits += character
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


func _row(
	id: String,
	category: String,
	description: String,
	expected_choice: String,
	negative_boundaries: Array,
	passed: bool
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"description": description,
		"expected_choice": expected_choice,
		"proof_reason": "focused_public_state_fixture_with_fail_closed_boundaries",
		"negative_boundaries": negative_boundaries.duplicate(),
		"passed": passed,
	}


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 玛俐的长毛巨魔",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"baseline": {
			"status": "pending_real_model_round00",
			"artifact": "res://tmp/v18cpg/optimization21/800018501/round00.json",
			"artifact_exists": FileAccess.file_exists("res://tmp/v18cpg/optimization21/800018501/round00.json"),
			"seed_base": DECK_ID,
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 6,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"The Punk Up 2+2 allocation and reserved manual Darkness attachment are proved through real effects/public targets, but still need a production interaction certificate before a formal round.",
			"The Froslass-to-Munkidori sequence and 210 HP breakpoint are real engine paths; the current generic damage-counter module does not yet emit a deck-specific bounded sequence certificate for them.",
			"The Shadow Bullet 2+1 closeout is proved from the real selected-Bench effect, but production must still derive the combined prize fact before model takeover.",
			"A real-model round00 and paired-seed comparison against the exact Rule floor remain pending.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"real_model_formal_run": false,
			"hidden_sentinel_absent_from_frontiers": true,
		},
		"coverage": [
			"second-player Arven into Buddy-Buddy Poffin and two-root TM Evolution",
			"Spikemuth Gym search before Iono, Rare Candy, Punk Up split, and reserved manual Darkness attachment",
			"Froslass Pokemon Check damage feeding an exact three-counter Munkidori transfer",
			"Munkidori before Shadow Bullet for a public 210 HP attack-chain breakpoint",
			"Shadow Bullet 180 plus exact 30 Bench damage for a three-Prize terminal",
		],
		"scenarios": _rows.duplicate(true),
		"failures": _failures.duplicate(),
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_check(file != null, "complex scenario report must be writable")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()


func _load_json(path: String) -> Dictionary:
	_check(FileAccess.file_exists(path), "%s must exist" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s must contain valid JSON" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
