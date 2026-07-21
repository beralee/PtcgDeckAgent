extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const CyclePivotScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCyclePivot.gd")

const DECK_ID := 800018880
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018880.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018880/complex_decision_scenarios.json"

const CYNDAQUIL_UID := "CSV10C_028"
const QUILAVA_UID := "CSV10C_029"
const TYPHLOSION_UID := "CSV10C_030"
const PIDGEY_UID := "151C_016"
const PIDGEOTTO_UID := "151C_017"
const PIDGEOT_UID := "CSV4C_101"
const VICTINI_UID := "CSV9C_023"
const FEZANDIPITI_UID := "CSV8C_135"
const ADVENTURE_UID := "CSV10C_208"
const POFFIN_UID := "CSV7C_177"
const TM_EVOLUTION_UID := "CSV5C_119"
const FIRE_UID := "CSVE1C_FIR"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Ethan's Typhlosion profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Ethan's Typhlosion semantic manifest must load")
	_check(_profile.get("modules", []) == ["partner_chain", "stage2_chain", "cycle_pivot"], \
		"scenarios must use the production partner/stage2/cycle module composition")

	_scenario_a_poffin_tm_two_evolution_roots()
	_scenario_b_quilava_journey_bond_reopens_epoch()
	_scenario_c_pidgeot_adventure_exact_typhlosion_ko()
	_scenario_d_partner_blast_public_discard_breakpoint()
	_scenario_e_low_deck_last_prize_stops_information_churn()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018880 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018880 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_poffin_tm_two_evolution_roots() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var victini := _real_slot(_real_card_data(VICTINI_UID), 0)
	var fire := _real_instance(FIRE_UID, 0)
	var tm := _real_instance(TM_EVOLUTION_UID, 0)
	var poffin := _real_instance(POFFIN_UID, 0)
	var cyndaquil := _real_instance(CYNDAQUIL_UID, 0)
	var pidgey := _real_instance(PIDGEY_UID, 0)
	var quilava := _real_instance(QUILAVA_UID, 0)
	var pidgeotto := _real_instance(PIDGEOTTO_UID, 0)
	victini.attached_energy = [fire]
	state.players[0].active_pokemon = victini
	state.players[0].hand = [poffin, tm]
	state.players[0].deck = [cyndaquil, pidgey, quilava, pidgeotto, _filler_instance("VISIBLE_DECK_FILLER", 0)]
	state.players[1].active_pokemon = _real_target("Public TM target", 200, 1)

	var poffin_effect := processor.get_effect(poffin.card_data.effect_id)
	var poffin_steps: Array = poffin_effect.get_interaction_steps(poffin, state) if poffin_effect != null else []
	var poffin_step: Dictionary = poffin_steps[0] if not poffin_steps.is_empty() else {}
	var poffin_public := str(poffin_step.get("visible_scope", "")) == "own_full_deck" \
		and cyndaquil in (poffin_step.get("items", []) as Array) \
		and pidgey in (poffin_step.get("items", []) as Array)
	var poffin_executed := processor.execute_card_effect(poffin, [{
		"buddy_poffin_pokemon": [cyndaquil, pidgey],
	}], state)
	var roots: Array = state.players[0].bench.duplicate()
	var root_uids := _slot_uids(roots)

	victini.attached_tool = tm
	var tm_effect := processor.get_effect(tm.card_data.effect_id)
	var granted: Array = processor.get_granted_attacks(victini, state)
	var granted_ready := not granted.is_empty() \
		and RuleValidator.new().can_use_granted_attack(state, 0, victini, granted[0], processor)
	var tm_first_steps: Array = tm_effect.get_granted_attack_interaction_steps( \
		victini, granted[0], state) if tm_effect != null and not granted.is_empty() else []
	var tm_followup: Array = tm_effect.get_followup_granted_attack_interaction_steps( \
		victini, granted[0], state, {"evolution_bench": roots}) \
		if tm_effect != null and not granted.is_empty() else []
	var evolution_step: Dictionary = tm_followup[0] if not tm_followup.is_empty() else {}
	var tm_public := not tm_first_steps.is_empty() \
		and str(evolution_step.get("visible_scope", "")) == "own_full_deck" \
		and quilava in (evolution_step.get("items", []) as Array) \
		and pidgeotto in (evolution_step.get("items", []) as Array)
	if tm_effect != null and not granted.is_empty():
		tm_effect.execute_granted_attack(victini, granted[0], state, [{
			"evolution_bench": roots,
			"evolution_cards": [quilava, pidgeotto],
		}])
	var evolved_uids := _slot_uids(state.players[0].bench)

	var no_energy_state := _game_state()
	var no_energy_carrier := _real_slot(_real_card_data(VICTINI_UID), 0)
	no_energy_carrier.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	no_energy_state.players[0].active_pokemon = no_energy_carrier
	no_energy_state.players[1].active_pokemon = _real_target("Public TM target", 200, 1)
	no_energy_state.players[0].bench = [
		_real_slot(_real_card_data(CYNDAQUIL_UID), 0),
		_real_slot(_real_card_data(PIDGEY_UID), 0),
	]
	no_energy_state.players[0].deck = [
		_real_instance(QUILAVA_UID, 0),
		_real_instance(PIDGEOTTO_UID, 0),
	]
	var no_energy_granted: Array = processor.get_granted_attacks(no_energy_carrier, no_energy_state)
	var no_energy_blocked := not no_energy_granted.is_empty() \
		and not RuleValidator.new().can_use_granted_attack( \
			no_energy_state, 0, no_energy_carrier, no_energy_granted[0], processor)

	var missing_lane_state := _game_state()
	var missing_lane_carrier := _real_slot(_real_card_data(VICTINI_UID), 0)
	missing_lane_carrier.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	missing_lane_carrier.attached_energy = [_real_instance(FIRE_UID, 0)]
	missing_lane_state.players[0].active_pokemon = missing_lane_carrier
	missing_lane_state.players[0].bench = [
		_real_slot(_real_card_data(CYNDAQUIL_UID), 0),
		_real_slot(_real_card_data(PIDGEY_UID), 0),
	]
	missing_lane_state.players[0].deck = [_real_instance(QUILAVA_UID, 0)]
	var missing_lane_granted: Array = processor.get_granted_attacks(missing_lane_carrier, missing_lane_state)
	var missing_followup: Array = tm_effect.get_followup_granted_attack_interaction_steps( \
		missing_lane_carrier, missing_lane_granted[0], missing_lane_state, {
			"evolution_bench": missing_lane_state.players[0].bench,
		}) if tm_effect != null and not missing_lane_granted.is_empty() else []
	var missing_items: Array = (missing_followup[0] as Dictionary).get("items", []) \
		if not missing_followup.is_empty() else []
	var missing_second_lane_blocked := missing_items.size() == 1 \
		and (missing_items[0] as CardInstance).card_data.get_uid() == QUILAVA_UID

	var passed := poffin_public and poffin_executed \
		and root_uids == [CYNDAQUIL_UID, PIDGEY_UID] \
		and granted_ready and tm_public \
		and evolved_uids == [QUILAVA_UID, PIDGEOTTO_UID] \
		and no_energy_blocked and missing_second_lane_blocked
	_check(passed, "scenario A must prove real Poffin -> two roots -> real TM double evolution and fail closed boundaries: %s" % JSON.stringify({
		"poffin_public": poffin_public,
		"poffin_executed": poffin_executed,
		"root_uids": root_uids,
		"granted_ready": granted_ready,
		"tm_public": tm_public,
		"evolved_uids": evolved_uids,
		"no_energy_blocked": no_energy_blocked,
		"missing_second_lane_blocked": missing_second_lane_blocked,
	}))
	_rows.append(_row(
		"poffin_tm_two_evolution_roots",
		"宝芬/TM双进化根",
		"前台比克提尼已有1火能，友好宝芬从公开完整牌库同时铺阿响的火球鼠与波波；进化TM随后把两个不同根分别进化为火岩鼠与比比鸟。",
		"Buddy-Buddy Poffin(Cyndaquil+Pidgey) -> TM Evolution(Quilava+Pidgeotto)",
		["TM carrier without one payable energy", "Pidgeotto absent from the visible full-deck search"],
		passed
	))


func _scenario_b_quilava_journey_bond_reopens_epoch() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var quilava := _real_slot(_real_card_data(QUILAVA_UID), 0)
	var adventure := _real_instance(ADVENTURE_UID, 0)
	state.players[0].active_pokemon = quilava
	state.players[0].deck = [adventure, _filler_instance("VISIBLE_NON_ADVENTURE", 0)]
	processor.register_pokemon_card(quilava.get_card_data())
	var ability_effect := processor.get_ability_effect(quilava, 0, state)
	var ability_steps: Array = ability_effect.get_interaction_steps(quilava.get_top_card(), state) \
		if ability_effect != null else []
	var ability_step: Dictionary = ability_steps[0] if not ability_steps.is_empty() else {}
	var exact_public_search := str(ability_step.get("visible_scope", "")) == "own_full_deck" \
		and (ability_step.get("items", []) as Array) == [adventure]

	var before := _observation(
		[_ability("ability:journey-bond", "slot:active", QUILAVA_UID, true), _end_turn("end:stale")],
		_slot("slot:active", QUILAVA_UID, []),
		[],
		2
	)
	before["own"]["hand"] = []
	before["observation_version"] = 1
	before["observation_hash"] = "typhlosion-before-journey-bond"
	var facts_before := _facts(false, false, false, 0, false, false, 40)
	var frontier := _frontier(before, {
		"ability:journey-bond": 520.0,
		"end:stale": -900.0,
	}, facts_before, "ability:journey-bond")
	var search_candidate := _candidate(frontier, "ability:journey-bond")

	var executed := processor.execute_ability_effect(quilava, 0, [{"search_cards": [adventure]}], state)
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "typhlosion-after-journey-bond"
	after["own"]["hand"] = [_card(ADVENTURE_UID)]
	after["own"]["deck_count"] = 1
	after["legal_actions"] = [
		_play_trainer("supporter:ethans-adventure", ADVENTURE_UID, true),
		_end_turn("end:stale"),
	]
	var facts_after := _facts(false, false, false, 1, false, false, 40)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, search_candidate, frontier)
	var unchanged_after := before.duplicate(true)
	unchanged_after["observation_version"] = 2
	unchanged_after["observation_hash"] = "typhlosion-empty-journey-bond"
	var empty_does_not_reopen := not _epoch_reopens( \
		before, unchanged_after, facts_before, facts_before, search_candidate, frontier, false)
	var exact_route := str(search_candidate.get("route_id", "")) == "route:information" \
		and str(search_candidate.get("checkpoint_after", "")) == "information_result"
	var passed := exact_public_search and executed and adventure in state.players[0].hand \
		and exact_route and reopened and empty_does_not_reopen
	_check(passed, "scenario B real Journey Bond must search exact Adventure and reopen only after material public change: %s" % JSON.stringify({
		"exact_public_search": exact_public_search,
		"executed": executed,
		"adventure_in_hand": adventure in state.players[0].hand,
		"exact_route": exact_route,
		"reopened": reopened,
		"empty_does_not_reopen": empty_does_not_reopen,
		"route_id": str(search_candidate.get("route_id", "")),
		"checkpoint_after": str(search_candidate.get("checkpoint_after", "")),
	}))
	_rows.append(_row(
		"quilava_journey_bond_information_epoch",
		"旅途牵绊/信息epoch",
		"火岩鼠的旅途牵绊只公开检索阿响的冒险；成功加入手牌后旧图失效并重开信息epoch，空结果或无状态变化不得制造额外重规划。",
		"ability:journey-bond -> information_result -> supporter:ethans-adventure",
		["no matching Adventure in the visible deck", "successful flag without hand/deck MaterialDelta"],
		passed
	))


func _scenario_c_pidgeot_adventure_exact_typhlosion_ko() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var quilava := _real_slot(_real_card_data(QUILAVA_UID), 0)
	var pidgeot := _real_slot(_real_card_data(PIDGEOT_UID), 0)
	var adventure := _real_instance(ADVENTURE_UID, 0)
	var prior_adventure := _real_instance(ADVENTURE_UID, 0)
	var typhlosion := _real_instance(TYPHLOSION_UID, 0)
	var fire := _real_instance(FIRE_UID, 0)
	var second_fire := _real_instance(FIRE_UID, 0)
	var filler := _filler_instance("VISIBLE_QUICK_SEARCH_ALTERNATIVE", 0)
	state.players[0].active_pokemon = quilava
	state.players[0].bench = [pidgeot]
	state.players[0].deck = [adventure, typhlosion, fire, second_fire, filler]
	state.players[0].discard_pile = [prior_adventure]
	state.players[1].active_pokemon = _real_target("Public 160 HP single-Prize active", 160, 1)
	processor.register_pokemon_card(pidgeot.get_card_data())
	processor.register_pokemon_card(quilava.get_card_data())
	processor.register_pokemon_card(typhlosion.card_data)

	var quick_search := processor.get_ability_effect(pidgeot, 0, state)
	var quick_steps: Array = quick_search.get_interaction_steps(pidgeot.get_top_card(), state) \
		if quick_search != null else []
	var quick_step: Dictionary = quick_steps[0] if not quick_steps.is_empty() else {}
	var quick_public := str(quick_step.get("visible_scope", "")) == "own_full_deck" \
		and adventure in (quick_step.get("items", []) as Array)
	var quick_executed := processor.execute_ability_effect(pidgeot, 0, [{"search_cards": [adventure]}], state)
	var adventure_executed := processor.execute_card_effect(adventure, [{
		"search_cards": [typhlosion, fire],
	}], state)
	# GameStateMachine normally performs this public Supporter-zone transition.
	state.players[0].hand.erase(adventure)
	state.players[0].discard_pile.append(adventure)
	var exact_evolution := typhlosion.card_data.evolves_from_matches(quilava.get_card_data())
	if exact_evolution and typhlosion in state.players[0].hand:
		state.players[0].hand.erase(typhlosion)
		quilava.pokemon_stack.append(typhlosion)
	if fire in state.players[0].hand:
		state.players[0].hand.erase(fire)
		quilava.attached_energy.append(fire)

	var base_damage := _base_attack_damage(typhlosion.card_data, 0)
	var public_bonus := processor.get_attack_damage_modifier(
		quilava, state.players[1].active_pokemon, typhlosion.card_data.attacks[0], state, [], 0)
	var total_damage := base_damage + public_bonus
	var exact_ko := total_damage == 160 and state.players[1].active_pokemon.get_remaining_hp() == 160

	var observation := _observation(
		[
			_play_trainer("supporter:research-after-chain", "CSV1C_121", true),
			_attack("attack:partner-blast-exact", TYPHLOSION_UID, 0, total_damage, exact_ko),
		],
		_slot("slot:active", TYPHLOSION_UID, [_fire_energy()]),
		[_slot("slot:pidgeot", PIDGEOT_UID, [])],
		state.players[0].deck.size()
	)
	observation["own"]["discard"] = [_card(ADVENTURE_UID), _card(ADVENTURE_UID)]
	observation["own"]["prizes_remaining"] = 1
	observation["opponent"]["active"] = _public_target("PUBLIC_160_HP_SINGLE_PRIZE", 160, 1)
	var facts := _facts(true, true, false, state.players[0].hand.size(), false, false, total_damage)
	facts["resources"]["prizes_remaining"] = 1
	facts["prize"] = {"current_swing": 1, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:research-after-chain": 700.0,
		"attack:partner-blast-exact": 10.0,
	}, facts, "supporter:research-after-chain")
	var attack_candidate := _candidate(frontier, "attack:partner-blast-exact")
	var safety := _route_safety(attack_candidate, frontier, facts)

	state.players[0].discard_pile.erase(prior_adventure)
	var one_adventure_bonus := processor.get_attack_damage_modifier(
		quilava, state.players[1].active_pokemon, typhlosion.card_data.attacks[0], state, [], 0)
	var one_adventure_not_ko := base_damage + one_adventure_bonus == 100
	var passed := quick_public and quick_executed and adventure_executed and exact_evolution \
		and quilava.get_card_data().get_uid() == TYPHLOSION_UID \
		and quilava.attached_energy.size() == 1 \
		and public_bonus == 120 and exact_ko and one_adventure_not_ko \
		and str(safety.get("reason", "")) == "deterministic_win_now"
	_check(passed, "scenario C real Quick Search -> Adventure -> Typhlosion chain must produce the exact 160 KO")
	_rows.append(_row(
		"pidgeot_adventure_typhlosion_exact_ko",
		"比雕搜索/冒险/精确KO",
		"弃牌已有1张阿响的冒险时，大比鸟ex音速搜索第2张；冒险公开检索火暴兽与基本火能，进化并手贴后，冒险进入弃牌使搭档爆破精确达到160并取末奖。",
		"Pidgeot ex Quick Search -> Ethan's Adventure(Typhlosion+Fire) -> Partner Blast 160",
		["only one public Adventure in own discard: 100 damage", "target remaining HP above 160"],
		passed
	))


func _scenario_d_partner_blast_public_discard_breakpoint() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var typhlosion := _real_slot(_real_card_data(TYPHLOSION_UID), 0)
	typhlosion.attached_energy = [_real_instance(FIRE_UID, 0)]
	state.players[0].active_pokemon = typhlosion
	state.players[0].discard_pile = [
		_real_instance(ADVENTURE_UID, 0),
		_real_instance(ADVENTURE_UID, 0),
	]
	# These identities are not in the attack's legal public count and must not add damage.
	state.players[0].deck = [_real_instance(ADVENTURE_UID, 0)]
	state.players[1].discard_pile = [_real_instance(ADVENTURE_UID, 1)]
	state.players[1].hand = [_real_instance(ADVENTURE_UID, 1)]
	state.players[1].active_pokemon = _real_target("Public 160 HP active", 160, 1)
	processor.register_pokemon_card(typhlosion.get_card_data())
	var card := typhlosion.get_card_data()
	var base_damage := _base_attack_damage(card, 0)
	var bonus := processor.get_attack_damage_modifier(
		typhlosion, state.players[1].active_pokemon, card.attacks[0], state, [], 0)
	var validator := RuleValidator.new()
	var partner_legal := validator.can_use_attack(state, 0, 0, processor)
	var blast_burn_legal := validator.can_use_attack(state, 0, 1, processor)
	var exact_public_count := bonus == 120 and base_damage + bonus == 160

	state.players[0].discard_pile.pop_back()
	var one_copy_bonus := processor.get_attack_damage_modifier(
		typhlosion, state.players[1].active_pokemon, card.attacks[0], state, [], 0)
	var one_copy_below_line := base_damage + one_copy_bonus == 100
	state.players[0].discard_pile.clear()
	var zero_copy_bonus := processor.get_attack_damage_modifier(
		typhlosion, state.players[1].active_pokemon, card.attacks[0], state, [], 0)
	var hidden_and_opponent_cards_ignored := zero_copy_bonus == 0
	var passed := str(card.attacks[0].get("cost", "")) == "R" \
		and str(card.attacks[1].get("cost", "")) == "RRC" \
		and partner_legal and not blast_burn_legal \
		and exact_public_count and one_copy_below_line and hidden_and_opponent_cards_ignored
	_check(passed, "scenario D Partner Blast must use only public own-discard Adventures and beat the three-energy Blast Burn line")
	_rows.append(_row(
		"partner_blast_public_discard_breakpoint",
		"公开弃牌计数/最低资源攻击",
		"己方公开弃牌恰有2张阿响的冒险时，搭档爆破为40+120=160且只需1火；同局爆热炮需要RRC而不可用。己方牌库、对手弃牌与对手手牌中的同名卡均不计数。",
		"attack:partner-blast(1 Fire, 2 public Adventures) over Blast Burn(RRC)",
		["one own-discard Adventure: 100 damage", "same-name cards outside own public discard: zero bonus"],
		passed
	))


func _scenario_e_low_deck_last_prize_stops_information_churn() -> void:
	var attack := _attack("attack:last-prize-partner-blast", TYPHLOSION_UID, 0, 160, true)
	var observation := _observation(
		[
			_ability("ability:pidgeot-low-deck", "slot:pidgeot", PIDGEOT_UID, true),
			_ability("ability:fez-low-deck", "slot:fez", FEZANDIPITI_UID, true),
			_play_trainer("supporter:research-low-deck", "CSV1C_121", true),
			attack,
		],
		_slot("slot:active", TYPHLOSION_UID, [_fire_energy()]),
		[
			_slot("slot:pidgeot", PIDGEOT_UID, []),
			_slot("slot:fez", FEZANDIPITI_UID, []),
		],
		4
	)
	observation["own"]["discard"] = [_card(ADVENTURE_UID), _card(ADVENTURE_UID)]
	observation["own"]["prizes_remaining"] = 1
	observation["opponent"]["active"] = _public_target("PUBLIC_LAST_PRIZE_TARGET", 160, 1)
	var facts := _facts(true, true, false, 5, true, true, 160)
	facts["resources"]["prizes_remaining"] = 1
	facts["prize"] = {"current_swing": 1, "win_now": true}
	var frontier := _frontier(observation, {
		"ability:pidgeot-low-deck": 800.0,
		"ability:fez-low-deck": 780.0,
		"supporter:research-low-deck": 760.0,
		"attack:last-prize-partner-blast": 10.0,
	}, facts, "ability:pidgeot-low-deck")
	var attack_candidate := _candidate(frontier, "attack:last-prize-partner-blast")
	var pidgeot_candidate := _candidate(frontier, "ability:pidgeot-low-deck")
	var fez_candidate := _candidate(frontier, "ability:fez-low-deck")
	var research_candidate := _candidate(frontier, "supporter:research-low-deck")
	var safety := _route_safety(attack_candidate, frontier, facts)
	var cycle := CyclePivotScript.new()
	var pidgeot_block := cycle.validate_route_switch(pidgeot_candidate, attack_candidate, facts, _profile)
	var fez_block := cycle.validate_route_switch(fez_candidate, attack_candidate, facts, _profile)
	var research_block := cycle.validate_route_switch(research_candidate, attack_candidate, facts, _profile)
	var all_churn_blocked := str(pidgeot_block.get("reason", "")) == "flareon_ko_before_cycle" \
		and str(fez_block.get("reason", "")) == "flareon_ko_before_cycle" \
		and str(research_block.get("reason", "")) == "flareon_ko_before_cycle"
	var terminal := _public_terminal_prize(1, 1, 160, 160)
	var nonterminal_boundary := not _public_terminal_prize(2, 1, 160, 160)
	var passed := terminal and nonterminal_boundary and all_churn_blocked \
		and str(safety.get("reason", "")) == "deterministic_win_now"
	_check(passed, "scenario E low-deck last-prize KO must stop all optional information churn")
	_rows.append(_row(
		"low_deck_last_prize_stops_information_churn",
		"低牌库/末奖终止",
		"牌库4张、己方剩1奖，对手160HP单奖前台，火暴兽以2张公开冒险达到160时，必须立即攻击；音速搜索、吉雉鸡与博士研究均不得延迟确定性末奖。",
		"attack:last-prize-partner-blast",
		["own prizes remaining is 2: not a terminal certificate", "one Adventure or target above 160: no deterministic KO"],
		passed
	))


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest
	)
	for candidate: Dictionary in annotated:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
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
		"observation_hash": "ethans-typhlosion-complex-scenario",
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


func _slot(slot_id: String, uid: String, energy: Array) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": 170 if uid == TYPHLOSION_UID else 200,
		"max_hp": 170 if uid == TYPHLOSION_UID else 280,
		"prize_count": 2 if uid in [PIDGEOT_UID, FEZANDIPITI_UID] else 1,
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


func _fire_energy() -> Dictionary:
	return {
		"uid": FIRE_UID,
		"name": "Fire Energy",
		"type": "Basic Energy",
		"energy_type": "R",
		"energy_provides": "R",
		"semantic_roles": ["energy_source", "typed_energy", "basic_energy"],
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


func _game_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 8
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


func _public_terminal_prize(own_prizes: int, target_prizes: int, damage: int, target_hp: int) -> bool:
	return own_prizes > 0 and target_prizes >= own_prizes and target_hp > 0 and damage >= target_hp


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
		"deck_name": "18.0 阿响火暴兽",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"baseline": {
			"artifact": "res://tmp/v18cpg/optimization21/800018880/round00.json",
			"seed_base": 800018880,
			"rule_wins": 3,
			"v18cpg_wins": 3,
			"clean_games": 5,
			"model_calls": 33,
			"model_accepted": 3,
			"visible_wait_p95_ms": 6254,
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local capability certificate is claimed by this fixture.",
			"The Quick Search -> Adventure -> exact Partner Blast suffix still needs trace-derived production binding before a formal round.",
			"The Poffin/TM double-root fixture proves the real effects and public boundary, not a production interaction takeover.",
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
			"Buddy-Buddy Poffin plus real TM Evolution across Cyndaquil and Pidgey roots",
			"Quilava Journey Bond exact named search and information-epoch reopen",
			"Pidgeot ex Quick Search into Ethan's Adventure and exact Typhlosion KO",
			"Partner Blast public own-discard Adventure count versus Blast Burn energy line",
			"low-deck last-Prize terminal discipline against optional information churn",
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
