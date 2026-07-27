extends SceneTree

const BundleSearchScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteBundleSearch.gd"
)
const RagingDemandScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltContinuityDemand.gd"
)
const PairSolverScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltTrainerPairSolver.gd"
)
const ProfileCatalogScript = preload(
	"res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd"
)

var _failures: Array[String] = []
var _passed := 0


func _initialize() -> void:
	_check_damage_units(30, 1)
	_check_damage_units(70, 1)
	_check_damage_units(71, 2)
	_check_damage_units(140, 2)
	_check_damage_units(210, 3)
	_check_damage_units(280, 4)
	_check_damage_units(330, 5)
	_check_win_now_releases_bank()
	_check_current_noctowl_lane()
	_check_future_hoothoot_lane()
	_check_area_zero_binds_engine_followup()
	_check_area_zero_without_debt_has_no_fake_followup()
	_check_teal_dance_has_current_and_future_value()
	_check_teal_dance_increments_predicted_bank_once()
	_check_premature_attack_is_exposed()
	_check_win_now_attack_is_not_marked_premature()
	_check_satisfied_bank_stops_optional_churn()
	_check_noctowl_contract_requires_complementary_pair()
	_check_incomplete_pair_fails_closed()
	_check_pair_selection_is_order_invariant()
	if _failures.is_empty() and _passed == 20:
		print("V18CPG Raging Bolt route-value v3: PASS (20/20)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG Raging Bolt route-value v3: FAIL (%d/20)" % _passed)
	quit(1)


func _check_damage_units(target_hp: int, expected: int) -> void:
	var observation := _observation()
	observation["opponent"]["active"]["remaining_hp"] = target_hp
	var facts := _facts()
	facts["attack"]["ko_available"] = false
	var demand: Dictionary = RagingDemandScript.new().solve(
		observation,
		facts,
		_clock(),
		_profile()
	)
	_expect(
		int(demand.get("dynamic_damage_units_required", 0)) == expected,
		"%d HP must require %d damage units" % [target_hp, expected]
	)


func _check_win_now_releases_bank() -> void:
	var facts := _facts()
	facts["prize"]["win_now"] = true
	var demand: Dictionary = RagingDemandScript.new().solve(
		_observation(),
		facts,
		_clock(),
		_profile()
	)
	_expect(
		int(demand.get("dynamic_damage_units_required", -1)) == 0,
		"win-now must release the future damage bank"
	)


func _check_current_noctowl_lane() -> void:
	var observation := _observation()
	observation["own"]["bench"].append(_slot("own:noctowl", "CSV9C_155", 100, 0))
	var demand := RagingDemandScript.new().solve(
		observation,
		_facts(),
		_clock(),
		_profile()
	)
	_expect(int(demand.get("noctowl_current_lane", 0)) == 1, "current Noctowl lane must be counted separately")


func _check_future_hoothoot_lane() -> void:
	var demand := RagingDemandScript.new().solve(
		_observation(),
		_facts(),
		_clock(),
		_profile()
	)
	_expect(int(demand.get("hoothoot_future_lane", 0)) == 1, "future Hoothoot lane must be preserved")


func _check_area_zero_binds_engine_followup() -> void:
	var bundle := _bundle_for(_candidate(
		"area",
		"route:stadium",
		"play_stadium",
		"CSV9C_207",
		""
	))
	var extension: Dictionary = bundle.get("deck_extension", {})
	_expect(
		bool(extension.get("area_zero_bound_followup", false))
			and int(bundle.get("bundle_depth", 0)) >= 2,
		"Area Zero must bind a concrete engine/evolution followup"
	)


func _check_area_zero_without_debt_has_no_fake_followup() -> void:
	var observation := _observation()
	observation["own"]["bench"] = [
		_slot("own:e1", "CSV8C_028", 210, 1),
		_slot("own:e2", "CSV8C_028", 210, 1),
		_slot("own:noctowl", "CSV9C_155", 100, 0),
		_slot("own:hoothoot", "CSV9C_154", 70, 0),
	]
	var facts := _facts()
	facts["prize"]["win_now"] = true
	var bundle := _bundle_for(
		_candidate("area-idle", "route:stadium", "play_stadium", "CSV9C_207", ""),
		observation,
		facts
	)
	_expect(
		not bool(bundle.get("deck_extension", {}).get("area_zero_bound_followup", true))
			and int(bundle.get("bundle_depth", 0)) == 1,
		"Area Zero without live debt must not fabricate a followup"
	)


func _check_teal_dance_has_current_and_future_value() -> void:
	var facts := _facts()
	facts["attack"]["energy_deficit"] = 1
	facts["continuity"]["banked_damage_units"] = 1
	var bundle := _bundle_for(
		_candidate("teal", "route:information", "use_ability", "", "CSV8C_028"),
		_observation(),
		facts
	)
	_expect(
		float(bundle.get("deck_extension", {}).get("teal_dance_current_value", 0.0)) > 4.0,
		"Teal Dance value must combine current deficit, future bank, and draw"
	)


func _check_teal_dance_increments_predicted_bank_once() -> void:
	var facts := _facts()
	facts["continuity"]["banked_damage_units"] = 2
	var bundle := _bundle_for(
		_candidate("teal-bank", "route:information", "use_ability", "", "CSV8C_028"),
		_observation(),
		facts
	)
	var extension: Dictionary = bundle.get("deck_extension", {})
	_expect(
		int(extension.get("banked_damage_units_before", 0)) == 2
			and int(extension.get("banked_damage_units_after", 0)) == 3,
		"one Teal Dance projection must add exactly one banked unit"
	)


func _check_premature_attack_is_exposed() -> void:
	var facts := _facts()
	facts["continuity"]["banked_damage_units"] = 1
	var bundle := _bundle_for(
		_candidate("attack", "route:attack_ko", "attack", "", ""),
		_observation(),
		facts
	)
	_expect(
		bool(bundle.get("deck_extension", {}).get("premature_attack_prevented", false)),
		"non-terminal KO with insufficient next-window bank must be exposed"
	)


func _check_win_now_attack_is_not_marked_premature() -> void:
	var facts := _facts()
	facts["prize"]["win_now"] = true
	facts["continuity"]["banked_damage_units"] = 0
	var bundle := _bundle_for(
		_candidate("win", "route:attack_ko", "attack", "", ""),
		_observation(),
		facts
	)
	_expect(
		not bool(bundle.get("deck_extension", {}).get("premature_attack_prevented", true)),
		"win-now must outrank future banking"
	)


func _check_satisfied_bank_stops_optional_churn() -> void:
	var facts := _facts()
	facts["continuity"]["banked_damage_units"] = 4
	var observation := _observation()
	observation["own"]["bench"].append(
		_slot("own:noctowl", "CSV9C_155", 100, 0)
	)
	var bundle := _bundle_for(
		_candidate("info", "route:information", "use_ability", "", "OTHER"),
		observation,
		facts
	)
	_expect(
		bool(bundle.get("deck_extension", {}).get("optional_churn_stopped", false)),
		"satisfied dynamic bank must stop optional information churn"
	)


func _check_noctowl_contract_requires_complementary_pair() -> void:
	var bundle := _bundle_for(
		_candidate("noctowl", "route:noctowl_search", "use_ability", "", "CSV9C_155")
	)
	var contract: Dictionary = bundle.get("deck_extension", {}).get("trainer_pair_contract", {})
	_expect(
		bool(contract.get("requires_same_pair_route_closure", false))
			and contract.get("required_roles", []) == ["supporter_acceleration", "energy_access"],
		"Noctowl must search a pair that jointly closes the damage route"
	)


func _check_incomplete_pair_fails_closed() -> void:
	var result := PairSolverScript.new().solve(
		[
			{"stable_id": "sada", "semantic_roles": ["supporter_acceleration"]},
			{"stable_id": "gust", "semantic_roles": ["gust"]},
		],
		[["supporter_acceleration", "energy_access"]],
		["supporter_acceleration", "energy_access"]
	)
	_expect(
		not bool(result.get("dependencies_closed", true))
			and result.get("missing_roles", []) == ["energy_access"],
		"an incomplete Noctowl pair must fail closed"
	)


func _check_pair_selection_is_order_invariant() -> void:
	var solver = PairSolverScript.new()
	var items := [
		{"stable_id": "vessel", "semantic_roles": ["energy_access"]},
		{"stable_id": "gust", "semantic_roles": ["gust"]},
		{"stable_id": "sada", "semantic_roles": ["supporter_acceleration"]},
	]
	var first := solver.solve(
		items,
		[["supporter_acceleration", "energy_access"]],
		["supporter_acceleration", "energy_access"]
	)
	items.reverse()
	var second := solver.solve(
		items,
		[["supporter_acceleration", "energy_access"]],
		["supporter_acceleration", "energy_access"]
	)
	_expect(
		first.get("selected_ids", []) == second.get("selected_ids", []),
		"pair selection must be invariant to visible item order"
	)


func _bundle_for(
	candidate: Dictionary,
	observation: Dictionary = {},
	facts: Dictionary = {}
) -> Dictionary:
	var used_observation := observation if not observation.is_empty() else _observation()
	var used_facts := facts if not facts.is_empty() else _facts()
	var bundles := BundleSearchScript.new().build(
		[candidate],
		used_observation,
		used_facts,
		_ledger(),
		_profile(),
		_clock()
	)
	return bundles[0] if not bundles.is_empty() else {}


func _candidate(
	candidate_id: String,
	route_id: String,
	kind: String,
	card_uid: String,
	source_uid: String
) -> Dictionary:
	var action_ref := {
		"id": "action:%s" % candidate_id,
		"kind": kind,
		"source": "own:active",
		"target": "own:active",
	}
	if card_uid != "":
		action_ref["card"] = {
			"uid": card_uid,
			"instance_id": candidate_id.hash(),
			"type": "Stadium" if kind == "play_stadium" else "Trainer",
		}
	if source_uid != "":
		action_ref["source_card"] = {
			"uid": source_uid,
			"instance_id": source_uid.hash(),
			"type": "Pokemon",
		}
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"action_kind": kind,
		"safe_prefix_action_id": str(action_ref["id"]),
		"action_ref": action_ref,
		"checkpoint_after": (
			"information_result"
			if route_id in ["route:information", "route:noctowl_search"]
			else "terminal"
			if route_id.begins_with("route:attack")
			else "action_resolved"
		),
		"base_score": 100.0,
		"local_score": 100.0,
		"rule_order": 0,
		"outcome": {"prizes_now": 2 if route_id == "route:attack_ko" else 0},
	}


func _observation() -> Dictionary:
	return {
		"observation_hash": "raging-v3",
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
			"hand_count": 6,
			"deck_count": 25,
			"prizes_remaining": 4,
			"discard": [],
			"lost_zone": [],
			"active": _slot("own:active", "CSV7C_154", 240, 2),
			"bench": [
				_slot("own:engine", "CSV8C_028", 210, 1),
				_slot("own:root", "CSV9C_154", 70, 0),
			],
		},
		"opponent": {
			"hand_count": 5,
			"deck_count": 25,
			"prizes_remaining": 4,
			"discard": [],
			"lost_zone": [],
			"active": _slot("opp:active", "TARGET", 210, 2),
			"bench": [_slot("opp:bench", "NEXT", 280, 2)],
		},
		"stadium": {},
		"legal_actions": [],
	}


func _slot(slot_id: String, uid: String, hp: int, energy_count: int) -> Dictionary:
	var energy: Array[Dictionary] = []
	for index: int in energy_count:
		energy.append({
			"instance_id": slot_id.hash() + index,
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
		"prize_count": 2,
		"retreat_cost": 1,
		"ability_used": false,
		"tera": uid == "CSV8C_028",
	}


func _facts() -> Dictionary:
	return {
		"attack": {
			"ready": true,
			"ko_available": true,
			"max_damage": 280,
			"energy_deficit": 0,
		},
		"prize": {"win_now": false, "current_swing": 2},
		"resources": {"prizes_remaining": 4, "bench_slots_free": 3},
		"continuity": {
			"banked_damage_units": 2,
			"debt_count": 2,
			"floor_met": false,
		},
	}


func _clock() -> Dictionary:
	return {
		"own": {"robust": {"prize_sequence": [2, 2], "finish_tick": 4}},
		"opponent": {"robust": {"prize_sequence": [2, 2], "finish_tick": 5}},
		"race_margin": 1,
	}


func _ledger() -> Dictionary:
	return {
		"schema_version": 3,
		"exclusive_quota": {
			"energy_attachment": true,
			"supporter": true,
			"retreat": true,
			"stadium": true,
		},
		"reserved_by_window": {},
	}


func _profile() -> Dictionary:
	return ProfileCatalogScript.get_profile_for_deck(800018509)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failures.append(message)
