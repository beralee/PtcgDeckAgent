extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800017631
const DECK_SEED_PATH := "res://data/bundled_user/decks/800017631.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800017631.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/800017631/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800017631/complex_decision_scenarios.json"

const SNORUNT_UID := "CSV9.5C_043"
const FROSLASS_UID := "CSV7C_059"
const MUNKIDORI_UID := "CSV8C_094"
const MARACTUS_UID := "CSV10C_008"
const BLOODMOON_UID := "CSV8C_172"
const RESEARCH_UID := "CSV1C_121"
const NIGHT_STRETCHER_UID := "CSV8C_183"
const DARKNESS_UID := "CSVE1C_DAR"
const LUMINOUS_UID := "CSV1C_127"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _deck_seed: Dictionary = {}
var _current_fingerprint := ""
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_deck_seed = _load_json(DECK_SEED_PATH)
	var deck := DeckData.from_dict(_deck_seed)
	_current_fingerprint = SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Froslass/Munkidori profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Froslass/Munkidori semantic manifest must load")
	_check(_profile.get("modules", []) == ["damage_counter_control", "control_recycle"], \
		"scenarios must use the production counter-control/recycle module composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")

	_scenario_a_double_froslass_check_stacks_exactly()
	_scenario_b_luminous_munkidori_moves_exact_three()
	_scenario_c_old_snorunt_evolves_before_dark_fueling()
	_scenario_d_stretcher_attach_before_research()
	_scenario_e_bloodmoon_takes_the_final_two_prizes()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800017631 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800017631 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_double_froslass_check_stacks_exactly() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(8)
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	var froslass_a := _real_slot(_real_card_data(FROSLASS_UID), 0)
	var froslass_b := _real_slot(_real_card_data(FROSLASS_UID), 0)
	var snorunt := _real_slot(_real_card_data(SNORUNT_UID), 0)
	var opponent_ability := _target_with_ability("Public opposing Ability Pokemon", 160, 1)
	var opponent_plain := _real_target("Public opposing no-Ability Pokemon", 160, 1)
	state.players[0].active_pokemon = munkidori
	state.players[0].bench = [froslass_a, froslass_b, snorunt]
	state.players[1].active_pokemon = opponent_ability
	state.players[1].bench = [opponent_plain]
	processor.register_pokemon_card(froslass_a.get_card_data())

	var first_damaged := processor.process_pokemon_check(state)
	var first_check_exact := munkidori.damage_counters == 20 \
		and opponent_ability.damage_counters == 20 \
		and froslass_a.damage_counters == 0 and froslass_b.damage_counters == 0 \
		and snorunt.damage_counters == 0 and opponent_plain.damage_counters == 0 \
		and first_damaged.has(munkidori) and first_damaged.has(opponent_ability) \
		and first_damaged.size() == 2
	var second_damaged := processor.process_pokemon_check(state)
	var accumulated_exact := munkidori.damage_counters == 40 \
		and opponent_ability.damage_counters == 40 \
		and second_damaged.size() == 2

	var passed := first_check_exact and accumulated_exact
	_check(passed, "scenario A must stack two real Freezing Shrouds per Pokemon Check and exclude Froslass/no-Ability targets")
	_rows.append(_row(
		"double_froslass_check_stacks_exactly",
		"雪妖女特性伤害累积",
		"两只雪妖女让双方所有拥有特性的非雪妖女宝可梦在每次宝可梦检查时各增加20伤害；连续两次检查精确累积到40，雪妖女自身与无特性宝可梦保持0。",
		"Freezing Shroud x2 at each Pokemon Check",
		["雪妖女不能伤害自己", "无特性的宝可梦不能被放置伤害指示物", "两只雪妖女不得被错误合并成每次只放1个指示物"],
		passed
	))


func _scenario_b_luminous_munkidori_moves_exact_three() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(9)
	var source := _real_slot(_real_card_data(FROSLASS_UID), 0)
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	var luminous := _real_instance(LUMINOUS_UID, 0)
	munkidori.attached_energy = [luminous]
	source.damage_counters = 40
	var target := _real_target("Public exact 30 HP target", 30, 1)
	state.players[0].active_pokemon = source
	state.players[0].bench = [munkidori]
	state.players[1].active_pokemon = target
	processor.register_pokemon_card(munkidori.get_card_data())

	var effect := processor.get_ability_effect(munkidori, 0, state)
	var source_steps: Array = effect.get_interaction_steps(munkidori.get_top_card(), state) if effect != null else []
	var source_step := _step(source_steps, "source_pokemon")
	var followup: Array = effect.get_followup_interaction_steps(
		munkidori.get_top_card(), state, {"source_pokemon": [source]}
	) if effect != null else []
	var counter_step := _step(followup, "target_damage_counters")
	var luminous_is_dark := processor.can_use_ability(munkidori, state, 0)
	var interaction_exact := (source_step.get("items", []) as Array) == [source] \
		and int(counter_step.get("total_counters", 0)) == 3 \
		and int(counter_step.get("max_assignments", 0)) == 1 \
		and target in (counter_step.get("target_items", []) as Array)
	var over_cap_rejected := not processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [source],
		"target_damage_counters": [{"target": target, "amount": 40}],
	}], state)
	var unchanged_after_rejection := source.damage_counters == 40 and target.damage_counters == 0
	var moved := processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [source],
		"target_damage_counters": [{"target": target, "amount": 30}],
	}], state)
	var once_guard := not processor.can_use_ability(munkidori, state, 0)

	var downgraded_processor := EffectProcessor.new()
	var downgraded_state := _game_state(9)
	var downgraded_source := _real_slot(_real_card_data(FROSLASS_UID), 0)
	downgraded_source.damage_counters = 30
	var downgraded_munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	downgraded_munkidori.attached_energy = [
		_real_instance(LUMINOUS_UID, 0),
		_special_energy("Fixture second Special Energy", 0),
	]
	downgraded_state.players[0].active_pokemon = downgraded_source
	downgraded_state.players[0].bench = [downgraded_munkidori]
	downgraded_state.players[1].active_pokemon = _real_target("Public downgrade target", 100, 1)
	downgraded_processor.register_pokemon_card(downgraded_munkidori.get_card_data())
	var second_special_blocks := not downgraded_processor.can_use_ability(
		downgraded_munkidori, downgraded_state, 0)

	var observation := _observation([
		_ability("ability:adrena-exact-three", "slot:munkidori", MUNKIDORI_UID, true),
		_end_turn("end:leave-damage-unmoved"),
	], _slot("slot:froslass", FROSLASS_UID, [], 40, 50, 90, 1), [
		_slot("slot:munkidori", MUNKIDORI_UID, [_energy_card(LUMINOUS_UID, "ANY")], 0, 110, 110, 1),
	], _public_target("PUBLIC_30_HP_SINGLE", 30, 1), [], 16, 4)
	var facts := _facts(false, true, false, 1, false, false, 0, 4)
	var frontier := _frontier(observation, {
		"ability:adrena-exact-three": 650.0,
		"end:leave-damage-unmoved": -500.0,
	}, facts, "ability:adrena-exact-three")
	var exact_candidate := _candidate(frontier, "ability:adrena-exact-three")

	var passed := luminous_is_dark and interaction_exact and over_cap_rejected \
		and unchanged_after_rejection and moved \
		and source.damage_counters == 10 and target.damage_counters == 30 \
		and once_guard and second_special_blocks and not exact_candidate.is_empty()
	_check(passed, "scenario B must let lone Luminous Energy power one exact three-counter Adrena-Brain transfer with strict cap/downgrade guards")
	_rows.append(_row(
		"luminous_munkidori_moves_exact_three",
		"愿增猿搬伤/恶能",
		"愿增猿仅附夜光能量时把它视为恶能，先拒绝超上限的4指示物请求，再从受伤雪妖女精确搬3个到只剩30HP的公开目标，并锁住同回合第二次使用。",
		"Adrena Brain: move exactly 3 counters with lone Luminous Energy",
		["单次最多搬3个伤害指示物", "同一愿增猿每回合只能使用一次", "夜光能量与另一张特殊能量并存时退化为无色，不能启动特性"],
		passed
	))


func _scenario_c_old_snorunt_evolves_before_dark_fueling() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(7)
	var state := gsm.game_state
	var maractus := _real_slot(_real_card_data(MARACTUS_UID), 0)
	var old_snorunt := _real_slot(_real_card_data(SNORUNT_UID), 0)
	var fresh_snorunt := _real_slot(_real_card_data(SNORUNT_UID), 0)
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	old_snorunt.turn_played = 2
	fresh_snorunt.turn_played = state.turn_number
	state.players[0].active_pokemon = maractus
	state.players[0].bench = [old_snorunt, fresh_snorunt, munkidori]
	state.players[1].active_pokemon = _target_with_ability("Public evolution pressure target", 180, 1)
	var froslass := _real_instance(FROSLASS_UID, 0)
	var darkness := _real_instance(DARKNESS_UID, 0)
	state.players[0].hand = [froslass, darkness]
	gsm.effect_processor.register_pokemon_card(froslass.card_data)
	gsm.effect_processor.register_pokemon_card(munkidori.get_card_data())

	var old_legal := gsm.rule_validator.can_evolve(state, 0, old_snorunt, froslass, gsm.effect_processor)
	var fresh_blocked := not gsm.rule_validator.can_evolve(state, 0, fresh_snorunt, froslass, gsm.effect_processor)
	var wrong_fresh_rejected := not gsm.evolve_pokemon(0, froslass, fresh_snorunt)
	var evolved := gsm.evolve_pokemon(0, froslass, old_snorunt)
	var attached := gsm.attach_energy(0, darkness, munkidori)
	var check_damaged := gsm.effect_processor.process_pokemon_check(state)
	var engine_online := old_snorunt.get_card_data().get_uid() == FROSLASS_UID \
		and fresh_snorunt.get_card_data().get_uid() == SNORUNT_UID \
		and darkness in munkidori.attached_energy \
		and munkidori.damage_counters == 10 \
		and check_damaged.has(munkidori) \
		and gsm.effect_processor.can_use_ability(munkidori, state, 0)
	var second_attachment_blocked := not gsm.rule_validator.can_attach_energy(
		state, 0, _real_instance(DARKNESS_UID, 0), gsm.effect_processor)

	var before := _observation([
		_evolve("evolve:old-snorunt", FROSLASS_UID, "slot:old-snorunt"),
		_attach_energy("energy:dark-to-munkidori", DARKNESS_UID, "slot:munkidori"),
	], _slot("slot:maractus", MARACTUS_UID, [], 0, 120, 120, 1), [
		_slot("slot:old-snorunt", SNORUNT_UID, [], 0, 70, 70, 1),
		_slot("slot:fresh-snorunt", SNORUNT_UID, [], 0, 70, 70, 1),
		_slot("slot:munkidori", MUNKIDORI_UID, [], 0, 110, 110, 1),
	], _public_target("PUBLIC_EVOLUTION_PRESSURE", 180, 1), [], 22, 5)
	before["own"]["hand"] = [_card(FROSLASS_UID), _energy_card(DARKNESS_UID, "D")]
	var facts_before := _facts(false, false, true, 2, false, false, 0, 5)
	var frontier := _frontier(before, {
		"evolve:old-snorunt": 620.0,
		"energy:dark-to-munkidori": 590.0,
	}, facts_before, "evolve:old-snorunt")
	var evolve_candidate := _candidate(frontier, "evolve:old-snorunt")
	var deterministic_suffix_bound := not evolve_candidate.is_empty() \
		and str(evolve_candidate.get("safe_prefix_action_id", "")) == "evolve:old-snorunt"

	var passed := old_legal and fresh_blocked and wrong_fresh_rejected and evolved and attached \
		and engine_online and second_attachment_blocked and deterministic_suffix_bound
	_check(passed, "scenario C must evolve only the old Snorunt, spend the one manual attachment on Munkidori, and expose the new counter engine: %s" % JSON.stringify({
		"old_legal": old_legal,
		"fresh_blocked": fresh_blocked,
		"wrong_fresh_rejected": wrong_fresh_rejected,
		"evolved": evolved,
		"attached": attached,
		"engine_online": engine_online,
		"second_attachment_blocked": second_attachment_blocked,
		"deterministic_suffix_bound": deterministic_suffix_bound,
		"old_uid": old_snorunt.get_card_data().get_uid(),
		"fresh_uid": fresh_snorunt.get_card_data().get_uid(),
		"munk_damage": munkidori.damage_counters,
	}))
	_rows.append(_row(
		"old_snorunt_evolves_before_dark_fueling",
		"进化与填能",
		"旧雪童子进化成雪妖女，本回合新下场的雪童子保持未进化；随后把唯一手贴恶能交给愿增猿，宝可梦检查产生伤害后立刻开启搬伤路线。",
		"Evolve old Snorunt -> attach Darkness to Munkidori",
		["本回合刚下场的雪童子不能进化", "一回合不能进行第二次手贴", "没有恶能或伤害来源时愿增猿不能宣言特性"],
		passed
	))


func _scenario_d_stretcher_attach_before_research() -> void:
	var correct := _recovery_draw_state()
	var gsm: GameStateMachine = correct.get("gsm")
	var state: GameState = gsm.game_state
	var munkidori: PokemonSlot = correct.get("munkidori")
	var stretcher: CardInstance = correct.get("stretcher")
	var research: CardInstance = correct.get("research")
	var darkness: CardInstance = correct.get("darkness")
	var luminous: CardInstance = correct.get("luminous")
	var effect := gsm.effect_processor.get_effect(stretcher.card_data.effect_id)
	var steps: Array = effect.get_interaction_steps(stretcher, state) if effect != null else []
	var choice_step := _step(steps, "night_stretcher_choice")
	var recovery_exact := darkness in (choice_step.get("items", []) as Array) \
		and luminous not in (choice_step.get("items", []) as Array) \
		and int(choice_step.get("max_select", 0)) == 1

	var before := _recovery_observation(state, [
		_play_trainer("item:stretcher-dark-first", NIGHT_STRETCHER_UID, true),
		_play_trainer("supporter:research-first-wrong", RESEARCH_UID, false),
	])
	before["observation_version"] = 1
	before["observation_hash"] = "froslass-munkidori-before-stretcher"
	var facts_before := _facts(false, false, true, 3, false, false, 0, 4)
	var frontier := _frontier(before, {
		"item:stretcher-dark-first": 640.0,
		"supporter:research-first-wrong": 610.0,
	}, facts_before, "item:stretcher-dark-first")
	var stretcher_candidate := _candidate(frontier, "item:stretcher-dark-first")

	var recovered := gsm.play_trainer(0, stretcher, [{"night_stretcher_choice": [darkness]}])
	var attached := gsm.attach_energy(0, darkness, munkidori)
	var before_research := _recovery_observation(state, [
		_play_trainer("supporter:research-after-attachment", RESEARCH_UID, false),
	])
	before_research["observation_version"] = 2
	before_research["observation_hash"] = "froslass-munkidori-before-research"
	var research_facts_before := _facts(false, false, false, state.players[0].hand.size(), false, false, 0, 4)
	var research_frontier := _frontier(before_research, {
		"supporter:research-after-attachment": 650.0,
	}, research_facts_before, "supporter:research-after-attachment")
	var research_candidate := _candidate(research_frontier, "supporter:research-after-attachment")
	var researched := gsm.play_trainer(0, research, [])
	var correct_hand_names := _instance_names(state.players[0].hand)
	var correct_keeps_engine := recovered and attached and researched \
		and darkness in munkidori.attached_energy \
		and correct_hand_names == [
			"VISIBLE_DRAW_A", "VISIBLE_DRAW_B", "VISIBLE_DRAW_C", "VISIBLE_DRAW_D",
			"VISIBLE_DRAW_E", "VISIBLE_DRAW_F", "VISIBLE_DRAW_G",
		]
	var after := _recovery_observation(state, [])
	after["observation_version"] = 2
	after["observation_hash"] = "froslass-munkidori-after-stretcher-attach-research"
	var facts_after := _facts(false, false, false, 7, false, false, 0, 4)
	var reopened := _epoch_reopens(
		before_research, after, research_facts_before, facts_after, research_candidate, research_frontier)

	var wrong := _recovery_draw_state()
	var wrong_gsm: GameStateMachine = wrong.get("gsm")
	var wrong_state := wrong_gsm.game_state
	var wrong_stretcher: CardInstance = wrong.get("stretcher")
	var wrong_research: CardInstance = wrong.get("research")
	var wrong_darkness: CardInstance = wrong.get("darkness")
	var wrong_munkidori: PokemonSlot = wrong.get("munkidori")
	var wrong_researched := wrong_gsm.play_trainer(0, wrong_research, [])
	var stretcher_was_discarded := wrong_stretcher in wrong_state.players[0].discard_pile
	var cannot_recover_after := not wrong_gsm.play_trainer(
		0, wrong_stretcher, [{"night_stretcher_choice": [wrong_darkness]}])
	var wrong_loses_attachment := wrong_darkness in wrong_state.players[0].discard_pile \
		and wrong_munkidori.attached_energy.is_empty()

	var passed := recovery_exact and correct_keeps_engine and reopened \
		and wrong_researched and stretcher_was_discarded and cannot_recover_after and wrong_loses_attachment
	_check(passed, "scenario D must recover and attach Darkness before Professor's Research discards the recovery window: %s" % JSON.stringify({
		"recovery_exact": recovery_exact,
		"recovered": recovered,
		"attached": attached,
		"researched": researched,
		"correct_hand_names": correct_hand_names,
		"correct_keeps_engine": correct_keeps_engine,
		"reopened": reopened,
		"wrong_researched": wrong_researched,
		"stretcher_was_discarded": stretcher_was_discarded,
		"cannot_recover_after": cannot_recover_after,
		"wrong_loses_attachment": wrong_loses_attachment,
	}))
	_rows.append(_row(
		"stretcher_attach_before_research",
		"支援者/抽牌/回收顺序",
		"夜间担架先从弃牌区精确回收基础恶能，立即手贴给愿增猿，再用博士的研究弃掉剩余手牌并抽7；若先研究，担架会被弃掉且恶能永久留在弃牌区。",
		"Night Stretcher(Darkness) -> attach to Munkidori -> Professor's Research draw 7",
		["夜间担架不能回收特殊的夜光能量", "夜间担架一次只能回收1张", "先用博士会把尚未使用的担架弃掉"],
		passed
	))


func _scenario_e_bloodmoon_takes_the_final_two_prizes() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _bloodmoon_state(1, 240)
	var state := gsm.game_state
	var bloodmoon := state.players[0].active_pokemon
	gsm.effect_processor.register_pokemon_card(bloodmoon.get_card_data())
	var attack := bloodmoon.get_card_data().attacks[0]
	var modifier := gsm.effect_processor.get_attack_colorless_cost_modifier(bloodmoon, attack, state)
	var free_attack := gsm.rule_validator.can_use_attack(state, 0, 0, gsm.effect_processor)
	var attacked := gsm.use_attack(0, 0)
	if attacked:
		gsm.call("_check_all_knockouts")
	var first_prize_taken := gsm.resolve_take_prize(0, 0) if attacked else false
	var second_prize_taken := gsm.resolve_take_prize(0, 1) if first_prize_taken else false
	var final_two_exact := attacked and first_prize_taken and second_prize_taken \
		and state.players[0].prizes.is_empty() and state.is_game_over()

	var cost_negative := _bloodmoon_state(2, 240)
	var cost_processor := EffectProcessor.new()
	var cost_bloodmoon := cost_negative.players[0].active_pokemon
	cost_processor.register_pokemon_card(cost_bloodmoon.get_card_data())
	var one_energy_still_required := not RuleValidator.new().can_use_attack(
		cost_negative, 0, 0, cost_processor)

	var hp_gsm := GameStateMachine.new()
	hp_gsm.game_state = _bloodmoon_state(1, 241)
	var hp_bloodmoon := hp_gsm.game_state.players[0].active_pokemon
	hp_gsm.effect_processor.register_pokemon_card(hp_bloodmoon.get_card_data())
	var hp_attacked := hp_gsm.use_attack(0, 0)
	var exact_hp_guard := hp_attacked \
		and hp_gsm.game_state.players[1].active_pokemon != null \
		and hp_gsm.game_state.players[1].active_pokemon.damage_counters == 240 \
		and not hp_gsm.game_state.is_game_over()

	var observation := _observation([
		_attack("attack:bloodmoon-final-two", BLOODMOON_UID, 0, 240, true),
		_play_trainer("supporter:research-too-late", RESEARCH_UID, false),
	], _slot("slot:bloodmoon", BLOODMOON_UID, [], 0, 260, 260, 2), [],
		_public_target("PUBLIC_240_HP_EX", 240, 2), [], 9, 2)
	observation["opponent"]["prizes_remaining"] = 1
	var facts := _facts(true, true, false, 1, false, false, 240, 2)
	facts["prize"] = {"current_swing": 2, "win_now": true}
	var frontier := _frontier(observation, {
		"attack:bloodmoon-final-two": 800.0,
		"supporter:research-too-late": 780.0,
	}, facts, "attack:bloodmoon-final-two")
	var attack_candidate := _candidate(frontier, "attack:bloodmoon-final-two")
	var safety := _route_safety(attack_candidate, frontier, facts)

	var passed := modifier == -5 and free_attack and final_two_exact \
		and one_energy_still_required and exact_hp_guard \
		and not attack_candidate.is_empty() and bool(safety.get("valid", false))
	_check(passed, "scenario E must use free Blood Moon immediately for the final two Prizes with exact cost/HP boundaries: %s" % JSON.stringify({
		"modifier": modifier,
		"free_attack": free_attack,
		"attacked": attacked,
		"first_prize_taken": first_prize_taken,
		"second_prize_taken": second_prize_taken,
		"own_prizes": state.players[0].prizes.size(),
		"game_over": state.is_game_over(),
		"final_two_exact": final_two_exact,
		"one_energy_still_required": one_energy_still_required,
		"hp_attacked": hp_attacked,
		"hp_target_damage": hp_gsm.game_state.players[1].active_pokemon.damage_counters if hp_gsm.game_state.players[1].active_pokemon != null else -1,
		"hp_game_over": hp_gsm.game_state.is_game_over(),
		"exact_hp_guard": exact_hp_guard,
		"candidate": attack_candidate,
		"safety": safety,
	}))
	_rows.append(_row(
		"bloodmoon_takes_the_final_two_prizes",
		"关键奖终局",
		"对手只剩1奖意味着已拿5奖，月月熊赫月ex的老练招式把血月5无色费用完整减为0，立刻击倒公开240HP双奖目标结束对局，不再进行博士等可选周转。",
		"Blood Moon 240 for the final two Prizes",
		["对手还剩2奖时无能量月月熊仍差1个费用", "240不能击倒剩余241HP目标", "已锁定终局时禁止先做可选抽牌"],
		passed
	))


func _frontier(
	observation: Dictionary,
	scores: Dictionary,
	facts: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(
		observation, scores, _manifest, facts)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest)
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
	frontier: Array[Dictionary]
) -> bool:
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return bool(strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(candidate.get("route_id", "")),
			"candidate_id": str(candidate.get("candidate_id", "")),
		}, delta, frontier))


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	_check(false, "candidate for %s must exist" % action_id)
	return {}


func _observation(
	actions: Array,
	active: Dictionary,
	bench: Array,
	opponent_active: Dictionary,
	opponent_bench: Array,
	deck_count: int,
	prizes_remaining: int
) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "froslass-munkidori-complex-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": prizes_remaining,
		},
		"opponent": {
			"active": opponent_active,
			"bench": opponent_bench,
			"prizes_remaining": 6,
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
	max_damage: int,
	prizes_remaining: int
) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": ko_available, "max_damage": max_damage},
		"turn": {"energy_available": energy_available, "supporter_available": true},
		"resources": {
			"deck_low": deck_low,
			"deck_critical": deck_critical,
			"hand_size": hand_size,
			"bench_slots_free": 2,
			"prizes_remaining": prizes_remaining,
			"energy_on_board": 0,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _slot(
	slot_id: String,
	uid: String,
	energy: Array,
	damage: int,
	remaining_hp: int,
	max_hp: int,
	prize_count: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"tool": {},
		"energy": energy,
		"energy_count": energy.size(),
		"damage": damage,
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _public_target(uid: String, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": "slot:%s" % uid.to_lower(),
		"pokemon": {"uid": uid},
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp,
		"damage": 0,
		"prize_count": prize_count,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _evolve(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "evolve",
		"card": _card(uid),
		"target": target,
		"requires_interaction": false,
	}


func _attach_energy(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_energy",
		"card": _energy_card(uid, "D"),
		"target": target,
		"requires_interaction": false,
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


func _energy_card(uid: String, symbol: String) -> Dictionary:
	var card := _card(uid)
	card["energy_type"] = symbol
	card["energy_provides"] = symbol
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if uid == DARKNESS_UID and "basic_energy" not in roles:
		roles.append("basic_energy")
	card["semantic_roles"] = roles
	return card


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


func _game_state(turn: int = 8) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
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


func _special_energy(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Special Energy"
	data.energy_provides = "C"
	data.effect_id = "fixture_second_special_energy"
	return CardInstance.create(data, owner)


func _filler_instance(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	data.set_code = "FIXTURE"
	data.card_index = name
	return CardInstance.create(data, owner)


func _recovery_draw_state() -> Dictionary:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(10)
	var state := gsm.game_state
	var maractus := _real_slot(_real_card_data(MARACTUS_UID), 0)
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	state.players[0].active_pokemon = maractus
	state.players[0].bench = [munkidori]
	state.players[1].active_pokemon = _real_target("Public recovery target", 180, 1)
	var stretcher := _real_instance(NIGHT_STRETCHER_UID, 0)
	var research := _real_instance(RESEARCH_UID, 0)
	var darkness := _real_instance(DARKNESS_UID, 0)
	var luminous := _real_instance(LUMINOUS_UID, 0)
	state.players[0].hand = [stretcher, research, _filler_instance("VISIBLE_STALE_HAND", 0)]
	state.players[0].discard_pile = [darkness, luminous]
	state.players[0].deck = [
		_filler_instance("VISIBLE_DRAW_A", 0),
		_filler_instance("VISIBLE_DRAW_B", 0),
		_filler_instance("VISIBLE_DRAW_C", 0),
		_filler_instance("VISIBLE_DRAW_D", 0),
		_filler_instance("VISIBLE_DRAW_E", 0),
		_filler_instance("VISIBLE_DRAW_F", 0),
		_filler_instance("VISIBLE_DRAW_G", 0),
	]
	return {
		"gsm": gsm,
		"munkidori": munkidori,
		"stretcher": stretcher,
		"research": research,
		"darkness": darkness,
		"luminous": luminous,
	}


func _recovery_observation(state: GameState, actions: Array) -> Dictionary:
	var result := _observation(
		actions,
		_slot("slot:maractus", MARACTUS_UID, [], 0, 120, 120, 1),
		[_slot("slot:munkidori", MUNKIDORI_UID, [], 0, 110, 110, 1)],
		_public_target("PUBLIC_RECOVERY_TARGET", 180, 1),
		[],
		state.players[0].deck.size(),
		4
	)
	var hand: Array[Dictionary] = []
	for instance: CardInstance in state.players[0].hand:
		if instance.card_data.get_uid() in [NIGHT_STRETCHER_UID, RESEARCH_UID]:
			hand.append(_card(instance.card_data.get_uid()))
		else:
			hand.append({"uid": instance.card_data.get_uid(), "name": instance.card_data.name_en})
	result["own"]["hand"] = hand
	result["own"]["discard"] = [
		_energy_card(DARKNESS_UID, "D"),
		_energy_card(LUMINOUS_UID, "ANY"),
	]
	return result


func _bloodmoon_state(opponent_prizes_remaining: int, defender_hp: int) -> GameState:
	var state := _game_state(12)
	state.players[0].active_pokemon = _real_slot(_real_card_data(BLOODMOON_UID), 0)
	state.players[1].active_pokemon = _real_target("Public Blood Moon target", defender_hp, 2)
	state.players[0].deck = [
		_filler_instance("OWN_BLOODMOON_DRAW_A", 0),
		_filler_instance("OWN_BLOODMOON_DRAW_B", 0),
	]
	state.players[1].deck = [
		_filler_instance("OPP_BLOODMOON_DRAW_A", 1),
		_filler_instance("OPP_BLOODMOON_DRAW_B", 1),
	]
	_fill_prizes(state.players[0], 2, "OWN_FINAL_PRIZE")
	_fill_prizes(state.players[1], opponent_prizes_remaining, "OPP_LATE_PRIZE")
	return state


func _instance_names(cards: Array[CardInstance]) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in cards:
		names.append(card.card_data.name_en if card.card_data.name_en != "" else card.card_data.name)
	return names


func _fill_prizes(player: PlayerState, count: int, prefix: String) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_filler_instance("%s_%d" % [prefix, index], player.player_index))


func _step(steps: Array, id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == id:
			return raw_step as Dictionary
	return {}


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
		"deck_name": "18.0 雪妖女愿增猿",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"deck_source": {
			"source_kind": "bundled_ai",
			"bundled_seed_path": DECK_SEED_PATH,
			"source_provider": str(_deck_seed.get("source_provider", "")),
			"source_url": str(_deck_seed.get("source_url", "")),
			"total_cards": int(_deck_seed.get("total_cards", 0)),
			"deck_content_fingerprint": _current_fingerprint,
			"semantic_manifest_fingerprint": str(_manifest.get("deck_content_fingerprint", "")),
			"fingerprint_verified": _current_fingerprint != "" \
				and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")),
		},
		"baseline": {
			"status": "pending_current_bundled_ai_round00",
			"required_deck_content_fingerprint": _current_fingerprint,
			"valid_round00_found": false,
			"inspected_artifact": ROUND00_PATH,
			"artifact_exists": FileAccess.file_exists(ROUND00_PATH),
			"accepted_artifact": "",
			"seed_base": DECK_ID,
			"legacy_user_deck_evidence_reused": false,
			"note": "The existing round00 has no deck_source/deck_content_fingerprint/manifest provenance, so it cannot be matched to the current bundled_ai fingerprint and is not accepted as baseline evidence.",
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"The double-Freezing-Shroud stack, lone-Luminous Adrena Brain transfer, normal evolution, manual attachment, Night Stretcher recovery, Research draw, and Blood Moon cost reduction are verified through real engine paths.",
			"Generic damage-counter/recycle modules still need live bounded certificates for the exact multi-action continuations and post-interaction target binding.",
			"A new provenance-bearing, fingerprint-aligned bundled_ai round00 and paired-seed comparison against the exact Rule floor remain pending.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"real_model_formal_run": false,
			"hidden_sentinel_absent_from_frontiers": true,
			"invalidated_user_deck_evidence_reused": false,
		},
		"coverage": [
			"two Froslass Pokemon Check abilities stacking exact public damage while excluding Froslass and no-Ability targets",
			"lone Luminous Energy powering Munkidori's exact three-counter transfer with cap, once, and downgrade guards",
			"only an old Snorunt evolving before the one manual Darkness attachment turns Munkidori online",
			"Night Stretcher recovering basic Darkness for immediate attachment before Professor's Research draws seven",
			"free Blood Moon 240 taking the final two Prizes with exact opponent-prize and HP boundaries",
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
