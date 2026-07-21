extends SceneTree

## Focused RED for the current bundled-AI Marnie's Grimmsnarl seed.
##
## The seed-501 turn-7 O41 Rule floor spends a second Counter Catcher to replace
## an attackless, retreat-locked Iron Hands ex with a fully powered Raikou V.
## This test specifies the missing public, fail-closed certificate for the
## strictly resource-preserving suffix:
##
##   hold Counter Catcher #36 -> free retreat Munkidori to Impidimp ->
##   action_resolved reobserve -> end turn while Iron Hands stays Active.
##
## Production must certify both switches away from the same exact Rule gust.
## The negative matrix must remain green and this file must never depend on
## hidden hand/deck/prize data.

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const PolicyValidatorScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyValidator.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018501
const DECK_PATH := "res://data/bundled_user/decks/800018501.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018501.json"
const EXPECTED_DECK_FINGERPRINT := "2e5c3534bff9e3349dda17bf3b97224fc7ec723ff600b7f295b3970c52904763"
const EXPECTED_PROFILE_FINGERPRINT := "ed96e083127b1a2e13c6617f7a5b4bb5272f151e4ee4ff336fc4e6c49f1c75ab"
const EXPECTED_MODULES := ["stage2_chain", "energy_burst", "damage_counter_control"]

const TRACE_OBSERVATION_VERSION := 41
const POST_RETREAT_OBSERVATION_VERSION := 43
const TRACE_OBSERVATION_HASH := "9a46ad9e6b726f215ff27761e473c68be927f8e240285d2f22fab19d2f995cf7"
const POST_RETREAT_OBSERVATION_HASH := "counterfactual:800018501:t7:o43:hold-catcher36:retreat-slot1"

const COUNTER_CATCHER_UID := "CSV6C_114"
const COUNTER_CATCHER_EFFECT_ID := "06bc00d5dcec33898dc6db2e4c4d10ec"
const FIRST_COUNTER_CATCHER_INSTANCE := 35
const SECOND_COUNTER_CATCHER_INSTANCE := 36
const IRON_HANDS_UID := "CSV6C_051"
const IRON_HANDS_EFFECT_ID := "e9f0c124fc2e352af2408a7e61862b95"
const RAIKOU_UID := "CS4DaC_137"
const RAIKOU_EFFECT_ID := "9296cfa33d6dc517d8e12f62ad96cb75"
const MIRAIDON_UID := "CSV1C_050"
const MUNKIDORI_UID := "CSV8C_094"
const MUNKIDORI_EFFECT_ID := "66fee12502043db7d92b97b0d62b0f59"
const IMPIDIMP_UID := "CSV10C_146"
const IMPIDIMP_EFFECT_ID := "cd9d3ec383aa409ff7930840c21d43b0"
const SNORUNT_UID := "CSV9.5C_043"
const SNORUNT_EFFECT_ID := "f6baf0c4c60ff47c7f836c1271f40cb3"
const DARKNESS_UID := "CSVE1C_DAR"
const DARKNESS_EFFECT_ID := "46c769fc57a6c250c560df648bb779f8"
const LIGHTNING_UID := "CSVE1C_LIG"
const RESCUE_BOARD_UID := "CSV7C_185"
const RESCUE_BOARD_EFFECT_ID := "0b4cc131a19862f92acf71494f29a0ed"
const FROSLASS_UID := "CSV7C_059"
const FROSLASS_EFFECT_ID := "f27a2982c03f5b49a68ec0a77a2d6e48"
const MORGREM_UID := "CSV10C_147"
const MORGREM_EFFECT_ID := "945c3caf74096499c2140de9f71d815e"
const RARE_CANDY_UID := "CSVH1C_045"
const RARE_CANDY_EFFECT_ID := "d3891abcfe3277c8811cde06741d3236"
const ARVEN_UID := "CSV1C_123"
const ARVEN_EFFECT_ID := "5bdbc985f9aa2e6f248b53f6f35d1d37"

const MUNKIDORI_SLOT := "slot:9"
const IMPIDIMP_SLOT := "slot:1"
const SNORUNT_A_SLOT := "slot:11"
const SNORUNT_B_SLOT := "slot:10"
const IRON_HANDS_ACTIVE_SLOT := "slot:58"
const IRON_HANDS_BENCH_SLOT := "slot:57"
const MIRAIDON_SLOT := "slot:14"
const RAIKOU_SLOT := "slot:47"

const FIRST_GUST_ACTION_ID := "action:play_trainer:35:-:-:-1:-1"
const FIRST_GUST_CANDIDATE_ID := "candidate:65edfe5b7a11e7b29a36"
const RULE_GUST_ACTION_ID := "action:play_trainer:36:-:-:-1:-1"
const RULE_GUST_CANDIDATE_ID := "candidate:1a4905b8ccc439503437"
const RETREAT_ACTION_ID := "action:retreat:-:-:1:-1:-1"
const RETREAT_CANDIDATE_ID := "candidate:0fef3b1e6604f2fefcc9"
const END_ACTION_ID := "action:end_turn:-:-:-:-1:-1"
const END_CANDIDATE_ID := "candidate:8f40cb63bb171e97d5f0"
const RULE_GUST_SCORE := 334.8
const RETREAT_SCORE := 55.8
const END_SCORE := -2824.0
const EXPECTED_CERTIFICATE := "public_attackless_second_gust_releases_ready_attacker"

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
		"fixture and manifest must bind the current deck fingerprint")
	_check(ContractsScript.stable_hash(profile) == EXPECTED_PROFILE_FINGERPRINT,
		"fixture must bind the current production profile fingerprint; actual=%s" % ContractsScript.stable_hash(profile))
	_check(profile.get("modules", []) == EXPECTED_MODULES,
		"fixture must bind the exact three-module production composition")
	_check(int(profile.get("profile_version", 0)) == 3,
		"the action-result-bound certificate must publish profile version 3")
	_check(bool(profile.get("safety", {}).get("require_payable_ko_before_gust", false)),
		"profile must retain the payable-KO-before-gust safety intent")
	_check(_manifest_contract(manifest),
		"semantic manifest must bind every tactically relevant UID/effect pair")
	_check(is_equal_approx(RULE_GUST_SCORE - RETREAT_SCORE, 279.0),
		"captured O41 Rule-to-retreat score gap must remain exact")

	_test_real_engine_counterfactual()
	_test_production_root_action_result_bridge(profile, manifest)
	_test_production_o43_action_result_bridge(profile, manifest)
	_test_observation_version_provenance_optional(profile, manifest)

	var positive := _sequence_contract(_base_sequence(), profile, manifest)
	_check(bool(positive.get("accepted", false)),
		"EXPECTED RED: O41 must hold Counter Catcher #36 -> retreat to Impidimp -> action_resolved reobserve -> end with one model graph; blocker=%s" % str(positive.get("reason", "unknown")))

	_test_fail_closed_boundaries(profile, manifest)
	_check(_negative_count >= 40,
		"focused RED must prove at least forty independent fail-closed boundaries")

	if _failures.is_empty():
		print("V18CPG 800018501 attackless-second-gust hold: PASS (%d fail-closed boundaries)" % _negative_count)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800018501 attackless-second-gust hold focused RED: EXPECTED FAIL (%d failure, %d negative boundaries passed)" % [_failures.size(), _negative_count])
	quit(1)


func _sequence_contract(
	sequence: Array[Dictionary],
	profile: Dictionary,
	manifest: Dictionary
) -> Dictionary:
	if ContractsScript.stable_hash(profile) != EXPECTED_PROFILE_FINGERPRINT:
		return _rejected("profile_fingerprint")
	if profile.get("modules", []) != EXPECTED_MODULES \
			or not bool(profile.get("safety", {}).get("require_payable_ko_before_gust", false)):
		return _rejected("profile_contract")
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
	var retreat := _candidate(root_frontier, RETREAT_CANDIDATE_ID)
	var end_turn := _candidate(post_frontier, END_CANDIDATE_ID)
	if retreat.is_empty() or end_turn.is_empty():
		return _rejected("required_candidate_missing")
	if str(root_frontier[0].get("candidate_id", "")) != RULE_GUST_CANDIDATE_ID \
			or str(post_frontier[0].get("candidate_id", "")) != RULE_GUST_CANDIDATE_ID:
		return _rejected("exact_rule_floor_not_first")

	var root_safety := strategy._validate_model_route_safety(
		"route:pivot", root_frontier, root_facts, RETREAT_CANDIDATE_ID
	)
	if not bool(root_safety.get("valid", false)):
		return _rejected("root_retreat_not_certified:%s" % str(root_safety.get("reason", "unknown")))
	if str(root_safety.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE:
		return _rejected("root_certificate_kind")
	if str(root_safety.get("advantage", {}).get("module", "")) != "damage_counter_control":
		return _rejected("root_certificate_owner")

	var post_safety := strategy._validate_model_route_safety(
		"route:end_turn", post_frontier, post_facts, END_CANDIDATE_ID
	)
	if not bool(post_safety.get("valid", false)):
		return _rejected("post_retreat_end_not_certified:%s" % str(post_safety.get("reason", "unknown")))
	if str(post_safety.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE:
		return _rejected("post_retreat_certificate_kind")
	if str(post_safety.get("advantage", {}).get("module", "")) != "damage_counter_control":
		return _rejected("post_retreat_certificate_owner")

	var policy := _two_epoch_policy()
	var response_validation := PolicyValidatorScript.new().validate_response(
		{"policy": policy},
		["route:pivot", "route:end_turn"],
		8,
		[RETREAT_CANDIDATE_ID],
		true
	)
	if not bool(response_validation.get("valid", false)):
		return _rejected("policy_invalid:%s" % str(response_validation.get("reason", "unknown")))

	# Request #1 produced the graph.  The post-retreat decision is a local graph
	# continuation after a material public observation, not another model call.
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
	var rule_catcher: CardInstance = rule_fixture["second_catcher"]
	var rule_raikou: PokemonSlot = rule_fixture["raikou"]
	var rule_impidimp: PokemonSlot = rule_fixture["impidimp"]
	var catcher_effect: BaseEffect = rule_gsm.effect_processor.get_effect(COUNTER_CATCHER_EFFECT_ID)
	var catcher_steps: Array = catcher_effect.get_interaction_steps(rule_catcher, rule_state) \
		if catcher_effect != null else []
	var target_step := _interaction_step(catcher_steps, "opponent_bench_target")
	_check(catcher_effect != null and bool(catcher_effect.call("can_execute", rule_catcher, rule_state)),
		"real Counter Catcher effect must be legal only because own prizes are 6 versus 5")
	_check(int(target_step.get("min_select", -1)) == 1 and int(target_step.get("max_select", -1)) == 1,
		"real Counter Catcher interaction must bind exactly one opponent Bench target")
	var catcher_played := rule_gsm.play_trainer(0, rule_catcher, [{
		"opponent_bench_target": [rule_raikou],
	}])
	_check(catcher_played
		and rule_state.players[1].active_pokemon == rule_raikou
		and rule_catcher in rule_state.players[0].discard_pile,
		"captured Rule suffix must spend instance #36 and expose ready Raikou V slot:47")
	var rule_retreated := rule_gsm.retreat(0, [], rule_impidimp)
	_check(rule_retreated and rule_state.players[0].active_pokemon == rule_impidimp,
		"Rescue Board must make the captured Munkidori-to-Impidimp retreat executable for Rule")

	var hold_fixture := _engine_fixture()
	var hold_gsm: GameStateMachine = hold_fixture["gsm"]
	var hold_state: GameState = hold_fixture["state"]
	var held_catcher: CardInstance = hold_fixture["second_catcher"]
	var held_impidimp: PokemonSlot = hold_fixture["impidimp"]
	var held_iron_hands: PokemonSlot = hold_fixture["iron_hands_active"]
	var held_munkidori: PokemonSlot = hold_fixture["munkidori"]
	var held_retreat := hold_gsm.retreat(0, [], held_impidimp)
	_check(held_retreat
		and hold_state.players[0].active_pokemon == held_impidimp
		and held_munkidori in hold_state.players[0].bench
		and hold_state.players[1].active_pokemon == held_iron_hands
		and held_catcher in hold_state.players[0].hand
		and int(held_catcher.instance_id) == SECOND_COUNTER_CATCHER_INSTANCE,
		"counterfactual must execute the same free retreat while preserving Catcher #36 and attackless Iron Hands Active")


func _test_production_o43_action_result_bridge(
	profile: Dictionary,
	manifest: Dictionary
) -> void:
	var post := _base_sequence()[1]
	# Production ObservationGateway does not place the host action_result inside
	# the model observation. Strategy owns that already-audited result separately
	# until the next material observation consumes it.
	post.erase("event")
	var facts := _facts_for(post)
	var exact_result := {
		"action_id": RETREAT_ACTION_ID,
		"action_kind": "retreat",
		"action_card_uid": "",
		"success": true,
		"route_id": "route:pivot",
		"candidate_id": RETREAT_CANDIDATE_ID,
		"owner": "module_verified_upgrade",
	}
	for observation_version: int in [43, 47, 1043]:
		var versioned_post := post.duplicate(true)
		versioned_post["observation_version"] = observation_version
		var versioned_facts := _facts_for(versioned_post)
		var versioned_safety := _production_bridge_safety(
			versioned_post,
			versioned_facts,
			profile,
			manifest,
			exact_result,
			true,
			"route:end_turn",
			END_CANDIDATE_ID
		)
		_check(bool(versioned_safety.get("valid", false))
			and str(versioned_safety.get("reason", "")) == "module_verified_advantage"
			and str(versioned_safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
			"post-retreat certificate must ignore observation_version provenance=%d" % observation_version)
	for action_owner: String in ["module_verified_upgrade", "deadline_fallback", "local_gate"]:
		var owner_result := exact_result.duplicate(true)
		owner_result["owner"] = action_owner
		var owner_safety := _production_bridge_safety(
			post, facts, profile, manifest, owner_result, true, "route:end_turn", END_CANDIDATE_ID
		)
		_check(bool(owner_safety.get("valid", false))
			and str(owner_safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
			"post-retreat certificate must bind the action result, not owner=%s" % action_owner)
	var safety := _production_bridge_safety(
		post, facts, profile, manifest, exact_result, true, "route:end_turn", END_CANDIDATE_ID
	)
	_check(not post.has("event"),
		"production action-result bridge must not mutate the model observation")
	_check(bool(safety.get("valid", false))
		and str(safety.get("reason", "")) == "module_verified_advantage"
		and str(safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE
		and str(safety.get("advantage", {}).get("module", "")) == "damage_counter_control",
		"real O43 bridge must certify end only from the consumed successful retreat result")
	for spec: Dictionary in [
		{"key": "success", "value": false, "label": "failed retreat result"},
		{"key": "action_id", "value": "action:wrong", "label": "wrong action-result id"},
		{"key": "action_kind", "value": "play_trainer", "label": "wrong action-result kind"},
		{"key": "route_id", "value": "route:gust", "label": "wrong completed route"},
		{"key": "candidate_id", "value": RULE_GUST_CANDIDATE_ID, "label": "wrong completed candidate"},
	]:
		var invalid_result := exact_result.duplicate(true)
		invalid_result[str(spec.get("key", ""))] = spec.get("value")
		var rejected := _production_bridge_safety(
			post, facts, profile, manifest, invalid_result, true, "route:end_turn", END_CANDIDATE_ID
		)
		_check(not bool(rejected.get("valid", false))
			or str(rejected.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE,
			"production O43 must fail closed for %s" % str(spec.get("label", "invalid result")))
		_negative_count += 1


func _test_production_root_action_result_bridge(
	profile: Dictionary,
	manifest: Dictionary
) -> void:
	var root := _base_sequence()[0]
	root.erase("event")
	var exact_result := {
		"action_id": FIRST_GUST_ACTION_ID,
		"action_kind": "play_trainer",
		"action_card_uid": COUNTER_CATCHER_UID,
		"success": true,
		"route_id": "route:gust",
		"candidate_id": FIRST_GUST_CANDIDATE_ID,
		# The certificate binds the public transition, not whichever non-model
		# owner happened to execute the exact Rule root.
		"owner": "local_gate",
	}
	for observation_version: int in [41, 45, 1041]:
		var versioned_root := root.duplicate(true)
		versioned_root["observation_version"] = observation_version
		var facts := _facts_for(versioned_root)
		var safety := _production_bridge_safety(
			versioned_root,
			facts,
			profile,
			manifest,
			exact_result,
			false,
			"route:pivot",
			RETREAT_CANDIDATE_ID
		)
		_check(bool(safety.get("valid", false))
			and str(safety.get("reason", "")) == "module_verified_advantage"
			and str(safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
			"root certificate must ignore observation_version provenance=%d" % observation_version)
	for action_owner: String in ["local_gate", "deadline_fallback", "rules_fallback"]:
		var owner_result := exact_result.duplicate(true)
		owner_result["owner"] = action_owner
		var facts := _facts_for(root)
		var owner_safety := _production_bridge_safety(
			root, facts, profile, manifest, owner_result, false, "route:pivot", RETREAT_CANDIDATE_ID
		)
		_check(bool(owner_safety.get("valid", false))
			and str(owner_safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
			"root certificate must bind the action result, not owner=%s" % action_owner)
	for spec: Dictionary in [
		{"key": "success", "value": false, "label": "failed first Catcher result"},
		{"key": "action_id", "value": "action:wrong", "label": "wrong first Catcher action id"},
		{"key": "action_kind", "value": "retreat", "label": "wrong first Catcher action kind"},
		{"key": "route_id", "value": "route:information", "label": "wrong first Catcher route"},
		{"key": "candidate_id", "value": RULE_GUST_CANDIDATE_ID, "label": "wrong first Catcher candidate"},
	]:
		var invalid_result := exact_result.duplicate(true)
		invalid_result[str(spec.get("key", ""))] = spec.get("value")
		var facts := _facts_for(root)
		var rejected := _production_bridge_safety(
			root,
			facts,
			profile,
			manifest,
			invalid_result,
			false,
			"route:pivot",
			RETREAT_CANDIDATE_ID
		)
		_check(not bool(rejected.get("valid", false))
			or str(rejected.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE,
			"production root must fail closed for %s" % str(spec.get("label", "invalid result")))
		_negative_count += 1


func _production_bridge_safety(
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	manifest: Dictionary,
	action_result: Dictionary,
	post_retreat: bool,
	route_id: String,
	candidate_id: String
) -> Dictionary:
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile, manifest)
	strategy._unconsumed_action_result = action_result.duplicate(true)
	var raw_frontier := _frontier(observation, facts, profile, manifest, post_retreat, false)
	var frontier := strategy._annotate_candidate_pool_with_engine_rule_floor(
		raw_frontier,
		RULE_GUST_ACTION_ID,
		observation,
		facts
	)
	return strategy._validate_model_route_safety(
		route_id,
		frontier,
		facts,
		candidate_id
	)


func _test_observation_version_provenance_optional(
	profile: Dictionary,
	manifest: Dictionary
) -> void:
	var versionless_profile := profile.duplicate(true)
	var config: Dictionary = versionless_profile.get("local_action_certificate_parameters", {}) \
		.get("damage_counter_control", {}).get("attackless_second_gust_hold", {})
	config.erase("root_observation_version")
	config.erase("post_retreat_observation_version")
	var sequence := _base_sequence()
	var root_result := {
		"action_id": FIRST_GUST_ACTION_ID,
		"action_kind": "play_trainer",
		"success": true,
		"route_id": "route:gust",
		"candidate_id": FIRST_GUST_CANDIDATE_ID,
		"owner": "deadline_fallback",
	}
	var root_safety := _production_bridge_safety(
		sequence[0],
		_facts_for(sequence[0]),
		versionless_profile,
		manifest,
		root_result,
		false,
		"route:pivot",
		RETREAT_CANDIDATE_ID
	)
	var post_result := {
		"action_id": RETREAT_ACTION_ID,
		"action_kind": "retreat",
		"success": true,
		"route_id": "route:pivot",
		"candidate_id": RETREAT_CANDIDATE_ID,
		"owner": "module_verified_upgrade",
	}
	var post_safety := _production_bridge_safety(
		sequence[1],
		_facts_for(sequence[1]),
		versionless_profile,
		manifest,
		post_result,
		true,
		"route:end_turn",
		END_CANDIDATE_ID
	)
	_check(bool(root_safety.get("valid", false))
		and str(root_safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
		"root_observation_version must remain optional provenance")
	_check(bool(post_safety.get("valid", false))
		and str(post_safety.get("advantage", {}).get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
		"post_retreat_observation_version must remain optional provenance")


func _test_fail_closed_boundaries(profile: Dictionary, manifest: Dictionary) -> void:
	var cases: Array[Dictionary] = [
		{"kind": "wrong_deck_id", "label": "deck identity changed"},
		{"kind": "wrong_deck_fingerprint", "label": "deck fingerprint changed"},
		{"kind": "wrong_trace_hash", "label": "captured observation hash changed"},
		{"kind": "hash_reused", "label": "material reobserve reused the old hash"},
		{"kind": "wrong_turn", "label": "turn number changed"},
		{"kind": "wrong_current_player", "label": "current player changed"},
		{"kind": "wrong_viewer", "label": "viewer changed"},
		{"kind": "wrong_phase", "label": "decision is outside MAIN"},
		{"kind": "opponent_hand_leak", "label": "opponent hidden hand leaked"},
		{"kind": "opponent_deck_leak", "label": "opponent hidden deck identities leaked"},
		{"kind": "opponent_prize_leak", "label": "opponent hidden prizes leaked"},
		{"kind": "own_prize_leak", "label": "own hidden prizes leaked"},
		{"kind": "belief_leak", "label": "hidden belief/deck order injected"},
		{"kind": "wrong_rule_action", "label": "Rule action identity changed"},
		{"kind": "wrong_rule_candidate", "label": "Rule candidate identity changed"},
		{"kind": "wrong_catcher_uid", "label": "gust source UID changed"},
		{"kind": "wrong_catcher_effect", "label": "gust source effect changed"},
		{"kind": "wrong_catcher_instance", "label": "gust source instance changed"},
		{"kind": "catcher_missing", "label": "second Counter Catcher is absent"},
		{"kind": "duplicate_catcher", "label": "second Counter Catcher is not unique"},
		{"kind": "first_catcher_missing_discard", "label": "first Counter Catcher history is absent"},
		{"kind": "not_behind_on_prizes", "label": "Counter Catcher behind gate is closed"},
		{"kind": "wrong_iron_uid", "label": "opponent Active UID changed"},
		{"kind": "wrong_iron_effect", "label": "opponent Active effect changed"},
		{"kind": "wrong_iron_slot", "label": "opponent Active instance changed"},
		{"kind": "iron_extra_energy", "label": "opponent Active gains a payable attack"},
		{"kind": "iron_attack_cost_changed", "label": "opponent Active printed cost changed"},
		{"kind": "iron_retreat_unlocked", "label": "opponent Active retreat lock disappeared"},
		{"kind": "wrong_raikou_uid", "label": "ready Bench attacker UID changed"},
		{"kind": "wrong_raikou_effect", "label": "ready Bench attacker effect changed"},
		{"kind": "wrong_raikou_slot", "label": "ready Bench attacker instance changed"},
		{"kind": "raikou_energy_missing", "label": "Bench attacker is no longer ready"},
		{"kind": "raikou_cost_changed", "label": "Bench attacker printed cost changed"},
		{"kind": "own_attack_added", "label": "own attack unexpectedly became legal"},
		{"kind": "own_ko_added", "label": "own deterministic KO became available"},
		{"kind": "wrong_munkidori_uid", "label": "own Active UID changed"},
		{"kind": "wrong_munkidori_effect", "label": "own Active effect changed"},
		{"kind": "wrong_munkidori_slot", "label": "own Active instance changed"},
		{"kind": "darkness_missing", "label": "Munkidori Darkness binding changed"},
		{"kind": "rescue_board_missing", "label": "free-retreat tool binding changed"},
		{"kind": "retreat_quota_closed", "label": "retreat quota is unavailable"},
		{"kind": "retreat_missing", "label": "exact retreat candidate is unavailable"},
		{"kind": "retreat_target_changed", "label": "retreat target changed"},
		{"kind": "retreat_action_changed", "label": "retreat action identity changed"},
		{"kind": "event_failed", "label": "retreat action_result failed"},
		{"kind": "event_mismatch", "label": "reobserve acknowledges another action"},
		{"kind": "post_opponent_changed", "label": "opponent board changed during own retreat"},
		{"kind": "post_catcher_consumed", "label": "held Catcher disappeared after retreat"},
		{"kind": "post_active_changed", "label": "post-retreat Active is not Impidimp"},
		{"kind": "post_munkidori_missing", "label": "retreated Munkidori is absent from Bench"},
		{"kind": "post_darkness_moved", "label": "retreated Munkidori lost its Darkness"},
		{"kind": "post_tool_moved", "label": "retreated Munkidori lost Rescue Board"},
		{"kind": "post_deck_count_changed", "label": "retreat changed hidden deck count"},
		{"kind": "post_hand_count_changed", "label": "retreat changed public hand count"},
		{"kind": "post_bench_changed", "label": "retreat altered an unrelated opponent Bench slot"},
		{"kind": "post_turn_changed", "label": "continuation crossed a turn before end"},
		{"kind": "post_retreat_still_available", "label": "retreat quota was not consumed"},
		{"kind": "end_missing", "label": "post-retreat end action is unavailable"},
		{"kind": "end_action_changed", "label": "post-retreat end action identity changed"},
		{"kind": "interaction_min_changed", "label": "Counter Catcher min selection changed"},
		{"kind": "interaction_max_changed", "label": "Counter Catcher max selection changed"},
		{"kind": "interaction_target_changed", "label": "Rule gust target binding changed"},
	]
	for spec: Dictionary in cases:
		var mutated_sequence := _base_sequence()
		var mutated_profile := profile.duplicate(true)
		var mutated_manifest := manifest.duplicate(true)
		_apply_mutation(mutated_sequence, mutated_profile, mutated_manifest, str(spec.get("kind", "")))
		var result := _sequence_contract(mutated_sequence, mutated_profile, mutated_manifest)
		_check(not bool(result.get("accepted", false)),
			"%s must fail closed" % str(spec.get("label", "invalid boundary")))
		_negative_count += 1

	# Profile/manifest mutations are kept separate from the public sequence list
	# because they fail before observation parsing.
	for spec: Dictionary in [
		{"kind": "profile_fingerprint", "label": "profile fingerprint changed"},
		{"kind": "module_composition", "label": "module composition changed"},
		{"kind": "payable_gust_safety", "label": "payable-KO gust safety disabled"},
		{"kind": "manifest_effect", "label": "manifest effect binding changed"},
	]:
		var mutated_sequence := _base_sequence()
		var mutated_profile := profile.duplicate(true)
		var mutated_manifest := manifest.duplicate(true)
		_apply_mutation(mutated_sequence, mutated_profile, mutated_manifest, str(spec.get("kind", "")))
		var result := _sequence_contract(mutated_sequence, mutated_profile, mutated_manifest)
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
				or str(provenance.get("deck_content_fingerprint", "")) != EXPECTED_DECK_FINGERPRINT:
			return _invalid("deck_provenance")
		var turn: Dictionary = observation.get("turn", {}) \
			if observation.get("turn", {}) is Dictionary else {}
		if int(turn.get("number", -1)) != 7 \
				or int(turn.get("current_player", -1)) != 0 \
				or int(turn.get("viewer", -1)) != 0 \
				or int(turn.get("phase", -1)) != int(GameState.GamePhase.MAIN):
			return _invalid("turn_identity")
		var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
		var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
		if int(own.get("prizes_remaining", -1)) != 6 \
				or int(opponent.get("prizes_remaining", -1)) != 5:
			return _invalid("counter_catcher_prize_gate")
		if int(own.get("deck_count", -1)) != 27 \
				or int(opponent.get("deck_count", -1)) != 37 \
				or int(opponent.get("hand_count", -1)) != 6:
			return _invalid("public_zone_counts")
		if not _attackless_locked_iron_hands(opponent.get("active", {})):
			return _invalid("attackless_locked_iron_hands")
		if not _ready_raikou(_slot_by_id(opponent.get("bench", []), RAIKOU_SLOT)):
			return _invalid("ready_raikou_bench_threat")
		if not _opponent_bench_identity(opponent.get("bench", [])):
			return _invalid("opponent_bench_identity")
		if _actions_of_kind(observation, "attack").size() != 0 \
				or bool(observation.get("public_outcome", {}).get("own_ko_available", false)):
			return _invalid("own_attackless_boundary")

	if str(root.get("observation_hash", "")) != TRACE_OBSERVATION_HASH:
		return _invalid("captured_o41_identity")
	if str(post.get("observation_hash", "")) != POST_RETREAT_OBSERVATION_HASH \
			or str(post.get("observation_hash", "")) == str(root.get("observation_hash", "")):
		return _invalid("material_reobserve_identity")
	if not _event_matches(post, RETREAT_ACTION_ID):
		return _invalid("retreat_action_resolved_event")

	var root_own: Dictionary = root.get("own", {})
	var post_own: Dictionary = post.get("own", {})
	if int(root_own.get("hand_count", -1)) != 5 or int(post_own.get("hand_count", -1)) != 5 \
			or _count_card(root_own.get("hand", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) != 1 \
			or _count_card(post_own.get("hand", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) != 1:
		return _invalid("held_second_counter_catcher")
	if _count_card(root_own.get("discard", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, FIRST_COUNTER_CATCHER_INSTANCE) != 1 \
			or _count_card(post_own.get("discard", []), COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, FIRST_COUNTER_CATCHER_INSTANCE) != 1:
		return _invalid("first_counter_catcher_history")
	if not _root_own_board(root_own) or not _post_retreat_own_board(post_own):
		return _invalid("own_retreat_transition")
	if not _same_opponent_board(root.get("opponent", {}), post.get("opponent", {})):
		return _invalid("opponent_board_changed_during_retreat")
	if not bool(root.get("turn", {}).get("quotas", {}).get("retreat_available", false)) \
			or bool(post.get("turn", {}).get("quotas", {}).get("retreat_available", true)):
		return _invalid("retreat_quota_transition")

	var root_gust := _action_by_id(root, RULE_GUST_ACTION_ID)
	var post_gust := _action_by_id(post, RULE_GUST_ACTION_ID)
	if not _exact_second_catcher_action(root_gust) or not _exact_second_catcher_action(post_gust):
		return _invalid("exact_second_catcher_rule_action")
	var retreat := _action_by_id(root, RETREAT_ACTION_ID)
	if retreat.is_empty() \
			or str(retreat.get("kind", "")) != "retreat" \
			or str(retreat.get("candidate_id", "")) != RETREAT_CANDIDATE_ID \
			or str(retreat.get("target", "")) != IMPIDIMP_SLOT \
			or int(retreat.get("target_instance_id", -1)) != 1 \
			or int(retreat.get("effective_cost", -1)) != 0:
		return _invalid("exact_free_retreat_action")
	var end_turn := _action_by_id(post, END_ACTION_ID)
	if end_turn.is_empty() \
			or str(end_turn.get("kind", "")) != "end_turn" \
			or str(end_turn.get("candidate_id", "")) != END_CANDIDATE_ID:
		return _invalid("exact_post_retreat_end_action")
	return {"valid": true, "reason": ""}


func _frontier(
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	manifest: Dictionary,
	post_retreat: bool,
	annotate: bool = true
) -> Array[Dictionary]:
	var gust := {
		"candidate_id": RULE_GUST_CANDIDATE_ID,
		"route_id": "route:gust",
		"action_kind": "play_trainer",
		"safe_prefix_action_id": RULE_GUST_ACTION_ID,
		"base_score": RULE_GUST_SCORE,
		"local_score": RULE_GUST_SCORE,
		"checkpoint_after": "action_resolved",
		"engine_rule_floor_exact": true,
		"rule_floor_exact": true,
		"action_semantic_roles": ["item", "gust"],
		"action_ref": _action_by_id(observation, RULE_GUST_ACTION_ID),
		"outcome": {"future_flexibility": 0.3, "resource_commitment": 0.35, "uncertainty": 0.2},
	}
	var candidates: Array[Dictionary] = [gust]
	if not post_retreat:
		candidates.append({
			"candidate_id": RETREAT_CANDIDATE_ID,
			"route_id": "route:pivot",
			"action_kind": "retreat",
			"safe_prefix_action_id": RETREAT_ACTION_ID,
			"base_score": RETREAT_SCORE,
			"local_score": RETREAT_SCORE,
			"checkpoint_after": "action_resolved",
			"action_ref": _action_by_id(observation, RETREAT_ACTION_ID),
			"outcome": {"future_flexibility": 0.8, "resource_commitment": 0.7, "uncertainty": 0.2},
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
		"outcome": {"future_flexibility": 0.3, "resource_commitment": 0.0, "terminal": true, "uncertainty": 0.0},
	})
	if not annotate:
		return candidates
	return CapabilityRegistryScript.new().annotate_frontier(candidates, observation, facts, profile, manifest)


func _facts_for(observation: Dictionary) -> Dictionary:
	var opponent: Dictionary = observation.get("opponent", {})
	var own: Dictionary = observation.get("own", {})
	var raikou := _slot_by_id(opponent.get("bench", []), RAIKOU_SLOT)
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
			"energy_on_board": 1,
			"bench_slots_free": 2,
		},
		"turn": {
			"energy_available": bool(observation.get("turn", {}).get("quotas", {}).get("energy_available", false)),
			"supporter_available": bool(observation.get("turn", {}).get("quotas", {}).get("supporter_available", false)),
			"retreat_available": bool(observation.get("turn", {}).get("quotas", {}).get("retreat_available", false)),
		},
		"prize": {"win_now": false, "current_swing": 0},
		"route": {"current_valid": true},
		"threat": {
			"second_gust_harmful": true,
			"opponent_active_attack_ready": false,
			"opponent_active_retreat_locked": true,
			"ready_bench_attacker_slot_id": str(raikou.get("slot_id", "")),
			"ready_bench_attacker_uid": str(raikou.get("pokemon", {}).get("uid", "")),
		},
		"belief": {"known_in_deck_uid_counts": {}, "evidence_kind": "public_only"},
	}


func _two_epoch_policy() -> Dictionary:
	return {
		"root_node_id": "node:hold-second-catcher-retreat",
		"nodes": [{
			"node_id": "node:hold-second-catcher-retreat",
			"kind": "route",
			"route_ref": {
				"mode": "select_candidate",
				"route_id": "route:pivot",
				"candidate_id": RETREAT_CANDIDATE_ID,
			},
			"next_node_id": "node:after-retreat-reobserve",
		}, {
			"node_id": "node:after-retreat-reobserve",
			"kind": "checkpoint",
			"branches": [{
				"when_all": [{"fact": "attack.ready", "op": "==", "value": false}],
				"next_node_id": "node:end-behind-attackless-iron-hands",
			}],
			"otherwise": "replan",
		}, {
			"node_id": "node:end-behind-attackless-iron-hands",
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
		"action_kind": "play_trainer",
		"route_id": "route:gust",
		"candidate_id": FIRST_GUST_CANDIDATE_ID,
		"owner": "local_gate",
	}
	root["own"]["active"] = _munkidori_slot()
	root["own"]["bench"] = [_impidimp_slot(), _snorunt_slot(SNORUNT_A_SLOT, 11), _snorunt_slot(SNORUNT_B_SLOT, 10)]
	root["own"]["hand"] = _exact_hand()
	root["own"]["discard"] = [_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", FIRST_COUNTER_CATCHER_INSTANCE)]
	root["opponent"]["active"] = _iron_hands_slot(IRON_HANDS_ACTIVE_SLOT, 58, 1)
	root["opponent"]["bench"] = [
		_iron_hands_slot(IRON_HANDS_BENCH_SLOT, 57, 0),
		_slot(MIRAIDON_SLOT, _card(MIRAIDON_UID, "fixture:exact-miraidon-effect", "Pokemon", 14), [], {}, 220, 2, 2),
		_raikou_slot(),
	]
	root["legal_actions"] = [
		_second_catcher_action(),
		_retreat_action(),
		{"id": END_ACTION_ID, "candidate_id": END_CANDIDATE_ID, "kind": "end_turn"},
	]

	var post := _observation_shell(POST_RETREAT_OBSERVATION_VERSION, POST_RETREAT_OBSERVATION_HASH)
	post["event"] = {
		"kind": "action_resolved",
		"success": true,
		"action_id": RETREAT_ACTION_ID,
		"action_kind": "retreat",
		"route_id": "route:pivot",
		"candidate_id": RETREAT_CANDIDATE_ID,
	}
	post["turn"]["quotas"]["retreat_available"] = false
	post["own"]["active"] = _impidimp_slot()
	post["own"]["bench"] = [_munkidori_slot(), _snorunt_slot(SNORUNT_A_SLOT, 11), _snorunt_slot(SNORUNT_B_SLOT, 10)]
	post["own"]["hand"] = _exact_hand()
	post["own"]["discard"] = [_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", FIRST_COUNTER_CATCHER_INSTANCE)]
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
			"deck_content_fingerprint": EXPECTED_DECK_FINGERPRINT,
			"source": "prepare_third_trace_seed501:turn7:o41",
		},
		"turn": {
			"number": 7,
			"current_player": 0,
			"first_player": 0,
			"viewer": 0,
			"phase": int(GameState.GamePhase.MAIN),
			"deterministic_attack_window_open": true,
			"quotas": {
				"energy_available": true,
				"retreat_available": true,
				"stadium_available": true,
				"supporter_available": false,
				"vstar_available": true,
			},
		},
		"visibility": {
			"deck_order_visible": false,
			"decklist_visibility": "observed_only",
			"opponent_hand_contents": false,
			"own_prize_identities": false,
		},
		"stadium": {"uid": "CSV10C_216", "type": "Stadium"},
		"own": {
			"prizes_remaining": 6,
			"deck_count": 27,
			"hand_count": 5,
			"hand": [],
			"discard": [],
			"active": {},
			"bench": [],
		},
		"opponent": {
			"prizes_remaining": 5,
			"deck_count": 37,
			"hand_count": 6,
			"active": {},
			"bench": [],
		},
		"public_outcome": {"own_ko_available": false, "win_now": false},
		"legal_actions": [],
	}


func _second_catcher_action() -> Dictionary:
	return {
		"id": RULE_GUST_ACTION_ID,
		"candidate_id": RULE_GUST_CANDIDATE_ID,
		"kind": "play_trainer",
		"route_id": "route:gust",
		"card_instance_id": SECOND_COUNTER_CATCHER_INSTANCE,
		"card": _card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE),
		"interaction_steps": [{
			"id": "opponent_bench_target",
			"min_select": 1,
			"max_select": 1,
			"public_items": [IRON_HANDS_BENCH_SLOT, MIRAIDON_SLOT, RAIKOU_SLOT],
		}],
		"rule_selected_target_slot_id": RAIKOU_SLOT,
		"rule_selected_target_instance_id": 47,
	}


func _retreat_action() -> Dictionary:
	return {
		"id": RETREAT_ACTION_ID,
		"candidate_id": RETREAT_CANDIDATE_ID,
		"kind": "retreat",
		"route_id": "route:pivot",
		"source": MUNKIDORI_SLOT,
		"source_instance_id": 9,
		"target": IMPIDIMP_SLOT,
		"target_instance_id": 1,
		"effective_cost": 0,
		"payment_instance_ids": [],
	}


func _exact_hand() -> Array:
	return [
		_card(RARE_CANDY_UID, RARE_CANDY_EFFECT_ID, "Item"),
		_card(FROSLASS_UID, FROSLASS_EFFECT_ID, "Pokemon"),
		_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE),
		_card(ARVEN_UID, ARVEN_EFFECT_ID, "Supporter"),
		_card(MORGREM_UID, MORGREM_EFFECT_ID, "Pokemon"),
	]


func _munkidori_slot() -> Dictionary:
	return _slot(
		MUNKIDORI_SLOT,
		_card(MUNKIDORI_UID, MUNKIDORI_EFFECT_ID, "Pokemon", 9, [{"cost": "PC", "damage": 60}]),
		[_energy(DARKNESS_UID, DARKNESS_EFFECT_ID, "D", 29)],
		_card(RESCUE_BOARD_UID, RESCUE_BOARD_EFFECT_ID, "Tool", 30),
		110,
		1,
		0
	)


func _impidimp_slot() -> Dictionary:
	return _slot(
		IMPIDIMP_SLOT,
		_card(IMPIDIMP_UID, IMPIDIMP_EFFECT_ID, "Pokemon", 1, [
			{"cost": "C", "damage": 0}, {"cost": "D", "damage": 10},
		]),
		[], {}, 70, 1, 1
	)


func _snorunt_slot(slot_id: String, instance_id: int) -> Dictionary:
	return _slot(
		slot_id,
		_card(SNORUNT_UID, SNORUNT_EFFECT_ID, "Pokemon", instance_id, [{"cost": "WC", "damage": 20}]),
		[], {}, 60, 1, 1
	)


func _iron_hands_slot(slot_id: String, instance_id: int, energy_count: int) -> Dictionary:
	var energy: Array = []
	for index: int in energy_count:
		energy.append(_energy(LIGHTNING_UID, "fixture:lightning-energy", "L", 70 + instance_id + index))
	return _slot(
		slot_id,
		_card(IRON_HANDS_UID, IRON_HANDS_EFFECT_ID, "Pokemon", instance_id, [
			{"cost": "LLC", "damage": 160}, {"cost": "LCCC", "damage": 120},
		]),
		energy, {}, 230, 2, 4
	)


func _raikou_slot() -> Dictionary:
	return _slot(
		RAIKOU_SLOT,
		_card(RAIKOU_UID, RAIKOU_EFFECT_ID, "Pokemon", 47, [{"cost": "LC", "damage": 20}]),
		[
			_energy(LIGHTNING_UID, "fixture:lightning-energy", "L", 117),
			_energy(LIGHTNING_UID, "fixture:lightning-energy", "L", 118),
			_energy(LIGHTNING_UID, "fixture:lightning-energy", "L", 119),
		],
		{}, 200, 2, 1
	)


func _slot(
	slot_id: String,
	pokemon: Dictionary,
	energy: Array,
	tool: Dictionary,
	remaining_hp: int,
	prize_count: int,
	retreat_cost: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": pokemon,
		"energy": energy,
		"energy_count": energy.size(),
		"tool": tool,
		"remaining_hp": remaining_hp,
		"damage": 0,
		"prize_count": prize_count,
		"printed_retreat_cost": retreat_cost,
		"effective_retreat_cost": 0 if _card_matches(tool, RESCUE_BOARD_UID, RESCUE_BOARD_EFFECT_ID) else retreat_cost,
		"ability_used": false,
		"tera": false,
	}


func _card(
	uid: String,
	effect_id: String,
	type_name: String,
	instance_id: int = -1,
	attacks: Array = []
) -> Dictionary:
	var result := {"uid": uid, "effect_id": effect_id, "type": type_name}
	if instance_id >= 0:
		result["instance_id"] = instance_id
	if not attacks.is_empty():
		result["attacks"] = attacks.duplicate(true)
	return result


func _energy(uid: String, effect_id: String, symbol: String, instance_id: int) -> Dictionary:
	var result := _card(uid, effect_id, "Basic Energy", instance_id)
	result["energy_provides"] = symbol
	return result


func _root_own_board(own: Dictionary) -> bool:
	var active: Dictionary = own.get("active", {})
	return _slot_card_matches(active, MUNKIDORI_SLOT, 9, MUNKIDORI_UID, MUNKIDORI_EFFECT_ID) \
		and _count_energy_symbol(active.get("energy", []), "D") == 1 \
		and _card_matches(active.get("tool", {}), RESCUE_BOARD_UID, RESCUE_BOARD_EFFECT_ID) \
		and int(active.get("effective_retreat_cost", -1)) == 0 \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), IMPIDIMP_SLOT), IMPIDIMP_SLOT, 1, IMPIDIMP_UID, IMPIDIMP_EFFECT_ID) \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), SNORUNT_A_SLOT), SNORUNT_A_SLOT, 11, SNORUNT_UID, SNORUNT_EFFECT_ID) \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), SNORUNT_B_SLOT), SNORUNT_B_SLOT, 10, SNORUNT_UID, SNORUNT_EFFECT_ID)


func _post_retreat_own_board(own: Dictionary) -> bool:
	var active: Dictionary = own.get("active", {})
	var mover := _slot_by_id(own.get("bench", []), MUNKIDORI_SLOT)
	return _slot_card_matches(active, IMPIDIMP_SLOT, 1, IMPIDIMP_UID, IMPIDIMP_EFFECT_ID) \
		and _slot_card_matches(mover, MUNKIDORI_SLOT, 9, MUNKIDORI_UID, MUNKIDORI_EFFECT_ID) \
		and _count_energy_symbol(mover.get("energy", []), "D") == 1 \
		and _card_matches(mover.get("tool", {}), RESCUE_BOARD_UID, RESCUE_BOARD_EFFECT_ID) \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), SNORUNT_A_SLOT), SNORUNT_A_SLOT, 11, SNORUNT_UID, SNORUNT_EFFECT_ID) \
		and _slot_card_matches(_slot_by_id(own.get("bench", []), SNORUNT_B_SLOT), SNORUNT_B_SLOT, 10, SNORUNT_UID, SNORUNT_EFFECT_ID)


func _attackless_locked_iron_hands(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var slot: Dictionary = value as Dictionary
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	return _slot_card_matches(slot, IRON_HANDS_ACTIVE_SLOT, 58, IRON_HANDS_UID, IRON_HANDS_EFFECT_ID) \
		and int(slot.get("remaining_hp", 0)) == 230 \
		and int(slot.get("printed_retreat_cost", -1)) == 4 \
		and int(slot.get("effective_retreat_cost", -1)) == 4 \
		and _count_energy_symbol(slot.get("energy", []), "L") == 1 \
		and _attacks_match(pokemon.get("attacks", []), ["LLC", "LCCC"]) \
		and not _any_attack_payable(pokemon.get("attacks", []), slot.get("energy", []))


func _ready_raikou(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var slot: Dictionary = value as Dictionary
	var pokemon: Dictionary = slot.get("pokemon", {}) if slot.get("pokemon", {}) is Dictionary else {}
	return _slot_card_matches(slot, RAIKOU_SLOT, 47, RAIKOU_UID, RAIKOU_EFFECT_ID) \
		and int(slot.get("remaining_hp", 0)) == 200 \
		and _count_energy_symbol(slot.get("energy", []), "L") == 3 \
		and _attacks_match(pokemon.get("attacks", []), ["LC"]) \
		and _any_attack_payable(pokemon.get("attacks", []), slot.get("energy", []))


func _opponent_bench_identity(bench_value: Variant) -> bool:
	if not (bench_value is Array) or (bench_value as Array).size() != 3:
		return false
	var bench: Array = bench_value as Array
	return _slot_card_matches(_slot_by_id(bench, IRON_HANDS_BENCH_SLOT), IRON_HANDS_BENCH_SLOT, 57, IRON_HANDS_UID, IRON_HANDS_EFFECT_ID) \
		and _slot_card_matches(_slot_by_id(bench, MIRAIDON_SLOT), MIRAIDON_SLOT, 14, MIRAIDON_UID, "fixture:exact-miraidon-effect") \
		and _ready_raikou(_slot_by_id(bench, RAIKOU_SLOT))


func _same_opponent_board(left_value: Variant, right_value: Variant) -> bool:
	if not (left_value is Dictionary) or not (right_value is Dictionary):
		return false
	var left: Dictionary = (left_value as Dictionary).duplicate(true)
	var right: Dictionary = (right_value as Dictionary).duplicate(true)
	return ContractsScript.stable_hash(left) == ContractsScript.stable_hash(right)


func _exact_second_catcher_action(action: Dictionary) -> bool:
	if action.is_empty():
		return false
	var card: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
	var steps: Array = action.get("interaction_steps", []) if action.get("interaction_steps", []) is Array else []
	if steps.size() != 1 or not (steps[0] is Dictionary):
		return false
	var step: Dictionary = steps[0]
	return str(action.get("candidate_id", "")) == RULE_GUST_CANDIDATE_ID \
		and str(action.get("kind", "")) == "play_trainer" \
		and int(action.get("card_instance_id", -1)) == SECOND_COUNTER_CATCHER_INSTANCE \
		and _card_matches(card, COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, SECOND_COUNTER_CATCHER_INSTANCE) \
		and str(step.get("id", "")) == "opponent_bench_target" \
		and int(step.get("min_select", -1)) == 1 \
		and int(step.get("max_select", -1)) == 1 \
		and (step.get("public_items", []) as Array) == [IRON_HANDS_BENCH_SLOT, MIRAIDON_SLOT, RAIKOU_SLOT] \
		and str(action.get("rule_selected_target_slot_id", "")) == RAIKOU_SLOT \
		and int(action.get("rule_selected_target_instance_id", -1)) == 47


func _manifest_contract(manifest: Dictionary) -> bool:
	if int(manifest.get("deck_id", 0)) != DECK_ID \
			or str(manifest.get("deck_content_fingerprint", "")) != EXPECTED_DECK_FINGERPRINT:
		return false
	var expected := {
		COUNTER_CATCHER_UID: COUNTER_CATCHER_EFFECT_ID,
		MUNKIDORI_UID: MUNKIDORI_EFFECT_ID,
		IMPIDIMP_UID: IMPIDIMP_EFFECT_ID,
		SNORUNT_UID: SNORUNT_EFFECT_ID,
		DARKNESS_UID: DARKNESS_EFFECT_ID,
		RESCUE_BOARD_UID: RESCUE_BOARD_EFFECT_ID,
		FROSLASS_UID: FROSLASS_EFFECT_ID,
		MORGREM_UID: MORGREM_EFFECT_ID,
		RARE_CANDY_UID: RARE_CANDY_EFFECT_ID,
		ARVEN_UID: ARVEN_EFFECT_ID,
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


func _apply_mutation(
	sequence: Array[Dictionary],
	profile: Dictionary,
	manifest: Dictionary,
	kind: String
) -> void:
	var root := sequence[0]
	var post := sequence[1]
	match kind:
		"wrong_deck_id": root["provenance"]["deck_id"] = DECK_ID + 1
		"wrong_deck_fingerprint": root["provenance"]["deck_content_fingerprint"] = "wrong"
		"wrong_trace_hash": root["observation_hash"] = "wrong"
		"hash_reused": post["observation_hash"] = TRACE_OBSERVATION_HASH
		"wrong_turn": post["turn"]["number"] = 8
		"wrong_current_player": root["turn"]["current_player"] = 1
		"wrong_viewer": root["turn"]["viewer"] = 1
		"wrong_phase": root["turn"]["phase"] = int(GameState.GamePhase.ATTACK)
		"opponent_hand_leak": post["opponent"]["hand"] = [_card("hidden", "hidden", "Pokemon")]
		"opponent_deck_leak": post["opponent"]["deck_cards"] = [_card("hidden", "hidden", "Pokemon")]
		"opponent_prize_leak": post["opponent"]["prize_cards"] = [_card("hidden", "hidden", "Pokemon")]
		"own_prize_leak": post["own"]["prize_cards"] = [_card("hidden", "hidden", "Pokemon")]
		"belief_leak": post["belief"] = {"deck_order": [COUNTER_CATCHER_UID]}
		"wrong_rule_action": root["legal_actions"][0]["id"] = "action:wrong"
		"wrong_rule_candidate": root["legal_actions"][0]["candidate_id"] = "candidate:wrong"
		"wrong_catcher_uid": root["legal_actions"][0]["card"]["uid"] = "wrong"
		"wrong_catcher_effect": root["legal_actions"][0]["card"]["effect_id"] = "wrong"
		"wrong_catcher_instance": root["legal_actions"][0]["card_instance_id"] = 37
		"catcher_missing": root["own"]["hand"].remove_at(2)
		"duplicate_catcher": root["own"]["hand"].append(_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Item", SECOND_COUNTER_CATCHER_INSTANCE))
		"first_catcher_missing_discard": root["own"]["discard"].clear()
		"not_behind_on_prizes": root["own"]["prizes_remaining"] = 5
		"wrong_iron_uid": root["opponent"]["active"]["pokemon"]["uid"] = "wrong"
		"wrong_iron_effect": root["opponent"]["active"]["pokemon"]["effect_id"] = "wrong"
		"wrong_iron_slot": root["opponent"]["active"]["slot_id"] = "slot:59"
		"iron_extra_energy": root["opponent"]["active"]["energy"].append(_energy(LIGHTNING_UID, "fixture:lightning-energy", "L", 999))
		"iron_attack_cost_changed": root["opponent"]["active"]["pokemon"]["attacks"][0]["cost"] = "L"
		"iron_retreat_unlocked": root["opponent"]["active"]["effective_retreat_cost"] = 1
		"wrong_raikou_uid": _slot_by_id(root["opponent"]["bench"], RAIKOU_SLOT)["pokemon"]["uid"] = "wrong"
		"wrong_raikou_effect": _slot_by_id(root["opponent"]["bench"], RAIKOU_SLOT)["pokemon"]["effect_id"] = "wrong"
		"wrong_raikou_slot": _slot_by_id(root["opponent"]["bench"], RAIKOU_SLOT)["pokemon"]["instance_id"] = 48
		"raikou_energy_missing": _slot_by_id(root["opponent"]["bench"], RAIKOU_SLOT)["energy"].clear()
		"raikou_cost_changed": _slot_by_id(root["opponent"]["bench"], RAIKOU_SLOT)["pokemon"]["attacks"][0]["cost"] = "WW"
		"own_attack_added": root["legal_actions"].append({"id": "action:attack", "kind": "attack", "projected_knockout": false})
		"own_ko_added": root["public_outcome"]["own_ko_available"] = true
		"wrong_munkidori_uid": root["own"]["active"]["pokemon"]["uid"] = "wrong"
		"wrong_munkidori_effect": root["own"]["active"]["pokemon"]["effect_id"] = "wrong"
		"wrong_munkidori_slot": root["own"]["active"]["slot_id"] = "slot:8"
		"darkness_missing": root["own"]["active"]["energy"].clear()
		"rescue_board_missing": root["own"]["active"]["tool"] = {}
		"retreat_quota_closed": root["turn"]["quotas"]["retreat_available"] = false
		"retreat_missing": root["legal_actions"].remove_at(1)
		"retreat_target_changed": root["legal_actions"][1]["target"] = SNORUNT_A_SLOT
		"retreat_action_changed": root["legal_actions"][1]["id"] = "action:wrong-retreat"
		"event_failed": post["event"]["success"] = false
		"event_mismatch": post["event"]["action_id"] = "action:wrong"
		"post_opponent_changed": post["opponent"]["active"] = post["opponent"]["bench"][2]
		"post_catcher_consumed": post["own"]["hand"].remove_at(2)
		"post_active_changed": post["own"]["active"] = _snorunt_slot(SNORUNT_A_SLOT, 11)
		"post_munkidori_missing": post["own"]["bench"].remove_at(0)
		"post_darkness_moved": post["own"]["bench"][0]["energy"].clear()
		"post_tool_moved": post["own"]["bench"][0]["tool"] = {}
		"post_deck_count_changed": post["own"]["deck_count"] = 26
		"post_hand_count_changed": post["own"]["hand_count"] = 4
		"post_bench_changed": post["opponent"]["bench"].remove_at(0)
		"post_turn_changed": post["turn"]["number"] = 8
		"post_retreat_still_available": post["turn"]["quotas"]["retreat_available"] = true
		"end_missing": post["legal_actions"].remove_at(1)
		"end_action_changed": post["legal_actions"][1]["id"] = "action:wrong-end"
		"interaction_min_changed": root["legal_actions"][0]["interaction_steps"][0]["min_select"] = 0
		"interaction_max_changed": root["legal_actions"][0]["interaction_steps"][0]["max_select"] = 2
		"interaction_target_changed": root["legal_actions"][0]["rule_selected_target_slot_id"] = MIRAIDON_SLOT
		"profile_fingerprint": profile["expected_regret_threshold"] = float(profile.get("expected_regret_threshold", 0.0)) + 1.0
		"module_composition": profile["modules"] = ["stage2_chain", "energy_burst"]
		"payable_gust_safety": profile["safety"]["require_payable_ko_before_gust"] = false
		"manifest_effect":
			for raw_card: Variant in manifest.get("cards", []):
				if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == COUNTER_CATCHER_UID:
					(raw_card as Dictionary)["effect_id"] = "wrong"
					break


func _engine_fixture() -> Dictionary:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 7
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	state.energy_attached_this_turn = false
	state.retreat_used_this_turn = false
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)

	var own: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var munkidori := _engine_pokemon(MUNKIDORI_UID, MUNKIDORI_EFFECT_ID, "Munkidori", 110, 1, [{"name": "Mind Bend", "cost": "PC", "damage": "60", "text": ""}], 9, 0)
	var impidimp := _engine_pokemon(IMPIDIMP_UID, IMPIDIMP_EFFECT_ID, "Impidimp", 70, 1, [{"name": "Push", "cost": "D", "damage": "10", "text": ""}], 1, 0)
	var snorunt_a := _engine_pokemon(SNORUNT_UID, SNORUNT_EFFECT_ID, "Snorunt", 60, 1, [{"name": "Astonish", "cost": "WC", "damage": "20", "text": ""}], 11, 0)
	var snorunt_b := _engine_pokemon(SNORUNT_UID, SNORUNT_EFFECT_ID, "Snorunt", 60, 1, [{"name": "Astonish", "cost": "WC", "damage": "20", "text": ""}], 10, 0)
	var darkness := _engine_card(DARKNESS_UID, DARKNESS_EFFECT_ID, "Darkness Energy", "Basic Energy", 29, 0)
	darkness.card_data.energy_provides = "D"
	var rescue_board := _engine_card(RESCUE_BOARD_UID, RESCUE_BOARD_EFFECT_ID, "Rescue Board", "Tool", 30, 0)
	munkidori.attached_energy = [darkness]
	munkidori.attached_tool = rescue_board
	own.active_pokemon = munkidori
	own.bench = [impidimp, snorunt_a, snorunt_b]

	var first_catcher := _engine_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Counter Catcher", "Item", FIRST_COUNTER_CATCHER_INSTANCE, 0)
	var second_catcher := _engine_card(COUNTER_CATCHER_UID, COUNTER_CATCHER_EFFECT_ID, "Counter Catcher", "Item", SECOND_COUNTER_CATCHER_INSTANCE, 0)
	own.hand = [second_catcher]
	own.discard_pile = [first_catcher]
	_fill_engine_cards(own.prizes, 6, "OWN_PRIZE", 0)

	var iron_hands_active := _engine_pokemon(IRON_HANDS_UID, IRON_HANDS_EFFECT_ID, "Iron Hands ex", 230, 4, [
		{"name": "Arm Press", "cost": "LLC", "damage": "160", "text": ""},
		{"name": "Amp You Very Much", "cost": "LCCC", "damage": "120", "text": ""},
	], 58, 1, "ex")
	var iron_hands_bench := _engine_pokemon(IRON_HANDS_UID, IRON_HANDS_EFFECT_ID, "Iron Hands ex", 230, 4, [], 57, 1, "ex")
	var miraidon := _engine_pokemon(MIRAIDON_UID, "fixture:exact-miraidon-effect", "Miraidon ex", 220, 1, [], 14, 1, "ex")
	var raikou := _engine_pokemon(RAIKOU_UID, RAIKOU_EFFECT_ID, "Raikou V", 200, 1, [
		{"name": "Lightning Rondo", "cost": "LC", "damage": "20+", "text": ""},
	], 47, 1, "V")
	iron_hands_active.attached_energy = [_engine_lightning(120)]
	raikou.attached_energy = [_engine_lightning(121), _engine_lightning(122), _engine_lightning(123)]
	opponent.active_pokemon = iron_hands_active
	opponent.bench = [iron_hands_bench, miraidon, raikou]
	_fill_engine_cards(opponent.prizes, 5, "OPPONENT_PRIZE", 1)

	var gsm := GameStateMachine.new()
	gsm.game_state = state
	return {
		"gsm": gsm,
		"state": state,
		"munkidori": munkidori,
		"impidimp": impidimp,
		"iron_hands_active": iron_hands_active,
		"raikou": raikou,
		"second_catcher": second_catcher,
	}


func _engine_pokemon(
	uid: String,
	effect_id: String,
	name: String,
	hp: int,
	retreat_cost: int,
	attacks: Array,
	instance_id: int,
	owner: int,
	mechanic: String = ""
) -> PokemonSlot:
	var data := CardData.new()
	var parts := uid.split("_")
	data.set_code = str(parts[0])
	data.card_index = str(parts[1]) if parts.size() > 1 else uid
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.effect_id = effect_id
	data.hp = hp
	data.retreat_cost = retreat_cost
	data.mechanic = mechanic
	var typed_attacks: Array[Dictionary] = []
	for raw_attack: Variant in attacks:
		if raw_attack is Dictionary:
			typed_attacks.append((raw_attack as Dictionary).duplicate(true))
	data.attacks = typed_attacks
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


func _engine_lightning(instance_id: int) -> CardInstance:
	var energy := _engine_card(LIGHTNING_UID, "fixture:lightning-energy", "Lightning Energy", "Basic Energy", instance_id, 1)
	energy.card_data.energy_provides = "L"
	return energy


func _fill_engine_cards(target: Array, count: int, prefix: String, owner: int) -> void:
	for index: int in count:
		target.append(_engine_card("FIXTURE_%d" % index, "fixture:%s:%d" % [prefix, index], "%s_%d" % [prefix, index], "Item", 200 + owner * 20 + index, owner))


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


func _count_energy_symbol(energy_value: Variant, symbol: String) -> int:
	if not (energy_value is Array):
		return 0
	var count := 0
	for raw_energy: Variant in energy_value as Array:
		if raw_energy is Dictionary and str((raw_energy as Dictionary).get("energy_provides", "")) == symbol:
			count += 1
	return count


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
