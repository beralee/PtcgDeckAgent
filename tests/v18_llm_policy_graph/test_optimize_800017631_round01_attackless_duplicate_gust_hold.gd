extends SceneTree

## Focused regression for bundled_ai deck 800017631, seed 800017635, turn 5.
##
## The captured Rule suffix has already resolved Counter Catcher #35, moving
## Fezandipiti ex slot:51 Active and Raichu V slot:34 to the Bench.  Rule then
## spends Counter Catcher #36 to move Raichu V straight back Active, attaches
## TM: Devolution #45 to the same Froslass, and ends without an attack or KO.
##
## The certificate preserves #36 and executes the otherwise-identical
## public suffix:
##
##   attach TM: Devolution #45 -> action_resolved reobserve -> end turn
##
## Froslass Freezing Shroud iterates every Pokemon on both fields and is not
## Active-position dependent.  The real-engine counterfactual below proves the
## second gust changes neither Pokemon Check damage, prizes, damage, attack
## readiness, nor any other declared Active-dependent payoff.
##
## Production must issue the exact graph-only public certificate while every
## negative boundary stays green.

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const PolicyValidatorScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyValidator.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const FroslassShroudScript = preload("res://scripts/effects/pokemon_effects/AbilityFroslassFreezingShroud.gd")

const DECK_ID := 800017631
const TRACE_SEED := 800017635
const TRACE_TURN := 5
const DECK_PATH := "res://data/bundled_user/decks/800017631.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800017631.json"
const EXPECTED_DECK_FINGERPRINT := "ef817989aed00513d93f10889e93a3bea0b94f63a369408389a590953a50d810"
const EXPECTED_PROFILE_FINGERPRINT := "b72e7f0806688b0ca3ba01f1d7bf3e6e37b7a8ec7d234719516825a606b04989"
const EXPECTED_MODULES := ["damage_counter_control", "control_recycle"]

const TRACE_OBSERVATION_VERSION := 17
const POST_TOOL_OBSERVATION_VERSION := 19
const TRACE_OBSERVATION_HASH := "c4fd81323ccf63fca63570b4e7092cca9d1ddefe39ca753bdb2703b56d8d7944"
const POST_TOOL_OBSERVATION_HASH := "counterfactual:800017631:seed800017635:t5:o19:hold-catcher36:tool45"

const COUNTER_CATCHER_UID := "CSV6C_114"
const COUNTER_CATCHER_EFFECT_ID := "06bc00d5dcec33898dc6db2e4c4d10ec"
const FIRST_COUNTER_CATCHER_INSTANCE := 35
const SECOND_COUNTER_CATCHER_INSTANCE := 36
const FROSLASS_UID := "CSV7C_059"
const FROSLASS_EFFECT_ID := "f27a2982c03f5b49a68ec0a77a2d6e48"
const BUDEW_UID := "CSV9.5C_004"
const BUDEW_EFFECT_ID := "28505a8ad6e07e74382c1b5e09737932"
const FEZANDIPITI_UID := "CSV8C_135"
const FEZANDIPITI_EFFECT_ID := "ab6c3357e2b8a8385a68da738f41e0c1"
const RAICHU_UID := "CS5aC_019"
const RAICHU_EFFECT_ID := "4c9d0366a3633bc11a4612a3ef1624cf"
const TM_DEVOLUTION_UID := "CSV5C_120"
const TM_DEVOLUTION_EFFECT_ID := "e228e825c541ce80e2507c557cb506c3"
const TM_DEVOLUTION_INSTANCE := 45
const LUMINOUS_UID := "CSV1C_127"
const LUMINOUS_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const LUMINOUS_INSTANCE := 59
const NIGHT_STRETCHER_UID := "CSV8C_183"
const NIGHT_STRETCHER_EFFECT_ID := "3e6f1daf545dfed48d0588dd50792a2e"
const NIGHT_STRETCHER_INSTANCE := 29

const FROSLASS_SLOT := "slot:10"
const BUDEW_SLOT := "slot:11"
const FEZANDIPITI_SLOT := "slot:51"
const RAICHU_SLOT := "slot:34"

const FIRST_GUST_ACTION_ID := "action:play_trainer:35:-:-:-1:-1"
const FIRST_GUST_CANDIDATE_ID := "candidate:65edfe5b7a11e7b29a36"
const RULE_SECOND_GUST_ACTION_ID := "action:play_trainer:36:-:-:-1:-1"
const RULE_SECOND_GUST_CANDIDATE_ID := "candidate:1a4905b8ccc439503437"
const TOOL_ACTION_ID := "action:attach_tool:45:-:10:-1:-1"
const TOOL_CANDIDATE_ID := "candidate:6742e330faa673a378be"
const END_ACTION_ID := "action:end_turn:-:-:-:-1:-1"
const END_CANDIDATE_ID := "candidate:8f40cb63bb171e97d5f0"
const RULE_SECOND_GUST_SCORE := 538.8
const TOOL_SCORE := 322.4
const END_SCORE := -1024.0
const EXPECTED_CERTIFICATE := "public_attackless_duplicate_gust_hold"

var _failures: Array[String] = []
var _negative_count := 0


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	var manifest := _load_json(MANIFEST_PATH)
	var deck_seed := _load_json(DECK_PATH)
	var deck := DeckData.from_dict(deck_seed)
	var fingerprint := SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60,
		"fixture must bind the current exact 60-card bundled_ai deck")
	_check(fingerprint == EXPECTED_DECK_FINGERPRINT
		and fingerprint == str(manifest.get("deck_content_fingerprint", "")),
		"fixture and semantic manifest must bind the current bundled_ai fingerprint")
	_check(int(profile.get("profile_version", 0)) == 3
		and int(profile.get("semantic_version", 0)) == 1,
		"fixture must bind current profile v3 / semantic v1")
	_check(ContractsScript.stable_hash(profile) == EXPECTED_PROFILE_FINGERPRINT,
		"fixture must bind current profile fingerprint; actual=%s" % ContractsScript.stable_hash(profile))
	_check(profile.get("modules", []) == EXPECTED_MODULES,
		"fixture must bind damage_counter_control + control_recycle only")
	_check(_manifest_contract(manifest),
		"semantic manifest must bind every tactically relevant UID/effect pair")
	_check(is_equal_approx(RULE_SECOND_GUST_SCORE - TOOL_SCORE, 216.4),
		"captured Rule second-gust to TM score gap must remain exact")

	_test_real_engine_counterfactual()

	var positive := _sequence_contract(_base_sequence(), profile, manifest)
	_check(bool(positive.get("accepted", false)),
		"O17 must hold Catcher #36 -> attach TM #45 -> action_resolved reobserve -> end with one model graph; blocker=%s" % str(positive.get("reason", "unknown")))

	_test_fail_closed_boundaries(profile, manifest)
	_check(_negative_count >= 40,
		"focused regression must prove at least forty independent fail-closed boundaries")

	if _failures.is_empty():
		print("V18CPG 800017631 attackless duplicate-gust hold focused regression: PASS (%d boundaries)" % _negative_count)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800017631 attackless duplicate-gust hold focused regression: FAIL (%d failure, %d negative boundaries passed)" % [_failures.size(), _negative_count])
	quit(1)


func _sequence_contract(
	sequence: Array[Dictionary],
	profile: Dictionary,
	manifest: Dictionary
) -> Dictionary:
	if ContractsScript.stable_hash(profile) != EXPECTED_PROFILE_FINGERPRINT:
		return _rejected("profile_fingerprint")
	if profile.get("modules", []) != EXPECTED_MODULES:
		return _rejected("module_composition")
	if not _manifest_contract(manifest):
		return _rejected("manifest_contract")
	var shape := _validate_public_sequence_shape(sequence)
	if not bool(shape.get("valid", false)):
		return _rejected(str(shape.get("reason", "public_sequence_shape")))

	var strategy := StrategyScript.new()
	strategy.configure_profile(profile, manifest)
	var root_facts := _facts_for(sequence[0])
	var post_facts := _facts_for(sequence[1])
	var root_frontier := _frontier(sequence[0], root_facts, profile, manifest, false)
	var post_frontier := _frontier(sequence[1], post_facts, profile, manifest, true)
	var tool := _candidate(root_frontier, TOOL_CANDIDATE_ID)
	var end_turn := _candidate(post_frontier, END_CANDIDATE_ID)
	if tool.is_empty() or end_turn.is_empty():
		return _rejected("required_candidate_missing")
	if str(root_frontier[0].get("candidate_id", "")) != RULE_SECOND_GUST_CANDIDATE_ID \
			or str(post_frontier[0].get("candidate_id", "")) != RULE_SECOND_GUST_CANDIDATE_ID:
		return _rejected("exact_rule_floor_not_first")

	var root_safety := strategy._validate_model_route_safety(
		"route:develop", root_frontier, root_facts, TOOL_CANDIDATE_ID
	)
	if not bool(root_safety.get("valid", false)):
		return _rejected("root_tool_not_certified:%s" % str(root_safety.get("reason", "unknown")))
	if str(root_safety.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE:
		return _rejected("root_certificate_kind")

	var post_safety := strategy._validate_model_route_safety(
		"route:end_turn", post_frontier, post_facts, END_CANDIDATE_ID
	)
	if not bool(post_safety.get("valid", false)):
		return _rejected("post_tool_end_not_certified:%s" % str(post_safety.get("reason", "unknown")))
	if str(post_safety.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE:
		return _rejected("post_tool_certificate_kind")

	var response_validation := PolicyValidatorScript.new().validate_response(
		{"policy": _two_epoch_policy()},
		["route:develop", "route:end_turn"],
		8,
		[TOOL_CANDIDATE_ID],
		true
	)
	if not bool(response_validation.get("valid", false)):
		return _rejected("policy_invalid:%s" % str(response_validation.get("reason", "unknown")))

	# Request #1 owns the bounded graph.  The successful tool action produces one
	# public observation; the declared checkpoint advances locally to end turn.
	strategy._turn_model_requests = 1
	strategy._policy_graph.install(response_validation.get("policy", {}), "model_selected_local_route")
	var transition := strategy._policy_graph.advance_after_observation(
		post_facts, _route_ids(post_frontier), _candidate_ids(post_frontier)
	)
	if str(transition.get("status", "")) != "route" \
			or str(transition.get("route_id", "")) != "route:end_turn" \
			or not bool(transition.get("branch_hit", false)):
		return _rejected("reobserve_checkpoint_did_not_bind_end")
	if strategy._turn_model_requests != 1:
		return _rejected("checkpoint_opened_extra_model_request")
	return {
		"accepted": true,
		"reason": "",
		"certificate_kind": EXPECTED_CERTIFICATE,
		"model_calls": 1,
		"branch_hits": 1,
	}


func _test_real_engine_counterfactual() -> void:
	var rule_fixture := _engine_fixture()
	var rule_gsm: GameStateMachine = rule_fixture["gsm"]
	var rule_state: GameState = rule_fixture["state"]
	var rule_first: CardInstance = rule_fixture["first_catcher"]
	var rule_second: CardInstance = rule_fixture["second_catcher"]
	var rule_tool: CardInstance = rule_fixture["tool"]
	var rule_froslass: PokemonSlot = rule_fixture["froslass"]
	var rule_fez: PokemonSlot = rule_fixture["fezandipiti"]
	var rule_raichu: PokemonSlot = rule_fixture["raichu"]
	var catcher_effect: BaseEffect = rule_gsm.effect_processor.get_effect(COUNTER_CATCHER_EFFECT_ID)
	_check(catcher_effect != null and bool(catcher_effect.call("can_execute", rule_first, rule_state)),
		"real first Counter Catcher must be legal at 6 prizes versus 5")
	var first_played := rule_gsm.play_trainer(0, rule_first, [{"opponent_bench_target": [rule_fez]}])
	_check(first_played
		and rule_state.players[1].active_pokemon == rule_fez
		and rule_raichu in rule_state.players[1].bench
		and rule_first in rule_state.players[0].discard_pile,
		"real first gust must bind #35 and produce captured Fezandipiti-Active O17")
	var second_steps: Array = catcher_effect.get_interaction_steps(rule_second, rule_state) \
		if catcher_effect != null else []
	var target_step := _interaction_step(second_steps, "opponent_bench_target")
	var public_targets: Array = target_step.get("items", []) if target_step.get("items", []) is Array else []
	_check(int(target_step.get("min_select", -1)) == 1
		and int(target_step.get("max_select", -1)) == 1
		and public_targets.size() == 1 and public_targets[0] == rule_raichu,
		"after gust #35, real gust #36 must bind the sole public Bench target Raichu V #34")
	var prizes_before := [rule_state.players[0].prizes.size(), rule_state.players[1].prizes.size()]
	var damage_before := [rule_fez.damage_counters, rule_raichu.damage_counters]
	var second_played := rule_gsm.play_trainer(0, rule_second, [{"opponent_bench_target": [rule_raichu]}])
	var rule_tool_attached := rule_gsm.attach_tool(0, rule_tool, rule_froslass)
	_check(second_played
		and rule_state.players[1].active_pokemon == rule_raichu
		and rule_fez in rule_state.players[1].bench
		and rule_second in rule_state.players[0].discard_pile,
		"captured Rule suffix must spend #36 and restore original Raichu V Active")
	_check(prizes_before == [rule_state.players[0].prizes.size(), rule_state.players[1].prizes.size()]
		and damage_before == [rule_fez.damage_counters, rule_raichu.damage_counters]
		and rule_tool_attached and rule_froslass.attached_tool == rule_tool,
		"second gust must award no prize/damage and Rule must still attach the same TM #45")

	var hold_fixture := _engine_fixture()
	var hold_gsm: GameStateMachine = hold_fixture["gsm"]
	var hold_state: GameState = hold_fixture["state"]
	var hold_first: CardInstance = hold_fixture["first_catcher"]
	var held_second: CardInstance = hold_fixture["second_catcher"]
	var held_tool: CardInstance = hold_fixture["tool"]
	var held_froslass: PokemonSlot = hold_fixture["froslass"]
	var held_fez: PokemonSlot = hold_fixture["fezandipiti"]
	var held_raichu: PokemonSlot = hold_fixture["raichu"]
	var held_first_played := hold_gsm.play_trainer(0, hold_first, [{"opponent_bench_target": [held_fez]}])
	var held_tool_attached := hold_gsm.attach_tool(0, held_tool, held_froslass)
	_check(held_first_played and held_tool_attached
		and hold_state.players[1].active_pokemon == held_fez
		and held_raichu in hold_state.players[1].bench
		and held_second in hold_state.players[0].hand
		and int(held_second.instance_id) == SECOND_COUNTER_CATCHER_INSTANCE
		and held_froslass.attached_tool == held_tool,
		"counterfactual must execute the same TM #45 while preserving exact Catcher #36")

	# Invoke the exact registered engine implementation directly.  The generic
	# EffectProcessor lookup is lifecycle-gated outside Pokemon Check and would
	# intentionally no-op in this isolated main-phase fixture.
	var rule_shroud: BaseEffect = FroslassShroudScript.new()
	var hold_shroud: BaseEffect = FroslassShroudScript.new()
	var rule_damaged: Array[PokemonSlot] = []
	var hold_damaged: Array[PokemonSlot] = []
	if rule_shroud != null:
		rule_shroud.call("process_pokemon_check", rule_froslass, rule_state, rule_damaged)
	if hold_shroud != null:
		hold_shroud.call("process_pokemon_check", held_froslass, hold_state, hold_damaged)
	_check(rule_shroud != null and hold_shroud != null
		and rule_fez.damage_counters == 30 and held_fez.damage_counters == 30
		and rule_raichu.damage_counters == 10 and held_raichu.damage_counters == 10
		and rule_froslass.damage_counters == 0 and held_froslass.damage_counters == 0
		and _damaged_instance_ids(rule_damaged) == _damaged_instance_ids(hold_damaged),
		"real Freezing Shroud must produce identical all-field check damage regardless of Fez/Raichu Active order")


func _test_fail_closed_boundaries(profile: Dictionary, manifest: Dictionary) -> void:
	var cases: Array[Dictionary] = [
		{"kind": "wrong_deck_id", "label": "deck identity changed"},
		{"kind": "wrong_deck_fingerprint", "label": "deck fingerprint changed"},
		{"kind": "wrong_seed", "label": "paired seed changed"},
		{"kind": "wrong_trace_version", "label": "captured observation version changed"},
		{"kind": "wrong_trace_hash", "label": "captured observation hash changed"},
		{"kind": "hash_reused", "label": "post-tool observation reused the old hash"},
		{"kind": "wrong_post_version", "label": "post-tool version did not advance one action"},
		{"kind": "wrong_turn", "label": "turn number changed"},
		{"kind": "wrong_current_player", "label": "current player changed"},
		{"kind": "wrong_viewer", "label": "viewer changed"},
		{"kind": "wrong_phase", "label": "decision moved outside MAIN"},
		{"kind": "opponent_hand_leak", "label": "opponent hidden hand leaked"},
		{"kind": "opponent_deck_leak", "label": "opponent hidden deck identities leaked"},
		{"kind": "opponent_prize_leak", "label": "opponent prize identities leaked"},
		{"kind": "own_prize_leak", "label": "own prize identities leaked"},
		{"kind": "belief_leak", "label": "hidden deck order belief injected"},
		{"kind": "first_event_kind", "label": "first gust result event kind changed"},
		{"kind": "first_event_failed", "label": "first gust result failed"},
		{"kind": "first_event_action", "label": "first gust action id changed"},
		{"kind": "first_event_instance", "label": "first gust instance changed"},
		{"kind": "first_event_target", "label": "first gust public target changed"},
		{"kind": "first_event_previous", "label": "pre-gust Active binding changed"},
		{"kind": "first_event_result", "label": "first gust resulting Active changed"},
		{"kind": "first_catcher_missing", "label": "first Catcher discard history missing"},
		{"kind": "first_catcher_uid", "label": "first Catcher UID changed"},
		{"kind": "first_catcher_effect", "label": "first Catcher effect changed"},
		{"kind": "second_rule_action", "label": "second Rule action id changed"},
		{"kind": "second_rule_candidate", "label": "second Rule candidate changed"},
		{"kind": "second_catcher_uid", "label": "second Catcher UID changed"},
		{"kind": "second_catcher_effect", "label": "second Catcher effect changed"},
		{"kind": "second_catcher_instance", "label": "second Catcher instance changed"},
		{"kind": "second_catcher_missing", "label": "held second Catcher missing"},
		{"kind": "second_catcher_duplicate", "label": "held second Catcher duplicated"},
		{"kind": "second_target_slot", "label": "second Rule target slot changed"},
		{"kind": "second_target_instance", "label": "second Rule target instance changed"},
		{"kind": "interaction_min", "label": "second gust min selection changed"},
		{"kind": "interaction_max", "label": "second gust max selection changed"},
		{"kind": "interaction_items", "label": "second gust public target list changed"},
		{"kind": "wrong_froslass_uid", "label": "Froslass UID changed"},
		{"kind": "wrong_froslass_effect", "label": "Froslass effect changed"},
		{"kind": "wrong_froslass_slot", "label": "Froslass instance/slot changed"},
		{"kind": "froslass_ability_missing", "label": "Freezing Shroud public ability missing"},
		{"kind": "froslass_energy_added", "label": "own Active unexpectedly became payable"},
		{"kind": "wrong_budew_uid", "label": "recovered Budew identity changed"},
		{"kind": "budew_ability_added", "label": "Budew unexpectedly entered Shroud target set"},
		{"kind": "wrong_fez_uid", "label": "first gust Fez UID changed"},
		{"kind": "wrong_fez_effect", "label": "first gust Fez effect changed"},
		{"kind": "wrong_fez_slot", "label": "first gust Fez instance changed"},
		{"kind": "fez_ability_missing", "label": "Fez public Ability missing"},
		{"kind": "fez_damage_changed", "label": "Fez captured damage changed"},
		{"kind": "wrong_raichu_uid", "label": "second target Raichu UID changed"},
		{"kind": "wrong_raichu_effect", "label": "second target Raichu effect changed"},
		{"kind": "wrong_raichu_slot", "label": "second target Raichu instance changed"},
		{"kind": "raichu_ability_added", "label": "Raichu unexpectedly entered Shroud target set"},
		{"kind": "raichu_damage_changed", "label": "Raichu captured damage changed"},
		{"kind": "opponent_energy_added", "label": "opponent target gained energy"},
		{"kind": "own_attack_added", "label": "own attack became legal"},
		{"kind": "own_ko_added", "label": "own deterministic KO became available"},
		{"kind": "win_now_added", "label": "a game-winning line appeared"},
		{"kind": "prize_swing_added", "label": "current prize swing changed"},
		{"kind": "gust_prize_reward", "label": "second gust gained immediate prizes"},
		{"kind": "gust_damage_reward", "label": "second gust gained immediate damage"},
		{"kind": "gust_attack_reward", "label": "second gust changed attack readiness"},
		{"kind": "gust_active_payoff", "label": "an Active-dependent payoff appeared"},
		{"kind": "gust_check_delta", "label": "second gust changed Shroud check damage"},
		{"kind": "tool_action", "label": "same subsequent tool action id changed"},
		{"kind": "tool_candidate", "label": "same subsequent tool candidate changed"},
		{"kind": "tool_uid", "label": "same subsequent tool UID changed"},
		{"kind": "tool_effect", "label": "same subsequent tool effect changed"},
		{"kind": "tool_instance", "label": "same subsequent tool instance changed"},
		{"kind": "tool_target", "label": "same subsequent tool target changed"},
		{"kind": "tool_missing", "label": "same subsequent tool action missing"},
		{"kind": "post_event_failed", "label": "tool action_result failed"},
		{"kind": "post_event_action", "label": "tool action_result acknowledged another action"},
		{"kind": "post_catcher_consumed", "label": "held Catcher disappeared after tool"},
		{"kind": "post_tool_missing", "label": "TM was not attached after action_result"},
		{"kind": "post_opponent_changed", "label": "opponent board changed during own tool attachment"},
		{"kind": "post_deck_changed", "label": "tool attachment changed own deck count"},
		{"kind": "post_hand_changed", "label": "tool attachment changed wrong hand count"},
		{"kind": "post_turn_changed", "label": "continuation crossed turn before end"},
		{"kind": "end_missing", "label": "same subsequent end action missing"},
		{"kind": "end_action", "label": "same subsequent end action id changed"},
		{"kind": "end_candidate", "label": "same subsequent end candidate changed"},
	]
	for spec: Dictionary in cases:
		var mutated_sequence := _base_sequence()
		_apply_public_mutation(mutated_sequence, str(spec.get("kind", "")))
		var shape := _validate_public_sequence_shape(mutated_sequence)
		_check(not bool(shape.get("valid", false)),
			"%s must be independently rejected by the public fixture guard" % str(spec.get("label", "invalid boundary")))
		var result := _sequence_contract(mutated_sequence, profile, manifest)
		_check(not bool(result.get("accepted", false)),
			"%s must fail closed through production entry" % str(spec.get("label", "invalid boundary")))
		_negative_count += 1

	for spec: Dictionary in [
		{"kind": "profile_fingerprint", "label": "profile fingerprint changed"},
		{"kind": "module_composition", "label": "module composition changed"},
		{"kind": "manifest_fingerprint", "label": "manifest fingerprint changed"},
		{"kind": "manifest_catcher_effect", "label": "manifest Catcher effect changed"},
		{"kind": "manifest_froslass_effect", "label": "manifest Froslass effect changed"},
	]:
		var mutated_profile := profile.duplicate(true)
		var mutated_manifest := manifest.duplicate(true)
		_apply_configuration_mutation(mutated_profile, mutated_manifest, str(spec.get("kind", "")))
		var result := _sequence_contract(_base_sequence(), mutated_profile, mutated_manifest)
		_check(not bool(result.get("accepted", false)),
			"%s must fail closed" % str(spec.get("label", "invalid configuration")))
		_negative_count += 1


func _validate_public_sequence_shape(sequence: Array[Dictionary]) -> Dictionary:
	if sequence.size() != 2:
		return _invalid("observation_epoch_count")
	var root := sequence[0]
	var post := sequence[1]
	for observation: Dictionary in sequence:
		if _contains_hidden_information(observation):
			return _invalid("hidden_information_present")
		var provenance: Dictionary = observation.get("provenance", {}) \
			if observation.get("provenance", {}) is Dictionary else {}
		if int(provenance.get("deck_id", 0)) != DECK_ID \
				or int(provenance.get("seed", 0)) != TRACE_SEED \
				or str(provenance.get("deck_content_fingerprint", "")) != EXPECTED_DECK_FINGERPRINT:
			return _invalid("trace_provenance")
		var turn: Dictionary = observation.get("turn", {}) \
			if observation.get("turn", {}) is Dictionary else {}
		if int(turn.get("number", -1)) != TRACE_TURN \
				or int(turn.get("current_player", -1)) != 0 \
				or int(turn.get("viewer", -1)) != 0 \
				or int(turn.get("phase", -1)) != int(GameState.GamePhase.MAIN):
			return _invalid("turn_identity")
		var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
		var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
		if int(own.get("prizes_remaining", -1)) != 6 \
				or int(opponent.get("prizes_remaining", -1)) != 5:
			return _invalid("counter_catcher_prize_gate")
		if int(own.get("deck_count", -1)) != 43 \
				or int(opponent.get("deck_count", -1)) != 42 \
				or int(opponent.get("hand_count", -1)) != 5:
			return _invalid("public_zone_counts")
		if not _own_attackless_froslass_board(own):
			return _invalid("own_attackless_froslass_board")
		if not _post_first_gust_opponent_board(opponent):
			return _invalid("post_first_gust_opponent_board")
		if _actions_of_kind(observation, "attack").size() != 0:
			return _invalid("legal_attack_present")
		if not _zero_gust_reward(observation.get("public_outcome", {})):
			return _invalid("nonzero_gust_reward")
		if not _froslass_passive_contract(observation.get("public_passive", {})):
			return _invalid("froslass_passive_scope")

	if int(root.get("observation_version", -1)) != TRACE_OBSERVATION_VERSION \
			or str(root.get("observation_hash", "")) != TRACE_OBSERVATION_HASH:
		return _invalid("captured_o17_identity")
	if int(post.get("observation_version", -1)) != POST_TOOL_OBSERVATION_VERSION \
			or int(post.get("observation_version", -1)) != int(root.get("observation_version", -1)) + 2 \
			or str(post.get("observation_hash", "")) != POST_TOOL_OBSERVATION_HASH \
			or str(post.get("observation_hash", "")) == str(root.get("observation_hash", "")):
		return _invalid("single_action_reobserve_identity")
	if not _first_gust_result_event(root.get("event", {})):
		return _invalid("first_gust_result_event")
	if not _event_matches(post, TOOL_ACTION_ID):
		return _invalid("tool_action_resolved_event")

	var root_own: Dictionary = root.get("own", {})
	var post_own: Dictionary = post.get("own", {})
	if int(root_own.get("hand_count", -1)) != 3 or int(post_own.get("hand_count", -1)) != 2:
		return _invalid("public_hand_count_transition")
	if _count_card(root_own.get("hand", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) != 1 \
			or _count_card(post_own.get("hand", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) != 1:
		return _invalid("held_second_counter_catcher")
	if _count_card(root_own.get("hand", []), TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, TM_DEVOLUTION_INSTANCE) != 1 \
			or _count_card(post_own.get("hand", []), TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, TM_DEVOLUTION_INSTANCE) != 0:
		return _invalid("tool_hand_transition")
	if _count_card(root_own.get("discard", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, FIRST_COUNTER_CATCHER_INSTANCE) != 1 \
			or _count_card(post_own.get("discard", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, FIRST_COUNTER_CATCHER_INSTANCE) != 1 \
			or _count_card(post_own.get("discard", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) != 0:
		return _invalid("counter_catcher_history")
	if not _root_own_board(root_own) or not _post_tool_own_board(post_own):
		return _invalid("own_tool_transition")
	if not _same_public_board(root.get("opponent", {}), post.get("opponent", {})):
		return _invalid("opponent_changed_during_tool")

	var root_rule_gust := _action_by_id(root, RULE_SECOND_GUST_ACTION_ID)
	var post_rule_gust := _action_by_id(post, RULE_SECOND_GUST_ACTION_ID)
	if not _exact_second_catcher_action(root_rule_gust) \
			or not _exact_second_catcher_action(post_rule_gust):
		return _invalid("exact_second_catcher_rule_action")
	var tool := _action_by_id(root, TOOL_ACTION_ID)
	if not _exact_tool_action(tool):
		return _invalid("exact_same_tool_action")
	var end_turn := _action_by_id(post, END_ACTION_ID)
	if end_turn.is_empty() \
			or str(end_turn.get("kind", "")) != "end_turn" \
			or str(end_turn.get("candidate_id", "")) != END_CANDIDATE_ID:
		return _invalid("exact_same_end_action")
	return {"valid": true, "reason": ""}


func _frontier(
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	manifest: Dictionary,
	post_tool: bool
) -> Array[Dictionary]:
	var gust := {
		"candidate_id": RULE_SECOND_GUST_CANDIDATE_ID,
		"route_id": "route:gust",
		"action_kind": "play_trainer",
		"safe_prefix_action_id": RULE_SECOND_GUST_ACTION_ID,
		"base_score": RULE_SECOND_GUST_SCORE,
		"local_score": RULE_SECOND_GUST_SCORE,
		"checkpoint_after": "action_resolved",
		"engine_rule_floor_exact": true,
		"rule_floor_exact": true,
		"action_semantic_roles": ["item", "gust"],
		"action_ref": _action_by_id(observation, RULE_SECOND_GUST_ACTION_ID),
		"outcome": {"future_flexibility": 0.3, "resource_commitment": 0.35, "uncertainty": 0.0},
	}
	var candidates: Array[Dictionary] = [gust]
	if not post_tool:
		candidates.append({
			"candidate_id": TOOL_CANDIDATE_ID,
			"route_id": "route:develop",
			"action_kind": "attach_tool",
			"safe_prefix_action_id": TOOL_ACTION_ID,
			"base_score": TOOL_SCORE,
			"local_score": TOOL_SCORE,
			"checkpoint_after": "action_resolved",
			"action_ref": _action_by_id(observation, TOOL_ACTION_ID),
			"outcome": {"board_development": 1.0, "board_commitment": 0.55, "future_flexibility": 0.3, "resource_commitment": 0.0, "uncertainty": 0.0},
		})
	candidates.append({
		"candidate_id": END_CANDIDATE_ID,
		"route_id": "route:end_turn",
		"action_kind": "end_turn",
		"safe_prefix_action_id": END_ACTION_ID,
		"base_score": END_SCORE,
		"local_score": END_SCORE,
		"checkpoint_after": "terminal",
		"action_ref": _action_by_id(observation, END_ACTION_ID),
		"outcome": {"future_flexibility": 1.0, "resource_commitment": 0.0, "terminal": true, "uncertainty": 0.0},
	})
	return CapabilityRegistryScript.new().annotate_frontier(
		candidates, observation, facts, profile, manifest
	)


func _facts_for(observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {})
	var opponent: Dictionary = observation.get("opponent", {})
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"board": {
			"own_active_remaining_hp": int(own.get("active", {}).get("remaining_hp", 0)),
			"opponent_active_remaining_hp": int(opponent.get("active", {}).get("remaining_hp", 0)),
			"bench_full": false,
			"has_tera": false,
		},
		"resources": {
			"prizes_remaining": int(own.get("prizes_remaining", 0)),
			"hand_size": int(own.get("hand_count", 0)),
			"deck_low": false,
			"deck_critical": false,
			"energy_on_board": 0,
			"distinct_energy_symbols": 0,
			"bench_slots_free": 4,
		},
		"turn": {
			"energy_available": bool(observation.get("turn", {}).get("quotas", {}).get("energy_available", false)),
			"supporter_available": bool(observation.get("turn", {}).get("quotas", {}).get("supporter_available", false)),
			"retreat_available": bool(observation.get("turn", {}).get("quotas", {}).get("retreat_available", false)),
		},
		"prize": {"win_now": false, "current_swing": 0},
		"route": {"current_valid": true},
		"control": {
			"first_gust_resolved": true,
			"second_gust_immediate_reward": 0,
			"froslass_passive_position_independent": true,
			"held_counter_catcher_instance_id": SECOND_COUNTER_CATCHER_INSTANCE,
		},
		"belief": {"known_in_deck_uid_counts": {}, "evidence_kind": "public_only"},
	}


func _two_epoch_policy() -> Dictionary:
	return {
		"root_node_id": "node:hold-second-catcher-attach-tool",
		"nodes": [{
			"node_id": "node:hold-second-catcher-attach-tool",
			"kind": "route",
			"route_ref": {
				"mode": "select_candidate",
				"route_id": "route:develop",
				"candidate_id": TOOL_CANDIDATE_ID,
			},
			"next_node_id": "node:after-tool-reobserve",
		}, {
			"node_id": "node:after-tool-reobserve",
			"kind": "checkpoint",
			"branches": [{
				"when_all": [{"fact": "attack.ready", "op": "==", "value": false}],
				"next_node_id": "node:end-with-catcher-held",
			}],
			"otherwise": "replan",
		}, {
			"node_id": "node:end-with-catcher-held",
			"kind": "route",
			"route_ref": {"mode": "follow_route", "route_id": "route:end_turn"},
		}],
		"reservations": [{
			"resource": "card_instance:%d" % SECOND_COUNTER_CATCHER_INSTANCE,
			"count": 1,
			"until": "turn_end",
		}],
		"interaction_policy_refs": {},
		"interaction_policies": [],
		"replan_if": ["no_branch_matches", "current_route_invalid", "protected_resource_changed"],
	}


func _base_sequence() -> Array[Dictionary]:
	var root := _observation_shell(TRACE_OBSERVATION_VERSION, TRACE_OBSERVATION_HASH)
	root["event"] = {
		"kind": "action_resolved",
		"success": true,
		"action_id": FIRST_GUST_ACTION_ID,
		"candidate_id": FIRST_GUST_CANDIDATE_ID,
		"card_instance_id": FIRST_COUNTER_CATCHER_INSTANCE,
		"target_slot_id": FEZANDIPITI_SLOT,
		"target_instance_id": 51,
		"previous_active_slot_id": RAICHU_SLOT,
		"result_active_slot_id": FEZANDIPITI_SLOT,
	}
	root["own"]["active"] = _froslass_slot(false)
	root["own"]["bench"] = [_budew_slot()]
	root["own"]["hand"] = _root_hand()
	root["own"]["discard"] = _exact_discard()
	root["opponent"]["active"] = _fezandipiti_slot()
	root["opponent"]["bench"] = [_raichu_slot()]
	root["legal_actions"] = [
		_second_catcher_action(),
		_tool_action(),
		{"id": END_ACTION_ID, "candidate_id": END_CANDIDATE_ID, "kind": "end_turn"},
	]

	var post := _observation_shell(POST_TOOL_OBSERVATION_VERSION, POST_TOOL_OBSERVATION_HASH)
	post["event"] = {"kind": "action_resolved", "success": true, "action_id": TOOL_ACTION_ID}
	post["own"]["active"] = _froslass_slot(true)
	post["own"]["bench"] = [_budew_slot()]
	post["own"]["hand_count"] = 2
	post["own"]["hand"] = _post_tool_hand()
	post["own"]["discard"] = _exact_discard()
	post["opponent"] = root["opponent"].duplicate(true)
	post["legal_actions"] = [
		_second_catcher_action(),
		{"id": END_ACTION_ID, "candidate_id": END_CANDIDATE_ID, "kind": "end_turn"},
	]
	return [root, post]


func _observation_shell(version: int, hash_value: String) -> Dictionary:
	return {
		"schema_version": "v18cpg-2",
		"observation_version": version,
		"observation_hash": hash_value,
		"provenance": {
			"deck_id": DECK_ID,
			"seed": TRACE_SEED,
			"deck_content_fingerprint": EXPECTED_DECK_FINGERPRINT,
			"source": "opt21_800017631_round00_current_verified_local:800017631_5:t5:o17",
		},
		"turn": {
			"number": TRACE_TURN,
			"current_player": 0,
			"first_player": 0,
			"viewer": 0,
			"phase": int(GameState.GamePhase.MAIN),
			"quotas": {
				"energy_available": true,
				"retreat_available": true,
				"stadium_available": true,
				"supporter_available": true,
				"vstar_available": true,
			},
		},
		"visibility": {
			"deck_order_visible": false,
			"decklist_visibility": "observed_only",
			"opponent_hand_contents": false,
			"own_prize_identities": false,
		},
		"stadium": {},
		"own": {
			"prizes_remaining": 6,
			"deck_count": 43,
			"hand_count": 3,
			"hand": [],
			"discard": [],
			"active": {},
			"bench": [],
		},
		"opponent": {
			"prizes_remaining": 5,
			"deck_count": 42,
			"hand_count": 5,
			"active": {},
			"bench": [],
		},
		"public_outcome": {
			"attack_ready": false,
			"own_ko_available": false,
			"win_now": false,
			"current_prize_swing": 0,
			"gust_immediate_prizes": 0,
			"gust_immediate_damage": 0,
			"gust_changes_attack_readiness": false,
			"gust_active_dependent_payoff": false,
			"gust_check_damage_delta": 0,
		},
		"public_passive": {
			"source_uid": FROSLASS_UID,
			"source_effect_id": FROSLASS_EFFECT_ID,
			"scope": "both_fields_all_pokemon",
			"requires_ability": true,
			"position_independent": true,
			"damage_per_source": 10,
			"excluded_uid": FROSLASS_UID,
		},
		"legal_actions": [],
	}


func _second_catcher_action() -> Dictionary:
	return {
		"id": RULE_SECOND_GUST_ACTION_ID,
		"candidate_id": RULE_SECOND_GUST_CANDIDATE_ID,
		"kind": "play_trainer",
		"route_id": "route:gust",
		"card_instance_id": SECOND_COUNTER_CATCHER_INSTANCE,
		"card": _card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE),
		"interaction_steps": [{
			"id": "opponent_bench_target",
			"min_select": 1,
			"max_select": 1,
			"public_items": [RAICHU_SLOT],
		}],
		"rule_selected_target_slot_id": RAICHU_SLOT,
		"rule_selected_target_instance_id": 34,
		"projected_prizes": 0,
		"projected_damage": 0,
		"changes_attack_readiness": false,
		"active_dependent_payoff": false,
		"check_damage_delta": 0,
	}


func _tool_action() -> Dictionary:
	return {
		"id": TOOL_ACTION_ID,
		"candidate_id": TOOL_CANDIDATE_ID,
		"kind": "attach_tool",
		"route_id": "route:develop",
		"card_instance_id": TM_DEVOLUTION_INSTANCE,
		"card": _card(TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, "Tool", TM_DEVOLUTION_INSTANCE),
		"target": FROSLASS_SLOT,
		"target_instance_id": 10,
	}


func _root_hand() -> Array:
	return [
		_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE),
		_card(TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, "Tool", TM_DEVOLUTION_INSTANCE),
		_card(LUMINOUS_UID, LUMINOUS_EFFECT_ID, "Special Energy", LUMINOUS_INSTANCE),
	]


func _post_tool_hand() -> Array:
	return [
		_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE),
		_card(LUMINOUS_UID, LUMINOUS_EFFECT_ID, "Special Energy", LUMINOUS_INSTANCE),
	]


func _exact_discard() -> Array:
	return [
		_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", FIRST_COUNTER_CATCHER_INSTANCE),
		_card(NIGHT_STRETCHER_UID, NIGHT_STRETCHER_EFFECT_ID, "Item", NIGHT_STRETCHER_INSTANCE),
	]


func _froslass_slot(tool_attached: bool) -> Dictionary:
	return _slot(
		FROSLASS_SLOT,
		_card(FROSLASS_UID, FROSLASS_EFFECT_ID, "Pokemon", 10,
			[{"cost": "WC", "damage": 60}],
			[{"effect_id": FROSLASS_EFFECT_ID, "position_independent": true}]),
		[],
		_card(TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, "Tool", TM_DEVOLUTION_INSTANCE) if tool_attached else {},
		90, 1, 1, 0
	)


func _budew_slot() -> Dictionary:
	return _slot(
		BUDEW_SLOT,
		_card(BUDEW_UID, BUDEW_EFFECT_ID, "Pokemon", 11, [{"cost": "0", "damage": 10}], []),
		[], {}, 30, 1, 0, 0
	)


func _fezandipiti_slot() -> Dictionary:
	return _slot(
		FEZANDIPITI_SLOT,
		_card(FEZANDIPITI_UID, FEZANDIPITI_EFFECT_ID, "Pokemon", 51,
			[{"cost": "CCC", "damage": 100}],
			[{"effect_id": FEZANDIPITI_EFFECT_ID}]),
		[], {}, 190, 2, 1, 20
	)


func _raichu_slot() -> Dictionary:
	return _slot(
		RAICHU_SLOT,
		_card(RAICHU_UID, RAICHU_EFFECT_ID, "Pokemon", 34,
			[{"cost": "L", "damage": 0}, {"cost": "LL", "damage": 60}], []),
		[], {}, 190, 2, 1, 10
	)


func _slot(
	slot_id: String,
	pokemon: Dictionary,
	energy: Array,
	tool: Dictionary,
	remaining_hp: int,
	prize_count: int,
	retreat_cost: int,
	damage: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": pokemon,
		"energy": energy,
		"energy_count": energy.size(),
		"tool": tool,
		"remaining_hp": remaining_hp,
		"damage": damage,
		"prize_count": prize_count,
		"printed_retreat_cost": retreat_cost,
		"effective_retreat_cost": retreat_cost,
		"ability_used": false,
		"tera": false,
	}


func _card(
	uid: String,
	effect_id: String,
	type_name: String,
	instance_id: int = -1,
	attacks: Array = [],
	abilities: Array = []
) -> Dictionary:
	var result := {"uid": uid, "effect_id": effect_id, "type": type_name}
	if instance_id >= 0:
		result["instance_id"] = instance_id
	if not attacks.is_empty():
		result["attacks"] = attacks.duplicate(true)
	result["abilities"] = abilities.duplicate(true)
	return result


func _root_own_board(own: Dictionary) -> bool:
	var active: Dictionary = own.get("active", {})
	return _slot_card_matches(active, FROSLASS_SLOT, 10, FROSLASS_UID, FROSLASS_EFFECT_ID) \
		and _has_exact_ability(active, FROSLASS_EFFECT_ID) \
		and active.get("energy", []).is_empty() \
		and (active.get("tool", {}) as Dictionary).is_empty() \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), BUDEW_SLOT), BUDEW_SLOT, 11, BUDEW_UID, BUDEW_EFFECT_ID) \
		and not _slot_has_any_ability(_slot_by_id(own.get("bench", []), BUDEW_SLOT))


func _post_tool_own_board(own: Dictionary) -> bool:
	var active: Dictionary = own.get("active", {})
	return _slot_card_matches(active, FROSLASS_SLOT, 10, FROSLASS_UID, FROSLASS_EFFECT_ID) \
		and _has_exact_ability(active, FROSLASS_EFFECT_ID) \
		and active.get("energy", []).is_empty() \
		and _card_matches(active.get("tool", {}), TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, TM_DEVOLUTION_INSTANCE) \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), BUDEW_SLOT), BUDEW_SLOT, 11, BUDEW_UID, BUDEW_EFFECT_ID) \
		and not _slot_has_any_ability(_slot_by_id(own.get("bench", []), BUDEW_SLOT))


func _own_attackless_froslass_board(own: Dictionary) -> bool:
	var active: Dictionary = own.get("active", {})
	var pokemon: Dictionary = active.get("pokemon", {}) if active.get("pokemon", {}) is Dictionary else {}
	return _slot_card_matches(active, FROSLASS_SLOT, 10, FROSLASS_UID, FROSLASS_EFFECT_ID) \
		and _attacks_match(pokemon.get("attacks", []), ["WC"]) \
		and active.get("energy", []).is_empty() \
		and not _any_attack_payable(pokemon.get("attacks", []), active.get("energy", []))


func _post_first_gust_opponent_board(opponent: Dictionary) -> bool:
	var active: Dictionary = opponent.get("active", {})
	var raichu := _slot_by_id(opponent.get("bench", []), RAICHU_SLOT)
	return _slot_card_matches(active, FEZANDIPITI_SLOT, 51, FEZANDIPITI_UID, FEZANDIPITI_EFFECT_ID) \
		and int(active.get("remaining_hp", 0)) == 190 \
		and int(active.get("damage", -1)) == 20 \
		and int(active.get("prize_count", 0)) == 2 \
		and active.get("energy", []).is_empty() \
		and _has_exact_ability(active, FEZANDIPITI_EFFECT_ID) \
		and _slot_card_matches(raichu, RAICHU_SLOT, 34, RAICHU_UID, RAICHU_EFFECT_ID) \
		and int(raichu.get("remaining_hp", 0)) == 190 \
		and int(raichu.get("damage", -1)) == 10 \
		and int(raichu.get("prize_count", 0)) == 2 \
		and raichu.get("energy", []).is_empty() \
		and not _slot_has_any_ability(raichu) \
		and (opponent.get("bench", []) as Array).size() == 1


func _zero_gust_reward(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var outcome: Dictionary = value as Dictionary
	return not bool(outcome.get("attack_ready", true)) \
		and not bool(outcome.get("own_ko_available", true)) \
		and not bool(outcome.get("win_now", true)) \
		and int(outcome.get("current_prize_swing", -1)) == 0 \
		and int(outcome.get("gust_immediate_prizes", -1)) == 0 \
		and int(outcome.get("gust_immediate_damage", -1)) == 0 \
		and not bool(outcome.get("gust_changes_attack_readiness", true)) \
		and not bool(outcome.get("gust_active_dependent_payoff", true)) \
		and int(outcome.get("gust_check_damage_delta", -1)) == 0


func _froslass_passive_contract(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var passive: Dictionary = value as Dictionary
	return str(passive.get("source_uid", "")) == FROSLASS_UID \
		and str(passive.get("source_effect_id", "")) == FROSLASS_EFFECT_ID \
		and str(passive.get("scope", "")) == "both_fields_all_pokemon" \
		and bool(passive.get("requires_ability", false)) \
		and bool(passive.get("position_independent", false)) \
		and int(passive.get("damage_per_source", 0)) == 10 \
		and str(passive.get("excluded_uid", "")) == FROSLASS_UID


func _first_gust_result_event(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var event: Dictionary = value as Dictionary
	return str(event.get("kind", "")) == "action_resolved" \
		and bool(event.get("success", false)) \
		and str(event.get("action_id", "")) == FIRST_GUST_ACTION_ID \
		and str(event.get("candidate_id", "")) == FIRST_GUST_CANDIDATE_ID \
		and int(event.get("card_instance_id", -1)) == FIRST_COUNTER_CATCHER_INSTANCE \
		and str(event.get("target_slot_id", "")) == FEZANDIPITI_SLOT \
		and int(event.get("target_instance_id", -1)) == 51 \
		and str(event.get("previous_active_slot_id", "")) == RAICHU_SLOT \
		and str(event.get("result_active_slot_id", "")) == FEZANDIPITI_SLOT


func _exact_second_catcher_action(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	var card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	var steps: Array = action.get("interaction_steps", []) if action.get("interaction_steps", []) is Array else []
	if steps.size() != 1 or not (steps[0] is Dictionary):
		return false
	var step: Dictionary = steps[0]
	return str(action.get("candidate_id", "")) == RULE_SECOND_GUST_CANDIDATE_ID \
		and str(action.get("kind", "")) == "play_trainer" \
		and int(action.get("card_instance_id", -1)) == SECOND_COUNTER_CATCHER_INSTANCE \
		and _card_matches(card, COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) \
		and str(step.get("id", "")) == "opponent_bench_target" \
		and int(step.get("min_select", -1)) == 1 \
		and int(step.get("max_select", -1)) == 1 \
		and (step.get("public_items", []) as Array) == [RAICHU_SLOT] \
		and str(action.get("rule_selected_target_slot_id", "")) == RAICHU_SLOT \
		and int(action.get("rule_selected_target_instance_id", -1)) == 34 \
		and int(action.get("projected_prizes", -1)) == 0 \
		and int(action.get("projected_damage", -1)) == 0 \
		and not bool(action.get("changes_attack_readiness", true)) \
		and not bool(action.get("active_dependent_payoff", true)) \
		and int(action.get("check_damage_delta", -1)) == 0


func _exact_tool_action(action: Dictionary) -> bool:
	var card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	return not action.is_empty() \
		and str(action.get("candidate_id", "")) == TOOL_CANDIDATE_ID \
		and str(action.get("kind", "")) == "attach_tool" \
		and int(action.get("card_instance_id", -1)) == TM_DEVOLUTION_INSTANCE \
		and _card_matches(card, TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, TM_DEVOLUTION_INSTANCE) \
		and str(action.get("target", "")) == FROSLASS_SLOT \
		and int(action.get("target_instance_id", -1)) == 10


func _manifest_contract(manifest: Dictionary) -> bool:
	if int(manifest.get("deck_id", 0)) != DECK_ID \
			or str(manifest.get("deck_content_fingerprint", "")) != EXPECTED_DECK_FINGERPRINT:
		return false
	var expected := {
		COUNTER_CATCHER_UID: COUNTER_CATCHER_EFFECT_ID,
		FROSLASS_UID: FROSLASS_EFFECT_ID,
		BUDEW_UID: BUDEW_EFFECT_ID,
		TM_DEVOLUTION_UID: TM_DEVOLUTION_EFFECT_ID,
		LUMINOUS_UID: LUMINOUS_EFFECT_ID,
		NIGHT_STRETCHER_UID: NIGHT_STRETCHER_EFFECT_ID,
	}
	for uid: String in expected:
		var found := false
		for raw_card: Variant in manifest.get("cards", []):
			if raw_card is Dictionary \
					and str((raw_card as Dictionary).get("uid", "")).to_upper() == uid.to_upper() \
					and str((raw_card as Dictionary).get("effect_id", "")).to_lower() == str(expected[uid]).to_lower():
				found = true
				break
		if not found:
			return false
	return true


func _apply_public_mutation(sequence: Array[Dictionary], kind: String) -> void:
	var root := sequence[0]
	var post := sequence[1]
	match kind:
		"wrong_deck_id": root["provenance"]["deck_id"] = DECK_ID + 1
		"wrong_deck_fingerprint": root["provenance"]["deck_content_fingerprint"] = "wrong"
		"wrong_seed": root["provenance"]["seed"] = TRACE_SEED + 1
		"wrong_trace_version": root["observation_version"] = TRACE_OBSERVATION_VERSION + 1
		"wrong_trace_hash": root["observation_hash"] = "wrong"
		"hash_reused": post["observation_hash"] = TRACE_OBSERVATION_HASH
		"wrong_post_version": post["observation_version"] = TRACE_OBSERVATION_VERSION + 1
		"wrong_turn": post["turn"]["number"] = TRACE_TURN + 1
		"wrong_current_player": root["turn"]["current_player"] = 1
		"wrong_viewer": root["turn"]["viewer"] = 1
		"wrong_phase": root["turn"]["phase"] = int(GameState.GamePhase.ATTACK)
		"opponent_hand_leak": post["opponent"]["hand"] = [_card("hidden", "hidden", "Item")]
		"opponent_deck_leak": post["opponent"]["deck_cards"] = [_card("hidden", "hidden", "Item")]
		"opponent_prize_leak": post["opponent"]["prize_cards"] = [_card("hidden", "hidden", "Item")]
		"own_prize_leak": post["own"]["prize_cards"] = [_card("hidden", "hidden", "Item")]
		"belief_leak": post["belief"] = {"deck_order": [COUNTER_CATCHER_UID]}
		"first_event_kind": root["event"]["kind"] = "decision_window_open"
		"first_event_failed": root["event"]["success"] = false
		"first_event_action": root["event"]["action_id"] = "action:wrong"
		"first_event_instance": root["event"]["card_instance_id"] = 37
		"first_event_target": root["event"]["target_slot_id"] = RAICHU_SLOT
		"first_event_previous": root["event"]["previous_active_slot_id"] = FEZANDIPITI_SLOT
		"first_event_result": root["event"]["result_active_slot_id"] = RAICHU_SLOT
		"first_catcher_missing": root["own"]["discard"].remove_at(0)
		"first_catcher_uid": root["own"]["discard"][0]["uid"] = "wrong"
		"first_catcher_effect": root["own"]["discard"][0]["effect_id"] = "wrong"
		"second_rule_action": root["legal_actions"][0]["id"] = "action:wrong"
		"second_rule_candidate": root["legal_actions"][0]["candidate_id"] = "candidate:wrong"
		"second_catcher_uid": root["legal_actions"][0]["card"]["uid"] = "wrong"
		"second_catcher_effect": root["legal_actions"][0]["card"]["effect_id"] = "wrong"
		"second_catcher_instance": root["legal_actions"][0]["card_instance_id"] = 37
		"second_catcher_missing": root["own"]["hand"].remove_at(0)
		"second_catcher_duplicate": root["own"]["hand"].append(_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE))
		"second_target_slot": root["legal_actions"][0]["rule_selected_target_slot_id"] = FEZANDIPITI_SLOT
		"second_target_instance": root["legal_actions"][0]["rule_selected_target_instance_id"] = 51
		"interaction_min": root["legal_actions"][0]["interaction_steps"][0]["min_select"] = 0
		"interaction_max": root["legal_actions"][0]["interaction_steps"][0]["max_select"] = 2
		"interaction_items": root["legal_actions"][0]["interaction_steps"][0]["public_items"] = [FEZANDIPITI_SLOT]
		"wrong_froslass_uid": root["own"]["active"]["pokemon"]["uid"] = "wrong"
		"wrong_froslass_effect": root["own"]["active"]["pokemon"]["effect_id"] = "wrong"
		"wrong_froslass_slot": root["own"]["active"]["slot_id"] = "slot:12"
		"froslass_ability_missing": root["own"]["active"]["pokemon"]["abilities"].clear()
		"froslass_energy_added": root["own"]["active"]["energy"] = [_card(LUMINOUS_UID, LUMINOUS_EFFECT_ID, "Special Energy", LUMINOUS_INSTANCE)]
		"wrong_budew_uid": root["own"]["bench"][0]["pokemon"]["uid"] = "wrong"
		"budew_ability_added": root["own"]["bench"][0]["pokemon"]["abilities"] = [{"effect_id": "fixture:ability"}]
		"wrong_fez_uid": root["opponent"]["active"]["pokemon"]["uid"] = "wrong"
		"wrong_fez_effect": root["opponent"]["active"]["pokemon"]["effect_id"] = "wrong"
		"wrong_fez_slot": root["opponent"]["active"]["slot_id"] = "slot:52"
		"fez_ability_missing": root["opponent"]["active"]["pokemon"]["abilities"].clear()
		"fez_damage_changed": root["opponent"]["active"]["damage"] = 10
		"wrong_raichu_uid": root["opponent"]["bench"][0]["pokemon"]["uid"] = "wrong"
		"wrong_raichu_effect": root["opponent"]["bench"][0]["pokemon"]["effect_id"] = "wrong"
		"wrong_raichu_slot": root["opponent"]["bench"][0]["slot_id"] = "slot:33"
		"raichu_ability_added": root["opponent"]["bench"][0]["pokemon"]["abilities"] = [{"effect_id": "fixture:ability"}]
		"raichu_damage_changed": root["opponent"]["bench"][0]["damage"] = 20
		"opponent_energy_added": root["opponent"]["active"]["energy"] = [_card(LUMINOUS_UID, LUMINOUS_EFFECT_ID, "Special Energy", 99)]
		"own_attack_added": root["legal_actions"].append({"id": "action:attack", "kind": "attack"})
		"own_ko_added": root["public_outcome"]["own_ko_available"] = true
		"win_now_added": root["public_outcome"]["win_now"] = true
		"prize_swing_added": root["public_outcome"]["current_prize_swing"] = 2
		"gust_prize_reward": root["public_outcome"]["gust_immediate_prizes"] = 2
		"gust_damage_reward": root["public_outcome"]["gust_immediate_damage"] = 10
		"gust_attack_reward": root["public_outcome"]["gust_changes_attack_readiness"] = true
		"gust_active_payoff": root["public_outcome"]["gust_active_dependent_payoff"] = true
		"gust_check_delta": root["public_outcome"]["gust_check_damage_delta"] = 10
		"tool_action": root["legal_actions"][1]["id"] = "action:wrong"
		"tool_candidate": root["legal_actions"][1]["candidate_id"] = "candidate:wrong"
		"tool_uid": root["legal_actions"][1]["card"]["uid"] = "wrong"
		"tool_effect": root["legal_actions"][1]["card"]["effect_id"] = "wrong"
		"tool_instance": root["legal_actions"][1]["card_instance_id"] = 46
		"tool_target": root["legal_actions"][1]["target"] = BUDEW_SLOT
		"tool_missing": root["legal_actions"].remove_at(1)
		"post_event_failed": post["event"]["success"] = false
		"post_event_action": post["event"]["action_id"] = "action:wrong"
		"post_catcher_consumed": post["own"]["hand"].remove_at(0)
		"post_tool_missing": post["own"]["active"]["tool"] = {}
		"post_opponent_changed": post["opponent"]["active"] = post["opponent"]["bench"][0]
		"post_deck_changed": post["own"]["deck_count"] = 42
		"post_hand_changed": post["own"]["hand_count"] = 1
		"post_turn_changed": post["turn"]["number"] = TRACE_TURN + 1
		"end_missing": post["legal_actions"].remove_at(1)
		"end_action": post["legal_actions"][1]["id"] = "action:wrong"
		"end_candidate": post["legal_actions"][1]["candidate_id"] = "candidate:wrong"


func _apply_configuration_mutation(profile: Dictionary, manifest: Dictionary, kind: String) -> void:
	match kind:
		"profile_fingerprint": profile["expected_regret_threshold"] = float(profile.get("expected_regret_threshold", 0.0)) + 1.0
		"module_composition": profile["modules"] = ["damage_counter_control"]
		"manifest_fingerprint": manifest["deck_content_fingerprint"] = "wrong"
		"manifest_catcher_effect": _mutate_manifest_effect(manifest, COUNTER_CATCHER_UID)
		"manifest_froslass_effect": _mutate_manifest_effect(manifest, FROSLASS_UID)


func _mutate_manifest_effect(manifest: Dictionary, uid: String) -> void:
	for raw_card: Variant in manifest.get("cards", []):
		if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == uid:
			(raw_card as Dictionary)["effect_id"] = "wrong"
			return


func _engine_fixture() -> Dictionary:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = TRACE_TURN
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	var own: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var froslass := _engine_pokemon(
		FROSLASS_UID, FROSLASS_EFFECT_ID, "Froslass", 90, 1,
		[{"name": "Frost Smash", "cost": "WC", "damage": "60", "text": ""}],
		[{"name": "Freezing Shroud", "text": ""}], 10, 0, "", "Stage 1"
	)
	var budew := _engine_pokemon(
		BUDEW_UID, BUDEW_EFFECT_ID, "Budew", 30, 0,
		[{"name": "Itchy Pollen", "cost": "0", "damage": "10", "text": ""}],
		[], 11, 0
	)
	own.active_pokemon = froslass
	own.bench = [budew]
	var first_catcher := _engine_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Counter Catcher", "Item", FIRST_COUNTER_CATCHER_INSTANCE, 0)
	var second_catcher := _engine_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Counter Catcher", "Item", SECOND_COUNTER_CATCHER_INSTANCE, 0)
	var tool := _engine_card(TM_DEVOLUTION_UID, TM_DEVOLUTION_EFFECT_ID, "Technical Machine: Devolution", "Tool", TM_DEVOLUTION_INSTANCE, 0)
	var luminous := _engine_card(LUMINOUS_UID, LUMINOUS_EFFECT_ID, "Luminous Energy", "Special Energy", LUMINOUS_INSTANCE, 0)
	own.hand = [first_catcher, second_catcher, tool, luminous]
	own.discard_pile = [_engine_card(NIGHT_STRETCHER_UID, NIGHT_STRETCHER_EFFECT_ID, "Night Stretcher", "Item", NIGHT_STRETCHER_INSTANCE, 0)]
	_fill_engine_cards(own.prizes, 6, "OWN_PRIZE", 0)
	_fill_engine_cards(own.deck, 43, "OWN_DECK", 0)

	var raichu := _engine_pokemon(
		RAICHU_UID, RAICHU_EFFECT_ID, "Raichu V", 200, 1,
		[{"name": "Fast Charge", "cost": "L", "damage": "", "text": ""}, {"name": "Dynamic Spark", "cost": "LL", "damage": "60x", "text": ""}],
		[], 34, 1, "V"
	)
	var fezandipiti := _engine_pokemon(
		FEZANDIPITI_UID, FEZANDIPITI_EFFECT_ID, "Fezandipiti ex", 210, 1,
		[{"name": "Cruel Arrow", "cost": "CCC", "damage": "", "text": ""}],
		[{"name": "Flip the Script", "text": ""}], 51, 1, "ex"
	)
	raichu.damage_counters = 10
	fezandipiti.damage_counters = 20
	opponent.active_pokemon = raichu
	opponent.bench = [fezandipiti]
	_fill_engine_cards(opponent.prizes, 5, "OPPONENT_PRIZE", 1)
	_fill_engine_cards(opponent.deck, 42, "OPPONENT_DECK", 1)
	_fill_engine_cards(opponent.hand, 5, "OPPONENT_HAND", 1)

	var gsm := GameStateMachine.new()
	gsm.game_state = state
	return {
		"gsm": gsm,
		"state": state,
		"froslass": froslass,
		"budew": budew,
		"fezandipiti": fezandipiti,
		"raichu": raichu,
		"first_catcher": first_catcher,
		"second_catcher": second_catcher,
		"tool": tool,
	}


func _engine_pokemon(
	uid: String,
	effect_id: String,
	name: String,
	hp: int,
	retreat_cost: int,
	attacks: Array,
	abilities: Array,
	instance_id: int,
	owner: int,
	mechanic: String = "",
	stage: String = "Basic"
) -> PokemonSlot:
	var data := CardData.new()
	var parts := uid.split("_")
	data.set_code = str(parts[0])
	data.card_index = str(parts[1]) if parts.size() > 1 else uid
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.effect_id = effect_id
	data.hp = hp
	data.retreat_cost = retreat_cost
	data.mechanic = mechanic
	var typed_attacks: Array[Dictionary] = []
	for raw_attack: Variant in attacks:
		if raw_attack is Dictionary:
			typed_attacks.append((raw_attack as Dictionary).duplicate(true))
	data.attacks = typed_attacks
	var typed_abilities: Array[Dictionary] = []
	for raw_ability: Variant in abilities:
		if raw_ability is Dictionary:
			typed_abilities.append((raw_ability as Dictionary).duplicate(true))
	data.abilities = typed_abilities
	var card := CardInstance.create(data, owner)
	card.instance_id = instance_id
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _engine_card(
	uid: String,
	effect_id: String,
	name: String,
	type_name: String,
	instance_id: int,
	owner: int
) -> CardInstance:
	var data := CardData.new()
	var parts := uid.split("_")
	data.set_code = str(parts[0])
	data.card_index = str(parts[1]) if parts.size() > 1 else uid
	data.name = name
	data.name_en = name
	data.card_type = type_name
	data.effect_id = effect_id
	var card := CardInstance.create(data, owner)
	card.instance_id = instance_id
	return card


func _fill_engine_cards(target: Array, count: int, prefix: String, owner: int) -> void:
	for index: int in count:
		target.append(_engine_card("FIXTURE_%d" % index, "fixture:%s:%d" % [prefix, index], "%s_%d" % [prefix, index], "Item", 200 + owner * 100 + index, owner))


func _damaged_instance_ids(slots: Array[PokemonSlot]) -> Array[int]:
	var result: Array[int] = []
	for slot: PokemonSlot in slots:
		if slot != null and slot.get_top_card() != null:
			result.append(int(slot.get_top_card().instance_id))
	result.sort()
	return result


func _interaction_step(steps: Array, step_id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == step_id:
			return raw_step as Dictionary
	return {}


func _contains_hidden_information(observation: Dictionary) -> bool:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	return observation.has("belief") or observation.has("rng_state") \
		or own.has("prize_cards") or own.has("deck_cards") or own.has("deck_order") \
		or opponent.has("hand") or opponent.has("prize_cards") \
		or opponent.has("deck_cards") or opponent.has("deck_order")


func _event_matches(observation: Dictionary, action_id: String) -> bool:
	var event: Dictionary = observation.get("event", {}) if observation.get("event", {}) is Dictionary else {}
	return str(event.get("kind", "")) == "action_resolved" \
		and bool(event.get("success", false)) \
		and str(event.get("action_id", "")) == action_id


func _attacks_match(attacks_value: Variant, costs: Array[String]) -> bool:
	if not (attacks_value is Array) or (attacks_value as Array).size() != costs.size():
		return false
	for index: int in costs.size():
		var attack: Variant = (attacks_value as Array)[index]
		if not (attack is Dictionary) or str((attack as Dictionary).get("cost", "")) != costs[index]:
			return false
	return true


func _any_attack_payable(attacks_value: Variant, energy_value: Variant) -> bool:
	if not (attacks_value is Array) or not (energy_value is Array):
		return false
	var symbols: Array[String] = []
	for raw_energy: Variant in energy_value as Array:
		if raw_energy is Dictionary:
			symbols.append(str((raw_energy as Dictionary).get("energy_provides", "")))
	for raw_attack: Variant in attacks_value as Array:
		if raw_attack is Dictionary and _cost_payable(str((raw_attack as Dictionary).get("cost", "")), symbols):
			return true
	return false


func _cost_payable(cost: String, energy: Array[String]) -> bool:
	var remaining := energy.duplicate()
	var colorless := 0
	for symbol: String in cost:
		if symbol == "C":
			colorless += 1
			continue
		var index := remaining.find(symbol)
		if index < 0:
			return false
		remaining.remove_at(index)
	return remaining.size() >= colorless


func _has_exact_ability(slot: Dictionary, effect_id: String) -> bool:
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	var abilities: Array = pokemon.get("abilities", []) if pokemon.get("abilities", []) is Array else []
	return abilities.size() == 1 \
		and abilities[0] is Dictionary \
		and str((abilities[0] as Dictionary).get("effect_id", "")) == effect_id


func _slot_has_any_ability(slot: Dictionary) -> bool:
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	return pokemon.get("abilities", []) is Array and not (pokemon.get("abilities", []) as Array).is_empty()


func _slot_card_matches(
	value: Variant,
	slot_id: String,
	instance_id: int,
	uid: String,
	effect_id: String
) -> bool:
	if not (value is Dictionary):
		return false
	var slot: Dictionary = value as Dictionary
	return str(slot.get("slot_id", "")) == slot_id \
		and _card_matches(slot.get("pokemon", {}), uid, effect_id, instance_id)


func _card_matches(value: Variant, uid: String, effect_id: String, instance_id: int = -1) -> bool:
	if not (value is Dictionary):
		return false
	var card: Dictionary = value as Dictionary
	return str(card.get("uid", "")).strip_edges().to_upper() == uid.to_upper() \
		and str(card.get("effect_id", "")).strip_edges().to_lower() == effect_id.to_lower() \
		and (instance_id < 0 or int(card.get("instance_id", -1)) == instance_id)


func _count_card(cards_value: Variant, uid: String, effect_id: String, instance_id: int = -1) -> int:
	if not (cards_value is Array):
		return 0
	var count := 0
	for raw_card: Variant in cards_value as Array:
		if _card_matches(raw_card, uid, effect_id, instance_id):
			count += 1
	return count


func _slot_by_id(slots_value: Variant, slot_id: String) -> Dictionary:
	if not (slots_value is Array):
		return {}
	for raw_slot: Variant in slots_value as Array:
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == slot_id:
			return raw_slot as Dictionary
	return {}


func _actions_of_kind(observation: Dictionary, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_action: Variant in observation.get("legal_actions", []):
		if raw_action is Dictionary and str((raw_action as Dictionary).get("kind", "")) == kind:
			result.append(raw_action as Dictionary)
	return result


func _action_by_id(observation: Dictionary, action_id: String) -> Dictionary:
	for raw_action: Variant in observation.get("legal_actions", []):
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == action_id:
			return raw_action as Dictionary
	return {}


func _candidate(frontier: Array, candidate_id: String) -> Dictionary:
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary and str((raw_candidate as Dictionary).get("candidate_id", "")) == candidate_id:
			return raw_candidate as Dictionary
	return {}


func _route_ids(frontier: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary:
			var route_id := str((raw_candidate as Dictionary).get("route_id", ""))
			if route_id != "" and route_id not in result:
				result.append(route_id)
	return result


func _candidate_ids(frontier: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary:
			var candidate_id := str((raw_candidate as Dictionary).get("candidate_id", ""))
			if candidate_id != "":
				result.append(candidate_id)
	return result


func _same_public_board(left_value: Variant, right_value: Variant) -> bool:
	if not (left_value is Dictionary) or not (right_value is Dictionary):
		return false
	return ContractsScript.stable_hash(left_value as Dictionary) \
		== ContractsScript.stable_hash(right_value as Dictionary)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func _rejected(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
