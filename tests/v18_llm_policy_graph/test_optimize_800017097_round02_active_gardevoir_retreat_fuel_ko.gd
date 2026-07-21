extends SceneTree

## Focused RED for seed 800017098, game 2, turn 6 of bundled deck 800017097.
##
## The captured Rule branch manually attaches one of two hand Psychic Energy to the
## Bench Drifloon and never attacks.  The missing certificate is a strictly
## public, resource-conserving four-observation suffix:
##
##   manual Psychic -> Active Gardevoir ex
##   action_resolved -> Psychic Embrace -> Active Gardevoir ex
##   action_resolved -> Psychic Embrace -> Active Gardevoir ex
##   action_resolved -> Miracle Force for 190, KO 160-HP Squawkabilly ex
##
## The line owns exactly five visible Psychic Energy at every checkpoint:
## two in hand plus three in discard initially, then three on Active, one in
## hand, and one in discard. It never invents discard Energy, reads hidden state,
## or opens another model request.  The focused contract stays local and
## deterministic; no formal model request is executed by this regression.

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800017097
const DECK_PATH := "res://data/bundled_user/decks/800017097.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800017097.json"
const GARDEVOIR_CARD_PATH := "res://data/bundled_user/cards/CSV2C_055.json"
const SQUAWKABILLY_CARD_PATH := "res://data/bundled_user/cards/CSV2C_105.json"
const EXPECTED_DECK_FINGERPRINT := "98f27aebdb2b8eeb4f449191b519a049eba0e11b108323264ea84bd6a3fdce63"
const EXPECTED_MANIFEST_HASH := "5556f2a1d21d5d9d3c82a8ff6f252007a4e5a391aef709ef1bc0889690e71a7a"
const EXPECTED_PROFILE_FINGERPRINT := "c04bb5a7c0c5b92822040c78f1fef0edb707db50226ec58f6497e5174f930a9c"
const EXPECTED_MODULES := ["gardevoir_embrace", "damage_counter_control"]
const EXPECTED_CERTIFICATE := "profiled_visible_engine_hold"
const EXPECTED_TARGET_CERTIFICATE := "public_profiled_active_gardevoir_ko_suffix_target"

const GARDEVOIR_UID := "CSV2C_055"
const GARDEVOIR_EFFECT := "bd134d7d84e9f1a837a74b061fcb5f40"
const SQUAWKABILLY_UID := "CSV2C_105"
const SQUAWKABILLY_EFFECT := "1b951205e53e179bde0905c4a194d9ee"
const PSYCHIC_UID := "CSVE1C_PSY"
const PSYCHIC_EFFECT := "41b2d1a95fafc35e4cf39383ffae928a"
const DARKNESS_UID := "CSVE1C_DAR"
const DARKNESS_EFFECT := "46c769fc57a6c250c560df648bb779f8"
const ULTRA_BALL_UID := "CSV1C_112"
const ULTRA_BALL_EFFECT := "a337ed34a45e63c6d21d98c3d8e0cb6e"
const RARE_CANDY_UID := "CSVH1C_045"
const RARE_CANDY_EFFECT := "public:rare-candy"
const NEST_BALL_UID := "CSVH1C_043"
const NEST_BALL_EFFECT := "public:nest-ball"
const DRIFLOON_UID := "CSV2C_060"
const DRIFLOON_EFFECT := "8e295bb9597fb1ebbc2c6d58a98e0839"
const MUNKIDORI_UID := "CSV8C_094"
const MUNKIDORI_EFFECT := "66fee12502043db7d92b97b0d62b0f59"
const CLEFFA_UID := "CSV4C_044"
const CLEFFA_EFFECT := "5bb7158b704f6d30d43c8f68cc52f39c"
const BUDEW_UID := "CSV9.5C_004"
const BUDEW_EFFECT := "28505a8ad6e07e74382c1b5e09737932"
const ZAPDOS_UID := "CS6aC_057"
const ZAPDOS_EFFECT := "03bcecb40c957575e16b4af22b08b7bd"
const FEZANDIPITI_UID := "CSV8C_135"
const FEZANDIPITI_EFFECT := "ab6c3357e2b8a8385a68da738f41e0c1"
const IRON_HANDS_UID := "CSV6C_051"
const IRON_HANDS_EFFECT := "e9f0c124fc2e352af2408a7e61862b95"
const LUMINEON_UID := "CS5bC_049"
const LUMINEON_EFFECT := "553639840a44f19ad83b89a892a21f98"

const ACTIVE_SLOT := "slot:6"
const DRIFLOON_SLOT := "slot:13"
const DARK_MUNKIDORI_SLOT := "slot:9"
const PLAIN_MUNKIDORI_SLOT := "slot:8"
const CLEFFA_SLOT := "slot:15"
const BUDEW_SLOT := "slot:14"
const OPPONENT_ACTIVE_SLOT := "slot:8"

const ATTACH_DRIF_ACTION := "action:attach_energy:51:-:13:-1:-1"
const ATTACH_ACTIVE_ACTION := "action:attach_energy:51:-:6:-1:-1"
const EMBRACE_ACTION := "action:use_ability:-:6:-:-1:0"
const MUNKIDORI_ACTION := "action:use_ability:-:9:-:-1:0"
const ATTACK_ACTION := "action:attack:-:6:-:0:-1"
const ULTRA_BALL_ACTION := "action:play_trainer:30:-:-:-1:-1"
const END_ACTION := "action:end_turn:-:-:-:-1:-1"
const PRIOR_EVOLVE_ACTION := "action:evolve:6:-:6:-1:-1"
const PRIOR_EVOLVE_CANDIDATE := "candidate:fd55d051dd88842667f6"

const RULE_ATTACH_CANDIDATE := "candidate:e85a04b542f7fbd881f4"
const ATTACH_ACTIVE_CANDIDATE := "candidate:focused-attach-active"
const EMBRACE_CANDIDATE := "candidate:focused-embrace-active"
const RULE_MUNKIDORI_CANDIDATE := "candidate:focused-rule-munkidori"
const ATTACK_CANDIDATE := "candidate:focused-active-gardevior-attack"

const TRACE_VERSIONS := [40, 42, 44, 46]
const TRACE_HASHES := [
	"3210cc606239c017bccdbb3baf80e5e15fc06ba9c4b1216465585edd9fe9eea9",
	"counterfactual:800017097:seed800017098:t6:o42:attach-active",
	"counterfactual:800017097:seed800017098:t6:o44:embrace-active-1",
	"counterfactual:800017097:seed800017098:t6:o46:embrace-active-2",
]

var _failures: Array[String] = []
var _negative_count := 0


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	var manifest := _load_json(MANIFEST_PATH)
	var deck_seed := _load_json(DECK_PATH)
	var deck := DeckData.from_dict(deck_seed)
	var gardevoir_card := _load_json(GARDEVOIR_CARD_PATH)
	var squawkabilly_card := _load_json(SQUAWKABILLY_CARD_PATH)
	var fingerprint := SemanticCompilerScript.deck_content_fingerprint(deck)

	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60,
		"fixture must bind the current exact 60-card bundled_ai deck")
	_check(fingerprint == EXPECTED_DECK_FINGERPRINT
		and fingerprint == str(manifest.get("deck_content_fingerprint", "")),
		"fixture and manifest must bind the current deck fingerprint")
	_check(bool(_validate_static_contract(profile, manifest).get("valid", false)),
		"fixture must bind the current profile/manifest version hashes; actual_profile=%s" % ContractsScript.stable_hash(profile))
	_check(_printed_card_contract(gardevoir_card, squawkabilly_card),
		"printed Gardevoir/Squawkabilly HP, effect, attack index, cost, and damage drifted")

	var positive := _sequence_contract(_base_sequence(), profile, manifest)
	_check(bool(positive.get("accepted", false)),
		"seed800017098 t6 must attach Psychic to Active Gardevoir -> two reobserved Embrace assignments to Active -> Miracle Force 190 KO on 160-HP Squawkabilly with one model request; blockers=%s" % str(positive.get("reason", "unknown")))

	_test_fail_closed_boundaries(profile, manifest)
	_test_observation_version_invariance(profile, manifest)
	_check(_negative_count >= 25,
		"focused RED must prove at least twenty-five independent fail-closed boundaries")

	if _failures.is_empty():
		print("V18CPG 800017097 Active Gardevoir retreat-fuel KO focused regression: PASS (%d boundaries)" % _negative_count)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800017097 Active Gardevoir retreat-fuel KO focused regression: FAIL (%d failure, %d negative boundaries passed)" % [_failures.size(), _negative_count])
	quit(1)


func _sequence_contract(
	sequence: Array[Dictionary],
	profile: Dictionary,
	manifest: Dictionary
) -> Dictionary:
	var blockers: Array[String] = []
	var static_contract := _validate_static_contract(profile, manifest)
	if not bool(static_contract.get("valid", false)):
		blockers.append(str(static_contract.get("reason", "static_contract")))
	var shape := _validate_public_sequence_shape(sequence)
	if not bool(shape.get("valid", false)):
		blockers.append(str(shape.get("reason", "public_sequence_shape")))
	if not blockers.is_empty():
		return _rejected(";".join(blockers))

	var strategy := StrategyScript.new()
	strategy.configure_profile(profile, manifest)
	strategy.configure_verified_local_only_for_benchmark()
	# Request #1 supplied the conditional suffix.  Everything below is local
	# certificate validation after a fresh public observation.
	strategy._turn_model_requests = 1
	var registry := CapabilityRegistryScript.new()
	var annotated: Array[Array] = []
	for epoch: int in sequence.size():
		annotated.append(registry.annotate_frontier(
			_frontier_for_epoch(epoch), sequence[epoch], _facts_for_epoch(epoch), profile, manifest
		))

	var root_target := _candidate(annotated[0], ATTACH_ACTIVE_CANDIDATE)
	var root_annotation := _suffix_annotation(root_target)
	if str(root_annotation.get("stage", "")) != "manual_psychic_to_active":
		blockers.append("root_suffix_annotation_missing")
	var root_safety := strategy._validate_model_route_safety(
		"route:energy_commit", annotated[0], _facts_for_epoch(0), ATTACH_ACTIVE_CANDIDATE
	)
	if not bool(root_safety.get("valid", false)) \
			or str(root_safety.get("advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE:
		blockers.append("root_attach_not_certified:%s" % str(root_safety.get("reason", "unknown")))
	var root_upgrade := root_target.duplicate(true)
	root_upgrade["verified_advantage"] = root_safety.get("advantage", {})
	strategy._activate_verified_upgrade_certificate(root_upgrade)

	var first_embrace := _candidate(annotated[1], EMBRACE_CANDIDATE)
	var first_gate := strategy._should_use_local(annotated[1], _facts_for_epoch(1))
	if not bool(first_gate.get("use_local", false)) \
			or float(first_gate.get("expected_regret", -1.0)) != 110.0:
		blockers.append("first_embrace_would_open_second_model_request")
	var first_safety := strategy._validate_model_route_safety(
		"route:information", annotated[1], _facts_for_epoch(1), EMBRACE_CANDIDATE
	)
	if not bool(first_safety.get("valid", false)) \
			or str(first_safety.get("reason", "")) != "matches_rules_floor":
		blockers.append("first_embrace_not_rule_floor")
	if str(_suffix_annotation(first_embrace).get("stage", "")) != "first_embrace_to_active":
		blockers.append("first_embrace_suffix_annotation_missing")
	var first_upgrade := strategy._find_module_verified_upgrade(annotated[1], _facts_for_epoch(1))
	if str(first_upgrade.get("candidate_id", "")) != EMBRACE_CANDIDATE \
			or str(first_upgrade.get("verified_advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE:
		blockers.append("first_embrace_continuation_not_certified")
	strategy._activate_verified_upgrade_certificate(first_upgrade)
	if not _interaction_targets_active(sequence[1], profile, manifest, registry):
		blockers.append("first_embrace_target_not_certified")
	if not _strategy_interaction_targets_active(
		strategy, annotated[1], sequence[1], _facts_for_epoch(1)
	):
		blockers.append("first_embrace_strategy_bridge_not_certified")

	var second_upgrade := strategy._find_module_verified_upgrade(annotated[2], _facts_for_epoch(2))
	if str(second_upgrade.get("candidate_id", "")) != EMBRACE_CANDIDATE \
			or str(second_upgrade.get("verified_advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE \
			or str(_suffix_annotation(_candidate(annotated[2], EMBRACE_CANDIDATE)).get("stage", "")) != "second_embrace_to_active":
		blockers.append("second_embrace_not_certified")
	strategy._activate_verified_upgrade_certificate(second_upgrade)
	if not _interaction_targets_active(sequence[2], profile, manifest, registry):
		blockers.append("second_embrace_target_not_certified")
	if not _strategy_interaction_targets_active(
		strategy, annotated[2], sequence[2], _facts_for_epoch(2)
	):
		blockers.append("second_embrace_strategy_bridge_not_certified")

	var attack_upgrade := strategy._find_module_verified_upgrade(annotated[3], _facts_for_epoch(3))
	if str(attack_upgrade.get("candidate_id", "")) != ATTACK_CANDIDATE \
			or str(attack_upgrade.get("verified_advantage", {}).get("certificate_kind", "")) != EXPECTED_CERTIFICATE \
			or str(_suffix_annotation(_candidate(annotated[3], ATTACK_CANDIDATE)).get("stage", "")) != "active_gardevoir_190_ko":
		blockers.append("active_gardevoir_attack_not_certified")

	if strategy._turn_model_requests != 1:
		blockers.append("checkpoint_opened_extra_model_request")
	if not blockers.is_empty():
		return _rejected(";".join(blockers))
	return {
		"accepted": true,
		"reason": "",
		"certificate_kind": EXPECTED_CERTIFICATE,
		"model_calls": 1,
		"reobservations": 3,
	}


func _test_fail_closed_boundaries(profile: Dictionary, manifest: Dictionary) -> void:
	var sequence_cases: Array[Dictionary] = [
		{"kind": "wrong_deck_id", "label": "deck identity changed"},
		{"kind": "wrong_deck_fingerprint", "label": "deck fingerprint changed"},
		{"kind": "wrong_manifest_hash", "label": "observation manifest hash changed"},
		{"kind": "wrong_profile_hash", "label": "observation profile hash changed"},
		{"kind": "wrong_profile_version", "label": "observation profile version changed"},
		{"kind": "wrong_semantic_version", "label": "observation semantic version changed"},
		{"kind": "wrong_observation_version", "label": "observation epoch version changed"},
		{"kind": "wrong_observation_hash", "label": "observation hash changed"},
		{"kind": "reused_observation_hash", "label": "material checkpoint reused a hash"},
		{"kind": "root_event_missing", "label": "production prior evolve action result missing"},
		{"kind": "root_event_kind_changed", "label": "production prior event kind changed"},
		{"kind": "root_prior_action_changed", "label": "production prior evolve action changed"},
		{"kind": "root_prior_candidate_changed", "label": "production prior evolve candidate changed"},
		{"kind": "root_prior_action_kind_changed", "label": "production prior evolve kind changed"},
		{"kind": "root_prior_route_changed", "label": "production prior evolve route changed"},
		{"kind": "root_prior_target_changed", "label": "production prior evolve target changed"},
		{"kind": "root_prior_failed", "label": "production prior evolve failed"},
		{"kind": "wrong_turn", "label": "turn number changed"},
		{"kind": "wrong_current_player", "label": "current player changed"},
		{"kind": "wrong_viewer", "label": "viewer changed"},
		{"kind": "wrong_phase", "label": "decision left MAIN"},
		{"kind": "opponent_hand_leak", "label": "opponent hidden hand leaked"},
		{"kind": "opponent_deck_leak", "label": "opponent hidden deck identities leaked"},
		{"kind": "opponent_prize_leak", "label": "opponent hidden prizes leaked"},
		{"kind": "own_prize_leak", "label": "own hidden prizes leaked"},
		{"kind": "belief_leak", "label": "belief/deck order leaked"},
		{"kind": "wrong_gardevoir_uid", "label": "Active Gardevoir UID changed"},
		{"kind": "wrong_gardevoir_effect", "label": "Active Gardevoir effect changed"},
		{"kind": "wrong_gardevoir_slot", "label": "Active Gardevoir instance changed"},
		{"kind": "wrong_attack_cost", "label": "Miracle Force printed cost changed"},
		{"kind": "wrong_attack_damage", "label": "Miracle Force printed damage changed"},
		{"kind": "wrong_squawk_uid", "label": "opponent Active UID changed"},
		{"kind": "wrong_squawk_effect", "label": "opponent Active effect changed"},
		{"kind": "wrong_squawk_hp", "label": "opponent Active HP changed"},
		{"kind": "squawk_energy_added", "label": "opponent Active Energy changed"},
		{"kind": "squawk_prize_changed", "label": "opponent Active prize value changed"},
		{"kind": "squawk_reaction_added", "label": "opponent reaction effect appeared"},
		{"kind": "wrong_own_prizes", "label": "own prizes changed"},
		{"kind": "wrong_opponent_prizes", "label": "opponent prizes changed"},
		{"kind": "wrong_deck_count", "label": "own deck count changed"},
		{"kind": "supporter_available", "label": "spent Iono quota reopened"},
		{"kind": "energy_quota_spent_root", "label": "manual attachment quota unavailable"},
		{"kind": "energy_quota_reopened", "label": "manual attachment quota reopened later"},
		{"kind": "psychic_hand_missing", "label": "manual Psychic missing from hand"},
		{"kind": "psychic_hand_duplicate", "label": "manual Psychic is not unique"},
		{"kind": "ultra_ball_missing", "label": "post-Iono Ultra Ball changed"},
		{"kind": "discard_psychic_two", "label": "initial discard has only two Psychic"},
		{"kind": "discard_psychic_four", "label": "synthetic fourth discard Psychic appeared"},
		{"kind": "final_discard_zero", "label": "final discard failed to retain one Psychic"},
		{"kind": "resource_total_changed", "label": "visible Psychic conservation changed"},
		{"kind": "active_precharged", "label": "Active began with Energy"},
		{"kind": "active_damage_root", "label": "Active began damaged"},
		{"kind": "first_embrace_damage_wrong", "label": "first Embrace damage changed"},
		{"kind": "second_embrace_damage_wrong", "label": "second Embrace damage changed"},
		{"kind": "first_embrace_knockout", "label": "first Embrace would KO Active"},
		{"kind": "second_embrace_knockout", "label": "second Embrace would KO Active"},
		{"kind": "drifloon_missing", "label": "Drifloon Bench identity changed"},
		{"kind": "drifloon_charged", "label": "Drifloon unexpectedly gained Energy"},
		{"kind": "bench_extra", "label": "Bench uniqueness changed"},
		{"kind": "dark_munkidori_missing", "label": "Darkness Munkidori changed"},
		{"kind": "plain_munkidori_missing", "label": "second Munkidori changed"},
		{"kind": "attach_missing", "label": "Active attachment candidate missing"},
		{"kind": "attach_duplicate", "label": "Active attachment candidate duplicated"},
		{"kind": "attach_wrong_target", "label": "manual attachment target changed"},
		{"kind": "attach_wrong_energy", "label": "manual attachment Energy changed"},
		{"kind": "attach_event_failed", "label": "manual attachment failed"},
		{"kind": "attach_event_mismatch", "label": "manual attachment acknowledgement changed"},
		{"kind": "embrace_missing", "label": "Psychic Embrace action missing"},
		{"kind": "embrace_duplicate", "label": "Psychic Embrace action not unique"},
		{"kind": "embrace_source_changed", "label": "Psychic Embrace source changed"},
		{"kind": "embrace_interaction_changed", "label": "Psychic Embrace interaction cardinality changed"},
		{"kind": "embrace_event_failed", "label": "Psychic Embrace failed"},
		{"kind": "embrace_event_mismatch", "label": "Psychic Embrace acknowledgement changed"},
		{"kind": "embrace_target_changed", "label": "Psychic Embrace target changed"},
		{"kind": "attack_missing", "label": "Miracle Force action missing"},
		{"kind": "attack_duplicate", "label": "Miracle Force action not unique"},
		{"kind": "attack_source_changed", "label": "Miracle Force source changed"},
		{"kind": "attack_index_changed", "label": "Miracle Force attack index changed"},
		{"kind": "attack_action_cost_changed", "label": "Miracle Force action cost changed"},
		{"kind": "attack_projection_changed", "label": "Miracle Force projection changed"},
		{"kind": "attack_ko_false", "label": "Miracle Force KO proof changed"},
		{"kind": "active_special_condition", "label": "Active gained an attack-blocking condition"},
	]
	for spec: Dictionary in sequence_cases:
		var mutated := _base_sequence()
		_apply_sequence_mutation(mutated, str(spec.get("kind", "")))
		var result := _validate_public_sequence_shape(mutated)
		_check(not bool(result.get("valid", false)),
			"%s must fail closed" % str(spec.get("label", "invalid public state")))
		_negative_count += 1

	for spec: Dictionary in [
		{"kind": "production_profile_hash", "label": "production profile fingerprint changed"},
		{"kind": "production_profile_version", "label": "production profile version changed"},
		{"kind": "production_semantic_version", "label": "production semantic version changed"},
		{"kind": "production_modules", "label": "production module composition changed"},
		{"kind": "production_manifest_hash", "label": "production manifest hash changed"},
		{"kind": "production_manifest_effect", "label": "manifest Gardevoir effect changed"},
	]:
		var mutated_profile := profile.duplicate(true)
		var mutated_manifest := manifest.duplicate(true)
		_apply_static_mutation(mutated_profile, mutated_manifest, str(spec.get("kind", "")))
		var result := _validate_static_contract(mutated_profile, mutated_manifest)
		_check(not bool(result.get("valid", false)),
			"%s must fail closed" % str(spec.get("label", "invalid static contract")))
		_negative_count += 1


func _test_observation_version_invariance(profile: Dictionary, manifest: Dictionary) -> void:
	for erase_versions: bool in [false, true]:
		var sequence := _base_sequence()
		var drifted_versions := [40, 44, 1040, 7]
		for epoch: int in sequence.size():
			if erase_versions:
				sequence[epoch].erase("observation_version")
			else:
				sequence[epoch]["observation_version"] = drifted_versions[epoch]
		var registry := CapabilityRegistryScript.new()
		var annotated: Array[Array] = []
		for epoch: int in sequence.size():
			annotated.append(registry.annotate_frontier(
				_frontier_for_epoch(epoch), sequence[epoch], _facts_for_epoch(epoch), profile, manifest
			))
		var stages := [
			"manual_psychic_to_active", "first_embrace_to_active",
			"second_embrace_to_active", "active_gardevoir_190_ko",
		]
		var candidate_ids := [
			ATTACH_ACTIVE_CANDIDATE, EMBRACE_CANDIDATE, EMBRACE_CANDIDATE, ATTACK_CANDIDATE,
		]
		for epoch: int in annotated.size():
			_check(
				str(_suffix_annotation(_candidate(annotated[epoch], candidate_ids[epoch])).get("stage", "")) \
					== stages[epoch],
				"observation_version must remain non-semantic at epoch %d (erase=%s); annotation=%s" % [
					epoch, erase_versions,
					str(_suffix_annotation(_candidate(annotated[epoch], candidate_ids[epoch]))),
				]
			)
		for epoch: int in [0, 2, 3]:
			var verification := registry.verify_route_advantage(
				_candidate(annotated[epoch], candidate_ids[epoch]),
				annotated[epoch][0],
				_facts_for_epoch(epoch),
				profile
			)
			_check(
				bool(verification.get("verified", false)) \
					and str(verification.get("certificate_kind", "")) == EXPECTED_CERTIFICATE,
				"certificate must ignore observation_version provenance at epoch %d (erase=%s)" % [epoch, erase_versions]
			)
		_check(_interaction_targets_active(sequence[1], profile, manifest, registry),
			"first Embrace target must ignore observation_version provenance (erase=%s)" % erase_versions)
		_check(_interaction_targets_active(sequence[2], profile, manifest, registry),
			"second Embrace target must ignore observation_version provenance (erase=%s)" % erase_versions)

	var versionless_profile := profile.duplicate(true)
	var parameters: Dictionary = versionless_profile.get("module_parameters", {})
	var gardevoir_parameters: Dictionary = parameters.get("gardevoir_embrace", {})
	var config: Dictionary = gardevoir_parameters.get("profiled_active_gardevoir_retreat_fuel_ko", {})
	for key: String in [
		"root_observation_version", "post_attach_observation_version",
		"post_first_embrace_observation_version", "post_second_embrace_observation_version",
	]:
		config.erase(key)
	var versionless_sequence := _base_sequence()
	var versionless_registry := CapabilityRegistryScript.new()
	for epoch: int in versionless_sequence.size():
		var annotated := versionless_registry.annotate_frontier(
			_frontier_for_epoch(epoch), versionless_sequence[epoch], _facts_for_epoch(epoch),
			versionless_profile, manifest
		)
		var candidate_id: String = str([
			ATTACH_ACTIVE_CANDIDATE, EMBRACE_CANDIDATE, EMBRACE_CANDIDATE, ATTACK_CANDIDATE,
		][epoch])
		_check(not _suffix_annotation(_candidate(annotated, candidate_id)).is_empty(),
			"deleting profile observation_version provenance keys must not disable epoch %d" % epoch)
	_check(_interaction_targets_active(versionless_sequence[1], versionless_profile, manifest, versionless_registry),
		"deleting profile observation_version provenance keys must preserve first Embrace target")
	_check(_interaction_targets_active(versionless_sequence[2], versionless_profile, manifest, versionless_registry),
		"deleting profile observation_version provenance keys must preserve second Embrace target")


func _validate_static_contract(profile: Dictionary, manifest: Dictionary) -> Dictionary:
	if ContractsScript.stable_hash(profile) != EXPECTED_PROFILE_FINGERPRINT:
		return _invalid("profile_fingerprint")
	if int(profile.get("profile_version", 0)) != 10 \
			or int(profile.get("semantic_version", 0)) != 1 \
			or profile.get("modules", []) != EXPECTED_MODULES:
		return _invalid("profile_version_or_modules")
	if int(manifest.get("deck_id", 0)) != DECK_ID \
			or str(manifest.get("deck_content_fingerprint", "")) != EXPECTED_DECK_FINGERPRINT \
			or str(manifest.get("manifest_hash", "")) != EXPECTED_MANIFEST_HASH \
			or int(manifest.get("semantic_version", 0)) != 1:
		return _invalid("manifest_provenance")
	var expected := {
		GARDEVOIR_UID: GARDEVOIR_EFFECT,
		PSYCHIC_UID: PSYCHIC_EFFECT,
		ULTRA_BALL_UID: ULTRA_BALL_EFFECT,
		DRIFLOON_UID: DRIFLOON_EFFECT,
		MUNKIDORI_UID: MUNKIDORI_EFFECT,
		CLEFFA_UID: CLEFFA_EFFECT,
		BUDEW_UID: BUDEW_EFFECT,
	}
	for uid: String in expected:
		if not _manifest_has(manifest, uid, str(expected[uid])):
			return _invalid("manifest_card:%s" % uid)
	return {"valid": true, "reason": ""}


func _validate_public_sequence_shape(sequence: Array[Dictionary]) -> Dictionary:
	if sequence.size() != 4:
		return _invalid("observation_epoch_count")
	var seen_hashes: Dictionary = {}
	for epoch: int in sequence.size():
		var observation := sequence[epoch]
		if _contains_hidden_information(observation):
			return _invalid("hidden_information_present")
		var provenance: Dictionary = observation.get("provenance", {}) \
			if observation.get("provenance", {}) is Dictionary else {}
		if int(provenance.get("deck_id", 0)) != DECK_ID \
				or str(provenance.get("deck_content_fingerprint", "")) != EXPECTED_DECK_FINGERPRINT \
				or str(provenance.get("manifest_hash", "")) != EXPECTED_MANIFEST_HASH \
				or str(provenance.get("profile_fingerprint", "")) != EXPECTED_PROFILE_FINGERPRINT \
				or int(provenance.get("profile_version", 0)) != 10 \
				or int(provenance.get("semantic_version", 0)) != 1:
			return _invalid("observation_provenance:%d" % epoch)
		if int(observation.get("observation_version", -1)) != int(TRACE_VERSIONS[epoch]) \
				or str(observation.get("observation_hash", "")) != str(TRACE_HASHES[epoch]):
			return _invalid("observation_identity:%d" % epoch)
		var observation_hash := str(observation.get("observation_hash", ""))
		if observation_hash in seen_hashes:
			return _invalid("observation_hash_reused")
		seen_hashes[observation_hash] = true
		var turn: Dictionary = observation.get("turn", {}) \
			if observation.get("turn", {}) is Dictionary else {}
		var quotas: Dictionary = turn.get("quotas", {}) \
			if turn.get("quotas", {}) is Dictionary else {}
		if int(turn.get("number", -1)) != 6 \
				or int(turn.get("current_player", -1)) != 1 \
				or int(turn.get("viewer", -1)) != 1 \
				or int(turn.get("first_player", -1)) != 0 \
				or int(turn.get("phase", -1)) != int(GameState.GamePhase.MAIN) \
				or not bool(turn.get("deterministic_attack_window_open", false)):
			return _invalid("turn_contract:%d" % epoch)
		if bool(quotas.get("supporter_available", true)) \
				or bool(quotas.get("energy_available", false)) != (epoch == 0):
			return _invalid("spent_quotas:%d" % epoch)

		var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
		var opponent: Dictionary = observation.get("opponent", {}) \
			if observation.get("opponent", {}) is Dictionary else {}
		if int(own.get("prizes_remaining", -1)) != 6 \
				or int(opponent.get("prizes_remaining", -1)) != 6 \
				or int(own.get("deck_count", -1)) != 26:
			return _invalid("public_resource_counts:%d" % epoch)
		if not _exact_active(own.get("active", {}), epoch):
			return _invalid("active_shape:%d" % epoch)
		if not _exact_own_bench(own.get("bench", [])):
			return _invalid("own_bench_shape:%d" % epoch)
		if not _exact_hand(own.get("hand", []), epoch):
			return _invalid("hand_shape:%d" % epoch)
		if not _exact_discard_counts(own.get("discard_counts", {}), epoch):
			return _invalid("discard_shape:%d" % epoch)
		if not _exact_opponent(opponent):
			return _invalid("opponent_shape:%d" % epoch)
		if _visible_psychic_total(observation) != 5:
			return _invalid("psychic_resource_conservation:%d" % epoch)

	if not _root_evolve_event_matches(sequence[0]):
		return _invalid("root_prior_evolve_action_result")
	if not _event_matches(sequence[1], ATTACH_ACTIVE_ACTION, ACTIVE_SLOT) \
			or not _event_matches(sequence[2], EMBRACE_ACTION, ACTIVE_SLOT) \
			or not _event_matches(sequence[3], EMBRACE_ACTION, ACTIVE_SLOT):
		return _invalid("action_resolved_transition")
	if not _exact_attach_actions(sequence[0]):
		return _invalid("manual_attach_action")
	if not _exact_embrace_action(sequence[1]) or not _exact_embrace_action(sequence[2]):
		return _invalid("embrace_action")
	if not _exact_attack_action(sequence[3]):
		return _invalid("attack_action")
	return {"valid": true, "reason": ""}


func _frontier_for_epoch(epoch: int) -> Array[Dictionary]:
	if epoch == 0:
		return [
			_candidate_shape(RULE_ATTACH_CANDIDATE, ATTACH_DRIF_ACTION, "route:energy_commit", "attach_energy", 710.4, {
				"card": _card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 51, "P"),
				"target": DRIFLOON_SLOT,
			}, false, 0),
			_candidate_shape(ATTACH_ACTIVE_CANDIDATE, ATTACH_ACTIVE_ACTION, "route:energy_commit", "attach_energy", 640.0, {
				"card": _card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 51, "P"),
				"target": ACTIVE_SLOT,
			}, false, 0),
			_candidate_shape("candidate:ultra-ball", ULTRA_BALL_ACTION, "route:opening_search", "play_trainer", 320.0, {
				"card": _card(ULTRA_BALL_UID, ULTRA_BALL_EFFECT, "Item", 30),
			}, false, 0),
			_candidate_shape("candidate:end-root", END_ACTION, "route:end_turn", "end_turn", -144.0, {}, false, 0),
		]
	if epoch == 1:
		return [
			_candidate_shape(EMBRACE_CANDIDATE, EMBRACE_ACTION, "route:information", "use_ability", 539.4, _embrace_action_ref(), false, 0),
			_candidate_shape("candidate:end-after-attach", END_ACTION, "route:end_turn", "end_turn", -144.0, {}, false, 0),
		]
	if epoch == 2:
		return [
			_candidate_shape(RULE_MUNKIDORI_CANDIDATE, MUNKIDORI_ACTION, "route:information", "use_ability", 6464.176, {
				"source": DARK_MUNKIDORI_SLOT,
				"ability_index": 0,
				"requires_interaction": true,
				"source_card": _card(MUNKIDORI_UID, MUNKIDORI_EFFECT, "Pokemon"),
			}, false, 0),
			_candidate_shape(EMBRACE_CANDIDATE, EMBRACE_ACTION, "route:information", "use_ability", 539.4, _embrace_action_ref(), false, 0),
			_candidate_shape("candidate:end-after-embrace-one", END_ACTION, "route:end_turn", "end_turn", -144.0, {}, false, 0),
		]
	return [
		_candidate_shape(RULE_MUNKIDORI_CANDIDATE, MUNKIDORI_ACTION, "route:information", "use_ability", 6464.176, {
			"source": DARK_MUNKIDORI_SLOT,
			"ability_index": 0,
			"requires_interaction": true,
			"source_card": _card(MUNKIDORI_UID, MUNKIDORI_EFFECT, "Pokemon"),
		}, false, 0),
		_candidate_shape(ATTACK_CANDIDATE, ATTACK_ACTION, "route:attack_ko", "attack", 2657.08, {
			"source": ACTIVE_SLOT,
			"source_card": _card(GARDEVOIR_UID, GARDEVOIR_EFFECT, "Pokemon"),
			"attack_index": 0,
			"attack_cost": ["P", "P", "C"],
			"projected_damage": 190,
			"projected_knockout": true,
		}, true, 2),
		_candidate_shape("candidate:end-before-ko", END_ACTION, "route:end_turn", "end_turn", -144.0, {}, false, 0),
	]


func _candidate_shape(
	candidate_id: String,
	action_id: String,
	route_id: String,
	action_kind: String,
	score: float,
	action_ref: Dictionary,
	terminal: bool,
	prizes_now: int
) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"safe_prefix_action_id": action_id,
		"route_id": route_id,
		"action_kind": action_kind,
		"action_ref": action_ref.duplicate(true),
		"action_semantic_roles": ["attacker"] if action_kind == "attack" else ["ability_engine", "energy_accelerator"] if action_kind == "use_ability" else ["typed_energy"] if action_kind == "attach_energy" else ["item"],
		"checkpoint_after": "terminal" if terminal else "action_resolved",
		"base_score": score,
		"local_score": score,
		"engine_rule_floor_exact": false,
		"outcome": {
			"win_now": false,
			"prizes_now": prizes_now,
			"terminal": terminal,
			"estimated_damage": 190 if action_kind == "attack" else 0,
		},
	}


func _facts_for_epoch(epoch: int) -> Dictionary:
	return {
		"attack": {
			"ready": epoch == 3,
			"ko_available": epoch == 3,
			"max_damage": 190 if epoch == 3 else 0,
		},
		"board": {
			"bench_full": true,
			"own_active_remaining_hp": [310, 310, 290, 270][epoch],
			"opponent_active_remaining_hp": 160,
		},
		"information": {"material_action_available": epoch < 3},
		"prize": {"current_swing": 2 if epoch == 3 else 0, "win_now": false},
		"resources": {
			"bench_slots_free": 0,
			"deck_low": false,
			"energy_on_board": 1 + epoch,
			"hand_size": 2 if epoch == 0 else 1,
			"prizes_remaining": 6,
		},
		"turn": {"energy_available": epoch == 0, "supporter_available": false},
	}


func _base_sequence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for epoch: int in 4:
		var observation := {
			"observation_version": TRACE_VERSIONS[epoch],
			"observation_hash": TRACE_HASHES[epoch],
			"provenance": {
				"deck_id": DECK_ID,
				"deck_content_fingerprint": EXPECTED_DECK_FINGERPRINT,
				"manifest_hash": EXPECTED_MANIFEST_HASH,
				"profile_fingerprint": EXPECTED_PROFILE_FINGERPRINT,
				"profile_version": 10,
				"semantic_version": 1,
			},
			"turn": {
				"number": 6,
				"current_player": 1,
				"viewer": 1,
				"first_player": 0,
				"phase": int(GameState.GamePhase.MAIN),
				"deterministic_attack_window_open": true,
				"quotas": {
					"energy_available": epoch == 0,
					"supporter_available": false,
					"retreat_available": true,
				},
			},
			"visibility": {
				"deck_order_visible": false,
				"decklist_visibility": "observed_only",
				"opponent_hand_contents": false,
				"own_prize_identities": false,
			},
			"own": {
				"active": _active_slot(epoch),
				"bench": _own_bench(),
				"hand": _root_hand() if epoch == 0 else _post_attach_hand(),
				"hand_count": 5 if epoch == 0 else 4,
				"discard_counts": _discard_counts(epoch),
				"deck_count": 26,
				"prizes_remaining": 6,
			},
			"opponent": _opponent_state(),
			"legal_actions": _legal_actions_for_epoch(epoch),
			"public_outcome": {
				"own_attack_ready": epoch == 3,
				"own_ko_available": epoch == 3,
				"max_damage": 190 if epoch == 3 else 0,
			},
		}
		if epoch == 0:
			observation["event"] = _root_evolve_event()
		elif epoch == 1:
			observation["event"] = _event(ATTACH_ACTIVE_ACTION, ACTIVE_SLOT)
		elif epoch in [2, 3]:
			observation["event"] = _event(EMBRACE_ACTION, ACTIVE_SLOT)
		result.append(observation)
	return result


func _active_slot(epoch: int) -> Dictionary:
	var energy: Array[Dictionary] = []
	for index: int in epoch:
		energy.append(_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 51 + index, "P"))
	var damage: int = int([0, 0, 20, 40][epoch])
	var remaining_hp: int = int([310, 310, 290, 270][epoch])
	return {
		"slot_id": ACTIVE_SLOT,
		"pokemon": {
			"uid": GARDEVOIR_UID,
			"effect_id": GARDEVOIR_EFFECT,
			"instance_id": 6,
			"type": "Pokemon",
			"hp": 310,
			"attacks": [{"index": 0, "cost": ["P", "P", "C"], "damage": 190}],
		},
		"tool": {},
		"energy": energy,
		"energy_count": energy.size(),
		"damage": damage,
		"damage_counters": int(damage / 10),
		"remaining_hp": remaining_hp,
		"max_hp": 310,
		"prize_count": 2,
		"ability_used": false,
		"special_conditions": [],
	}


func _own_bench() -> Array[Dictionary]:
	return [
		_slot(DRIFLOON_SLOT, 13, DRIFLOON_UID, DRIFLOON_EFFECT, 70, [], 1),
		_slot(DARK_MUNKIDORI_SLOT, 9, MUNKIDORI_UID, MUNKIDORI_EFFECT, 110,
			[_card(DARKNESS_UID, DARKNESS_EFFECT, "Basic Energy", 47, "D")], 1),
		_slot(PLAIN_MUNKIDORI_SLOT, 8, MUNKIDORI_UID, MUNKIDORI_EFFECT, 110, [], 1),
		_slot(CLEFFA_SLOT, 15, CLEFFA_UID, CLEFFA_EFFECT, 30, [], 1),
		_slot(BUDEW_SLOT, 14, BUDEW_UID, BUDEW_EFFECT, 30, [], 1),
	]


func _opponent_state() -> Dictionary:
	return {
		"active": {
			"slot_id": OPPONENT_ACTIVE_SLOT,
			"pokemon": {
				"uid": SQUAWKABILLY_UID,
				"effect_id": SQUAWKABILLY_EFFECT,
				"instance_id": 8,
				"type": "Pokemon",
				"hp": 160,
				"weakness": "L",
				"resistance": "F",
			},
			"tool": {},
			"energy": [],
			"energy_count": 0,
			"damage": 0,
			"remaining_hp": 160,
			"max_hp": 160,
			"prize_count": 2,
			"ability_used": false,
			"public_effects": [],
			"reaction_effects": [],
		},
		"bench": [
			_slot("slot:0", 0, ZAPDOS_UID, ZAPDOS_EFFECT, 120, _energy_list("L", 3, 120), 1),
			_slot("slot:51", 51, FEZANDIPITI_UID, FEZANDIPITI_EFFECT, 210, [], 2),
			_slot("slot:58", 58, IRON_HANDS_UID, IRON_HANDS_EFFECT, 230, _energy_list("L", 4, 130), 2),
			_slot("slot:36", 36, LUMINEON_UID, LUMINEON_EFFECT, 170, [], 2),
		],
		"deck_count": 25,
		"discard_counts": {"CSV1C_107": 3, "CSV1C_123": 3, "CSVE1C_LIG": 3},
		"hand_count": 6,
		"prizes_remaining": 6,
	}


func _legal_actions_for_epoch(epoch: int) -> Array[Dictionary]:
	if epoch == 0:
		return [
			{"id": ATTACH_DRIF_ACTION, "candidate_id": RULE_ATTACH_CANDIDATE, "kind": "attach_energy", "card": _card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 51, "P"), "target_slot_id": DRIFLOON_SLOT},
			{"id": ATTACH_ACTIVE_ACTION, "candidate_id": ATTACH_ACTIVE_CANDIDATE, "kind": "attach_energy", "card": _card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 51, "P"), "target_slot_id": ACTIVE_SLOT},
			{"id": ULTRA_BALL_ACTION, "candidate_id": "candidate:ultra-ball", "kind": "play_trainer", "card": _card(ULTRA_BALL_UID, ULTRA_BALL_EFFECT, "Item", 30)},
			{"id": END_ACTION, "candidate_id": "candidate:end-root", "kind": "end_turn"},
		]
	if epoch in [1, 2]:
		var result: Array[Dictionary] = [_legal_embrace_action()]
		if epoch == 2:
			result.push_front({"id": MUNKIDORI_ACTION, "candidate_id": RULE_MUNKIDORI_CANDIDATE, "kind": "use_ability", "source_slot_id": DARK_MUNKIDORI_SLOT, "source_card": _card(MUNKIDORI_UID, MUNKIDORI_EFFECT, "Pokemon"), "ability_index": 0})
		result.append({"id": END_ACTION, "candidate_id": "candidate:end", "kind": "end_turn"})
		return result
	return [
		{"id": MUNKIDORI_ACTION, "candidate_id": RULE_MUNKIDORI_CANDIDATE, "kind": "use_ability", "source_slot_id": DARK_MUNKIDORI_SLOT, "source_card": _card(MUNKIDORI_UID, MUNKIDORI_EFFECT, "Pokemon"), "ability_index": 0},
		{"id": ATTACK_ACTION, "candidate_id": ATTACK_CANDIDATE, "kind": "attack", "source_slot_id": ACTIVE_SLOT, "source_card": _card(GARDEVOIR_UID, GARDEVOIR_EFFECT, "Pokemon"), "attack_index": 0, "attack_cost": ["P", "P", "C"], "projected_damage": 190, "projected_knockout": true, "target_slot_id": OPPONENT_ACTIVE_SLOT},
		{"id": END_ACTION, "candidate_id": "candidate:end", "kind": "end_turn"},
	]


func _legal_embrace_action() -> Dictionary:
	return {
		"id": EMBRACE_ACTION,
		"candidate_id": EMBRACE_CANDIDATE,
		"kind": "use_ability",
		"source_slot_id": ACTIVE_SLOT,
		"source_card": _card(GARDEVOIR_UID, GARDEVOIR_EFFECT, "Pokemon"),
		"ability_index": 0,
		"interaction_steps": [{
			"id": "embrace_target",
			"min_select": 1,
			"max_select": 1,
			"public_items": [ACTIVE_SLOT, DRIFLOON_SLOT, DARK_MUNKIDORI_SLOT, PLAIN_MUNKIDORI_SLOT, CLEFFA_SLOT],
		}],
	}


func _embrace_action_ref() -> Dictionary:
	return {
		"source": ACTIVE_SLOT,
		"ability_index": 0,
		# The production frontier currently reports false even though the exact
		# legal action exposes the one-card embrace_target interaction step.
		"requires_interaction": false,
		"source_card": _card(GARDEVOIR_UID, GARDEVOIR_EFFECT, "Pokemon"),
	}


func _exact_active(value: Variant, epoch: int) -> bool:
	if not (value is Dictionary):
		return false
	var active: Dictionary = value as Dictionary
	var pokemon: Dictionary = active.get("pokemon", {}) if active.get("pokemon", {}) is Dictionary else {}
	var attacks: Array = pokemon.get("attacks", []) if pokemon.get("attacks", []) is Array else []
	if attacks.size() != 1 or not (attacks[0] is Dictionary):
		return false
	var attack: Dictionary = attacks[0]
	return _card_matches(pokemon, GARDEVOIR_UID, GARDEVOIR_EFFECT, 6) \
		and str(active.get("slot_id", "")) == ACTIVE_SLOT \
		and int(pokemon.get("hp", 0)) == 310 \
		and int(attack.get("index", -1)) == 0 \
		and attack.get("cost", []) == ["P", "P", "C"] \
		and int(attack.get("damage", 0)) == 190 \
		and _count_energy_symbol(active.get("energy", []), "P") == epoch \
		and int(active.get("energy_count", -1)) == epoch \
		and int(active.get("damage", -1)) == [0, 0, 20, 40][epoch] \
		and int(active.get("remaining_hp", -1)) == [310, 310, 290, 270][epoch] \
		and int(active.get("remaining_hp", 0)) > 0 \
		and int(active.get("prize_count", 0)) == 2 \
		and active.get("special_conditions", []) == []


func _exact_own_bench(value: Variant) -> bool:
	if not (value is Array) or (value as Array).size() != 5:
		return false
	var bench: Array = value as Array
	var drifloon := _slot_by_id(bench, DRIFLOON_SLOT)
	var dark_munkidori := _slot_by_id(bench, DARK_MUNKIDORI_SLOT)
	var plain_munkidori := _slot_by_id(bench, PLAIN_MUNKIDORI_SLOT)
	return _slot_matches(drifloon, DRIFLOON_SLOT, 13, DRIFLOON_UID, DRIFLOON_EFFECT, 70, 0, 1) \
		and _slot_matches(dark_munkidori, DARK_MUNKIDORI_SLOT, 9, MUNKIDORI_UID, MUNKIDORI_EFFECT, 110, 1, 1) \
		and _count_energy_symbol(dark_munkidori.get("energy", []), "D") == 1 \
		and _slot_matches(plain_munkidori, PLAIN_MUNKIDORI_SLOT, 8, MUNKIDORI_UID, MUNKIDORI_EFFECT, 110, 0, 1) \
		and _slot_matches(_slot_by_id(bench, CLEFFA_SLOT), CLEFFA_SLOT, 15, CLEFFA_UID, CLEFFA_EFFECT, 30, 0, 1) \
		and _slot_matches(_slot_by_id(bench, BUDEW_SLOT), BUDEW_SLOT, 14, BUDEW_UID, BUDEW_EFFECT, 30, 0, 1)


func _exact_hand(value: Variant, epoch: int) -> bool:
	if not (value is Array):
		return false
	var hand: Array = value as Array
	if epoch == 0:
		return hand.size() == 5 \
			and _count_card(hand, PSYCHIC_UID, PSYCHIC_EFFECT, 51) == 1 \
			and _count_card(hand, PSYCHIC_UID, PSYCHIC_EFFECT) == 2 \
			and _count_card(hand, ULTRA_BALL_UID, ULTRA_BALL_EFFECT, 30) == 1 \
			and _count_card(hand, RARE_CANDY_UID, RARE_CANDY_EFFECT, 53) == 1 \
			and _count_card(hand, NEST_BALL_UID, NEST_BALL_EFFECT, 55) == 1
	return hand.size() == 4 \
		and _count_card(hand, PSYCHIC_UID, PSYCHIC_EFFECT, 54) == 1 \
		and _count_card(hand, ULTRA_BALL_UID, ULTRA_BALL_EFFECT, 30) == 1 \
		and _count_card(hand, RARE_CANDY_UID, RARE_CANDY_EFFECT, 53) == 1 \
		and _count_card(hand, NEST_BALL_UID, NEST_BALL_EFFECT, 55) == 1


func _exact_discard_counts(value: Variant, epoch: int) -> bool:
	if not (value is Dictionary):
		return false
	var counts: Dictionary = value as Dictionary
	var expected := {
		"CSV1C_112": 1,
		"CSV1C_121": 1,
		"CSV2C_127": 1,
		"CSV3C_123": 2,
		"CSV6C_115": 1,
		"CSV8C_183": 2,
		"CSVE1C_DAR": 2,
		"CSVE1C_PSY": [3, 3, 2, 1][epoch],
	}
	return counts == expected


func _exact_opponent(opponent: Dictionary) -> bool:
	var active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var pokemon: Dictionary = active.get("pokemon", {}) if active.get("pokemon", {}) is Dictionary else {}
	var bench: Array = opponent.get("bench", []) if opponent.get("bench", []) is Array else []
	return _card_matches(pokemon, SQUAWKABILLY_UID, SQUAWKABILLY_EFFECT, 8) \
		and str(active.get("slot_id", "")) == OPPONENT_ACTIVE_SLOT \
		and int(pokemon.get("hp", 0)) == 160 \
		and str(pokemon.get("weakness", "")) == "L" \
		and str(pokemon.get("resistance", "")) == "F" \
		and int(active.get("remaining_hp", 0)) == 160 \
		and int(active.get("energy_count", -1)) == 0 \
		and (active.get("energy", []) as Array).is_empty() \
		and int(active.get("prize_count", 0)) == 2 \
		and active.get("public_effects", []) == [] \
		and active.get("reaction_effects", []) == [] \
		and bench.size() == 4 \
		and _slot_matches(_slot_by_id(bench, "slot:0"), "slot:0", 0, ZAPDOS_UID, ZAPDOS_EFFECT, 120, 3, 1) \
		and _slot_matches(_slot_by_id(bench, "slot:51"), "slot:51", 51, FEZANDIPITI_UID, FEZANDIPITI_EFFECT, 210, 0, 2) \
		and _slot_matches(_slot_by_id(bench, "slot:58"), "slot:58", 58, IRON_HANDS_UID, IRON_HANDS_EFFECT, 230, 4, 2) \
		and _slot_matches(_slot_by_id(bench, "slot:36"), "slot:36", 36, LUMINEON_UID, LUMINEON_EFFECT, 170, 0, 2) \
		and int(opponent.get("deck_count", -1)) == 25 \
		and int(opponent.get("hand_count", -1)) == 6 \
		and opponent.get("discard_counts", {}) == {"CSV1C_107": 3, "CSV1C_123": 3, "CSVE1C_LIG": 3}


func _exact_attach_actions(observation: Dictionary) -> bool:
	var active_actions := _actions_by_id(observation, ATTACH_ACTIVE_ACTION)
	var drif_actions := _actions_by_id(observation, ATTACH_DRIF_ACTION)
	if active_actions.size() != 1 or drif_actions.size() != 1:
		return false
	var action: Dictionary = active_actions[0]
	return str(action.get("kind", "")) == "attach_energy" \
		and str(action.get("candidate_id", "")) == ATTACH_ACTIVE_CANDIDATE \
		and str(action.get("target_slot_id", "")) == ACTIVE_SLOT \
		and _card_matches(action.get("card", {}), PSYCHIC_UID, PSYCHIC_EFFECT, 51)


func _exact_embrace_action(observation: Dictionary) -> bool:
	var actions := _actions_by_id(observation, EMBRACE_ACTION)
	if actions.size() != 1:
		return false
	var action: Dictionary = actions[0]
	var steps: Array = action.get("interaction_steps", []) if action.get("interaction_steps", []) is Array else []
	if steps.size() != 1 or not (steps[0] is Dictionary):
		return false
	var step: Dictionary = steps[0]
	return str(action.get("kind", "")) == "use_ability" \
		and str(action.get("candidate_id", "")) == EMBRACE_CANDIDATE \
		and str(action.get("source_slot_id", "")) == ACTIVE_SLOT \
		and _card_matches(action.get("source_card", {}), GARDEVOIR_UID, GARDEVOIR_EFFECT) \
		and int(action.get("ability_index", -1)) == 0 \
		and str(step.get("id", "")) == "embrace_target" \
		and int(step.get("min_select", -1)) == 1 \
		and int(step.get("max_select", -1)) == 1 \
		and (step.get("public_items", []) as Array).count(ACTIVE_SLOT) == 1


func _exact_attack_action(observation: Dictionary) -> bool:
	var actions := _actions_by_id(observation, ATTACK_ACTION)
	if actions.size() != 1:
		return false
	var action: Dictionary = actions[0]
	return str(action.get("kind", "")) == "attack" \
		and str(action.get("candidate_id", "")) == ATTACK_CANDIDATE \
		and str(action.get("source_slot_id", "")) == ACTIVE_SLOT \
		and _card_matches(action.get("source_card", {}), GARDEVOIR_UID, GARDEVOIR_EFFECT) \
		and int(action.get("attack_index", -1)) == 0 \
		and action.get("attack_cost", []) == ["P", "P", "C"] \
		and int(action.get("projected_damage", 0)) == 190 \
		and bool(action.get("projected_knockout", false)) \
		and str(action.get("target_slot_id", "")) == OPPONENT_ACTIVE_SLOT \
		and _cost_payable(action.get("attack_cost", []), observation.get("own", {}).get("active", {}).get("energy", [])) \
		and int(action.get("projected_damage", 0)) >= int(observation.get("opponent", {}).get("active", {}).get("remaining_hp", 999))


func _interaction_targets_active(
	observation: Dictionary,
	profile: Dictionary,
	manifest: Dictionary,
	registry: RefCounted
) -> bool:
	var gardevoir := _pokemon_slot("Gardevoir ex", "CSV2C", "055", GARDEVOIR_EFFECT)
	var drifloon := _pokemon_slot("Drifloon", "CSV2C", "060", DRIFLOON_EFFECT)
	var override: Dictionary = registry.call("pick_verified_interaction_override",
		[gardevoir, drifloon],
		# Production effect runtime omits min_select; the exact effect contract
		# makes this a mandatory single target and max_select remains explicit.
		{"id": "embrace_target", "max_select": 1},
		[drifloon],
		{
			"v18cpg_observation": observation,
			"v18cpg_facts": _facts_for_epoch(1),
			"v18cpg_semantic_manifest": manifest,
		},
		profile,
		EXPECTED_CERTIFICATE
	)
	return bool(override.get("handled", false)) \
		and override.get("items", []) == [gardevoir] \
		and str(override.get("certificate_kind", "")) == EXPECTED_TARGET_CERTIFICATE


func _strategy_interaction_targets_active(
	strategy: RefCounted,
	frontier: Array,
	observation: Dictionary,
	facts: Dictionary
) -> bool:
	var gardevoir := _pokemon_slot("Gardevoir ex", "CSV2C", "055", GARDEVOIR_EFFECT)
	var drifloon := _pokemon_slot("Drifloon", "CSV2C", "060", DRIFLOON_EFFECT)
	strategy._last_observation = observation.duplicate(true)
	strategy._last_facts = facts.duplicate(true)
	strategy._last_frontier = frontier.duplicate(true)
	strategy.call(
		"_select_route", "route:information", frontier,
		"module_verified_upgrade", EMBRACE_CANDIDATE
	)
	var picked: Array = strategy.call(
		"pick_interaction_items",
		[gardevoir, drifloon],
		{"id": "embrace_target", "max_select": 1},
		{}
	)
	var active_score := float(strategy.call("score_interaction_target", gardevoir,
		{"id": "embrace_target", "max_select": 1}, {}))
	var drifloon_score := float(strategy.call("score_interaction_target", drifloon,
		{"id": "embrace_target", "max_select": 1}, {}))
	return picked == [gardevoir] \
		and active_score > drifloon_score \
		and str(strategy._active_module_certificate_kind) == EXPECTED_CERTIFICATE


func _printed_card_contract(gardevoir: Dictionary, squawkabilly: Dictionary) -> bool:
	var attacks: Array = gardevoir.get("attacks", []) if gardevoir.get("attacks", []) is Array else []
	var squawk_attacks: Array = squawkabilly.get("attacks", []) if squawkabilly.get("attacks", []) is Array else []
	if attacks.size() != 1 or squawk_attacks.size() != 1:
		return false
	var attack: Dictionary = attacks[0] if attacks[0] is Dictionary else {}
	return str(gardevoir.get("effect_id", "")) == GARDEVOIR_EFFECT \
		and int(gardevoir.get("hp", 0)) == 310 \
		and str(attack.get("cost", "")) == "PPC" \
		and str(attack.get("damage", "")) == "190" \
		and str(squawkabilly.get("effect_id", "")) == SQUAWKABILLY_EFFECT \
		and int(squawkabilly.get("hp", 0)) == 160 \
		and str(squawkabilly.get("weakness_energy", "")) == "L" \
		and str(squawkabilly.get("resistance_energy", "")) == "F"


func _apply_sequence_mutation(sequence: Array[Dictionary], kind: String) -> void:
	var root := sequence[0]
	var first := sequence[1]
	var second := sequence[2]
	var attack := sequence[3]
	match kind:
		"wrong_deck_id": root["provenance"]["deck_id"] = DECK_ID + 1
		"wrong_deck_fingerprint": root["provenance"]["deck_content_fingerprint"] = "wrong"
		"wrong_manifest_hash": first["provenance"]["manifest_hash"] = "wrong"
		"wrong_profile_hash": second["provenance"]["profile_fingerprint"] = "wrong"
		"wrong_profile_version": attack["provenance"]["profile_version"] = 11
		"wrong_semantic_version": root["provenance"]["semantic_version"] = 2
		"wrong_observation_version": second["observation_version"] = 45
		"wrong_observation_hash": attack["observation_hash"] = "wrong"
		"reused_observation_hash": first["observation_hash"] = TRACE_HASHES[0]
		"root_event_missing": root.erase("event")
		"root_event_kind_changed": root["event"]["kind"] = "interaction_resolved"
		"root_prior_action_changed": root["event"]["action_id"] = ATTACH_ACTIVE_ACTION
		"root_prior_candidate_changed": root["event"]["candidate_id"] = "wrong"
		"root_prior_action_kind_changed": root["event"]["action_kind"] = "attach_energy"
		"root_prior_route_changed": root["event"]["route_id"] = "route:information"
		"root_prior_target_changed": root["event"]["target_slot_id"] = DRIFLOON_SLOT
		"root_prior_failed": root["event"]["success"] = false
		"wrong_turn": attack["turn"]["number"] = 7
		"wrong_current_player": root["turn"]["current_player"] = 0
		"wrong_viewer": root["turn"]["viewer"] = 0
		"wrong_phase": root["turn"]["phase"] = int(GameState.GamePhase.ATTACK)
		"opponent_hand_leak": first["opponent"]["hand"] = [_card("hidden", "hidden", "Pokemon")]
		"opponent_deck_leak": second["opponent"]["deck_cards"] = [_card("hidden", "hidden", "Pokemon")]
		"opponent_prize_leak": attack["opponent"]["prize_cards"] = [_card("hidden", "hidden", "Pokemon")]
		"own_prize_leak": root["own"]["prize_cards"] = [_card("hidden", "hidden", "Pokemon")]
		"belief_leak": second["belief"] = {"deck_order": [PSYCHIC_UID]}
		"wrong_gardevoir_uid": root["own"]["active"]["pokemon"]["uid"] = "wrong"
		"wrong_gardevoir_effect": first["own"]["active"]["pokemon"]["effect_id"] = "wrong"
		"wrong_gardevoir_slot": second["own"]["active"]["slot_id"] = "slot:3"
		"wrong_attack_cost": attack["own"]["active"]["pokemon"]["attacks"][0]["cost"] = ["P", "P", "P", "C"]
		"wrong_attack_damage": attack["own"]["active"]["pokemon"]["attacks"][0]["damage"] = 180
		"wrong_squawk_uid": root["opponent"]["active"]["pokemon"]["uid"] = "wrong"
		"wrong_squawk_effect": first["opponent"]["active"]["pokemon"]["effect_id"] = "wrong"
		"wrong_squawk_hp": attack["opponent"]["active"]["remaining_hp"] = 190
		"squawk_energy_added": second["opponent"]["active"]["energy"].append(_card("CSVE1C_LIG", "fixture:lightning", "Basic Energy", 200, "L"))
		"squawk_prize_changed": root["opponent"]["active"]["prize_count"] = 1
		"squawk_reaction_added": attack["opponent"]["active"]["reaction_effects"] = ["reduce_damage"]
		"wrong_own_prizes": root["own"]["prizes_remaining"] = 5
		"wrong_opponent_prizes": second["opponent"]["prizes_remaining"] = 5
		"wrong_deck_count": first["own"]["deck_count"] = 27
		"supporter_available": first["turn"]["quotas"]["supporter_available"] = true
		"energy_quota_spent_root": root["turn"]["quotas"]["energy_available"] = false
		"energy_quota_reopened": second["turn"]["quotas"]["energy_available"] = true
		"psychic_hand_missing": root["own"]["hand"].remove_at(1)
		"psychic_hand_duplicate": root["own"]["hand"].append(_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 99, "P"))
		"ultra_ball_missing": first["own"]["hand"].clear()
		"discard_psychic_two": root["own"]["discard_counts"][PSYCHIC_UID] = 2
		"discard_psychic_four": root["own"]["discard_counts"][PSYCHIC_UID] = 4
		"final_discard_zero": attack["own"]["discard_counts"][PSYCHIC_UID] = 0
		"resource_total_changed": second["own"]["discard_counts"][PSYCHIC_UID] = 1
		"active_precharged": root["own"]["active"]["energy"].append(_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 100, "P"))
		"active_damage_root": root["own"]["active"]["damage"] = 20
		"first_embrace_damage_wrong": second["own"]["active"]["damage"] = 10
		"second_embrace_damage_wrong": attack["own"]["active"]["remaining_hp"] = 260
		"first_embrace_knockout": second["own"]["active"]["remaining_hp"] = 0
		"second_embrace_knockout": attack["own"]["active"]["remaining_hp"] = 0
		"drifloon_missing": root["own"]["bench"].remove_at(0)
		"drifloon_charged": first["own"]["bench"][0]["energy"].append(_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 101, "P"))
		"bench_extra": second["own"]["bench"].append(_slot("slot:extra", 99, CLEFFA_UID, CLEFFA_EFFECT, 30, [], 1))
		"dark_munkidori_missing": attack["own"]["bench"][1]["energy"].clear()
		"plain_munkidori_missing": root["own"]["bench"][2]["pokemon"]["uid"] = "wrong"
		"attach_missing": root["legal_actions"].remove_at(1)
		"attach_duplicate": root["legal_actions"].append(root["legal_actions"][1].duplicate(true))
		"attach_wrong_target": root["legal_actions"][1]["target_slot_id"] = DRIFLOON_SLOT
		"attach_wrong_energy": root["legal_actions"][1]["card"]["effect_id"] = "wrong"
		"attach_event_failed": first["event"]["success"] = false
		"attach_event_mismatch": first["event"]["action_id"] = ATTACH_DRIF_ACTION
		"embrace_missing": first["legal_actions"].remove_at(0)
		"embrace_duplicate": second["legal_actions"].append(second["legal_actions"][1].duplicate(true))
		"embrace_source_changed": first["legal_actions"][0]["source_slot_id"] = DRIFLOON_SLOT
		"embrace_interaction_changed": second["legal_actions"][1]["interaction_steps"][0]["max_select"] = 2
		"embrace_event_failed": second["event"]["success"] = false
		"embrace_event_mismatch": attack["event"]["action_id"] = MUNKIDORI_ACTION
		"embrace_target_changed": attack["event"]["target_slot_id"] = DRIFLOON_SLOT
		"attack_missing": attack["legal_actions"].remove_at(1)
		"attack_duplicate": attack["legal_actions"].append(attack["legal_actions"][1].duplicate(true))
		"attack_source_changed": attack["legal_actions"][1]["source_slot_id"] = DRIFLOON_SLOT
		"attack_index_changed": attack["legal_actions"][1]["attack_index"] = 1
		"attack_action_cost_changed": attack["legal_actions"][1]["attack_cost"] = ["P", "P", "P", "C"]
		"attack_projection_changed": attack["legal_actions"][1]["projected_damage"] = 180
		"attack_ko_false": attack["legal_actions"][1]["projected_knockout"] = false
		"active_special_condition": attack["own"]["active"]["special_conditions"] = ["Asleep"]


func _apply_static_mutation(profile: Dictionary, manifest: Dictionary, kind: String) -> void:
	match kind:
		"production_profile_hash": profile["switch_margin"] = float(profile.get("switch_margin", 0.0)) + 1.0
		"production_profile_version": profile["profile_version"] = 11
		"production_semantic_version": profile["semantic_version"] = 2
		"production_modules": profile["modules"] = ["gardevoir_embrace"]
		"production_manifest_hash": manifest["manifest_hash"] = "wrong"
		"production_manifest_effect":
			for raw_card: Variant in manifest.get("cards", []):
				if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == GARDEVOIR_UID:
					(raw_card as Dictionary)["effect_id"] = "wrong"
					break


func _manifest_has(manifest: Dictionary, uid: String, effect_id: String) -> bool:
	for raw_card: Variant in manifest.get("cards", []):
		if raw_card is Dictionary \
				and str((raw_card as Dictionary).get("uid", "")).to_upper() == uid.to_upper() \
				and str((raw_card as Dictionary).get("effect_id", "")).to_lower() == effect_id.to_lower():
			return true
	return false


func _contains_hidden_information(observation: Dictionary) -> bool:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	return observation.has("belief") or observation.has("rng_state") \
		or own.has("prize_cards") or own.has("deck_cards") or own.has("deck_order") \
		or opponent.has("hand") or opponent.has("prize_cards") \
		or opponent.has("deck_cards") or opponent.has("deck_order")


func _visible_psychic_total(observation: Dictionary) -> int:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	return _count_card(own.get("hand", []), PSYCHIC_UID, PSYCHIC_EFFECT) \
		+ int(own.get("discard_counts", {}).get(PSYCHIC_UID, 0)) \
		+ _count_energy_symbol(own.get("active", {}).get("energy", []), "P") \
		+ _count_energy_on_bench(own.get("bench", []), "P")


func _count_energy_on_bench(value: Variant, symbol: String) -> int:
	if not (value is Array):
		return 0
	var total := 0
	for raw_slot: Variant in value as Array:
		if raw_slot is Dictionary:
			total += _count_energy_symbol((raw_slot as Dictionary).get("energy", []), symbol)
	return total


func _event(action_id: String, target_slot_id: String) -> Dictionary:
	return {
		"kind": "action_resolved",
		"success": true,
		"action_id": action_id,
		"target_slot_id": target_slot_id,
	}


func _root_evolve_event() -> Dictionary:
	return {
		"kind": "action_resolved",
		"success": true,
		"action_id": PRIOR_EVOLVE_ACTION,
		"action_kind": "evolve",
		"route_id": "route:evolve",
		"candidate_id": PRIOR_EVOLVE_CANDIDATE,
		"target_slot_id": ACTIVE_SLOT,
		# Ownership is audit provenance only.  The same public action result may
		# come from a model graph, a local certificate, or an exact Rule root.
		"owner": "model_selected_local_route",
	}


func _root_evolve_event_matches(observation: Dictionary) -> bool:
	var event: Dictionary = observation.get("event", {}) \
		if observation.get("event", {}) is Dictionary else {}
	return str(event.get("kind", "")) == "action_resolved" \
		and bool(event.get("success", false)) \
		and str(event.get("action_id", "")) == PRIOR_EVOLVE_ACTION \
		and str(event.get("action_kind", "")) == "evolve" \
		and str(event.get("route_id", "")) == "route:evolve" \
		and str(event.get("candidate_id", "")) == PRIOR_EVOLVE_CANDIDATE \
		and str(event.get("target_slot_id", "")) == ACTIVE_SLOT


func _event_matches(observation: Dictionary, action_id: String, target_slot_id: String) -> bool:
	var event: Dictionary = observation.get("event", {}) if observation.get("event", {}) is Dictionary else {}
	return str(event.get("kind", "")) == "action_resolved" \
		and bool(event.get("success", false)) \
		and str(event.get("action_id", "")) == action_id \
		and str(event.get("target_slot_id", "")) == target_slot_id


func _root_hand() -> Array[Dictionary]:
	return [
		_card(ULTRA_BALL_UID, ULTRA_BALL_EFFECT, "Item", 30),
		_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 51, "P"),
		_card(RARE_CANDY_UID, RARE_CANDY_EFFECT, "Item", 53),
		_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 54, "P"),
		_card(NEST_BALL_UID, NEST_BALL_EFFECT, "Item", 55),
	]


func _post_attach_hand() -> Array[Dictionary]:
	return [
		_card(ULTRA_BALL_UID, ULTRA_BALL_EFFECT, "Item", 30),
		_card(RARE_CANDY_UID, RARE_CANDY_EFFECT, "Item", 53),
		_card(PSYCHIC_UID, PSYCHIC_EFFECT, "Basic Energy", 54, "P"),
		_card(NEST_BALL_UID, NEST_BALL_EFFECT, "Item", 55),
	]


func _discard_counts(epoch: int) -> Dictionary:
	return {
		"CSV1C_112": 1,
		"CSV1C_121": 1,
		"CSV2C_127": 1,
		"CSV3C_123": 2,
		"CSV6C_115": 1,
		"CSV8C_183": 2,
		"CSVE1C_DAR": 2,
		"CSVE1C_PSY": [3, 3, 2, 1][epoch],
	}


func _energy_list(symbol: String, count: int, first_instance: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in count:
		var uid := "CSVE1C_LIG" if symbol == "L" else PSYCHIC_UID if symbol == "P" else DARKNESS_UID
		result.append(_card(uid, "public:basic-energy:%s" % symbol, "Basic Energy", first_instance + index, symbol))
	return result


func _slot(
	slot_id: String,
	instance_id: int,
	uid: String,
	effect_id: String,
	hp: int,
	energy: Array,
	prize_count: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid, "effect_id": effect_id, "instance_id": instance_id, "type": "Pokemon", "hp": hp},
		"tool": {},
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"damage": 0,
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _card(
	uid: String,
	effect_id: String,
	type_name: String,
	instance_id: int = -1,
	energy_symbol: String = ""
) -> Dictionary:
	var result := {"uid": uid, "effect_id": effect_id, "type": type_name}
	if instance_id >= 0:
		result["instance_id"] = instance_id
	if energy_symbol != "":
		result["energy_type"] = energy_symbol
		result["energy_provides"] = energy_symbol
	return result


func _slot_matches(
	value: Variant,
	slot_id: String,
	instance_id: int,
	uid: String,
	effect_id: String,
	hp: int,
	energy_count: int,
	prize_count: int
) -> bool:
	if not (value is Dictionary):
		return false
	var slot: Dictionary = value as Dictionary
	return str(slot.get("slot_id", "")) == slot_id \
		and _card_matches(slot.get("pokemon", {}), uid, effect_id, instance_id) \
		and int(slot.get("remaining_hp", -1)) == hp \
		and int(slot.get("energy_count", -1)) == energy_count \
		and (slot.get("energy", []) as Array).size() == energy_count \
		and int(slot.get("prize_count", 0)) == prize_count


func _card_matches(value: Variant, uid: String, effect_id: String, instance_id: int = -1) -> bool:
	if not (value is Dictionary):
		return false
	var card: Dictionary = value as Dictionary
	return str(card.get("uid", "")).to_upper() == uid.to_upper() \
		and str(card.get("effect_id", "")).to_lower() == effect_id.to_lower() \
		and (instance_id < 0 or int(card.get("instance_id", -1)) == instance_id)


func _count_card(value: Variant, uid: String, effect_id: String, instance_id: int = -1) -> int:
	if not (value is Array):
		return 0
	var count := 0
	for raw_card: Variant in value as Array:
		if _card_matches(raw_card, uid, effect_id, instance_id):
			count += 1
	return count


func _count_energy_symbol(value: Variant, symbol: String) -> int:
	if not (value is Array):
		return 0
	var count := 0
	for raw_energy: Variant in value as Array:
		if raw_energy is Dictionary \
				and str((raw_energy as Dictionary).get("energy_provides", "")) == symbol:
			count += 1
	return count


func _cost_payable(cost: Variant, energy: Variant) -> bool:
	if not (cost is Array) or not (energy is Array):
		return false
	var remaining: Array[String] = []
	for raw_energy: Variant in energy as Array:
		if raw_energy is Dictionary:
			remaining.append(str((raw_energy as Dictionary).get("energy_provides", "")))
	var colorless := 0
	for raw_symbol: Variant in cost as Array:
		var symbol := str(raw_symbol)
		if symbol == "C":
			colorless += 1
			continue
		var index := remaining.find(symbol)
		if index < 0:
			return false
		remaining.remove_at(index)
	return remaining.size() >= colorless


func _actions_by_id(observation: Dictionary, action_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_action: Variant in observation.get("legal_actions", []):
		if raw_action is Dictionary and str((raw_action as Dictionary).get("id", "")) == action_id:
			result.append(raw_action as Dictionary)
	return result


func _slot_by_id(value: Variant, slot_id: String) -> Dictionary:
	if not (value is Array):
		return {}
	for raw_slot: Variant in value as Array:
		if raw_slot is Dictionary and str((raw_slot as Dictionary).get("slot_id", "")) == slot_id:
			return raw_slot as Dictionary
	return {}


func _candidate(frontier: Array, candidate_id: String) -> Dictionary:
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary \
				and str((raw_candidate as Dictionary).get("candidate_id", "")) == candidate_id:
			return raw_candidate as Dictionary
	return {}


func _suffix_annotation(candidate: Dictionary) -> Dictionary:
	var modules: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var gardevoir: Dictionary = modules.get("gardevoir_embrace", {}) \
		if modules.get("gardevoir_embrace", {}) is Dictionary else {}
	return gardevoir.get("profiled_active_gardevoir_ko_suffix", {}) \
		if gardevoir.get("profiled_active_gardevoir_ko_suffix", {}) is Dictionary else {}


func _card_instance(name: String, set_code: String, card_index: String, effect_id: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.set_code = set_code
	data.card_index = card_index
	data.effect_id = effect_id
	return CardInstance.create(data, 0)


func _pokemon_slot(name: String, set_code: String, card_index: String, effect_id: String) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card_instance(name, set_code, card_index, effect_id))
	return slot


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
