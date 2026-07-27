extends SceneTree

const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)
const ProfileCatalogScript = preload(
	"res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd"
)
const TransitionStateScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionState.gd"
)
const TransitionRegistryScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGTransitionRegistry.gd"
)
const TransitionEvaluatorScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGCandidateTransitionEvaluator.gd"
)
const BundleSearchScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteBundleSearch.gd"
)
const ContinuityDemandScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGContinuityDemandSolver.gd"
)
const ResponseEnvelopeScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGOpponentResponseEnvelopeV2.gd"
)
const ParetoFrontierScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGParetoFrontier.gd"
)
const RouteValueGraphScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteValueGraph.gd"
)
const ResourceLedgerScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGResourceLedger.gd"
)
const RagingContinuityScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltContinuityDemand.gd"
)
const RagingPairScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltTrainerPairSolver.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_test_contract_versions_are_additive()
	_test_all_profiles_inherit_v3()
	_test_live_switch_is_explicit_and_reversible()
	_test_base_transition_operator_registry()
	_test_transition_is_public_and_quota_owned()
	_test_resource_ledger_has_window_ownership()
	_test_information_action_ends_the_segment()
	_test_projected_followups_are_never_current_legal_claims()
	_test_response_lanes_are_fully_bound()
	_test_dynamic_continuity_releases_debt_on_win_now()
	_test_generic_profile_does_not_invent_engine_debt()
	_test_raging_damage_bank_is_target_driven()
	_test_noctowl_pair_closes_route_dependencies()
	_test_pareto_preserves_rule_and_verified_rescue()
	if _failures.is_empty():
		print("V18CPG route-value graph v3: PASS (14 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG route-value graph v3: FAIL (%d)" % _failures.size())
	quit(1)


func _test_contract_versions_are_additive() -> void:
	_check(ContractsScript.ROUTE_VALUE_GRAPH_VERSION == 3, "v3 contract version must be explicit")
	_check(ContractsScript.BUNDLE_SCHEMA_VERSION == 1, "bundle schema must be independently versioned")
	_check(ContractsScript.TRANSITION_SCHEMA_VERSION == 1, "transition schema must be independently versioned")
	_check(ContractsScript.RESPONSE_ENVELOPE_SCHEMA_VERSION == 2, "response envelope must be v2")
	_check(ContractsScript.SCHEMA_VERSION == "v18cpg-2", "v3 must not silently break the outer wire schema")


func _test_all_profiles_inherit_v3() -> void:
	var profiles := ProfileCatalogScript.list_profiles()
	_check(profiles.size() == 24, "v3 coverage fixture must see all 24 profiles")
	for profile: Dictionary in profiles:
		var config: Dictionary = profile.get("route_value_graph_v3", {}) \
			if profile.get("route_value_graph_v3", {}) is Dictionary else {}
		_check(
			not bool(config.get("enabled", true)),
			"Base v3 must remain live-disabled before real-model promotion"
		)
		_check(
			bool(config.get("shadow_enabled", false)),
			"every V18CPG profile must inherit Base v3 shadow computation"
		)
		_check(int(config.get("max_bundle_depth", 0)) == 4, "every profile must share the hard depth cap")


func _test_live_switch_is_explicit_and_reversible() -> void:
	var setting_key := "ai/route_value_graph_v3_enabled"
	var had_setting := ProjectSettings.has_setting(setting_key)
	var previous: Variant = ProjectSettings.get_setting(setting_key) \
		if had_setting else null
	var profile := ProfileCatalogScript.get_profile_for_deck(800018509)
	ProjectSettings.set_setting(setting_key, false)
	_check(
		not RouteValueGraphScript.is_enabled(profile)
			and RouteValueGraphScript.should_compute(profile),
		"default rollout state must be shadow-only"
	)
	ProjectSettings.set_setting(setting_key, true)
	_check(
		RouteValueGraphScript.is_enabled(profile),
		"explicit live switch must expose the already-tested v3 graph"
	)
	if had_setting:
		ProjectSettings.set_setting(setting_key, previous)
	else:
		ProjectSettings.set_setting(setting_key, null)


func _test_base_transition_operator_registry() -> void:
	var registry = TransitionRegistryScript.new()
	var cases := [
		["play_basic_to_bench", "route:develop", TransitionRegistryScript.BENCH],
		["evolve", "route:evolve", TransitionRegistryScript.EVOLVE],
		["attach_energy", "route:energy_commit", TransitionRegistryScript.ATTACH_ENERGY],
		["use_ability", "route:information", TransitionRegistryScript.USE_PUBLIC_ABILITY],
		["play_stadium", "route:stadium", TransitionRegistryScript.PLAY_STADIUM],
		["retreat", "route:pivot", TransitionRegistryScript.RETREAT_OR_SWITCH],
		["play_trainer", "route:gust", TransitionRegistryScript.GUST],
		["play_trainer", "route:recover", TransitionRegistryScript.RECOVER_PUBLIC_ZONE],
		["play_trainer", "route:accelerate", TransitionRegistryScript.MOVE_PUBLIC_ENERGY],
		["use_ability", "route:damage_counter_control", TransitionRegistryScript.MOVE_PUBLIC_DAMAGE],
		["attack", "route:attack_ko", TransitionRegistryScript.ATTACK],
		["end_turn", "route:end_turn", TransitionRegistryScript.END_TURN],
	]
	for raw_case: Variant in cases:
		var item: Array = raw_case
		_check(
			registry.operator_for({
				"action_kind": str(item[0]),
				"route_id": str(item[1]),
			}) == str(item[2]),
			"Base transition registry must type %s" % str(item[1])
		)


func _test_transition_is_public_and_quota_owned() -> void:
	var observation := _observation()
	var ledger := {
		"schema_version": 3,
		"exclusive_quota": {
			"energy_attachment": true,
			"supporter": true,
			"retreat": true,
			"stadium": true,
		},
		"reserved_by_window": {},
	}
	var state: Dictionary = TransitionStateScript.new().build(
		observation,
		ledger,
		_facts(),
		_clock()
	)
	var candidate := _candidate(
		"attach",
		"route:energy_commit",
		"attach_energy",
		"action:attach"
	)
	candidate["action_ref"]["target"] = "slot:own-active"
	candidate["action_ref"]["card"] = {
		"instance_id": 10,
		"uid": "CSVE1C_LIG",
		"type": "Basic Energy",
		"energy_provides": "L",
	}
	var result: Dictionary = TransitionEvaluatorScript.new().evaluate(
		candidate,
		state,
		observation,
		{}
	)
	_check(bool(result.get("supported", false)), "public manual attachment must have a transition operator")
	_check(str(result.get("operator", "")) == TransitionRegistryScript.ATTACH_ENERGY, "attachment operator must be typed")
	_check(
		not bool(result.get("predicted_state", {}).get("quotas", {}).get("energy_attachment", true)),
		"attachment transition must consume the exclusive quota"
	)
	_check(
		int(result.get("predicted_state", {}).get("own", {}).get("active", {}).get("energy_count", 0)) == 3,
		"attachment transition must update the bound public target"
	)
	_check(
		not JSON.stringify(result).contains("hidden_sentinel"),
		"transition output must not copy unknown observation keys"
	)


func _test_resource_ledger_has_window_ownership() -> void:
	var reservation := {
		"resource": "quota:energy_attachment",
		"count": 1,
		"available": 1,
		"until": "turn_end",
	}
	var ledger: Dictionary = ResourceLedgerScript.new().build(
		_observation(),
		{},
		{"protected_roles": ["next_attacker"]},
		{},
		[reservation]
	)
	_check(int(ledger.get("schema_version", 0)) == 3, "Resource Ledger must be schema v3")
	_check(
		ledger.get("reserved_by_window", {}).get("current_action_window", []) == [reservation],
		"current reservations must keep explicit action-window ownership"
	)
	_check(
		ledger.get("reserved_by_window", {}).get("next_attack_window", [])
			== [{"resource": "role:next_attacker", "count": 1, "until": "next_turn_attack_window"}],
		"protected roles must keep explicit next-attack-window ownership"
	)


func _test_information_action_ends_the_segment() -> void:
	var observation := _observation()
	var candidate := _candidate(
		"search",
		"route:noctowl_search",
		"use_ability",
		"action:noctowl"
	)
	candidate["checkpoint_after"] = "information_result"
	candidate["conditional_suffix"] = {
		"guarded_followups": [
			{"route_id": "route:energy_commit"},
			{"route_id": "route:attack_ko"},
		],
	}
	var bundles: Array[Dictionary] = BundleSearchScript.new().build(
		[candidate],
		observation,
		_facts(),
		{},
		_profile(),
		_clock()
	)
	_check(bundles.size() == 1, "information root must remain representable")
	_check(int(bundles[0].get("bundle_depth", 0)) == 1, "information root must end its local segment")
	_check(bool(bundles[0].get("requires_reobservation", false)), "information result must force reobservation")
	_check(str(bundles[0].get("checkpoint_after", "")) == "information_result", "information checkpoint must be explicit")


func _test_projected_followups_are_never_current_legal_claims() -> void:
	var observation := _observation()
	var candidate := _candidate(
		"stadium",
		"route:stadium",
		"play_stadium",
		"action:stadium"
	)
	candidate["conditional_suffix"] = {
		"guarded_followups": [
			{"route_id": "route:evolve", "dependency": "bench_capacity"},
			{"route_id": "route:noctowl_search", "dependency": "search_engine_ready"},
			{"route_id": "route:energy_commit", "dependency": "typed_energy_missing"},
			{"route_id": "route:attack_ko", "dependency": "attack_paid"},
		],
	}
	var bundles: Array[Dictionary] = BundleSearchScript.new().build(
		[candidate],
		observation,
		_facts(),
		{},
		_profile(),
		_clock()
	)
	var bundle := bundles[0]
	_check(int(bundle.get("bundle_depth", 0)) == 4, "bundle must honor the hard four-step cap")
	var steps: Array = bundle.get("steps", [])
	_check(bool((steps[0] as Dictionary).get("exact_now", false)), "only the root may be exact now")
	for index: int in range(1, steps.size()):
		var step: Dictionary = steps[index]
		_check(not bool(step.get("exact_now", true)), "projected followup must not claim current legality")
		_check(bool(step.get("requires_reobservation", false)), "projected followup must require reobservation")
		_check(str(step.get("action_id", "")) == "", "projected followup must not invent an action id")


func _test_response_lanes_are_fully_bound() -> void:
	var observation := _observation()
	observation["opponent"]["active"]["public_attack_damage"] = 220
	observation["opponent"]["active"]["public_attack_id"] = "attack:public"
	observation["opponent"]["active"]["public_attack_cost_paid"] = true
	var envelope: Dictionary = ResponseEnvelopeScript.new().solve(observation)
	var responses: Array = envelope.get("responses", [])
	_check(not responses.is_empty(), "public board must produce at least one response lane")
	for raw_response: Variant in responses:
		var response: Dictionary = raw_response
		for key: String in ["response_id", "attacker_slot_id", "attack_id", "target_slot_id", "payment", "damage", "prizes", "evidence_level"]:
			_check(response.has(key), "response lane must bind %s" % key)
	_check(str(responses[0].get("evidence_level", "")) == "verified", "fully public paid attack may be verified")


func _test_dynamic_continuity_releases_debt_on_win_now() -> void:
	var demand: Dictionary = ContinuityDemandScript.new().solve(
		_observation(),
		_facts(),
		_clock(),
		_profile()
	)
	_check(int(demand.get("remaining_attack_windows", 0)) == 2, "demand must derive remaining windows from prize clock")
	_check(int(demand.get("minimum_next_attacker_roots", 0)) == 1, "non-terminal game must preserve an attacker root")
	var win_facts := _facts()
	win_facts["prize"]["win_now"] = true
	var win_demand: Dictionary = ContinuityDemandScript.new().solve(
		_observation(),
		win_facts,
		_clock(),
		_profile()
	)
	_check(int(win_demand.get("remaining_attack_windows", -1)) == 0, "win-now must release future continuity debt")
	_check(int(win_demand.get("required_banked_damage_units", -1)) == 0, "win-now must not force dead resources")


func _test_generic_profile_does_not_invent_engine_debt() -> void:
	var demand: Dictionary = ContinuityDemandScript.new().solve(
		_observation(),
		_facts(),
		_clock(),
		{"deck_id": 18000230}
	)
	_check(
		int(demand.get("minimum_energy_engine_width", -1)) == 0,
		"Base v3 must not invent an energy engine for an undeclared deck family"
	)
	_check(
		int(demand.get("minimum_current_search_lane", -1)) == 0
			and int(demand.get("minimum_future_search_root", -1)) == 0,
		"Base v3 must not invent Noctowl-style search debt for other decks"
	)


func _test_raging_damage_bank_is_target_driven() -> void:
	var observation := _observation()
	var solver = RagingContinuityScript.new()
	for target_hp: int in [30, 70, 71, 210, 280, 330]:
		observation["opponent"]["active"]["remaining_hp"] = target_hp
		var target_facts := _facts()
		target_facts["attack"]["ko_available"] = false
		var result: Dictionary = solver.solve(
			observation,
			target_facts,
			_clock(),
			_profile()
		)
		_check(
			int(result.get("dynamic_damage_units_required", 0)) == ceili(float(target_hp) / 70.0),
			"Raging Bolt bank must use ceil(target HP / 70) for %d HP" % target_hp
		)


func _test_noctowl_pair_closes_route_dependencies() -> void:
	var items := [
		{"stable_id": "sada", "semantic_roles": ["supporter_acceleration"]},
		{"stable_id": "vessel", "semantic_roles": ["energy_access"]},
		{"stable_id": "gust", "semantic_roles": ["gust"]},
	]
	var result: Dictionary = RagingPairScript.new().solve(
		items,
		[["supporter_acceleration", "energy_access"]],
		["supporter_acceleration", "energy_access"]
	)
	_check(bool(result.get("dependencies_closed", false)), "Noctowl pair must close every required route role")
	_check(result.get("selected_ids", []) == ["sada", "vessel"], "pair selection must be deterministic and complementary")


func _test_pareto_preserves_rule_and_verified_rescue() -> void:
	var bundles: Array[Dictionary] = [
		_bundle("rule", 100.0, 0, 2, false),
		_bundle("dominated", 90.0, 0, 4, false),
		_bundle("verified", 50.0, 1, 1, true),
		_bundle("best", 120.0, 2, 1, false),
	]
	var frontier: Array[Dictionary] = ParetoFrontierScript.new().prune(
		bundles,
		3,
		"rule"
	)
	var ids: Array[String] = []
	for bundle: Dictionary in frontier:
		ids.append(str(bundle.get("root_candidate_id", "")))
	_check("rule" in ids, "Pareto pruning must preserve the exact Rule root")
	_check("verified" in ids, "Pareto pruning must preserve a public verified rescue")
	_check("dominated" not in ids, "strictly dominated bundle must be removed")


func _observation() -> Dictionary:
	return {
		"schema_version": 1,
		"observation_hash": "public:test",
		"hidden_sentinel": "must_not_escape",
		"turn": {
			"number": 5,
			"current_player": 0,
			"viewer": 0,
			"phase": 2,
			"quotas": {
				"energy_available": true,
				"supporter_available": true,
				"stadium_available": true,
				"retreat_available": true,
			},
		},
		"own": {
			"hand": [],
			"hand_count": 5,
			"deck_count": 30,
			"prizes_remaining": 4,
			"active": _slot("slot:own-active", "CSV7C_154", 240, 2, 2),
			"bench": [
				_slot("slot:own-engine", "CSV8C_028", 210, 1, 2),
				_slot("slot:own-root", "CSV9C_154", 70, 0, 1),
			],
			"discard": [],
			"lost_zone": [],
		},
		"opponent": {
			"hand_count": 5,
			"deck_count": 30,
			"prizes_remaining": 4,
			"active": _slot("slot:opp-active", "TARGET", 210, 2, 2),
			"bench": [_slot("slot:opp-bench", "ENGINE", 280, 1, 2)],
			"discard": [],
			"lost_zone": [],
		},
		"stadium": {},
		"legal_actions": [],
		"interaction": {},
		"visibility": {
			"own_prize_identities": false,
			"deck_order_visible": false,
		},
	}


func _slot(slot_id: String, uid: String, hp: int, energy_count: int, prizes: int) -> Dictionary:
	var energy: Array[Dictionary] = []
	for index: int in energy_count:
		energy.append({
			"instance_id": 100 + index,
			"uid": "CSVE1C_GRA",
			"type": "Basic Energy",
			"energy_provides": "G",
		})
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid, "instance_id": slot_id.hash()},
		"energy": energy,
		"energy_count": energy_count,
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": prizes,
		"retreat_cost": 1,
		"ability_used": false,
		"tera": uid == "CSV8C_028",
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": true, "max_damage": 280},
		"prize": {"win_now": false},
		"resources": {"prizes_remaining": 4, "bench_slots_free": 3},
		"continuity": {"banked_damage_units": 3, "floor_met": false},
	}


func _clock() -> Dictionary:
	return {
		"schema_version": 1,
		"own": {"robust": {"prize_sequence": [2, 2], "finish_tick": 4}},
		"opponent": {"robust": {"prize_sequence": [2, 2], "finish_tick": 5}},
		"race_margin": 1,
	}


func _profile() -> Dictionary:
	return {
		"deck_id": 800018509,
		"post_attack_continuity": {
			"enabled": true,
			"required_attack_types": ["L", "F"],
			"engine_uids": ["CSV8C_028"],
			"search_engine_root_uids": ["CSV9C_154"],
			"search_engine_uids": ["CSV9C_155"],
			"next_attacker_uids": ["CSV7C_154"],
		},
		"module_parameters": {
			"energy_burst": {
				"damage_per_discard": 70,
				"primary_attack_required_types": ["L", "F"],
			},
		},
	}


func _candidate(candidate_id: String, route_id: String, kind: String, action_id: String) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"action_kind": kind,
		"safe_prefix_action_id": action_id,
		"action_ref": {"id": action_id, "kind": kind},
		"checkpoint_after": "action_resolved",
		"base_score": 100.0,
		"local_score": 100.0,
		"rule_order": 0,
		"outcome": {},
	}


func _bundle(
	candidate_id: String,
	rule_score: float,
	prizes: int,
	debt: int,
	verified: bool
) -> Dictionary:
	return {
		"bundle_id": "bundle:%s" % candidate_id,
		"root_candidate_id": candidate_id,
		"root_route_id": "route:develop",
		"rule_score": rule_score,
		"verified_rescue": verified,
		"outcome_vector": {
			"win_now": false,
			"prizes_now": prizes,
			"race_margin": 0,
			"current_attack_window_preserved": true,
			"next_attack_window_uptime": true,
			"continuity_debt": debt,
			"ledger_debt": 0,
			"liability": 0.0,
			"uncertainty": 0.2,
		},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
