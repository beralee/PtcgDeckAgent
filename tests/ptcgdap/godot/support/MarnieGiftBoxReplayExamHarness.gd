class_name MarnieGiftBoxReplayExamHarness
extends RefCounted

const DEFAULT_CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260828_215722_938052_r43.json"
)
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const HandleScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd"
)
const ReviewedPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)
const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")


static func load_corpus(path: String = DEFAULT_CORPUS_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func run_corpus(
	corpus: Dictionary,
	expectation_key: String,
	repetitions_override: int = 0
) -> Dictionary:
	if expectation_key not in ["observed_baseline_selected_indexes", "target_selected_indexes"]:
		return _error_report("invalid_expectation_key")
	var package: Variant = corpus.get("strategy_package")
	var exams: Variant = corpus.get("exams")
	if not package is Dictionary or not exams is Array or exams.is_empty():
		return _error_report("invalid_exam_corpus")
	var repetitions := repetitions_override
	if repetitions <= 0:
		repetitions = maxi(1, int(corpus.get("repetitions_per_exam", 1)))
	var selection := {
		"package_id": package.get("package_id"),
		"package_version": package.get("package_version"),
		"archive_sha256": package.get("archive_sha256"),
		"install_source": package.get("install_source"),
	}
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	# This suite owns policy behavior, not repeated archive-cryptography timing.
	# Admit the real signed archive once, then mint independent one-use handles
	# from that already admitted immutable fixture. Package/catalog suites keep
	# the production guarantee that every live match request revalidates bytes.
	var admitted: Dictionary = GateScript.request_match_handle(
		catalog, selection, "Windows"
	)
	if not bool(admitted.get("ok", false)):
		catalog.free()
		return _error_report(str(admitted.get("error_code", "package_handle_rejected")))
	var fixture: Dictionary = _fixture_from_admitted_handle(admitted.get("handle"))
	if fixture.is_empty():
		catalog.free()
		return _error_report("package_integrity_invalid")
	var results: Array[Dictionary] = []
	var passed_exams := 0
	var passed_runs := 0
	var total_runs := 0
	for case_index: int in exams.size():
		if exams.size() >= 20 and (case_index == 0 or case_index % 10 == 0):
			print("EXAM_PROGRESS: %d/%d (%d repetitions each)" % [
				case_index,
				exams.size(),
				repetitions,
			])
		var exam_value: Variant = exams[case_index]
		if not exam_value is Dictionary:
			catalog.free()
			return _error_report("invalid_exam_case")
		var exam: Dictionary = exam_value
		var expected := _index_array(exam.get(expectation_key, []))
		var order_insensitive := bool(exam.get("selection_order_insensitive", false))
		var case_runs: Array[Dictionary] = []
		var case_passed := true
		for repetition: int in repetitions:
			total_runs += 1
			var requested: Dictionary = HandleScript.create(
				fixture.get("metadata"),
				fixture.get("payloads"),
				fixture.get("local_deck")
			)
			if not bool(requested.get("ok", false)):
				case_passed = false
				case_runs.append({
					"passed": false,
					"error_code": str(requested.get("error_code", "package_handle_rejected")),
					"selected_indexes": [],
					"matched_rule_ids": [],
				})
				continue
			var match_id := "exam-%02d-%02d-%s" % [
				case_index,
				repetition,
				"base" if expectation_key.begins_with("observed") else "target",
			]
			var created: Dictionary = ReviewedPolicyScript.create(
				requested.get("handle"), match_id
			)
			if not bool(created.get("ok", false)):
				case_passed = false
				case_runs.append({
					"passed": false,
					"error_code": str(created.get("error_code", "policy_create_failed")),
					"selected_indexes": [],
					"matched_rule_ids": [],
				})
				continue
			var policy: Variant = created.get("policy")
			var frame := build_frame(exam, 1000 + case_index)
			var selected: Dictionary = policy.select(frame) if policy != null else {}
			var indexes := _index_array(selected.get("selected_indexes", []))
			var passed := bool(selected.get("ok", false)) and (
				_sorted_index_array(indexes) == _sorted_index_array(expected)
				if order_insensitive else indexes == expected
			)
			if passed:
				passed_runs += 1
			else:
				case_passed = false
			case_runs.append({
				"passed": passed,
				"error_code": str(selected.get("error_code", "")),
				"selected_indexes": indexes,
				"matched_rule_ids": selected.get("matched_rule_ids", []).duplicate(),
				"failed_public_decision_audit": (
					selected.get("decision_audit", {}).duplicate(true) if not passed else {}
				),
			})
		if case_passed:
			passed_exams += 1
		results.append({
			"exam_id": str(exam.get("exam_id", "")),
			"issue_number": int(exam.get("issue_number", 0)),
			"turn_number": int(exam.get("turn_number", 0)),
			"provenance": str(exam.get("provenance", "")),
			"expected_selected_indexes": expected,
			"selection_order_insensitive": order_insensitive,
			"passed": case_passed,
			"runs": case_runs,
		})
	if exams.size() >= 20:
		print("EXAM_PROGRESS: %d/%d complete" % [exams.size(), exams.size()])
	catalog.free()
	return {
		"ok": true,
		"error_code": "",
		"corpus_id": str(corpus.get("corpus_id", "")),
		"expectation_key": expectation_key,
		"repetitions_per_exam": repetitions,
		"passed_exams": passed_exams,
		"total_exams": exams.size(),
		"passed_runs": passed_runs,
		"total_runs": total_runs,
		"pass_percent": 100.0 * float(passed_runs) / float(total_runs) if total_runs > 0 else 0.0,
		"all_passed": passed_exams == exams.size(),
		"results": results,
	}


static func _fixture_from_admitted_handle(handle: Variant) -> Dictionary:
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return {}
	var metadata: Variant = handle.get("_metadata")
	var payloads: Variant = handle.get("_payloads")
	var local_deck: Variant = handle.get("_local_deck")
	if not metadata is Dictionary or not payloads is Dictionary or not local_deck is Array:
		return {}
	return {
		"metadata": metadata.duplicate(true),
		"payloads": payloads.duplicate(true),
		"local_deck": local_deck.duplicate(true),
	}


static func build_frame(exam: Dictionary, sequence: int) -> Dictionary:
	var compact_state: Dictionary = exam.get("state", {})
	var compact_self: Dictionary = compact_state.get("self", {})
	var compact_opponent: Dictionary = compact_state.get("opponent", {})
	var own_hand: Array = []
	for index: int in compact_self.get("hand", []).size():
		own_hand.append(_card(str(compact_self.get("hand", [])[index]), 10000 + index))
	var own_active := _slot_list(compact_self.get("active", []), 11000)
	var own_bench := _slot_list(compact_self.get("bench", []), 12000)
	var own_discard: Array = []
	for index: int in compact_self.get("discard", []).size():
		own_discard.append(_card(str(compact_self.get("discard", [])[index]), 13000 + index))
	var opponent_discard: Array = []
	for index: int in compact_opponent.get("discard", []).size():
		opponent_discard.append(_card(
			str(compact_opponent.get("discard", [])[index]), 16000 + index
		))
	var public_state := {
		"turn_number": int(exam.get("turn_number", 0)),
		"phase": str(compact_state.get("phase", "MAIN")),
		"self": {
			"hand": own_hand,
			"active": own_active,
			"bench": own_bench,
			"bench_capacity": maxi(5, own_bench.size()),
			"discard": own_discard,
			"deck_count": int(compact_self.get("deck_count", 0)),
			"prizes_remaining": int(compact_self.get("prizes_remaining", 6)),
			"turn": compact_self.get("turn", {
				"supporter_available": true,
				"manual_attachment_available": true,
				"retreat_available": true,
			}).duplicate(true),
		},
		"opponent": {
			"hand_count": int(compact_opponent.get("hand_count", 0)),
			"active": _slot_list(compact_opponent.get("active", []), 14000),
			"bench": _slot_list(compact_opponent.get("bench", []), 15000),
			"discard": opponent_discard,
			"deck_count": int(compact_opponent.get("deck_count", 0)),
			"prizes_remaining": int(compact_opponent.get("prizes_remaining", 6)),
		},
	}
	var options: Array = []
	var compact_options: Array = exam.get("options", [])
	for index: int in compact_options.size():
		options.append(_option(index, compact_options[index], public_state))
	var compact_semantics: Dictionary = exam.get("select_semantics", {})
	var semantics := {
		"min_count": int(compact_semantics.get("min_count", 0)),
		"max_count": int(compact_semantics.get("max_count", 0)),
		"select_type_raw": int(compact_semantics.get("select_type_raw", 0)),
		"select_context_raw": int(compact_semantics.get("select_context_raw", 0)),
	}
	var observation: Dictionary = TreeHashScript.public_observation_hash({
		"schema_version": 2,
		"sequence": sequence,
		"seat": 1,
		"prompt_kind": exam.get("prompt_kind"),
		"public_state": public_state,
	})
	var window: Dictionary = TreeHashScript.public_observation_hash({
		"public_observation_hash": observation.get("sha256"),
		"select_semantics": semantics,
		"options": options,
	})
	return {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": sequence,
		"seat": 1,
		"prompt_kind": exam.get("prompt_kind"),
		"source": {
			"public_observation_hash": observation.get("sha256"),
			"window_id": window.get("sha256"),
		},
		"public_state": public_state,
		"select_semantics": semantics,
		"options": options,
	}


static func _card(uid: String, serial: int) -> Dictionary:
	return {"serial": serial, "local_card_uid": uid}


static func _slot_list(values: Variant, serial_base: int) -> Array:
	var result: Array = []
	if not values is Array:
		return result
	for index: int in values.size():
		var value: Variant = values[index]
		if value is Dictionary:
			result.append(_slot(value, serial_base + index))
	return result


static func _slot(compact: Dictionary, serial: int) -> Dictionary:
	var uid := str(compact.get("uid", ""))
	var energy_uids: Array = compact.get("energy_uids", []).duplicate()
	var minimum := int(compact.get("minimum_attack_energy_count", 0))
	var ready: bool = bool(compact.get("attack_ready", energy_uids.size() >= minimum))
	var result := {
		"serial": serial,
		"entity_serial": serial + 100000,
		"local_card_uid": uid,
		"remaining_hp": int(compact.get("hp", 1)),
		"max_hp": int(compact.get("max_hp", compact.get("hp", 1))),
		"damage_counters": int(compact.get("damage_counters", 0)),
		"appeared_this_turn": bool(compact.get("appeared_this_turn", false)),
		"prize_value": int(compact.get("prize_value", 2 if uid == "CSV10C_148" else 1)),
		"attached_energy_count": energy_uids.size(),
		"attached_energy_uids": energy_uids,
		"minimum_attack_energy_count": minimum,
		"attack_ready": ready,
		"energy_debt": int(compact.get("energy_debt", maxi(0, minimum - energy_uids.size()))),
	}
	if compact.has("attached_tool_uid"):
		result["attached_tool_uid"] = compact.get("attached_tool_uid")
	return result


static func _option(index: int, compact: Dictionary, public_state: Dictionary) -> Dictionary:
	var option_type := int(compact.get("option_type_raw", 3))
	var card_uid: Variant = compact.get("card_uid")
	var source_uid: Variant = compact.get("source_uid")
	var target_uid: Variant = compact.get("target_uid")
	var source_slot := _find_target_slot(public_state, str(source_uid)) if source_uid != null else {}
	var target_slot := _find_target_slot(public_state, str(target_uid)) if target_uid != null else {}
	var target_energy_uids: Array = compact.get(
		"target_energy_uids", target_slot.get("attached_energy_uids", [])
	).duplicate()
	var target_minimum: Variant = compact.get(
		"target_minimum_attack_energy_count",
		target_slot.get("minimum_attack_energy_count")
	)
	if target_minimum != null:
		target_minimum = int(target_minimum)
	var target_ready: Variant = compact.get("target_attack_ready")
	if target_ready == null and target_minimum != null:
		target_ready = target_energy_uids.size() >= int(target_minimum)
	var target_debt: Variant = compact.get("target_energy_debt")
	if target_debt == null and target_minimum != null:
		target_debt = maxi(0, int(target_minimum) - target_energy_uids.size())
	return {
		"index": index,
		"kind": str(compact.get("kind", "candidate")),
		"card_uid": card_uid,
		"card_serial": _optional_int(compact.get("card_serial", 20000 + index)) if card_uid != null else null,
		"source_uid": source_uid,
		"source_serial": _optional_int(compact.get("source_serial", 30000 + index)) if source_uid != null else null,
		"source_entity_serial": compact.get(
			"source_entity_serial", source_slot.get("entity_serial")
		) if not compact.has("source_entity_serial") else _optional_int(
			compact.get("source_entity_serial")
		),
		"target_uid": target_uid,
		"target_serial": _optional_int(compact.get("target_serial", 40000 + index)) if target_uid != null else null,
		"target_entity_serial": compact.get(
			"target_entity_serial", target_slot.get("entity_serial")
		) if not compact.has("target_entity_serial") else _optional_int(
			compact.get("target_entity_serial")
		),
		"target_remaining_hp": _optional_int(
			compact.get("target_remaining_hp", target_slot.get("remaining_hp"))
		) if target_uid != null else null,
		"target_prize_value": _optional_int(
			compact.get("target_prize_value", target_slot.get("prize_value"))
		) if target_uid != null else null,
		"target_attached_energy_count": target_energy_uids.size() if target_uid != null else null,
		"target_attached_energy_uids": target_energy_uids if target_uid != null else null,
		"target_minimum_attack_energy_count": target_minimum if target_uid != null else null,
		"target_attack_ready": target_ready if target_uid != null else null,
		"target_energy_debt": target_debt if target_uid != null else null,
		"projected_damage": _optional_int(compact.get("projected_damage")),
		"projected_knockout": bool(compact.get("projected_knockout", false)),
		"requires_interaction": bool(compact.get("requires_interaction", false)),
		"attack_index": _optional_int(compact.get("attack_index")),
		"option_number": _optional_int(compact.get("option_number")),
		"ability_index": _optional_int(compact.get("ability_index")),
		"energy_type_raw": _optional_int(compact.get("energy_type_raw")),
		"energy_count": _optional_int(compact.get("energy_count")),
		"special_condition_type": _optional_int(compact.get("special_condition_type")),
		"pending_assignment_count": int(compact.get("pending_assignment_count", 0)),
		"tags": compact.get("tags", []).duplicate(),
		"option_type_raw": option_type,
		"option_player_index": 1,
	}


static func _find_target_slot(public_state: Dictionary, uid: String) -> Dictionary:
	if uid.is_empty():
		return {}
	for zone: String in ["active", "bench"]:
		for value: Variant in public_state.get("self", {}).get(zone, []):
			if value is Dictionary and value.get("local_card_uid") == uid:
				return value
	return {}


static func _index_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item: Variant in value:
			result.append(int(item))
	return result


static func _sorted_index_array(value: Array[int]) -> Array[int]:
	var result := value.duplicate()
	result.sort()
	return result


static func _optional_int(value: Variant) -> Variant:
	return null if value == null else int(value)


static func _error_report(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"all_passed": false,
		"passed_exams": 0,
		"total_exams": 0,
		"passed_runs": 0,
		"total_runs": 0,
		"pass_percent": 0.0,
		"results": [],
	}
